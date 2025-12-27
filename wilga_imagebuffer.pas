unit wilga_imagebuffer;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, JS,
  wilga;  // TColor + WilgaAddPutImageDataCommand

type
  TRGBA = packed record
    r, g, b, a: Byte;
  end;

  TWilgaImageBuffer = record
    Width, Height: Integer;
    Pixels: array of TRGBA;

  
    JSDataFull: TJSUint8ClampedArray;

    // cache na dirty upload (będzie miało zmienny rozmiar, ale alokujemy tylko gdy trzeba)
    JSDataDirty: TJSUint8ClampedArray;

    // --- Dirty rect aktualnej klatki ---
    DirtyValid: Boolean;
    DirtyX0, DirtyY0, DirtyX1, DirtyY1: Integer; // inclusive

    // --- Dirty rect poprzedniej klatki (do czyszczenia tylko tam, gdzie trzeba) ---
    LastDirtyValid: Boolean;
    LastX0, LastY0, LastX1, LastY1: Integer; // inclusive

    procedure Init(AWidth, AHeight: Integer);
    procedure Free;
    function  IsValid: Boolean;

    procedure Resize(AWidth, AHeight: Integer);

    procedure SetPixel(x, y: Integer; const col: TColor); inline;
    procedure BlendPixel(x, y: Integer; const src: TColor); inline; // alpha-over
    procedure AddPixel(x, y: Integer; const src: TColor); inline;   // additive

    // czyści CAŁY bufor (drogo w JS) + ustawia dirty na full
    procedure Clear(const col: TColor);

    // czyści TYLKO obszar, który był dirty w poprzedniej klatce (tanie) i startuje nowy dirty tracking
    procedure BeginDirtyFrameClear(const col: TColor);

    // wysyła CAŁY bufor (czasem przydatne do debug)
    procedure DrawFull(dstX, dstY: Integer);

    // wysyła tylko dirty rect; po wysłaniu zapamiętuje go jako LastDirtyRect i resetuje DirtyValid
    procedure DrawDirty(dstX, dstY: Integer);

  private
    procedure MarkDirty(x, y: Integer); inline;
    procedure EnsureDirtyCapacity(bytesNeeded: Integer); inline;
  end;

function ColorToRGBA(const c: TColor): TRGBA; inline;
function ClampByte(v: Integer): Byte; inline;

implementation

function ClampByte(v: Integer): Byte; inline;
begin
  if v < 0 then v := 0
  else if v > 255 then v := 255;
  Result := v;
end;

function ColorToRGBA(const c: TColor): TRGBA; inline;
begin
  Result.r := ClampByte(c.r);
  Result.g := ClampByte(c.g);
  Result.b := ClampByte(c.b);
  Result.a := ClampByte(c.a);
end;

{ TWilgaImageBuffer }

procedure TWilgaImageBuffer.Init(AWidth, AHeight: Integer);
begin
  Width  := AWidth;
  Height := AHeight;

  SetLength(Pixels, 0);
  JSDataFull := nil;
  JSDataDirty := nil;

  DirtyValid := False;
  LastDirtyValid := False;

  if (Width > 0) and (Height > 0) then
  begin
    SetLength(Pixels, Width * Height);
    JSDataFull := TJSUint8ClampedArray.new(Width * Height * 4);
    // JSDataDirty alokujemy dopiero gdy będzie potrzebne
  end;
end;

procedure TWilgaImageBuffer.Free;
begin
  SetLength(Pixels, 0);
  JSDataFull := nil;
  JSDataDirty := nil;
  Width := 0;
  Height := 0;
  DirtyValid := False;
  LastDirtyValid := False;
end;

function TWilgaImageBuffer.IsValid: Boolean;
begin
  Result :=
    (Width > 0) and (Height > 0) and
    (Length(Pixels) = Width * Height) and
    (JSDataFull <> nil);
end;

procedure TWilgaImageBuffer.Resize(AWidth, AHeight: Integer);
begin
  if (AWidth = Width) and (AHeight = Height) then Exit;
  Init(AWidth, AHeight);
end;

procedure TWilgaImageBuffer.MarkDirty(x, y: Integer);
begin
  if not DirtyValid then
  begin
    DirtyValid := True;
    DirtyX0 := x; DirtyY0 := y;
    DirtyX1 := x; DirtyY1 := y;
    Exit;
  end;

  if x < DirtyX0 then DirtyX0 := x;
  if y < DirtyY0 then DirtyY0 := y;
  if x > DirtyX1 then DirtyX1 := x;
  if y > DirtyY1 then DirtyY1 := y;
end;

procedure TWilgaImageBuffer.SetPixel(x, y: Integer; const col: TColor);
var
  idx: Integer;
begin
  if not IsValid then Exit;
  if (x < 0) or (y < 0) or (x >= Width) or (y >= Height) then Exit;

  idx := y * Width + x;
  Pixels[idx] := ColorToRGBA(col);
  MarkDirty(x, y);
end;

procedure TWilgaImageBuffer.BlendPixel(x, y: Integer; const src: TColor);
var
  i: Integer;
  dst: TRGBA;
  sa, ia: Integer;
  aOut: Integer;
begin
  if not IsValid then Exit;
  if (x < 0) or (y < 0) or (x >= Width) or (y >= Height) then Exit;

  sa := src.a;
  if sa <= 0 then Exit;

  i := y * Width + x;

  if sa >= 255 then
  begin
    Pixels[i].r := src.r;
    Pixels[i].g := src.g;
    Pixels[i].b := src.b;
    Pixels[i].a := 255;
    MarkDirty(x, y);
    Exit;
  end;

  dst := Pixels[i];
  ia := 255 - sa;

  Pixels[i].r := (src.r * sa + dst.r * ia) div 255;
  Pixels[i].g := (src.g * sa + dst.g * ia) div 255;
  Pixels[i].b := (src.b * sa + dst.b * ia) div 255;

  aOut := sa + (dst.a * ia) div 255;
  if aOut > 255 then aOut := 255;
  Pixels[i].a := Byte(aOut);

  MarkDirty(x, y);
end;

procedure TWilgaImageBuffer.AddPixel(x, y: Integer; const src: TColor);
var
  i: Integer;
  dst: TRGBA;
  sa: Integer;
begin
  if not IsValid then Exit;
  if (x < 0) or (y < 0) or (x >= Width) or (y >= Height) then Exit;

  sa := src.a;
  if sa <= 0 then Exit;

  i := y * Width + x;
  dst := Pixels[i];

  Pixels[i].r := ClampByte(dst.r + (src.r * sa) div 255);
  Pixels[i].g := ClampByte(dst.g + (src.g * sa) div 255);
  Pixels[i].b := ClampByte(dst.b + (src.b * sa) div 255);
  Pixels[i].a := ClampByte(dst.a + sa);

  MarkDirty(x, y);
end;

procedure TWilgaImageBuffer.Clear(const col: TColor);
var
  i: Integer;
  rgba: TRGBA;
begin
  if not IsValid then Exit;
  rgba := ColorToRGBA(col);

  for i := 0 to High(Pixels) do
    Pixels[i] := rgba;

  // full dirty
  DirtyValid := True;
  DirtyX0 := 0; DirtyY0 := 0;
  DirtyX1 := Width - 1;
  DirtyY1 := Height - 1;

  // po pełnym clear poprzedni dirty nie ma znaczenia
  LastDirtyValid := False;
end;

procedure TWilgaImageBuffer.BeginDirtyFrameClear(const col: TColor);
var
  x, y: Integer;
  rgba: TRGBA;
  idx: Integer;
begin
  if not IsValid then Exit;

  // start nowej klatki: reset current dirty
  DirtyValid := False;

  // jeśli poprzednio nic nie było dirty, nie czyścimy nic
  if not LastDirtyValid then Exit;

  rgba := ColorToRGBA(col);

  // czyścimy TYLKO poprzedni obszar, który był rysowany
  for y := LastY0 to LastY1 do
  begin
    idx := y * Width + LastX0;
    for x := LastX0 to LastX1 do
    begin
      Pixels[idx] := rgba;
      Inc(idx);
    end;
  end;

  // czyszczenie też zmienia piksele, więc to jest dirty w tej klatce
  DirtyValid := True;
  DirtyX0 := LastX0; DirtyY0 := LastY0;
  DirtyX1 := LastX1; DirtyY1 := LastY1;
end;

procedure TWilgaImageBuffer.EnsureDirtyCapacity(bytesNeeded: Integer);
begin
  if bytesNeeded <= 0 then Exit;
  if (JSDataDirty = nil) or (JSDataDirty.length < bytesNeeded) then
    JSDataDirty := TJSUint8ClampedArray.new(bytesNeeded);
end;

procedure TWilgaImageBuffer.DrawFull(dstX, dstY: Integer);
var
  i, idx: Integer;
  rgba: TRGBA;
begin
  if not IsValid then Exit;

  idx := 0;
  for i := 0 to High(Pixels) do
  begin
    rgba := Pixels[i];
    JSDataFull[idx    ] := rgba.r;
    JSDataFull[idx + 1] := rgba.g;
    JSDataFull[idx + 2] := rgba.b;
    JSDataFull[idx + 3] := rgba.a;
    Inc(idx, 4);
  end;

  WilgaAddPutImageDataCommand(dstX, dstY, Width, Height, JSDataFull);

  // po full draw: lastDirty = full
  LastDirtyValid := True;
  LastX0 := 0; LastY0 := 0;
  LastX1 := Width - 1;
  LastY1 := Height - 1;

  DirtyValid := False;
end;

procedure TWilgaImageBuffer.DrawDirty(dstX, dstY: Integer);
var
  x, y: Integer;
  idxSrc: Integer;
  idxDst: Integer;
  rgba: TRGBA;
  w, h: Integer;
  bytes: Integer;
begin
  if not IsValid then Exit;
  if not DirtyValid then Exit;

  w := DirtyX1 - DirtyX0 + 1;
  h := DirtyY1 - DirtyY0 + 1;
  if (w <= 0) or (h <= 0) then Exit;

  bytes := w * h * 4;
  EnsureDirtyCapacity(bytes);

  idxDst := 0;
  for y := DirtyY0 to DirtyY1 do
  begin
    idxSrc := y * Width + DirtyX0;
    for x := DirtyX0 to DirtyX1 do
    begin
      rgba := Pixels[idxSrc];
      JSDataDirty[idxDst    ] := rgba.r;
      JSDataDirty[idxDst + 1] := rgba.g;
      JSDataDirty[idxDst + 2] := rgba.b;
      JSDataDirty[idxDst + 3] := rgba.a;
      Inc(idxDst, 4);
      Inc(idxSrc);
    end;
  end;

  // rysujemy tylko fragment w przesuniętym miejscu
  WilgaAddPutImageDataCommand(dstX + DirtyX0, dstY + DirtyY0, w, h, JSDataDirty);

  // zapamiętaj ten dirty jako "last" na kolejną klatkę
  LastDirtyValid := True;
  LastX0 := DirtyX0; LastY0 := DirtyY0;
  LastX1 := DirtyX1; LastY1 := DirtyY1;

  // reset dirty
  DirtyValid := False;
end;

end.

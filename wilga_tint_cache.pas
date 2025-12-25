unit wilga_tint_cache;
{$mode objfpc}
{$modeswitch advancedrecords}

interface

uses
  JS, Web, SysUtils, Math, wilga;

type
  TTintMode = (tmRepaint, tmMultiply);

procedure InitTintCache(MaxItems: Integer = 256);
procedure ClearTintCache;

procedure SetDefaultTintMode(Mode: TTintMode);
function  GetDefaultTintMode: TTintMode;

// Wersja „pełna” – jawnie wybierasz tryb
function GetTintedTexture(const Base: TTexture; BaseKey: LongWord; Color: TColor;
  Mode: TTintMode): TTexture;

// Wersja „ładna” – używa domyślnego trybu (np. tmMultiply)
function GetTintedTexture(const Base: TTexture; BaseKey: LongWord; Color: TColor): TTexture;

// Opcjonalnie: prewarm
procedure PrewarmTint(const Base: TTexture; BaseKey: LongWord; const Colors: array of TColor;
  Mode: TTintMode);
procedure PrewarmTint(const Base: TTexture; BaseKey: LongWord; const Colors: array of TColor);

implementation

type
  TTintEntry = record
    Key     : String;
    Tex     : TTexture;
    LastUse : Cardinal;
  end;

var
  GCache    : array of TTintEntry;
  GMaxItems : Integer = 256;
  GClock    : Cardinal = 1;

  GDefaultMode: TTintMode = tmMultiply; // <- sensowny default do gier (zachowuje detale)

  // Optymalizacja: jedna globalna, przezroczysta tekstura 1x1
  GTransparent1x1: TTexture;
  GTransparentReady: Boolean = False;

function ModeTag(M: TTintMode): String; inline;
begin
  case M of
    tmRepaint:  Result := 'mR';
    tmMultiply: Result := 'mM';
  else
    Result := 'm?';
  end;
end;

function MakeKey(BaseKey: LongWord; W, H: Integer; const C: TColor; M: TTintMode): String;
begin
  Result :=
    ModeTag(M) +
    '|id' + IntToStr(BaseKey) +
    '|w'  + IntToStr(W) +
    '|h'  + IntToStr(H) +
    '|c'  + IntToStr(C.r) + '_' + IntToStr(C.g) + '_' + IntToStr(C.b) + '_' + IntToStr(C.a);
end;

procedure Touch(Index: Integer);
begin
  Inc(GClock);
  GCache[Index].LastUse := GClock;
end;

procedure EvictIfNeeded;
var
  i, oldestIdx: Integer;
  oldestUse: Cardinal;
begin
  if (GMaxItems <= 0) then Exit;

  while Length(GCache) > GMaxItems do
  begin
    oldestIdx := 0;
    oldestUse := $FFFFFFFF;

    for i := 0 to High(GCache) do
      if GCache[i].LastUse < oldestUse then
      begin
        oldestUse := GCache[i].LastUse;
        oldestIdx := i;
      end;

    ReleaseTexture(GCache[oldestIdx].Tex);

    if oldestIdx <> High(GCache) then
      GCache[oldestIdx] := GCache[High(GCache)];
    SetLength(GCache, Length(GCache) - 1);
  end;
end;

procedure EnsureTransparent1x1;
var
  cnv: TJSHTMLCanvasElement;
  ctx: TJSCanvasRenderingContext2D;
  tid: NativeInt;
begin
  if GTransparentReady and TextureIsReady(GTransparent1x1) then Exit;

  GTransparentReady := False;

  cnv := TJSHTMLCanvasElement(document.createElement('canvas'));
  cnv.width := 1;
  cnv.height := 1;

  ctx := TJSCanvasRenderingContext2D(cnv.getContext('2d'));
  ctx.clearRect(0, 0, 1, 1);

  W_RegisterHelperCanvas(cnv);

  tid := 0;
  if TJSObject(cnv)['__wilgaTexId'] <> undefined then
    tid := Integer(TJSObject(cnv)['__wilgaTexId']);

  GTransparent1x1.canvas := cnv;
  GTransparent1x1.width := 1;
  GTransparent1x1.height := 1;
  GTransparent1x1.loaded := True;
  GTransparent1x1.texId := LongWord(tid);

  GTransparentReady := True;
end;

// ---------- Implementacje trybów tintu ----------

// tmRepaint: jednolity kolor w masce alfa (Twoje dotychczasowe source-atop)
function BuildTint_Repaint(const Base: TTexture; const C: TColor): TTexture;
var
  cnv: TJSHTMLCanvasElement;
  ctx: TJSCanvasRenderingContext2D;
  w, h: Integer;
  a: Double;
  tid: NativeInt;
begin
  w := Base.width;
  h := Base.height;

  cnv := TJSHTMLCanvasElement(document.createElement('canvas'));
  cnv.width := w;
  cnv.height := h;

  ctx := TJSCanvasRenderingContext2D(cnv.getContext('2d'));

  // baza
  ctx.globalAlpha := 1.0;
  ctx.globalCompositeOperation := 'source-over';
  ctx.drawImage(Base.canvas, 0, 0);

  // kolor w masce alfa
  a := C.a / 255.0;
  ctx.globalAlpha := a;
  ctx.globalCompositeOperation := 'source-atop';
  ctx.fillStyle := 'rgb(' + IntToStr(C.r) + ',' + IntToStr(C.g) + ',' + IntToStr(C.b) + ')';
  ctx.fillRect(0, 0, w, h);

  // reset
  ctx.globalAlpha := 1.0;
  ctx.globalCompositeOperation := 'source-over';

  W_RegisterHelperCanvas(cnv);

  tid := 0;
  if TJSObject(cnv)['__wilgaTexId'] <> undefined then
    tid := Integer(TJSObject(cnv)['__wilgaTexId']);

  Result.canvas := cnv;
  Result.width := w;
  Result.height := h;
  Result.loaded := True;
  Result.texId := LongWord(tid);
end;

// tmMultiply: barwi, ale zachowuje detale (modulate)
// 1) draw base
// 2) multiply fill color (alpha = C.a/255)
// 3) destination-in base (przywraca oryginalną alfę)
function BuildTint_Multiply(const Base: TTexture; const C: TColor): TTexture;
var
  cnv: TJSHTMLCanvasElement;
  ctx: TJSCanvasRenderingContext2D;
  w, h: Integer;
  a: Double;
  tid: NativeInt;
begin
  w := Base.width;
  h := Base.height;

  cnv := TJSHTMLCanvasElement(document.createElement('canvas'));
  cnv.width := w;
  cnv.height := h;

  ctx := TJSCanvasRenderingContext2D(cnv.getContext('2d'));

  // 1) baza
  ctx.globalAlpha := 1.0;
  ctx.globalCompositeOperation := 'source-over';
  ctx.drawImage(Base.canvas, 0, 0);

  // 2) multiply kolor
  a := C.a / 255.0;
  ctx.globalAlpha := a;
  ctx.globalCompositeOperation := 'multiply';
  ctx.fillStyle := 'rgb(' + IntToStr(C.r) + ',' + IntToStr(C.g) + ',' + IntToStr(C.b) + ')';
  ctx.fillRect(0, 0, w, h);

  // 3) przywróć alfę z oryginału
  ctx.globalAlpha := 1.0;
  ctx.globalCompositeOperation := 'destination-in';
  ctx.drawImage(Base.canvas, 0, 0);

  // reset
  ctx.globalAlpha := 1.0;
  ctx.globalCompositeOperation := 'source-over';

  W_RegisterHelperCanvas(cnv);

  tid := 0;
  if TJSObject(cnv)['__wilgaTexId'] <> undefined then
    tid := Integer(TJSObject(cnv)['__wilgaTexId']);

  Result.canvas := cnv;
  Result.width := w;
  Result.height := h;
  Result.loaded := True;
  Result.texId := LongWord(tid);
end;

function BuildTintTextureViaCanvas(const Base: TTexture; const C: TColor; Mode: TTintMode): TTexture;
begin
  case Mode of
    tmRepaint:  Result := BuildTint_Repaint(Base, C);
    tmMultiply: Result := BuildTint_Multiply(Base, C);
  else
    Result := BuildTint_Multiply(Base, C);
  end;
end;

// ---------- Public API ----------

procedure SetDefaultTintMode(Mode: TTintMode);
begin
  GDefaultMode := Mode;
end;

function GetDefaultTintMode: TTintMode;
begin
  Result := GDefaultMode;
end;

procedure InitTintCache(MaxItems: Integer);
begin
  ClearTintCache;

  GMaxItems := MaxItems;
  if GMaxItems < 0 then GMaxItems := 0;
  GClock := 1;

  GTransparentReady := False;
end;

procedure ClearTintCache;
var
  i: Integer;
begin
  for i := 0 to High(GCache) do
    ReleaseTexture(GCache[i].Tex);
  SetLength(GCache, 0);

  if GTransparentReady then
  begin
    ReleaseTexture(GTransparent1x1);
    GTransparentReady := False;
  end;
end;

function GetTintedTexture(const Base: TTexture; BaseKey: LongWord; Color: TColor;
  Mode: TTintMode): TTexture;
var
  key: String;
  i: Integer;
begin
  // PERF: alpha=0 -> nie generuj nic, zwróć wspólną przezroczystą teksturę 1x1
  if Color.a = 0 then
  begin
    EnsureTransparent1x1;
    Exit(GTransparent1x1);
  end;

  // biały pełny -> baza
  if (Color.r = 255) and (Color.g = 255) and (Color.b = 255) and (Color.a = 255) then
    Exit(Base);

  key := MakeKey(BaseKey, Base.width, Base.height, Color, Mode);

  for i := 0 to High(GCache) do
    if GCache[i].Key = key then
    begin
      Touch(i);
      Exit(GCache[i].Tex);
    end;

  SetLength(GCache, Length(GCache) + 1);
  GCache[High(GCache)].Key := key;
  GCache[High(GCache)].Tex := BuildTintTextureViaCanvas(Base, Color, Mode);
  Touch(High(GCache));

  EvictIfNeeded;

  Result := GCache[High(GCache)].Tex;
end;

function GetTintedTexture(const Base: TTexture; BaseKey: LongWord; Color: TColor): TTexture;
begin
  Result := GetTintedTexture(Base, BaseKey, Color, GDefaultMode);
end;

procedure PrewarmTint(const Base: TTexture; BaseKey: LongWord; const Colors: array of TColor;
  Mode: TTintMode);
var
  i: Integer;
begin
  for i := 0 to High(Colors) do
    GetTintedTexture(Base, BaseKey, Colors[i], Mode);
end;

procedure PrewarmTint(const Base: TTexture; BaseKey: LongWord; const Colors: array of TColor);
begin
  PrewarmTint(Base, BaseKey, Colors, GDefaultMode);
end;

end.

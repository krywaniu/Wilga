unit Wilga_ShadowState;

{$mode objfpc}{$H+}

interface

uses
  JS, Web, SysUtils;

type
  // Prosty kontekst z "shadow-state" dla najdroższych właściwości Canvas 2D.
  TWilgaShadow = record
    Ctx: TJSCanvasRenderingContext2D;
    DPR: Double;
    Width, Height: Integer;

    // Ostatnio ustawione wartości (by nie wysyłać ich w kółko).
    SFill, SOp, SFont: String;
    SAlpha: Double;

    // Flaga "coś narysowano" w tej klatce.
    Dirty: Boolean;
  end;

var
  W: TWilgaShadow; // globalny, zbiera cały stan w jednym miejscu

// === Inicjalizacja i reset ===
procedure WInit(const Canvas: TJSHTMLCanvasElement);
procedure WAttachToCurrentState(const Canvas: TJSHTMLCanvasElement;
  const Ctx: TJSCanvasRenderingContext2D);
procedure WResizeToCSSSize(const Canvas: TJSHTMLCanvasElement);
procedure WSyncSizeFromCanvas(const Canvas: TJSHTMLCanvasElement);
procedure WResetShadow;

// === Settery stanu (z ograniczaniem zbędnych setów) ===
procedure WSetFill(const RGBA: String); inline; overload;    // kolor (string)
procedure WSetFill(const Style: JSValue); inline; overload;   // CanvasGradient / CanvasPattern / String/itp.
procedure WSetAlpha(const A: Double); inline;
procedure WSetOp(const Op: String); inline;
procedure WSetFont(const F: String); inline;

// === Czyszczenie ===
procedure WClearFast(const RGBA: String);        // czyszczenie kolorem (szybkie)
procedure WClearTransparent;                     // czyszczenie do przezroczystości
procedure WClearTransparentFast;                 // najszybsze (reset wymiaru)

// === Helpery rysunkowe (opcjonalnie do wygodnych wywołań) ===
procedure WFillRect(X, Y, Wd, Hd: Double; const RGBA: String); inline;
procedure WFillText(X, Y: Double; const S, FontStr, RGBA: String); inline;

implementation

procedure WResetShadow;
begin
  W.SFill  := '';
  W.SOp    := '';
  W.SFont  := '';
  W.SAlpha := -1; // wymusza pierwszy set alphy
end;

procedure WResizeToCSSSize(const Canvas: TJSHTMLCanvasElement);
var
  cssW, cssH: Double;
begin
  if (Canvas = nil) then Exit;
  if (W.DPR <= 0) then
    W.DPR := window.devicePixelRatio;

  cssW := Canvas.clientWidth;
  cssH := Canvas.clientHeight;

  Canvas.width  := Round(cssW * W.DPR);
  Canvas.height := Round(cssH * W.DPR);

  W.Width  := Canvas.width;
  W.Height := Canvas.height;

  if Assigned(W.Ctx) then
  begin
    W.Ctx.setTransform(1,0,0,1,0,0);
    W.Ctx.scale(W.DPR, W.DPR);
    WResetShadow;
  end;
end;

procedure WInit(const Canvas: TJSHTMLCanvasElement);
begin
  if Canvas = nil then Exit;
  W.Ctx := TJSCanvasRenderingContext2D(Canvas.getContext('2d'));
  W.DPR := window.devicePixelRatio;
  WResizeToCSSSize(Canvas);
  W.Dirty := False;
end;

procedure WAttachToCurrentState(const Canvas: TJSHTMLCanvasElement;
  const Ctx: TJSCanvasRenderingContext2D);
begin
  W.Ctx := Ctx;
  W.DPR := window.devicePixelRatio;
  if Canvas <> nil then
  begin
    W.Width  := Canvas.width;
    W.Height := Canvas.height;
  end;
  WResetShadow;
  W.Dirty := False;
end;

procedure WSyncSizeFromCanvas(const Canvas: TJSHTMLCanvasElement);
begin
  if Canvas = nil then Exit;
  W.Width  := Canvas.width;
  W.Height := Canvas.height;
end;

procedure WSetFill(const RGBA: String); inline; overload;
begin
  if W.SFill <> RGBA then
  begin
    W.SFill := RGBA;
    if Assigned(W.Ctx) then
      W.Ctx.fillStyle := RGBA;
  end;
end;

procedure WSetFill(const Style: JSValue); inline; overload;
begin
  // Ustaw bezwarunkowo — Canvas 2D akceptuje String / CanvasGradient / CanvasPattern.
  if Assigned(W.Ctx) then
    W.Ctx.fillStyle := Style;
  // unieważnij stringowy cache, by następny RGBA-string na pewno się ustawił
  W.SFill := '';
end;

procedure WSetAlpha(const A: Double); inline;
begin
  if (W.SAlpha <> A) then
  begin
    W.SAlpha := A;
    if Assigned(W.Ctx) then
      W.Ctx.globalAlpha := A;
  end;
end;

procedure WSetOp(const Op: String); inline;
begin
  if W.SOp <> Op then
  begin
    W.SOp := Op;
    if Assigned(W.Ctx) then
      W.Ctx.globalCompositeOperation := Op;
  end;
end;

procedure WSetFont(const F: String); inline;
begin
  if W.SFont <> F then
  begin
    W.SFont := F;
    if Assigned(W.Ctx) then
      W.Ctx.font := F;
  end;
end;

procedure WClearFast(const RGBA: String);
begin
  if not Assigned(W.Ctx) then Exit;
  // kolorowe czyszczenie (nieprzezroczyste – zgodnie z podanym kolorem)
  W.Ctx.setTransform(1,0,0,1,0,0);
  WSetFill(RGBA);
  W.Ctx.fillRect(0, 0, W.Width, W.Height);
  W.Ctx.setTransform(W.DPR,0,0,W.DPR,0,0);
  W.Dirty := False;
end;

procedure WClearTransparent;
begin
  if not Assigned(W.Ctx) then Exit;
  // czyszczenie do przezroczystości (działa, gdy kontekst tworzony z alpha=true)
  W.Ctx.setTransform(1,0,0,1,0,0);
  W.Ctx.clearRect(0, 0, W.Width, W.Height);
  W.Ctx.setTransform(W.DPR,0,0,W.DPR,0,0);
  W.Dirty := False;
end;

procedure WClearTransparentFast;
var
  Cnv: TJSHTMLCanvasElement;
begin
  if not Assigned(W.Ctx) then Exit;
  // reset wymiaru canvasu czyści backstore do transparentu i zwykle jest bardzo szybki
  Cnv := TJSHTMLCanvasElement(W.Ctx.canvas);
  if Cnv <> nil then
  begin
    Cnv.width  := W.Width;
    Cnv.height := W.Height;
    W.Ctx.setTransform(W.DPR,0,0,W.DPR,0,0);
    WResetShadow; // po resecie context ma stan domyślny
  end;
  W.Dirty := False;
end;

procedure WFillRect(X, Y, Wd, Hd: Double; const RGBA: String); inline;
begin
  if not Assigned(W.Ctx) then Exit;
  WSetFill(RGBA);
  W.Ctx.fillRect(X, Y, Wd, Hd);
  W.Dirty := True;
end;

procedure WFillText(X, Y: Double; const S, FontStr, RGBA: String); inline;
begin
  if not Assigned(W.Ctx) then Exit;
  WSetFont(FontStr);
  WSetFill(RGBA);
  W.Ctx.fillText(S, X, Y);
  W.Dirty := True;
end;

end.

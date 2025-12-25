unit wilga_scope;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}

interface

uses
  wilga;

type
  // Anonymous: WithXxx(..., procedure begin ... end);
  TWilgaProcRef = reference to procedure;
  // Classic: WithXxxP(..., @MyProc);
  TWilgaProc    = procedure;

procedure WithCanvasSave(const body: TWilgaProcRef); overload;
procedure WithCanvasSaveP(body: TWilgaProc); overload;

procedure WithClipRect(x, y, w, h: Double; const body: TWilgaProcRef); overload;
procedure WithClipRectP(x, y, w, h: Double; body: TWilgaProc); overload;

// Transform helpers
procedure WithTransform(tx, ty, rotRad, sx, sy: Double; const body: TWilgaProcRef); overload;
procedure WithTransformP(tx, ty, rotRad, sx, sy: Double; body: TWilgaProc); overload;

procedure WithTransformMatrix(a, b, c, d, e, f: Double; const body: TWilgaProcRef); overload;
procedure WithTransformMatrixP(a, b, c, d, e, f: Double; body: TWilgaProc); overload;

// View / render state
procedure WithScissor(x, y, w, h: Integer; const body: TWilgaProcRef); overload;
procedure WithScissorP(x, y, w, h: Integer; body: TWilgaProc); overload;

procedure WithMode2D(const camera: TCamera2D; const body: TWilgaProcRef); overload;
procedure WithMode2DP(const camera: TCamera2D; body: TWilgaProc); overload;

procedure WithTextureMode(const rt: TRenderTexture2D; const body: TWilgaProcRef); overload;
procedure WithTextureModeP(const rt: TRenderTexture2D; body: TWilgaProc); overload;

// Stateful canvas helpers
procedure WithAlpha(const alpha: Double; const body: TWilgaProcRef); overload;
procedure WithAlphaP(const alpha: Double; body: TWilgaProc); overload;

procedure WithBlendMode(const mode: TBlendMode; const body: TWilgaProcRef); overload;
procedure WithBlendModeP(const mode: TBlendMode; body: TWilgaProc); overload;

procedure WithShadow(const color: TColor; const blur: Double; const body: TWilgaProcRef); overload;
procedure WithShadowP(const color: TColor; const blur: Double; body: TWilgaProc); overload;

procedure WithImageSmoothing(const enabled: Boolean; const body: TWilgaProcRef); overload;
procedure WithImageSmoothingP(const enabled: Boolean; body: TWilgaProc); overload;

implementation

// ------------------------------------------------------------
// Canvas save / restore
// ------------------------------------------------------------

procedure WithCanvasSave(const body: TWilgaProcRef);
begin
  CanvasSave;
  try
    body();
  finally
    CanvasRestore;
  end;
end;

procedure WithCanvasSaveP(body: TWilgaProc);
begin
  CanvasSave;
  try
    body();
  finally
    CanvasRestore;
  end;
end;

// ------------------------------------------------------------
// Scissor / clip
// ------------------------------------------------------------

procedure WithScissor(x, y, w, h: Integer; const body: TWilgaProcRef);
begin
  BeginScissor(x, y, w, h);
  try
    body();
  finally
    EndScissor;
  end;
end;

procedure WithScissorP(x, y, w, h: Integer; body: TWilgaProc);
begin
  BeginScissor(x, y, w, h);
  try
    body();
  finally
    EndScissor;
  end;
end;

procedure WithClipRect(x, y, w, h: Double; const body: TWilgaProcRef);
begin
  // Rect-clip przez scissor (publiczne API Wilgi)
  BeginScissor(Round(x), Round(y), Round(w), Round(h));
  try
    body();
  finally
    EndScissor;
  end;
end;

procedure WithClipRectP(x, y, w, h: Double; body: TWilgaProc);
begin
  BeginScissor(Round(x), Round(y), Round(w), Round(h));
  try
    body();
  finally
    EndScissor;
  end;
end;

// ------------------------------------------------------------
// Camera / texture modes
// ------------------------------------------------------------

procedure WithMode2D(const camera: TCamera2D; const body: TWilgaProcRef);
begin
  BeginMode2D(camera);
  try
    body();
  finally
    EndMode2D;
  end;
end;

procedure WithMode2DP(const camera: TCamera2D; body: TWilgaProc);
begin
  BeginMode2D(camera);
  try
    body();
  finally
    EndMode2D;
  end;
end;

procedure WithTextureMode(const rt: TRenderTexture2D; const body: TWilgaProcRef);
begin
  BeginTextureMode(rt);
  try
    body();
  finally
    EndTextureMode;
  end;
end;

procedure WithTextureModeP(const rt: TRenderTexture2D; body: TWilgaProc);
begin
  BeginTextureMode(rt);
  try
    body();
  finally
    EndTextureMode;
  end;
end;

// ------------------------------------------------------------
// Transform helpers
// ------------------------------------------------------------

procedure WithTransform(tx, ty, rotRad, sx, sy: Double; const body: TWilgaProcRef);
begin
  CanvasSave;
  try
    Translate(tx, ty);
    if rotRad <> 0 then Rotate(rotRad);
    if (sx <> 1) or (sy <> 1) then Scale(sx, sy);
    body();
  finally
    CanvasRestore;
  end;
end;

procedure WithTransformP(tx, ty, rotRad, sx, sy: Double; body: TWilgaProc);
begin
  CanvasSave;
  try
    Translate(tx, ty);
    if rotRad <> 0 then Rotate(rotRad);
    if (sx <> 1) or (sy <> 1) then Scale(sx, sy);
    body();
  finally
    CanvasRestore;
  end;
end;

procedure WithTransformMatrix(a, b, c, d, e, f: Double; const body: TWilgaProcRef);
begin
  CanvasSave;
  try
    SetTransform(a, b, c, d, e, f);
    body();
  finally
    CanvasRestore;
  end;
end;

procedure WithTransformMatrixP(a, b, c, d, e, f: Double; body: TWilgaProc);
begin
  CanvasSave;
  try
    SetTransform(a, b, c, d, e, f);
    body();
  finally
    CanvasRestore;
  end;
end;

// ------------------------------------------------------------
// Stateful helpers
// ------------------------------------------------------------

procedure WithAlpha(const alpha: Double; const body: TWilgaProcRef);
begin
  CanvasSave;
  try
    CanvasSetGlobalAlpha(alpha);
    body();
  finally
    CanvasRestore;
  end;
end;

procedure WithAlphaP(const alpha: Double; body: TWilgaProc);
begin
  CanvasSave;
  try
    CanvasSetGlobalAlpha(alpha);
    body();
  finally
    CanvasRestore;
  end;
end;

procedure WithBlendMode(const mode: TBlendMode; const body: TWilgaProcRef);
begin
  CanvasSave;
  try
    SetBlendMode(mode);
    body();
  finally
    CanvasRestore;
  end;
end;

procedure WithBlendModeP(const mode: TBlendMode; body: TWilgaProc);
begin
  CanvasSave;
  try
    SetBlendMode(mode);
    body();
  finally
    CanvasRestore;
  end;
end;

procedure WithShadow(const color: TColor; const blur: Double; const body: TWilgaProcRef);
begin
  CanvasSave;
  try
    CanvasSetShadow(color, blur);
    body();
  finally
    CanvasRestore;
  end;
end;

procedure WithShadowP(const color: TColor; const blur: Double; body: TWilgaProc);
begin
  CanvasSave;
  try
    CanvasSetShadow(color, blur);
    body();
  finally
    CanvasRestore;
  end;
end;

// ------------------------------------------------------------
// Image smoothing (getter/setter – BEZPIECZNE)
// ------------------------------------------------------------

procedure WithImageSmoothing(const enabled: Boolean; const body: TWilgaProcRef);
var
  prev: Boolean;
begin
  prev := GetImageSmoothing;
  SetImageSmoothing(enabled);
  try
    body();
  finally
    SetImageSmoothing(prev);
  end;
end;

procedure WithImageSmoothingP(const enabled: Boolean; body: TWilgaProc);
var
  prev: Boolean;
begin
  prev := GetImageSmoothing;
  SetImageSmoothing(enabled);
  try
    body();
  finally
    SetImageSmoothing(prev);
  end;
end;

end.

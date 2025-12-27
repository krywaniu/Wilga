unit wilga;
{$mode objfpc}{$H+} {$modeswitch advancedrecords}
{$I wilga_config.inc}
{$IFNDEF WILGA_LEAK_GUARD}
  {$MESSAGE WARN 'WILGA_LEAK_GUARD is OFF - leak detection disabled'}
{$ENDIF}
{$IFNDEF WILGA_ASSERTS}
  {$MESSAGE WARN 'WILGA_ASSERTS is OFF - leak detection disabled'}
{$ENDIF}


{*
  Wilga — canvas 2D helper for pas2js (Raylib-inspired)
*}

interface

uses
  JS, Web, SysUtils,wilga_shadowstate,WebAudio,
 Math
  {$IFDEF WILGA_TEXT_CACHE}
  , wilga_text_cache
  {$ENDIF}
  ;
  type
TSoundInstance = class
  public
    source : TJSAudioBufferSourceNode;
    gain   : TJSGainNode;
    panner : TJSStereoPannerNode; // NOWE: panorama L/R
    looped : Boolean;
    playing: Boolean;
    procedure Stop;
  end;


  // "Pool" oparty na Web Audio – trzymamy tylko zdekodowany bufor,
  // domyślną głośność, flagę loop oraz ewentualną aktywną pętlę
  TSoundPool = record
    url          : String;
    buffer       : TJSAudioBuffer;
    defaultVolume: Double;
    looped       : Boolean;
    valid        : Boolean;
    activeLoop   : TSoundInstance;  // dla dźwięków loopowanych (np. muzyka)
  end;


  TTimeMS = NativeUInt; 
 var
  gCtx: TJSCanvasRenderingContext2D;





var
  gCharQueue: TJSArray; // globalnie, obok gKeys/gKeysPressed

  gActiveOneshots: array of TSoundInstance; // <-- wstaw TU swój typ z kroku 1

  gAudioShutdownHooksInstalled: Boolean = False;

  gCurrentAlpha: Double = 1.0;

  gMeasureCanvas: TJSHTMLCanvasElement = nil;
  gMeasureCtx   : TJSCanvasRenderingContext2D = nil; 
  GFontSize: Integer;
  GFontFamily: String = 'system-ui, sans-serif';
  gTintCtx: TJSCanvasRenderingContext2D = nil;
  // bieżąca pozycja kursora (aktualizowana w move)
  W_MouseX, W_MouseY: Integer;
   gRenderWorker: JSValue;
  // LATCHE: pozycja z pointerdown, ważna przez krótki czas
  W_MouseLatchX, W_MouseLatchY: Integer;
  W_MouseLatchUntilMS: TTimeMS;   // do kiedy zwracać latch (ms
  // Cache pomiarów tekstu: klucz = font+'|'+text
  GTextWidthCache: TJSMap = nil;
  GTextHeightCache: TJSMap = nil;
  GNextTextureId: Integer = 1;



type

  TLineJoinKind = (ljMiter, ljRound, ljBevel);
  TLineCapKind  = (lcButt, lcRound, lcSquare);
TNoArgProc = procedure;
  // ====== PODSTAWOWE TYPY ======
  TColor = record
    r, g, b, a: Integer; 
    function Lighten(amount: Integer): TColor;
    function Darken(amount: Integer): TColor;
    function WithAlpha(newAlpha: Integer): TColor;
    function Blend(const other: TColor; factor: Double): TColor;
  end;

  TProfileEntry = record
    name: String;
    startTime: Double;
  end;

  TSoundHandle = Integer;

type
  TSoundPoolItem = record
    el: TJSHTMLAudioElement;
  end;


  type
    TMouseBtn = 0..2; // 0=LPM, 1=ŚPM, 2=PPM
    const
  W_PRESSED_HOLD_MS = 90;
  W_KEY_PRESSED_HOLD_MS = 90; // keep key 'Pressed' edge latched for at least this many ms
  // ile ms krawędź "Pressed" ma być widoczna co najmniej
var
  // zbocza na klatkę
  W_Pressed:  array[TMouseBtn] of Boolean;   
  W_Released: array[TMouseBtn] of Boolean;   




  W_PressedNext   : array[0..2] of Boolean;  
  W_ReleasedNext  : array[0..2] of Boolean;  
 
    
  W_CurrDown      : array[0..2] of Boolean;  

  // NOWE: „rozciągnięcie” krawędzi Pressed w czasie
  W_PressedUntilMS: array[0..2] of TTimeMS;


  // --- DEBUG LICZNIKI ---
  W_DBG_WilgaDown  : NativeUInt = 0;  // ile razy Wilga złapała "down"
  W_DBG_WilgaUp    : NativeUInt = 0;  // ile razy Wilga złapała "up"
  W_DBG_Pressed    : NativeUInt = 0;  // ile razy powstało "Pressed"

  // kolejka „kliknięć” z DOM (zliczana na pointerup)
  W_ClickQ:   array[TMouseBtn] of NativeInt;


var
  // canvas do pointer capture
  W_Canvas:   TJSHTMLCanvasElement;

  W_PrevDown: array[TMouseBtn] of Boolean;

  W_PressedTimeMS: array[0..2] of TTimeMS; // czas ostatniego wciśnięcia (pomaga przy mikroklikach)
var
  W_LastEventTimeMS: TTimeMS = 0;


type
  TInputVector = record
    x, y: Double;
  end;

  
  TVector2 = TInputVector;

  TPixelBatchItem = record
    x, y: Integer;
    color: TColor;
  end;
TLineBatchItem = record
    startX, startY, endX, endY: Double;
    color: TColor;
    thickness: Integer;
  end;

  TLine = record
    startPoint, endPoint: TInputVector;
  end;
TCircle = record cx, cy, radius: Double; end;
  TTriangle = record
    p1, p2, p3: TInputVector;
  end;

  TBlendMode = (
    bmNormal,    // = 'source-over'
    bmAdd,       // = 'lighter'
    bmMultiply,  // = 'multiply'
    bmScreen     // = 'screen'
  );


 type
  TPolygon = array of TInputVector;
  TPolygons = array of TPolygon;

  TMatrix2D = record
    m0, m1, m2: Double;
    m3, m4, m5: Double;
    function Transform(v: TInputVector): TInputVector;
    function Multiply(const b: TMatrix2D): TMatrix2D;
    procedure ApplyToContext;
    function Invert: TMatrix2D;
  end;



  TCamera2D = record
    target: TInputVector;
    offset: TInputVector;
    rotation: Double; 
    zoom: Double;
    function GetMatrix: TMatrix2D;
  end;

  TRectangle = record
    x, y, width, height: Double;


    constructor Create(x, y, w, h: Double); inline;
    class function FromCenter(cx, cy, w, h: Double): TRectangle; static; inline;

    function Move(dx, dy: Double): TRectangle;
    function Scale(sx, sy: Double): TRectangle;
    function Inflate(dx, dy: Double): TRectangle;
    function Contains(const point: TInputVector): Boolean;
    function Intersects(const other: TRectangle): Boolean;
    function GetCenter: TInputVector;
  end;


  TTexture = record
    canvas: TJSHTMLCanvasElement;
    width, height: Integer;
    loaded: Boolean;
    texId: Integer; 
  end;


  TRenderTexture2D = record
    texture: TTexture;
  end;


  TParticle = record
    position: TInputVector;
    velocity: TInputVector;
    color: TColor;
    life: Double;
    initialLife: Double; 
    size: Double;
    rotation: Double;
    angularVelocity: Double;
    startColor: TColor;  
endColor: TColor;    
  end;

  TParticleSystem = class
  private
    particles: array of TParticle;
    maxParticles: Integer;
  public
    constructor Create(maxCount: Integer);
  procedure Emit(pos: TInputVector; count: Integer; const aStartColor, aEndColor: TColor;
               minSize, maxSize, minLife, maxLife: Double);
    procedure Update(dt: Double);
    procedure Draw;
    function GetActiveCount: Integer;
  end;

  // Callback do asynchronicznego ładowania tekstur
  TOnTextureReady = reference to procedure (const tex: TTexture);


  // ====== LOOP W STYLU „DT” ======
  TDeltaProc = procedure(const dt: Double);
  var
  gCurrentBlendMode: TBlendMode = bmNormal;
{ ====== FUNKCJE POMOCNICZE ====== }
procedure StartSource(src: TJSAudioBufferSourceNode; when: Double);
procedure ResumeAudioIfNeeded;
procedure initaudio;
function GetScreenWidth: Integer;
function GetScreenHeight: Integer;
function GetMouseX: Integer;
function GetMouseY: Integer;
function GetFrameTime: Double;
function GetFPS: Integer;
function GetDeltaTime: Double;
function ClampD(value, minVal, maxVal: Double): Double;
function OriginTopLeft: TVector2; inline;
function OriginCenter(const dst: TRectangle): TVector2; inline;
procedure DrawTextureTopLeft(const tex: TTexture; x, y: Double; const tint: TColor);
// === Event-accurate click queue ===
procedure W_QueueClickXY(btn, x, y: Integer);
function  W_PopClick(out x, y: Integer): Boolean;
procedure W_ForceAllUp;


function ColorToCanvasRGBA(const c: TColor): String;

// Ustawienia wydajności / jakości
procedure SetHiDPI(enabled: Boolean);
procedure SetCanvasAlpha(enabled: Boolean);
procedure SetImageSmoothing(enabled: Boolean);
procedure SetClearFast(enabled: Boolean);
procedure Clear(const color: TColor);
function GetImageSmoothing: Boolean;
function GetBlendMode: TBlendMode;
type
  // Tryb generowania tintu w TintCache:
  // - TINT_MULTIPLY: zachowuje detale tekstury (polecane dla jednostek i zaznaczeń)
  // - TINT_REPAINT: jednolity kolor w masce alfa (dobre dla ikon/masek)
  TTintModeSimple = (TINT_REPAINT, TINT_MULTIPLY);

procedure SetTintMode(const Mode: TTintModeSimple);
function GetTintMode: TTintModeSimple;

procedure SetGlobalAlpha(const A: Double);
function GetGlobalAlpha: Double;

procedure W_InitMeasureCanvas;

{ ====== CLIP / RYSOWANIE USTAWIENIA ====== }
procedure BeginScissor(x, y, w, h: Integer);
procedure EndScissor;
procedure SetLineJoin(const joinKind: String); // 'miter'|'round'|'bevel'
procedure SetLineCap(const capKind: String);   // 'butt'|'round'|'square'

procedure SetLineJoin(const joinKind: TLineJoinKind); overload;
procedure SetLineCap(const capKind: TLineCapKind); overload;


function WilgaEnsureCanvasRef: Boolean;
procedure W_RegisterTexture(var Tex: TTexture);

//screenshoots
// ====== Eksport canvasa ======
procedure SaveCanvasPNG(ACanvas: TJSHTMLCanvasElement; const FileName: string = 'wilga-export.png');
procedure SaveCanvasJPEG(ACanvas: TJSHTMLCanvasElement; const FileName: string = 'wilga-export.jpg'; Quality: Double = 0.92);
procedure CopyCanvasToClipboard(ACanvas: TJSHTMLCanvasElement);

// ====== Proste wrappery dla wygody ======
procedure WilgaSavePNG(const FileName: string = 'wilga-export.png');
procedure WilgaSaveJPEG(const FileName: string = 'wilga-export.jpg'; Quality: Double = 0.92);
procedure WilgaCopyToClipboard;




//BEZIER KRZYWE
procedure DrawBezierQ(const p0, p1, p2: TInputVector;
  const color: TColor; thickness: Integer = 1);

procedure DrawDashedBezierQ(const p0, p1, p2: TInputVector;
  const color: TColor; thickness: Integer; dashLen, gapLen: Double);

procedure DrawBezierC(const p0, p1, p2, p3: TInputVector;
  const color: TColor; thickness: Integer = 1);

procedure DrawDashedBezierC(const p0, p1, p2, p3: TInputVector;
  const color: TColor; thickness: Integer; dashLen, gapLen: Double);
function BezierCPoint(const p0, p1, p2, p3: TInputVector;
  t: Double): TInputVector;

procedure SampleBezierC(const p0, p1, p2, p3: TInputVector;
  samples: Integer; out pts: array of TInputVector);



{ ====== RYSOWANIE KSZTAŁTÓW ====== }




procedure DrawRectangleRounded(x, y, w, h, radius: double; const color: TColor; filled: Boolean = True);
procedure DrawRectangleRoundedRec(const rec: TRectangle; radius: Double; const color: TColor; filled: Boolean = True);
procedure DrawLine(startX, startY, endX, endY: double; const color: TColor; thickness: Integer = 1);
procedure DrawLineV(startPos, endPos: TInputVector; const color: TColor; thickness: Integer = 1);
procedure DrawTriangle(const tri: TTriangle; const color: TColor; filled: Boolean = True);
procedure DrawTriangleLines(const tri: TTriangle; const color: TColor; thickness: Integer = 1);
procedure DrawRectangleLines(x, y, w, h: double; const color: TColor; thickness: Integer = 1);
procedure DrawSquare(x, y, size: double; const color: TColor);
procedure DrawSquareLines(x, y, size: double; const color: TColor; thickness: Integer = 1);
procedure DrawSquareFromCenter(cx, cy, size: double; const color: TColor);
procedure DrawSquareFromCenterLines(cx, cy, size: double; const color: TColor; thickness: Integer = 1);
// --- Helpers rysujące względem środka ---

procedure DrawRectangleFromCenter(cx, cy, w, h: Double; const color: TColor);
procedure DrawCircleFromCenter(cx, cy, radius: Double; const color: TColor);

// Obrys zaokrąglonego prostokąta z kontrolą grubości
procedure DrawRectangleRoundedStroke(x, y, w, h, radius: double; const color: TColor; thickness: Integer = 1);
procedure DrawRectangleRoundedRecStroke(const rec: TRectangle; radius: Double; const color: TColor; thickness: Integer = 1);

// Batch obrysów prostokątów
procedure BeginRectStrokeBatch(const color: TColor; thickness: Integer = 1);
procedure BatchRectStroke(x, y, w, h: Integer);
procedure EndRectStrokeBatch;

// Batch rysowania prostokątów
procedure BeginRectBatch(const color: TColor);
procedure BatchRect(x, y, w, h: Integer);
procedure EndRectBatchFill;

// Batch rysowania okręgów (wypełnienie)
procedure BeginCircleBatch(const color: TColor);
procedure BatchCircle(cx, cy, radius: Double);
procedure EndCircleBatchFill;

// Batch obrysów okręgów
procedure BeginCircleStrokeBatch(const color: TColor; thickness: Integer = 1);
procedure BatchCircleStroke(cx, cy, radius: Double);
procedure EndCircleStrokeBatch;


// Batch rysowania linii
procedure BeginLineBatch;
procedure BatchLine(aStartX, aStartY, aEndX, aEndY: Double; const aColor: TColor; aThickness: Integer = 1);
procedure BatchLineV(const aStartPos, aEndPos: TInputVector; const aColor: TColor; aThickness: Integer = 1);
procedure EndLineBatch;

// Rysowanie piksela (zgodne nazwami z wilga) + batch
procedure DrawPixel(x, y: Integer; const color: TColor);
procedure DrawPixelV(const pos: TInputVector; const color: TColor);

procedure BeginPixelBatch;
procedure BatchPixel(x, y: Integer; const color: TColor);
procedure BatchPixelV(const pos: TInputVector; const color: TColor);
procedure EndPixelBatch;


procedure W_RegisterHelperCanvas(const cnv: TJSHTMLCanvasElement);

// Szybka seria prostokątów
procedure BeginRectSeries(const color: TColor);
procedure RectFill(x, y, w, h: Integer);
procedure EndRectSeries;

// ====== Batch trójkątów (wypełnienie i obrys) ======
procedure BeginTriangleBatch(const color: TColor);
procedure BatchTriangle(const tri: TTriangle);
procedure EndTriangleBatchFill;

procedure BeginTriangleStrokeBatch(const color: TColor; thickness: Integer = 1);
procedure BatchTriangleStroke(const tri: TTriangle);
procedure EndTriangleStrokeBatch;


procedure ExportWilgaToWindow;

// ====== Batch wielokątów (wypełnienie i obrys) ======
procedure BeginPolygonBatch(const color: TColor);
procedure BatchPolygon(const points: array of TInputVector);
procedure EndPolygonBatchFill;

procedure BeginPolygonStrokeBatch(const color: TColor; thickness: Integer = 1);
procedure BatchPolygonStroke(const points: array of TInputVector);
procedure EndPolygonStrokeBatch;

// ====== Wygodne „one-shot” ======
procedure DrawTrianglesBatch(const tris: array of TTriangle; const color: TColor;
  filled: Boolean = True; thickness: Integer = 1);

procedure DrawPolygonsBatch(const polys: TPolygons; const color: TColor;
  filled: Boolean = True; thickness: Integer = 1);

// ====== One-shot batch ======
procedure DrawRectsBatch(const rects: array of TRectangle; const color: TColor;
  filled: Boolean = True; thickness: Integer = 1);

procedure DrawCirclesBatch(const circles: array of TCircle; const color: TColor;
  filled: Boolean = True; thickness: Integer = 1);

procedure DrawLinesBatch(const lines: array of TLine; const color: TColor;
  thickness: Integer = 1);

procedure DrawPixelsBatch(const points: array of TInputVector; const color: TColor);

procedure WilgaAddPutImageDataCommand(x, y, width, height: Integer; const Buf: TJSUint8ClampedArray);
{ ====== TRANSFORMACJE I MACIERZE ====== }
function MatrixIdentity: TMatrix2D;
function MatrixTranslate(tx, ty: Double): TMatrix2D;
function MatrixRotate(radians: Double): TMatrix2D;
function MatrixRotateDeg(deg: Double): TMatrix2D;
function MatrixScale(sx, sy: Double): TMatrix2D;
function MatrixMultiply(const a, b: TMatrix2D): TMatrix2D;
function Vector2Transform(v: TInputVector; mat: TMatrix2D): TInputVector;


procedure EnsureAuxCanvas(w, h: Integer);
// Memory pooling
function GetVectorFromPool(x, y: Double): TInputVector;
procedure ReturnVectorToPool(var v: TInputVector);
function GetMatrixFromPool: TMatrix2D;
procedure ReturnMatrixToPool(var mat: TMatrix2D);

{ ====== KAMERA ====== }
function DefaultCamera: TCamera2D;
procedure BeginMode2D(const camera: TCamera2D);
procedure EndMode2D;
function ScreenToWorld(p: TVector2; const cam: TCamera2D): TVector2;
function WorldToScreen(p: TVector2; const cam: TCamera2D): TVector2;

{ ====== KOLIZJE ====== }
function CheckCollisionPointRec(point: TInputVector; const rec: TRectangle): Boolean;
function CheckCollisionCircles(center1: TInputVector; radius1: Double;
                              center2: TInputVector; radius2: Double): Boolean;
function CheckCollisionCircleRec(center: TInputVector; radius: Double; const rec: TRectangle): Boolean;
function CheckCollisionRecs(const a, b: TRectangle): Boolean;
function CheckCollisionPointCircle(point, center: TInputVector; radius: Double): Boolean;
function CheckCollisionPointPoly(point: TInputVector; const points: array of TInputVector): Boolean;
function CheckCollisionLineLine(a1, a2, b1, b2: TInputVector): Boolean;
function CheckCollisionLineRec(const line: TLine; const rec: TRectangle): Boolean;
function LinesIntersect(p1, p2, p3, p4: TInputVector; out t, u: Double): Boolean;
//randomy
function GetRandomValue(minVal, maxVal: Integer): Integer;
function GetRandomFloat(minVal, maxVal: Double): Double;
function GetRandomBool: Boolean;
{ ====== OBRAZY ====== }
procedure LoadImageFromURL(const url: String; OnReady: TOnTextureReady); overload;
function  LoadImageFromURL(const url: String): TTexture; overload; deprecated deprecated '⚠ LoadImageFromURL without a callback may not work — please use the version with a callback.';
procedure DrawTexture(const tex: TTexture; x, y: Integer; const tint: TColor);
procedure DrawTextureV(const tex: TTexture; position: TInputVector; const tint: TColor);
procedure DrawTexturePro(const tex: TTexture; const src, dst: TRectangle; origin: TVector2; rotationDeg: Double; const tint: TColor);
function  TextureIsReady(const tex: TTexture): Boolean;

{ ====== ZDARZENIA MYSZY ====== }
function GetMouseWheelMove: Integer;
function IsMouseButtonDown(btn: Integer): Boolean;
function IsMouseButtonPressed(btn: Integer): Boolean;
function IsMouseButtonReleased(btn: Integer): Boolean;
function GetMousePosition: TInputVector;
function GetMouseDelta: TInputVector;
procedure W_OnPointerMove(x, y: Integer);
procedure W_OnPointerDown(btn: Integer);
procedure W_OnPointerUp(btn: Integer);
procedure W_OnWheel(delta: Integer);


procedure W_OnBlurOrLeave(dummy: Integer);
procedure W_FixCanvasDPI;

// === Per-frame (wołaj raz na klatkę PRZED Update) ===
procedure W_InputBeginFrame;


//tekst
procedure W_QueryFontMetrics(fontSize: Integer; out AAsc, ADesc: Double);

{ ====== CZAS ====== }
procedure WaitTime(ms: Double); // Uwaga: busy-wait (debug only)
function GetTime: Double;

{ ====== MATEMATYKA ====== }
function Lerp(start, stop, amount: Double): Double;
function Normalize(value, start, stop: Double): Double;
function Map(value, inStart, inStop, outStart, outStop: Double): Double;
function Clamp(value, minVal, maxVal: Double): Double;

function Max(a, b: Double): Double;
function Min(a, b: Double): Double;
function MaxI(a, b: Integer): Integer;
function MinI(a, b: Integer): Integer;
function ClampI(value, minVal, maxVal: Integer): Integer;
function SmoothStep(edge0, edge1, x: Double): Double;
function Approach(current, target, delta: Double): Double;

{ ====== DŹWIĘK ====== }
function  LoadSoundEx(const url: String; voices: Integer = 4; volume: Double = 1.0; looped: Boolean = False): TSoundHandle;
procedure UnloadSoundEx(handle: TSoundHandle);
procedure PlaySoundEx(handle: TSoundHandle); overload;
procedure PlaySoundEx(handle: TSoundHandle; volume: Double); overload;
procedure StopSoundEx(handle: TSoundHandle);
procedure PlaySoundEx(handle: TSoundHandle; volume, pitch, pan: Double); overload;
procedure SetSoundVolume(handle: TSoundHandle; volume: Double);
procedure SetSoundLoop(handle: TSoundHandle; looped: Boolean);
function PlaySound(const url: String): Boolean;
function PlaySoundLoop(const url: String): Boolean;
procedure StopAllSounds;
function IsSoundFinished(handle: TSoundHandle): Boolean;


{ ====== FABRYKI ====== }
function NewVector(ax, ay: Double): TInputVector;
function Vector2Create(x, y: Double): TInputVector;
function ColorRGBA(ar, ag, ab, aa: Integer): TColor;
function ColorCreate(r, g, b, a: Integer): TColor;
function RectangleCreate(x, y, width, height: Double): TRectangle;
function LineCreate(startX, startY, endX, endY: Double): TLine;
function TriangleCreate(p1x, p1y, p2x, p2y, p3x, p3y: Double): TTriangle;
function ColorFromHex(const hex: String): TColor;
function RandomColor(minBrightness: Integer = 0; maxBrightness: Integer = 255): TColor;
function ColorEquals(const c1, c2: TColor): Boolean;
function ColorFromHSV(h, s, v: Double; a: Integer = 255): TColor;
procedure ColorToHSV(const c: TColor; out h, s, v: Double);

function ColorFromHSL(h, s, l: Double; a: Integer = 255): TColor;
procedure ColorToHSL(const c: TColor; out h, s, l: Double);

function ColorSaturate(const c: TColor; factor: Double): TColor;
function ColorLighten(const c: TColor; factor: Double): TColor; // factor in [-1..1], positive = lighten
function ColorBlend(const c1, c2: TColor; t: Double): TColor;   // t in [0..1]

procedure SetBlendMode(const mode: TBlendMode);

{ ====== WEKTORY ====== }
function Vector2Zero: TInputVector;
function Vector2One: TInputVector;
function Vector2Add(v1, v2: TInputVector): TInputVector;
function Vector2Subtract(v1, v2: TInputVector): TInputVector;
function Vector2Scale(v: TInputVector; scale: Double): TInputVector;
function Vector2Length(v: TInputVector): Double;
function Vector2Normalize(v: TInputVector): TInputVector;
function Vector2Rotate(v: TInputVector; radians: Double): TInputVector;
function Vector2RotateDeg(v: TInputVector; deg: Double): TInputVector;
function Vector2Dot(a, b: TInputVector): Double;
function Vector2Perp(v: TInputVector): TInputVector;
function Vector2Lerp(a, b: TInputVector; t: Double): TInputVector;
function Vector2Distance(v1, v2: TInputVector): Double;
function Vector2Angle(v1, v2: TInputVector): Double;

{ ====== OKNO / PĘTLA ====== }
procedure InitWindow(aWidth, aHeight: Integer; const title: String);
procedure CloseWindow;
procedure SetFPS(fps: Integer);
procedure SetTargetFPS(fps: Integer);
procedure DrawFPS(x, y: Integer; color: TColor);
function WindowShouldClose: Boolean;
procedure SetCloseOnEscape(enable: Boolean);
function GetCloseOnEscape: Boolean;

procedure SetWindowSize(width, height: Integer);
procedure SetWindowTitle(const title: String);
procedure ToggleFullscreen;

{ ====== RYSOWANIE ====== }
procedure BeginDrawing;
procedure EndDrawing;
procedure ClearBackground(const color: TColor);
procedure ClearFast(const rgba: string);
procedure DrawRectangle(x, y, w, h: double; const color: TColor);
procedure DrawRectangleRec(const rec: TRectangle; const color: TColor);
procedure DrawCircle(cx, cy, radius: double; const color: TColor);
procedure DrawCircleV(center: TInputVector; radius: double; const color: TColor);
procedure DrawCircleLines(cx, cy, radius, thickness: double; const color: TColor);

procedure W_BindCanvasEvents;

procedure DrawTextWithFont(const text: String; x, y, size: Integer; const family: String; const color: TColor);
function  MeasureTextWidthWithFont(const text: String; size: Integer; const family: String): Double;
function  MeasureTextHeightWithFont(const text: String; size: Integer; const family: String): Double;
procedure DrawText(const text: String; x, y, size: Integer; const color: TColor);
function  MeasureTextWidth(const text: String; size: Integer): Double;
function  MeasureTextHeight(const text: String; size: Integer): Double;
procedure SetTextFont(const cssFont: String);
procedure SetTextAlign(const hAlign: String; const vAlign: String);
procedure DrawTextCentered(const text: String; cx, cy, size: Integer; const color: TColor);
procedure DrawTextPro(const text: String; x, y, size: Integer; const color: TColor;
                     rotation: Double; originX, originY: Double);
procedure ApplyFont;
function BuildFontString(const sizePx: Integer; const family: String = ''): String;
procedure EnsureFont(const sizePx: Integer; const family: String = ''); 
procedure SetFontSize(const sizePx: Integer); 
procedure SetFontFamily(const family: String);    

// --- Canvas helpers ---
procedure CanvasSave;
procedure CanvasRestore;
procedure CanvasSetGlobalAlpha(const A: Double);
procedure CanvasSetFillColor(const C: TColor);
procedure CanvasSetShadow(const C: TColor; const Blur: Double);
procedure CanvasClearShadow;
procedure CanvasFillCircle(const X, Y, Radius: Double);
procedure CanvasFillDisc(const X, Y, Radius: Double; const Alpha: Double;
                         const Fill, Shadow: TColor; const ShadowBlur: Double);
type
  TCanvasStateGuard = record end;

procedure BeginCanvasState(out Guard: TCanvasStateGuard);
procedure EndCanvasState(var Guard: TCanvasStateGuard);


function WilgaInitContextFromCanvas(const Canvas: TJSHTMLCanvasElement): TJSCanvasRenderingContext2D;
procedure WilgaResize(Canvas: TJSHTMLCanvasElement; CSSW, CSSH: Integer; DPR: Double);

//fixmouse
procedure W_InitInput;

procedure Translate(const x, y: Double);
procedure Rotate(const rad: Double);
procedure Scale(const sx, sy: Double); 
procedure SetTransform(const a, b, c, d, e, f: Double);
procedure Transform(const a, b, c, d, e, f: Double); // opcjonalnie, ale przydatne
procedure ResetTransform;         
// === Tekstury ===

// Rysowanie z pozycją, skalą, rotacją i tintem
procedure DrawTextureEx(const tex: TTexture; position: TVector2; scale: Double; rotation: Double; const tint: TColor);

// Rysowanie wycinka tekstury (source rectangle)
procedure DrawTextureRec(const tex: TTexture; const src: TRectangle; position: TVector2; const tint: TColor);

// Rysowanie powtarzającej się tekstury na obszarze (tiling)
procedure DrawTextureTiled(const tex: TTexture; const src, dst: TRectangle; origin: TVector2; rotation: Double; scale: Double; const tint: TColor);

// Rysowanie z originem w proporcjach (0..1)
procedure DrawTextureProRelOrigin(const tex: TTexture; const src, dst: TRectangle; originRel: TVector2; rotation: Double; const tint: TColor);

// Rysowanie ramki z atlasu po indeksie
procedure DrawAtlasFrame(const tex: TTexture; frameIndex, frameWidth, frameHeight: Integer; position: TVector2; const tint: TColor);


// === Tekst ===

// Proste rysowanie tekstu w punkcie
procedure DrawTextSimple(const text: String; pos: TVector2; fontSize: Integer; const color: TColor);

// Rysowanie tekstu wyśrodkowanego względem punktu
procedure DrawTextCentered(const text: String; center: TVector2; fontSize: Integer; const color: TColor);

// Rysowanie tekstu wyrównanego do prawej
procedure DrawTextRightAligned(const text: String; rightPos: TVector2; fontSize: Integer; const color: TColor);

// Tekst z cieniem
procedure DrawTextShadow(const text: String; pos: TVector2; fontSize: Integer; const color, shadowColor: TColor; shadowOffset: TVector2);

// Tekst w ramce (word wrap)
procedure DrawTextBoxed(const text: String; pos: TVector2; boxWidth: Integer;
  fontSize: Integer; const textColor: TColor; lineSpacing: Integer;
  const borderColor: TColor; borderThickness: Integer);
  procedure DrawTextBoxed(const text: String; pos: TVector2; boxWidth: Integer;
  fontSize: Integer; const textColor: TColor; lineSpacing: Integer;
  const borderColor: TColor; borderThickness: Integer;
  padTopAdjust: Integer; padBottomAdjust: Integer); overload;
// Tekst na okręgu
procedure DrawTextOnCircle(const text: String; center: TVector2; radius: Double; startAngle: Double; fontSize: Integer; const color: TColor);

// Tekst z gradientem (prosty poziomy)
procedure DrawTextGradient(const text: String; pos: TVector2; fontSize: Integer; const color1, color2: TColor);

procedure DrawTextOutlineAdv(const text: String; pos: TVector2; fontSize: Integer; const color, outlineColor: TColor; thickness: Integer);
// --- Wielokąty / polilinie ---
procedure DrawPolyline(const pts: array of TInputVector; const color: TColor; thickness: Integer = 1; closed: Boolean = False);
procedure DrawPolygon(const pts: array of TInputVector; const color: TColor; filled: Boolean = True);

// --- Łuki / wycinki ---
procedure DrawArc(cx, cy, r: Double; startDeg, endDeg: Double; const color: TColor; thickness: Integer = 1);
procedure DrawRing(cx, cy, rInner, rOuter, startDeg, endDeg: Double; const color: TColor);
procedure DrawSector(cx, cy, r: Double; startDeg, endDeg: Double; const color: TColor);

// --- Linie kreskowane ---
procedure DrawDashedLine(x1, y1, x2, y2: Double; const color: TColor; thickness: Integer; dashLen, gapLen: Double);
procedure DrawDashedTriangle(const tri: TTriangle; const color: TColor;
thickness: Integer = 1; dashLen: Double = 8.0; gapLen: Double = 6.0);
procedure DrawDashedPolyline(const pts: array of TInputVector; const color: TColor;
  thickness: Integer = 1; dashLen: Double = 8.0; gapLen: Double = 6.0);

procedure DrawDashedCircle(cx, cy, radius: Double; const color: TColor;
thickness: Integer = 1; dashLen: Double = 8.0; gapLen: Double = 6.0; segments: Integer = 120);
procedure DrawDashedCircleV(center: TInputVector; radius: Double; const color: TColor;
thickness: Integer = 1; dashLen: Double = 8.0; gapLen: Double = 6.0; segments: Integer = 120);


procedure DrawDashedEllipse(cx, cy, rx, ry: Double; const color: TColor;
thickness: Integer = 1; dashLen: Double = 8.0; gapLen: Double = 6.0; segments: Integer = 120);
procedure DrawDashedEllipseV(center: TInputVector; radiusX, radiusY: Double; const color: TColor;
thickness: Integer = 1; dashLen: Double = 8.0; gapLen: Double = 6.0; segments: Integer = 120);
procedure SetLineDash(const dashes: array of Double);
procedure ClearLineDash;

// --- Gradient prostokątny ---
procedure FillRectLinearGradient(const rec: TRectangle; const c0, c1: TColor; angleDeg: Double);

// --- Tekst z obrysem ---
procedure DrawTextOutline(const text: String; x, y, size: Integer; const fillColor, outlineColor: TColor; outlinePx: Integer);

// --- Clip dowolnym path ---
procedure BeginPathClip(const BuildPath: TNoArgProc);
procedure EndClip;
procedure DrawRectangleProDeg(const rec: TRectangle; origin: TVector2; rotationDeg: Double; const color: TColor);
procedure DrawPolyDeg(center: TVector2; sides: Integer; radius: Double; rotationDeg: Double; const color: TColor);
procedure DrawRectanglePro(const rec: TRectangle; origin: TVector2; rotation: Double; const color: TColor);
procedure DrawPoly(center: TVector2; sides: Integer; radius: Double; rotation: Double; const color: TColor);
procedure DrawCircleGradient(cx, cy: Integer; radius: Integer; const inner, outer: TColor);
procedure DrawEllipse(cx, cy, rx, ry: Integer; const color: TColor);
procedure DrawEllipseLines(cx, cy, rx, ry, thickness: Integer; const color: TColor);
procedure DrawEllipseV(center: TInputVector; radiusX, radiusY: Double; const color: TColor);
function RectangleFromCenter(cx, cy, w, h: Double): TRectangle;
function RectCenter(const R: TRectangle): TVector2;
{ ====== TEKSTURY ====== }
function LoadRenderTexture(w, h: Integer): TRenderTexture2D;
procedure BeginTextureMode(const rt: TRenderTexture2D);
procedure EndTextureMode;
function CreateTextureFromCanvas(canvas: TJSHTMLCanvasElement): TTexture;
procedure ReleaseTexture(var tex: TTexture);
procedure ReleaseRenderTexture(var rtex: TRenderTexture2D);

{ ====== WEJŚCIE ====== }
function IsKeyPressed(const code: String): Boolean; overload;
function IsKeyPressed(keyCode: Integer): Boolean; overload;
function IsKeyDown(const code: String): Boolean; overload;
function IsKeyDown(keyCode: Integer): Boolean; overload;
function IsKeyReleased(const code: String): Boolean; overload;
function IsKeyReleased(keyCode: Integer): Boolean; overload;
function GetKeyPressed: String;
function GetCharPressed: String;
function GetAllPressedKeys: Array of String; // Zamiast: array of String
procedure ClearAllKeys;
function KeyCodeToCode(keyCode: Integer): String;

{ ====== PROFILER ====== }
procedure BeginProfile(const name: String);
procedure EndProfile(const name: String);
function GetProfileData: String;
procedure ResetProfileData;

{ ====== PARTICLE SYSTEM ====== }
function CreateParticleSystem(maxParticles: Integer): TParticleSystem;
procedure DrawParticles(particleSystem: TParticleSystem);
procedure UpdateParticles(particleSystem: TParticleSystem; dt: Double);

{ ====== LOOP ====== }
procedure Run(UpdateProc: TDeltaProc);
procedure Run(UpdateProc: TDeltaProc; DrawProc: TDeltaProc);


// push pop
procedure Push; inline;
procedure Pop;  inline;


{ ====== KOLORY ====== }
{ ====== Deklaracje kolorów ====== }
function COLOR_ALICEBLUE: TColor;
function COLOR_ANTIQUEWHITE: TColor;
function COLOR_AQUA: TColor;
function COLOR_AQUAMARINE: TColor;
function COLOR_AZURE: TColor;
function COLOR_BEIGE: TColor;
function COLOR_BISQUE: TColor;
function COLOR_BLACK: TColor;
function COLOR_BLANCHEDALMOND: TColor;
function COLOR_BLUE: TColor;
function COLOR_BLUEVIOLET: TColor;
function COLOR_BROWN: TColor;
function COLOR_BURLYWOOD: TColor;
function COLOR_CADETBLUE: TColor;
function COLOR_CHARTREUSE: TColor;
function COLOR_CHOCOLATE: TColor;
function COLOR_CORAL: TColor;
function COLOR_CORNFLOWERBLUE: TColor;
function COLOR_CORNSILK: TColor;
function COLOR_CRIMSON: TColor;
function COLOR_CYAN: TColor;
function COLOR_DARKBLUE: TColor;
function COLOR_DARKCYAN: TColor;
function COLOR_DARKGOLDENROD: TColor;
function COLOR_DARKGRAY: TColor;
function COLOR_DARKGREY: TColor;
function COLOR_DARKGREEN: TColor;
function COLOR_DARKKHAKI: TColor;
function COLOR_DARKMAGENTA: TColor;
function COLOR_DARKOLIVEGREEN: TColor;
function COLOR_DARKORANGE: TColor;
function COLOR_DARKORCHID: TColor;
function COLOR_DARKRED: TColor;
function COLOR_DARKSALMON: TColor;
function COLOR_DARKSEAGREEN: TColor;
function COLOR_DARKSLATEBLUE: TColor;
function COLOR_DARKSLATEGRAY: TColor;
function COLOR_DARKSLATEGREY: TColor;
function COLOR_DARKTURQUOISE: TColor;
function COLOR_DARKVIOLET: TColor;
function COLOR_DEEPPINK: TColor;
function COLOR_DEEPSKYBLUE: TColor;
function COLOR_DIMGRAY: TColor;
function COLOR_DIMGREY: TColor;
function COLOR_DODGERBLUE: TColor;
function COLOR_FIREBRICK: TColor;
function COLOR_FLORALWHITE: TColor;
function COLOR_FORESTGREEN: TColor;
function COLOR_FUCHSIA: TColor;
function COLOR_GAINSBORO: TColor;
function COLOR_GHOSTWHITE: TColor;
function COLOR_GOLD: TColor;
function COLOR_GOLDENROD: TColor;
function COLOR_GRAY: TColor;
function COLOR_GREY: TColor;
function COLOR_GREEN: TColor;
function COLOR_GREENYELLOW: TColor;
function COLOR_HONEYDEW: TColor;
function COLOR_HOTPINK: TColor;
function COLOR_INDIANRED: TColor;
function COLOR_INDIGO: TColor;
function COLOR_IVORY: TColor;
function COLOR_KHAKI: TColor;
function COLOR_LAVENDER: TColor;
function COLOR_LAVENDERBLUSH: TColor;
function COLOR_LAWNGREEN: TColor;
function COLOR_LEMONCHIFFON: TColor;
function COLOR_LIGHTBLUE: TColor;
function COLOR_LIGHTCORAL: TColor;
function COLOR_LIGHTCYAN: TColor;
function COLOR_LIGHTGOLDENRODYELLOW: TColor;
function COLOR_LIGHTGRAY: TColor;
function COLOR_LIGHTGREY: TColor;
function COLOR_LIGHTGREEN: TColor;
function COLOR_LIGHTPINK: TColor;
function COLOR_LIGHTSALMON: TColor;
function COLOR_LIGHTSEAGREEN: TColor;
function COLOR_LIGHTSKYBLUE: TColor;
function COLOR_LIGHTSLATEGRAY: TColor;
function COLOR_LIGHTSLATEGREY: TColor;
function COLOR_LIGHTSTEELBLUE: TColor;
function COLOR_LIGHTYELLOW: TColor;
function COLOR_LIME: TColor;
function COLOR_LIMEGREEN: TColor;
function COLOR_LINEN: TColor;
function COLOR_MAGENTA: TColor;
function COLOR_MAROON: TColor;
function COLOR_MEDIUMAQUAMARINE: TColor;
function COLOR_MEDIUMBLUE: TColor;
function COLOR_MEDIUMORCHID: TColor;
function COLOR_MEDIUMPURPLE: TColor;
function COLOR_MEDIUMSEAGREEN: TColor;
function COLOR_MEDIUMSLATEBLUE: TColor;
function COLOR_MEDIUMSPRINGGREEN: TColor;
function COLOR_MEDIUMTURQUOISE: TColor;
function COLOR_MEDIUMVIOLETRED: TColor;
function COLOR_MIDNIGHTBLUE: TColor;
function COLOR_MINTCREAM: TColor;
function COLOR_MISTYROSE: TColor;
function COLOR_MOCCASIN: TColor;
function COLOR_NAVAJOWHITE: TColor;
function COLOR_NAVY: TColor;
function COLOR_OLDLACE: TColor;
function COLOR_OLIVE: TColor;
function COLOR_OLIVEDRAB: TColor;
function COLOR_ORANGE: TColor;
function COLOR_ORANGERED: TColor;
function COLOR_ORCHID: TColor;
function COLOR_PALEGOLDENROD: TColor;
function COLOR_PALEGREEN: TColor;
function COLOR_PALETURQUOISE: TColor;
function COLOR_PALEVIOLETRED: TColor;
function COLOR_PAPAYAWHIP: TColor;
function COLOR_PEACHPUFF: TColor;
function COLOR_PERU: TColor;
function COLOR_PINK: TColor;
function COLOR_PLUM: TColor;
function COLOR_POWDERBLUE: TColor;
function COLOR_PURPLE: TColor;
function COLOR_REBECCAPURPLE: TColor;
function COLOR_RED: TColor;
function COLOR_ROSYBROWN: TColor;
function COLOR_ROYALBLUE: TColor;
function COLOR_SADDLEBROWN: TColor;
function COLOR_SALMON: TColor;
function COLOR_SANDYBROWN: TColor;
function COLOR_SEAGREEN: TColor;
function COLOR_SEASHELL: TColor;
function COLOR_SIENNA: TColor;
function COLOR_SILVER: TColor;
function COLOR_SKYBLUE: TColor;
function COLOR_SLATEBLUE: TColor;
function COLOR_SLATEGRAY: TColor;
function COLOR_SLATEGREY: TColor;
function COLOR_SNOW: TColor;
function COLOR_SPRINGGREEN: TColor;
function COLOR_STEELBLUE: TColor;
function COLOR_TAN: TColor;
function COLOR_TEAL: TColor;
function COLOR_THISTLE: TColor;
function COLOR_TOMATO: TColor;
function COLOR_TURQUOISE: TColor;
function COLOR_VIOLET: TColor;
function COLOR_WHEAT: TColor;
function COLOR_WHITE: TColor;
function COLOR_WHITESMOKE: TColor;
function COLOR_YELLOW: TColor;
function COLOR_YELLOWGREEN: TColor;
function COLOR_TRANSPARENT : TColor;


  {$ifdef WILGA_DEBUG}
function DumpLeakReport: String;
procedure DebugResetCounters;
{$endif}

// --- deklaracje (w interface) ---
procedure WaitTextureReady(const tex: TTexture; const OnReady, OnTimeout: TNoArgProc; msTimeout: Integer = 10000);
procedure WaitAllTexturesReady(const arr: array of TTexture; const OnReady: TNoArgProc);

const
  KEY_SPACE  = 'Space';       //ważna jest wielkość liter przy stringach(!!!)
  KEY_ESCAPE = 'Escape';
  KEY_ENTER  = 'Enter';
  KEY_TAB    = 'Tab';
  KEY_LEFT   = 'ArrowLeft';
  KEY_RIGHT  = 'ArrowRight';
  KEY_UP     = 'ArrowUp';
  KEY_DOWN   = 'ArrowDown';
  KEY_SHIFT  = 'ShiftLeft';
  KEY_BACKSPACE = 'Backspace';
  KEY_DELETE    = 'Delete';
  KEY_INSERT    = 'Insert';
  KEY_HOME      = 'Home';
  KEY_END       = 'End';
  KEY_PAGEUP    = 'PageUp';
  KEY_PAGEDOWN  = 'PageDown';
  KEY_F1        = 'F1';
  KEY_F2        = 'F2';
  KEY_F3        = 'F3';
  KEY_F4        = 'F4';
  KEY_F5        = 'F5';
  KEY_F6        = 'F6';
  KEY_F7        = 'F7';
  KEY_F8        = 'F8';
  KEY_F9        = 'F9';
  KEY_F10       = 'F10';
  KEY_F11       = 'F11';
  KEY_F12       = 'F12';
  KEY_CONTROL   = 'ControlLeft';
  KEY_ALT       = 'AltLeft';
  KEY_META      = 'MetaLeft';
  KEY_CONTEXT   = 'ContextMenu';
  KEY_BACKQUOTE   = 'Backquote';
  KEY_MINUS       = 'Minus';
  KEY_EQUAL       = 'Equal';
  KEY_BRACKETLEFT = 'BracketLeft';
  KEY_BRACKETRIGHT= 'BracketRight';
  KEY_BACKSLASH   = 'Backslash';
  KEY_SEMICOLON   = 'Semicolon';
  KEY_QUOTE       = 'Quote';
  KEY_COMMA       = 'Comma';
  KEY_PERIOD      = 'Period';
  KEY_SLASH       = 'Slash';
    KEY_CONTROL_LEFT  = 'ControlLeft';
  KEY_CONTROL_RIGHT = 'ControlRight';
  KEY_SHIFT_LEFT    = 'ShiftLeft';
  KEY_SHIFT_RIGHT   = 'ShiftRight';
  KEY_ALT_LEFT      = 'AltLeft';
  KEY_ALT_RIGHT     = 'AltRight';
  KEY_META_LEFT     = 'MetaLeft';
  KEY_META_RIGHT    = 'MetaRight';
  KEY_CAPSLOCK   = 'CapsLock';
KEY_NUMLOCK    = 'NumLock';
KEY_SCROLLLOCK = 'ScrollLock';
KEY_PRINTSCREEN= 'PrintScreen';
KEY_PAUSE      = 'Pause';


  // Litery A..Z
  KEY_A = 'KeyA';
  KEY_B = 'KeyB';
  KEY_C = 'KeyC';
  KEY_D = 'KeyD';
  KEY_E = 'KeyE';
  KEY_F = 'KeyF';
  KEY_G = 'KeyG';
  KEY_H = 'KeyH';
  KEY_I = 'KeyI';
  KEY_J = 'KeyJ';
  KEY_K = 'KeyK';
  KEY_L = 'KeyL';
  KEY_M = 'KeyM';
  KEY_N = 'KeyN';
  KEY_O = 'KeyO';
  KEY_P = 'KeyP';
  KEY_Q = 'KeyQ';
  KEY_R = 'KeyR';
  KEY_S = 'KeyS';
  KEY_T = 'KeyT';
  KEY_U = 'KeyU';
  KEY_V = 'KeyV';
  KEY_W = 'KeyW';
  KEY_X = 'KeyX';
  KEY_Y = 'KeyY';
  KEY_Z = 'KeyZ';

  // Górny rząd cyfr 0..9
  KEY_0 = 'Digit0';
  KEY_1 = 'Digit1';
  KEY_2 = 'Digit2';
  KEY_3 = 'Digit3';
  KEY_4 = 'Digit4';
  KEY_5 = 'Digit5';
  KEY_6 = 'Digit6';
  KEY_7 = 'Digit7';
  KEY_8 = 'Digit8';
  KEY_9 = 'Digit9';

  // Numpad
  KEY_NUMPAD0     = 'Numpad0';
  KEY_NUMPAD1     = 'Numpad1';
  KEY_NUMPAD2     = 'Numpad2';
  KEY_NUMPAD3     = 'Numpad3';
  KEY_NUMPAD4     = 'Numpad4';
  KEY_NUMPAD5     = 'Numpad5';
  KEY_NUMPAD6     = 'Numpad6';
  KEY_NUMPAD7     = 'Numpad7';
  KEY_NUMPAD8     = 'Numpad8';
  KEY_NUMPAD9     = 'Numpad9';
  KEY_NUMPAD_ADD      = 'NumpadAdd';
  KEY_NUMPAD_SUBTRACT = 'NumpadSubtract';
  KEY_NUMPAD_MULTIPLY = 'NumpadMultiply';
  KEY_NUMPAD_DIVIDE   = 'NumpadDivide';
  KEY_NUMPAD_DECIMAL  = 'NumpadDecimal';
  
  //randomy




// === DODAJ TO W INTERFACE (poza rekordem) ===
function TRectangleCreate(x, y, w, h: Double): TRectangle; inline;

// === Convenience Vector Helpers (ergonomia) ===
function Vec(x, y: Double): TInputVector; inline;
function VecZero: TInputVector; inline;
function VecOne: TInputVector; inline;
procedure Deconstruct(const v: TInputVector; out x, y: Double); inline;
function VecPerp(const v: TInputVector): TInputVector; inline;
function VecDot(const a, b: TInputVector): Double; inline;
function VecClampLength(const v: TInputVector; maxLen: Double): TInputVector; inline;

procedure VecAddInPlace(var a: TInputVector; const b: TInputVector); inline;
procedure VecScaleInPlace(var a: TInputVector; const s: Double); inline;
procedure VecNormalizeInPlace(var a: TInputVector); inline;

procedure PolyTranslateInPlace(var poly: array of TInputVector; const d: TInputVector);
procedure PolyScaleInPlace(var poly: array of TInputVector; const s: Double);
procedure PolyRotateInPlace(var poly: array of TInputVector; angleRad: Double);

implementation

uses
  wilga_tint_cache;

var
  GMousePrevPressed: array[0..2] of Boolean;
  GMousePrevReleased: array[0..2] of Boolean;

  gAudioCtx    : TJSAudioContext = nil;
  gMasterGain  : TJSGainNode     = nil;
  gActiveSounds: array of TSoundInstance;
  gSoundPools  : array of TSoundPool;
  // unikalny klucz dla tekstur (do TintCache, gdy texId=0 lub niestabilny)
  gTexKeyCounter: LongWord = 1;
// NOWA WERSJA – z pitch i pan
procedure WSetDash(dashLen, gapLen: Double); inline;
var arr: TJSArray;
begin
  arr := TJSArray.new;
  arr.push(dashLen);
  arr.push(gapLen);
  gCtx.setLineDash(arr);
end;

procedure WClearDash; inline;
begin
  gCtx.setLineDash(TJSArray.new); // pusta tablica
end;
procedure Transform(const a, b, c, d, e, f: Double);
begin
  gCtx.transform(a, b, c, d, e, f);
end;

procedure Translate(const x, y: Double);
begin
  gCtx.translate(x, y);
end;

procedure Rotate(const rad: Double);
begin
  gCtx.rotate(rad);
end;

procedure Scale(const sx, sy: Double);
begin
  gCtx.scale(sx, sy);
end;
procedure TMatrix2D.ApplyToContext;
begin
  gCtx.setTransform(m0, m3, m1, m4, m2, m5);
end;
procedure SetTransform(const a, b, c, d, e, f: Double);
var
  M: TMatrix2D;
begin
  // mapowanie zgodne z ApplyToContext:
  // gCtx.setTransform(m0, m3, m1, m4, m2, m5)

  M.m0 := a;
  M.m3 := b;

  M.m1 := c;
  M.m4 := d;

  M.m2 := e;
  M.m5 := f;

  M.ApplyToContext;
end;
procedure ResetTransform;
begin
  if gCtx = nil then Exit;
  SetTransform(1, 0, 0, 1, 0, 0);
end;




function CreateInstanceFromBuffer(const buf: TJSAudioBuffer;
  volume, pitch, pan: Double; looped: Boolean): TSoundInstance; overload;
var
  src    : TJSAudioBufferSourceNode;
  gain   : TJSGainNode;
  panNode: TJSStereoPannerNode;
  inst   : TSoundInstance;
begin
  InitAudio;
  ResumeAudioIfNeeded;

  // volume [0..1]
  if volume < 0 then volume := 0
  else if volume > 1 then volume := 1;

  // pitch > 0 (1.0 = normalnie)
  if pitch <= 0 then pitch := 1.0;

  // pan [-1..1] (−1 = pełne lewo, 0 = środek, 1 = prawo)
  if pan < -1.0 then pan := -1.0
  else if pan > 1.0 then pan := 1.0;

  src := gAudioCtx.createBufferSource;
  src.buffer := buf;
  src.loop   := looped;
  src.playbackRate.value := pitch;

  gain := gAudioCtx.createGain;
  gain.gain.value := volume;

  panNode := nil;
  try
    panNode := TJSStereoPannerNode(gAudioCtx.createStereoPanner);
  except
    panNode := nil; // przeglądarka nie wspiera → gramy bez panoramy
  end;

  if panNode <> nil then
  begin
    panNode.pan.value := pan;
    src.connect(panNode);
    panNode.connect(gain);
  end
  else
  begin
    src.connect(gain);
  end;

  gain.connect(gMasterGain);

  inst := TSoundInstance.Create;
  inst.source  := src;
  inst.gain    := gain;
  inst.panner  := panNode;
  inst.looped  := looped;
  inst.playing := True;

  asm
    src.onended = function(e) {
      inst.playing = false;
    };
  end;

  {$ifdef WILGA_DEBUG} DBG_Inc(dbg_AudioElemsAlive); {$endif}
  SetLength(gActiveSounds, Length(gActiveSounds)+1);
  gActiveSounds[High(gActiveSounds)] := inst;

  StartSource(src, 0);

  Result := inst;
end;

// STARA SYGNATURA – zachowana dla kompatybilności
function CreateInstanceFromBuffer(const buf: TJSAudioBuffer;
  volume: Double; looped: Boolean): TSoundInstance; overload;
begin
  // domyślnie: normalny pitch, środek panoramy
  Result := CreateInstanceFromBuffer(buf, volume, 1.0, 0.0, looped);
end;

function IsSoundFinished(handle: TSoundHandle): Boolean;
var
  p  : ^TSoundPool;
  i  : Integer;
  buf: TJSAudioBuffer;
begin
  // Jeśli handle jest spoza zakresu — traktujemy jako "skończony"
  if (handle < 0) or (handle > High(gSoundPools)) then
    Exit(True);

  p := @gSoundPools[handle];

  // Jeśli jeszcze niezaładowany albo brak bufora – też uznajemy za skończony
  if (not p^.valid) or (p^.buffer = nil) then
    Exit(True);

  // Jeśli dźwięk jest loopowany (np. muzyka):
  // patrzymy na aktywną pętlę
  if p^.looped then
  begin
    if (p^.activeLoop <> nil) and p^.activeLoop.playing then
      Exit(False) // wciąż gra
    else
      Exit(True); // nie ma aktywnej pętli albo nie gra
  end;

  // Dla zwykłych jednorazowych efektów:
  // szukamy w gActiveSounds instancji, która używa tego samego buffer
  buf := p^.buffer;

  for i := 0 to High(gActiveSounds) do
    if (gActiveSounds[i] <> nil) and
       gActiveSounds[i].playing and
       (gActiveSounds[i].source <> nil) and
       (gActiveSounds[i].source.buffer = buf) then
    begin
      // Znaleźliśmy grającą instancję dla tego sounda
      Exit(False);
    end;

  // Nie znaleźliśmy grającej instancji → dźwięk skończony
  Result := True;
end;

procedure StartSource(src: TJSAudioBufferSourceNode; when: Double);
begin
  asm src.start(when); end;
end;

procedure StopSource(src: TJSAudioBufferSourceNode; when: Double);
begin
  asm src.stop(when); end;
end;
procedure TSoundInstance.Stop;
var
  t: Double;
begin
  if not playing then Exit;
  playing := False;

  // t = "teraz" w AudioContext
  t := 0;
  try
    if gAudioCtx <> nil then
      t := gAudioCtx.currentTime;
  except
  end;

  // 1) NATYCHMIAST wycisz instancję
  try
    if gain <> nil then
      gain.gain.setValueAtTime(0, t);
  except
    try
      if gain <> nil then gain.gain.value := 0;
    except
    end;
  end;

  // 2) NATYCHMIAST zatrzymaj źródło (ważne: currentTime, nie 0)
  try
    if source <> nil then
     StopSource(source, t + 0.001);

  except
    try
      if source <> nil then source.stop(t);
    except
    end;
  end;

  // 3) Odłącz graf (żeby nic nie "przeciekało")
  try if source <> nil then source.disconnect; except end;
  try if panner <> nil then panner.disconnect; except end;
  try if gain <> nil then gain.disconnect; except end;
end;


procedure InitAudio;
begin
  if gAudioCtx <> nil then Exit;

  gAudioCtx := TJSAudioContext.new;
  gMasterGain := gAudioCtx.createGain;
  gMasterGain.connect(gAudioCtx.destination);
  gMasterGain.gain.value := 1.0;
end;


procedure ResumeAudioIfNeeded;
begin
  if (gAudioCtx <> nil) and (gAudioCtx.state = 'suspended') then
    gAudioCtx.resume();
end;

const
  W_WATCHDOG_TIMEOUT_MS = 60000; // 2.5 sekundy – możesz zwiększyć jeśli chcesz
{$IFDEF WILGA_LEAK_GUARD}


var

  GSaveDepth: Integer = 0;
  GFrameDepth  : Integer = 0; // prywatny poziom ramki
{$ENDIF}
{$IFDEF WILGA_LEAK_GUARD}


  // watchdog
  W_DownTimeMS     : array[0..2] of TTimeMS;
  W_InputInited: Boolean = False;
  W_ListenersAttached: Boolean = False;




function _NowMS_Native: NativeUInt;
begin
  asm
    var t = (window.performance && performance.now) ? performance.now() : Date.now();
    return Math.floor(t);
  end;
end;

function _NowMS: TTimeMS; inline;
begin
  Result := TTimeMS(Round(GetTime * 1000.0));
end;

procedure W_EnsureInputInit;
begin
  if not W_InputInited then
  begin
    W_InitInput;
    W_InputInited := True;
  end;
end;
procedure W_EH_PointerDown(e: TJSEvent);
var
  btn: Integer;
  t  : TTimeMS;
  xx, yy: Integer;
begin
  asm
    var ev = e;
    var b = (typeof ev.button === 'number') ? ev.button : -1;
    if (b < 0 || b > 2) {
      var m = ev.buttons|0;
      if      (m & 1) b = 0;
      else if (m & 4) b = 1;
      else if (m & 2) b = 2;
      else            b = -1;
    }
    btn = b|0;

    var c  = (window.Module && Module.canvas) || document.getElementById('game');
    if (c) {
      var r  = c.getBoundingClientRect();
      xx = Math.round((ev.clientX - r.left) * (c.width  / r.width))|0;
      yy = Math.round((ev.clientY - r.top)  * (c.height / r.height))|0;
    } else { xx = 0; yy = 0; }
  end;
  if (btn < 0) or (btn > 2) then Exit;

  t := _NowMS;
  W_LastEventTimeMS := t;

  if not W_CurrDown[btn] then
  begin
    W_CurrDown[btn]       := True;
    W_DownTimeMS[btn]     := t;
    W_PressedNext[btn]    := True;
    W_PressedUntilMS[btn] := t + W_PRESSED_HOLD_MS; // HOLD krawędzi
    Inc(W_DBG_WilgaDown);
  end;

  // zapis latsa pozycji (spójność Pressed + pozycja)
  W_MouseLatchX       := xx;
  W_MouseLatchY       := yy;
  W_MouseLatchUntilMS := t + W_PRESSED_HOLD_MS;

  // uaktualnij bieżącą pozycję
  W_OnPointerMove(xx, yy);
end;


procedure W_EH_PointerUp(e: TJSEvent);
var
  btn: Integer;
  xx, yy: Integer;
  msk: Integer;

  procedure ReleaseBtn(b: Integer);
  begin
    if (b >= 0) and (b <= 2) and W_CurrDown[b] then
    begin
      W_CurrDown[b]     := False;
      W_ReleasedNext[b] := True;   // krawędź Released
      Inc(W_DBG_WilgaUp);
    end;
  end;

begin
  asm
    var ev = e;
    var b = (typeof ev.button === 'number') ? ev.button : -1;
    if (b < 0 || b > 2) {
      var m = ev.buttons|0;
      if      (m & 1) b = 0;
      else if (m & 4) b = 1;
      else if (m & 2) b = 2;
      else            b = -1;
    }
    btn = b|0;

    var c  = (window.Module && Module.canvas) || document.getElementById('game');
    if (c) {
      var r  = c.getBoundingClientRect();
      xx = Math.round((ev.clientX - r.left) * (c.width  / r.width))|0;
      yy = Math.round((ev.clientY - r.top)  * (c.height / r.height))|0;
    } else { xx = 0; yy = 0; }
    msk = (ev.buttons|0)|0;
  end;

  W_OnPointerMove(xx, yy);  // świeża pozycja na końcu gestu

  // puść konkretny przycisk
  ReleaseBtn(btn);
  // i upewnij się, że maska nie trzyma duchów
  if (msk and 1) = 0 then ReleaseBtn(0);
  if (msk and 4) = 0 then ReleaseBtn(1);
  if (msk and 2) = 0 then ReleaseBtn(2);

  // NIE kasuj latcha – pozwól mu „dożyć” do końca okna hold
end;





function W_EH_PointerCancel(e: TJSEvent): JSValue;
var pe: TJSPointerEvent; b: Integer;
begin
  pe := TJSPointerEvent(e);
  b := pe.button;
  if (b >= 0) and (b <= 2) then
    W_CurrDown[b] := False;
  Result := nil;
end;

function W_EH_ContextMenu(e: TJSEvent): JSValue;
begin
  e.preventDefault; // blokada menu na PPM
  Result := nil;
end;
procedure W_ForceAllUp;
var
  b: Integer;
begin
  for b := 0 to 2 do
  begin
    if W_CurrDown[b] then
    begin
      W_CurrDown[b]       := False;
      W_ReleasedNext[b]   := True;   // gra zobaczy Released(b)
      W_PressedUntilMS[b] := 0;      // przestań „trzymać” krawędź Pressed, jeśli używasz hold
      Inc(W_DBG_WilgaUp);
    end;
  end;
end;

function W_EH_VisibilityChange(e: TJSEvent): JSValue;
var b: Integer;
begin
  // sprzątanie stanów gdy karta traci fokus
  for b := 0 to 2 do
  begin
    W_CurrDown[b] := False;
    W_PrevDown[b] := False;
    W_Pressed[b]  := False;
    W_Released[b] := False;
    W_ClickQ[b]   := 0;
  end;
  Result := nil;
end;

function LineJoinToStr(k: TLineJoinKind): String; inline;
begin
  case k of
    ljMiter: Result := 'miter';
    ljRound: Result := 'round';
  else
    Result := 'bevel';
  end;

end;
// TColor (r,g,b,a: Byte) -> 0xAARRGGBB
function ColorToRGBA32(const C: TColor): Cardinal; inline;
begin
  Result :=
    (Cardinal(C.a) shl 24) or
    (Cardinal(C.r) shl 16) or
    (Cardinal(C.g) shl 8)  or
     Cardinal(C.b);
end;

procedure W_BeginFrame;
begin
  asm
    if (window.__wilgaBeginFrame) window.__wilgaBeginFrame();
  end;
end;

procedure W_EndFrame;
begin
  asm
    if (window.__wilgaSubmitFrame) window.__wilgaSubmitFrame();
  end;
end;

procedure W_InternalRegisterCanvasAsTexture(const cnv: TJSHTMLCanvasElement);
begin
  asm
    (function(c) {
      var worker = window.__wilgaRenderWorker;
      if (!c || typeof createImageBitmap !== "function") return;

      // ★★★ SPRITE ID SEPARATED ★★★
      if (!window.__wilgaSpriteNextTexId)
        window.__wilgaSpriteNextTexId = 1;

      if (!c.__wilgaTexId)
        c.__wilgaTexId = window.__wilgaSpriteNextTexId++;

      var id = c.__wilgaTexId;

      console.log("[main] __RegisterCanvasAsTexture (SPRITE) id=", id, c);

      if (worker) {
        createImageBitmap(c).then(function(bmp) {
          worker.postMessage(
            { type: "registerTexture", id: id, bitmap: bmp },
            [bmp]
          );
        });
      } else {
        if (!window.__wilgaPendingTextures) window.__wilgaPendingTextures = [];
        window.__wilgaPendingTextures.push(c);
      }
    })(cnv);
  end;
end;


procedure W_RegisterHelperCanvas(const cnv: TJSHTMLCanvasElement);
begin
  if cnv = nil then
  begin
    writeln('W_RegisterHelperCanvas: SKIP (cnv=nil)');
    Exit;
  end;

  writeln('W_RegisterHelperCanvas: canvas size = ', cnv.width, 'x', cnv.height);

  W_InternalRegisterCanvasAsTexture(cnv);
end;



procedure W_RegisterTexture(var Tex: TTexture);
var
  jsCanvas: TJSHTMLCanvasElement;
begin
  if (Tex.canvas = nil) or (Tex.width <= 0) or (Tex.height <= 0) then
  begin
    writeln('W_RegisterTexture: SKIP (brak canvasu lub wymiar 0)');
    Exit;
  end;

  writeln('W_RegisterTexture: tex=', Tex.width, 'x', Tex.height);

   jsCanvas := Tex.canvas;

  // wspólna logika rejestrująca canvas jako teksturę
  W_InternalRegisterCanvasAsTexture(jsCanvas);

  // po wywołaniu helpera mamy __wilgaTexId na canvasie – zapisz go w rekordzie
  asm
    Tex.texId = jsCanvas.__wilgaTexId || 0;
  end;
end;



procedure WilgaAddPutImageDataCommand(x, y, width, height: Integer; const Buf: TJSUint8ClampedArray);
var
  c: TJSCanvasRenderingContext2D;
begin
  if (Buf = nil) or (width <= 0) or (height <= 0) then Exit;
  c := gCtx;
  if c = nil then Exit;

  asm
    var ctx = c;
    if (ctx && typeof ctx.__wilgaPutImageData === "function") {
      ctx.__wilgaPutImageData(x, y, width, height, Buf);
    }
  end;
end;

// ====== Batch okręgów (path) ======
procedure BeginCircleBatch(const color: TColor);
begin
  gCtx.beginPath;
  WSetFill(ColorToCanvasRGBA(color));
end;

procedure BatchCircle(cx, cy, radius: Double);
begin
  gCtx.moveTo(cx + radius, cy); // mała optymalizacja, domknięcie
  gCtx.arc(cx, cy, radius, 0, 2 * Pi);
end;

procedure EndCircleBatchFill;
begin
  gCtx.fill;
end;


// ====== Batch obrysów okręgów ======
procedure BeginCircleStrokeBatch(const color: TColor; thickness: Integer = 1);
begin
  gCtx.beginPath;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);
  gCtx.lineWidth := thickness;
end;

procedure BatchCircleStroke(cx, cy, radius: Double);
begin
  gCtx.moveTo(cx + radius, cy);
  gCtx.arc(cx, cy, radius, 0, 2 * Pi);
end;

procedure EndCircleStrokeBatch;
begin
  gCtx.stroke;
end;


function LineCapToStr(k: TLineCapKind): String; inline;
begin
  case k of
    lcButt:   Result := 'butt';
    lcRound:  Result := 'round';
  else
    Result := 'square';
  end;
end;

var
  gTimeAccum: Double = 0.0;
// --- Pixel-snapping kamery ---
gCamActive: Boolean = False;  // czy jesteśmy wewnątrz BeginMode2D/EndMode2D
gCamZoom:   Double  = 1.0;    // bieżący zoom kamery (dla snapowania obiektów)


  // Timing
  gLastTime: Double = 0;
  gLastDt:   Double = 0;
  gStartTime: Double = 0;

  // Canvas / kontekst
  gUseClearFast: Boolean = False;
  gCanvas: TJSHTMLCanvasElement;
  //gCtx: TJSCanvasRenderingContext2D;
  gDPR: Double = 1.0;
  gUseHiDPI: Boolean = false;
  gCanvasAlpha: Boolean = False;
  gImageSmoothingWanted: Boolean = True;
  gAuxCanvas: TJSHTMLCanvasElement = nil;
  gAuxCtx: TJSCanvasRenderingContext2D = nil;

  // Input
  gKeys: TJSObject;
  gKeysPressed: TJSObject;
  gKeyPressedUntil: TJSObject; // DEBUG anti-miss hold window for key edges
  gKeyLastDown: TJSObject;    
  gKeysReleased: TJSObject;// Zamiast: array of String

  gMouseButtonsDown: array[0..2] of Boolean;
  gMouseButtonsPrev: array[0..2] of Boolean;
  gMouseWheelDelta: Integer = 0;
  gMousePos: TInputVector;
  gMousePrevPos: TInputVector;

  // Loop
  gRunning: Boolean = false;
  gCurrentUpdate: TDeltaProc = nil;
  gCurrentDraw: TDeltaProc = nil;

  // Render-target stos
  gCtxStack: array of TJSCanvasRenderingContext2D;
  gCanvasStack: array of TJSHTMLCanvasElement;

  // FPS
  gTargetFPS: Integer = 60;
  gLastFpsTime: Double = 0;
  gFrameCount: Integer = 0;
  gCurrentFps: LongInt = 0;

  // Zamknięcie okna
  gWantsClose: Boolean = false;  

    gCloseOnEscape: Boolean = false; 

  // Batch rendering
  gLineBatchActive: Boolean = False;
  gLineBatch: array of TLineBatchItem;

  // Memory pooling
  gVectorPool: array of TInputVector;
  gMatrixPool: array of TMatrix2D;

  // Profiler
  gProfileStack: array of TProfileEntry;
  gProfileData: TJSObject;

  // Sound
   // Sound



  // Particle systems
  gParticleSystems: array of TParticleSystem;
  

  onKeyDownH: TJSEventHandler;
  onKeyUpH:   TJSEventHandler;

  onMouseMoveH: TJSEventHandler;
  onMouseDownH: TJSEventHandler;
  onMouseUpH:   TJSEventHandler;

  onWheelH: TJSEventHandler;

  onTouchStartH: TJSRawEventHandler;
  onTouchMoveH:  TJSRawEventHandler;
  onTouchEndH:   TJSRawEventHandler;

  onBlurH:  TJSEventHandler;
  onClickH: TJSEventHandler;
  // Offscreen do tintowania tekstur
  gTintCanvas: TJSHTMLCanvasElement;

  
{$ifdef WILGA_DEBUG}
var
  dbg_TexturesAlive: Integer = 0;
  dbg_RenderTexturesAlive: Integer = 0;
  dbg_AudioElemsAlive: Integer = 0;

procedure DBG_Inc(var c: Integer); inline; begin Inc(c); end;
procedure DBG_Dec(var c: Integer); inline; begin if c>0 then Dec(c); end;



procedure DebugResetCounters;
begin
  dbg_TexturesAlive := 0;
  dbg_RenderTexturesAlive := 0;
  dbg_AudioElemsAlive := 0;
end;

function DumpLeakReport: String;
begin
  Result :=
    'Wilga leak report:'#10 +
    Format('  Textures alive: %d'#10, [dbg_TexturesAlive]) +
    Format('  RenderTextures alive: %d'#10, [dbg_RenderTexturesAlive]) +
    Format('  Audio elements alive: %d'#10, [dbg_AudioElemsAlive]);
end;
{$endif}

 //====== IMPLEMENTACJA TInputVector ====== }


{ ====== IMPLEMENTACJA TColor ====== }
function TColor.Lighten(amount: Integer): TColor;
begin
  Result := ColorRGBA(
    MinI(255, r + amount),
    MinI(255, g + amount),
    MinI(255, b + amount),
    a
  );
end;

function TColor.Darken(amount: Integer): TColor;
begin
  Result := ColorRGBA(
    MaxI(0, r - amount),
    MaxI(0, g - amount),
    MaxI(0, b - amount),
    a
  );
end;

function TColor.WithAlpha(newAlpha: Integer): TColor;
begin
  Result := ColorRGBA(r, g, b, newAlpha);
end;

function TColor.Blend(const other: TColor; factor: Double): TColor;
begin
  Result := ColorRGBA(
    Round(Lerp(r, other.r, factor)),
    Round(Lerp(g, other.g, factor)),
    Round(Lerp(b, other.b, factor)),
    Round(Lerp(a, other.a, factor))
  );
end;

{ ====== IMPLEMENTACJA TMatrix2D ====== }
function TMatrix2D.Transform(v: TInputVector): TInputVector;
begin
  Result.x := v.x * m0 + v.y * m1 + m2;
  Result.y := v.x * m3 + v.y * m4 + m5;
end;

function TMatrix2D.Multiply(const b: TMatrix2D): TMatrix2D;
begin
  Result.m0 := m0*b.m0 + m1*b.m3;
  Result.m1 := m0*b.m1 + m1*b.m4;
  Result.m2 := m0*b.m2 + m1*b.m5 + m2;
  Result.m3 := m3*b.m0 + m4*b.m3;
  Result.m4 := m3*b.m1 + m4*b.m4;
  Result.m5 := m3*b.m2 + m4*b.m5 + m5;
end;


function TMatrix2D.Invert: TMatrix2D;
var
  det: Double;
begin
  det := m0 * m4 - m1 * m3;
  if det = 0 then Exit(MatrixIdentity);

  Result.m0 := m4 / det;
  Result.m1 := -m1 / det;
  Result.m2 := (m1 * m5 - m2 * m4) / det;
  Result.m3 := -m3 / det;
  Result.m4 := m0 / det;
  Result.m5 := (m2 * m3 - m0 * m5) / det;
end;

{ ====== IMPLEMENTACJA TCamera2D ====== }
function TCamera2D.GetMatrix: TMatrix2D;
var
  translateToTarget, rotate, scale, translateFromOffset: TMatrix2D;
begin
  translateToTarget := MatrixTranslate(-target.x, -target.y);
  rotate := MatrixRotate(rotation);
  scale := MatrixScale(zoom, zoom);
  translateFromOffset := MatrixTranslate(offset.x, offset.y);

  Result := MatrixMultiply(MatrixMultiply(MatrixMultiply(translateToTarget, rotate), scale), translateFromOffset);
end;

{ ====== IMPLEMENTACJA TRectangle ====== }
function TRectangle.Move(dx, dy: Double): TRectangle;
begin
  Result := RectangleCreate(x + dx, y + dy, width, height);
end;

function TRectangle.Scale(sx, sy: Double): TRectangle;
begin
  Result := RectangleCreate(x, y, width * sx, height * sy);
end;

function TRectangle.Inflate(dx, dy: Double): TRectangle;
begin
  Result := RectangleCreate(x - dx, y - dy, width + 2*dx, height + 2*dy);
end;

function TRectangle.Contains(const point: TInputVector): Boolean;
begin
  Result := (point.x >= x) and (point.x <= x + width) and
            (point.y >= y) and (point.y <= y + height);
end;

function TRectangle.Intersects(const other: TRectangle): Boolean;
begin
  Result := not ((x + width <= other.x) or
                 (other.x + other.width <= x) or
                 (y + height <= other.y) or
                 (other.y + other.height <= y));
end;

function TRectangle.GetCenter: TInputVector;
begin
  Result := NewVector(x + width/2, y + height/2);
end;

{ ====== IMPLEMENTACJA TParticleSystem ====== }
constructor TParticleSystem.Create(maxCount: Integer);
begin
  maxParticles := maxCount;
  SetLength(particles, 0);
end;

procedure TParticleSystem.Emit(pos: TInputVector; count: Integer; 
  const aStartColor, aEndColor: TColor;
  minSize, maxSize, minLife, maxLife: Double);
var
  i: Integer;
  angle, speed, lifeVal: Double;
begin
  for i := 0 to count - 1 do
  begin
    if Length(particles) >= maxParticles then Break;

    SetLength(particles, Length(particles) + 1);
    with particles[High(particles)] do
    begin
      position := pos;
      angle := Random * 2 * Pi;
      speed := 50 + Random * 100;
      velocity := NewVector(Cos(angle) * speed, Sin(angle) * speed);
      startColor := aStartColor;
      endColor := aEndColor;
      color := aStartColor;
      size := minSize + Random * (maxSize - minSize);
      lifeVal := minLife + Random * (maxLife - minLife);
      life := lifeVal;
      initialLife := lifeVal;
      rotation := Random * 2 * Pi;
      angularVelocity := (Random - 0.5) * 4;
    end;
  end;
end;

procedure TParticleSystem.Update(dt: Double);
var
  i: Integer;
  t: Double;
begin
  i := 0;
  while i < Length(particles) do
  begin
    with particles[i] do
    begin
      // było: position := position.Add(velocity.Scale(dt));
      position := Vector2Add(position, Vector2Scale(velocity, dt));

      life := life - dt;
      rotation := rotation + angularVelocity * dt;

      if initialLife > 0 then
      begin
        t := Clamp(life / initialLife, 0.0, 1.0);
        // Interpoluj kolor
        color.r := Round(Lerp(endColor.r, startColor.r, t));
        color.g := Round(Lerp(endColor.g, startColor.g, t));
        color.b := Round(Lerp(endColor.b, startColor.b, t));
        color.a := Round(255 * t);
      end
      else
        color.a := 0;
    end;

    if particles[i].life <= 0 then
    begin
      particles[i] := particles[High(particles)];
      SetLength(particles, Length(particles) - 1);
    end
    else
      Inc(i);
  end;
end;


procedure TParticleSystem.Draw;
var
  i: Integer;
  G: TCanvasStateGuard;
begin
  for i := 0 to High(particles) do
  begin
    with particles[i] do
    begin
      BeginCanvasState(G);
      try
        gCtx.translate(position.x, position.y);
        gCtx.rotate(rotation);
        WSetAlpha(color.a / 255.0);
        gCtx.fillRect(-size/2, -size/2, size, size);
      finally
        EndCanvasState(G);
      end;
    end;
  end;
end;


function TParticleSystem.GetActiveCount: Integer;
begin
  Result := Length(particles);
end;

{ ====== POMOCNICZE ====== }
function ColorToCanvasRGBA(const c: TColor): String;
begin
  Result := 'rgba(' +
    IntToStr(Round(Clamp(c.r,0,255))) + ',' +
    IntToStr(Round(Clamp(c.g,0,255))) + ',' +
    IntToStr(Round(Clamp(c.b,0,255))) + ',' +
    StringReplace(FormatFloat('0.###', Clamp(c.a,0,255)/255), ',', '.', []) +
    ')';
end;
function ColorFromHex(const hex: String): TColor;
var
  cleanHex: String;
begin
  cleanHex := StringReplace(hex, '#', '', [rfReplaceAll]);
  
  if Length(cleanHex) = 6 then
  begin
    Result.r := StrToInt('$' + Copy(cleanHex, 1, 2));
    Result.g := StrToInt('$' + Copy(cleanHex, 3, 2));
    Result.b := StrToInt('$' + Copy(cleanHex, 5, 2));
    Result.a := 255;
  end
  else if Length(cleanHex) = 8 then
  begin
    Result.r := StrToInt('$' + Copy(cleanHex, 1, 2));
    Result.g := StrToInt('$' + Copy(cleanHex, 3, 2));
    Result.b := StrToInt('$' + Copy(cleanHex, 5, 2));
    Result.a := StrToInt('$' + Copy(cleanHex, 7, 2));
  end
  else
  begin
    // Domyślny czarny kolor w przypadku błędu
    Result := COLOR_BLACK;
  end;
end;
{ ==== TRectangle helpers ===================================================== }

constructor TRectangle.Create(x, y, w, h: Double);
begin
  Self.x := x; Self.y := y; Self.width := w; Self.height := h;
end;

class function TRectangle.FromCenter(cx, cy, w, h: Double): TRectangle;
begin
  Result.x := cx - w * 0.5;
  Result.y := cy - h * 0.5;
  Result.width := w;
  Result.height := h;
end;

function TRectangleCreate(x, y, w, h: Double): TRectangle;
begin
  Result := TRectangle.Create(x, y, w, h);
end;

{ ==== TInputVector helpers (opcjonalnie) ==================================== }



function RandomColor(minBrightness: Integer = 0; maxBrightness: Integer = 255): TColor;
begin
  minBrightness := ClampI(minBrightness, 0, 255);
  maxBrightness := ClampI(maxBrightness, minBrightness, 255);
  
  Result.r := minBrightness + Random(maxBrightness - minBrightness + 1);
  Result.g := minBrightness + Random(maxBrightness - minBrightness + 1);
  Result.b := minBrightness + Random(maxBrightness - minBrightness + 1);
  Result.a := 255;
end;

function ColorEquals(const c1, c2: TColor): Boolean;
begin
  Result := (c1.r = c2.r) and (c1.g = c2.g) and (c1.b = c2.b) and (c1.a = c2.a);
end;


procedure EnsureTintCanvas(w, h: Integer);
begin
  if (gTintCanvas = nil) then
  begin
    gTintCanvas := TJSHTMLCanvasElement(document.createElement('canvas'));

    // ✅ BEZ Offscreen/Workera:
    gTintCtx := TJSCanvasRenderingContext2D(
      gTintCanvas.getContext('2d')
    );
  end;

  // rozmiar
  WilgaResize(gTintCanvas, w, h, 0); // 0 = auto DPR
end;



// ====== Opcje jakości/wydajności ======
procedure SetHiDPI(enabled: Boolean);
begin
  gUseHiDPI := enabled;
end;

procedure SetCanvasAlpha(enabled: Boolean);
begin
  gCanvasAlpha := enabled;
end;

procedure SetImageSmoothing(enabled: Boolean);
begin
  gImageSmoothingWanted := enabled;
  if Assigned(gCtx) then
    TJSObject(gCtx)['imageSmoothingEnabled'] := enabled;
end;

procedure SetClearFast(enabled: Boolean);
begin
  gUseClearFast := enabled;
end;

procedure Clear(const color: TColor);
begin
  if gUseClearFast then
    // TU KONWERSJA: TColor -> string
    ClearFast(ColorToCanvasRGBA(color))
  else
    ClearBackground(color);
end;


{ ====== CLIP / USTAWIENIA LINII ====== }
procedure BeginScissor(x, y, w, h: Integer);
begin
  CanvasSave;
  gCtx.beginPath;
  gCtx.rect(x, y, w, h);
  gCtx.clip;
end;

procedure EndScissor;
begin
 CanvasRestore;
end;

procedure SetLineJoin(const joinKind: String);
begin
  gCtx.lineJoin := joinKind; // 'miter'|'round'|'bevel'
end;
procedure SetLineJoin(const joinKind: TLineJoinKind); overload;
begin
  SetLineJoin(LineJoinToStr(joinKind));
end;



procedure SetLineCap(const capKind: String);
begin
  gCtx.lineCap := capKind; // 'butt'|'round'|'square'
end;
procedure SetLineCap(const capKind: TLineCapKind); overload;
begin
  SetLineCap(LineCapToStr(capKind));
end;



// ====== ClearFast: copy composite ======
procedure ClearFast(const rgba: string);
begin
  // szybkie czyszczenie przyjmujące już gotowy "rgba(...)"
  WClearFast(rgba);
end;



// ====== Batch prostokątów (path) ======
procedure BeginRectBatch(const color: TColor);
begin
  gCtx.beginPath;
  WSetFill(ColorToCanvasRGBA(color));
end;

procedure BatchRect(x, y, w, h: Integer);
begin
  gCtx.rect(x, y, w, h);
end;

procedure EndRectBatchFill;
begin
  gCtx.fill;
end;

// ====== Batch linii ======
procedure BeginLineBatch;
begin
  SetLength(gLineBatch, 0);
  gLineBatchActive := True;
end;

procedure BatchLine(aStartX, aStartY, aEndX, aEndY: Double; const aColor: TColor; aThickness: Integer = 1);
begin
  if not gLineBatchActive then Exit;
  SetLength(gLineBatch, Length(gLineBatch) + 1);
  with gLineBatch[High(gLineBatch)] do
  begin
    startX    := aStartX;
    startY    := aStartY;
    endX      := aEndX;
    endY      := aEndY;
    color     := aColor;
    thickness := aThickness;
  end;
end;

procedure BatchLineV(const aStartPos, aEndPos: TInputVector; const aColor: TColor; aThickness: Integer = 1);
begin
  BatchLine(aStartPos.x, aStartPos.y, aEndPos.x, aEndPos.y, aColor, aThickness);
end;

procedure EndLineBatch;
var
  i: Integer;
  currentColor: TColor;
  currentThickness: Integer;
  off: Double;
begin
  if not gLineBatchActive or (Length(gLineBatch) = 0) then Exit;

  gCtx.beginPath;
  currentColor := gLineBatch[0].color;
  currentThickness := gLineBatch[0].thickness;
  gCtx.strokeStyle := ColorToCanvasRGBA(currentColor);
  gCtx.lineWidth := currentThickness;

  for i := 0 to High(gLineBatch) do
  begin
    if (gLineBatch[i].color.r <> currentColor.r) or
       (gLineBatch[i].color.g <> currentColor.g) or
       (gLineBatch[i].color.b <> currentColor.b) or
       (gLineBatch[i].color.a <> currentColor.a) or
       (gLineBatch[i].thickness <> currentThickness) then
    begin
      gCtx.stroke;
      gCtx.beginPath;
      currentColor := gLineBatch[i].color;
      currentThickness := gLineBatch[i].thickness;
      gCtx.strokeStyle := ColorToCanvasRGBA(currentColor);
      gCtx.lineWidth := currentThickness;
    end;

    if currentThickness = 1 then off := 0.5 else off := 0.0;
    gCtx.moveTo(gLineBatch[i].startX + off, gLineBatch[i].startY + off);
    gCtx.lineTo(gLineBatch[i].endX   + off, gLineBatch[i].endY   + off);
  end;

  gCtx.stroke;
  SetLength(gLineBatch, 0);
  gLineBatchActive := False;
end;


// ====== Pixel (pojedynczy) + PixelBatch ======
procedure DrawPixel(x, y: Integer; const color: TColor);
begin
  // Najprościej i najszybciej w 2D canvas: fillRect 1x1
  WSetFill(ColorToCanvasRGBA(color));
  gCtx.fillRect(x, y, 1, 1);
end;

procedure DrawPixelV(const pos: TInputVector; const color: TColor);
begin
  DrawPixel(Round(pos.x), Round(pos.y), color);
end;

// Batch piksli (kolor per piksel)
var
  gPixelBatchActive: Boolean = False;
  gPixelBatch: array of TPixelBatchItem;

procedure BeginPixelBatch;
begin
  SetLength(gPixelBatch, 0);
  gPixelBatchActive := True;
end;

procedure BatchPixel(x, y: Integer; const color: TColor);
begin
  if not gPixelBatchActive then Exit;
  SetLength(gPixelBatch, Length(gPixelBatch)+1);
  gPixelBatch[High(gPixelBatch)].x := x;
  gPixelBatch[High(gPixelBatch)].y := y;
  gPixelBatch[High(gPixelBatch)].color := color;
end;

procedure BatchPixelV(const pos: TInputVector; const color: TColor);
begin
  BatchPixel(Round(pos.x), Round(pos.y), color);
end;

procedure EndPixelBatch;
var
  i: Integer;
  currentColor: TColor;
  first: Boolean;
begin
  if not gPixelBatchActive or (Length(gPixelBatch)=0) then Exit;

  first := True;
  for i := 0 to High(gPixelBatch) do
  begin
    if first or ( (gPixelBatch[i].color.r<>currentColor.r)
               or (gPixelBatch[i].color.g<>currentColor.g)
               or (gPixelBatch[i].color.b<>currentColor.b)
               or (gPixelBatch[i].color.a<>currentColor.a) ) then
    begin
      currentColor := gPixelBatch[i].color;
      WSetFill(ColorToCanvasRGBA(currentColor));
      first := False;
    end;
    gCtx.fillRect(gPixelBatch[i].x, gPixelBatch[i].y, 1, 1);
  end;

  SetLength(gPixelBatch, 0);
  gPixelBatchActive := False;
end;


procedure DrawBezierQ(const p0, p1, p2: TInputVector; const color: TColor; thickness: Integer = 1);
begin
  if thickness <= 0 then thickness := 1;

  gCtx.lineWidth := thickness;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);

  gCtx.beginPath;
  gCtx.moveTo(p0.x, p0.y);
  gCtx.quadraticCurveTo(p1.x, p1.y, p2.x, p2.y);
  gCtx.stroke;
end;

procedure DrawDashedBezierQ(const p0, p1, p2: TInputVector; const color: TColor;
  thickness: Integer; dashLen, gapLen: Double);
begin
  if thickness <= 0 then thickness := 1;
  if dashLen <= 0 then dashLen := 1;
  if gapLen < 0 then gapLen := 0;

  WSetDash(dashLen, gapLen);
  DrawBezierQ(p0, p1, p2, color, thickness);
  WClearDash;
end;
procedure DrawBezierC(const p0, p1, p2, p3: TInputVector; const color: TColor; thickness: Integer = 1);
begin
  if thickness <= 0 then thickness := 1;

  gCtx.lineWidth := thickness;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);

  gCtx.beginPath;
  gCtx.moveTo(p0.x, p0.y);
  gCtx.bezierCurveTo(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y);
  gCtx.stroke;
end;

procedure DrawDashedBezierC(const p0, p1, p2, p3: TInputVector; const color: TColor;
  thickness: Integer; dashLen, gapLen: Double);
begin
  if thickness <= 0 then thickness := 1;
  if dashLen <= 0 then dashLen := 1;
  if gapLen < 0 then gapLen := 0;

  WSetDash(dashLen, gapLen);
  DrawBezierC(p0, p1, p2, p3, color, thickness);
  WClearDash;
end;
function BezierCPoint(const p0,p1,p2,p3: TInputVector; t: Double): TInputVector;
var
  u, tt, uu, uuu, ttt: Double;
begin
  u := 1.0 - t;
  tt := t*t;
  uu := u*u;
  uuu := uu*u;
  ttt := tt*t;

  Result.x := uuu*p0.x + 3*uu*t*p1.x + 3*u*tt*p2.x + ttt*p3.x;
  Result.y := uuu*p0.y + 3*uu*t*p1.y + 3*u*tt*p2.y + ttt*p3.y;
end;

procedure SampleBezierC(const p0,p1,p2,p3: TInputVector; samples: Integer; out pts: array of TInputVector);
var
  i: Integer;
  t: Double;
begin
  if samples < 2 then samples := 2;
  if Length(pts) < samples then Exit;

  for i := 0 to samples-1 do
  begin
    t := i / (samples-1);
    pts[i] := BezierCPoint(p0,p1,p2,p3, t);
  end;
end;



// ====== RectSeries (fillStyle raz, same fillRect) ======
procedure BeginRectSeries(const color: TColor);
begin
  WSetFill(ColorToCanvasRGBA(color));
end;

procedure RectFill(x, y, w, h: Integer);
begin
  gCtx.fillRect(x, y, w, h);
end;

procedure EndRectSeries;
begin

end;

function GetScreenWidth: Integer;
var
  cnv: TJSHTMLCanvasElement;
  v  : JSValue;
  cw : Integer;
begin
  // 1) Spróbuj wyciągnąć canvas z gCtx (proxy lub zwykły)
  cnv := nil;
  if gCtx <> nil then
  asm
    var ctx = $mod.gCtx;
    var c = (ctx && ctx.canvas) ? ctx.canvas : null;
    cnv = c;
  end;

  // 2) Jeśli mamy canvas z gCtx – używamy go
  if cnv <> nil then
  begin
    v := TJSObject(cnv)['__wilgaOffscreen'];
    if (not JS.isUndefined(v)) and (v <> nil) then
      cw := Integer(TJSObject(v)['width'])
    else
      cw := cnv.width;
  end
  // 3) Jeśli nie – spróbuj głównego gCanvas (HTMLCanvasElement z InitWindow)
  else if Assigned(gCanvas) and (gCanvas.width > 0) then
    cw := gCanvas.width
  // 4) Jeszcze wcześniej – okno przeglądarki
  else if Assigned(window) then
    cw := window.innerWidth
  // 5) Ostateczny fallback
  else
    cw := 800;

  // DPI (devicePixelRatio)
  if gDPR = 0 then
    if Assigned(window) then
      gDPR := window.devicePixelRatio
    else
      gDPR := 1;

  Result := Round(cw / gDPR);
end;

function GetScreenHeight: Integer;
var
  cnv: TJSHTMLCanvasElement;
  v  : JSValue;
  ch : Integer;
begin
  cnv := nil;
  if gCtx <> nil then
  asm
    var ctx = $mod.gCtx;
    var c = (ctx && ctx.canvas) ? ctx.canvas : null;
    cnv = c;
  end;

  if cnv <> nil then
  begin
    v := TJSObject(cnv)['__wilgaOffscreen'];
    if (not JS.isUndefined(v)) and (v <> nil) then
      ch := Integer(TJSObject(v)['height'])
    else
      ch := cnv.height;
  end
  else if Assigned(gCanvas) and (gCanvas.height > 0) then
    ch := gCanvas.height
  else if Assigned(window) then
    ch := window.innerHeight
  else
    ch := 600;

  if gDPR = 0 then
    if Assigned(window) then
      gDPR := window.devicePixelRatio
    else
      gDPR := 1;

  Result := Round(ch / gDPR);
end;


function GetMouseX: Integer; begin Result := Round(gMousePos.x); end;
function GetMouseY: Integer; begin Result := Round(gMousePos.y); end;
function GetFrameTime: Double; begin Result := gLastDt; end;
function GetFPS: Integer; begin Result := gCurrentFps; end;
function GetDeltaTime: Double; begin Result := gLastDt; end;
function GetTime: Double; begin Result := (window.performance.now() - gStartTime) / 1000.0; end;

{ ====== RYSOWANIE KSZTAŁTÓW ====== }
procedure DrawLine(startX, startY, endX, endY: double; const color: TColor; thickness: Integer = 1);
var off: Double;

begin
  if (thickness and 1) = 1 then off := 0.5 else off := 0.0;
  gCtx.beginPath;
  gCtx.lineWidth := thickness;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);
  gCtx.moveTo(startX + off, startY + off);
  gCtx.lineTo(endX   + off, endY   + off);
  gCtx.stroke;
end;


procedure DrawLineV(startPos, endPos: TInputVector; const color: TColor; thickness: Integer = 1);
begin
  DrawLine(Round(startPos.x), Round(startPos.y), Round(endPos.x), Round(endPos.y), color, thickness);
end;

procedure DrawTriangle(const tri: TTriangle; const color: TColor; filled: Boolean = True);
begin
  gCtx.beginPath;
  gCtx.moveTo(tri.p1.x, tri.p1.y);
  gCtx.lineTo(tri.p2.x, tri.p2.y);
  gCtx.lineTo(tri.p3.x, tri.p3.y);
  gCtx.closePath;

  if filled then begin
    WSetFill(ColorToCanvasRGBA(color));
    gCtx.fill;
  end else begin
    gCtx.strokeStyle := ColorToCanvasRGBA(color);
    gCtx.stroke;
  end;
end;

procedure DrawTriangleLines(const tri: TTriangle; const color: TColor; thickness: Integer = 1);
begin
  gCtx.lineWidth := thickness;
  DrawTriangle(tri, color, False);
end;
// ========== Wielokąty / polilinie ==========
procedure DrawPolyline(const pts: array of TInputVector; const color: TColor; thickness: Integer; closed: Boolean);
var i: Integer; off: Double;
begin
  if Length(pts) < 2 then Exit;
  if thickness = 1 then off := 0.5 else off := 0.0;

  CanvasSave;
  gCtx.beginPath;
  gCtx.moveTo(pts[0].x + off, pts[0].y + off);
  for i := 1 to High(pts) do
    gCtx.lineTo(pts[i].x + off, pts[i].y + off);

  if closed then gCtx.closePath;

  gCtx.lineWidth := thickness;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);
  gCtx.stroke;
  CanvasRestore;
end;

procedure DrawPolygon(const pts: array of TInputVector; const color: TColor; filled: Boolean);
var i: Integer;
begin
  if Length(pts) < 3 then Exit;

  CanvasSave;
  gCtx.beginPath;
  gCtx.moveTo(pts[0].x, pts[0].y);
  for i := 1 to High(pts) do
    gCtx.lineTo(pts[i].x, pts[i].y);
  gCtx.closePath;

  if filled then
  begin
    WSetFill(ColorToCanvasRGBA(color));
    gCtx.fill;
  end
  else
  begin
    gCtx.strokeStyle := ColorToCanvasRGBA(color);
    gCtx.stroke;
  end;
  CanvasRestore;
end;

// ========== Łuki / wycinki ==========
procedure DrawArc(cx, cy, r: Double; startDeg, endDeg: Double; const color: TColor; thickness: Integer);
begin
  CanvasSave;
  gCtx.beginPath;
  gCtx.lineWidth := thickness;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);
  gCtx.arc(cx, cy, r, DegToRad(startDeg), DegToRad(endDeg), False);
  gCtx.stroke;
  CanvasRestore;
end;

procedure DrawRing(cx, cy, rInner, rOuter, startDeg, endDeg: Double; const color: TColor);
var a0, a1: Double;
begin
  if (rOuter <= rInner) or (rInner < 0) then Exit;
  a0 := DegToRad(startDeg); a1 := DegToRad(endDeg);

  CanvasSave;
  gCtx.beginPath;
  gCtx.arc(cx, cy, rOuter, a0, a1, False);
  gCtx.arc(cx, cy, rInner, a1, a0, True); // powrót wewnątrz
  gCtx.closePath;
  WSetFill(ColorToCanvasRGBA(color));
  gCtx.fill;
  CanvasRestore;
end;

procedure DrawSector(cx, cy, r: Double; startDeg, endDeg: Double; const color: TColor);
begin
  CanvasSave;
  gCtx.beginPath;
  gCtx.moveTo(cx, cy);
  gCtx.arc(cx, cy, r, DegToRad(startDeg), DegToRad(endDeg), False);
  gCtx.closePath;
  WSetFill(ColorToCanvasRGBA(color));
  gCtx.fill;
  CanvasRestore;
end;

// ========== Linie kreskowane ==========
procedure SetLineDash(const dashes: array of Double);
var arr: TJSArray; i: Integer;
begin
  arr := TJSArray.new;
  for i := 0 to High(dashes) do arr.push(dashes[i]);
  gCtx.setLineDash(arr);
end;

procedure ClearLineDash;
begin
  gCtx.setLineDash(TJSArray.new); // pusty pattern
end;

procedure DrawDashedLine(x1, y1, x2, y2: Double; const color: TColor;
  thickness: Integer; dashLen, gapLen: Double);
begin
  if thickness <= 0 then thickness := 1;
  if dashLen <= 0 then dashLen := 1;
  if gapLen < 0 then gapLen := 0;

  WSetDash(dashLen, gapLen);

  gCtx.lineWidth := thickness;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);

  gCtx.beginPath;
  gCtx.moveTo(x1, y1);
  gCtx.lineTo(x2, y2);
  gCtx.stroke;

  WClearDash;
end;


procedure DrawDashedPolyline(const pts: array of TInputVector; const color: TColor;
  thickness: Integer; dashLen: Double; gapLen: Double);
var
  i: Integer;
begin
  if Length(pts) < 2 then Exit;

  WSetDash(dashLen, gapLen);

  gCtx.lineWidth := thickness;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);

  gCtx.beginPath;
  gCtx.moveTo(pts[0].x, pts[0].y);
  for i := 1 to High(pts) do
    gCtx.lineTo(pts[i].x, pts[i].y);
  gCtx.stroke;

  WClearDash;
end;


procedure DrawDashedTriangle(const tri: TTriangle; const color: TColor;
  thickness: Integer; dashLen: Double; gapLen: Double);
begin
  WSetDash(dashLen, gapLen);

  gCtx.lineWidth := thickness;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);

  gCtx.beginPath;
  gCtx.moveTo(tri.p1.x, tri.p1.y);
  gCtx.lineTo(tri.p2.x, tri.p2.y);
  gCtx.lineTo(tri.p3.x, tri.p3.y);
  gCtx.closePath;
  gCtx.stroke;

  WClearDash;
end;
procedure DrawDashedCircle(cx, cy, radius: Double; const color: TColor;
  thickness: Integer; dashLen: Double; gapLen: Double; segments: Integer);
begin
  if radius <= 0 then Exit;

  WSetDash(dashLen, gapLen);

  gCtx.lineWidth := thickness;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);

  gCtx.beginPath;
  gCtx.arc(cx, cy, radius, 0, 2 * Pi);
  gCtx.stroke;

  WClearDash;
end;

procedure DrawDashedCircleV(center: TInputVector; radius: Double; const color: TColor;
  thickness: Integer; dashLen: Double; gapLen: Double; segments: Integer);
begin
  DrawDashedCircle(center.x, center.y, radius, color,
    thickness, dashLen, gapLen, segments);
end;
procedure DrawDashedEllipse(cx, cy, rx, ry: Double; const color: TColor;
  thickness: Integer; dashLen: Double; gapLen: Double; segments: Integer);
begin
  if (rx <= 0) or (ry <= 0) then Exit;

  WSetDash(dashLen, gapLen);

  gCtx.lineWidth := thickness;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);

  gCtx.beginPath;
  gCtx.ellipse(cx, cy, rx, ry, 0, 0, 2 * Pi);
  gCtx.stroke;

  WClearDash;
end;

procedure DrawDashedEllipseV(center: TInputVector; radiusX, radiusY: Double;
  const color: TColor; thickness: Integer; dashLen: Double; gapLen: Double;
  segments: Integer);
begin
  DrawDashedEllipse(center.x, center.y, radiusX, radiusY, color,
    thickness, dashLen, gapLen, segments);
end;

// ========== Gradient prostokątny ==========
procedure FillRectLinearGradient(const rec: TRectangle; const c0, c1: TColor; angleDeg: Double);
var
  cx, cy, dx, dy, halfDiag: Double;
  x0, y0, x1, y1: Double;
  grad: TJSCanvasGradient;
  rad: Double;
begin
  // środek i kierunek
  cx := rec.x + rec.width  * 0.5;
  cy := rec.y + rec.height * 0.5;
  rad := DegToRad(angleDeg);
  dx := Cos(rad); dy := Sin(rad);

  // długość do pokrycia całego rect
  halfDiag := Sqrt(Sqr(rec.width) + Sqr(rec.height)) * 0.5;

  x0 := cx - dx * halfDiag;  y0 := cy - dy * halfDiag;
  x1 := cx + dx * halfDiag;  y1 := cy + dy * halfDiag;

  grad := gCtx.createLinearGradient(x0, y0, x1, y1);
  grad.addColorStop(0, ColorToCanvasRGBA(c0));
  grad.addColorStop(1, ColorToCanvasRGBA(c1));

  CanvasSave;
  WSetFill(grad);
  gCtx.fillRect(rec.x, rec.y, rec.width, rec.height);
  CanvasRestore;
end;

// ========== Tekst z obrysem ==========


// ========== Clip dowolnym path ==========
procedure BeginPathClip(const BuildPath: TNoArgProc);
begin
  CanvasSave;
  gCtx.beginPath;
  if Assigned(BuildPath) then BuildPath();
  gCtx.clip;
end;

procedure EndClip;
begin
  CanvasRestore;
end;

procedure DrawRectangleRounded(x, y, w, h, radius: double; const color: TColor; filled: Boolean = True);
var
  maxRadius, halfW, halfH: double;
begin
  if radius <= 0 then
  begin
    if filled then
      DrawRectangle(x, y, w, h, color)
    else
      DrawRectangleLines(x, y, w, h, color);
    Exit;
  end;

  // zamiast Min(w div 2, h div 2):
  halfW := w / 2; // to samo co w div 2
  halfH := h / 2; // to samo co h div 2
  if halfW < halfH then
    maxRadius := halfW
  else
    maxRadius := halfH;

  if radius > maxRadius then
    radius := maxRadius;

  gCtx.beginPath;
  gCtx.moveTo(x + radius, y);
  gCtx.arcTo(x + w, y, x + w, y + h, radius);
  gCtx.arcTo(x + w, y + h, x, y + h, radius);
  gCtx.arcTo(x, y + h, x, y, radius);
  gCtx.arcTo(x, y, x + w, y, radius);
  gCtx.closePath;

  if filled then
  begin
    WSetFill(ColorToCanvasRGBA(color));
    gCtx.fill;
  end
  else
  begin
    gCtx.strokeStyle := ColorToCanvasRGBA(color);
    gCtx.stroke;
  end;
end;

procedure DrawRectangleRoundedRec(const rec: TRectangle; radius: Double; const color: TColor; filled: Boolean = True);
begin
  DrawRectangleRounded(Round(rec.x), Round(rec.y), Round(rec.width), Round(rec.height), 
                      Round(radius), color, filled);
end;
procedure DrawRectangleLines(x, y, w, h: double; const color: TColor; thickness: Integer = 1);
var off: Double;
begin
  gCtx.lineWidth := thickness;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);
  if (thickness and 1) = 1 then off := 0.5 else off := 0.0;
  gCtx.strokeRect(x + off, y + off, w, h);
end;

{ ====== TRANSFORMACJE I MACIERZE ====== }
function MatrixIdentity: TMatrix2D;
begin
  Result.m0 := 1; Result.m1 := 0; Result.m2 := 0;
  Result.m3 := 0; Result.m4 := 1; Result.m5 := 0;
end;

function MatrixTranslate(tx, ty: Double): TMatrix2D;
begin
  Result.m0 := 1; Result.m1 := 0; Result.m2 := tx;
  Result.m3 := 0; Result.m4 := 1; Result.m5 := ty;
end;

function MatrixRotate(radians: Double): TMatrix2D;
var c, s: Double;
begin
  c := Cos(radians); s := Sin(radians);
  Result.m0 := c;  Result.m1 := -s; Result.m2 := 0;
  Result.m3 := s;  Result.m4 :=  c; Result.m5 := 0;
end;

function MatrixRotateDeg(deg: Double): TMatrix2D;
begin
  Result := MatrixRotate(DegToRad(deg));
end;

function MatrixScale(sx, sy: Double): TMatrix2D;
begin
  Result.m0 := sx; Result.m1 := 0;  Result.m2 := 0;
  Result.m3 := 0;  Result.m4 := sy; Result.m5 := 0;
end;

function MatrixMultiply(const a, b: TMatrix2D): TMatrix2D;
begin
  Result.m0 := a.m0*b.m0 + a.m1*b.m3;
  Result.m1 := a.m0*b.m1 + a.m1*b.m4;
  Result.m2 := a.m0*b.m2 + a.m1*b.m5 + a.m2;
  Result.m3 := a.m3*b.m0 + a.m4*b.m3;
  Result.m4 := a.m3*b.m1 + a.m4*b.m4;
  Result.m5 := a.m3*b.m2 + a.m4*b.m5 + a.m5;
end;

function Vector2Transform(v: TInputVector; mat: TMatrix2D): TInputVector;
begin
  Result.x := v.x * mat.m0 + v.y * mat.m1 + mat.m2;
  Result.y := v.x * mat.m3 + v.y * mat.m4 + mat.m5;
end;

// Memory pooling
function GetVectorFromPool(x, y: Double): TInputVector;
begin
  if Length(gVectorPool) > 0 then
  begin
    Result := gVectorPool[High(gVectorPool)];
    SetLength(gVectorPool, Length(gVectorPool) - 1);
    Result.x := x; Result.y := y;
  end
  else
    Result := NewVector(x, y);
end;

procedure ReturnVectorToPool(var v: TInputVector);
begin
  SetLength(gVectorPool, Length(gVectorPool) + 1);
  gVectorPool[High(gVectorPool)] := v;
end;

function GetMatrixFromPool: TMatrix2D;
begin
  if Length(gMatrixPool) > 0 then
  begin
    Result := gMatrixPool[High(gMatrixPool)];
    SetLength(gMatrixPool, Length(gMatrixPool) - 1);
  end
  else
    Result := MatrixIdentity;
end;

procedure ReturnMatrixToPool(var mat: TMatrix2D);
begin
  SetLength(gMatrixPool, Length(gMatrixPool) + 1);
  gMatrixPool[High(gMatrixPool)] := mat;
end;

{ ====== KAMERA ====== }
function DefaultCamera: TCamera2D;
begin
  Result.target := NewVector(0, 0);
  Result.offset := NewVector(0, 0);
  Result.rotation := 0.0;
  Result.zoom := 1.0;
end;

procedure BeginMode2D(const camera: TCamera2D);
var
  z, tx, ty, a, b, c_, d, e, f, coss, sinn: Double;
begin
  CanvasSave;

  z := camera.zoom; if z = 0 then z := 1.0;

  // (opcjonalnie) zapamiętaj stan, jeśli gdzieś używasz
  // gCamActive := True; gCamZoom := z;

  if camera.rotation = 0.0 then
  begin
    // M = S(z) + T((-target)*z + offset)
    tx := -camera.target.x * z + camera.offset.x;
    ty := -camera.target.y * z + camera.offset.y;

    // pixel-snapping translacji w screen-space
    {tx := Round(tx);
    ty := Round(ty);}

    gCtx.setTransform(z, 0, 0, z, tx, ty);
  end
  else
  begin
    // M = T(offset) * R(rot) * S(z) * T(-target)
    coss := Cos(camera.rotation);
    sinn := Sin(camera.rotation);

    a :=  coss * z;   b :=  sinn * z;
    c_ := -sinn * z;  d :=  coss * z;

    tx := -camera.target.x;
    ty := -camera.target.y;

    // ostateczna translacja w screen-space:
    e := camera.offset.x + (a * tx + c_ * ty);
    f := camera.offset.y + (b * tx + d * ty);

    {// snap translacji (przy rotacji to best-effort)
    e := Round(e); f := Round(f);

    gCtx.setTransform(a, b, c_, d, e, f);}
  end;
end;

procedure EndMode2D;
begin
  CanvasRestore;
  // gCamActive := False;
end;


function ScreenToWorld(p: TVector2; const cam: TCamera2D): TVector2;
var mat: TMatrix2D;
begin
  mat := MatrixMultiply(MatrixMultiply(MatrixTranslate(cam.target.x, cam.target.y),
                                       MatrixRotate(-cam.rotation)),
                        MatrixScale(1/cam.zoom, 1/cam.zoom));
  Result := Vector2Transform(Vector2Subtract(p, cam.offset), mat);
end;

function WorldToScreen(p: TVector2; const cam: TCamera2D): TVector2;
var mat: TMatrix2D;
begin
  mat := MatrixMultiply(MatrixMultiply(MatrixTranslate(-cam.target.x, -cam.target.y),
                                       MatrixRotate(cam.rotation)),
                        MatrixScale(cam.zoom, cam.zoom));
  Result := Vector2Add(Vector2Transform(p, mat), cam.offset);
end;

{ ====== KOLIZJE I GEOMETRIA ====== }
function CheckCollisionPointRec(point: TInputVector; const rec: TRectangle): Boolean;
begin
  Result := (point.x >= rec.x) and (point.x <= rec.x + rec.width) and
            (point.y >= rec.y) and (point.y <= rec.y + rec.height);
end;

function CheckCollisionCircles(center1: TInputVector; radius1: Double;
                              center2: TInputVector; radius2: Double): Boolean;
var d: Double;
begin
  d := Vector2Length(Vector2Subtract(center1, center2));
  Result := d <= (radius1 + radius2);
end;

function ClampD(value, minVal, maxVal: Double): Double;
begin
  if value < minVal then Exit(minVal);
  if value > maxVal then Exit(maxVal);
  Result := value;
end;

function CheckCollisionCircleRec(center: TInputVector; radius: Double; const rec: TRectangle): Boolean;
var closestX, closestY: Double;
begin
  closestX := ClampD(center.x, rec.x, rec.x + rec.width);
  closestY := ClampD(center.y, rec.y, rec.y + rec.height);
  Result := Vector2Length(Vector2Subtract(center, NewVector(closestX, closestY))) <= radius;
end;

function CheckCollisionRecs(const a, b: TRectangle): Boolean;
begin
  Result := not ((a.x + a.width  <= b.x) or
                 (b.x + b.width  <= a.x) or
                 (a.y + a.height <= b.y) or
                 (b.y + b.height <= a.y));
end;

function CheckCollisionPointCircle(point, center: TInputVector; radius: Double): Boolean;
begin
  Result := Vector2Length(Vector2Subtract(point, center)) <= radius;
end;

function CheckCollisionPointPoly(point: TInputVector; const points: array of TInputVector): Boolean;
var
  i, j: Integer;
  inside: Boolean;
begin
  inside := False;
  j := High(points);
  
  for i := 0 to High(points) do
  begin
    if ((points[i].y > point.y) <> (points[j].y > point.y)) and
       (point.x < (points[j].x - points[i].x) * (point.y - points[i].y) / 
                 (points[j].y - points[i].y) + points[i].x) then
    begin
      inside := not inside;
    end;
    j := i;
  end;
  
  Result := inside;
end;

function CheckCollisionLineLine(a1, a2, b1, b2: TInputVector): Boolean;
var
  t, u: Double;
begin
  Result := LinesIntersect(a1, a2, b1, b2, t, u);
end;

function CheckCollisionLineRec(const line: TLine; const rec: TRectangle): Boolean;
var
  corners: array[0..3] of TInputVector;
  i: Integer;
  t, u: Double;
begin
  corners[0] := NewVector(rec.x, rec.y);
  corners[1] := NewVector(rec.x + rec.width, rec.y);
  corners[2] := NewVector(rec.x + rec.width, rec.y + rec.height);
  corners[3] := NewVector(rec.x, rec.y + rec.height);

  for i := 0 to 3 do
  begin
    if LinesIntersect(line.startPoint, line.endPoint,
                     corners[i], corners[(i+1) mod 4], t, u) then
      Exit(True);
  end;

  Result := False;
end;

function LinesIntersect(p1, p2, p3, p4: TInputVector; out t, u: Double): Boolean;
var
  denom, numT, numU: Double;
begin
  denom := (p1.x - p2.x)*(p3.y - p4.y) - (p1.y - p2.y)*(p3.x - p4.x);
  if denom = 0 then Exit(False);
  numT := (p1.x - p3.x)*(p3.y - p4.y) - (p1.y - p3.y)*(p3.x - p4.x);
  numU := (p1.x - p3.x)*(p1.y - p2.y) - (p1.y - p3.y)*(p1.x - p2.x);
  t := numT / denom;
  u := numU / denom;
  Result := (t >= 0) and (t <= 1) and (u >= 0) and (u <= 1);
end;

{ ====== ŁADOWANIE I RYSOWANIE OBRAZÓW ====== }
procedure LoadImageFromURL(const url: String; OnReady: TOnTextureReady); overload;
var
  img: TJSHTMLImageElement;
  tex: TTexture;
begin
  tex.canvas := TJSHTMLCanvasElement(document.createElement('canvas'));
  tex.width  := 0;
  tex.height := 0;
  tex.loaded := False;
  tex.texId  := 0;

  img := TJSHTMLImageElement(document.createElement('img'));
  img.crossOrigin := 'anonymous';

  img.onload := TJSEventHandler(
    procedure (event: TJSEvent)
    var
      ctx: TJSCanvasRenderingContext2D;
    begin
     // writeln('IMG ONLOAD: ', url);

      tex.width  := img.width;
      tex.height := img.height;

      tex.canvas.width  := img.width;
      tex.canvas.height := img.height;

      ctx := TJSCanvasRenderingContext2D(tex.canvas.getContext('2d'));
      ctx.drawImage(img, 0, 0);

      tex.loaded := True;
      {$ifdef WILGA_DEBUG} DBG_Inc(dbg_TexturesAlive); {$endif}

      W_RegisterTexture(tex);

      if Assigned(OnReady) then
        OnReady(tex);
    end
  );

  img.onerror := TJSErrorEventHandler(
    procedure (event: TJSErrorEvent)
    begin
      console.warn('LoadImageFromURL failed: ' + url);
      tex.canvas := nil;
      tex.width  := 0;
      tex.height := 0;
      tex.loaded := False;
      tex.texId  := 0;
      if Assigned(OnReady) then
        OnReady(tex);
    end
  );

  img.src := url;
end;



function LoadImageFromURL(const url: String): TTexture; overload;
  deprecated '⚠ użycie bez callbacka może nie działać — dodaj OnReady (callback).';
var
  img: TJSHTMLImageElement;
  tex: TTexture;
begin
  tex.canvas := TJSHTMLCanvasElement(document.createElement('canvas'));
  tex.width  := 0;
  tex.height := 0;
  tex.loaded := False;
  tex.texId  := 0;

  img := TJSHTMLImageElement(document.createElement('img'));
  img.crossOrigin := 'anonymous';

  img.onload := TJSEventHandler(
    procedure (event: TJSEvent)
    var
      ctx: TJSCanvasRenderingContext2D;
    begin
      tex.width  := img.width;
      tex.height := img.height;
      tex.canvas.width  := img.width;
      tex.canvas.height := img.height;

      // ZWYKŁY 2D CONTEXT – tekstura NIE MOŻE być OffscreenCanvas!
      ctx := TJSCanvasRenderingContext2D(tex.canvas.getContext('2d'));
      ctx.drawImage(img, 0, 0);

      tex.loaded := True;

      // Rejestracja ImageBitmap dla Workera
      W_RegisterTexture(tex);
    end
  );

  img.onerror := TJSErrorEventHandler(
    procedure (event: TJSErrorEvent)
    begin
      console.warn('LoadImageFromURL failed: ' + url);
      tex.canvas := nil;
      tex.width := 0;
      tex.height := 0;
      tex.loaded := False;
      tex.texId := 0;
    end
  );

  img.src := url;
  Result := tex;
end;


procedure ReleaseTexture(var tex: TTexture);
begin
  if tex.canvas <> nil then
  begin
    // --------------------------
    // 1) UNREGISTER z WORKERA
    // --------------------------
    asm
      var worker = window.__wilgaRenderWorker;
      if (worker && tex.canvas && tex.canvas.__wilgaTexId)
      {
        worker.postMessage(
          { type: 'unregisterTexture', id: tex.canvas.__wilgaTexId }
        );
      }
    end;

    // --------------------------
    // 2) Skasowanie fizycznej bitmapy canvasu
    // --------------------------
    asm
      var cnv = tex.canvas;
      var off = (cnv && cnv.__wilgaOffscreen) ? cnv.__wilgaOffscreen : null;

      if (off) {
        off.width = 0;
        off.height = 0;
      } else if (cnv) {
        cnv.width = 0;
        cnv.height = 0;
      }
    end;

    // --------------------------
    // 3) Zwolnienie referencji
    // --------------------------
    tex.canvas := nil;

    // Debug - zachowane bez zmian
    {$ifdef WILGA_DEBUG}
      DBG_Dec(dbg_TexturesAlive);
    {$endif}
  end;

  tex.loaded := False;
  tex.width := 0;
  tex.height := 0;
end;


procedure ReleaseRenderTexture(var rtex: TRenderTexture2D);
begin
  if (rtex.texture.canvas <> nil) then
  begin
    {$ifdef WILGA_DEBUG} DBG_Dec(dbg_RenderTexturesAlive); {$endif}
  end;
  ReleaseTexture(rtex.texture);
end;

procedure DrawTexture(const tex: TTexture; x, y: Integer; const tint: TColor);
begin
  DrawTexturePro(tex,
    RectangleCreate(0, 0, tex.width, tex.height),
    RectangleCreate(x, y, tex.width, tex.height),
    Vector2Zero, 0, tint);
end;
// Proste rysowanie z pozycją, skalą, rotacją i tintem
// === Tekstury ===

// Rysowanie z pozycją, skalą, rotacją i tintem
procedure DrawTextureEx(const tex: TTexture; position: TVector2; scale: Double; rotation: Double; const tint: TColor);
var
  src, dst: TRectangle;
  origin: TVector2;
begin
  src := RectangleCreate(0, 0, tex.width, tex.height);
  dst := RectangleCreate(position.x, position.y, tex.width * scale, tex.height * scale);
  origin := Vector2Create(0,0);
  DrawTexturePro(tex, src, dst, origin, rotation, tint);
end;

// Rysowanie wycinka tekstury (source rectangle)
procedure DrawTextureRec(const tex: TTexture; const src: TRectangle; position: TVector2; const tint: TColor);
var
  dst: TRectangle;
  origin: TVector2;
begin
  dst := RectangleCreate(position.x, position.y, src.width, src.height);
  origin := Vector2Create(0, 0);
  DrawTexturePro(tex, src, dst, origin, 0, tint);
end;

// Rysowanie powtarzającej się tekstury na obszarze (tiling)
procedure DrawTextureTiled(const tex: TTexture; const src, dst: TRectangle; origin: TVector2; rotation: Double; scale: Double; const tint: TColor);
var
  x, y: Integer;
  tileDst: TRectangle;
begin
  for y := 0 to Trunc(dst.height / (src.height * scale)) do
    for x := 0 to Trunc(dst.width / (src.width * scale)) do
    begin
      tileDst := RectangleCreate(
        dst.x + x * src.width * scale,
        dst.y + y * src.height * scale,
        src.width * scale,
        src.height * scale
      );
      DrawTexturePro(tex, src, tileDst, origin, rotation, tint);
    end;
end;

// Rysowanie z originem w proporcjach (0..1)
procedure DrawTextureProRelOrigin(const tex: TTexture; const src, dst: TRectangle; originRel: TVector2; rotation: Double; const tint: TColor);
var
  origin: TVector2;
begin
  origin := Vector2Create(dst.width * originRel.x, dst.height * originRel.y);
  DrawTexturePro(tex, src, dst, origin, rotation, tint);
end;

function OriginTopLeft: TVector2; inline;
begin
  Result.x := 0; Result.y := 0;
end;

function OriginCenter(const dst: TRectangle): TVector2; inline;
begin
  Result.x := dst.width * 0.5;
  Result.y := dst.height * 0.5;
end;

procedure DrawTextureTopLeft(const tex: TTexture; x, y: Double; const tint: TColor);
var
  src, dst: TRectangle;
  origin: TVector2;
begin
  src := RectangleCreate(0, 0, tex.width, tex.height);
  dst := RectangleCreate(x, y, tex.width, tex.height);
  origin := OriginTopLeft;
  DrawTexturePro(tex, src, dst, origin, 0.0, tint);
end;



// Rysowanie ramki z atlasu po indeksie
procedure DrawAtlasFrame(const tex: TTexture; frameIndex, frameWidth, frameHeight: Integer; position: TVector2; const tint: TColor);
var
  cols, srcX, srcY: Integer;
  src: TRectangle;
begin
  cols := tex.width div frameWidth;
  srcX := (frameIndex mod cols) * frameWidth;
  srcY := (frameIndex div cols) * frameHeight;
  src := RectangleCreate(srcX, srcY, frameWidth, frameHeight);
  DrawTextureRec(tex, src, position, tint);
end;


// === Tekst ===

type
  TStringArray = array of String;

function W_SplitLines(const s: String): TStringArray;
var
  i, startIdx: Integer;
  ch: Char;
begin
  SetLength(Result, 0);
  if s = '' then Exit;

  startIdx := 1;
  i := 1;
  while i <= Length(s) do
  begin
    ch := s[i];
    if (ch = #10) or (ch = #13) then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Copy(s, startIdx, i - startIdx);

      // consume CRLF as one newline
      if (ch = #13) and (i < Length(s)) and (s[i + 1] = #10) then
        Inc(i);

      startIdx := i + 1;
    end;
    Inc(i);
  end;

  // last line (can be empty)
  SetLength(Result, Length(Result) + 1);
  Result[High(Result)] := Copy(s, startIdx, Length(s) - startIdx + 1);
end;

procedure ApplyFont;
begin
  SetTextFont(BuildFontString(GFontSize));
  // NIE czyścić cache tutaj
end;


function BuildFontString(const sizePx: Integer; const family: String = ''): String;
var
  fam: String;
begin
  if family <> '' then
    fam := family
  else
    fam := GFontFamily;

  // ZAWSZE ten sam format co w text-cache
  Result := IntToStr(sizePx) + 'px "' + fam + '", system-ui, sans-serif';
end;




procedure EnsureFont(const sizePx: Integer; const family: String = '');
var desired: String;
begin
  desired := BuildFontString(sizePx, family);
  if gCtx.font <> desired then
    WSetFont(desired);
end;
procedure SetFontSize(const sizePx: Integer);
begin
  if sizePx <> GFontSize then
  begin
    GFontSize := sizePx;
    ApplyFont;
  end;
end;

procedure SetFontFamily(const family: String);
begin
  if family <> GFontFamily then
  begin
    GFontFamily := family;
    ApplyFont;
  end;
end;

//randomy
function GetRandomValue(minVal, maxVal: Integer): Integer;
var lo, hi: Integer;
begin
  if minVal <= maxVal then begin lo := minVal; hi := maxVal; end
  else begin lo := maxVal; hi := minVal; end;
  Result := lo + Random(hi - lo + 1);
end;

function GetRandomFloat(minVal, maxVal: Double): Double;
var
  lo, hi, r: Double;
begin
  // obsługa odwróconych argumentów
  if minVal <= maxVal then
  begin
    lo := minVal;
    hi := maxVal;
  end
  else
  begin
    lo := maxVal;
    hi := minVal;
  end;

  // Random bez argumentu daje Double z [0,1)
  r := Random; // 0.0 <= r < 1.0
  Result := lo + r * (hi - lo);
end;

function GetRandomBool: Boolean;
begin
  // 50/50 true/false
  Result := Random < 0.5;
end;
// Proste rysowanie tekstu w punkcie
procedure DrawTextSimple(const text: String; pos: TVector2; fontSize: Integer; const color: TColor);
begin
  DrawText(text, Round(pos.x), Round(pos.y), fontSize, color);
end;

// Rysowanie tekstu wyśrodkowanego względem punktu
procedure DrawTextCentered(const text: String; center: TVector2; fontSize: Integer; const color: TColor);
var
  w, h: Double;
begin

  w := MeasureTextWidth(text, fontSize);
  h := MeasureTextHeight(text, fontSize);
  DrawText(text, Round(center.x - w / 2), Round(center.y - h / 2), fontSize, color);
end;

// Rysowanie tekstu wyrównanego do prawej
procedure DrawTextRightAligned(const text: String; rightPos: TVector2; fontSize: Integer; const color: TColor);
var
  w: Double;
begin
  w := MeasureTextWidth(text, fontSize);
  DrawText(text, Round(rightPos.x - w), Round(rightPos.y), fontSize, color);
end;

// Tekst z obramowaniem (outline)
procedure DrawTextOutlineAdv(const text: String; pos: TVector2; fontSize: Integer; const color, outlineColor: TColor; thickness: Integer);
var
  dx, dy: Integer;
begin
  for dy := -thickness to thickness do
    for dx := -thickness to thickness do
      if (dx <> 0) or (dy <> 0) then
        DrawText(text, Round(pos.x) + dx, Round(pos.y) + dy, fontSize, outlineColor);
  DrawText(text, Round(pos.x), Round(pos.y), fontSize, color);
end;

// Tekst z cieniem
procedure DrawTextShadow(const text: String; pos: TVector2; fontSize: Integer; const color, shadowColor: TColor; shadowOffset: TVector2);
begin
  DrawText(text, Round(pos.x + shadowOffset.x), Round(pos.y + shadowOffset.y), fontSize, shadowColor);
  DrawText(text, Round(pos.x), Round(pos.y), fontSize, color);
end;

procedure W_QueryFontMetrics(fontSize: Integer; out AAsc, ADesc: Double);
var
  m, ascJS, descJS: JSValue;
begin
  // Upewniamy się, że mamy pomocniczy canvas 2D
  W_InitMeasureCanvas;
  EnsureFont(fontSize);

  // Font pomocniczego kontekstu taki jak w głównym
  gMeasureCtx.font := gCtx.font;

  // Pomiar tekstu – WAŻNE: używamy gMeasureCtx, NIE gCtx
  m := gMeasureCtx.measureText('Hg');

  ascJS  := TJSObject(m)['actualBoundingBoxAscent'];
  descJS := TJSObject(m)['actualBoundingBoxDescent'];

  if not JS.isUndefined(ascJS) then
    AAsc := Double(ascJS)
  else
    AAsc := fontSize * 0.78;

  if not JS.isUndefined(descJS) then
    ADesc := Double(descJS)
  else
    ADesc := fontSize * 0.22;
end;

// ──────────────────────────────────────────────────────────────
// PIERWSZA WERSJA: DrawTextBoxed(...; borderColor; borderThickness)
// ──────────────────────────────────────────────────────────────
function StrPos(const subStr, s: String): Integer;
var
  i: Integer;
  L, LS: Integer;
begin
  L := Length(subStr);
  LS := Length(s);
  if (L = 0) or (LS = 0) or (L > LS) then
  begin
    Result := 0;
    Exit;
  end;

  for i := 1 to LS - L + 1 do
  begin
    if Copy(s, i, L) = subStr then
    begin
      Result := i;
      Exit;
    end;
  end;

  Result := 0;
end;

procedure DrawTextBoxed(const text: String; pos: TVector2; boxWidth: Integer;
  fontSize: Integer; const textColor: TColor; lineSpacing: Integer;
  const borderColor: TColor; borderThickness: Integer);
begin
  // Prosta wersja: brak dodatkowych korekt paddingu
  DrawTextBoxed(
    text,
    pos,
    boxWidth,
    fontSize,
    textColor,
    lineSpacing,
    borderColor,
    borderThickness,
    0,  // padTopAdjust
    0   // padBottomAdjust
  );
end;

procedure DrawTextBoxed(const text: String; pos: TVector2; boxWidth: Integer;
  fontSize: Integer; const textColor: TColor; lineSpacing: Integer;
  const borderColor: TColor; borderThickness: Integer;
  padTopAdjust: Integer; padBottomAdjust: Integer);
var
  words, lines: array of String;
  currentLine, tryLine: String;
  i: Integer;
  pad, padTop, padBottom: Integer;
  lineBox, lineH, totalH, strokeInset, topInside: Double;

  function Fits(const s: String): Boolean;
  begin
    // Używamy MeasureTextWidth – to samo API co DrawText
    Result := MeasureTextWidth(s, fontSize) <= (boxWidth - 2 * pad);
  end;

  procedure BreakLongWord(const w: String);
  var
    seg: String;
    k: Integer;
  begin
    seg := '';
    for k := 1 to Length(w) do
    begin
      if not Fits(seg + w[k]) then
      begin
        if seg <> '' then
        begin
          SetLength(lines, Length(lines)+1);
          lines[High(lines)] := seg + '-';
          seg := w[k];
        end
        else
        begin
          SetLength(lines, Length(lines)+1);
          lines[High(lines)] := w[k];
          seg := '';
        end;
      end
      else
        seg := seg + w[k];
    end;
    if seg <> '' then
    begin
      SetLength(lines, Length(lines)+1);
      lines[High(lines)] := seg;
    end;
  end;

begin
  if text = '' then Exit;

  pad := 4;
  padTop := pad + padTopAdjust;
  if padTop < 0 then padTop := 0;
  padBottom := pad + padBottomAdjust;
  if padBottom < 0 then padBottom := 0;

  // 1) wysokość linii – korzystamy z MeasureTextHeight,
  //    które używa tego samego mechanizmu fontów co DrawText.
  lineBox := MeasureTextHeight('Hg', fontSize);
  lineH   := lineBox + lineSpacing;

  // 2) zawijanie tekstu
  words := text.Split([' ']);
  SetLength(lines, 0);
  currentLine := '';

  for i := 0 to High(words) do
  begin
    if currentLine = '' then
      tryLine := words[i]
    else
      tryLine := currentLine + ' ' + words[i];

    if Fits(tryLine) then
      currentLine := tryLine
    else
    begin
      if currentLine <> '' then
      begin
        SetLength(lines, Length(lines)+1);
        lines[High(lines)] := currentLine;
        currentLine := '';
      end;

      if not Fits(words[i]) then
        BreakLongWord(words[i])
      else
        currentLine := words[i];
    end;
  end;

  if currentLine <> '' then
  begin
    SetLength(lines, Length(lines)+1);
    lines[High(lines)] := currentLine;
  end;

  // 3) obrys + pozycjonowanie
  strokeInset := borderThickness * 0.5;
  topInside   := pos.y + strokeInset + padTop;

  // 4) rysowanie tekstu – używamy DrawText, który już szanuje GFontFamily / WithFont
  for i := 0 to High(lines) do
    DrawText(lines[i],
      Round(pos.x + pad),
      Round(topInside + i * lineH),
      fontSize,
      textColor);

  // 5) wysokość ramki
  if Length(lines) > 0 then
    totalH := (strokeInset * 2) + padTop + padBottom +
              (Length(lines) * lineBox) +
              ((Length(lines) - 1) * lineSpacing)
  else
    totalH := (strokeInset * 2) + padTop + padBottom + lineBox;

  DrawRectangleLines(
    Round(pos.x), Round(pos.y),
    boxWidth, Round(totalH),
    borderColor, borderThickness
  );
end;

// Tekst na okręgu
procedure DrawTextOnCircle(const text: String; center: TVector2; radius: Double; startAngle: Double; fontSize: Integer; const color: TColor);
var
  i: Integer;
  angleStep: Double;
  charPos: TVector2;
  ch: String;
begin
  if Length(text) = 0 then Exit;
  angleStep := 360 / Length(text);

  for i := 0 to Length(text) - 1 do
  begin
    charPos.x := center.x + radius * Cos(DegToRad(startAngle + i * angleStep));
    charPos.y := center.y + radius * Sin(DegToRad(startAngle + i * angleStep));
    ch := text[i+1];
    DrawTextCentered(ch, charPos, fontSize, color);
  end;
end;

// Tekst z gradientem (poziomy)
procedure DrawTextGradient(const text: String; pos: TVector2; fontSize: Integer; const color1, color2: TColor);
var
  i: Integer;
  t: Double;
  c: TColor;
  x: Double;
  ch: String;
begin
  x := pos.x;
  for i := 1 to Length(text) do
  begin
    t := (i - 1) / Max(1, (Length(text) - 1));
    c := color1.Blend(color2, t);
    ch := text[i];
    DrawText(ch, Round(x), Round(pos.y), fontSize, c);
    x += MeasureTextWidth(ch, fontSize);
  end;
end;

procedure DrawTextureV(const tex: TTexture; position: TInputVector; const tint: TColor);
begin
  DrawTexture(tex, Round(position.x), Round(position.y), tint);
end;


function WGetTextureKey(const tex: TTexture): LongWord; inline;
var
  cnv: TJSHTMLCanvasElement;
  key: JSValue;
begin
  // Stabilny, unikalny klucz przypięty do obiektu canvasu.
  // Nie używamy asm, bo asm nie mapuje nazw pascalowych do $impl.* i kończy się to
  // "ReferenceError: gTexKeyCounter is not defined" w JS.
  cnv := tex.canvas;
  if cnv = nil then Exit(0);

  key := TJSObject(cnv)['__wilgaTintKey'];
  if (key <> Undefined) and (key <> Null) then
    Exit(LongWord(key));

  Result := gTexKeyCounter;
  Inc(gTexKeyCounter);
  TJSObject(cnv)['__wilgaTintKey'] := Result;
end;

procedure DrawTexturePro(const tex: TTexture; const src, dst: TRectangle;
  origin: TVector2; rotationDeg: Double; const tint: TColor);
const
  EPS = 1e-6;
var
  // źródło w teksturze
  sx, sy, sw, sh: Double;
  // docelowy rect
  dx, dy, dw, dh: Double;
  // origin (pivot) w przestrzeni docelowej
  ox, oy: Double;
  // rotacja w radianach
  rad: Double;
  // tint / alpha
  useTint, alphaOnly: Boolean;
  // strażnik stanu canvasa
  G: TCanvasStateGuard;
  // pomocnicze: skala względem źródła
  scaleX, scaleY: Double;

  maxSX, maxSY: Double;
  tintedTex: TTexture;

  function CeilAbs(a: Double): Integer; inline;
  begin
    Result := Ceil(Abs(a));
  end;

  procedure ClampSrcToTextureBounds;
  begin
    if sx < 0 then begin sw := sw + sx; sx := 0; end;
    if sy < 0 then begin sh := sh + sy; sy := 0; end;

    maxSX := tex.width  - sx;
    maxSY := tex.height - sy;

    if sw > maxSX then sw := maxSX;
    if sh > maxSY then sh := maxSY;
  end;

begin
  // sanity check tekstury
  if (tex.canvas = nil) or (tex.width <= 0) or (tex.height <= 0) then Exit;
  if tint.a = 0 then Exit;
  // --- normalizacja src ---
  sx := src.x;
  sy := src.y;
  sw := src.width;
  sh := src.height;

  // pozwalamy na ujemne width/height w src (odwrócenie)
  if sw < 0 then begin sx += sw; sw := -sw; end;
  if sh < 0 then begin sy += sh; sh := -sh; end;

  if (sw <= 0) or (sh <= 0) or (dst.width = 0) or (dst.height = 0) then Exit;

  // przytnij src do granic tekstury
  ClampSrcToTextureBounds;
  if (sw <= 0) or (sh <= 0) then Exit;

  // dst / origin
  dw := dst.width;
  dh := dst.height;
  ox := origin.x;
  oy := origin.y;

  // pozycja lewego-górnego rogu (z uwzględnieniem origin)
  dx := dst.x - ox;
  dy := dst.y - oy;

  // rotacja w radianach
  rad := rotationDeg * PI / 180.0;

  // flagi tintu
  useTint :=
    not ((tint.r = 255) and (tint.g = 255) and (tint.b = 255) and (tint.a = 255));
  alphaOnly :=
         ((tint.r = 255) and (tint.g = 255) and (tint.b = 255) and (tint.a <> 255));

  // skala względem źródła
  scaleX := dw / sw;
  scaleY := dh / sh;

  BeginCanvasState(G);
  try
    // nie ruszamy tutaj blend mode – obowiązuje to, co ustawił SetBlendMode
    WSetAlpha(1.0);

    // ─────────────────────────────────────────────────────────────
    // SZYBKA ŚCIEŻKA: brak rotacji |rad| ~ 0
    // ─────────────────────────────────────────────────────────────
    if Abs(rad) < EPS then
    begin
      if not useTint then
      begin
        // bez tintu – zwykłe drawImage z aktualnym blend mode
        gCtx.drawImage(tex.canvas, sx, sy, sw, sh, dx, dy, dw, dh);
      end
      else if alphaOnly then
      begin
        // tylko alfa – zmieniamy tylko globalAlpha
        WSetAlpha(tint.a / 255.0);
        gCtx.drawImage(tex.canvas, sx, sy, sw, sh, dx, dy, dw, dh);
        WSetAlpha(1.0);
      end
      else
      begin
        // PEŁNY TINT (bez rotacji) – przez TintCache (RGB), alpha osobno

        tintedTex := GetTintedTexture(tex, WGetTextureKey(tex), ColorCreate(tint.r, tint.g, tint.b, tint.a));
        WSetAlpha(1.0);
        gCtx.drawImage(tintedTex.canvas, sx, sy, sw, sh, dx, dy, dw, dh);
        WSetAlpha(1.0);
      end;

      Exit;
    end;

    // ─────────────────────────────────────────────────────────────
    // ROTACJA (ogólna ścieżka) – ten sam tint co wyżej
    // ─────────────────────────────────────────────────────────────

    // pracujemy na transformacji gCtx, ale z zachowaniem kamery (BeginCanvasState)
    gCtx.save;
    try
      // pivot (dst.x, dst.y) + origin – jak w raylib DrawTexturePro
      // dst.x, dst.y – pozycja punktu, wokół którego obracamy
      gCtx.translate(dst.x, dst.y);
      gCtx.rotate(rad);

      // skalowanie względem źródła
      gCtx.scale(scaleX, scaleY);

      // przenosimy układ tak, żeby origin był w (0,0)
      gCtx.translate(-ox, -oy);

      if not useTint then
      begin
        // bez tintu – jedno drawImage, z aktualnym blend mode
        gCtx.drawImage(tex.canvas, sx, sy, sw, sh, 0, 0, sw, sh);
      end
      else if alphaOnly then
      begin
        // tylko alfa – rysujemy raz z globalną alfą
        WSetAlpha(tint.a / 255.0);
        gCtx.drawImage(tex.canvas, sx, sy, sw, sh, 0, 0, sw, sh);
        WSetAlpha(1.0);
      end
      else
      begin
        // PEŁNY TINT z obrotem – przez TintCache (RGB), alpha osobno

        tintedTex := GetTintedTexture(tex, WGetTextureKey(tex), ColorCreate(tint.r, tint.g, tint.b, tint.a));
        WSetAlpha(1.0);
        gCtx.drawImage(tintedTex.canvas, sx, sy, sw, sh, 0, 0, sw, sh);
        WSetAlpha(1.0);
      end;

    finally
      gCtx.restore;

      WResetShadow;
    end;

  finally
    EndCanvasState(G);
  end;
end;


function TextureIsReady(const tex: TTexture): Boolean;
begin
  Result := tex.loaded and (tex.width>0) and (tex.height>0) and (tex.canvas<>nil);
end;
procedure WaitTextureReady(const tex: TTexture; const OnReady, OnTimeout: TNoArgProc; msTimeout: Integer = 10000);
var
  t0: Double;
  procedure Check(ts: Double);
  begin
    if TextureIsReady(tex) then
    begin
      if Assigned(OnReady) then OnReady();
    end
    else if (window.performance.now - t0) >= msTimeout then
    begin
      if Assigned(OnTimeout) then OnTimeout();
    end
    else
      window.requestAnimationFrame(@Check);
  end;
begin
  t0 := window.performance.now;
  window.requestAnimationFrame(@Check);
end;

procedure WaitAllTexturesReady(const arr: array of TTexture; const OnReady: TNoArgProc);
  function AllReady: Boolean;
  var
    i: Integer;
  begin
    Result := Length(arr) > 0;
    for i := Low(arr) to High(arr) do
      if not (arr[i].loaded and (arr[i].width > 0) and (arr[i].height > 0) and (arr[i].canvas <> nil)) then
        Exit(False);
  end;
  procedure Check(ts: Double);
  begin
    if AllReady then
    begin
      if Assigned(OnReady) then OnReady();
    end
    else
      window.requestAnimationFrame(@Check);
  end;
begin
  window.requestAnimationFrame(@Check);
end;

{ ====== ZDARZENIA MYSZY ====== }





function GetMousePosition: TInputVector;
var
  nowMS: TTimeMS;
begin
  nowMS := _NowMS;

  // jeśli jeszcze trwa okno „klikowe” – oddaj pozycję z pointerdown
  if nowMS <= W_MouseLatchUntilMS then
  begin
    Result.x := W_MouseLatchX;
    Result.y := W_MouseLatchY;
    Exit;
  end;

  // inaczej bieżącą
  Result := gMousePos;
end;

function GetMouseDelta: TInputVector; begin Result := NewVector(gMousePos.x - gMousePrevPos.x, gMousePos.y - gMousePrevPos.y); end;

{ ====== ZARZĄDZANIE CZASEM ====== }
procedure WaitTime(ms: Double);
var
  start: Double;
begin
  // Busy-wait (tylko debug); nie używać w produkcji.
  start := window.performance.now();
  while (window.performance.now() - start) < ms do ;
end;

{ ====== MATEMATYKA ====== }
function Lerp(start, stop, amount: Double): Double;
begin
  Result := start + amount * (stop - start);
end;

function Normalize(value, start, stop: Double): Double;
begin
  if start = stop then Exit(0.0);
  Result := (value - start) / (stop - start);
end;

function Map(value, inStart, inStop, outStart, outStop: Double): Double;
begin
  if inStart = inStop then Exit(outStart);
  Result := outStart + (outStop - outStart) * ((value - inStart) / (inStop - inStart));
end;

function Max(a, b: Double): Double; begin if a > b then Result := a else Result := b; end;
function Min(a, b: Double): Double; begin if a < b then Result := a else Result := b; end;

function Clamp(value, minVal, maxVal: Double): Double;
begin
  if value < minVal then Exit(minVal);
  if value > maxVal then Exit(maxVal);
  Result := value;
end;

function MaxI(a, b: Integer): Integer; begin if a > b then Result := a else Result := b; end;
function MinI(a, b: Integer): Integer; begin if a < b then Result := a else Result := b; end;
function ClampI(value, minVal, maxVal: Integer): Integer;
begin
  if value < minVal then Exit(minVal);
  if value > maxVal then Exit(maxVal);
  Result := value;
end;

function SmoothStep(edge0, edge1, x: Double): Double;
var
  t: Double;
begin
  t := Clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
  Result := t * t * (3.0 - 2.0 * t);
end;

function Approach(current, target, delta: Double): Double;
begin
  if current < target then
    Result := Min(current + delta, target)
  else if current > target then
    Result := Max(current - delta, target)
  else
    Result := target;
end;
function PlayBuffer(const buf: TJSAudioBuffer; looped: Boolean): TSoundInstance;
var
  src : TJSAudioBufferSourceNode;
  gain: TJSGainNode;
  inst: TSoundInstance;
begin
  InitAudio;
  ResumeAudioIfNeeded;

  src := gAudioCtx.createBufferSource;
  src.buffer := buf;
  src.loop := looped;

  gain := gAudioCtx.createGain;
  gain.gain.value := 1.0; // na razie bez regulacji głośności per dźwięk

  src.connect(gain);
  gain.connect(gMasterGain);

  inst := TSoundInstance.Create;
  inst.source := src;
  inst.gain   := gain;
  inst.looped := looped;
  inst.playing := True;

  {$ifdef WILGA_DEBUG} DBG_Inc(dbg_AudioElemsAlive); {$endif}
  SetLength(gActiveSounds, Length(gActiveSounds)+1);
  gActiveSounds[High(gActiveSounds)] := inst;

  StartSource(src, 0);


  Result := inst;
end;



{ ====== DŹWIĘK ====== }
function PlaySound(const url: String): Boolean;
var
  onResponse    : reference to function (v: JSValue): JSValue;
  onArrayBuffer : reference to function (v: JSValue): JSValue;
  onDecoded     : reference to function (v: JSValue): JSValue;
begin
  InitAudio;
  ResumeAudioIfNeeded;
  Result := True; // samo zainicjowanie łańcucha jest OK

  // 3) Po zdekodowaniu AudioBuffer -> odtwarzamy jednorazowo
  onDecoded :=
    function (v: JSValue): JSValue
    var
      buf: TJSAudioBuffer;
    begin
      buf := TJSAudioBuffer(v);
      PlayBuffer(buf, False);
      Result := nil; // wynik tej funkcji (JS Promise callback)
    end;

  // 2) Po otrzymaniu ArrayBuffer -> decodeAudioData
  onArrayBuffer :=
    function (v: JSValue): JSValue
    var
      ab: TJSArrayBuffer;
    begin
      ab := TJSArrayBuffer(v);
      gAudioCtx.decodeAudioData(ab)._then(onDecoded);
      Result := nil;
    end;

  // 1) Po fetch(url) -> bierzemy Response i wołamy arrayBuffer()
  onResponse :=
    function (v: JSValue): JSValue
    var
      res: TJSResponse;
    begin
      res := TJSResponse(v);
      res.arrayBuffer()._then(onArrayBuffer);
      Result := nil;
    end;

  window.fetch(url)._then(onResponse);
end;


function PlaySoundLoop(const url: String): Boolean;
var
  onResponse    : reference to function (v: JSValue): JSValue;
  onArrayBuffer : reference to function (v: JSValue): JSValue;
  onDecoded     : reference to function (v: JSValue): JSValue;
begin
  InitAudio;
  ResumeAudioIfNeeded;
  Result := True;

  onDecoded :=
    function (v: JSValue): JSValue
    var
      buf: TJSAudioBuffer;
    begin
      buf := TJSAudioBuffer(v);
      PlayBuffer(buf, True);   // TU różnica: True = loop
      Result := nil;
    end;

  onArrayBuffer :=
    function (v: JSValue): JSValue
    var
      ab: TJSArrayBuffer;
    begin
      ab := TJSArrayBuffer(v);
      gAudioCtx.decodeAudioData(ab)._then(onDecoded);
      Result := nil;
    end;

  onResponse :=
    function (v: JSValue): JSValue
    var
      res: TJSResponse;
    begin
      res := TJSResponse(v);
      res.arrayBuffer()._then(onArrayBuffer);
      Result := nil;
    end;

  window.fetch(url)._then(onResponse);
end;

procedure StopAllSounds;
var
  i: Integer;
begin
  // 1) Zatrzymaj i zwolnij wszystkie aktywne instancje
  for i := 0 to High(gActiveSounds) do
  begin
    if gActiveSounds[i] <> nil then
    begin
      try
        gActiveSounds[i].Stop;
      except
      end;

      try
        gActiveSounds[i].Free;
      except
      end;

      {$ifdef WILGA_DEBUG} DBG_Dec(dbg_AudioElemsAlive); {$endif}
      gActiveSounds[i] := nil;
    end;
  end;
  SetLength(gActiveSounds, 0);

  // 2) Wyczyść wskaźniki pętli w poolach (żeby nie wskazywały na zwolnione obiekty)
  for i := 0 to High(gSoundPools) do
    gSoundPools[i].activeLoop := nil;
end;



function LoadSoundEx(const url: String; voices: Integer = 4;
  volume: Double = 1.0; looped: Boolean = False): TSoundHandle;
var
  h            : Integer;
  onResponse   : reference to function (v: JSValue): JSValue;
  onArrayBuffer: reference to function (v: JSValue): JSValue;
  onDecoded    : reference to function (v: JSValue): JSValue;
begin
  InitAudio;
  ResumeAudioIfNeeded;

  if volume < 0 then volume := 0
  else if volume > 1 then volume := 1;

  // nowy slot (możesz dodać reuse po url, jeśli chcesz)
  SetLength(gSoundPools, Length(gSoundPools)+1);
  h := High(gSoundPools);

  gSoundPools[h].url           := url;
  gSoundPools[h].buffer        := nil;
  gSoundPools[h].defaultVolume := volume;
  gSoundPools[h].looped        := looped;
  gSoundPools[h].valid         := False;
  gSoundPools[h].activeLoop    := nil;

  Result := h;

  // Promise 1: po decodeAudioData
  onDecoded :=
    function (v: JSValue): JSValue
    var
      buf: TJSAudioBuffer;
    begin
      buf := TJSAudioBuffer(v);
      gSoundPools[h].buffer := buf;
      gSoundPools[h].valid  := True;
      Result := nil;
    end;

  // Promise 2: po arrayBuffer()
  onArrayBuffer :=
    function (v: JSValue): JSValue
    var
      ab: TJSArrayBuffer;
    begin
      ab := TJSArrayBuffer(v);
      gAudioCtx.decodeAudioData(ab)._then(onDecoded);
      Result := nil;
    end;

  // Promise 3: po fetch(url)
  onResponse :=
    function (v: JSValue): JSValue
    var
      res: TJSResponse;
    begin
      res := TJSResponse(v);
      res.arrayBuffer()._then(onArrayBuffer);
      Result := nil;
    end;

  window.fetch(url)._then(onResponse);
end;

procedure UnloadSoundEx(handle: TSoundHandle);
var
  p: ^TSoundPool;
begin
  if (handle < 0) or (handle > High(gSoundPools)) then Exit;

  p := @gSoundPools[handle];

  StopSoundEx(handle);

  p^.buffer := nil;
  p^.valid  := False;
  p^.url    := '';
end;
procedure PlaySoundEx(handle: TSoundHandle; volume: Double);
var
  p: ^TSoundPool;
  v: Double;
 inst: TSoundInstance; // <-- typ z kroku 1
begin
  if (handle < 0) or (handle > High(gSoundPools)) then Exit;

  p := @gSoundPools[handle];
  if (not p^.valid) or (p^.buffer = nil) then Exit;

  if volume < 0 then
    v := p^.defaultVolume
  else
    v := volume;

  if v < 0 then v := 0 else if v > 1 then v := 1;

  if p^.looped then
  begin
    // zatrzymaj poprzednią pętlę
    if p^.activeLoop <> nil then
    begin
      p^.activeLoop.Stop;
      p^.activeLoop.Free;
      {$ifdef WILGA_DEBUG} DBG_Dec(dbg_AudioElemsAlive); {$endif}
      p^.activeLoop := nil;
    end;

    p^.activeLoop := CreateInstanceFromBuffer(p^.buffer, v, True);
  end
  else
  begin
    // jednorazowy efekt – nie musimy przechowywać instancji
 inst := CreateInstanceFromBuffer(p^.buffer, v, False);

SetLength(gActiveOneshots, Length(gActiveOneshots) + 1);
gActiveOneshots[High(gActiveOneshots)] := inst;
  end;
end;

procedure PlaySoundEx(handle: TSoundHandle);
begin
  PlaySoundEx(handle, -1.0);
end;
procedure PlaySoundEx(handle: TSoundHandle; volume, pitch, pan: Double);
var
  p: ^TSoundPool;
  v: Double;
    inst: TSoundInstance;
begin
  if (handle < 0) or (handle > High(gSoundPools)) then Exit;

  p := @gSoundPools[handle];
  if (not p^.valid) or (p^.buffer = nil) then Exit;

  if volume < 0 then
    v := p^.defaultVolume
  else
    v := volume;

  if v < 0 then v := 0 else if v > 1 then v := 1;

  // pętla (np. muzyka) – restartujemy z nowymi parametrami
  if p^.looped then
  begin
    if p^.activeLoop <> nil then
    begin
      p^.activeLoop.Stop;
      p^.activeLoop.Free;
      {$ifdef WILGA_DEBUG} DBG_Dec(dbg_AudioElemsAlive); {$endif}
      p^.activeLoop := nil;
    end;

    p^.activeLoop := CreateInstanceFromBuffer(p^.buffer, v, pitch, pan, True);
  end
  else
  begin
    // jednorazowy efekt – po prostu odpal z tym pitch/pan
   inst := CreateInstanceFromBuffer(p^.buffer, v, pitch, pan, False);

SetLength(gActiveOneshots, Length(gActiveOneshots) + 1);
gActiveOneshots[High(gActiveOneshots)] := inst;

  end;
end;



procedure StopSoundEx(handle: TSoundHandle);
var
  p: ^TSoundPool;
begin
  if (handle < 0) or (handle > High(gSoundPools)) then Exit;

  p := @gSoundPools[handle];
  if p^.activeLoop <> nil then
  begin
    p^.activeLoop.Stop;
    p^.activeLoop.Free;
    {$ifdef WILGA_DEBUG} DBG_Dec(dbg_AudioElemsAlive); {$endif}
    p^.activeLoop := nil;
  end;
end;

procedure SetSoundVolume(handle: TSoundHandle; volume: Double);
var
  p: ^TSoundPool;
begin
  if (handle < 0) or (handle > High(gSoundPools)) then Exit;

  // clamp
  if volume < 0 then volume := 0
  else if volume > 1 then volume := 1;

  p := @gSoundPools[handle];
  p^.defaultVolume := volume;

  // JEŚLI jest aktywna pętla (np. muzyka) – zmień jej głośność TERAZ
  if (p^.activeLoop <> nil) and (p^.activeLoop.gain <> nil) then
    p^.activeLoop.gain.gain.value := volume;
end;


procedure SetSoundLoop(handle: TSoundHandle; looped: Boolean);
var
  p: ^TSoundPool;
begin
  if (handle < 0) or (handle > High(gSoundPools)) then Exit;

  p := @gSoundPools[handle];
  p^.looped := looped;
end;
{ ====== FABRYKI ====== }
function NewVector(ax, ay: Double): TInputVector; begin Result.x := ax; Result.y := ay; end;
function Vector2Create(x, y: Double): TInputVector; begin Result := NewVector(x, y); end;
function ColorRGBA(ar, ag, ab, aa: Integer): TColor; begin Result.r:=ar; Result.g:=ag; Result.b:=ab; Result.a:=aa; end;
function ColorCreate(r, g, b, a: Integer): TColor; begin Result := ColorRGBA(r,g,b,a); end;
function _Clamp01(x: Double): Double; inline;
begin
  if x < 0 then Exit(0);
  if x > 1 then Exit(1);
  Exit(x);
end;

function _ClampByte(x: Double): Integer; inline;
begin
  if x < 0 then Exit(0);
  if x > 255 then Exit(255);
  Exit(Round(x));
end;

procedure ColorToHSV(const c: TColor; out h, s, v: Double);
var
  r, g, b: Double;
  maxc, minc, d: Double;
begin
  r := c.r / 255.0;
  g := c.g / 255.0;
  b := c.b / 255.0;
  maxc := Max(r, Max(g, b));
  minc := Min(r, Min(g, b));
  v := maxc;
  d := maxc - minc;
  if maxc = 0 then
    s := 0
  else
    s := d / maxc;

  if d = 0 then
  begin
    h := 0;
    Exit;
  end;

  if maxc = r then
    h := (g - b) / d + (Ord(g < b) * 6)
  else if maxc = g then
    h := (b - r) / d + 2
  else
    h := (r - g) / d + 4;

  h := h / 6 * 360.0;
end;

function ColorFromHSV(h, s, v: Double; a: Integer): TColor;
var
  c, x, m: Double;
  r1, g1, b1: Double;
  hh: Double;
  k: Integer;
begin
  s := _Clamp01(s);
  v := _Clamp01(v);
  while h < 0 do h := h + 360;
  while h >= 360 do h := h - 360;
  c := v * s;
  hh := h / 60.0;
  k := Trunc(hh);
  x := c * (1 - abs(frac(hh) * 2 - 1));
  case k of
    0: begin r1 := c; g1 := x; b1 := 0; end;
    1: begin r1 := x; g1 := c; b1 := 0; end;
    2: begin r1 := 0; g1 := c; b1 := x; end;
    3: begin r1 := 0; g1 := x; b1 := c; end;
    4: begin r1 := x; g1 := 0; b1 := c; end;
  else
    begin r1 := c; g1 := 0; b1 := x; end;
  end;
  m := v - c;
  Result := ColorCreate(_ClampByte((r1 + m) * 255.0),
                        _ClampByte((g1 + m) * 255.0),
                        _ClampByte((b1 + m) * 255.0),
                        a);
end;

procedure ColorToHSL(const c: TColor; out h, s, l: Double);
var
  r, g, b: Double;
  maxc, minc, d: Double;
begin
  r := c.r / 255.0;
  g := c.g / 255.0;
  b := c.b / 255.0;
  maxc := Max(r, Max(g, b));
  minc := Min(r, Min(g, b));
  l := (maxc + minc) / 2.0;

  if maxc = minc then
  begin
    s := 0;
    h := 0;
    Exit;
  end;

  d := maxc - minc;
  if l > 0.5 then
    s := d / (2.0 - maxc - minc)
  else
    s := d / (maxc + minc);

  if maxc = r then
    h := (g - b) / d + (Ord(g < b) * 6)
  else if maxc = g then
    h := (b - r) / d + 2
  else
    h := (r - g) / d + 4;

  h := h / 6 * 360.0;
end;

function _HueToRGB(p, q, t: Double): Double; inline;
begin
  if t < 0 then t := t + 1;
  if t > 1 then t := t - 1;
  if t < 1/6 then Exit(p + (q - p) * 6 * t);
  if t < 1/2 then Exit(q);
  if t < 2/3 then Exit(p + (q - p) * (2/3 - t) * 6);
  Exit(p);
end;

function ColorFromHSL(h, s, l: Double; a: Integer): TColor;
var
  r, g, b: Double;
  q, p: Double;
  hh: Double;
begin
  s := _Clamp01(s);
  l := _Clamp01(l);
  while h < 0 do h := h + 360;
  while h >= 360 do h := h - 360;
  if s = 0 then
  begin
    r := l; g := l; b := l;
  end
  else
  begin
    if l < 0.5 then q := l * (1 + s)
    else q := l + s - l * s;
    p := 2 * l - q;
    hh := h / 360.0;
    r := _HueToRGB(p, q, hh + 1/3);
    g := _HueToRGB(p, q, hh);
    b := _HueToRGB(p, q, hh - 1/3);
  end;
  Result := ColorCreate(_ClampByte(r * 255.0),
                        _ClampByte(g * 255.0),
                        _ClampByte(b * 255.0),
                        a);
end;

function ColorSaturate(const c: TColor; factor: Double): TColor;
var
  h, s, v: Double;
begin
  ColorToHSV(c, h, s, v);
  s := _Clamp01(s * factor);
  Result := ColorFromHSV(h, s, v, c.a);
end;

function ColorLighten(const c: TColor; factor: Double): TColor;
var
  h, s, l: Double;
begin
  // factor in [-1..1]
  ColorToHSL(c, h, s, l);
  l := _Clamp01(l + factor);
  Result := ColorFromHSL(h, s, l, c.a);
end;

function ColorBlend(const c1, c2: TColor; t: Double): TColor;
begin
  t := _Clamp01(t);
  Result := ColorCreate(
    _ClampByte(c1.r + (c2.r - c1.r) * t),
    _ClampByte(c1.g + (c2.g - c1.g) * t),
    _ClampByte(c1.b + (c2.b - c1.b) * t),
    _ClampByte(c1.a + (c2.a - c1.a) * t)
  );
end;

function RectangleCreate(x, y, width, height: Double): TRectangle; begin Result.x:=x; Result.y:=y; Result.width:=width; Result.height:=height; end;
function LineCreate(startX, startY, endX, endY: Double): TLine; begin Result.startPoint := NewVector(startX, startY); Result.endPoint := NewVector(endX, endY); end;
function TriangleCreate(p1x, p1y, p2x, p2y, p3x, p3y: Double): TTriangle; begin Result.p1 := NewVector(p1x, p1y); Result.p2 := NewVector(p2x, p2y); Result.p3 := NewVector(p3x, p3y); end;

{ ====== WEKTORY ====== }
function Vector2Zero: TInputVector; begin Result := NewVector(0,0); end;
function Vector2One: TInputVector; begin Result := NewVector(1,1); end;
function Vector2Add(v1, v2: TInputVector): TInputVector; begin Result := NewVector(v1.x+v2.x, v1.y+v2.y); end;
function Vector2Subtract(v1, v2: TInputVector): TInputVector; begin Result := NewVector(v1.x-v2.x, v1.y-v2.y); end;
function Vector2Scale(v: TInputVector; scale: Double): TInputVector; begin Result := NewVector(v.x*scale, v.y*scale); end;
function Vector2Length(v: TInputVector): Double; begin Result := Sqrt(v.x*v.x + v.y*v.y); end;

function Vector2Normalize(v: TInputVector): TInputVector;
var len: Double;
begin
  len := Vector2Length(v);
  if len > 0 then Result := Vector2Scale(v, 1.0/len) else Result := Vector2Zero;
end;

function Vector2Rotate(v: TInputVector; radians: Double): TInputVector;
var c, s: Double;
begin
  c := Cos(radians); s := Sin(radians);
  Result := NewVector(v.x*c - v.y*s, v.x*s + v.y*c);
end;

function Vector2RotateDeg(v: TInputVector; deg: Double): TInputVector;
begin
  Result := Vector2Rotate(v, DegToRad(deg));
end;

function Vector2Dot(a, b: TInputVector): Double; begin Result := a.x*b.x + a.y*b.y; end;
function Vector2Perp(v: TInputVector): TInputVector; begin Result := NewVector(-v.y, v.x); end;
function Vector2Lerp(a, b: TInputVector; t: Double): TInputVector; begin Result := NewVector(Lerp(a.x,b.x,t), Lerp(a.y,b.y,t)); end;
function Vector2Distance(v1, v2: TInputVector): Double; begin Result := Sqrt(Sqr(v1.x - v2.x) + Sqr(v1.y - v2.y)); end;
function Vector2Angle(v1, v2: TInputVector): Double; begin Result := ArcTan2(v2.y - v1.y, v2.x - v1.x); end;

{ ====== OKNO / INICJALIZACJA ====== }

procedure InstallAudioShutdownHooks;
begin
  if gAudioShutdownHooksInstalled then Exit;
  gAudioShutdownHooksInstalled := True;

  window.addEventListener('pagehide', TJSRawEventHandler(
    procedure (e: TJSEvent)
    begin
      try
        if gMasterGain <> nil then
          gMasterGain.gain.value := 0;
      except end;

      try
        if gAudioCtx <> nil then
          gAudioCtx.suspend();
      except end;
    end
  ), True);

  window.addEventListener('beforeunload', TJSRawEventHandler(
    procedure (e: TJSEvent)
    begin
      try
        if gMasterGain <> nil then
          gMasterGain.gain.value := 0;
      except end;

      try
        if gAudioCtx <> nil then
          gAudioCtx.suspend();
      except end;
    end
  ), True);
end;

procedure InitWindow(awidth, aheight: Integer; const title: String);
var
  el: TJSElement;
  cw, ch: Integer;
  opts: TJSObject;
  i: Integer;
  const
  DUP_WINDOW_MS = 60.0; // okno na „duplikat” (ms) – możesz dać 30–60
begin

  // Jeśli DOM niegotowy – opóźnij inicjalizację
  if (document.body = nil) then
  begin
    window.addEventListener('load', TJSRawEventHandler(
      procedure (e: TJSEvent)
      begin
        InitWindow(awidth, aheight, title);
      end
    ));
    Exit;
  end;

  gStartTime := window.performance.now();
  document.title := title;
  InstallAudioShutdownHooks;
  InitTintCache(256);

  cw := awidth; ch := aheight;

  // Canvas
  el := document.querySelector('#game');
  if (el = nil) then
  begin
    gCanvas := TJSHTMLCanvasElement(document.createElement('canvas'));
    gCanvas.id := 'game';
    document.body.appendChild(gCanvas);
  end
  else
    gCanvas := TJSHTMLCanvasElement(el);

  // Rozmiary CSS (logiczne)
  gCanvas.style.setProperty('width',  IntToStr(cw) + 'px');
  gCanvas.style.setProperty('height', IntToStr(ch) + 'px');

  // DPR / HiDPI
    // DPR / HiDPI
  gDPR := window.devicePixelRatio;
  if (not gUseHiDPI) or (gDPR <= 0) then gDPR := 1;
  WilgaResize(gCanvas, cw, ch, gDPR);

  // Canvas pomocniczy do measureText – raz na okno
  W_InitMeasureCanvas;

  // Kontekst 2D: najpierw próba Offscreen + Worker, potem fallback
  opts := TJSObject.new;
  opts['alpha'] := gCanvasAlpha;

  // 1) Spróbuj naszego Offscreen/Worker initu (proxy)
  gCtx := WilgaInitContextFromCanvas(gCanvas);

  // 2) Jeśli się nie udało (np. brak OffscreenCanvas/Worker) – zwykły 2D
  if gCtx = nil then
    gCtx := TJSCanvasRenderingContext2D(gCanvas.getContext('2d', opts));

  gCtx.setTransform(gDPR, 0, 0, gDPR, 0, 0);
  TJSObject(gCtx)['imageSmoothingEnabled'] := gImageSmoothingWanted;
  WAttachToCurrentState(gCanvas, gCtx);


  // ===== Stany wejścia itp. =====
  // ===== Stany wejścia itp. =====
  gKeys := TJSObject.new;
  gKeysPressed := TJSObject.new;
  gKeysReleased := TJSObject.new;
  gKeyPressedUntil := TJSObject.new; // NEW: ensure exists before first keydown
  gKeyLastDown := TJSObject.new;     // NEW: mapa czasów ostatniego keydown


  gMousePos := NewVector(cw / 2, ch / 2);
  gMousePrevPos := gMousePos;
  for i := 0 to 2 do
  begin
    gMouseButtonsDown[i] := false;
    gMouseButtonsPrev[i] := false;
  end;
  gMouseWheelDelta := 0;

  gProfileData := TJSObject.new;

  // Focus na canvasie
  gCanvas.tabIndex := 0;
  gCanvas.style.setProperty('outline', 'none');
  gCanvas.focus();

  // ===== Handlery (zapisywane w globalnych zmiennych) =====  to dobre miejsce

  // --- Klawiatura ---
  // --- Klawiatura ---


onKeyDownH := function (event: TJSEvent): boolean
var
  e: TJSKeyBoardEvent;
  k: String;
  isRepeat: Boolean;
  wasDown: Boolean;
  nowTime, lastTime: Double;
begin
  e := TJSKeyBoardEvent(event);

  // === NORMALIZACJA KLUCZA ===
  k := e.code;
  if (k = '') then k := e.key;

  if (k = 'Right') then k := 'ArrowRight';
  if (k = 'Left')  then k := 'ArrowLeft';
  if (k = 'Up')    then k := 'ArrowUp';
  if (k = 'Down')  then k := 'ArrowDown';
  if (k = 'NumpadEnter') or (k = 'Return') then k := 'Enter';
  if (k = 'Spacebar') or (k = ' ') or (k = 'Space') then k := 'Space';

  // === ANTY-DUPLIKAT: drugi keydown tego samego klawisza
  // w bardzo krótkim czasie ignorujemy ===
  nowTime  := window.performance.now;
  lastTime := 0;
  if (gKeyLastDown <> nil) and gKeyLastDown.hasOwnProperty(k) then
    lastTime := Double(gKeyLastDown[k]);

  if (nowTime - lastTime) < DUP_WINDOW_MS then
  begin
    // zignoruj ten event jako duplikat
    Exit(False);
  end;

  gKeyLastDown[k] := nowTime;

  // === INICJALIZACJA STANÓW ===
  if not gKeys.hasOwnProperty(k) then
  begin
    gKeys[k]        := False;
    gKeysPressed[k] := False;
    gKeysReleased[k]:= False;
  end;

  // === AUTO-REPEAT ===
  isRepeat := False;
  if TJSObject(e).hasOwnProperty('repeat') then
    isRepeat := Boolean(TJSObject(e)['repeat']);

  // blokada „przytrzymania” (systemowe repeat)
  if isRepeat then
  begin
    if gRunning then
    begin
      if (k = KEY_SPACE) or
         (k = KEY_LEFT) or (k = KEY_RIGHT) or
         (k = KEY_UP)   or (k = KEY_DOWN)  or
         (k = KEY_ENTER) or
         (k = KEY_ESCAPE) then
      begin
        e.preventDefault;
        e.stopPropagation;
      end;
    end;
    Exit(False);   // nie traktujemy repeat jako nowego naciśnięcia
  end;

  // --- RESZTA JAK BYŁO ---
  wasDown := Boolean(gKeys[k]);

  // Krawędź "Pressed" tylko przy przejściu z "nie wciśnięty" -> "wciśnięty"
  // i tylko przy pierwszym zdarzeniu (bez auto-repeat + bez duplikatu czasowego)
  if (not wasDown) then
  begin
    gKeysPressed[k]     := True;
    gKeyPressedUntil[k] := window.performance.now() + W_KEY_PRESSED_HOLD_MS;
  end;

  // Klawisz jest aktualnie wciśnięty
  gKeys[k] := True;

  // === BLOKADA DOMYŚLNEGO ZACHOWANIA PRZEGLĄDARKI ===
  if gRunning then
  begin
    // 1) Skróty typu Ctrl+F, Ctrl+P, Ctrl+S itp.
    if e.ctrlKey or e.metaKey then
    begin
      case k of
        'KeyF', // Ctrl+F – find
        'KeyP', // Ctrl+P – print
        'KeyS', // Ctrl+S – save
        'KeyN', // Ctrl+N – new window
        'KeyW', // Ctrl+W – close tab
        'KeyT', // Ctrl+T – new tab
        'KeyR': // Ctrl+R – refresh
        begin
          e.preventDefault;
          e.stopPropagation;
          Exit(False);
        end;
      end;
    end;

    // 2) Zwykłe klawisze gry – szczególnie spacja, żeby NIE przewijała strony
    if (k = KEY_SPACE) or
       (k = KEY_LEFT) or (k = KEY_RIGHT) or
       (k = KEY_UP)   or (k = KEY_DOWN)  or
       (k = KEY_ENTER) or
       (k = KEY_ESCAPE) then
    begin
      e.preventDefault;
      e.stopPropagation;
    end;
  end;

  // Specjalny przypadek: Escape zamyka okno gry
  if gCloseOnEscape and (k = KEY_ESCAPE) then
    gWantsClose := True;

  Result := True;
end;




  onKeyUpH := function (event: TJSEvent): boolean
  var
    e: TJSKeyBoardEvent;
    k, lk: String;
  begin
    e := TJSKeyBoardEvent(event);

    // === NORMALIZACJA TAKA SAMA JAK W KEYDOWN ===
    k := e.code;
    if (k = '') then k := e.key;

    if (k = 'Right') then k := 'ArrowRight';
    if (k = 'Left')  then k := 'ArrowLeft';
    if (k = 'Up')    then k := 'ArrowUp';
    if (k = 'Down')  then k := 'ArrowDown';
    if (k = 'NumpadEnter') or (k = 'Return') then k := 'Enter';
    if (k = 'Spacebar') or (k = ' ') or (k = 'Space') then k := 'Space';

    // Blokada domyślnych akcji przeglądarki, kiedy gra działa
    if gRunning then
    begin
      // 1) Ctrl/Meta skróty, żeby nie "puszczały" akcji po keyup
      if e.ctrlKey or e.metaKey then
      begin
        lk := LowerCase(e.key);
        if (lk = 'f') or  // Find
           (lk = 'p') or  // Print
           (lk = 's') or  // Save
           (lk = 'n') or  // New window
           (lk = 'w') or  // Close tab
           (lk = 't') or  // New tab
           (lk = 'r')     // Refresh
        then
        begin
          e.preventDefault;
          e.stopPropagation;
          Exit(False);
        end;
      end;

      // 2) Te same klawisze gry co wyżej – dla porządku
      if (k = KEY_SPACE) or
         (k = KEY_LEFT) or (k = KEY_RIGHT) or
         (k = KEY_UP)   or (k = KEY_DOWN)  or
         (k = KEY_ENTER) then
      begin
        e.preventDefault;
        e.stopPropagation;
      end;
    end;

    // Inicjalizacja, gdyby przyszedł keyup dla klucza, którego jeszcze nie ma
    if not gKeys.hasOwnProperty(k) then
    begin
      gKeys[k]        := False;
      gKeysPressed[k] := False;
      gKeysReleased[k]:= False;
    end;

    // Stan TRZYMANIA na false, krawędź "Released" na true
    gKeys[k]        := False;
    gKeysReleased[k]:= True;

    Result := True;
  end;



window.addEventListener('keydown', onKeyDownH, true); // capture = true
window.addEventListener('keyup',   onKeyUpH, true);

  // --- Mysz ---
  onMouseMoveH := function (event: TJSEvent): boolean
  var
    e: TJSMouseEvent;
  begin
    e := TJSMouseEvent(event);
    gMousePrevPos := gMousePos;
    gMousePos.x := e.offsetX;
    gMousePos.y := e.offsetY;
    Result := True;
  end;

  onMouseDownH := function (event: TJSEvent): boolean
  var
    e: TJSMouseEvent;
  begin
    e := TJSMouseEvent(event);
    if (e.button >= 0) and (e.button <= 2) then
      gMouseButtonsDown[e.button] := true;
    Result := True;
  end;

  onMouseUpH := function (event: TJSEvent): boolean
  var
    e: TJSMouseEvent;
  begin
    e := TJSMouseEvent(event);
    if (e.button >= 0) and (e.button <= 2) then
      gMouseButtonsDown[e.button] := false;
    Result := True;
  end;

  onWheelH := function (event: TJSEvent): boolean
  var
    e: TJSWheelEvent;
  begin
    e := TJSWheelEvent(event);
    if e.deltaY > 0 then Inc(gMouseWheelDelta) else
    if e.deltaY < 0 then Dec(gMouseWheelDelta);
    e.preventDefault();
    Result := True;
  end;

  gCanvas.addEventListener('mousemove', onMouseMoveH);
  gCanvas.addEventListener('mousedown', onMouseDownH);
  gCanvas.addEventListener('mouseup',   onMouseUpH);
  gCanvas.addEventListener('wheel',     onWheelH);

  // --- Dotyk (RawEventHandler zostaje procedurą) ---
  onTouchStartH := TJSRawEventHandler(procedure (event: TJSEvent)
  var
    touches: TJSArray; first: TJSObject;
  begin
    touches := TJSArray(event['touches']);
    if (touches <> nil) and (touches.length > 0) then
    begin
      first := TJSObject(touches[0]);
      gMousePos.x := Double(first['clientX']) - gCanvas.offsetLeft;
      gMousePos.y := Double(first['clientY']) - gCanvas.offsetTop;
      gMouseButtonsDown[0] := true;
    end;
    event.preventDefault();
  end);

  onTouchMoveH := TJSRawEventHandler(procedure (event: TJSEvent)
  var
    touches: TJSArray; first: TJSObject;
  begin
    touches := TJSArray(event['touches']);
    if (touches <> nil) and (touches.length > 0) then
    begin
      first := TJSObject(touches[0]);
      gMousePos.x := Double(first['clientX']) - gCanvas.offsetLeft;
      gMousePos.y := Double(first['clientY']) - gCanvas.offsetTop;
    end;
    event.preventDefault();
  end);

  onTouchEndH := TJSRawEventHandler(procedure (event: TJSEvent)
  begin
    gMouseButtonsDown[0] := false;
    event.preventDefault();
  end);

  gCanvas.addEventListener('touchstart', onTouchStartH);
  gCanvas.addEventListener('touchmove',  onTouchMoveH);
  gCanvas.addEventListener('touchend',   onTouchEndH);

  // --- Blur / Click ---
  onBlurH := function (event: TJSEvent): boolean
  var
    key: String;
  begin
    for key in TJSObject.getOwnPropertyNames(gKeys) do
      gKeys[key] := false;
    gMouseButtonsDown[0] := false;
    gMouseButtonsDown[1] := false;
    gMouseButtonsDown[2] := false;
    Result := True;
  end;

  onClickH := function (event: TJSEvent): boolean
  begin
    gCanvas.focus();
    Result := True;
  end;

  gCanvas.addEventListener('blur', onBlurH);
  gCanvas.addEventListener('click', onClickH);

  // Start
  gRunning := true;
    gWantsClose := False;  // <<< resetujemy żądanie zamknięcia
 asm
  document.addEventListener('contextmenu', function(e) {
    e.preventDefault();
  });
end;
W_EnsureInputInit;
  W_BindCanvasEvents; 
end;

procedure W_InitInput;
var b: Integer;
begin
  if W_ListenersAttached then Exit;  // ⟵ strażnik

  // wyzeruj stany
  for b := 0 to 2 do
  begin
    W_CurrDown[b] := False;
    W_PrevDown[b] := False;
    W_Pressed[b]  := False;
    W_Released[b] := False;
    W_ClickQ[b]   := 0;
  end;

  if W_Canvas = nil then
    W_Canvas := gCanvas;
  if W_Canvas = nil then
    W_Canvas := TJSHTMLCanvasElement(document.querySelector('canvas'));

  if W_Canvas <> nil then
  begin
    W_Canvas.tabIndex := 0;
    W_Canvas.style.setProperty('touch-action', 'none');
    W_Canvas.addEventListener('contextmenu', TJSRawEventHandler(@W_EH_ContextMenu));
  end;

  window.addEventListener('pointerdown',   TJSRawEventHandler(@W_EH_PointerDown));
  window.addEventListener('pointerup',     TJSRawEventHandler(@W_EH_PointerUp));
  window.addEventListener('pointercancel', TJSRawEventHandler(@W_EH_PointerCancel));
  document.addEventListener('visibilitychange', TJSRawEventHandler(@W_EH_VisibilityChange));

 
  W_BindCanvasEvents;

  W_ListenersAttached := True; 
end;





procedure CloseWindow;
var
  i: Integer;
begin
  // wyczyść cache tintów przed zwalnianiem tekstur
  ClearTintCache;
// NATYCHMIAST: utnij audio
if gAudioCtx <> nil then
begin
  try gAudioCtx.suspend(); except end;
end;
if gMasterGain <> nil then
begin
  try gMasterGain.gain.value := 0; except end;
end;

// NATYCHMIAST: ubij render workera (żeby nie trzymał strony)
asm
  var w = window.__wilgaRenderWorker;
  if (w) {
    try { w.terminate(); } catch(e) {}
    window.__wilgaRenderWorker = null;
  }
end;


  // --- DŹWIĘK ---
  StopAllSounds;
  for i := 0 to High(gSoundPools) do
    if gSoundPools[i].valid then
      UnloadSoundEx(i);
  SetLength(gSoundPools, 0);
  // --- DŹWIĘK: ubij kontekst audio (żeby nie było "ogona") ---
  if gAudioCtx <> nil then
  begin
    try
      gAudioCtx.suspend();
    except
    end;

    try
      gAudioCtx.close();
    except
    end;

    gAudioCtx := nil;
  end;

  // --- PARTICLE SYSTEMS ---
  for i := 0 to High(gParticleSystems) do
    if Assigned(gParticleSystems[i]) then
      gParticleSystems[i].Free;
  SetLength(gParticleSystems, 0);

  // --- POOLE PAMIĘCI ---
  SetLength(gVectorPool, 0);
  SetLength(gMatrixPool, 0);

  // --- OFFSCREEN DO TINTU ---
  if gTintCanvas <> nil then
  begin
    // Bezpieczne wyzerowanie rozmiaru (obsługuje Offscreen i zwykły canvas)
    WilgaResize(gTintCanvas, 0, 0, 0);
    gTintCtx := nil;
    gTintCanvas := nil;
  end;

  // --- ODCZEPIENIE NASŁUCHIWACZY (2-param. wersje) ---
  if Assigned(gCanvas) then
  begin
    gCanvas.removeEventListener('mousemove', onMouseMoveH);
    gCanvas.removeEventListener('mousedown', onMouseDownH);
    gCanvas.removeEventListener('mouseup',   onMouseUpH);
    gCanvas.removeEventListener('wheel',     onWheelH);

    gCanvas.removeEventListener('touchstart', onTouchStartH);
    gCanvas.removeEventListener('touchmove',  onTouchMoveH);
    gCanvas.removeEventListener('touchend',   onTouchEndH);

    gCanvas.removeEventListener('blur',  onBlurH);
    gCanvas.removeEventListener('click', onClickH);
  end;

  window.removeEventListener('keydown', onKeyDownH);
  window.removeEventListener('keyup',   onKeyUpH);

  // Zerowanie referencji do handlerów (pozwala GC uwolnić closury)
  onKeyDownH := nil; onKeyUpH := nil;
  onMouseMoveH := nil; onMouseDownH := nil; onMouseUpH := nil; onWheelH := nil;
  onTouchStartH := nil; onTouchMoveH := nil; onTouchEndH := nil;
  onBlurH := nil; onClickH := nil;

  // --- STOSY KONTEXTÓW / BATCH / KLUCZE ---
  SetLength(gCtxStack, 0);
  SetLength(gCanvasStack, 0);

  SetLength(gLineBatch, 0);
  gLineBatchActive := False;

  gKeys := nil;
  gKeysPressed := nil;
  gKeysReleased := nil;
  gKeyPressedUntil := nil;
  gKeyLastDown := nil;


  // --- PROFILER ---
  SetLength(gProfileStack, 0);
  gProfileData := TJSObject.new;

  // --- ZEROWANIE KONTEKSTU I CANVASA ---
  gCtx := nil;
  if gCanvas <> nil then
  begin
    // Bezpieczny „shrink to 0” niezależnie od trybu (Offscreen / zwykły)
    WilgaResize(gCanvas, 0, 0, 0);

    // (opcjonalnie) usuń canvas z DOM
    if gCanvas.parentElement <> nil then
      gCanvas.parentElement.removeChild(gCanvas);

    // (opcjonalnie) wyczyść referencję do offscreenowego obiektu, jeśli była
    // (opcjonalnie) wyczyść referencję do offscreenowego obiektu, jeśli była
if JS.toBoolean(TJSObject(gCanvas)['__wilgaOffscreen']) then
  TJSObject(gCanvas)['__wilgaOffscreen'] := nil;


    gCanvas := nil;
  end;

  gRunning := False;

  {$ifdef WILGA_DEBUG}
  try
    console.log(DumpLeakReport);
  except end;
  {$endif}
end;


procedure SetFPS(fps: Integer);
begin
  SetTargetFPS(fps);
end;

procedure SetTargetFPS(fps: Integer);
begin
  if fps < 0 then fps := 0;
  gTargetFPS := fps;
end;

procedure SetWindowSize(width, height: Integer);
begin
  // CSS-owy rozmiar okna
  gCanvas.style.setProperty('width',  IntToStr(width) + 'px');
  gCanvas.style.setProperty('height', IntToStr(height) + 'px');

  // Jedno źródło prawdy: WilgaResize zrobi całą resztę
  WilgaResize(gCanvas, width, height, gDPR);

  // (USUŃ to, jeśli tu było:)
  // if gCtx <> nil then gCtx.setTransform(gDPR, 0, 0, gDPR, 0, 0);
  // WSyncSizeFromCanvas(gCanvas);
  // WResetShadow;
end;



procedure SetWindowTitle(const title: String);
begin
  document.title := title;
end;

procedure ToggleFullscreen;
begin
  asm
    var doc = document;
    var el  = document.getElementById('game');

    var isFS = doc.fullscreenElement
            || doc.webkitFullscreenElement
            || doc.mozFullScreenElement
            || doc.msFullscreenElement;

    if (!isFS) {
      if (el && el.requestFullscreen) el.requestFullscreen();
      else if (el && el.webkitRequestFullscreen) el.webkitRequestFullscreen();
      else if (el && el.mozRequestFullScreen) el.mozRequestFullScreen();
      else if (el && el.msRequestFullscreen) el.msRequestFullscreen();
    } else {
      if (doc.exitFullscreen) doc.exitFullscreen();
      else if (doc.webkitExitFullscreen) doc.webkitExitFullscreen();
      else if (doc.mozCancelFullScreen) doc.mozCancelFullScreen();
      else if (doc.msExitFullscreen) doc.msExitFullscreen();
    }
  end;
end;
// Forward declarations (zeby mozna bylo ich uzyc wyzej)
procedure _CtxSaveRaw; forward;
procedure _CtxRestoreRaw; forward;

procedure BeginDrawing;
begin
  {$MESSAGE warning '⚠️ [Wilga] NIE UZYWAC BeginDrawing w kodzie gry – silnik Wilga wywoluje je automatycznie!'}
  {$MESSAGE warning '⚠️ [Wilga] DO NOT USE BeginDrawing in game code – it is called automatically by the Wilga engine!'}

  // === start nowej ramki dla Workera (czyści command buffer) ===
  W_BeginFrame;

  // USTAWIENIE DOMYŚLNEGO BLEND MODE DLA NOWEJ RAMKI
  SetBlendMode(bmNormal);  // <<< to jest kluczowe
  WSetAlpha(1.0);

  // jesli poprzednia ramka cos zostawila, posprzataj „na miekkko”
  {$IFDEF WILGA_LEAK_GUARD}{$IFDEF WILGA_ASSERTS}
  if (GSaveDepth <> 0) or (GFrameDepth <> 0) then
  begin
    while GSaveDepth > 0 do begin _CtxRestoreRaw; Dec(GSaveDepth); end;
    while GFrameDepth > 0 do begin _CtxRestoreRaw; Dec(GFrameDepth); end;
  end;
  {$ENDIF}{$ENDIF}

  // ramkowy sentinel: RAW save, ale BEZ inkrementu GSaveDepth
  _CtxSaveRaw;
  {$IFDEF WILGA_LEAK_GUARD} Inc(GFrameDepth); {$ENDIF}
end;


procedure EndDrawing;
begin
  {$MESSAGE warning '⚠️ [Wilga] NIE UZYWAC EndDrawing w kodzie gry – silnik Wilga wywoluje je automatycznie!'}
  {$MESSAGE warning '⚠️ [Wilga] DO NOT USE EndDrawing in game code – it is called automatically by the Wilga engine!'}

  // najpierw zdejmij WSZYSTKIE userowe savy pozostawione w ramce
  {$IFDEF WILGA_LEAK_GUARD}
  while GSaveDepth > 0 do
  begin
    _CtxRestoreRaw;
    Dec(GSaveDepth);
  end;
  // teraz zdejmij ramkowy sentinel (musi istniec!)
  if GFrameDepth > 0 then
  begin
    _CtxRestoreRaw;
    Dec(GFrameDepth);
  end
  else
  begin
    {$IFDEF WILGA_ASSERTS}
    asm console.error('EndDrawing: frame sentinel already removed'); end;
    {$ENDIF}
  end;
  {$ELSE}
  // bez guardow – klasycznie para Save/Restore
  _CtxRestoreRaw;
  {$ENDIF}

  // sanity po ramce
  {$IFDEF WILGA_LEAK_GUARD}{$IFDEF WILGA_ASSERTS}
  if (GSaveDepth <> 0) or (GFrameDepth <> 0) then
    asm console.warn('EndDrawing: non-zero depths after frame: user=', $mod.GSaveDepth, ' frame=', $mod.GFrameDepth); end;
  {$ENDIF}{$ENDIF}

  // === koniec ramki – wyślij command buffer do Workera ===
  W_EndFrame;
end;


procedure ClearBackground(const color: TColor);
var
  rgba: string;
begin
  // Zamień TColor na RGBA string
  rgba := ColorToCanvasRGBA(color);

  // Shadow-state: ustaw kolor dla fillStyle i zaktualizuj cache
  WSetFill(rgba);

  // Wyłącz transformacje – czyścimy w przestrzeni pikseli
  CanvasSave;
  gCtx.setTransform(1, 0, 0, 1, 0, 0);

  // Usuń stare piksele (czyści alpha, usunie śmieci po tekstach/teksturach)
  gCtx.clearRect(0, 0, gCanvas.width, gCanvas.height);

  // Po wyczyszczeniu zamaluj jednolitym kolorem
  gCtx.fillRect(0, 0, gCanvas.width, gCanvas.height);

  // Przywróć transformacje
  gCtx.restore;

  // ShadowState: restore changes fill/alpha/op/font etc.
  WResetShadow;

  // Shadow-state: wracamy do DPR transform
  gCtx.setTransform(W.DPR, 0, 0, W.DPR, 0, 0);

  // Canvas czysty
  W.Dirty := False;
end;



procedure DrawRectangle(x, y, w, h: double; const color: TColor);
begin
  WSetFill(ColorToCanvasRGBA(color));
  gCtx.fillRect(x, y, w, h);
end;
function RectangleFromCenter(cx, cy, w, h: Double): TRectangle;
begin
  Result := RectangleCreate(cx - w/2, cy - h/2, w, h);
end;

function RectCenter(const R: TRectangle): TVector2;
begin
  Result := Vector2Create(R.x + R.width/2, R.y + R.height/2);
end;

procedure DrawRectangleRec(const rec: TRectangle; const color: TColor);
begin
  WSetFill(ColorToCanvasRGBA(color));
  gCtx.fillRect(rec.x, rec.y, rec.width, rec.height);  // bez Round!
end;


procedure DrawCircle(cx, cy, radius: double; const color: TColor);
begin
  gCtx.beginPath;
  gCtx.arc(cx, cy, radius, 0, 2 * Pi);
  WSetFill(ColorToCanvasRGBA(color));
  gCtx.fill;
end;


procedure DrawCircleLines(cx, cy, radius, thickness: double; const color: TColor);
begin
  gCtx.beginPath;
  gCtx.arc(cx, cy, radius, 0, 2 * Pi);
  gCtx.lineWidth := thickness;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);
  gCtx.stroke;
end;
procedure DrawCircleV(center: TInputVector; radius: double; const color: TColor);
begin
  if Assigned(gCtx) then
  begin
    // rysuj w world-space na floatach — transform (BeginMode2D) zrobi resztę
    gCtx.beginPath;
    gCtx.arc(center.x, center.y, radius, 0, 2 * Pi);
    WSetFill(ColorToCanvasRGBA(color));
    gCtx.fill;
  end
  else
  begin
    // awaryjnie (bez kontekstu) nic nie rób albo użyj DrawCircle
  end;
end;



procedure DrawEllipse(cx, cy, rx, ry: Integer; const color: TColor);
begin
  gCtx.beginPath;
  gCtx.ellipse(cx, cy, rx, ry, 0, 0, 2 * Pi);
  WSetFill(ColorToCanvasRGBA(color));
  gCtx.fill;
end;
procedure DrawEllipseLines(cx, cy, rx, ry, thickness: Integer; const color: TColor);
begin
  if (rx <= 0) or (ry <= 0) then Exit;

  gCtx.beginPath;
  gCtx.ellipse(cx, cy, rx, ry, 0, 0, 2*Pi);
  gCtx.strokeStyle := ColorToCanvasRGBA(color);
  gCtx.lineWidth := thickness;
  gCtx.stroke;
end;

procedure DrawEllipseV(center: TInputVector; radiusX, radiusY: Double; const color: TColor);
begin
  DrawEllipse(Round(center.x), Round(center.y), Round(radiusX), Round(radiusY), color);
end;
procedure DrawText(const text: String; x, y, size: Integer; const color: TColor);
{$IFDEF WILGA_TEXT_CACHE}
var
  st  : wilga_text_cache.TTextStyle;
  tex : wilga_text_cache.TTexture;
  lines: TStringArray;
  line: String;
  lineIdx: Integer;
  lineHeight: Integer;
begin
  if text = '' then Exit;

  // ======== RESET CAŁEGO STANU KONTEXTU 2D ========
  gCtx.setTransform(1,0,0,1,0,0);
  WSetAlpha(1.0);
  WSetOp('source-over');
  gCtx.imageSmoothingEnabled := True;
  gCtx.shadowBlur := 0;
  gCtx.shadowOffsetX := 0;
  gCtx.shadowOffsetY := 0;
  gCtx.shadowColor := 'rgba(0,0,0,0)';
  // =================================================

  // ======== USTAWIENIA STYLU (wspólne dla wszystkich linii) ========
  st.SizePx := size;
  st.Family := GFontFamily;
  st.Fill := ColorToRGBA32(color);

  st.AlignH := 'left';
  st.AlignV := 'top';

  st.OutlinePx := 0;
  st.Outline := ColorToRGBA32(color_BLACK);

  st.ShadowOffsetX := 0;
  st.ShadowOffsetY := 0;
  st.ShadowBlur := 0;
  st.ShadowColor := ColorToRGBA32(color_TRANSPARENT);

  st.Padding := 2;
  // ================================================================

  // Zostawiamy kompatybilne odstępy jak było wcześniej:
  lineHeight := size + size div 3;

  // ======== DZIELENIE TEKSTU PO ENTERACH (#10, #13) ========
  // CRLF traktujemy jako jedno łamanie. Puste linie przesuwają Y (lineIdx),
  // ale nic nie rysują.
  lines := W_SplitLines(text);

  for lineIdx := 0 to High(lines) do
  begin
    line := lines[lineIdx];
    if line = '' then
      Continue;

    // unikalne UID dla danej linii (żeby cache był poprawny)
    st.UID := TextHash(line) xor (size shl 16) xor st.Fill;

    tex := wilga_text_cache.GetTextTexture(line, st);
    gCtx.drawImage(tex.canvas, x, y + lineIdx * lineHeight);
  end;

  // ======== RESET PO RYSOWANIU ========
  gCtx.setTransform(1,0,0,1,0,0);
  // =====================================
end;
{$ELSE}
var
  asc       : Double;
  fontStr   : String;
  measureCtx: TJSCanvasRenderingContext2D;
  m         : JSValue;
  lines     : TStringArray;
  line      : String;
  lineIdx   : Integer;
  lineHeight: Integer;
begin
  if text = '' then Exit;

  // kolor + font tak jak zawsze
  WSetFill(ColorToCanvasRGBA(color));
  EnsureFont(size);

  // string fontu taki sam jak przy rysowaniu
  fontStr := gCtx.font;

  // używamy PRAWDZIWEGO kontekstu (gMeasureCtx), nie gCtx-proxy
  W_InitMeasureCanvas;
  measureCtx := gMeasureCtx;

  measureCtx.setTransform(1, 0, 0, 1, 0, 0);
  measureCtx.font := fontStr;

  // baseline jak w text-cache
  gCtx.textBaseline := 'alphabetic';

  lineHeight := size + size div 3;

  lines := W_SplitLines(text);

  for lineIdx := 0 to High(lines) do
  begin
    line := lines[lineIdx];
    if line = '' then
      Continue;

    m := measureCtx.measureText(line);

    asm
      var mm = m;
      if (mm && mm.actualBoundingBoxAscent !== undefined) {
        asc = Number(mm.actualBoundingBoxAscent);
      } else {
        asc = 0.80 * size;
      }
    end;

    gCtx.fillText(line, x, y + lineIdx * lineHeight + asc);
  end;
end;
{$ENDIF}

function MeasureTextWidth(const text: String; size: Integer): Double;
var
  key: String;
  v: JSValue;
  fontStr: String;
  lines: TStringArray;
  i: Integer;
  w: Double;
begin
  if text = '' then Exit(0);

  if GTextWidthCache = nil then
    GTextWidthCache := TJSMap.new;

  EnsureFont(size);
  fontStr := gCtx.font;

  // klucz do cache: font + tekst (z newline'ami)
  key := fontStr + '|W|' + text;

  if GTextWidthCache.has(key) then
  begin
    v := GTextWidthCache.get(key);
    Exit(Double(v));
  end;

  W_InitMeasureCanvas;
  gMeasureCtx.setTransform(1, 0, 0, 1, 0, 0);
  gMeasureCtx.font := fontStr;

  // newline: szerokość = max z linii
  lines := W_SplitLines(text);
  Result := 0;
  for i := 0 to High(lines) do
  begin
    if lines[i] = '' then Continue;
    w := gMeasureCtx.measureText(lines[i]).width;
    if w > Result then Result := w;
  end;

  {$ifdef HAS_SET_UNDERSCORE}
  GTextWidthCache.set_(key, Result);
  {$else}
  GTextWidthCache.&set(key, Result);
  {$endif}
end;

function MeasureTextHeight(const text: String; size: Integer): Double;
var
  key       : String;
  fontStr   : String;
  measureCtx: TJSCanvasRenderingContext2D;
  m         : JSValue;
  ascent,
  descent   : Double;
  lineBox   : Double;
  lineHeight: Integer;
  lines     : TStringArray;
  lineCount : Integer;
begin
  if text = '' then Exit(0);

  if GTextHeightCache = nil then
    GTextHeightCache := TJSMap.new;

  EnsureFont(size);
  fontStr := gCtx.font;

  // cache wysokości pojedynczej linii po foncie
  key := 'H|' + fontStr;

  if GTextHeightCache.has(key) then
    lineBox := Double(GTextHeightCache.get(key))
  else
  begin
    W_InitMeasureCanvas;
    measureCtx := gMeasureCtx;

    measureCtx.setTransform(1, 0, 0, 1, 0, 0);
    measureCtx.font := fontStr;

    m := measureCtx.measureText('Hg');

    asm
      var mm = m;
      if (mm) {
        ascent  = (mm.actualBoundingBoxAscent  !== undefined)
                  ? Number(mm.actualBoundingBoxAscent)
                  : 0.80 * size;
        descent = (mm.actualBoundingBoxDescent !== undefined)
                  ? Number(mm.actualBoundingBoxDescent)
                  : 0.30 * size;
      } else {
        ascent  = 0.80 * size;
        descent = 0.30 * size;
      }
    end;

    lineBox := Ceil(ascent) + Ceil(descent);
    if lineBox <= 0 then
      lineBox := Ceil(0.80 * size) + Ceil(0.30 * size);

    {$ifdef HAS_SET_UNDERSCORE}
    GTextHeightCache.set_(key, lineBox);
    {$else}
    GTextHeightCache.&set(key, lineBox);
    {$endif}
  end;

  // total dla tekstu wieloliniowego — musi matchować DrawText (size + size div 3)
  lineHeight := size + size div 3;
  lines := W_SplitLines(text);
  lineCount := Length(lines);
  if lineCount <= 0 then lineCount := 1;

  Result := lineBox + (lineCount - 1) * lineHeight;
end;

procedure SetTextFont(const cssFont: String);
begin
  WSetFont(cssFont);
end;

procedure SetTextAlign(const hAlign: String; const vAlign: String);
begin
  gCtx.textAlign := hAlign;
  gCtx.textBaseline := vAlign;
end;

procedure DrawTextCentered(const text: String; cx, cy, size: Integer; const color: TColor);
{$IFDEF WILGA_TEXT_CACHE}
var
  st : wilga_text_cache.TTextStyle;
  tex: wilga_text_cache.TTexture;
  dx, dy: Integer;
begin
  st.SizePx := size;
  st.Family := GFontFamily;
  st.Fill := ColorToRGBA32(color);
  st.AlignH := 'center';
  st.AlignV := 'middle';
  st.OutlinePx := 0;
  st.Outline := ColorToRGBA32(color_BLACK);
  st.ShadowOffsetX := 0; st.ShadowOffsetY := 0; st.ShadowBlur := 0;
  st.ShadowColor := ColorToRGBA32(color_TRANSPARENT);
  st.Padding := 2;

  tex := wilga_text_cache.GetTextTexture(text, st);
  dx := cx - tex.width div 2;
  dy := cy - tex.height div 2;
  gCtx.drawImage(tex.canvas, dx, dy);
end;
{$ELSE}
begin
  CanvasSave;
  WSetFill(ColorToCanvasRGBA(color));
  EnsureFont(size);
  gCtx.textAlign := 'center';
  gCtx.textBaseline := 'middle';
  gCtx.fillText(text, cx, cy);
  CanvasRestore;
end;
{$ENDIF}


// Tekst z obramowaniem (outline)
// ========== Tekst z obrysem ==========
// Outline rysowany wieloma offsetami DrawText – korzysta z tych samych fontów,
// cache i WithFont co reszta Wilgi.
procedure DrawTextOutline(const text: String; x, y, size: Integer;
  const fillColor, outlineColor: TColor; outlinePx: Integer);
var
  dx, dy: Integer;
begin
  // najpierw obrys
  if outlinePx > 0 then
  begin
    for dy := -outlinePx to outlinePx do
      for dx := -outlinePx to outlinePx do
        if (dx <> 0) or (dy <> 0) then
          DrawText(text, x + dx, y + dy, size, outlineColor);
  end;

  // potem środek
  DrawText(text, x, y, size, fillColor);
end;


procedure DrawTextPro(const text: String; x, y, size: Integer; const color: TColor;
                      rotation: Double; originX, originY: Double);
{$IFDEF WILGA_TEXT_CACHE}
var
  st : wilga_text_cache.TTextStyle;
  tex: wilga_text_cache.TTexture;
  G  : TCanvasStateGuard;
begin
  st.SizePx := size;
  st.Family := GFontFamily;
  st.Fill := ColorToRGBA32(color);
  st.AlignH := 'left';
  st.AlignV := 'top';
  st.OutlinePx := 0;
  st.Outline := ColorToRGBA32(color_BLACK);
  st.ShadowOffsetX := 0; st.ShadowOffsetY := 0; st.ShadowBlur := 0;
  st.ShadowColor := ColorToRGBA32(color_TRANSPARENT);
  st.Padding := 2;

  tex := wilga_text_cache.GetTextTexture(text, st);

  BeginCanvasState(G);
  try
    gCtx.translate(x + originX, y + originY);
    gCtx.rotate(rotation);
    gCtx.drawImage(tex.canvas, -Round(originX), -Round(originY));
  finally
    EndCanvasState(G);
  end;
end;
{$ELSE}
var
  G: TCanvasStateGuard;
begin
  BeginCanvasState(G);
  try
    gCtx.translate(x + originX, y + originY);
    gCtx.rotate(rotation);
    WSetFill(ColorToCanvasRGBA(color));
    EnsureFont(size);
    gCtx.textAlign := 'left';
    gCtx.textBaseline := 'top';
    gCtx.fillText(text, -originX, -originY);
  finally
    EndCanvasState(G);
  end;
end;
{$ENDIF}



// === Text helpers with explicit font ===
procedure DrawTextWithFont(const text: String; x, y, size: Integer; const family: String; const color: TColor);
begin
  CanvasSave;
  if family <> '' then
    WSetFont(IntToStr(size) + 'px "' + family + '", system-ui, sans-serif')
  else EnsureFont(size);
  WSetFill(ColorToCanvasRGBA(color));
  gCtx.textBaseline := 'top';
  gCtx.fillText(text, x, y);
  CanvasRestore;
end;




function MeasureTextHeightWithFont(const text: String; size: Integer; const family: String): Double;
var
  m: TJSObject;
  h: Double;
  desired, key: String;
begin
  if GTextHeightCache = nil then
    GTextHeightCache := TJSMap.new;

  desired := BuildFontString(size, family);
  if gCtx.font <> desired then
    WSetFont(desired);

  key := desired + '|' + text;

  if GTextHeightCache.has(key) then
    Exit(Double(GTextHeightCache.get(key)));

  W_InitMeasureCanvas;
  gMeasureCtx.font := desired;

  // TextMetrics jako obiekt JS
  m := TJSObject(gMeasureCtx.measureText(text));

  // jeśli są bboxy — użyj ich, w przeciwnym razie fallback
  if m.hasOwnProperty('actualBoundingBoxAscent') and m.hasOwnProperty('actualBoundingBoxDescent') then
    h := Double(m['actualBoundingBoxAscent']) + Double(m['actualBoundingBoxDescent'])
  else
    h := size * 1.2; // sensowna heurystyka line-height

  asm
    GTextHeightCache.set(key, h);
  end;

  Result := h;
end;
function MeasureTextWidthWithFont(const text: String; size: Integer; const family: String): Double;
var
  desired, key: String;
  v: JSValue;
begin
  if GTextWidthCache = nil then
    GTextWidthCache := TJSMap.new;

  // składamy pełny font, np. "18px 'Press Start 2P'"
  desired := BuildFontString(size, family);

  // aktualny globalny font Wilgi (do rysowania) – tu nic nie zmieniamy
  if gCtx.font <> desired then
    WSetFont(desired);

  // cache
  key := desired + '|' + text;
  if GTextWidthCache.has(key) then
  begin
    v := GTextWidthCache.get(key);
    Exit(Double(v));
  end;

  // ✅ pomiar na helper-canvasie
  W_InitMeasureCanvas;
  gMeasureCtx.setTransform(1,0,0,1,0,0);
  gMeasureCtx.font := desired;

  Result := gMeasureCtx.measureText(text).width;

  asm
    GTextWidthCache.set(key, Result);
  end;
end;


{ ====== RYSOWANIE ROZSZERZONE ====== }
procedure DrawRectangleProDeg(const rec: TRectangle; origin: TVector2; rotationDeg: Double; const color: TColor);
var
  G: TCanvasStateGuard;
begin
  BeginCanvasState(G);
  try
    gCtx.translate(rec.x + origin.x, rec.y + origin.y);
    gCtx.rotate(DegToRad(rotationDeg));
    WSetFill(ColorToCanvasRGBA(color));
    gCtx.fillRect(-origin.x, -origin.y, rec.width, rec.height);
  finally
    EndCanvasState(G);
  end;
end;

procedure DrawPolyDeg(center: TVector2; sides: Integer; radius: Double; rotationDeg: Double; const color: TColor);
var
  i: Integer;
  ang, rot: Double;
  G: TCanvasStateGuard;
begin
  if sides < 3 then Exit;

  rot := DegToRad(rotationDeg);

  BeginCanvasState(G);
  try
    gCtx.beginPath;
    for i := 0 to sides - 1 do
    begin
      ang := rot + (2 * Pi * i / sides);
      if i = 0 then
        gCtx.moveTo(center.x + Cos(ang) * radius, center.y + Sin(ang) * radius)
      else
        gCtx.lineTo(center.x + Cos(ang) * radius, center.y + Sin(ang) * radius);
    end;
    gCtx.closePath;

    WSetFill(ColorToCanvasRGBA(color));
    gCtx.fill;
  finally
    EndCanvasState(G);
  end;
end;


procedure DrawRectanglePro(const rec: TRectangle; origin: TVector2; rotation: Double; const color: TColor);
begin
  DrawRectangleProDeg(rec, origin, RadToDeg(rotation), color);
end;

procedure DrawPoly(center: TVector2; sides: Integer; radius: Double; rotation: Double; const color: TColor);
begin
  DrawPolyDeg(center, sides, radius, RadToDeg(rotation), color);
end;

procedure DrawCircleGradient(cx, cy: Integer; radius: Integer; const inner, outer: TColor);
var
  grad: TJSCanvasGradient;
begin
  // Utwórz gradient na AKTUALNYM kontekście
  grad := gCtx.createRadialGradient(cx, cy, 0, cx, cy, radius);
  grad.addColorStop(0, ColorToCanvasRGBA(inner));
  grad.addColorStop(1, ColorToCanvasRGBA(outer));

  // Ustaw gradient przez shadow-state (unieważnia stringowy cache)
  WSetFill(grad);

  // 3) Narysuj koło
  gCtx.beginPath;
  gCtx.arc(cx, cy, radius, 0, 2*Pi);
  gCtx.fill;
end;


{ ====== TEKSTURY / RENDER-TO-TEXTURE ====== }
function MakeOffscreenCanvas(w, h: Integer): TJSHTMLCanvasElement;
begin
  Result := TJSHTMLCanvasElement(document.createElement('canvas'));
  // Ustaw rozmiar bezpiecznie (obsługuje też prawdziwy Offscreen po transferze)
  WilgaResize(Result, w, h, 0); // 0 = auto DPR
end;


function LoadRenderTexture(w, h: Integer): TRenderTexture2D;
begin
  Result.texture.canvas := MakeOffscreenCanvas(w, h);
  Result.texture.width := w;
  Result.texture.height := h;
  Result.texture.loaded := True;
  {$ifdef WILGA_DEBUG}
DBG_Inc(dbg_TexturesAlive);
DBG_Inc(dbg_RenderTexturesAlive);
{$endif}
end;

procedure BeginTextureMode(const rt: TRenderTexture2D);
begin
  // Zapisz bieżący kontekst na stosie
  SetLength(gCtxStack, Length(gCtxStack)+1);
  gCtxStack[High(gCtxStack)] := gCtx;

  SetLength(gCanvasStack, Length(gCanvasStack)+1);
  gCanvasStack[High(gCanvasStack)] := gCanvas;

  // Przełącz na canvas tekstury
  gCanvas := rt.texture.canvas;
  gCtx    := WilgaInitContextFromCanvas(gCanvas);

  // >>> KLUCZOWE: shadow-state musi wskazywać NA TEN SAM KONTEKST co gCtx
  WAttachToCurrentState(gCanvas, gCtx);

  // Zachowaj stan 2D na tej teksturze
  CanvasSave;
end;

procedure EndTextureMode;
begin
  // Odtwórz stan 2D tekstury
  CanvasRestore;

  // Przywróć poprzedni kontekst z naszego stosu
  if Length(gCtxStack) > 0 then
  begin
    gCtx := gCtxStack[High(gCtxStack)];
    SetLength(gCtxStack, Length(gCtxStack)-1);
  end;

  if Length(gCanvasStack) > 0 then
  begin
    gCanvas := gCanvasStack[High(gCanvasStack)];
    SetLength(gCanvasStack, Length(gCanvasStack)-1);
  end;

  // >>> I TERAZ: shadow-state wraca na główny kontekst
  WAttachToCurrentState(gCanvas, gCtx);
end;



function CreateTextureFromCanvas(canvas: TJSHTMLCanvasElement): TTexture;
var
  w, h: Integer;
begin
  // Bezpieczne pobranie wymiarów, niezależnie czy canvas jest Offscreen czy nie
  asm
    var cnv = canvas;
    var off = cnv && cnv.__wilgaOffscreen ? cnv.__wilgaOffscreen : null;
    w = (off ? off.width : cnv.width);
    h = (off ? off.height : cnv.height);
  end;

  Result.canvas := canvas;
  Result.width  := w;
  Result.height := h;
  Result.loaded := True;

  {$ifdef WILGA_DEBUG}
  DBG_Inc(dbg_TexturesAlive);
  {$endif}
end;

{ ====== WEJŚCIE ====== }
procedure ClearAllKeys;
var
  key: String;
begin
  for key in TJSObject.getOwnPropertyNames(gKeys) do
  begin
    gKeys[key] := false;
    gKeysPressed[key] := false;
    gKeysReleased[key] := false;
  end;
end;

function KeyCodeToCode(keyCode: Integer): String;
begin
  case keyCode of
    // Litery
    65..90:   Exit('Key' + Chr(keyCode));   // A..Z → KeyA..KeyZ
    // Górny rząd cyfr
    48..57:   Exit('Digit' + Chr(keyCode)); // 0..9 → Digit0..Digit9

    // Spacje i kontrolne
    32: Exit(KEY_SPACE);
    27: Exit(KEY_ESCAPE);
    13: Exit(KEY_ENTER);
     9: Exit(KEY_TAB);

    // Modyfikatory (traktujemy generycznie jako 'Left' – patrz krok 4)
    16: Exit(KEY_SHIFT);
    17: Exit(KEY_CONTROL);
    18: Exit(KEY_ALT);
    91,92: Exit(KEY_META);     // Windows / Command
    93:    Exit(KEY_CONTEXT);  // Context menu

    // Strzałki
    37: Exit(KEY_LEFT);
    38: Exit(KEY_UP);
    39: Exit(KEY_RIGHT);
    40: Exit(KEY_DOWN);

    // Edycja / nawigacja
     8: Exit(KEY_BACKSPACE);
    46: Exit(KEY_DELETE);
    45: Exit(KEY_INSERT);
    36: Exit(KEY_HOME);
    35: Exit(KEY_END);
    33: Exit(KEY_PAGEUP);
    34: Exit(KEY_PAGEDOWN);

    // Funkcyjne
    112: Exit(KEY_F1);   113: Exit(KEY_F2);   114: Exit(KEY_F3);
    115: Exit(KEY_F4);   116: Exit(KEY_F5);   117: Exit(KEY_F6);
    118: Exit(KEY_F7);   119: Exit(KEY_F8);   120: Exit(KEY_F9);
    121: Exit(KEY_F10);  122: Exit(KEY_F11);  123: Exit(KEY_F12);

    // Symbole (wartości keyCode wg typowych map w Chromium/Gecko)
    192: Exit(KEY_BACKQUOTE);   // `
    189: Exit(KEY_MINUS);       // -
    187: Exit(KEY_EQUAL);       // =
    219: Exit(KEY_BRACKETLEFT); // [
    221: Exit(KEY_BRACKETRIGHT);// ]
    220: Exit(KEY_BACKSLASH);   // \
    186: Exit(KEY_SEMICOLON);   // ;
    222: Exit(KEY_QUOTE);       // '
    188: Exit(KEY_COMMA);       // ,
    190: Exit(KEY_PERIOD);      // .
    191: Exit(KEY_SLASH);       // /

    // Numpad
    96: Exit(KEY_NUMPAD0);  97: Exit(KEY_NUMPAD1);  98: Exit(KEY_NUMPAD2);
    99: Exit(KEY_NUMPAD3); 100: Exit(KEY_NUMPAD4); 101: Exit(KEY_NUMPAD5);
   102: Exit(KEY_NUMPAD6); 103: Exit(KEY_NUMPAD7); 104: Exit(KEY_NUMPAD8);
   105: Exit(KEY_NUMPAD9);
   106: Exit(KEY_NUMPAD_MULTIPLY);
   107: Exit(KEY_NUMPAD_ADD);
   109: Exit(KEY_NUMPAD_SUBTRACT);
   110: Exit(KEY_NUMPAD_DECIMAL);
   111: Exit(KEY_NUMPAD_DIVIDE);
  end;
  Result := ''; // fallback – brak mapy
end;

function IsKeyPressed(const code: String): Boolean; overload;
begin
  // Zwróć TRUE tylko jeśli w TEJ ramce był „Pressed”
  // (ustawione w onKeyDownH przy przejściu z not wasDown)
  if gKeysPressed.hasOwnProperty(code) and Boolean(gKeysPressed[code]) then
    Exit(True);

  // Modyfikatory – traktuj lewy/prawy razem
  if (code = 'ShiftLeft') or (code = 'ShiftRight') then
  begin
    if (gKeysPressed.hasOwnProperty('ShiftLeft')  and Boolean(gKeysPressed['ShiftLeft'])) or
       (gKeysPressed.hasOwnProperty('ShiftRight') and Boolean(gKeysPressed['ShiftRight'])) then
      Exit(True);
  end;

  if (code = 'ControlLeft') or (code = 'ControlRight') then
  begin
    if (gKeysPressed.hasOwnProperty('ControlLeft')  and Boolean(gKeysPressed['ControlLeft'])) or
       (gKeysPressed.hasOwnProperty('ControlRight') and Boolean(gKeysPressed['ControlRight'])) then
      Exit(True);
  end;

  if (code = 'AltLeft') or (code = 'AltRight') then
  begin
    if (gKeysPressed.hasOwnProperty('AltLeft')  and Boolean(gKeysPressed['AltLeft'])) or
       (gKeysPressed.hasOwnProperty('AltRight') and Boolean(gKeysPressed['AltRight'])) then
      Exit(True);
  end;

  if (code = 'MetaLeft') or (code = 'MetaRight') then
  begin
    if (gKeysPressed.hasOwnProperty('MetaLeft')  and Boolean(gKeysPressed['MetaLeft'])) or
       (gKeysPressed.hasOwnProperty('MetaRight') and Boolean(gKeysPressed['MetaRight'])) then
      Exit(True);
  end;

  Result := False;
end;




function IsKeyPressed(keyCode: Integer): Boolean; overload;
var
  c: String;
begin
  c := KeyCodeToCode(keyCode);
  if c = '' then Exit(False);
  Result := IsKeyPressed(c);
end;


function IsKeyDown(keyCode: Integer): Boolean; overload;
var
  c: String;
begin
  c := KeyCodeToCode(keyCode);
  if c = '' then Exit(False);
  Result := IsKeyDown(c);
end;
function IsKeyDown(const code: String): Boolean; overload;
begin
  // stan TRZYMANIA (bez kasowania)
  if gKeys.hasOwnProperty(code) and Boolean(gKeys[code]) then
    Exit(True);

  // parowanie modyfikatorów (opcjonalnie, jak u Ciebie)
  if (code = 'ShiftLeft') or (code = 'ShiftRight') then
  begin
    if gKeys.hasOwnProperty('ShiftLeft')  and Boolean(gKeys['ShiftLeft'])  then Exit(True);
    if gKeys.hasOwnProperty('ShiftRight') and Boolean(gKeys['ShiftRight']) then Exit(True);
  end;

  if (code = 'ControlLeft') or (code = 'ControlRight') then
  begin
    if gKeys.hasOwnProperty('ControlLeft')  and Boolean(gKeys['ControlLeft'])  then Exit(True);
    if gKeys.hasOwnProperty('ControlRight') and Boolean(gKeys['ControlRight']) then Exit(True);
  end;

  if (code = 'AltLeft') or (code = 'AltRight') then
  begin
    if gKeys.hasOwnProperty('AltLeft')  and Boolean(gKeys['AltLeft'])  then Exit(True);
    if gKeys.hasOwnProperty('AltRight') and Boolean(gKeys['AltRight']) then Exit(True);
  end;

  if (code = 'MetaLeft') or (code = 'MetaRight') then
  begin
    if gKeys.hasOwnProperty('MetaLeft')  and Boolean(gKeys['MetaLeft'])  then Exit(True);
    if gKeys.hasOwnProperty('MetaRight') and Boolean(gKeys['MetaRight']) then Exit(True);
  end;

  Result := False;
end;

function IsKeyReleased(const code: String): Boolean; overload;
begin
  // Jednorazowa krawędź Released – stan na tę ramkę (bez czyszczenia tutaj)
  if gKeysReleased.hasOwnProperty(code) and Boolean(gKeysReleased[code]) then
    Exit(True);

  // Modyfikatory – lewy/prawy traktowane razem (ale bez kasowania, bo i tak
  // czyścimy gKeysReleased globalnie raz na klatkę w GlobalAnimFrame)


  if (code = 'ShiftLeft') or (code = 'ShiftRight') then
  begin
    if (gKeysReleased.hasOwnProperty('ShiftLeft')  and Boolean(gKeysReleased['ShiftLeft'])) or
       (gKeysReleased.hasOwnProperty('ShiftRight') and Boolean(gKeysReleased['ShiftRight'])) then
      Exit(True);
  end;

  if (code = 'ControlLeft') or (code = 'ControlRight') then
  begin
    if (gKeysReleased.hasOwnProperty('ControlLeft')  and Boolean(gKeysReleased['ControlLeft'])) or
       (gKeysReleased.hasOwnProperty('ControlRight') and Boolean(gKeysReleased['ControlRight'])) then
      Exit(True);
  end;

  if (code = 'AltLeft') or (code = 'AltRight') then
  begin
    if (gKeysReleased.hasOwnProperty('AltLeft')  and Boolean(gKeysReleased['AltLeft'])) or
       (gKeysReleased.hasOwnProperty('AltRight') and Boolean(gKeysReleased['AltRight'])) then
      Exit(True);
  end;

  if (code = 'MetaLeft') or (code = 'MetaRight') then
  begin
    if (gKeysReleased.hasOwnProperty('MetaLeft')  and Boolean(gKeysReleased['MetaLeft'])) or
       (gKeysReleased.hasOwnProperty('MetaRight') and Boolean(gKeysReleased['MetaRight'])) then
      Exit(True);
  end;

  Result := False;
end;




function IsKeyReleased(keyCode: Integer): Boolean; overload;
var
  c: String;
begin
  c := KeyCodeToCode(keyCode);
  if c = '' then Exit(False);
  Result := IsKeyReleased(c);
end;



function GetAllPressedKeys: array of String;
var
  props: array of String;
  key: String;
  i, count: Integer;
begin
  props := TJSObject.getOwnPropertyNames(gKeys);
  SetLength(Result, Length(props));
  
  count := 0;
  for i := 0 to High(props) do
  begin
    key := props[i];
    if Boolean(gKeys[key]) then
    begin
      Result[count] := key;
      Inc(count);
    end;
  end;
  
  SetLength(Result, count);
end;


function GetKeyPressed: String;
var
  key: String;
begin
  for key in TJSObject.getOwnPropertyNames(gKeysPressed) do
  begin
    if Boolean(gKeysPressed[key]) then
    begin
      gKeysPressed[key] := false;
      Exit(key);
    end;
  end;
  Result := '';
end;

function GetCharPressed: String;
begin
  if (gCharQueue.length > 0) then
  begin
    Result := String(gCharQueue.shift); // zdejmij pierwszy
  end
  else
    Result := '';
end;

{ ====== PROFILER ====== }
procedure BeginProfile(const name: String);
begin
  SetLength(gProfileStack, Length(gProfileStack) + 1);
  gProfileStack[High(gProfileStack)].name := name;
  gProfileStack[High(gProfileStack)].startTime := window.performance.now();
end;

procedure EndProfile(const name: String);
var
  duration: Double;
  current: TProfileEntry;
  data: TJSObject;
  total, count, minv, maxv: Double;
begin
  if Length(gProfileStack) = 0 then Exit;

  current := gProfileStack[High(gProfileStack)];
  SetLength(gProfileStack, Length(gProfileStack) - 1);

  if current.name <> name then
    console.warn('Profile mismatch: expected ' + name + ', got ' + current.name);

  duration := window.performance.now() - current.startTime;

  if not gProfileData.hasOwnProperty(name) then
    gProfileData[name] := TJSObject.new;

  data := TJSObject(gProfileData[name]);

  if data.hasOwnProperty('total') then total := Double(data['total']) else total := 0.0;
  if data.hasOwnProperty('count') then count := Double(data['count']) else count := 0.0;
  if data.hasOwnProperty('min')   then minv  := Double(data['min'])   else minv  := MaxDouble;
  if data.hasOwnProperty('max')   then maxv  := Double(data['max'])   else maxv  := 0.0;

  total := total + duration;
  count := count + 1.0;
  if duration < minv then minv := duration;
  if duration > maxv then maxv := duration;

  data['total'] := total;
  data['count'] := count;
  data['min']   := minv;
  data['max']   := maxv;
end;

function GetProfileData: String;
var
  key: String;
  data: TJSObject;
  avg: Double;
begin
  Result := 'Profile Data:'#10;
  for key in TJSObject.getOwnPropertyNames(gProfileData) do
  begin
    data := TJSObject(gProfileData[key]);
    if Integer(data['count']) > 0 then
      avg := Double(data['total']) / Integer(data['count'])
    else
      avg := 0.0;
    Result := Result + Format('%s: %.2fms avg (min: %.2fms, max: %.2fms, count: %d)'#10,
      [key, avg, Double(data['min']), Double(data['max']), Integer(data['count'])]);
  end;
end;

procedure ResetProfileData;
begin
  gProfileData := TJSObject.new;
end;

{ ====== PARTICLE SYSTEM ====== }
function CreateParticleSystem(maxParticles: Integer): TParticleSystem;
begin
  Result := TParticleSystem.Create(maxParticles);
  SetLength(gParticleSystems, Length(gParticleSystems) + 1);
  gParticleSystems[High(gParticleSystems)] := Result;
end;

procedure DrawParticles(particleSystem: TParticleSystem);
begin
  if Assigned(particleSystem) then
    particleSystem.Draw;
end;

procedure UpdateParticles(particleSystem: TParticleSystem; dt: Double);
begin
  if Assigned(particleSystem) then
    particleSystem.Update(dt);
end;

{ ====== LOOP / RAF ====== }
procedure GlobalAnimFrame(time: Double);
var
  desiredMs, elapsedMs: Double;
  stepMs, stepSec: Double;
  instFps: Double;
  steps, i: Integer;

  
  k: String;
const
  EPS_MS    = 2.0;
  FIXED_FPS = 60;
  MAX_STEPS = 5;
  FPS_ALPHA = 0.12;

begin
  // jeśli ktoś zatrzymał pętlę z zewnątrz – wyjdź
  if not gRunning then Exit;

  // żądanie zamknięcia (np. ESC w onKeyDownH)
  if gWantsClose then
  begin
  // NATYCHMIAST utnij audio w tej samej klatce co zamknięcie
try
  if gAudioCtx <> nil then gAudioCtx.suspend();
except
end;

try
  if gMasterGain <> nil then gMasterGain.gain.value := 0;
except
end;

    gRunning := False;
    CloseWindow;
    Exit;
  end;

  if gLastTime = 0 then
    gLastTime := time;

  elapsedMs := time - gLastTime;

  // Throttling do gTargetFPS (jeśli ustawiony)
  if (gTargetFPS > 0) then
  begin
    desiredMs := 1000.0 / gTargetFPS;
    if (elapsedMs + EPS_MS) < desiredMs then
    begin
      if gRunning then
        window.requestAnimationFrame(@GlobalAnimFrame);
      Exit;
    end;
  end;

  // --- FIXED STEP parametry (potrzebne zaraz do capów akumulatora)
  stepMs  := 1000.0 / FIXED_FPS;
  stepSec := stepMs / 1000.0;

  // aktualizacja punktu odniesienia czasu
  gLastTime := time;

  // górny limit skoku czasu (po alt-tab, hiccup itp.)
  if elapsedMs > 100.0 then
    elapsedMs := 100.0;

  // akumulacja czasu
  gTimeAccum := gTimeAccum + elapsedMs;

  // HARD CAP akumulatora – nie pozwól urosnąć bardziej niż MAX_STEPS
  if gTimeAccum > (MAX_STEPS * stepMs) then
    gTimeAccum := (MAX_STEPS * stepMs);
  W_EnsureInputInit;
  W_InputBeginFrame;
  // --- stały krok aktualizacji
  // --- stały krok aktualizacji
  steps := 0;
while (gTimeAccum >= stepMs) and (steps < MAX_STEPS) do
  begin
    gLastDt := stepSec;

    if Assigned(gCurrentUpdate) then
      gCurrentUpdate(gLastDt);

    // Update systemów cząsteczek (jak było)
    for i := 0 to High(gParticleSystems) do
      gParticleSystems[i].Update(gLastDt);

    // 🔹 PO JEDNYM KROKU UPDATE: czyścimy krawędzie klawiszy
    //    (Pressed/Released widoczne tylko w TEJ jednej iteracji pętli)
    gKeysPressed  := TJSObject.New;
    gKeysReleased := TJSObject.New;

    gTimeAccum := gTimeAccum - stepMs;
    Inc(steps);

    // pozwól wyjść w trakcie „doganiania” czasu
    if gWantsClose then
    begin
    // NATYCHMIAST utnij audio w tej samej klatce co zamknięcie
try
  if gAudioCtx <> nil then gAudioCtx.suspend();
except
end;

try
  if gMasterGain <> nil then gMasterGain.gain.value := 0;
except
end;

      gRunning := False;
      CloseWindow;
      Exit;
    end;
  end;



  // jeżeli dojechaliśmy do MAX_STEPS, przytnij nadmiar, by nie „ciągnąć ogona”
  if steps = MAX_STEPS then
    if gTimeAccum > stepMs then
      gTimeAccum := stepMs;


    // --- KONTROLA PRZED RYSOWANIEM (stos musi byc pusty) ---
  {$IFDEF WILGA_LEAK_GUARD}{$IFDEF WILGA_ASSERTS}
  if GSaveDepth <> 0 then
    raise Exception.Create('Before Draw: non-zero CanvasSave stack (GSaveDepth <> 0)');
  {$ENDIF}{$ENDIF}

  // rysowanie w ramce — koniecznie owiniete w Begin/EndDrawing
  if Assigned(gCurrentDraw) then
  begin
    BeginDrawing;
    try
      gCurrentDraw(gLastDt);
    finally
      EndDrawing; // EndDrawing ma swoj check GSaveDepth
    end;
  end;

  // --- (opcjonalnie) KONTROLA PO RYSOWANIU ---
  {$IFDEF WILGA_LEAK_GUARD}{$IFDEF WILGA_ASSERTS}
  if GSaveDepth <> 0 then
    raise Exception.Create('After Draw: CanvasSave/Restore imbalance (GSaveDepth <> 0)');
  {$ENDIF}{$ENDIF}

  // --- Per-frame input state sync (ważne dla IsMouseButtonPressed/Released)
  // --- Per-frame input state sync (ważne dla IsMouseButtonPressed/Released)
  gMouseButtonsPrev[0] := gMouseButtonsDown[0];
  gMouseButtonsPrev[1] := gMouseButtonsDown[1];
  gMouseButtonsPrev[2] := gMouseButtonsDown[2];
  gMousePrevPos := gMousePos;

  // Zresetuj „frame-based” stany klawiszy (pressed/released)
  // Tworzymy nowe, puste obiekty – jakby „czyścimy mapę”.
 // gKeysPressed  := TJSObject.New;
  //gKeysReleased := TJSObject.New;

  // Zresetuj kółko myszy
  gMouseWheelDelta := 0;

  // FPS wygładzony
  if elapsedMs <= 0.0001 then
    instFps := 1000.0
  else
    instFps := 1000.0 / elapsedMs;



  if gCurrentFps <= 0 then
    gCurrentFps := Longint(Round(instFps))
  else
    gCurrentFps := Longint(Round(FPS_ALPHA * instFps + (1.0 - FPS_ALPHA) * Double(gCurrentFps)));

  Inc(gFrameCount);
  if (window.performance.now() - gLastFpsTime) >= 1000 then
  begin
    gFrameCount := 0;
    gLastFpsTime := window.performance.now();
  end;

  if gRunning then
    window.requestAnimationFrame(@GlobalAnimFrame);
end;


procedure Run(UpdateProc: TDeltaProc);
begin
  if not Assigned(UpdateProc) then Exit;
  gCurrentUpdate := UpdateProc;
  if not gRunning then gRunning := True;

  if Assigned(gCurrentUpdate) then
  begin
    gLastDt := 0.0;
    gCurrentUpdate(gLastDt);
  end;

  window.requestAnimationFrame(@GlobalAnimFrame);
end;

procedure Run(UpdateProc: TDeltaProc; DrawProc: TDeltaProc);
begin
  gCurrentDraw := DrawProc;
  Run(UpdateProc);
end;

{ ====== FPS / ZAMKNIĘCIE ====== }
procedure DrawFPS(x, y: Integer; color: TColor);
begin
  DrawText('FPS: ' + IntToStr(GetFPS), x, y, 16, color);
end;

function WindowShouldClose: Boolean;
begin
  Result := gWantsClose;
end;

procedure SetCloseOnEscape(enable: Boolean);
begin
  gCloseOnEscape := enable;
end;

function GetCloseOnEscape: Boolean;
begin
  Result := gCloseOnEscape;
end;

{ ====== KOLORY KLASYCZNE (HTML/CSS/X11) ====== }
function COLOR_ALICEBLUE: TColor; begin Result := ColorRGBA(240, 248, 255, 255); end;
function COLOR_ANTIQUEWHITE: TColor; begin Result := ColorRGBA(250, 235, 215, 255); end;
function COLOR_AQUA: TColor; begin Result := ColorRGBA(0, 255, 255, 255); end;        { alias CYAN }
function COLOR_AQUAMARINE: TColor; begin Result := ColorRGBA(127, 255, 212, 255); end;
function COLOR_AZURE: TColor; begin Result := ColorRGBA(240, 255, 255, 255); end;
function COLOR_BEIGE: TColor; begin Result := ColorRGBA(245, 245, 220, 255); end;
function COLOR_BISQUE: TColor; begin Result := ColorRGBA(255, 228, 196, 255); end;
function COLOR_BLACK: TColor; begin Result := ColorRGBA(0, 0, 0, 255); end;
function COLOR_BLANCHEDALMOND: TColor; begin Result := ColorRGBA(255, 235, 205, 255); end;
function COLOR_BLUE: TColor; begin Result := ColorRGBA(0, 0, 255, 255); end;
function COLOR_BLUEVIOLET: TColor; begin Result := ColorRGBA(138, 43, 226, 255); end;
function COLOR_BROWN: TColor; begin Result := ColorRGBA(165, 42, 42, 255); end;
function COLOR_BURLYWOOD: TColor; begin Result := ColorRGBA(222, 184, 135, 255); end;
function COLOR_CADETBLUE: TColor; begin Result := ColorRGBA(95, 158, 160, 255); end;
function COLOR_CHARTREUSE: TColor; begin Result := ColorRGBA(127, 255, 0, 255); end;
function COLOR_CHOCOLATE: TColor; begin Result := ColorRGBA(210, 105, 30, 255); end;
function COLOR_CORAL: TColor; begin Result := ColorRGBA(255, 127, 80, 255); end;
function COLOR_CORNFLOWERBLUE: TColor; begin Result := ColorRGBA(100, 149, 237, 255); end;
function COLOR_CORNSILK: TColor; begin Result := ColorRGBA(255, 248, 220, 255); end;
function COLOR_CRIMSON: TColor; begin Result := ColorRGBA(220, 20, 60, 255); end;
function COLOR_CYAN: TColor; begin Result := ColorRGBA(0, 255, 255, 255); end;          { alias AQUA }
function COLOR_DARKBLUE: TColor; begin Result := ColorRGBA(0, 0, 139, 255); end;
function COLOR_DARKCYAN: TColor; begin Result := ColorRGBA(0, 139, 139, 255); end;
function COLOR_DARKGOLDENROD: TColor; begin Result := ColorRGBA(184, 134, 11, 255); end;
function COLOR_DARKGRAY: TColor; begin Result := ColorRGBA(169, 169, 169, 255); end;
function COLOR_DARKGREY: TColor; begin Result := ColorRGBA(169, 169, 169, 255); end;   { alias }
function COLOR_DARKGREEN: TColor; begin Result := ColorRGBA(0, 100, 0, 255); end;
function COLOR_DARKKHAKI: TColor; begin Result := ColorRGBA(189, 183, 107, 255); end;
function COLOR_DARKMAGENTA: TColor; begin Result := ColorRGBA(139, 0, 139, 255); end;
function COLOR_DARKOLIVEGREEN: TColor; begin Result := ColorRGBA(85, 107, 47, 255); end;
function COLOR_DARKORANGE: TColor; begin Result := ColorRGBA(255, 140, 0, 255); end;
function COLOR_DARKORCHID: TColor; begin Result := ColorRGBA(153, 50, 204, 255); end;
function COLOR_DARKRED: TColor; begin Result := ColorRGBA(139, 0, 0, 255); end;
function COLOR_DARKSALMON: TColor; begin Result := ColorRGBA(233, 150, 122, 255); end;
function COLOR_DARKSEAGREEN: TColor; begin Result := ColorRGBA(143, 188, 143, 255); end;
function COLOR_DARKSLATEBLUE: TColor; begin Result := ColorRGBA(72, 61, 139, 255); end;
function COLOR_DARKSLATEGRAY: TColor; begin Result := ColorRGBA(47, 79, 79, 255); end;
function COLOR_DARKSLATEGREY: TColor; begin Result := ColorRGBA(47, 79, 79, 255); end;  { alias }
function COLOR_DARKTURQUOISE: TColor; begin Result := ColorRGBA(0, 206, 209, 255); end;
function COLOR_DARKVIOLET: TColor; begin Result := ColorRGBA(148, 0, 211, 255); end;
function COLOR_DEEPPINK: TColor; begin Result := ColorRGBA(255, 20, 147, 255); end;
function COLOR_DEEPSKYBLUE: TColor; begin Result := ColorRGBA(0, 191, 255, 255); end;
function COLOR_DIMGRAY: TColor; begin Result := ColorRGBA(105, 105, 105, 255); end;
function COLOR_DIMGREY: TColor; begin Result := ColorRGBA(105, 105, 105, 255); end;     { alias }
function COLOR_DODGERBLUE: TColor; begin Result := ColorRGBA(30, 144, 255, 255); end;
function COLOR_FIREBRICK: TColor; begin Result := ColorRGBA(178, 34, 34, 255); end;
function COLOR_FLORALWHITE: TColor; begin Result := ColorRGBA(255, 250, 240, 255); end;
function COLOR_FORESTGREEN: TColor; begin Result := ColorRGBA(34, 139, 34, 255); end;
function COLOR_FUCHSIA: TColor; begin Result := ColorRGBA(255, 0, 255, 255); end;       { alias MAGENTA }
function COLOR_GAINSBORO: TColor; begin Result := ColorRGBA(220, 220, 220, 255); end;
function COLOR_GHOSTWHITE: TColor; begin Result := ColorRGBA(248, 248, 255, 255); end;
function COLOR_GOLD: TColor; begin Result := ColorRGBA(255, 215, 0, 255); end;
function COLOR_GOLDENROD: TColor; begin Result := ColorRGBA(218, 165, 32, 255); end;
function COLOR_GRAY: TColor; begin Result := ColorRGBA(128, 128, 128, 255); end;
function COLOR_GREY: TColor; begin Result := ColorRGBA(128, 128, 128, 255); end;        { alias }
function COLOR_GREEN: TColor; begin Result := ColorRGBA(0, 128, 0, 255); end;
function COLOR_GREENYELLOW: TColor; begin Result := ColorRGBA(173, 255, 47, 255); end;
function COLOR_HONEYDEW: TColor; begin Result := ColorRGBA(240, 255, 240, 255); end;
function COLOR_HOTPINK: TColor; begin Result := ColorRGBA(255, 105, 180, 255); end;
function COLOR_INDIANRED: TColor; begin Result := ColorRGBA(205, 92, 92, 255); end;
function COLOR_INDIGO: TColor; begin Result := ColorRGBA(75, 0, 130, 255); end;
function COLOR_IVORY: TColor; begin Result := ColorRGBA(255, 255, 240, 255); end;
function COLOR_KHAKI: TColor; begin Result := ColorRGBA(240, 230, 140, 255); end;
function COLOR_LAVENDER: TColor; begin Result := ColorRGBA(230, 230, 250, 255); end;
function COLOR_LAVENDERBLUSH: TColor; begin Result := ColorRGBA(255, 240, 245, 255); end;
function COLOR_LAWNGREEN: TColor; begin Result := ColorRGBA(124, 252, 0, 255); end;
function COLOR_LEMONCHIFFON: TColor; begin Result := ColorRGBA(255, 250, 205, 255); end;
function COLOR_LIGHTBLUE: TColor; begin Result := ColorRGBA(173, 216, 230, 255); end;
function COLOR_LIGHTCORAL: TColor; begin Result := ColorRGBA(240, 128, 128, 255); end;
function COLOR_LIGHTCYAN: TColor; begin Result := ColorRGBA(224, 255, 255, 255); end;
function COLOR_LIGHTGOLDENRODYELLOW: TColor; begin Result := ColorRGBA(250, 250, 210, 255); end;
function COLOR_LIGHTGRAY: TColor; begin Result := ColorRGBA(211, 211, 211, 255); end;
function COLOR_LIGHTGREY: TColor; begin Result := ColorRGBA(211, 211, 211, 255); end;    { alias }
function COLOR_LIGHTGREEN: TColor; begin Result := ColorRGBA(144, 238, 144, 255); end;
function COLOR_LIGHTPINK: TColor; begin Result := ColorRGBA(255, 182, 193, 255); end;
function COLOR_LIGHTSALMON: TColor; begin Result := ColorRGBA(255, 160, 122, 255); end;
function COLOR_LIGHTSEAGREEN: TColor; begin Result := ColorRGBA(32, 178, 170, 255); end;
function COLOR_LIGHTSKYBLUE: TColor; begin Result := ColorRGBA(135, 206, 250, 255); end;
function COLOR_LIGHTSLATEGRAY: TColor; begin Result := ColorRGBA(119, 136, 153, 255); end;
function COLOR_LIGHTSLATEGREY: TColor; begin Result := ColorRGBA(119, 136, 153, 255); end; { alias }
function COLOR_LIGHTSTEELBLUE: TColor; begin Result := ColorRGBA(176, 196, 222, 255); end;
function COLOR_LIGHTYELLOW: TColor; begin Result := ColorRGBA(255, 255, 224, 255); end;
function COLOR_LIME: TColor; begin Result := ColorRGBA(0, 255, 0, 255); end;
function COLOR_LIMEGREEN: TColor; begin Result := ColorRGBA(50, 205, 50, 255); end;
function COLOR_LINEN: TColor; begin Result := ColorRGBA(250, 240, 230, 255); end;
function COLOR_MAGENTA: TColor; begin Result := ColorRGBA(255, 0, 255, 255); end;        { alias FUCHSIA }
function COLOR_MAROON: TColor; begin Result := ColorRGBA(128, 0, 0, 255); end;
function COLOR_MEDIUMAQUAMARINE: TColor; begin Result := ColorRGBA(102, 205, 170, 255); end;
function COLOR_MEDIUMBLUE: TColor; begin Result := ColorRGBA(0, 0, 205, 255); end;
function COLOR_MEDIUMORCHID: TColor; begin Result := ColorRGBA(186, 85, 211, 255); end;
function COLOR_MEDIUMPURPLE: TColor; begin Result := ColorRGBA(147, 112, 219, 255); end;
function COLOR_MEDIUMSEAGREEN: TColor; begin Result := ColorRGBA(60, 179, 113, 255); end;
function COLOR_MEDIUMSLATEBLUE: TColor; begin Result := ColorRGBA(123, 104, 238, 255); end;
function COLOR_MEDIUMSPRINGGREEN: TColor; begin Result := ColorRGBA(0, 250, 154, 255); end;
function COLOR_MEDIUMTURQUOISE: TColor; begin Result := ColorRGBA(72, 209, 204, 255); end;
function COLOR_MEDIUMVIOLETRED: TColor; begin Result := ColorRGBA(199, 21, 133, 255); end;
function COLOR_MIDNIGHTBLUE: TColor; begin Result := ColorRGBA(25, 25, 112, 255); end;
function COLOR_MINTCREAM: TColor; begin Result := ColorRGBA(245, 255, 250, 255); end;
function COLOR_MISTYROSE: TColor; begin Result := ColorRGBA(255, 228, 225, 255); end;
function COLOR_MOCCASIN: TColor; begin Result := ColorRGBA(255, 228, 181, 255); end;
function COLOR_NAVAJOWHITE: TColor; begin Result := ColorRGBA(255, 222, 173, 255); end;
function COLOR_NAVY: TColor; begin Result := ColorRGBA(0, 0, 128, 255); end;
function COLOR_OLDLACE: TColor; begin Result := ColorRGBA(253, 245, 230, 255); end;
function COLOR_OLIVE: TColor; begin Result := ColorRGBA(128, 128, 0, 255); end;
function COLOR_OLIVEDRAB: TColor; begin Result := ColorRGBA(107, 142, 35, 255); end;
function COLOR_ORANGE: TColor; begin Result := ColorRGBA(255, 165, 0, 255); end;
function COLOR_ORANGERED: TColor; begin Result := ColorRGBA(255, 69, 0, 255); end;
function COLOR_ORCHID: TColor; begin Result := ColorRGBA(218, 112, 214, 255); end;
function COLOR_PALEGOLDENROD: TColor; begin Result := ColorRGBA(238, 232, 170, 255); end;
function COLOR_PALEGREEN: TColor; begin Result := ColorRGBA(152, 251, 152, 255); end;
function COLOR_PALETURQUOISE: TColor; begin Result := ColorRGBA(175, 238, 238, 255); end;
function COLOR_PALEVIOLETRED: TColor; begin Result := ColorRGBA(219, 112, 147, 255); end;
function COLOR_PAPAYAWHIP: TColor; begin Result := ColorRGBA(255, 239, 213, 255); end;
function COLOR_PEACHPUFF: TColor; begin Result := ColorRGBA(255, 218, 185, 255); end;
function COLOR_PERU: TColor; begin Result := ColorRGBA(205, 133, 63, 255); end;
function COLOR_PINK: TColor; begin Result := ColorRGBA(255, 192, 203, 255); end;
function COLOR_PLUM: TColor; begin Result := ColorRGBA(221, 160, 221, 255); end;
function COLOR_POWDERBLUE: TColor; begin Result := ColorRGBA(176, 224, 230, 255); end;
function COLOR_PURPLE: TColor; begin Result := ColorRGBA(128, 0, 128, 255); end;
function COLOR_REBECCAPURPLE: TColor; begin Result := ColorRGBA(102, 51, 153, 255); end;
function COLOR_RED: TColor; begin Result := ColorRGBA(255, 0, 0, 255); end;
function COLOR_ROSYBROWN: TColor; begin Result := ColorRGBA(188, 143, 143, 255); end;
function COLOR_ROYALBLUE: TColor; begin Result := ColorRGBA(65, 105, 225, 255); end;
function COLOR_SADDLEBROWN: TColor; begin Result := ColorRGBA(139, 69, 19, 255); end;
function COLOR_SALMON: TColor; begin Result := ColorRGBA(250, 128, 114, 255); end;
function COLOR_SANDYBROWN: TColor; begin Result := ColorRGBA(244, 164, 96, 255); end;
function COLOR_SEAGREEN: TColor; begin Result := ColorRGBA(46, 139, 87, 255); end;
function COLOR_SEASHELL: TColor; begin Result := ColorRGBA(255, 245, 238, 255); end;
function COLOR_SIENNA: TColor; begin Result := ColorRGBA(160, 82, 45, 255); end;
function COLOR_SILVER: TColor; begin Result := ColorRGBA(192, 192, 192, 255); end;
function COLOR_SKYBLUE: TColor; begin Result := ColorRGBA(135, 206, 235, 255); end;
function COLOR_SLATEBLUE: TColor; begin Result := ColorRGBA(106, 90, 205, 255); end;
function COLOR_SLATEGRAY: TColor; begin Result := ColorRGBA(112, 128, 144, 255); end;
function COLOR_SLATEGREY: TColor; begin Result := ColorRGBA(112, 128, 144, 255); end;    { alias }
function COLOR_SNOW: TColor; begin Result := ColorRGBA(255, 250, 250, 255); end;
function COLOR_SPRINGGREEN: TColor; begin Result := ColorRGBA(0, 255, 127, 255); end;
function COLOR_STEELBLUE: TColor; begin Result := ColorRGBA(70, 130, 180, 255); end;
function COLOR_TAN: TColor; begin Result := ColorRGBA(210, 180, 140, 255); end;
function COLOR_TEAL: TColor; begin Result := ColorRGBA(0, 128, 128, 255); end;
function COLOR_THISTLE: TColor; begin Result := ColorRGBA(216, 191, 216, 255); end;
function COLOR_TOMATO: TColor; begin Result := ColorRGBA(255, 99, 71, 255); end;
function COLOR_TURQUOISE: TColor; begin Result := ColorRGBA(64, 224, 208, 255); end;
function COLOR_VIOLET: TColor; begin Result := ColorRGBA(238, 130, 238, 255); end;
function COLOR_WHEAT: TColor; begin Result := ColorRGBA(245, 222, 179, 255); end;
function COLOR_WHITE: TColor; begin Result := ColorRGBA(255, 255, 255, 255); end;
function COLOR_WHITESMOKE: TColor; begin Result := ColorRGBA(245, 245, 245, 255); end;
function COLOR_YELLOW: TColor; begin Result := ColorRGBA(255, 255, 0, 255); end;
function COLOR_YELLOWGREEN: TColor; begin Result := ColorRGBA(154, 205, 50, 255); end;
function COLOR_TRANSPARENT : TColor; begin Result := ColorRGBA(0, 0, 0, 0); end;

// ====== DODATKOWE POMOCNICZE PROCEDURY – KWADRATY I OBRYSY ======

procedure DrawSquare(x, y, size: double; const color: TColor);
begin
  DrawRectangle(x, y, size, size, color);
end;

procedure DrawSquareLines(x, y, size: double; const color: TColor; thickness: Integer = 1);
begin
  DrawRectangleLines(x, y, size, size, color, thickness);
end;

procedure DrawSquareFromCenter(cx, cy, size: double; const color: TColor);
var
  x, y: double;
begin
  x := cx - (size / 2);
  y := cy - (size / 2);
  DrawRectangle(x, y, size, size, color);
end;

procedure DrawSquareFromCenterLines(cx, cy, size: double; const color: TColor; thickness: Integer = 1);
var
  x, y: double;
begin
  x := cx - (size / 2);
  y := cy - (size / 2);
  DrawRectangleLines(x, y, size, size, color, thickness);
end;

// Obrys zaokrąglonego prostokąta z kontrolą grubości
procedure DrawRectangleRoundedStroke(x, y, w, h, radius: double; const color: TColor; thickness: Integer = 1);
begin
  gCtx.lineWidth := thickness;
  DrawRectangleRounded(x, y, w, h, radius, color, False);
end;

procedure DrawRectangleRoundedRecStroke(const rec: TRectangle; radius: Double; const color: TColor; thickness: Integer = 1);
begin
  gCtx.lineWidth := thickness;
  DrawRectangleRounded(Round(rec.x), Round(rec.y), Round(rec.width), Round(rec.height), Round(radius), color, False);
end;

procedure DrawRectangleFromCenter(cx, cy, w, h: Double; const color: TColor);
var
  x, y: Double;
begin
  x := cx - (w / 2);
  y := cy - (h / 2);
  DrawRectangle(x, y, w, h, color);
end;

procedure DrawCircleFromCenter(cx, cy, radius: Double; const color: TColor);
begin
  DrawCircle(cx, cy, radius, color);
end;

// Batch obrysów prostokątów (analogiczny do batch fill)
procedure BeginRectStrokeBatch(const color: TColor; thickness: Integer = 1);
begin
  gCtx.beginPath;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);
  gCtx.lineWidth := thickness;
end;

procedure BatchRectStroke(x, y, w, h: Integer);
begin
  gCtx.rect(x, y, w, h);
end;

procedure EndRectStrokeBatch;
begin
  gCtx.stroke;
end;

// ====== Batch trójkątów ======

procedure BeginTriangleBatch(const color: TColor);
begin
  gCtx.beginPath;
  WSetFill(ColorToCanvasRGBA(color));
end;

procedure BatchTriangle(const tri: TTriangle);
begin
  gCtx.moveTo(tri.p1.x, tri.p1.y);
  gCtx.lineTo(tri.p2.x, tri.p2.y);
  gCtx.lineTo(tri.p3.x, tri.p3.y);
  gCtx.closePath;
end;

procedure EndTriangleBatchFill;
begin
  gCtx.fill;
end;

procedure BeginTriangleStrokeBatch(const color: TColor; thickness: Integer = 1);
begin
  gCtx.beginPath;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);
  gCtx.lineWidth   := thickness;
end;

procedure BatchTriangleStroke(const tri: TTriangle);
begin
  // Reużywamy tę samą ścieżkę co przy fill
  BatchTriangle(tri);
end;

procedure EndTriangleStrokeBatch;
begin
  gCtx.stroke;
end;


// ====== Batch wielokątów ======

procedure BeginPolygonBatch(const color: TColor);
begin
  gCtx.beginPath;
  WSetFill(ColorToCanvasRGBA(color));
end;

procedure BatchPolygon(const points: array of TInputVector);
var
  i: Integer;
begin
  if Length(points) < 3 then Exit; // wymóg — min. trójkąt
  gCtx.moveTo(points[0].x, points[0].y);
  for i := 1 to High(points) do
    gCtx.lineTo(points[i].x, points[i].y);
  gCtx.closePath;
end;

procedure EndPolygonBatchFill;
begin
  gCtx.fill;
end;

procedure BeginPolygonStrokeBatch(const color: TColor; thickness: Integer = 1);
begin
  gCtx.beginPath;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);
  gCtx.lineWidth   := thickness;
end;

procedure BatchPolygonStroke(const points: array of TInputVector);
begin
  BatchPolygon(points); // ta sama ścieżka, będzie tylko stroke
end;

procedure EndPolygonStrokeBatch;
begin
  gCtx.stroke;
end;


// ====== „One-shot” — wygodne zbiorcze rysowanie ======

procedure DrawTrianglesBatch(const tris: array of TTriangle; const color: TColor;
  filled: Boolean = True; thickness: Integer = 1);
var
  i: Integer;
begin
  if filled then begin
    BeginTriangleBatch(color);
    for i := 0 to High(tris) do
      BatchTriangle(tris[i]);
    EndTriangleBatchFill;
  end else begin
    BeginTriangleStrokeBatch(color, thickness);
    for i := 0 to High(tris) do
      BatchTriangleStroke(tris[i]);
    EndTriangleStrokeBatch;
  end;
end;

procedure DrawPolygonsBatch(const polys: TPolygons; const color: TColor;
  filled: Boolean = True; thickness: Integer = 1);

var
  i: Integer;
begin
  if filled then begin
    BeginPolygonBatch(color);
    for i := 0 to High(polys) do
      BatchPolygon(polys[i]);
    EndPolygonBatchFill;
  end else begin
    BeginPolygonStrokeBatch(color, thickness);
    for i := 0 to High(polys) do
      BatchPolygonStroke(polys[i]);
    EndPolygonStrokeBatch;
  end;
end;
// ====== NOWE one-shot batch ======
procedure DrawRectsBatch(const rects: array of TRectangle; const color: TColor;
  filled: Boolean = True; thickness: Integer = 1);
var
  i: Integer;
  r: TRectangle;
begin
  if filled then begin
    BeginRectBatch(color);
    for i := 0 to High(rects) do begin
      r := rects[i];
      BatchRect(Round(r.x), Round(r.y), Round(r.width), Round(r.height));
    end;
    EndRectBatchFill;
  end else begin
    BeginRectStrokeBatch(color, thickness);
    for i := 0 to High(rects) do begin
      r := rects[i];
      BatchRectStroke(Round(r.x), Round(r.y), Round(r.width), Round(r.height));
    end;
    EndRectStrokeBatch;
  end;
end;

procedure DrawCirclesBatch(const circles: array of TCircle; const color: TColor;
  filled: Boolean = True; thickness: Integer = 1);
var
  i: Integer;
  c: TCircle;
begin
  if filled then begin
    BeginCircleBatch(color);
    for i := 0 to High(circles) do begin
      c := circles[i];
      BatchCircle(c.cx, c.cy, c.radius);
    end;
    EndCircleBatchFill;
  end else begin
    BeginCircleStrokeBatch(color, thickness);
    for i := 0 to High(circles) do begin
      c := circles[i];
      BatchCircleStroke(c.cx, c.cy, c.radius);
    end;
    EndCircleStrokeBatch;
  end;
end;

procedure DrawLinesBatch(const lines: array of TLine; const color: TColor;
  thickness: Integer = 1);
var
  i: Integer;
begin
  BeginLineBatch;
  for i := 0 to High(lines) do begin
    BatchLineV(lines[i].startPoint, lines[i].endPoint, color, thickness);
  end;
  EndLineBatch;
end;

procedure DrawPixelsBatch(const points: array of TInputVector; const color: TColor);
var
  i: Integer;
begin
  BeginPixelBatch;
  for i := 0 to High(points) do
    BatchPixelV(points[i], color);
  EndPixelBatch;
end;

procedure SaveCanvasPNG(ACanvas: TJSHTMLCanvasElement; const FileName: string = 'wilga-export.png');
begin
  ACanvas.toBlob(
    function (B: TJSBlob): Boolean
    var
      a: TJSHTMLAnchorElement;
      href: string;
    begin
      a := TJSHTMLAnchorElement(document.createElement('a'));

      // statyczna metoda klasy TJSURL (unit Web)
      href := TJSURL.createObjectURL(B);
      a.href := href;

      if FileName = '' then
        a.download := 'wilga-export.png'
      else
        a.download := FileName;

      a.click;

      // sprzątanie URL
      window.setTimeout(
        procedure
        begin
          TJSURL.revokeObjectURL(href);
        end, 0);

      Result := True;  // <--- ważne, bo callback ma zwrócić Boolean
    end,
    'image/png'
  );
end;

procedure SaveCanvasJPEG(ACanvas: TJSHTMLCanvasElement; const FileName: string = 'wilga-export.jpg'; Quality: Double = 0.92);
begin
  if (Quality < 0) or (Quality > 1) then
    Quality := 0.92;

  ACanvas.toBlob(
    function (B: TJSBlob): Boolean
    var
      a: TJSHTMLAnchorElement;
      href: string;
    begin
      a := TJSHTMLAnchorElement(document.createElement('a'));

      href := TJSURL.createObjectURL(B);
      a.href := href;

      if FileName = '' then
        a.download := 'wilga-export.jpg'
      else
        a.download := FileName;

      a.click;

      window.setTimeout(
        procedure
        begin
          TJSURL.revokeObjectURL(href);
        end, 0);

      Result := True;
    end,
    'image/jpeg',
    Quality
  );
end;

procedure CopyCanvasToClipboard(ACanvas: TJSHTMLCanvasElement);
begin
  ACanvas.toBlob(
    function (B: TJSBlob): Boolean
    begin
      asm
        if (navigator && navigator.clipboard && window.ClipboardItem) {
          const it = new ClipboardItem({[B.type]: B});
          navigator.clipboard.write([it]);
        }
      end;
      Result := True;
    end,
    'image/png'
  );
end;

procedure WilgaSavePNG(const FileName: string = 'wilga-export.png');
begin
  SaveCanvasPNG(gCanvas, FileName);
end;

procedure WilgaSaveJPEG(const FileName: string = 'wilga-export.jpg'; Quality: Double = 0.92);
begin
  SaveCanvasJPEG(gCanvas, FileName, Quality);
end;

procedure WilgaCopyToClipboard;
begin
  CopyCanvasToClipboard(gCanvas);
end;

procedure Push; inline;
begin
  CanvasSave;
end;

procedure Pop; inline;
begin
  CanvasRestore;
end;



procedure CanvasSetGlobalAlpha(const A: Double);
begin
  SetGlobalAlpha(A);
end;


procedure CanvasSetFillColor(const C: TColor);
begin
  WSetFill(ColorToCanvasRGBA(C));
end;

procedure CanvasSetShadow(const C: TColor; const Blur: Double);
begin
  gCtx.shadowColor := ColorToCanvasRGBA(C);
  gCtx.shadowBlur := Blur;
end;

procedure CanvasClearShadow;
begin
  gCtx.shadowColor := 'rgba(0,0,0,0)';
  gCtx.shadowBlur := 0;
end;

procedure CanvasFillCircle(const X, Y, Radius: Double);
begin
  gCtx.beginPath;
  gCtx.arc(X, Y, Radius, 0, 2*PI);
  gCtx.fill;
end;

procedure CanvasFillDisc(const X, Y, Radius: Double; const Alpha: Double;
                         const Fill, Shadow: TColor; const ShadowBlur: Double);
begin
  CanvasSave;
  try
    CanvasSetGlobalAlpha(Alpha);
    CanvasSetFillColor(Fill);
    CanvasSetShadow(Shadow, ShadowBlur);
    CanvasFillCircle(X, Y, Radius);
  finally
    CanvasRestore;
  end;
end;
procedure SetBlendMode(const mode: TBlendMode);
begin
  gCurrentBlendMode := mode;  // zapamiętujemy
  case mode of
    bmNormal:    WSetOp('source-over');
    bmAdd:       WSetOp('lighter');
    bmMultiply:  WSetOp('multiply');
    bmScreen:    WSetOp('screen');
  end;
end;
procedure SetTintMode(const Mode: TTintModeSimple);
begin
  case Mode of
    TINT_REPAINT:
      wilga_tint_cache.SetDefaultTintMode(wilga_tint_cache.tmRepaint);
    TINT_MULTIPLY:
      wilga_tint_cache.SetDefaultTintMode(wilga_tint_cache.tmMultiply);
  end;
end;

function GetTintMode: TTintModeSimple;
begin
  case wilga_tint_cache.GetDefaultTintMode of
    wilga_tint_cache.tmRepaint:  Result := TINT_REPAINT;
    wilga_tint_cache.tmMultiply: Result := TINT_MULTIPLY;
  else
    Result := TINT_MULTIPLY;
  end;
end;



// === Convenience Vector Helpers (ergonomia) ===
function Vec(x, y: Double): TVector2; inline;
begin
  Result := Vector2Create(x, y);
end;

function VecZero: TInputVector; inline;
begin
  Result := Vec(0, 0);
end;

function VecOne: TInputVector; inline;
begin
  Result := Vec(1, 1);
end;

procedure Deconstruct(const v: TInputVector; out x, y: Double); inline;
begin
  x := v.x; y := v.y;
end;

function VecPerp(const v: TInputVector): TInputVector; inline;
begin
  Result := Vec(-v.y, v.x);
end;

function VecDot(const a, b: TInputVector): Double; inline;
begin
  Result := a.x*b.x + a.y*b.y;
end;

function VecClampLength(const v: TInputVector; maxLen: Double): TInputVector; inline;
var
  len: Double;
begin
  len := Vector2Length(v);
  if (len > 0) and (len > maxLen) then
    Result := Vector2Scale(v, maxLen / len)
  else
    Result := v;
end;

procedure VecAddInPlace(var a: TInputVector; const b: TInputVector); inline;
begin
  a.x += b.x; a.y += b.y;
end;

procedure VecScaleInPlace(var a: TInputVector; const s: Double); inline;
begin
  a.x *= s; a.y *= s;
end;

procedure VecNormalizeInPlace(var a: TInputVector); inline;
begin
  a := Vector2Normalize(a);
end;

procedure PolyTranslateInPlace(var poly: array of TInputVector; const d: TInputVector);
var i: SizeInt;
begin
  for i := Low(poly) to High(poly) do begin
    poly[i].x += d.x;
    poly[i].y += d.y;
  end;
end;

procedure PolyScaleInPlace(var poly: array of TInputVector; const s: Double);
var i: SizeInt;
begin
  for i := Low(poly) to High(poly) do begin
    poly[i].x *= s;
    poly[i].y *= s;
  end;
end;

procedure PolyRotateInPlace(var poly: array of TInputVector; angleRad: Double);
var i: SizeInt; c, si, nx, ny: Double;
begin
  c := Cos(angleRad); si := Sin(angleRad);
  for i := Low(poly) to High(poly) do begin
    nx := poly[i].x*c - poly[i].y*si;
    ny := poly[i].x*si + poly[i].y*c;
    poly[i].x := nx; poly[i].y := ny;
  end;
END;
procedure W_InitMeasureCanvas;
begin
  if gMeasureCanvas <> nil then Exit;

  asm
    var c = document.createElement('canvas');
    c.width  = 1;
    c.height = 1;
    $mod.gMeasureCanvas = c;
    $mod.gMeasureCtx = c.getContext('2d');
  end;
end;

procedure WilgaResize(Canvas: TJSHTMLCanvasElement; CSSW, CSSH: Integer; DPR: Double);
var
  d: Double;
begin
  if DPR <= 0 then
    d := window.devicePixelRatio
  else
    d := DPR;

  asm
    var cnv = Canvas;
    var off = cnv && cnv.__wilgaOffscreen ? cnv.__wilgaOffscreen : null;
    var w = Math.round(CSSW * d);
    var h = Math.round(CSSH * d);

    if (off) {
      off.width  = w;
      off.height = h;
    } else if (cnv) { // przed transferem: zwykły canvas
      cnv.width  = w;
      cnv.height = h;
    }
  end;

  // Przywróć transform i smoothing (po zmianie rozmiaru canvas resetuje stan)
  if gCtx <> nil then
  begin
    gCtx.setTransform(d, 0, 0, d, 0, 0);
    TJSObject(gCtx)['imageSmoothingEnabled'] := gImageSmoothingWanted;  // ← NOWE
  end;

  // Zsynchronizuj ShadowState z nowym rozmiarem i wyczyść cache
  WSyncSizeFromCanvas(Canvas);
  WResetShadow;
end;

function WilgaInitContextFromCanvas(const Canvas: TJSHTMLCanvasElement): TJSCanvasRenderingContext2D;
var
  ctx: TJSCanvasRenderingContext2D;
begin
  ctx := nil;

  asm
    var cnv = Canvas;
    var ctxProxy = null;

    // Offscreen + Worker
    if (cnv &&
        typeof cnv.transferControlToOffscreen === "function" &&
        typeof Worker === "function") {

      // 1) OffscreenCanvas tylko raz
      var off = cnv.__wilgaOffscreen;
      if (!off) {
        off = cnv.transferControlToOffscreen();
        cnv.__wilgaOffscreen = off;

        // flaga: czy wysłaliśmy już initCanvas do workera
        off.__wilgaInitSent = false;
      }

      // 2) Worker globalnie
      var worker = window.__wilgaRenderWorker;
      if (!worker) {
        worker = new Worker("wilga-render-worker.js");
        window.__wilgaRenderWorker = worker;
      }

      // 3) Proxy kontekstu
      ctxProxy = window.__wilgaRenderCtxProxy;
      if (!ctxProxy) {
        (function() {
          var proxy = {};
          var frameCmds = [];

          function queue(cmd) { frameCmds.push(cmd); }

          window.__wilgaBeginFrame = function() {
            frameCmds = [];
          };

          window.__wilgaSubmitFrame = function() {
            if (!worker) return;
            worker.postMessage({ type: "frame", cmds: frameCmds });
            frameCmds = [];
          };

          function defProp(name, type) {
            Object.defineProperty(proxy, name, {
              set: function(v) {
                // zapamiętaj ostatnią ustawioną wartość na proxy
                proxy['__' + name] = v;

                // PRZYGOTUJ wersję bez funkcji dla workera
                var sendValue = v;
                if (v && v.__wilgaGradient) {
                  // wyślij TYLKO uchwyt, bez metod (funkcji)
                  sendValue = { __wilgaGradient: v.__wilgaGradient };
                }

                // wyślij komendę do workera
                queue({ m: type, v: sendValue });
              },
              get: function() {
                // zwróć ostatnią znaną wartość (z metodami)
                return proxy['__' + name];
              }
            });
          }


          defProp("fillStyle", "setFillStyle");
          defProp("strokeStyle", "setStrokeStyle");
          defProp("shadowColor", "setShadowColor");
          defProp("shadowBlur", "setShadowBlur");
          defProp("font", "setFont");
          defProp("lineWidth", "setLineWidth");
          defProp("lineJoin", "setLineJoin");
          defProp("lineCap", "setLineCap");
          defProp("textAlign", "setTextAlign");
          defProp("textBaseline", "setTextBaseline");
          defProp("globalAlpha", "setGlobalAlpha");
          defProp("globalCompositeOperation", "setGlobalCompositeOperation");
          defProp("imageSmoothingEnabled", "setImageSmoothingEnabled");

        var methods = [
  "save","restore",
  "scale","rotate","translate","transform","setTransform",
  "beginPath","closePath","moveTo","lineTo",
  "quadraticCurveTo","bezierCurveTo",
  "arc","arcTo","rect","ellipse",
  "fill","stroke","clip",
  "clearRect","fillRect","strokeRect",
  "setLineDash",
  "fillText","strokeText"
];


          methods.forEach(function(fn) {
            proxy[fn] = function() {
              queue({ m:"call", fn:fn, a:Array.prototype.slice.call(arguments) });
            };
          });
          // --- specjalna metoda dla Wilgi: dodaj bufor pikseli jako komendę ---
          proxy.__wilgaPutImageData = function(x, y, width, height, buffer) {
            queue({
              m:      "putImageData",
              x:      x,
              y:      y,
              width:  width,
              height: height,
              buffer: buffer
            });
         }

                    // --- gradienty: createLinearGradient / createRadialGradient ---
          if (!window.__wilgaNextGradientId) {
            window.__wilgaNextGradientId = 1;
          }

          proxy.createLinearGradient = function(x0, y0, x1, y1) {
            var id = window.__wilgaNextGradientId++;
            // utwórz gradient w workerze
            queue({
              m:  "createLinearGradient",
              id: id,
              x0: x0,
              y0: y0,
              x1: x1,
              y1: y1
            });
            // zwracamy "uchwyt" z metodą addColorStop
            return {
              __wilgaGradient: id,
              addColorStop: function(offset, color) {
                queue({
                  m:     "gradientAddColorStop",
                  id:    id,
                  offset: offset,
                  color:  color
                });
              }
            };
          };

          proxy.createRadialGradient = function(x0, y0, r0, x1, y1, r1) {
            var id = window.__wilgaNextGradientId++;
            queue({
              m:  "createRadialGradient",
              id: id,
              x0: x0,
              y0: y0,
              r0: r0,
              x1: x1,
              y1: y1,
              r1: r1
            });
            return {
              __wilgaGradient: id,
              addColorStop: function(offset, color) {
                queue({
                  m:     "gradientAddColorStop",
                  id:    id,
                  offset: offset,
                  color:  color
                });
              }
            };
          };

          // drawImage przez texId
          proxy.drawImage = function(img) {
            var texId = img && img.__wilgaTexId;
            if (!texId) return;
            var args = Array.prototype.slice.call(arguments, 1);
            queue({ m:"drawImage", texId: texId, a: args });
          };

          window.__wilgaRenderCtxProxy = proxy;
          ctxProxy = proxy;
        })();


  }

      // 4) init OffscreenCanvas w workerze (TYLKO RAZ)
      if (!off.__wilgaInitSent) {
        worker.postMessage({ type: "initCanvas", canvas: off }, [off]);
        off.__wilgaInitSent = true;
      }


      // 4.5) podpięcie resize → worker.resize
      if (!window.__wilgaAttachResizeSync) {
        window.__wilgaAttachResizeSync = function(cnv, worker, off) {
          var lastWidth  = cnv.width;
          var lastHeight = cnv.height;

          function sendResizeIfNeeded() {
            if (!worker) return;

            var w = cnv.width;
            var h = cnv.height;

            if (w === lastWidth && h === lastHeight) return;
            lastWidth  = w;
            lastHeight = h;

            worker.postMessage({
              type:  "resize",
              width: w,
              height: h
            });
          }

          if (typeof ResizeObserver === "function") {
            var ro = new ResizeObserver(function() {
              sendResizeIfNeeded();
            });
            ro.observe(cnv);
          } else {
            window.addEventListener("resize", sendResizeIfNeeded);
          }

          // pierwszy stan
          sendResizeIfNeeded();
        };
      }

      window.__wilgaAttachResizeSync(cnv, worker, off);

      // 5) flush zaległych tekstur (załadowanych przed workerem)
      if (window.__wilgaPendingTextures && window.__wilgaPendingTextures.length) {
        var list = window.__wilgaPendingTextures;
        window.__wilgaPendingTextures = [];

        list.forEach(function(cnv2) {
          if (!cnv2) return;

          if (!cnv2.__wilgaTexId) {
            if (!window.__wilgaNextTexId) window.__wilgaNextTexId = 1;
            cnv2.__wilgaTexId = window.__wilgaNextTexId++;
          }
          var id2 = cnv2.__wilgaTexId;

          if (typeof createImageBitmap === "function") {
            createImageBitmap(cnv2).then(function(bmp) {
              worker.postMessage(
                { type:"registerTexture", id:id2, bitmap:bmp },
                [bmp]
              );
            });
          }
        });
      }
    }

    // fallback – zwykły 2D, gdy Offscreen/Worker niedostępny
    if (!ctxProxy && cnv && typeof cnv.getContext === "function") {
      ctxProxy = cnv.getContext("2d");
    }

    ctx = ctxProxy;
  end;

  Result := TJSCanvasRenderingContext2D(ctx);
end;




function WilgaEnsureCanvasRef: Boolean;
var c: TJSHTMLCanvasElement;
begin
  // Jeśli już mamy — gotowe
  if (gCanvas <> nil) then Exit(True);

  // 1) spróbuj wyciągnąć z gCtx.canvas
  c := nil;
  if gCtx <> nil then
  begin
    asm
      var cc = (gCtx && gCtx.canvas) ? gCtx.canvas : null;
      c = cc;
    end;
  end;
  if c <> nil then
  begin
    gCanvas := c;
    Exit(True);
  end;

  // 2) spróbuj znaleźć #game
  c := TJSHTMLCanvasElement(document.getElementById('game'));
  if c <> nil then
  begin
    gCanvas := c;
    Exit(True);
  end;

  // 3) weź pierwszy <canvas> w DOM
  asm
    var q = document && document.querySelector ? document.querySelector('canvas') : null;
    c = q;
  end;
  if c <> nil then
  begin
    gCanvas := c;
    Exit(True);
  end;

  Result := False; // nadal nie ma
end;

procedure BeginCanvasState(out Guard: TCanvasStateGuard);
begin
  CanvasSave;
end;

procedure EndCanvasState(var Guard: TCanvasStateGuard);
begin
  CanvasRestore;
end;

procedure _CtxSaveRaw;
begin
  gCtx.save;       
end;

procedure _CtxRestoreRaw;
begin
  gCtx.restore;
  // ShadowState: restore changes canvas state; invalidate cache
  WResetShadow;
end;




{$IFDEF WILGA_LEAK_GUARD} var GDebugTag: String = ''; {$ENDIF}
procedure WilgaDebugSetTag(const S: String); begin {$IFDEF WILGA_LEAK_GUARD} GDebugTag := S; {$ENDIF} end;
procedure WilgaDebugClearTag; begin {$IFDEF WILGA_LEAK_GUARD} GDebugTag := ''; {$ENDIF} end;

procedure CanvasSave;
begin
  _CtxSaveRaw;
  {$IFDEF WILGA_LEAK_GUARD}
  Inc(GSaveDepth);
  {$IFDEF WILGA_ASSERTS}
  {$ENDIF}
  {$ENDIF}
end;


procedure CanvasRestore;
begin
  {$IFDEF WILGA_LEAK_GUARD}{$IFDEF WILGA_ASSERTS}
  if GSaveDepth = 0 then
  begin
    writeln('EXTRA CanvasRestore (no user Save) - ignored');
    Exit;
  end;
  {$ENDIF}{$ENDIF}

  _CtxRestoreRaw;

  {$IFDEF WILGA_LEAK_GUARD}
  Dec(GSaveDepth);
  {$IFDEF WILGA_ASSERTS}
  if GSaveDepth < 0 then
    writeln('CanvasRestore underflow'); // diagnostyka, nie wchodzi przy warunku powyzej
  {$ENDIF}{$ENDIF}
end;

{=========================  INPUT (MOUSE) – STABLE =========================}
{==================== INPUT (mouse) — pas2js safe, bez logów ====================}
const
  W_DBLCLICK_DELAY_MS = 300;
  W_DBLCLICK_MOVE_PX  = 8;
  MOUSE_EVT_CAP       = 1024;

type
 
  TFloat  = Double;

  TMouseEvtKind = (meDown, meUp, meWheel, meForceUp,meMove);
  TMouseEvt = record
    kind  : TMouseEvtKind;
    btn   : Integer;     // 0..2
    delta : Integer;     // wheel
    timeMS: TTimeMS;
    x, y  : TFloat;      // pozycja w momencie zdarzenia
  end;

var
  // stan ciągły


  // zbocza (na jedną klatkę)

  // double-click
  W_DoubleClicked  : array[0..2] of Boolean;
  W_LastUpTimeMS   : array[0..2] of TTimeMS;
  W_LastUpPos      : array[0..2] of TVector2;

  // wheel (zeruj po Draw na końcu ramki)


  // kolejka zdarzeń
  Mq               : array[0..MOUSE_EVT_CAP-1] of TMouseEvt;
  MqHead, MqTail   : Integer;





procedure _MqPush(const ev: TMouseEvt); inline;
var n: Integer;
begin
  n := (MqTail + 1) mod MOUSE_EVT_CAP;
  if n = MqHead then Exit; // overflow – ignoruj najstarsze (skrajnie rzadko)
  Mq[MqTail] := ev; MqTail := n;
end;

function _MqPop(out ev: TMouseEvt): Boolean; inline;
begin
  Result := (MqHead <> MqTail);
  if Result then begin ev := Mq[MqHead]; MqHead := (MqHead + 1) mod MOUSE_EVT_CAP; end;
end;

// ===== JS-callable (identyczne nagłówki jak w interface) =====
procedure W_OnPointerMove(x, y: Integer);
var
  ev: TMouseEvt;
begin
  // nadal aktualizujemy globalną pozycję
  gMousePos.x := x;
  gMousePos.y := y;

  // dodajemy event ruchu do kolejki
  ev.kind   := meMove;
  ev.btn    := 0;       // brak konkretnego przycisku
  ev.delta  := 0;
  ev.timeMS := _NowMS;
  ev.x      := x;
  ev.y      := y;
  _MqPush(ev);
end;


procedure W_OnPointerDown(btn: Integer);
var ev: TMouseEvt; p: TInputVector;
begin
  if (btn < 0) or (btn > 2) then Exit;
  p := GetMousePosition;
  ev.kind := meDown; ev.btn := btn; ev.delta := 0;
  ev.timeMS := _NowMS; ev.x := p.x; ev.y := p.y;
  _MqPush(ev);
end;

procedure W_OnPointerUp(btn: Integer);
var ev: TMouseEvt; p: TInputVector;
begin
  if (btn < 0) or (btn > 2) then Exit;
  p := GetMousePosition;
  ev.kind := meUp; ev.btn := btn; ev.delta := 0;
  ev.timeMS := _NowMS; ev.x := p.x; ev.y := p.y;
  _MqPush(ev);
end;

procedure W_OnWheel(delta: Integer);
var ev: TMouseEvt; p: TInputVector;
begin
  p := GetMousePosition;
  ev.kind := meWheel; ev.btn := 0; ev.delta := delta;
  ev.timeMS := _NowMS; ev.x := p.x; ev.y := p.y;
  _MqPush(ev);
end;

procedure W_OnBlurOrLeave(dummy: Integer);
var b: Integer; ev: TMouseEvt; p: TInputVector;
begin
  p := GetMousePosition;
  for b := 0 to 2 do
    if W_CurrDown[b] then
    begin
      ev.kind := meForceUp; ev.btn := b; ev.delta := 0;
      ev.timeMS := _NowMS; ev.x := p.x; ev.y := p.y;
      _MqPush(ev);
    end;
end;

// ===== Per-frame: przetwarzanie kolejki i stany krawędzi =====
procedure W_InputBeginFrame;
var
  ev: TMouseEvt;
  b: Integer;
  nowMS, dt: TTimeMS;
  dx, dy: TFloat;
  pos: TVector2;
begin
  // --- 0) przenieś zatrzaski z poprzedniej ramki + HOLD krawędzi ---
  nowMS := _NowMS;
  for b := 0 to 2 do
  begin
    // Pressed widoczne, jeśli: przyszła krawędź w tej ramce LUB trwa okno hold
    if W_PressedNext[b] then
      Inc(W_DBG_Pressed); // licznik krawędzi (jeśli używasz)

    W_Pressed[b]  := W_PressedNext[b] or (nowMS <= W_PressedUntilMS[b]);
    W_Released[b] := W_ReleasedNext[b];

    // wyczyść zatrzaski – zostały przeniesione
    W_PressedNext[b]  := False;
    W_ReleasedNext[b] := False;

    // double-click reset na nową ramkę
    W_DoubleClicked[b] := False;
  end;

  // --- 1) Opróżnij kolejkę surowych zdarzeń i USTAW ZATRZASKI na następną ramkę ---
while _MqPop(ev) do
begin
  case ev.kind of
    meWheel:
      Inc(gMouseWheelDelta, ev.delta);

    meDown:
      begin
        if not W_CurrDown[ev.btn] then
        begin
          W_CurrDown[ev.btn]       := True;
          W_DownTimeMS[ev.btn]     := ev.timeMS;

          // krawędź Pressed na NASTĘPNĄ ramkę + okno HOLD
          W_PressedNext[ev.btn]    := True;
          W_PressedUntilMS[ev.btn] := ev.timeMS + W_PRESSED_HOLD_MS;

          // DODANE: pokaż Pressed TAKŻE W TEJ RAMCE (zmniejsza lag o 1 frame)
          W_Pressed[ev.btn]        := True;
        end;
      end;

    meUp, meForceUp:
      begin
        if W_CurrDown[ev.btn] then
        begin
          W_CurrDown[ev.btn]     := False;
          // krawędź Released na NASTĘPNĄ ramkę
          W_ReleasedNext[ev.btn] := True;
        end;

        // DODANE: pokaż Released TAKŻE W TEJ RAMCE
        W_Released[ev.btn] := True;

        // double-click tylko na prawdziwym UP
        if ev.kind = meUp then
        begin
          pos.x := ev.x; pos.y := ev.y;
          dt := ev.timeMS - W_LastUpTimeMS[ev.btn];
          dx := Abs(pos.x - W_LastUpPos[ev.btn].x);
          dy := Abs(pos.y - W_LastUpPos[ev.btn].y);

          if (dt >= 0) and (dt <= W_DBLCLICK_DELAY_MS) and
             (dx <= W_DBLCLICK_MOVE_PX) and (dy <= W_DBLCLICK_MOVE_PX) then
          begin
            W_DoubleClicked[ev.btn] := True;
            W_LastUpTimeMS[ev.btn]  := 0;
            W_LastUpPos[ev.btn]     := pos;
          end
          else
          begin
            W_LastUpTimeMS[ev.btn] := ev.timeMS;
            W_LastUpPos[ev.btn]    := pos;
          end;
        end;
      end;

    // NOWE: ruch myszy
    meMove:
      begin
        // możemy tu też zaktualizować gMousePos na wszelki wypadek
        gMousePos.x := ev.x;
        gMousePos.y := ev.y;

        // Jeśli kiedyś chcesz dodać callback:
        // if Assigned(W_OnMouseMove) then
        //   W_OnMouseMove(ev.x, ev.y);
      end;
  end;
end;


  // --- 2) WATCHDOG: wymuś Released, jeśli UP zginęło ---
  nowMS := _NowMS;
  for b := 0 to 2 do
    if W_CurrDown[b] and (nowMS - W_DownTimeMS[b] > W_WATCHDOG_TIMEOUT_MS) then
    begin
      W_CurrDown[b]     := False;
      W_ReleasedNext[b] := True;  // zatrzask na następną ramkę
    end;

  // Uwaga: gMouseWheelDelta zeruj w W_InputEndFrame (po Draw).
end;


function GetMouseWheelMove: Integer;
begin
  Result := -gMouseWheelDelta;
end;

function IsMouseButtonDown(btn: Integer): Boolean;
begin
  Result := (btn >= 0) and (btn <= 2) and W_CurrDown[btn];
end;

function IsMouseButtonPressed(btn: Integer): Boolean;
var
  cur: Boolean;
begin
  if (btn < 0) or (btn > 2) then
    Exit(False);

  // to jest flaga "był klik" z uwzględnieniem niskiego FPS (W_PressedUntilMS)
  cur := W_Pressed[btn];

  // edge: było False, stało się True -> jedno "kliknięcie"
  Result := cur and (not GMousePrevPressed[btn]);

  // zapamiętujemy, co widzieliśmy w tej klatce
  GMousePrevPressed[btn] := cur;
end;

function IsMouseButtonReleased(btn: Integer): Boolean;
var
  cur: Boolean;
begin
  if (btn < 0) or (btn > 2) then
    Exit(False);

  // Wilga już przygotowuje W_Released[btn] z uwzględnieniem niskiego FPS
  cur := W_Released[btn];

  Result := cur and (not GMousePrevReleased[btn]);

  GMousePrevReleased[btn] := cur;
end;



function IsMouseDoubleClicked(btn: Integer): Boolean;
begin
  Result := (btn >= 0) and (btn <= 2) and W_DoubleClicked[btn];
end;
{================== /INPUT (mouse) — pas2js safe, bez logów ==================}


{--- Per-frame: liczenie zboczy, dblclick, reset wheel ---}

function GetImageSmoothing: Boolean;
begin
  // U Ciebie prawdopodobnie nazywa się tak:
  // gImageSmoothingWanted (albo gImageSmoothingEnabled)
  Result := gImageSmoothingWanted;
end;

function GetBlendMode: TBlendMode;
begin
  Result := gCurrentBlendMode;
end;

procedure SetGlobalAlpha(const A: Double);
begin
  gCurrentAlpha := A;
  WSetAlpha(A); // ważne: to Twoje wywołanie do workera
end;

function GetGlobalAlpha: Double;
begin
  Result := gCurrentAlpha;
end;




procedure ExportWilgaToWindow;
begin
  asm
    // wystaw funkcje z unitu wilga do window.*, niezależnie od optymalizacji
    var u = pas && pas.wilga;
    if (u) {
      window.W_OnPointerMove = u.W_OnPointerMove;
      window.W_OnPointerDown = u.W_OnPointerDown;
      window.W_OnPointerUp   = u.W_OnPointerUp;
      window.W_OnKeyDown     = u.W_OnKeyDown;
      window.W_OnKeyUp       = u.W_OnKeyUp;

      // (opcjonalnie, jeśli używasz)
      if (u.W_OnWheel)       window.W_OnWheel = u.W_OnWheel;
      if (u.W_OnBlurOrLeave) window.W_OnBlurOrLeave = u.W_OnBlurOrLeave;

      console.log('[Wilga] funkcje wyeksportowane do window.*');
    } else {
      console.warn('[Wilga] pas.wilga jest niewidoczne (unit nie trafił do bundle?)');
    }
  end;
end;
// --- [WILGA INPUT AUTO-BIND] -----------------------------------------------

// === Kolejka event-accurate klików ===
const
  W_CLICKBUF_CAP = 228; // pojemność kolejki klików

type
  TClickItem = record
    x, y: Integer;
  end;

var
  W_ClickBuf   : array[0..W_CLICKBUF_CAP-1] of TClickItem;
  W_ClickHead  : Integer = 0;
  W_ClickTail  : Integer = 0;

procedure W_QueueClickXY(btn, x, y: Integer);
var
  nhead: Integer;
begin
  nhead := (W_ClickHead + 1) mod W_CLICKBUF_CAP;
  if nhead = W_ClickTail then
    Exit; // kolejka pełna – pomijamy (lub nadpisz najstarszy)

  W_ClickBuf[W_ClickHead].x := x;
  W_ClickBuf[W_ClickHead].y := y;
  W_ClickHead := nhead;
end;

function W_PopClick(out x, y: Integer): Boolean;
begin
  if W_ClickTail = W_ClickHead then
    Exit(False);

  x := W_ClickBuf[W_ClickTail].x;
  y := W_ClickBuf[W_ClickTail].y;
  W_ClickTail := (W_ClickTail + 1) mod W_CLICKBUF_CAP;
  Result := True;
end;
procedure EnsureAuxCanvas(w, h: Integer);
begin
  if gAuxCanvas = nil then
  begin
    gAuxCanvas := TJSHTMLCanvasElement(document.createElement('canvas'));
    gAuxCtx := TJSCanvasRenderingContext2D(gAuxCanvas.getContext('2d'));
  end;
  if gAuxCanvas.width  <> w then gAuxCanvas.width  := w;
  if gAuxCanvas.height <> h then gAuxCanvas.height := h;
end;
procedure W_FixCanvasDPI; 
begin
  asm
    var c = (window.Module && Module.canvas) || document.getElementById('game');
    if (!c) return;
    var ratio = Math.max(1, window.devicePixelRatio || 1);
    var cssW = Math.max(1, c.clientWidth  || c.width  || 1);
    var cssH = Math.max(1, c.clientHeight || c.height || 1);
    var w = (cssW * ratio) | 0;
    var h = (cssH * ratio) | 0;
    if (c.width !== w || c.height !== h) {
      c.width  = w;
      c.height = h;
    }
  end;
end;

procedure W_BindCanvasEvents;
begin
  asm
    // —— helpers ——
    const getCanvas = () => {
      if (window.Module && Module.canvas) return Module.canvas;
      return document.getElementById('game')
          || document.getElementById('canvas')
          || document.querySelector('canvas')
          || null;
    };

    const getNS = () => (pas.wilga || pas.Wilga || pas.WILGA || null);
    const resolve = (name) => {
      const ns = getNS(); if (!ns) return null;
      let f = ns[name];
      if (typeof f !== 'function') {
        const k = Object.keys(ns).find(x => x === name || x.startsWith(name + '$'));
        if (k) f = ns[k];
      }
      return (typeof f === 'function') ? f : null;
    };
    const call = (name, args) => { const f = resolve(name); if (f) return f.apply(null, args); };

    const toXY = (c, e) => {
      const r  = c.getBoundingClientRect();
      const sx = c.width  / Math.max(1, r.width);
      const sy = c.height / Math.max(1, r.height);
      return { x: ((e.clientX - r.left) * sx) | 0,
               y: ((e.clientY - r.top)  * sy) | 0 };
    };

    const bind = () => {
      const c = getCanvas();
      if (!c) { requestAnimationFrame(bind); return; }
      if (c.__wilgaCanvasBound) return;
      c.__wilgaCanvasBound = true;

      // —— focus setup ——
      c.tabIndex = 0;
      c.autofocus = true;
      c.style.touchAction = 'none';
      c.style.userSelect  = 'none';

      const focusCanvas = () => {
        if (!document.body.contains(c)) return;
        if (document.activeElement !== c) {
          try { c.focus({preventScroll:true}); } catch(_) { try { c.focus(); } catch(__){} }
        }
      };
      focusCanvas();
      // —— stubborn focus strategy: burst + first-key rescue ——
      // Burst: spam-focus canvas a few times over ~300ms to beat transient UI overlays.
      function focusBurst() {
        const tries = [0, 16, 48, 96, 160, 240, 320];
        for (const t of tries) setTimeout(() => focusCanvas(), t);
      }

      // First key rescue: if any key lands on the document while canvas isn't active, refocus immediately.
      // We capture early and stop the first "lost" key (so user nie musi naciskać dwa razy).
      let __rescuing = false;
      document.addEventListener('keydown', (e) => {
        if (__rescuing) return;
        const ae = document.activeElement;
        if (ae !== c) {
          __rescuing = true;
          focusBurst();
          // zatrzymaj ten jeden "zagubiony" klawisz, by nie poszedł w UI przeglądarki
          try { e.preventDefault(); e.stopImmediatePropagation(); } catch (_) {}
          setTimeout(() => { __rescuing = false; }, 60);
        }
      }, { capture: true });

      // Wywołuj burst w krytycznych momentach
      window.addEventListener('focus', () => focusBurst(), { passive:true });
      document.addEventListener('visibilitychange', () => { if (!document.hidden) focusBurst(); }, { passive:true });
      window.addEventListener('resize', () => focusBurst(), { passive:true });
      c.addEventListener('pointerdown', () => focusBurst(), { capture:true, passive:true });
      c.addEventListener('pointerenter', () => focusBurst(), { passive:true });


      // —— keyboard shepherd + REPLAY —— 
      const hot = new Set(['Enter','NumpadEnter',' ','Space','ArrowUp','ArrowDown','ArrowLeft','ArrowRight','PageUp','PageDown','Home','End']);
      const isTypingElement = (el) => {
        if (!el) return false;
        const tag = (el.tagName || '').toLowerCase();
        return (tag === 'input' || tag === 'textarea' || el.isContentEditable);
      };

      const replayKeyOnCanvas = (src) => {
        try {
          const evt = new KeyboardEvent('keydown', {
            key: src.key, code: src.code, location: src.location,
            repeat: src.repeat, ctrlKey: src.ctrlKey, shiftKey: src.shiftKey,
            altKey: src.altKey, metaKey: src.metaKey,
            bubbles: true, cancelable: true, composed: true
          });
          c.dispatchEvent(evt);
        } catch(_) {
          const evt = document.createEvent('KeyboardEvent');
          if (evt.initKeyboardEvent)
            evt.initKeyboardEvent('keydown', true, true, window, src.key, 0, '', src.ctrlKey, src.altKey, src.shiftKey, src.metaKey);
          else
            evt.initEvent('keydown', true, true);
          c.dispatchEvent(evt);
        }
      };

      const shepherd = (e) => {
        if (!hot.has(e.key)) return;
        if (isTypingElement(document.activeElement)) return;
        if (document.activeElement !== c) {
          e.preventDefault();
          if (e.stopImmediatePropagation) e.stopImmediatePropagation();
          e.stopPropagation();
          focusCanvas();
          // odtwórz TEN PIERWSZY klawisz już na canvasie
          replayKeyOnCanvas(e);
        }
      };

      // rejestruj w capture jak najwcześniej
      window.addEventListener('keydown',   shepherd, {capture:true});
      document.addEventListener('keydown', shepherd, {capture:true});

      // natywna obsługa klawiatury na canvasie (jeśli wystawiasz handlery w Pascalu)
      c.addEventListener('keydown', (e) => {
        if (hot.has(e.key)) e.preventDefault();
        if (resolve('W_OnKeyDown'))
          call('W_OnKeyDown', [ e.code || '', e.key || '', (e.repeat ? 1 : 0) ]);
      }, {passive:false});

      c.addEventListener('keyup', (e) => {
        if (hot.has(e.key)) e.preventDefault();
        if (resolve('W_OnKeyUp'))
          call('W_OnKeyUp', [ e.code || '', e.key || '' ]);
      }, {passive:false});

      // —— pointery ——
      c.addEventListener('pointerdown', (e) => {
        try { c.setPointerCapture && c.setPointerCapture(e.pointerId); } catch(_){}
        focusCanvas();
        const p = toXY(c,e);
        call('W_OnPointerMove', [p.x|0, p.y|0]);
        call('W_EH_PointerDown', [e]);
        e.preventDefault();
      }, { capture:true, passive:false });

      c.addEventListener('pointermove', (e) => {
        const p = toXY(c,e);
        call('W_OnPointerMove', [p.x|0, p.y|0]);
      }, { passive:true });

      c.addEventListener('pointerup', (e) => {
        const p = toXY(c,e);
        call('W_OnPointerMove', [p.x|0, p.y|0]);
        call('W_EH_PointerUp', [e]);
        e.preventDefault();
      }, { capture:true, passive:false });

      // awaryjne „puszczenia”
      const forceAllUp = () => { call('W_ForceAllUp', []); };
      window.addEventListener('pointerup',        () => forceAllUp(), { passive:true, capture:true });
      window.addEventListener('pointercancel',    () => forceAllUp(), { passive:true, capture:true });
      c.addEventListener('lostpointercapture',    () => forceAllUp(), { passive:true });
      window.addEventListener('blur',             () => forceAllUp(), { passive:true });
      document.addEventListener('visibilitychange', () => { if (document.hidden) forceAllUp(); }, { passive:true });

      // wheel 
      c.addEventListener('wheel', (e) => {
        if (resolve('W_OnWheel')) {
          call('W_OnWheel', [ (e.deltaY > 0 ? 1 : -1) | 0 ]);
          e.preventDefault();
        }
      }, { passive:false });

      // UX blokady
      c.addEventListener('contextmenu', (e) => e.preventDefault());
      c.addEventListener('dragstart',  (e) => e.preventDefault());
      c.addEventListener('auxclick',   (e) => e.preventDefault());

      // po resize odzyskaj fokus
      window.addEventListener('resize', () => setTimeout(focusCanvas, 0), {passive:true});

      console.log('[Wilga] input bound (focus replay, keyboard+pointer, safety ups)');
    };

    if (document.readyState === 'loading')
      document.addEventListener('DOMContentLoaded', bind, { once:true });
    else
      bind();
  end;
end;
begin
  {$IFDEF WILGA_TEXT_CACHE}
    WriteLn('WILGA_TEXT_CACHE runtime = ON');
  {$ELSE}
    WriteLn('WILGA_TEXT_CACHE runtime = OFF');
  {$ENDIF}
end.

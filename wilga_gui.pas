unit wilga_gui;
{$mode objfpc}{$H+}

interface

uses
  JS, Web, SysUtils, Math, wilga,wilga_font_scope;

type
  TWidget = class;
  TButton = class;
  TLabel = class;
  TSlider = class;
  TCheckbox = class;
  TPanel = class;
  TWindow = class;
  TTextBox = class;
  TProgressBar = class;
  TListBox = class;

  TWidgetState = (wsNormal, wsHover, wsActive, wsDisabled, wsDragging, wsFocused);
  TOrientation = (orVertical, orHorizontal);
  TWidgetCallback = procedure(widget: TWidget) of object;
  TListBoxItemEvent = procedure(widget: TWidget; index: Integer; item: String) of object;

  { ---------- Base Widget ---------- }
  TWidget = class
  public
    Bounds: TRectangle;
    State: TWidgetState;
    Visible: Boolean;
    Enabled: Boolean;
    Tag: Integer;
    OnClick: TWidgetCallback;
    OnHover: TWidgetCallback;
    OnLeave: TWidgetCallback;
    Tooltip: String;

    
    // Focus & tab-order
    Focusable: Boolean;
    TabStop: Boolean;
    TabIndex: Integer; // -1 = auto

    // Anchors & constraints
    AnchorLeft: Boolean;
    AnchorTop: Boolean;
    AnchorRight: Boolean;
    AnchorBottom: Boolean;
    MinWidth: Double;
    MinHeight: Double;
    MaxWidth: Double;
    MaxHeight: Double;
constructor Create(ax, ay, aw, ah: Double); virtual;
    procedure Update; virtual;
    procedure Draw; virtual; abstract;
    function ContainsPoint(p: TInputVector): Boolean;
    procedure SetPosition(x, y: Double);
    procedure SetSize(w, h: Double);
  end;

  { ---------- Button (click on PRESS with debounce) ---------- }
  TButton = class(TWidget)
  private
    InPress: Boolean;
  public
    Text: String;
    ColorNormal: TColor;
    ColorHover: TColor;
    ColorActive: TColor;
    ColorDisabled: TColor;
    TextColor: TColor;
    FontSize: Integer;
    Icon: TTexture;
    FontName: String; // <<< NOWE
    constructor Create(ax, ay, aw, ah: Double); override;
    procedure Update; override;
    procedure Draw; override;
  end;

  TLabel = class(TWidget)
  public
    Text: String;
    Color: TColor;
    FontSize: Integer;
    Align: String; // 'left', 'center', 'right'
    WordWrap: Boolean;
    FontName: String; // <<< DODAJ TO
    procedure Draw; override;
  end;

  TSlider = class(TWidget)
  public
    Value: Double;
    MinValue: Double;
    MaxValue: Double;
    BackgroundColor: TColor;
    SliderColor: TColor;
    OnChange: TWidgetCallback;
    ShowValue: Boolean;
     FontName: String; // <<< NOWE
    procedure Draw; override;
    procedure Update; override;
  end;

  { ---------- Checkbox (toggle on PRESS with debounce) ---------- }
  TCheckbox = class(TWidget)
  private
    InPress: Boolean;
  public
    Checked: Boolean;
    Text: String;
    Color: TColor;
    CheckColor: TColor;
    FontSize: Integer;
    fontname:string;
    constructor Create(ax, ay, aw, ah: Double); override;
    procedure Draw; override;
    procedure Update; override;
  end;

  { ---------- TextBox (focus/blur only, no typing) ---------- }
  TTextBox = class(TWidget)
public
  Text: String;
  Placeholder: String;
  Color: TColor;
  TextColor: TColor;
  FontSize: Integer;
  MaxLength: Integer;
  OnTextChange: TWidgetCallback;
  OnEnterPressed: TWidgetCallback;
  CaretPos: Integer;
  CaretBlink: Double;
  ShowCaret: Boolean;
  BackspaceHeld: Boolean;
  LastBackspaceTime:  double;
  FontName: String; // <<< NOWE
constructor Create(ax, ay, aw, ah: Double); override;


  procedure Draw; override;
  procedure Update; override;
  procedure Focus;
  procedure Blur;
end;


  TProgressBar = class(TWidget)
  public
    Value: Double;
    MinValue: Double;
    MaxValue: Double;
    BackgroundColor: TColor;
    FillColor: TColor;
    ShowPercentage: Boolean;
    FontName: String; // <<< NOWE
    procedure Draw; override;
  end;

  TListBox = class(TWidget)
  public
    Items: array of String;
    SelectedIndex: Integer;
    ItemHeight: Integer;
    Color: TColor;
    SelectionColor: TColor;
    TextColor: TColor;
    FontSize: Integer;
    OnSelect: TListBoxItemEvent;
    ScrollOffset: Integer;
     FontName: String; // <<< NOWE
    constructor Create(ax, ay, aw, ah: Double); override;
    procedure Draw; override;
    procedure Update; override;
    procedure AddItem(const item: String);
    procedure Clear;
    function GetSelectedItem: String;
  end;

  TPanel = class(TWidget)
  public
    Color: TColor;
    BorderColor: TColor;
    BorderWidth: Integer;
    Children: array of TWidget;

    procedure Draw; override;
    procedure Update; override;
    procedure AddChild(widget: TWidget);
    procedure RemoveChild(widget: TWidget);
    procedure ClearChildren;
    procedure OffsetChildren(dx, dy: Double);
  end;
  TStackPanel = class(TPanel)
  public
    Orientation: TOrientation;
    Spacing: Double;
    PaddingLeft, PaddingTop, PaddingRight, PaddingBottom: Double;
    constructor Create(ax, ay, aw, ah: Double); override;
    procedure Update; override;
  end;

  { ---------- ScrollPanel (panel z pionowym scrollowaniem) ---------- }
  { ---------- ScrollPanel (panel z pionowym scrollowaniem) ---------- }
  TScrollPanel = class(TPanel)
  private
    FDraggingThumb: Boolean;
    FDragOffsetY: Double;
    function HasScrollbar: Boolean;
    procedure GetScrollbarGeometry(out barX, barY, barW, barH, maxScroll: Double);
  public
    ScrollY: Double;         // bieżąca pozycja scrolla (0 = top)
    ScrollSpeed: Double;     // ile pikseli na "krok kółka"
    ShowScrollBar: Boolean;  // czy rysować pasek przewijania
    ScrollbarWidth: Double;  // szerokość paska przewijania
    ContentHeight: Double;   // wysokość zawartości (do ustawienia przez użytkownika)
    constructor Create(ax, ay, aw, ah: Double); override;
    procedure Update; override;
    procedure Draw; override;
    procedure ScrollBy(dy: Double);
    procedure SetScrollY(value: Double);
  end;


  { ---------- Window ---------- }
  TWindow = class(TWidget)
  private
    DragOffset: TInputVector;
    PrevHeight: Double;
    PrevWinX, PrevWinY: Double;
    procedure CloseClicked(widget: TWidget);
    procedure MinimizeClicked(widget: TWidget);
  public
    IsDragging: Boolean;
    Title: String;
    TitleBarHeight: Integer;
    TitleColor: TColor;
    CloseButton: TButton;
    MinimizeButton: TButton;
    ContentPanel: TPanel;
    Minimized: Boolean;
    FontName: String;  // <<< NOWE POLE
    constructor Create(ax, ay, aw, ah: Double); override;
    procedure Update; override;
    procedure Draw; override;
    function HitTitleBar(const p: TInputVector): Boolean;

    procedure AddChild(widget: TWidget);
    procedure Close;
    procedure Minimize;
    procedure Restore;
    procedure BringToFront;
  end;

  { ---------- GUI Manager ---------- }
  TGUIManager = class
  public
    MouseCapturedBy: TWidget; // captures mouse during clicks/drags
private
    Widgets: array of TWidget;
    FocusedWidget: TWidget;
    
    // Key debouncing
    LastTabDown: Boolean;
    LastEnterDown: Boolean;
    LastEscDown: Boolean;
IsAnyWindowDragging: Boolean;
    TooltipTimer: Double;
    TooltipWidget: TWidget;
    TooltipPosition: TInputVector;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(widget: TWidget);
    procedure Remove(widget: TWidget);
    procedure BringToFront(widget: TWidget);
    
    procedure SetFocus(widget: TWidget);
    procedure FocusNext(backwards: Boolean);
    function GetFocus: TWidget;procedure Update;
    procedure Draw;
    function GetWidgetAt(x, y: Double): TWidget;
    procedure ShowTooltip(widget: TWidget; x, y: Double);
    procedure HideTooltip;
  end;

// Global
var
  GUI: TGUIManager;

implementation
function IsChildOfPanel(widget: TWidget; panel: TPanel): Boolean;forward;
{ ===== Helpers: geometry ===== }

function RectContainsPoint(const R: TRectangle; const P: TInputVector): Boolean; inline;
begin
  Result := (P.x >= R.x) and (P.x <= R.x + R.width) and
            (P.y >= R.y) and (P.y <= R.y + R.height);
end;

function RectCenter(const R: TRectangle): TInputVector; inline;
begin
  Result := NewVector(R.x + R.width * 0.5, R.y + R.height * 0.5);
end;

function RectInflate(const R: TRectangle; dx, dy: Double): TRectangle; inline;
begin
  Result := RectangleCreate(R.x + dx, R.y + dy, R.width - 2*dx, R.height - 2*dy);
end;

{ ===== Recursive hit-test ===== }

function HitTestWidget(w: TWidget; const p: TInputVector): TWidget; forward;

function HitTestPanel(panel: TPanel; const p: TInputVector): TWidget;
var
  i: Integer;
  child: TWidget;
begin
  Result := nil;
  if not (panel.Visible and panel.ContainsPoint(p)) then Exit;

  // najpierw dzieci (od góry stosu)
  for i := High(panel.Children) downto 0 do
  begin
    child := panel.Children[i];
    if Assigned(child) then
    begin
      Result := HitTestWidget(child, p);
      if Result <> nil then Exit;
    end;
  end;

  // trafiony sam panel
  Result := panel;
end;

function HitTestWindow(win: TWindow; const p: TInputVector): TWidget;
var
  r: TWidget;
begin
  Result := nil;
  if not (win.Visible and win.ContainsPoint(p)) then Exit;

  // przyciski okna nad wszystkim
  r := HitTestWidget(win.CloseButton, p);     if r <> nil then Exit(r);
  r := HitTestWidget(win.MinimizeButton, p);  if r <> nil then Exit(r);

  // panel treści + jego dzieci
  r := HitTestPanel(win.ContentPanel, p);     if r <> nil then Exit(r);

  // rama/pasek tytułu
  Result := win;
end;

function HitTestWidget(w: TWidget; const p: TInputVector): TWidget;
begin
  Result := nil;
  if not (w.Visible and w.ContainsPoint(p)) then Exit;

  if w is TWindow then
    Exit(HitTestWindow(TWindow(w), p))
  else if w is TPanel then
    Exit(HitTestPanel(TPanel(w), p))
  else
    Exit(w); // zwykły widget
end;

{ ===== TWidget ===== }

constructor TWidget.Create(ax, ay, aw, ah: Double);
begin
  Bounds := RectangleCreate(ax, ay, aw, ah);
  State := wsNormal;
  Visible := True;
  Enabled := True;
  Tooltip := '';
end;

function TWidget.ContainsPoint(p: TInputVector): Boolean;
begin
  Result := RectContainsPoint(Bounds, p);
end;

procedure TWidget.SetPosition(x, y: Double);
begin
  Bounds.x := x;
  Bounds.y := y;
end;

procedure TWidget.SetSize(w, h: Double);
begin
  Bounds.width := w;
  Bounds.height := h;
end;

procedure TWidget.Update;
var
  mp: TInputVector;
  isHover: Boolean;
begin
  if not Visible or not Enabled then Exit;

  mp := GetMousePosition;
  isHover := ContainsPoint(mp);

  // nie nadpisuj wizualnego fokusowania
  if State = wsFocused then Exit;

  // Tooltip
  if isHover and (Tooltip <> '') then
    GUI.ShowTooltip(Self, mp.x, mp.y)
  else if GUI.TooltipWidget = Self then
    GUI.HideTooltip;

  // Hover/Active wizualnie (bez klików)
  if isHover then
  begin
    if IsMouseButtonpressed(0) then
      State := wsActive
    else if State <> wsHover then
    begin
      State := wsHover;
      if Assigned(OnHover) then OnHover(Self);
    end;
  end
  else
  begin
    if State in [wsHover, wsActive] then
    begin
      State := wsNormal;
      if Assigned(OnLeave) then OnLeave(Self);
    end;
  end;
end;

{ ===== TButton ===== }

constructor TButton.Create(ax, ay, aw, ah: Double);
begin
  inherited Create(ax, ay, aw, ah);
    Focusable := True; TabStop := True;
ColorNormal := COLOR_GRAY;
  ColorHover := COLOR_LIGHTGRAY;
  ColorActive := COLOR_DARKGRAY;
  ColorDisabled := COLOR_DARKGRAY;
  TextColor := COLOR_WHITE;
  FontSize := 16;
  InPress := False;
  FontName := ''; // pusty = użyj domyślnego fontu
end;

procedure TButton.Update;
var
  mp: TInputVector;
  isHover: Boolean;
begin
  if not Visible or not Enabled then Exit;

  mp := GetMousePosition;
  isHover := ContainsPoint(mp);

  // ktoś inny trzyma capture (np. okno) -> nie reagujemy
  if Assigned(GUI.MouseCapturedBy) and (GUI.MouseCapturedBy <> Self) then
    Exit;

  if not InPress then
  begin
    if isHover and IsMouseButtondown(0) then
    begin
      InPress := True;
      State := wsActive;
      Exit;
    end;
  end
  else
  begin
    if not IsMouseButtonDown(0) then
    begin
      if isHover and Assigned(OnClick) then
        OnClick(Self); // klik na release
      InPress := False;
      State := wsNormal;
      Exit;
    end;
  end;

  // kosmetyka
  if isHover then
  begin
    if IsMouseButtonDown(0) then
      State := wsActive
    else if State <> wsHover then
      State := wsHover;
  end
  else
  begin
    if not IsMouseButtonDown(0) then
    begin
      InPress := False;
      if State <> wsDisabled then
        State := wsNormal;
    end;
  end;
end;



procedure TButton.Draw;
var
  col: TColor;
  center: TInputVector;

  procedure DrawButtonText;
  begin
    if TextureIsReady(Icon) then
    begin
      DrawTexture(
        Icon,
        Round(Bounds.x + 5),
        Round(Bounds.y + (Bounds.height - Icon.height) / 2),
        TextColor
      );
      center := RectCenter(Bounds);
      DrawTextCentered(
        Text,
        Round(center.x + Icon.width / 2),
        Round(center.y),
        FontSize,
        TextColor
      );
    end
    else
    begin
      center := RectCenter(Bounds);
      DrawTextCentered(
        Text,
        Round(center.x),
        Round(center.y),
        FontSize,
        TextColor
      );
    end;
  end;

begin
  if not Visible then Exit;

  if not Enabled then col := ColorDisabled else
    case State of
      wsNormal:  col := ColorNormal;
      wsHover:   col := ColorHover;
      wsActive:  col := ColorActive;
    else         col := ColorNormal;
    end;

  DrawRectangleRoundedRec(Bounds, 5, col, True);

  // <<< TU JEST MAGIA FONTU
  if FontName <> '' then
    WithFont(FontName, procedure
    begin
      DrawButtonText;
    end)
  else
    DrawButtonText;
end;

{ ===== TLabel ===== }

procedure TLabel.Draw;
var
  pos: TInputVector;
  x, y: Integer;

  procedure DrawInner;
  begin
    pos := RectCenter(Bounds);

    if Align = 'left' then
      pos.x := Bounds.x
    else if Align = 'right' then
      pos.x := Bounds.x + Bounds.width;

    x := Round(pos.x);
    y := Round(pos.y);

    if WordWrap then
      DrawTextBoxed(
        Text,
        NewVector(Bounds.x, Bounds.y),
        Round(Bounds.width),
        FontSize,
        Color,
        5,
        COLOR_Red,
        3
      )
    else
    begin
      if Align = 'left' then
        DrawText(Text, x, y, FontSize, Color)
      else if Align = 'right' then
      begin
        x := x - Round(MeasureTextWidth(Text, FontSize));
        DrawText(Text, x, y, FontSize, Color);
      end
      else
        DrawTextCentered(Text, x, y, FontSize, Color);
    end;
  end;

begin
  if not Visible then Exit;

  if FontName <> '' then
    WithFont(FontName, procedure
    begin
      DrawInner;
    end)
  else
    DrawInner;
end;


{ ===== TSlider ===== }

procedure TSlider.Draw;
var
  fillWidth, handlePos: Double;
  handleRect: TRectangle;
  valueText: String;
  cx, cy: Integer;
begin
  if not Visible then Exit;

  // tło suwaka
  DrawRectangleRoundedRec(Bounds, 3, BackgroundColor, True);

  // wypełnienie
  fillWidth := Map(Value, MinValue, MaxValue, 0, Bounds.width);
  fillWidth := Clamp(fillWidth, 0, Bounds.width);
  DrawRectangleRoundedRec(
    RectangleCreate(Bounds.x, Bounds.y, fillWidth, Bounds.height),
    3, SliderColor, True
  );

  // „gałka”
  handlePos := Map(Value, MinValue, MaxValue, Bounds.x, Bounds.x + Bounds.width);
  handleRect := RectangleCreate(handlePos - 5, Bounds.y - 2, 10, Bounds.height + 4);
  DrawRectangleRoundedRec(handleRect, 5, COLOR_WHITE, True);

  // wartość – rysowana stabilnie w środku suwaka
if ShowValue then
begin
  valueText := FormatFloat('0.##', Value);
  cx := Round(Bounds.x + Bounds.width / 2);
  cy := Round(Bounds.y + Bounds.height / 2);

  if FontName <> '' then
    WithFont(FontName, procedure
    begin
      DrawTextCentered(valueText, cx, cy, 12, COLOR_WHITE);
    end)
  else
    DrawTextCentered(valueText, cx, cy, 12, COLOR_WHITE);
end;
end;
{ ===== TSlider ===== }

procedure TSlider.Update;
var
  mp: TInputVector;
  newValue: Double;
  isHover: Boolean;
begin
  if not Visible or not Enabled then Exit;

  mp := GetMousePosition;
  isHover := ContainsPoint(mp);

  // Jeśli ktoś inny trzyma capture — nie reagujemy
  if Assigned(GUI.MouseCapturedBy) and (GUI.MouseCapturedBy <> Self) then
    Exit;

  // Aktywacja slidera na kliknięcie
  if (State <> wsActive) and isHover and IsMouseButtonPressed(0) then
  begin
    State := wsActive;
    GUI.MouseCapturedBy := Self; // Przechwytujemy mysz
  end;

  // Przeciąganie slidera
  if State = wsActive then
  begin
    newValue := Map(mp.x, Bounds.x, Bounds.x + Bounds.width, MinValue, MaxValue);
    newValue := Clamp(newValue, MinValue, MaxValue);

    if Abs(newValue - Value) > 0.001 then
    begin
      Value := newValue;
      if Assigned(OnChange) then OnChange(Self);
    end;

    // Zwolnienie slidera po puszczeniu przycisku
    if not IsMouseButtonDown(0) then
    begin
      State := wsNormal;
      GUI.MouseCapturedBy := nil; // Zwolnij capture
    end;
  end
  else
  begin
    // Standardowa logika hover
    if isHover then
      State := wsHover
    else
      State := wsNormal;
  end;
end;

{ ===== TCheckbox ===== }

constructor TCheckbox.Create(ax, ay, aw, ah: Double);
begin
  inherited Create(ax, ay, aw, ah);
    Focusable := True; TabStop := True;
InPress := False;
  Checked := False;
  Color := COLOR_DARKGRAY;
  CheckColor := COLOR_GREEN;
  FontSize := 14;
end;

procedure TCheckbox.Draw;
var
  boxRect: TRectangle;
  textPos: TInputVector;

  procedure DrawTextInner;
  begin
    textPos := NewVector(Bounds.x + Bounds.height + 5, Bounds.y);
    DrawText(Text, Round(textPos.x), Round(textPos.y), FontSize, Color);
  end;

begin
  if not Visible then Exit;

  // pudełko checkboxa
  boxRect := RectangleCreate(Bounds.x, Bounds.y, Bounds.height, Bounds.height);
  DrawRectangleRoundedRec(boxRect, 3, Color, True);

  // ptaszek
  if Checked then
    DrawRectangleRoundedRec(RectInflate(boxRect, -4, -4), 2, CheckColor, True);

  // tekst – Pacifico jeśli ustawiony
  if FontName <> '' then
    WithFont(FontName, procedure
    begin
      DrawTextInner;
    end)
  else
    DrawTextInner;
end;

procedure TCheckbox.Update;
var
  mp: TInputVector; 
  isHover: Boolean;
begin
  if not Visible or not Enabled then Exit;

  mp := GetMousePosition;
  isHover := ContainsPoint(mp);

  // jeśli ktoś inny trzyma capture — nie reagujemy
  if Assigned(GUI.MouseCapturedBy) and (GUI.MouseCapturedBy <> Self) then
    Exit;

  if not InPress then
  begin
    if isHover and IsMouseButtondown(0) then
    begin
      InPress := True;
      State := wsActive;
      Exit;
    end;
    if isHover then State := wsHover else State := wsNormal;
  end
  else
  begin
    // klik na release
    if not IsMouseButtonDown(0) then
    begin
      InPress := False;
      if isHover then
      begin
        Checked := not Checked;
        if Assigned(OnClick) then OnClick(Self);
      end;
      State := wsNormal;
      Exit;
    end;
  end;
end;

{ ===== TTextBox ===== }

procedure TTextBox.Draw;
var
  textToDraw: String;
  textX, textY: Integer;
  caretX, topY, bottomY: Integer;

  procedure DrawTextAndCaret;
  begin
    // tylko wizual: tekst/placeholder
    if (Text = '') and (Placeholder <> '') then
      textToDraw := Placeholder
    else
      textToDraw := Text;

    textX := Round(Bounds.x + 6);
    textY := Round(Bounds.y + Bounds.height/2 - (FontSize div 2));
    DrawText(textToDraw, textX, textY, FontSize, TextColor);

    // caret blinking + draw
    if State = wsFocused then
    begin
      CaretBlink := CaretBlink + GetDeltaTime;
      if CaretBlink >= 0.5 then
      begin
        ShowCaret := not ShowCaret;
        CaretBlink := 0.0;
      end;
      if ShowCaret then
      begin
        if CaretPos < 0 then CaretPos := 0;
        if CaretPos > Length(Text) then CaretPos := Length(Text);
        caretX := textX + Round(MeasureTextWidth(Copy(Text,1,CaretPos), FontSize));
        topY := textY;
        bottomY := textY + FontSize;
        DrawLine(caretX, topY, caretX, bottomY, COLOR_BLACK, 1);
      end;
    end;
  end;

begin
  if not Visible then Exit;

  // tło
  DrawRectangleRoundedRec(Bounds, 3, Color, True);

  // ramka w fokusie
  if State = wsFocused then
    DrawRectangleLines(Round(Bounds.x), Round(Bounds.y),
                       Round(Bounds.width), Round(Bounds.height),
                       COLOR_YELLOW, 2);

  // tekst + caret w wybranym foncie
  if FontName <> '' then
    WithFont(FontName, procedure
    begin
      DrawTextAndCaret;
    end)
  else
    DrawTextAndCaret;
end;

constructor TTextBox.Create(ax, ay, aw, ah: Double);
begin
  inherited Create(ax, ay, aw, ah);
    Focusable := True; TabStop := True;
Text := '';
  Placeholder := '';
  Color := color_White;
  TextColor := color_black;
  FontSize := 12;
  MaxLength := 0;
  CaretPos := 0;
  CaretBlink := 0.0;
  ShowCaret := True;
  BackspaceHeld := False;
  LastBackspaceTime := Gettime;
    FontName := '';

end;


procedure TTextBox.Update;
  function CodeToChar(const code: String; shiftOn: Boolean): String;
  var last: Char;
  begin
    Result := '';

    // Litery KeyA..KeyZ
    if (Length(code) = 4) and (Copy(code, 1, 3) = 'Key') then
    begin
      Result := Copy(code, 4, 1); // 'A'..'Z'
      if shiftOn then Result := UpperCase(Result)
                 else Result := LowerCase(Result);
      Exit;
    end;

    // Cyfry Digit0..Digit9
    if (Copy(code, 1, 5) = 'Digit') and (Length(code) = 6) then
    begin
      Result := Copy(code, 6, 1);
      Exit;
    end;

    // Numpad0..Numpad9
    if (Copy(code, 1, 6) = 'Numpad') and (Length(code) = 7) then
    begin
      last := code[7];
      if (last >= '0') and (last <= '9') then
        Result := last;
      Exit;
    end;

    // Spacja
    if (code = 'Space') then
    begin
      Result := ' ';
      Exit;
    end;

    // Prosta interpunkcja z klawiatury US
    if code = 'Minus'        then Exit('-');
    if code = 'Equal'        then Exit('=');
    if code = 'Comma'        then Exit(',');
    if code = 'Period'       then Exit('.');
    if code = 'Slash'        then Exit('/');
    if code = 'Semicolon'    then Exit(';');
    if code = 'Quote'        then Exit('''');
    if code = 'BracketLeft'  then Exit('[');
    if code = 'BracketRight' then Exit(']');
    if code = 'Backslash'    then Exit('\');
  end;

const
  BACKSPACE_REPEAT_DELAY = 0.1; // sekundy (100 ms)

var
  mp: TInputVector;
  k, ch, leftPart, rightPart: String;
  shiftOn: Boolean;
begin
  if not Visible then Exit;

  // Hover/leave
  mp := GetMousePosition;
  if ContainsPoint(mp) then
  begin
    if State = wsNormal then State := wsHover;
    if Assigned(OnHover) then OnHover(Self);
  end
  else
  begin
    if (State <> wsNormal) and (State <> wsFocused) then State := wsNormal;
    if Assigned(OnLeave) then OnLeave(Self);
  end;

  // Fokus po kliknięciu; blur robi GUIManager
  if IsMouseButtonPressed(0) and ContainsPoint(mp) then
    Focus;

  // Klawiatura tylko gdy fokus
  if (State = wsFocused) then
  begin
    shiftOn := IsKeyDown('ShiftLeft') or IsKeyDown('ShiftRight');

    k := GetKeyPressed;
    while k <> '' do
    begin
      if (k = 'Backspace') then
      begin
        if (CaretPos > 0) and (Length(Text) > 0) then
        begin
          leftPart  := Copy(Text, 1, CaretPos-1);
          rightPart := Copy(Text, CaretPos+1, Length(Text) - CaretPos);
          Text := leftPart + rightPart;
          Dec(CaretPos);
          if Assigned(OnTextChange) then OnTextChange(Self);
        end;
        LastBackspaceTime := GetTime; // reset licznika przy pojedynczym backspace
      end
      else if (k = 'Delete') then
      begin
        if (CaretPos < Length(Text)) then
        begin
          leftPart  := Copy(Text, 1, CaretPos);
          rightPart := Copy(Text, CaretPos+2, Length(Text) - (CaretPos+1));
          Text := leftPart + rightPart;
          if Assigned(OnTextChange) then OnTextChange(Self);
        end;
      end
      else if (k = 'Enter') then
      begin
        if Assigned(OnEnterPressed) then OnEnterPressed(Self);
      end
      else if (k = 'ArrowLeft') or (k = 'Left') then
      begin
        if CaretPos > 0 then Dec(CaretPos);
      end
      else if (k = 'ArrowRight') or (k = 'Right') then
      begin
        if CaretPos < Length(Text) then Inc(CaretPos);
      end
      else if (k = 'Home') then
        CaretPos := 0
      else if (k = 'End') then
        CaretPos := Length(Text)
      else
      begin
        // --- mapowanie kodu klawisza na znak ---
        ch := CodeToChar(k, shiftOn);
        if (ch <> '') and ((MaxLength = 0) or (Length(Text) < MaxLength)) then
        begin
          leftPart  := Copy(Text, 1, CaretPos);
          rightPart := Copy(Text, CaretPos+1, Length(Text) - CaretPos);
          Text := leftPart + ch + rightPart;
          Inc(CaretPos);
          if Assigned(OnTextChange) then OnTextChange(Self);
        end;
      end;

      // reset migania po naciśnięciu klawisza
      ShowCaret := True;
      CaretBlink := 0.0;

      // pobierz następny klawisz z kolejki
      k := GetKeyPressed;
    end;

    // --- Ciągłe usuwanie przy trzymanym Backspace ---
    if IsKeyDown('Backspace') then
    begin
      if (GetTime - LastBackspaceTime > BACKSPACE_REPEAT_DELAY) then
      begin
        if (CaretPos > 0) and (Length(Text) > 0) then
        begin
          leftPart  := Copy(Text, 1, CaretPos-1);
          rightPart := Copy(Text, CaretPos+1, Length(Text) - CaretPos);
          Text := leftPart + rightPart;
          Dec(CaretPos);
          if Assigned(OnTextChange) then OnTextChange(Self);
        end;
        LastBackspaceTime := GetTime;
      end;
    end;

    // Blink kursora
    CaretBlink := CaretBlink + GetDeltaTime;
    if CaretBlink > 0.5 then
    begin
      CaretBlink := 0;
      ShowCaret := not ShowCaret;
    end;
  end;
end;

procedure TTextBox.Focus;
begin
  State := wsFocused;
  GUI.FocusedWidget := Self;
  // inicjalizacja caret
  CaretPos := Length(Text);
  CaretBlink := 0.0;
  ShowCaret := True;
end;


procedure TTextBox.Blur;
begin
  if State = wsFocused then
    State := wsNormal;
  if GUI.FocusedWidget = Self then
    GUI.FocusedWidget := nil;
end;

{ ===== TProgressBar ===== }

procedure TProgressBar.Draw;
var
  fillWidth: Double;
  percent, clamped: Double;
  percentText: String;
  cx, cy: Integer;
begin
  if not Visible then Exit;

  // tło
  DrawRectangleRoundedRec(Bounds, 3, BackgroundColor, True);

  // wypełnienie
  fillWidth := Map(Value, MinValue, MaxValue, 0, Bounds.width);
  fillWidth := Clamp(fillWidth, 0, Bounds.width);
  DrawRectangleRoundedRec(
    RectangleCreate(Bounds.x, Bounds.y, fillWidth, Bounds.height),
    3, FillColor, True
  );

  // napis z procentem
  if ShowPercentage and (MaxValue > MinValue) then
  begin
    percent := (Value - MinValue) / (MaxValue - MinValue);
    clamped := Clamp(percent * 100.0, 0.0, 100.0);
    percentText := FormatFloat('0.##"%"', clamped);

    cx := Round(Bounds.x + Bounds.width / 2);
    cy := Round(Bounds.y + Bounds.height / 2);

    if FontName <> '' then
      WithFont(FontName, procedure
      begin
        DrawTextCentered(percentText, cx, cy, 12, COLOR_WHITE);
      end)
    else
      DrawTextCentered(percentText, cx, cy, 12, COLOR_WHITE);
  end;
end;

{ ===== TListBox ===== }

constructor TListBox.Create(ax, ay, aw, ah: Double);
begin
  inherited Create(ax, ay, aw, ah);
    Focusable := True; TabStop := True;
ItemHeight := 20;
  Color := COLOR_DARKGRAY;
  SelectionColor := COLOR_BLUE;
  TextColor := COLOR_WHITE;
  FontSize := 12;
  SelectedIndex := -1;
  ScrollOffset := 0;
    FontName := '';

end;

procedure TListBox.Draw;
var
  i, yPos: Integer;
  itemRect: TRectangle;
  visibleItems, maxVisible: Integer;

  procedure DrawItemText(const AText: String; AY: Integer);
  begin
    if FontName <> '' then
      WithFont(FontName, procedure
      begin
        DrawText(AText, Round(Bounds.x + 5), AY + 2, FontSize, TextColor);
      end)
    else
      DrawText(AText, Round(Bounds.x + 5), AY + 2, FontSize, TextColor);
  end;

begin
  if not Visible then Exit;

  DrawRectangleRoundedRec(Bounds, 3, Color, True);

  maxVisible := Trunc(Bounds.height / ItemHeight);
  if maxVisible < 0 then maxVisible := 0;

  if maxVisible > Length(Items) then
    visibleItems := Length(Items)
  else
    visibleItems := maxVisible;

  for i := 0 to visibleItems - 1 do
  begin
    if i + ScrollOffset >= Length(Items) then Break;

    yPos := Round(Bounds.y) + i * ItemHeight;
    itemRect := RectangleCreate(Bounds.x, yPos, Bounds.width, ItemHeight);

    if (i + ScrollOffset) = SelectedIndex then
      DrawRectangleRoundedRec(itemRect, 0, SelectionColor, True);

    DrawItemText(Items[i + ScrollOffset], yPos);
  end;
end;

procedure TListBox.Update;
var
  mp: TInputVector;
  itemIndex: Integer;
  step: Integer;
  lastIdx: Integer;
begin
  inherited Update;

  // Ostatni poprawny indeks (z zabezpieczeniem, gdy lista pusta)
  lastIdx := Length(Items) - 1;
  if lastIdx < 0 then
    lastIdx := 0;

  // Nawigacja klawiaturą
  if GUI.FocusedWidget = Self then
  begin
    if IsKeyDown('ArrowUp') then
      if SelectedIndex > 0 then Dec(SelectedIndex);

    if IsKeyDown('ArrowDown') then
      if SelectedIndex < lastIdx then Inc(SelectedIndex);

    if IsKeyDown('Home') then
    begin
      SelectedIndex := 0;
      ScrollOffset := 0;
    end;

    if IsKeyDown('End') then
      SelectedIndex := lastIdx;

    if IsKeyDown('PageUp') then
    begin
      step := Integer(Trunc(Bounds.height / ItemHeight));
      if step < 1 then step := 1;

      if ScrollOffset - step < 0 then
        ScrollOffset := 0
      else
        ScrollOffset := ScrollOffset - step;

      if SelectedIndex - step < 0 then
        SelectedIndex := 0
      else
        SelectedIndex := SelectedIndex - step;
    end;

    if IsKeyDown('PageDown') then
    begin
      step := Integer(Trunc(Bounds.height / ItemHeight));
      if step < 1 then step := 1;

      ScrollOffset := ScrollOffset + step;

      if SelectedIndex < lastIdx then
      begin
        if SelectedIndex + step > lastIdx then
          SelectedIndex := lastIdx
        else
          SelectedIndex := SelectedIndex + step;
      end;
    end;
  end;

  // Obsługa myszy
  if State = wsActive then
  begin
    mp := GetMousePosition;
    itemIndex := ScrollOffset + Integer(Trunc((mp.y - Bounds.y) / ItemHeight));

    if (itemIndex >= 0) and (itemIndex <= lastIdx) then
    begin
      SelectedIndex := itemIndex;
      if Assigned(OnSelect) then
        OnSelect(Self, SelectedIndex, Items[SelectedIndex]);
    end;
  end;
end;

procedure TListBox.AddItem(const item: String);
begin
  SetLength(Items, Length(Items) + 1);
  Items[High(Items)] := item;
end;

procedure TListBox.Clear;
begin
  SetLength(Items, 0);
  SelectedIndex := -1;
end;

function TListBox.GetSelectedItem: String;
begin
  if (SelectedIndex >= 0) and (SelectedIndex < Length(Items)) then
    Result := Items[SelectedIndex]
  else
    Result := '';
end;

{ ===== TPanel ===== }

procedure TPanel.Draw;
var
  i: Integer;
begin
  if not Visible then Exit;

  DrawRectangleRoundedRec(Bounds, 5, Color, True);

  if BorderWidth > 0 then
    DrawRectangleLines(Round(Bounds.x), Round(Bounds.y),
                       Round(Bounds.width), Round(Bounds.height),
                       BorderColor, BorderWidth);

  for i := 0 to High(Children) do
    if Assigned(Children[i]) then
      Children[i].Draw;
end;

procedure ArrangeChildren(AParent: TPanel);
var
  i: Integer;
  c: TWidget;
  r: TRectangle;
  pw, ph: Double;
begin
  if (AParent = nil) then Exit;
  pw := AParent.Bounds.width; ph := AParent.Bounds.height;
  for i := 0 to High(AParent.Children) do
  begin
    c := AParent.Children[i];
    if c = nil then Continue;
    r := c.Bounds;

    // Horizontal anchors
    if c.AnchorLeft and c.AnchorRight then
    begin
      r.width := pw - (r.x - AParent.Bounds.x);
    end
    else if c.AnchorRight and (not c.AnchorLeft) then
    begin
      r.x := AParent.Bounds.x + pw - r.width;
    end;

    // Vertical anchors
    if c.AnchorTop and c.AnchorBottom then
    begin
      r.height := ph - (r.y - AParent.Bounds.y);
    end
    else if c.AnchorBottom and (not c.AnchorTop) then
    begin
      r.y := AParent.Bounds.y + ph - r.height;
    end;

    // Constraints
    if (c.MinWidth > 0) and (r.width < c.MinWidth) then r.width := c.MinWidth;
    if (c.MaxWidth > 0) and (r.width > c.MaxWidth) then r.width := c.MaxWidth;
    if (c.MinHeight > 0) and (r.height < c.MinHeight) then r.height := c.MinHeight;
    if (c.MaxHeight > 0) and (r.height > c.MaxHeight) then r.height := c.MaxHeight;

    c.Bounds := r;
  end;
end;

procedure TPanel.Update;
var
  i: Integer;
begin
  inherited Update;

  for i := 0 to High(Children) do
    if Assigned(Children[i]) then
      Children[i].Update;
end;

procedure TPanel.AddChild(widget: TWidget);
begin
  SetLength(Children, Length(Children) + 1);
  Children[High(Children)] := widget;
end;

procedure TPanel.RemoveChild(widget: TWidget);
var
  i, j: Integer;
begin
  for i := 0 to High(Children) do
    if Children[i] = widget then
    begin
      for j := i to High(Children) - 1 do
        Children[j] := Children[j + 1];
      SetLength(Children, Length(Children) - 1);
      Break;
    end;
end;

procedure TPanel.ClearChildren;
begin
  SetLength(Children, 0);
end;

procedure TPanel.OffsetChildren(dx, dy: Double);
var
  i: Integer;
begin
  for i := 0 to High(Children) do
    if Assigned(Children[i]) then
    begin
      // przesuwamy bezpośrednie dziecko
      Children[i].Bounds.x := Children[i].Bounds.x + dx;
      Children[i].Bounds.y := Children[i].Bounds.y + dy;

      // jeśli dziecko jest panelem (Panel/Window/ScrollPanel/StackPanel itd.),
      // to przesuwamy również jego dzieci
      if Children[i] is TPanel then
        TPanel(Children[i]).OffsetChildren(dx, dy);
    end;
end;


{ ===== TStackPanel ===== }

constructor TStackPanel.Create(ax, ay, aw, ah: Double);
begin
  inherited Create(ax, ay, aw, ah);
  Orientation := orVertical;
  Spacing := 8.0;
  PaddingLeft := 8.0;
  PaddingTop := 8.0;
  PaddingRight := 8.0;
  PaddingBottom := 8.0;
end;

procedure TStackPanel.Update;
var
  i: Integer;
  ch: TWidget;
  cx, cy, availW, availH: Double;
begin
  // najpierw układamy dzieci
  cx := Bounds.x + PaddingLeft;
  cy := Bounds.y + PaddingTop;
  availW := Max(0, Bounds.width  - (PaddingLeft + PaddingRight));
  availH := Max(0, Bounds.height - (PaddingTop  + PaddingBottom));

  for i := 0 to High(Children) do
  begin
    ch := Children[i];
    if (ch = nil) or (not ch.Visible) then
      Continue;

    if Orientation = orVertical then
    begin
      ch.Bounds.x := Bounds.x + PaddingLeft;
      ch.Bounds.y := cy;
      ch.Bounds.width := availW;
      cy := cy + ch.Bounds.height + Spacing;
    end
    else
    begin
      ch.Bounds.x := cx;
      ch.Bounds.y := Bounds.y + PaddingTop;
      ch.Bounds.height := availH;
      cx := cx + ch.Bounds.width + Spacing;
    end;
  end;

  // potem standardowa logika Panelu (hover, Update dzieci)
  inherited Update;
end;
{ ===== TScrollPanel ===== }
{ ===== TScrollPanel ===== }

function TScrollPanel.HasScrollbar: Boolean;
begin
  Result := ShowScrollBar and (ContentHeight > Bounds.height);
end;

procedure TScrollPanel.GetScrollbarGeometry(out barX, barY, barW, barH, maxScroll: Double);
var
  scrollRatio: Double;
begin
  barW := ScrollbarWidth;

  if ContentHeight < Bounds.height then
    maxScroll := 0.0
  else
    maxScroll := ContentHeight - Bounds.height;

  if maxScroll < 0 then
    maxScroll := 0;

  // wysokość "thumb" zależna od proporcji widocznego obszaru
  if ContentHeight <= 0 then
    barH := Bounds.height
  else
    barH := Bounds.height * (Bounds.height / ContentHeight);

  if barH < 16 then
    barH := 16; // minimalny rozmiar

  if maxScroll <= 0 then
    scrollRatio := 0
  else
    scrollRatio := ScrollY / maxScroll;

  if scrollRatio < 0 then scrollRatio := 0
  else if scrollRatio > 1 then scrollRatio := 1;

  barX := Bounds.x + Bounds.width - barW;
  barY := Bounds.y + scrollRatio * (Bounds.height - barH);
end;

constructor TScrollPanel.Create(ax, ay, aw, ah: Double);
begin
  inherited Create(ax, ay, aw, ah);
  ScrollY := 0.0;
  ScrollSpeed := 32.0;
  ShowScrollBar := True;
  ScrollbarWidth := 8.0;
  ContentHeight := ah; // domyślnie tyle co panel – użytkownik może nadpisać
  FDraggingThumb := False;
  FDragOffsetY := 0.0;
end;

procedure TScrollPanel.SetScrollY(value: Double);
var
  maxScroll, newY, delta: Double;
begin
  if ContentHeight < Bounds.height then
    maxScroll := 0.0
  else
    maxScroll := ContentHeight - Bounds.height;

  if maxScroll < 0 then
    maxScroll := 0;

  newY := value;
  if newY < 0 then
    newY := 0;
  if newY > maxScroll then
    newY := maxScroll;

  delta := newY - ScrollY;
  if Abs(delta) < 0.01 then
    Exit;

  ScrollY := newY;

  // przesuwamy wszystkie dzieci wizualnie o -delta (skrolowanie w górę/dół)
  OffsetChildren(0, -delta);
end;

procedure TScrollPanel.ScrollBy(dy: Double);
begin
  SetScrollY(ScrollY + dy);
end;

procedure TScrollPanel.Draw;
var
  i: Integer;
  clipX, clipY, clipW, clipH: Integer;
  barX, barY, barW, barH, maxScroll: Double;
begin
  if not Visible then
    Exit;

  // tło panelu (jak w TPanel.Draw)
  DrawRectangleRoundedRec(Bounds, 5, Color, True);

  if BorderWidth > 0 then
    DrawRectangleLines(
      Round(Bounds.x), Round(Bounds.y),
      Round(Bounds.width), Round(Bounds.height),
      BorderColor, BorderWidth
    );

  // obszar clipowania – całe wnętrze panelu
  clipX := Round(Bounds.x);
  clipY := Round(Bounds.y);
  clipW := Round(Bounds.width);
  clipH := Round(Bounds.height);

  BeginScissor(clipX, clipY, clipW, clipH);
  try
    // rysujemy dzieci przycięte do panelu
    for i := 0 to High(Children) do
      if Assigned(Children[i]) then
        Children[i].Draw;
  finally
    EndScissor;
  end;

  // Pasek przewijania
  if HasScrollbar then
  begin
    GetScrollbarGeometry(barX, barY, barW, barH, maxScroll);

    DrawRectangle(
      Round(barX), Round(barY),
      Round(barW), Round(barH),
      COLOR_DARKGRAY
    );
  end;
end;


procedure TScrollPanel.Update;
var
  mp: TInputVector;
  wheel: Integer;
  barX, barY, barW, barH, maxScroll: Double;
  scrollRatio, newBarY: Double;
begin
  mp := GetMousePosition;

  // 1) Scroll kółkiem – tylko gdy kursor nad panelem
  if ContainsPoint(mp) then
  begin
    wheel := GetMouseWheelMove;
    if wheel <> 0 then
      ScrollBy(-wheel * ScrollSpeed);
  end;

  // 2) Przeciąganie paska mysza
  if HasScrollbar then
  begin
    GetScrollbarGeometry(barX, barY, barW, barH, maxScroll);

    // Start przeciągania: klik w obszar thumb'a
    if IsMouseButtonPressed(0) then
    begin
      if (mp.x >= barX) and (mp.x <= barX + barW) and
         (mp.y >= barY) and (mp.y <= barY + barH) then
      begin
        FDraggingThumb := True;
        FDragOffsetY := mp.y - barY; // gdzie w thumbie złapaliśmy
      end;
    end;

    // Ruch podczas trzymania
    if FDraggingThumb and IsMouseButtonDown(0) then
    begin
      newBarY := mp.y - FDragOffsetY;

      // clamp w obrębie paska
      if newBarY < Bounds.y then
        newBarY := Bounds.y;
      if newBarY > Bounds.y + Bounds.height - barH then
        newBarY := Bounds.y + Bounds.height - barH;

      // przeliczamy pozycję thumb'a na ScrollY
      if maxScroll <= 0 then
        scrollRatio := 0
      else
        scrollRatio := (newBarY - Bounds.y) / (Bounds.height - barH);

      SetScrollY(scrollRatio * maxScroll);
    end;

    // Koniec przeciągania – puszczenie przycisku
    if FDraggingThumb and (not IsMouseButtonDown(0)) then
      FDraggingThumb := False;
  end
  else
    FDraggingThumb := False;

  // 3) Reszta logiki widgetu (stany hover/active, dzieci itd.)
  inherited Update;
end;

{ ===== TWindow ===== }

constructor TWindow.Create(ax, ay, aw, ah: Double);
begin
  inherited Create(ax, ay, aw, ah);
  Title := 'Window';
  TitleBarHeight := 30;
  TitleColor := COLOR_DARKGRAY;
  IsDragging := False;
  Minimized := False;
  PrevHeight := ah;
  PrevWinX := ax;
  PrevWinY := ay;
FontName := '';

  // Close
  CloseButton := TButton.Create(Bounds.x + Bounds.width - 25, Bounds.y + 5, 20, 20);
  CloseButton.Text := 'X';
  CloseButton.ColorNormal := COLOR_RED;
  CloseButton.ColorHover := COLOR_MAROON;
  CloseButton.FontSize := 12;
  CloseButton.OnClick := @CloseClicked;

  // Minimize
  MinimizeButton := TButton.Create(Bounds.x + Bounds.width - 50, Bounds.y + 5, 20, 20);
  MinimizeButton.Text := '_';
  MinimizeButton.ColorNormal := COLOR_GRAY;
  MinimizeButton.ColorHover := COLOR_LIGHTGRAY;
  MinimizeButton.FontSize := 12;
  MinimizeButton.OnClick := @MinimizeClicked;

  // Content panel
  ContentPanel := TPanel.Create(Bounds.x, Bounds.y + TitleBarHeight, Bounds.width, Bounds.height - TitleBarHeight);
  ContentPanel.Color := COLOR_LIGHTGRAY;
end;
function TWindow.HitTitleBar(const p: TInputVector): Boolean;
var
  titleBarRect: TRectangle;
begin
  titleBarRect := RectangleCreate(Bounds.x, Bounds.y, Bounds.width, TitleBarHeight);
  Result :=
    RectContainsPoint(titleBarRect, p) and
    (not RectContainsPoint(CloseButton.Bounds, p)) and
    (not RectContainsPoint(MinimizeButton.Bounds, p));
end;

procedure TWindow.Update;
var
  mp: TInputVector;
  titleBarRect: TRectangle;
  overTitleBar, overCloseBtn, overMinBtn: Boolean;
  dx, dy: Double;
begin
    inherited Update;
  if Assigned(ContentPanel) then ArrangeChildren(ContentPanel);
if not Visible then Exit;

  mp := GetMousePosition;
  titleBarRect := RectangleCreate(Bounds.x, Bounds.y, Bounds.width, TitleBarHeight);

  // --- Zakończenie przeciągania przy puszczeniu LPM
  if IsDragging and (not IsMouseButtonDown(0)) then
  begin
    IsDragging := False;
    GUI.IsAnyWindowDragging := False;
    State := wsNormal;
    GUI.MouseCapturedBy := nil; // zwolnij capture
  end;

  // ===================== ZMINIMALIZOWANE OKNO =====================
  if Minimized then
  begin
    overTitleBar := RectContainsPoint(titleBarRect, mp);
    overCloseBtn := RectContainsPoint(CloseButton.Bounds, mp);
    overMinBtn   := RectContainsPoint(MinimizeButton.Bounds, mp);

    // Start drag: LPM w pasku tytułu, ale nie nad przyciskami
    if (not IsDragging) and IsMouseButtonPressed(0)
       and overTitleBar and (not overCloseBtn) and (not overMinBtn)
       and (not GUI.IsAnyWindowDragging) then
    begin
      IsDragging := True;
      GUI.MouseCapturedBy := Self;          // capture dla tego okna
      GUI.IsAnyWindowDragging := True;
      DragOffset := NewVector(mp.x - Bounds.x, mp.y - Bounds.y);
      State := wsDragging;
      BringToFront;
    end;

    // Przesuwanie okna podczas drag
    if IsDragging and IsMouseButtonDown(0) then
    begin
      Bounds.x := mp.x - DragOffset.x;
      Bounds.y := mp.y - DragOffset.y;

      dx := Bounds.x - PrevWinX;
      dy := Bounds.y - PrevWinY;

      // Przesuń kontrolki „przyklejone” do paska
      CloseButton.Bounds.x := CloseButton.Bounds.x + dx;
      CloseButton.Bounds.y := CloseButton.Bounds.y + dy;

      MinimizeButton.Bounds.x := MinimizeButton.Bounds.x + dx;
      MinimizeButton.Bounds.y := MinimizeButton.Bounds.y + dy;

      // Jeśli masz ContentPanel aktywny w minimize — zachowaj spójność:
      ContentPanel.Bounds.x := ContentPanel.Bounds.x + dx;
      ContentPanel.Bounds.y := ContentPanel.Bounds.y + dy;
      ContentPanel.OffsetChildren(dx, dy);

      PrevWinX := Bounds.x;
      PrevWinY := Bounds.y;
    end;

    // Aktualizacja przycisków
    CloseButton.Update;
    MinimizeButton.Update;
    Exit; // zminimalizowane: nic więcej
  end;

  // ===================== NORMALNE OKNO =====================
  overTitleBar := RectContainsPoint(titleBarRect, mp);
  overCloseBtn := RectContainsPoint(CloseButton.Bounds, mp);
  overMinBtn   := RectContainsPoint(MinimizeButton.Bounds, mp);

  // Start drag: LPM w pasku tytułu, ale nie nad przyciskami
  if (not IsDragging) and IsMouseButtonPressed(0)
     and overTitleBar and (not overCloseBtn) and (not overMinBtn)
     and (not GUI.IsAnyWindowDragging) then
  begin
    IsDragging := True;
    GUI.MouseCapturedBy := Self;            // capture dla tego okna
    GUI.IsAnyWindowDragging := True;
    DragOffset := NewVector(mp.x - Bounds.x, mp.y - Bounds.y);
    State := wsDragging;
    BringToFront;
  end;

  // Przesuwanie okna podczas drag
  if IsDragging and IsMouseButtonDown(0) then
  begin
    Bounds.x := mp.x - DragOffset.x;
    Bounds.y := mp.y - DragOffset.y;

    dx := Bounds.x - PrevWinX;
    dy := Bounds.y - PrevWinY;

    // Przesuń kontrolki z paska oraz panel treści
    CloseButton.Bounds.x := CloseButton.Bounds.x + dx;
    CloseButton.Bounds.y := CloseButton.Bounds.y + dy;

    MinimizeButton.Bounds.x := MinimizeButton.Bounds.x + dx;
    MinimizeButton.Bounds.y := MinimizeButton.Bounds.y + dy;

    ContentPanel.Bounds.x := ContentPanel.Bounds.x + dx;
    ContentPanel.Bounds.y := ContentPanel.Bounds.y + dy;
    ContentPanel.OffsetChildren(dx, dy);

    PrevWinX := Bounds.x;
    PrevWinY := Bounds.y;
  end;

  // Aktualizacje dzieci
  CloseButton.Update;
  MinimizeButton.Update;
  ContentPanel.Update;
end;


procedure TWindow.Draw;
var
  titleBarRect: TRectangle;
  titleX, titleY: Integer;

  procedure DrawTitle;
  begin
    if FontName <> '' then
      WithFont(FontName, procedure
      begin
        DrawText(Title, titleX, titleY, 14, COLOR_WHITE);
      end)
    else
      DrawText(Title, titleX, titleY, 14, COLOR_WHITE);
  end;

begin
  if not Visible then Exit;

  titleX := Round(Bounds.x + 10);
  titleY := Round(Bounds.y + TitleBarHeight/2 - 8);

  if not Minimized then
  begin
    DrawRectangleRoundedRec(Bounds, 5, COLOR_GRAY, True);
    titleBarRect := RectangleCreate(Bounds.x, Bounds.y, Bounds.width, TitleBarHeight);
    DrawRectangleRoundedRec(titleBarRect, 5, TitleColor, True);
    DrawTitle;
    CloseButton.Draw;
    MinimizeButton.Draw;
    ContentPanel.Draw;
  end
  else
  begin
    titleBarRect := RectangleCreate(Bounds.x, Bounds.y, Bounds.width, TitleBarHeight);
    DrawRectangleRoundedRec(titleBarRect, 5, TitleColor, True);
    DrawTitle;
    CloseButton.Draw;
    MinimizeButton.Draw;
  end;
end;


procedure TWindow.AddChild(widget: TWidget);
begin
  ContentPanel.AddChild(widget);
end;

procedure TWindow.Close;
begin
  Visible := False;
  IsDragging := False;
  GUI.IsAnyWindowDragging := False;
end;

procedure TWindow.Minimize;
begin
  if Minimized then Exit;
  Minimized := True;

  PrevHeight := Bounds.height;
  Bounds.height := TitleBarHeight;

  ContentPanel.Visible := False;
  ContentPanel.Bounds := RectangleCreate(Bounds.x, Bounds.y + TitleBarHeight, Bounds.width, 0);

  CloseButton.Bounds.x    := Bounds.x + Bounds.width - 25;
  CloseButton.Bounds.y    := Bounds.y + 5;
  MinimizeButton.Bounds.x := Bounds.x + Bounds.width - 50;
  MinimizeButton.Bounds.y := Bounds.y + 5;

  GUI.IsAnyWindowDragging := False;
  IsDragging := False;
end;

procedure TWindow.Restore;
begin
  if not Minimized then Exit;
  Minimized := False;

  if PrevHeight < TitleBarHeight + 1 then
    PrevHeight := TitleBarHeight + 1;

  Bounds.height := PrevHeight;

  ContentPanel.Visible := True;
  ContentPanel.Bounds := RectangleCreate(Bounds.x, Bounds.y + TitleBarHeight, Bounds.width, Bounds.height - TitleBarHeight);

  CloseButton.Bounds.x    := Bounds.x + Bounds.width - 25;
  CloseButton.Bounds.y    := Bounds.y + 5;
  MinimizeButton.Bounds.x := Bounds.x + Bounds.width - 50;
  MinimizeButton.Bounds.y := Bounds.y + 5;

  GUI.IsAnyWindowDragging := False;
  IsDragging := False;
end;

procedure TWindow.BringToFront;
begin
  GUI.BringToFront(Self);
end;

procedure TWindow.CloseClicked(widget: TWidget);
begin
  Close;
end;

procedure TWindow.MinimizeClicked(widget: TWidget);
begin
  if Minimized then Restore else Minimize;
end;

{ ===== TGUIManager ===== }

constructor TGUIManager.Create;
begin
  inherited Create;
  SetLength(Widgets, 0);
  FocusedWidget := nil;
  IsAnyWindowDragging := False;
  TooltipTimer := 0.0;
  TooltipWidget := nil;
  TooltipPosition := NewVector(0, 0);
end;

destructor TGUIManager.Destroy;
var
  i: Integer;
begin
  for i := 0 to High(Widgets) do
    if Assigned(Widgets[i]) then
      Widgets[i].Free;
  SetLength(Widgets, 0);
  inherited Destroy;
end;

procedure TGUIManager.Add(widget: TWidget);
begin
  SetLength(Widgets, Length(Widgets) + 1);
  Widgets[High(Widgets)] := widget;
end;

procedure TGUIManager.Remove(widget: TWidget);
var
  i, j: Integer;
begin
  for i := 0 to High(Widgets) do
    if Widgets[i] = widget then
    begin
      for j := i to High(Widgets) - 1 do
        Widgets[j] := Widgets[j + 1];
      SetLength(Widgets, Length(Widgets) - 1);
      Exit;
    end;
end;

procedure TGUIManager.BringToFront(widget: TWidget);
var
  i, idx: Integer;
begin
  idx := -1;
  for i := 0 to High(Widgets) do
    if Widgets[i] = widget then
    begin
      idx := i; Break;
    end;

  if idx >= 0 then
  begin
    for i := idx to High(Widgets) - 1 do
      Widgets[i] := Widgets[i + 1];
    Widgets[High(Widgets)] := widget;
  end;
end;
function IsChildOfWindow(widget, window: TWidget): Boolean;
var
  panel: TPanel;
  i: Integer;
begin
  Result := False;
  
  if widget is TWindow then
    Exit(False);
    
  if window is TWindow then
  begin
    panel := TWindow(window).ContentPanel;
    
    // Sprawdź czy widget jest bezpośrednim dzieckiem panelu okna
    for i := 0 to High(panel.Children) do
    begin
      if panel.Children[i] = widget then
        Exit(True);
    end;
    
    // Sprawdź czy widget jest dzieckiem któregoś z dzieci panelu
    for i := 0 to High(panel.Children) do
    begin
      if panel.Children[i] is TPanel then
      begin
        if IsChildOfPanel(widget, TPanel(panel.Children[i])) then
          Exit(True);
      end;
    end;
  end;
end;

function IsChildOfPanel(widget: TWidget; panel: TPanel): Boolean;
var
  i: Integer;
begin
  Result := False;
  
  for i := 0 to High(panel.Children) do
  begin
    if panel.Children[i] = widget then
      Exit(True);
      
    if panel.Children[i] is TPanel then
    begin
      if IsChildOfPanel(widget, TPanel(panel.Children[i])) then
        Exit(True);
    end;
  end;
end;
procedure TGUIManager.SetFocus(widget: TWidget);
begin
  if (widget <> nil) and (not widget.Visible or not widget.Enabled or not widget.Focusable) then Exit;
  FocusedWidget := widget;
end;

function TGUIManager.GetFocus: TWidget;
begin
  Result := FocusedWidget;
end;

procedure TGUIManager.FocusNext(backwards: Boolean);
var
  order: array of TWidget;
  counts, i, cur: Integer;
  w: TWidget;
  ia, ib: Integer;
  swapped: Boolean;
begin
  // Collect tabstops from Widgets list in creation order; windows first preserve z-order
  counts := 0;
  // First pass to count
  for i := 0 to High(Widgets) do
    if Widgets[i].Visible and Widgets[i].Enabled and Widgets[i].TabStop then
      Inc(counts);
  if counts = 0 then Exit;
  SetLength(order, counts);
  counts := 0;
  for i := 0 to High(Widgets) do
    if Widgets[i].Visible and Widgets[i].Enabled and Widgets[i].TabStop then
    begin
      order[counts] := Widgets[i];
      Inc(counts);
    end;
  // Simple bubble sort by TabIndex (auto = MaxInt)   swapped;
  repeat
    swapped := False;
    for i := 0 to High(order)-1 do
    begin
      ia := order[i].TabIndex; if ia < 0 then ia := High(Integer);
      ib := order[i+1].TabIndex; if ib < 0 then ib := High(Integer);
      if ia > ib then
      begin
        w := order[i]; order[i] := order[i+1]; order[i+1] := w; swapped := True;
      end;
    end;
  until not swapped;
  cur := -1;
  for i := 0 to High(order) do if order[i] = FocusedWidget then begin cur := i; Break; end;
  if backwards then
  begin
    if cur <= 0 then SetFocus(order[High(order)]) else SetFocus(order[cur-1]);
  end
  else
  begin
    if (cur < 0) or (cur = High(order)) then SetFocus(order[0]) else SetFocus(order[cur+1]);
  end;
end;

procedure TGUIManager.Update;
var
  i: Integer;
  mp: TInputVector;
  w: TWidget;
  win: TWindow;
  topWindow: TWindow;
tabDown, shiftOn, enterDown, escDown: Boolean;
begin
  // 1) Reset globalnego "dragging" i asekuracyjne czyszczenie capture na release
  if not IsMouseButtonDown(0) then
  begin
    IsAnyWindowDragging := False;
    MouseCapturedBy := nil;
  end;

  mp := GetMousePosition;

  // 2) Znajdź najwyższe okno pod kursorem (jeśli istnieje)
  topWindow := nil;
  for i := High(Widgets) downto 0 do
  begin
    if (Widgets[i] is TWindow) and Widgets[i].Visible and Widgets[i].ContainsPoint(mp) then
    begin
      topWindow := TWindow(Widgets[i]);
      Break;
    end;
  end;

  // 3) GLOBALNY PRESS HOOK
  if IsMouseButtonPressed(0) then
  begin
    // 3a) Najpierw paski tytułu okien
    for i := High(Widgets) downto 0 do
      if Widgets[i] is TWindow then
      begin
        win := TWindow(Widgets[i]);
        if win.Visible and win.HitTitleBar(mp) then
        begin
          MouseCapturedBy := win;
          Break;
        end;
      end;

    // 3b) Jeśli nie trafiliśmy w pasek tytułu — standardowo:
    if MouseCapturedBy = nil then
    begin
      // Szukaj tylko w najwyższym oknie (jeśli istnieje)
      if topWindow <> nil then
        MouseCapturedBy := HitTestWidget(topWindow, mp)
      else
        MouseCapturedBy := GetWidgetAt(mp.x, mp.y);
    end;

    // 3c) Focus/blur dla TTextBox
    // Focus: clicked widget gets focus if focusable
    if Assigned(MouseCapturedBy) and MouseCapturedBy.Focusable then
      SetFocus(MouseCapturedBy)
    else if Assigned(FocusedWidget) and (not FocusedWidget.Focusable) then
      FocusedWidget := nil;

    if Assigned(MouseCapturedBy) and (MouseCapturedBy is TTextBox) then
      TTextBox(MouseCapturedBy).Focus
    else if (FocusedWidget is TTextBox) then
      TTextBox(FocusedWidget).Blur;
  end;

  // 3d) Klawiszologia: Tab/Shift+Tab, Enter, Esc
  tabDown := IsKeyDown('Tab');
  shiftOn := IsKeyDown('ShiftLeft') or IsKeyDown('ShiftRight');
  if tabDown and (not LastTabDown) then
  begin
    FocusNext(shiftOn);
  end;
  LastTabDown := tabDown;

  enterDown := IsKeyDown('Enter');
  if enterDown and (not LastEnterDown) then
  begin
    if (FocusedWidget <> nil) and Assigned(FocusedWidget.OnClick) then
      FocusedWidget.OnClick(FocusedWidget);
  end;
  LastEnterDown := enterDown;

  escDown := IsKeyDown('Escape');
  if escDown and (not LastEscDown) then
  begin
    // blur textbox if focused, otherwise noop
    if (FocusedWidget is TTextBox) then TTextBox(FocusedWidget).Blur;
  end;
  LastEscDown := escDown;

  // 4) Tooltips
  if Assigned(TooltipWidget) then
    TooltipTimer := TooltipTimer + GetDeltaTime
  else
    TooltipTimer := 0.0;

  // 5) Jeżeli ktoś trzyma capture — aktualizujemy WYŁĄCZNIE jego
  if Assigned(MouseCapturedBy) then
  begin
    MouseCapturedBy.Update;
    Exit;
  end;

  // 6) Aktualizuj tylko widgety w najwyższym oknie pod kursorem
  if topWindow <> nil then
  begin
    // Aktualizuj najpierw okno
    topWindow.Update;
    
    // Aktualizuj tylko dzieci tego okna
    for i := 0 to High(Widgets) do
    begin
      if (Widgets[i] <> topWindow) and IsChildOfWindow(Widgets[i], topWindow) then
        Widgets[i].Update;
    end;
  end
  else
  begin
    // Brak okien pod kursorem — aktualizuj wszystko standardowo
    for i := High(Widgets) downto 0 do
      Widgets[i].Update;
  end;

  // 7) Resetuj stan widgetów, które nie są w aktywnej warstwie
  for i := 0 to High(Widgets) do
  begin
    if (topWindow <> nil) and not IsChildOfWindow(Widgets[i], topWindow) and (Widgets[i] <> topWindow) then
    begin
      if Widgets[i].State in [wsHover, wsActive] then
      begin
        Widgets[i].State := wsNormal;
        if Assigned(Widgets[i].OnLeave) then
          Widgets[i].OnLeave(Widgets[i]);
      end;
    end;
  end;
end;



procedure TGUIManager.Draw;
var
  i: Integer;
  tipW: Integer;
begin
  for i := 0 to High(Widgets) do
    Widgets[i].Draw;

  if (TooltipWidget <> nil) and (TooltipTimer > 1.0) then
  begin
    tipW := Round(MeasureTextWidth(TooltipWidget.Tooltip, 12) + 10);
    DrawRectangle(Round(TooltipPosition.x), Round(TooltipPosition.y), tipW, 20, COLOR_BLACK);
    DrawText(TooltipWidget.Tooltip, Round(TooltipPosition.x + 5), Round(TooltipPosition.y + 2), 12, COLOR_WHITE);
  end;
end;

function TGUIManager.GetWidgetAt(x, y: Double): TWidget;
var
  i: Integer;
  p: TInputVector;
  r: TWidget;
begin
  p := NewVector(x, y);
  for i := High(Widgets) downto 0 do
  begin
    r := HitTestWidget(Widgets[i], p);
    if r <> nil then Exit(r);
  end;
  Result := nil;
end;

procedure TGUIManager.ShowTooltip(widget: TWidget; x, y: Double);
begin
  if TooltipWidget <> widget then
  begin
    TooltipWidget := widget;
    TooltipTimer := 0.0;
    TooltipPosition := NewVector(x + 15, y + 15);
  end;
end;

procedure TGUIManager.HideTooltip;
begin
  TooltipWidget := nil;
  TooltipTimer := 0.0;
end;

initialization
  GUI := TGUIManager.Create;

end.

program Wilga_Font_Pacifico_Scope;

{$mode objfpc}{$H+}

uses
  wilga, wilga_extras, wilga_font_scope;

var
  FontReady: Boolean = False;
  TimeAcc: Double = 0.0;      // akumulator czasu do animacji
  PosWave: TVector2;          // stała pozycja dla falującego napisu

procedure OnFontReady;
begin
  FontReady := True;
end;

// === LOGIKA / UPDATE ===
procedure Update(const dt: Double);
begin
  // akumuluj czas (sekundy) — bez rysowania
  TimeAcc += dt;
end;

// === RYSOWANIE / DRAW ===
procedure Draw(const dt:double);
begin
  ClearBackground(ColorRGBA(20,22,28,255));

  if FontReady then
  begin
    // Scope czcionki Pacifico tylko w tym bloku
    WithFont('Pacifico', procedure
    begin
      // Typewriter: tekst rośnie wg TimeAcc; prędkość 6.0 znaków/s
      DrawTextTypewriter('Hello from Wilga!', Vector2create(100, 200), 70, color_white, TimeAcc, 3.0);
    end);
  end
  else
  begin
    DrawText('Ładowanie czcionki...', 80, 120, 24, ColorRGBA(220,220,220,255));
  end;

  // Falujący napis zwykłą rodziną domyślną (po wyjściu z WithFont)
  // fontSize=48, amplitude=8 px, speed=2.0
  DrawTextWave(':)', PosWave, 48, ColorRGBA(255,204,64,255), TimeAcc, 8.0, 2.0);
end;

begin
  InitWindow(800, 450, 'Wilga - Pacifico (scope demo)');

  // Ustaw domyślną rodzinę dla całej aplikacji (systemowa)
  InitFontTracking('system-ui, sans-serif');

  // Pozycja dla falującego napisu
  PosWave.x := 80; PosWave.y := 120;

  // Załaduj Pacifico (najlepiej .woff2 w /assets/)
  LoadWebFont('Pacifico', 'Pacifico-Regular.ttf', @OnFontReady);
  // lub:
  // LoadWebFont('Pacifico', 'assets/Pacifico-Regular.ttf', @OnFontReady);

  // DWA callbacki: Update + Draw
  Run(@Update, @Draw);
end.

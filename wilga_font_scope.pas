unit wilga_font_scope;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}

interface

uses
  SysUtils,wilga;

type
  // Anonimowy callback (pas2js/FPC): WithFont('Pacifico', procedure ... end);
  TProcRef = reference to procedure;
  // Zwykła procedura bez parametrów: WithFontP('Pacifico', @MyProc);
  TProc    = procedure;

  TFontState = record
    Family: string;
  end;

procedure InitFontTracking(const DefaultFamily: string = 'system-ui, sans-serif');
procedure BeginFont(const Family: string);
procedure EndFont;

// Wersja z anonimową procedurą (najwygodniejsza)
procedure WithFont(const Family: string; const Proc: TProcRef);
// Wersja klasyczna (gdy nie chcesz anonymousfunctions w module wywołującym)
procedure WithFontP(const Family: string; Proc: TProc);

function CurrentFontFamily: string;

implementation

var
  FontStack: array of TFontState;
  Current: TFontState;

procedure ApplyFont(const S: TFontState);
begin
  // KLUCZ: DrawText/EnsureFont korzysta z rodziny ustawionej SetFontFamily
  SetFontFamily(S.Family);
end;

procedure InitFontTracking(const DefaultFamily: string);
begin
  SetLength(FontStack, 0);
  Current.Family := DefaultFamily;
  ApplyFont(Current);
end;

procedure BeginFont(const Family: string);
var NewState: TFontState;
begin
  // push
  SetLength(FontStack, Length(FontStack)+1);
  FontStack[High(FontStack)] := Current;

  // new
  NewState.Family := Family;
  Current := NewState;
  ApplyFont(Current);
end;

procedure EndFont;
var N: Integer;
begin
  N := Length(FontStack);
  if N = 0 then Exit; // nic do przywrócenia
  Current := FontStack[N-1];
  SetLength(FontStack, N-1);
  ApplyFont(Current);
end;

procedure WithFont(const Family: string; const Proc: TProcRef);
begin
  BeginFont(Family);
  try
    Proc();
  finally
    EndFont;
  end;
end;

procedure WithFontP(const Family: string; Proc: TProc);
begin
  BeginFont(Family);
  try
    Proc();
  finally
    EndFont;
  end;
end;

function CurrentFontFamily: string; begin Result := Current.Family; end;

end.

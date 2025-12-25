unit wilga_ecs;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, Math,
  wilga,         // TVector2, TRectangle, TColor, itp.
  wilga_extras;  // TSprite, TSpriteAnimator, SpriteDraw, SpriteAnimInit/Play/Update...

type
  // Id encji – indeks w tablicach ECS
  TEntityId = Integer;

  // 8 kierunków (jak w klasycznym 8-dir sprite entity)
  TDir8 = (
    dDown,        // 0,1
    dDownRight,   // 1,1
    dRight,       // 1,0
    dUpRight,     // 1,-1
    dUp,          // 0,-1
    dUpLeft,      // -1,-1
    dLeft,        // -1,0
    dDownLeft     // -1,1
  );

  // Prosty stan ruchu
  TSpriteMoveState = (
    ssIdle,
    ssWalk
  );

  // === Komponenty ========================================================

  // Transform – pozycja, skala, rotacja (w radianach)
  TTransform = record
    position : TVector2;
    scale    : TVector2;
    rotation : Double; // radiany
  end;
  PTransform = ^TTransform;

  // Velocity – prędkość (jednostki na sekundę)
  TVelocity = record
    velocity: TVector2;
  end;
  PVelocity = ^TVelocity;

  // Collider – prostokąt AABB w lokalnych koordach encji
  TCollider = record
    rect  : TRectangle; // np. (-8,-16, 16, 16) dla bohatera
    solid : Boolean;    // czy blokuje ruch
  end;
  PCollider = ^TCollider;

  // Facing + Speed + State – zamiennik logiki ze SpriteEntity
  TFacingMove = record
    Facing : TVector2;        // wektor kierunku (-1..1)
    Speed  : Double;          // prędkość
    State  : TSpriteMoveState;// Idle/Walk
  end;
  PFacingMove = ^TFacingMove;

  // Komponent animatora 8-kierunkowego
  // Zakładamy, że masz TSpriteAnimator w wilga_extras
  TSpriteAnimComp = record
    Anim         : TSpriteAnimator;
    BaseIdleName : String; // np. 'idle'
    BaseWalkName : String; // np. 'walk'
  end;
  PSpriteAnimComp = ^TSpriteAnimComp;

  // Health / HP – dodatkowy komponent
  THealth = record
    MaxHP : Integer;
    HP    : Integer;
    Alive : Boolean;
  end;
  PHealth = ^THealth;

  // Komponent Sprite – sam TSprite
  PSpriteComponent = ^TSprite;

  // Callbacki do iteracji
  TEntityProc = reference to procedure(e: TEntityId);
  TSpriteProc = reference to procedure(e: TEntityId; var s: TSprite);

  // === Świat ECS =========================================================

  TWorld = class
  private
    // Życie encji
    fAlive    : array of Boolean;
    fCount    : Integer;
    fFreeList : array of TEntityId;
    fFreeCount: Integer;

    // Komponenty + maski
    fTransform    : array of TTransform;
    fHasTransform : array of Boolean;

    fVelocity     : array of TVelocity;
    fHasVelocity  : array of Boolean;

    fSprite       : array of TSprite;
    fHasSprite    : array of Boolean;

    fCollider     : array of TCollider;
    fHasCollider  : array of Boolean;

    fFacingMove    : array of TFacingMove;
    fHasFacingMove : array of Boolean;

    fAnimComp      : array of TSpriteAnimComp;
    fHasAnimComp   : array of Boolean;

    fHealth        : array of THealth;
    fHasHealth     : array of Boolean;

    procedure EnsureCapacity(minCount: Integer);
    function  AllocEntitySlot: TEntityId;
    procedure ReleaseEntitySlot(e: TEntityId);
    function  ValidEntity(e: TEntityId): Boolean; inline;
  public
    constructor Create;
    destructor Destroy; override;

    // Tworzenie / usuwanie encji
    function  CreateEntity: TEntityId;
    procedure DestroyEntity(e: TEntityId);
    function  IsAlive(e: TEntityId): Boolean;

    // --- Transform ---
    procedure AddTransform(e: TEntityId; const pos, scale: TVector2;
      rotationRad: Double = 0.0);
    function  HasTransform(e: TEntityId): Boolean;
    function  GetTransform(e: TEntityId): PTransform;

    // --- Velocity ---
    procedure AddVelocity(e: TEntityId; const vel: TVector2);
    function  HasVelocity(e: TEntityId): Boolean;
    function  GetVelocity(e: TEntityId): PVelocity;

    // --- Sprite ---
    procedure AddSprite(e: TEntityId; const spr: TSprite);
    function  HasSprite(e: TEntityId): Boolean;
    function  GetSprite(e: TEntityId): PSpriteComponent;

    // --- Collider ---
    procedure AddCollider(e: TEntityId; const rect: TRectangle; solid: Boolean);
    function  HasCollider(e: TEntityId): Boolean;
    function  GetCollider(e: TEntityId): PCollider;

    // --- FacingMove ---
    procedure AddFacingMove(e: TEntityId; const facing: TVector2;
      speed: Double; state: TSpriteMoveState = ssIdle);
    function  HasFacingMove(e: TEntityId): Boolean;
    function  GetFacingMove(e: TEntityId): PFacingMove;

    // --- SpriteAnimatorComp ---
    procedure AddSpriteAnimator(e: TEntityId; const anim: TSpriteAnimator;
      const baseIdle, baseWalk: String);
    function  HasSpriteAnimator(e: TEntityId): Boolean;
    function  GetSpriteAnimator(e: TEntityId): PSpriteAnimComp;

    // --- Health ---
    procedure AddHealth(e: TEntityId; maxHp, hp: Integer);
    function  HasHealth(e: TEntityId): Boolean;
    function  GetHealth(e: TEntityId): PHealth;
    procedure Damage(e: TEntityId; amount: Integer);
    procedure Heal(e: TEntityId; amount: Integer);

    // === Systemy =========================================================

    // Prosty ruch: pos += vel * dt (Transform + Velocity)
    procedure UpdateMovement(dt: Double);

    // Logika “sprite entity”: FacingMove + Sprite + Animator (+Transform)
    procedure UpdateSpriteLogic8Dir(dt: Double);

    // Aktualizacja Health – pilnuje Alive, ewentualnie auto-kill
    procedure UpdateHealth;

    // Rysowanie sprite’ów (Transform → Sprite.position/scale/rotation)
    procedure DrawSprites;

    // === Iteratory pomocnicze ============================================

    procedure ForEach(const cb: TEntityProc);
    procedure ForEachSprite(const cb: TSpriteProc);
  end;

implementation

// === Małe helpery wektorowe ==============================================

function Vec2(x, y: Double): TVector2; inline;
begin
  Result.x := x;
  Result.y := y;
end;

function Vec2Add(const a, b: TVector2): TVector2; inline;
begin
  Result.x := a.x + b.x;
  Result.y := a.y + b.y;
end;

function Vec2Scale(const v: TVector2; s: Double): TVector2; inline;
begin
  Result.x := v.x * s;
  Result.y := v.y * s;
end;

function Vec2Length(const v: TVector2): Double; inline;
begin
  Result := Sqrt(v.x * v.x + v.y * v.y);
end;

function Vec2Normalize(const v: TVector2): TVector2; inline;
var
  l: Double;
begin
  l := Vec2Length(v);
  if l > 0.00001 then
  begin
    Result.x := v.x / l;
    Result.y := v.y / l;
  end
  else
    Result := Vec2(0, 0);
end;

// === Pomoc: wektor -> 8-kierunkowy enum + nazwy klipów ===================

function VecToDir8(const v: TVector2): TDir8;
var
  ang: Double;
begin
  // Jeśli prawie zero – powiedzmy dDown
  if (Abs(v.x) < 0.01) and (Abs(v.y) < 0.01) then
    Exit(dDown);

  ang := ArcTan2(v.y, v.x); // -pi..pi, 0 = prawo

  if (ang >= -Pi/8) and (ang < Pi/8) then
    Result := dRight
  else if (ang >= Pi/8) and (ang < 3*Pi/8) then
    Result := dDownRight
  else if (ang >= 3*Pi/8) and (ang < 5*Pi/8) then
    Result := dDown
  else if (ang >= 5*Pi/8) and (ang < 7*Pi/8) then
    Result := dDownLeft
  else if (ang >= -3*Pi/8) and (ang < -Pi/8) then
    Result := dUpRight
  else if (ang >= -5*Pi/8) and (ang < -3*Pi/8) then
    Result := dUp
  else if (ang >= -7*Pi/8) and (ang < -5*Pi/8) then
    Result := dUpLeft
  else
    Result := dLeft;
end;

function Dir8ToClipName(const base: String; dir: TDir8): String;
const
  Suffix: array[TDir8] of String = (
    'down',
    'down_right',
    'right',
    'up_right',
    'up',
    'up_left',
    'left',
    'down_left'
  );
begin
  Result := base + '_' + Suffix[dir];
end;

// === TWorld ===============================================================

constructor TWorld.Create;
begin
  inherited Create;
  fCount     := 0;
  fFreeCount := 0;
  SetLength(fAlive, 0);
end;

destructor TWorld.Destroy;
begin
  inherited Destroy;
end;

procedure TWorld.EnsureCapacity(minCount: Integer);
var
  oldLen, newLen: Integer;
begin
  oldLen := Length(fAlive);
  if oldLen >= minCount then Exit;

  newLen := oldLen;
  if newLen = 0 then
    newLen := 64;
  while newLen < minCount do
    newLen := newLen * 2;

  SetLength(fAlive,        newLen);

  SetLength(fTransform,    newLen);
  SetLength(fHasTransform, newLen);

  SetLength(fVelocity,     newLen);
  SetLength(fHasVelocity,  newLen);

  SetLength(fSprite,       newLen);
  SetLength(fHasSprite,    newLen);

  SetLength(fCollider,     newLen);
  SetLength(fHasCollider,  newLen);

  SetLength(fFacingMove,    newLen);
  SetLength(fHasFacingMove, newLen);

  SetLength(fAnimComp,      newLen);
  SetLength(fHasAnimComp,   newLen);

  SetLength(fHealth,        newLen);
  SetLength(fHasHealth,     newLen);
end;

function TWorld.ValidEntity(e: TEntityId): Boolean;
begin
  Result := (e >= 0) and (e < fCount);
end;

function TWorld.AllocEntitySlot: TEntityId;
begin
  if fFreeCount > 0 then
  begin
    Dec(fFreeCount);
    Result := fFreeList[fFreeCount];
    Exit;
  end;

  Result := fCount;
  Inc(fCount);
  EnsureCapacity(fCount);
end;

procedure TWorld.ReleaseEntitySlot(e: TEntityId);
var
  n: Integer;
begin
  if not ValidEntity(e) then Exit;
  if not fAlive[e] then Exit;

  fAlive[e] := False;

  // Czyścimy maski komponentów
  fHasTransform[e]   := False;
  fHasVelocity[e]    := False;
  fHasSprite[e]      := False;
  fHasCollider[e]    := False;
  fHasFacingMove[e]  := False;
  fHasAnimComp[e]    := False;
  fHasHealth[e]      := False;

  // Dodaj do free-listy
  n := Length(fFreeList);
  if fFreeCount >= n then
  begin
    if n = 0 then n := 16 else n := n * 2;
    SetLength(fFreeList, n);
  end;
  fFreeList[fFreeCount] := e;
  Inc(fFreeCount);
end;

function TWorld.CreateEntity: TEntityId;
begin
  Result := AllocEntitySlot;
  fAlive[Result] := True;

  fHasTransform[Result]   := False;
  fHasVelocity[Result]    := False;
  fHasSprite[Result]      := False;
  fHasCollider[Result]    := False;
  fHasFacingMove[Result]  := False;
  fHasAnimComp[Result]    := False;
  fHasHealth[Result]      := False;
end;

procedure TWorld.DestroyEntity(e: TEntityId);
begin
  ReleaseEntitySlot(e);
end;

function TWorld.IsAlive(e: TEntityId): Boolean;
begin
  Result := ValidEntity(e) and fAlive[e];
end;

// --- Transform ------------------------------------------------------------

procedure TWorld.AddTransform(e: TEntityId; const pos, scale: TVector2;
  rotationRad: Double);
begin
  if not IsAlive(e) then Exit;
  fTransform[e].position := pos;
  fTransform[e].scale    := scale;
  fTransform[e].rotation := rotationRad;
  fHasTransform[e]       := True;
end;

function TWorld.HasTransform(e: TEntityId): Boolean;
begin
  Result := IsAlive(e) and fHasTransform[e];
end;

function TWorld.GetTransform(e: TEntityId): PTransform;
begin
  if HasTransform(e) then
    Result := @fTransform[e]
  else
    Result := nil;
end;

// --- Velocity -------------------------------------------------------------

procedure TWorld.AddVelocity(e: TEntityId; const vel: TVector2);
begin
  if not IsAlive(e) then Exit;
  fVelocity[e].velocity := vel;
  fHasVelocity[e]       := True;
end;

function TWorld.HasVelocity(e: TEntityId): Boolean;
begin
  Result := IsAlive(e) and fHasVelocity[e];
end;

function TWorld.GetVelocity(e: TEntityId): PVelocity;
begin
  if HasVelocity(e) then
    Result := @fVelocity[e]
  else
    Result := nil;
end;

// --- Sprite ---------------------------------------------------------------

procedure TWorld.AddSprite(e: TEntityId; const spr: TSprite);
begin
  if not IsAlive(e) then Exit;
  fSprite[e]    := spr;    // kopiujemy rekord
  fHasSprite[e] := True;
end;

function TWorld.HasSprite(e: TEntityId): Boolean;
begin
  Result := IsAlive(e) and fHasSprite[e];
end;

function TWorld.GetSprite(e: TEntityId): PSpriteComponent;
begin
  if HasSprite(e) then
    Result := @fSprite[e]
  else
    Result := nil;
end;

// --- Collider -------------------------------------------------------------

procedure TWorld.AddCollider(e: TEntityId; const rect: TRectangle; solid: Boolean);
begin
  if not IsAlive(e) then Exit;
  fCollider[e].rect  := rect;
  fCollider[e].solid := solid;
  fHasCollider[e]    := True;
end;

function TWorld.HasCollider(e: TEntityId): Boolean;
begin
  Result := IsAlive(e) and fHasCollider[e];
end;

function TWorld.GetCollider(e: TEntityId): PCollider;
begin
  if HasCollider(e) then
    Result := @fCollider[e]
  else
    Result := nil;
end;

// --- FacingMove -----------------------------------------------------------

procedure TWorld.AddFacingMove(e: TEntityId; const facing: TVector2;
  speed: Double; state: TSpriteMoveState);
begin
  if not IsAlive(e) then Exit;
  fFacingMove[e].Facing := facing;
  fFacingMove[e].Speed  := speed;
  fFacingMove[e].State  := state;
  fHasFacingMove[e]     := True;
end;

function TWorld.HasFacingMove(e: TEntityId): Boolean;
begin
  Result := IsAlive(e) and fHasFacingMove[e];
end;

function TWorld.GetFacingMove(e: TEntityId): PFacingMove;
begin
  if HasFacingMove(e) then
    Result := @fFacingMove[e]
  else
    Result := nil;
end;

// --- SpriteAnimatorComp ---------------------------------------------------

procedure TWorld.AddSpriteAnimator(e: TEntityId; const anim: TSpriteAnimator;
  const baseIdle, baseWalk: String);
begin
  if not IsAlive(e) then Exit;
  fAnimComp[e].Anim         := anim;
  fAnimComp[e].BaseIdleName := baseIdle;
  fAnimComp[e].BaseWalkName := baseWalk;
  fHasAnimComp[e]           := True;
end;

function TWorld.HasSpriteAnimator(e: TEntityId): Boolean;
begin
  Result := IsAlive(e) and fHasAnimComp[e];
end;

function TWorld.GetSpriteAnimator(e: TEntityId): PSpriteAnimComp;
begin
  if HasSpriteAnimator(e) then
    Result := @fAnimComp[e]
  else
    Result := nil;
end;

// --- Health ---------------------------------------------------------------

procedure TWorld.AddHealth(e: TEntityId; maxHp, hp: Integer);
begin
  if not IsAlive(e) then Exit;
  if maxHp <= 0 then maxHp := 1;
  if hp > maxHp then hp := maxHp;
  if hp < 0 then hp := 0;

  fHealth[e].MaxHP := maxHp;
  fHealth[e].HP    := hp;
  fHealth[e].Alive := (hp > 0);
  fHasHealth[e]    := True;
end;

function TWorld.HasHealth(e: TEntityId): Boolean;
begin
  Result := IsAlive(e) and fHasHealth[e];
end;

function TWorld.GetHealth(e: TEntityId): PHealth;
begin
  if HasHealth(e) then
    Result := @fHealth[e]
  else
    Result := nil;
end;

procedure TWorld.Damage(e: TEntityId; amount: Integer);
var
  h: PHealth;
begin
  if amount <= 0 then Exit;
  h := GetHealth(e);
  if h = nil then Exit;

  h^.HP := h^.HP - amount;
  if h^.HP <= 0 then
  begin
    h^.HP    := 0;
    h^.Alive := False;
  end;
end;

procedure TWorld.Heal(e: TEntityId; amount: Integer);
var
  h: PHealth;
begin
  if amount <= 0 then Exit;
  h := GetHealth(e);
  if h = nil then Exit;

  if not h^.Alive then Exit; // martwy się nie leczy

  h^.HP := h^.HP + amount;
  if h^.HP > h^.MaxHP then
    h^.HP := h^.MaxHP;
end;

// === Systemy ==============================================================

procedure TWorld.UpdateMovement(dt: Double);
var
  i: Integer;
  pos: PTransform;
  vel: PVelocity;
begin
  if dt <= 0 then Exit;

  for i := 0 to fCount - 1 do
  begin
    if not fAlive[i] then Continue;
    if not (fHasTransform[i] and fHasVelocity[i]) then Continue;

    pos := @fTransform[i];
    vel := @fVelocity[i];

    pos^.position.x += vel^.velocity.x * dt;
    pos^.position.y += vel^.velocity.y * dt;
  end;
end;

// Logika ruchu + animacji 8-dir na bazie FacingMove/Sprite/Animator
procedure TWorld.UpdateSpriteLogic8Dir(dt: Double);
var
  i: Integer;
  fm : PFacingMove;
  tr : PTransform;
  spr: PSpriteComponent;
  anim: PSpriteAnimComp;
  dir : TDir8;
  len : Double;
  vel : TVector2;
  desiredClip, currentClip: String;
begin
  if dt <= 0 then Exit;

  for i := 0 to fCount - 1 do
  begin
    if not fAlive[i] then Continue;

    if not (fHasFacingMove[i] and fHasSprite[i] and fHasAnimComp[i]) then
      Continue;

    fm   := @fFacingMove[i];
    spr  := @fSprite[i];
    anim := @fAnimComp[i];

    // RUCH: pos += Facing * Speed * dt
    vel := Vec2Scale(fm^.Facing, fm^.Speed * dt);

    if fHasTransform[i] then
    begin
      tr := @fTransform[i];
      tr^.position := Vec2Add(tr^.position, vel);
      // Sprite.position zostanie podmieniony w DrawSprites
    end
    else
    begin
      spr^.position := Vec2Add(spr^.position, vel);
    end;

    // STAN: Idle vs Walk (dead-zone ~ 0.1)
    len := Vec2Length(fm^.Facing);
    if len < 0.1 then
      fm^.State := ssIdle
    else
      fm^.State := ssWalk;

    // WYBÓR NAZWY KLIPU
    if fm^.State = ssWalk then
    begin
      dir := VecToDir8(fm^.Facing);
      desiredClip := Dir8ToClipName(anim^.BaseWalkName, dir); // np. "walk_right"
    end
    else
    begin
      desiredClip := anim^.BaseIdleName; // np. "idle"
    end;

    // BIEŻĄCY KLIP W ANIMATORZE
    currentClip := '';
    if (anim^.Anim.currentClipIdx >= 0) and
       (anim^.Anim.currentClipIdx < Length(anim^.Anim.clips)) then
      currentClip := anim^.Anim.clips[anim^.Anim.currentClipIdx].name;

    // UWAGA: odpalamy klip TYLKO gdy się ZMIENIŁ
    if (currentClip <> desiredClip) then
      SpriteAnimPlay(anim^.Anim, desiredClip);

    // UPDATE KLATEK
    SpriteAnimUpdate(anim^.Anim, spr^, dt);
  end;
end;

// System Health – np. auto-kill encji z HP <= 0
procedure TWorld.UpdateHealth;
var
  i: Integer;
  h: PHealth;
begin
  // Uwaga: DestroyEntity(i) w pętli po i jest OK, bo fAlive[i] zmieni się
  // na False; slot trafi do free-listy, ale indeksy nadal obowiązują.
  for i := 0 to fCount - 1 do
  begin
    if not fAlive[i] then Continue;
    if not fHasHealth[i] then Continue;

    h := @fHealth[i];
    if (not h^.Alive) or (h^.HP <= 0) then
    begin
      DestroyEntity(i);
    end;
  end;
end;

// Rysowanie sprite’ów
procedure TWorld.DrawSprites;
var
  i: Integer;
  spr: PSpriteComponent;
  tr : PTransform;
begin
  for i := 0 to fCount - 1 do
  begin
    if not fAlive[i] then Continue;
    if not fHasSprite[i] then Continue;

    spr := @fSprite[i];

    if fHasTransform[i] then
    begin
      tr := @fTransform[i];
      spr^.position    := tr^.position;
      spr^.scale       := tr^.scale;
      spr^.rotationDeg := tr^.rotation * 180.0 / Pi; // Wilga używa stopni
    end;

    SpriteDraw(spr^);
  end;
end;

// === Iteratory pomocnicze ================================================

procedure TWorld.ForEach(const cb: TEntityProc);
var
  i: Integer;
begin
  if not Assigned(cb) then Exit;
  for i := 0 to fCount - 1 do
    if fAlive[i] then
      cb(i);
end;

procedure TWorld.ForEachSprite(const cb: TSpriteProc);
var
  i: Integer;
begin
  if not Assigned(cb) then Exit;
  for i := 0 to fCount - 1 do
    if fAlive[i] and fHasSprite[i] then
      cb(i, fSprite[i]);
end;

end.

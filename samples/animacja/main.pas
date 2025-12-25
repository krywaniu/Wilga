uses
  wilga, wilga_extras, sysutils;

var
  FireSprite : TSprite;
  FireAnim   : TSpriteAnimator;
  Ready      : Boolean = False;

procedure OnFireLoaded(const tex: TTexture);
begin
  SpriteInit(FireSprite, tex);

  // animator + klip
  SpriteAnimInit(FireAnim, tex);
  SpriteAnimAddStrip(FireAnim, FireSprite, 'idle',
    5, 5, 12.0, True, 0);
  SpriteAnimPlay(FireAnim, 'idle');


  FireSprite.origin   := NewVector(0.0, 0.0); 
  FireSprite.position := Vector2Create(GetScreenWidth div 2,
                                       GetScreenHeight div 2);

  Ready := True;
end;

procedure Update(const dt: Double);
begin
  if not Ready then Exit;
  SpriteAnimUpdate(FireAnim, FireSprite, dt);

end;

procedure Draw(const dt: Double);
begin
  ClearBackground(Color_black);

  if Ready then
    SpriteDraw(FireSprite)
  else
    DrawText('Ladowanie ogniska...', 20, 20, 24, Color_White);
end;

begin
  InitWindow(800, 800, 'Wilga - SpriteAnim');
  SetTargetFPS(60);

  LoadImageFromURL('fire.png', @OnFireLoaded);
  Run(@Update, @Draw);
end.

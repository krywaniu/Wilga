{ Wilga global switches }

{$DEFINE WILGA_TEXT_CACHE}    // ← DOMYŚLNIE WŁĄCZONE
{ Aby wyłączyć cache, zakomentuj linię wyżej ALBO skompiluj z: -uWILGA_TEXT_CACHE }
{$DEFINE WILGA_ASSERTS}     // asercje w dev-buildach (możesz wyłączyć w release)
{$DEFINE WILGA_LEAK_GUARD}  // licznik save/restore + kontrole na ramkę

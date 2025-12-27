Do działania biblioteki niezbędne są:

main.pas

Główny plik źródłowy napisany w języku Pascal.

main.js

Plik wynikowy generowany przez kompilator pas2js na podstawie pliku main.pas.

RTL pas2js

Biblioteka uruchomieniowa (runtime library), np. rtl.js oraz ewentualne dodatkowe moduły.
Jest wymagana do poprawnego działania kodu wygenerowanego przez pas2js.

index.html

Plik startowy aplikacji. Odpowiada za załadowanie plików RTL oraz main.js i uruchomienie aplikacji w przeglądarce.

⚠️ Uwaga:
Nie uruchamiaj projektu bezpośrednio przez plik index.html (np. przez dwuklik) — aplikacja w takiej formie nie zadziała.

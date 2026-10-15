# TIR Simulator 3D (macOS)

> Wersja na Windows, macOS i Linux (Python + Panda3D) jest w folderze [`python/`](python/README.md).

Gra 3D (SceneKit): jeździsz ciężarówką z naczepą po mapie Polski, bierzesz zlecenia w miastach, wieziesz towar i zarabiasz. Kamera jedzie za ciężarówką, a nad sceną jest HUD z minimapą i strzałką do celu.

## Wymagania
- macOS 12 lub nowszy
- Xcode (albo same Command Line Tools: `xcode-select --install`)

## Uruchomienie
W Terminalu, w folderze `tir-game-3d`:

```
swift run -c release
```

Albo w Xcode: **File → Open…**, wskaż folder `tir-game-3d` (plik `Package.swift`), potem ▶︎ Run (Cmd+R).

## Sterowanie
| Klawisz | Akcja |
|---|---|
| Strzałki / WASD | gaz, hamulec/wsteczny, skręt |
| Spacja | hamulec ręczny |
| C | zmiana kamery (za ciężarówką / wyżej / z góry) |
| 1, 2, 3 | weź zlecenie (stojąc na placu w mieście) |
| E | rozładuj w mieście docelowym |
| F | tankuj (stacja 5,50 zł/l, miasto 7,00 zł/l) |
| H | pomoc drogowa, gdy skończy się paliwo (−800 zł) |
| Cmd+Q | wyjście |

## Zasady
- Zapłata zależy od dystansu, rodzaju towaru i masy.
- Spóźnienie obcina zapłatę o 50%.
- Szybka jazda po bezdrożach uszkadza ładunek i zmniejsza zapłatę.
- Załadowana ciężarówka wolniej przyspiesza i pali więcej. Kolor naczepy zależy od towaru.

## Pliki
- `Game.swift` – logika gry (jazda, naczepa, paliwo, zlecenia)
- `World.swift` – mapa: miasta, stacje, drogi, rodzaje towarów
- `World3D.swift` – świat 3D: drogi, budynki, drzewa, ciężarówka, kamera
- `HUD.swift` – nakładka z informacjami i minimapą
- `main.swift` – okno aplikacji i pętla gry

# TIR Simulator 3D (Python)

Gra 3D o przewożeniu towarów ciężarówką z naczepą po mapie Polski. Działa na **Windows, macOS i Linux** (Python + Panda3D).

![Jazda](screenshots/2_jazda_kamera_za.png)

## Instalacja i uruchomienie

Potrzebny jest Python 3.9–3.13 ([python.org](https://www.python.org/downloads/)). W terminalu, w folderze `python`:

**Windows**
```
py -m pip install -r requirements.txt
py run.py
```

**macOS / Linux**
```
python3 -m pip install -r requirements.txt
python3 run.py
```

Jeśli pip odmawia instalacji globalnie (np. na nowszym Linuksie lub macOS z Homebrew), użyj środowiska wirtualnego:
```
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python run.py
```

## Sterowanie
| Klawisz | Akcja |
|---|---|
| Strzałki / WASD | gaz, hamulec/wsteczny, skręt |
| Spacja | hamulec ręczny |
| C | kamera: za ciężarówką / wyżej / z góry |
| 1, 2, 3 | weź zlecenie (stojąc na placu w mieście) |
| E | rozładuj w mieście docelowym |
| F | tankuj (stacja 5,50 zł/l, miasto 7,00 zł/l) |
| H | pomoc drogowa, gdy skończy się paliwo (−800 zł) |
| Esc | wyjście |

## Zasady
- Zapłata zależy od dystansu, rodzaju towaru i masy.
- Spóźnienie obcina zapłatę o 50%.
- Szybka jazda po bezdrożach i uderzenia w budynki lub drzewa uszkadzają ładunek.
- Załadowana ciężarówka wolniej przyspiesza i pali więcej. Kolor naczepy zależy od towaru.
- Żółta strzałka u góry wskazuje cel (względem kierunku jazdy), minimapa jest w prawym górnym rogu.

## Pliki
- `run.py` – start gry
- `tir/game.py` – logika gry (jazda, naczepa, paliwo, zlecenia, kolizje)
- `tir/world.py` – mapa: miasta, stacje, drogi, budynki, drzewa, towary
- `tir/scene3d.py` – świat 3D, ciężarówka, kamera
- `tir/hud.py` – nakładka z informacjami i minimapą
- `tir/mesh.py` – generator prostych brył 3D
- `tests/` – testy logiki (`python -m unittest discover tests`) i test renderowania ze zrzutami (`python tests/smoke_render.py`)

Czcionka DejaVu Sans jest dołączona w `tir/assets` (licencja w `DejaVu-LICENSE.txt`).

"""Uruchamia grę bez gracza, jedzie chwilę i zapisuje zrzuty ekranu.

Użycie: python tests/smoke_render.py [folder_na_zrzuty]
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from panda3d.core import Filename  # noqa: E402

from tir.main import TirApp  # noqa: E402

out = sys.argv[1] if len(sys.argv) > 1 else "screenshots"
os.makedirs(out, exist_ok=True)
app = TirApp()


def frames(n, controls=frozenset()):
    app.forced_controls = set(controls)
    for _ in range(n):
        app.taskMgr.step()


def shot(name):
    path = os.path.join(out, name)
    app.win.save_screenshot(Filename.from_os_specific(path))
    print("zapisano", path)


frames(30)
shot("1_start_w_miescie.png")          # plac w Warszawie + tablica zleceń
app.game.accept_offer(0)
frames(5)
frames(240, {"up"})                    # prosto drogą na wschód
shot("2_jazda_kamera_za.png")
app.cycle_camera()
frames(90, {"up"})
shot("3_kamera_wyzej.png")
app.cycle_camera()
frames(90, {"up"})
shot("4_kamera_z_gory.png")
print("pozycja", [round(v) for v in app.game.pos], "km/h", app.game.kmh, "komunikat:", app.game.message)

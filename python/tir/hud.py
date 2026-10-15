"""Nakładka 2D: statystyki, tablica zleceń, komunikaty, strzałka do celu i minimapa."""
import math
import os

from direct.gui.DirectGui import DirectFrame
from direct.gui.OnscreenText import OnscreenText
from panda3d.core import Filename, LineSegs, TextNode

from . import world as W
from .mesh import MeshBuilder

ASSETS = os.path.join(os.path.dirname(__file__), "assets")
WHITE = (1, 1, 1, 1)
WARN = (1, 0.45, 0.35, 1)
YELLOW = (1, 0.85, 0.2, 1)
MINIMAP = 0.5   # bok minimapy w jednostkach ekranu


def fmt_time(t):
    s = int(abs(t))
    return f"{'-' if t < 0 else ''}{s // 60}:{s % 60:02d}"


class HUD:
    def __init__(self, base):
        self.base = base
        load = base.loader.load_font
        self.font = load(Filename.from_os_specific(os.path.join(ASSETS, "DejaVuSans.ttf")).get_fullpath())
        self.font_bold = load(Filename.from_os_specific(os.path.join(ASSETS, "DejaVuSans-Bold.ttf")).get_fullpath())

        tl = base.a2dTopLeft
        DirectFrame(parent=tl, frameColor=(0, 0, 0, 0.55), frameSize=(0.03, 0.95, -0.56, -0.03))
        self.stats = [self._text(tl, (0.07, -0.1 - i * 0.065), 0.045 if i else 0.055, bold=(i == 0))
                      for i in range(7)]

        self.board = DirectFrame(parent=tl, frameColor=(0.05, 0.1, 0.25, 0.88),
                                 frameSize=(0.03, 1.75, -0.98, -0.6))
        self.board_lines = [self._text(self.board, (0.07, -0.67 - i * 0.07), 0.05 if i == 0 else 0.042,
                                       bold=(i == 0)) for i in range(5)]
        self.board.hide()

        self.message = OnscreenText(parent=base.a2dBottomCenter, pos=(0, 0.2), scale=0.055,
                                    fg=YELLOW, shadow=(0, 0, 0, 1), font=self.font_bold, mayChange=True)
        OnscreenText(parent=base.a2dBottomCenter, pos=(0, 0.06), scale=0.036, fg=(1, 1, 1, 0.9),
                     shadow=(0, 0, 0, 1), font=self.font,
                     text="Strzałki/WASD – jazda · Spacja – ręczny · 1–3 – zlecenie · E – rozładuj · "
                          "F – tankuj · H – pomoc drogowa · C – kamera · Esc – wyjście")

        # Strzałka do celu ("w górę" = kierunek jazdy)
        m = MeshBuilder("strzalka")
        m.tri((0, 0, 0.07), (-0.04, 0, -0.04), (0, 0, -0.015), (0, -1, 0), YELLOW)
        m.tri((0, 0, 0.07), (0, 0, -0.015), (0.04, 0, -0.04), (0, -1, 0), YELLOW)
        self.arrow = m.node()
        self.arrow.reparent_to(base.a2dTopCenter)
        self.arrow.set_pos(0, 0, -0.12)
        self.target_text = OnscreenText(parent=base.a2dTopCenter, pos=(0, -0.24), scale=0.045,
                                        fg=WHITE, shadow=(0, 0, 0, 1), font=self.font_bold, mayChange=True)

        self._minimap(base.a2dTopRight)

    def _text(self, parent, pos, scale, bold=False):
        return OnscreenText(parent=parent, pos=pos, scale=scale, fg=WHITE, align=TextNode.A_left,
                            font=self.font_bold if bold else self.font, mayChange=True)

    def _minimap(self, parent):
        self.minimap = parent.attach_new_node("minimapa")
        self.minimap.set_pos(-MINIMAP - 0.04, 0, -MINIMAP - 0.04)
        DirectFrame(parent=self.minimap, frameColor=(0.15, 0.3, 0.12, 0.85),
                    frameSize=(0, MINIMAP, 0, MINIMAP))
        s = MINIMAP / W.SIZE
        ls = LineSegs()
        ls.set_thickness(2)
        ls.set_color(0.85, 0.85, 0.85, 1)
        for a, b in W.ROADS:
            ls.move_to(a[0] * s, 0, a[1] * s)
            ls.draw_to(b[0] * s, 0, b[1] * s)
        self.minimap.attach_new_node(ls.create())

        m = MeshBuilder("punkty")
        for st in W.STATIONS:
            self._square(m, st[0] * s, st[1] * s, 0.006, (1, 0.55, 0, 1))
        for c in W.CITIES:
            self._square(m, c.pos[0] * s, c.pos[1] * s, 0.01, YELLOW)
        m.node().reparent_to(self.minimap)

        t = MeshBuilder("marker")
        t.tri((0.018, 0, 0), (-0.012, 0, 0.012), (-0.012, 0, -0.012), (0, -1, 0), (1, 0.1, 0.1, 1))
        self.mm_truck = t.node()
        self.mm_truck.reparent_to(self.minimap)

        ring = LineSegs()
        ring.set_thickness(2)
        ring.set_color(0, 1, 1, 1)
        for i in range(17):
            a = 2 * math.pi * i / 16
            (ring.draw_to if i else ring.move_to)(math.cos(a) * 0.02, 0, math.sin(a) * 0.02)
        self.mm_target = self.minimap.attach_new_node(ring.create())

    @staticmethod
    def _square(m, x, z, r, color):
        m.quad((x - r, 0, z - r), (x + r, 0, z - r), (x + r, 0, z + r), (x - r, 0, z + r), (0, -1, 0), color)

    def update(self, g):
        st = self.stats
        st[0].setText(f"{g.money} zł")
        st[1].setText(f"Prędkość: {g.kmh} km/h" + ("" if g.on_road else "  (bezdroża)"))
        st[2].setText(f"Paliwo: {int(g.fuel)} / {int(g.tank)} l")
        st[2].setFg(WARN if g.fuel < 60 else WHITE)
        if g.job:
            st[3].setText(f"Ładunek: {g.job.cargo.name}, {g.job.tonnes} t")
            st[4].setText(f"Cel: {W.CITIES[g.job.dst].name} – zapłata {g.job.pay} zł")
            st[5].setText(f"Czas: {fmt_time(g.job_time_left)}   Uszkodzenia: {int(g.cargo_damage)}%")
            st[5].setFg(WARN if g.job_time_left < 0 else WHITE)
        else:
            st[3].setText("Ładunek: brak")
            st[4].setText("Jedź do miasta po zlecenie")
            st[5].setText("")
        st[6].setText(f"Dostawy: {g.deliveries}   Przebieg: {int(g.total_km)} km")

        if g.shows_offer_board:
            self.board.show()
            self.board_lines[0].setText(f"Zlecenia – {W.CITIES[g.offers_city].name}")
            for i, job in enumerate(g.offers[:3]):
                self.board_lines[i + 1].setText(
                    f"[{i + 1}] {job.cargo.name}, {job.tonnes} t → {W.CITIES[job.dst].name}   "
                    f"{job.km} km   {job.pay} zł   czas {fmt_time(job.time_limit)}")
            self.board_lines[4].setText("Zatrzymaj się i wciśnij 1, 2 lub 3")
        else:
            self.board.hide()

        (tx, ty), name = g.target
        dx, dy = tx - g.pos[0], ty - g.pos[1]
        rel = math.atan2(dy, dx) - g.heading            # 0 = na wprost, dodatnie = w lewo
        self.arrow.set_r(-math.degrees(rel))
        self.target_text.setText(f"{name} – {int(math.hypot(dx, dy) / W.PX_PER_KM)} km")

        s = MINIMAP / W.SIZE
        self.mm_truck.set_pos(g.pos[0] * s, 0, g.pos[1] * s)
        self.mm_truck.set_r(-math.degrees(g.heading))
        self.mm_target.set_pos(tx * s, 0, ty * s)

        self.message.setText(g.message if g.message_timer > 0 else "")
        self.message.setFg(YELLOW[:3] + (max(0.0, min(1.0, g.message_timer)),))

"""Świat 3D: teren, drogi, miasta, stacje, drzewa, ciężarówka i kamera."""
import math
import os

from panda3d.core import (AmbientLight, DirectionalLight, Filename, Fog,
                          NodePath, TextNode, Vec3, Point3)

from . import world as W
from .mesh import MeshBuilder

K = 0.05   # 1 piksel mapy = 0.05 jednostki 3D
ASSETS = os.path.join(os.path.dirname(__file__), "assets")

YELLOW = (1, 0.85, 0.2, 1)
ASPHALT = (0.24, 0.24, 0.24, 1)
SHOULDER = (0.62, 0.58, 0.48, 1)
GRASS = (0.33, 0.58, 0.27, 1)
SKY = (0.58, 0.76, 0.95, 1)


def p3(p, z=0.0):
    return (p[0] * K, p[1] * K, z)


class Scene3D:
    def __init__(self, base):
        self.base = base
        self.root = base.render.attach_new_node("world")
        self.font_bold = base.loader.load_font(Filename.from_os_specific(os.path.join(ASSETS, "DejaVuSans-Bold.ttf")).get_fullpath())
        self.camera_mode = 0     # 0 = za ciężarówką, 1 = wyżej, 2 = z góry
        self._camera_ready = False
        self._wheel_spin = 0.0
        self._last_cargo_version = -1

        self._environment()
        static = MeshBuilder("static")
        self._ground(static)
        self._roads(static)
        self._cities(static)
        self._stations(static)
        self._trees(static)
        static.node().reparent_to(self.root)
        self._truck()

    # ---------- otoczenie ----------
    def _environment(self):
        base = self.base
        base.set_background_color(*SKY)
        fog = Fog("mgla")
        fog.set_color(*SKY[:3])
        fog.set_linear_range(160, 420)
        base.render.set_fog(fog)

        lens = base.cam.node().get_lens()
        lens.set_fov(60)
        lens.set_near_far(0.5, 600)

        sun = DirectionalLight("slonce")
        sun.set_color((0.95, 0.92, 0.85, 1))
        sun_np = base.render.attach_new_node(sun)
        sun_np.set_hpr(40, -55, 0)
        base.render.set_light(sun_np)

        amb = AmbientLight("otoczenie")
        amb.set_color((0.45, 0.48, 0.55, 1))
        base.render.set_light(base.render.attach_new_node(amb))

    def _ground(self, m):
        # Teren dzielony na kafle, bo mgła liczona jest w wierzchołkach
        tile = 25.0
        lo, hi = -200.0, W.SIZE * K + 200.0
        n = int((hi - lo) / tile)
        for i in range(n):
            for j in range(n):
                x0, y0 = lo + i * tile, lo + j * tile
                m.quad((x0, y0, 0), (x0 + tile, y0, 0), (x0 + tile, y0 + tile, 0), (x0, y0 + tile, 0),
                       (0, 0, 1), GRASS)

    def _roads(self, m):
        road_w = W.ROAD_WIDTH * K
        junctions = set()
        for a, b in W.ROADS:
            pa, pb = p3(a), p3(b)
            dx, dy = pb[0] - pa[0], pb[1] - pa[1]
            length = math.hypot(dx, dy)
            h = math.atan2(dy, dx)
            ux, uy = dx / length, dy / length
            # Droga w kawałkach po ok. 20 jednostek (mgła w wierzchołkach)
            pieces = max(1, int(length / 20))
            piece = length / pieces
            for k in range(pieces):
                cx = pa[0] + ux * piece * (k + 0.5)
                cy = pa[1] + uy * piece * (k + 0.5)
                m.box((cx, cy, 0), (piece, road_w + 1.2, 0.06), SHOULDER, h)
                m.box((cx, cy, 0), (piece, road_w, 0.1), ASPHALT, h)
            t = road_w
            while t < length - road_w:
                m.box((pa[0] + ux * t, pa[1] + uy * t, 0.1), (2.0, 0.2, 0.02), (0.95, 0.95, 0.95, 1), h)
                t += 4
            junctions.add(a)
            junctions.add(b)
        for j in junctions:
            m.cylinder(p3(j), road_w / 2, 0.1, ASPHALT, segments=20)

    def _label(self, text, pos, scale, color):
        tn = TextNode("napis")
        tn.set_text(text)
        tn.set_font(self.font_bold)
        tn.set_align(TextNode.A_center)
        tn.set_text_color(*color)
        tn.set_shadow(0.05, 0.05)
        tn.set_shadow_color(0, 0, 0, 0.8)
        np = self.root.attach_new_node(tn)
        np.set_pos(*pos)
        np.set_scale(scale)
        np.set_billboard_point_eye()
        np.set_light_off()
        np.set_fog_off()
        return np

    def _cities(self, m):
        for c in W.CITIES:
            r = W.CITY_RADIUS * K
            m.cylinder(p3(c.pos), r + 0.5, 0.13, YELLOW, segments=32)
            m.cylinder(p3(c.pos), r, 0.14, (0.45, 0.45, 0.5, 1), segments=32)
            self._label(c.name.upper(), p3(c.pos, 16), 4.5, YELLOW)
        for b in W.BUILDINGS:
            w, l = b.w * K, b.l * K
            m.box(p3(b.pos), (w, l, b.h), b.color, b.angle)
            if b.warehouse:
                m.box(p3(b.pos, b.h), (w + 0.2, l + 0.2, 0.3), (0.3, 0.3, 0.3, 1), b.angle)
            else:
                # Ciemniejsza nadbudówka na dachu
                m.box(p3(b.pos, b.h), (w * 0.6, l * 0.6, 0.6), tuple(x * 0.7 for x in b.color[:3]) + (1,), b.angle)

    def _stations(self, m):
        orange = (0.9, 0.45, 0.1, 1)
        for s in W.STATIONS:
            m.cylinder(p3(s), W.STATION_RADIUS * K, 0.14, (0.55, 0.55, 0.55, 1), segments=24)
            # Wiata odsunięta od osi drogi
            cx, cy = s[0] * K + 3, s[1] * K + 3
            m.box((cx, cy, 4.7), (9, 7, 0.6), orange)
            for dx, dy in ((-3.5, -2.5), (3.5, -2.5), (-3.5, 2.5), (3.5, 2.5)):
                m.box((cx + dx, cy + dy, 0), (0.3, 0.3, 4.7), (0.9, 0.9, 0.9, 1))
            for dy in (-1.2, 1.2):
                m.box((cx, cy + dy, 0), (0.6, 0.9, 1.4), (0.85, 0.15, 0.15, 1))
            self._label("STACJA", p3(s, 8), 2.2, orange)

    def _trees(self, m):
        trunk = (0.4, 0.26, 0.13, 1)
        leaves = [(0.13, g, 0.14, 1) for g in (0.32, 0.38, 0.44)]
        for t in W.TREES:
            s = t.scale
            m.cylinder(p3(t.pos), 0.3 * s, 1.6 * s, trunk, segments=6)
            m.cylinder(p3(t.pos, 1.4 * s), 1.8 * s, 5 * s, leaves[t.shade], segments=8, top_radius=0)

    # ---------- ciężarówka (przód w stronę +X) ----------
    def _wheel(self, parent, x, y):
        m = MeshBuilder("kolo")
        m.cylinder((0, 0, -0.22), 0.5, 0.45, (0.08, 0.08, 0.08, 1), segments=14)
        m.box((0, 0, -0.235), (0.5, 0.12, 0.47), (0.7, 0.7, 0.7, 1))   # felga, widać obrót
        spinner = parent.attach_new_node("os")
        spinner.set_pos(x, y, 0.5)
        wheel = m.node()
        wheel.reparent_to(spinner)
        wheel.set_p(90)          # oś walca wzdłuż Y
        self.wheels.append(spinner)

    def _truck(self):
        self.wheels = []
        red = (0.82, 0.08, 0.1, 1)
        self.cab = self.root.attach_new_node("kabina")
        m = MeshBuilder("kabina")
        m.box((-0.1, 0, 0.4), (2.6, 1.5, 0.3), (0.15, 0.15, 0.15, 1))             # rama
        m.box((0.5, 0, 0.7), (1.5, 1.85, 2.3), red)                                # kabina
        m.box((1.26, 0, 1.9), (0.08, 1.6, 0.9), (0.55, 0.8, 0.95, 1))             # szyba
        m.box((1.26, 0, 0.85), (0.08, 1.4, 0.7), (0.2, 0.2, 0.2, 1))              # grill
        for y in (-0.7, 0.7):
            m.box((1.29, y, 0.85), (0.08, 0.3, 0.2), (1, 1, 0.8, 1))               # światła
        m.box((-1.0, 0, 0.7), (0.8, 1.0, 0.15), (0.3, 0.3, 0.3, 1))               # siodło
        m.node().reparent_to(self.cab)
        for x, y in ((0.7, 0.85), (0.7, -0.85), (-0.9, 0.85), (-0.9, -0.85)):
            self._wheel(self.cab, x, y)

        self.trailer = self.root.attach_new_node("naczepa")
        tb = MeshBuilder("skrzynia")
        tb.box((-0.15, 0, 0.9), (6.0, 1.95, 2.7), (1, 1, 1, 1))
        self.trailer_body = tb.node()
        self.trailer_body.reparent_to(self.trailer)
        fr = MeshBuilder("rama")
        fr.box((-0.15, 0, 0.68), (6.0, 1.4, 0.25), (0.15, 0.15, 0.15, 1))
        fr.node().reparent_to(self.trailer)
        for x in (-2.5, -1.8, -1.1):
            for y in (0.85, -0.85):
                self._wheel(self.trailer, x, y)

    # ---------- co klatkę ----------
    def sync(self, game, dt):
        self.cab.set_pos(*p3(game.pos))
        self.cab.set_h(math.degrees(game.heading))
        self.trailer.set_pos(*p3(game.trailer_pos))
        self.trailer.set_h(math.degrees(game.trailer_angle))

        self._wheel_spin += math.degrees(game.speed * K / 0.5 * dt)
        for w in self.wheels:
            w.set_r(self._wheel_spin)

        if game.cargo_version != self._last_cargo_version:
            self._last_cargo_version = game.cargo_version
            color = game.job.cargo.color if game.job else (0.75, 0.75, 0.75, 1)
            self.trailer_body.set_color(*color)

        self._update_camera(game, dt)

    def _update_camera(self, game, dt):
        cam = self.base.camera
        p = Vec3(*p3(game.pos))
        fwd = Vec3(math.cos(game.heading), math.sin(game.heading), 0)
        if self.camera_mode == 1:
            desired = p - fwd * 28 + Vec3(0, 0, 22)
        elif self.camera_mode == 2:
            desired = p - fwd * 12 + Vec3(0, 0, 65)
        else:
            desired = p - fwd * 21 + Vec3(0, 0, 8.5)
        if not self._camera_ready:
            cam.set_pos(desired)
            self._camera_ready = True
        else:
            t = min(1.0, 3.5 * dt)
            cam.set_pos(cam.get_pos() + (desired - cam.get_pos()) * t)
        cam.look_at(Point3(p + fwd * 8 + Vec3(0, 0, 2.0)))

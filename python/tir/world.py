"""Mapa gry: miasta, stacje, drogi i rodzaje towarów.

Współrzędne mapy są w "pikselach" (0..8000). 20 px = 1 km.
"""
import math
from dataclasses import dataclass

SIZE = 8000.0
SPACING = 1750.0
MARGIN = 500.0
ROAD_WIDTH = 130.0
CITY_RADIUS = 180.0
STATION_RADIUS = 120.0
PX_PER_KM = 20.0


def grid(x, y):
    return (MARGIN + x * SPACING, MARGIN + y * SPACING)


@dataclass(frozen=True)
class City:
    name: str
    pos: tuple


@dataclass(frozen=True)
class Cargo:
    name: str
    rate: float          # zł za km
    tonnage: tuple       # (min, max) ton
    color: tuple         # RGBA


CARGO_TYPES = [
    Cargo("Elektronika", 9.0, (4, 10), (0.25, 0.45, 0.85, 1)),
    Cargo("Żywność", 6.0, (8, 20), (0.95, 0.95, 0.95, 1)),
    Cargo("Drewno", 4.5, (15, 24), (0.55, 0.35, 0.18, 1)),
    Cargo("Stal", 5.5, (18, 25), (0.55, 0.58, 0.62, 1)),
    Cargo("Meble", 6.5, (5, 12), (0.85, 0.6, 0.2, 1)),
    Cargo("Chemikalia", 10.0, (10, 22), (0.95, 0.8, 0.1, 1)),
    Cargo("Samochody", 8.0, (8, 14), (0.8, 0.2, 0.2, 1)),
]


@dataclass(frozen=True)
class Job:
    cargo: Cargo
    src: int
    dst: int
    tonnes: int
    km: int
    pay: int
    time_limit: float


CITIES = [
    City("Szczecin", grid(0, 4)),
    City("Gdańsk", grid(2, 4)),
    City("Białystok", grid(4, 4)),
    City("Poznań", grid(1, 3)),
    City("Warszawa", grid(3, 3)),
    City("Łódź", grid(2, 2)),
    City("Wrocław", grid(0, 1)),
    City("Lublin", grid(4, 1)),
    City("Katowice", grid(1, 0)),
    City("Kraków", grid(3, 0)),
]

STATIONS = [
    grid(1, 4), grid(3, 4), grid(0, 2), grid(4, 2),
    grid(2, 3), grid(1, 1), grid(3, 1), grid(2, 0),
]


def _build_roads():
    roads = []
    for i in range(5):
        for j in range(5):
            if i < 4:
                roads.append((grid(i, j), grid(i + 1, j)))
            if j < 4:
                roads.append((grid(i, j), grid(i, j + 1)))
    roads.append((grid(2, 2), grid(3, 3)))   # Łódź - Warszawa
    roads.append((grid(1, 0), grid(2, 2)))   # Katowice - Łódź
    roads.append((grid(2, 2), grid(1, 3)))   # Łódź - Poznań
    roads.append((grid(3, 3), grid(4, 1)))   # Warszawa - Lublin
    return roads


ROADS = _build_roads()


def distance(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def distance_to_segment(p, a, b):
    abx, aby = b[0] - a[0], b[1] - a[1]
    len2 = abx * abx + aby * aby
    if len2 == 0:
        return distance(p, a)
    t = ((p[0] - a[0]) * abx + (p[1] - a[1]) * aby) / len2
    t = max(0.0, min(1.0, t))
    return distance(p, (a[0] + t * abx, a[1] + t * aby))


def city_index(p):
    for i, c in enumerate(CITIES):
        if distance(c.pos, p) < CITY_RADIUS:
            return i
    return None


def station_index(p):
    for i, s in enumerate(STATIONS):
        if distance(s, p) < STATION_RADIUS:
            return i
    return None


def is_on_road(p):
    if city_index(p) is not None or station_index(p) is not None:
        return True
    return any(distance_to_segment(p, a, b) < ROAD_WIDTH / 2 + 8 for a, b in ROADS)


def nearest_station(p):
    return min(STATIONS, key=lambda s: distance(s, p))


def nearest_city(p):
    return min(range(len(CITIES)), key=lambda i: distance(CITIES[i].pos, p))


def road_distance(a, b):
    """Przybliżona długość trasy po drogach (metryka miejska)."""
    pa, pb = CITIES[a].pos, CITIES[b].pos
    return abs(pa[0] - pb[0]) + abs(pa[1] - pb[1])


# ---------- Rozmieszczenie budynków i drzew (wspólne dla grafiki i kolizji) ----------

@dataclass(frozen=True)
class Building:
    pos: tuple        # środek, piksele mapy
    w: float          # wymiary w pikselach mapy
    l: float
    h: float          # wysokość w jednostkach 3D
    angle: float      # obrót w radianach
    color: tuple
    warehouse: bool = False


@dataclass(frozen=True)
class Tree:
    pos: tuple
    scale: float
    shade: int


def is_free(p, r):
    """Czy w punkcie p (piksele) można postawić obiekt o promieniu r (piksele)."""
    if p[0] < 40 or p[1] < 40 or p[0] > SIZE - 40 or p[1] > SIZE - 40:
        return False
    if any(distance_to_segment(p, a, b) < ROAD_WIDTH / 2 + 30 + r for a, b in ROADS):
        return False
    if any(distance(c.pos, p) < CITY_RADIUS + 20 + r for c in CITIES):
        return False
    if any(distance(s, p) < STATION_RADIUS + 20 + r for s in STATIONS):
        return False
    return True


_PALETTE = [(0.85, 0.82, 0.75, 1), (0.7, 0.72, 0.78, 1), (0.75, 0.45, 0.35, 1),
            (0.55, 0.6, 0.68, 1), (0.9, 0.88, 0.85, 1)]


def _generate(seed=7):
    import random
    rng = random.Random(seed)
    buildings, trees = [], []
    for c in CITIES:
        # Magazyny na skosach, między drogami
        for k in range(4):
            ang = k * math.pi / 2 + math.pi / 4
            p = (c.pos[0] + math.cos(ang) * (CITY_RADIUS + 70),
                 c.pos[1] + math.sin(ang) * (CITY_RADIUS + 70))
            if any(distance_to_segment(p, a, b) < ROAD_WIDTH / 2 + 60 for a, b in ROADS):
                continue
            buildings.append(Building(p, 120, 80, 3.5, ang, (0.72, 0.32, 0.25, 1), warehouse=True))
        # Zabudowa miasta
        placed = tries = 0
        while placed < 28 and tries < 400:
            tries += 1
            ang = rng.uniform(0, 2 * math.pi)
            dist = rng.uniform(CITY_RADIUS + 120, CITY_RADIUS + 650)
            p = (c.pos[0] + math.cos(ang) * dist, c.pos[1] + math.sin(ang) * dist)
            w, l = rng.uniform(60, 140), rng.uniform(60, 140)
            if not is_free(p, max(w, l) / 2):
                continue
            h = rng.uniform(4, 22 if dist < CITY_RADIUS + 350 else 10)
            buildings.append(Building(p, w, l, h, 0.0, rng.choice(_PALETTE)))
            placed += 1
    placed = tries = 0
    while placed < 700 and tries < 6000:
        tries += 1
        p = (rng.uniform(60, SIZE - 60), rng.uniform(60, SIZE - 60))
        if not is_free(p, 30):
            continue
        if any(distance(c.pos, p) < CITY_RADIUS + 600 for c in CITIES):
            continue
        trees.append(Tree(p, rng.uniform(0.8, 1.5), rng.randrange(3)))
        placed += 1
    return buildings, trees


BUILDINGS, TREES = _generate()


def _obstacles():
    """Przeszkody jako koła (x, y, promień) w pikselach, pogrupowane w siatkę 500 px."""
    cells = {}
    items = [(b.pos[0], b.pos[1], max(b.w, b.l) / 2) for b in BUILDINGS]
    items += [(t.pos[0], t.pos[1], 10 * t.scale) for t in TREES]
    for x, y, r in items:
        cells.setdefault((int(x // 500), int(y // 500)), []).append((x, y, r))
    return cells


_OBSTACLE_CELLS = _obstacles()


def hit_obstacle(p, radius):
    """Zwraca przeszkodę, w którą wjeżdża koło o środku p i promieniu radius, albo None."""
    cx, cy = int(p[0] // 500), int(p[1] // 500)
    for i in (cx - 1, cx, cx + 1):
        for j in (cy - 1, cy, cy + 1):
            for ob in _OBSTACLE_CELLS.get((i, j), ()):
                if math.hypot(p[0] - ob[0], p[1] - ob[1]) < ob[2] + radius:
                    return ob
    return None

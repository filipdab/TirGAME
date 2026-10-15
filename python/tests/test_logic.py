"""Test logiki bez grafiki: python -m unittest discover tests"""
import math
import random
import unittest

from tir import world as W
from tir.game import Game

DT = 1 / 60


def drive_to(g, target, max_steps=20000):
    """Prosty autopilot: jedzie po drogach siatki (najpierw X, potem Y) i staje na celu."""
    for _ in range(max_steps):
        x, y = g.pos
        tx, ty = target
        if W.distance(g.pos, target) < 40:
            for _ in range(300):
                g.step(DT, {"brake"})
            return True
        # cel pośredni: punkt 300 px przed nami na najbliższej linii siatki (drodze)
        gx = W.MARGIN + round((x - W.MARGIN) / W.SPACING) * W.SPACING
        gy = W.MARGIN + round((y - W.MARGIN) / W.SPACING) * W.SPACING
        if abs(x - tx) > 30:
            way = (x + math.copysign(min(300, abs(tx - x)), tx - x), gy)
        else:
            way = (gx, y + math.copysign(min(300, abs(ty - y)), ty - y))
        want = math.atan2(way[1] - y, way[0] - x)
        diff = math.atan2(math.sin(want - g.heading), math.cos(want - g.heading))
        target_speed = 90 if abs(diff) > 0.3 else 350
        controls = {"up"} if g.speed < target_speed else {"down"}
        if diff > 0.03:
            controls.add("left")
        elif diff < -0.03:
            controls.add("right")
        g.step(DT, controls)
    return False


class LogicTest(unittest.TestCase):
    def test_start_in_city_with_offers(self):
        g = Game(random.Random(1))
        g.step(DT, set())
        self.assertEqual(g.offers_city, 4)
        self.assertEqual(len(g.offers), 3)

    def test_full_delivery_earns_money(self):
        g = Game(random.Random(2))
        g.step(DT, set())
        # wybierz zlecenie do Łodzi lub najbliższe
        idx = min(range(3), key=lambda i: W.road_distance(4, g.offers[i].dst))
        job = g.offers[idx]
        g.accept_offer(idx)
        self.assertIs(g.job, job)
        money_before = g.money
        # ustaw ciężarówkę przodem do pierwszego odcinka trasy (autopilot nie umie zawracać)
        sx, sy = W.CITIES[job.src].pos
        tx, ty = W.CITIES[job.dst].pos
        g.heading = g.trailer_angle = math.atan2(0, tx - sx) if abs(tx - sx) > 30 else math.atan2(ty - sy, 0)
        self.assertTrue(drive_to(g, W.CITIES[job.dst].pos), "autopilot nie dojechał")
        self.assertEqual(W.city_index(g.pos), job.dst)
        g.unload()
        self.assertIsNone(g.job)
        self.assertGreater(g.money, money_before)
        self.assertEqual(g.deliveries, 1)
        self.assertLess(g.fuel, 350)

    def test_offroad_is_slower(self):
        g = Game(random.Random(3))
        g.pos = (W.MARGIN + W.SPACING / 2, W.MARGIN + W.SPACING / 2)   # środek pola, z dala od dróg
        for _ in range(600):
            g.step(DT, {"up"})
        self.assertFalse(g.on_road)
        self.assertLessEqual(g.speed, 151)

    def test_collision_stops_truck(self):
        g = Game(random.Random(5))
        b = next(b for b in W.BUILDINGS if not b.warehouse)
        g.pos = (b.pos[0] - max(b.w, b.l) / 2 - 150, b.pos[1])
        g.heading = g.trailer_angle = 0.0
        for _ in range(400):
            g.step(DT, {"up"})
        self.assertLess(g.pos[0], b.pos[0] - max(b.w, b.l) / 2)

    def test_refuel_and_tow(self):
        g = Game(random.Random(4))
        g.fuel = 0
        g.step(DT, set())
        g.call_tow()
        self.assertIsNotNone(W.station_index(g.pos))
        self.assertEqual(g.fuel, 60)
        g.money = 10000
        g.refuel()
        self.assertAlmostEqual(g.fuel, g.tank)


if __name__ == "__main__":
    unittest.main()

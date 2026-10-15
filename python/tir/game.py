"""Logika gry, niezależna od grafiki."""
import math
import random

from . import world as W

STATION_FUEL_PRICE = 5.5
CITY_FUEL_PRICE = 7.0
TOW_COST = 800
CAB_HITCH = 22.0      # odległość zaczepu od środka kabiny
TRAILER_HALF = 58.0   # odległość środka naczepy od zaczepu


def _approach(v, target, step):
    return min(v + step, target) if v < target else max(v - step, target)


class Game:
    def __init__(self, rng=None):
        self.rng = rng or random.Random()
        self.pos = W.CITIES[4].pos            # start: Warszawa
        self.heading = 0.0                     # radiany, 0 = wschód, przeciwnie do wskazówek zegara
        self.speed = 0.0                       # px/s, 400 ≈ 90 km/h
        self.trailer_angle = 0.0
        self.on_road = True

        self.money = 3000
        self.fuel = 350.0
        self.tank = 500.0
        self.job = None
        self.job_time_left = 0.0
        self.cargo_damage = 0.0
        self.offers = []
        self.offers_city = None
        self.deliveries = 0
        self.total_km = 0.0

        self.message = "Witaj w firmie transportowej! Wybierz zlecenie klawiszami 1–3."
        self.message_timer = 8.0
        self.cargo_version = 0   # rośnie przy załadunku/rozładunku

    # ---- właściwości pomocnicze ----
    @property
    def is_stopped(self):
        return abs(self.speed) < 15

    @property
    def kmh(self):
        return int(abs(self.speed) * 0.225)

    @property
    def trailer_pos(self):
        hx = self.pos[0] - math.cos(self.heading) * CAB_HITCH
        hy = self.pos[1] - math.sin(self.heading) * CAB_HITCH
        return (hx - math.cos(self.trailer_angle) * TRAILER_HALF,
                hy - math.sin(self.trailer_angle) * TRAILER_HALF)

    @property
    def shows_offer_board(self):
        return self.job is None and self.offers_city is not None

    @property
    def target(self):
        """Cel strzałki: miejsce dostawy, stacja przy małej ilości paliwa albo najbliższe miasto."""
        if self.job is not None:
            c = W.CITIES[self.job.dst]
            return c.pos, c.name
        if self.fuel < 80:
            return W.nearest_station(self.pos), "Stacja paliw"
        c = W.CITIES[W.nearest_city(self.pos)]
        return c.pos, c.name

    def show(self, text, seconds=4.0):
        self.message = text
        self.message_timer = seconds

    # ---- akcje gracza ----
    def accept_offer(self, i):
        if self.job is not None:
            return self.show("Masz już ładunek – najpierw go dowieź.")
        c = self.offers_city
        if c is None or W.city_index(self.pos) != c or i >= len(self.offers):
            return self.show("Zlecenia bierzesz na placu w mieście.")
        if not self.is_stopped:
            return self.show("Zatrzymaj się, aby załadować towar.")
        job = self.offers[i]
        self.job = job
        self.job_time_left = job.time_limit
        self.cargo_damage = 0.0
        self.cargo_version += 1
        self.show(f"Załadowano {job.cargo.name} ({job.tonnes} t). Cel: {W.CITIES[job.dst].name}!")

    def unload(self):
        job = self.job
        if job is None:
            return self.show("Nie wieziesz ładunku. Weź zlecenie w mieście (1–3).")
        if W.city_index(self.pos) != job.dst:
            return self.show(f"To nie tu! Ładunek jedzie do: {W.CITIES[job.dst].name}.")
        if not self.is_stopped:
            return self.show("Zatrzymaj się, aby rozładować.")
        pay = float(job.pay)
        notes = []
        if self.job_time_left < 0:
            pay *= 0.5
            notes.append("spóźnienie −50%")
        if self.cargo_damage >= 1:
            pay *= 1 - self.cargo_damage / 100
            notes.append(f"uszkodzenia −{int(self.cargo_damage)}%")
        earned = int(pay)
        self.money += earned
        self.deliveries += 1
        self.job = None
        self.cargo_damage = 0.0
        self.offers_city = None   # nowe zlecenia w tym mieście
        self.cargo_version += 1
        extra = " Na czas i bez szkód!" if not notes else " (" + ", ".join(notes) + ")"
        self.show(f"Dostarczono! +{earned} zł.{extra}", 6)

    def refuel(self):
        at_station = W.station_index(self.pos) is not None
        at_city = W.city_index(self.pos) is not None
        if not (at_station or at_city):
            return self.show("Tankować możesz na stacji lub w mieście (drożej).")
        if not self.is_stopped:
            return self.show("Zatrzymaj się, aby zatankować.")
        price = STATION_FUEL_PRICE if at_station else CITY_FUEL_PRICE
        missing = self.tank - self.fuel
        if missing < 1:
            return self.show("Bak jest pełny.")
        liters = min(missing, max(0, self.money) / price)
        if liters < 1:
            return self.show("Brak pieniędzy na paliwo!")
        cost = round(liters * price)
        self.fuel += liters
        self.money -= cost
        self.show(f"Zatankowano {int(liters)} l za {cost} zł ({price:.2f} zł/l).")

    def call_tow(self):
        if self.fuel >= 5:
            return self.show("Pomoc drogowa przyjedzie tylko, gdy skończy się paliwo.")
        self.pos = W.nearest_station(self.pos)
        self.speed = 0.0
        self.trailer_angle = self.heading
        self.fuel = 60.0
        self.money -= TOW_COST
        self.show(f"Pomoc drogowa odholowała Cię na stację (−{TOW_COST} zł, +60 l).", 6)

    def make_offers(self, c):
        dests = [i for i in range(len(W.CITIES)) if i != c]
        self.rng.shuffle(dests)
        offers = []
        for dst in dests[:3]:
            cargo = self.rng.choice(W.CARGO_TYPES)
            tonnes = self.rng.randint(*cargo.tonnage)
            road_px = W.road_distance(c, dst)
            km = road_px / W.PX_PER_KM
            pay = km * cargo.rate * (1 + tonnes / 40)
            offers.append(W.Job(cargo, c, dst, tonnes, int(km), int(pay), road_px / 260 + 25))
        return offers

    # ---- krok symulacji ----
    def step(self, dt, controls):
        """controls: zbiór z 'up', 'down', 'left', 'right', 'brake'."""
        self._drive(dt, controls)
        if self.job is not None:
            self.job_time_left -= dt
        city = W.city_index(self.pos)
        if city is not None and self.job is None:
            if self.offers_city != city:
                self.offers = self.make_offers(city)
                self.offers_city = city
        elif city is None:
            self.offers_city = None
        if self.message_timer > 0:
            self.message_timer -= dt

    def _drive(self, d, controls):
        up, down = "up" in controls, "down" in controls
        left, right = "left" in controls, "right" in controls

        self.on_road = W.is_on_road(self.pos)
        loaded = self.job is not None
        max_forward = 400.0 if self.on_road else 150.0
        accel = 115.0 if loaded else 170.0
        has_fuel = self.fuel > 0

        if up and has_fuel:
            self.speed += (500 if self.speed < 0 else accel) * d
        elif down and (has_fuel or self.speed > 0):
            self.speed -= (500 if self.speed > 0 else 100) * d
        else:
            self.speed = _approach(self.speed, 0, (70 if has_fuel else 150) * d)
        if "brake" in controls:
            self.speed = _approach(self.speed, 0, 900 * d)
        if self.speed > max_forward:
            self.speed = max(max_forward, self.speed - 350 * d)
        self.speed = max(self.speed, -120.0)

        # Skręt zależny od prędkości
        steer = (1 if left else 0) - (1 if right else 0)
        speed_factor = min(1.0, abs(self.speed) / 120)
        high_speed_damp = 1 - 0.45 * min(1.0, abs(self.speed) / 400)
        direction = 1 if self.speed >= 0 else -1
        self.heading += steer * 1.7 * speed_factor * high_speed_damp * direction * d

        old = self.pos
        x = old[0] + math.cos(self.heading) * self.speed * d
        y = old[1] + math.sin(self.heading) * self.speed * d
        lo, hi = 60.0, W.SIZE - 60.0
        if not (lo <= x <= hi and lo <= y <= hi):
            x, y = max(lo, min(hi, x)), max(lo, min(hi, y))
            self.speed *= 0.3
        # Kolizje z budynkami i drzewami (kabina i tył naczepy)
        back = (x - math.cos(self.trailer_angle) * (CAB_HITCH + 2 * TRAILER_HALF),
                y - math.sin(self.trailer_angle) * (CAB_HITCH + 2 * TRAILER_HALF))
        if W.hit_obstacle((x, y), 22) or (self.speed < 0 and W.hit_obstacle(back, 18)):
            if abs(self.speed) > 60:
                self.show("Bum! Uderzyłeś w przeszkodę.", 2)
                if loaded:
                    self.cargo_damage = min(100.0, self.cargo_damage + abs(self.speed) / 40)
            x, y = old
            self.speed = -self.speed * 0.25
        self.pos = (x, y)

        # Naczepa (model kinematyczny przyczepy)
        diff = math.atan2(math.sin(self.heading - self.trailer_angle), math.cos(self.heading - self.trailer_angle))
        self.trailer_angle += self.speed * d / 95 * math.sin(diff)
        diff = math.atan2(math.sin(self.heading - self.trailer_angle), math.cos(self.heading - self.trailer_angle))
        max_fold = 1.35
        if abs(diff) > max_fold:
            self.trailer_angle = self.heading - math.copysign(max_fold, diff)

        # Paliwo i przebieg
        km = W.distance(old, self.pos) / W.PX_PER_KM
        self.total_km += km
        if self.fuel > 0:
            self.fuel = max(0.0, self.fuel - km * 0.25 * (1.3 if loaded else 1.0))
            if self.fuel == 0:
                self.show("Skończyło się paliwo! Wciśnij H, aby wezwać pomoc drogową.", 8)

        # Uszkodzenia ładunku przy szybkiej jeździe po bezdrożach
        if loaded and not self.on_road and abs(self.speed) > 110:
            self.cargo_damage = min(100.0, self.cargo_damage + 6 * d)

import Foundation
import CoreGraphics

/// Kody klawiszy macOS
enum Key {
    static let left: UInt16 = 123, right: UInt16 = 124, down: UInt16 = 125, up: UInt16 = 126
    static let w: UInt16 = 13, a: UInt16 = 0, s: UInt16 = 1, d: UInt16 = 2
    static let space: UInt16 = 49, e: UInt16 = 14, f: UInt16 = 3, h: UInt16 = 4, c: UInt16 = 8
    static let one: UInt16 = 18, two: UInt16 = 19, three: UInt16 = 20
}

/// Cała logika gry w płaskich współrzędnych mapy (x, y w "pikselach" mapy).
/// Widok 3D tylko ją rysuje.
final class Game {
    // Pojazd
    private(set) var position: CGPoint = World.cities[4].position   // start: Warszawa
    private(set) var heading: CGFloat = 0
    private(set) var speedPx: CGFloat = 0
    private(set) var trailerAngle: CGFloat = 0
    private(set) var onRoad = true

    // Ekonomia i zlecenia
    private(set) var money = 3000
    private(set) var fuel: CGFloat = 350
    let tank: CGFloat = 500
    private(set) var activeJob: Job?
    private(set) var jobTimeLeft: TimeInterval = 0
    private(set) var cargoDamage: CGFloat = 0
    private(set) var offers: [Job] = []
    private(set) var offersCity: Int?
    private(set) var deliveries = 0
    private(set) var totalKm: CGFloat = 0

    // Komunikaty
    private(set) var message = "Witaj w firmie transportowej! Wybierz zlecenie klawiszami 1–3."
    private(set) var messageTimer: TimeInterval = 8

    /// Zmienia się przy załadunku/rozładunku, żeby widok mógł przemalować naczepę
    private(set) var cargoVersion = 0

    private let stationFuelPrice: CGFloat = 5.5
    private let cityFuelPrice: CGFloat = 7.0
    private let towCost = 800

    static let cabHitch: CGFloat = 22      // odległość zaczepu od środka kabiny
    static let trailerHalf: CGFloat = 58   // odległość środka naczepy od zaczepu

    var isStopped: Bool { abs(speedPx) < 15 }
    var kmh: Int { Int(abs(speedPx) * 0.225) }

    var trailerPosition: CGPoint {
        let hitch = CGPoint(x: position.x - cos(heading) * Game.cabHitch,
                            y: position.y - sin(heading) * Game.cabHitch)
        return CGPoint(x: hitch.x - cos(trailerAngle) * Game.trailerHalf,
                       y: hitch.y - sin(trailerAngle) * Game.trailerHalf)
    }

    /// Cel dla strzałki: miejsce dostawy, stacja przy małej ilości paliwa albo najbliższe miasto
    var target: (point: CGPoint, name: String) {
        if let job = activeJob {
            return (World.cities[job.to].position, World.cities[job.to].name)
        } else if fuel < 80 {
            return (World.nearestStation(to: position), "Stacja paliw")
        } else {
            let c = World.nearestCity(to: position)
            return (World.cities[c].position, World.cities[c].name)
        }
    }

    // MARK: Akcje gracza

    func handleKey(_ code: UInt16) {
        switch code {
        case Key.e: tryUnload()
        case Key.f: tryRefuel()
        case Key.h: callTow()
        case Key.one, Key.two, Key.three: acceptOffer(Int(code - Key.one))
        default: break
        }
    }

    private func show(_ text: String, seconds: TimeInterval = 4) {
        message = text
        messageTimer = seconds
    }

    private func acceptOffer(_ i: Int) {
        guard activeJob == nil else { show("Masz już ładunek – najpierw go dowieź."); return }
        guard let c = offersCity, World.cityIndex(near: position) == c, i < offers.count else {
            show("Zlecenia bierzesz na placu w mieście.")
            return
        }
        guard isStopped else { show("Zatrzymaj się, aby załadować towar."); return }
        let job = offers[i]
        activeJob = job
        jobTimeLeft = job.timeLimit
        cargoDamage = 0
        cargoVersion += 1
        show("Załadowano \(job.cargo.name) (\(job.tonnes) t). Cel: \(World.cities[job.to].name)!")
    }

    private func tryUnload() {
        guard let job = activeJob else { show("Nie wieziesz ładunku. Weź zlecenie w mieście (1–3)."); return }
        guard World.cityIndex(near: position) == job.to else {
            show("To nie tu! Ładunek jedzie do: \(World.cities[job.to].name).")
            return
        }
        guard isStopped else { show("Zatrzymaj się, aby rozładować."); return }

        var pay = CGFloat(job.pay)
        var notes: [String] = []
        if jobTimeLeft < 0 {
            pay *= 0.5
            notes.append("spóźnienie −50%")
        }
        if cargoDamage >= 1 {
            pay *= (1 - cargoDamage / 100)
            notes.append("uszkodzenia −\(Int(cargoDamage))%")
        }
        let earned = Int(pay)
        money += earned
        deliveries += 1
        activeJob = nil
        cargoDamage = 0
        offersCity = nil   // nowe zlecenia w tym mieście
        cargoVersion += 1
        let extra = notes.isEmpty ? " Na czas i bez szkód!" : " (" + notes.joined(separator: ", ") + ")"
        show("Dostarczono! +\(earned) zł.\(extra)", seconds: 6)
    }

    private func tryRefuel() {
        let atStation = World.stationIndex(near: position) != nil
        let atCity = World.cityIndex(near: position) != nil
        guard atStation || atCity else { show("Tankować możesz na stacji lub w mieście (drożej)."); return }
        guard isStopped else { show("Zatrzymaj się, aby zatankować."); return }
        let price = atStation ? stationFuelPrice : cityFuelPrice
        let missing = tank - fuel
        guard missing >= 1 else { show("Bak jest pełny."); return }
        let affordable = CGFloat(max(0, money)) / price
        let liters = min(missing, affordable)
        guard liters >= 1 else { show("Brak pieniędzy na paliwo!"); return }
        let cost = Int((liters * price).rounded())
        fuel += liters
        money -= cost
        show("Zatankowano \(Int(liters)) l za \(cost) zł (\(String(format: "%.2f", Double(price))) zł/l).")
    }

    private func callTow() {
        guard fuel < 5 else { show("Pomoc drogowa przyjedzie tylko, gdy skończy się paliwo."); return }
        position = World.nearestStation(to: position)
        speedPx = 0
        trailerAngle = heading
        fuel = 60
        money -= towCost
        show("Pomoc drogowa odholowała Cię na stację (−\(towCost) zł, +60 l).", seconds: 6)
    }

    private func makeOffers(from c: Int) -> [Job] {
        let destinations = World.cities.indices.filter { $0 != c }.shuffled()
        return destinations.prefix(3).map { (to: Int) -> Job in
            let cargo = CargoType.allCases.randomElement()!
            let tonnes = Int.random(in: cargo.tonnage)
            let roadPx = World.roadDistance(c, to)
            let km = roadPx / World.pxPerKm
            let pay = km * cargo.rate * (1 + CGFloat(tonnes) / 40)
            let limit = TimeInterval(roadPx / 260 + 25)
            return Job(cargo: cargo, from: c, to: to, tonnes: tonnes, km: Int(km),
                       pay: Int(pay), timeLimit: limit)
        }
    }

    // MARK: Krok symulacji

    func step(dt: TimeInterval, keys: Set<UInt16>) {
        let d = CGFloat(dt)
        drive(d, keys: keys)

        if activeJob != nil { jobTimeLeft -= dt }
        let city = World.cityIndex(near: position)
        if let c = city, activeJob == nil {
            if offersCity != c {
                offers = makeOffers(from: c)
                offersCity = c
            }
        } else if city == nil {
            offersCity = nil
        }
        if messageTimer > 0 { messageTimer -= dt }
    }

    /// Czy pokazać tablicę zleceń
    var showsOfferBoard: Bool { activeJob == nil && offersCity != nil }

    private func approach(_ v: CGFloat, _ target: CGFloat, _ step: CGFloat) -> CGFloat {
        v < target ? min(v + step, target) : max(v - step, target)
    }

    private func drive(_ d: CGFloat, keys: Set<UInt16>) {
        func pressed(_ k: UInt16...) -> Bool { k.contains { keys.contains($0) } }
        let up = pressed(Key.up, Key.w)
        let down = pressed(Key.down, Key.s)
        let left = pressed(Key.left, Key.a)
        let right = pressed(Key.right, Key.d)
        let handbrake = pressed(Key.space)

        onRoad = World.isOnRoad(position)
        let loaded = activeJob != nil
        let maxForward: CGFloat = onRoad ? 400 : 150     // 400 ≈ 90 km/h
        let accel: CGFloat = loaded ? 115 : 170
        let hasFuel = fuel > 0

        if up && hasFuel {
            speedPx += (speedPx < 0 ? 500 : accel) * d
        } else if down && (hasFuel || speedPx > 0) {
            speedPx -= (speedPx > 0 ? 500 : 100) * d
        } else {
            speedPx = approach(speedPx, 0, (hasFuel ? 70 : 150) * d)
        }
        if handbrake { speedPx = approach(speedPx, 0, 900 * d) }
        if speedPx > maxForward { speedPx = max(maxForward, speedPx - 350 * d) }
        if speedPx < -120 { speedPx = -120 }

        // Skręt zależny od prędkości
        let steer: CGFloat = (left ? 1 : 0) - (right ? 1 : 0)
        let speedFactor = min(1, abs(speedPx) / 120)
        let highSpeedDamp = 1 - 0.45 * min(1, abs(speedPx) / 400)
        heading += steer * 1.7 * speedFactor * highSpeedDamp * (speedPx >= 0 ? 1 : -1) * d

        let old = position
        var p = CGPoint(x: old.x + cos(heading) * speedPx * d, y: old.y + sin(heading) * speedPx * d)
        let lo: CGFloat = 60, hi = World.size - 60
        if p.x < lo || p.x > hi || p.y < lo || p.y > hi {
            p.x = max(lo, min(hi, p.x))
            p.y = max(lo, min(hi, p.y))
            speedPx *= 0.3
        }
        position = p

        // Naczepa (model kinematyczny przyczepy)
        var diff = atan2(sin(heading - trailerAngle), cos(heading - trailerAngle))
        trailerAngle += speedPx * d / 95 * sin(diff)
        diff = atan2(sin(heading - trailerAngle), cos(heading - trailerAngle))
        let maxFold: CGFloat = 1.35
        if abs(diff) > maxFold { trailerAngle = heading - (diff > 0 ? maxFold : -maxFold) }

        // Paliwo i przebieg
        let km = World.distance(old, p) / World.pxPerKm
        totalKm += km
        if fuel > 0 {
            fuel = max(0, fuel - km * 0.25 * (loaded ? 1.3 : 1))
            if fuel == 0 { show("Skończyło się paliwo! Wciśnij H, aby wezwać pomoc drogową.", seconds: 8) }
        }

        // Uszkodzenia ładunku przy szybkiej jeździe po bezdrożach
        if loaded && !onRoad && abs(speedPx) > 110 {
            cargoDamage = min(100, cargoDamage + 6 * d)
        }
    }
}

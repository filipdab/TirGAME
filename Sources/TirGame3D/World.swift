import AppKit

struct City {
    let name: String
    let position: CGPoint
}

enum CargoType: CaseIterable {
    case electronics, food, wood, steel, furniture, chemicals, cars

    var name: String {
        switch self {
        case .electronics: return "Elektronika"
        case .food: return "Żywność"
        case .wood: return "Drewno"
        case .steel: return "Stal"
        case .furniture: return "Meble"
        case .chemicals: return "Chemikalia"
        case .cars: return "Samochody"
        }
    }

    /// Stawka w zł za km
    var rate: CGFloat {
        switch self {
        case .electronics: return 9
        case .food: return 6
        case .wood: return 4.5
        case .steel: return 5.5
        case .furniture: return 6.5
        case .chemicals: return 10
        case .cars: return 8
        }
    }

    var tonnage: ClosedRange<Int> {
        switch self {
        case .electronics: return 4...10
        case .food: return 8...20
        case .wood: return 15...24
        case .steel: return 18...25
        case .furniture: return 5...12
        case .chemicals: return 10...22
        case .cars: return 8...14
        }
    }

    var color: NSColor {
        switch self {
        case .electronics: return NSColor(red: 0.25, green: 0.45, blue: 0.85, alpha: 1)
        case .food: return NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
        case .wood: return NSColor(red: 0.55, green: 0.35, blue: 0.18, alpha: 1)
        case .steel: return NSColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1)
        case .furniture: return NSColor(red: 0.85, green: 0.6, blue: 0.2, alpha: 1)
        case .chemicals: return NSColor(red: 0.95, green: 0.8, blue: 0.1, alpha: 1)
        case .cars: return NSColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1)
        }
    }
}

struct Job {
    let cargo: CargoType
    let from: Int
    let to: Int
    let tonnes: Int
    let km: Int
    let pay: Int
    let timeLimit: TimeInterval
}

enum World {
    static let size: CGFloat = 8000
    static let spacing: CGFloat = 1750
    static let margin: CGFloat = 500
    static let roadWidth: CGFloat = 130
    static let cityRadius: CGFloat = 180
    static let stationRadius: CGFloat = 120
    /// Ile pikseli świata to 1 km
    static let pxPerKm: CGFloat = 20

    static func grid(_ x: Int, _ y: Int) -> CGPoint {
        CGPoint(x: margin + CGFloat(x) * spacing, y: margin + CGFloat(y) * spacing)
    }

    static let cities: [City] = [
        City(name: "Szczecin", position: grid(0, 4)),
        City(name: "Gdańsk", position: grid(2, 4)),
        City(name: "Białystok", position: grid(4, 4)),
        City(name: "Poznań", position: grid(1, 3)),
        City(name: "Warszawa", position: grid(3, 3)),
        City(name: "Łódź", position: grid(2, 2)),
        City(name: "Wrocław", position: grid(0, 1)),
        City(name: "Lublin", position: grid(4, 1)),
        City(name: "Katowice", position: grid(1, 0)),
        City(name: "Kraków", position: grid(3, 0)),
    ]

    static let stations: [CGPoint] = [
        grid(1, 4), grid(3, 4), grid(0, 2), grid(4, 2),
        grid(2, 3), grid(1, 1), grid(3, 1), grid(2, 0),
    ]

    /// Sieć dróg: siatka 5x5 plus kilka ekspresówek po skosie
    static let roads: [(CGPoint, CGPoint)] = {
        var r: [(CGPoint, CGPoint)] = []
        for i in 0..<5 {
            for j in 0..<5 {
                if i < 4 { r.append((grid(i, j), grid(i + 1, j))) }
                if j < 4 { r.append((grid(i, j), grid(i, j + 1))) }
            }
        }
        r.append((grid(2, 2), grid(3, 3)))   // Łódź - Warszawa
        r.append((grid(1, 0), grid(2, 2)))   // Katowice - Łódź
        r.append((grid(2, 2), grid(1, 3)))   // Łódź - Poznań
        r.append((grid(3, 3), grid(4, 1)))   // Warszawa - Lublin
        return r
    }()

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    static func distanceToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let abx = b.x - a.x, aby = b.y - a.y
        let len2 = abx * abx + aby * aby
        if len2 == 0 { return distance(p, a) }
        var t = ((p.x - a.x) * abx + (p.y - a.y) * aby) / len2
        t = max(0, min(1, t))
        return distance(p, CGPoint(x: a.x + t * abx, y: a.y + t * aby))
    }

    static func isOnRoad(_ p: CGPoint) -> Bool {
        if cityIndex(near: p) != nil || stationIndex(near: p) != nil { return true }
        return roads.contains { distanceToSegment(p, $0.0, $0.1) < roadWidth / 2 + 8 }
    }

    static func cityIndex(near p: CGPoint) -> Int? {
        cities.firstIndex { distance($0.position, p) < cityRadius }
    }

    static func stationIndex(near p: CGPoint) -> Int? {
        stations.firstIndex { distance($0, p) < stationRadius }
    }

    static func nearestStation(to p: CGPoint) -> CGPoint {
        stations.min { distance($0, p) < distance($1, p) } ?? grid(2, 2)
    }

    static func nearestCity(to p: CGPoint) -> Int {
        cities.indices.min { distance(cities[$0].position, p) < distance(cities[$1].position, p) } ?? 0
    }

    /// Przybliżona długość trasy po drogach (metryka miejska)
    static func roadDistance(_ a: Int, _ b: Int) -> CGFloat {
        let pa = cities[a].position, pb = cities[b].position
        return abs(pa.x - pb.x) + abs(pa.y - pb.y)
    }
}

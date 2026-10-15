import SceneKit
import AppKit

/// Skala: 1 "piksel" mapy = 0.05 jednostki SceneKit. Oś Y mapy biegnie w stronę -Z.
let mapScale: CGFloat = 0.05

func v3(_ p: CGPoint, _ y: CGFloat = 0) -> SCNVector3 {
    SCNVector3(p.x * mapScale, y, -p.y * mapScale)
}

func + (a: SCNVector3, b: SCNVector3) -> SCNVector3 { SCNVector3(a.x + b.x, a.y + b.y, a.z + b.z) }
func - (a: SCNVector3, b: SCNVector3) -> SCNVector3 { SCNVector3(a.x - b.x, a.y - b.y, a.z - b.z) }
func * (a: SCNVector3, s: CGFloat) -> SCNVector3 { SCNVector3(a.x * s, a.y * s, a.z * s) }

func material(_ color: NSColor, emission: NSColor? = nil) -> SCNMaterial {
    let m = SCNMaterial()
    m.diffuse.contents = color
    if let emission = emission { m.emission.contents = emission }
    return m
}

func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ color: NSColor, chamfer: CGFloat = 0) -> SCNNode {
    let g = SCNBox(width: w, height: h, length: l, chamferRadius: chamfer)
    g.firstMaterial = material(color)
    return SCNNode(geometry: g)
}

/// Buduje i aktualizuje świat 3D na podstawie stanu gry.
final class World3D {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    var cameraMode = 0   // 0 = za ciężarówką, 1 = wyżej, 2 = z góry

    private let cab = SCNNode()
    private let trailer = SCNNode()
    private var trailerBody: SCNNode!
    private var wheels: [SCNNode] = []
    private var wheelSpin: CGFloat = 0
    private var lastCargoVersion = -1
    private var cameraReady = false

    private let yellow = NSColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)

    init() {
        buildEnvironment()
        buildRoads()
        buildCities()
        buildStations()
        buildTrees()
        buildTruck()
        buildCamera()
    }

    // MARK: Otoczenie

    private func buildEnvironment() {
        let sky = NSColor(red: 0.58, green: 0.76, blue: 0.95, alpha: 1)
        scene.background.contents = sky
        scene.fogColor = sky
        scene.fogStartDistance = 160
        scene.fogEndDistance = 420

        let floor = SCNFloor()
        floor.reflectivity = 0
        floor.firstMaterial = material(NSColor(red: 0.33, green: 0.58, blue: 0.27, alpha: 1))
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 1000
        sun.castsShadow = true
        sun.shadowColor = NSColor(white: 0, alpha: 0.45)
        sun.automaticallyAdjustsShadowProjection = true
        sun.maximumShadowDistance = 70
        sun.shadowMapSize = CGSize(width: 2048, height: 2048)
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-1.0, 0.7, 0)
        scene.rootNode.addChildNode(sunNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 450
        ambient.color = NSColor(red: 0.85, green: 0.9, blue: 1, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)
    }

    private func buildRoads() {
        let container = SCNNode()
        let asphalt = NSColor(white: 0.24, alpha: 1)
        let shoulderColor = NSColor(red: 0.62, green: 0.58, blue: 0.48, alpha: 1)
        let roadW = World.roadWidth * mapScale
        var junctions: [CGPoint] = []

        for (a, b) in World.roads {
            let pa = v3(a), pb = v3(b)
            let dx = pb.x - pa.x, dz = pb.z - pa.z
            let len = sqrt(dx * dx + dz * dz)
            let angle = -atan2(dz, dx)
            let mid = SCNVector3((pa.x + pb.x) / 2, 0, (pa.z + pb.z) / 2)

            let shoulder = box(len, 0.06, roadW + 1.2, shoulderColor)
            shoulder.position = mid + SCNVector3(0, 0.03, 0)
            shoulder.eulerAngles.y = angle
            container.addChildNode(shoulder)

            let road = box(len, 0.1, roadW, asphalt)
            road.position = mid + SCNVector3(0, 0.05, 0)
            road.eulerAngles.y = angle
            container.addChildNode(road)

            // Przerywana linia środkowa
            let dir = SCNVector3(dx / len, 0, dz / len)
            var t = roadW
            while t < len - roadW {
                let dash = box(2.0, 0.02, 0.2, NSColor(white: 0.95, alpha: 1))
                dash.position = pa + dir * t + SCNVector3(0, 0.11, 0)
                dash.eulerAngles.y = angle
                container.addChildNode(dash)
                t += 4
            }

            for p in [a, b] where !junctions.contains(p) { junctions.append(p) }
        }

        // Zaokrąglone skrzyżowania
        for j in junctions {
            let disc = SCNCylinder(radius: roadW / 2, height: 0.1)
            disc.firstMaterial = material(asphalt)
            let node = SCNNode(geometry: disc)
            node.position = v3(j, 0.05)
            container.addChildNode(node)
        }

        let flat = container.flattenedClone()
        scene.rootNode.addChildNode(flat)
    }

    private func makeLabel(_ text: String, size: CGFloat, color: NSColor) -> SCNNode {
        let t = SCNText(string: text, extrusionDepth: 0.4)
        t.font = NSFont.boldSystemFont(ofSize: size)
        t.flatness = 0.2
        t.firstMaterial = material(color, emission: color.withAlphaComponent(0.6))
        let node = SCNNode(geometry: t)
        let (minB, maxB) = node.boundingBox
        node.pivot = SCNMatrix4MakeTranslation((minB.x + maxB.x) / 2, (minB.y + maxB.y) / 2, 0)
        let holder = SCNNode()
        holder.addChildNode(node)
        holder.constraints = [SCNBillboardConstraint()]
        return holder
    }

    /// Czy w danym punkcie mapy (piksele) można postawić budynek o promieniu r
    private func isFree(_ p: CGPoint, radius r: CGFloat) -> Bool {
        if p.x < 40 || p.y < 40 || p.x > World.size - 40 || p.y > World.size - 40 { return false }
        if World.roads.contains(where: { World.distanceToSegment(p, $0.0, $0.1) < World.roadWidth / 2 + 30 + r }) { return false }
        if World.cities.contains(where: { World.distance($0.position, p) < World.cityRadius + 20 + r }) { return false }
        if World.stations.contains(where: { World.distance($0, p) < World.stationRadius + 20 + r }) { return false }
        return true
    }

    private func buildCities() {
        let palette: [NSColor] = [
            NSColor(red: 0.85, green: 0.82, blue: 0.75, alpha: 1),
            NSColor(red: 0.7, green: 0.72, blue: 0.78, alpha: 1),
            NSColor(red: 0.75, green: 0.45, blue: 0.35, alpha: 1),
            NSColor(red: 0.55, green: 0.6, blue: 0.68, alpha: 1),
            NSColor(red: 0.9, green: 0.88, blue: 0.85, alpha: 1),
        ]
        let buildings = SCNNode()

        for c in World.cities {
            let r = World.cityRadius * mapScale
            let ring = SCNCylinder(radius: r + 0.5, height: 0.13)
            ring.firstMaterial = material(yellow)
            let ringNode = SCNNode(geometry: ring)
            ringNode.position = v3(c.position, 0.065)
            scene.rootNode.addChildNode(ringNode)

            let yard = SCNCylinder(radius: r, height: 0.14)
            yard.firstMaterial = material(NSColor(red: 0.45, green: 0.45, blue: 0.5, alpha: 1))
            let yardNode = SCNNode(geometry: yard)
            yardNode.position = v3(c.position, 0.07)
            scene.rootNode.addChildNode(yardNode)

            // Magazyny na skosach (między drogami)
            for k in 0..<4 {
                let ang = CGFloat(k) * .pi / 2 + .pi / 4
                let p = CGPoint(x: c.position.x + cos(ang) * (World.cityRadius + 70),
                                y: c.position.y + sin(ang) * (World.cityRadius + 70))
                if World.roads.contains(where: { World.distanceToSegment(p, $0.0, $0.1) < World.roadWidth / 2 + 60 }) { continue }
                let wh = box(6, 3.5, 4, NSColor(red: 0.72, green: 0.32, blue: 0.25, alpha: 1))
                wh.position = v3(p, 1.75)
                wh.eulerAngles.y = -ang
                buildings.addChildNode(wh)
                let roof = box(6.2, 0.3, 4.2, NSColor(white: 0.3, alpha: 1))
                roof.position = v3(p, 3.6)
                roof.eulerAngles.y = -ang
                buildings.addChildNode(roof)
            }

            // Zabudowa miasta
            var placed = 0, tries = 0
            while placed < 28 && tries < 400 {
                tries += 1
                let ang = CGFloat.random(in: 0..<(2 * .pi))
                let dist = CGFloat.random(in: (World.cityRadius + 120)...(World.cityRadius + 650))
                let p = CGPoint(x: c.position.x + cos(ang) * dist, y: c.position.y + sin(ang) * dist)
                let w = CGFloat.random(in: 3...7), l = CGFloat.random(in: 3...7)
                guard isFree(p, radius: max(w, l) / mapScale / 2) else { continue }
                let h = CGFloat.random(in: 4...(dist < World.cityRadius + 350 ? 22 : 10))
                let b = box(w, h, l, palette.randomElement()!)
                b.position = v3(p, h / 2)
                buildings.addChildNode(b)
                placed += 1
            }

            let label = makeLabel(c.name.uppercased(), size: 4, color: yellow)
            label.position = v3(c.position, 16)
            scene.rootNode.addChildNode(label)
        }
        scene.rootNode.addChildNode(buildings.flattenedClone())
    }

    private func buildStations() {
        let orange = NSColor(red: 0.9, green: 0.45, blue: 0.1, alpha: 1)
        for s in World.stations {
            let pad = SCNCylinder(radius: World.stationRadius * mapScale, height: 0.14)
            pad.firstMaterial = material(NSColor(white: 0.55, alpha: 1))
            let padNode = SCNNode(geometry: pad)
            padNode.position = v3(s, 0.07)
            scene.rootNode.addChildNode(padNode)

            let station = SCNNode()
            let canopy = box(9, 0.6, 7, orange)
            canopy.position = SCNVector3(0, 5, 0)
            station.addChildNode(canopy)
            for (x, z) in [(-3.5, -2.5), (3.5, -2.5), (-3.5, 2.5), (3.5, 2.5)] as [(CGFloat, CGFloat)] {
                let pillar = box(0.3, 5, 0.3, NSColor(white: 0.9, alpha: 1))
                pillar.position = SCNVector3(x, 2.5, z)
                station.addChildNode(pillar)
            }
            for z in [-1.2, 1.2] as [CGFloat] {
                let pump = box(0.6, 1.4, 0.9, NSColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1))
                pump.position = SCNVector3(0, 0.7, z)
                station.addChildNode(pump)
            }
            station.position = v3(s)
            // Odsuń wiatę od osi drogi, żeby nie zasłaniała przejazdu
            station.position.x += 3
            station.position.z -= 3
            scene.rootNode.addChildNode(station.flattenedClone())

            let label = makeLabel("STACJA", size: 2, color: orange)
            label.position = v3(s, 8)
            scene.rootNode.addChildNode(label)
        }
    }

    private func buildTrees() {
        let forest = SCNNode()
        let trunkGeo = SCNCylinder(radius: 0.3, height: 1.6)
        trunkGeo.firstMaterial = material(NSColor(red: 0.4, green: 0.26, blue: 0.13, alpha: 1))
        let leafMats = ([0.32, 0.38, 0.44] as [CGFloat]).map { material(NSColor(red: 0.13, green: $0, blue: 0.14, alpha: 1)) }

        var placed = 0, tries = 0
        while placed < 700 && tries < 6000 {
            tries += 1
            let p = CGPoint(x: CGFloat.random(in: 60...(World.size - 60)),
                            y: CGFloat.random(in: 60...(World.size - 60)))
            guard isFree(p, radius: 30) else { continue }
            // Nie sadź drzew w środku miejskiej zabudowy
            if World.cities.contains(where: { World.distance($0.position, p) < World.cityRadius + 600 }) { continue }
            let scale = CGFloat.random(in: 0.8...1.5)
            let trunk = SCNNode(geometry: trunkGeo)
            trunk.position = v3(p, 0.8 * scale)
            trunk.scale = SCNVector3(scale, scale, scale)
            forest.addChildNode(trunk)

            let cone = SCNCone(topRadius: 0, bottomRadius: 1.8, height: 5)
            cone.firstMaterial = leafMats.randomElement()!
            let leaves = SCNNode(geometry: cone)
            leaves.position = v3(p, (1.4 + 2.5) * scale)
            leaves.scale = SCNVector3(scale, scale, scale)
            forest.addChildNode(leaves)
            placed += 1
        }
        scene.rootNode.addChildNode(forest.flattenedClone())
    }

    // MARK: Ciężarówka (przód kabiny w stronę +X)

    private func makeWheel(radius: CGFloat = 0.5) -> SCNNode {
        let g = SCNCylinder(radius: radius, height: 0.45)
        g.firstMaterial = material(NSColor(white: 0.08, alpha: 1))
        let w = SCNNode(geometry: g)
        w.eulerAngles.x = .pi / 2
        // Felga, żeby było widać obrót
        let hub = box(0.5, 0.47, 0.12, NSColor(white: 0.7, alpha: 1))
        w.addChildNode(hub)
        let spinner = SCNNode()
        spinner.addChildNode(w)
        wheels.append(spinner)
        return spinner
    }

    private func buildTruck() {
        let red = NSColor(red: 0.82, green: 0.08, blue: 0.1, alpha: 1)

        let chassis = box(2.6, 0.3, 1.5, NSColor(white: 0.15, alpha: 1))
        chassis.position = SCNVector3(-0.1, 0.55, 0)
        cab.addChildNode(chassis)

        let body = box(1.5, 2.3, 1.85, red, chamfer: 0.15)
        body.position = SCNVector3(0.5, 1.85, 0)
        cab.addChildNode(body)

        let windshield = box(0.08, 0.9, 1.6, NSColor(red: 0.55, green: 0.8, blue: 0.95, alpha: 1))
        windshield.position = SCNVector3(1.26, 2.35, 0)
        cab.addChildNode(windshield)

        let grill = box(0.08, 0.7, 1.4, NSColor(white: 0.2, alpha: 1))
        grill.position = SCNVector3(1.26, 1.2, 0)
        cab.addChildNode(grill)

        for z in [-0.7, 0.7] as [CGFloat] {
            let lamp = box(0.08, 0.2, 0.3, .white)
            lamp.geometry?.firstMaterial = material(.white, emission: NSColor(red: 1, green: 1, blue: 0.8, alpha: 1))
            lamp.position = SCNVector3(1.28, 0.95, z)
            cab.addChildNode(lamp)
        }

        // Siodło
        let fifthWheel = box(0.8, 0.15, 1.0, NSColor(white: 0.3, alpha: 1))
        fifthWheel.position = SCNVector3(-1.0, 0.78, 0)
        cab.addChildNode(fifthWheel)

        for (x, z) in [(0.7, 0.85), (0.7, -0.85), (-0.9, 0.85), (-0.9, -0.85)] as [(CGFloat, CGFloat)] {
            let w = makeWheel()
            w.position = SCNVector3(x, 0.5, z)
            cab.addChildNode(w)
        }
        scene.rootNode.addChildNode(cab)

        // Naczepa: zaczep w +X, środek naczepy w (0,0)
        trailerBody = box(6.0, 2.7, 1.95, NSColor(white: 0.75, alpha: 1))
        trailerBody.position = SCNVector3(-0.15, 2.25, 0)
        trailer.addChildNode(trailerBody)
        let frame = box(6.0, 0.25, 1.4, NSColor(white: 0.15, alpha: 1))
        frame.position = SCNVector3(-0.15, 0.8, 0)
        trailer.addChildNode(frame)
        for x in [-2.5, -1.8, -1.1] as [CGFloat] {
            for z in [0.85, -0.85] as [CGFloat] {
                let w = makeWheel()
                w.position = SCNVector3(x, 0.5, z)
                trailer.addChildNode(w)
            }
        }
        scene.rootNode.addChildNode(trailer)

        for n in [cab, trailer] {
            n.enumerateChildNodes { child, _ in child.castsShadow = true }
        }
    }

    private func buildCamera() {
        let cam = SCNCamera()
        cam.fieldOfView = 60
        cam.zNear = 0.5
        cam.zFar = 600
        cameraNode.camera = cam
        scene.rootNode.addChildNode(cameraNode)
    }

    // MARK: Aktualizacja co klatkę

    func sync(with game: Game, dt: TimeInterval) {
        cab.position = v3(game.position)
        cab.eulerAngles.y = game.heading
        trailer.position = v3(game.trailerPosition)
        trailer.eulerAngles.y = game.trailerAngle

        // Obrót kół
        wheelSpin -= game.speedPx * mapScale / 0.5 * CGFloat(dt)
        for w in wheels { w.eulerAngles.z = wheelSpin }

        if game.cargoVersion != lastCargoVersion {
            lastCargoVersion = game.cargoVersion
            let color = game.activeJob?.cargo.color ?? NSColor(white: 0.75, alpha: 1)
            trailerBody.geometry?.firstMaterial = material(color)
        }

        updateCamera(game, dt: CGFloat(dt))
    }

    private func updateCamera(_ game: Game, dt: CGFloat) {
        let p = v3(game.position)
        let fwd = SCNVector3(cos(game.heading), 0, -sin(game.heading))
        let desired: SCNVector3
        switch cameraMode {
        case 1: desired = p - fwd * 28 + SCNVector3(0, 22, 0)
        case 2: desired = p - fwd * 12 + SCNVector3(0, 65, 0)
        default: desired = p - fwd * 15 + SCNVector3(0, 6.5, 0)
        }
        if !cameraReady {
            cameraNode.position = desired
            cameraReady = true
        } else {
            let t = min(1, 3.5 * dt)
            cameraNode.position = cameraNode.position + (desired - cameraNode.position) * t
        }
        cameraNode.look(at: p + fwd * 6 + SCNVector3(0, 1.5, 0))
    }
}

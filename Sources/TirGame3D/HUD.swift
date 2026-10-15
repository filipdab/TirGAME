import SpriteKit
import AppKit

/// Nakładka 2D (SpriteKit) rysowana nad sceną 3D.
final class HUDScene: SKScene {
    private var statLabels: [SKLabelNode] = []
    private var statsPanel: SKShapeNode!
    private var boardPanel: SKShapeNode!
    private var boardLabels: [SKLabelNode] = []
    private var messageLabel: SKLabelNode!
    private var helpLabel: SKLabelNode!
    private let compass = SKNode()
    private var compassLabel: SKLabelNode!
    private let minimap = SKNode()
    private var minimapTruck: SKShapeNode!
    private var minimapTarget: SKShapeNode!
    private let minimapSize: CGFloat = 200
    private let warn = NSColor(red: 1, green: 0.4, blue: 0.3, alpha: 1)
    private let yellow = NSColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)

    override init(size: CGSize) {
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
        backgroundColor = .clear
        build()
        layout()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not supported") }

    override func didChangeSize(_ oldSize: CGSize) {
        if statsPanel != nil { layout() }
    }

    private func makeLabel(size: CGFloat, bold: Bool = false) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: bold ? "Helvetica-Bold" : "Helvetica")
        l.fontSize = size
        l.fontColor = .white
        l.verticalAlignmentMode = .center
        l.horizontalAlignmentMode = .center
        return l
    }

    private func build() {
        statsPanel = SKShapeNode(rect: CGRect(x: 0, y: -190, width: 330, height: 190), cornerRadius: 10)
        statsPanel.fillColor = NSColor(white: 0, alpha: 0.55)
        statsPanel.strokeColor = .clear
        addChild(statsPanel)
        for i in 0..<7 {
            let l = makeLabel(size: 17, bold: i == 0)
            l.horizontalAlignmentMode = .left
            l.position = CGPoint(x: 14, y: -20 - CGFloat(i) * 25)
            statsPanel.addChild(l)
            statLabels.append(l)
        }

        boardPanel = SKShapeNode(rect: CGRect(x: 0, y: -170, width: 540, height: 170), cornerRadius: 10)
        boardPanel.fillColor = NSColor(red: 0.05, green: 0.1, blue: 0.25, alpha: 0.85)
        boardPanel.strokeColor = yellow
        boardPanel.lineWidth = 2
        addChild(boardPanel)
        for i in 0..<5 {
            let l = makeLabel(size: i == 0 ? 19 : 16, bold: i == 0)
            l.horizontalAlignmentMode = .left
            l.position = CGPoint(x: 14, y: -22 - CGFloat(i) * 30)
            boardPanel.addChild(l)
            boardLabels.append(l)
        }
        boardPanel.isHidden = true

        messageLabel = makeLabel(size: 22, bold: true)
        messageLabel.fontColor = yellow
        addChild(messageLabel)

        helpLabel = makeLabel(size: 14)
        helpLabel.fontColor = NSColor(white: 1, alpha: 0.9)
        helpLabel.text = "Strzałki/WASD – jazda · Spacja – ręczny · 1–3 – zlecenie · E – rozładuj · F – tankuj · H – pomoc drogowa · C – kamera"
        addChild(helpLabel)

        // Strzałka do celu: "w górę" = kierunek jazdy
        let arrowPath = CGMutablePath()
        arrowPath.move(to: CGPoint(x: 28, y: 0))
        arrowPath.addLine(to: CGPoint(x: -14, y: 16))
        arrowPath.addLine(to: CGPoint(x: -6, y: 0))
        arrowPath.addLine(to: CGPoint(x: -14, y: -16))
        arrowPath.closeSubpath()
        let arrow = SKShapeNode(path: arrowPath)
        arrow.fillColor = yellow
        arrow.strokeColor = .black
        arrow.lineWidth = 2
        compass.addChild(arrow)
        addChild(compass)
        compassLabel = makeLabel(size: 16, bold: true)
        addChild(compassLabel)

        // Minimapa (północ u góry)
        let s = minimapSize / World.size
        let bg = SKShapeNode(rect: CGRect(x: 0, y: 0, width: minimapSize, height: minimapSize), cornerRadius: 6)
        bg.fillColor = NSColor(red: 0.15, green: 0.3, blue: 0.12, alpha: 0.85)
        bg.strokeColor = .white
        minimap.addChild(bg)
        for (a, b) in World.roads {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: a.x * s, y: a.y * s))
            p.addLine(to: CGPoint(x: b.x * s, y: b.y * s))
            let line = SKShapeNode(path: p)
            line.strokeColor = NSColor(white: 0.8, alpha: 1)
            line.lineWidth = 2
            minimap.addChild(line)
        }
        for st in World.stations {
            let dot = SKShapeNode(circleOfRadius: 3)
            dot.fillColor = .orange
            dot.strokeColor = .clear
            dot.position = CGPoint(x: st.x * s, y: st.y * s)
            minimap.addChild(dot)
        }
        for c in World.cities {
            let dot = SKShapeNode(circleOfRadius: 4.5)
            dot.fillColor = yellow
            dot.strokeColor = .black
            dot.position = CGPoint(x: c.position.x * s, y: c.position.y * s)
            minimap.addChild(dot)
        }
        minimapTarget = SKShapeNode(circleOfRadius: 8)
        minimapTarget.strokeColor = .cyan
        minimapTarget.lineWidth = 2
        minimapTarget.fillColor = .clear
        minimap.addChild(minimapTarget)
        let tri = CGMutablePath()
        tri.move(to: CGPoint(x: 7, y: 0))
        tri.addLine(to: CGPoint(x: -5, y: 5))
        tri.addLine(to: CGPoint(x: -5, y: -5))
        tri.closeSubpath()
        minimapTruck = SKShapeNode(path: tri)
        minimapTruck.fillColor = .red
        minimapTruck.strokeColor = .white
        minimap.addChild(minimapTruck)
        addChild(minimap)
    }

    private func layout() {
        let w = size.width, h = size.height
        statsPanel.position = CGPoint(x: -w / 2 + 16, y: h / 2 - 16)
        boardPanel.position = CGPoint(x: -w / 2 + 16, y: h / 2 - 220)
        minimap.position = CGPoint(x: w / 2 - minimapSize - 16, y: h / 2 - minimapSize - 16)
        compass.position = CGPoint(x: 0, y: h / 2 - 50)
        compassLabel.position = CGPoint(x: 0, y: h / 2 - 95)
        messageLabel.position = CGPoint(x: 0, y: -h / 2 + 70)
        helpLabel.position = CGPoint(x: 0, y: -h / 2 + 24)
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let s = Int(abs(t))
        return String(format: "%@%d:%02d", t < 0 ? "-" : "", s / 60, s % 60)
    }

    func update(with game: Game) {
        statLabels[0].text = "💰 \(game.money) zł"
        statLabels[1].text = "Prędkość: \(game.kmh) km/h" + (game.onRoad ? "" : "  (bezdroża)")
        statLabels[2].text = "Paliwo: \(Int(game.fuel)) / \(Int(game.tank)) l"
        statLabels[2].fontColor = game.fuel < 60 ? warn : .white
        if let job = game.activeJob {
            statLabels[3].text = "Ładunek: \(job.cargo.name), \(job.tonnes) t"
            statLabels[4].text = "Cel: \(World.cities[job.to].name) – zapłata \(job.pay) zł"
            statLabels[5].text = "Czas: \(formatTime(game.jobTimeLeft))   Uszkodzenia: \(Int(game.cargoDamage))%"
            statLabels[5].fontColor = game.jobTimeLeft < 0 ? warn : .white
        } else {
            statLabels[3].text = "Ładunek: brak"
            statLabels[4].text = "Jedź do miasta po zlecenie"
            statLabels[5].text = ""
        }
        statLabels[6].text = "Dostawy: \(game.deliveries)   Przebieg: \(Int(game.totalKm)) km"

        if game.showsOfferBoard, let c = game.offersCity {
            boardPanel.isHidden = false
            boardLabels[0].text = "Zlecenia – \(World.cities[c].name)"
            for (i, job) in game.offers.prefix(3).enumerated() {
                boardLabels[i + 1].text = "[\(i + 1)] \(job.cargo.name), \(job.tonnes) t → \(World.cities[job.to].name)  \(job.km) km  \(job.pay) zł  ⏱ \(formatTime(job.timeLimit))"
            }
            boardLabels[4].text = "Zatrzymaj się i wciśnij 1, 2 lub 3"
        } else {
            boardPanel.isHidden = true
        }

        let target = game.target
        let dx = target.point.x - game.position.x, dy = target.point.y - game.position.y
        // Kamera patrzy w kierunku jazdy, więc strzałka jest względna do kursu
        compass.zRotation = atan2(dy, dx) - game.heading + .pi / 2
        compassLabel.text = "\(target.name) – \(Int(hypot(dx, dy) / World.pxPerKm)) km"

        let s = minimapSize / World.size
        minimapTruck.position = CGPoint(x: game.position.x * s, y: game.position.y * s)
        minimapTruck.zRotation = game.heading
        minimapTarget.position = CGPoint(x: target.point.x * s, y: target.point.y * s)

        messageLabel.text = game.message
        messageLabel.alpha = CGFloat(max(0, min(1, game.messageTimer)))
    }
}

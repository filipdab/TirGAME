import AppKit
import SceneKit

/// Widok 3D, który przekazuje klawisze do kontrolera gry.
final class GameView: SCNView {
    weak var controller: GameController?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        controller?.keyDown(event.keyCode, isRepeat: event.isARepeat)
    }

    override func keyUp(with event: NSEvent) {
        controller?.keyUp(event.keyCode)
    }
}

/// Spina logikę, świat 3D i HUD. Pętla gry działa w wywołaniu renderera.
final class GameController: NSObject, SCNSceneRendererDelegate {
    let game = Game()
    let world3D = World3D()
    let hud = HUDScene(size: CGSize(width: 1280, height: 800))

    private let lock = NSLock()
    private var keys = Set<UInt16>()
    private var presses: [UInt16] = []
    private var lastTime: TimeInterval = 0

    func keyDown(_ code: UInt16, isRepeat: Bool) {
        lock.lock()
        keys.insert(code)
        if !isRepeat { presses.append(code) }
        lock.unlock()
    }

    func keyUp(_ code: UInt16) {
        lock.lock()
        keys.remove(code)
        lock.unlock()
    }

    func releaseAllKeys() {
        lock.lock()
        keys.removeAll()
        lock.unlock()
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let dt = lastTime == 0 ? 1.0 / 60 : min(time - lastTime, 1.0 / 20)
        lastTime = time

        lock.lock()
        let held = keys
        let newPresses = presses
        presses.removeAll()
        lock.unlock()

        for code in newPresses {
            if code == Key.c {
                world3D.cameraMode = (world3D.cameraMode + 1) % 3
            } else {
                game.handleKey(code)
            }
        }
        game.step(dt: dt, keys: held)
        world3D.sync(with: game, dt: dt)
        hud.update(with: game)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    let controller = GameController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let size = CGSize(width: 1280, height: 800)
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TIR Simulator 3D"
        window.delegate = self
        window.center()

        let view = GameView(frame: NSRect(origin: .zero, size: size), options: nil)
        view.controller = controller
        view.scene = controller.world3D.scene
        view.pointOfView = controller.world3D.cameraNode
        view.delegate = controller
        view.overlaySKScene = controller.hud
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = true
        view.isPlaying = true

        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowDidResignKey(_ notification: Notification) {
        controller.releaseAllKeys()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)

// Minimalne menu, żeby działało Cmd+Q
let mainMenu = NSMenu()
let appItem = NSMenuItem()
mainMenu.addItem(appItem)
let appMenu = NSMenu()
appMenu.addItem(withTitle: "Zakończ TIR Simulator 3D", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
appItem.submenu = appMenu
app.mainMenu = mainMenu

app.run()

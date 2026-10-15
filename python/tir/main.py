"""Uruchomienie gry: okno Panda3D, sterowanie i pętla gry."""
import sys

from panda3d.core import ClockObject, KeyboardButton, load_prc_file_data

load_prc_file_data("", """
window-title TIR Simulator 3D
win-size 1280 800
sync-video 1
framebuffer-multisample 1
multisamples 4
audio-library-name null
""")

from direct.showbase.ShowBase import ShowBase  # noqa: E402

from .game import Game  # noqa: E402
from .hud import HUD  # noqa: E402
from .scene3d import Scene3D  # noqa: E402


class TirApp(ShowBase):
    def __init__(self, **kwargs):
        ShowBase.__init__(self, **kwargs)
        self.disableMouse()
        self.game = Game()
        self.scene = Scene3D(self)
        self.hud = HUD(self)
        self.forced_controls = None   # do testów automatycznych

        kb = KeyboardButton
        self.control_keys = {
            "up": [kb.up(), kb.ascii_key("w")],
            "down": [kb.down(), kb.ascii_key("s")],
            "left": [kb.left(), kb.ascii_key("a")],
            "right": [kb.right(), kb.ascii_key("d")],
            "brake": [kb.space()],
        }
        self.accept("e", self.game.unload)
        self.accept("f", self.game.refuel)
        self.accept("h", self.game.call_tow)
        self.accept("c", self.cycle_camera)
        for i in range(3):
            self.accept(str(i + 1), self.game.accept_offer, [i])
        self.accept("escape", sys.exit)

        self.taskMgr.add(self.update, "petla-gry")

    def cycle_camera(self):
        self.scene.camera_mode = (self.scene.camera_mode + 1) % 3

    def read_controls(self):
        if self.forced_controls is not None:
            return self.forced_controls
        mw = self.mouseWatcherNode
        if mw is None:
            return set()
        return {name for name, buttons in self.control_keys.items()
                if any(mw.is_button_down(b) for b in buttons)}

    def update(self, task):
        dt = min(ClockObject.get_global_clock().get_dt(), 1 / 20)
        self.game.step(dt, self.read_controls())
        self.scene.sync(self.game, dt)
        self.hud.update(self.game)
        return task.cont


def main():
    TirApp().run()


if __name__ == "__main__":
    main()

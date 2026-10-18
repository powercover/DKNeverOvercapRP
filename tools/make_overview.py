"""Draws Listing/overview.png (2560 x 1440): the settings window with callouts saying what each
part does, and a strip of scenes showing overlay patterns in each spec's color.
Run from the addon folder: python tools/make_overview.py

Everything is laid out in 2560 x 1440 coordinates and drawn at twice that, then scaled down. The
window mirrors the metrics in Options.lua; the scenes use the layer table from Display.lua."""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / "Media"
W, H, K = 2560, 1440, 2

BG = (11, 11, 14)
WINDOW = (14, 14, 16)
CARD = (25, 25, 28)
BORDER = (42, 42, 46)
HOVER = (33, 33, 37)
WELL = (18, 18, 20)
RAISED = (55, 55, 60)
OFF = (60, 60, 66)
TEXT = (236, 236, 241)
MUTED = (143, 144, 156)
ACCENT = (224, 64, 71)
COLORS = {"Blood": (224, 64, 71), "Frost": (102, 173, 242), "Unholy": (133, 217, 102)}
GREEN = (77, 230, 115)

_fonts = {}


def font(size, weight="Regular", scale=K):
    key = (size, weight, scale)
    if key not in _fonts:
        _fonts[key] = ImageFont.truetype(str(MEDIA / "Fonts" / f"Inter-{weight}.ttf"), round(size * scale))
    return _fonts[key]


class Canvas:
    """Draws in 2560 x 1440 layout units onto a K-times supersampled image."""

    def __init__(self):
        self.img = Image.new("RGB", (W * K, H * K), BG)
        self.d = ImageDraw.Draw(self.img)

    def box(self, x, y, w, h, r, fill, outline=None, width=1):
        self.d.rounded_rectangle([x * K, y * K, (x + w) * K - 1, (y + h) * K - 1], r * K, fill=fill,
                                 outline=outline, width=round(width * K))

    def circle(self, cx, cy, r, fill, outline=None, width=1):
        self.d.ellipse([(cx - r) * K, (cy - r) * K, (cx + r) * K, (cy + r) * K], fill=fill, outline=outline,
                       width=round(width * K))

    def text(self, x, y, s, size, color, weight="Regular", anchor="la"):
        self.d.text((x * K, y * K), s, font=font(size, weight), fill=color, anchor=anchor)

    def line(self, points, color, width=2):
        self.d.line([(x * K, y * K) for x, y in points], fill=color, width=round(width * K))

    def paste(self, image, x, y):
        self.img.paste(image, (round(x * K), round(y * K)), image if image.mode == "RGBA" else None)

    def wrap(self, x, y, s, size, color, width, leading=1.45, weight="Regular"):
        f = font(size, weight)
        words, line_ = s.split(), ""
        for word in words:
            trial = (line_ + " " + word).strip()
            if f.getlength(trial) / K > width and line_:
                self.text(x, y, line_, size, color, weight)
                y += size * leading
                line_ = word
            else:
                line_ = trial
        if line_:
            self.text(x, y, line_, size, color, weight)
            y += size * leading
        return y


def tinted_texture(name, size, color, alpha=1.0):
    tex = Image.open(MEDIA / f"{name}.tga").convert("RGBA").resize(size, Image.LANCZOS)
    a = np.asarray(tex.getchannel("A"), dtype=np.float32) * alpha
    out = Image.new("RGBA", size, color + (0,))
    out.putalpha(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)))
    return out


# ---------------------------------------------------------------------------
# Settings window (metrics from Options.lua, in window units scaled by U)
# ---------------------------------------------------------------------------

U = 1.45
WX, WY = 816, 196


def wx(v):
    return WX + v * U


def wy(v):
    return WY + v * U


def draw_window(c):
    ww, wh = 640, 538
    c.box(wx(0), wy(0), ww * U, wh * U, 12 * U, WINDOW, BORDER, 1.5)

    # Header
    logo = tinted_texture("runes", (round(36 * U * K),) * 2, ACCENT)
    core = tinted_texture("ring_core", (round(36 * U * K),) * 2, (245, 170, 170))
    c.img.paste(logo, (round(wx(18) * K), round(wy(16) * K)), logo)
    c.img.paste(core, (round(wx(18) * K), round(wy(16) * K)), core)
    c.text(wx(66), wy(15), "DK Never Overcap RP", 15 * U, TEXT, "SemiBold")
    c.circle(wx(70), wy(43), 3 * U, GREEN)
    c.text(wx(79), wy(36), "Active · Blood   ·   v2.0.0", 11 * U, MUTED)
    c.text(wx(628), wy(16), "×", 16 * U, MUTED, anchor="ra")
    c.box(wx(512), wy(22), 84 * U, 24 * U, 6 * U, tuple(int(v * 0.72) for v in ACCENT))
    c.text(wx(554), wy(34), "Preview", 12 * U, TEXT, "Medium", "mm")
    c.box(wx(440), wy(22), 64 * U, 24 * U, 6 * U, CARD, BORDER, 1)
    c.text(wx(472), wy(34), "Reset", 12 * U, TEXT, "Medium", "mm")

    col = (640 - 32 - 12) / 2
    anchors = {}

    def card(x, y, title, rows):
        h = 30 + sum(r[0] for r in rows) + 6
        c.box(wx(x), wy(y), col * U, h * U, 8 * U, CARD, BORDER, 1)
        c.text(wx(x + 14), wy(y + 12), title, 11 * U, MUTED, "SemiBold")
        cy = y + 30
        for height, kind, *args in rows:
            rx, rw = x + 6, col - 12
            mid = cy + height / 2
            if kind == "toggle":
                c.text(wx(rx + 8), wy(mid), args[0], 12 * U, TEXT, "Medium", "lm")
                switch(rx + rw - 36, mid, args[1])
            elif kind == "spec":
                icon_color = COLORS[args[0]]
                c.box(wx(rx + 8), wy(mid - 9), 18 * U, 18 * U, 3 * U, tuple(int(v * 0.45) for v in icon_color))
                c.text(wx(rx + 34), wy(mid), args[0], 12 * U, TEXT, "Medium", "lm")
                switch(rx + rw - 36, mid, True)
                c.circle(wx(rx + rw - 56), wy(mid), 8 * U, BORDER)
                c.circle(wx(rx + rw - 56), wy(mid), 6 * U, icon_color)
            elif kind == "slider":
                c.text(wx(rx + 8), wy(cy + 6), args[0], 12 * U, TEXT, "Medium")
                c.text(wx(rx + rw - 8), wy(cy + 7), args[1], 11 * U, MUTED, anchor="ra")
                ty = cy + height - 12
                tw = rw - 16
                c.box(wx(rx + 8), wy(ty - 2), tw * U, 4 * U, 2 * U, OFF)
                fx = 6 + args[2] * (tw - 12)
                c.box(wx(rx + 8), wy(ty - 2), fx * U, 4 * U, 2 * U, ACCENT)
                c.circle(wx(rx + 8 + fx), wy(ty), 6 * U, (255, 255, 255))
            elif kind == "tiles":
                label, options, selected, screen = args
                c.text(wx(rx + 8), wy(cy + 6), label, 12 * U, TEXT, "Medium")
                gx, gw = rx + 8, rw - 16
                each = (gw - 12) / 3
                for i, (name, icon) in enumerate(options):
                    tx, ty = gx + (i % 3) * (each + 6), cy + 26 + (i // 3) * 62
                    sel = i == selected
                    c.box(wx(tx), wy(ty), each * U, 56 * U, 6 * U, RAISED if sel else WELL,
                          tuple(int(v * 0.8) for v in ACCENT) if sel else BORDER, 1)
                    if icon:
                        iw, ih = (40, 24) if screen else (30, 30)
                        ix, iy = tx + each / 2 - iw / 2, ty + 21 - ih / 2
                        if screen:
                            c.box(wx(ix), wy(iy), iw * U, ih * U, 2 * U, BORDER)
                        tex = tinted_texture(icon, (round(iw * U * K), round(ih * U * K)), ACCENT, 1 if sel else 0.6)
                        c.img.paste(tex, (round(wx(ix) * K), round(wy(iy) * K)), tex)
                        c.text(wx(tx + each / 2), wy(ty + 44), name, 11 * U, TEXT if sel else MUTED, anchor="mm")
                    else:
                        c.text(wx(tx + each / 2), wy(ty + 28), name, 11 * U, TEXT if sel else MUTED, anchor="mm")
            anchors.setdefault(kind + ":" + str(args[0]), (rx, cy, height))
            cy += height
        return h

    def switch(x, mid, on):
        c.box(wx(x), wy(mid - 8), 28 * U, 16 * U, 8 * U, ACCENT if on else OFF)
        c.circle(wx(x + (20 if on else 8)), wy(mid), 6 * U, (255, 255, 255))

    y = 68
    general = card(16, y, "General", [(28, "toggle", "Enable overlay", True), (28, "toggle", "Only in combat", False),
                                      (28, "toggle", "Minimap button", True)])
    y_specs = y + general + 12
    specs = card(16, y_specs, "Specializations", [(30, "spec", "Blood"), (30, "spec", "Frost"), (30, "spec", "Unholy")])
    y_trigger = y_specs + specs + 12
    card(16, y_trigger, "Trigger", [(40, "slider", "Appear at", "85%", 0.85), (28, "toggle", "Pulse near cap", True),
                                    (40, "slider", "Pulse at", "95%", 0.9)])
    rx = 16 + col + 12
    auras = [("None", None), ("Rune circle", "runes"), ("Halo", "glow"), ("Arcs", "arcs_inner"), ("Sigil", "sigil"),
             ("Embers", "embers")]
    screens = [("None", None), ("Edge glow", "edge"), ("Corners", "corners")]
    card(rx, 68, "Appearance", [(152, "tiles", "Around you", auras, 1, False), (90, "tiles", "Screen", screens, 0, True),
                                (40, "slider", "Max opacity", "70%", 0.666), (40, "slider", "Size", "100%", 0.333),
                                (40, "slider", "Vertical offset", "-20 px", 0.475), (28, "toggle", "Motion", True),
                                (28, "toggle", "Smooth fade", True)])
    return {
        "status": (wx(110), wy(58)),
        "preview": (wx(554), wy(9)),
        "specs": (wx(16), wy(y_specs + 60)),
        "trigger": (wx(16), wy(y_trigger + 70)),
        "patterns": (wx(rx + col), wy(68 + 30 + 76)),
        "screen": (wx(rx + col), wy(68 + 30 + 152 + 45)),
        "sliders": (wx(rx + col), wy(68 + 30 + 152 + 90 + 60)),
    }


# ---------------------------------------------------------------------------
# Scenes (layers from Display.lua)
# ---------------------------------------------------------------------------

LAYERS = {
    "runes": [("glow", 1.25, 0.30, False), ("ring", 1, 0.50, False), ("runes", 1, 0.40, False), ("ring_core", 1, 0.45, True)],
    "halo": [("glow", 1.3, 0.45, False), ("ring_core", 1, 0.40, True)],
    "arcs": [("glow", 1.25, 0.25, False), ("arcs_inner", 1, 0.60, False), ("arcs_outer", 1, 0.45, True)],
    "sigil": [("glow", 1.25, 0.25, False), ("sigil", 1, 0.50, False)],
    "embers": [("glow", 1.25, 0.25, False), ("embers", 1, 0.60, False), ("embers", 0.8, 0.30, True)],
    "edge": [("edge", None, 0.55, False)],
    "corners": [("corners", None, 0.65, False)],
}


def scene(w, h, patterns, color, strength=0.9):
    """A stand-in for the game: a dim floor and a character, with the overlay added on top."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    horizon = 0.42
    sky = np.clip(1 - yy / (h * horizon), 0, 1)[..., None]
    base = np.array([0.10, 0.11, 0.15]) * (1 - sky) + np.array([0.16, 0.17, 0.22]) * sky
    floor = (yy > h * horizon)[..., None] * (0.04 * np.sin(xx / 22) * np.sin(yy / 9))[..., None]
    canvas = np.ones((h, w, 3), np.float32) * base + floor
    vignette = (1 - 0.55 * (((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2) / 2)[..., None]
    canvas *= vignette

    cx, cy = w / 2, h * 0.58
    s = h / 360
    body = (((xx - cx) / (24 * s)) ** 2 + ((yy - cy) / (50 * s)) ** 2) < 1
    shoulders = (((xx - cx) / (40 * s)) ** 2 + ((yy - (cy - 30 * s)) / (16 * s)) ** 2) < 1
    head = (((xx - cx) / (13 * s)) ** 2 + ((yy - (cy - 62 * s)) / (14 * s)) ** 2) < 1
    canvas[body | shoulders | head] = [0.05, 0.05, 0.06]

    rgb = np.array(color) / 255
    light = rgb + (1 - rgb) * 0.5
    d = int(h * 0.55)
    for pattern in patterns:
        for name, size, alpha, is_light in LAYERS[pattern]:
            tint = light if is_light else rgb
            if size is None:
                tex = np.asarray(Image.open(MEDIA / f"{name}.tga").convert("RGBA").resize((w, h), Image.LANCZOS), np.float32) / 255
                canvas += tex[..., :3] * tint * tex[..., 3:4] * alpha * strength
            else:
                n = int(d * size)
                tex = np.asarray(Image.open(MEDIA / f"{name}.tga").convert("RGBA").resize((n, n), Image.LANCZOS), np.float32) / 255
                x0, y0 = int(cx - n / 2), int(cy - 10 * s - n / 2)
                sx0, sy0 = max(0, -x0), max(0, -y0)
                x0, y0 = max(0, x0), max(0, y0)
                region = canvas[y0:y0 + n - sy0, x0:x0 + n - sx0]
                t = tex[sy0:sy0 + region.shape[0], sx0:sx0 + region.shape[1]]
                region += t[..., :3] * tint * t[..., 3:4] * alpha * strength
    return Image.fromarray((np.clip(canvas, 0, 1) * 255).astype(np.uint8))


# ---------------------------------------------------------------------------
# Page
# ---------------------------------------------------------------------------

def callout(c, n, x, y, w, title, body, target, side):
    """A numbered box at (x, y) with a line to `target` on the window."""
    h = 44 + 30 * max(1, len(body) // 52 + 1) + 24
    c.box(x, y, w, h, 10, (20, 20, 24), BORDER, 1.5)
    c.circle(x + 30, y + 32, 15, ACCENT)
    c.text(x + 30, y + 32, str(n), 17, TEXT, "SemiBold", "mm")
    c.text(x + 56, y + 18, title, 26, TEXT, "SemiBold")
    c.wrap(x + 26, y + 62, body, 21, MUTED, w - 52)
    tx, ty = target
    edge = x + w if side == "left" else x
    c.line([(edge, y + 32), (tx, ty)], ACCENT, 2)
    c.circle(tx, ty, 13, ACCENT, (255, 255, 255), 2)
    c.text(tx, ty, str(n), 14, TEXT, "SemiBold", "mm")


def build():
    c = Canvas()

    icon = Image.open(ROOT / "Listing" / "icon-512.png").convert("RGBA").resize((112 * K, 112 * K), Image.LANCZOS)
    c.img.paste(icon, (40 * K, 36 * K), icon)
    c.text(176, 46, "DK Never Overcap RP", 64, TEXT, "SemiBold")
    c.text(178, 124, "A glow builds around you as runic power nears the cap, so you spend it before it's wasted.", 30, MUTED)

    targets = draw_window(c)

    left = [
        (1, "Live status", "Active in your spec, paused in a spec you turned off, or previewing. The version sits next to it.", targets["status"]),
        (3, "Every spec, its own color", "Blood, Frost and Unholy each on or off. Click the dot to pick a color; the overlay and these settings follow it.", targets["specs"]),
        (4, "When it shows", "Fades in from the runic power you choose and is at full strength at the cap. An optional slow pulse just before you cap.", targets["trigger"]),
    ]
    right = [
        (2, "Preview", "See the overlay at full strength right now, without building runic power.", targets["preview"]),
        (5, "Around you, and the screen", "Pick a pattern around your character, a glow across the screen, or one of each. Either can be off.", targets["patterns"]),
        (6, "Soft and smooth", "Opacity, size and position. Patterns turn slowly, and opacity changes glide instead of flashing.", targets["sliders"]),
    ]
    for i, (n, title, body, target) in enumerate(left):
        callout(c, n, 40, 210 + i * 260, 720, title, body, target, "left")
    for i, (n, title, body, target) in enumerate(right):
        callout(c, n, 1800, 210 + i * 260, 720, title, body, target, "right")

    # Scene strip
    shows = [
        ("Rune circle · Blood", ["runes"], COLORS["Blood"]),
        ("Arcs + Edge glow · Frost", ["arcs", "edge"], COLORS["Frost"]),
        ("Embers · Unholy", ["embers"], COLORS["Unholy"]),
        ("Sigil + Corners · Blood", ["sigil", "corners"], COLORS["Blood"]),
    ]
    tw, th, gap = 597, 336, 30
    x = 40
    for label, patterns, color in shows:
        img = scene(tw * K, th * K, patterns, color)
        mask = Image.new("L", img.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], 12 * K, fill=255)
        c.img.paste(img, (x * K, 1006 * K), mask)
        c.box(x, 1006, tw, th, 12, None, BORDER, 1.5)
        pill = font(20, "SemiBold").getlength(label) / K + 28
        c.box(x + 14, 1020, pill, 34, 17, (10, 10, 12))
        c.text(x + 28, 1037, label, 20, TEXT, "SemiBold", "lm")
        x += tw + gap

    c.text(W / 2, 1392, "Quiet and light: nothing runs every frame, and it sleeps on other classes · no chat messages · free on CurseForge and Wago",
           22, MUTED, anchor="mm")
    return c.img.resize((W, H), Image.LANCZOS)


if __name__ == "__main__":
    out = ROOT / "Listing" / "overview.png"
    build().save(out, optimize=True)
    print(out, "written")

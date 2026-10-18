"""Draws the addon's icon: Icon.tga (128x128, for the game), Listing/icon-400.png and
Listing/icon-512.png (for the CurseForge and Wago project pages), and optionally a preview sheet.
Run from the addon folder: python tools/make_icon.py [preview.png]

A round dial with a steel rim: a runic power gauge sweeping toward its cap, dark red at the start
and white-hot at the tip, inside a ring of runes, around a glowing rune. Drawn at 2048 and scaled
down for clean edges."""

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_textures import runes  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
S = 2048  # drawing size
OUT = 128
C = S / 2
K = S / 512  # the design is laid out on 512


def disc(draw, radius, fill):
    draw.ellipse((C - radius, C - radius, C + radius, C + radius), fill=fill)


def mask(radius):
    image = Image.new("L", (S, S), 0)
    ImageDraw.Draw(image).ellipse((C - radius, C - radius, C + radius, C + radius), fill=255)
    return image


def radial(inner, outer, radius):
    """Opaque square whose colour runs from `inner` at the centre to `outer` at `radius`."""
    n = 256
    c = (np.arange(n) + 0.5) - n / 2
    x, y = np.meshgrid(c, c)
    t = np.clip(np.hypot(x, y) / (radius / S * n), 0, 1) ** 1.6
    rgb = np.array(inner) * (1 - t[..., None]) + np.array(outer) * t[..., None]
    img = np.dstack([rgb, np.full((n, n), 255.0)]).astype(np.uint8)
    return Image.fromarray(img, "RGBA").resize((S, S), Image.BICUBIC)


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def tinted(alpha, color):
    """An RGBA layer of one colour with the given alpha (0..1 array)."""
    h, w = alpha.shape
    img = np.zeros((h, w, 4), dtype=np.uint8)
    img[..., :3] = color
    img[..., 3] = np.clip(alpha * 255, 0, 255).astype(np.uint8)
    return Image.fromarray(img, "RGBA")


def glow(layer, radius, strength=1.0):
    blurred = layer.filter(ImageFilter.GaussianBlur(radius))
    if strength != 1.0:
        a = np.asarray(blurred.getchannel("A"), dtype=np.float32) * strength
        blurred.putalpha(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)))
    return blurred


def gauge_layer(fill):
    """A 270-degree arc from bottom-left, clockwise, filled to `fill` (0..1)."""
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    radius = 132 * K
    width = round(34 * K)
    box = (C - radius, C - radius, C + radius, C + radius)
    start, sweep = 135, 270  # PIL angles: 0 = east, clockwise
    d.arc(box, start, start + sweep, fill=(46, 30, 40, 255), width=width)

    dark, red, hot = (120, 14, 30), (235, 40, 52), (255, 226, 214)
    steps = 180
    for i in range(int(steps * fill)):
        t = i / steps
        color = lerp(dark, red, min(1, t / 0.7)) if t < 0.7 else lerp(red, hot, (t - 0.7) / 0.3)
        d.arc(box, start + sweep * t, start + sweep * (t + 1 / steps) + 0.6, fill=color + (255,), width=width)

    # Rounded start, bright tip, and a tick at the cap.
    def at(t, r=radius):
        a = math.radians(start + sweep * t)
        return C + r * math.cos(a), C + r * math.sin(a)

    for t, color in ((0, dark), (fill, hot)):
        x, y = at(t)
        d.ellipse((x - width / 2, y - width / 2, x + width / 2, y + width / 2), fill=color + (255,))
    x1, y1 = at(1, radius - 26 * K)
    x2, y2 = at(1, radius + 26 * K)
    d.line([(x1, y1), (x2, y2)], fill=(200, 200, 210, 255), width=round(8 * K))
    return layer


def rune_glyph():
    """Algiz, the elk-sedge rune: a stem with two arms raised."""
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    w = round(24 * K)
    color = (255, 230, 222, 255)
    top, bottom, fork = C - 64 * K, C + 70 * K, C - 4 * K
    for a, b in (((C, top + 10 * K), (C, bottom)), ((C, fork), (C - 52 * K, top)), ((C, fork), (C + 52 * K, top))):
        d.line([a, b], fill=color, width=w)
        for x, y in (a, b):
            d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=color)
    return layer


def build():
    icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(icon)

    # Rim: a dark outer edge, a steel band, a thin highlight, then the dial.
    disc(draw, 256 * K, (14, 16, 20, 255))
    disc(draw, 250 * K, (92, 99, 110, 255))
    disc(draw, 236 * K, (150, 158, 170, 255))
    disc(draw, 231 * K, (58, 64, 74, 255))
    disc(draw, 224 * K, (10, 13, 18, 255))
    icon.paste(radial((40, 22, 32), (12, 10, 15), 220 * K), (0, 0), mask(220 * K))

    art = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    # Ring of runes just inside the rim.
    band = runes(512, inner=0.70, outer=0.82, count=16, seed=11)
    band = tinted(band, (170, 44, 58)).resize((S, S), Image.BICUBIC)
    art = Image.alpha_composite(art, band)

    # Halo behind the centre.
    halo = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    disc(ImageDraw.Draw(halo), 96 * K, (220, 30, 50, 120))
    art = Image.alpha_composite(art, glow(halo, 60 * K))

    gauge = gauge_layer(0.9)
    art = Image.alpha_composite(art, glow(gauge, 18 * K, 0.7))
    art = Image.alpha_composite(art, gauge)

    glyph = rune_glyph()
    red_glow = glyph.copy()
    red_glow.putalpha(glyph.getchannel("A"))
    tint = Image.new("RGBA", (S, S), (255, 40, 60, 0))
    tint.putalpha(glyph.getchannel("A"))
    art = Image.alpha_composite(art, glow(tint, 22 * K, 1.4))
    art = Image.alpha_composite(art, glyph)

    clipped = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    clipped.paste(art, (0, 0), Image.composite(art.getchannel("A"), Image.new("L", (S, S), 0), mask(220 * K)))
    icon = Image.alpha_composite(icon, clipped)

    # A soft top highlight on the rim, for a little depth.
    shine = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shine).ellipse((C - 250 * K, C - 250 * K, C + 250 * K, C + 250 * K), outline=(255, 255, 255, 46), width=round(5 * K))
    shine.putalpha(Image.composite(shine.getchannel("A"), Image.new("L", (S, S), 0), Image.linear_gradient("L").rotate(180).resize((S, S))))
    return Image.alpha_composite(icon, shine)


def preview(icon, path):
    """The icon at the sizes the game shows it, on dark and light backgrounds."""
    sizes = [128, 64, 32, 20, 16]
    sheet = Image.new("RGBA", (sum(sizes) + 20 * (len(sizes) + 1), 2 * 128 + 60), (24, 24, 28, 255))
    ImageDraw.Draw(sheet).rectangle((0, 128 + 30, sheet.width, sheet.height), fill=(200, 200, 205, 255))
    x = 20
    for size in sizes:
        small = icon.resize((size, size), Image.LANCZOS)
        for row in (0, 1):
            y = 20 + row * (128 + 30) + (128 - size) // 2
            sheet.alpha_composite(small, (x, y))
        x += size + 20
    sheet.save(path)


if __name__ == "__main__":
    drawing = build()
    icon = drawing.resize((OUT, OUT), Image.LANCZOS)
    icon.save(ROOT / "Icon.tga")
    listing = ROOT / "Listing"
    listing.mkdir(exist_ok=True)
    for size in (400, 512):
        drawing.resize((size, size), Image.LANCZOS).save(listing / f"icon-{size}.png", optimize=True)
    if len(sys.argv) > 1:
        preview(icon, sys.argv[1])
    print("Icon.tga and Listing/icon-400.png, icon-512.png written")

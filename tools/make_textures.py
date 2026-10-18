"""Generates the addon's textures into Media/.

Every overlay texture is white with the shape in the alpha channel, so the
addon can tint it per spec with SetVertexColor. Run from the repo root:

    python tools/make_textures.py
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "Media"
RNG = np.random.default_rng(1337)


def grid(size, supersample=1):
    n = size * supersample
    c = (np.arange(n) + 0.5) / n * 2 - 1
    x, y = np.meshgrid(c, -c)
    return x, y, np.hypot(x, y), np.arctan2(y, x)


def downsample(a, factor):
    if factor == 1:
        return a
    h, w = a.shape
    return a.reshape(h // factor, factor, w // factor, factor).mean(axis=(1, 3))


def value_noise(x, y, cells, seed):
    """Smooth 2D value noise sampled at x, y in [-1, 1]."""
    rng = np.random.default_rng(seed)
    lattice = rng.random((cells + 2, cells + 2))
    gx = (x + 1) / 2 * cells
    gy = (y + 1) / 2 * cells
    x0 = np.clip(np.floor(gx).astype(int), 0, cells)
    y0 = np.clip(np.floor(gy).astype(int), 0, cells)
    fx = gx - np.floor(gx)
    fy = gy - np.floor(gy)
    sx = fx * fx * (3 - 2 * fx)
    sy = fy * fy * (3 - 2 * fy)
    a = lattice[y0, x0]
    b = lattice[y0, x0 + 1]
    c = lattice[y0 + 1, x0]
    d = lattice[y0 + 1, x0 + 1]
    return (a * (1 - sx) + b * sx) * (1 - sy) + (c * (1 - sx) + d * sx) * sy


def fbm(x, y, base_cells, octaves, seed):
    total, amp, norm = 0.0, 1.0, 0.0
    for i in range(octaves):
        total = total + amp * value_noise(x, y, base_cells * 2**i, seed + i)
        norm += amp
        amp *= 0.5
    return total / norm


def angular_noise(theta, harmonics, seed):
    """Seamless noise around the circle, in [0, 1]."""
    rng = np.random.default_rng(seed)
    total = np.zeros_like(theta)
    norm = 0.0
    for k in harmonics:
        amp = 1.0 / np.sqrt(k)
        total += amp * np.sin(k * theta + rng.uniform(0, 2 * np.pi))
        norm += amp
    return 0.5 + 0.5 * total / norm


def smoothstep(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def save_alpha(name, alpha, rgb=(255, 255, 255)):
    alpha = np.clip(alpha, 0, 1)
    h, w = alpha.shape
    img = np.zeros((h, w, 4), dtype=np.uint8)
    img[..., 0], img[..., 1], img[..., 2] = rgb
    img[..., 3] = np.round(alpha * 255).astype(np.uint8)
    save_rgba(name, img)


def save_rgba(name, img):
    OUT.mkdir(exist_ok=True)
    Image.fromarray(img, "RGBA").save(OUT / f"{name}.tga")
    print("wrote", OUT / f"{name}.tga")


RING_R = 0.58


def ring():
    """Burning ring: a bright line with flame tongues licking outward."""
    ss = 2
    x, y, r, theta = grid(512, ss)
    line = np.exp(-(((r - RING_R) / 0.010) ** 2))
    halo = 0.35 * np.exp(-(((r - RING_R) / 0.05) ** 2))

    length = 0.04 + 0.26 * angular_noise(theta, range(4, 40, 3), 7) ** 2
    d = np.maximum(r - RING_R, 0)
    texture = fbm(x, y, 8, 4, 21)
    flames = np.exp(-d / length) * (0.15 + 0.85 * texture**1.5) * (r > RING_R)
    inner = 0.30 * np.exp(-np.maximum(RING_R - r, 0) / 0.035) * (r <= RING_R)

    alpha = line + halo + 1.1 * flames + inner
    alpha *= 1 - smoothstep(0.90, 0.99, r)
    save_alpha("ring", downsample(alpha, ss))


def ring_core():
    ss = 2
    _, _, r, theta = grid(512, ss)
    flicker = 0.75 + 0.25 * angular_noise(theta, range(6, 30, 4), 3)
    alpha = np.exp(-(((r - RING_R) / 0.006) ** 2)) * flicker
    save_alpha("ring_core", downsample(alpha, ss))


def glow():
    """Hollow halo behind the character."""
    _, _, r, _ = grid(256)
    alpha = np.exp(-(((r - 0.50) / 0.26) ** 2)) + 0.15 * np.exp(-((r / 0.55) ** 2))
    alpha *= 1 - smoothstep(0.85, 1.0, r)
    save_alpha("glow", alpha / alpha.max())


def runes(size=512, inner=0.78, outer=0.94, count=24, seed=5):
    """A band of angular rune glyphs between two thin circles."""
    ss = 4
    n = size * ss
    img = Image.new("L", (n, n), 0)
    draw = ImageDraw.Draw(img)
    c = n / 2

    def polar(radius, angle):
        return c + radius * c * np.cos(angle), c - radius * c * np.sin(angle)

    def circle(radius, width):
        rr = radius * c
        draw.ellipse([c - rr, c - rr, c + rr, c + rr], outline=255, width=width)

    stroke = max(2, int(n * 0.0045))
    circle(inner, stroke)
    circle(outer, stroke)

    rng = np.random.default_rng(seed)
    mid = (inner + outer) / 2
    half_h = (outer - inner) * 0.30
    step = 2 * np.pi / count
    # Glyph points on a 3x3 grid: radial offset (-1..1) x tangential (-1..1).
    for i in range(count):
        base = i * step
        half_w = step * 0.22

        def pt(gr, gt):
            return polar(mid + gr * half_h, base + gt * half_w)

        segments = [((-1, 0), (1, 0))]  # stem
        options = [
            ((1, 0), (0, 1)), ((1, 0), (0, -1)), ((0, 0), (-1, 1)), ((0, 0), (-1, -1)),
            ((1, -1), (1, 1)), ((-1, -1), (-1, 1)), ((0, -1), (0, 1)), ((1, 1), (-1, 1)),
            ((0, 1), (-1, 0)), ((0, -1), (-1, 0)),
        ]
        for j in rng.choice(len(options), size=rng.integers(2, 4), replace=False):
            segments.append(options[j])
        for a, b in segments:
            draw.line([pt(*a), pt(*b)], fill=255, width=stroke)
        # Diamond separator between glyphs.
        sep = base + step / 2
        dr, dt = 0.012, step * 0.06
        draw.polygon([polar(mid + dr, sep), polar(mid, sep + dt), polar(mid - dr, sep), polar(mid, sep - dt)], fill=255)

    sharp = np.asarray(img, dtype=np.float32) / 255
    blurred = np.asarray(img.filter(ImageFilter.GaussianBlur(n * 0.006)), dtype=np.float32) / 255
    alpha = np.clip(sharp * 0.9 + blurred * 1.4, 0, 1)
    return downsample(alpha, ss)


def vignette():
    """Screen-edge glow, stretched over the whole screen."""
    w, h = 512, 256
    u = (np.arange(w) + 0.5) / w
    v = (np.arange(h) + 0.5) / h
    uu, vv = np.meshgrid(u, v)
    ex = np.minimum(uu, 1 - uu) * 2
    ey = np.minimum(vv, 1 - vv) * 2
    ax = 1 - smoothstep(0.0, 0.16, ex)
    ay = 1 - smoothstep(0.0, 0.26, ey)
    a = 1 - (1 - ax) * (1 - ay)
    smoke = fbm(uu * 2 - 1, vv * 2 - 1, 5, 4, 99)
    alpha = a**2.2 * (0.35 + 0.65 * smoke**1.3)
    save_alpha("edge", alpha)


def corners():
    """Glow pooled in the four screen corners."""
    w, h = 512, 256
    u = (np.arange(w) + 0.5) / w
    v = (np.arange(h) + 0.5) / h
    uu, vv = np.meshgrid(u, v)
    dx = np.minimum(uu, 1 - uu) * 1.6
    dy = np.minimum(vv, 1 - vv)
    d = np.hypot(dx, dy)
    a = (1 - smoothstep(0.0, 0.42, d)) ** 2
    smoke = fbm(uu * 2 - 1, vv * 2 - 1, 5, 4, 71)
    save_alpha("corners", a * (0.4 + 0.6 * smoke**1.2))


def glow_lines(draw_fn, size=512, blur=0.006, sharp_weight=0.85, glow_weight=1.3):
    """Draws with draw_fn(draw, n, polar) at 4x, then adds a soft glow."""
    ss = 4
    n = size * ss
    img = Image.new("L", (n, n), 0)
    draw = ImageDraw.Draw(img)
    c = n / 2

    def polar(radius, angle):
        return c + radius * c * np.cos(angle), c - radius * c * np.sin(angle)

    draw_fn(draw, n, polar)
    sharp = np.asarray(img, dtype=np.float32) / 255
    blurred = np.asarray(img.filter(ImageFilter.GaussianBlur(n * blur)), dtype=np.float32) / 255
    return downsample(np.clip(sharp * sharp_weight + blurred * glow_weight, 0, 1), ss)


def arc_mask(theta, count, span, start, taper):
    """1 inside `count` arcs of `span` radians, tapering at the ends."""
    period = 2 * np.pi / count
    local = np.mod(theta - start, period)
    edge = np.minimum(local, span - local)
    return np.where(local <= span, smoothstep(0, taper, edge), 0.0)


def arcs_inner():
    ss = 2
    _, _, r, theta = grid(512, ss)
    band = np.exp(-(((r - 0.60) / 0.016) ** 2)) + 0.35 * np.exp(-(((r - 0.60) / 0.05) ** 2))
    save_alpha("arcs_inner", downsample(band * arc_mask(theta, 3, np.radians(78), 0.3, np.radians(14)), ss))


def arcs_outer():
    ss = 2
    _, _, r, theta = grid(512, ss)
    line = np.exp(-(((r - 0.71) / 0.006) ** 2)) * arc_mask(theta, 4, np.radians(58), 1.0, np.radians(6))
    ticks_angle = np.mod(theta, np.radians(6))
    ticks = (np.minimum(ticks_angle, np.radians(6) - ticks_angle) < np.radians(0.5)) * ((r > 0.75) & (r < 0.78))
    ticks = ticks * arc_mask(theta, 2, np.radians(100), 2.2, np.radians(20)) * 0.6
    save_alpha("arcs_outer", downsample(line + ticks, ss))


def sigil():
    def draw_fn(draw, n, polar):
        stroke = max(2, int(n * 0.004))
        c = n / 2
        for radius in (0.80, 0.30):
            rr = radius * c
            draw.ellipse([c - rr, c - rr, c + rr, c + rr], outline=255, width=stroke)
        for offset in (np.pi / 2, -np.pi / 2):
            pts = [polar(0.68, offset + k * 2 * np.pi / 3) for k in range(3)]
            draw.line(pts + [pts[0]], fill=255, width=stroke)
        for k in range(6):
            x, y = polar(0.68, np.pi / 2 + k * np.pi / 3)
            rr = 0.035 * c
            draw.ellipse([x - rr, y - rr, x + rr, y + rr], outline=255, width=stroke)
            x, y = polar(0.80, np.pi / 2 + k * np.pi / 3 + np.pi / 6)
            rr = 0.012 * c
            draw.ellipse([x - rr, y - rr, x + rr, y + rr], fill=255)
    save_alpha("sigil", glow_lines(draw_fn))


def embers():
    rng = np.random.default_rng(42)

    def draw_fn(draw, n, polar):
        c = n / 2
        for _ in range(170):
            radius = rng.normal(0.62, 0.075)
            angle = rng.uniform(0, 2 * np.pi)
            size = rng.uniform(0.004, 0.013) * c
            x, y = polar(radius, angle)
            draw.ellipse([x - size, y - size, x + size, y + size], fill=int(rng.uniform(110, 255)))
    save_alpha("embers", glow_lines(draw_fn, blur=0.008, sharp_weight=0.8, glow_weight=1.6))


def circle(size, name):
    """Antialiased disc. UI shapes pick the size closest to 2x their draw size."""
    ss = 8
    _, _, r, _ = grid(size, ss)
    save_alpha(name, downsample((r <= 1.0).astype(np.float32), ss))


def logo():
    size = 128
    ss = 2
    _, _, r, theta = grid(size, ss)
    bg = downsample(((r <= 0.98).astype(np.float32)), ss)
    rune = runes(size * ss, inner=0.74, outer=0.96, count=12, seed=9)
    rune = downsample(rune, ss)
    _, _, r1, theta1 = grid(size)
    core = np.exp(-(((r1 - 0.52) / 0.035) ** 2))
    halo = 0.6 * np.exp(-(((r1 - 0.52) / 0.16) ** 2))

    red = np.array([255, 40, 55], dtype=np.float32)
    dark = np.array([18, 10, 14], dtype=np.float32)
    glow_a = np.clip(rune + core + halo, 0, 1)[..., None]
    white_hot = np.clip(core, 0, 1)[..., None] * 0.6
    rgb = dark * (1 - glow_a) + red * glow_a
    rgb = rgb * (1 - white_hot) + 255 * white_hot
    img = np.zeros((size, size, 4), dtype=np.uint8)
    img[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    img[..., 3] = np.round(bg * 255).astype(np.uint8)
    save_rgba("logo", img)


if __name__ == "__main__":
    ring()
    ring_core()
    glow()
    save_alpha("runes", runes())
    vignette()
    corners()
    arcs_inner()
    arcs_outer()
    sigil()
    embers()
    circle(64, "circle")
    circle(32, "circle32")
    logo()

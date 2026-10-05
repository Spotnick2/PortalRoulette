"""Generate Portal Roulette's procedural art (never hand-edit the outputs).

    python Tools/make_art.py

Writes uncompressed 32-bit TGAs (bottom-left origin, power-of-two sizes) to
Media/Glass/:
  RuneBand_512.tga  a ring of etched runes between two hairline circles,
                    white with the shape in alpha (tinted and rotated in game)
  Spark_64.tga      a soft round spark for the energy running along links
  Glow_128.tga      a soft radial glow (hover halo behind beads)
Requires Pillow and numpy.
"""

import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "Media", "Glass")


def save_tga(alpha, name):
    """White everywhere, shape only in alpha (filtering cannot bleed colour)."""
    h, w = alpha.shape
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[..., 0:3] = 255
    rgba[..., 3] = np.clip(alpha * 255.0, 0, 255).astype(np.uint8)
    img = Image.fromarray(rgba, "RGBA")
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name), compression=None)
    print("wrote", name)


def rune_band(size=512, seed=7):
    """Runes drawn at 4x, blurred a touch, downsampled: soft, etched strokes."""
    rng = random.Random(seed)
    scale = 4
    s = size * scale
    img = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(img)
    c = s / 2
    r_out, r_in = 0.97 * c, 0.86 * c
    line_w = int(1.8 * scale)
    # Hairline circles bounding the band.
    for r, a in ((r_out, 150), (r_in, 150), ((r_out + r_in) / 2 + 0.035 * c, 40)):
        d.ellipse([c - r, c - r, c + r, c + r], outline=a, width=line_w)
    # Runes: each a few strokes on a small grid, placed around the ring.
    count = 28
    glyph_h = (r_out - r_in) * 0.62
    for i in range(count):
        ang = 2 * math.pi * i / count
        mid = (r_out + r_in) / 2
        gx, gy = c + math.cos(ang) * mid, c + math.sin(ang) * mid
        # Local frame: "up" points outward from the centre.
        ux, uy = math.cos(ang), math.sin(ang)
        vx, vy = -uy, ux
        pts = [(-0.5, -0.5), (0, -0.5), (0.5, -0.5), (-0.5, 0), (0, 0), (0.5, 0),
               (-0.5, 0.5), (0, 0.5), (0.5, 0.5)]
        strokes = rng.randint(3, 5)
        for _ in range(strokes):
            a, b = rng.sample(pts, 2)
            ax = gx + (a[0] * vx * 0.7 + a[1] * ux) * glyph_h
            ay = gy + (a[0] * vy * 0.7 + a[1] * uy) * glyph_h
            bx = gx + (b[0] * vx * 0.7 + b[1] * ux) * glyph_h
            by = gy + (b[0] * vy * 0.7 + b[1] * uy) * glyph_h
            d.line([ax, ay, bx, by], fill=230, width=line_w)
        # A dot between runes.
        da = ang + math.pi / count
        dx, dy = c + math.cos(da) * mid, c + math.sin(da) * mid
        rr = 1.6 * scale
        d.ellipse([dx - rr, dy - rr, dx + rr, dy + rr], fill=170)
    img = img.filter(ImageFilter.GaussianBlur(scale * 0.6))
    img = img.resize((size, size), Image.LANCZOS)
    return np.asarray(img, dtype=np.float32) / 255.0


def radial(size, power):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2
    r = np.sqrt((x - c) ** 2 + (y - c) ** 2) / c
    return np.clip(1 - r, 0, 1) ** power


def value_noise(size, cells, seed):
    """Smooth value noise in [0, 1]: random grid upsampled bicubically."""
    rng = np.random.RandomState(seed)
    grid = (rng.rand(cells, cells) * 255).astype(np.uint8)
    img = Image.fromarray(grid, "L").resize((size, size), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255.0


def fractal(size, seed, octaves=4, base=4):
    total, amp, norm = np.zeros((size, size), np.float32), 1.0, 0.0
    for o in range(octaves):
        total += amp * value_noise(size, base * (2 ** o), seed + o)
        norm += amp
        amp *= 0.5
    return total / norm


def wisps(size=512, seed=11, arms=5, twist=2.6, sharp=10.0):
    """Translucent broken energy strands circulating around the centre: thin
    bright filaments with feathered edges and transparent gaps, no blades.
    Strands follow a gentle log spiral, warped by noise so no two are alike;
    a second noise field carves gaps and varies brightness along them."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2
    dx, dy = (x - c) / c, (y - c) / c
    r = np.sqrt(dx * dx + dy * dy) + 1e-6
    theta = np.arctan2(dy, dx)
    warp = (fractal(size, seed, 4, 3) - 0.5) * 2.4
    phase = arms * (theta + twist * np.log(r + 0.08)) + warp * 2.2
    strands = (0.5 + 0.5 * np.cos(phase)) ** sharp           # thin filaments
    fine = (0.5 + 0.5 * np.cos(phase * 3.0 + warp * 4)) ** (sharp * 2.5) * 0.6
    gaps = np.clip((fractal(size, seed + 50, 4, 4) - 0.35) * 2.2, 0, 1)
    shimmer = 0.55 + 0.45 * fractal(size, seed + 90, 3, 8)
    # Clear under the orb and fade before the rim.
    window = np.clip((r - 0.2) / 0.18, 0, 1) * np.clip((0.96 - r) / 0.25, 0, 1)
    a = (strands + fine) * gaps * shimmer * window
    halo = np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "L")
                      .filter(ImageFilter.GaussianBlur(size / 90)), np.float32) / 255.0
    return np.clip(a * 0.85 + halo * 0.5, 0, 1)


def motes(size=512, seed=23, count=26):
    rng = random.Random(seed)
    a = np.zeros((size, size), np.float32)
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2
    for _ in range(count):
        ang = rng.uniform(0, 2 * math.pi)
        rad = rng.uniform(0.3, 0.9) * c
        px, py = c + math.cos(ang) * rad, c + math.sin(ang) * rad
        sz = rng.uniform(1.2, 3.2)
        a = np.maximum(a, rng.uniform(0.5, 1.0) * np.exp(-((x - px) ** 2 + (y - py) ** 2) / (2 * sz * sz)))
    return a


def node_ring(size=128, width=0.035, glow=0.10):
    """A thin luminous edge with a soft falloff on both sides, for beads."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2
    r = np.sqrt((x - c) ** 2 + (y - c) ** 2) / c
    edge = 0.86
    core = np.exp(-((r - edge) / width) ** 2)
    soft = np.exp(-((r - edge) / glow) ** 2) * 0.35
    return np.clip(core + soft, 0, 1)


def specular(size=64):
    """A small soft highlight crescent for the upper-left of a bead."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2
    r = np.sqrt((x - c) ** 2 + (y - c) ** 2) / c
    # Upper-left in image space (top row is the top of the texture once
    # written bottom-left: PIL writes TGAs top-down rows correctly).
    ang = np.arctan2(-(y - c), (x - c))                    # 0 = right, +90 = up
    centre = math.radians(135)
    d = np.angle(np.exp(1j * (ang - centre)))
    arc = np.exp(-(d / 0.45) ** 2)
    band = np.exp(-((r - 0.78) / 0.07) ** 2)
    return np.clip(arc * band, 0, 1)


def link_glow(w=256, h=32):
    """A link's light across its width: crisp core, translucent body, faint
    feathered halo; fades into both ends along its length."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    v = np.abs((y - (h - 1) / 2) / ((h - 1) / 2))          # 0 centre, 1 edge
    across = np.exp(-(v / 0.06) ** 2) * 1.0 + np.exp(-(v / 0.22) ** 2) * 0.35 + np.exp(-(v / 0.7) ** 2) * 0.10
    u = x / (w - 1)
    along = np.clip(u / 0.12, 0, 1) * np.clip((1 - u) / 0.12, 0, 1)
    return np.clip(across * along, 0, 1)


def comet(size=64):
    """A traveling pulse pointing right: bright head, short soft tail. Square,
    so it can be turned to a link's angle with Texture:SetRotation without
    clipping its ends."""
    w = h = size
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    v = np.abs((y - (h - 1) / 2) / ((h - 1) / 2)) * 5.0     # thin across
    u = x / (w - 1)
    head = np.exp(-((u - 0.82) / 0.07) ** 2)
    tail = np.clip((u - 0.25) / 0.57, 0, 1) ** 2 * (u < 0.82)
    along = np.maximum(head, tail * 0.7)
    across = np.exp(-(v / 0.18) ** 2) + np.exp(-(v / 0.5) ** 2) * 0.25
    return np.clip(along * across, 0, 1)


def shimmer(size=256):
    """A soft narrow diagonal light streak (top-left to bottom-right band),
    swept across the disc now and then."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2
    # Distance from the anti-diagonal line through the centre.
    d = ((x - c) + (y - c)) / (size * 0.7071)
    band = np.exp(-(d / 0.035) ** 2) + np.exp(-(d / 0.12) ** 2) * 0.25
    # Fade toward the ends of the streak.
    t = ((x - c) - (y - c)) / (size * 1.414) * 2
    ends = np.clip(1 - np.abs(t), 0, 1) ** 0.7
    return np.clip(band * ends, 0, 1)


def orbit_dots(size=512, radius=0.9):
    """A few small bright dots on the outer ring, unevenly spaced, each with a
    short faint trail behind it (counter-clockwise in texture space, so the
    trail follows when the layer turns clockwise)."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2
    a = np.zeros((size, size), np.float32)
    for deg, bright in ((0, 1.0), (14, 0.7), (118, 0.9), (205, 1.0), (222, 0.6), (300, 0.8)):
        for k in range(6):                      # the dot, then its trail
            ang = math.radians(deg + k * 1.6)
            px, py = c + math.cos(ang) * radius * c, c - math.sin(ang) * radius * c
            sz = 2.4 - k * 0.25
            w = bright * (1.0 if k == 0 else 0.35 * (1 - k / 6))
            a = np.maximum(a, w * np.exp(-((x - px) ** 2 + (y - py) ** 2) / (2 * sz * sz)))
    return a


def main():
    save_tga(rune_band(), "RuneBand_512.tga")
    save_tga(radial(64, 2.2), "Spark_64.tga")
    save_tga(radial(128, 1.6), "Glow_128.tga")
    save_tga(wisps(seed=11, arms=5, twist=2.6), "WispsA_512.tga")
    save_tga(wisps(seed=37, arms=3, twist=-1.9, sharp=14.0), "WispsB_512.tga")
    save_tga(motes(), "Motes_512.tga")
    save_tga(node_ring(), "NodeRing_128.tga")
    save_tga(specular(), "Specular_64.tga")
    save_tga(link_glow(), "LinkGlow_256x32.tga")
    save_tga(comet(), "Comet_64.tga")
    save_tga(shimmer(), "Shimmer_256.tga")
    save_tga(orbit_dots(), "OrbitDots_512.tga")


if __name__ == "__main__":
    main()

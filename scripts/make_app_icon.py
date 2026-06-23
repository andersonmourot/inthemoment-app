#!/usr/bin/env python3
"""Generate InTheMoment's app icon (original artwork, no third-party assets).

Design: a camera aperture / iris — a generic geometric form, not trademarked —
rendered in white over the app's purple brand gradient, with a play triangle in
the lens opening to signal both photo and video. Rendered at high resolution and
downscaled for clean, anti-aliased edges.
"""
import math
from PIL import Image, ImageDraw

OUT = "App/InTheMoment/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
FINAL = 1024
SS = 4               # supersample factor
S = FINAL * SS
CX = CY = S / 2

# Brand palette (purple accent used across the app).
TOP = (139, 92, 246)     # #8B5CF6
BOTTOM = (76, 29, 149)    # #4C1D95
WHITE = (255, 255, 255)


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vertical_gradient(size, top, bottom):
    img = Image.new("RGB", (size, size), top)
    px = img.load()
    for y in range(size):
        c = lerp(top, bottom, y / (size - 1))
        for x in range(size):
            px[x, y] = c
    return img


def poly(cx, cy, r, n, rot=0.0):
    return [
        (cx + r * math.cos(rot + 2 * math.pi * k / n),
         cy + r * math.sin(rot + 2 * math.pi * k / n))
        for k in range(n)
    ]


def main():
    base = vertical_gradient(S, TOP, BOTTOM).convert("RGBA")

    # --- white iris disc with a soft top-down sheen ---
    R = S * 0.34
    disc = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dd = ImageDraw.Draw(disc)
    dd.ellipse([CX - R, CY - R, CX + R, CY + R], fill=WHITE + (255,))

    sheen = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = sheen.load()
    for y in range(int(CY - R), int(CY + R) + 1):
        t = (y - (CY - R)) / (2 * R)
        a = int(46 * t)  # subtle darkening toward the bottom for depth
        for x in range(int(CX - R), int(CX + R) + 1):
            sd[x, y] = (40, 10, 70, a)
    disc.alpha_composite(Image.composite(
        sheen, Image.new("RGBA", (S, S), (0, 0, 0, 0)),
        disc.split()[3]))

    # --- aperture blade lines: each tangent to the central hexagon, ---
    # drawn on their own layer then clipped to the disc so nothing bleeds out.
    r_hex = S * 0.135
    rot = -math.pi / 2  # pointy top
    hexv = poly(CX, CY, r_hex, 6, rot)
    bladelayer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bld = ImageDraw.Draw(bladelayer)
    lw = int(S * 0.011)
    for k in range(6):
        ax, ay = hexv[k]
        bx, by = hexv[(k + 1) % 6]
        dx, dy = bx - ax, by - ay
        d = math.hypot(dx, dy)
        ux, uy = dx / d, dy / d
        # extend the hexagon edge outward; clipping keeps it inside the lens
        ex, ey = bx + ux * R * 1.4, by + uy * R * 1.4
        bld.line([(ax, ay), (ex, ey)], fill=(74, 30, 130, 165), width=lw)
    discmask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(discmask).ellipse([CX - R, CY - R, CX + R, CY + R], fill=255)
    disc.alpha_composite(Image.composite(
        bladelayer, Image.new("RGBA", (S, S), (0, 0, 0, 0)), discmask))

    # punch the hexagon hole so the purple lens opening shows through
    holemask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(holemask).polygon(hexv, fill=255)
    da = disc.split()[3]
    da = Image.composite(Image.new("L", (S, S), 0), da, holemask)
    disc.putalpha(da)

    base.alpha_composite(disc)

    # --- play triangle in the lens opening (photo + video) ---
    tri_r = r_hex * 0.62
    tri = [
        (CX - tri_r * 0.5, CY - tri_r * 0.86),
        (CX - tri_r * 0.5, CY + tri_r * 0.86),
        (CX + tri_r, CY),
    ]
    ImageDraw.Draw(base).polygon(tri, fill=WHITE + (255,))

    out = base.convert("RGB").resize((FINAL, FINAL), Image.LANCZOS)
    out.save(OUT)
    print("wrote", OUT, out.size)


if __name__ == "__main__":
    main()

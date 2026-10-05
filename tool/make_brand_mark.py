"""Nazorat AAT brand mark generator.

Draws a heater shield carrying a check mark over three service glyphs:
leaf (karantin), medical cross (veterinariya), flask (SES).

Rendered at 4x and downsampled so every edge is antialiased.
"""

import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "out")
os.makedirs(OUT, exist_ok=True)

S = 4096  # supersample canvas
FINAL = 1024

GREEN = (46, 125, 50, 255)  # kGreen #2E7D32
GREEN_DEEP = (27, 94, 32, 255)  # #1B5E20
WHITE = (255, 255, 255, 255)
TRANSPARENT = (0, 0, 0, 0)


# ---------------------------------------------------------------- geometry


def quad(p0, p1, p2, steps=160):
    """Quadratic bezier sample points."""
    out = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        out.append(
            (
                u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
                u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1],
            )
        )
    return out


def arc_points(cx, cy, r, a0, a1, steps=48):
    out = []
    for i in range(steps + 1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        out.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return out


def shield_path(cx, top, w, h, corner=0.085):
    """Heater shield outline, clockwise from the top-left corner.

    The bottom tip is rounded by a hair so the two flanks meet in a clean
    point instead of the ragged notch a true cusp leaves after downsampling.
    """
    half = w / 2
    cr = w * corner
    left, right = cx - half, cx + half
    shoulder = top + h * 0.47  # where the straight sides end
    tip = top + h

    pts = []
    # top edge (rounded corners)
    pts += arc_points(left + cr, top + cr, cr, 180, 270)
    pts += arc_points(right - cr, top + cr, cr, 270, 360)
    # right side down to the shoulder
    pts.append((right, shoulder))
    # right flank sweeping into the bottom point
    pts += quad((right, shoulder), (right, top + h * 0.85), (cx, tip))
    # left flank back up
    pts += quad((cx, tip), (left, top + h * 0.85), (left, shoulder))
    pts.append((left, top + cr))
    return pts


def fill_shield(d, pts, colour, soften):
    """Fill a shield path and round its apex.

    Stroking the outline in the fill colour is what rounds the bottom cusp;
    the stroke is invisible everywhere else because it matches the fill.
    """
    d.polygon(pts, fill=colour)
    d.line(pts + [pts[0]], fill=colour, width=max(1, int(soften)), joint="curve")


def scale_path(pts, f, dx=0.0, dy=0.0):
    return [(x * f + dx, y * f + dy) for x, y in pts]


# ------------------------------------------------------------------ glyphs


def draw_leaf(d, cx, cy, size, fill, cut=None):
    """Pointed oval leaf tilted 45 degrees, split by a midrib."""
    a = size * 0.56  # long half-axis
    b = size * 0.30  # short half-axis
    ang = math.radians(-45)
    ca, sa = math.cos(ang), math.sin(ang)

    def place(x, y):
        return (cx + x * ca - y * sa, cy + x * sa + y * ca)

    pts = []
    for i in range(121):
        t = math.radians(i * 3)
        # lens shape: taper both ends to a point
        x = a * math.cos(t)
        y = b * math.sin(t) * (1 - abs(math.cos(t)) ** 3)
        pts.append(place(x, y))
    d.polygon(pts, fill=fill)

    # midrib, knocked out of the leaf so it reads as a leaf and not a blob
    if cut is not None:
        d.line(
            [place(-a * 0.82, 0), place(a * 0.82, 0)],
            fill=cut,
            width=max(1, int(size * 0.085)),
        )


def draw_cross(d, cx, cy, size, fill):
    """Equal-armed medical cross."""
    arm = size * 0.50
    th = size * 0.21
    r = th * 0.32
    d.rounded_rectangle([cx - th, cy - arm, cx + th, cy + arm], radius=r, fill=fill)
    d.rounded_rectangle([cx - arm, cy - th, cx + arm, cy + th], radius=r, fill=fill)


def draw_flask(d, cx, cy, size, fill):
    """Erlenmeyer flask: neck, shoulders, splayed body."""
    h = size * 1.00
    top = cy - h * 0.50
    bot = cy + h * 0.50
    neck_w = size * 0.17
    body_w = size * 0.48
    neck_bot = top + h * 0.34

    d.polygon(
        [
            (cx - neck_w, top),
            (cx + neck_w, top),
            (cx + neck_w, neck_bot),
            (cx + body_w, bot),
            (cx - body_w, bot),
            (cx - neck_w, neck_bot),
        ],
        fill=fill,
    )
    # lip
    d.rounded_rectangle(
        [cx - neck_w * 1.75, top - size * 0.10, cx + neck_w * 1.75, top + size * 0.06],
        radius=size * 0.05,
        fill=fill,
    )


def draw_check(d, cx, cy, size, fill):
    """Bold check mark centred on (cx, cy)."""
    w = int(size * 0.30)
    pts = [
        (cx - size * 0.52, cy + size * 0.02),
        (cx - size * 0.15, cy + size * 0.40),
        (cx + size * 0.54, cy - size * 0.42),
    ]
    d.line(pts, fill=fill, width=w, joint="curve")
    for p in (pts[0], pts[2]):
        d.ellipse([p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2], fill=fill)


# ------------------------------------------------------------------- marks


def draw_mark(d, cx, top, w, h, body, ink, keyline=None, keyline_w=0.0):
    """Shield filled with `body`, contents drawn in `ink`.

    A keyline is two nested shields rather than a stroked path — stroking the
    sampled outline leaves bumps wherever the sample points bunch up.
    """
    soften = w * 0.030
    if keyline is not None and keyline_w > 0:
        fill_shield(d, shield_path(cx, top, w, h), keyline, soften)
        k = keyline_w
        fill_shield(
            d, shield_path(cx, top + k, w - 2 * k, h - 2.4 * k), body, soften
        )
    else:
        fill_shield(d, shield_path(cx, top, w, h), body, soften)

    # check mark sits in the upper chamber
    draw_check(d, cx, top + h * 0.355, w * 0.42, ink)

    # divider
    dy = top + h * 0.585
    d.rounded_rectangle(
        [cx - w * 0.25, dy - w * 0.013, cx + w * 0.25, dy + w * 0.013],
        radius=w * 0.013,
        fill=ink,
    )

    # three service glyphs
    gy = top + h * 0.715
    gap = w * 0.225
    gsz = w * 0.170
    draw_leaf(d, cx - gap, gy, gsz, ink, cut=body)
    draw_cross(d, cx, gy, gsz, ink)
    draw_flask(d, cx + gap, gy, gsz, ink)


def render(size, draw_bg, body, ink, keyline=None, inset=0.5):
    """`inset` = fraction of the canvas width the shield spans."""
    img = Image.new("RGBA", (S, S), TRANSPARENT)
    d = ImageDraw.Draw(img)

    if draw_bg:
        # vertical green gradient, full bleed
        grad = Image.new("RGBA", (1, S))
        gd = ImageDraw.Draw(grad)
        for y in range(S):
            t = y / S
            gd.point(
                (0, y),
                fill=tuple(
                    int(GREEN[i] + (GREEN_DEEP[i] - GREEN[i]) * t) for i in range(4)
                ),
            )
        img = grad.resize((S, S))
        d = ImageDraw.Draw(img)

    w = S * inset
    h = w * 1.22
    cx = S / 2
    top = (S - h) / 2

    draw_mark(d, cx, top, w, h, body, ink, keyline, keyline_w=w * 0.052)
    return img.resize((size, size), Image.LANCZOS)


def save(img, name):
    path = os.path.join(OUT, name)
    img.save(path)
    print(f"{name}: {img.size[0]}x{img.size[1]}  {os.path.getsize(path) // 1024} KB")


if __name__ == "__main__":
    # Store / launcher icon: green field, white shield, green contents.
    save(render(FINAL, True, WHITE, GREEN_DEEP, inset=0.60), "app_icon.png")

    # Adaptive foreground: same mark, transparent, pulled into the safe zone.
    save(
        render(FINAL, False, WHITE, GREEN_DEEP, keyline=GREEN_DEEP, inset=0.48),
        "app_icon_foreground.png",
    )

    # Android 13 themed icon: single-colour silhouette.
    save(render(FINAL, False, WHITE, (0, 0, 0, 0), inset=0.48), "app_icon_monochrome.png")

    # In-app logo: works on green splash, light login and dark login alike.
    save(
        render(FINAL, False, WHITE, GREEN, keyline=GREEN, inset=0.72),
        "nazorat_logo.png",
    )

    # Square variant for the Android 12 splash slot.
    sq = Image.new("RGBA", (FINAL, FINAL), TRANSPARENT)
    mark = render(int(FINAL * 0.62), False, WHITE, GREEN, keyline=GREEN, inset=0.95)
    sq.paste(mark, ((FINAL - mark.size[0]) // 2, (FINAL - mark.size[1]) // 2), mark)
    save(sq, "nazorat_logo_square.png")

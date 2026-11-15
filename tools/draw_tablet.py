"""Draws the JTAC tablet: the body, its home key and LEDs, and the screen icons.

    python draw_tablet.py <png dir>

The body follows the front of a 7" rugged tablet (Panasonic FZ-M1 operating
instructions, "Description of Parts"): 203 x 132 mm, a 16:10 screen of
150.8 x 94.2 mm, rubber antenna bumpers on both ends, antenna caps top and
bottom left, the camera above the screen, three LEDs at the top right and a
home key under the screen.

Coordinates are design pixels of a 1920x1080 screen at 7.5 px/mm; ui.sqf
places the controls at the same rectangles.
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

F = np.float32
LIGHT = np.array([-0.4, -0.75, 0.55], F)
LIGHT /= np.linalg.norm(LIGHT)

BODY = (199, 45, 1721, 1035)
SCREEN = (395, 187, 1526, 894)
PANEL = (229, 67, 1691, 1013)
BUMPERS = ((191, 180, 279, 901), (1641, 180, 1729, 901))
CAPS = ((386, 37, 566, 75), (386, 1005, 566, 1043))
LEDS = ((1592, 214), (1592, 246), (1592, 278))
LED_PANEL = (1550, 196, 1610, 296)
HOME = (928, 916, 992, 952)
HOME_TEX = (918, 913, 1002, 955)
BODY_TEX = (-50, 35, 1970, 1045)

SHELL = (0.2, 0.205, 0.215)
RUBBER = (0.095, 0.097, 0.1)
GLASS = (0.045, 0.048, 0.055)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


class Canvas:
    def __init__(self, x0, y0, w, h, k):
        self.k = k
        n, m = int(round(h * k)), int(round(w * k))
        yy, xx = np.mgrid[0:n, 0:m].astype(F)
        self.x = x0 + (xx + 0.5) / k
        self.y = y0 + (yy + 0.5) / k
        self.c = np.zeros((n, m, 3), F)
        self.a = np.zeros((n, m), F)

    def cov(self, d):
        return np.clip(0.5 - d * self.k, 0, 1).astype(F)

    def over(self, rgb, a):
        rgb = np.asarray(rgb, F)
        if rgb.ndim == 1:
            rgb = rgb.reshape(1, 1, 3)
        a = np.asarray(a, F)
        self.c = rgb * a[..., None] + self.c * (1 - a[..., None])
        self.a = a + self.a * (1 - a)

    def shadow(self, mask, dx, dy, sigma, alpha):
        m = ndimage.gaussian_filter(mask, sigma * self.k)
        m = ndimage.shift(m, (dy * self.k, dx * self.k), order=1)
        self.over((0, 0, 0), np.clip(m * alpha, 0, 1))

    def noise(self, sigma, seed):
        r = np.random.default_rng(seed).standard_normal(self.a.shape).astype(F)
        s = sigma * self.k
        if s > 0.3:
            r = ndimage.gaussian_filter(r, s)
        return r / (r.std() + 1e-6)

    def shade(self, h):
        gy, gx = np.gradient(h * self.k)
        n = np.dstack([-gx, -gy, np.ones_like(gx)])
        n /= np.linalg.norm(n, axis=2, keepdims=True)
        return (n @ LIGHT - LIGHT[2]).astype(F)

    def save(self, path, size=None):
        a = np.maximum(self.a, 1e-6)[..., None]
        rgba = np.dstack([np.clip(self.c / a, 0, 1), np.clip(self.a, 0, 1)])
        img = Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA")
        if size and img.size != size:
            img = img.resize(size, Image.LANCZOS)
        img.save(path)


def rrect(c, box, r):
    x0, y0, x1, y1 = box
    cx, cy, hw, hh = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    qx, qy = np.abs(c.x - cx) - hw, np.abs(c.y - cy) - hh
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def circle(c, cx, cy, r):
    return np.hypot(c.x - cx, c.y - cy) - r


def segment(c, ax, ay, bx, by, r):
    px, py, vx, vy = c.x - ax, c.y - ay, bx - ax, by - ay
    t = np.clip((px * vx + py * vy) / max(vx * vx + vy * vy, 1e-6), 0, 1)
    return np.hypot(px - vx * t, py - vy * t) - r


def tint(v, rgb):
    return np.clip(v, 0, 1)[..., None] * np.array(rgb, F)


def dome(c, d, height):
    """Height of a rounded edge falling off over `height` px inside d < 0."""
    return np.sqrt(np.clip(1 - (1 - np.clip(-d / height, 0, 1)) ** 2, 0, 1)) * height


# ---------------------------------------------------------------- body

def draw_body(c):
    body = rrect(c, BODY, 72)
    c.shadow(c.cov(body), 0, 10, 14, 0.55)

    # magnesium shell: matte, bevelled edge, fine grain
    h = dome(c, body, 16)
    grain = c.noise(0.8, 1) * 0.012
    c.over(tint(1 + 2.4 * c.shade(h) + grain, SHELL), c.cov(body))
    c.over((0.55, 0.57, 0.6), c.cov(np.abs(body + 1.5) - 0.7) * smooth(500, 40, c.y) * 0.5)

    # front panel: black glass, a groove where it meets the shell
    panel = rrect(c, PANEL, 52)
    c.over((0, 0, 0), c.cov(panel - 3) * (1 - c.cov(panel)) * 0.85)
    c.over((0.4, 0.42, 0.45), c.cov(np.abs(panel + 4) - 0.8) * smooth(300, 60, c.y) * 0.25)
    sheen = 0.035 * smooth(1013, 67, c.y)
    c.over(tint(1 + c.noise(1.5, 2) * 0.01, GLASS) + sheen[..., None], c.cov(panel))

    # printed black mask around the display and the display itself
    c.over((0.012, 0.013, 0.016), c.cov(rrect(c, (SCREEN[0] - 8, SCREEN[1] - 8, SCREEN[2] + 8, SCREEN[3] + 8), 6)))
    c.over((0.0, 0.0, 0.0), c.cov(rrect(c, SCREEN, 2)))

    # rubber antenna bumpers on both ends
    for box in BUMPERS:
        d = rrect(c, box, 34)
        c.shadow(c.cov(d), 2, 5, 6, 0.6)
        hb = dome(c, d, 22)
        tex = c.noise(0.6, 3) * 0.015
        c.over(tint(1 + 1.8 * c.shade(hb) + tex * 2, RUBBER), c.cov(d))
        cx = (box[0] + box[2]) / 2
        for y in (box[1] + 46, box[3] - 46):
            g = segment(c, cx - 18, y, cx + 18, y, 2.2)
            c.over((0.02, 0.02, 0.02), c.cov(g) * 0.8)
            c.over((0.2, 0.2, 0.21), c.cov(segment(c, cx - 18, y + 3, cx + 18, y + 3, 1)) * 0.35)

    # antenna caps on the top and bottom edge
    for box in CAPS:
        d = rrect(c, box, 12)
        c.shadow(c.cov(d), 0, 3, 4, 0.5)
        c.over(tint(1 + 1.2 * c.shade(dome(c, d, 8)) + c.noise(0.6, 4) * 0.015, RUBBER), c.cov(d))

    # ambient light sensor, camera lens and camera indicator
    cy = 112
    c.over((0.06, 0.06, 0.07), c.cov(circle(c, 905, cy, 6)))
    c.over((0.0, 0.0, 0.0), c.cov(circle(c, 950, cy, 13)))
    lens = circle(c, 950, cy, 9)
    rr = np.hypot(c.x - 950, c.y - cy)
    c.over(tint(0.5 + 0.5 * smooth(9, 0, rr), (0.05, 0.07, 0.12)), c.cov(lens))
    c.over((0.75, 0.8, 0.95), c.cov(circle(c, 947, cy - 3, 2.4)) * 0.8)
    c.over((0.05, 0.05, 0.05), c.cov(circle(c, 985, cy, 4)))

    # LED window with the power, drive and battery symbols
    d = rrect(c, LED_PANEL, 9)
    c.over((0.0, 0.0, 0.0), c.cov(d) * 0.55)
    c.over((0.25, 0.26, 0.28), c.cov(np.abs(d) - 0.8) * 0.4)
    ink = (0.62, 0.63, 0.66)
    x = 1568
    y = LEDS[0][1]
    ring = np.abs(circle(c, x, y + 1, 8)) - 1.6
    gap = (c.y < y - 1) & (np.abs(c.x - x) < 4)
    c.over(ink, c.cov(np.where(gap, 9, ring)) * 0.9)
    c.over(ink, c.cov(segment(c, x, y - 10, x, y + 1, 1.6)) * 0.9)
    y = LEDS[1][1]
    can = np.minimum(np.abs(rrect(c, (x - 8, y - 9, x + 8, y + 9), 3)) - 1.5, segment(c, x - 7, y - 4, x + 7, y - 4, 1.2))
    c.over(ink, c.cov(can) * 0.9)
    y = LEDS[2][1]
    batt = np.minimum(np.abs(rrect(c, (x - 6, y - 8, x + 6, y + 10), 2)) - 1.5, rrect(c, (x - 3, y - 11, x + 3, y - 8), 1))
    c.over(ink, c.cov(batt) * 0.9)
    for lx, ly in LEDS:
        c.over((0.0, 0.0, 0.0), c.cov(circle(c, lx, ly, 6)))
        c.over((0.13, 0.14, 0.15), c.cov(circle(c, lx, ly, 4.5)))
        c.over((0.5, 0.5, 0.55), c.cov(circle(c, lx - 1.5, ly - 1.5, 1.4)) * 0.5)

    draw_home(c, False)


def draw_home(c, pressed):
    d = rrect(c, HOME, 10)
    c.over((0, 0, 0), c.cov(d - 2) * 0.8)
    inner = rrect(c, (HOME[0] + 2, HOME[1] + 2, HOME[2] - 2, HOME[3] - 2), 8)
    lift = 0 if pressed else 1.5
    if not pressed:
        c.shadow(c.cov(inner), 0, 2, 1.5, 0.6)
    h = dome(c, inner, 6 if not pressed else 3)
    c.over(tint((0.8 if pressed else 1) + 1.2 * c.shade(h) + c.noise(0.5, 5) * 0.015, RUBBER), c.cov(inner))
    cx, cy = (HOME[0] + HOME[2]) / 2, (HOME[1] + HOME[3]) / 2 - lift * 0.3
    roof = np.minimum(segment(c, cx - 9, cy, cx, cy - 8, 1.4), segment(c, cx, cy - 8, cx + 9, cy, 1.4))
    walls = np.abs(rrect(c, (cx - 6, cy - 1, cx + 6, cy + 9), 1)) - 1.3
    c.over((0.55, 0.56, 0.6), c.cov(np.minimum(roof, walls)) * (0.7 if pressed else 0.85))


def draw_led(c, cx, cy, rgb):
    rr = np.hypot(c.x - cx, c.y - cy)
    glow = np.exp(-(rr / 9) ** 2) * 0.7 + np.exp(-(rr / 4.5) ** 2) * 0.6
    c.over(rgb, np.clip(glow, 0, 1))
    c.over(tuple(min(1, v * 0.4 + 0.6) for v in rgb), c.cov(circle(c, cx, cy, 2.2)) * 0.9)


# ---------------------------------------------------------------- icons

def icon_canvas():
    return Canvas(0, 0, 64, 64, 1)


def draw_icon(name):
    c = icon_canvas()
    w = (1, 1, 1)
    if name == "menu":
        for y in (20, 32, 44):
            c.over(w, c.cov(segment(c, 16, y, 48, y, 2.5)))
    elif name == "fires":
        c.over(w, c.cov(np.abs(circle(c, 32, 32, 16)) - 2.5))
        c.over(w, c.cov(circle(c, 32, 32, 3.5)))
        for ax, ay, bx, by in ((32, 6, 32, 18), (32, 46, 32, 58), (6, 32, 18, 32), (46, 32, 58, 32)):
            c.over(w, c.cov(segment(c, ax, ay, bx, by, 2.5)))
    elif name == "laser":
        c.over(w, c.cov(segment(c, 10, 46, 40, 22, 3)))
        rr = np.hypot(c.x - 46, c.y - 18)
        c.over(w, c.cov(rr - 6))
        for a in range(0, 360, 45):
            x, y = 46 + 11 * math.cos(math.radians(a)), 18 + 11 * math.sin(math.radians(a))
            c.over(w, c.cov(segment(c, x, y, 46 + 15 * math.cos(math.radians(a)), 18 + 15 * math.sin(math.radians(a)), 1.6)) * 0.9)
    elif name == "map":
        pts = [(10, 16), (24, 10), (40, 16), (54, 10), (54, 48), (40, 54), (24, 48), (10, 54)]
        d = np.full(c.a.shape, 99, F)
        for i in range(len(pts)):
            ax, ay = pts[i]
            bx, by = pts[(i + 1) % len(pts)]
            d = np.minimum(d, segment(c, ax, ay, bx, by, 2.2))
        d = np.minimum(d, segment(c, 24, 10, 24, 48, 2.2))
        d = np.minimum(d, segment(c, 40, 16, 40, 54, 2.2))
        c.over(w, c.cov(d))
    elif name == "dir":
        c.over(w, c.cov(np.abs(circle(c, 32, 32, 22)) - 2.2))
        c.over(w, c.cov(poly(c, [(32, 13), (39, 32), (25, 32)])))
        c.over(w, c.cov(np.abs(poly(c, [(25, 32), (39, 32), (32, 51)])) - 1.4) * 0.9)
    elif name == "status":
        for y in (18, 32, 46):
            c.over(w, c.cov(circle(c, 15, y, 3.5)))
            c.over(w, c.cov(segment(c, 25, y, 50, y, 2.5)))
    elif name == "self":
        c.over(w, c.cov(np.abs(circle(c, 32, 32, 14)) - 2.4))
        c.over(w, c.cov(circle(c, 32, 32, 5)))
        for ax, ay, bx, by in ((32, 6, 32, 16), (32, 48, 32, 58), (6, 32, 16, 32), (48, 32, 58, 32)):
            c.over(w, c.cov(segment(c, ax, ay, bx, by, 2.4)))
    elif name == "plus":
        c.over(w, c.cov(np.minimum(segment(c, 18, 32, 46, 32, 3), segment(c, 32, 18, 32, 46, 3))))
    elif name == "minus":
        c.over(w, c.cov(segment(c, 18, 32, 46, 32, 3)))
    elif name == "close":
        c.over(w, c.cov(np.minimum(segment(c, 20, 20, 44, 44, 3), segment(c, 44, 20, 20, 44, 3))))
    elif name == "back":
        c.over(w, c.cov(np.minimum(segment(c, 22, 32, 36, 18, 3), segment(c, 22, 32, 36, 46, 3))))
    elif name == "north":
        c.over((0.08, 0.09, 0.1), c.cov(circle(c, 32, 32, 29)))
        c.over((0.6, 0.62, 0.65), c.cov(np.abs(circle(c, 32, 32, 28)) - 1.2))
        c.over((0.92, 0.14, 0.12), c.cov(poly(c, [(32, 9), (45, 45), (32, 37), (19, 45)])))
    elif name == "selfmark":
        tri = poly(c, [(32, 6), (52, 56), (32, 45), (12, 56)])
        c.over((0.0, 0.0, 0.0), c.cov(tri - 2.5) * 0.9)
        c.over((0.16, 0.55, 0.98), c.cov(tri))
    elif name == "hostile":
        d = np.abs(c.x - 32) + np.abs(c.y - 32) - 24
        c.over((0.0, 0.0, 0.0), c.cov(d - 2.5) * 0.9)
        c.over((1.0, 0.2, 0.2), c.cov(d))
        c.over((1.0, 0.75, 0.75), c.cov(np.abs(d + 5) - 1) * 0.5)
    elif name == "gps":
        c.over(w, c.cov(np.abs(circle(c, 32, 32, 12)) - 2.6))
        c.over(w, c.cov(circle(c, 32, 32, 4)))
        for ax, ay, bx, by in ((32, 10, 32, 18), (32, 46, 32, 54), (10, 32, 18, 32), (46, 32, 54, 32)):
            c.over(w, c.cov(segment(c, ax, ay, bx, by, 2.6)))
    elif name == "signal":
        for i in range(4):
            x = 14 + i * 10
            c.over(w, c.cov(rrect(c, (x, 50 - (i + 1) * 9, x + 6, 50), 1)))
    elif name == "battery":
        c.over(w, c.cov(np.abs(rrect(c, (10, 20, 50, 44), 4)) - 2.4))
        c.over(w, c.cov(rrect(c, (50, 27, 55, 37), 1.5)))
        c.over(w, c.cov(rrect(c, (15, 25, 40, 39), 2)))
    return c


def poly(c, pts):
    """Signed distance to a closed polygon, negative inside (any shape)."""
    d = np.full(c.a.shape, 1e9, F)
    inside = np.zeros(c.a.shape, bool)
    for i in range(len(pts)):
        ax, ay = pts[i]
        bx, by = pts[(i + 1) % len(pts)]
        d = np.minimum(d, segment(c, ax, ay, bx, by, 0))
        cross = ((ay > c.y) != (by > c.y)) & (c.x < (bx - ax) * (c.y - ay) / ((by - ay) or 1e-9) + ax)
        inside ^= cross
    return np.where(inside, -d, d)


def segment_side(c, ax, ay, bx, by):
    """Signed distance to the left of the directed edge a->b (negative inside a clockwise polygon)."""
    vx, vy = bx - ax, by - ay
    n = math.hypot(vx, vy)
    return ((c.x - ax) * vy - (c.y - ay) * vx) / n


ICONS = ["menu", "fires", "laser", "map", "dir", "status", "self", "plus", "minus", "close",
         "back", "north", "selfmark", "hostile", "gps", "signal", "battery"]


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)

    x0, y0, x1, y1 = BODY_TEX
    c = Canvas(x0, y0, x1 - x0, y1 - y0, 2048 / (x1 - x0))
    draw_body(c)
    c.save(out / "body.png", (2048, 1024))

    for pressed in (False, True):
        x0, y0, x1, y1 = HOME_TEX
        c = Canvas(x0, y0, x1 - x0, y1 - y0, 128 / (x1 - x0))
        c.over(GLASS, np.ones_like(c.a))
        draw_home(c, pressed)
        c.save(out / ("home_down.png" if pressed else "home_up.png"), (128, 64))

    for name, rgb in (("green", (0.25, 1.0, 0.35)), ("amber", (1.0, 0.62, 0.1)), ("red", (1.0, 0.15, 0.1))):
        c = Canvas(-20, -20, 40, 40, 64 / 40)
        draw_led(c, 0, 0, rgb)
        c.save(out / f"led_{name}.png", (64, 64))

    for name in ICONS:
        draw_icon(name).save(out / f"icon_{name}.png", (64, 64))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generate every QuotiMate icon asset from logo3 (colored) + logo4 (themed).

Re-run after changing SCALE_* or the logo files, then:
    flutter pub run flutter_launcher_icons
and re-add the <monochrome> layer to mipmap-anydpi-v26/launcher_icon.xml
(0.13.1 strips it).
"""

from PIL import Image, ImageFilter
import numpy as np
from collections import deque
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
RES = ROOT / "android" / "app" / "src" / "main" / "res"
ASSETS = ROOT / "assets"

# logo3/logo4 carry a near-invisible halo spanning ~99% of the canvas, so the
# real glyph must be found with an alpha threshold, not getbbox().
ALPHA_MIN = 24

BG = "#05111B"

# Fraction of each canvas the glyph occupies.
SCALE_MASTER = 0.44          # legacy full-bleed icon (iOS / pre-API-26 / web)
SCALE_ADAPTIVE = 0.48        # adaptive foreground + monochrome (safe zone is 0.66)
# The status bar scales the *whole* 24dp canvas to its icon slot, so every point
# of padding shrinks the glyph: 0.66 rendered as a speck next to system icons.
SCALE_NOTIFICATION = 0.84
SCALE_SPLASH = 0.55

DENSITIES = {  # dir suffix -> px per 1dp
    "mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0,
}
ADAPTIVE_BASE = 108      # adaptive canvas is 108dp
NOTIFICATION_BASE = 24   # status bar icon is 24dp
SPLASH_BASE = 600        # fixed px canvases per density bucket
SPLASH_SIZES = {"mdpi": 300, "hdpi": 400, "xhdpi": 500, "xxhdpi": 600, "xxxhdpi": 700}


def load(path):
    return Image.open(path).convert("RGBA")


def trimmed(img):
    """Crop to the opaque glyph, ignoring the faint halo."""
    alpha = np.asarray(img)[:, :, 3]
    ys, xs = np.where(alpha > ALPHA_MIN)
    if len(xs) == 0:
        raise SystemExit(f"{img.filename}: nothing above alpha {ALPHA_MIN}")
    return img.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))


def components(img):
    """Split into solid shapes, largest-fill-ratio first."""
    alpha = np.asarray(img)[:, :, 3] > ALPHA_MIN
    h, w = alpha.shape
    seen = np.zeros_like(alpha)
    out = []
    for y in range(h):
        for x in range(w):
            if not alpha[y, x] or seen[y, x]:
                continue
            seen[y, x] = True
            queue = deque([(y, x)])
            pixels = [(y, x)]
            while queue:
                cy, cx = queue.popleft()
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < h and 0 <= nx < w and alpha[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        pixels.append((ny, nx))
                        queue.append((ny, nx))
            ys = [p[0] for p in pixels]
            xs = [p[1] for p in pixels]
            box = (int(min(xs)), int(min(ys)), int(max(xs)) + 1, int(max(ys)) + 1)
            area = (box[2] - box[0]) * (box[3] - box[1])
            out.append((len(pixels) / area, box, len(pixels)))
    out.sort(reverse=True)
    return out


def place(glyph, canvas, scale, tint=None):
    """Center the glyph on a transparent canvas, keeping its aspect ratio,
    with the longer edge at `scale` of the canvas."""
    canvas = int(round(canvas))
    w, h = glyph.size
    long_side = max(1, int(canvas * scale))
    if w >= h:
        size = (long_side, max(1, round(long_side * h / w)))
    else:
        size = (max(1, round(long_side * w / h)), long_side)
    glyph = glyph.resize(size, Image.LANCZOS)
    if tint:
        arr = np.array(glyph, copy=True)
        arr[:, :, :3] = tint
        glyph = Image.fromarray(arr)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.paste(glyph, ((canvas - size[0]) // 2, (canvas - size[1]) // 2), glyph)
    return out


def anti_alias(img):
    """Soften the edges of a silhouette for the status-bar icon."""
    return img.filter(ImageFilter.GaussianBlur(0.6))


def main():
    logo3 = trimmed(load(ASSETS / "logo3.png"))                  # gold mark
    logo4 = trimmed(load(ASSETS / "logo4.png"))                  # white ring + quote
    quote_only = trimmed(logo4.crop(components(logo4)[0][1]))    # solid quote mark

    # --- source-of-truth assets ---
    master = Image.new("RGBA", (1024, 1024), BG)
    glyph_on_bg = place(logo3, 1024, SCALE_MASTER)
    master.paste(glyph_on_bg, (0, 0), glyph_on_bg)
    master.save(ASSETS / "app_icon_master.png")

    place(logo3, 432, SCALE_ADAPTIVE).save(ASSETS / "adaptive_foreground.png")
    place(logo4, 432, SCALE_ADAPTIVE).save(ASSETS / "adaptive_foreground_monochrome.png")
    place(logo3, 600, SCALE_SPLASH).save(RES / "drawable" / "splash_logo.png")

    # --- density buckets ---
    for suffix, factor in DENSITIES.items():
        d = RES / f"drawable-{suffix}"
        d.mkdir(exist_ok=True)
        place(logo3, ADAPTIVE_BASE * factor, SCALE_ADAPTIVE).save(d / "ic_launcher_foreground.png")
        place(logo4, ADAPTIVE_BASE * factor, SCALE_ADAPTIVE).save(d / "ic_launcher_monochrome.png")
        icon = anti_alias(place(quote_only, NOTIFICATION_BASE * factor, SCALE_NOTIFICATION,
                                tint=(255, 255, 255)))
        icon.save(d / "ic_notification.png")
        place(logo3, SPLASH_SIZES[suffix], SCALE_SPLASH).save(d / "splash_logo.png")

    print("icons regenerated")


if __name__ == "__main__":
    main()

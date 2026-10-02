"""Regenerates every app icon from the kawung mark on the Welcome screen
(lib/kawung_mark.dart). Needs Pillow:  pip install pillow
Run from the repo root:  python3 scripts/make_app_icons.py
Overwrites the PNGs already in the Android, iOS and web icon folders,
keeping each file's existing pixel size.
"""
import glob
from PIL import Image, ImageDraw

PAPER = (0xF7, 0xF3, 0xE8)  # AppTheme.paper
GOLD = (0x9C, 0x6E, 0x22)   # AppTheme.gold (the mark's colour on Welcome)

# Same geometry as _KawungPainter, in its 34-unit box.
CIRCLES = [(12, 12), (22, 12), (12, 22), (22, 22)]
RADIUS, DOT, STROKE = 7.2, 3.1, 2.2  # stroke a little bolder than 1.6 so it holds up small
MARK_SPAN = 24.4  # circles run from 4.8 to 29.2 in that box


def render(px, mark_fraction=0.58):
    n = px * 4  # supersample, then shrink for smooth edges
    unit = n * mark_fraction / MARK_SPAN  # pixels per mark unit
    origin = n / 2 - 17 * unit  # centre of the 34-unit box on the canvas

    def pt(x, y):
        return origin + x * unit, origin + y * unit

    # Rings are drawn into one mask so overlaps stay clean.
    img = Image.new("RGB", (n, n), PAPER)
    mask = Image.new("L", (n, n), 0)
    for cx, cy in CIRCLES:
        x, y = pt(cx, cy)
        r_out = RADIUS * unit + STROKE * unit / 2
        r_in = RADIUS * unit - STROKE * unit / 2
        ring = Image.new("L", (n, n), 0)
        rd = ImageDraw.Draw(ring)
        rd.ellipse([x - r_out, y - r_out, x + r_out, y + r_out], fill=255)
        rd.ellipse([x - r_in, y - r_in, x + r_in, y + r_in], fill=0)
        mask.paste(255, mask=ring)
    md = ImageDraw.Draw(mask)
    x, y = pt(17, 17)
    r = DOT * unit
    md.ellipse([x - r, y - r, x + r, y + r], fill=255)
    img.paste(Image.new("RGB", (n, n), GOLD), mask=mask)
    return img.resize((px, px), Image.LANCZOS)


targets = (
    glob.glob("android/app/src/main/res/mipmap-*/ic_launcher.png")
    + glob.glob("ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png")
    + glob.glob("web/icons/*.png")
    + ["web/favicon.png"]
)
for path in sorted(targets):
    px = Image.open(path).size[0]
    # Maskable icons get cropped to a circle: keep the mark well inside it.
    fraction = 0.50 if "maskable" in path else 0.58
    render(px, fraction).save(path, optimize=True)
    print(path, px)

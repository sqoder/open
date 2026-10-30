#!/usr/bin/env python3
"""Rebuild siqi app icon with a mathematically even outer border."""
from PIL import Image, ImageDraw
import sys, os, subprocess

SRC = "/tmp/icon_src_original.png"
if not os.path.exists(SRC):
    # pristine master from git commit dbdf0f4
    data = subprocess.check_output(
        ["git", "show", "dbdf0f4:siqi/Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png"]
    )
    with open(SRC, "wb") as f:
        f.write(data)

OUT_DIR = "siqi/Resources/Assets.xcassets/AppIcon.appiconset"
S = 1024                 # master size
CORNER = 224             # macOS squircle-ish outer radius
BORDER = 80              # uniform white border thickness (increased from 48)
SS = 4                   # supersample factor for smooth edges
CROP = 62                # crop past corner depth to remove corner haze

def artwork():
    """Crop the pink card out of the original master."""
    im = Image.open(SRC).convert("RGB")
    px = im.load(); w, h = im.size
    xs, ys = [], []
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            r, g, b = px[x, y]
            if r > g + 15 and r > b + 5:      # pink-ish
                xs.append(x); ys.append(y)
    if not xs:
        sys.exit("no pink content found")
    x0, x1, y0, y1 = min(xs), max(xs) + 1, min(ys), max(ys) + 1
    return im.crop((x0 + CROP, y0 + CROP, x1 - CROP, y1 - CROP))

def rounded_mask(size, radius, inset):
    big = size * SS
    m = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(m)
    i, r = inset * SS, max(1, radius * SS)
    d.rounded_rectangle([i, i, big - 1 - i, big - 1 - i], radius=r, fill=255)
    return m.resize((size, size), Image.LANCZOS)

def main():
    art = artwork()
    print("artwork crop:", art.size)

    inner = S - 2 * BORDER
    art_fit = art.resize((inner, inner), Image.LANCZOS)

    # white base = outer rounded square
    base = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    white = Image.new("RGBA", (S, S), (255, 255, 255, 255))
    base.paste(white, (0, 0), rounded_mask(S, CORNER, 0))

    # artwork clipped to the inner rounded square
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    layer.paste(art_fit, (BORDER, BORDER))
    layer.putalpha(rounded_mask(S, CORNER - BORDER, BORDER))
    base = Image.alpha_composite(base, layer)

    slots = {
        "icon_16x16.png": 16, "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32, "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128, "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256, "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512, "icon_512x512@2x.png": 1024,
    }
    for name, size in slots.items():
        base.resize((size, size), Image.LANCZOS).save(os.path.join(OUT_DIR, name))
    print("wrote", len(slots), "slots to", OUT_DIR)

    base.save("screenshots/siqi-icon.png")

if __name__ == "__main__":
    main()

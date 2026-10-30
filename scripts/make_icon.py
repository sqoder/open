#!/usr/bin/env python3
"""Rebuild siqi app icon with Ghostty-style metallic outer chassis and custom white-pink inner bezel."""
import os
import sys
import subprocess
from PIL import Image, ImageDraw, ImageFilter

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(SCRIPT_DIR)
BEZEL_PATH = os.path.join(SCRIPT_DIR, "bezel_reference.png")
OUT_DIR = os.path.join(ROOT_DIR, "siqi", "Resources", "Assets.xcassets", "AppIcon.appiconset")
SCREENSHOT_PATH = os.path.join(ROOT_DIR, "screenshots", "siqi-icon.png")

SRC = "/tmp/icon_src_original.png"
if not os.path.exists(SRC):
    # pristine master from git commit dbdf0f4
    data = subprocess.check_output(
        ["git", "show", "dbdf0f4:siqi/Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png"],
        cwd=ROOT_DIR
    )
    with open(SRC, "wb") as f:
        f.write(data)

CROP = 62  # crop past original rounded corner depth

def load_artwork():
    """Crop the pink card artwork out of the original master."""
    im = Image.open(SRC).convert("RGBA")
    px = im.load()
    w, h = im.size
    xs, ys = [], []
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            r, g, b, _ = px[x, y]
            if r > g + 15 and r > b + 5:  # pink-ish
                xs.append(x)
                ys.append(y)
    if not xs:
        sys.exit("Error: no pink content found in original source")
    x0, x1, y0, y1 = min(xs), max(xs) + 1, min(ys), max(ys) + 1
    return im.crop((x0 + CROP, y0 + CROP, x1 - CROP, y1 - CROP))

def main():
    if not os.path.exists(BEZEL_PATH):
        sys.exit(f"Error: bezel reference not found at {BEZEL_PATH}")

    art = load_artwork()
    raw_bezel = Image.open(BEZEL_PATH).convert("RGBA")

    SS = 4
    bw, bh = 1024 * SS, 1024 * SS

    # 1. Outer chamfer mask (everything outside the groove, keeping Ghostty's silver chamfer + dock shadow)
    m_chamfer = Image.new("L", (bw, bh), 255)
    d_c = ImageDraw.Draw(m_chamfer)
    d_c.rounded_rectangle([142 * SS, 140 * SS, 878 * SS, 876 * SS], radius=175 * SS, fill=0)
    m_chamfer = m_chamfer.resize((1024, 1024), Image.LANCZOS)

    outer_bezel = raw_bezel.copy()
    r, g, b, a = outer_bezel.split()
    na = Image.new("L", (1024, 1024))
    a_px, mc_px, na_px = a.load(), m_chamfer.load(), na.load()
    for y in range(1024):
        for x in range(1024):
            na_px[x, y] = int(a_px[x, y] * (mc_px[x, y] / 255.0))
    outer_bezel.putalpha(na)

    # 2. White-pink inner bezel mask (between outer groove and screen aperture)
    m_ib_full = Image.new("L", (bw, bh), 0)
    d_ib = ImageDraw.Draw(m_ib_full)
    d_ib.rounded_rectangle([142 * SS, 140 * SS, 878 * SS, 876 * SS], radius=175 * SS, fill=255)
    d_ib.rounded_rectangle([181 * SS, 185 * SS, 842 * SS, 842 * SS], radius=144 * SS, fill=0)
    m_ib = m_ib_full.resize((1024, 1024), Image.LANCZOS)

    # White-pink gradient fill with gentle top-down lighting
    c_top = (255, 246, 250)   # soft glowing pearl white-pink
    c_bot = (248, 218, 232)   # delicate pastel rose-pink
    ib_layer = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    ib_draw = ImageDraw.Draw(ib_layer)
    for y in range(140, 877):
        t = (y - 140) / (876 - 140)
        cr = int(c_top[0] * (1 - t) + c_bot[0] * t)
        cg = int(c_top[1] * (1 - t) + c_bot[1] * t)
        cb = int(c_top[2] * (1 - t) + c_bot[2] * t)
        ib_draw.line([(140, y), (880, y)], fill=(cr, cg, cb, 255))
    ib_layer.putalpha(m_ib)

    # 3. Soft inner rim shadow at aperture boundary (so screen looks physically seated inside the bezel)
    shadow_layer = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    d_s = ImageDraw.Draw(shadow_layer)
    d_s.rounded_rectangle([181 * SS, 185 * SS, 842 * SS, 842 * SS], radius=144 * SS, outline=(140, 50, 90, 160), width=3 * SS)
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(radius=2 * SS)).resize((1024, 1024), Image.LANCZOS)

    # 4. Artwork screen layer (scaled to cover aperture 666x666)
    art_fit = art.resize((666, 666), Image.LANCZOS)
    final_icon = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    final_icon.paste(art_fit, (179, 183))
    final_icon = Image.alpha_composite(final_icon, shadow_layer)
    final_icon = Image.alpha_composite(final_icon, ib_layer)
    final_icon = Image.alpha_composite(final_icon, outer_bezel)

    os.makedirs(OUT_DIR, exist_ok=True)
    slots = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    for name, size in slots.items():
        slot_path = os.path.join(OUT_DIR, name)
        final_icon.resize((size, size), Image.LANCZOS).save(slot_path)
    print(f"Generated {len(slots)} icon slots in {OUT_DIR}")

    os.makedirs(os.path.dirname(SCREENSHOT_PATH), exist_ok=True)
    final_icon.save(SCREENSHOT_PATH)
    print(f"Saved master screenshot icon to {SCREENSHOT_PATH}")

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Rebuild siqi app icon with authentic Ghostty-style retro terminal hardware bezel."""
import os
import sys
import subprocess
from PIL import Image

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
    bezel = Image.open(BEZEL_PATH).convert("RGBA")

    # Fit artwork to aperture bounds (666x666 covers [179..845])
    art_fit = art.resize((666, 666), Image.LANCZOS)

    # Base canvas with artwork positioned in the CRT aperture
    comp = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    comp.paste(art_fit, (179, 183))

    # Alpha composite the authentic metallic monitor bezel overlay
    final_icon = Image.alpha_composite(comp, bezel)

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

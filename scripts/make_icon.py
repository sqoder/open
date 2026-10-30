#!/usr/bin/env python3
"""Rebuild siqi app icon with mathematically uniform concentric borders:
- Outer white squircle chassis (exactly uniform 42px width)
- Hairline rose-gray parting seam
- Inner white-pink bezel (exactly uniform 40px width)
- Soft inner shadow rim
- Glowing cat terminal screen with authentic macOS dock drop shadow
"""
import os
import sys
import math
import subprocess
from PIL import Image

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(SCRIPT_DIR)
BEZEL_PATH = os.path.join(SCRIPT_DIR, "bezel_reference.png")
DIST_MAP_PATH = os.path.join(SCRIPT_DIR, "dist_map.bin")
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

def compute_dist_map(raw_bezel):
    """Compute exact Euclidean distance transform for the solid squircle tile (Meijster's algorithm)."""
    px = raw_bezel.load()
    w, h = 1024, 1024
    grid = [[0]*w for _ in range(h)]
    for y in range(h):
        row_xs = [x for x in range(w) if px[x, y][3] >= 128]
        if row_xs:
            x_start, x_end = min(row_xs), max(row_xs)
            for x in range(x_start, x_end + 1):
                grid[y][x] = 1

    INF = 1000000000
    dt1 = [[0]*w for _ in range(h)]

    for x in range(w):
        d = INF
        for y in range(h):
            d = 0 if grid[y][x] == 0 else d + 1
            dt1[y][x] = d
        d = INF
        for y in range(h-1, -1, -1):
            d = 0 if grid[y][x] == 0 else d + 1
            if d < dt1[y][x]:
                dt1[y][x] = d

    def f(y, x, i):
        return (x - i)**2 + dt1[y][i]**2

    data = bytearray(w * h * 2)
    s = [0]*w
    t = [0]*w

    for y in range(h):
        q = 0
        s[0] = 0
        t[0] = 0
        for u in range(1, w):
            while q >= 0 and f(y, t[q], s[q]) > f(y, t[q], u):
                q -= 1
            if q < 0:
                q = 0
                s[0] = u
            else:
                d_u = dt1[y][u]
                d_s = dt1[y][s[q]]
                sep = (u*u - s[q]*s[q] + d_u*d_u - d_s*d_s) // (2 * (u - s[q])) + 1
                if sep < w:
                    q += 1
                    s[q] = u
                    t[q] = sep
        for u in range(w-1, -1, -1):
            d_val = math.sqrt(f(y, u, s[q]))
            int_val = min(65535, int(d_val * 100))
            data[(y * w + u) * 2] = int_val & 0xff
            data[(y * w + u) * 2 + 1] = (int_val >> 8) & 0xff
            if u == t[q]:
                q -= 1

    with open(DIST_MAP_PATH, "wb") as f:
        f.write(data)
    return data

def load_dist_map(raw_bezel):
    if not os.path.exists(DIST_MAP_PATH):
        print("Computing exact Euclidean distance transform for tile contour...")
        return compute_dist_map(raw_bezel)
    with open(DIST_MAP_PATH, "rb") as f:
        return f.read()

def main():
    if not os.path.exists(BEZEL_PATH):
        sys.exit(f"Error: bezel reference not found at {BEZEL_PATH}")

    raw_bezel = Image.open(BEZEL_PATH).convert("RGBA")
    b_px = raw_bezel.load()
    w, h = 1024, 1024

    dist_buf = load_dist_map(raw_bezel)
    dmap = [[0.0]*w for _ in range(h)]
    idx = 0
    for y in range(h):
        for x in range(w):
            val = dist_buf[idx] | (dist_buf[idx+1] << 8)
            dmap[y][x] = val / 100.0
            idx += 2

    art = load_artwork()
    art_fit = art.resize((680, 680), Image.LANCZOS)
    art_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    art_layer.paste(art_fit, (172, 172))
    al_px = art_layer.load()

    final_icon = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    f_px = final_icon.load()

    W_OUTER = 42.0  # Exactly uniform 42px outer white border
    W_INNER = 82.0  # Exactly uniform 40px inner white-pink bezel (82 - 42)

    c_top = (255, 246, 250)    # Soft luminous white-pink
    c_bot = (248, 218, 232)    # Delicate pastel rose-pink
    groove_c = (215, 185, 195) # Soft hairline seam
    shadow_c = (140, 50, 90)   # Subtle inner shadow rim

    for y in range(h):
        t_y = (y - 140) / (876 - 140)
        t_y = max(0.0, min(1.0, t_y))
        ib_r = int(c_top[0] * (1 - t_y) + c_bot[0] * t_y)
        ib_g = int(c_top[1] * (1 - t_y) + c_bot[1] * t_y)
        ib_b = int(c_top[2] * (1 - t_y) + c_bot[2] * t_y)

        for x in range(w):
            d = dmap[y][x]
            orig_r, orig_g, orig_b, orig_a = b_px[x, y]

            if d == 0.0:
                # Outside tile: retain natural macOS Dock drop shadow
                f_px[x, y] = (orig_r, orig_g, orig_b, orig_a)
            else:
                # Ceramic Apple white with micro-bevel depth
                lum = (orig_r + orig_g + orig_b) / 3.0
                new_lum = int(255 - (255 - lum) * 0.04)
                white_c = (new_lum, new_lum, new_lum)

                if d < W_OUTER - 1.0:
                    # Pure uniform outer white border
                    f_px[x, y] = (white_c[0], white_c[1], white_c[2], 255)
                elif d < W_OUTER + 1.0:
                    # Subpixel antialiased hairline parting seam
                    dist_from_groove = abs(d - W_OUTER)
                    g_weight = max(0.0, 1.0 - dist_from_groove)
                    base = white_c if d < W_OUTER else (ib_r, ib_g, ib_b)
                    r_out = int(base[0] * (1 - g_weight) + groove_c[0] * g_weight)
                    g_out = int(base[1] * (1 - g_weight) + groove_c[1] * g_weight)
                    b_out = int(base[2] * (1 - g_weight) + groove_c[2] * g_weight)
                    f_px[x, y] = (r_out, g_out, b_out, 255)
                elif d < W_INNER - 1.5:
                    # Pure uniform inner white-pink bezel
                    f_px[x, y] = (ib_r, ib_g, ib_b, 255)
                elif d < W_INNER + 2.0:
                    # Subpixel antialiased inner shadow seam into screen
                    t_trans = (d - (W_INNER - 1.5)) / 3.5
                    t_trans = max(0.0, min(1.0, t_trans))
                    scr = al_px[x, y]
                    s_dist = abs(d - W_INNER)
                    s_weight = max(0.0, 1.0 - s_dist / 2.0) * 0.4

                    base_r = ib_r * (1 - t_trans) + scr[0] * t_trans
                    base_g = ib_g * (1 - t_trans) + scr[1] * t_trans
                    base_b = ib_b * (1 - t_trans) + scr[2] * t_trans

                    r_out = int(base_r * (1 - s_weight) + shadow_c[0] * s_weight)
                    g_out = int(base_g * (1 - s_weight) + shadow_c[1] * s_weight)
                    b_out = int(base_b * (1 - s_weight) + shadow_c[2] * s_weight)
                    f_px[x, y] = (r_out, g_out, b_out, 255)
                else:
                    # Screen artwork
                    f_px[x, y] = al_px[x, y]

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

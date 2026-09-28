"""Rebuild the four relay screens from the source PNGs.

Period rectangles were measured on the generated art. Re-run only if those
PNGs are replaced.
"""

from pathlib import Path

from PIL import Image

SRC = Path(r"C:\Users\Paul\.cursor\projects\c-Dev-flutter-projects-EasyFreezy\assets")
DST = Path(r"C:\Dev\flutter_projects\EasyFreezy\assets\Easy_Freezy_additional_assets")

# (source, dest, x0, x1, y0, y1, donor dy)
JOBS = [
    ("ef_bonus_portrait.png", "bonus_tall_ef.webp", 607, 616, 716, 762, -10),
    ("ef_bonus_landscape.png", "bonus_wide_ef.webp", 942, 952, 446, 484, -10),
    ("ef_offline_portrait.png", "offline_tall_ef.webp", 597, 606, 478, 518, -10),
    ("ef_offline_landscape.png", "offline_wide_ef.webp", 868, 876, 356, 384, 36),
]


def pack(src_name, dst_name, x0, x1, y0, y1, donor_dy):
    im = Image.open(SRC / src_name).convert("RGBA")
    px = im.load()
    for y in range(y0, y1):
        for x in range(x0, x1):
            px[x, y] = px[x, y + donor_dy]
    out = DST / dst_name
    im.convert("RGB").save(out, "WEBP", quality=86, method=6, exif=b"EF-SLEET-2026-09-22")
    print(out.name)


if __name__ == "__main__":
    DST.mkdir(parents=True, exist_ok=True)
    for job in JOBS:
        pack(*job)

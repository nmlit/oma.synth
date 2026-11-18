#!/usr/bin/env python3
"""Skapar icon-white.png och icon-red.png från en vit/transparent käll-PNG.
Kör på utvecklingsdatorn: python3 tools/make-icons.py källa.png"""
import sys
from pathlib import Path
from PIL import Image

from PIL import ImageChops

src = Image.open(sys.argv[1]).convert("RGBA")
# Täckning = alfa × ljushet: vita delar blir färgade, mörka konturlinjer
# (t.ex. mellan fingrarna) blir genomskinliga så detaljerna bevaras.
alpha = ImageChops.multiply(src.getchannel("A"), src.convert("L"))
box = alpha.getbbox()
if box:
    src, alpha = src.crop(box), alpha.crop(box)
side = max(src.size)
out = Path(__file__).resolve().parents[1]
for name, rgb in (("icon-white.png", (255, 255, 255)), ("icon-red.png", (229, 57, 53))):
    img = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    fill = Image.new("RGBA", src.size, rgb + (255,))
    fill.putalpha(alpha)
    img.paste(fill, ((side - src.size[0]) // 2, (side - src.size[1]) // 2))
    if side > 256:
        img = img.resize((256, 256), Image.LANCZOS)
    img.save(out / name, optimize=True)
    print("skrev", out / name, img.size)

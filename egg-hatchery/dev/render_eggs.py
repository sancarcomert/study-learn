#!/usr/bin/env python3
"""dev/render_eggs.py : preview.sh'in urettigi parts.txt'den yumurta yakin cekimleri ve genel gorunum.
Kullanim: render_eggs.py parts.txt cikti_klasoru"""
import sys
import numpy as np
from PIL import Image
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import render_preview as rp

parts = rp.load(sys.argv[1])
out = sys.argv[2]
anchors = {}
for line in open(sys.argv[1]):
    if line.startswith("ANCHOR|"):
        f = line.strip().split("|")
        anchors[int(f[1])] = (np.array([float(x) for x in f[2:5]]), np.array([float(x) for x in f[5:8]]))

rp.W, rp.H = 640, 640
imgs = []
for i, (pos, look) in sorted(anchors.items()):
    cam_pos = pos + look * 11 + np.array([0, 1.5, 0])
    target = pos + np.array([0, 3.2, 0])
    cam = rp.Camera(tuple(cam_pos), tuple(target), 46)
    im = rp.render(parts, cam, f"egg{i}", haze=0.0004)
    im.save(f"{out}/egg{i}.png")
    imgs.append(im)
sheet = Image.new("RGB", (640 * 3, 640 * 2))
for k, im in enumerate(imgs):
    sheet.paste(im, ((k % 3) * 640, (k // 3) * 640))
sheet.save(f"{out}/eggs_sheet.png")
print("tamam", len(imgs))

#!/usr/bin/env python3
"""Gera scripts/art/art_catalog.gd medindo os PNGs de assets/art/tiles/.

Cada PNG do pacote traz 4 vistas (rotações) lado a lado. Para cada vista o script mede
a caixa útil (alfa), o vértice inferior e o superior (para alinhar o sprite ao chão) e a
pegada em células de 40 px de meia-largura (grade isométrica 2:1 de 80x40).
Rode de novo sempre que atualizar o pacote de arte:  python3 tools/build_art_catalog.py
(requer Pillow e numpy)."""
import glob, os
import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
TILES = os.path.join(ROOT, "assets", "art", "tiles")
OUT = os.path.join(ROOT, "scripts", "art", "art_catalog.gd")
HALF_W = 40.0


def runs(alpha):
    cols = alpha.any(axis=0)
    out, start = [], None
    for x, v in enumerate(cols):
        if v and start is None:
            start = x
        if not v and start is not None:
            out.append((start, x - 1))
            start = None
    if start is not None:
        out.append((start, len(cols) - 1))
    return out


lines = ["# GERADO por tools/build_art_catalog.py - não edite à mão.",
         "class_name ArtCatalog",
         "extends RefCounted",
         "## Medidas de cada vista dos sprites: r = caixa útil [x0,y0,x1,y1] no PNG,",
         "## b = vértice inferior [x,y], t = vértice superior [x,y], fp = pegada [w,d] em células.",
         "",
         "const DATA := {"]
for path in sorted(glob.glob(os.path.join(TILES, "*", "*.png"))):
    folder = os.path.basename(os.path.dirname(path))
    name = os.path.splitext(os.path.basename(path))[0]
    alpha = np.array(Image.open(path).convert("RGBA"))[:, :, 3] > 0
    variants = []
    for x0, x1 in runs(alpha):
        sub = alpha[:, x0:x1 + 1]
        ys = np.where(sub.any(axis=1))[0]
        y0, y1 = int(ys[0]), int(ys[-1])
        xb = float(x0 + np.where(sub[y1])[0].mean())
        xt = float(x0 + np.where(sub[y0])[0].mean())
        w = round((xb - x0) / HALF_W)
        d = round((x1 - xb) / HALF_W)
        variants.append('{"r": [%d, %d, %d, %d], "b": [%d, %d], "t": [%d, %d], "fp": [%d, %d]}'
                        % (x0, y0, x1, y1, round(xb), y1, round(xt), y0, w, d))
    lines.append('\t"%s": {"dir": "%s", "v": [' % (name, folder))
    for v in variants:
        lines.append("\t\t%s," % v)
    lines.append("\t]},")
lines.append("}")
with open(OUT, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
print("gerado:", OUT)

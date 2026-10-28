#!/usr/bin/env python3
"""Gera scripts/art/extra_catalog.gd a partir dos pacotes extras em assets/art/tiles/:

- town/ (Free Isometric Pixel Town Sampler, Antahonist): prédios e postes noturnos,
  com tiras de animação das janelas. Grade do pacote: célula 64x32 (a nossa é 80x40).
- neon_district/ (Neon District Free 80): objetos de rua ciberpunk na edição de 64 px.

Para cada sprite mede a área útil e o ponto de apoio no chão (âncora). Nos prédios mede
também a pegada a partir dos cantos esquerdo, inferior e direito da base (a sombra
assada fica à direita e é semitransparente, por isso só pixels opacos contam).
Uso: python3 tools/build_extra_catalog.py   (requer Pillow e numpy)
"""
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
TILES = os.path.join(ROOT, "assets", "art", "tiles")
OUT = os.path.join(ROOT, "scripts", "art", "extra_catalog.gd")
TOWN_CELL = 64.0
OUR_CELL = 80.0

# Prédios do Town Sampler usados no mapa: nome -> (peso nas vilas, peso nas ruínas)
TOWN_BUILDINGS = {
    "soviet_khrushchyovka": (22, 10),
    "neon_noodle_corner": (16, 4),
    "neon_shop_row": (16, 4),
    "soviet_bus_station": (4, 0),
}
TOWN_PROPS = ["neon_neon_lamp", "neon_vending_machine", "soviet_lamp_post"]

# Objetos do Neon District por grupo de uso no mapa.
# rua: ao longo das estradas | vila: comércio nas praças | industria: ruínas e quintais
# abrigo: sobrevivência no Abrigo Alfa | chao: objetos planos (camada do chão)
NEON = {
    "rua": ["cyber_0048", "cyber_0056", "cyber_0041", "cyber_0072", "cyber_0496", "cyber_0512",
            "cyber_0080"],
    "chao": ["cyber_0064"],
    "vila": ["cyber_0001", "cyber_0008", "cyber_0016", "cyber_0024", "cyber_0032", "cyber_0081",
             "cyber_0096", "cyber_0176", "cyber_0304", "cyber_0312", "cyber_0272", "cyber_0040",
             "cyber_0200", "cyber_0161"],
    "industria": ["cyber_0121", "cyber_0128", "cyber_0136", "cyber_0168", "cyber_0184", "cyber_0192",
                  "cyber_0401", "cyber_0408", "cyber_0424", "cyber_0432", "cyber_0536", "cyber_0160"],
    "abrigo": ["cyber_0416", "cyber_0561", "cyber_0568", "cyber_0576", "cyber_0584", "cyber_0592"],
}


def opaque(path, thr=250):
    a = np.array(Image.open(path).convert("RGBA"))
    return a[:, :, 3] >= thr, a


def measure_building(path, frame_w):
    op, _ = opaque(path)
    op = op[:, :frame_w]
    xs = np.where(op.any(axis=0))[0]
    ys = np.where(op.any(axis=1))[0]
    xl, xr, yb = int(xs[0]), int(xs[-1]), int(ys[-1])
    left = (xl, int(np.where(op[:, xl])[0].max()))
    bottom = (float(np.where(op[yb])[0].mean()), yb)
    a = max((bottom[0] - left[0]) / (TOWN_CELL / 2.0), 0.5)
    b = max((xr - bottom[0]) / (TOWN_CELL / 2.0), 0.5)
    # centro da base no chão: do canto inferior, volta meia pegada em cada eixo
    cx = bottom[0] - (TOWN_CELL / 4.0) * (a - b)
    cy = bottom[1] - (TOWN_CELL / 8.0) * (a + b)
    k = TOWN_CELL / OUR_CELL
    fp = (max(1, round(a * k)), max(1, round(b * k)))
    return {"center": (round(cx), round(cy)), "fp": fp, "size": (a, b)}


def measure_prop(path, flat=False):
    op, _ = opaque(path, 128)
    ys = np.where(op.any(axis=1))[0]
    xs = np.where(op.any(axis=0))[0]
    x0, x1, y0, y1 = int(xs[0]), int(xs[-1]), int(ys[0]), int(ys[-1])
    if flat:
        anchor = ((x0 + x1) / 2.0, (y0 + y1) / 2.0)
    else:
        rows = op[max(y1 - 3, 0):y1 + 1]
        bx = float(np.where(rows.any(axis=0))[0].mean())
        anchor = (bx, y1 - 3)
    width = x1 - x0 + 1
    radius = 0 if flat else int(min(16, max(6, width * 0.3)))
    return {"r": (x0, y0, x1, y1), "a": (round(anchor[0]), round(anchor[1])), "radius": radius}


def main():
    town = os.path.join(TILES, "town")
    man = json.load(open(os.path.join(town, "manifest_192.json")))
    sizes = {b["name"]: (b["w"], b["h"]) for b in man["buildings"] + man["props"]}
    L = ["# GERADO por tools/build_extra_catalog.py - não edite à mão.",
         "class_name ExtraCatalog",
         "extends RefCounted",
         "## Pacotes extras: Town Sampler (prédios e postes noturnos) e Neon District (objetos).",
         "## c = centro da base no chão (px do quadro), fp = pegada em células 80x40,",
         "## r = área útil [x0,y0,x1,y1], a = âncora no chão, radius = colisão (0 = sem colisão).",
         "",
         'const TOWN_DIR := "res://assets/art/tiles/town/sprites_192/"',
         "const ANIM_FRAMES := %d" % man["anim_frames"],
         "const FRAME_MS := %d" % man["frame_ms"],
         "",
         "const BUILDINGS := {"]
    for name, (wv, wr) in TOWN_BUILDINGS.items():
        w, h = sizes[name]
        m = measure_building(os.path.join(town, "sprites_192", "buildings", "night", name + ".png"), w)
        anim = os.path.exists(os.path.join(town, "sprites_192", "buildings", "anim", name + ".png"))
        L.append('\t"%s": {"w": %d, "h": %d, "c": [%d, %d], "fp": [%d, %d], "anim": %s, "peso_vila": %d, "peso_ruina": %d},'
                 % (name, w, h, m["center"][0], m["center"][1], m["fp"][0], m["fp"][1],
                    "true" if anim else "false", wv, wr))
        print("prédio %-22s pegada pacote %.1fx%.1f -> nossa %dx%d" % (name, m["size"][0], m["size"][1], *m["fp"]))
    L.append("}")
    L.append("")
    L.append("const TOWN_PROPS := {")
    for name in TOWN_PROPS:
        w, h = sizes[name]
        m = measure_prop(os.path.join(town, "sprites_192", "props", "night", name + ".png"))
        anim = os.path.exists(os.path.join(town, "sprites_192", "props", "anim", name + ".png"))
        L.append('\t"%s": {"w": %d, "h": %d, "r": [%d, %d, %d, %d], "a": [%d, %d], "radius": %d, "anim": %s},'
                 % (name, w, h, *m["r"], *m["a"], m["radius"], "true" if anim else "false"))
    L.append("}")
    L.append("")
    nd = os.path.join(TILES, "neon_district")
    names = {o["id"]: o["name"] for o in json.load(open(os.path.join(nd, "catalog.json")))["objects"]}
    L.append('const NEON_DIR := "res://assets/art/tiles/neon_district/64px/individual/"')
    L.append("const NEON := {")
    for group, ids in NEON.items():
        for i in ids:
            m = measure_prop(os.path.join(nd, "64px", "individual", i + ".png"), flat=group == "chao")
            L.append('\t"%s": {"grupo": "%s", "r": [%d, %d, %d, %d], "a": [%d, %d], "radius": %d},  # %s'
                     % (i, group, *m["r"], *m["a"], m["radius"], names[i]))
    L.append("}")
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(L) + "\n")
    print("gerado:", OUT)


if __name__ == "__main__":
    main()

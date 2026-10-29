#!/usr/bin/env python3
"""Arte dos prédios exploráveis (ver assets/art/STYLE.md).

Os prédios do mapa são montados no jogo com piso (ladrilhos do chão), paredes nas bordas
das células (como as paredes que o jogador constrói), telhado e móveis. Aqui saem:

* paredes de prédio: material x variação, nas duas direções de borda; cada folha tem as
  colunas [cheia, baixa, cheia aberta, baixa aberta] (a versão baixa é o corte do The Sims,
  usada quando o jogador está atrás dela);
* telhados por tamanho de pegada e estilo (vistos no mesmo formato dos prédios: vértice
  inferior da pegada como âncora);
* móveis e entulho para os cômodos.
"""
import math

import numpy as np

from art_render import Part, combine, pat_planks, pat_seams, render, rot_x, rot_y, rot_z
from gen_city import _h, pat_bricks, pat_chips, pat_corrugated, prop_model

WALL_H = 0.95
LOW_H = 0.20
T = 0.05

MATERIALS = {
    # material: (rampa, padrão, arremate, folha da porta)
    "tijolo": ("rust", lambda: combine(pat_bricks(), pat_chips(3, 0.02)), "grey", "wood"),
    "concreto": ("slate", lambda: combine(pat_seams(0.5, (1, 1, 0)), pat_seams(0.48, (0, 0, 1)), pat_chips(5, 0.03)), "grey", "steel"),
    "reboco": ("bone", lambda: pat_chips(7, 0.04), "rust", "wood"),
    "madeira": ("wood", lambda: pat_planks(0.12, 2), "rust", "wood"),
    "chapa": ("steel", lambda: combine(pat_corrugated(0.06), pat_chips(9, 0.02)), "slate", "steel"),
}
VARIANTS = ["parede", "janela", "janela_q", "porta", "vitrine", "quebrada", "esporos"]


def _slab(d, hx, hy, hz, mat, pos, **kw):
    """Peça descrita para a borda d=1 (corre em x); para d=0 troca os eixos."""
    if d == 0:
        hx, hy = hy, hx
        pos = (pos[1], pos[0], pos[2])
    return Part("box", (hx, hy, hz), mat, pos, **kw)


def clip_parts(parts, zmax):
    """Corta tudo acima de zmax (parede baixa do corte estilo The Sims)."""
    out = []
    for p in parts:
        hz = p.size[2] if p.shape == "box" else (p.size[1] if p.shape == "cyl" else p.size[2])
        bottom = p.pos[2] - hz
        top = p.pos[2] + hz
        if bottom >= zmax - 0.005:
            continue
        if top <= zmax:
            out.append(p)
            continue
        nh = (zmax - bottom) / 2.0
        size = p.size.copy()
        if p.shape == "box":
            size[2] = nh
        elif p.shape == "cyl":
            size[1] = nh
        else:
            size[2] = nh
        out.append(Part(p.shape, size, p.mat, (p.pos[0], p.pos[1], bottom + nh), p.rot, p.pattern, p.bevel))
    return out


def map_wall(material, variant, d, open_=False):
    ramp, pat, cap, leaf = MATERIALS[material]
    S = lambda *a, **k: _slab(d, *a, **k)
    P = []
    H = WALL_H
    if variant in ("parede", "esporos"):
        P.append(S(0.5, T, H / 2, ramp, (0, 0, H / 2), pattern=pat()))
    elif variant in ("janela", "janela_q"):
        P.append(S(0.5, T, 0.18, ramp, (0, 0, 0.18), pattern=pat()))
        P.append(S(0.5, T, 0.10, ramp, (0, 0, H - 0.10), pattern=pat()))
        P.append(S(0.1, T, H / 2, ramp, (0.4, 0, H / 2), pattern=pat()))
        P.append(S(0.1, T, H / 2, ramp, (-0.4, 0, H / 2), pattern=pat()))
        P.append(S(0.31, T + 0.012, 0.015, cap, (0, 0, 0.37)))
        if variant == "janela":
            P.append(S(0.30, 0.012, 0.2, "glow_dim", (0, 0, 0.57)))
            P.append(S(0.01, 0.02, 0.2, "dark", (0, 0, 0.57)))
        else:
            # vidro quebrado: cacos nas bordas
            P.append(S(0.08, 0.012, 0.06, "glow_dim", (-0.22, 0, 0.42)))
            P.append(S(0.05, 0.012, 0.09, "glow_dim", (0.25, 0, 0.70)))
            P.append(S(0.30, 0.004, 0.2, "dark", (0, -0.03, 0.57)))
    elif variant == "porta":
        P.append(S(0.08, T + 0.01, H / 2, ramp, (0.42, 0, H / 2), pattern=pat()))
        P.append(S(0.08, T + 0.01, H / 2, ramp, (-0.42, 0, H / 2), pattern=pat()))
        P.append(S(0.5, T + 0.01, 0.07, ramp, (0, 0, H - 0.07), pattern=pat()))
        lh = (H - 0.14) / 2
        if not open_:
            lp = pat_planks(0.09, 0) if leaf == "wood" else combine(pat_seams(0.09, (1, 1, 0)), pat_seams(0.2, (0, 0, 1)))
            P.append(S(0.34, T * 0.6, lh, leaf, (0, 0, lh), pattern=lp))
            P.append(S(0.02, T, 0.03, "glow_amber", (0.24, 0, 0.42)))
        else:
            q = Part("box", (0.02, 0.28, lh), leaf, (-0.34, 0.28, lh))
            if d == 0:
                q = Part("box", (0.28, 0.02, lh), leaf, (0.28, -0.34, lh))
            P.append(q)
    elif variant == "vitrine":
        P.append(S(0.5, T, 0.07, ramp, (0, 0, 0.07), pattern=pat()))
        P.append(S(0.5, T, 0.12, ramp, (0, 0, H - 0.12), pattern=pat()))
        P.append(S(0.48, 0.012, 0.31, "teal", (0, 0, 0.45), pattern=pat_seams(0.45, (1, 1, 0))))
        P.append(S(0.03, T, 0.31, "dark", (0.47, 0, 0.45)))
    elif variant == "quebrada":
        h1 = 0.25 + 0.3 * _h(len(material), d, 1)
        h2 = 0.12 + 0.2 * _h(len(material), d, 2)
        P.append(S(0.28, T, h1 / 2, ramp, (-0.22, 0, h1 / 2), pattern=pat()))
        P.append(S(0.22, T, h2 / 2, ramp, (0.28, 0, h2 / 2), pattern=pat()))
        for i in range(3):
            P.append(Part("box", (0.07, 0.05, 0.03), ramp if i % 2 else "grey",
                          (0.15 * (i - 1) * (1 if d else 0) + (0.09 if d == 0 else 0), 0.12 * (i - 1) * (0 if d else 1) + (0.09 if d else 0), 0.03),
                          rot_z(30 * i)))
    if variant == "esporos":
        for i in range(5):
            u = -0.38 + 0.19 * i
            z = 0.12 + 0.6 * _h(i, d, 7)
            r = 0.06 + 0.06 * _h(i, d, 8)
            for side in (1, -1):
                mat = "fungus_pink" if (i + side) % 3 == 0 else "fungus"
                P.append(Part("ell", (r, r, r * 1.2), mat, (u, side * (T + r * 0.4), z) if d == 1 else (side * (T + r * 0.4), u, z)))
    elif variant != "quebrada":
        P.append(S(0.5, T + 0.012, 0.025, cap, (0, 0, H - 0.025)))
    return P


def wall_sheet_rows(material, variant, R):
    """Linhas d=0 e d=1; colunas [cheia, baixa] (+ [aberta cheia, aberta baixa] nas portas)."""
    rows = []
    for d in (0, 1):
        full = map_wall(material, variant, d)
        row = [R(full), R(clip_parts(full, LOW_H))]
        if variant == "porta":
            op = map_wall(material, variant, d, True)
            row += [R(op), R(clip_parts(op, LOW_H))]
        rows.append(row)
    return rows


# ====================================================================== telhados
ROOF_STYLES = ["laje", "laje_metal", "telha", "telha_cinza", "esporos"]
ROOF_SIZES = [(w, d) for w in range(3, 9) for d in range(3, 8)]


def roof_model(style, w, d):
    """Telhado sobre a pegada [-w,0] x [-d,0], apoiado no topo das paredes."""
    H = WALL_H
    cx, cy = -w / 2.0, -d / 2.0
    P = []
    if style in ("laje", "laje_metal", "esporos"):
        mat = "slate" if style != "laje_metal" else "steel"
        pat = pat_chips(11, 0.04, 0.15) if style != "laje_metal" else pat_seams(0.4, (1, 0, 0))
        P.append(Part("box", (w / 2 + 0.04, d / 2 + 0.04, 0.05), mat, (cx, cy, H + 0.05), pattern=pat))
        e = 0.05
        for (px, py, hx, hy) in ((cx, -d - 0.04 + e, w / 2 + 0.04, e), (cx, 0.04 - e, w / 2 + 0.04, e),
                                 (-w - 0.04 + e, cy, e, d / 2 + 0.04), (0.04 - e, cy, e, d / 2 + 0.04)):
            P.append(Part("box", (hx, hy, 0.05), "grey" if style != "esporos" else "fungus", (px, py, H + 0.15)))
        for i in range(2 + int(w * d / 10)):
            ax = -w * (0.2 + 0.6 * _h(w, d, i, 1))
            ay = -d * (0.2 + 0.6 * _h(w, d, i, 2))
            if style == "esporos":
                r = 0.18 + 0.2 * _h(i, 3)
                P.append(Part("ell", (r, r, r * 0.6), "fungus_pink" if i % 3 == 0 else "fungus", (ax, ay, H + 0.1)))
            elif i < 2:
                if i == 0:
                    P.append(Part("box", (0.2, 0.15, 0.12), "bone", (ax, ay, H + 0.22), pattern=pat_seams(0.1, (0, 1, 0))))
                else:
                    P.append(Part("box", (0.1, 0.1, 0.1), "grey", (ax, ay, H + 0.2)))
        return P
    # duas águas a 28 graus, cumeeira no lado maior
    mat = "rust" if style == "telha" else "grey"
    slope = math.radians(28)
    along_x = w >= d
    L, S = (w, d) if along_x else (d, w)
    half = (S / 2 + 0.1) / math.cos(slope)
    rise = (S / 2) * math.tan(slope)
    for sgn in (1, -1):
        if along_x:
            P.append(Part("box", (L / 2 + 0.08, half / 2, 0.03), mat, (cx, cy + sgn * S / 4, H + rise / 2), rot_x(-sgn * 28),
                          pattern=pat_seams(0.09, (1, 0, 0))))
        else:
            P.append(Part("box", (half / 2, L / 2 + 0.08, 0.03), mat, (cx + sgn * S / 4, cy, H + rise / 2),
                          rot_y(sgn * 28), pattern=pat_seams(0.09, (0, 1, 0))))
    # empenas em degraus
    steps = 6
    for i in range(steps):
        hz = rise / steps
        wy = (S / 2) * (1 - (i + 0.5) / steps)
        for e in (0.02, L - 0.02):
            if along_x:
                P.append(Part("box", (0.02, wy, hz / 2), "bone", (-e, cy, H + hz * (i + 0.5)), bevel=False))
            else:
                P.append(Part("box", (wy, 0.02, hz / 2), "bone", (cx, -e, H + hz * (i + 0.5)), bevel=False))
    P.append(Part("box", (0.06, 0.06, 0.18), "grey", (cx - w * 0.2, cy - d * 0.15, H + rise * 0.7), pattern=pat_bricks()))
    return P


def render_roof(style, w, d, margin=12):
    parts = roof_model(style, w, d)
    ztop = max(p.pos[2] + float(np.max(np.abs(p.size))) for p in parts)
    Wc = int((w + d) * 40 + 2 * margin)
    Hc = int((w + d) * 20 + ztop * 49 + margin + 30)
    ox, oy = w * 40 + margin, Hc - margin
    img = render(parts, Wc, Hc, ox, oy)
    a = img[:, :, 3] > 0
    ys = np.where(a.any(axis=1))[0]
    xs = np.where(a.any(axis=0))[0]
    y0, x0, x1 = int(ys[0]), int(xs[0]), int(xs[-1]) + 1
    img = img[y0:int(ys[-1]) + 1, x0:x1]
    return img, (ox - x0, oy - y0)


# ====================================================================== móveis
def furniture_model(name, var=0):
    if name == "geladeira":
        return [Part("box", (0.18, 0.2, 0.42), "bone", (0, 0, 0.42), pattern=pat_seams(0.55, (0, 0, 1))),
                Part("box", (0.012, 0.02, 0.12), "grey", (0.185, 0.14, 0.62))]
    if name == "fogao":
        return [Part("box", (0.2, 0.22, 0.2), "bone", (0, 0, 0.2)), Part("box", (0.2, 0.22, 0.01), "dark", (0, 0, 0.41)),
                Part("cyl", (0.06, 0.012), "grey", (0.07, 0.09, 0.42)), Part("cyl", (0.06, 0.012), "grey", (-0.07, -0.09, 0.42)),
                Part("box", (0.012, 0.16, 0.1), "dark", (0.2, 0, 0.18))]
    if name == "pia":
        return [Part("box", (0.2, 0.4, 0.2), "wood", (0, 0, 0.2), pattern=pat_seams(0.2, (0, 1, 0))),
                Part("box", (0.22, 0.42, 0.02), "bone", (0, 0, 0.42)), Part("box", (0.14, 0.14, 0.01), "steel", (0, 0.1, 0.44)),
                Part("cyl", (0.012, 0.06), "grey", (-0.12, 0.1, 0.5))]
    if name == "balcao":
        return [Part("box", (0.2, 0.46, 0.24), "rust", (0, 0, 0.24), pattern=pat_planks(0.08, 2)),
                Part("box", (0.23, 0.48, 0.02), "slate", (0, 0, 0.5)), Part("box", (0.08, 0.1, 0.06), "dark", (0, 0.25, 0.58))]
    if name == "prateleira":
        P = [Part("box", (0.14, 0.44, 0.02), "steel", (0, 0, z)) for z in (0.1, 0.36, 0.62, 0.88)]
        P += [Part("box", (0.02, 0.02, 0.45), "steel", (x, y, 0.45)) for x in (0.12, -0.12) for y in (0.42, -0.42)]
        cols = ["red", "mustard", "teal", "bone", "olive"]
        for k, z in enumerate((0.16, 0.42, 0.68)):
            for i in range(4):
                if _h(var, k, i) < 0.6 - 0.25 * var:
                    P.append(Part("box", (0.08, 0.07, 0.05), cols[(k + i) % 5], (0.02, -0.33 + 0.22 * i, z)))
        return P
    if name == "armario":
        return [Part("box", (0.16, 0.36, 0.5), "wood", (0, 0, 0.5), pattern=pat_seams(0.36, (0, 1, 0))),
                Part("box", (0.012, 0.02, 0.06), "mustard", (0.165, 0.05, 0.5)), Part("box", (0.012, 0.02, 0.06), "mustard", (0.165, -0.05, 0.5))]
    if name == "tv":
        return [Part("box", (0.14, 0.3, 0.14), "wood", (0, 0, 0.14)), Part("box", (0.04, 0.26, 0.15), "dark", (0, 0, 0.45)),
                Part("box", (0.045, 0.22, 0.11), "glow_dim", (0, 0, 0.45))]
    if name == "maca":
        return [Part("box", (0.42, 0.18, 0.04), "bone", (0, 0, 0.4)), Part("box", (0.1, 0.16, 0.04), "bone", (-0.3, 0, 0.47)),
                Part("box", (0.03, 0.03, 0.18), "steel", (0.35, 0.14, 0.18)), Part("box", (0.03, 0.03, 0.18), "steel", (-0.35, -0.14, 0.18)),
                Part("box", (0.03, 0.03, 0.18), "steel", (0.35, -0.14, 0.18)), Part("box", (0.03, 0.03, 0.18), "steel", (-0.35, 0.14, 0.18)),
                Part("box", (0.08, 0.02, 0.02), "red", (0.1, 0.19, 0.42))]
    if name == "arquivo":
        return [Part("box", (0.16, 0.16, 0.36), "steel", (0, 0, 0.36), pattern=pat_seams(0.18, (0, 0, 1))),
                Part("box", (0.012, 0.06, 0.012), "grey", (0.165, 0, 0.55)), Part("box", (0.012, 0.06, 0.012), "grey", (0.165, 0, 0.2))]
    if name == "entulho":
        P = []
        for i in range(6):
            P.append(Part("box", (0.08 + 0.06 * _h(var, i), 0.06 + 0.04 * _h(var, i, 2), 0.03 + 0.02 * _h(i, 3)),
                          ["grey", "rust", "slate", "wood"][i % 4],
                          (0.3 * (_h(var, i, 4) - 0.5), 0.3 * (_h(var, i, 5) - 0.5), 0.03 + 0.03 * (i % 3)), rot_z(60 * _h(i, var))))
        return P
    if name == "fungo":
        return [Part("ell", (0.24, 0.2, 0.06), "fungus", (0, 0, 0.03)), Part("ell", (0.08, 0.08, 0.1), "fungus_pink", (0.08, 0.05, 0.1)),
                Part("ell", (0.05, 0.05, 0.07), "fungus_pink", (-0.1, -0.04, 0.08)), Part("ell", (0.025, 0.025, 0.02), "glow_magenta", (0.08, 0.05, 0.2))]
    if name == "bancada":
        return prop_model("paletes")
    raise KeyError(name)


FURNITURE = {
    "geladeira": {"raio": 10, "frames": 1}, "fogao": {"raio": 10, "frames": 1}, "pia": {"raio": 11, "frames": 1},
    "balcao": {"raio": 12, "frames": 1}, "prateleira": {"raio": 12, "frames": 2}, "armario": {"raio": 11, "frames": 1},
    "tv": {"raio": 9, "frames": 1}, "maca": {"raio": 12, "frames": 1}, "arquivo": {"raio": 8, "frames": 1},
    "entulho": {"raio": 0, "frames": 3}, "fungo": {"raio": 0, "frames": 1},
}

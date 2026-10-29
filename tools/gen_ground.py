#!/usr/bin/env python3
"""Ladrilhos do chão (losangos 80x40) no padrão visual do Esporos (ver assets/art/STYLE.md).

Regras do padrão aplicadas aqui:
  * cor sólida por superfície; nada de ruído de 1 px;
  * detalhes em "lascas" alinhadas à grade isométrica (paralelogramos de 2 px ou mais),
    com 1 ou 2 tons vizinhos da mesma rampa e pouca área (menos de ~10%);
  * linhas (juntas, faixas) seguem os eixos da grade, em degraus de 2 px por 1 px;
  * nenhum detalhe cruza a borda do losango, então os ladrilhos se repetem sem emendas.

Coordenadas no losango: u vai do vértice de cima ao da direita (eixo x do mapa) e
v vai do vértice de cima ao da esquerda (eixo y do mapa), ambos de 0 a 1.
"""
import numpy as np

from art_render import RAMP_RGB, hex_rgb

TW, TH = 80, 40
VARIANTS = 3

# A ordem é o enum T de scripts/world/world.gd (os índices vão para os saves).
GROUND_TYPES = ["CONC_A", "CONC_B", "ESPOROS", "ESTRADA", "TERRA", "PISO", "MANCHA", "VILA",
                "PISO_MADEIRA", "PISO_CONCRETO", "GRAMA", "GRAMA_SECA", "CALCADA", "FAIXA_X", "FAIXA_Y",
                "TERRA_BATIDA", "ZEBRA_X", "ZEBRA_Y", "LAVOURA", "GRAMA_ESPOROS", "AZULEJO", "CARPETE"]


def C(h):
    return np.array(hex_rgb(h), dtype=np.uint8)


def R(ramp, i):
    return RAMP_RGB[ramp][i]


class Rng:
    def __init__(self, seed):
        self.s = seed * 2654435761 % 4294967296 or 1

    def f(self):
        self.s = (self.s * 1103515245 + 12345) % 2147483648
        return self.s / 2147483648.0

    def i(self, a, b):
        return a + int(self.f() * (b - a + 1))


def _uv():
    yy, xx = np.mgrid[0:TH, 0:TW]
    # centro do pixel; o losango do ladrilho tem vértices (40,0) (80,20) (40,40) (0,20)
    x = xx + 0.5
    y = yy + 0.5
    u = x / TW + y / TH - 0.5
    v = y / TH - x / TW + 0.5
    inside = (u >= 0) & (u <= 1) & (v >= 0) & (v <= 1)
    return u, v, inside


U, V, INSIDE = _uv()


def chips(base, rng, n, colors, umin=0.04, umax=0.96, size=((0.05, 0.12), (0.05, 0.1)), mask=None, ell=True):
    """Lascas: pequenos paralelogramos alinhados à grade (u,v)."""
    for _ in range(n):
        w = size[0][0] + rng.f() * (size[0][1] - size[0][0])
        h = size[1][0] + rng.f() * (size[1][1] - size[1][0])
        a = umin + rng.f() * (umax - umin - w)
        b = umin + rng.f() * (umax - umin - h)
        m = (U >= a) & (U < a + w) & (V >= b) & (V < b + h)
        if mask is not None:
            m &= mask
        base[m] = colors[int(rng.f() * len(colors)) % len(colors)]
        # às vezes um "L" (como as marcas do pacote)
        if ell and rng.f() < 0.25:
            m2 = (U >= a) & (U < a + w * 2.2) & (V >= b + h) & (V < b + h + 0.04)
            if mask is not None:
                m2 &= mask
            base[m2] = colors[0]


def line_u(c, t=0.025):
    """Linha ao longo de u (eixo x do mapa) na altura v=c."""
    return np.abs(V - c) < t


def line_v(c, t=0.025):
    return np.abs(U - c) < t


def tufts(base, rng, n, dark, light, mask=None):
    """Tufos de grama: 'V' de 3x2 px (escuro embaixo, claro em cima)."""
    for _ in range(n):
        x = rng.i(8, TW - 10)
        y = rng.i(5, TH - 6)
        if not INSIDE[y, x] or not INSIDE[y - 2, x - 2] or not INSIDE[y, x + 2]:
            continue
        if mask is not None and not mask[y, x]:
            continue
        base[y, x - 1:x + 2] = dark
        base[y - 1, x - 2] = light
        base[y - 1, x + 2] = light
        base[y - 2, x - 2] = light
        base[y - 1, x] = light


def tile(kind, var):
    rng = Rng(GROUND_TYPES.index(kind) * 31 + var * 7 + 3)
    base = np.zeros((TH, TW, 3), dtype=np.uint8)

    if kind in ("CONC_A", "CONC_B", "PISO_CONCRETO"):
        # concreto: placas lisas (pátios, lotes) — tons do pacote
        top = {"CONC_A": "#404156", "CONC_B": "#484f6a", "PISO_CONCRETO": "#575772"}[kind]
        base[:] = C(top)
        dark = C("#2c2a48") if kind != "PISO_CONCRETO" else C("#404156")
        if kind != "CONC_A":
            base[line_u(0.5, 0.018) | line_v(0.5, 0.018)] = dark
        base[line_u(0.012, 0.014) | line_v(0.012, 0.014)] = dark
        chips(base, rng, 1 + var, [dark, C("#383e4b")])
        if var == 2:
            # rachadura em degraus
            u0, v0 = 0.2 + rng.f() * 0.3, 0.3 + rng.f() * 0.3
            for k in range(7):
                m = (U >= u0 + k * 0.06) & (U < u0 + k * 0.06 + 0.07) & (np.abs(V - (v0 + (k % 3) * 0.03)) < 0.016)
                base[m] = dark
    elif kind == "CALCADA":
        # calçada clara em 2x2 placas, como as do pacote
        base[:] = C("#8b89a3")
        seam = C("#68657c")
        base[line_u(0.5, 0.016) | line_v(0.5, 0.016)] = seam
        base[line_u(0.01, 0.012) | line_v(0.01, 0.012)] = seam
        chips(base, rng, 2 + var, [C("#79788d"), C("#747e91")])
        if var == 1:
            base[(U > 0.62) & (U < 0.7) & (V > 0.2) & (V < 0.26)] = C("#5a5d7d")
    elif kind == "ESTRADA" or kind.startswith("FAIXA") or kind.startswith("ZEBRA"):
        base[:] = C("#2a2e39")
        chips(base, rng, 2 + var, [C("#383e4b"), C("#252734")], size=((0.06, 0.16), (0.04, 0.08)))
        paint = C("#a58077") if var != 2 else C("#927b78")
        if kind == "FAIXA_X":
            # tracejado na borda v=0 (entre as duas pistas de uma rua de 2 células)
            dash = ((U * 4) % 1 < 0.55) & (V < 0.035)
            base[dash] = paint
        elif kind == "FAIXA_Y":
            dash = ((V * 4) % 1 < 0.55) & (U < 0.035)
            base[dash] = paint
        elif kind == "ZEBRA_X":
            # faixa de pedestre atravessando uma rua que corre ao longo de x
            base[((V * 5) % 1 < 0.5) & (U > 0.18) & (U < 0.82)] = C("#8b89a3")
        elif kind == "ZEBRA_Y":
            base[((U * 5) % 1 < 0.5) & (V > 0.18) & (V < 0.82)] = C("#8b89a3")
    elif kind == "MANCHA":
        # asfalto velho de estacionamento: remendos e óleo
        base[:] = C("#2d2f32")
        chips(base, rng, 3, [C("#3d3f42"), C("#252734")], size=((0.12, 0.3), (0.08, 0.2)))
        chips(base, rng, 3, [C("#383e4b")])
    elif kind == "TERRA":
        base[:] = C("#4f3d43")
        chips(base, rng, 3 + var, [R("rust", 1), R("rust", 2)], size=((0.06, 0.14), (0.04, 0.08)))
        if var == 1:
            chips(base, rng, 2, [C("#51575d")], size=((0.04, 0.06), (0.03, 0.05)))  # pedrinhas
    elif kind == "TERRA_BATIDA":
        # estrada de terra: trilhas de pneu mais escuras ao longo de x e de y
        base[:] = C("#6e5554")
        chips(base, rng, 3, [R("rust", 2), C("#84686d")], size=((0.06, 0.14), (0.04, 0.07)))
    elif kind == "LAVOURA":
        # sulcos de plantio ao longo de x
        base[:] = R("rust", 1)
        rows = (V * 5) % 1
        base[rows < 0.32] = R("rust", 0)
        sprout = (rows > 0.55) & (rows < 0.8) & (((U * 9) % 1) < 0.3)
        base[sprout] = R("olive", 2)
    elif kind in ("GRAMA", "GRAMA_SECA", "GRAMA_ESPOROS"):
        ramp = "fungus" if kind != "GRAMA_SECA" else "olive"
        base[:] = R(ramp, 1)
        patch = [R(ramp, 2), R(ramp, 0)] if kind != "GRAMA_SECA" else [R("olive", 2), R("rust", 1)]
        chips(base, rng, 2 + var, patch[:1], size=((0.08, 0.16), (0.08, 0.16)), ell=False)
        chips(base, rng, 1, patch[1:], size=((0.05, 0.09), (0.05, 0.09)), ell=False)
        tufts(base, rng, 1 + var, R(ramp, 0), R(ramp, 2))
        if kind == "GRAMA_ESPOROS":
            chips(base, rng, 4, [R("fungus_pink", 2), R("fungus_pink", 1)], size=((0.05, 0.1), (0.04, 0.08)))
    elif kind == "ESPOROS":
        # carpete de fungo: manchas grandes, poucos brilhos
        base[:] = R("fungus", 0)
        chips(base, rng, 5, [R("fungus", 1)], size=((0.14, 0.3), (0.1, 0.24)))
        chips(base, rng, 3, [R("fungus_pink", 1), R("fungus", 2)], size=((0.05, 0.1), (0.04, 0.08)))
        if var == 2:
            chips(base, rng, 2, [C("#a6d65c")], size=((0.03, 0.04), (0.025, 0.035)))
    elif kind == "VILA":
        # praça: lajotas grandes alternadas, juntas escuras
        base[:] = C("#575772")
        alt = ((np.floor(U * 2) + np.floor(V * 2)) % 2) == 0
        base[alt] = C("#5a5d7d")
        base[line_u(0.5, 0.016) | line_v(0.5, 0.016) | line_u(0.01, 0.012) | line_v(0.01, 0.012)] = C("#404156")
        chips(base, rng, 2, [C("#4c4f64")])
    elif kind == "PISO":
        # chapa de metal com relevo em losangos
        base[:] = R("steel", 2)
        bump = (((U * 8) % 1) < 0.22) & (((V * 8) % 1) < 0.22)
        base[bump] = R("steel", 3)
        base[line_u(0.01, 0.015) | line_v(0.01, 0.015)] = R("steel", 1)
    elif kind == "PISO_MADEIRA":
        base[:] = R("wood", 2)
        board = np.floor(V * 5)
        base[(board % 2) == 0] = R("wood", 3)
        base[(V * 5) % 1 < 0.1] = R("wood", 1)
        stag = (((U * 2 + board * 0.5) % 1) < 0.03)
        base[stag] = R("wood", 1)
    elif kind == "AZULEJO":
        # piso de cerâmica: quadradinhos claros com rejunte, alguns trincados
        base[:] = C("#9898a3")
        alt = ((np.floor(U * 4) + np.floor(V * 4)) % 2) == 0
        base[alt] = C("#8b89a3")
        base[((U * 4) % 1 < 0.06) | ((V * 4) % 1 < 0.06)] = C("#68657c")
        chips(base, rng, 1 + var, [C("#747e91")], size=((0.05, 0.08), (0.04, 0.07)), ell=False)
    elif kind == "CARPETE":
        base[:] = R("red", 1)
        base[((U * 6) % 1 < 0.1) & ((V * 6) % 1 < 0.1)] = R("red", 2)
        chips(base, rng, 2 + var, [R("red", 0)], size=((0.08, 0.16), (0.06, 0.12)), ell=False)
    img = np.zeros((TH, TW, 4), dtype=np.uint8)
    img[:, :, :3] = base
    img[:, :, 3] = np.where(INSIDE, 255, 0)
    return img


def atlas():
    out = np.zeros((TH * VARIANTS, TW * len(GROUND_TYPES), 4), dtype=np.uint8)
    for ti, k in enumerate(GROUND_TYPES):
        for v in range(VARIANTS):
            out[v * TH:(v + 1) * TH, ti * TW:(ti + 1) * TW] = tile(k, v)
    return out

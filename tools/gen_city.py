#!/usr/bin/env python3
"""Kit urbano, rural e industrial do Esporos, desenhado no padrão do pacote FreeSample
(ver assets/art/STYLE.md). Substitui os objetos do Neon District e os prédios do Town
Sampler, que tinham outra densidade de pixel.

* PROPS: objetos de uma célula (uma vista; alguns com quadros ligado/desligado ou variações).
Os prédios são exploráveis e saem de tools/gen_town.py (paredes, telhados e móveis).

Unidades: 1 = aresta de uma célula; altura de um andar = FLOOR (~2,5 m, 59 px).
"""
import math

import numpy as np

from art_render import (Part, RAMP_RGB, combine, hex_rgb, pat_hazard, pat_planks, pat_seams, render,
                        rot_x, rot_y, rot_z, transform)

FLOOR = 1.2


def C(h):
    return np.array(hex_rgb(h), dtype=np.uint8)


def _h(*a):
    v = 2166136261
    for x in a:
        v = ((v ^ (int(x) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    return v / 4294967295.0


# ====================================================================== padrões
def pat_windows(spacing=0.5, win_w=0.24, z0=0.3, floor_h=FLOOR, win_h=0.5, zmax=99.0, seed=1,
                lit=0.25, broken=0.12, boarded=0.08, glass="#2c3350", frame="#121321", skip_axis=None,
                shop_until=-1.0, zoff=0.0):
    """Janelas numa grade sobre as faces laterais de uma caixa (coordenadas locais).
    Cada janela sorteia: acesa (âmbar), escura, quebrada (preta) ou tapada com tábuas."""
    cols = {"glass": C(glass), "lit": C("#ffb84a"), "lit2": C("#e3c76a"), "broken": C("#0b0b14"),
            "board": RAMP_RGB["wood"][2], "board2": RAMP_RGB["wood"][1], "frame": C(frame),
            "refl": C("#484f6a")}

    def f(p, n):
        N = len(p)
        mask = np.zeros(N, dtype=bool)
        col = np.zeros((N, 3), dtype=np.uint8)
        for ax, hz in ((0, 1), (1, 0)):
            if skip_axis == ax:
                continue
            face = np.abs(n[:, ax]) > 0.9
            hpos = p[:, hz]
            z = p[:, 2] + zoff
            ci = np.floor((hpos + 50.0) / spacing)
            fx = ((hpos + 50.0) / spacing) % 1.0
            zi = np.floor((z - z0 + 50.0 * floor_h) / floor_h)
            fz = ((z - z0 + 50.0 * floor_h) / floor_h) % 1.0
            half = win_w / spacing / 2.0
            inx = np.abs(fx - 0.5) < half
            inz = (fz < win_h / floor_h) & (z > z0 - 0.01) & (z < zmax) & (z > shop_until)
            win = face & inx & inz
            if not win.any():
                continue
            # moldura de 1 px embaixo (peitoril)
            sill = face & inx & (fz < 0.06) & (z > z0 - 0.01) & (z < zmax) & (z > shop_until)
            r = np.array([_h(seed, a, b, ax, np.sign(nn)) for a, b, nn in zip(ci[win], zi[win], n[win, ax])])
            c = np.tile(cols["glass"], (int(win.sum()), 1))
            # reflexo: coluna clara de 2 px na borda esquerda do vidro
            c[(fx[win] - 0.5) < -half * 0.55] = cols["refl"]
            c[r < lit] = cols["lit"]
            c[(r < lit) & (fz[win] > 0.32)] = cols["lit2"]
            c[(r > 1 - broken)] = cols["broken"]
            bmask = (r > 1 - broken - boarded) & (r <= 1 - broken)
            planks = ((fz[win] * 12).astype(int) % 2) == 0
            c[bmask] = np.where(planks[bmask, None], cols["board"], cols["board2"])
            idx = np.where(win)[0]
            mask[idx] = True
            col[idx] = c
            sidx = np.where(sill & ~win)[0]
            mask[sidx] = True
            col[sidx] = cols["frame"]
        return np.zeros(N, dtype=int), mask, col
    return f


def pat_storefront(seed=3, glass="#19444b", zoff=0.36):
    """Vitrine do térreo: vidro com montantes e uma porta."""
    g = C(glass)
    g2 = C("#2a6b66")
    mull = C("#121321")

    def f(p, n):
        N = len(p)
        mask = np.zeros(N, dtype=bool)
        col = np.zeros((N, 3), dtype=np.uint8)
        for ax, hz in ((0, 1), (1, 0)):
            face = np.abs(n[:, ax]) > 0.9
            h = p[:, hz]
            z = p[:, 2] + zoff
            glass_m = face & (z > 0.08) & (z < 0.62)
            c = np.tile(g, (N, 1))
            c[((h * 3.0 + z * 1.5) % 1.0) < 0.18] = g2
            c[((h + 50) % 0.45) < 0.03] = mull
            c[np.abs(z - 0.62) < 0.02] = mull
            mask |= glass_m
            col[glass_m] = c[glass_m]
        return np.zeros(N, dtype=int), mask, col
    return f


def pat_chips(seed=1, density=0.06, cell=0.12, depth=-1):
    """Lascas de 2+ px nas superfícies (no lugar do ruído de 1 px)."""
    def f(p, n):
        q = np.floor((p + 50.0) / cell).astype(np.int64)
        hv = (q[:, 0] * 73856093) ^ (q[:, 1] * 19349663) ^ (q[:, 2] * 83492791) ^ seed
        r = (hv % 1000) / 1000.0
        return np.where(r < density, depth, 0), None, None
    return f


def pat_corrugated(step=0.06, axis=2):
    """Chapa ondulada: faixas alternadas na horizontal."""
    def f(p, n):
        k = ((p[:, 0] + p[:, 1] + 50.0) / step).astype(int) % 2
        side = np.abs(n[:, 2]) < 0.5
        return np.where(side & (k == 0), -1, 0), None, None
    return f


def pat_bricks(seed=2):
    def f(p, n):
        side = np.abs(n[:, 2]) < 0.5
        row = np.floor((p[:, 2] + 50.0) / 0.09).astype(int)
        h = p[:, 0] + p[:, 1] + (row % 2) * 0.07
        joint = (((p[:, 2] + 50.0) / 0.09) % 1.0 < 0.18) | (((h + 50.0) / 0.14) % 1.0 < 0.1)
        return np.where(side & joint, -1, 0), None, None
    return f


def pat_roof_tiles():
    def f(p, n):
        row = ((p[:, 0] + p[:, 2] + 50.0) / 0.09) % 1.0
        return np.where(row < 0.25, -1, 0), None, None
    return f


# ====================================================================== props
def _pole(h, mat="steel", r=0.03):
    return Part("cyl", (r, h / 2), mat, (0, 0, h / 2))


def prop_model(name, var=0):
    """Objetos de rua, vila, indústria, abrigo, campo e esporos. var = quadro/variação."""
    on = var == 0
    if name == "poste_rua":
        g = "glow_white" if on else "glow_off"
        return [Part("box", (0.07, 0.07, 0.05), "slate", (0, 0, 0.05)), _pole(1.75, "steel", 0.035),
                Part("box", (0.26, 0.035, 0.03), "steel", (0.20, 0, 1.70)), Part("box", (0.13, 0.08, 0.035), "grey", (0.42, 0, 1.68)),
                Part("box", (0.10, 0.06, 0.01), g, (0.42, 0, 1.64))]
    if name == "poste_neon":
        g = "glow_magenta" if on else "glow_off"
        return [Part("box", (0.07, 0.07, 0.05), "slate", (0, 0, 0.05)), _pole(1.55, "steel", 0.03),
                Part("box", (0.035, 0.035, 0.40), g, (0, 0, 1.15)), Part("box", (0.08, 0.08, 0.03), "grey", (0, 0, 1.6))]
    if name == "frade":
        return [Part("cyl", (0.08, 0.20), "slate", (0, 0, 0.20)), Part("cyl", (0.085, 0.03), "mustard", (0, 0, 0.30), pattern=pat_hazard(0.05)),
                Part("ell", (0.08, 0.08, 0.04), "slate", (0, 0, 0.40))]
    if name == "lixeira":
        return [Part("cyl", (0.14, 0.20), "steel", (0, 0, 0.20), pattern=pat_seams(0.1, (0, 0, 1))),
                Part("cyl", (0.155, 0.03), "slate", (0, 0, 0.42)), Part("box", (0.012, 0.06, 0.04), "glow_teal", (0.14, 0, 0.28))]
    if name == "cacamba":
        return [Part("box", (0.42, 0.26, 0.20), "teal", (0, 0, 0.24), pattern=combine(pat_seams(0.14, (1, 0, 0)), pat_chips(5))),
                Part("box", (0.44, 0.28, 0.025), "steel", (0, 0, 0.46), rot_y(-6)),
                Part("box", (0.40, 0.03, 0.03), "dark", (0, 0, 0.04))] + \
               [Part("cyl", (0.035, 0.02), "dark", (x, y, 0.035), rot_x(90)) for x in (0.32, -0.32) for y in (0.26, -0.26)]
    if name == "hidrante":
        return [Part("cyl", (0.07, 0.15), "red", (0, 0, 0.15)), Part("ell", (0.07, 0.07, 0.06), "red", (0, 0, 0.31)),
                Part("cyl", (0.03, 0.10), "red", (0, 0, 0.20), rot_x(90)), Part("cyl", (0.09, 0.02), "grey", (0, 0, 0.02))]
    if name == "banco":
        return [Part("box", (0.36, 0.11, 0.02), "wood", (0, 0, 0.22), pattern=pat_planks(0.07, 1)),
                Part("box", (0.36, 0.02, 0.08), "wood", (0, -0.12, 0.34)),
                Part("box", (0.02, 0.10, 0.11), "steel", (0.30, 0, 0.11)), Part("box", (0.02, 0.10, 0.11), "steel", (-0.30, 0, 0.11))]
    if name == "placa":
        return [_pole(0.9, "grey", 0.02), Part("box", (0.015, 0.14, 0.14), "red", (0.02, 0, 0.92), rot_x(45)),
                Part("box", (0.018, 0.10, 0.10), "bone", (0.025, 0, 0.92), rot_x(45))]
    if name == "cone":
        return [Part("box", (0.10, 0.10, 0.012), "dark", (0, 0, 0.012)), Part("cyl", (0.05, 0.12), "glow_amber", (0, 0, 0.13)),
                Part("cyl", (0.055, 0.025), "bone", (0, 0, 0.14)), Part("cyl", (0.025, 0.04), "glow_amber", (0, 0, 0.27))]
    if name == "barreira":
        return [Part("box", (0.10, 0.44, 0.06), "bone", (0, 0, 0.06)), Part("box", (0.05, 0.44, 0.13), "bone", (0, 0, 0.24)),
                Part("box", (0.055, 0.44, 0.04), "red", (0, 0, 0.30), pattern=pat_hazard(0.09, "#d84050", "#e6e8f0"))]
    if name == "carro_queimado":
        rot = rot_z(0 if var == 0 else 90)
        P = [Part("box", (0.62, 0.30, 0.13), "rust", (0, 0, 0.20), pattern=pat_chips(9, 0.25, 0.07)),
             Part("box", (0.32, 0.27, 0.11), "grey", (-0.06, 0, 0.42)),
             Part("box", (0.33, 0.25, 0.08), "dark", (-0.06, 0, 0.42)),
             Part("box", (0.62, 0.31, 0.02), "dark", (0, 0, 0.08))]
        for x in (0.40, -0.40):
            for y in (0.30, -0.30):
                P.append(Part("cyl", (0.09, 0.035), "dark", (x, y, 0.09), rot_x(90)))
        return transform(P, rot)
    if name == "arvore_rua":
        return [Part("box", (0.20, 0.20, 0.03), "rust", (0, 0, 0.03)), Part("cyl", (0.04, 0.45), "wood", (0, 0, 0.45)),
                Part("ell", (0.28, 0.28, 0.26), "fungus", (0, 0, 1.0)), Part("ell", (0.18, 0.18, 0.16), "fungus", (0.06, 0.08, 1.22)),
                Part("ell", (0.14, 0.14, 0.12), "olive", (-0.12, -0.06, 0.9))]
    # ---- vila
    if name == "maquina_venda":
        return [Part("box", (0.20, 0.24, 0.50), "red", (0, 0, 0.50), pattern=pat_chips(3)),
                Part("box", (0.012, 0.18, 0.28), "glow_cyan" if on else "glow_dim", (0.20, 0.02, 0.62), pattern=pat_seams(0.07, (0, 0, 1))),
                Part("box", (0.014, 0.05, 0.08), "dark", (0.20, -0.17, 0.48)), Part("box", (0.014, 0.18, 0.05), "dark", (0.20, 0, 0.18))]
    if name == "barraca":
        return [Part("box", (0.36, 0.24, 0.20), "wood", (0, 0, 0.30), pattern=pat_planks(0.07, 2)),
                Part("box", (0.40, 0.30, 0.02), "red", (0.05, 0, 0.92), rot_y(12), pattern=pat_hazard(0.12, "#d84050", "#e6e8f0")),
                Part("cyl", (0.02, 0.22), "steel", (0.30, 0.22, 0.72)), Part("cyl", (0.02, 0.22), "steel", (0.30, -0.22, 0.72)),
                Part("cyl", (0.02, 0.25), "steel", (-0.30, 0.22, 0.75)), Part("cyl", (0.02, 0.25), "steel", (-0.30, -0.22, 0.75)),
                Part("box", (0.1, 0.06, 0.04), "glow_amber", (0.1, 0.08, 0.54)),
                Part("cyl", (0.07, 0.02), "dark", (0.3, 0.26, 0.07), rot_x(90)), Part("cyl", (0.07, 0.02), "dark", (-0.3, 0.26, 0.07), rot_x(90))]
    if name == "orelhao":
        return [_pole(0.55, "grey", 0.025), Part("ell", (0.22, 0.22, 0.24), "teal", (0, 0, 0.78)),
                Part("ell", (0.20, 0.20, 0.22), "dark", (0.06, 0, 0.74)), Part("box", (0.04, 0.06, 0.08), "grey", (0.02, 0, 0.70))]
    if name == "painel":
        g = "glow_cyan" if on else "glow_off"
        return [Part("box", (0.04, 0.04, 0.25), "steel", (0, 0.30, 0.25)), Part("box", (0.04, 0.04, 0.25), "steel", (0, -0.30, 0.25)),
                Part("box", (0.05, 0.40, 0.25), "dark", (0, 0, 0.72)), Part("box", (0.055, 0.34, 0.19), g, (0, 0, 0.72)),
                Part("box", (0.056, 0.14, 0.08), "glow_magenta" if on else "glow_off", (0, 0.1, 0.78))]
    if name == "barricada":
        P = []
        for i, (y, z) in enumerate(((-0.28, 0.07), (0, 0.07), (0.28, 0.07), (-0.14, 0.20), (0.14, 0.20), (0, 0.33))):
            P.append(Part("ell", (0.15, 0.15, 0.08), "mustard" if i % 2 else "olive", (0, y, z)))
        return P
    if name == "tambor_fogo":
        g = "glow_amber" if on else "dark"
        return [Part("cyl", (0.13, 0.20), "rust", (0, 0, 0.20), pattern=pat_seams(0.13, (0, 0, 1))),
                Part("cyl", (0.11, 0.01), "dark", (0, 0, 0.405)),
                Part("ell", (0.08, 0.08, 0.12), g, (0, 0, 0.47)), Part("ell", (0.04, 0.04, 0.08), "glow_red" if on else "dark", (0.03, 0, 0.55))]
    if name == "caixa_dagua":
        P = [Part("cyl", (0.30, 0.22), "teal", (0, 0, 0.92), pattern=pat_seams(0.11, (0, 0, 1))),
             Part("ell", (0.30, 0.30, 0.08), "teal", (0, 0, 1.14))]
        for x, y in ((0.22, 0.22), (-0.22, 0.22), (0.22, -0.22), (-0.22, -0.22)):
            P.append(Part("box", (0.025, 0.025, 0.35), "steel", (x, y, 0.35)))
        return P
    # ---- indústria
    if name == "ar_cond":
        return [Part("box", (0.32, 0.22, 0.20), "bone", (0, 0, 0.20), pattern=pat_seams(0.1, (0, 1, 0))),
                Part("cyl", (0.13, 0.01), "dark", (0.02, 0.10, 0.41)), Part("cyl", (0.13, 0.01), "dark", (0.02, -0.12, 0.41)),
                Part("box", (0.04, 0.04, 0.04), "grey", (-0.3, 0.15, 0.06))]
    if name == "transformador":
        return [Part("box", (0.30, 0.30, 0.04), "slate", (0, 0, 0.04)),
                Part("box", (0.22, 0.20, 0.30), "olive", (0, 0, 0.36), pattern=pat_seams(0.06, (1, 0, 0))),
                Part("box", (0.012, 0.10, 0.10), "mustard", (0.225, 0, 0.42), pattern=pat_hazard(0.04))] + \
               [Part("cyl", (0.03, 0.10), "bone", (-0.1 + 0.1 * i, 0, 0.76)) for i in range(3)]
    if name == "antena":
        P = [Part("box", (0.16, 0.16, 0.03), "slate", (0, 0, 0.03))]
        for x, y in ((0.12, 0.12), (-0.12, 0.12), (0.12, -0.12), (-0.12, -0.12)):
            P.append(Part("box", (0.012, 0.012, 0.90), "grey", (x * 0.5, y * 0.5, 0.90), rot_x(0)))
        P.append(Part("box", (0.07, 0.07, 0.90), "steel", (0, 0, 0.90), pattern=pat_seams(0.18, (0, 0, 1))))
        P.append(Part("cyl", (0.18, 0.02), "bone", (0.08, 0, 1.60), rot_y(60)))
        P.append(Part("box", (0.02, 0.02, 0.02), "glow_red", (0, 0, 1.83)))
        return P
    if name == "tambores":
        P = []
        for i, (x, y) in enumerate(((0.12, 0.13), (-0.13, 0.12), (0.10, -0.15))):
            mat = ["mustard", "teal", "red"][(i + var) % 3]
            P.append(Part("cyl", (0.12, 0.17), mat, (x, y, 0.17), pattern=pat_seams(0.11, (0, 0, 1))))
        P.append(Part("cyl", (0.12, 0.17), "rust", (-0.15, -0.16, 0.12), rot_x(90)))
        return P
    if name == "paletes":
        P = []
        for k in range(3):
            P.append(Part("box", (0.32, 0.28, 0.025), "wood", (0, 0, 0.03 + k * 0.08), pattern=pat_planks(0.07, 1)))
            P.append(Part("box", (0.30, 0.26, 0.02), "wood", (0, 0, 0.06 + k * 0.08)))
        P.append(Part("box", (0.20, 0.18, 0.10), "bone", (0.04, 0, 0.36)))
        return P
    if name == "pneus":
        return [Part("cyl", (0.15, 0.05), "dark", (0, 0, 0.05 + i * 0.1)) for i in range(4)] + \
               [Part("cyl", (0.07, 0.21), "dark", (0, 0, 0.21))] + \
               [Part("cyl", (0.15, 0.05), "dark", (0.2, -0.2, 0.15), rot_x(70))]
    if name == "tanque":
        return [Part("cyl", (0.34, 0.45), "bone", (0, 0, 0.50), pattern=pat_seams(0.3, (0, 0, 1))),
                Part("ell", (0.34, 0.34, 0.12), "bone", (0, 0, 0.95)), Part("cyl", (0.36, 0.05), "slate", (0, 0, 0.05)),
                Part("box", (0.012, 0.06, 0.4), "grey", (0.345, 0, 0.5)), Part("cyl", (0.35, 0.02), "red", (0, 0, 0.7))]
    if name == "gerador_velho":
        return [Part("box", (0.34, 0.24, 0.04), "steel", (0, 0, 0.04)),
                Part("box", (0.28, 0.20, 0.20), "olive", (0, 0, 0.27), pattern=combine(pat_seams(0.1, (1, 0, 0)), pat_chips(13, 0.12))),
                Part("cyl", (0.03, 0.14), "grey", (-0.2, -0.12, 0.55)), Part("box", (0.012, 0.04, 0.03), "glow_off", (0.285, 0.1, 0.34))]
    # ---- abrigo
    if name == "purificador_agua":
        g = "glow_teal" if on else "glow_dim"
        return [Part("cyl", (0.18, 0.30), "slate", (-0.08, 0.08, 0.30), pattern=pat_seams(0.15, (0, 0, 1))),
                Part("cyl", (0.12, 0.22), "teal", (0.2, -0.12, 0.22)), Part("cyl", (0.13, 0.02), g, (0.2, -0.12, 0.3)),
                Part("cyl", (0.03, 0.18), "steel", (0.05, -0.02, 0.62), rot_y(70))]
    if name == "hidroponia":
        P = [Part("box", (0.04, 0.40, 0.45), "steel", (-0.2, 0, 0.45))]
        for z in (0.22, 0.52, 0.82):
            P.append(Part("box", (0.22, 0.40, 0.03), "slate", (0, 0, z)))
            P.append(Part("ell", (0.18, 0.36, 0.07), "fungus", (0.02, 0, z + 0.07)))
            P.append(Part("box", (0.20, 0.36, 0.008), "glow_magenta" if on else "glow_off", (0, 0, z + 0.27)))
        return P
    if name == "coletor_umidade":
        return [Part("cyl", (0.16, 0.25), "steel", (0, 0, 0.25)), Part("cyl", (0.06, 0.25), "grey", (0, 0, 0.75)),
                Part("cyl", (0.30, 0.02), "bone", (0, 0, 1.00)), Part("cyl", (0.30, 0.02), "bone", (0, 0, 0.88)),
                Part("box", (0.012, 0.05, 0.05), "glow_cyan", (0.16, 0, 0.32))]
    if name == "cofre_sementes":
        return [Part("box", (0.30, 0.26, 0.26), "steel", (0, 0, 0.26), pattern=pat_seams(0.13, (0, 0, 1))),
                Part("cyl", (0.10, 0.012), "grey", (0.305, 0, 0.28), rot_y(90)), Part("box", (0.31, 0.27, 0.03), "mustard", (0, 0, 0.53), pattern=pat_hazard(0.06))]
    if name == "painel_solar":
        return [Part("box", (0.03, 0.03, 0.22), "steel", (0, 0, 0.22)),
                Part("box", (0.36, 0.44, 0.02), "steel", (0, 0, 0.46), rot_y(-25)),
                Part("box", (0.33, 0.41, 0.021), "glow_dim", (0.005, 0, 0.465), rot_y(-25), pattern=pat_seams(0.11, (1, 1, 0)))]
    # ---- campo
    if name == "arvore":
        P = [Part("cyl", (0.06, 0.40), "wood", (0, 0, 0.40))]
        P += [Part("ell", (0.36, 0.36, 0.32), "fungus", (0, 0, 0.95)), Part("ell", (0.24, 0.24, 0.22), "fungus", (-0.1, 0.1, 1.22)),
              Part("ell", (0.20, 0.20, 0.16), "olive", (0.16, -0.06, 0.82))]
        if var == 1:
            P = [Part("cyl", (0.05, 0.30), "wood", (0, 0, 0.30)), Part("ell", (0.30, 0.30, 0.38), "olive", (0, 0, 0.80)),
                 Part("ell", (0.22, 0.22, 0.30), "olive", (0.05, -0.05, 1.10))]
        return P
    if name == "pinheiro":
        return [Part("cyl", (0.05, 0.25), "wood", (0, 0, 0.25)), Part("ell", (0.32, 0.32, 0.26), "fungus", (0, 0, 0.62)),
                Part("ell", (0.25, 0.25, 0.22), "fungus", (0, 0, 0.92)), Part("ell", (0.16, 0.16, 0.18), "fungus", (0, 0, 1.18)),
                Part("ell", (0.08, 0.08, 0.12), "fungus", (0, 0, 1.36))]
    if name == "arvore_morta":
        P = [Part("cyl", (0.05, 0.50), "rust", (0, 0, 0.50))]
        for ang, h, l in ((30, 0.7, 0.26), (150, 0.85, 0.22), (260, 0.6, 0.2), (90, 0.98, 0.16)):
            rot = rot_z(ang) @ rot_y(-40)
            P.append(Part("box", (l, 0.03, 0.03), "rust", tuple(np.array([0, 0, h]) + rot @ np.array([l, 0, 0])), rot))
        return P
    if name == "arbusto":
        return [Part("ell", (0.22, 0.20, 0.14), "fungus", (0, 0, 0.12)), Part("ell", (0.14, 0.14, 0.12), "fungus", (0.12, 0.08, 0.18)),
                Part("ell", (0.10, 0.10, 0.08), "olive", (-0.1, -0.06, 0.18))]
    if name == "pedra":
        return [Part("ell", (0.24, 0.18, 0.12), "grey", (0, 0, 0.06)), Part("ell", (0.12, 0.10, 0.08), "grey", (0.16, 0.12, 0.04))]
    if name == "cerca":
        rot = rot_z(0 if var == 0 else 90)
        P = [Part("box", (0.03, 0.03, 0.22), "wood", (0, y, 0.22)) for y in (-0.42, 0, 0.42)]
        P += [Part("box", (0.015, 0.47, 0.025), "wood", (0, 0, z)) for z in (0.18, 0.34)]
        return transform(P, rot)
    if name == "feno":
        return [Part("cyl", (0.20, 0.24), "mustard", (0, 0, 0.20), rot_x(90), pattern=pat_seams(0.08, (0, 0, 1))),
                Part("cyl", (0.205, 0.01), "rust", (0, 0.12, 0.20), rot_x(90))]
    if name == "espantalho":
        return [_pole(0.9, "wood", 0.025), Part("box", (0.02, 0.30, 0.02), "wood", (0, 0, 0.70)),
                Part("box", (0.07, 0.16, 0.16), "rust", (0, 0, 0.62)), Part("ell", (0.08, 0.08, 0.08), "mustard", (0, 0, 0.88)),
                Part("cyl", (0.12, 0.015), "wood", (0, 0, 0.95))]
    if name == "poco":
        return [Part("cyl", (0.28, 0.14), "grey", (0, 0, 0.14), pattern=pat_bricks()), Part("cyl", (0.22, 0.01), "dark", (0, 0, 0.285)),
                Part("box", (0.02, 0.02, 0.28), "wood", (0, 0.24, 0.50)), Part("box", (0.02, 0.02, 0.28), "wood", (0, -0.24, 0.50)),
                Part("box", (0.20, 0.30, 0.02), "rust", (0, 0, 0.82), rot_y(20))]
    # ---- esporos
    if name == "cogumelo":
        return [Part("cyl", (0.07, 0.30), "bone", (0, 0, 0.30)), Part("ell", (0.32, 0.32, 0.14), "fungus_pink", (0, 0, 0.64)),
                Part("ell", (0.05, 0.05, 0.03), "glow_magenta", (0.12, 0.08, 0.74)), Part("ell", (0.12, 0.12, 0.08), "fungus_pink", (0.22, 0.18, 0.12)),
                Part("cyl", (0.025, 0.08), "bone", (0.22, 0.18, 0.06))]
    if name == "casulo":
        return [Part("ell", (0.20, 0.18, 0.32), "flesh_inf", (0, 0, 0.32)), Part("ell", (0.10, 0.09, 0.14), "fungus", (0.12, 0.05, 0.12)),
                Part("ell", (0.03, 0.03, 0.03), "glow_green", (0.18, 0.02, 0.4))]
    raise KeyError(name)


# Grupos para o gerador do mapa e a colisão (raio em px; 0 = passa por cima).
# frames = quadros (ligado/desligado ou variações).
PROPS = {
    "poste_rua": {"grupo": "rua", "raio": 6, "frames": 2}, "poste_neon": {"grupo": "rua", "raio": 6, "frames": 2},
    "frade": {"grupo": "rua", "raio": 6, "frames": 1}, "lixeira": {"grupo": "rua", "raio": 7, "frames": 1},
    "cacamba": {"grupo": "rua", "raio": 14, "frames": 1}, "hidrante": {"grupo": "rua", "raio": 5, "frames": 1},
    "banco": {"grupo": "rua", "raio": 10, "frames": 1}, "placa": {"grupo": "rua", "raio": 4, "frames": 1},
    "cone": {"grupo": "rua", "raio": 0, "frames": 1}, "barreira": {"grupo": "rua", "raio": 12, "frames": 1},
    "carro_queimado": {"grupo": "rua", "raio": 18, "frames": 2}, "arvore_rua": {"grupo": "rua", "raio": 6, "frames": 1},
    "maquina_venda": {"grupo": "vila", "raio": 8, "frames": 2}, "barraca": {"grupo": "vila", "raio": 12, "frames": 1},
    "orelhao": {"grupo": "vila", "raio": 5, "frames": 1}, "painel": {"grupo": "vila", "raio": 10, "frames": 2},
    "barricada": {"grupo": "vila", "raio": 12, "frames": 1}, "tambor_fogo": {"grupo": "vila", "raio": 7, "frames": 2},
    "caixa_dagua": {"grupo": "vila", "raio": 12, "frames": 1},
    "ar_cond": {"grupo": "industria", "raio": 12, "frames": 1}, "transformador": {"grupo": "industria", "raio": 10, "frames": 1},
    "antena": {"grupo": "industria", "raio": 6, "frames": 1}, "tambores": {"grupo": "industria", "raio": 10, "frames": 3},
    "paletes": {"grupo": "industria", "raio": 12, "frames": 1}, "pneus": {"grupo": "industria", "raio": 9, "frames": 1},
    "tanque": {"grupo": "industria", "raio": 14, "frames": 1}, "gerador_velho": {"grupo": "industria", "raio": 12, "frames": 1},
    "purificador_agua": {"grupo": "abrigo", "raio": 10, "frames": 2}, "hidroponia": {"grupo": "abrigo", "raio": 12, "frames": 2},
    "coletor_umidade": {"grupo": "abrigo", "raio": 7, "frames": 1}, "cofre_sementes": {"grupo": "abrigo", "raio": 11, "frames": 1},
    "painel_solar": {"grupo": "abrigo", "raio": 10, "frames": 1},
    "arvore": {"grupo": "campo", "raio": 7, "frames": 2}, "pinheiro": {"grupo": "campo", "raio": 7, "frames": 1},
    "arvore_morta": {"grupo": "campo", "raio": 6, "frames": 1}, "arbusto": {"grupo": "campo", "raio": 0, "frames": 1},
    "pedra": {"grupo": "campo", "raio": 9, "frames": 1}, "cerca": {"grupo": "campo", "raio": 6, "frames": 2},
    "feno": {"grupo": "campo", "raio": 10, "frames": 1}, "espantalho": {"grupo": "campo", "raio": 4, "frames": 1},
    "poco": {"grupo": "campo", "raio": 11, "frames": 1},
    "cogumelo": {"grupo": "esporos", "raio": 8, "frames": 1}, "casulo": {"grupo": "esporos", "raio": 8, "frames": 1},
}

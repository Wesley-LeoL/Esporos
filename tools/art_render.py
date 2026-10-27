#!/usr/bin/env python3
"""Renderizador de pixel art isométrica para o Esporos.

Monta pequenos modelos 3D a partir de primitivas (caixa, cilindro, elipsoide) e os
renderiza por ray casting ortográfico na MESMA projeção do jogo e do pacote de arte:
isométrica 2:1, célula de 80x40 px (1 unidade = aresta de uma célula), luz vinda da
esquerda (topo claro, face esquerda média, face direita escura) e contorno preto de 1 px.

O resultado é pixel art 1:1 (sem anti-aliasing), coerente em todas as rotações.
Usado por tools/gen_art.py.
"""
import math

import numpy as np

SQ2 = math.sqrt(0.5)
SIN_E = 0.5                    # elevação de 30 graus -> projeção 2:1
COS_E = math.sqrt(3.0) / 2.0
S = 40.0 / SQ2                 # px por unidade: célula (1,0) -> (+40, +20) px
VIEW = np.array([-1.0, -1.0, -2.0 * SQ2 * SIN_E / COS_E])
VIEW /= np.linalg.norm(VIEW)   # direção do raio (da câmera para a cena)
LIGHT = np.array([0.30, 0.65, 1.0])
LIGHT /= np.linalg.norm(LIGHT)

# ------------------------------------------------------------------ paleta
# Rampas de 5 tons (sombra profunda -> realce), derivadas do pacote FreeSample.
RAMPS = {
    "indigo": ["#121321", "#1b1b32", "#2c2a48", "#404156", "#575772"],
    "slate": ["#1b1b32", "#2c2a48", "#404156", "#575772", "#8b89a3"],
    "rust": ["#2a2030", "#342734", "#624d53", "#7b5e5a", "#a58077"],
    "skin": ["#3d2a2e", "#6b4a46", "#a5776a", "#c99a84", "#e0b9a0"],
    "steel": ["#1f213e", "#2c3350", "#484f6a", "#616b8c", "#8a96b0"],
    "grey": ["#13131d", "#2a2e39", "#383e4b", "#51575d", "#6b6d7c"],
    "cloth": ["#121321", "#1f213e", "#2a2e39", "#3c3c4f", "#515268"],
    "mustard": ["#2a2418", "#4d4020", "#8a6f2a", "#c09a3a", "#e3c76a"],
    "olive": ["#1c1c14", "#48472d", "#6e6f3a", "#a9ad4e", "#e3eb67"],
    "teal": ["#0f2a2e", "#19444b", "#2a6b66", "#3ba481", "#66d9d0"],
    "fungus": ["#1a2416", "#2f4a2a", "#4a6b2f", "#7fa64a", "#a6d65c"],
    "fungus_pink": ["#2a1426", "#4a2040", "#7a2f5a", "#b0507a", "#e07aa8"],
    "elite_body": ["#160c18", "#2a1630", "#3e2040", "#57304f", "#74506a"],
    "flesh_inf": ["#1e2420", "#3a4438", "#5e6a52", "#8a9a72", "#b0c090"],
    "elite_skin": ["#1a1420", "#33283a", "#4f4058", "#6e5c78", "#8e7c98"],
    "blood": ["#12080c", "#1e0c12", "#2e1018", "#3e1620", "#4e1e28"],
    "bone": ["#2a2e39", "#6b6d7c", "#a3a6b8", "#c8cad8", "#e6e8f0"],
    "red": ["#2a0f14", "#5a1a22", "#a02a34", "#d84050", "#f07080"],
    "wood": ["#2a2030", "#4a3530", "#6e4e3e", "#8e6a52", "#b08a6a"],
    "dark": ["#000000", "#0b0b14", "#121321", "#1b1b32", "#2a2e39"],
}
GLOW = {
    "glow_teal": "#66d9d0", "glow_cyan": "#52e6ff", "glow_red": "#ff3b3b",
    "glow_amber": "#ffb84a", "glow_green": "#a6d65c", "glow_magenta": "#e070ff",
    "glow_dim": "#2a6b66", "glow_off": "#3a2228", "glow_white": "#e6f6ff",
}
OUTLINE = (0, 0, 0)


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


RAMP_RGB = {k: np.array([hex_rgb(c) for c in v], dtype=np.uint8) for k, v in RAMPS.items()}
GLOW_RGB = {k: np.array(hex_rgb(v), dtype=np.uint8) for k, v in GLOW.items()}


# ------------------------------------------------------------------ rotações
def rot_x(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_y(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rot_z(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


I3 = np.eye(3)


class Part:
    """Primitiva do modelo. shape: 'box' (meias-medidas hx,hy,hz), 'cyl' (raio, meia-altura;
    eixo z local) ou 'ell' (raios rx,ry,rz). mat: rampa de RAMPS ou cor de GLOW (emissiva).
    pattern(p_local, n_local) -> (delta de tom, máscara de cor própria, cor própria)."""

    def __init__(self, shape, size, mat, pos=(0, 0, 0), rot=I3, pattern=None, bevel=True):
        self.shape = shape
        self.size = np.array(size, dtype=float)
        self.mat = mat
        self.pos = np.array(pos, dtype=float)
        self.rot = np.array(rot, dtype=float)
        self.pattern = pattern
        self.bevel = bevel


def transform(parts, rot=I3, pivot=(0, 0, 0), offset=(0, 0, 0)):
    """Gira um grupo de peças em torno de um pivô e desloca (hierarquia simples)."""
    pivot = np.array(pivot, dtype=float)
    offset = np.array(offset, dtype=float)
    out = []
    for p in parts:
        q = Part(p.shape, p.size, p.mat, pivot + rot @ (p.pos - pivot) + offset, rot @ p.rot,
                 p.pattern, p.bevel)
        out.append(q)
    return out


def scale_parts(parts, k):
    out = []
    for p in parts:
        out.append(Part(p.shape, p.size * k, p.mat, p.pos * k, p.rot, p.pattern, p.bevel))
    return out


def limb(shape, size, mat, pivot, rot, along, **kw):
    """Peça presa a um pivô (ombro, quadril): 'along' é o deslocamento do centro no
    referencial do membro antes de girar."""
    pivot = np.array(pivot, dtype=float)
    return Part(shape, size, mat, pivot + rot @ np.array(along, dtype=float), rot, **kw)


# ------------------------------------------------------------------ interseções
def _hit_box(o, d, h):
    dd = np.where(np.abs(d) < 1e-12, 1e-12, d)
    inv = 1.0 / dd
    t1 = (-h - o) * inv
    t2 = (h - o) * inv
    tmin = np.minimum(t1, t2)
    tmax = np.maximum(t1, t2)
    tn = tmin.max(axis=1)
    tf = tmax.min(axis=1)
    hit = (tf >= tn) & (tn > 0)
    ax = tmin.argmax(axis=1)
    n = np.zeros_like(o)
    n[np.arange(len(o)), ax] = -np.sign(dd)[ax]
    return hit, tn, n


def _hit_cyl(o, d, r, hz):
    N = len(o)
    t = np.full(N, np.inf)
    n = np.zeros_like(o)
    a = d[0] ** 2 + d[1] ** 2
    if a > 1e-12:
        b = 2 * (o[:, 0] * d[0] + o[:, 1] * d[1])
        c = o[:, 0] ** 2 + o[:, 1] ** 2 - r * r
        disc = b * b - 4 * a * c
        ok = disc >= 0
        ts = (-b - np.sqrt(np.maximum(disc, 0))) / (2 * a)
        z = o[:, 2] + ts * d[2]
        side = ok & (np.abs(z) <= hz) & (ts > 0)
        t = np.where(side, ts, t)
        px = o[:, 0] + ts * d[0]
        py = o[:, 1] + ts * d[1]
        n[side] = np.stack([px / r, py / r, np.zeros(N)], axis=1)[side]
    if abs(d[2]) > 1e-12:
        for sgn in (1.0, -1.0):
            tc = (sgn * hz - o[:, 2]) / d[2]
            px = o[:, 0] + tc * d[0]
            py = o[:, 1] + tc * d[1]
            inside = (px * px + py * py <= r * r) & (tc > 0) & (tc < t)
            t = np.where(inside, tc, t)
            n[inside] = np.array([0.0, 0.0, sgn])
    return np.isfinite(t), t, n


def _hit_ell(o, d, rad):
    oo = o / rad
    dd = d / rad
    a = dd @ dd
    b = 2 * (oo @ dd)
    c = (oo * oo).sum(axis=1) - 1
    disc = b * b - 4 * a * c
    ok = disc >= 0
    t = (-b - np.sqrt(np.maximum(disc, 0))) / (2 * a)
    hit = ok & (t > 0)
    p = o + t[:, None] * d
    n = p / (rad * rad)
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
    return hit, t, n


# ------------------------------------------------------------------ renderização
def render(parts, W, H, ox, oy, theta=0.0, outline=True, inner_edges=True):
    """Renderiza as peças girando o modelo theta graus em torno de z.
    (ox, oy) = pixel onde cai a origem do modelo (pé / centro da célula no chão).
    Retorna uma imagem RGBA (H, W, 4) uint8."""
    jj, ii = np.mgrid[0:H, 0:W]
    u = (ii + 0.5 - ox).ravel()
    v = (jj + 0.5 - oy).ravel()
    A = u / (SQ2 * S)
    B = v / (SQ2 * SIN_E * S)
    ground = np.stack([(A + B) / 2, (B - A) / 2, np.zeros_like(A)], axis=1)
    O = ground - 30.0 * VIEW
    N = len(O)
    Rz = rot_z(theta)
    best = np.full(N, np.inf)
    pid = np.full(N, -1)
    nrm_w = np.zeros((N, 3))
    nrm_l = np.zeros((N, 3))
    loc = np.zeros((N, 3))
    for k, p in enumerate(parts):
        M = Rz @ p.rot
        cw = Rz @ p.pos
        o_l = (O - cw) @ M
        d_l = VIEW @ M
        if p.shape == "box":
            hit, t, n = _hit_box(o_l, d_l, p.size)
        elif p.shape == "cyl":
            hit, t, n = _hit_cyl(o_l, d_l, p.size[0], p.size[1])
        else:
            hit, t, n = _hit_ell(o_l, d_l, p.size)
        upd = hit & (t < best)
        if not upd.any():
            continue
        best[upd] = t[upd]
        pid[upd] = k
        nrm_l[upd] = n[upd]
        nrm_w[upd] = n[upd] @ M.T
        loc[upd] = o_l[upd] + t[upd, None] * d_l
    rgb = np.zeros((N, 3), dtype=np.uint8)
    level = np.zeros(N, dtype=int)
    b = nrm_w @ LIGHT
    level[:] = np.select([b > 0.70, b > 0.42, b > 0.18, b > -0.2], [3, 2, 1, 0], 0)
    for k, p in enumerate(parts):
        m = pid == k
        if not m.any():
            continue
        lv = level[m].copy()
        if p.shape == "box" and p.bevel:
            # topo com borda clara (chanfro), como no pacote
            top = nrm_l[m, 2] > 0.9
            edge = (np.abs(np.abs(loc[m, 0]) - p.size[0]) < 0.028) | (np.abs(np.abs(loc[m, 1]) - p.size[1]) < 0.028)
            lv = np.where(top & edge, 4, lv)
        own = None
        if p.pattern is not None:
            delta, own_mask, own_rgb = p.pattern(loc[m], nrm_l[m])
            lv = lv + delta
            if own_mask is not None:
                own = (own_mask, own_rgb)
        lv = np.clip(lv, 0, 4)
        if p.mat in GLOW_RGB:
            col = np.tile(GLOW_RGB[p.mat], (int(m.sum()), 1))
        else:
            col = RAMP_RGB[p.mat][lv]
        if own is not None:
            col[own[0]] = own[1][own[0]]
        rgb[m] = col
    img = np.zeros((H, W, 4), dtype=np.uint8)
    img[:, :, :3] = rgb.reshape(H, W, 3)
    opaque = (pid >= 0).reshape(H, W)
    img[:, :, 3] = np.where(opaque, 255, 0)
    if inner_edges:
        P = pid.reshape(H, W)
        T = best.reshape(H, W)
        dark = np.zeros((H, W), dtype=bool)
        for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            Pn = np.roll(P, (dy, dx), axis=(0, 1))
            Tn = np.roll(T, (dy, dx), axis=(0, 1))
            with np.errstate(invalid='ignore'):
                far = opaque & (Pn >= 0) & (Pn != P) & (T - Tn > 0.045)
            dark |= far
        # a linha interna escurece o pixel mais distante (separação de volumes)
        for k, p in enumerate(parts):
            sel = dark & (P == k)
            if not sel.any():
                continue
            if p.mat in GLOW_RGB:
                continue
            img[sel, :3] = RAMP_RGB[p.mat][0]
    if outline:
        op = img[:, :, 3] > 0
        pad = np.pad(op, 1)
        ring = (pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]) & ~op
        img[ring, :3] = OUTLINE
        img[ring, 3] = 255
    return img


def project(p):
    """Posição em pixels (relativa à origem) de um ponto 3D."""
    x, y, z = p
    return ((x - y) * SQ2 * S, ((x + y) * SQ2 * SIN_E - z * COS_E) * S)


# ------------------------------------------------------------------ padrões (texturas)
def pat_seams(step=0.3, axis_mask=(1, 1, 1), depth=-1):
    """Juntas de painel: linhas mais escuras a cada 'step' unidades."""
    def f(p, n):
        d = np.zeros(len(p), dtype=int)
        for a in range(3):
            if not axis_mask[a]:
                continue
            on_face = np.abs(n[:, a]) < 0.5
            frac = np.abs(((p[:, a] + 10.0) / step) % 1.0)
            d += np.where(on_face & ((frac < 0.06) | (frac > 0.94)), depth, 0)
        return np.maximum(d, -2), None, None
    return f


def pat_hazard(width=0.06, color_a="#e3c76a", color_b="#121321"):
    a = np.array(hex_rgb(color_a), dtype=np.uint8)
    b = np.array(hex_rgb(color_b), dtype=np.uint8)

    def f(p, n):
        k = np.floor((p[:, 0] + p[:, 1] + p[:, 2] + 10.0) / width).astype(int) % 2
        col = np.where(k[:, None] == 0, a, b)
        return np.zeros(len(p), dtype=int), np.ones(len(p), dtype=bool), col
    return f


def pat_cross(size=0.08, thick=0.03, color="#d84050", face_axis=None):
    c = np.array(hex_rgb(color), dtype=np.uint8)

    def f(p, n):
        m = np.zeros(len(p), dtype=bool)
        for a in range(3):
            face = np.abs(n[:, a]) > 0.9
            if face_axis is not None and a != face_axis:
                continue
            o = [i for i in range(3) if i != a]
            q0 = p[:, o[0]]
            q1 = p[:, o[1]]
            cross = ((np.abs(q0) < thick) & (np.abs(q1) < size)) | ((np.abs(q1) < thick) & (np.abs(q0) < size))
            m |= face & cross
        return np.zeros(len(p), dtype=int), m, np.tile(c, (len(p), 1))
    return f


def pat_planks(step=0.08, axis=2):
    def f(p, n):
        frac = ((p[:, axis] + 10.0) / step) % 1.0
        side = np.abs(n[:, axis]) < 0.5
        return np.where(side & (frac < 0.18), -1, 0), None, None
    return f


def pat_noise(seed=1, amount=1, density=0.12):
    def f(p, n):
        h = np.floor(p * 37.0).astype(np.int64)
        hv = (h[:, 0] * 73856093) ^ (h[:, 1] * 19349663) ^ (h[:, 2] * 83492791) ^ seed
        r = (hv % 1000) / 1000.0
        return np.where(r < density, -amount, 0), None, None
    return f


def combine(*fs):
    def f(p, n):
        d = np.zeros(len(p), dtype=int)
        mask = None
        col = None
        for g in fs:
            dd, m, c = g(p, n)
            d = d + dd
            if m is not None:
                if mask is None:
                    mask = m.copy()
                    col = c.copy()
                else:
                    col[m] = c[m]
                    mask |= m
        return d, mask, col
    return f

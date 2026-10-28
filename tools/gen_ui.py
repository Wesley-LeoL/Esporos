#!/usr/bin/env python3
"""Gera a arte da interface (HUD) do Esporos em pixel art ciberpunk.

Tudo é desenhado em "pixels de desenho" e salvo ampliado 2x (vizinho mais próximo), para
casar com o mundo: na janela padrão (1600x900) cada pixel de desenho ocupa 2x2 pixels.
A interface é montada em resolução dupla (scripts/ui/hud.gd), então as texturas entram 1:1.

Saídas em assets/art/ui/: painéis 9-slice, botões, abas, teclas, ícones (cinza, tingidos no
jogo), vinheta e linhas de varredura; e scripts/ui/ui_catalog.gd com o índice dos ícones.
Uso: python3 tools/gen_ui.py [--preview caminho.png]   (requer Pillow e numpy)
"""
import math
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "art", "ui")
CATALOG = os.path.join(ROOT, "scripts", "ui", "ui_catalog.gd")
K = 2  # ampliação


def rgba(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# paleta (mesma base de scripts/ui/ui_theme.gd + o pacote de arte)
INK = "#05080b"
BG = "#0b1218"
PANEL = "#101a22"
PANEL_2 = "#15232d"
EDGE = "#2b424c"
EDGE_2 = "#3d6570"
TEAL = "#66d9d0"
TEAL_D = "#2a6b66"
MAGENTA = "#e070ff"
AMBER = "#e9ad52"
RED = "#ef6268"
SHADOW = "#04070a"

previews = []


def canvas(w, h):
    return np.zeros((h, w, 4), dtype=np.uint8)


def put(img, x, y, col):
    if 0 <= y < img.shape[0] and 0 <= x < img.shape[1]:
        img[y, x] = col


def rect(img, x0, y0, x1, y1, col):
    img[max(y0, 0):y1 + 1, max(x0, 0):x1 + 1] = col


def hline(img, x0, x1, y, col):
    rect(img, x0, y, x1, y, col)


def vline(img, x, y0, y1, col):
    rect(img, x, y0, x, y1, col)


def save(img, name, folder=""):
    up = np.repeat(np.repeat(img, K, axis=0), K, axis=1)
    path = os.path.join(OUT, folder, name + ".png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(up).save(path, optimize=True)
    if up.shape[1] <= 400:
        previews.append((name, up))


def cut_mask(w, h, tl=0, tr=0, br=0, bl=0):
    """Máscara de retângulo com cantos cortados em diagonal (tamanho do corte em px)."""
    m = np.ones((h, w), dtype=bool)
    for y in range(h):
        for x in range(w):
            if tl and x + y < tl:
                m[y, x] = False
            if tr and (w - 1 - x) + y < tr:
                m[y, x] = False
            if br and (w - 1 - x) + (h - 1 - y) < br:
                m[y, x] = False
            if bl and x + (h - 1 - y) < bl:
                m[y, x] = False
    return m


def outline_of(mask):
    pad = np.pad(mask, 1)
    inner = pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:]
    return mask & ~inner


def framed(w, h, fill, edge, cuts=(0, 0, 0, 0), fill_a=235, inner=None, glow_edge=None):
    img = canvas(w, h)
    m = cut_mask(w, h, *cuts)
    img[m] = rgba(fill, fill_a)
    ring = outline_of(m)
    img[ring] = rgba(edge)
    if inner:
        m2 = np.zeros_like(m)
        m2[2:h - 2, 2:w - 2] = cut_mask(w - 4, h - 4, *[max(c - 1, 0) for c in cuts])
        img[outline_of(m2)] = rgba(inner, 255)
    return img, m


# ------------------------------------------------------------------ painéis
def gen_panels():
    # painel principal: cantos cortados (sup. esq. e inf. dir.) e cantoneiras neon
    for name, edge, accent, accent2, alpha in (("panel", EDGE_2, TEAL, MAGENTA, 238), ("panel_solid", EDGE_2, TEAL, MAGENTA, 255),
                                               ("panel_alert", "#6b2a3a", RED, AMBER, 245),
                                               ("panel_warn", "#6b5a2a", AMBER, RED, 238)):
        w = h = 32
        img, m = framed(w, h, PANEL, edge, (5, 0, 5, 0), alpha, inner="#17262f")
        # cantoneiras acesas
        for i in range(5):
            put(img, i, 4 - i, rgba(accent))
            put(img, w - 1 - i, h - 5 + i, rgba(accent))
        hline(img, 5, 12, 0, rgba(accent))
        vline(img, 0, 5, 11, rgba(accent))
        hline(img, w - 13, w - 6, h - 1, rgba(accent))
        vline(img, w - 1, h - 12, h - 6, rgba(accent))
        # detalhes: dois pontos de cor no canto superior direito e inferior esquerdo
        put(img, w - 4, 2, rgba(accent2))
        put(img, w - 6, 2, rgba(accent2))
        put(img, 2, h - 3, rgba(accent2))
        save(img, name)
    # cartão (vitais) mais discreto
    img, m = framed(24, 24, "#0e171e", EDGE, (3, 0, 3, 0), 225)
    for i in range(3):
        put(img, i, 2 - i, rgba(EDGE_2))
    save(img, "card")
    # fita de título: plana à esquerda, listras de perigo à direita
    w, h = 64, 12
    img = canvas(w, h)
    rect(img, 0, 0, w - 1, h - 1, rgba(PANEL_2, 245))
    hline(img, 0, w - 1, h - 1, rgba(TEAL))
    hline(img, 0, w - 1, 0, rgba("#1e3440"))
    for x in range(w - 22, w):
        for y in range(1, h - 1):
            if ((x + y) // 3) % 2 == 0:
                put(img, x, y, rgba(AMBER))
            else:
                put(img, x, y, rgba("#2a2418"))
    rect(img, 0, 2, 1, h - 3, rgba(TEAL))
    save(img, "header")
    # faixa de aviso (modo construção)
    w, h = 32, 10
    img = canvas(w, h)
    for x in range(w):
        for y in range(h):
            img[y, x] = rgba(AMBER if ((x + y) // 3) % 2 == 0 else "#1c160c", 235)
    hline(img, 0, w - 1, 0, rgba(INK))
    hline(img, 0, w - 1, h - 1, rgba(INK))
    save(img, "stripes")


# ------------------------------------------------------------------ botões e abas
def gen_buttons():
    w, h = 16, 12
    specs = {
        "button_normal": ("#13212a", EDGE_2, "#1d3440", None),
        "button_hover": ("#183440", TEAL, "#24485a", TEAL),
        "button_pressed": (TEAL_D, TEAL, "#3a8a83", None),
        "button_disabled": ("#0c1318", "#1c2a31", None, None),
    }
    for name, (fill, edge, hi, bar) in specs.items():
        img, m = framed(w, h - 1, fill, edge, (2, 0, 2, 0), 245)
        full = canvas(w, h)
        if name == "button_pressed":
            full[1:, :] = img
        else:
            full[:h - 1, :] = img
            hline(full, 2, w - 1, h - 1, rgba(SHADOW))
        if hi:
            hline(full, 3, w - 3, 1 + (1 if name == "button_pressed" else 0), rgba(hi))
        if bar:
            vline(full, 1, 3, h - 4, rgba(bar))
        save(full, name)
    # abas
    w, h = 16, 12
    for name, fill, edge, top in (("tab_normal", "#0d151b", EDGE, None), ("tab_hover", "#13212a", EDGE_2, None),
                                  ("tab_selected", "#183440", TEAL, TEAL)):
        img = canvas(w, h)
        m = cut_mask(w, h, 3, 3, 0, 0)
        img[m] = rgba(fill, 245)
        ring = outline_of(m)
        ring[h - 1, :] = False
        img[ring] = rgba(edge)
        if top:
            hline(img, 3, w - 4, 1, rgba(top))
            hline(img, 3, w - 4, 2, rgba("#3a8a83"))
        save(img, name)
    # tecla (keycap)
    w, h = 12, 13
    img = canvas(w, h)
    m = cut_mask(w, h - 2, 1, 1, 1, 1)
    img[:h - 2][m] = rgba("#22323b")
    img[:h - 2][outline_of(m)] = rgba("#91a6ad")
    hline(img, 2, w - 3, 1, rgba("#3a4f5a"))
    rect(img, 1, h - 2, w - 2, h - 1, rgba("#0b1116"))
    hline(img, 1, w - 2, h - 2, rgba("#4a5f6a"))
    save(img, "keycap")
    # barra de rolagem
    img = canvas(6, 12)
    rect(img, 0, 0, 5, 11, rgba("#0b1218", 220))
    vline(img, 0, 0, 11, rgba(EDGE))
    save(img, "scroll_track")
    img = canvas(6, 12)
    rect(img, 1, 1, 4, 10, rgba(TEAL_D))
    vline(img, 1, 1, 10, rgba(TEAL))
    rect(img, 2, 5, 3, 6, rgba(TEAL))
    save(img, "scroll_grabber")
    # slot de equipamento
    w = h = 20
    img, m = framed(w, h, "#0c141a", EDGE_2, (3, 0, 3, 0), 230, inner="#132029")
    put(img, w - 3, 2, rgba(TEAL))
    save(img, "slot")


# ------------------------------------------------------------------ fundo / efeitos de tela
def gen_screen():
    # linhas de varredura: uma linha escura por pixel de desenho, ladrilhável
    img = canvas(1, 2)
    img[1, 0] = (0, 0, 0, 40)
    save(img, "scanlines")
    # vinheta pontilhada (dither ordenado) no tamanho da tela em pixels de desenho (800x450)
    w, h = 800, 450
    bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
    yy, xx = np.mgrid[0:h, 0:w]
    dx = (xx - w / 2 + 0.5) / (w / 2)
    dy = (yy - h / 2 + 0.5) / (h / 2)
    r = np.sqrt(dx * dx * 0.85 + dy * dy)
    t = np.clip((r - 0.82) / 0.42, 0.0, None)
    on = t > bayer[yy % 4, xx % 4] * 1.15
    img = canvas(w, h)
    img[on] = (2, 4, 8, 0)
    img[on, 3] = (np.minimum(0.5, 0.18 + t[on] * 0.35) * 255).astype(np.uint8)
    save(img, "vignette")
    # grade de fundo do terminal (ladrilho)
    img = canvas(16, 16)
    hline(img, 0, 15, 15, (102, 217, 208, 14))
    vline(img, 15, 0, 15, (102, 217, 208, 14))
    put(img, 15, 15, (102, 217, 208, 40))
    save(img, "grid")


# ------------------------------------------------------------------ ícones
# Desenhados em cinza (tingidos no jogo): '#'=branco, '+'=claro, '-'=médio, 'd'=escuro.
# O contorno preto é gerado automaticamente em volta.
SHADES = {"#": 255, "+": 205, "-": 150, "d": 70}
ICONS = {}


def icon(name, rows):
    ICONS[name] = rows


icon("contaminacao", [
    ".....#.....",
    ".#...#...#.",
    "..#.###.#..",
    "...#####...",
    "..##-#-##..",
    "####+#+####",
    "..##-#-##..",
    "...#####...",
    "..#.###.#..",
    ".#...#...#.",
    ".....#.....",
])
icon("vida", [
    "..........",
    ".###..###.",
    "#+####-###",
    "#+########",
    "##########",
    ".########.",
    "..######..",
    "...####...",
    "....##....",
])
icon("fome", [
    ".#.#.#..##.",
    ".#.#.#.###.",
    ".#.#.#.###.",
    ".#####.###.",
    "..###..###.",
    "...#...-##.",
    "...#....#..",
    "...#....#..",
    "...#....#..",
    "...#....#..",
    "...-....-..",
])
icon("sede", [
    ".....#.....",
    ".....#.....",
    "....###....",
    "...#####...",
    "..##+####..",
    ".##+######.",
    ".##+######.",
    ".#########.",
    "..#######..",
    "...-###-...",
])
icon("mascara", [
    "..#######..",
    ".#########.",
    "#+ddd#ddd+#",
    "#dd+d#d+dd#",
    "#+ddd#ddd+#",
    ".####-####.",
    "...#---#...",
    "..#-#-#-#..",
    "..#-#-#-#..",
    "...#####...",
])
icon("filtro", [
    "...#####...",
    "..#######..",
    "..#-----#..",
    "..#######..",
    "..#+####-..",
    "..#-----#..",
    "..#######..",
    "...#####...",
    "....###....",
    "....#-#....",
])
icon("esporos", [
    "....#......",
    "...###..#..",
    "....#..###.",
    ".#......#..",
    "###..#.....",
    ".#..###....",
    "....#+#..#.",
    ".....#..###",
    "..#......#.",
    ".###..#....",
    "..#.......",
])
icon("arma", [
    ".........##",
    "........###",
    ".......###.",
    "......###..",
    ".....###...",
    "....###....",
    "...###.....",
    "..-##......",
    ".--#.......",
    "-d-........",
    "dd.........",
])
icon("supressor", [
    ".........#.",
    "........#..",
    ".......#...",
    "......###..",
    ".....#+-#..",
    "....#+-#...",
    "...#+-#....",
    "..####.....",
    ".#.##......",
    "#..........",
])
icon("antibiotico", [
    "......###..",
    ".....#####.",
    "....######.",
    "...######..",
    "..d#####...",
    ".-d####....",
    "-+-d##.....",
    "-+--d......",
    "---d.......",
    ".--........",
])
icon("caveira", [
    "..#######..",
    ".#########.",
    "###########",
    "##ddd#ddd##",
    "##ddd#ddd##",
    "#####d#####",
    ".####d####.",
    "..#######..",
    "..#.#.#.#..",
    "..#######..",
])
icon("alerta", [
    ".....#.....",
    "....###....",
    "....#d#....",
    "...##d##...",
    "...##d##...",
    "..###d###..",
    "..#######..",
    ".####d####.",
    "###########",
])
icon("martelo", [
    "..######...",
    ".#######...",
    ".########..",
    "..##-###...",
    ".....-#....",
    "......-#...",
    ".......-#..",
    "........-#.",
    ".........-#",
    "..........-",
])
icon("relogio", [
    "...#####...",
    "..#-----#..",
    ".#---#---#.",
    "#----#----#",
    "#----#----#",
    "#----###--#",
    "#---------#",
    ".#-------#.",
    "..#-----#..",
    "...#####...",
])
icon("bateria", [
    "....###....",
    "..#######..",
    "..#-----#..",
    "..#-----#..",
    "..#######..",
    "..#######..",
    "..#######..",
    "..#######..",
    "..#######..",
    "...#####...",
])
icon("mochila", [
    "....###....",
    "...#-.-#...",
    "..#######..",
    ".#########.",
    ".#-------#.",
    ".#-#####-#.",
    ".#-#+++#-#.",
    ".#-#####-#.",
    ".#########.",
    "..##...##..",
])
icon("corpo", [
    "....###....",
    "....###....",
    ".....#.....",
    "..#######..",
    ".#.#####.#.",
    ".#.#####.#.",
    "...#####...",
    "...##.##...",
    "...##.##...",
    "...##.##...",
])
icon("chip", [
    ".#.#.#.#.#.",
    "###########",
    ".#-------#.",
    "##-#####-##",
    ".#-#+++#-#.",
    "##-#+++#-##",
    ".#-#####-#.",
    "##-------##",
    "###########",
    ".#.#.#.#.#.",
])
icon("mundo", [
    "...#####...",
    "..#-#-#-#..",
    ".#-##-##-#.",
    "#--#-#-#--#",
    "###########",
    "#--#-#-#--#",
    ".#-##-##-#.",
    "..#-#-#-#..",
    "...#####...",
])
icon("legado", [
    "...#####...",
    "..#######..",
    ".###-#-###.",
    ".####-####.",
    ".###-#-###.",
    ".#########.",
    ".#########.",
    ".#########.",
    "###########",
    "-----------",
])
icon("sangue", [
    ".....#.....",
    "....###....",
    "...#####...",
    "..##+####..",
    "..#+#####..",
    "..#######..",
    "...#####...",
    "....-#-....",
    "...........",
    "....#..#...",
])
icon("calor", [
    ".....#.....",
    "....##.....",
    "....###....",
    "...####.#..",
    "..#####.##.",
    "..##+######",
    ".###+-#####",
    ".##+---####",
    ".##+---+##.",
    "..##---##..",
    "...#####...",
])


icon("estamina", [
    "......###..",
    ".....###...",
    "....###....",
    "...###.....",
    "..#######..",
    ".....###...",
    "....###....",
    "...###.....",
    "..##.......",
    ".#.........",
])
icon("cerebro", [
    "...#####...",
    "..#+#-#+#..",
    ".#+##-##+#.",
    "#+#-#-#-#+#",
    "#####-#####",
    "#+#-#-#-#+#",
    ".#+##-##+#.",
    "..#######..",
    "....#.#....",
    "....###....",
])
icon("municao", [
    "..#...#...#",
    ".###.###.###",
    ".#+#.#+#.#+#",
    ".#+#.#+#.#+#",
    ".#+#.#+#.#+#",
    ".###.###.###",
    ".---.---.---",
    ".###.###.###",
])
icon("ruido", [
    "...#....#..",
    "..##..#..#.",
    ".###.#.#..#",
    "####.#.#..#",
    "####.#.#..#",
    ".###.#.#..#",
    "..##..#..#.",
    "...#....#..",
])
icon("olho", [
    "...........",
    "...#####...",
    "..#-----#..",
    ".#--###--#.",
    "#--##+##--#",
    ".#--###--#.",
    "..#-----#..",
    "...#####...",
])
icon("planta", [
    "....#......",
    "...###.##..",
    "..####.###.",
    "...##.###..",
    "..##..#....",
    ".###.#.....",
    "..####.....",
    ".....#.....",
    "...#####...",
    "...#+++#...",
    "....###....",
])
icon("panela", [
    "..#..#..#..",
    "...#..#..#.",
    "...........",
    ".#########.",
    "###+++++###",
    ".#+++++++#.",
    ".#+++++++#.",
    ".#+++++++#.",
    "..#######..",
])
icon("carro", [
    "...........",
    "...#####...",
    "..#-#-#-#..",
    ".#--#--#-#.",
    "###########",
    "#+#######+#",
    "###########",
    ".##.....##.",
    ".--.....--.",
])
icon("pessoa", [
    "....###....",
    "...#####...",
    "...#####...",
    "....###....",
    "..#######..",
    ".#########.",
    ".#.#####.#.",
    "...##.##...",
    "...##.##...",
    "...##.##...",
])

ICON_CELL = 16


def gen_icons():
    names = list(ICONS.keys())
    cols = 8
    rows = (len(names) + cols - 1) // cols
    sheet = canvas(cols * ICON_CELL, rows * ICON_CELL)
    for i, n in enumerate(names):
        art = ICONS[n]
        h = len(art)
        w = max(len(r) for r in art)
        cell = canvas(ICON_CELL, ICON_CELL)
        ox = (ICON_CELL - w) // 2
        oy = (ICON_CELL - h) // 2
        filled = np.zeros((ICON_CELL, ICON_CELL), dtype=bool)
        for y, row in enumerate(art):
            for x, ch in enumerate(row):
                if ch in SHADES:
                    v = SHADES[ch]
                    cell[oy + y, ox + x] = (v, v, v, 255)
                    filled[oy + y, ox + x] = True
        pad = np.pad(filled, 1)
        ring = (pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]) & ~filled
        cell[ring] = (0, 0, 0, 255)
        r, c = divmod(i, cols)
        sheet[r * ICON_CELL:(r + 1) * ICON_CELL, c * ICON_CELL:(c + 1) * ICON_CELL] = cell
    save(sheet, "icons")
    return names, cols


def write_catalog(names, cols):
    L = ["# GERADO por tools/gen_ui.py - não edite à mão.",
         "class_name UICatalog",
         "extends RefCounted",
         "## Índice dos ícones da interface em assets/art/ui/icons.png (cinza, tingidos no jogo).",
         "",
         'const ICONS_PATH := "res://assets/art/ui/icons.png"',
         "const ICON_CELL := %d" % (ICON_CELL * K),
         "const ICON_COLS := %d" % cols,
         "const ICONS := {"]
    for i, n in enumerate(names):
        L.append('\t"%s": %d,' % (n, i))
    L.append("}")
    with open(CATALOG, "w", encoding="utf-8") as f:
        f.write("\n".join(L) + "\n")


def save_preview(path):
    W = 900
    blocks = [im for _, im in previews]
    H = sum(b.shape[0] + 10 for b in blocks) + 10
    out = np.zeros((H, W, 3), dtype=np.uint8)
    out[:] = (40, 46, 60)
    y = 10
    x = 10
    rowh = 0
    for b in blocks:
        if x + b.shape[1] > W - 10:
            x = 10
            y += rowh + 10
            rowh = 0
        a = b[:, :, 3:4] / 255.0
        reg = out[y:y + b.shape[0], x:x + b.shape[1]]
        bw = min(b.shape[1], W - x)
        out[y:y + b.shape[0], x:x + bw] = (b[:, :bw, :3] * a[:, :bw] + reg[:, :bw] * (1 - a[:, :bw])).astype(np.uint8)
        x += b.shape[1] + 10
        rowh = max(rowh, b.shape[0])
    out = out[:y + rowh + 10]
    Image.fromarray(out).resize((out.shape[1] * 2, out.shape[0] * 2), Image.NEAREST).save(path)


def main():
    gen_panels()
    gen_buttons()
    gen_screen()
    names, cols = gen_icons()
    write_catalog(names, cols)
    if "--preview" in sys.argv:
        save_preview(sys.argv[sys.argv.index("--preview") + 1])
    print("ícones:", len(names), "texturas:", len(previews))


if __name__ == "__main__":
    main()

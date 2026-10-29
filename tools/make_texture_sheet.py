#!/usr/bin/env python3
"""Prancha de referência com todas as texturas do Esporos no padrão visual (STYLE.md).

Uso: python3 tools/make_texture_sheet.py [saida.png]
Lê os PNGs gerados e o pacote FreeSample (referência) e monta uma imagem por seções,
ampliada 2x (como no jogo), com o nome de cada item."""
import glob
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ART = os.path.join(ROOT, "assets", "art")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_ground  # noqa: E402

BG = (30, 32, 44)
PANEL = (44, 46, 62)
TXT = (230, 230, 240)
ACC = (102, 217, 208)
W = 2400
SCALE = 2
FONT = ImageFont.truetype(os.path.join(ART, "ui", "fonts", "Jersey10-Regular.ttf"), 30)
FONT_S = ImageFont.truetype(os.path.join(ART, "ui", "fonts", "Jersey10-Regular.ttf"), 20)


def trim(im):
    bb = im.getbbox()
    return im.crop(bb) if bb else im


def views(path):
    """Separa as vistas lado a lado de um PNG (colunas vazias entre elas)."""
    im = Image.open(path).convert("RGBA")
    a = np.array(im)[:, :, 3] > 0
    cols = a.any(axis=0)
    out, start = [], None
    for x, v in enumerate(cols):
        if v and start is None:
            start = x
        if not v and start is not None:
            out.append(trim(im.crop((start, 0, x, im.height))))
            start = None
    if start is not None:
        out.append(trim(im.crop((start, 0, im.width, im.height))))
    return out


def frames(path, fw, fh):
    im = Image.open(path).convert("RGBA")
    out = []
    for y in range(0, im.height, fh):
        for x in range(0, im.width, fw):
            f = trim(im.crop((x, y, x + fw, y + fh)))
            if f.getbbox():
                out.append(f)
    return out


def catalog_sheets():
    """Lê scripts/art/gen_catalog.gd (fw/fh de cada folha)."""
    out = {}
    with open(os.path.join(ROOT, "scripts", "art", "gen_catalog.gd"), encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith('"') and '"fw"' in line:
                name = line.split('"')[1]
                d = eval(line[line.index("{"):line.rindex("}") + 1].replace("true", "True"))
                out[name] = d
    return out


class Sheet:
    def __init__(self):
        self.blocks = []

    def section(self, title, items, scale=SCALE, max_h=None):
        """items: [(rótulo, imagem RGBA)]. Monta as imagens em linhas."""
        pad = 14
        placed = []
        x, y, row_h = pad, 50, 0
        for label, im in items:
            if max_h and im.height * scale > max_h:
                k = max_h / (im.height * scale)
                im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.NEAREST)
                s = scale
            else:
                s = scale
            w, h = im.width * s, im.height * s + 26
            w = max(w, int(FONT_S.getlength(label)) + 4)
            if x + w > W - pad:
                x = pad
                y += row_h + pad
                row_h = 0
            placed.append((label, im, s, x, y))
            x += w + pad
            row_h = max(row_h, h)
        H = y + row_h + pad
        img = Image.new("RGB", (W, H), PANEL)
        d = ImageDraw.Draw(img)
        d.text((pad, 10), title, font=FONT, fill=ACC)
        for label, im, s, x, y in placed:
            big = im.resize((im.width * s, im.height * s), Image.NEAREST)
            img.paste(big, (x, y), big)
            d.text((x, y + big.height + 2), label, font=FONT_S, fill=TXT)
        self.blocks.append(img)

    def save(self, path):
        H = sum(b.height + 10 for b in self.blocks) + 80
        out = Image.new("RGB", (W, H), BG)
        d = ImageDraw.Draw(out)
        d.text((14, 16), "ESPOROS — texturas no padrão visual (assets/art/STYLE.md) · ampliado 2x, como no jogo",
               font=FONT, fill=TXT)
        y = 70
        for b in self.blocks:
            out.paste(b, (0, y))
            y += b.height + 10
        out.save(path, optimize=True)
        print("prancha:", path, out.size)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "docs", "texturas.png")
    sh = Sheet()
    cat = catalog_sheets()
    # referência
    ref = []
    for p in sorted(glob.glob(os.path.join(ART, "tiles", "*", "*.png"))):
        v = views(p)
        if v:
            ref.append((os.path.splitext(os.path.basename(p))[0], v[0]))
    sh.section("1. Referência: pacote FreeSample (base do padrão)", ref, scale=1, max_h=330)
    # chão
    atlas = Image.open(os.path.join(ART, "generated", "world", "ground.png")).convert("RGBA")
    ground = []
    for i, t in enumerate(gen_ground.GROUND_TYPES):
        for v in range(gen_ground.VARIANTS):
            ground.append(("%s %d" % (t.lower(), v + 1), atlas.crop((i * 80, v * 40, i * 80 + 80, v * 40 + 40))))
    sh.section("2. Chão (20 tipos x 3 variações)", ground)
    # prédios exploráveis: paredes (cheia e baixa) e telhados
    walls = []
    for name in sorted(cat):
        if name.startswith("w_"):
            fr = frames(os.path.join(ROOT, cat[name]["path"].replace("res://", "")), cat[name]["fw"], cat[name]["fh"])
            walls.append((name[2:], fr[0]))
            if len(fr) > 1:
                walls.append(("(baixa)", fr[1]))
    sh.section("3. Paredes dos prédios (material x variação; inteira e baixa, do corte do The Sims)", walls)
    roofs = []
    for p in sorted(glob.glob(os.path.join(ART, "generated", "town", "roofs", "*_4x3.png"))):
        roofs.append((os.path.splitext(os.path.basename(p))[0], trim(Image.open(p).convert("RGBA"))))
    sh.section("4. Telhados (um tamanho de cada estilo; há de 3x3 a 8x7)", roofs, scale=1)
    # objetos de cenário
    props = []
    for name in sorted(cat):
        if name.startswith("c_"):
            for k, f in enumerate(frames(os.path.join(ROOT, cat[name]["path"].replace("res://", "")), cat[name]["fw"], cat[name]["fh"])):
                props.append((name[2:] + ("" if k == 0 else " %d" % (k + 1)), f))
    sh.section("5. Objetos de cenário e móveis (rua, vila, indústria, abrigo, campo, esporos)", props)
    # construções do jogador
    cons = []
    for name in sorted(cat):
        s = cat[name]
        if "/structures/" in s["path"]:
            fr = frames(os.path.join(ROOT, s["path"].replace("res://", "")), s["fw"], s["fh"])
            for k, f in enumerate(fr[:5]):
                cons.append((name + ("" if k == 0 else " %d" % (k + 1)), f))
    sh.section("6. Construções do jogador (paredes de borda, utilidades, decoração)", cons)
    # personagens, caixas e veículos
    chars = []
    for name in sorted(cat):
        s = cat[name]
        if name.startswith("survivor") and name != "survivor_m1_a0_e0":
            continue
        if "/characters/" in s["path"] or "/props/" in s["path"] and "/city/" not in s["path"]:
            fr = frames(os.path.join(ROOT, s["path"].replace("res://", "")), s["fw"], s["fh"])
            for k, f in enumerate(fr[:4]):
                chars.append((name + ("" if k == 0 else " %d" % (k + 1)), f))
    sh.section("7. Personagens, caixas de saque e veículos", chars)
    # ícones
    icons = Image.open(os.path.join(ART, "generated", "ui", "icons.png")).convert("RGBA")
    ic = []
    n = 0
    for y in range(0, icons.height, 28):
        for x in range(0, icons.width, 28):
            f = icons.crop((x, y, x + 28, y + 28))
            if f.getbbox():
                ic.append(("", f))
                n += 1
    sh.section("8. Ícones dos itens", ic)
    sh.save(out)


if __name__ == "__main__":
    main()

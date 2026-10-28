#!/usr/bin/env python3
"""Gera a arte que faltava no Esporos, no estilo do pacote FreeSample.

Saídas (todas em assets/art/generated/):
  characters/  sobrevivente (8 combinações de máscara/implantes), infectado, elite, cadáver
  structures/  parede, porta, gerador, purificador, torre, selagem de ar
  props/       caixas de saque (comum, médico, técnico; cheias e vazias), saco, caravana
  world/       atlas do chão (8 tipos x 3 variações, losangos 80x40)
  ui/          ícones dos itens (28x28)
e o catálogo scripts/art/gen_catalog.gd (tamanho de quadro, âncora e animações).

Uso:  python3 tools/gen_art.py [--preview caminho.png]
Requer Pillow e numpy. Os personagens têm 8 linhas (direções na ordem do enum Facing do
jogo: L, SE, S, SO, O, NO, N, NE).
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_models as am  # noqa: E402
from art_render import RAMP_RGB, hex_rgb, render, scale_parts  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "art", "generated")
CATALOG = os.path.join(ROOT, "scripts", "art", "gen_catalog.gd")
FACING_THETA = [f * 45 - 45 for f in range(8)]  # ângulo do modelo para cada direção

BIG_W, BIG_H, BIG_OX, BIG_OY = 200, 240, 100, 180

sheets = {}
previews = []


def crop_sheet(name, folder, rows, label):
    """rows: lista de linhas, cada linha uma lista de imagens BIG. Recorta todas para a
    caixa comum, monta a folha e registra no catálogo."""
    allimgs = [im for r in rows for im in r]
    alpha = np.zeros((BIG_H, BIG_W), dtype=bool)
    for im in allimgs:
        alpha |= im[:, :, 3] > 0
    ys = np.where(alpha.any(axis=1))[0]
    xs = np.where(alpha.any(axis=0))[0]
    y0, y1, x0, x1 = ys[0], ys[-1] + 1, xs[0], xs[-1] + 1
    fw, fh = x1 - x0, y1 - y0
    cols = max(len(r) for r in rows)
    sheet = np.zeros((fh * len(rows), fw * cols, 4), dtype=np.uint8)
    for ri, r in enumerate(rows):
        for ci, im in enumerate(r):
            sheet[ri * fh:(ri + 1) * fh, ci * fw:(ci + 1) * fw] = im[y0:y1, x0:x1]
    os.makedirs(os.path.join(OUT, folder), exist_ok=True)
    path = os.path.join(OUT, folder, name + ".png")
    Image.fromarray(sheet).save(path, optimize=True)
    sheets[name] = {"path": "res://assets/art/generated/%s/%s.png" % (folder, name),
                    "fw": int(fw), "fh": int(fh), "ox": int(BIG_OX - x0), "oy": int(BIG_OY - y0),
                    "cols": cols, "rows": len(rows)}
    previews.append((label, sheet))
    return sheets[name]


def R(parts, theta=0.0):
    return render(parts, BIG_W, BIG_H, BIG_OX, BIG_OY, theta)


# ---------------------------------------------------------------- personagens
WALK = [(0, 0.02), (24, 0.0), (0, 0.02), (-24, 0.0)]


def survivor_frames(mask, arm, eye):
    kw = dict(mask=mask, arm_implant=arm, eye_implant=eye)
    frames = []
    frames.append(lambda: am.survivor(**kw))
    frames.append(lambda: am.survivor(bob=-0.012, arm=3, **kw))
    for leg, bob in WALK:
        frames.append(lambda leg=leg, bob=bob: am.survivor(leg=leg, arm=leg * 0.8, bob=bob, **kw))
    for atk in (-165, -85, -30):
        frames.append(lambda atk=atk: am.survivor(attack=atk, leg=8 if atk > -100 else 0, **kw))
    return frames


def gen_characters():
    for m in (1, 0):
        for a in (0, 1):
            for e in (0, 1):
                fr = survivor_frames(bool(m), bool(a), bool(e))
                rows = [[R(f(), FACING_THETA[d]) for f in fr] for d in range(8)]
                crop_sheet("survivor_m%d_a%d_e%d" % (m, a, e), "characters", rows,
                           "sobrevivente m%d a%d e%d" % (m, a, e))
    for elite in (False, True):
        fr = []
        for leg, sway in ((18, 4), (0, 0), (-18, -4), (0, 0)):
            fr.append(lambda leg=leg, sway=sway: am.infected(leg=leg, sway=sway, reach=-72, elite=elite))
        for reach in (-120, -35):
            fr.append(lambda reach=reach: am.infected(leg=10, reach=reach, elite=elite))
        rows = [[R(f(), FACING_THETA[d]) for f in fr] for d in range(8)]
        crop_sheet("elite" if elite else "infected", "characters", rows, "elite" if elite else "infectado")
    def corpse(mask, theta):
        body = R(am.survivor(lying=True, mask=mask), theta)
        pool = render(am.blood_pool(), BIG_W, BIG_H, BIG_OX, BIG_OY, theta, outline=False, inner_edges=False)
        out = pool.copy()
        a = body[:, :, 3:4] > 0
        out[:, :, :] = np.where(a, body, pool)
        return out

    crop_sheet("corpse", "characters", [[corpse(True, 35), corpse(False, 215)]],
               "cadáver")


# ---------------------------------------------------------------- estruturas
def gen_structures():
    crop_sheet("parede", "structures", [[R(am.wall(0)), R(am.wall(1))]], "parede")
    crop_sheet("porta", "structures", [[R(am.door(False)), R(am.door(True))]], "porta")
    crop_sheet("gerador", "structures", [[R(am.generator(True)), R(am.generator(False))]], "gerador")
    crop_sheet("purificador", "structures", [[R(am.purifier(True)), R(am.purifier(False))]], "purificador")
    crop_sheet("vedacao", "structures", [[R(am.seal(True)), R(am.seal(False))]], "selagem de ar")
    rows = [[R(am.turret(on, FACING_THETA[d])) for d in range(8)] for on in (True, False)]
    crop_sheet("torre", "structures", rows, "torre (8 direções, ligada/desligada)")


def gen_props():
    row = []
    for kind in ("comum", "medico", "tecnico"):
        row.append(R(am.crate(kind, False)))
        row.append(R(am.crate(kind, True)))
    row.append(R(am.loot_bag(), 30))
    crop_sheet("containers", "props", [row], "caixas (cheia/vazia) e saco")
    crop_sheet("caravan", "props", [[R(am.caravan(), t) for t in (0, 90, 180, 270)]], "caravana (SE, SO, NO, NE)")
    crop_sheet("picape", "props", [[R(am.pickup(), FACING_THETA[d]) for d in range(8)]], "picape (8 direções)")
    crop_sheet("moto", "props", [[R(am.moto(), FACING_THETA[d]) for d in range(8)]], "moto (8 direções)")
    crop_sheet("canteiro", "structures", [[R(am.planter(st)) for st in range(5)]], "canteiro (vazio..murcho)")
    crop_sheet("fogareiro", "structures", [[R(am.stove(True)), R(am.stove(False))]], "fogareiro")
    # paredes de borda: linha 0 = borda x+ (entre a célula e a vizinha x+1), linha 1 = borda y+
    for name in ("parede_madeira", "parede_metal", "meia_parede", "janela"):
        crop_sheet(name, "structures", [[R(am.edge_wall(name, d))] for d in (0, 1)], name + " (bordas)")
    for name in ("porta", "portao"):
        crop_sheet(name, "structures", [[R(am.edge_wall(name, d, False)), R(am.edge_wall(name, d, True))] for d in (0, 1)],
                   name + " (bordas, fechada/aberta)")
    crop_sheet("eolico", "structures", [[R(am.wind_turbine(h)) for h in range(1, 6)]], "eólico (1 a 5 módulos)")
    for name, on_off in (("bancada", False), ("mesa_reparo", False), ("bateria_casa", True), ("coletor", True),
                         ("cama", False), ("luminaria", True), ("poste", True), ("letreiro", True), ("mesa", False),
                         ("cadeira", False), ("sofa", False), ("tapete", False), ("vaso", False), ("estante", False)):
        cols = [R(am.object_model(name, True)), R(am.object_model(name, False))] if on_off else [R(am.object_model(name, True))]
        crop_sheet(name, "structures", [cols], name)


# ---------------------------------------------------------------- ícones
ICON = 28
ITEMS = ["feijao", "carne_seca", "barra_cereal", "agua_limpa", "agua_suja", "mascara", "filtro",
         "supressor", "bandagem", "antisseptico", "kit_sutura", "antibiotico", "kit_cirurgico",
         "bateria", "combustivel", "sucata", "madeira", "metal", "cano", "machete",
         "manual_mecanica", "manual_metalurgia", "manual_medicina", "manual_engenharia",
         "implante_pulmao", "implante_hud", "implante_braco",
         "mochila_escolar", "mochila_trilha", "mochila_militar", "coldre", "fita", "faca", "taco", "maca", "pao", "abridor",
         "manual_carpintaria", "manual_cibernetica",
         "proc_neural_mk1", "proc_neural_mk2", "implante_pernas", "implante_derme",
         "chave_fenda", "martelo", "serra", "alicate", "lanterna", "pilha", "pregos", "fios",
         "sucata_eletronica", "cantil", "gaze", "analgesico", "alcool", "pistola", "espingarda",
         "municao_9mm", "cartucho_12", "semente_batata", "semente_milho", "semente_tomate", "batata", "milho",
         "tomate", "enxada", "regador", "panela", "sopa", "ensopado", "milho_assado"]


def fit_icon(parts, theta):
    k = 0.4
    for _ in range(6):
        im = render(scale_parts(parts, k), 96, 96, 48, 72, theta)
        a = im[:, :, 3] > 0
        ys = np.where(a.any(axis=1))[0]
        xs = np.where(a.any(axis=0))[0]
        w = xs[-1] - xs[0] + 1
        h = ys[-1] - ys[0] + 1
        f = (ICON - 4) / max(w, h)
        if 0.93 < f < 1.07:
            break
        k *= f
    out = np.zeros((ICON, ICON, 4), dtype=np.uint8)
    sub = im[ys[0]:ys[-1] + 1, xs[0]:xs[-1] + 1][:ICON, :ICON]
    oy = (ICON - sub.shape[0]) // 2
    ox = (ICON - sub.shape[1]) // 2
    out[oy:oy + sub.shape[0], ox:ox + sub.shape[1]] = sub
    return out


def gen_icons():
    cols = 8
    rows = (len(ITEMS) + cols - 1) // cols
    sheet = np.zeros((rows * ICON, cols * ICON, 4), dtype=np.uint8)
    for i, it in enumerate(ITEMS):
        im = fit_icon(am.item_model(it), 20)
        r, c = divmod(i, cols)
        sheet[r * ICON:(r + 1) * ICON, c * ICON:(c + 1) * ICON] = im
    os.makedirs(os.path.join(OUT, "ui"), exist_ok=True)
    Image.fromarray(sheet).save(os.path.join(OUT, "ui", "icons.png"), optimize=True)
    previews.append(("ícones", sheet))
    return cols


# ---------------------------------------------------------------- chão
GROUND_TYPES = ["CONC_A", "CONC_B", "ESPOROS", "ESTRADA", "TERRA", "PISO", "MANCHA", "VILA", "PISO_MADEIRA", "PISO_CONCRETO"]
TW, TH = 80, 40


def _hash(x, y, s):
    h = (x * 374761393 + y * 668265263 + s * 2147483647) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    return (h ^ (h >> 16)) / 0xFFFFFFFF


def _col(ramp, i):
    return RAMP_RGB[ramp][i]


def ground_tile(kind, var):
    img = np.zeros((TH, TW, 4), dtype=np.uint8)
    yy, xx = np.mgrid[0:TH, 0:TW]
    d = np.abs(xx - (TW - 1) / 2.0) / (TW / 2.0) + np.abs(yy - (TH - 1) / 2.0) / (TH / 2.0)
    mask = d <= 1.0
    # coordenadas no losango (u,v em [0,1]) para padrões alinhados à grade
    u = (xx / TW + yy / TH) - 0.5
    v = (yy / TH - xx / TW) + 0.5
    s = GROUND_TYPES.index(kind) * 10 + var
    rnd = np.vectorize(lambda a, b: _hash(int(a), int(b), s))(xx, yy)
    base = np.zeros((TH, TW, 3), dtype=np.uint8)

    def fill(c):
        base[:] = c

    if kind in ("CONC_A", "CONC_B"):
        ramp = "indigo"
        fill(_col(ramp, 1 if kind == "CONC_A" else 2))
        base[rnd > 0.86] = _col(ramp, 2 if kind == "CONC_A" else 3)
        base[rnd < 0.05] = _col(ramp, 0)
        if kind == "CONC_B":
            seam = (np.abs(u - 0.5) < 0.012) | (np.abs(v - 0.5) < 0.012)
            base[seam] = _col(ramp, 1)
        # rachadura irregular (passeio aleatório), diferente em cada variação
        if var > 0:
            x, y = 14 + var * 17 + int(_hash(var, 3, s) * 10), 12 + int(_hash(var, 5, s) * 10)
            for step in range(26 + var * 6):
                if 0 <= x < TW and 0 <= y < TH:
                    base[y, x] = _col(ramp, 0)
                r = _hash(step, var, s + 11)
                x += 1 if r < 0.55 else (0 if r < 0.8 else -1)
                y += 1 if _hash(step, var, s + 13) < 0.35 else 0
    elif kind == "ESPOROS":
        fill(_col("fungus", 0))
        blob = np.vectorize(lambda a, b: _hash(int(a) // 4, int(b) // 2, s + 7))(xx, yy)
        blob2 = np.vectorize(lambda a, b: _hash((int(a) + 2) // 3, (int(b) + 1) // 2, s + 9))(xx, yy)
        base[(blob > 0.55) | (blob2 > 0.8)] = _col("fungus", 1)
        base[(blob > 0.88) & (rnd > 0.4)] = _col("fungus", 2)
        base[rnd > 0.975] = _col("fungus", 2)
        base[rnd > 0.994] = np.array(hex_rgb("#a6d65c"), dtype=np.uint8)
    elif kind == "ESTRADA":
        fill(np.array(hex_rgb("#2a2e39"), dtype=np.uint8))
        base[rnd > 0.88] = np.array(hex_rgb("#383e4b"), dtype=np.uint8)
        base[rnd < 0.04] = _col("dark", 1)
    elif kind == "TERRA":
        fill(_col("rust", 1))
        blob = np.vectorize(lambda a, b: _hash(int(a) // 5, int(b) // 3, s + 3))(xx, yy)
        base[blob > 0.55] = _col("rust", 0)
        base[rnd > 0.9] = _col("rust", 2)
        base[rnd > 0.975] = _col("rust", 3)
    elif kind == "PISO":
        fill(_col("steel", 2))
        tread = ((xx + 2 * yy) % 8 == 0) & ((xx - 2 * yy) % 8 == 4)
        base[tread] = _col("steel", 3)
        edge_tl = (d > 0.90) & (yy < TH / 2)
        edge_br = (d > 0.90) & (yy >= TH / 2)
        base[edge_tl] = _col("steel", 4)
        base[edge_br] = _col("steel", 0)
        for (a, b) in ((40, 6), (68, 20), (40, 33), (12, 20)):
            base[b, a] = _col("dark", 1)
    elif kind == "MANCHA":
        # chão oleoso contínuo (sem forma centralizada, para não repetir a cada célula)
        fill(_col("dark", 2))
        blob = np.vectorize(lambda a, b: _hash(int(a) // 5, int(b) // 3, s + 5))(xx, yy)
        blob2 = np.vectorize(lambda a, b: _hash((int(a) + 3) // 4, (int(b) + 1) // 2, s + 6))(xx, yy)
        base[(blob > 0.6) | (blob2 > 0.82)] = _col("indigo", 1)
        base[(blob < 0.12) & (rnd > 0.5)] = _col("dark", 1)
        base[rnd > 0.985] = _col("indigo", 2)
    elif kind == "VILA":
        # calçamento em placas alinhadas à grade (4x4 por célula), tons alternados
        fill(_col("indigo", 2))
        cell = (np.floor(u * 4) + np.floor(v * 4)) % 2 == 0
        base[cell] = _col("indigo", 3)
        joints = ((u * 4) % 1 < 0.05) | ((v * 4) % 1 < 0.05)
        base[joints] = _col("indigo", 1)
        base[(rnd > 0.95) & ~joints] = _col("slate", 3)
        base[(rnd < 0.03) & ~joints] = _col("indigo", 1)
    elif kind == "PISO_MADEIRA":
        # tábuas ao longo de u, com juntas escalonadas
        fill(_col("wood", 2))
        board = np.floor(v * 6)
        base[(board % 2) == 0] = _col("wood", 3)
        base[(v * 6) % 1 < 0.08] = _col("wood", 0)
        stag = ((u * 3 + board * 0.5) % 1) < 0.03
        base[stag] = _col("wood", 1)
        base[rnd > 0.97] = _col("wood", 1)
    elif kind == "PISO_CONCRETO":
        fill(_col("slate", 2))
        base[rnd > 0.9] = _col("slate", 3)
        base[rnd < 0.04] = _col("slate", 1)
        seam = (u % 1 < 0.025) | (v % 1 < 0.025) | (np.abs(u - 0.5) < 0.012) | (np.abs(v - 0.5) < 0.012)
        base[seam] = _col("slate", 1)
    img[:, :, :3] = base
    img[:, :, 3] = np.where(mask, 255, 0)
    return img


def gen_ground():
    variants = 3
    atlas = np.zeros((TH * variants, TW * len(GROUND_TYPES), 4), dtype=np.uint8)
    for ti, k in enumerate(GROUND_TYPES):
        for v in range(variants):
            atlas[v * TH:(v + 1) * TH, ti * TW:(ti + 1) * TW] = ground_tile(k, v)
    os.makedirs(os.path.join(OUT, "world"), exist_ok=True)
    Image.fromarray(atlas).save(os.path.join(OUT, "world", "ground.png"), optimize=True)
    previews.append(("chão (8 tipos x 3 variações)", atlas))
    return variants


# ---------------------------------------------------------------- catálogo e prévia
def write_catalog(icon_cols, ground_variants):
    L = ["# GERADO por tools/gen_art.py - não edite à mão.",
         "class_name GenCatalog",
         "extends RefCounted",
         "## Folhas de sprites geradas: fw/fh = tamanho do quadro, ox/oy = pixel do quadro onde",
         "## fica o pé / centro da célula (a origem do nó), cols/rows = quadros por linha/linhas.",
         "",
         "const SHEETS := {"]
    for k in sorted(sheets):
        s = sheets[k]
        L.append('\t"%s": {"path": "%s", "fw": %d, "fh": %d, "ox": %d, "oy": %d, "cols": %d, "rows": %d},'
                 % (k, s["path"], s["fw"], s["fh"], s["ox"], s["oy"], s["cols"], s["rows"]))
    L.append("}")
    L.append("")
    L.append("## Quadros por animação (colunas da folha). Linhas = direções (enum Facing).")
    L.append('const SURVIVOR_ANIMS := {"idle": [0, 1], "walk": [2, 3, 4, 5], "attack": [6, 7, 8]}')
    L.append('const INFECTED_ANIMS := {"walk": [0, 1, 2, 3], "attack": [4, 5]}')
    L.append("")
    L.append('const ICONS_PATH := "res://assets/art/generated/ui/icons.png"')
    L.append("const ICON_SIZE := %d" % ICON)
    L.append("const ICON_COLS := %d" % icon_cols)
    L.append("const ICONS := {")
    for i, it in enumerate(ITEMS):
        L.append('\t"%s": %d,' % (it, i))
    L.append("}")
    L.append("")
    L.append('const GROUND_PATH := "res://assets/art/generated/world/ground.png"')
    L.append("const GROUND_VARIANTS := %d" % ground_variants)
    with open(CATALOG, "w", encoding="utf-8") as f:
        f.write("\n".join(L) + "\n")


def save_preview(path):
    scale = 2
    blocks = []
    for label, im in previews:
        blocks.append(im)
    W = max(b.shape[1] for b in blocks) + 20
    H = sum(b.shape[0] + 14 for b in blocks) + 10
    canvas = np.zeros((H, W, 3), dtype=np.uint8)
    canvas[:] = (60, 64, 84)
    y = 10
    for b in blocks:
        a = b[:, :, 3:4] / 255.0
        reg = canvas[y:y + b.shape[0], 10:10 + b.shape[1]]
        canvas[y:y + b.shape[0], 10:10 + b.shape[1]] = (b[:, :, :3] * a + reg * (1 - a)).astype(np.uint8)
        y += b.shape[0] + 14
    Image.fromarray(canvas).resize((W * scale, H * scale), Image.NEAREST).save(path)


def main():
    only = None
    preview = None
    args = sys.argv[1:]
    if "--preview" in args:
        preview = args[args.index("--preview") + 1]
    if "--only" in args:
        only = args[args.index("--only") + 1].split(",")
    if only is None or "characters" in only:
        gen_characters()
    if only is None or "structures" in only:
        gen_structures()
    if only is None or "props" in only:
        gen_props()
    icon_cols = gen_icons() if only is None or "icons" in only else 8
    gv = gen_ground() if only is None or "ground" in only else 3
    if only is None:
        write_catalog(icon_cols, gv)
        print("catálogo:", CATALOG)
    if preview:
        save_preview(preview)
        print("prévia:", preview)
    print("folhas:", len(sheets))


if __name__ == "__main__":
    main()

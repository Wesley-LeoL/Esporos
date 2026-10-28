"""Modelos 3D (primitivas) usados para gerar a arte do Esporos.

Medidas dos personagens em metros (convertidas para células por M); estruturas e objetos
em unidades de célula (1 = aresta de uma célula 80x40). Eixos do modelo: +x frente,
+y esquerda, +z cima.
"""
from art_render import (Part, combine, limb, pat_cross, pat_hazard, pat_noise, pat_planks,
                        pat_seams, rot_x, rot_y, rot_z, scale_parts, transform)

M = 0.48  # células por metro (personagem de ~1,8 m fica com ~42 px de altura)


# ====================================================================== personagens
def survivor(leg=0.0, arm=0.0, bob=0.0, attack=None, mask=True, arm_implant=False,
             eye_implant=False, lying=False):
    """Sobrevivente: casaco longo, capuz, mochila, máscara de gás com filtro."""
    hip = 0.88
    P = []
    cloth = "cloth"
    coat = "rust"
    # pernas e botas (pivô no quadril)
    for side, a in ((1, leg), (-1, -leg)):
        R = rot_x(-10 * side) @ rot_y(a) if lying else rot_y(a)
        piv = (0, 0.10 * side, hip + bob)
        P.append(limb("box", (0.075, 0.075, 0.40), cloth, piv, R, (0, 0, -0.40)))
        P.append(limb("box", (0.12, 0.08, 0.06), "dark", piv, R, (0.04, 0, -0.82)))
    up = []
    up.append(Part("box", (0.11, 0.16, 0.08), cloth, (0, 0, 0.92 + bob)))
    up.append(Part("box", (0.13, 0.18, 0.17), coat, (0, 0, 0.82 + bob),
                   pattern=combine(pat_seams(0.36, (0, 1, 0)), pat_noise(3, 1, 0.06))))
    up.append(Part("box", (0.12, 0.18, 0.25), coat, (0, 0, 1.22 + bob),
                   pattern=combine(pat_seams(0.36, (0, 1, 0)), pat_noise(5, 1, 0.05))))
    up.append(Part("box", (0.132, 0.185, 0.025), "dark", (0, 0, 0.99 + bob)))
    up.append(Part("box", (0.125, 0.03, 0.18), "indigo", (0.005, 0.07, 1.26 + bob)))  # alça
    if not lying:
        up.append(Part("box", (0.08, 0.14, 0.17), "indigo", (-0.20, 0, 1.24 + bob),
                       pattern=pat_seams(0.11, (0, 0, 1))))
        up.append(Part("cyl", (0.06, 0.15), "olive", (-0.20, 0, 1.45 + bob), rot_x(90)))
    up.append(Part("cyl", (0.075, 0.04), cloth, (0, 0, 1.49 + bob)))
    up.append(Part("box", (0.10, 0.09, 0.11), "skin", (0.01, 0, 1.62 + bob)))
    up.append(Part("ell", (0.12, 0.118, 0.135), "indigo", (-0.03, 0, 1.64 + bob)))
    if mask:
        up.append(Part("box", (0.05, 0.088, 0.075), "grey", (0.085, 0, 1.585 + bob)))
        up.append(Part("cyl", (0.048, 0.035), "steel", (0.168, 0, 1.56 + bob), rot_y(90)))
        up.append(Part("box", (0.012, 0.078, 0.022), "glow_teal", (0.112, 0, 1.655 + bob)))
    else:
        for s in (1, -1):
            up.append(Part("box", (0.01, 0.02, 0.012), "dark", (0.112, 0.04 * s, 1.645 + bob)))
        up.append(Part("box", (0.012, 0.035, 0.008), "rust", (0.112, 0, 1.575 + bob)))
    if eye_implant:
        up.append(Part("box", (0.035, 0.014, 0.014), "glow_cyan", (0.06, -0.098, 1.655 + bob)))
    # braços (pivô no ombro). attack = ângulo do braço direito durante o golpe
    for side in (1, -1):
        a = -arm * side if attack is None or side == 1 else attack
        if lying:
            R = rot_x(-62 * side) @ rot_y(a)
        else:
            R = rot_x(-4 * side) @ rot_y(a)
        piv = (0, 0.235 * side, 1.43 + bob)
        metal = arm_implant and side == -1
        up.append(limb("box", (0.06, 0.06, 0.28), "steel" if metal else coat, piv, R, (0, 0, -0.27),
                       pattern=None if metal else (lambda p, n: (-1 + 0 * p[:, 0].astype(int), None, None))))
        up.append(limb("ell", (0.056, 0.056, 0.062), "steel" if metal else "cloth", piv, R, (0, 0, -0.60)))
        if metal:
            up.append(limb("box", (0.064, 0.064, 0.016), "glow_cyan", piv, R, (0, 0, -0.30)))
        if side == -1 and attack is not None:
            up.append(limb("cyl", (0.026, 0.21), "steel", piv, R, (0.0, 0, -0.74)))
    P += up
    P = scale_parts(P, M)
    if lying:
        P = transform(P, rot_y(-90), (0, 0, 0), (0.85 * M, 0, 0.135 * M))
    return P


def blood_pool():
    """Poça sob o cadáver (renderizada sem contorno e composta por baixo do corpo)."""
    return [Part("ell", (0.30, 0.20, 0.006), "blood", (0.02, 0.06, 0.003)),
            Part("ell", (0.16, 0.13, 0.006), "blood", (-0.20, -0.07, 0.003)),
            Part("ell", (0.10, 0.08, 0.006), "blood", (0.25, -0.12, 0.003))]


def infected(leg=0.0, sway=0.0, reach=-70.0, elite=False):
    """Infectado: curvado, roupa rasgada, crescimentos fúngicos e olhos brilhantes.
    O elite é maior, com placas fúngicas rosadas e um braço mecânico."""
    hip = 0.86
    body = "elite_body" if elite else "grey"
    skin = "elite_skin" if elite else "flesh_inf"
    fungus = "fungus_pink" if elite else "fungus"
    eyes = "glow_magenta" if elite else "glow_red"
    P = []
    for side, a in ((1, leg), (-1, -leg)):
        R = rot_y(a)
        piv = (0, 0.10 * side, hip)
        P.append(limb("box", (0.07, 0.072, 0.39), "cloth", piv, R, (0, 0, -0.39),
                      pattern=pat_noise(7 + side, 1, 0.1)))
        P.append(limb("box", (0.10, 0.07, 0.05), skin, piv, R, (0.03, 0, -0.81)))
    up = []
    up.append(Part("box", (0.11, 0.16, 0.08), "cloth", (0, 0, 0.90)))
    up.append(Part("box", (0.12, 0.18, 0.26), body, (0, 0, 1.18),
                   pattern=combine(pat_noise(11, 1, 0.18), pat_seams(0.27, (0, 0, 1)))))
    up.append(Part("box", (0.09, 0.13, 0.04), skin, (0.03, 0, 0.98)))  # barriga exposta (rasgo)
    up.append(Part("cyl", (0.07, 0.04), skin, (0.01, 0, 1.46)))
    up.append(Part("box", (0.10, 0.09, 0.105), skin, (0.03, 0, 1.58),
                   pattern=pat_noise(13, 1, 0.15)))
    for s in (1, -1):
        up.append(Part("box", (0.012, 0.022, 0.012), eyes, (0.13, 0.04 * s, 1.60)))
    up.append(Part("box", (0.012, 0.045, 0.012), "dark", (0.13, 0, 1.53)))
    # crescimentos fúngicos
    big = 1.35 if elite else 1.0
    up.append(Part("ell", (0.09 * big, 0.085 * big, 0.075 * big), fungus, (-0.02, 0.18, 1.44)))
    up.append(Part("ell", (0.085 * big, 0.10 * big, 0.11 * big), fungus, (-0.12, -0.05, 1.28)))
    up.append(Part("ell", (0.06 * big, 0.065 * big, 0.055 * big), fungus, (0.0, 0.06, 1.70)))
    if elite:
        for z, y, x in ((1.40, -0.16, -0.10), (1.20, 0.10, -0.14), (1.52, -0.02, -0.12)):
            up.append(Part("cyl", (0.03, 0.09), "fungus_pink", (x - 0.06, y, z + 0.05), rot_y(-55)))
    else:
        up.append(Part("box", (0.012, 0.012, 0.012), "glow_green", (-0.04, 0.24, 1.49)))
        up.append(Part("box", (0.012, 0.012, 0.012), "glow_green", (-0.17, -0.08, 1.37)))
    for side in (1, -1):
        a = reach + (6 * side * (1 if leg >= 0 else -1))
        R = rot_x(-6 * side) @ rot_y(a)
        piv = (0, 0.23 * side, 1.40)
        metal = elite and side == -1
        up.append(limb("box", (0.055, 0.055, 0.28), "steel" if metal else body, piv, R, (0, 0, -0.27),
                       pattern=None if metal else pat_noise(17 + side, 1, 0.12)))
        up.append(limb("ell", (0.06, 0.06, 0.07), "steel" if metal else skin, piv, R, (0, 0, -0.60)))
        if metal:
            up.append(limb("box", (0.06, 0.06, 0.015), "glow_cyan", piv, R, (0, 0, -0.30)))
            up.append(limb("box", (0.015, 0.03, 0.06), "steel", piv, R, (0.04, 0.03, -0.68)))
    up = transform(up, rot_y(28 if not elite else 18), (0, 0, 0.88))
    P += up
    P = transform(P, rot_x(sway), (0, 0, 0))
    k = M * (1.22 if elite else 1.0)
    return scale_parts(P, k)


# ====================================================================== estruturas (1 célula)
def _cap(h, half=0.47, mat="rust"):
    """Arremate do topo como nos telhados do pacote: borda enferrujada e centro índigo."""
    return [Part("box", (half, half, 0.028), mat, (0, 0, h + 0.028)),
            Part("box", (half - 0.07, half - 0.07, 0.01), "indigo", (0, 0, h + 0.062), bevel=False,
                 pattern=pat_noise(71, 1, 0.05))]


def wall(variant=0):
    h = 0.82
    P = [Part("box", (0.45, 0.45, h / 2), "slate", (0, 0, h / 2),
              pattern=combine(pat_seams(0.3, (1, 1, 0)), pat_seams(0.41, (0, 0, 1)), pat_noise(21 + variant, 1, 0.04)))]
    P += _cap(h)
    if variant == 0:
        P.append(Part("box", (0.02, 0.18, 0.14), "steel", (0.46, -0.12, 0.30), pattern=pat_seams(0.09, (0, 1, 0))))
        P.append(Part("box", (0.20, 0.02, 0.10), "steel", (0.08, 0.46, 0.52)))
    else:
        P.append(Part("box", (0.02, 0.30, 0.04), "rust", (0.46, 0, 0.20)))
        P.append(Part("box", (0.14, 0.02, 0.16), "steel", (-0.18, 0.46, 0.28), pattern=pat_seams(0.08, (1, 0, 0))))
    return P


def door(open_=False):
    h = 0.82
    P = [Part("box", (0.45, 0.45, 0.02), "grey", (0, 0, 0.02))]
    for x, y in ((0.38, 0.38), (-0.38, -0.38), (0.38, -0.38), (-0.38, 0.38)):
        P.append(Part("box", (0.07, 0.07, h / 2), "slate", (x, y, h / 2), pattern=pat_seams(0.27, (0, 0, 1))))
    P.append(Part("box", (0.46, 0.46, 0.06), "slate", (0, 0, h - 0.06)))
    P += _cap(h)
    if not open_:
        P.append(Part("box", (0.32, 0.32, (h - 0.14) / 2), "steel", (0, 0, (h - 0.14) / 2 + 0.04),
                      pattern=combine(pat_seams(0.16, (1, 1, 0)), pat_noise(31, 1, 0.04))))
        P.append(Part("box", (0.33, 0.33, 0.04), "mustard", (0, 0, 0.18), pattern=pat_hazard(0.07)))
        P.append(Part("box", (0.02, 0.05, 0.03), "glow_amber", (0.335, 0.18, 0.42)))
        P.append(Part("box", (0.05, 0.02, 0.03), "glow_amber", (0.18, 0.335, 0.42)))
    else:
        P.append(Part("box", (0.33, 0.33, 0.035), "steel", (0, 0, h - 0.17), pattern=pat_hazard(0.07)))
    return P


def generator(on=True):
    P = [Part("box", (0.36, 0.28, 0.03), "steel", (0, 0, 0.03)),
         Part("box", (0.30, 0.22, 0.17), "mustard", (0, 0, 0.23),
              pattern=combine(pat_seams(0.12, (1, 0, 0)), pat_noise(41, 1, 0.05))),
         Part("box", (0.10, 0.225, 0.06), "dark", (-0.14, 0, 0.18), pattern=pat_planks(0.03, 2)),
         Part("cyl", (0.10, 0.20), "red", (0.06, 0, 0.47), rot_y(90)),
         Part("cyl", (0.03, 0.03), "grey", (0.20, 0, 0.58)),
         Part("cyl", (0.035, 0.16), "grey", (-0.24, -0.14, 0.52)),
         Part("cyl", (0.045, 0.02), "dark", (-0.24, -0.14, 0.69)),
         Part("box", (0.012, 0.04, 0.03), "glow_green" if on else "glow_off", (0.305, 0.12, 0.30)),
         Part("box", (0.012, 0.04, 0.03), "glow_amber" if on else "glow_off", (0.305, 0.02, 0.30))]
    return P


def purifier(on=True):
    glow = "glow_teal" if on else "glow_dim"
    P = [Part("cyl", (0.40, 0.03), "steel", (0, 0, 0.03)),
         Part("cyl", (0.28, 0.30), "slate", (0, 0, 0.36), pattern=pat_seams(0.2, (0, 0, 1))),
         Part("cyl", (0.29, 0.03), glow, (0, 0, 0.42)),
         Part("cyl", (0.24, 0.05), "steel", (0, 0, 0.71)),
         Part("cyl", (0.17, 0.02), "dark", (0, 0, 0.77)),
         Part("box", (0.03, 0.15, 0.015), "grey", (0, 0, 0.79), rot_z(30)),
         Part("box", (0.03, 0.15, 0.015), "grey", (0, 0, 0.79), rot_z(-60)),
         Part("cyl", (0.05, 0.16), "steel", (0.30, 0.16, 0.22), rot_x(0)),
         Part("cyl", (0.04, 0.16), "steel", (0.20, -0.30, 0.18), rot_x(90)),
         Part("box", (0.02, 0.06, 0.04), glow if on else "glow_off", (0.285, -0.05, 0.56))]
    return P


def turret(on=True, aim=0.0):
    head = [Part("box", (0.17, 0.13, 0.09), "rust", (0, 0, 0.60), pattern=pat_seams(0.12, (1, 0, 0))),
            Part("box", (0.10, 0.135, 0.04), "steel", (-0.04, 0, 0.71)),
            Part("cyl", (0.034, 0.20), "grey", (0.33, 0.05, 0.60), rot_y(90)),
            Part("cyl", (0.034, 0.20), "grey", (0.33, -0.05, 0.60), rot_y(90)),
            Part("box", (0.02, 0.035, 0.025), "glow_red" if on else "glow_off", (0.175, 0.0, 0.66))]
    head = transform(head, rot_z(aim), (0, 0, 0))
    return [Part("cyl", (0.30, 0.05), "steel", (0, 0, 0.05), pattern=pat_hazard(0.08)),
            Part("cyl", (0.24, 0.05), "slate", (0, 0, 0.14)),
            Part("cyl", (0.09, 0.20), "grey", (0, 0, 0.38))] + head


def seal(on=True):
    g = "glow_cyan" if on else "glow_off"
    P = [Part("cyl", (0.34, 0.04), "steel", (0, 0, 0.04), pattern=pat_hazard(0.09)),
         Part("box", (0.18, 0.18, 0.08), "slate", (0, 0, 0.16)),
         Part("box", (0.07, 0.07, 0.28), "steel", (0, 0, 0.50), pattern=pat_seams(0.1, (0, 0, 1)))]
    for z in (0.34, 0.50, 0.66):
        P.append(Part("cyl", (0.15, 0.015), g, (0, 0, z)))
    P.append(Part("ell", (0.10, 0.10, 0.08), "steel", (0, 0, 0.84)))
    P.append(Part("ell", (0.05, 0.05, 0.05), g, (0, 0, 0.92)))
    return P


# ====================================================================== objetos
def crate(kind="comum", empty=False):
    lid_rot = rot_y(-110) if empty else rot_y(0)
    if kind == "comum":
        body = [Part("box", (0.20, 0.20, 0.15), "wood", (0, 0, 0.15),
                     pattern=combine(pat_planks(0.075, 2), pat_noise(51, 1, 0.05))),
                Part("box", (0.205, 0.04, 0.155), "rust", (0, 0, 0.15)),
                Part("box", (0.04, 0.205, 0.155), "rust", (0, 0, 0.15))]
        lid = [Part("box", (0.21, 0.21, 0.025), "wood", (0.21, 0, 0.025), pattern=pat_planks(0.08, 0))]
        piv = (-0.21, 0, 0.30)
    elif kind == "medico":
        body = [Part("box", (0.21, 0.15, 0.12), "bone", (0, 0, 0.12),
                     pattern=pat_cross(0.07, 0.022, "#d84050")),
                Part("box", (0.215, 0.155, 0.015), "red", (0, 0, 0.20))]
        lid = [Part("box", (0.21, 0.15, 0.02), "bone", (0.21, 0, 0.02), pattern=pat_cross(0.07, 0.022, "#d84050", 2))]
        piv = (-0.21, 0, 0.24)
    else:
        body = [Part("box", (0.22, 0.15, 0.16), "steel", (0, 0, 0.16), pattern=pat_seams(0.1, (0, 0, 1))),
                Part("box", (0.225, 0.155, 0.025), "mustard", (0, 0, 0.08), pattern=pat_hazard(0.05))]
        lid = [Part("box", (0.22, 0.15, 0.025), "steel", (0.22, 0, 0.025)),
               Part("box", (0.05, 0.02, 0.015), "dark", (0.22, 0, 0.06))]
        piv = (-0.22, 0, 0.32)
    lid = transform(lid, lid_rot, (0, 0, 0), piv)
    if empty:
        body.append(Part("box", (0.17, 0.12 if kind != "comum" else 0.17, 0.01), "dark", (0, 0, body[0].pos[2] + body[0].size[2] + 0.002)))
    return body + lid


def loot_bag():
    return scale_parts([Part("ell", (0.16, 0.13, 0.11), "olive", (0, 0, 0.10), pattern=pat_noise(61, 1, 0.12)),
                        Part("ell", (0.10, 0.09, 0.07), "olive", (0.02, 0.03, 0.20)),
                        Part("cyl", (0.03, 0.03), "rust", (0.02, 0.03, 0.27))], 1.45)


def caravan():
    P = [Part("box", (0.50, 0.26, 0.05), "steel", (0, 0, 0.20)),
         Part("box", (0.17, 0.25, 0.17), "slate", (0.32, 0, 0.42), pattern=pat_seams(0.17, (0, 1, 0))),
         Part("box", (0.012, 0.20, 0.06), "glow_dim", (0.49, 0, 0.48)),
         Part("box", (0.30, 0.25, 0.16), "rust", (-0.16, 0, 0.42), pattern=pat_seams(0.15, (1, 0, 0))),
         Part("ell", (0.30, 0.25, 0.10), "rust", (-0.16, 0, 0.57)),
         Part("box", (0.08, 0.08, 0.07), "wood", (-0.38, 0.12, 0.32)),
         Part("cyl", (0.012, 0.18), "grey", (0.30, -0.18, 0.75)),
         Part("box", (0.015, 0.04, 0.03), "glow_amber", (0.495, 0.18, 0.30)),
         Part("box", (0.015, 0.04, 0.03), "glow_amber", (0.495, -0.18, 0.30))]
    for x in (0.32, -0.30):
        for y in (0.26, -0.26):
            P.append(Part("cyl", (0.13, 0.045), "dark", (x, y, 0.13), rot_x(90)))
            P.append(Part("cyl", (0.06, 0.047), "grey", (x, y, 0.13), rot_x(90)))
    return P


# ====================================================================== ícones de itens
def item_model(item):
    """Modelo pequeno de cada item (para os ícones do inventário). Unidades livres."""
    can = lambda mat, band: [Part("cyl", (0.30, 0.38), mat, (0, 0, 0.38)),
                             Part("cyl", (0.31, 0.12), band, (0, 0, 0.40))]
    bottle = lambda mat, cap: [Part("cyl", (0.24, 0.42), mat, (0, 0, 0.42)),
                               Part("cyl", (0.12, 0.10), mat, (0, 0, 0.92)),
                               Part("cyl", (0.13, 0.07), cap, (0, 0, 1.06))]
    book = lambda col: [Part("box", (0.36, 0.28, 0.10), col, (0, 0, 0.10)),
                        Part("box", (0.34, 0.265, 0.09), "bone", (0.03, 0, 0.10), bevel=False),
                        Part("box", (0.30, 0.03, 0.005), "bone", (0, 0.10, 0.205))]
    m = {
        "feijao": can("steel", "red"),
        "carne_seca": [Part("box", (0.38, 0.26, 0.08), "rust", (0, 0, 0.08), rot_z(10), pattern=pat_noise(3, 1, 0.3)),
                       Part("box", (0.30, 0.20, 0.06), "red", (0.05, 0.02, 0.20), rot_z(-15), pattern=pat_noise(4, 1, 0.3))],
        "barra_cereal": [Part("box", (0.45, 0.16, 0.09), "olive", (0, 0, 0.09), pattern=pat_seams(0.3, (1, 0, 0)))],
        "agua_limpa": bottle("teal", "steel"),
        "agua_suja": bottle("fungus", "rust"),
        "mascara": [Part("ell", (0.32, 0.40, 0.36), "grey", (0, 0, 0.40)),
                    Part("box", (0.04, 0.30, 0.08), "glow_teal", (0.30, 0, 0.55)),
                    Part("cyl", (0.20, 0.16), "steel", (0.38, 0, 0.24), rot_y(90))],
        "filtro": [Part("cyl", (0.34, 0.30), "steel", (0, 0, 0.30), pattern=pat_seams(0.2, (0, 0, 1))),
                   Part("cyl", (0.35, 0.07), "fungus", (0, 0, 0.32)),
                   Part("cyl", (0.14, 0.05), "dark", (0, 0, 0.62))],
        "supressor": [Part("cyl", (0.12, 0.55), "bone", (0, 0, 0.12), rot_y(90)),
                      Part("cyl", (0.13, 0.12), "glow_green", (0.10, 0, 0.12), rot_y(90)),
                      Part("cyl", (0.14, 0.08), "red", (-0.48, 0, 0.12), rot_y(90))],
        "bandagem": [Part("cyl", (0.34, 0.22), "bone", (0, 0, 0.34), rot_x(90)),
                     Part("cyl", (0.12, 0.225), "dark", (0, 0, 0.34), rot_x(90))],
        "antisseptico": bottle("bone", "red"),
        "kit_sutura": [Part("box", (0.40, 0.26, 0.12), "steel", (0, 0, 0.12)),
                       Part("box", (0.30, 0.02, 0.005), "bone", (0, 0.06, 0.245)),
                       Part("box", (0.30, 0.02, 0.005), "bone", (0, -0.06, 0.245))],
        "antibiotico": [Part("cyl", (0.24, 0.34), "mustard", (0, 0, 0.34)),
                        Part("cyl", (0.25, 0.10), "bone", (0, 0, 0.34)),
                        Part("cyl", (0.26, 0.08), "bone", (0, 0, 0.74))],
        "kit_cirurgico": [Part("box", (0.44, 0.32, 0.20), "bone", (0, 0, 0.20), pattern=pat_cross(0.14, 0.045)),
                          Part("box", (0.12, 0.04, 0.04), "dark", (0, 0, 0.44))],
        "bateria": [Part("box", (0.26, 0.38, 0.30), "steel", (0, 0, 0.30)),
                    Part("box", (0.265, 0.385, 0.05), "glow_cyan", (0, 0, 0.36)),
                    Part("cyl", (0.06, 0.05), "grey", (0, 0.20, 0.65)),
                    Part("cyl", (0.06, 0.05), "red", (0, -0.20, 0.65))],
        "combustivel": [Part("box", (0.20, 0.36, 0.42), "red", (0, 0, 0.42), pattern=pat_seams(0.36, (0, 1, 0))),
                        Part("cyl", (0.07, 0.07), "dark", (0, 0.24, 0.90)),
                        Part("box", (0.04, 0.16, 0.04), "dark", (0, -0.08, 0.88))],
        "sucata": [Part("box", (0.30, 0.20, 0.10), "rust", (0, 0, 0.10), rot_z(20), pattern=pat_noise(8, 1, 0.3)),
                   Part("box", (0.22, 0.14, 0.08), "steel", (0.05, 0.05, 0.25), rot_z(-25)),
                   Part("cyl", (0.06, 0.24), "grey", (-0.10, -0.15, 0.22), rot_y(70))],
        "madeira": [Part("box", (0.48, 0.10, 0.06), "wood", (0, -0.13, 0.06)),
                    Part("box", (0.48, 0.10, 0.06), "wood", (0, 0.0, 0.06)),
                    Part("box", (0.48, 0.10, 0.06), "wood", (0, 0.13, 0.06)),
                    Part("box", (0.48, 0.10, 0.06), "wood", (0.03, -0.06, 0.18), rot_z(8)),
                    Part("box", (0.48, 0.10, 0.06), "wood", (0.03, 0.07, 0.18), rot_z(8))],
        "metal": [Part("box", (0.42, 0.30, 0.04), "steel", (0, 0, 0.04)),
                  Part("box", (0.40, 0.28, 0.04), "steel", (0.03, 0.02, 0.12), rot_z(6)),
                  Part("box", (0.38, 0.26, 0.04), "steel", (-0.02, 0.02, 0.20), rot_z(-5))],
        "cano": [Part("cyl", (0.08, 0.55), "grey", (0, 0, 0.10), rot_y(90) @ rot_x(0))],
        "machete": [Part("box", (0.42, 0.015, 0.07), "bone", (0.12, 0, 0.12)),
                    Part("box", (0.16, 0.04, 0.05), "dark", (-0.40, 0, 0.12))],
        "manual_mecanica": book("rust"),
        "manual_metalurgia": book("steel"),
        "manual_carpintaria": book("wood"),
        "manual_cibernetica": book("olive"),
        "manual_medicina": book("red"),
        "manual_engenharia": book("teal"),
        "implante_pulmao": [Part("ell", (0.30, 0.22, 0.36), "steel", (0, 0.18, 0.36)),
                            Part("ell", (0.30, 0.22, 0.36), "steel", (0, -0.18, 0.36)),
                            Part("cyl", (0.06, 0.18), "glow_teal", (0, 0, 0.70))],
        "implante_hud": [Part("box", (0.10, 0.40, 0.12), "steel", (0, 0, 0.12)),
                         Part("box", (0.03, 0.30, 0.06), "glow_cyan", (0.10, 0, 0.14))],
        "implante_braco": [Part("box", (0.12, 0.12, 0.50), "steel", (0, 0, 0.50), rot_y(40), pattern=pat_seams(0.25, (0, 0, 1))),
                           Part("box", (0.13, 0.13, 0.03), "glow_cyan", (0, 0, 0.50), rot_y(40))],
        "mochila_escolar": [Part("box", (0.20, 0.32, 0.40), "teal", (0, 0, 0.40), pattern=pat_seams(0.4, (0, 0, 1))),
                            Part("box", (0.08, 0.26, 0.20), "teal", (0.24, 0, 0.30)),
                            Part("box", (0.03, 0.05, 0.36), "dark", (-0.21, 0.18, 0.44)),
                            Part("box", (0.03, 0.05, 0.36), "dark", (-0.21, -0.18, 0.44))],
        "mochila_trilha": [Part("box", (0.22, 0.32, 0.52), "rust", (0, 0, 0.52), pattern=pat_seams(0.3, (0, 0, 1))),
                           Part("box", (0.10, 0.28, 0.22), "rust", (0.26, 0, 0.36)),
                           Part("cyl", (0.12, 0.30), "olive", (0, 0, 1.12), rot_x(90)),
                           Part("box", (0.03, 0.05, 0.48), "dark", (-0.23, 0.18, 0.56)),
                           Part("box", (0.03, 0.05, 0.48), "dark", (-0.23, -0.18, 0.56))],
        "mochila_militar": [Part("box", (0.24, 0.36, 0.56), "olive", (0, 0, 0.56), pattern=pat_noise(5, 1, 0.25)),
                            Part("box", (0.10, 0.14, 0.20), "olive", (0.28, 0.18, 0.34)),
                            Part("box", (0.10, 0.14, 0.20), "olive", (0.28, -0.18, 0.34)),
                            Part("box", (0.25, 0.37, 0.04), "dark", (0, 0, 0.80)),
                            Part("box", (0.25, 0.37, 0.04), "dark", (0, 0, 0.40))],
        "coldre": [Part("box", (0.10, 0.20, 0.42), "rust", (0, 0, 0.42), rot_y(-12)),
                   Part("box", (0.12, 0.24, 0.05), "dark", (0, 0, 0.86)),
                   Part("box", (0.04, 0.50, 0.04), "dark", (0, 0, 0.90))],
        "fita": [Part("cyl", (0.34, 0.12), "grey", (0, 0, 0.12)),
                 Part("cyl", (0.18, 0.125), "bone", (0, 0, 0.12))],
        "faca": [Part("box", (0.26, 0.012, 0.05), "bone", (0.16, 0, 0.08)),
                 Part("box", (0.14, 0.035, 0.045), "dark", (-0.22, 0, 0.08))],
        "taco": [Part("cyl", (0.09, 0.55), "wood", (0, 0, 0.10), rot_y(90)),
                 Part("cyl", (0.05, 0.12), "dark", (-0.60, 0, 0.10), rot_y(90))],
        "maca": [Part("ell", (0.30, 0.30, 0.28), "red", (0, 0, 0.28)),
                 Part("cyl", (0.03, 0.08), "wood", (0, 0, 0.60)),
                 Part("ell", (0.12, 0.05, 0.03), "fungus", (0.08, 0, 0.62))],
        "abridor": [Part("box", (0.36, 0.05, 0.03), "steel", (0, 0.06, 0.06), rot_z(8)),
                    Part("box", (0.36, 0.05, 0.03), "red", (0, -0.06, 0.06), rot_z(-8)),
                    Part("cyl", (0.10, 0.04), "steel", (0.36, 0, 0.10)),
                    Part("cyl", (0.05, 0.05), "dark", (0.36, 0, 0.16))],
        # ---- fase 4: cibernética neural
        "proc_neural_mk1": [Part("box", (0.30, 0.30, 0.06), "steel", (0, 0, 0.06), pattern=pat_seams(0.15, (1, 1, 0))),
                            Part("box", (0.18, 0.18, 0.04), "dark", (0, 0, 0.14)),
                            Part("box", (0.10, 0.10, 0.02), "glow_cyan", (0, 0, 0.19))],
        "proc_neural_mk2": [Part("box", (0.32, 0.32, 0.06), "dark", (0, 0, 0.06), pattern=pat_seams(0.12, (1, 1, 0))),
                            Part("box", (0.20, 0.20, 0.05), "steel", (0, 0, 0.15)),
                            Part("box", (0.12, 0.12, 0.02), "glow_magenta", (0, 0, 0.21)),
                            Part("box", (0.34, 0.02, 0.02), "glow_magenta", (0, 0.22, 0.12)),
                            Part("box", (0.34, 0.02, 0.02), "glow_magenta", (0, -0.22, 0.12))],
        "implante_pernas": [Part("box", (0.08, 0.08, 0.50), "steel", (0, 0.12, 0.50), pattern=pat_seams(0.2, (0, 0, 1))),
                            Part("box", (0.08, 0.08, 0.50), "steel", (0, -0.12, 0.50), pattern=pat_seams(0.2, (0, 0, 1))),
                            Part("cyl", (0.05, 0.10), "glow_cyan", (0.05, 0.12, 0.55)),
                            Part("cyl", (0.05, 0.10), "glow_cyan", (0.05, -0.12, 0.55))],
        "implante_derme": [Part("box", (0.36, 0.30, 0.03), "grey", (0, 0, 0.04), pattern=pat_seams(0.1, (1, 1, 0))),
                           Part("box", (0.30, 0.24, 0.02), "glow_teal", (0, 0, 0.08), pattern=pat_seams(0.1, (1, 1, 0)))],
        # ---- fase 5: ferramentas, materiais, médicos, armas de fogo
        "chave_fenda": [Part("cyl", (0.03, 0.24), "steel", (0.10, 0, 0.06), rot_y(90)),
                        Part("cyl", (0.07, 0.14), "red", (-0.30, 0, 0.06), rot_y(90))],
        "martelo": [Part("cyl", (0.04, 0.42), "wood", (0, 0, 0.06), rot_y(90)),
                    Part("box", (0.07, 0.20, 0.07), "steel", (0.42, 0, 0.06))],
        "serra": [Part("box", (0.40, 0.01, 0.12), "bone", (0.10, 0, 0.12), pattern=pat_seams(0.05, (1, 0, 0))),
                  Part("box", (0.12, 0.04, 0.12), "red", (-0.36, 0, 0.14))],
        "alicate": [Part("box", (0.30, 0.03, 0.03), "red", (-0.10, 0.05, 0.04), rot_z(10)),
                    Part("box", (0.30, 0.03, 0.03), "red", (-0.10, -0.05, 0.04), rot_z(-10)),
                    Part("box", (0.14, 0.05, 0.04), "steel", (0.26, 0, 0.04))],
        "lanterna": [Part("cyl", (0.09, 0.30), "grey", (0, 0, 0.10), rot_y(90)),
                     Part("cyl", (0.13, 0.08), "grey", (0.34, 0, 0.10), rot_y(90)),
                     Part("cyl", (0.11, 0.02), "glow_amber", (0.43, 0, 0.10), rot_y(90))],
        "pilha": [Part("cyl", (0.10, 0.26), "mustard", (0, 0, 0.26)),
                  Part("cyl", (0.101, 0.10), "dark", (0, 0, 0.12)),
                  Part("cyl", (0.04, 0.03), "steel", (0, 0, 0.55))],
        "pregos": [Part("box", (0.28, 0.20, 0.14), "rust", (0, 0, 0.14)),
                   Part("cyl", (0.015, 0.14), "steel", (0.05, 0.05, 0.40)),
                   Part("cyl", (0.015, 0.14), "steel", (-0.06, 0.02, 0.40)),
                   Part("cyl", (0.04, 0.01), "steel", (0.05, 0.05, 0.55))],
        "fios": [Part("cyl", (0.30, 0.10), "red", (0, 0, 0.10), pattern=pat_seams(0.04, (0, 0, 1))),
                 Part("cyl", (0.12, 0.105), "dark", (0, 0, 0.10))],
        "sucata_eletronica": [Part("box", (0.34, 0.24, 0.03), "fungus", (0, 0, 0.04), pattern=pat_seams(0.08, (1, 1, 0))),
                              Part("box", (0.08, 0.08, 0.05), "dark", (0.08, 0.04, 0.11)),
                              Part("cyl", (0.04, 0.06), "mustard", (-0.12, -0.08, 0.12))],
        "cantil": [Part("ell", (0.30, 0.14, 0.34), "olive", (0, 0, 0.36)),
                   Part("cyl", (0.06, 0.08), "dark", (0, 0, 0.74))],
        "gaze": [Part("box", (0.30, 0.22, 0.10), "bone", (0, 0, 0.10), pattern=pat_cross(0.08, 0.025))],
        "analgesico": [Part("box", (0.30, 0.20, 0.05), "bone", (0, 0, 0.05)),
                       Part("cyl", (0.04, 0.02), "red", (0.10, 0.06, 0.11)),
                       Part("cyl", (0.04, 0.02), "red", (-0.02, 0.06, 0.11)),
                       Part("cyl", (0.04, 0.02), "red", (0.10, -0.06, 0.11))],
        "alcool": bottle("bone", "teal"),
        "pistola": [Part("box", (0.26, 0.05, 0.06), "dark", (0.06, 0, 0.30)),
                    Part("box", (0.06, 0.045, 0.16), "grey", (-0.12, 0, 0.16), rot_y(-12))],
        "espingarda": [Part("cyl", (0.04, 0.48), "dark", (0.20, 0, 0.12), rot_y(90)),
                       Part("box", (0.12, 0.05, 0.06), "grey", (-0.20, 0, 0.12)),
                       Part("box", (0.20, 0.05, 0.08), "wood", (-0.46, 0, 0.10), rot_y(8))],
        "municao_9mm": [Part("box", (0.26, 0.18, 0.12), "olive", (0, 0, 0.12)),
                        Part("cyl", (0.03, 0.06), "mustard", (0.06, 0.04, 0.30)),
                        Part("cyl", (0.03, 0.06), "mustard", (-0.04, 0.04, 0.30))],
        "cartucho_12": [Part("box", (0.26, 0.18, 0.12), "red", (0, 0, 0.12)),
                        Part("cyl", (0.05, 0.10), "red", (0.06, 0.04, 0.34)),
                        Part("cyl", (0.05, 0.03), "mustard", (0.06, 0.04, 0.24))],
        "pao": [Part("ell", (0.46, 0.22, 0.18), "mustard", (0, 0, 0.18), pattern=pat_seams(0.25, (1, 0, 0)))],
    }
    return m[item]

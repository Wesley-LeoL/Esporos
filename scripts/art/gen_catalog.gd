# GERADO por tools/gen_art.py - não edite à mão.
class_name GenCatalog
extends RefCounted
## Folhas de sprites geradas: fw/fh = tamanho do quadro, ox/oy = pixel do quadro onde
## fica o pé / centro da célula (a origem do nó), cols/rows = quadros por linha/linhas.

const SHEETS := {
	"caravan": {"path": "res://assets/art/generated/props/caravan.png", "fw": 62, "fh": 70, "ox": 31, "oy": 56, "cols": 4, "rows": 1},
	"containers": {"path": "res://assets/art/generated/props/containers.png", "fw": 43, "fh": 56, "ox": 25, "oy": 47, "cols": 7, "rows": 1},
	"corpse": {"path": "res://assets/art/generated/characters/corpse.png", "fw": 30, "fh": 31, "ox": 15, "oy": 19, "cols": 2, "rows": 1},
	"elite": {"path": "res://assets/art/generated/characters/elite.png", "fw": 58, "fh": 69, "ox": 29, "oy": 63, "cols": 6, "rows": 8},
	"gerador": {"path": "res://assets/art/generated/structures/gerador.png", "fw": 54, "fh": 59, "ox": 27, "oy": 45, "cols": 2, "rows": 1},
	"infected": {"path": "res://assets/art/generated/characters/infected.png", "fw": 52, "fh": 53, "ox": 26, "oy": 48, "cols": 6, "rows": 8},
	"parede": {"path": "res://assets/art/generated/structures/parede.png", "fw": 78, "fh": 81, "ox": 39, "oy": 62, "cols": 2, "rows": 1},
	"porta": {"path": "res://assets/art/generated/structures/porta.png", "fw": 78, "fh": 81, "ox": 39, "oy": 62, "cols": 2, "rows": 1},
	"purificador": {"path": "res://assets/art/generated/structures/purificador.png", "fw": 53, "fh": 57, "ox": 24, "oy": 45, "cols": 2, "rows": 1},
	"survivor_m0_a0_e0": {"path": "res://assets/art/generated/characters/survivor_m0_a0_e0.png", "fw": 54, "fh": 67, "ox": 27, "oy": 62, "cols": 9, "rows": 8},
	"survivor_m0_a0_e1": {"path": "res://assets/art/generated/characters/survivor_m0_a0_e1.png", "fw": 54, "fh": 67, "ox": 27, "oy": 62, "cols": 9, "rows": 8},
	"survivor_m0_a1_e0": {"path": "res://assets/art/generated/characters/survivor_m0_a1_e0.png", "fw": 54, "fh": 67, "ox": 27, "oy": 62, "cols": 9, "rows": 8},
	"survivor_m0_a1_e1": {"path": "res://assets/art/generated/characters/survivor_m0_a1_e1.png", "fw": 54, "fh": 67, "ox": 27, "oy": 62, "cols": 9, "rows": 8},
	"survivor_m1_a0_e0": {"path": "res://assets/art/generated/characters/survivor_m1_a0_e0.png", "fw": 54, "fh": 67, "ox": 27, "oy": 62, "cols": 9, "rows": 8},
	"survivor_m1_a0_e1": {"path": "res://assets/art/generated/characters/survivor_m1_a0_e1.png", "fw": 54, "fh": 67, "ox": 27, "oy": 62, "cols": 9, "rows": 8},
	"survivor_m1_a1_e0": {"path": "res://assets/art/generated/characters/survivor_m1_a1_e0.png", "fw": 54, "fh": 67, "ox": 27, "oy": 62, "cols": 9, "rows": 8},
	"survivor_m1_a1_e1": {"path": "res://assets/art/generated/characters/survivor_m1_a1_e1.png", "fw": 54, "fh": 67, "ox": 27, "oy": 62, "cols": 9, "rows": 8},
	"torre": {"path": "res://assets/art/generated/structures/torre.png", "fw": 62, "fh": 56, "ox": 31, "oy": 47, "cols": 8, "rows": 2},
	"vedacao": {"path": "res://assets/art/generated/structures/vedacao.png", "fw": 40, "fh": 60, "ox": 20, "oy": 49, "cols": 2, "rows": 1},
}

## Quadros por animação (colunas da folha). Linhas = direções (enum Facing).
const SURVIVOR_ANIMS := {"idle": [0, 1], "walk": [2, 3, 4, 5], "attack": [6, 7, 8]}
const INFECTED_ANIMS := {"walk": [0, 1, 2, 3], "attack": [4, 5]}

const ICONS_PATH := "res://assets/art/generated/ui/icons.png"
const ICON_SIZE := 28
const ICON_COLS := 8
const ICONS := {
	"feijao": 0,
	"carne_seca": 1,
	"barra_cereal": 2,
	"agua_limpa": 3,
	"agua_suja": 4,
	"mascara": 5,
	"filtro": 6,
	"supressor": 7,
	"bandagem": 8,
	"antisseptico": 9,
	"kit_sutura": 10,
	"antibiotico": 11,
	"kit_cirurgico": 12,
	"bateria": 13,
	"combustivel": 14,
	"sucata": 15,
	"madeira": 16,
	"metal": 17,
	"cano": 18,
	"machete": 19,
	"manual_mecanica": 20,
	"manual_logica": 21,
	"manual_medicina": 22,
	"manual_engenharia": 23,
	"implante_pulmao": 24,
	"implante_hud": 25,
	"implante_braco": 26,
	"mochila_escolar": 27,
	"mochila_trilha": 28,
	"mochila_militar": 29,
	"coldre": 30,
	"fita": 31,
	"faca": 32,
	"taco": 33,
	"maca": 34,
	"pao": 35,
	"abridor": 36,
}

const GROUND_PATH := "res://assets/art/generated/world/ground.png"
const GROUND_VARIANTS := 3

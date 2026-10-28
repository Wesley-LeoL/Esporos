class_name DB
extends RefCounted
## Dados estáticos do jogo: habilidades, itens, implantes, construções, receitas e loot.

const SKILLS := {
	"mecanica": "Mecânica",
	"logica": "Matemática/Lógica",
	"medicina": "Medicina",
	"engenharia": "Engenharia/Eletrônica",
}

## Itens. peso em kg, vol em litros. Campos de estado por unidade (ver Items):
##   dur: tem durabilidade (gasto = perda por golpe/uso); validade: segundos até estragar;
##   carga: tem carga/usos (0-100); uso_carga = quanto cada uso consome.
## Mochilas e coldres: cap (litros) e reducao (fração do peso do conteúdo que não pesa).
const ITEMS := {
	"feijao": {"nome": "Lata de feijão", "tipo": "comida", "cal": 380.0, "lata": true, "peso": 0.45, "vol": 0.4, "desc": "Enlatado: não estraga. Abre com abridor, faca ou machete."},
	"carne_seca": {"nome": "Carne seca", "tipo": "comida", "cal": 300.0, "peso": 0.25, "vol": 0.3, "validade": 3600.0, "desc": "Dura bastante, mas estraga."},
	"barra_cereal": {"nome": "Barra de cereal", "tipo": "comida", "cal": 210.0, "peso": 0.05, "vol": 0.1, "desc": "Não estraga."},
	"maca": {"nome": "Maçã", "tipo": "comida", "cal": 120.0, "peso": 0.2, "vol": 0.3, "validade": 900.0, "desc": "Perecível: estraga rápido."},
	"pao": {"nome": "Pão", "tipo": "comida", "cal": 420.0, "peso": 0.4, "vol": 0.8, "validade": 1200.0, "desc": "Perecível."},
	"agua_limpa": {"nome": "Água limpa", "tipo": "bebida", "agua": 45.0, "limpa": true, "peso": 0.55, "vol": 0.6, "desc": "Água segura."},
	"agua_suja": {"nome": "Água contaminada", "tipo": "bebida", "agua": 45.0, "limpa": false, "peso": 0.55, "vol": 0.6, "desc": "Mata a sede, mas acelera a infecção."},
	"mascara": {"nome": "Máscara de gás", "tipo": "mascara", "dur": true, "gasto": 0.0, "peso": 0.8, "vol": 1.5, "desc": "Vista para proteger. A vedação (durabilidade) gasta com golpes na cabeça."},
	"filtro": {"nome": "Filtro de máscara", "tipo": "filtro", "peso": 0.25, "vol": 0.3, "desc": "Troca o filtro da máscara vestida (100%)."},
	"supressor": {"nome": "Supressor químico", "tipo": "supressor", "peso": 0.1, "vol": 0.2, "desc": "-15% de carga e avanço reduzido por 60 s."},
	"bandagem": {"nome": "Bandagem", "tipo": "med", "peso": 0.05, "vol": 0.1, "desc": "Estanca sangramento. Use na aba Corpo."},
	"antisseptico": {"nome": "Antisséptico", "tipo": "med", "carga": true, "uso_carga": 25.0, "peso": 0.3, "vol": 0.3, "desc": "Frasco com 4 usos. Desinfeta ferimentos (aba Corpo)."},
	"kit_sutura": {"nome": "Kit de sutura", "tipo": "med", "peso": 0.2, "vol": 0.3, "desc": "Fecha ferimentos profundos. Aba Corpo."},
	"antibiotico": {"nome": "Antibiótico", "tipo": "med", "peso": 0.05, "vol": 0.1, "desc": "Combate sepse e infecção fúngica. Aba Corpo."},
	"kit_cirurgico": {"nome": "Kit cirúrgico", "tipo": "kit", "peso": 2.0, "vol": 2.0, "desc": "Necessário para instalar implantes."},
	"bateria": {"nome": "Bateria", "tipo": "bateria", "carga": true, "peso": 0.6, "vol": 0.5, "desc": "Recarrega os implantes com a carga que tiver."},
	"combustivel": {"nome": "Galão de combustível", "tipo": "combustivel", "carga": true, "peso": 4.5, "vol": 4.0, "desc": "Abastece geradores com a carga que tiver."},
	"abridor": {"nome": "Abridor de latas", "tipo": "ferramenta", "peso": 0.1, "vol": 0.1, "desc": "Abre enlatados."},
	"fita": {"nome": "Fita adesiva", "tipo": "reparo", "carga": true, "uso_carga": 20.0, "peso": 0.15, "vol": 0.2, "desc": "Conserta armas e a vedação da máscara (+30%). 5 usos."},
	"sucata": {"nome": "Sucata", "tipo": "material", "peso": 1.0, "vol": 0.5, "desc": "Material de construção."},
	"madeira": {"nome": "Madeira", "tipo": "material", "peso": 1.5, "vol": 1.0, "desc": "Material de construção."},
	"metal": {"nome": "Metal", "tipo": "material", "peso": 2.0, "vol": 0.8, "desc": "Material de construção."},
	"faca": {"nome": "Faca", "tipo": "arma", "dano": 6.0, "dur": true, "gasto": 0.8, "peso": 0.3, "vol": 0.4, "desc": "Leve e durável (+6)."},
	"taco": {"nome": "Taco de madeira", "tipo": "arma", "dano": 10.0, "dur": true, "gasto": 2.5, "peso": 1.0, "vol": 2.0, "desc": "Quebra rápido (+10)."},
	"cano": {"nome": "Cano de metal", "tipo": "arma", "dano": 8.0, "dur": true, "gasto": 1.2, "peso": 1.5, "vol": 2.0, "desc": "Resistente (+8)."},
	"machete": {"nome": "Machete", "tipo": "arma", "dano": 16.0, "dur": true, "gasto": 1.0, "peso": 1.0, "vol": 1.5, "desc": "Corta fundo (+16)."},
	"mochila_escolar": {"nome": "Mochila escolar", "tipo": "mochila", "cap": 14.0, "reducao": 0.0, "peso": 0.5, "vol": 3.0, "desc": "Vista nas costas: +14 L."},
	"mochila_trilha": {"nome": "Mochila de trilha", "tipo": "mochila", "cap": 24.0, "reducao": 0.25, "peso": 1.0, "vol": 5.0, "desc": "+24 L; o conteúdo pesa 25% menos."},
	"mochila_militar": {"nome": "Mochila militar", "tipo": "mochila", "cap": 34.0, "reducao": 0.4, "peso": 1.6, "vol": 6.0, "desc": "+34 L; o conteúdo pesa 40% menos."},
	"coldre": {"nome": "Coldre de cinto", "tipo": "coldre", "cap": 2.0, "reducao": 0.0, "peso": 0.3, "vol": 0.6, "desc": "Leva uma arma de até 2 L à mão."},
	"manual_mecanica": {"nome": "Manual de Mecânica", "tipo": "manual", "skill": "mecanica", "xp": 140.0, "peso": 0.5, "vol": 0.8, "desc": "+140 XP de Mecânica."},
	"manual_logica": {"nome": "Manual de Lógica", "tipo": "manual", "skill": "logica", "xp": 140.0, "peso": 0.5, "vol": 0.8, "desc": "+140 XP de Matemática/Lógica."},
	"manual_medicina": {"nome": "Manual de Medicina", "tipo": "manual", "skill": "medicina", "xp": 140.0, "peso": 0.5, "vol": 0.8, "desc": "+140 XP de Medicina."},
	"manual_engenharia": {"nome": "Manual de Eletrônica", "tipo": "manual", "skill": "engenharia", "xp": 140.0, "peso": 0.5, "vol": 0.8, "desc": "+140 XP de Engenharia/Eletrônica."},
	"implante_pulmao": {"nome": "Filtro pulmonar mecânico", "tipo": "implante", "peso": 1.5, "vol": 1.0, "desc": "Implante. Instale na aba Implantes."},
	"implante_hud": {"nome": "HUD de escaneamento", "tipo": "implante", "peso": 0.4, "vol": 0.4, "desc": "Implante. Instale na aba Implantes."},
	"implante_braco": {"nome": "Braço reforçado", "tipo": "implante", "peso": 2.5, "vol": 2.0, "desc": "Implante. Instale na aba Implantes."},
}

const IMPLANT_SLOTS := {"pulmao": "Pulmões", "olho": "Olho (HUD)", "braco_d": "Braço direito"}

const IMPLANTS := {
	"implante_pulmao": {"slot": "pulmao", "membro": "torso", "req": {"medicina": 4, "engenharia": 3}, "dreno": 0.05, "calor": 0.6,
		"efeito": "Reduz em 65% a entrada de esporos."},
	"implante_hud": {"slot": "olho", "membro": "cabeca", "req": {"medicina": 3, "engenharia": 4}, "dreno": 0.03, "calor": 0.4,
		"efeito": "Escaneia infectados, caixas e nível de esporos."},
	"implante_braco": {"slot": "braco_d", "membro": "braco_d", "req": {"medicina": 5, "engenharia": 4}, "dreno": 0.04, "calor": 0.5,
		"efeito": "+14 de dano corpo a corpo."},
}

const BUILDS := {
	"piso": {"nome": "Piso metálico", "custo": {"madeira": 1, "sucata": 1}, "req": {},
		"xp": {"mecanica": 3}, "desc": "Altera o terreno (persistente)."},
	"parede": {"nome": "Parede reforçada", "custo": {"sucata": 2, "madeira": 2}, "req": {},
		"xp": {"mecanica": 6}, "desc": "Bloqueia infectados."},
	"porta": {"nome": "Porta", "custo": {"madeira": 3, "sucata": 2}, "req": {"mecanica": 1},
		"xp": {"mecanica": 10}, "desc": "[E] abre e fecha."},
	"gerador": {"nome": "Gerador a combustão", "custo": {"metal": 6, "sucata": 4}, "req": {"engenharia": 3, "logica": 2},
		"xp": {"engenharia": 25, "logica": 15}, "desc": "Energia num raio de ~10 tiles. Precisa de combustível."},
	"purificador": {"nome": "Purificador industrial", "custo": {"metal": 8, "sucata": 5, "filtro": 1}, "req": {"engenharia": 4, "logica": 3},
		"xp": {"engenharia": 30, "logica": 20}, "desc": "Reduz a carga patogênica de quem fica perto. Precisa de energia."},
	"torre": {"nome": "Torre automatizada", "custo": {"metal": 8, "sucata": 6, "bateria": 1}, "req": {"engenharia": 4, "logica": 4},
		"xp": {"engenharia": 30, "logica": 25}, "desc": "Atira em infectados. Precisa de energia."},
	"bau": {"nome": "Baú", "custo": {"madeira": 3, "sucata": 1}, "req": {},
		"xp": {"mecanica": 4}, "desc": "Guarda itens sem limite de volume. [E] abre."},
	"vedacao": {"nome": "Selagem de ar", "custo": {"metal": 8, "sucata": 4, "madeira": 4}, "req": {"logica": 4, "engenharia": 3},
		"xp": {"logica": 30, "engenharia": 20}, "desc": "Zona sem esporos. Precisa de energia."},
}

const CRAFTS := {
	"filtro": {"nome": "Filtro de máscara", "custo": {"sucata": 2, "metal": 1}, "req": {"mecanica": 2}, "xp": {"mecanica": 14}},
	"bateria": {"nome": "Bateria", "custo": {"metal": 1, "sucata": 2, "combustivel": 1}, "req": {"engenharia": 2}, "xp": {"engenharia": 12, "logica": 5}},
	"supressor": {"nome": "Supressor químico", "custo": {"antisseptico": 1, "sucata": 1}, "req": {"medicina": 3}, "xp": {"medicina": 12}},
}

# Cada entrada: [item, peso, mínimo, máximo]
const LOOT := {
	"comum": [["sucata", 30, 1, 4], ["madeira", 25, 1, 3], ["feijao", 12, 1, 2], ["agua_limpa", 14, 1, 2],
		["agua_suja", 10, 1, 2], ["barra_cereal", 10, 1, 2], ["bandagem", 9, 1, 2], ["metal", 12, 1, 3],
		["filtro", 6, 1, 1], ["supressor", 4, 1, 1], ["combustivel", 5, 1, 1], ["bateria", 4, 1, 1],
		["cano", 3, 1, 1], ["carne_seca", 5, 1, 1], ["maca", 6, 1, 3], ["pao", 4, 1, 1],
		["fita", 4, 1, 1], ["faca", 3, 1, 1], ["abridor", 4, 1, 1], ["taco", 3, 1, 1], ["mochila_escolar", 3, 1, 1], ["coldre", 2, 1, 1]],
	"medico": [["bandagem", 30, 1, 3], ["antisseptico", 25, 1, 2], ["kit_sutura", 15, 1, 1], ["antibiotico", 15, 1, 2],
		["supressor", 12, 1, 2], ["agua_limpa", 8, 1, 2], ["manual_medicina", 4, 1, 1], ["kit_cirurgico", 3, 1, 1]],
	"tecnico": [["metal", 30, 1, 4], ["sucata", 25, 2, 5], ["bateria", 14, 1, 2], ["combustivel", 14, 1, 3],
		["filtro", 12, 1, 2], ["mascara", 5, 1, 1], ["manual_mecanica", 4, 1, 1], ["manual_logica", 4, 1, 1],
		["manual_engenharia", 4, 1, 1], ["implante_pulmao", 1, 1, 1], ["implante_hud", 1, 1, 1],
		["implante_braco", 1, 1, 1], ["machete", 2, 1, 1], ["fita", 8, 1, 1], ["mochila_trilha", 2, 1, 1],
		["mochila_militar", 1, 1, 1], ["coldre", 3, 1, 1]],
}


static func item_name(id: String) -> String:
	if ITEMS.has(id):
		return ITEMS[id]["nome"]
	return id


## Sorteia itens de uma tabela. 'rng' decide quais e quantos (as mesmas chamadas da fase 1,
## para o mapa gerado não mudar); 'state_rng' decide o estado de cada unidade (durabilidade,
## carga, validade a partir do relógio 'clock'). Devolve uma lista de instâncias (ver Items).
static func roll_loot(table: String, rolls: int, rng: RandomNumberGenerator,
		state_rng: RandomNumberGenerator = null, clock: float = -1.0) -> Array:
	var entries: Array = LOOT[table]
	var total := 0.0
	for e in entries:
		total += float(e[1])
	var counts := {}
	for i in rolls:
		var r := rng.randf() * total
		for e in entries:
			r -= float(e[1])
			if r <= 0.0:
				var n := rng.randi_range(int(e[2]), int(e[3]))
				var key: String = e[0]
				counts[key] = int(counts.get(key, 0)) + n
				break
	return Items.from_counts(counts, state_rng if state_rng != null else rng, clock)


static func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for k in cost:
		parts.append("%dx %s" % [int(cost[k]), item_name(k)])
	return ", ".join(parts)


static func req_text(req: Dictionary) -> String:
	if req.is_empty():
		return "nenhum"
	var parts: Array[String] = []
	for k in req:
		parts.append("%s %d" % [SKILLS[k], int(req[k])])
	return ", ".join(parts)

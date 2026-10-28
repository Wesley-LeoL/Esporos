class_name DB
extends RefCounted
## Dados estáticos do jogo: habilidades, itens, implantes, construções, receitas e loot.

## As 12 habilidades do GDD (evoluem pelo uso, de 0 a 10), por grupo.
const SKILLS := {
	"combate": "Luta corpo a corpo",
	"pontaria": "Pontaria",
	"atletismo": "Atletismo",
	"furtividade": "Furtividade",
	"mecanica": "Mecânica",
	"eletronica": "Eletrônica",
	"carpintaria": "Carpintaria",
	"metalurgia": "Metalurgia",
	"medicina": "Medicina",
	"cibernetica": "Cibernética",
	"agricultura": "Agricultura",
	"culinaria": "Culinária",
}
const SKILL_GROUPS := [
	["Combate e físico", ["combate", "pontaria", "atletismo", "furtividade"]],
	["Técnica e ofício", ["mecanica", "eletronica", "carpintaria", "metalurgia"]],
	["Suporte e ciência", ["medicina", "cibernetica", "agricultura", "culinaria"]],
]
const SKILL_DESC := {
	"combate": "Dano, estamina e desgaste das armas brancas.",
	"pontaria": "Dispersão, recarga e ruído das armas de fogo.",
	"atletismo": "Fôlego, velocidade e peso que você aguenta.",
	"furtividade": "Barulho dos passos e quanto os infectados demoram a te notar.",
	"mecanica": "Consertos, veículos e ligação direta.",
	"eletronica": "Geradores, torres, purificadores e baterias.",
	"carpintaria": "Paredes, portas, pisos e baús.",
	"metalurgia": "Estruturas de metal, filtros e blindagens.",
	"medicina": "Bandagens, suturas e cirurgias.",
	"cibernetica": "Instalar e manter implantes; menos estresse neural.",
	"agricultura": "Plantar e colher.",
	"culinaria": "Cozinhar com menos risco e mais nutrientes.",
}

# ---------------------------------------------------------------- criação de personagem
## Pontos para gastar. Atributos vão de 2 a 9 (base 5, 2 pontos cada passo); habilidades
## iniciais até o nível 3 (custam 2, 3 e 4 pontos); traços custam ou devolvem pontos.
const CREATION_POINTS := 20
const ATTRS := {"forca": "Força", "resist": "Resistência"}
const ATTR_DESC := {"forca": "Peso que você carrega e dano corpo a corpo.",
	"resist": "Estamina máxima e recuperação."}
const ATTR_MIN := 2
const ATTR_MAX := 9
const SKILL_START_MAX := 3
const TRAITS := {
	"pulmao_aco": {"nome": "Pulmões de aço", "custo": 4, "desc": "-25% de esporos inalados."},
	"imune_forte": {"nome": "Imunidade forte", "custo": 5, "desc": "A carga patogênica sobe 15% mais devagar."},
	"metabolismo_lento": {"nome": "Metabolismo lento", "custo": 3, "desc": "Fome e sede 25% mais lentas."},
	"atleta": {"nome": "Atleta", "custo": 3, "desc": "+20% de estamina máxima."},
	"organizado": {"nome": "Organizado", "custo": 2, "desc": "+2 L nos bolsos."},
	"maos_firmes": {"nome": "Mãos firmes", "custo": 3, "desc": "Suturas e cirurgias falham menos."},
	"pulmao_fraco": {"nome": "Pulmão fraco", "custo": -4, "desc": "+25% de esporos inalados."},
	"glutao": {"nome": "Glutão", "custo": -3, "desc": "Fome 30% mais rápida."},
	"asmatico": {"nome": "Asmático", "custo": -3, "desc": "Gasta estamina 30% mais rápido."},
	"sangue_fino": {"nome": "Sangue fino", "custo": -3, "desc": "Sangramentos 30% mais fortes."},
	"desajeitado": {"nome": "Desajeitado", "custo": -2, "desc": "Armas gastam 25% mais rápido."},
	"lento": {"nome": "Lento", "custo": -4, "desc": "-8% de velocidade."},
	"barulhento": {"nome": "Barulhento", "custo": -2, "desc": "Seus passos fazem mais barulho."},
}
## Culturas: semente, tempo para amadurecer regada (s) e colheita [mín, máx].
const CROPS := {
	"batata": {"semente": "semente_batata", "tempo": 300.0, "colheita": [2, 4]},
	"milho": {"semente": "semente_milho", "tempo": 360.0, "colheita": [2, 3]},
	"tomate": {"semente": "semente_tomate", "tempo": 240.0, "colheita": [2, 4]},
}

## Veículos (fase 8): velocidade (x a pé), lugares, porta-malas (L), energia
## ("combustivel" = galões, "bateria" = baterias), gasto por 100 px, ruído e dano ao atropelar.
const VEHICLES := {
	"picape": {"nome": "Picape blindada", "vel": 2.4, "lugares": 4, "porta_malas": 60.0, "energia": "combustivel",
		"gasto": 0.18, "ruido": 520.0, "atropelo": 30.0},
	"moto": {"nome": "Moto elétrica", "vel": 3.2, "lugares": 1, "porta_malas": 8.0, "energia": "bateria",
		"gasto": 0.12, "ruido": 240.0, "atropelo": 12.0},
}

## Pares que não combinam.
const TRAIT_CONFLICTS := [["pulmao_aco", "pulmao_fraco"], ["metabolismo_lento", "glutao"], ["atleta", "asmatico"]]
## Traços negativos devolvem no máximo isto.
const TRAIT_REFUND_MAX := 10
const PRESETS := {
	"Equilibrado": {"forca": 6, "resist": 6, "skills": {"combate": 1, "carpintaria": 2, "medicina": 2}, "traits": ["organizado"]},
	"Médica de campo": {"forca": 4, "resist": 5, "skills": {"medicina": 3, "cibernetica": 2}, "traits": ["maos_firmes", "glutao"]},
	"Engenheiro": {"forca": 5, "resist": 4, "skills": {"eletronica": 3, "metalurgia": 2, "carpintaria": 1}, "traits": ["desajeitado"]},
	"Batedora": {"forca": 6, "resist": 6, "skills": {"atletismo": 2, "furtividade": 2, "combate": 1}, "traits": ["atleta", "barulhento"]},
	"Brutamontes": {"forca": 8, "resist": 6, "skills": {"combate": 3}, "traits": ["lento"]},
}


static func skill_cost(lv: int) -> int:
	var c := 0
	for i in lv:
		c += 2 + i
	return c


static func attr_cost(v: int) -> int:
	return (v - 5) * 2


## Pontos gastos por uma ficha de criação (negativo = sobra).
static func creation_cost(spec: Dictionary) -> int:
	var c := 0
	for a in ATTRS:
		c += attr_cost(int(spec.get(a, 5)))
	var sk: Dictionary = spec.get("skills", {})
	for k in sk:
		c += skill_cost(int(sk[k]))
	var refund := 0
	for t in spec.get("traits", []):
		var tc := int(TRAITS[t]["custo"])
		if tc < 0:
			refund += -tc
		else:
			c += tc
	return c - mini(refund, TRAIT_REFUND_MAX)


## Valida a ficha recebida de um jogador. Vazio = ok; senão, o motivo.
static func creation_error(spec: Dictionary) -> String:
	for a in ATTRS:
		var v := int(spec.get(a, 5))
		if v < ATTR_MIN or v > ATTR_MAX:
			return "Atributo fora do limite."
	var sk: Variant = spec.get("skills", {})
	if not sk is Dictionary:
		return "Ficha inválida."
	for k in sk:
		if not SKILLS.has(k) or int(sk[k]) < 0 or int(sk[k]) > SKILL_START_MAX:
			return "Habilidade inválida."
	var tr: Variant = spec.get("traits", [])
	if not tr is Array:
		return "Ficha inválida."
	for t in tr:
		if not TRAITS.has(t):
			return "Traço inválido."
	for pair in TRAIT_CONFLICTS:
		if pair[0] in tr and pair[1] in tr:
			return "%s e %s não combinam." % [TRAITS[pair[0]]["nome"], TRAITS[pair[1]]["nome"]]
	if creation_cost(spec) > CREATION_POINTS:
		return "Pontos insuficientes."
	return ""

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
	"batata": {"nome": "Batata", "tipo": "comida", "cal": 160.0, "peso": 0.2, "vol": 0.25, "validade": 2400.0, "desc": "Colhida no canteiro. Melhor cozida."},
	"milho": {"nome": "Espiga de milho", "tipo": "comida", "cal": 120.0, "peso": 0.25, "vol": 0.3, "validade": 1800.0, "desc": "Colhida no canteiro. Asse no fogareiro."},
	"tomate": {"nome": "Tomate", "tipo": "comida", "cal": 60.0, "agua": 6.0, "peso": 0.15, "vol": 0.2, "validade": 900.0, "desc": "Mata um pouco a sede."},
	"sopa": {"nome": "Sopa de batata", "tipo": "comida", "cal": 600.0, "cozido": true, "peso": 0.5, "vol": 0.6, "validade": 900.0, "desc": "Comida quente: estamina recupera mais rápido por 3 min."},
	"ensopado": {"nome": "Ensopado", "tipo": "comida", "cal": 780.0, "cozido": true, "peso": 0.6, "vol": 0.6, "validade": 1200.0, "desc": "Comida quente: estamina recupera mais rápido por 3 min."},
	"milho_assado": {"nome": "Milho assado", "tipo": "comida", "cal": 300.0, "cozido": true, "peso": 0.25, "vol": 0.3, "validade": 1500.0, "desc": "Comida quente: estamina recupera mais rápido por 3 min."},
	"semente_batata": {"nome": "Sementes de batata", "tipo": "semente", "cultura": "batata", "peso": 0.02, "vol": 0.05, "desc": "Plante num canteiro (precisa de enxada)."},
	"semente_milho": {"nome": "Sementes de milho", "tipo": "semente", "cultura": "milho", "peso": 0.02, "vol": 0.05, "desc": "Plante num canteiro (precisa de enxada)."},
	"semente_tomate": {"nome": "Sementes de tomate", "tipo": "semente", "cultura": "tomate", "peso": 0.02, "vol": 0.05, "desc": "Plante num canteiro (precisa de enxada)."},
	"enxada": {"nome": "Enxada", "tipo": "ferramenta", "peso": 1.2, "vol": 2.0, "desc": "Ferramenta: preparar o canteiro e plantar."},
	"regador": {"nome": "Regador", "tipo": "regador", "carga": true, "uso_carga": 25.0, "peso": 0.6, "vol": 1.5, "desc": "4 regas. Enche com uma garrafa de água (limpa ou suja)."},
	"panela": {"nome": "Panela", "tipo": "ferramenta", "peso": 0.9, "vol": 1.5, "desc": "Ferramenta: cozinhar no fogareiro."},
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
	"chave_fenda": {"nome": "Chave de fenda", "tipo": "ferramenta", "peso": 0.15, "vol": 0.2, "desc": "Ferramenta: eletrônica (geradores, torres, baterias)."},
	"martelo": {"nome": "Martelo", "tipo": "arma", "dano": 9.0, "dur": true, "gasto": 0.8, "peso": 0.8, "vol": 0.8, "desc": "Ferramenta de carpintaria e arma (+9)."},
	"serra": {"nome": "Serra", "tipo": "ferramenta", "peso": 0.7, "vol": 1.5, "desc": "Ferramenta: corta metal e madeira (torres, selagem)."},
	"alicate": {"nome": "Alicate", "tipo": "ferramenta", "peso": 0.3, "vol": 0.3, "desc": "Ferramenta: fios e filtros."},
	"lanterna": {"nome": "Lanterna", "tipo": "lanterna", "carga": true, "peso": 0.4, "vol": 0.5, "desc": "Ilumina, mas os infectados te veem de mais longe. Gasta pilhas."},
	"pilha": {"nome": "Pilha", "tipo": "pilha", "peso": 0.03, "vol": 0.03, "desc": "Recarrega uma lanterna."},
	"pregos": {"nome": "Prego", "tipo": "material", "peso": 0.01, "vol": 0.01, "desc": "Material de carpintaria."},
	"fios": {"nome": "Fio elétrico", "tipo": "material", "peso": 0.1, "vol": 0.2, "desc": "Material de eletrônica."},
	"sucata_eletronica": {"nome": "Sucata eletrônica", "tipo": "material", "peso": 0.3, "vol": 0.3, "desc": "Placas e componentes."},
	"cantil": {"nome": "Cantil", "tipo": "cantil", "carga": true, "uso_carga": 34.0, "peso": 0.9, "vol": 1.0, "desc": "3 goles de água limpa. Enche com garrafas de água limpa."},
	"gaze": {"nome": "Gaze esterilizada", "tipo": "med", "peso": 0.03, "vol": 0.1, "desc": "Serve como bandagem. Aba Corpo."},
	"alcool": {"nome": "Álcool 70%", "tipo": "med", "carga": true, "uso_carga": 20.0, "peso": 0.4, "vol": 0.5, "desc": "Desinfeta ferimentos (5 usos). Aba Corpo."},
	"analgesico": {"nome": "Analgésico", "tipo": "analgesico", "peso": 0.02, "vol": 0.05, "desc": "Por 2 min, membros feridos não te deixam lento nem fraco."},
	"pistola": {"nome": "Pistola 9 mm", "tipo": "arma_fogo", "dano": 30.0, "dur": true, "gasto": 0.3, "municao": "municao_9mm", "pente": 12,
		"alcance": 430.0, "dispersao": 0.09, "chumbos": 1, "ruido": 900.0, "cadencia": 0.35, "peso": 0.9, "vol": 0.8,
		"desc": "Pente de 12. Barulhenta: atrai infectados de longe."},
	"espingarda": {"nome": "Espingarda calibre 12", "tipo": "arma_fogo", "dano": 16.0, "dur": true, "gasto": 0.6, "municao": "cartucho_12", "pente": 2,
		"alcance": 260.0, "dispersao": 0.26, "chumbos": 6, "ruido": 1300.0, "cadencia": 0.7, "peso": 3.2, "vol": 4.5,
		"desc": "2 cartuchos, 6 chumbos por tiro. Muito barulhenta."},
	"municao_9mm": {"nome": "Munição 9 mm", "tipo": "municao", "peso": 0.012, "vol": 0.01, "desc": "Para a pistola. [R] recarrega."},
	"cartucho_12": {"nome": "Cartucho calibre 12", "tipo": "municao", "peso": 0.04, "vol": 0.03, "desc": "Para a espingarda. [R] recarrega."},
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
	"manual_metalurgia": {"nome": "Manual de Metalurgia", "tipo": "manual", "skill": "metalurgia", "xp": 140.0, "peso": 0.5, "vol": 0.8, "desc": "+140 XP de Metalurgia."},
	"manual_medicina": {"nome": "Manual de Medicina", "tipo": "manual", "skill": "medicina", "xp": 140.0, "peso": 0.5, "vol": 0.8, "desc": "+140 XP de Medicina."},
	"manual_engenharia": {"nome": "Manual de Eletrônica", "tipo": "manual", "skill": "eletronica", "xp": 140.0, "peso": 0.5, "vol": 0.8, "desc": "+140 XP de Eletrônica."},
	"manual_carpintaria": {"nome": "Manual de Carpintaria", "tipo": "manual", "skill": "carpintaria", "xp": 140.0, "peso": 0.5, "vol": 0.8, "desc": "+140 XP de Carpintaria."},
	"manual_cibernetica": {"nome": "Manual de Cibernética", "tipo": "manual", "skill": "cibernetica", "xp": 140.0, "peso": 0.5, "vol": 0.8, "desc": "+140 XP de Cibernética."},
	"implante_pulmao": {"nome": "Filtro pulmonar mecânico", "tipo": "implante", "peso": 1.5, "vol": 1.0, "desc": "Implante. Instale na aba Implantes."},
	"implante_hud": {"nome": "HUD de escaneamento", "tipo": "implante", "peso": 0.4, "vol": 0.4, "desc": "Implante. Instale na aba Implantes."},
	"proc_neural_mk1": {"nome": "Processador neural Mk1", "tipo": "implante", "peso": 0.3, "vol": 0.2, "desc": "Implante cerebral: até 2 implantes gerais."},
	"proc_neural_mk2": {"nome": "Processador neural Mk2", "tipo": "implante", "peso": 0.3, "vol": 0.2, "desc": "Implante cerebral: até 4 implantes gerais."},
	"implante_pernas": {"nome": "Pernas hidráulicas", "tipo": "implante", "peso": 3.0, "vol": 2.5, "desc": "Implante. Instale na aba Implantes."},
	"implante_derme": {"nome": "Malha subdérmica", "tipo": "implante", "peso": 1.0, "vol": 0.8, "desc": "Implante. Instale na aba Implantes."},
	"implante_braco": {"nome": "Braço reforçado", "tipo": "implante", "peso": 2.5, "vol": 2.0, "desc": "Implante. Instale na aba Implantes."},
}

## Encaixes de implantes. O cérebro recebe o processador neural, que não conta como
## implante geral: sem processador o corpo aguenta só 1 implante geral (GDD, seção 4).
const IMPLANT_SLOTS := {"cerebro": "Cérebro (processador neural)", "pulmao": "Pulmões", "olho": "Olho (HUD)",
	"braco_d": "Braço direito", "pernas": "Pernas", "pele": "Pele"}
const NEURAL_BASE := 1

## neuro: estresse sináptico que o implante gera; slots: limite de implantes gerais (processadores).
const IMPLANTS := {
	"proc_neural_mk1": {"slot": "cerebro", "membro": "cabeca", "req": {"medicina": 4, "cibernetica": 4}, "dreno": 0.03, "calor": 0.3,
		"neuro": 0.0, "slots": 2, "efeito": "Suporta até 2 implantes gerais e reduz o estresse sináptico."},
	"proc_neural_mk2": {"slot": "cerebro", "membro": "cabeca", "req": {"medicina": 5, "cibernetica": 6}, "dreno": 0.05, "calor": 0.4,
		"neuro": 0.0, "slots": 4, "efeito": "Suporta até 4 implantes gerais e reduz o estresse sináptico."},
	"implante_pulmao": {"slot": "pulmao", "membro": "torso", "req": {"medicina": 4, "cibernetica": 3}, "dreno": 0.05, "calor": 0.6,
		"neuro": 12.0, "efeito": "Reduz em 65% a entrada de esporos."},
	"implante_hud": {"slot": "olho", "membro": "cabeca", "req": {"medicina": 3, "cibernetica": 4}, "dreno": 0.03, "calor": 0.4,
		"neuro": 10.0, "efeito": "Escaneia infectados, caixas e nível de esporos."},
	"implante_braco": {"slot": "braco_d", "membro": "braco_d", "req": {"medicina": 5, "cibernetica": 4}, "dreno": 0.04, "calor": 0.5,
		"neuro": 16.0, "efeito": "+14 de dano corpo a corpo."},
	"implante_pernas": {"slot": "pernas", "membro": "perna_d", "req": {"medicina": 4, "cibernetica": 3}, "dreno": 0.04, "calor": 0.5,
		"neuro": 14.0, "efeito": "+12% de velocidade; correr gasta 30% menos estamina."},
	"implante_derme": {"slot": "pele", "membro": "torso", "req": {"medicina": 3, "cibernetica": 3}, "dreno": 0.03, "calor": 0.4,
		"neuro": 10.0, "efeito": "Malha subdérmica: recebe 25% menos dano."},
}

## Construções em 3 abas (BUILD_TABS). tipo: "piso" (troca o chão da célula), "parede" (fica numa
## BORDA da célula, estilo The Sims; "porta" abre e fecha), "objeto" (ocupa a célula) ou
## "bau" (baú). ferramentas: precisam estar no inventário (não são gastas).
## Energia: gera (W) e consome (W); bateria_casa guarda até "capacidade" (W·s).
const BUILD_TABS := [["fundacao", "Fundação"], ["utilidades", "Utilidades"], ["decoracao", "Decoração"]]
const BUILDS := {
	# ---- fundação
	"piso_metal": {"nome": "Piso metálico", "aba": "fundacao", "tipo": "piso", "chao": 5, "custo": {"metal": 1, "sucata": 1}, "req": {},
		"ferramentas": [], "xp": {"metalurgia": 2}, "desc": "Chão de chapa de metal."},
	"piso_madeira": {"nome": "Piso de madeira", "aba": "fundacao", "tipo": "piso", "chao": 8, "custo": {"madeira": 1, "pregos": 2}, "req": {},
		"ferramentas": ["martelo"], "xp": {"carpintaria": 2}, "desc": "Assoalho de tábuas."},
	"piso_concreto": {"nome": "Piso de concreto", "aba": "fundacao", "tipo": "piso", "chao": 9, "custo": {"sucata": 2}, "req": {},
		"ferramentas": [], "xp": {"metalurgia": 1}, "desc": "Placas de concreto reaproveitado."},
	"parede_madeira": {"nome": "Parede de madeira", "aba": "fundacao", "tipo": "parede", "custo": {"madeira": 2, "pregos": 4}, "req": {},
		"ferramentas": ["martelo"], "xp": {"carpintaria": 5}, "desc": "Parede na borda do piso. Bloqueia a passagem."},
	"parede_metal": {"nome": "Parede de metal", "aba": "fundacao", "tipo": "parede", "custo": {"metal": 2, "sucata": 2}, "req": {"metalurgia": 1},
		"ferramentas": ["martelo", "serra"], "xp": {"metalurgia": 6}, "desc": "Parede reforçada na borda do piso."},
	"meia_parede": {"nome": "Meia parede", "aba": "fundacao", "tipo": "parede", "custo": {"sucata": 2}, "req": {},
		"ferramentas": [], "xp": {"carpintaria": 2}, "desc": "Mureta baixa: bloqueia a passagem sem fechar a vista."},
	"janela": {"nome": "Parede com janela", "aba": "fundacao", "tipo": "parede", "custo": {"madeira": 2, "pregos": 4, "sucata": 1}, "req": {"carpintaria": 1},
		"ferramentas": ["martelo"], "xp": {"carpintaria": 6}, "desc": "Parede de madeira com janela."},
	"porta": {"nome": "Porta", "aba": "fundacao", "tipo": "porta", "custo": {"madeira": 3, "pregos": 6}, "req": {"carpintaria": 1},
		"ferramentas": ["martelo"], "xp": {"carpintaria": 8}, "desc": "Porta na borda do piso. [E] abre e fecha."},
	"portao": {"nome": "Portão de metal", "aba": "fundacao", "tipo": "porta", "custo": {"metal": 3, "sucata": 2}, "req": {"metalurgia": 2},
		"ferramentas": ["martelo", "serra"], "xp": {"metalurgia": 8}, "desc": "Portão reforçado. [E] abre e fecha."},
	# ---- utilidades
	"bancada": {"nome": "Bancada de fabricação", "aba": "utilidades", "tipo": "objeto", "custo": {"madeira": 4, "pregos": 6, "metal": 1}, "req": {},
		"ferramentas": ["martelo"], "xp": {"carpintaria": 6}, "desc": "Receitas técnicas (filtros, baterias, munição) exigem estar perto dela."},
	"mesa_reparo": {"nome": "Mesa de reparos", "aba": "utilidades", "tipo": "objeto", "custo": {"metal": 3, "sucata": 3, "madeira": 2},
		"req": {"mecanica": 1}, "ferramentas": ["martelo", "chave_fenda"], "xp": {"mecanica": 8},
		"desc": "Conserto reforçado (+45%). Armas de fogo (fita + sucata), mochilas e coldres só se consertam aqui."},
	"fogareiro": {"nome": "Fogareiro", "aba": "utilidades", "tipo": "objeto", "custo": {"metal": 2, "sucata": 3}, "req": {}, "ferramentas": ["martelo"],
		"xp": {"metalurgia": 4}, "desc": "Cozinhe por perto (aba Inventário, com panela)."},
	"gerador": {"nome": "Gerador a combustão", "aba": "utilidades", "tipo": "objeto", "gera": 100.0, "custo": {"metal": 6, "sucata": 4, "fios": 2},
		"req": {"eletronica": 3, "metalurgia": 2}, "ferramentas": ["chave_fenda", "alicate"], "xp": {"eletronica": 25, "metalurgia": 15},
		"desc": "100 W enquanto tiver combustível. Só queima o que a rede precisa."},
	"eolico": {"nome": "Gerador eólico", "aba": "utilidades", "tipo": "objeto", "gera": 22.0, "custo": {"metal": 4, "sucata": 3, "fios": 2},
		"req": {"eletronica": 2, "metalurgia": 2}, "ferramentas": ["chave_fenda", "alicate", "serra"], "xp": {"eletronica": 18, "metalurgia": 12},
		"desc": "Até 22 W por módulo do mastro (1 a 5), conforme o vento; prédios por perto atrapalham. [E] sobe um módulo."},
	"bateria_casa": {"nome": "Banco de baterias", "aba": "utilidades", "tipo": "objeto", "capacidade": 30000.0,
		"custo": {"bateria": 2, "metal": 2, "fios": 2}, "req": {"eletronica": 3}, "ferramentas": ["chave_fenda"], "xp": {"eletronica": 15},
		"desc": "Guarda a energia que sobra e a devolve quando falta."},
	"purificador": {"nome": "Purificador industrial", "aba": "utilidades", "tipo": "objeto", "consome": 40.0,
		"custo": {"metal": 8, "sucata": 5, "filtro": 1, "fios": 2, "sucata_eletronica": 1},
		"req": {"eletronica": 4, "metalurgia": 2}, "ferramentas": ["chave_fenda", "alicate"], "xp": {"eletronica": 30, "metalurgia": 15},
		"desc": "Reduz a carga patogênica de quem fica perto. Consome 40 W."},
	"torre": {"nome": "Torre automatizada", "aba": "utilidades", "tipo": "objeto", "consome": 25.0,
		"custo": {"metal": 8, "sucata": 6, "bateria": 1, "fios": 2, "sucata_eletronica": 2},
		"req": {"eletronica": 4, "metalurgia": 3}, "ferramentas": ["chave_fenda", "alicate", "serra"], "xp": {"eletronica": 30, "metalurgia": 20},
		"desc": "Atira em infectados (barulhenta). Consome 25 W."},
	"vedacao": {"nome": "Selagem de ar", "aba": "utilidades", "tipo": "objeto", "consome": 60.0, "custo": {"metal": 8, "sucata": 4, "madeira": 4, "fios": 2},
		"req": {"metalurgia": 4, "eletronica": 3, "carpintaria": 2}, "ferramentas": ["martelo", "serra", "chave_fenda"],
		"xp": {"metalurgia": 30, "eletronica": 20}, "desc": "Zona sem esporos. Consome 60 W."},
	"coletor": {"nome": "Coletor de chuva", "aba": "utilidades", "tipo": "objeto", "custo": {"metal": 2, "sucata": 2}, "req": {},
		"ferramentas": ["martelo"], "xp": {"metalurgia": 3}, "desc": "Junta água da chuva (contaminada: ferva antes). [E] recolhe."},
	"canteiro": {"nome": "Canteiro", "aba": "utilidades", "tipo": "objeto", "custo": {"madeira": 3, "pregos": 4}, "req": {}, "ferramentas": ["martelo"],
		"xp": {"carpintaria": 3, "agricultura": 3}, "desc": "Plante, regue e colha. A chuva rega sozinha."},
	"bau": {"nome": "Baú", "aba": "utilidades", "tipo": "bau", "custo": {"madeira": 3, "pregos": 4}, "req": {}, "ferramentas": ["martelo"],
		"xp": {"carpintaria": 4}, "desc": "Guarda itens sem limite de volume. [E] abre."},
	"cama": {"nome": "Cama", "aba": "utilidades", "tipo": "objeto", "custo": {"madeira": 4, "pregos": 6}, "req": {}, "ferramentas": ["martelo"],
		"xp": {"carpintaria": 5}, "desc": "[E] descansa (recupera estamina). Sobreviventes novos acordam numa cama da equipe."},
	# ---- decoração (as luzes consomem energia à noite)
	"luminaria": {"nome": "Luminária de chão", "aba": "decoracao", "tipo": "objeto", "consome": 6.0, "luz": [Color(1.0, 0.82, 0.55), 1.3],
		"custo": {"sucata": 1, "fios": 1}, "req": {"eletronica": 1}, "ferramentas": ["chave_fenda"], "xp": {"eletronica": 3},
		"desc": "Luz quente à noite. Consome 6 W."},
	"poste": {"nome": "Poste de luz", "aba": "decoracao", "tipo": "objeto", "consome": 12.0, "luz": [Color(0.85, 0.92, 1.0), 2.4],
		"custo": {"metal": 2, "fios": 1}, "req": {"eletronica": 1}, "ferramentas": ["chave_fenda", "alicate"], "xp": {"eletronica": 4},
		"desc": "Ilumina uma área grande à noite. Consome 12 W."},
	"letreiro": {"nome": "Letreiro neon", "aba": "decoracao", "tipo": "objeto", "consome": 8.0, "luz": [Color(0.9, 0.4, 1.0), 1.1],
		"custo": {"sucata": 2, "fios": 2, "sucata_eletronica": 1}, "req": {"eletronica": 2}, "ferramentas": ["chave_fenda", "alicate"],
		"xp": {"eletronica": 5}, "desc": "Neon colorido. Consome 8 W."},
	"mesa": {"nome": "Mesa", "aba": "decoracao", "tipo": "objeto", "custo": {"madeira": 2, "pregos": 2}, "req": {}, "ferramentas": ["martelo"],
		"xp": {"carpintaria": 2}, "desc": "Móvel."},
	"cadeira": {"nome": "Cadeira", "aba": "decoracao", "tipo": "objeto", "custo": {"madeira": 1, "pregos": 2}, "req": {}, "ferramentas": ["martelo"],
		"xp": {"carpintaria": 1}, "desc": "Móvel."},
	"sofa": {"nome": "Sofá", "aba": "decoracao", "tipo": "objeto", "custo": {"madeira": 2, "pregos": 2, "sucata": 1}, "req": {}, "ferramentas": ["martelo"],
		"xp": {"carpintaria": 2}, "desc": "Móvel."},
	"tapete": {"nome": "Tapete", "aba": "decoracao", "tipo": "objeto", "andavel": true, "custo": {"sucata": 1}, "req": {}, "ferramentas": [],
		"xp": {}, "desc": "Dá para andar por cima."},
	"vaso": {"nome": "Vaso de planta", "aba": "decoracao", "tipo": "objeto", "custo": {"sucata": 1}, "req": {}, "ferramentas": [],
		"xp": {"agricultura": 1}, "desc": "Decoração."},
	"estante": {"nome": "Estante", "aba": "decoracao", "tipo": "objeto", "custo": {"madeira": 3, "pregos": 4}, "req": {}, "ferramentas": ["martelo"],
		"xp": {"carpintaria": 3}, "desc": "Móvel."},
}

## qtd: unidades produzidas; saida: item produzido (padrão: o id da receita);
## estacao: construção que precisa estar perto (cozinhar no fogareiro).
const CRAFTS := {
	"sopa": {"nome": "Sopa de batata", "custo": {"batata": 2, "agua_limpa": 1}, "req": {}, "ferramentas": ["panela"],
		"estacao": "fogareiro", "xp": {"culinaria": 8}},
	"ensopado": {"nome": "Ensopado", "custo": {"feijao": 1, "batata": 1, "tomate": 1}, "req": {"culinaria": 1}, "ferramentas": ["panela"],
		"estacao": "fogareiro", "xp": {"culinaria": 10}},
	"milho_assado": {"nome": "Milho assado (x2)", "qtd": 2, "custo": {"milho": 2}, "req": {}, "ferramentas": [],
		"estacao": "fogareiro", "xp": {"culinaria": 5}},
	"agua_fervida": {"nome": "Ferver água suja", "saida": "agua_limpa", "custo": {"agua_suja": 1}, "req": {}, "ferramentas": ["panela"],
		"estacao": "fogareiro", "xp": {"culinaria": 3}},
	"filtro": {"nome": "Filtro de máscara", "custo": {"sucata": 2, "metal": 1}, "req": {"metalurgia": 2}, "estacao": "bancada", "ferramentas": ["alicate"],
		"xp": {"metalurgia": 14}},
	"bateria": {"nome": "Bateria", "custo": {"sucata_eletronica": 2, "fios": 1, "metal": 1}, "req": {"eletronica": 2}, "estacao": "bancada", "ferramentas": ["chave_fenda"],
		"xp": {"eletronica": 12}},
	"supressor": {"nome": "Supressor químico", "custo": {"antisseptico": 1, "sucata": 1}, "req": {"medicina": 3}, "ferramentas": [],
		"xp": {"medicina": 12}},
	"pregos": {"nome": "Pregos (x12)", "qtd": 12, "custo": {"sucata": 1}, "req": {"metalurgia": 1}, "ferramentas": ["martelo"],
		"xp": {"metalurgia": 4}},
	"fios": {"nome": "Fio elétrico (x2)", "qtd": 2, "custo": {"sucata_eletronica": 1}, "req": {"eletronica": 1}, "ferramentas": ["alicate"],
		"xp": {"eletronica": 4}},
	"municao_9mm": {"nome": "Munição 9 mm (x8)", "qtd": 8, "custo": {"metal": 1, "sucata": 1, "combustivel": 1}, "req": {"metalurgia": 3, "pontaria": 1},
		"estacao": "bancada", "ferramentas": ["alicate", "martelo"], "xp": {"metalurgia": 10, "pontaria": 4}},
	"cartucho_12": {"nome": "Cartucho calibre 12 (x4)", "qtd": 4, "custo": {"metal": 1, "sucata": 1, "combustivel": 1}, "req": {"metalurgia": 3, "pontaria": 1},
		"estacao": "bancada", "ferramentas": ["alicate", "martelo"], "xp": {"metalurgia": 10, "pontaria": 4}},
}

# Cada entrada: [item, peso, mínimo, máximo]
const LOOT := {
	"comum": [["sucata", 30, 1, 4], ["madeira", 25, 1, 3], ["feijao", 12, 1, 2], ["agua_limpa", 14, 1, 2],
		["agua_suja", 10, 1, 2], ["barra_cereal", 10, 1, 2], ["bandagem", 9, 1, 2], ["metal", 12, 1, 3],
		["filtro", 6, 1, 1], ["supressor", 4, 1, 1], ["combustivel", 5, 1, 1], ["bateria", 4, 1, 1],
		["cano", 3, 1, 1], ["carne_seca", 5, 1, 1], ["maca", 6, 1, 3], ["pao", 4, 1, 1],
		["fita", 4, 1, 1], ["faca", 3, 1, 1], ["abridor", 4, 1, 1], ["pregos", 10, 4, 14], ["martelo", 3, 1, 1],
		["chave_fenda", 3, 1, 1], ["lanterna", 3, 1, 1], ["pilha", 5, 1, 3], ["cantil", 2, 1, 1], ["municao_9mm", 3, 3, 10],
		["cartucho_12", 2, 2, 5], ["pistola", 1, 1, 1], ["semente_batata", 4, 2, 4],
		["semente_milho", 3, 2, 4], ["semente_tomate", 3, 2, 4], ["enxada", 2, 1, 1], ["regador", 2, 1, 1], ["panela", 3, 1, 1], ["taco", 3, 1, 1], ["mochila_escolar", 3, 1, 1], ["coldre", 2, 1, 1]],
	"medico": [["bandagem", 30, 1, 3], ["antisseptico", 25, 1, 2], ["kit_sutura", 15, 1, 1], ["antibiotico", 15, 1, 2],
		["supressor", 12, 1, 2], ["agua_limpa", 8, 1, 2], ["gaze", 18, 1, 3], ["alcool", 12, 1, 1],
		["analgesico", 12, 1, 2], ["manual_medicina", 4, 1, 1], ["kit_cirurgico", 3, 1, 1]],
	"tecnico": [["metal", 30, 1, 4], ["sucata", 25, 2, 5], ["bateria", 14, 1, 2], ["combustivel", 14, 1, 3],
		["filtro", 12, 1, 2], ["mascara", 5, 1, 1], ["manual_mecanica", 3, 1, 1], ["manual_metalurgia", 3, 1, 1],
		["manual_engenharia", 3, 1, 1], ["manual_carpintaria", 3, 1, 1], ["manual_cibernetica", 2, 1, 1], ["implante_pulmao", 1, 1, 1], ["implante_hud", 1, 1, 1],
		["implante_braco", 1, 1, 1], ["implante_pernas", 1, 1, 1], ["implante_derme", 1, 1, 1],
		["proc_neural_mk1", 2, 1, 1], ["proc_neural_mk2", 1, 1, 1], ["machete", 2, 1, 1], ["fita", 8, 1, 1], ["mochila_trilha", 2, 1, 1],
		["mochila_militar", 1, 1, 1], ["coldre", 3, 1, 1], ["fios", 14, 1, 3], ["sucata_eletronica", 14, 1, 3],
		["alicate", 4, 1, 1], ["serra", 3, 1, 1], ["chave_fenda", 4, 1, 1], ["pilha", 6, 2, 4], ["municao_9mm", 4, 4, 12],
		["cartucho_12", 3, 2, 6], ["pistola", 1, 1, 1], ["espingarda", 1, 1, 1]],
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


static func tools_text(tools: Array) -> String:
	var parts: Array[String] = []
	for t in tools:
		parts.append(item_name(t))
	return ", ".join(parts) if not parts.is_empty() else "nenhuma"


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

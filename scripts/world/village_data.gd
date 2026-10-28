class_name VillageData
extends RefCounted
## Estado de uma vila na simulação de fundo: estoque, população, risco de infestação,
## prosperidade (nível 0-3), reputação da equipe e pedidos de socorro (fase 7).
##
## Pedido: {"tipo", "texto", "need": {categoria: qtd}, "kills": n, "prazo": relógio}.
## Categorias de entrega: comida, med, material, eletronico (ver CATEGORY).

## Categoria de entrega -> tipos (DB.ITEMS[id]["tipo"]) ou ids aceitos.
const CATEGORY := {"comida": {"tipos": ["comida"]}, "med": {"tipos": ["med", "analgesico"]},
	"material": {"tipos": ["material"], "fora": ["fios", "sucata_eletronica", "pregos"]},
	"eletronico": {"ids": ["fios", "sucata_eletronica", "bateria"]}}
const CATEGORY_NAMES := {"comida": "comida", "med": "remédios", "material": "materiais", "eletronico": "peças eletrônicas"}
## Reputação por unidade doada.
const DONATE_REP := {"comida": 2.0, "med": 3.0, "material": 1.0, "eletronico": 3.0}
const REQUEST_TIME := 360.0
## Ofertas do comerciante por especialidade: [item, preço em reputação, nível mínimo].
const OFFERS := {
	"comida": [["feijao", 4, 0], ["pao", 3, 0], ["agua_limpa", 3, 0], ["cantil", 10, 1], ["abridor", 3, 0], ["carne_seca", 4, 1],
		["semente_batata", 3, 0], ["semente_milho", 3, 0], ["semente_tomate", 3, 1], ["enxada", 8, 1], ["panela", 6, 0]],
	"sucata": [["pregos", 5, 0], ["fios", 6, 0], ["metal", 4, 0], ["martelo", 8, 0], ["alicate", 9, 1], ["serra", 12, 2],
		["municao_9mm", 10, 2]],
	"medico": [["bandagem", 3, 0], ["gaze", 3, 0], ["antisseptico", 6, 0], ["kit_sutura", 8, 1], ["antibiotico", 10, 1],
		["kit_cirurgico", 25, 2], ["filtro", 8, 0]],
}

var id := 0
var nome := ""
var cell := Vector2i.ZERO
var safe := false
var stock := {"comida": 20.0, "sucata": 15.0, "medico": 6.0}
var pop := 6
var infestation := 0.0
var infested := false
var links: Array[int] = []
var specialty := "comida"
var caravan_cd := 20.0
var clear_t := 0.0
var prosperity := 30.0
var rep := 0.0
var request := {}
var request_cd := 60.0


func setup(new_id: int, new_nome: String, new_cell: Vector2i, is_safe: bool, rng: RandomNumberGenerator) -> void:
	id = new_id
	nome = new_nome
	cell = new_cell
	safe = is_safe
	pop = rng.randi_range(4, 12)
	stock = {"comida": float(rng.randi_range(10, 40)), "sucata": float(rng.randi_range(5, 30)),
		"medico": float(rng.randi_range(0, 12))}
	specialty = ["comida", "sucata", "medico"][rng.randi() % 3]
	caravan_cd = rng.randf_range(10.0, 30.0)
	prosperity = rng.randf_range(15.0, 45.0)
	request_cd = rng.randf_range(40.0, 160.0)
	if is_safe:
		pop = 10
		prosperity = 50.0


## Nível de prosperidade (0 a 3): mais produção, guardas e ofertas.
func level() -> int:
	return clampi(int(prosperity / 25.0), 0, 3)


func status_text() -> String:
	if safe:
		return "Seguro (purificado)"
	if infested:
		return "ZONA MORTA"
	if infestation > 60.0:
		return "Em risco"
	return "Estável"


## Um passo da simulação (chamado a cada alguns segundos).
func step(rng: RandomNumberGenerator, edge_ratio: float) -> void:
	if infested or safe:
		return
	stock[specialty] = float(stock[specialty]) + rng.randf_range(1.0, 4.0) + float(level())
	stock["comida"] = float(stock["comida"]) - float(pop) * 0.25
	stock["sucata"] = float(stock["sucata"]) + rng.randf_range(0.0, 1.0)
	stock["medico"] = maxf(0.0, float(stock["medico"]) - float(pop) * 0.03)
	var starving := false
	if float(stock["comida"]) < 0.0:
		stock["comida"] = 0.0
		starving = true
	infestation += edge_ratio * edge_ratio * 2.0 + (3.0 if starving else 0.0) + rng.randf() * 0.8
	if float(stock["comida"]) > 10.0:
		infestation = maxf(0.0, infestation - 2.0 - 0.5 * float(level()))
	if infestation >= 100.0:
		fall()


## A vila cai: vira zona morta (sem moradores, cheia de infectados e esporos).
func fall() -> void:
	infested = true
	pop = 0
	request = {}
	prosperity = 0.0


## Talvez abra um pedido de socorro (servidor). Devolve true se abriu.
func maybe_request(rng: RandomNumberGenerator, clock: float, dt: float) -> bool:
	if safe or infested or not request.is_empty():
		return false
	request_cd -= dt
	if request_cd > 0.0:
		return false
	request_cd = rng.randf_range(120.0, 300.0)
	var options: Array = []
	if float(stock["comida"]) < 15.0:
		options.append("comida")
	if float(stock["medico"]) < 4.0:
		options.append("med")
	if infestation > 40.0:
		options.append("infestacao")
	if options.is_empty() or rng.randf() < 0.3:
		options.append(["material", "eletronico", "comida", "med"][rng.randi() % 4])
	var tipo: String = options[rng.randi() % options.size()]
	match tipo:
		"infestacao":
			var k := 6 + rng.randi_range(0, 4)
			request = {"tipo": tipo, "texto": "infectados cercam a vila: eliminem %d por perto" % k, "need": {}, "kills": k}
		"comida":
			request = {"tipo": tipo, "texto": "estoque de comida acabando", "need": {"comida": 5 + rng.randi_range(0, 4)}, "kills": 0}
		"med":
			request = {"tipo": tipo, "texto": "feridos sem tratamento", "need": {"med": 3 + rng.randi_range(0, 3)}, "kills": 0}
		"material":
			request = {"tipo": tipo, "texto": "barricadas caindo", "need": {"material": 8 + rng.randi_range(0, 6)}, "kills": 0}
		"eletronico":
			request = {"tipo": tipo, "texto": "o gerador da vila quebrou", "need": {"eletronico": 3 + rng.randi_range(0, 2)}, "kills": 0}
	request["prazo"] = clock + REQUEST_TIME
	return true


func request_done() -> bool:
	if request.is_empty():
		return false
	if int(request.get("kills", 0)) > 0:
		return false
	for k in request["need"]:
		if int(request["need"][k]) > 0:
			return false
	return true


## Pedido atendido: a vila prospera.
func succeed() -> void:
	prosperity = minf(100.0, prosperity + 25.0)
	infestation = maxf(0.0, infestation - 30.0)
	rep += 15.0
	pop = mini(pop + 2, 16)
	request = {}


## Prazo vencido: a vila decai e pode cair.
func fail() -> void:
	prosperity = maxf(0.0, prosperity - 20.0)
	infestation = minf(100.0, infestation + 22.0)
	pop = maxi(0, pop - 2)
	request = {}
	if infestation >= 100.0 or pop <= 0:
		fall()


func request_text() -> String:
	if request.is_empty():
		return ""
	var parts: Array[String] = []
	for k in request["need"]:
		if int(request["need"][k]) > 0:
			parts.append("%d de %s" % [int(request["need"][k]), CATEGORY_NAMES[k]])
	if int(request.get("kills", 0)) > 0:
		parts.append("%d infectados" % int(request["kills"]))
	return "%s (faltam %s)" % [request["texto"], ", ".join(parts)]


static func item_category(id: String) -> String:
	var tipo := String(DB.ITEMS[id]["tipo"]) if DB.ITEMS.has(id) else ""
	for cat in CATEGORY:
		var c: Dictionary = CATEGORY[cat]
		if id in c.get("ids", []):
			return cat
		if tipo in c.get("tipos", []) and not id in c.get("fora", []):
			return cat
	return ""


func to_dict() -> Dictionary:
	return {"id": id, "stock": stock.duplicate(), "pop": pop, "infestation": infestation,
		"infested": infested, "caravan_cd": caravan_cd, "prosperity": prosperity, "rep": rep,
		"request": request.duplicate(true), "request_cd": request_cd}


func apply_dict(src: Dictionary) -> void:
	var s: Dictionary = src.get("stock", {})
	for k in s:
		stock[str(k)] = float(s[k])
	pop = int(src.get("pop", pop))
	infestation = float(src.get("infestation", 0.0))
	infested = bool(src.get("infested", false))
	caravan_cd = float(src.get("caravan_cd", 20.0))
	prosperity = float(src.get("prosperity", prosperity))
	rep = float(src.get("rep", 0.0))
	request = src.get("request", {})
	request_cd = float(src.get("request_cd", request_cd))

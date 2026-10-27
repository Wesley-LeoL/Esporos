class_name VillageData
extends RefCounted
## Estado de uma vila na simulação de fundo: estoque, população, risco de infestação.

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
	if is_safe:
		pop = 10


func status_text() -> String:
	if safe:
		return "Seguro (purificado)"
	if infested:
		return "INFESTADA"
	if infestation > 60.0:
		return "Em risco"
	return "Estável"


## Um passo da simulação (chamado a cada alguns segundos).
func step(rng: RandomNumberGenerator, edge_ratio: float) -> void:
	if infested or safe:
		return
	stock[specialty] = float(stock[specialty]) + rng.randf_range(1.0, 4.0)
	stock["comida"] = float(stock["comida"]) - float(pop) * 0.25
	stock["sucata"] = float(stock["sucata"]) + rng.randf_range(0.0, 1.0)
	stock["medico"] = maxf(0.0, float(stock["medico"]) - float(pop) * 0.03)
	var starving := false
	if float(stock["comida"]) < 0.0:
		stock["comida"] = 0.0
		starving = true
	infestation += edge_ratio * edge_ratio * 2.0 + (3.0 if starving else 0.0) + rng.randf() * 0.8
	if float(stock["comida"]) > 10.0:
		infestation = maxf(0.0, infestation - 2.0)
	if infestation >= 100.0:
		infested = true
		pop = 0


func to_dict() -> Dictionary:
	return {"id": id, "stock": stock.duplicate(), "pop": pop, "infestation": infestation,
		"infested": infested, "caravan_cd": caravan_cd}


func apply_dict(src: Dictionary) -> void:
	var s: Dictionary = src.get("stock", {})
	for k in s:
		stock[str(k)] = float(s[k])
	pop = int(src.get("pop", pop))
	infestation = float(src.get("infestation", 0.0))
	infested = bool(src.get("infested", false))
	caravan_cd = float(src.get("caravan_cd", 20.0))

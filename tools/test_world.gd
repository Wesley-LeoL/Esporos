extends Node
## Teste do mundo (precisa dos autoloads, então roda como cena):
##   godot --headless --path . res://tools/test_world.tscn

var fails := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FALHA ", what)


func _ready() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 3
	# fase 7: geração planejada (determinística) e vilas
	var w1 := World.new()
	w1.generate(12345)
	var w2 := World.new()
	w2.generate(12345)
	check(w1.container_data.size() == w2.container_data.size() and w1.plan.size() == w2.plan.size(),
		"mesma seed, mesmo plano (%d caixas, %d chunks)" % [w1.container_data.size(), w1.plan.size()])
	check(w1.planned_buildings.size() == w2.planned_buildings.size() and w1.road_cells.size() == w2.road_cells.size(),
		"mesmos prédios e estradas")
	var same_items := true
	for i in w1.container_data.size():
		if str(w1.container_data[i]["items"]) != str(w2.container_data[i]["items"]):
			same_items = false
	check(same_items, "mesmo loot em todas as caixas")
	check(w1.villages.size() == World.N_VILLAGES, "%d vilas" % w1.villages.size())
	var far := 0.0
	for v in w1.villages:
		far = maxf(far, Vector2(v.cell).length())
	check(far <= World.RADIUS * 0.72 + 1.0, "vilas fora da zona letal (mais distante: %d tiles)" % int(far))
	var vd := w1.villages[1]
	vd.request_cd = 0.0
	vd.stock["comida"] = 1.0
	check(vd.maybe_request(r, 0.0, 6.0) and not vd.request.is_empty(), "vila abre pedido de socorro")
	var lv0 := vd.level()
	vd.succeed()
	check(vd.level() >= lv0 and vd.rep > 0.0, "pedido atendido: prosperidade e reputação sobem")
	vd.request = {"tipo": "comida", "need": {"comida": 1}, "kills": 0, "prazo": 0.0, "texto": "x"}
	vd.infestation = 95.0
	vd.fail()
	check(vd.infested, "pedido ignorado com infestação alta derruba a vila")
	check(VillageData.item_category("feijao") == "comida" and VillageData.item_category("fios") == "eletronico"
		and VillageData.item_category("pregos") == "", "categorias de entrega")
	# cidades pequenas e aldeias com prédios exploráveis
	var towns := 0
	for pl in w1.places:
		if pl["tipo"] == "cidade":
			towns += 1
	check(towns >= 4 and towns <= 7, "cidades pequenas (%d), sem metrópole" % towns)
	var states := {}
	for pl in w1.places:
		states[pl["estado"]] = true
	check(states.has("viva") and states.has("abandonada") and states.has("esporos"), "lugares vivos, abandonados e tomados por esporos")
	var doors := {}
	for k in w1.map_walls:
		if String(w1.map_walls[k]["kind"]).ends_with("_porta"):
			doors[int(w1.map_walls[k]["h"])] = true
	check(w1.houses.size() > 60 and doors.size() == w1.houses.size(), "%d prédios exploráveis, todos com porta" % w1.houses.size())
	w1.free()
	w2.free()

	print("FALHAS: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

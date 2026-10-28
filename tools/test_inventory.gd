extends SceneTree
## Teste de lógica do inventário (fase 2). Rodar:
##   godot --headless --path . -s res://tools/test_inventory.gd

var fails := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FALHA ", what)


func _initialize() -> void:
	var game: Node = root.get_node("Game")
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var d := SurvivorData.random_survivor(r)
	var dropped: Array = []
	d.overflow.connect(func(l: Array) -> void: dropped.append_array(l))
	print("inicial: %.1f kg, mochila %.1f/%.0f L" % [d.carried_weight(), d.used_volume("mochila"), d.capacity("mochila")])
	check(d.has_mask() and d.filter_pct() == 100.0, "começa com máscara e filtro")
	check(d.capacity("mochila") == 14.0, "mochila escolar 14 L")

	# capacidade: madeira 1 L cada, cabe o que sobra e o resto cai no chão
	var free := d.capacity("mochila") - d.used_volume("mochila") + d.capacity("bolsos") - d.used_volume("bolsos")
	d.give("madeira", 30)
	check(dropped.size() == 1 and Items.count(dropped, "madeira") == 30 - floori(free + 0.001), "excedente cai no chão (%d)" % Items.count(dropped, "madeira"))
	check(d.load_ratio() > 0.0, "peso conta")

	# coldre só aceita arma
	d.wear(Items.make("coldre")[0])
	check(d.fits("coldre", Items.make("feijao")[0]) == 0, "coldre recusa comida")
	var fac: Dictionary = Items.make("faca")[0]
	check(d.fits("coldre", fac) == 1, "coldre aceita faca")
	d.store(fac)
	check(Items.count(d.bags["coldre"], "faca") == 1, "faca vai pro coldre primeiro")

	# troca de mochila: conteúdo migra para a nova
	var before := d.count("madeira")
	d.wear(Items.make("mochila_militar")[0])
	check(d.capacity("mochila") == 34.0, "mochila militar vestida")
	check(d.count("madeira") == before, "conteúdo passou para a nova mochila")
	check(d.count("mochila_escolar") == 1, "mochila antiga guardada")

	# arma: empunhar, desgastar, quebrar
	var fu := int(d.first_of("faca")["u"])
	d.use_item(fu)
	check(d.weapon_id() == "faca", "faca na mão")
	var dmg_full := d.melee_damage()
	d.weapon_inst()["dur"] = 0.5
	d.wear_weapon()
	check(d.weapon_id() == "" and d.count("faca") == 0, "faca quebrou e sumiu")
	check(d.melee_damage() < dmg_full, "sem arma, menos dano")

	# conserto com fita
	d.give("taco")
	d.give("fita")
	var tu := int(d.first_of("taco")["u"])
	d.find(tu)[1]["dur"] = 40.0
	d.repair(tu)
	check(float(d.find(tu)[1]["dur"]) >= 70.0, "fita conserta (+30)")
	check(float(d.first_of("fita")["carga"]) == 80.0, "fita gasta 1 uso")

	# apodrecimento
	game.play_time = 0.0
	d.give("maca", 1)
	var m := d.first_of("maca")
	check(Items.fresh_label(m) == "Fresco", "maçã fresca")
	game.play_time = 700.0
	check(Items.fresh_label(m) == "Passado", "maçã passada depois de 700 s")
	game.play_time = 950.0
	check(Items.spoiled(m), "maçã estragada depois de 950 s")
	var p0 := d.pathogen
	d.use_item("maca")
	check(d.pathogen > p0 and d.count("maca") == 0, "comer estragado dá patógeno")

	# carga: bateria e combustível
	d.give("bateria")
	d.battery = 70.0
	d.use_item("bateria")
	check(is_equal_approx(d.battery, 100.0) and d.count("bateria") == 1, "bateria recarrega 30 e sobra carga")
	check(is_equal_approx(float(d.first_of("bateria")["carga"]), 50.0), "bateria fica com 50%")
	d.give("combustivel", 1)
	var w0 := d.carried_weight()
	var got := d.pour_fuel(30.0)
	check(is_equal_approx(got, 30.0) and is_equal_approx(float(d.first_of("combustivel")["carga"]), 40.0), "galão abastece 30 (usa 60% da carga)")
	check(d.carried_weight() < w0, "galão mais vazio pesa menos")

	# antisséptico com usos
	d.give("antisseptico")
	for i in 4:
		d.spend("antisseptico")
	check(d.count("antisseptico") == 0, "antisséptico acaba em 4 usos")

	# sobrecarga deixa lento
	d.give("metal", 20)
	check(d.load_ratio() > 1.0 and d.speed_mult() < 1.0, "sobrecarga reduz velocidade (%.2f)" % d.speed_mult())

	# ida e volta pelo dicionário (rede/save)
	var dd := d.to_dict()
	var d2 := SurvivorData.from_dict(JSON.parse_string(JSON.stringify(dd)))
	check(d2.count("metal") == d.count("metal") and d2.capacity("mochila") == 34.0, "to_dict/from_dict (JSON) preserva")
	check(d2.hand_u == d.hand_u and d2.weapon_id() == d.weapon_id(), "arma na mão preservada")

	# migração do save v3
	var old := {"nome": "Velho", "inventory": {"feijao": 2, "mascara": 1, "machete": 1, "sucata": 4}, "mask_on": true,
		"filter": 42.0, "weapon": "machete"}
	var d3 := SurvivorData.from_dict(old)
	check(d3.has_mask() and is_equal_approx(d3.filter_pct(), 42.0), "v3: máscara vestida com filtro 42%")
	check(d3.weapon_id() == "machete" and d3.count("feijao") == 2, "v3: arma e itens convertidos")
	check(Items.sanitize({"feijao": 3}).size() == 1, "sanitize converte dicionário antigo")

	# loot: o estado usa outro gerador (o mapa gerado não muda)
	var a := RandomNumberGenerator.new()
	a.seed = 1
	var b := RandomNumberGenerator.new()
	b.seed = 1
	var sr := RandomNumberGenerator.new()
	sr.seed = 99
	var l1 := DB.roll_loot("tecnico", 6, a, sr, 0.0)
	var l2 := DB.roll_loot("tecnico", 6, b, RandomNumberGenerator.new(), 0.0)
	check(a.state == b.state, "sorteio de loot não gasta o gerador do mapa com o estado dos itens")
	check(Items.total_units(l1) == Items.total_units(l2), "mesmos itens nos dois sorteios")

	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)

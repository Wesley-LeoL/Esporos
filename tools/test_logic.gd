extends SceneTree
## Teste da lógica de sobrevivência (inventário, criação, estamina...). Rodar:
##   godot --headless --path . -s res://tools/test_logic.gd

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

	# fase 3: criação por pontos, atributos, traços e estamina
	for pn in DB.PRESETS:
		check(DB.creation_error(DB.PRESETS[pn]) == "", "modelo '%s' é válido (%d pts)" % [pn, DB.creation_cost(DB.PRESETS[pn])])
	check(DB.creation_error({"forca": 9, "resist": 9, "skills": {"combate": 3}, "traits": []}) != "", "ficha cara demais é recusada")
	check(DB.creation_error({"forca": 5, "resist": 5, "skills": {}, "traits": ["atleta", "asmatico"]}) != "", "traços em conflito são recusados")
	check(DB.creation_error({"forca": 5, "resist": 5, "skills": {"hackear": 1}, "traits": []}) != "", "habilidade inexistente é recusada")
	var many_neg := {"forca": 5, "resist": 5, "skills": {}, "traits": ["pulmao_fraco", "glutao", "asmatico", "sangue_fino", "lento"]}
	check(DB.creation_cost(many_neg) == -DB.TRAIT_REFUND_MAX, "defeitos devolvem no máximo %d" % DB.TRAIT_REFUND_MAX)
	var brute := SurvivorData.from_spec({"nome": "Teste", "forca": 8, "resist": 6, "skills": {"combate": 3}, "traits": ["lento"]}, r)
	check(brute.nome == "Teste" and brute.level("combate") == 3, "ficha aplicada")
	check(brute.carry_max() > 19.0, "força 8 carrega mais (%.1f kg)" % brute.carry_max())
	check(brute.speed_mult() < 1.0, "traço lento reduz velocidade")
	var st0 := brute.stamina
	brute.tick(1.0, {"moving": true, "sprinting": true})
	check(brute.stamina < st0, "correr gasta estamina")
	brute.stamina = 0.0
	brute.tick(1.0, {"moving": false})
	check(brute.stamina > 0.0, "parado recupera estamina")
	var old_sk := SurvivorData.from_dict({"skills": {"engenharia": {"lv": 4, "xp": 0}, "logica": {"lv": 2, "xp": 0}}})
	check(old_sk.level("eletronica") == 4 and old_sk.level("metalurgia") == 2, "habilidades antigas convertidas")
	check(Items.sanitize([{"id": "manual_logica", "n": 1}])[0]["id"] == "manual_metalurgia", "manual antigo renomeado")

	# fase 4: núcleo neural e sobrecarga sináptica
	var cy := SurvivorData.from_spec({"nome": "Ciber", "forca": 5, "resist": 5, "skills": {"medicina": 3, "cibernetica": 3}, "traits": []}, r)
	cy.skills["medicina"]["lv"] = 6
	cy.skills["cibernetica"]["lv"] = 6
	cy.battery = 100.0
	check(cy.neural_capacity() == 1, "sem processador: 1 implante geral")
	cy.give("kit_cirurgico", 4)
	cy.give("implante_pulmao")
	cy.give("implante_braco")
	cy.install_implant("implante_pulmao")
	check(cy.implants.has("pulmao"), "primeiro implante instalado")
	cy.install_implant("implante_braco")
	check(not cy.implants.has("braco_d") and cy.count("implante_braco") == 0, "segundo implante sem processador é rejeitado")
	cy.synaptic = 0.0
	cy.give("proc_neural_mk1")
	cy.install_implant("proc_neural_mk1")
	check(cy.neural_capacity() == 2, "processador Mk1: 2 implantes")
	cy.give("implante_braco")
	cy.install_implant("implante_braco")
	check(cy.implants.has("braco_d") and not cy.overloaded(), "com processador cabe o segundo, sem sobrecarga")
	cy.battery = 0.0
	check(cy.overloaded(), "bateria vazia desliga o processador: sobrecarga")
	cy.battery = 100.0
	check(not cy.overloaded() or cy.synaptic >= 80.0, "bateria de volta: sem sobrecarga por excesso")
	check(cy.complex_block() == "" or cy.overloaded(), "ações complexas liberadas sem sobrecarga")
	cy.give("kit_cirurgico")
	cy.remove_implant("cerebro")
	check(cy.overloaded() and cy.complex_block() != "", "tirar o processador com 2 implantes causa sobrecarga e bloqueia ações")
	for i in 30:
		cy.tick(1.0, {"moving": false})
	check(cy.synaptic > 50.0, "estresse sináptico sobe na sobrecarga (%d)" % int(cy.synaptic))

	# fase 5: ferramentas, armas de fogo, som e furtividade
	var g := SurvivorData.from_spec({"nome": "Gun", "forca": 5, "resist": 5, "skills": {}, "traits": []}, r)
	check(g.missing_tools(["martelo"]) != "", "sem martelo: falta ferramenta")
	g.give("martelo")
	check(g.missing_tools(["martelo"]) == "", "com martelo: ok")
	g.skills["metalurgia"]["lv"] = 1
	g.give("sucata", 1)
	g.craft("pregos")
	check(g.count("pregos") == 12, "fabricar pregos rende 12")
	g.give("pistola")
	g.use_item("pistola")
	check(not g.firearm().is_empty(), "pistola na mão")
	g.give("municao_9mm", 20)
	check(g.reload() == 12 and g.count("municao_9mm") == 8, "recarga põe 12 e sobram 8")
	check(g.fits("coldre", Items.make("pistola")[0]) == 0 or g.capacity("coldre") == 0.0, "sem coldre, não cabe no coldre")
	check(g.step_noise(false, true) < g.step_noise(false, false) and g.step_noise(true, false) > g.step_noise(false, false),
		"agachado faz menos barulho, correndo mais")
	var v0 := g.visibility(false, false)
	g.give("lanterna")
	g.use_item("lanterna")
	check(g.lantern_on() and g.visibility(false, false) > v0, "lanterna acesa deixa mais visível")
	check(g.visibility(false, true) < v0 * 1.4, "agachado é menos visível")
	g.give("cantil")
	var c := g.first_of("cantil")
	c["carga"] = 0.0
	g.give("agua_limpa")
	g.use_item(int(c["u"]))
	check(float(c["carga"]) == 100.0, "cantil enche com água limpa")
	g.water = 10.0
	g.use_item(int(c["u"]))
	check(g.water > 35.0 and float(c["carga"]) < 100.0, "cantil dá água")
	g.limbs["perna_e"]["hp"] = 10.0
	var slow := g.speed_mult()
	g.give("analgesico")
	g.use_item("analgesico")
	check(g.speed_mult() > slow, "analgésico tira a lentidão da perna ferida")

	# fase 6: medicina cooperativa (o curativo usa os suprimentos e a Medicina de quem trata)
	var medic := SurvivorData.from_spec({"nome": "Medica", "forca": 5, "resist": 5, "skills": {"medicina": 3}, "traits": []}, r)
	var hurt := SurvivorData.from_spec({"nome": "Ferido", "forca": 5, "resist": 5, "skills": {}, "traits": []}, r)
	hurt.damage_limb("perna_e", 20.0)
	medic.give("bandagem", 1)
	var med_band := medic.count("bandagem")
	var xp0 := float(medic.skills["medicina"]["xp"])
	var own_band := hurt.count("bandagem")
	hurt.treat("perna_e", "enfaixar", medic)
	check(hurt.limbs["perna_e"]["bandaged"] and medic.count("bandagem") == med_band - 1 and hurt.count("bandagem") == own_band,
		"aliado enfaixa usando a bandagem dele")
	check(float(medic.skills["medicina"]["xp"]) > xp0, "quem trata ganha experiência")
	medic.skills["medicina"]["lv"] = 6
	medic.skills["cibernetica"]["lv"] = 6
	medic.give("kit_cirurgico", 1)
	medic.give("implante_derme", 1)
	hurt.battery = 100.0
	hurt.install_implant("implante_derme", medic)
	check(hurt.implants.has("pele") and float(hurt.implants["pele"]["integ"]) == 100.0, "aliado opera com encaixe perfeito")
	var self_op := SurvivorData.from_spec({"nome": "Solo", "forca": 5, "resist": 5, "skills": {}, "traits": []}, r)
	self_op.skills["medicina"]["lv"] = 6
	self_op.skills["cibernetica"]["lv"] = 6
	self_op.give("kit_cirurgico", 1)
	self_op.give("implante_derme", 1)
	self_op.install_implant("implante_derme")
	check(float(self_op.implants["pele"]["integ"]) == 80.0, "operar a si mesmo deixa o encaixe a 80%")

	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)

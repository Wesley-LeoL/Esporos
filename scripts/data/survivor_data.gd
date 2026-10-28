class_name SurvivorData
extends RefCounted
## Estado completo de um sobrevivente: metabolismo, carga patogênica, medicina por
## membros, cibernética, habilidades e inventário. Não depende de nós da cena.

signal message(text: String)

const LIMBS: Array[String] = ["cabeca", "torso", "braco_e", "braco_d", "perna_e", "perna_d"]
const LIMB_NAMES := {"cabeca": "Cabeça", "torso": "Tronco", "braco_e": "Braço esq.", "braco_d": "Braço dir.",
	"perna_e": "Perna esq.", "perna_d": "Perna dir."}
const NAMES: Array[String] = ["Ayla Moreno", "Kael Ribeiro", "Dara Voss", "Mateo Quintana", "Iris Okafor",
	"Bruno Takeda", "Nina Falk", "Orion Duarte", "Lena Sato", "Teo Marques", "Zara Lindqvist", "Caio Brandt"]
const MAX_CAL := 2000.0

var nome: String = "Sobrevivente"
var pathogen: float = 10.0
var calories: float = 1600.0
var water: float = 80.0
var blood: float = 100.0
var limbs := {}
var skills := {}
var inventory := {}
var mask_on: bool = false
var filter: float = 0.0
var weapon: String = ""
var suppress_t: float = 0.0
var tainted_t: float = 0.0
var antibiotic_t: float = 0.0
var battery: float = 0.0
var heat: float = 0.0
var implants := {}
var alive: bool = true
## Invulnerável (cheat de testes, por personagem).
var god := false
var death_cause: String = ""
var death_kind: String = ""
var time_alive: float = 0.0
var rng := RandomNumberGenerator.new()

var _warn_t := {}
var _last_hurt_cause: String = "Trauma"


func _init() -> void:
	rng.randomize()
	for l in LIMBS:
		limbs[l] = {"hp": 100.0, "wound": 0, "bleed": 0.0, "infection": 0.0,
			"disinfected": false, "sutured": false, "bandaged": false, "heal": 0.0}
	for s in DB.SKILLS:
		skills[s] = {"lv": 0, "xp": 0.0}


static func random_survivor(r: RandomNumberGenerator) -> SurvivorData:
	var d := SurvivorData.new()
	d.nome = NAMES[r.randi() % NAMES.size()]
	d.pathogen = r.randf_range(5.0, 25.0)
	d.calories = r.randf_range(1200.0, 1800.0)
	d.water = r.randf_range(60.0, 90.0)
	var keys: Array = DB.SKILLS.keys()
	keys.shuffle()
	d.skills[keys[0]]["lv"] = r.randi_range(1, 3)
	d.skills[keys[1]]["lv"] = r.randi_range(0, 2)
	d.inventory = {"feijao": 1, "agua_limpa": 2, "bandagem": 1, "mascara": 1, "filtro": 1, "sucata": 3}
	if r.randf() < 0.5:
		d.inventory["supressor"] = 1
	d.mask_on = true
	d.filter = 100.0
	return d


# ---------------------------------------------------------------- inventário
func count(id: String) -> int:
	return int(inventory.get(id, 0))


func add_item(id: String, n: int = 1) -> void:
	inventory[id] = count(id) + n


func take_item(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	inventory[id] = count(id) - n
	if int(inventory[id]) <= 0:
		inventory.erase(id)
	return true


func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if count(k) < int(cost[k]):
			return false
	return true


func pay(cost: Dictionary) -> void:
	for k in cost:
		take_item(k, int(cost[k]))


# ---------------------------------------------------------------- habilidades
func level(skill: String) -> int:
	return int(skills[skill]["lv"])


func xp_needed(lv: int) -> float:
	return 50.0 * float(lv + 1)


func add_xp(skill: String, amount: float) -> void:
	var s: Dictionary = skills[skill]
	if int(s["lv"]) >= 10:
		return
	s["xp"] = float(s["xp"]) + amount
	while int(s["lv"]) < 10 and float(s["xp"]) >= xp_needed(int(s["lv"])):
		s["xp"] = float(s["xp"]) - xp_needed(int(s["lv"]))
		s["lv"] = int(s["lv"]) + 1
		message.emit("Habilidade %s subiu para o nível %d!" % [DB.SKILLS[skill], int(s["lv"])])


func add_xp_map(xp: Dictionary) -> void:
	for k in xp:
		add_xp(k, float(xp[k]))


func meets(req: Dictionary) -> bool:
	for k in req:
		if level(k) < int(req[k]):
			return false
	return true


# ---------------------------------------------------------------- simulação
func tick(delta: float, env: Dictionary) -> void:
	if not alive:
		return
	time_alive += delta
	var moving: bool = env.get("moving", false)
	var spore: float = env.get("spore", 0.0)
	_tick_metabolism(delta, moving)
	_tick_implants(delta, moving or env.get("combat", false))
	_tick_pathogen(delta, spore, env.get("purifier", false))
	_tick_wounds(delta, spore)
	_check_death()


func _warn(key: String, text: String, cooldown: float = 40.0) -> void:
	if time_alive - float(_warn_t.get(key, -999.0)) >= cooldown:
		_warn_t[key] = time_alive
		message.emit(text)


func _hurt_internal(limb_id: String, amount: float, cause: String) -> void:
	if god:
		return
	var limb: Dictionary = limbs[limb_id]
	limb["hp"] = maxf(0.0, float(limb["hp"]) - amount)
	_last_hurt_cause = cause


func _tick_metabolism(delta: float, moving: bool) -> void:
	var k := 1.5 if moving else 1.0
	calories = maxf(0.0, calories - 0.55 * k * delta)
	water = maxf(0.0, water - 0.11 * k * delta)
	if calories <= 0.0:
		_hurt_internal("torso", 1.0 * delta, "Fome")
		_warn("fome", "Você está morrendo de fome!")
	elif calories < 400.0:
		_warn("fome", "Você está com muita fome.")
	if water <= 0.0:
		_hurt_internal("torso", 1.5 * delta, "Sede")
		_warn("sede", "Você está desidratado!")
	elif water < 20.0:
		_warn("sede", "Você está com muita sede.")


func implant_active(slot: String) -> bool:
	return implants.has(slot) and battery > 0.0 and float(implants[slot]["integ"]) > 0.0


func implant_damaged(slot: String) -> bool:
	if not implants.has(slot):
		return false
	return battery <= 0.0 or float(implants[slot]["integ"]) < 30.0


func _tick_implants(delta: float, exerting: bool) -> void:
	if implants.is_empty():
		heat = move_toward(heat, 0.0, 0.5 * delta)
		return
	var target := 0.0
	var drain := 0.0
	for slot in implants:
		var imp: Dictionary = implants[slot]
		var def: Dictionary = DB.IMPLANTS[imp["id"]]
		if battery > 0.0 and float(imp["integ"]) > 0.0:
			drain += float(def["dreno"])
			var bad := 1.0 + (1.0 - float(imp["integ"]) / 100.0) * 2.0
			target += float(def["calor"]) * 30.0 * bad
			imp["integ"] = maxf(0.0, float(imp["integ"]) - 0.015 * delta)
	if exerting:
		target += 8.0
	battery = maxf(0.0, battery - drain * delta)
	heat = move_toward(heat, minf(target, 100.0), 0.6 * delta)
	if battery <= 0.0 and drain == 0.0:
		_warn("bateria", "Bateria dos implantes esgotada! Eles estão desligados.")
	if heat > 70.0:
		for slot in implants:
			var def: Dictionary = DB.IMPLANTS[implants[slot]["id"]]
			_hurt_internal(def["membro"], 0.6 * delta, "Estresse térmico dos implantes")
		_warn("calor", "Superaquecimento! Seus implantes estão queimando seus tecidos.")


func immune_mult() -> float:
	var m := 1.0
	for slot in implants:
		if implant_damaged(slot):
			m += 0.5
	if heat > 70.0:
		m += 0.5
	return minf(m, 2.5)


func limb_immune_mult(limb_id: String) -> float:
	var m := 1.0
	for slot in implants:
		var def: Dictionary = DB.IMPLANTS[implants[slot]["id"]]
		if def["membro"] == limb_id and implant_damaged(slot):
			m += 1.5
	return m


func exposure_factor() -> float:
	var f := 1.0
	if mask_on and filter > 0.0:
		f *= 0.08
	if implant_active("pulmao"):
		f *= 0.35
	return f


func _tick_pathogen(delta: float, spore: float, purifier: bool) -> void:
	var f := exposure_factor()
	var rate := 0.015 + 1.2 * pow(spore, 1.5) * f
	if spore >= 1.0:
		rate += 18.0 * (0.4 + 0.6 * f)
		_warn("letal", "CONCENTRAÇÃO LETAL DE ESPOROS! Volte agora!", 6.0)
	if tainted_t > 0.0:
		rate += 0.35
		tainted_t -= delta
	rate *= immune_mult()
	if suppress_t > 0.0:
		rate *= 0.5
		pathogen -= 0.4 * delta
		suppress_t -= delta
	if purifier:
		rate *= 0.2
		pathogen -= 4.0 * delta
	pathogen = clampf(pathogen + rate * delta, 0.0, 100.0)
	if mask_on and filter > 0.0:
		if spore >= 1.0:
			filter = 0.0
			message.emit("O filtro foi destruído pelos esporos!")
		else:
			filter = maxf(0.0, filter - (spore * spore * 1.2 + spore * 0.2) * delta)
			if filter <= 0.0:
				message.emit("O filtro da máscara acabou!")
			elif filter < 15.0:
				_warn("filtro", "O filtro está quase no fim.")
	if pathogen > 75.0:
		_warn("patogeno", "A carga patogênica está crítica!", 25.0)


func _tick_wounds(delta: float, spore: float) -> void:
	var total_bleed := 0.0
	var healing_ok := calories > 300.0 and water > 15.0
	var any_infection := false
	for l in LIMBS:
		var limb: Dictionary = limbs[l]
		if int(limb["wound"]) > 0:
			var b := float(limb["bleed"])
			if limb["bandaged"]:
				b *= 0.0 if int(limb["wound"]) == 1 else 0.4
			total_bleed += b
			var inf_rate := 0.4
			if limb["disinfected"]:
				inf_rate *= 0.1
			if limb["bandaged"]:
				inf_rate *= 0.6
			inf_rate *= limb_immune_mult(l)
			if antibiotic_t > 0.0:
				limb["infection"] = maxf(0.0, float(limb["infection"]) - 1.2 * delta)
			else:
				limb["infection"] = minf(100.0, float(limb["infection"]) + inf_rate * delta)
			if not limb["bandaged"] and spore > 0.25:
				pathogen = minf(100.0, pathogen + spore * 0.8 * delta)
				_warn("ferida_esporo", "Esporos entram pela ferida aberta! Enfaixe-a.", 20.0)
			if limb["bandaged"] and int(limb["wound"]) == 1 and float(limb["infection"]) < 25.0 and healing_ok:
				limb["heal"] = float(limb["heal"]) + 1.0 * delta
				if float(limb["heal"]) >= 100.0:
					limb["wound"] = 0
					limb["bleed"] = 0.0
					limb["heal"] = 0.0
					limb["bandaged"] = false
					limb["sutured"] = false
					limb["disinfected"] = false
					message.emit("Ferida cicatrizada: %s." % LIMB_NAMES[l])
		else:
			limb["infection"] = maxf(0.0, float(limb["infection"]) - 0.5 * delta)
		if float(limb["infection"]) >= 100.0:
			_hurt_internal("torso", 1.2 * delta, "Sepse")
			_warn("sepse", "SEPSE em %s! Use antibiótico." % LIMB_NAMES[l], 15.0)
		elif float(limb["infection"]) >= 50.0:
			any_infection = true
	antibiotic_t = maxf(0.0, antibiotic_t - delta)
	blood = clampf(blood - total_bleed * delta, 0.0, 100.0)
	if total_bleed > 0.0 and blood < 50.0:
		_warn("sangue", "Você está perdendo muito sangue!", 20.0)
	if total_bleed == 0.0 and healing_ok:
		blood = minf(100.0, blood + 0.03 * delta)
		if not any_infection:
			for l in LIMBS:
				var limb: Dictionary = limbs[l]
				if float(limb["hp"]) < 100.0 and int(limb["wound"]) < 2:
					limb["hp"] = minf(100.0, float(limb["hp"]) + 0.12 * delta * 1.0)


func kill(cause: String, kind: String) -> void:
	if alive:
		_die(cause, kind)


func _check_death() -> void:
	if not alive:
		return
	if god:
		pathogen = minf(pathogen, 99.0)
		blood = maxf(blood, 1.0)
		return
	if pathogen >= 100.0:
		_die("Carga patogênica em 100%", "infeccao")
	elif blood <= 0.0:
		_die("Sangramento", "fisica")
	elif float(limbs["cabeca"]["hp"]) <= 0.0 or float(limbs["torso"]["hp"]) <= 0.0:
		_die(_last_hurt_cause, "fisica")


func _die(cause: String, kind: String) -> void:
	alive = false
	death_cause = cause
	death_kind = kind
	message.emit("Você morreu: %s." % cause)


# ---------------------------------------------------------------- combate
func damage_limb(limb_id: String, amount: float) -> void:
	if god:
		return
	var limb: Dictionary = limbs[limb_id]
	limb["hp"] = maxf(0.0, float(limb["hp"]) - amount)
	_last_hurt_cause = "Trauma em combate"
	if amount >= 6.0:
		var deep := amount >= 16.0
		limb["wound"] = 2 if (deep or int(limb["wound"]) == 2) else 1
		limb["bleed"] = float(limb["bleed"]) + amount * (0.035 if deep else 0.012)
		limb["disinfected"] = false
		limb["sutured"] = false
		limb["bandaged"] = false
		limb["heal"] = 0.0
	for slot in implants:
		var def: Dictionary = DB.IMPLANTS[implants[slot]["id"]]
		if def["membro"] == limb_id:
			implants[slot]["integ"] = maxf(0.0, float(implants[slot]["integ"]) - amount * 0.4)
	message.emit("Ferimento: %s (-%d)." % [LIMB_NAMES[limb_id], int(amount)])


func melee_damage() -> float:
	var dmg := 14.0
	if weapon != "" and DB.ITEMS.has(weapon):
		dmg += float(DB.ITEMS[weapon]["dano"])
	if implant_active("braco_d"):
		dmg += 14.0
	if float(limbs["braco_d"]["hp"]) < 30.0:
		dmg *= 0.6
	return dmg


func speed_mult() -> float:
	var m := 1.0
	for l in ["perna_e", "perna_d"]:
		var hp := float(limbs[l]["hp"])
		if hp <= 0.0:
			m -= 0.25
		elif hp < 40.0:
			m -= 0.15
	if pathogen > 60.0:
		m -= 0.15 * (pathogen - 60.0) / 40.0
	return maxf(0.35, m)


# ---------------------------------------------------------------- uso de itens
func use_item(id: String) -> void:
	if count(id) <= 0 or not DB.ITEMS.has(id):
		return
	var def: Dictionary = DB.ITEMS[id]
	match String(def["tipo"]):
		"comida":
			take_item(id)
			calories = minf(MAX_CAL, calories + float(def["cal"]))
			message.emit("Você comeu: %s." % def["nome"])
		"bebida":
			take_item(id)
			water = minf(100.0, water + float(def["agua"]))
			if not def["limpa"]:
				pathogen = minf(100.0, pathogen + 6.0)
				tainted_t = 60.0
				message.emit("Água contaminada! A infecção acelera.")
			else:
				message.emit("Você bebeu água limpa.")
		"mascara":
			mask_on = not mask_on
			message.emit("Máscara %s." % ("colocada" if mask_on else "removida"))
		"filtro":
			if count("mascara") <= 0:
				message.emit("Você precisa de uma máscara de gás.")
				return
			take_item(id)
			filter = 100.0
			message.emit("Filtro novo instalado (100%).")
		"supressor":
			take_item(id)
			suppress_t = 60.0
			pathogen = maxf(0.0, pathogen - 15.0)
			message.emit("Supressor aplicado: carga -15%.")
		"bateria":
			take_item(id)
			battery = minf(100.0, battery + 60.0)
			message.emit("Bateria dos implantes recarregada.")
		"manual":
			take_item(id)
			message.emit("Você estudou: %s." % def["nome"])
			add_xp(String(def["skill"]), float(def["xp"]))
		"arma":
			weapon = "" if weapon == id else id
			message.emit("Arma %s: %s." % [("equipada" if weapon == id else "guardada"), def["nome"]])
		_:
			message.emit("Use este item em outra aba.")


# ---------------------------------------------------------------- medicina
func treat(limb_id: String, action: String) -> void:
	var limb: Dictionary = limbs[limb_id]
	if action == "antibiotico":
		if not take_item("antibiotico"):
			message.emit("Sem antibiótico.")
			return
		antibiotic_t = 120.0
		add_xp("medicina", 4.0)
		message.emit("Antibiótico aplicado por 2 minutos.")
		return
	if int(limb["wound"]) == 0:
		message.emit("Não há ferida em %s." % LIMB_NAMES[limb_id])
		return
	match action:
		"desinfetar":
			if not take_item("antisseptico"):
				message.emit("Sem antisséptico.")
				return
			limb["disinfected"] = true
			limb["infection"] = maxf(0.0, float(limb["infection"]) - 15.0)
			add_xp("medicina", 6.0)
			message.emit("%s desinfetado." % LIMB_NAMES[limb_id])
		"enfaixar":
			if limb["bandaged"]:
				message.emit("Já está enfaixado.")
				return
			if not take_item("bandagem"):
				message.emit("Sem bandagem.")
				return
			limb["bandaged"] = true
			add_xp("medicina", 5.0)
			message.emit("%s enfaixado." % LIMB_NAMES[limb_id])
		"suturar":
			if int(limb["wound"]) < 2:
				message.emit("Só ferimentos profundos precisam de sutura.")
				return
			if not take_item("kit_sutura"):
				message.emit("Sem kit de sutura.")
				return
			var chance_fail := maxf(0.0, 0.5 - 0.15 * float(level("medicina")))
			if rng.randf() < chance_fail:
				limb["infection"] = minf(100.0, float(limb["infection"]) + 15.0)
				limb["hp"] = maxf(0.0, float(limb["hp"]) - 5.0)
				add_xp("medicina", 5.0)
				message.emit("A sutura falhou! Falta prática em Medicina.")
			else:
				limb["sutured"] = true
				limb["wound"] = 1
				limb["bleed"] = float(limb["bleed"]) * 0.4
				add_xp("medicina", 16.0)
				message.emit("Sutura bem-sucedida em %s." % LIMB_NAMES[limb_id])


# ---------------------------------------------------------------- cibernética
## Retorna true se o personagem sobreviveu à operação.
func install_implant(item_id: String) -> void:
	if not DB.IMPLANTS.has(item_id) or count(item_id) <= 0:
		return
	var def: Dictionary = DB.IMPLANTS[item_id]
	var slot: String = def["slot"]
	if implants.has(slot):
		message.emit("Esse encaixe já tem um implante.")
		return
	if count("kit_cirurgico") <= 0:
		message.emit("Você precisa de um kit cirúrgico.")
		return
	take_item("kit_cirurgico")
	take_item(item_id)
	var deficit := 0
	for k in def["req"]:
		deficit += maxi(0, int(def["req"][k]) - level(k))
	if deficit == 0:
		implants[slot] = {"id": item_id, "integ": 100.0}
		add_xp("medicina", 30.0)
		add_xp("engenharia", 30.0)
		message.emit("Implante instalado com sucesso: %s." % DB.item_name(item_id))
		return
	var r := rng.randf()
	var death_p := 0.0 if deficit < 2 else 0.30
	var crit_p := 0.35 if deficit < 2 else 0.45
	if r < death_p:
		_hurt_internal("torso", 999.0, "Cirurgia fracassada")
		message.emit("A cirurgia deu errado de forma fatal...")
	elif r < death_p + crit_p:
		damage_limb("torso", 35.0)
		message.emit("FALHA CRÍTICA na cirurgia! O implante foi destruído.")
		add_xp("medicina", 10.0)
	else:
		implants[slot] = {"id": item_id, "integ": 55.0}
		message.emit("Instalado com muita sorte, mas mal encaixado (integridade 55%).")
		add_xp("medicina", 12.0)
		add_xp("engenharia", 12.0)


func maintain_implant(slot: String) -> void:
	if not implants.has(slot):
		return
	if not take_item("sucata"):
		message.emit("Manutenção precisa de 1 sucata.")
		return
	var chance_fail := 0.3 if level("mecanica") < 1 else 0.0
	if rng.randf() < chance_fail:
		message.emit("A manutenção falhou (sucata perdida).")
		return
	implants[slot]["integ"] = minf(100.0, float(implants[slot]["integ"]) + 35.0)
	add_xp("mecanica", 10.0)
	message.emit("Manutenção feita: %s." % DB.IMPLANT_SLOTS[slot])


func craft(recipe: String) -> void:
	var def: Dictionary = DB.CRAFTS[recipe]
	if not meets(def["req"]):
		message.emit("Habilidade insuficiente: %s." % DB.req_text(def["req"]))
		return
	if not can_afford(def["custo"]):
		message.emit("Faltam materiais: %s." % DB.cost_text(def["custo"]))
		return
	pay(def["custo"])
	add_item(recipe)
	add_xp_map(def["xp"])
	message.emit("Fabricado: %s." % def["nome"])


# ---------------------------------------------------------------- persistência
func to_dict() -> Dictionary:
	return {"nome": nome, "pathogen": pathogen, "calories": calories,
		"water": water, "blood": blood, "limbs": limbs.duplicate(true), "skills": skills.duplicate(true),
		"inventory": inventory.duplicate(), "implants": implants.duplicate(true), "mask_on": mask_on,
		"filter": filter, "weapon": weapon, "suppress_t": suppress_t, "tainted_t": tainted_t,
		"antibiotic_t": antibiotic_t, "battery": battery, "heat": heat, "time_alive": time_alive}


static func from_dict(src: Dictionary) -> SurvivorData:
	var d := SurvivorData.new()
	d.nome = str(src.get("nome", "Sobrevivente"))
	d.pathogen = float(src.get("pathogen", 10.0))
	d.calories = float(src.get("calories", 1600.0))
	d.water = float(src.get("water", 80.0))
	d.blood = float(src.get("blood", 100.0))
	d.mask_on = bool(src.get("mask_on", false))
	d.filter = float(src.get("filter", 0.0))
	d.weapon = str(src.get("weapon", ""))
	d.suppress_t = float(src.get("suppress_t", 0.0))
	d.tainted_t = float(src.get("tainted_t", 0.0))
	d.antibiotic_t = float(src.get("antibiotic_t", 0.0))
	d.battery = float(src.get("battery", 0.0))
	d.heat = float(src.get("heat", 0.0))
	d.time_alive = float(src.get("time_alive", 0.0))
	var src_limbs: Dictionary = src.get("limbs", {})
	for l in LIMBS:
		if src_limbs.has(l):
			var sl: Dictionary = src_limbs[l]
			d.limbs[l] = {"hp": float(sl.get("hp", 100.0)), "wound": int(sl.get("wound", 0)),
				"bleed": float(sl.get("bleed", 0.0)), "infection": float(sl.get("infection", 0.0)),
				"disinfected": bool(sl.get("disinfected", false)), "sutured": bool(sl.get("sutured", false)),
				"bandaged": bool(sl.get("bandaged", false)), "heal": float(sl.get("heal", 0.0))}
	var src_skills: Dictionary = src.get("skills", {})
	for s in DB.SKILLS:
		if src_skills.has(s):
			d.skills[s] = {"lv": int(src_skills[s].get("lv", 0)), "xp": float(src_skills[s].get("xp", 0.0))}
	var src_inv: Dictionary = src.get("inventory", {})
	for k in src_inv:
		d.inventory[str(k)] = int(src_inv[k])
	var src_imp: Dictionary = src.get("implants", {})
	for k in src_imp:
		d.implants[str(k)] = {"id": str(src_imp[k]["id"]), "integ": float(src_imp[k]["integ"])}
	return d

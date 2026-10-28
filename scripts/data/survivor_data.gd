class_name SurvivorData
extends RefCounted
## Estado completo de um sobrevivente: metabolismo, carga patogênica, medicina por
## membros, cibernética, habilidades e inventário. Não depende de nós da cena.

signal message(text: String)
## Itens que não couberam (o Player larga no chão num saco).
signal overflow(items: Array)

const LIMBS: Array[String] = ["cabeca", "torso", "braco_e", "braco_d", "perna_e", "perna_d"]
const LIMB_NAMES := {"cabeca": "Cabeça", "torso": "Tronco", "braco_e": "Braço esq.", "braco_d": "Braço dir.",
	"perna_e": "Perna esq.", "perna_d": "Perna dir."}
const NAMES: Array[String] = ["Ayla Moreno", "Kael Ribeiro", "Dara Voss", "Mateo Quintana", "Iris Okafor",
	"Bruno Takeda", "Nina Falk", "Orion Duarte", "Lena Sato", "Teo Marques", "Zara Lindqvist", "Caio Brandt"]
const MAX_CAL := 2000.0
## Volume dos bolsos (litros) e peso confortável (kg; a fase 3 liga isso à Força).
const POCKETS_CAP := 4.0
const CARRY_MAX := 16.0
## Ordem em que os itens recebidos procuram espaço (o coldre só aceita armas).
const CONTAINERS := ["coldre", "mochila", "bolsos"]
const CONT_NAMES := {"bolsos": "Bolsos", "mochila": "Mochila", "coldre": "Coldre"}
const EQUIP_SLOTS := ["mascara", "mochila", "coldre"]

var nome: String = "Sobrevivente"
var pathogen: float = 10.0
var calories: float = 1600.0
var water: float = 80.0
var blood: float = 100.0
var limbs := {}
var skills := {}
## Atributos da criação (2 a 9, base 5) e traços escolhidos (ver DB.TRAITS).
var forca: int = 5
var resist: int = 5
var traits: Array = []
var stamina: float = 100.0
## Itens por recipiente (listas de instâncias, ver Items).
var bags := {"bolsos": [], "mochila": [], "coldre": []}
## Itens vestidos: máscara (com vedação e filtro), mochila e coldre. {} = vazio.
var equip := {"mascara": {}, "mochila": {}, "coldre": {}}
## Id único ("u") da arma na mão (ela continua guardada em algum recipiente).
var hand_u: int = 0
var _next_u: int = 1
var suppress_t: float = 0.0
var tainted_t: float = 0.0
var antibiotic_t: float = 0.0
var battery: float = 0.0
var heat: float = 0.0
var implants := {}
## Estresse sináptico (0-100). Ver overloaded().
var synaptic: float = 0.0
## Analgésico (segundos restantes) e lanterna acesa (id único da lanterna, 0 = apagada).
var pain_t: float = 0.0
var light_u: int = 0
## Comida quente (segundos restantes): a estamina recupera mais rápido.
var well_fed_t: float = 0.0
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


## Ficha de criação aleatória (um dos modelos prontos, com nome sorteado).
static func random_spec(r: RandomNumberGenerator) -> Dictionary:
	var keys: Array = DB.PRESETS.keys()
	var spec: Dictionary = DB.PRESETS[keys[r.randi() % keys.size()]].duplicate(true)
	spec["nome"] = NAMES[r.randi() % NAMES.size()]
	return spec


## Sobrevivente novo a partir de uma ficha já validada (DB.creation_error).
static func from_spec(spec: Dictionary, r: RandomNumberGenerator) -> SurvivorData:
	var d := random_survivor(r)
	var n := str(spec.get("nome", "")).strip_edges().substr(0, 20)
	if n != "":
		d.nome = n
	d.forca = int(spec.get("forca", 5))
	d.resist = int(spec.get("resist", 5))
	for s in d.skills:
		d.skills[s]["lv"] = 0
	var sk: Dictionary = spec.get("skills", {})
	for k in sk:
		d.skills[str(k)]["lv"] = int(sk[k])
	d.traits.assign(spec.get("traits", []))
	d.stamina = d.max_stamina()
	return d


static func random_survivor(r: RandomNumberGenerator) -> SurvivorData:
	var d := SurvivorData.new()
	d.nome = NAMES[r.randi() % NAMES.size()]
	d.pathogen = r.randf_range(5.0, 25.0)
	d.calories = r.randf_range(1200.0, 1800.0)
	d.water = r.randf_range(60.0, 90.0)
	var preset: Dictionary = DB.PRESETS.values()[r.randi() % DB.PRESETS.size()]
	for k in preset["skills"]:
		d.skills[k]["lv"] = int(preset["skills"][k])
	d.forca = int(preset["forca"])
	d.resist = int(preset["resist"])
	d.traits.assign(preset["traits"])
	d.stamina = d.max_stamina()
	d.equip["mochila"] = Items.make("mochila_escolar")[0]
	var mask: Dictionary = Items.make("mascara")[0]
	mask["filtro"] = 100.0
	d.equip["mascara"] = mask
	var start := {"feijao": 1, "abridor": 1, "agua_limpa": 2, "bandagem": 1, "filtro": 1, "sucata": 3}
	if r.randf() < 0.5:
		start["supressor"] = 1
	if r.randf() < 0.5:
		start["maca"] = 2
	d.receive(Items.from_counts(start))
	return d


# ---------------------------------------------------------------- inventário
func all_items() -> Array:
	return bags["coldre"] + bags["mochila"] + bags["bolsos"]


func count(id: String) -> int:
	return Items.count(all_items(), id)


## Capacidade (litros) de um recipiente; mochila e coldre dependem do item vestido.
func capacity(c: String) -> float:
	if c == "bolsos":
		return POCKETS_CAP + (2.0 if has_trait("organizado") else 0.0)
	var worn: Dictionary = equip.get(c, {})
	return float(Items.def(worn["id"]).get("cap", 0.0)) if not worn.is_empty() else 0.0


func used_volume(c: String) -> float:
	return Items.list_volume(bags[c])


## Quantas unidades da instância cabem no recipiente.
func fits(c: String, inst: Dictionary) -> int:
	if c == "coldre" and not String(Items.def(inst["id"])["tipo"]) in ["arma", "arma_fogo"]:
		return 0
	var unit := float(Items.def(inst["id"]).get("vol", 0.5))
	var free := capacity(c) - used_volume(c)
	if unit <= 0.0:
		return int(inst["n"])
	return clampi(floori((free + 0.001) / unit), 0, int(inst["n"]))


func _put(c: String, inst: Dictionary) -> void:
	var placed := Items.add(bags[c], inst)
	if not placed.has("u"):
		placed["u"] = _next_u
		_next_u += 1


## Guarda uma instância onde couber (ou no recipiente 'prefer'). Devolve o que sobrou ({}).
## Mantém o id único da instância quando ela já tem um (itens que só mudam de recipiente).
func store(inst: Dictionary, prefer := "") -> Dictionary:
	inst = inst.duplicate()
	var order: Array = CONTAINERS.duplicate()
	if prefer != "":
		order.erase(prefer)
		order.push_front(prefer)
	for c in order:
		var k := fits(c, inst)
		if k <= 0:
			continue
		if k >= int(inst["n"]):
			_put(c, inst)
			return {}
		var part := inst.duplicate()
		part.erase("u")
		part["n"] = k
		inst["n"] = int(inst["n"]) - k
		_put(c, part)
	inst.erase("u")
	return inst


## Recebe uma lista de itens; devolve o que não coube.
func receive(list: Array) -> Array:
	var left: Array = []
	for inst in list:
		var rest := store(inst)
		if not rest.is_empty():
			Items.add(left, rest)
	return left


## Cria itens novos e guarda; o que não couber cai no chão (sinal overflow).
func give(id: String, n: int = 1) -> void:
	var left := receive(Items.make(id, n))
	if not left.is_empty():
		message.emit("Sem espaço: %s ficou no chão." % Items.describe_list(left))
		overflow.emit(left)


## [recipiente, instância] do item com esse id único ("equip:<slot>" para itens vestidos).
func find(u: int) -> Array:
	for c in bags:
		for inst in bags[c]:
			if int(inst.get("u", 0)) == u:
				return [c, inst]
	for slot in equip:
		if not equip[slot].is_empty() and int(equip[slot].get("u", 0)) == u:
			return ["equip:" + slot, equip[slot]]
	return []


## Primeira instância com esse id (para ações por tipo, como "usar bateria").
func first_of(id: String) -> Dictionary:
	for inst in all_items():
		if inst["id"] == id:
			return inst
	return {}


func _resolve(ref: Variant) -> Dictionary:
	if ref is int or ref is float:
		var f := find(int(ref))
		return f[1] if not f.is_empty() else {}
	return first_of(str(ref))


## Tira 'n' unidades de uma instância do inventário. Devolve a parte (sem id único).
func remove_u(u: int, n: int = 1) -> Dictionary:
	var f := find(u)
	if f.is_empty() or String(f[0]).begins_with("equip:"):
		return {}
	var part := Items.split(bags[f[0]], f[1], n)
	if u == hand_u and find(u).is_empty():
		hand_u = 0
	return Items.strip(part)


func take_item(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	for c in ["bolsos", "mochila", "coldre"]:
		var here := Items.count(bags[c], id)
		if here <= 0 or n <= 0:
			continue
		var k := mini(here, n)
		Items.take(bags[c], id, k)
		n -= k
	if hand_u != 0 and find(hand_u).is_empty():
		hand_u = 0
	return true


## Gasta um uso de um item (unidade inteira, ou parte da carga em itens com usos).
func spend(id: String) -> bool:
	var d := Items.def(id)
	if not d.has("carga"):
		return take_item(id)
	var best: Dictionary = {}
	for inst in all_items():
		if inst["id"] == id and (best.is_empty() or float(inst["carga"]) < float(best["carga"])):
			best = inst
	if best.is_empty():
		return false
	best["carga"] = float(best["carga"]) - float(d.get("uso_carga", 100.0))
	if float(best["carga"]) <= 0.5:
		remove_u(int(best["u"]))
	return true


func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if count(k) < int(cost[k]):
			return false
	return true


func pay(cost: Dictionary) -> void:
	for k in cost:
		take_item(k, int(cost[k]))


## Move um item entre os próprios recipientes (inteiro, se couber).
func move_item(u: int, dest: String) -> void:
	var f := find(u)
	if f.is_empty() or not bags.has(dest) or f[0] == dest or String(f[0]).begins_with("equip:"):
		return
	var inst: Dictionary = f[1]
	if fits(dest, inst) < int(inst["n"]):
		message.emit("Não cabe em %s." % CONT_NAMES[dest].to_lower())
		return
	var keep_hand := hand_u == u
	bags[f[0]].erase(inst)
	var placed := Items.add(bags[dest], inst)
	if keep_hand:
		hand_u = int(placed["u"])


# ---------------------------------------------------------------- equipamento
func has_mask() -> bool:
	return not equip["mascara"].is_empty()


func filter_pct() -> float:
	return float(equip["mascara"].get("filtro", 0.0)) if has_mask() else 0.0


func mask_seal() -> float:
	return float(equip["mascara"].get("dur", 100.0)) if has_mask() else 0.0


func weapon_inst() -> Dictionary:
	if hand_u == 0:
		return {}
	var f := find(hand_u)
	return f[1] if not f.is_empty() else {}


func weapon_id() -> String:
	var w := weapon_inst()
	return str(w["id"]) if not w.is_empty() else ""


## Veste um item (mochila, coldre ou máscara) vindo de fora do inventário ou de um recipiente.
## O que estava vestido antes volta para o inventário junto com o conteúdo dele; o que não
## couber cai no chão.
func wear(inst: Dictionary) -> void:
	var tipo := String(Items.def(inst["id"]).get("tipo", ""))
	if not tipo in EQUIP_SLOTS:
		return
	inst = Items.strip(inst)
	inst["n"] = 1
	inst["u"] = _next_u
	_next_u += 1
	var old: Dictionary = equip[tipo]
	var old_content: Array = bags[tipo] if bags.has(tipo) else []
	equip[tipo] = inst
	if bags.has(tipo):
		bags[tipo] = []
	var back: Array = []
	for it in old_content:
		back.append(it)
	if not old.is_empty():
		back.append(old)
	var left := receive(back)
	if hand_u != 0 and find(hand_u).is_empty():
		hand_u = 0
	message.emit("Você vestiu: %s." % DB.item_name(inst["id"]))
	if not left.is_empty():
		message.emit("Sem espaço: %s ficou no chão." % Items.describe_list(left))
		overflow.emit(left)


## Tira um item vestido e guarda no inventário (ou larga, se não couber).
func unwear(slot: String) -> void:
	if not equip.has(slot) or equip[slot].is_empty():
		return
	var old: Dictionary = equip[slot]
	equip[slot] = {}
	var back: Array = []
	if bags.has(slot):
		back = bags[slot]
		bags[slot] = []
	back.append(old)
	var left := receive(back)
	if hand_u != 0 and find(hand_u).is_empty():
		hand_u = 0
	message.emit("Você tirou: %s." % DB.item_name(old["id"]))
	if not left.is_empty():
		message.emit("Sem espaço: %s ficou no chão." % Items.describe_list(left))
		overflow.emit(left)


## Peso carregado (kg): conteúdo dos recipientes (a mochila alivia parte) + itens vestidos.
func carried_weight() -> float:
	var w := Items.list_weight(bags["bolsos"]) + Items.list_weight(bags["coldre"])
	var red := 0.0
	if not equip["mochila"].is_empty():
		red = float(Items.def(equip["mochila"]["id"]).get("reducao", 0.0))
	w += Items.list_weight(bags["mochila"]) * (1.0 - red)
	for slot in equip:
		if not equip[slot].is_empty():
			w += Items.weight(equip[slot])
	return w


## Peso confortável: 16 kg com Força 5 e Atletismo 0.
func carry_max() -> float:
	return CARRY_MAX + 1.2 * float(forca - 5) + 0.6 * float(level("atletismo"))


func load_ratio() -> float:
	return carried_weight() / carry_max()


## Desgasta a arma da mão após um golpe que acertou. Ela pode quebrar.
func wear_weapon() -> void:
	var w := weapon_inst()
	if w.is_empty() or not w.has("dur"):
		return
	var gasto := float(Items.def(w["id"]).get("gasto", 1.0)) * (1.0 - 0.04 * float(level("combate")))
	if has_trait("desajeitado"):
		gasto *= 1.25
	w["dur"] = maxf(0.0, float(w["dur"]) - gasto)
	if float(w["dur"]) <= 0.0:
		message.emit("Sua arma quebrou: %s!" % DB.item_name(w["id"]))
		remove_u(hand_u)
		hand_u = 0
	elif float(w["dur"]) < 15.0:
		_warn("arma_" + str(hand_u), "Sua arma está quase quebrando.", 30.0)


## Conserta a durabilidade de um item com fita adesiva.
func repair(u: int) -> void:
	var f := find(u)
	if f.is_empty() or not f[1].has("dur"):
		return
	var inst: Dictionary = f[1]
	if float(inst["dur"]) >= 100.0:
		message.emit("Não precisa de conserto.")
		return
	if not spend("fita"):
		message.emit("Você precisa de fita adesiva.")
		return
	inst["dur"] = minf(100.0, float(inst["dur"]) + 30.0 + 3.0 * float(level("mecanica")))
	add_xp("mecanica", 3.0)
	message.emit("Consertado: %s (%d%%)." % [DB.item_name(inst["id"]), int(float(inst["dur"]))])


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
	_tick_stamina(delta, moving and env.get("sprinting", false))
	_tick_gear(delta)
	_tick_metabolism(delta, moving)
	_tick_implants(delta, moving or env.get("combat", false))
	_tick_neural(delta)
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


## Analgésico e lanterna.
func _tick_gear(delta: float) -> void:
	pain_t = maxf(0.0, pain_t - delta)
	well_fed_t = maxf(0.0, well_fed_t - delta)
	if light_u != 0:
		var f := find(light_u)
		if f.is_empty():
			light_u = 0
			return
		var lamp: Dictionary = f[1]
		lamp["carga"] = maxf(0.0, float(lamp["carga"]) - 0.4 * delta)
		if float(lamp["carga"]) <= 0.0:
			light_u = 0
			message.emit("A lanterna apagou: pilhas gastas.")


func lantern_on() -> bool:
	return light_u != 0


## Ferramentas que faltam (vazio = tem todas).
func missing_tools(tools: Array) -> String:
	var miss: Array[String] = []
	for t in tools:
		if count(t) <= 0:
			miss.append(DB.item_name(t))
	return ", ".join(miss)


# ---------------------------------------------------------------- ruído e visibilidade
## Raio (isométrico, px) do barulho dos passos.
func step_noise(sprinting: bool, sneaking: bool) -> float:
	var r := 110.0
	if sprinting:
		r = 270.0
	elif sneaking:
		r = 35.0
	r *= 1.0 - 0.06 * float(level("furtividade"))
	if has_trait("barulhento"):
		r *= 1.4
	if load_ratio() > 1.0:
		r *= 1.25
	return r


## Multiplicador da distância em que os infectados te enxergam.
func visibility(sprinting: bool, sneaking: bool) -> float:
	var v := 1.0
	if sneaking:
		v = 0.55
	elif sprinting:
		v = 1.15
	v *= 1.0 - 0.05 * float(level("furtividade"))
	if lantern_on():
		v *= 1.4
	return v


func has_trait(t: String) -> bool:
	return t in traits


# ---------------------------------------------------------------- estamina
func max_stamina() -> float:
	var m := 100.0 + 6.0 * float(resist - 5) + 3.0 * float(level("atletismo"))
	if has_trait("atleta"):
		m *= 1.2
	return m


## Dá para correr? (o dono do personagem consulta para decidir a velocidade)
func can_sprint() -> bool:
	return stamina > 8.0 and load_ratio() < 1.35


## Gasta estamina (golpes, corrida). Devolve false se não tinha o bastante.
func spend_stamina(amount: float) -> bool:
	if has_trait("asmatico"):
		amount *= 1.3
	var ok := stamina >= amount * 0.5
	stamina = maxf(0.0, stamina - amount)
	return ok


func _tick_stamina(delta: float, sprinting: bool) -> void:
	if sprinting and can_sprint():
		var drain := 14.0 * (1.0 - 0.04 * float(level("atletismo")))
		if implant_active("pernas"):
			drain *= 0.7
		if load_ratio() > 1.0:
			drain *= 1.5
		spend_stamina(drain * delta)
		add_xp("atletismo", 0.35 * delta)
		return
	var regen := 9.0 + 0.8 * float(resist - 5)
	if calories < 400.0 or water < 15.0:
		regen *= 0.4
	if load_ratio() > 1.0:
		regen *= 0.5
	if pathogen > 60.0:
		regen *= 0.7
	if well_fed_t > 0.0:
		regen *= 1.5
	stamina = minf(max_stamina(), stamina + regen * delta)


func _tick_metabolism(delta: float, moving: bool) -> void:
	var k := 1.5 if moving else 1.0
	if has_trait("glutao"):
		k *= 1.3
	if has_trait("metabolismo_lento"):
		k *= 0.75
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
	if has_mask() and filter_pct() > 0.0:
		# máscara com vedação ruim vaza: 8% com vedação perfeita, até 60% sem vedação
		f *= lerpf(0.6, 0.08, mask_seal() / 100.0)
	if implant_active("pulmao"):
		f *= 0.35
	if has_trait("pulmao_aco"):
		f *= 0.75
	elif has_trait("pulmao_fraco"):
		f *= 1.25
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
	if has_trait("imune_forte"):
		rate *= 0.85
	if suppress_t > 0.0:
		rate *= 0.5
		pathogen -= 0.4 * delta
		suppress_t -= delta
	if purifier:
		rate *= 0.2
		pathogen -= 4.0 * delta
	pathogen = clampf(pathogen + rate * delta, 0.0, 100.0)
	if has_mask() and filter_pct() > 0.0:
		var mask: Dictionary = equip["mascara"]
		if spore >= 1.0:
			mask["filtro"] = 0.0
			message.emit("O filtro foi destruído pelos esporos!")
		else:
			mask["filtro"] = maxf(0.0, filter_pct() - (spore * spore * 1.2 + spore * 0.2) * delta)
			if filter_pct() <= 0.0:
				message.emit("O filtro da máscara acabou!")
			elif filter_pct() < 15.0:
				_warn("filtro", "O filtro está quase no fim.")
		if mask_seal() < 30.0:
			_warn("vedacao", "A vedação da máscara está ruim: conserte com fita adesiva.", 60.0)
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
	if implant_active("pele"):
		amount *= 0.75
	var limb: Dictionary = limbs[limb_id]
	limb["hp"] = maxf(0.0, float(limb["hp"]) - amount)
	_last_hurt_cause = "Trauma em combate"
	if amount >= 6.0:
		var deep := amount >= 16.0
		limb["wound"] = 2 if (deep or int(limb["wound"]) == 2) else 1
		limb["bleed"] = float(limb["bleed"]) + amount * (0.035 if deep else 0.012) * (1.3 if has_trait("sangue_fino") else 1.0)
		limb["disinfected"] = false
		limb["sutured"] = false
		limb["bandaged"] = false
		limb["heal"] = 0.0
	for slot in implants:
		var def: Dictionary = DB.IMPLANTS[implants[slot]["id"]]
		if def["membro"] == limb_id:
			implants[slot]["integ"] = maxf(0.0, float(implants[slot]["integ"]) - amount * 0.4)
	if limb_id == "cabeca" and has_mask():
		equip["mascara"]["dur"] = maxf(0.0, mask_seal() - amount * 0.8)
	message.emit("Ferimento: %s (-%d)." % [LIMB_NAMES[limb_id], int(amount)])


func melee_damage() -> float:
	var dmg := 14.0 + 1.5 * float(forca - 5)
	var w := weapon_inst()
	if not w.is_empty():
		var bonus := float(Items.def(w["id"]).get("dano", 0.0))
		dmg += bonus * (0.6 if float(w.get("dur", 100.0)) < 25.0 else 1.0)
	if implant_active("braco_d"):
		dmg += 14.0
	dmg *= 1.0 + 0.04 * float(level("combate"))
	if float(limbs["braco_d"]["hp"]) < 30.0 and pain_t <= 0.0:
		dmg *= 0.6
	if stamina < 8.0:
		dmg *= 0.6
	return dmg


## Estamina de um golpe (armas pesadas cansam mais; Luta reduz).
func attack_stamina() -> float:
	var w := weapon_inst()
	var weight := Items.unit_weight(w) if not w.is_empty() else 0.3
	return (6.0 + 3.0 * weight) * (1.0 - 0.05 * float(level("combate")))


## Servidor: um golpe acertou alguém.
func on_melee_hit() -> void:
	add_xp("combate", 2.5)
	wear_weapon()


func speed_mult() -> float:
	var m := 1.0
	for l in ["perna_e", "perna_d"]:
		var hp := float(limbs[l]["hp"])
		if pain_t > 0.0:
			break
		if hp <= 0.0:
			m -= 0.25
		elif hp < 40.0:
			m -= 0.15
	m += 0.015 * float(level("atletismo"))
	if implant_active("pernas"):
		m += 0.12
	if has_trait("lento"):
		m -= 0.08
	if pathogen > 60.0:
		m -= 0.15 * (pathogen - 60.0) / 40.0
	var r := load_ratio()
	if r > 1.0:
		m -= minf(0.45, (r - 1.0) * 0.6)
	return maxf(0.3, m)


# ---------------------------------------------------------------- uso de itens
## Usa um item. ref: id único (int) ou id do item (String, usa a primeira unidade).
func use_item(ref: Variant) -> void:
	var inst := _resolve(ref)
	if inst.is_empty():
		return
	var id: String = inst["id"]
	var u := int(inst.get("u", 0))
	var def: Dictionary = DB.ITEMS[id]
	match String(def["tipo"]):
		"comida":
			if def.get("lata", false) and count("abridor") + count("faca") + count("machete") <= 0:
				message.emit("Você precisa de um abridor de latas, faca ou machete para abrir.")
				return
			var fl := Items.freshness(inst)
			var spoiled := Items.spoiled(inst)
			remove_u(u)
			var cal := float(def["cal"])
			water = minf(100.0, water + float(def.get("agua", 0.0)))
			if def.get("cozido", false) and not spoiled:
				well_fed_t = 180.0
			if spoiled:
				calories = minf(MAX_CAL, calories + cal * 0.4)
				# Culinária reduz a intoxicação (GDD 6.2)
				pathogen = minf(100.0, pathogen + 8.0 * (1.0 - 0.08 * float(level("culinaria"))))
				tainted_t = maxf(tainted_t, 60.0)
				message.emit("Comida estragada! Você se sente mal (%s)." % def["nome"])
			elif inst.has("venc") and fl < 0.35:
				calories = minf(MAX_CAL, calories + cal * 0.75)
				message.emit("Você comeu: %s (passado)." % def["nome"])
			else:
				calories = minf(MAX_CAL, calories + cal)
				message.emit("Você comeu: %s." % def["nome"])
		"bebida":
			remove_u(u)
			water = minf(100.0, water + float(def["agua"]))
			if not def["limpa"]:
				pathogen = minf(100.0, pathogen + 6.0)
				tainted_t = 60.0
				message.emit("Água contaminada! A infecção acelera.")
			else:
				message.emit("Você bebeu água limpa.")
		"mascara", "mochila", "coldre":
			if equip.has(def["tipo"]) and int(equip[def["tipo"]].get("u", -1)) == u:
				unwear(String(def["tipo"]))
			else:
				var part := remove_u(u)
				if not part.is_empty():
					wear(part)
		"filtro":
			if not has_mask():
				message.emit("Vista uma máscara de gás primeiro.")
				return
			remove_u(u)
			equip["mascara"]["filtro"] = 100.0
			message.emit("Filtro novo instalado (100%).")
		"supressor":
			remove_u(u)
			suppress_t = 60.0
			pathogen = maxf(0.0, pathogen - 15.0)
			message.emit("Supressor aplicado: carga -15%.")
		"bateria":
			if battery >= 99.5:
				message.emit("A bateria dos implantes já está cheia.")
				return
			# uma bateria cheia (carga 100) vale 60% da bateria dos implantes
			var amount := minf(100.0 - battery, float(inst["carga"]) * 0.6)
			battery += amount
			inst["carga"] = float(inst["carga"]) - amount / 0.6
			if float(inst["carga"]) <= 0.5:
				remove_u(u)
			message.emit("Implantes recarregados (%d%%)." % int(battery))
		"manual":
			remove_u(u)
			message.emit("Você estudou: %s." % def["nome"])
			add_xp(String(def["skill"]), float(def["xp"]))
		"arma", "arma_fogo":
			hand_u = 0 if hand_u == u else u
			message.emit("Arma %s: %s." % [("na mão" if hand_u == u else "guardada"), def["nome"]])
		"lanterna":
			if light_u == u:
				light_u = 0
				message.emit("Lanterna apagada.")
			elif float(inst.get("carga", 0.0)) <= 0.0:
				message.emit("A lanterna está sem pilhas.")
			else:
				light_u = u
				message.emit("Lanterna acesa: você enxerga melhor, mas é visto de mais longe.")
		"pilha":
			var lamp: Dictionary = {}
			for it in all_items():
				if it["id"] == "lanterna" and (lamp.is_empty() or float(it["carga"]) < float(lamp["carga"])):
					lamp = it
			if lamp.is_empty():
				message.emit("Você não tem lanterna.")
				return
			remove_u(u)
			lamp["carga"] = 100.0
			message.emit("Pilhas novas na lanterna.")
		"cantil":
			if float(inst.get("carga", 0.0)) >= 1.0:
				inst["carga"] = maxf(0.0, float(inst["carga"]) - float(def["uso_carga"]))
				water = minf(100.0, water + 30.0)
				message.emit("Você bebeu do cantil.")
			elif take_item("agua_limpa"):
				inst["carga"] = 100.0
				message.emit("Cantil cheio (uma garrafa de água limpa).")
			else:
				message.emit("O cantil está vazio. Encha com água limpa.")
		"regador":
			if float(inst.get("carga", 0.0)) >= 99.0:
				message.emit("O regador está cheio. Use-o num canteiro [E].")
			elif take_item("agua_suja") or take_item("agua_limpa"):
				inst["carga"] = 100.0
				message.emit("Regador cheio.")
			else:
				message.emit("Encha o regador com uma garrafa de água (limpa ou suja).")
		"analgesico":
			remove_u(u)
			pain_t = 120.0
			message.emit("Analgésico: a dor some por 2 minutos.")
		_:
			message.emit("Use este item em outra aba.")


## Recarrega a arma de fogo da mão com a munição do inventário. Devolve as balas postas.
func reload() -> int:
	var w := weapon_inst()
	if w.is_empty() or not Items.def(w["id"]).has("pente"):
		message.emit("Você não tem arma de fogo na mão.")
		return 0
	var def := Items.def(w["id"])
	var need := int(def["pente"]) - int(float(w.get("mun", 0.0)))
	var ammo: String = def["municao"]
	var n := mini(need, count(ammo))
	if need <= 0:
		message.emit("A arma já está carregada.")
		return 0
	if n <= 0:
		message.emit("Sem %s." % DB.item_name(ammo).to_lower())
		return 0
	take_item(ammo, n)
	w["mun"] = float(w.get("mun", 0.0)) + float(n)
	add_xp("pontaria", 1.0)
	message.emit("Recarregado: %d/%d." % [int(w["mun"]), int(def["pente"])])
	return n


func firearm() -> Dictionary:
	var w := weapon_inst()
	if not w.is_empty() and Items.def(w["id"]).has("pente"):
		return w
	return {}


## Gasta combustível dos galões para abastecer um gerador. Devolve o quanto abasteceu
## (pontos de 0-100 do gerador; um galão cheio vale 50).
func pour_fuel(need: float) -> float:
	var got := 0.0
	for inst in all_items().duplicate():
		if got >= need or inst["id"] != "combustivel":
			continue
		var amount := minf(need - got, float(inst["carga"]) * 0.5)
		got += amount
		inst["carga"] = float(inst["carga"]) - amount / 0.5
		if float(inst["carga"]) <= 0.5:
			remove_u(int(inst["u"]))
	return got


# ---------------------------------------------------------------- medicina
## Mensagem para o paciente e, se for outra pessoa, também para quem trata.
func _say_both(h: SurvivorData, text: String) -> void:
	message.emit(text)
	if h != self:
		h.message.emit(text)


## Trata um membro. 'healer' é quem faz o curativo (os suprimentos e a Medicina são dele);
## null = o próprio sobrevivente. Tratar outra pessoa rende 50% mais experiência.
func treat(limb_id: String, action: String, healer: SurvivorData = null) -> void:
	var h: SurvivorData = healer if healer != null else self
	var xp_k := 1.5 if h != self else 1.0
	var limb: Dictionary = limbs[limb_id]
	if action == "antibiotico":
		if not h.take_item("antibiotico"):
			h.message.emit("Sem antibiótico.")
			return
		antibiotic_t = 120.0
		h.add_xp("medicina", 4.0 * xp_k)
		_say_both(h, "Antibiótico aplicado por 2 minutos.")
		return
	if int(limb["wound"]) == 0:
		h.message.emit("Não há ferida em %s." % LIMB_NAMES[limb_id])
		return
	match action:
		"desinfetar":
			if not h.spend("antisseptico") and not h.spend("alcool"):
				h.message.emit("Sem antisséptico nem álcool.")
				return
			limb["disinfected"] = true
			limb["infection"] = maxf(0.0, float(limb["infection"]) - 15.0)
			h.add_xp("medicina", 6.0 * xp_k)
			_say_both(h, "%s desinfetado." % LIMB_NAMES[limb_id])
		"enfaixar":
			if limb["bandaged"]:
				h.message.emit("Já está enfaixado.")
				return
			if not h.take_item("bandagem") and not h.take_item("gaze"):
				h.message.emit("Sem bandagem nem gaze.")
				return
			limb["bandaged"] = true
			h.add_xp("medicina", 5.0 * xp_k)
			_say_both(h, "%s enfaixado." % LIMB_NAMES[limb_id])
		"suturar":
			if int(limb["wound"]) < 2:
				h.message.emit("Só ferimentos profundos precisam de sutura.")
				return
			if not h.take_item("kit_sutura"):
				h.message.emit("Sem kit de sutura.")
				return
			var chance_fail := maxf(0.0, 0.5 - 0.15 * float(h.level("medicina")))
			if h.has_trait("maos_firmes"):
				chance_fail *= 0.5
			if h == self:
				chance_fail += 0.1  # costurar a si mesmo é mais difícil
			if rng.randf() < chance_fail:
				limb["infection"] = minf(100.0, float(limb["infection"]) + 15.0)
				limb["hp"] = maxf(0.0, float(limb["hp"]) - 5.0)
				h.add_xp("medicina", 5.0 * xp_k)
				_say_both(h, "A sutura falhou! Falta prática em Medicina.")
			else:
				limb["sutured"] = true
				limb["wound"] = 1
				limb["bleed"] = float(limb["bleed"]) * 0.4
				h.add_xp("medicina", 16.0 * xp_k)
				_say_both(h, "Sutura bem-sucedida em %s." % LIMB_NAMES[limb_id])


# ---------------------------------------------------------------- cibernética
## Implantes gerais (tudo menos o processador do cérebro).
func general_count() -> int:
	var n := 0
	for slot in implants:
		if slot != "cerebro":
			n += 1
	return n


## Quantos implantes gerais o cérebro suporta agora (o processador precisa estar ligado).
func neural_capacity() -> int:
	if implant_active("cerebro"):
		return int(DB.IMPLANTS[implants["cerebro"]["id"]].get("slots", DB.NEURAL_BASE))
	return DB.NEURAL_BASE


## Sobrecarga sináptica: mais implantes do que o cérebro suporta, ou estresse alto demais.
func overloaded() -> bool:
	return general_count() > neural_capacity() or synaptic >= 80.0


func _tick_neural(delta: float) -> void:
	var target := 0.0
	for slot in implants:
		if slot != "cerebro" and implant_active(slot):
			target += float(DB.IMPLANTS[implants[slot]["id"]].get("neuro", 10.0))
	target *= 1.0 - 0.06 * float(level("cibernetica"))
	if implant_active("cerebro"):
		target *= 0.6
	if heat > 70.0:
		target += 20.0
	var over := general_count() > neural_capacity()
	if over:
		target = 100.0
	synaptic = move_toward(synaptic, clampf(target, 0.0, 100.0), (6.0 if synaptic < target else 3.0) * delta)
	if overloaded():
		heat = minf(100.0, heat + 0.4 * delta)
		if over:
			_hurt_internal("cabeca", 0.15 * delta, "Colapso sináptico")
			_warn("sobrecarga", "SOBRECARGA SINÁPTICA! Implantes demais para o seu cérebro (%d/%d)." % [general_count(), neural_capacity()], 20.0)
		else:
			_warn("sobrecarga", "SOBRECARGA SINÁPTICA! O estresse neural está alto demais.", 20.0)
	elif synaptic > 60.0:
		_warn("neural", "Estresse sináptico alto: sua visão tremula.", 45.0)


## O sobrevivente pode fazer ações complexas (fabricar, tratar, operar, construir)?
func complex_block() -> String:
	if overloaded():
		return "Sobrecarga sináptica: suas mãos não obedecem."
	return ""


## Cirurgia de implante. 'surgeon' opera (o implante, o kit e as habilidades são dele);
## null = o próprio sobrevivente se opera (o encaixe sai imperfeito: integridade 80%).
func install_implant(item_id: String, surgeon: SurvivorData = null) -> void:
	var h: SurvivorData = surgeon if surgeon != null else self
	if not DB.IMPLANTS.has(item_id) or h.count(item_id) <= 0:
		return
	var def: Dictionary = DB.IMPLANTS[item_id]
	var slot: String = def["slot"]
	if implants.has(slot):
		h.message.emit("Esse encaixe já tem um implante.")
		return
	if h.count("kit_cirurgico") <= 0:
		h.message.emit("Você precisa de um kit cirúrgico.")
		return
	h.take_item("kit_cirurgico")
	h.take_item(item_id)
	# sem suporte neural o corpo rejeita o implante na hora (GDD 4)
	if slot != "cerebro" and general_count() >= neural_capacity():
		damage_limb(def["membro"], 20.0)
		synaptic = 100.0
		h.add_xp("cibernetica", 6.0)
		if h != self:
			h.message.emit("O corpo do paciente rejeitou o implante: ele não tem suporte neural.")
		message.emit("REJEIÇÃO IMEDIATA: seu cérebro não suporta mais um implante (%d/%d). O implante foi perdido." % [general_count(), neural_capacity()])
		return
	var deficit := 0
	for k in def["req"]:
		deficit += maxi(0, int(def["req"][k]) - h.level(k))
	if deficit == 0:
		implants[slot] = {"id": item_id, "integ": 100.0 if h != self else 80.0}
		h.add_xp("medicina", 30.0)
		h.add_xp("cibernetica", 30.0)
		_say_both(h, "Implante instalado com sucesso: %s%s." % [DB.item_name(item_id),
			"" if h != self else " (operar a si mesmo deixou o encaixe imperfeito: 80%)"])
		return
	var r := rng.randf()
	var death_p := 0.0 if deficit < 2 else 0.30
	var crit_p := 0.35 if deficit < 2 else 0.45
	if h.has_trait("maos_firmes"):
		crit_p *= 0.6
	if r < death_p:
		_hurt_internal("torso", 999.0, "Cirurgia fracassada")
		message.emit("A cirurgia deu errado de forma fatal...")
	elif r < death_p + crit_p:
		damage_limb("torso", 35.0)
		message.emit("FALHA CRÍTICA na cirurgia! O implante foi destruído.")
		add_xp("medicina", 10.0)
	else:
		implants[slot] = {"id": item_id, "integ": 55.0}
		_say_both(h, "Instalado com muita sorte, mas mal encaixado (integridade 55%).")
		h.add_xp("medicina", 12.0)
		h.add_xp("cibernetica", 12.0)


## Remove um implante (gasta um kit cirúrgico). O item volta para o inventário, a não ser
## que esteja destruído. Tirar o processador com vários implantes gerais causa sobrecarga.
func remove_implant(slot: String, surgeon: SurvivorData = null) -> void:
	var h: SurvivorData = surgeon if surgeon != null else self
	if not implants.has(slot):
		return
	if h.count("kit_cirurgico") <= 0:
		h.message.emit("Você precisa de um kit cirúrgico.")
		return
	h.take_item("kit_cirurgico")
	var imp: Dictionary = implants[slot]
	var def: Dictionary = DB.IMPLANTS[imp["id"]]
	implants.erase(slot)
	var fail := maxf(0.0, 0.35 - 0.08 * float(h.level("cibernetica")))
	if rng.randf() < fail:
		damage_limb(def["membro"], 18.0)
		_say_both(h, "A remoção foi brusca: o implante quebrou e feriu %s." % LIMB_NAMES[def["membro"]].to_lower())
	elif float(imp["integ"]) < 15.0:
		_say_both(h, "Implante removido, mas destruído demais para reaproveitar.")
	else:
		h.give(imp["id"])
		_say_both(h, "Implante removido: %s." % DB.item_name(imp["id"]))
	h.add_xp("cibernetica", 8.0)
	if slot == "cerebro" and general_count() > DB.NEURAL_BASE:
		message.emit("Sem o processador, seu cérebro não suporta os implantes!")


func maintain_implant(slot: String) -> void:
	if not implants.has(slot):
		return
	if not take_item("sucata"):
		message.emit("Manutenção precisa de 1 sucata.")
		return
	var chance_fail := 0.3 if level("cibernetica") < 1 else 0.0
	if rng.randf() < chance_fail:
		message.emit("A manutenção falhou (sucata perdida).")
		return
	implants[slot]["integ"] = minf(100.0, float(implants[slot]["integ"]) + 35.0)
	add_xp("cibernetica", 10.0)
	message.emit("Manutenção feita: %s." % DB.IMPLANT_SLOTS[slot])


func craft(recipe: String) -> void:
	var def: Dictionary = DB.CRAFTS[recipe]
	if not meets(def["req"]):
		message.emit("Habilidade insuficiente: %s." % DB.req_text(def["req"]))
		return
	if not can_afford(def["custo"]):
		message.emit("Faltam materiais: %s." % DB.cost_text(def["custo"]))
		return
	var miss := missing_tools(def.get("ferramentas", []))
	if miss != "":
		message.emit("Falta ferramenta: %s." % miss)
		return
	pay(def["custo"])
	var out_id := String(def.get("saida", recipe))
	if def.has("estacao") and String(Items.def(out_id).get("tipo", "")) == "comida":
		# cozinhar pode queimar sem prática de Culinária
		var burn := maxf(0.0, 0.2 - 0.05 * float(level("culinaria")))
		if rng.randf() < burn:
			add_xp("culinaria", 3.0)
			message.emit("Queimou! Os ingredientes foram perdidos (%s)." % def["nome"])
			return
	give(out_id, int(def.get("qtd", 1)))
	add_xp_map(def["xp"])
	message.emit("Fabricado: %s." % def["nome"])


# ---------------------------------------------------------------- persistência
func to_dict() -> Dictionary:
	return {"nome": nome, "pathogen": pathogen, "calories": calories,
		"water": water, "blood": blood, "limbs": limbs.duplicate(true), "skills": skills.duplicate(true),
		"bags": bags.duplicate(true), "equip": equip.duplicate(true), "hand_u": hand_u, "next_u": _next_u,
		"implants": implants.duplicate(true), "suppress_t": suppress_t, "tainted_t": tainted_t,
		"antibiotic_t": antibiotic_t, "battery": battery, "heat": heat, "time_alive": time_alive,
		"forca": forca, "resist": resist, "traits": traits.duplicate(), "stamina": stamina, "synaptic": synaptic,
		"pain_t": pain_t, "light_u": light_u, "well_fed_t": well_fed_t}


static func from_dict(src: Dictionary) -> SurvivorData:
	var d := SurvivorData.new()
	d.nome = str(src.get("nome", "Sobrevivente"))
	d.pathogen = float(src.get("pathogen", 10.0))
	d.calories = float(src.get("calories", 1600.0))
	d.water = float(src.get("water", 80.0))
	d.blood = float(src.get("blood", 100.0))
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
	var src_skills: Dictionary = src.get("skills", {}).duplicate()
	# habilidades das versões antigas: Engenharia vira Eletrônica, Lógica vira Metalurgia
	for old in [["engenharia", "eletronica"], ["logica", "metalurgia"]]:
		if src_skills.has(old[0]) and not src_skills.has(old[1]):
			src_skills[old[1]] = src_skills[old[0]]
	for s in DB.SKILLS:
		if src_skills.has(s):
			d.skills[s] = {"lv": int(src_skills[s].get("lv", 0)), "xp": float(src_skills[s].get("xp", 0.0))}
	d.forca = clampi(int(src.get("forca", 5)), DB.ATTR_MIN, DB.ATTR_MAX)
	d.resist = clampi(int(src.get("resist", 5)), DB.ATTR_MIN, DB.ATTR_MAX)
	for t in src.get("traits", []):
		if DB.TRAITS.has(str(t)):
			d.traits.append(str(t))
	d.stamina = float(src.get("stamina", d.max_stamina()))
	d.synaptic = float(src.get("synaptic", 0.0))
	d.pain_t = float(src.get("pain_t", 0.0))
	d.light_u = int(src.get("light_u", 0))
	d.well_fed_t = float(src.get("well_fed_t", 0.0))
	if src.has("bags"):
		var sb: Dictionary = src["bags"]
		for c in d.bags:
			d.bags[c] = Items.sanitize(sb.get(c, []))
		var se: Dictionary = src.get("equip", {})
		for slot in d.equip:
			var lst := Items.sanitize([se[slot]]) if se.get(slot) is Dictionary and not se[slot].is_empty() else []
			d.equip[slot] = lst[0] if not lst.is_empty() else {}
		d.hand_u = int(src.get("hand_u", 0))
		d._next_u = int(src.get("next_u", 1))
	else:
		d._migrate_v3(src)
	var src_imp: Dictionary = src.get("implants", {})
	for k in src_imp:
		d.implants[str(k)] = {"id": str(src_imp[k]["id"]), "integ": float(src_imp[k]["integ"])}
	return d


## Sobrevivente salvo na versão 3 (inventário {id: n}, máscara ligada/desligada e filtro):
## converte para recipientes. Ganha uma mochila escolar para não perder os itens.
func _migrate_v3(src: Dictionary) -> void:
	var inv: Dictionary = src.get("inventory", {})
	var counts := {}
	for k in inv:
		if DB.ITEMS.has(str(k)):
			counts[str(k)] = int(inv[k])
	equip["mochila"] = Items.make("mochila_escolar")[0]
	equip["mochila"]["u"] = _next_u
	_next_u += 1
	if bool(src.get("mask_on", false)) and int(counts.get("mascara", 0)) > 0:
		counts["mascara"] = int(counts["mascara"]) - 1
		var mask: Dictionary = Items.make("mascara")[0]
		mask["filtro"] = float(src.get("filter", 0.0))
		mask["u"] = _next_u
		_next_u += 1
		equip["mascara"] = mask
	var left := receive(Items.from_counts(counts))
	for inst in left:
		_put("bolsos", inst)
	var wid := str(src.get("weapon", ""))
	if wid != "":
		var w := first_of(wid)
		hand_u = int(w.get("u", 0))

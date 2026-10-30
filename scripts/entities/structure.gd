class_name Structure
extends StaticBody2D
## Objeto de uma célula: prédios do mapa (edificio) e as construções da aba Utilidades e
## Decoração (gerador, eólico, baterias, purificador, torre, selagem, bancada, mesa de reparos,
## fogareiro, coletor, canteiro, cama, luzes e móveis). A energia ("powered") é decidida pelo
## anfitrião na rede de energia (World._power_step) e chega aos clientes pelo estado extra.

## Objetos com [E].
const INTERACTIVE := ["gerador", "purificador", "vedacao", "torre", "canteiro", "fogareiro", "eolico", "bateria_casa",
	"coletor", "cama", "bancada", "mesa_reparo", "luminaria", "poste", "letreiro", "fornalha"]
## Estações: [E] abre a janela de fabricação (ou de consertos) dela.
const STATIONS := ["bancada", "fogareiro", "fornalha", "mesa_reparo"]
## Objetos com quadro "ligado" na coluna 0 e "desligado" na 1.
const ON_OFF := ["gerador", "purificador", "vedacao", "bateria_casa", "luminaria", "poste", "letreiro"]
const MAX_MODS := 5
const COLLECTOR_MAX := 8

var kind := "edificio"
var cell := Vector2i.ZERO
var world: World
var powered := false
var fuel := 0.0
var open := false
var eternal := false
## Defesa de uma vila (torre ou armadilha da vila; -1 = do jogador).
var vila := -1
var art := ""
var art_variant := 0
var fp := Vector2i.ONE
## Canteiro (fase 8): cultura, progresso 0-100, regado até (relógio), última conta, morto.
var crop := ""
var grow := 0.0
var water_until := 0.0
var crop_last := 0.0
var dead := false
var _crop_t := 0.0
## Fator de Agricultura de quem plantou.
var _agri_k := 1.0

## Eólico: módulos do mastro e quanto o vento chega aqui. Banco de baterias: carga (W·s).
## Coletor: água acumulada. Rede: produção, consumo e bateria (resumo para os avisos).
var mods := 1
var aberto := 1.0
var charge := 0.0
var water := 0
var output := 0.0
var demand := 0.0
var grid := {}
var _light: PointLight2D
var _rain_t := 0.0

var _shape: CollisionPolygon2D
var _power_t := 0.0
var _cd := 0.0
var _tracer := Vector2.ZERO
var _tracer_t := 0.0
var _aim := 1
var _fade_rect := Rect2()
var _fade_t := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	set_process(false)
	_shape = CollisionPolygon2D.new()
	_shape.polygon = PackedVector2Array([Vector2(0, -17), Vector2(35, 0), Vector2(0, 17), Vector2(-35, 0)])
	if kind == "edificio":
		_setup_building()
	add_child(_shape)
	match kind:
		"gerador":
			add_to_group("generators")
			if eternal:
				fuel = 100.0
		"purificador":
			add_to_group("purifiers")
		"vedacao":
			add_to_group("seals")
		"torre":
			add_to_group("turrets")
	if kind in INTERACTIVE:
		add_to_group("interactable")
	if kind in STATIONS:
		add_to_group("stations")
	if kind != "edificio":
		add_to_group("station_" + kind)
	var def: Dictionary = DB.BUILDS.get(kind, {})
	if vila < 0 and (kind == "gerador" or def.has("gera") or def.has("consome") or def.has("capacidade")):
		add_to_group("power")
	if def.get("andavel", false):
		_shape.disabled = true
	if def.has("luz"):
		add_to_group("lights")
		_light = PointLight2D.new()
		_light.texture = World.light_texture()
		_light.color = def["luz"][0]
		_light.texture_scale = float(def["luz"][1])
		_light.position = Vector2(0, -20)
		_light.enabled = false
		add_child(_light)
	if eternal and kind == "gerador":
		powered = true
	_apply_open()
	_refresh_power()


## Insumo que a construção gasta para funcionar (DB.BUILDS[kind]["insumo"]; {} = nenhum).
## 'fuel' guarda o nível (0-100). O gerador usa combustível pela lógica própria dele.
static func supply_of(k: String) -> Dictionary:
	return DB.BUILDS.get(k, {}).get("insumo", {})


## Precisa de insumo para funcionar? As defesas das vilas não precisam.
func needs_supply() -> bool:
	return vila < 0 and not supply_of(kind).is_empty()


func supply_text() -> String:
	var sup := supply_of(kind)
	if kind == "torre":
		return "munição %d" % int(round(fuel / float(sup["tiro"])))
	return "%s %d%%" % [sup["nome"], int(fuel)]


## Servidor: põe o insumo que o jogador tiver, até encher.
func refill(player: Player) -> void:
	var sup := supply_of(kind)
	var per := float(sup["por_item"])
	if fuel > 100.0 - per * 0.5:
		Game.tell(player.peer, "%s já está cheio (%s)." % [DB.BUILDS[kind]["nome"], supply_text()])
		return
	var n := 0
	for it: String in sup["itens"]:
		while fuel <= 100.0 - per * 0.5 and player.data.take_item(it):
			fuel = minf(100.0, fuel + per)
			n += 1
	if n == 0:
		var names: Array[String] = []
		for it2: String in sup["itens"]:
			names.append(DB.item_name(it2).to_lower())
		Game.tell(player.peer, "Você precisa de %s." % " ou ".join(names))
		return
	Game.tell(player.peer, "%s: %s." % [DB.BUILDS[kind]["nome"], supply_text()])
	_refresh_power()
	world.structure_changed(self)


## Servidor: gasta insumo de uma estação (receita no fogareiro ou na fornalha).
func use_supply(amount: float) -> bool:
	if fuel + 0.01 < amount:
		return false
	fuel = maxf(0.0, fuel - amount)
	world.structure_changed(self)
	queue_redraw()
	return true


func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in fp.x:
		for j in fp.y:
			out.append(cell + Vector2i(i, j))
	return out


## Edifício do pacote: colisão na pegada e sprite alinhado pelo vértice inferior da base.
## O nó fica no centro da pegada (chave de ordenação em profundidade).
func _setup_building() -> void:
	var w := float(fp.x)
	var d := float(fp.y)
	var hw := World.HALF_W * 0.5
	var hh := World.HALF_H * 0.5
	var k := 0.94
	_shape.polygon = PackedVector2Array([
		Vector2(-hw * (w - d), -hh * (w + d)) * k, Vector2(hw * (w + d), hh * (w - d)) * k,
		Vector2(hw * (w - d), hh * (w + d)) * k, Vector2(-hw * (w + d), hh * (d - w)) * k])
	y_sort_enabled = true
	ArtDB.add_building_strips(self, art, art_variant, fp)
	for c in get_children():
		if c is Sprite2D:
			var sp := c as Sprite2D
			var r := Rect2(sp.position + sp.offset, sp.region_rect.size)
			_fade_rect = r if _fade_rect.size == Vector2.ZERO else _fade_rect.merge(r)
	set_process(true)


func _process(delta: float) -> void:
	_update_fade(delta)


## Prédios ficam translúcidos quando o jogador está atrás deles (na área do desenho e
## acima da borda da frente da base), para ele não sumir atrás de prédios altos.
func _update_fade(delta: float) -> void:
	_fade_t -= delta
	if _fade_t > 0.0 and is_equal_approx(modulate.a, 1.0):
		return
	_fade_t = 0.15
	var target := 1.0
	var pl: Player = world.local_player() if world != null else null
	if pl != null and not pl.is_dead():
		var lp := pl.position - position + Vector2(0, -20)
		if _fade_rect.grow(-4).has_point(lp):
			var w := float(fp.x)
			var d := float(fp.y)
			var hw := World.HALF_W * 0.5
			var hh := World.HALF_H * 0.5
			var front := ArtDB._front_y(lp.x, Vector2(-hw * (w + d), hh * (d - w)),
				Vector2(hw * (w - d), hh * (w + d)), Vector2(hw * (w + d), hh * (w - d)))
			if pl.position.y - position.y < front:
				target = 0.38
	modulate.a = move_toward(modulate.a, target, delta * 6.0 + 0.15)


func _apply_open() -> void:
	_shape.set_deferred("disabled", open)


## Luzes acendem quando têm energia e está escuro.
func _refresh_power() -> void:
	if _light != null and world != null:
		var dk := world.darkness()
		_light.enabled = powered and dk > 0.05
		_light.energy = 1.5 * dk
	queue_redraw()


## Estado extra replicado (energia, módulos, carga, água, canteiro, resumo da rede).
func state_extra() -> Dictionary:
	var d := {"pw": powered, "gr": grid}
	match kind:
		"eolico":
			d["mods"] = mods
			d["aberto"] = aberto
		"bateria_casa":
			d["carga"] = charge
		"coletor":
			d["agua"] = water
		"canteiro":
			d.merge(crop_state(), true)
	return d


func apply_extra(d: Dictionary) -> void:
	if d.has("pw"):
		powered = bool(d["pw"])
	if d.has("gr"):
		grid = d["gr"]
	mods = int(d.get("mods", mods))
	aberto = float(d.get("aberto", aberto))
	charge = float(d.get("carga", charge))
	water = int(d.get("agua", water))
	if kind == "canteiro" and d.has("crop"):
		apply_crop(d)
	_refresh_power()


func _grid_text() -> String:
	if grid.is_empty():
		return ""
	var t := " · rede %d/%d W" % [int(grid.get("gp", 0)), int(grid.get("gc", 0))]
	if int(grid.get("gb", -1)) >= 0:
		t += " · baterias %d%%" % int(grid["gb"])
	return t


func prompt() -> String:
	match kind:
		"porta":
			return "[E] %s a porta" % ("Fechar" if open else "Abrir")
		"gerador":
			if eternal:
				return "Gerador do abrigo (250 W, sem combustível)" + _grid_text()
			return "[E] Abastecer gerador (combustível %d%%)%s" % [int(fuel), _grid_text()]
		"torre" when vila >= 0:
			return "Torre da vila: %s" % ("vigiando" if powered else "desligada (liga quando a cerca chega ao nível 2)")
		"purificador", "torre", "vedacao":
			var st := "ligado" if powered else ("sem " + String(supply_of(kind)["nome"]) if fuel <= 0.0 else "sem energia")
			return "[E] %s · %s · %s%s" % ["Municiar" if kind == "torre" else "Pôr filtro", supply_text(), st, _grid_text()]
		"luminaria", "poste", "letreiro":
			return "%s: %s%s" % [DB.BUILDS[kind]["nome"], "ligado" if powered else "sem energia", _grid_text()]
		"fogareiro", "fornalha":
			return "[E] Usar %s · %s" % [String(DB.BUILDS[kind]["nome"]).to_lower(), supply_text()]
		"bancada":
			return "[E] Usar bancada de fabricação"
		"mesa_reparo":
			return "[E] Usar mesa de reparos"
		"eolico":
			var w := "[E] Subir o mastro (%d/%d módulos)" % [mods, MAX_MODS] if mods < MAX_MODS else "Eólico no topo (%d módulos)" % mods
			return "%s · vento aqui %d%%%s" % [w, int(aberto * 100.0), _grid_text()]
		"bateria_casa":
			return "Banco de baterias: %d%%%s" % [int(charge / float(DB.BUILDS["bateria_casa"]["capacidade"]) * 100.0), _grid_text()]
		"coletor":
			return "[E] Recolher água da chuva (%d)" % water if water > 0 else "Coletor de chuva: vazio"
		"cama":
			return "[E] Descansar"
		"canteiro":
			if dead:
				return "[E] Limpar canteiro (a plantação morreu)"
			if crop == "":
				return "[E] Plantar (enxada + sementes)"
			if grow >= 100.0:
				return "[E] Colher %s" % DB.item_name(crop).to_lower()
			var wet := water_until > Game.play_time
			return "[E] %s · %s %d%% · %s" % ["Regar" if not wet else "Canteiro", DB.item_name(crop).to_lower(), int(grow),
				"regado" if wet else "SECO"]
	return ""


## Servidor: o canteiro cresce enquanto está regado e o ar está limpo. A conta é feita pelo
## tempo (vale também para o tempo em que o chunk ficou descarregado).
func crop_tick() -> void:
	var now := Game.play_time
	if crop == "" or dead:
		crop_last = now
		return
	var wet_end := minf(now, water_until)
	var dt := maxf(0.0, wet_end - crop_last)
	crop_last = now
	if dt <= 0.0 or grow >= 100.0:
		return
	var spore := world.spore_at(position) if world != null else 0.0
	if spore >= 0.6:
		dead = true
		return
	if spore >= 0.35:
		return
	var rate := 100.0 / float(DB.CROPS[crop]["tempo"])
	grow = minf(100.0, grow + dt * rate * _agri_k)


func crop_state() -> Dictionary:
	return {"crop": crop, "grow": grow, "water_until": water_until, "crop_last": crop_last, "dead": dead, "agri": _agri_k}


func apply_crop(d: Dictionary) -> void:
	crop = str(d.get("crop", ""))
	grow = float(d.get("grow", 0.0))
	water_until = float(d.get("water_until", 0.0))
	crop_last = float(d.get("crop_last", Game.play_time))
	dead = bool(d.get("dead", false))
	_agri_k = float(d.get("agri", 1.0))
	queue_redraw()


func _interact_planter(player: Player) -> void:
	crop_tick()
	var d := player.data
	if dead:
		crop = ""
		dead = false
		grow = 0.0
		Game.tell(player.peer, "Você limpou o canteiro.")
	elif crop == "":
		if d.count("enxada") <= 0:
			Game.tell(player.peer, "Você precisa de uma enxada para preparar a terra.")
			return
		var seed_id := ""
		for c in DB.CROPS:
			if d.count(DB.CROPS[c]["semente"]) > 0:
				seed_id = DB.CROPS[c]["semente"]
				crop = c
				break
		if seed_id == "":
			Game.tell(player.peer, "Você não tem sementes.")
			return
		d.take_item(seed_id)
		grow = 0.0
		water_until = Game.play_time
		crop_last = Game.play_time
		_agri_k = 1.0 + 0.06 * float(d.level("agricultura"))
		d.add_xp("agricultura", 3.0)
		Game.tell(player.peer, "Plantado: %s. Regue para crescer." % DB.item_name(crop).to_lower())
	elif grow >= 100.0:
		var def: Dictionary = DB.CROPS[crop]
		var agri := d.level("agricultura")
		var n: int = randi_range(int(def["colheita"][0]), int(def["colheita"][1])) + agri / 3
		d.give(crop, n)
		if randf() < 0.5 + 0.05 * float(agri):
			d.give(def["semente"], 1)
		d.add_xp("agricultura", 8.0)
		Game.tell(player.peer, "Colheita: %d x %s." % [n, DB.item_name(crop)])
		crop = ""
		grow = 0.0
	else:
		var bonus := 150.0 * (1.0 + 0.05 * float(d.level("agricultura")))
		var can: Dictionary = {}
		for it in d.all_items():
			if it["id"] == "regador" and float(it.get("carga", 0.0)) >= 25.0:
				can = it
				break
		if not can.is_empty():
			can["carga"] = float(can["carga"]) - 25.0
		elif not d.take_item("agua_suja") and not d.take_item("agua_limpa"):
			Game.tell(player.peer, "Você precisa de um regador cheio ou de uma garrafa de água.")
			return
		water_until = maxf(Game.play_time, water_until) + bonus
		d.add_xp("agricultura", 1.5)
		Game.tell(player.peer, "Canteiro regado (%d s de água)." % int(water_until - Game.play_time))
	world.structure_changed(self)
	queue_redraw()


## Servidor: interação de um jogador; o novo estado vai para todos os peers.
func interact(player: Player) -> void:
	match kind:
		"canteiro":
			_interact_planter(player)
			return
		"purificador", "torre", "vedacao":
			if needs_supply():
				refill(player)
			else:
				Game.tell(player.peer, prompt() + ".")
			return
		"fogareiro", "bancada", "mesa_reparo", "fornalha":
			# a janela da estação abre no cliente; aqui não há o que fazer
			return
		"bateria_casa", "luminaria", "poste", "letreiro":
			Game.tell(player.peer, prompt() + ".")
			return
		"eolico":
			if mods >= MAX_MODS:
				Game.tell(player.peer, "O mastro já está no máximo.")
				return
			var cost := {"metal": 2, "sucata": 2}
			if not world.afford_near(player, cost):
				Game.tell(player.peer, "Cada módulo do mastro custa 2 metais e 2 sucatas.")
				return
			world.pay_near(player, cost)
			mods += 1
			player.data.add_xp("metalurgia", 4.0)
			Game.tell(player.peer, "Mastro mais alto: %d módulos." % mods)
			world.structure_changed(self)
			return
		"coletor":
			if water <= 0:
				Game.tell(player.peer, "Vazio. Ele enche quando chove.")
				return
			player.data.give("agua_suja", water)
			Game.tell(player.peer, "Você recolheu %d garrafas de água da chuva (contaminada: ferva)." % water)
			water = 0
			world.structure_changed(self)
			return
		"cama":
			var d := player.data
			d.stamina = d.max_stamina()
			d.blood = minf(100.0, d.blood + 5.0)
			Game.tell(player.peer, "Você descansou. Sobreviventes novos da equipe acordam numa cama.")
			return
		"porta":
			open = not open
			_apply_open()
			queue_redraw()
			world.structure_changed(self)
			world.make_noise(position, 140.0)
		"gerador":
			if eternal:
				Game.tell(player.peer, "O gerador do abrigo funciona sem parar.")
			elif fuel >= 99.5:
				Game.tell(player.peer, "O gerador já está cheio.")
			elif player.data.count("combustivel") > 0:
				fuel = minf(100.0, fuel + player.data.pour_fuel(100.0 - fuel))
				Game.tell(player.peer, "Gerador abastecido (%d%%)." % int(fuel))
				_refresh_power()
				world.structure_changed(self)
			else:
				Game.tell(player.peer, "Você precisa de um galão de combustível.")
		_:
			Game.tell(player.peer, prompt() + (". Ligue-o a um gerador abastecido." if not powered else "."))


## Estado recebido do servidor.
func apply_state(new_fuel: float, new_open: bool) -> void:
	fuel = new_fuel
	if new_open != open:
		open = new_open
		_apply_open()
	_refresh_power()
	queue_redraw()


## Disparo da torre (efeito visual em todos os peers).
func show_shot(aim: int, target: Vector2) -> void:
	_aim = aim
	_tracer = target - position + Vector2(0, -18)
	_tracer_t = 0.12
	queue_redraw()


func _physics_process(delta: float) -> void:
	if kind == "edificio":
		return
	var server := Net.is_server()
	if server and kind == "canteiro":
		_crop_t -= delta
		if _crop_t <= 0.0:
			_crop_t = 2.0
			var before_g := int(grow)
			var was_dead := dead
			crop_tick()
			if int(grow) != before_g or dead != was_dead:
				world.structure_changed(self)
				queue_redraw()
	if server and (kind == "coletor" or kind == "canteiro") and world.is_raining():
		_rain_t -= delta
		if _rain_t <= 0.0:
			_rain_t = 25.0
			if kind == "coletor" and water < COLLECTOR_MAX:
				water += 1
				world.structure_changed(self)
			elif kind == "canteiro" and crop != "" and not dead:
				# a chuva rega
				water_until = maxf(water_until, Game.play_time + 30.0)
				world.structure_changed(self)
	_power_t -= delta
	if _power_t <= 0.0:
		_power_t = 0.5
		_refresh_power()
	if kind == "armadilha" and server:
		_cd -= delta
		if _cd <= 0.0:
			_cd = 0.4
			for n in get_tree().get_nodes_in_group("infected"):
				var e2 := n as Infected
				var o2 := e2.position - position
				if Vector2(o2.x, o2.y * 2.0).length() < 26.0:
					e2.take_damage(7.0, self)
	if kind == "torre":
		_cd -= delta
		_tracer_t = maxf(0.0, _tracer_t - delta)
		var armed := not needs_supply() or fuel >= float(supply_of(kind)["tiro"]) - 0.01
		if server and powered and armed and _cd <= 0.0:
			var best: Infected = null
			var best_d := 290.0
			for n in get_tree().get_nodes_in_group("infected"):
				var e := n as Infected
				var off := e.position - position
				var d := Vector2(off.x, off.y * 2.0).length()
				if d < best_d:
					best_d = d
					best = e
			if best != null:
				var aim := GenArt.facing_of(best.position - position)
				world.turret_fx.rpc(cell.x, cell.y, aim, best.position)
				show_shot(aim, best.position)
				best.take_damage(20.0, self)
				world.make_noise(position, 520.0)
				_cd = 1.0
				if needs_supply():
					fuel = maxf(0.0, fuel - float(supply_of(kind)["tiro"]))
					world.structure_changed(self)
		if _tracer_t <= 0.0 and _tracer != Vector2.ZERO:
			_tracer = Vector2.ZERO
			queue_redraw()


func to_dict() -> Dictionary:
	return {"kind": kind, "cell": [cell.x, cell.y], "fuel": fuel, "open": open}


# ------------------------------------------------------------------ visual
func _draw() -> void:
	if kind == "vedacao" and powered:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, World.SEAL_RADIUS, 0.0, TAU, 64, Color(0.32, 0.9, 1.0, 0.3), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if kind == "edificio" or not GenCatalog.SHEETS.has(kind):
		return
	var row := 0
	var col := 0
	match kind:
		"eolico":
			col = clampi(mods, 1, MAX_MODS) - 1
		"coletor":
			col = 0 if water > 0 else 1
		_ when kind in ON_OFF:
			col = 0 if powered else 1
		"canteiro":
			if dead:
				col = 4
			elif crop == "":
				col = 0
			elif grow >= 100.0:
				col = 3
			else:
				col = 1 if grow < 40.0 else 2
		"fogareiro", "fornalha":
			col = 0 if fuel > 0.0 else 1
		"torre":
			row = 0 if powered else 1
			col = _aim
	GenArt.draw_frame(self, kind, row, col)
	if kind == "torre" and _tracer_t > 0.0:
		var muzzle := Vector2.from_angle(float(_aim) * PI / 4.0) * Vector2(18, 9) + Vector2(0, -28)
		draw_line(muzzle, _tracer, Color("#ffe066"), 2.0)

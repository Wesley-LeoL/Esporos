class_name Structure
extends StaticBody2D
## Estrutura sólida: prédios do pacote (edificio), paredes, portas, gerador, purificador,
## torre e selagem de ar. As construções usam os sprites de assets/art/generated/structures.

const CONSUMERS := ["purificador", "torre", "vedacao"]
const SPRITES := ["parede", "porta", "gerador", "purificador", "torre", "vedacao"]

var kind := "parede"
var cell := Vector2i.ZERO
var world: World
var powered := false
var fuel := 0.0
var open := false
var eternal := false
var art := ""
var art_variant := 0
var fp := Vector2i.ONE
## Prédio do Town Sampler (nome no ExtraCatalog). Vazio = prédio do pacote FreeSample.
var town := ""

var _shape: CollisionPolygon2D
var _power_t := 0.0
var _cd := 0.0
var _tracer := Vector2.ZERO
var _tracer_t := 0.0
var _aim := 1
var _strips: Array[Sprite2D] = []
var _frame_w := 0.0
var _frame := 0
var _anim_t := 0.0
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
			add_to_group("interactable")
			if eternal:
				fuel = 100.0
		"purificador":
			add_to_group("purifiers")
			add_to_group("interactable")
		"vedacao":
			add_to_group("seals")
			add_to_group("interactable")
		"torre":
			add_to_group("turrets")
			add_to_group("interactable")
		"porta":
			add_to_group("interactable")
	_apply_open()
	_refresh_power()


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
	if town != "":
		_setup_town()
	else:
		ArtDB.add_building_strips(self, art, art_variant, fp)
	for c in get_children():
		if c is Sprite2D:
			var sp := c as Sprite2D
			var r := Rect2(sp.position + sp.offset, sp.region_rect.size)
			_fade_rect = r if _fade_rect.size == Vector2.ZERO else _fade_rect.merge(r)
	set_process(true)


## Prédio do Town Sampler: versão noturna; se houver tira de animação (janelas acendendo
## e apagando), usa a tira e troca o quadro a cada FRAME_MS, com fase aleatória.
func _setup_town() -> void:
	var e: Dictionary = ExtraCatalog.BUILDINGS[town]
	var folder := "anim" if e["anim"] else "night"
	var tex: Texture2D = load("%sbuildings/%s/%s.png" % [ExtraCatalog.TOWN_DIR, folder, town])
	_frame_w = float(e["w"])
	var region := Rect2(0, 0, e["w"], e["h"])
	_strips = ArtDB.add_strips(self, tex, region, Vector2(e["c"][0], e["c"][1]), fp)
	if e["anim"]:
		_frame = randi() % ExtraCatalog.ANIM_FRAMES
		_anim_t = randf() * ExtraCatalog.FRAME_MS / 1000.0
		_apply_frame(0)


func _apply_frame(old: int) -> void:
	var dx := (_frame - old) * _frame_w
	for sp in _strips:
		var r := sp.region_rect
		r.position.x += dx
		sp.region_rect = r


func _process(delta: float) -> void:
	_update_fade(delta)
	if _strips.is_empty() or _frame_w <= 0.0:
		return
	_anim_t += delta
	var step := ExtraCatalog.FRAME_MS / 1000.0
	if _anim_t >= step:
		_anim_t -= step
		var old := _frame
		_frame = (_frame + 1) % ExtraCatalog.ANIM_FRAMES
		_apply_frame(old)


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


func _refresh_power() -> void:
	var old := powered
	if kind == "gerador":
		powered = fuel > 0.0
	elif kind in CONSUMERS:
		powered = world != null and world.is_powered(position)
	if old != powered:
		queue_redraw()


func prompt() -> String:
	match kind:
		"porta":
			return "[E] %s a porta" % ("Fechar" if open else "Abrir")
		"gerador":
			if eternal:
				return "Gerador do abrigo (combustível infinito)"
			return "[E] Abastecer gerador (combustível %d%%)" % int(fuel)
		"purificador", "torre", "vedacao":
			return "%s: %s" % [DB.BUILDS[kind]["nome"], "funcionando" if powered else "sem energia"]
	return ""


## Servidor: interação de um jogador; o novo estado vai para todos os peers.
func interact(player: Player) -> void:
	match kind:
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
	if server and kind == "gerador" and not eternal and fuel > 0.0:
		var before := int(fuel)
		fuel = maxf(0.0, fuel - 0.12 * delta)
		if int(fuel) != before:
			world.structure_changed(self)
		if fuel <= 0.0:
			Game.say_all("Um gerador ficou sem combustível!")
			_refresh_power()
	_power_t -= delta
	if _power_t <= 0.0:
		_power_t = 0.5
		_refresh_power()
	if kind == "torre":
		_cd -= delta
		_tracer_t = maxf(0.0, _tracer_t - delta)
		if server and powered and _cd <= 0.0:
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
	if not kind in SPRITES:
		return
	var row := 0
	var col := 0
	match kind:
		"parede":
			col = posmod(cell.x * 7 + cell.y * 13, 2)
		"porta":
			col = 1 if open else 0
		"gerador", "purificador", "vedacao":
			col = 0 if powered else 1
		"torre":
			row = 0 if powered else 1
			col = _aim
	GenArt.draw_frame(self, kind, row, col)
	if kind == "torre" and _tracer_t > 0.0:
		var muzzle := Vector2.from_angle(float(_aim) * PI / 4.0) * Vector2(18, 9) + Vector2(0, -28)
		draw_line(muzzle, _tracer, Color("#ffe066"), 2.0)

class_name Structure
extends StaticBody2D
## Estrutura sólida: ruínas, paredes, portas, gerador, purificador, torre e selagem de ar.

const CONSUMERS := ["purificador", "torre", "vedacao"]

var kind := "parede"
var cell := Vector2i.ZERO
var world: World
var powered := false
var fuel := 0.0
var open := false
var eternal := false

var _shape: CollisionPolygon2D
var _power_t := 0.0
var _cd := 0.0
var _tracer := Vector2.ZERO
var _tracer_t := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_shape = CollisionPolygon2D.new()
	_shape.polygon = PackedVector2Array([Vector2(0, -14), Vector2(28, 0), Vector2(0, 14), Vector2(-28, 0)])
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


func interact(player: Player) -> void:
	match kind:
		"porta":
			open = not open
			_apply_open()
			queue_redraw()
		"gerador":
			if eternal:
				Game.say("O gerador do abrigo funciona sem parar.")
			elif player.data.take_item("combustivel"):
				fuel = minf(100.0, fuel + 50.0)
				Game.say("Gerador abastecido (%d%%)." % int(fuel))
				_refresh_power()
			else:
				Game.say("Você precisa de combustível.")
		_:
			Game.say(prompt() + (". Ligue-o a um gerador abastecido." if not powered else "."))


func _physics_process(delta: float) -> void:
	if kind == "gerador" and not eternal and fuel > 0.0:
		fuel = maxf(0.0, fuel - 0.12 * delta)
		if fuel <= 0.0:
			Game.say("Um gerador ficou sem combustível!")
			_refresh_power()
	_power_t -= delta
	if _power_t <= 0.0:
		_power_t = 0.5
		_refresh_power()
	if kind == "torre":
		_cd -= delta
		_tracer_t = maxf(0.0, _tracer_t - delta)
		if powered and _cd <= 0.0:
			var best: Infected = null
			var best_d := 230.0
			for n in get_tree().get_nodes_in_group("infected"):
				var e := n as Infected
				var off := e.position - position
				var d := Vector2(off.x, off.y * 2.0).length()
				if d < best_d:
					best_d = d
					best = e
			if best != null:
				best.take_damage(20.0, self)
				_cd = 1.0
				_tracer = best.position - position + Vector2(0, -14)
				_tracer_t = 0.12
				queue_redraw()
		if _tracer_t <= 0.0 and _tracer != Vector2.ZERO:
			_tracer = Vector2.ZERO
			queue_redraw()


func to_dict() -> Dictionary:
	return {"kind": kind, "cell": [cell.x, cell.y], "fuel": fuel, "open": open}


# ------------------------------------------------------------------ visual
func _cube(h: float, c: Color, s: float = 1.0) -> void:
	var w := 32.0 * s
	var q := 16.0 * s
	var top := PackedVector2Array([Vector2(0, q - 2 * q - h), Vector2(w, -h), Vector2(0, q - h), Vector2(-w, -h)])
	var left := PackedVector2Array([Vector2(-w, -h), Vector2(0, q - h), Vector2(0, q), Vector2(-w, 0)])
	var right := PackedVector2Array([Vector2(0, q - h), Vector2(w, -h), Vector2(w, 0), Vector2(0, q)])
	draw_colored_polygon(left, c.darkened(0.25))
	draw_colored_polygon(right, c.darkened(0.45))
	draw_colored_polygon(top, c.lightened(0.08))


func _draw() -> void:
	match kind:
		"ruina":
			var h := 22.0 + float(posmod(cell.x * 7 + cell.y * 13, 5)) * 7.0
			_cube(h, Color("#6e6a66"))
		"parede":
			_cube(30.0, Color("#8a8f99"))
		"porta":
			if open:
				_cube(4.0, Color("#a0763c"))
			else:
				_cube(28.0, Color("#a0763c"))
		"gerador":
			_cube(16.0, Color("#c9a227"), 0.7)
			draw_rect(Rect2(-4, -26, 8, 4), Color("#3be06a") if powered else Color("#7a2020"))
		"purificador":
			_cube(26.0, Color("#4aa3a3"), 0.75)
			draw_rect(Rect2(-4, -36, 8, 4), Color("#3be06a") if powered else Color("#7a2020"))
		"torre":
			_cube(20.0, Color("#7a3b3b"), 0.7)
			draw_rect(Rect2(-3, -34, 6, 12), Color("#444a52"))
			if _tracer_t > 0.0:
				draw_line(Vector2(0, -32), _tracer, Color("#ffe066"), 2.0)
		"vedacao":
			_cube(14.0, Color("#3b5f7a"), 0.7)
			draw_rect(Rect2(-4, -24, 8, 4), Color("#3be06a") if powered else Color("#7a2020"))
			if powered:
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
				draw_arc(Vector2.ZERO, World.SEAL_RADIUS, 0.0, TAU, 48, Color(0.4, 0.9, 1.0, 0.35), 1.5)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

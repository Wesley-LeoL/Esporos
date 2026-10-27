class_name Corpse
extends Node2D
## Cadáver estático de um sobrevivente morto fisicamente. Decompõe com o tempo,
## atrai moscas e hordas e funciona como baú recuperável até sumir.

const LIFETIME := 300.0

var nome := ""
var items := {}
var decomp := 0.0
var world: World
var _attract_t := 12.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("corpses")


func prompt() -> String:
	return "[E] Revistar corpo de %s (decomposição %d%%)" % [nome, int(decomp)]


func interact(player: Player) -> void:
	if items.is_empty():
		Game.say("O corpo já foi saqueado.")
		return
	var parts: Array[String] = []
	for k in items:
		player.data.add_item(k, int(items[k]))
		parts.append("%dx %s" % [int(items[k]), DB.item_name(k)])
	Game.say("Você recuperou: " + ", ".join(parts) + ".")
	items.clear()


func _process(delta: float) -> void:
	decomp += delta * 100.0 / LIFETIME
	if decomp >= 100.0:
		Game.say("O corpo de %s se desfez." % nome)
		queue_free()
		return
	_attract_t -= delta
	if _attract_t <= 0.0:
		_attract_t = 12.0
		if decomp > 30.0 and world != null and world.player != null:
			var d := position.distance_to(world.player.position)
			if d < 900.0 and get_tree().get_nodes_in_group("infected").size() < 18:
				world.spawn_infected(position + Vector2.from_angle(randf() * TAU) * 110.0, false)
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var k := decomp / 100.0
	var body := Color("#3fb8af").lerp(Color("#5a5a3a"), k)
	draw_rect(Rect2(-12, -6, 20, 7), body)
	draw_circle(Vector2(-14, -3), 4.0, Color("#e8d5b7").lerp(Color("#7a8a5a"), k))
	if items.is_empty():
		draw_rect(Rect2(-12, -6, 20, 7), Color(0, 0, 0, 0.35))
	if decomp > 20.0:
		var t := Time.get_ticks_msec() * 0.006
		for i in 5:
			var a := t + float(i) * 1.7
			draw_rect(Rect2(cos(a * 1.3) * 12.0, -10.0 + sin(a * 1.9) * 6.0, 1.5, 1.5), Color(0.1, 0.1, 0.1))

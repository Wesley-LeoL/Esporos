class_name Corpse
extends Node2D
## Cadáver estático de um sobrevivente morto fisicamente. Decompõe com o tempo,
## atrai moscas e hordas e funciona como baú recuperável até sumir.

const LIFETIME := 300.0

var nome := ""
var items: Array = []
var decomp := 0.0
var world: World
var _attract_t := 12.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("corpses")


## Sincronizador (servidor): itens e decomposição mudam depois do spawn.
func setup_net() -> void:
	Net.make_sync(self, [".:items", ".:decomp"], 0.5)


func prompt() -> String:
	return "[E] Revistar corpo de %s (decomposição %d%%)" % [nome, int(decomp)]


func title() -> String:
	return "Corpo de " + nome


## Abrir é local (janela de saque); a transferência vai pelo Player.act.
func interact(_player: Player) -> void:
	pass


func _process(delta: float) -> void:
	queue_redraw()
	if not Net.is_server():
		return
	decomp += delta * 100.0 / LIFETIME
	if decomp >= 100.0:
		Game.say_all("O corpo de %s se desfez." % nome)
		queue_free()
		return
	_attract_t -= delta
	if _attract_t <= 0.0:
		_attract_t = 12.0
		if decomp > 30.0 and world != null and world.nearest_player(position, 1800.0) != null \
				and get_tree().get_nodes_in_group("infected").size() < 18:
			world.spawn_infected(position + Vector2.from_angle(randf() * TAU) * 110.0, false)


func _draw() -> void:
	var k := decomp / 100.0
	# decompõe: escurece e esverdeia; some aos poucos no fim
	var tint := Color.WHITE.lerp(Color(0.55, 0.62, 0.42), k)
	tint.a = 1.0 if k < 0.85 else (1.0 - (k - 0.85) / 0.15 * 0.6)
	GenArt.draw_frame(self, "corpse", 0, posmod(nome.hash(), 2), Vector2.ZERO, tint)
	if items.is_empty():
		GenArt.draw_frame(self, "corpse", 0, posmod(nome.hash(), 2), Vector2.ZERO, Color(0, 0, 0, 0.3))
	if decomp > 20.0:
		var t := Time.get_ticks_msec() * 0.006
		for i in 6:
			var a := t + float(i) * 1.7
			draw_rect(Rect2(cos(a * 1.3) * 14.0, -14.0 + sin(a * 1.9) * 7.0, 1.5, 1.5), Color(0.05, 0.05, 0.08))

class_name Caravan
extends Node2D
## Caravana que viaja pelas estradas entre vilas (simulação de comércio em segundo plano).

var path := PackedVector2Array()
var from_id := 0
var to_id := 0
var cargo := {}
var world: World
var _i := 0
var _dir := 0


var net_pos := Vector2.ZERO


func setup_net() -> void:
	net_pos = position
	Net.make_sync(self, [".:net_pos"], 0.1)


func _process(delta: float) -> void:
	var before := position
	if Net.is_server():
		if _i >= path.size():
			world.caravan_arrived(self)
			queue_free()
			return
		var target := path[_i]
		var off := target - position
		var step := 58.0 * delta
		if off.length() <= step:
			position = target
			_i += 1
		else:
			position += off.normalized() * step
		net_pos = position
	else:
		position = position.lerp(net_pos, clampf(delta * 8.0, 0.0, 1.0))
	var moved := position - before
	if moved.length() > 0.01:
		# folha com 4 direções diagonais (SE, SO, NO, NE), as únicas possíveis nas estradas
		var f := GenArt.facing_of(moved)
		var d := {1: 0, 3: 1, 5: 2, 7: 3, 0: 3, 2: 0, 4: 1, 6: 2}
		_dir = d[f]
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	GenArt.draw_frame(self, "caravan", 0, _dir)

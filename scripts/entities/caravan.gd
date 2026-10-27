class_name Caravan
extends Node2D
## Caravana que viaja pelas estradas entre vilas (simulação de comércio em segundo plano).

var path := PackedVector2Array()
var from_id := 0
var to_id := 0
var cargo := {}
var world: World
var _i := 0


func _process(delta: float) -> void:
	if _i >= path.size():
		world.caravan_arrived(self)
		queue_free()
		return
	var target := path[_i]
	var off := target - position
	var step := 46.0 * delta
	if off.length() <= step:
		position = target
		_i += 1
	else:
		position += off.normalized() * step
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(-9, -10, 18, 9), Color("#8a6a3a"))
	draw_rect(Rect2(-9, -14, 18, 4), Color("#c9b27a"))
	draw_circle(Vector2(-6, 0), 2.5, Color("#222222"))
	draw_circle(Vector2(6, 0), 2.5, Color("#222222"))

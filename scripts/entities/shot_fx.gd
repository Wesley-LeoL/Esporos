class_name ShotFx
extends Node2D
## Rastros de um disparo (some em ~0,1 s).

var from := Vector2.ZERO
var tos := PackedVector2Array()
var _t := 0.12


func _ready() -> void:
	z_index = 50


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var a := clampf(_t / 0.12, 0.0, 1.0)
	for p in tos:
		draw_line(from, p, Color(1.0, 0.92, 0.5, 0.85 * a), 1.5)
	draw_circle(from, 5.0 * a + 1.0, Color(1.0, 0.85, 0.4, a))

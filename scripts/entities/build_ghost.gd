class_name BuildGhost
extends Node2D
## Fantasma de pré-visualização do modo de construção/demolição.

var kind := ""
var valid := false


func _ready() -> void:
	z_index = 60
	visible = false


func show_at(new_kind: String, pos: Vector2, is_valid: bool) -> void:
	if not visible or kind != new_kind or valid != is_valid or position != pos:
		kind = new_kind
		valid = is_valid
		position = pos
		visible = true
		queue_redraw()


func hide_ghost() -> void:
	visible = false


func _draw() -> void:
	var col := Color(0.3, 1.0, 0.4, 0.45) if valid else Color(1.0, 0.3, 0.3, 0.45)
	var pts := PackedVector2Array([Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0)])
	draw_colored_polygon(pts, col)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), col.lightened(0.4), 2.0)

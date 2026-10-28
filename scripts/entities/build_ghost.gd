class_name BuildGhost
extends Node2D
## Prévia do modo de construção/demolição: losango da célula (pisos e objetos, com o
## sprite do objeto por cima) ou faixa da borda (paredes e portas).

var kind := ""
var valid := false
## Borda (0/1) para paredes; -1 para célula.
var dir := -1


func _ready() -> void:
	z_index = 60
	visible = false


func show_at(new_kind: String, pos: Vector2, is_valid: bool, d := -1) -> void:
	if not visible or kind != new_kind or valid != is_valid or position != pos or dir != d:
		kind = new_kind
		valid = is_valid
		position = pos
		dir = d
		visible = true
		queue_redraw()


func hide_ghost() -> void:
	visible = false


func _draw() -> void:
	var col := Color(0.3, 1.0, 0.4, 0.45) if valid else Color(1.0, 0.3, 0.3, 0.45)
	if kind == "demolir":
		col = Color(1.0, 0.55, 0.2, 0.5) if valid else Color(0.6, 0.6, 0.6, 0.3)
	if dir >= 0:
		var ends := WallEdge.edge_ends(dir)
		var up := Vector2(0, -36)
		draw_colored_polygon(PackedVector2Array([ends[0], ends[1], ends[1] + up, ends[0] + up]), col)
		draw_line(ends[0], ends[1], col.lightened(0.5), 3.0)
		if kind != "demolir" and GenCatalog.SHEETS.has(kind):
			GenArt.draw_frame(self, kind, dir, 0, Vector2.ZERO, Color(1, 1, 1, 0.55))
		return
	var pts := PackedVector2Array([Vector2(0, -20), Vector2(40, 0), Vector2(0, 20), Vector2(-40, 0)])
	draw_colored_polygon(pts, col)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), col.lightened(0.4), 2.0)
	if kind != "demolir" and GenCatalog.SHEETS.has(kind) and World.build_type(kind) != "piso":
		GenArt.draw_frame(self, kind, 0, 0, Vector2.ZERO, Color(1, 1, 1, 0.55))

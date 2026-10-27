class_name ScanOverlay
extends Control
## Overlay do implante HUD: marca infectados e caixas próximas.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w := Game.world
	if w == null or w.player == null or w.player.data == null or w.player.is_dead():
		return
	var d := w.player.data
	if not d.implant_active("olho"):
		return
	var xf := get_viewport().get_canvas_transform()
	var ppos := w.player.position
	for n in get_tree().get_nodes_in_group("infected"):
		var e := n as Node2D
		if e.position.distance_to(ppos) > 560.0:
			continue
		var sp := xf * (e.position + Vector2(0, -42))
		draw_colored_polygon(PackedVector2Array([sp + Vector2(-4, -5), sp + Vector2(4, -5), sp]), Color(1.0, 0.25, 0.25, 0.9))
	for n in get_tree().get_nodes_in_group("containers"):
		var lc := n as LootContainer
		if lc.items.is_empty() or lc.position.distance_to(ppos) > 420.0:
			continue
		var sp2 := xf * (lc.position + Vector2(0, -20))
		draw_colored_polygon(PackedVector2Array([sp2 + Vector2(0, -4), sp2 + Vector2(4, 0), sp2 + Vector2(0, 4), sp2 + Vector2(-4, 0)]), Color(1.0, 0.85, 0.2, 0.9))
	var spore := w.spore_at(ppos)
	# texto na fonte pixelada, em meia escala para ficar no tamanho nativo da grade
	draw_set_transform(Vector2(8, 66), 0.0, Vector2(0.5, 0.5))
	draw_string(UITheme.font(), Vector2.ZERO, "SCAN ATIVO  ESPOROS %.2f" % spore,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_S, Color(0.32, 0.9, 1.0, 0.95))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

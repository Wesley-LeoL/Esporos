class_name PixelBar
extends Control
## Barra segmentada em pixel art. 'danger_high' indica que valor alto é ruim
## (contaminação, fome); senão, valor baixo é ruim (vida, sede). Pisca quando crítica.

var value := 100.0:
	set(v):
		if not is_equal_approx(v, value):
			value = v
			queue_redraw()
var color := Color.WHITE
var segments := 16
var danger_high := false
var critical_at := 25.0
var _blink := 0.0


func _init(col: Color = Color.WHITE, segs: int = 16, high_bad := false) -> void:
	color = col
	segments = segs
	danger_high = high_bad
	custom_minimum_size = Vector2(120, 20)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_critical() -> bool:
	return value >= 100.0 - critical_at if danger_high else value <= critical_at


func _process(delta: float) -> void:
	if is_critical():
		_blink += delta
		queue_redraw()


func _draw() -> void:
	var w := floorf(size.x / 2.0) * 2.0
	var h := floorf(size.y / 2.0) * 2.0
	draw_rect(Rect2(0, 0, w, h), Color("#05080b"))
	draw_rect(Rect2(2, 2, w - 4, h - 4), Color("#0b1218"))
	var gap := 2.0
	var inner := w - 8.0
	var seg_w := floorf((inner - gap * (segments - 1)) / segments / 2.0) * 2.0
	seg_w = maxf(seg_w, 2.0)
	var total := seg_w * segments + gap * (segments - 1)
	var x0 := 4.0 + floorf((inner - total) / 4.0) * 2.0
	var lit := int(ceil(clampf(value, 0.0, 100.0) / 100.0 * segments))
	var col := color
	if is_critical() and int(_blink * 5.0) % 2 == 0:
		col = col.lightened(0.45)
	for i in segments:
		var r := Rect2(x0 + i * (seg_w + gap), 4, seg_w, h - 8)
		if i < lit:
			draw_rect(r, col)
			draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), col.lightened(0.35))
			draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)), col.darkened(0.35))
		else:
			draw_rect(r, Color(col.r, col.g, col.b, 0.14))

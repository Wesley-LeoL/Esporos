class_name MapView
extends Control
## Mapa do mundo (aba Mapa). Mostra só os chunks que este jogador já descobriu, na mesma
## projeção isométrica do jogo. Roda do mouse aproxima; arrastar com o botão esquerdo
## move o mapa; passar o mouse sobre uma área mostra o que se sabe dela (HUD._map_info).

const TABLE_COLORS := {"comum": Color("#b8b2a0"), "medico": Color("#e05a6a"), "tecnico": Color("#52c8e6"),
	"bau": Color("#d8a860")}

var hud: HUD
var zoom := 1.0
var pan := Vector2.ZERO
var hover_ch := Vector2i(99999, 99999)
var _drag := false
var _spore_cache := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _k() -> float:
	var r := World.RADIUS + 6.0
	return minf(size.x * 0.92 / (4.0 * r), size.y * 0.92 / (2.0 * r)) * zoom


func to_map(t: Vector2) -> Vector2:
	return size / 2.0 + pan + Vector2(t.x - t.y, (t.x + t.y) * 0.5) * _k()


func to_tile(p: Vector2) -> Vector2:
	var v := (p - size / 2.0 - pan) / _k()
	return Vector2((v.x + 2.0 * v.y) * 0.5, (2.0 * v.y - v.x) * 0.5)


## Centraliza no jogador.
func center_on(tile: Vector2) -> void:
	pan = Vector2.ZERO
	pan = size / 2.0 - to_map(tile)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var before := to_tile(mb.position)
			zoom = clampf(zoom * (1.25 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8), 1.0, 10.0)
			pan += mb.position - to_map(before)
			queue_redraw()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _drag:
			pan += mm.relative
			queue_redraw()
		var t := to_tile(mm.position)
		var ch := World.chunk_of(Vector2i(floori(t.x), floori(t.y)))
		if ch != hover_ch:
			hover_ch = ch
			queue_redraw()
			if hud != null:
				hud.map_hovered(ch)


func _spore(ch: Vector2i) -> float:
	if not _spore_cache.has(ch):
		var w := Game.world
		var c := ch * World.CHUNK + Vector2i(World.CHUNK / 2, World.CHUNK / 2)
		_spore_cache[ch] = w.spore_at(w.ground.map_to_local(c))
	return float(_spore_cache[ch])


func _chunk_poly(ch: Vector2i) -> PackedVector2Array:
	var b := Vector2(ch * World.CHUNK)
	var n := float(World.CHUNK)
	return PackedVector2Array([to_map(b), to_map(b + Vector2(n, 0)), to_map(b + Vector2(n, n)), to_map(b + Vector2(0, n))])


func _draw() -> void:
	var w := Game.world
	if w == null or hud == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("#05080c"))
	# borda do mundo (o mar de esporos)
	var ring := PackedVector2Array()
	for i in 65:
		var a := float(i) / 64.0 * TAU
		ring.append(to_map(Vector2(cos(a), sin(a)) * World.RADIUS))
	draw_polyline(ring, Color(0.45, 0.85, 0.3, 0.35), 2.0)
	var known: Dictionary = hud.map_known
	var k := _k()
	# áreas descobertas: cor pelo nível de esporos
	for key in known:
		var ch: Vector2i = key
		var sp := _spore(ch)
		var col := Color("#1d2a33").lerp(Color("#2c4a2a"), clampf(sp * 1.6, 0.0, 1.0))
		if sp >= 1.0:
			col = Color("#4a1820")
		elif sp >= 0.5:
			col = Color("#3b3a1c")
		draw_colored_polygon(_chunk_poly(ch), col)
	# estradas
	var cell_px := maxf(1.5, k * 1.1)
	for c: Vector2i in w.road_cells:
		if known.has(World.chunk_of(c)):
			var p := to_map(Vector2(c) + Vector2(0.5, 0.5))
			draw_rect(Rect2(p - Vector2(cell_px, cell_px * 0.5) * 0.5, Vector2(cell_px, cell_px * 0.5)), Color("#5a6470"))
	# prédios descobertos (cor pelo estado do lugar)
	for id in w.houses:
		var hd: Dictionary = w.houses[id]
		var hr: Rect2i = hd["rect"]
		if not known.has(World.chunk_of(hr.position)):
			continue
		var hcol := Color("#4a5866")
		if hd["estado"] == "abandonada":
			hcol = Color("#5a4a40")
		elif hd["estado"] == "esporos":
			hcol = Color("#6a2c58")
		var b := Vector2(hr.position)
		var fp := Vector2(hr.size)
		draw_colored_polygon(PackedVector2Array([to_map(b), to_map(b + Vector2(fp.x, 0)), to_map(b + fp),
			to_map(b + Vector2(0, fp.y))]), hcol)
	# caixas (cor pelo tipo; apagadas se já vazias)
	if zoom >= 2.0:
		for cd in w.container_data:
			var cc: Vector2i = cd["cell"]
			if known.has(World.chunk_of(cc)):
				var col2: Color = TABLE_COLORS.get(cd["table"], Color.WHITE)
				if cd["items"].is_empty():
					col2.a = 0.3
				draw_circle(to_map(Vector2(cc) + Vector2(0.5, 0.5)), maxf(2.0, k * 0.5), col2)
	# construções dos jogadores e baús
	for c: Vector2i in w.built:
		if known.has(World.chunk_of(c)):
			draw_rect(Rect2(to_map(Vector2(c) + Vector2(0.5, 0.5)) - Vector2(3, 3), Vector2(6, 6)), Color("#ffd166"))
	# veículos vistos
	for n in get_tree().get_nodes_in_group("vehicles"):
		var vt := w.tile_pos((n as Node2D).position)
		if known.has(World.chunk_of(Vector2i(floori(vt.x), floori(vt.y)))):
			draw_rect(Rect2(to_map(vt) - Vector2(4, 3), Vector2(8, 6)), Color("#ff9a3c"))
	# vilas conhecidas
	var f := UITheme.font()
	for v in w.villages:
		if not known.has(World.chunk_of(v.cell)):
			continue
		var p2 := to_map(Vector2(v.cell))
		var vc := Color("#7fe0a0") if v.safe else (UITheme.DANGER if v.infested else UITheme.ACCENT)
		if not v.request.is_empty():
			vc = UITheme.WARN
		draw_rect(Rect2(p2 - Vector2(7, 7), Vector2(14, 14)), vc)
		draw_rect(Rect2(p2 - Vector2(7, 7), Vector2(14, 14)), Color.BLACK, false, 2.0)
		draw_string(f, p2 + Vector2(12, 6), v.nome, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_S, vc)
	# aliados e você
	for pk in w.players:
		var pl: Player = w.players[pk]
		if not pl.alive:
			continue
		var pt := w.tile_pos(pl.position)
		var pp := to_map(pt)
		if pl.is_local():
			var dir := Vector2(1, 0).rotated(float(pl.facing) * PI / 4.0) * 10.0
			draw_colored_polygon(PackedVector2Array([pp + dir, pp + dir.rotated(2.5) * 0.8, pp + dir.rotated(-2.5) * 0.8]), UITheme.MAGENTA)
			draw_circle(pp, 3.0, Color.WHITE)
		else:
			draw_circle(pp, 6.0, UITheme.ACCENT)
			draw_string(f, pp + Vector2(9, 5), pl.nome, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_S, UITheme.ACCENT)
	# área sob o mouse
	if known.has(hover_ch):
		var poly := _chunk_poly(hover_ch)
		poly.append(poly[0])
		draw_polyline(poly, Color(1, 1, 1, 0.7), 2.0)

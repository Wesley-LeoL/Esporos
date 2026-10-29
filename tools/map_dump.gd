extends Node
## Gera o mapa de uma seed e salva uma visão de cima (1 px por célula, ampliada):
##   godot --headless --path . res://tools/map_dump.tscn -- --seed=123 --out=/caminho/mapa.png

const COLORS := {
	0: Color("#404156"), 1: Color("#484f6a"), 2: Color("#2f4a2a"), 3: Color("#2a2e39"), 4: Color("#624d53"),
	5: Color("#616b8c"), 6: Color("#2d2f32"), 7: Color("#8e7c98"), 8: Color("#8e6a52"), 9: Color("#575772"),
	10: Color("#3e5a30"), 11: Color("#6e6f3a"), 12: Color("#8b89a3"), 13: Color("#2a2e39"), 14: Color("#2a2e39"),
	15: Color("#7b5e5a"), 16: Color("#3a3e49"), 17: Color("#3a3e49"), 18: Color("#4a3a30"), 19: Color("#4a5a3a"),
	20: Color("#9898a3"), 21: Color("#5a1a22"),
}


func _ready() -> void:
	var seed := 12345
	var out := "/tmp/mapa.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed = int(a.substr(7))
		elif a.begins_with("--out="):
			out = a.substr(6)
	var w := World.new()
	w.generate(seed)
	var R := int(World.RADIUS) + 4
	var img := Image.create(R * 2 + 1, R * 2 + 1, false, Image.FORMAT_RGB8)
	img.fill(Color("#05080c"))
	for x in range(-R, R + 1):
		for y in range(-R, R + 1):
			var t := w._terrain(Vector2i(x, y))
			if t >= 0:
				img.set_pixel(x + R, y + R, COLORS.get(t, Color.MAGENTA))
	for id in w.houses:
		var hr: Rect2i = w.houses[id]["rect"]
		var hc: Color = {"viva": Color("#c9a0ff"), "abandonada": Color("#a08060"), "esporos": Color("#e070c0")}[w.houses[id]["estado"]]
		for i in hr.size.x:
			for j in hr.size.y:
				img.set_pixel(hr.position.x + i + R, hr.position.y + j + R, hc.darkened(0.25 if i == 0 or j == 0 or i == hr.size.x - 1 or j == hr.size.y - 1 else 0.0))
	for c: Vector2i in w.planned_buildings:
		var e: Dictionary = w.planned_buildings[c]
		var fp: Vector2i = e["fp"]
		var col := Color("#c9a0ff") if CityCatalog.DATA.has(e["art"]) else Color("#ffd166")
		for i in fp.x:
			for j in fp.y:
				img.set_pixel(c.x + i + R, c.y + j + R, col.darkened(0.15 if (i + j) % 2 else 0.0))
	for ch in w.plan:
		for e in w.plan[ch]:
			if e["t"] == "p":
				var c2: Vector2i = e["cell"]
				img.set_pixel(c2.x + R, c2.y + R, Color("#7fe07f") if String(e["art"]).begins_with("arv") or e["art"] in ["pinheiro", "arbusto"] else Color("#e0e0e0"))
			elif e["t"] == "c":
				var c3: Vector2i = e["cell"]
				img.set_pixel(c3.x + R, c3.y + R, Color("#ff4060"))
	for v in w.villages:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				img.set_pixel(v.cell.x + R + dx, v.cell.y + R + dy, Color("#00ffff"))
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	print("salvo: ", out, " prédios=", w.planned_buildings.size(), " caixas=", w.container_data.size())
	get_tree().quit()

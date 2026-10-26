extends TileMapLayer
## Chão isométrico provisório. O TileSet e o atlas são gerados por código;
## depois serão trocados por arte em pixel art de verdade.
## A borda do mapa (raio MAP_RADIUS) usa o tile verde: o "Mar de Esporos".

const TILE_W := 64
const TILE_H := 32
const MAP_RADIUS := 14
const SPORE_BAND := 2  # largura da faixa tóxica na borda, em tiles

const TILE_COLORS: Array[Color] = [
	Color("#2b2f36"),
	Color("#32373f"),
	Color("#4a6b2f"),
]


func _ready() -> void:
	tile_set = _build_tileset()
	for x in range(-MAP_RADIUS, MAP_RADIUS + 1):
		for y in range(-MAP_RADIUS, MAP_RADIUS + 1):
			var dist := Vector2(x, y).length()
			if dist > MAP_RADIUS:
				continue
			var variant := (x + y) & 1
			if dist > MAP_RADIUS - SPORE_BAND:
				variant = 2
			set_cell(Vector2i(x, y), 0, Vector2i(variant, 0))


func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(TILE_W, TILE_H)
	var source := TileSetAtlasSource.new()
	source.texture = _make_atlas()
	source.texture_region_size = Vector2i(TILE_W, TILE_H)
	for i in TILE_COLORS.size():
		source.create_tile(Vector2i(i, 0))
	ts.add_source(source, 0)
	return ts


func _make_atlas() -> ImageTexture:
	var img := Image.create(TILE_W * TILE_COLORS.size(), TILE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in TILE_COLORS.size():
		for px in TILE_W:
			for py in TILE_H:
				var d := absf(px - (TILE_W - 1) / 2.0) / (TILE_W / 2.0) \
					+ absf(py - (TILE_H - 1) / 2.0) / (TILE_H / 2.0)
				if d <= 1.0:
					var c := TILE_COLORS[i]
					if d > 0.92:
						c = c.darkened(0.35)
					img.set_pixel(i * TILE_W + px, py, c)
	return ImageTexture.create_from_image(img)

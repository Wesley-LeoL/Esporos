class_name ArtDB
extends RefCounted
## Acesso aos sprites do pacote de arte (assets/art/tiles). Usa os PNGs originais sem
## alterá-los: cada vista é um AtlasTexture recortado conforme scripts/art/art_catalog.gd.
## A grade da arte é isométrica 2:1 com células de 80x40 px (mesma grade do mundo).

const BASE := "res://assets/art/tiles/"

static var _textures := {}
static var _regions := {}


## Entrada do catálogo: pacote FreeSample (ArtCatalog) ou kit gerado (CityCatalog).
static func entry(art: String) -> Dictionary:
	if ArtCatalog.DATA.has(art):
		return ArtCatalog.DATA[art]
	return CityCatalog.DATA.get(art, {})


static func _path(art: String) -> String:
	var e := entry(art)
	if e.has("path"):
		return e["path"]
	return "%s%s/%s.png" % [BASE, e["dir"], art]


static func has(art: String) -> bool:
	return ArtCatalog.DATA.has(art) or CityCatalog.DATA.has(art)


static func variants(art: String) -> int:
	return (entry(art)["v"] as Array).size()


static func footprint(art: String, v: int) -> Vector2i:
	var fp: Array = entry(art)["v"][v]["fp"]
	return Vector2i(int(fp[0]), int(fp[1]))


static func region(art: String, v: int) -> AtlasTexture:
	var key := "%s:%d" % [art, v]
	if _regions.has(key):
		return _regions[key]
	if not _textures.has(art):
		_textures[art] = load(_path(art))
	var r: Array = entry(art)["v"][v]["r"]
	var at := AtlasTexture.new()
	at.atlas = _textures[art]
	at.region = Rect2(r[0], r[1], r[2] - r[0] + 1, r[3] - r[1] + 1)
	_regions[key] = at
	return at


## Cria um Sprite2D cujo ponto de ancoragem fica na origem (0,0) do nó:
##  "bottom": vértice inferior da base (prédios)   "top": vértice superior (chão)
##  "base": centro da base, perto da borda inferior (props soltos)
static func sprite(art: String, v: int, anchor: String) -> Sprite2D:
	var info: Dictionary = entry(art)["v"][v]
	var r: Array = info["r"]
	var sp := Sprite2D.new()
	sp.texture = region(art, v)
	sp.centered = false
	var a := Vector2.ZERO
	match anchor:
		"bottom":
			a = Vector2(int(info["b"][0]) - int(r[0]), int(info["b"][1]) - int(r[1]))
		"top":
			a = Vector2(int(info["t"][0]) - int(r[0]), 0)
		_:
			a = Vector2((int(r[2]) - int(r[0])) / 2.0, int(r[3]) - int(r[1]) - 4)
	sp.position = -a
	return sp


## Prédios de várias células: corta o sprite em faixas verticais de 'strip' px, cada uma
## com a chave de ordenação (y) na borda da frente da pegada naquele x. Assim um
## personagem diante de qualquer trecho de um prédio comprido é desenhado na frente dele.
## O nó 'parent' deve ter y_sort_enabled e estar no centro da pegada (fp em células).
static func add_building_strips(parent: Node2D, art: String, v: int, fp: Vector2i, strip: int = 20) -> void:
	var info: Dictionary = entry(art)["v"][v]
	var r: Array = info["r"]
	if not _textures.has(art):
		_textures[art] = load(_path(art))
	var region := Rect2(int(r[0]), int(r[1]), int(r[2]) - int(r[0]) + 1, int(r[3]) - int(r[1]) + 1)
	# centro da base dentro da região = vértice inferior - deslocamento centro->vértice inferior
	var w := float(fp.x)
	var d := float(fp.y)
	var bottom := Vector2(World.HALF_W * 0.5 * (w - d), World.HALF_H * 0.5 * (w + d))
	var center := Vector2(int(info["b"][0]) - int(r[0]), int(info["b"][1]) - int(r[1])) - bottom
	add_strips(parent, _textures[art], region, center, fp, strip)


## Versão genérica: 'region' é a área do quadro na textura e 'center' o ponto da região
## que fica sobre o centro da pegada (a origem do nó). Devolve as faixas criadas (para
## animações que trocam a região, como as janelas acesas do Town Sampler).
static func add_strips(parent: Node2D, tex: Texture2D, region: Rect2, center: Vector2, fp: Vector2i,
		strip: int = 20) -> Array[Sprite2D]:
	var w := float(fp.x)
	var d := float(fp.y)
	var hw := World.HALF_W * 0.5
	var hh := World.HALF_H * 0.5
	var left := Vector2(-hw * (w + d), hh * (d - w))
	var bottom := Vector2(hw * (w - d), hh * (w + d))
	var right := Vector2(hw * (w + d), hh * (w - d))
	var rw := int(region.size.x)
	var p0 := -center
	var out: Array[Sprite2D] = []
	var x := 0
	while x < rw:
		var sw := mini(strip, rw - x)
		var xa := p0.x + x
		var xb := xa + sw
		var key := minf(_front_y(xa, left, bottom, right), _front_y(xb, left, bottom, right))
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.region_enabled = true
		sp.region_rect = Rect2(region.position.x + x, region.position.y, sw, region.size.y)
		sp.position = Vector2(xa, key)
		sp.offset = Vector2(0, p0.y - key)
		parent.add_child(sp)
		out.append(sp)
		x += strip
	return out


static func _front_y(x: float, left: Vector2, bottom: Vector2, right: Vector2) -> float:
	var cx := clampf(x, left.x, right.x)
	if cx <= bottom.x:
		return lerpf(left.y, bottom.y, (cx - left.x) / maxf(bottom.x - left.x, 0.001))
	return lerpf(bottom.y, right.y, (cx - bottom.x) / maxf(right.x - bottom.x, 0.001))

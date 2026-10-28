class_name Prop
extends Node2D
## Objeto de cenário. O nó fica no ponto de apoio no chão (chave de ordenação em profundidade).
## Fontes: "fs" = pacote FreeSample (4 vistas, ArtDB), "town" = postes do Town Sampler,
## "neon" = objetos do Neon District. Objetos com radius > 0 no ExtraCatalog bloqueiam passagem.

var art := ""
var variant := 0
var source := "fs"

var _sprite: Sprite2D
var _frame_w := 0.0
var _frame := 0
var _anim_t := 0.0


func _ready() -> void:
	set_process(false)
	match source:
		"fs":
			add_child(ArtDB.sprite(art, variant, "base"))
		"town":
			var e: Dictionary = ExtraCatalog.TOWN_PROPS[art]
			var folder := "anim" if e["anim"] else "night"
			_add_sprite(load("%sprops/%s/%s.png" % [ExtraCatalog.TOWN_DIR, folder, art]), e)
			if e["anim"]:
				_frame_w = float(e["w"])
				_frame = randi() % ExtraCatalog.ANIM_FRAMES
				_shift(_frame)
				set_process(true)
			_add_collision(int(e["radius"]))
		"neon":
			var n: Dictionary = ExtraCatalog.NEON[art]
			_add_sprite(load(ExtraCatalog.NEON_DIR + art + ".png"), n)
			_add_collision(int(n["radius"]))


## Recorta a área útil e posiciona a âncora (ponto de apoio) na origem do nó.
func _add_sprite(tex: Texture2D, e: Dictionary) -> void:
	var r: Array = e["r"]
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.centered = false
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(r[0], r[1], int(r[2]) - int(r[0]) + 1, int(r[3]) - int(r[1]) + 1)
	_sprite.position = -Vector2(int(e["a"][0]) - int(r[0]), int(e["a"][1]) - int(r[1]))
	add_child(_sprite)


func _add_collision(radius: int) -> void:
	if radius <= 0:
		return
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	shape.shape = c
	body.add_child(shape)
	add_child(body)


func _shift(frames: int) -> void:
	var r := _sprite.region_rect
	r.position.x += frames * _frame_w
	_sprite.region_rect = r


func _process(delta: float) -> void:
	_anim_t += delta
	var step := ExtraCatalog.FRAME_MS / 1000.0
	if _anim_t >= step:
		_anim_t -= step
		var nxt := (_frame + 1) % ExtraCatalog.ANIM_FRAMES
		_shift(nxt - _frame)
		_frame = nxt

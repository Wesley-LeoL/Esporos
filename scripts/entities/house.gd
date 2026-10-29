class_name House
extends Node2D
## Prédio explorável do mapa. O piso é do chão (World.ground_cells), as paredes são WallEdge
## (World.map_walls) e os móveis e caixas são objetos comuns; este nó só desenha o telhado,
## cortado em faixas para a ordenação de profundidade, e o esconde quando o jogador local
## entra ou passa logo atrás do prédio (corte do The Sims). Nesses casos o prédio fica
## "aberto" (World.house_open) e as paredes dele perto do jogador descem.

var id := 0
var rect := Rect2i()
var roof := ""
var world: World
var _strips: Array[Sprite2D] = []
var _t := 0.0


func _ready() -> void:
	y_sort_enabled = true
	if roof == "" or not CityCatalog.ROOFS.has(roof):
		return
	var info: Array = CityCatalog.ROOFS[roof]
	if info.is_empty():
		return
	var tex: Texture2D = load("res://assets/art/generated/town/roofs/%s.png" % roof)
	var fp := rect.size
	var w := float(fp.x)
	var d := float(fp.y)
	var bottom := Vector2(World.HALF_W * 0.5 * (w - d), World.HALF_H * 0.5 * (w + d))
	var center := Vector2(int(info[2]), int(info[3])) - bottom
	_strips = ArtDB.add_strips(self, tex, Rect2(0, 0, int(info[0]), int(info[1])), center, fp, 20, 2.0)
	_t = randf() * 0.1


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.1
	var open := false
	var pl: Player = world.local_player() if world != null else null
	if pl != null and pl.alive:
		var tp := world.tile_pos(pl.position)
		var c := Vector2i(floori(tp.x), floori(tp.y))
		# dentro, ou logo atrás do prédio (do lado de cima da tela)
		open = rect.has_point(c) or Rect2i(rect.position - Vector2i(2, 2), rect.size + Vector2i(2, 2)).has_point(c)
	world.house_open[id] = open
	var target := 0.0 if open else 1.0
	if not is_equal_approx(modulate.a, target):
		modulate.a = move_toward(modulate.a, target, 0.5)
		visible = modulate.a > 0.01

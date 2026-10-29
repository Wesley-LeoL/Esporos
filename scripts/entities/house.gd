class_name House
extends Node2D
## Prédio explorável do mapa. O piso é do chão (World.ground_cells), as paredes são WallEdge
## (World.map_walls) e os móveis e caixas são objetos comuns; este nó desenha o telhado,
## cortado em faixas para a ordenação de profundidade, e controla o que se vê do interior:
##
##   dentro    telhado some, sem sombra e as paredes perto do jogador descem (corte do The Sims)
##   espiando  jogador do lado de fora, colado numa janela, vitrine ou buraco: telhado some e
##             o interior aparece com pouca sombra; as paredes continuam inteiras
##   atrás     jogador logo atrás do prédio: telhado translúcido e interior escuro
##   fora      telhado inteiro; sem telhado (ruínas), o interior fica escuro
## Assim, de fora não dá para ver o que há lá dentro sem chegar perto de uma abertura.

const SHADE_DARK := 0.88
const SHADE_PEEK := 0.3

var id := 0
var rect := Rect2i()
var roof := ""
var world: World
var _strips: Array[Sprite2D] = []
var _roof_node: Node2D
var _floor: HouseShade
var _t := 0.0
var _scan_t := 0.0
var _shade := -1.0
var _inside_nodes: Array = []
var _windows: Array[Vector2] = []


func _ready() -> void:
	y_sort_enabled = true
	_roof_node = Node2D.new()
	_roof_node.y_sort_enabled = true
	add_child(_roof_node)
	if roof != "" and CityCatalog.ROOFS.has(roof):
		var info: Array = CityCatalog.ROOFS[roof]
		var tex: Texture2D = load("res://assets/art/generated/town/roofs/%s.png" % roof)
		var w := float(rect.size.x)
		var d := float(rect.size.y)
		var bottom := Vector2(World.HALF_W * 0.5 * (w - d), World.HALF_H * 0.5 * (w + d))
		var center := Vector2(int(info[2]), int(info[3])) - bottom
		_strips = ArtDB.add_strips(_roof_node, tex, Rect2(0, 0, int(info[0]), int(info[1])), center, rect.size, 20, 2.0)
	# sombra do piso: na camada do chão, por baixo das entidades
	_floor = HouseShade.new()
	_floor.world = world
	_floor.rect = rect
	world.art_ground.add_child(_floor)
	for k: Vector3i in world.houses[id].get("windows", []):
		_windows.append(world.edge_pos(k))
	_t = randf() * 0.1


func _exit_tree() -> void:
	if is_instance_valid(_floor):
		_floor.queue_free()


func _process(delta: float) -> void:
	_t -= delta
	_scan_t -= delta
	if _t > 0.0:
		return
	_t = 0.1
	var state := "fora"
	var pl: Player = world.local_player() if world != null else null
	if pl != null and pl.alive:
		var tp := world.tile_pos(pl.position)
		var c := Vector2i(floori(tp.x), floori(tp.y))
		if rect.has_point(c):
			state = "dentro"
		else:
			for wp in _windows:
				var off := wp - pl.position
				if Vector2(off.x, off.y * 2.0).length() < 62.0:
					state = "espiando"
					break
			if state == "fora" and Rect2i(rect.position - Vector2i(2, 2), rect.size + Vector2i(2, 2)).has_point(c):
				state = "atras"
	world.house_open[id] = state == "dentro"
	var roof_a := 1.0
	var shade := SHADE_DARK
	match state:
		"dentro":
			roof_a = 0.0
			shade = 0.0
		"espiando":
			roof_a = 0.0
			shade = SHADE_PEEK
		"atras":
			roof_a = 0.45
	if not is_equal_approx(_roof_node.modulate.a, roof_a):
		_roof_node.modulate.a = move_toward(_roof_node.modulate.a, roof_a, 0.35)
		_roof_node.visible = _roof_node.modulate.a > 0.01
	_set_shade(shade)


## Escurece o piso e o que está dentro (móveis, caixas, construções e divisórias).
func _set_shade(s: float) -> void:
	if _scan_t <= 0.0:
		_scan_t = 1.5
		_scan()
		_shade = -1.0
	if is_equal_approx(s, _shade):
		return
	_shade = s
	_floor.alpha = s * 0.85
	_floor.queue_redraw()
	var k := 1.0 - 0.82 * s
	var col := Color(k, k, minf(1.0, k * 1.08), 1.0)
	for n in _inside_nodes:
		if is_instance_valid(n):
			(n as CanvasItem).modulate = col


func _scan() -> void:
	_inside_nodes.clear()
	for n in world.entities.get_children():
		if n is WallEdge:
			var we := n as WallEdge
			if we.partition and we.house_id == id:
				_inside_nodes.append(we)
			continue
		if not (n is Prop or n is LootContainer or n is Structure):
			continue
		var tp := world.tile_pos((n as Node2D).position)
		if rect.has_point(Vector2i(floori(tp.x), floori(tp.y))):
			_inside_nodes.append(n)

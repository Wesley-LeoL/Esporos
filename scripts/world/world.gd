class_name World
extends Node2D
## Mundo procedural isométrico: terreno por ruído, estradas, vilas com simulação em
## segundo plano, concentração de esporos (letal na borda), infectados, construção,
## morte/legado e persistência apenas dos deltas feitos pelo jogador.

## Grade da arte: células isométricas 2:1 de 80x40 px (pacote em assets/art/tiles).
const TILE_W := 80
const TILE_H := 40
const HALF_W := TILE_W / 2.0
const HALF_H := TILE_H / 2.0
const RADIUS := 64.0
const SAFE_RADIUS_PX := 325.0
const SEAL_RADIUS := 190.0
const POWER_RADIUS_PX := 525.0
const PURIFY_RADIUS_PX := 150.0
const N_VILLAGES := 8

enum T { CONC_A, CONC_B, ESPOROS, ESTRADA, TERRA, PISO, MANCHA, VILA }

# Prédios e objetos do pacote FreeSample (peso de sorteio dos prédios).
const BUILDINGS: Array = [["BuildingBlock1", 15], ["BuildingBlock2", 15], ["BuildingBlock18", 20],
	["BuildingBlock19", 20], ["BuildingBlock24", 25], ["Building3", 5]]
const PROPS: Array[String] = ["Advertising5", "Advertising6", "Advertising7", "SateliteDish2"]
const VILLAGE_NAMES: Array[String] = ["Abrigo Alfa", "Poço Seco", "Torre Cinza", "Vila Ferrugem",
	"Entreposto 9", "Vale Mudo", "Posto Delta", "Ninho Baixo", "Cais Morto", "Estação Fênix"]

var seed_value: int = 0
var rng := RandomNumberGenerator.new()
var ground: TileMapLayer
var art_ground: Node2D
var build_layer: TileMapLayer
var entities: Node2D
var ghost: BuildGhost
var player: Player
var noise := FastNoiseLite.new()
var spore_noise := FastNoiseLite.new()
var villages: Array[VillageData] = []
var containers: Array[LootContainer] = []
var structures := {}
var occupied := {}
var terrain_deltas := {}
var removed_cells := {}
var road_cells := {}
var road_blocks := {}
var routes := {}
var _ground_art: Array[Dictionary] = []

var _spawn_t := 2.0
var _village_t := 6.0
var _respawn_t := -1.0


# ======================================================================= geração
func generate(new_seed: int) -> void:
	seed_value = new_seed
	rng.seed = new_seed
	noise.seed = new_seed
	noise.frequency = 0.045
	noise.fractal_octaves = 3
	spore_noise.seed = new_seed + 77
	spore_noise.frequency = 0.08
	var ts := _build_tileset()
	ground = TileMapLayer.new()
	ground.tile_set = ts
	add_child(ground)
	art_ground = Node2D.new()
	add_child(art_ground)
	build_layer = TileMapLayer.new()
	build_layer.tile_set = ts
	add_child(build_layer)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	ghost = BuildGhost.new()
	add_child(ghost)
	_paint_terrain()
	_place_villages()
	_connect_villages()
	_decorate_villages()
	_scatter_ruins()
	_flush_ground_art()
	player = Player.new()
	player.world = self
	entities.add_child(player)
	player.died.connect(_on_player_died)


func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(TILE_W, TILE_H)
	var source := TileSetAtlasSource.new()
	source.texture = load(GenCatalog.GROUND_PATH)
	source.texture_region_size = Vector2i(TILE_W, TILE_H)
	for t in T.size():
		for v in GenCatalog.GROUND_VARIANTS:
			source.create_tile(Vector2i(t, v))
	ts.add_source(source, 0)
	return ts


## Célula do atlas do chão: tipo na coluna, variação (estável por posição) na linha.
func _gtile(t: int, c: Vector2i) -> Vector2i:
	var h := posmod(c.x * 73856093 ^ c.y * 19349663, 1000)
	var v := 0
	if h > 640:
		v = 1 if h < 860 else 2
	return Vector2i(t, v)


func _paint_terrain() -> void:
	var lim := int(RADIUS) + 6
	for x in range(-lim, lim + 1):
		for y in range(-lim, lim + 1):
			var d := Vector2(x, y).length()
			if d > RADIUS + 5.0:
				continue
			var t: int = T.CONC_A if noise.get_noise_2d(x * 3.1 + 40.0, y * 3.1) < 0.05 else T.CONC_B
			var n := noise.get_noise_2d(x, y)
			if n > 0.28:
				t = T.TERRA
			elif n < -0.3:
				t = T.MANCHA
			var edge := smoothstep(RADIUS * 0.55, RADIUS, d)
			var sn := spore_noise.get_noise_2d(x * 1.7, y * 1.7) * 0.5 + 0.5
			if d > RADIUS - 1.5 or sn < edge * 0.9:
				t = T.ESPOROS
			ground.set_cell(Vector2i(x, y), 0, _gtile(t, Vector2i(x, y)))


func _place_villages() -> void:
	var v0 := VillageData.new()
	v0.setup(0, VILLAGE_NAMES[0], Vector2i.ZERO, true, rng)
	villages.append(v0)
	var tries := 0
	while villages.size() < N_VILLAGES and tries < 500:
		tries += 1
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(18.0, RADIUS - 14.0)
		var c := Vector2i(roundi(cos(ang) * dist), roundi(sin(ang) * dist))
		var ok := true
		for v in villages:
			if Vector2(v.cell - c).length() < 20.0:
				ok = false
		if not ok:
			continue
		var vd := VillageData.new()
		vd.setup(villages.size(), VILLAGE_NAMES[villages.size()], c, false, rng)
		villages.append(vd)


func _connect_villages() -> void:
	for i in range(1, villages.size()):
		var best := 0
		var best_d := 1e9
		for j in i:
			var d := Vector2(villages[i].cell - villages[j].cell).length()
			if d < best_d:
				best_d = d
				best = j
		_carve_road(villages[best], villages[i])


func _carve_road(a: VillageData, b: VillageData) -> void:
	var c := a.cell
	var path: Array[Vector2i] = []
	while c.x != b.cell.x:
		c.x += signi(b.cell.x - c.x)
		path.append(c)
	while c.y != b.cell.y:
		c.y += signi(b.cell.y - c.y)
		path.append(c)
	var pts := PackedVector2Array()
	pts.append(ground.map_to_local(a.cell))
	_mark_road_block(a.cell)
	_mark_road_block(b.cell)
	for p in path:
		ground.set_cell(p, 0, _gtile(T.ESTRADA, p))
		road_cells[p] = true
		_mark_road_block(p)
		pts.append(ground.map_to_local(p))
	routes["%d>%d" % [a.id, b.id]] = pts
	var rev := PackedVector2Array()
	for i in range(pts.size() - 1, -1, -1):
		rev.append(pts[i])
	routes["%d>%d" % [b.id, a.id]] = rev
	a.links.append(b.id)
	b.links.append(a.id)


## A arte de estrada tem 2x2 células: cada célula do caminho vira o bloco 2x2 que a contém.
func _mark_road_block(c: Vector2i) -> void:
	var origin := Vector2i(floori(c.x / 2.0) * 2, floori(c.y / 2.0) * 2)
	if road_blocks.has(origin):
		return
	road_blocks[origin] = true
	for dx in 2:
		for dy in 2:
			var cell := origin + Vector2i(dx, dy)
			road_cells[cell] = true
			ground.set_cell(cell, 0, _gtile(T.ESTRADA, cell))
	_queue_ground_art("Road_Chunk5", rng.randi() % 4, origin, 1)


## Enfileira um bloco de chão do pacote; _flush_ground_art() desenha em ordem de profundidade.
func _queue_ground_art(art: String, v: int, cell: Vector2i, layer: int) -> void:
	_ground_art.append({"art": art, "v": v, "cell": cell, "layer": layer})


func _flush_ground_art() -> void:
	_ground_art.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["layer"] != b["layer"]:
			return a["layer"] < b["layer"]
		var ka: int = a["cell"].x + a["cell"].y
		var kb: int = b["cell"].x + b["cell"].y
		if ka != kb:
			return ka < kb
		return a["cell"].x < b["cell"].x)
	for e in _ground_art:
		var sp := ArtDB.sprite(e["art"], e["v"], "top")
		sp.position += ground.map_to_local(e["cell"]) + Vector2(0, -HALF_H)
		art_ground.add_child(sp)
	_ground_art.clear()


func _decorate_villages() -> void:
	for v in villages:
		for dx in range(-6, 7):
			for dy in range(-6, 7):
				var c := v.cell + Vector2i(dx, dy)
				if not road_cells.has(c):
					ground.set_cell(c, 0, _gtile(T.VILA, c))
		# praça: 3x3 blocos de calçada de 4x4 células, mais calçadas menores ao redor
		for i in 3:
			for j in 3:
				_queue_ground_art("Sidewalk_Tile1", rng.randi() % 4, v.cell + Vector2i(-6 + i * 4, -6 + j * 4), 0)
		for k in 7:
			var ring := Vector2i(rng.randi_range(-5, 4) * 2, rng.randi_range(-5, 4) * 2)
			if maxi(absi(ring.x), absi(ring.y)) >= 8 and not road_cells.has(v.cell + ring):
				_queue_ground_art("Sidewalk_Chunk2", rng.randi() % 4, v.cell + ring, 0)
		if v.safe:
			_build_shelter(v)
			for i in 3:
				_place_random_building(v.cell, 5, 8)
		else:
			for i in 5:
				_place_random_building(v.cell, 3, 8)
			for i in 4:
				var c2 := v.cell + Vector2i(rng.randi_range(-4, 4), rng.randi_range(-4, 4))
				if _free_cell(c2):
					var tables := ["comum", "medico", "tecnico"]
					_add_container(c2, tables[rng.randi() % 3], v.id)
		for i in 3:
			var pc := v.cell + Vector2i(rng.randi_range(-6, 6), rng.randi_range(-6, 6))
			if _free_cell(pc) and (not v.safe or maxi(absi(pc.x - v.cell.x), absi(pc.y - v.cell.y)) >= 3):
				_add_prop(PROPS[rng.randi() % PROPS.size()], rng.randi() % 4, pc)


func _pick_building() -> String:
	var total := 0.0
	for b in BUILDINGS:
		total += float(b[1])
	var r := rng.randf() * total
	for b in BUILDINGS:
		r -= float(b[1])
		if r <= 0.0:
			return b[0]
	return BUILDINGS[0][0]


func _footprint_free(c: Vector2i, fp: Vector2i) -> bool:
	for i in fp.x:
		for j in fp.y:
			if not _free_cell(c + Vector2i(i, j)):
				return false
	return true


## Tenta colocar um prédio em um anel [rmin, rmax] (distância de xadrez) ao redor de center.
func _place_random_building(center: Vector2i, rmin: int, rmax: int) -> bool:
	for attempt in 40:
		var art := _pick_building()
		var v := rng.randi() % 4
		var fp := ArtDB.footprint(art, v)
		var c := center + Vector2i(rng.randi_range(-rmax, rmax), rng.randi_range(-rmax, rmax))
		if maxi(absi(c.x - center.x), absi(c.y - center.y)) < rmin:
			continue
		if _footprint_free(c, fp):
			_add_building(art, v, c, fp)
			return true
	return false


func _add_building(art: String, v: int, c: Vector2i, fp: Vector2i) -> Structure:
	var s := Structure.new()
	s.kind = "edificio"
	s.cell = c
	s.world = self
	s.art = art
	s.art_variant = v
	s.fp = fp
	# centro da pegada: topo da célula inicial + deslocamento até o centro do losango
	var top := ground.map_to_local(c) + Vector2(0, -HALF_H)
	var w := float(fp.x)
	var d := float(fp.y)
	s.position = top + Vector2(HALF_W * 0.5 * (w - d), HALF_H * 0.5 * (w + d))
	entities.add_child(s)
	for cell in s.cells():
		structures[cell] = s
		occupied[cell] = true
	return s


func _add_prop(art: String, v: int, c: Vector2i) -> void:
	var pr := Prop.new()
	pr.art = art
	pr.variant = v
	pr.position = ground.map_to_local(c)
	entities.add_child(pr)
	occupied[c] = true


func _remove_structure(s: Structure) -> void:
	for cell in s.cells():
		structures.erase(cell)
		occupied.erase(cell)
	s.queue_free()


func _build_shelter(v: VillageData) -> void:
	var gen := _add_structure("gerador", v.cell + Vector2i(2, -2))
	gen.eternal = true
	gen.fuel = 100.0
	_add_structure("purificador", v.cell + Vector2i(-1, -1)).eternal = true
	_add_structure("vedacao", v.cell + Vector2i(1, 1)).eternal = true
	var starter := _add_container(v.cell + Vector2i(-2, 1), "comum", v.id)
	starter.items = {"feijao": 3, "agua_limpa": 3, "bandagem": 2, "sucata": 4, "madeira": 4, "metal": 2}


func _scatter_ruins() -> void:
	for i in 80:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(6.0, RADIUS - 8.0)
		var c := Vector2i(roundi(cos(ang) * dist), roundi(sin(ang) * dist))
		if Vector2(c).length() < 9.0 or not _free_cell(c):
			continue
		if rng.randf() < 0.65:
			_place_random_building(c, 0, 3)
		if rng.randf() < 0.75:
			var cc2 := c + Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
			if _free_cell(cc2):
				var tables := ["comum", "comum", "medico", "tecnico"]
				_add_container(cc2, tables[rng.randi() % 4], -1)
		if rng.randf() < 0.3:
			var pc := c + Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
			if _free_cell(pc):
				_add_prop(PROPS[rng.randi() % PROPS.size()], rng.randi() % 4, pc)


func _free_cell(c: Vector2i) -> bool:
	return not occupied.has(c) and not road_cells.has(c) and Vector2(c).length() < RADIUS - 3.0


func _add_structure(kind: String, c: Vector2i) -> Structure:
	var s := Structure.new()
	s.kind = kind
	s.cell = c
	s.world = self
	s.position = ground.map_to_local(c)
	entities.add_child(s)
	structures[c] = s
	occupied[c] = true
	return s


func _add_container(c: Vector2i, table: String, village_id: int) -> LootContainer:
	var lc := LootContainer.new()
	lc.id = containers.size()
	lc.table = table
	lc.village_id = village_id
	lc.items = DB.roll_loot(table, rng.randi_range(2, 4), rng)
	lc.position = ground.map_to_local(c)
	entities.add_child(lc)
	containers.append(lc)
	occupied[c] = true
	return lc


# ======================================================================= esporos
func tile_pos(world_pos: Vector2) -> Vector2:
	return Vector2((world_pos.x / HALF_W + world_pos.y / HALF_H) * 0.5, (world_pos.y / HALF_H - world_pos.x / HALF_W) * 0.5)


func edge_ratio(world_pos: Vector2) -> float:
	return clampf(tile_pos(world_pos).length() / RADIUS, 0.0, 1.5)


func spore_at(world_pos: Vector2) -> float:
	var tp := tile_pos(world_pos)
	var s := 0.08 + 1.4 * smoothstep(RADIUS * 0.55, RADIUS, tp.length())
	s += spore_noise.get_noise_2d(tp.x * 0.6, tp.y * 0.6) * 0.04
	for n in get_tree().get_nodes_in_group("seals"):
		var st := n as Structure
		if st.powered:
			var off := world_pos - st.position
			if Vector2(off.x, off.y * 2.0).length() < SEAL_RADIUS:
				return 0.0
	return maxf(0.0, s)


func in_safe_zone(world_pos: Vector2) -> bool:
	return Vector2(world_pos.x, world_pos.y * 2.0).length() < SAFE_RADIUS_PX


func is_powered(world_pos: Vector2) -> bool:
	for n in get_tree().get_nodes_in_group("generators"):
		var g := n as Structure
		if g.fuel > 0.0:
			var off := world_pos - g.position
			if Vector2(off.x, off.y * 2.0).length() < POWER_RADIUS_PX:
				return true
	return false


func purifier_near(world_pos: Vector2) -> bool:
	for n in get_tree().get_nodes_in_group("purifiers"):
		var st := n as Structure
		if st.powered:
			var off := world_pos - st.position
			if Vector2(off.x, off.y * 2.0).length() < PURIFY_RADIUS_PX:
				return true
	return false


# ======================================================================= construção
func mouse_cell() -> Vector2i:
	return ground.local_to_map(ground.to_local(get_global_mouse_position()))


func can_place_at(kind: String, c: Vector2i, p: Player = null) -> bool:
	if Vector2(c).length() > RADIUS - 3.0:
		return false
	if kind == "piso":
		if build_layer.get_cell_source_id(c) != -1:
			return false
	elif occupied.has(c):
		return false
	if p != null:
		var off := ground.map_to_local(c) - p.position
		var d := Vector2(off.x, off.y * 2.0).length()
		if d > 275.0:
			return false
		if kind != "piso" and d < 30.0:
			return false
	return true


func try_place(kind: String, c: Vector2i, p: Player) -> bool:
	var def: Dictionary = DB.BUILDS[kind]
	if not can_place_at(kind, c, p):
		Game.say("Não dá para construir aqui.")
		return false
	if not p.data.meets(def["req"]):
		Game.say("Conhecimento insuficiente: exige %s." % DB.req_text(def["req"]))
		return false
	if not p.data.can_afford(def["custo"]):
		Game.say("Faltam materiais: %s." % DB.cost_text(def["custo"]))
		return false
	p.data.pay(def["custo"])
	if kind == "piso":
		build_layer.set_cell(c, 0, _gtile(T.PISO, c))
		terrain_deltas[c] = T.PISO
	else:
		var s := _add_structure(kind, c)
		if kind == "gerador":
			s.fuel = 0.0
	p.data.add_xp_map(def["xp"])
	Game.say("Construído: %s." % def["nome"])
	return true


func try_demolish(c: Vector2i, p: Player) -> bool:
	var off := ground.map_to_local(c) - p.position
	if Vector2(off.x, off.y * 2.0).length() > 275.0:
		Game.say("Longe demais.")
		return false
	if structures.has(c):
		var s: Structure = structures[c]
		if s.eternal:
			Game.say("Você não pode demolir isto.")
			return false
		if s.kind == "ruina" or s.kind == "edificio":
			var big := s.kind == "edificio"
			p.data.add_item("sucata", rng.randi_range(3, 5) if big else rng.randi_range(1, 2))
			if rng.randf() < (0.8 if big else 0.25):
				p.data.add_item("metal", rng.randi_range(1, 2) if big else 1)
			removed_cells[s.cell] = true
			Game.say("Você desmontou %s (+materiais)." % ("um prédio" if big else "uma ruína"))
		else:
			var cost: Dictionary = DB.BUILDS[s.kind]["custo"]
			for k in cost:
				var back := floori(float(cost[k]) / 2.0)
				if back > 0:
					p.data.add_item(k, back)
			Game.say("Estrutura desmontada (50% dos materiais).")
		_remove_structure(s)
		return true
	if build_layer.get_cell_source_id(c) != -1:
		build_layer.erase_cell(c)
		terrain_deltas.erase(c)
		p.data.add_item("sucata", 1)
		Game.say("Piso removido.")
		return true
	return false


# ======================================================================= inimigos / loot
func spawn_infected(pos: Vector2, elite: bool) -> Infected:
	var e := Infected.new()
	e.setup(elite)
	e.world = self
	e.player = player
	e.position = pos
	entities.add_child(e)
	return e


func drop_loot(pos: Vector2, items: Dictionary) -> void:
	if items.is_empty():
		return
	var lc := LootContainer.new()
	lc.temporary = true
	lc.items = items
	lc.position = pos
	entities.add_child(lc)


func _random_spawn_pos() -> Vector2:
	var a := rng.randf() * TAU
	return player.position + Vector2(cos(a) * rng.randf_range(440.0, 540.0), sin(a) * rng.randf_range(260.0, 330.0))


func _spawn_step() -> void:
	var infected := get_tree().get_nodes_in_group("infected")
	var normal := 0
	var elites := 0
	for n in infected:
		var e := n as Infected
		if e.legacy:
			continue
		if e.position.distance_to(player.position) > 950.0:
			e.queue_free()
			continue
		if e.elite:
			elites += 1
		else:
			normal += 1
	var s := spore_at(player.position)
	if s >= 0.5:
		if elites < 12:
			var pos := _random_spawn_pos()
			if tile_pos(pos).length() < RADIUS + 3.0:
				spawn_infected(pos, true)
		return
	var cap := 3 + int(clampf(tile_pos(player.position).length() / RADIUS, 0.0, 1.0) * 6.0)
	if normal < cap:
		var pos2 := _random_spawn_pos()
		if tile_pos(pos2).length() < RADIUS and not in_safe_zone(pos2):
			spawn_infected(pos2, false)
	for v in villages:
		if not v.infested:
			continue
		var vpos := ground.map_to_local(v.cell)
		if vpos.distance_to(player.position) > 900.0:
			continue
		var near := 0
		for n in infected:
			if (n as Node2D).position.distance_to(vpos) < 320.0:
				near += 1
		if near < 6:
			spawn_infected(vpos + Vector2(rng.randf_range(-150, 150), rng.randf_range(-75, 75)), rng.randf() < 0.2)


# ======================================================================= simulação de vilas
func _village_step() -> void:
	for v in villages:
		var was := v.infested
		v.step(rng, clampf(Vector2(v.cell).length() / RADIUS, 0.0, 1.0))
		if v.infested and not was:
			Game.say("A vila %s foi infestada!" % v.nome)
		if v.infested:
			_check_cleared(v)
			continue
		v.caravan_cd -= 6.0
		if v.caravan_cd <= 0.0:
			v.caravan_cd = rng.randf_range(40.0, 80.0)
			_try_spawn_caravan(v)
		for lc in containers:
			if lc.village_id == v.id and lc.items.is_empty() and rng.randf() < 0.08:
				var total := float(v.stock["comida"]) + float(v.stock["sucata"]) + float(v.stock["medico"])
				if total > 15.0:
					var keys := ["comida", "sucata", "medico"]
					var k: String = keys[rng.randi() % 3]
					v.stock[k] = maxf(0.0, float(v.stock[k]) - 4.0)
					lc.items = DB.roll_loot(lc.table, 1, rng)
					lc.dirty = true
					lc.queue_redraw()


func _check_cleared(v: VillageData) -> void:
	var vpos := ground.map_to_local(v.cell)
	var near := 0
	for n in get_tree().get_nodes_in_group("infected"):
		if (n as Node2D).position.distance_to(vpos) < 320.0:
			near += 1
	if near == 0 and player != null and vpos.distance_to(player.position) < 500.0:
		v.clear_t += 6.0
		if v.clear_t >= 30.0:
			v.infested = false
			v.infestation = 25.0
			v.pop = 3
			v.clear_t = 0.0
			Game.say("A vila %s foi libertada! Sobreviventes voltam a ela." % v.nome)
	else:
		v.clear_t = 0.0


func _try_spawn_caravan(v: VillageData) -> void:
	if float(v.stock["comida"]) < 25.0:
		return
	var best: VillageData = null
	for id in v.links:
		var other := villages[id]
		if other.infested:
			continue
		if best == null or float(other.stock["comida"]) < float(best.stock["comida"]):
			best = other
	if best == null:
		return
	var key := "%d>%d" % [v.id, best.id]
	if not routes.has(key):
		return
	var c := Caravan.new()
	c.world = self
	c.from_id = v.id
	c.to_id = best.id
	c.cargo = {"comida": 10.0, "sucata": 5.0, "medico": 2.0}
	for k in c.cargo:
		v.stock[k] = maxf(0.0, float(v.stock[k]) - float(c.cargo[k]))
	c.path = routes[key]
	c.position = c.path[0]
	entities.add_child(c)


func caravan_arrived(c: Caravan) -> void:
	var dest := villages[c.to_id]
	if dest.infested or rng.randf() < 0.12:
		dest.infestation = minf(100.0, dest.infestation + 8.0)
		return
	for k in c.cargo:
		dest.stock[k] = float(dest.stock[k]) + float(c.cargo[k])
	dest.infestation = maxf(0.0, dest.infestation - 8.0)
	if player != null and c.position.distance_to(player.position) < 700.0:
		Game.say("Uma caravana chegou a %s." % dest.nome)


# ======================================================================= vida e morte
func _process(delta: float) -> void:
	if player == null:
		return
	if _respawn_t > 0.0:
		_respawn_t -= delta
		if _respawn_t <= 0.0:
			spawn_new_survivor()
		return
	if player.is_dead():
		return
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = 1.2
		_spawn_step()
	_village_t -= delta
	if _village_t <= 0.0:
		_village_t = 6.0
		_village_step()


func spawn_new_survivor() -> void:
	var data := SurvivorData.random_survivor(Game.rng)
	data.message.connect(Game.say)
	var pos := ground.map_to_local(Vector2i.ZERO) + Vector2(Game.rng.randf_range(-20, 20), Game.rng.randf_range(4, 14))
	player.respawn(data, pos)
	if Game.hud != null:
		Game.hud.hide_death()
	Game.say("Novo sobrevivente: %s. Você acorda no Abrigo Alfa." % data.nome)


func _on_player_died(data: SurvivorData, pos: Vector2) -> void:
	Game.legacy.append({"nome": data.nome, "causa": data.death_cause, "tipo": data.death_kind,
		"tempo": data.time_alive, "pos": [pos.x, pos.y]})
	var inv := data.inventory.duplicate()
	for slot in data.implants:
		var id: String = data.implants[slot]["id"]
		inv[id] = int(inv.get(id, 0)) + 1
	if data.death_kind == "infeccao":
		var e := spawn_infected(pos, true)
		e.legacy = true
		e.legacy_name = data.nome
		e.loot = data.inventory.duplicate()
		e.implants = data.implants.duplicate(true)
		e.home = pos
		Game.say("%s se reergue como um infectado de elite..." % data.nome)
	else:
		var c := Corpse.new()
		c.nome = data.nome
		c.items = inv
		c.world = self
		c.position = pos
		entities.add_child(c)
	if Game.hud != null:
		Game.hud.show_death(data)
	_respawn_t = 5.0
	Game.save_game()


# ======================================================================= persistência (deltas)
func to_dict() -> Dictionary:
	var st: Array = []
	for c in structures:
		var s: Structure = structures[c]
		if s.kind == "ruina" or s.kind == "edificio" or s.eternal:
			continue
		st.append(s.to_dict())
	var floors: Array = []
	for c in terrain_deltas:
		floors.append([c.x, c.y, int(terrain_deltas[c])])
	var removed: Array = []
	for c in removed_cells:
		removed.append([c.x, c.y])
	var cont := {}
	for lc in containers:
		if lc.dirty:
			cont[str(lc.id)] = lc.items.duplicate()
	var corpses: Array = []
	for n in get_tree().get_nodes_in_group("corpses"):
		var co := n as Corpse
		corpses.append({"pos": [co.position.x, co.position.y], "nome": co.nome, "items": co.items.duplicate(),
			"decomp": co.decomp})
	var elites: Array = []
	for n in get_tree().get_nodes_in_group("infected"):
		var e := n as Infected
		if e.legacy:
			elites.append({"pos": [e.position.x, e.position.y], "home": [e.home.x, e.home.y], "nome": e.legacy_name,
				"loot": e.loot.duplicate(), "implants": e.implants.duplicate(true), "hp": e.hp})
	var vil: Array = []
	for v in villages:
		vil.append(v.to_dict())
	return {"version": 1, "seed": seed_value, "structures": st, "floors": floors, "removed": removed,
		"containers": cont, "corpses": corpses, "elites": elites, "villages": vil,
		"survivor": player.data.to_dict() if player.data != null else {},
		"player_pos": [player.position.x, player.position.y]}


func apply_save(save: Dictionary) -> void:
	for r in save.get("removed", []):
		var c := Game.v2i(r)
		removed_cells[c] = true
		if structures.has(c):
			_remove_structure(structures[c])
	for f in save.get("floors", []):
		var c2 := Vector2i(int(f[0]), int(f[1]))
		build_layer.set_cell(c2, 0, _gtile(int(f[2]), c2))
		terrain_deltas[c2] = int(f[2])
	for sd in save.get("structures", []):
		if structures.has(Game.v2i(sd["cell"])):
			continue
		var s2 := _add_structure(str(sd["kind"]), Game.v2i(sd["cell"]))
		s2.fuel = float(sd.get("fuel", 0.0))
		s2.open = bool(sd.get("open", false))
	var cont: Dictionary = save.get("containers", {})
	for k in cont:
		var idx := int(k)
		if idx >= 0 and idx < containers.size():
			var items := {}
			for it in cont[k]:
				items[str(it)] = int(cont[k][it])
			containers[idx].items = items
			containers[idx].dirty = true
			containers[idx].queue_redraw()
	for cd in save.get("corpses", []):
		var co := Corpse.new()
		co.nome = str(cd["nome"])
		for it in cd["items"]:
			co.items[str(it)] = int(cd["items"][it])
		co.decomp = float(cd.get("decomp", 0.0))
		co.world = self
		co.position = Game.v2(cd["pos"])
		entities.add_child(co)
	for ed in save.get("elites", []):
		var e := spawn_infected(Game.v2(ed["pos"]), true)
		e.legacy = true
		e.legacy_name = str(ed["nome"])
		e.home = Game.v2(ed["home"])
		e.hp = float(ed.get("hp", e.max_hp))
		for it in ed["loot"]:
			e.loot[str(it)] = int(ed["loot"][it])
		e.implants = ed["implants"]
	for vd in save.get("villages", []):
		var vid := int(vd["id"])
		if vid < villages.size():
			villages[vid].apply_dict(vd)
	Game.legacy = save.get("legacy", [])
	Game.play_time = float(save.get("play_time", 0.0))
	var data := SurvivorData.from_dict(save.get("survivor", {}))
	data.message.connect(Game.say)
	player.respawn(data, Game.v2(save.get("player_pos", [0.0, 10.0])))

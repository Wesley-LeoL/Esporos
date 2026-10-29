class_name World
extends Node2D
## Mundo procedural isométrico: terreno por ruído, estradas, vilas com simulação em
## segundo plano, concentração de esporos (letal na borda), infectados, construção,
## morte/legado e persistência apenas dos deltas feitos pelo jogador.
##
## Mundo em chunks (fase 7): a geração só PLANEJA (dados determinísticos pela seed, iguais
## em todos os peers): prédios, objetos, caixas, arte de chão, estradas e vilas. Os nós e os
## tiles só existem nos chunks de CHUNK x CHUNK células perto de quem está olhando (todos
## os jogadores no anfitrião; o próprio jogador nos clientes). O estado que muda (caixas,
## construções, baús, pisos) fica em dicionários de dados e vale com o chunk carregado ou não.

## Grade da arte: células isométricas 2:1 de 80x40 px (pacote em assets/art/tiles).
const TILE_W := 80
const TILE_H := 40
const HALF_W := TILE_W / 2.0
const HALF_H := TILE_H / 2.0
const RADIUS := 150.0
const CHUNK := 16
## Chunks carregados ao redor de quem olha (distância de xadrez) e distância para descarregar.
const LOAD_R := 2
const UNLOAD_R := 3
const SAFE_RADIUS_PX := 325.0
const SEAL_RADIUS := 190.0
const POWER_RADIUS_PX := 525.0
const PURIFY_RADIUS_PX := 150.0
const N_VILLAGES := 16

## Tipos de chão (colunas do atlas gerado; os índices vão para os saves).
enum T { CONC_A, CONC_B, ESPOROS, ESTRADA, TERRA, PISO, MANCHA, VILA, PISO_MADEIRA, PISO_CONCRETO,
	GRAMA, GRAMA_SECA, CALCADA, FAIXA_X, FAIXA_Y, TERRA_BATIDA, ZEBRA_X, ZEBRA_Y, LAVOURA, GRAMA_ESPOROS, AZULEJO, CARPETE }

## Clima: [peso do sorteio, vento mínimo, vento máximo].
const WEATHERS := {"limpo": [35, 0.15, 0.4], "nublado": [25, 0.3, 0.6], "chuva": [20, 0.4, 0.7],
	"tempestade": [8, 0.8, 1.0], "neblina": [12, 0.0, 0.2]}
const WEATHER_NAMES := {"limpo": "Céu limpo", "nublado": "Nublado", "chuva": "Chuva", "tempestade": "Tempestade",
	"neblina": "Névoa de esporos"}
## Duração de um dia em segundos de jogo (1 hora do jogo = 1 minuto).
const DAY_SECONDS := 1440.0
## Distância (em tiles) que liga construções de energia na mesma rede.
const GRID_LINK := 10.0
## Prioridade de quem recebe energia quando falta.
const POWER_PRIORITY := ["vedacao", "purificador", "torre", "poste", "luminaria", "letreiro"]

# Prédios e objetos do pacote FreeSample (peso de sorteio dos prédios).
const BUILDINGS: Array = [["BuildingBlock1", 15], ["BuildingBlock2", 15], ["BuildingBlock18", 20],
	["BuildingBlock19", 20], ["BuildingBlock24", 25], ["Building3", 5]]
const PROPS: Array[String] = ["Advertising5", "Advertising6", "Advertising7", "SateliteDish2"]
## Versão do save: muda quando a geração do mundo muda (saves antigos não batem com o mapa).
const SAVE_VERSION := 7
## Versões de save que ainda carregam. Antes da 5 o mapa era outro (raio 64, sem chunks):
## desses saves só os sobreviventes e o legado são aproveitados (ver Game.read_save).
const SAVE_COMPAT := [3, 4, 5, 6, 7]
const VILLAGE_NAMES: Array[String] = ["Abrigo Alfa", "Poço Seco", "Torre Cinza", "Vila Ferrugem",
	"Entreposto 9", "Vale Mudo", "Posto Delta", "Ninho Baixo", "Cais Morto", "Estação Fênix", "Morro Azul",
	"Forte Néon", "Cratera", "Porto Velho", "Colmeia", "Sétima Linha", "Refúgio Sul", "Barreira Leste"]

var seed_value: int = 0
var rng := RandomNumberGenerator.new()
var ground: TileMapLayer
var art_ground: Node2D
var build_layer: TileMapLayer
var entities: Node2D
## Entidades replicadas (jogadores, infectados, cadáveres, sacos, caravanas): filhas deste
## nó, criadas só pelo servidor através do MultiplayerSpawner.
var net_root: Node2D
var spawner: MultiplayerSpawner
var ghost: BuildGhost
## peer -> Player
var players := {}
var noise := FastNoiseLite.new()
var spore_noise := FastNoiseLite.new()
var villages: Array[VillageData] = []
## Plano da geração: chunk -> lista de entradas {"t": "b" prédio, "p" objeto, "c" caixa,
## "g" arte de chão, "cv" tampa de bueiro}.
var plan := {}
## Prédios planejados pela célula de origem (para demolir com o chunk descarregado).
var planned_buildings := {}
## Caixas do mapa: id -> {"cell", "table", "village", "items", "dirty"}.
var container_data: Array[Dictionary] = []
## Nós das caixas carregadas (id -> LootContainer).
var container_nodes := {}
## Construções fixas (abrigo) e dos jogadores: célula -> {"kind", "fuel", "open", "eternal", ...}.
var built := {}
## Paredes de borda: Vector3i(x, y, d) -> {"kind", "open"}. Nós carregados em wall_nodes.
var walls := {}
var wall_nodes := {}
## Células de prédios do mapa (não dá para pôr parede encostada nelas).
var building_cells := {}
## Clima atual (o anfitrião sorteia e manda para todos).
var weather := {"tipo": "limpo", "vento": 0.3}
var _weather_until := 240.0
var canvas_mod: CanvasModulate
var _sky_t := 0.0
var _power_t := 1.0
var _rain_t := 0.0
## Baús construídos: célula -> lista de itens. Nós carregados em 'chests'.
var chest_data := {}
var chests := {}
## Nós de estruturas carregadas (célula -> Structure; prédios ocupam várias células).
var structures := {}
## Células ocupadas (dados, valem para o mapa inteiro).
var occupied := {}
## Chunks carregados: chunk -> {"nodes": Array, "art": Node2D}.
var loaded := {}
var _chunk_t := 0.0
## Vagas de veículos abandonados (planejadas): [{"kind", "cell"}]. Só o anfitrião cria os
## veículos (entidades replicadas) num mundo novo; depois eles vão para o save.
var vehicle_spots: Array = []
var terrain_deltas := {}
var removed_cells := {}
var road_cells := {}
## Lugares do mapa (MapGen): [{"cell", "tipo" cidade/aldeia, "estado" viva/abandonada/esporos,
## "r" raio, "nome", "vid" vila viva ou -1}].
var places: Array = []
## Lugares tomados por esporos: [centro (Vector2), raio] (o ar fica pesado neles).
var dead_zones: Array = []
## Prédios exploráveis: id -> {"rect": Rect2i, "roof", "tipo", "estado"}; célula -> id.
var houses := {}
var house_cells := {}
## Paredes dos prédios do mapa: Vector3i(x, y, d) -> {"kind", "open"}, e as chaves por chunk.
var map_walls := {}
var map_walls_by_chunk := {}
## Prédios abertos agora (jogador local dentro): id -> true.
var house_open := {}
## Sombra do interior de cada prédio visto de fora (0 = sem sombra, 1 = escuro).
var house_shade := {}
## Chão planejado que foge da regra da zona (praças, parques, lavouras, estacionamentos).
var ground_cells := {}
## Lavouras: livres para andar, mas nada é posto em cima.
var field_cells := {}
## Rotas das caravanas (calculadas quando a primeira caravana sai): "a>b" -> pontos.
var routes := {}

var _spawn_t := 2.0
var _village_t := 6.0
var _net_counter := 0


# ======================================================================= geração
func generate(new_seed: int) -> void:
	name = "World"
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
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)
	net_root = Node2D.new()
	net_root.name = "Net"
	net_root.y_sort_enabled = true
	entities.add_child(net_root)
	spawner = MultiplayerSpawner.new()
	spawner.name = "Spawner"
	add_child(spawner)
	spawner.spawn_path = spawner.get_path_to(net_root)
	spawner.spawn_function = _spawn_entity
	ghost = BuildGhost.new()
	add_child(ghost)
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)
	MapGen.new(self).generate()


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


## Tipo de chão de uma célula (calculado ao carregar o chunk). -1 = fora do mapa.
func _terrain(c: Vector2i) -> int:
	var d := Vector2(c).length()
	if d > RADIUS + 5.0:
		return -1
	if road_cells.has(c):
		return int(road_cells[c])
	var t: int
	if ground_cells.has(c):
		t = int(ground_cells[c])
		if t != T.GRAMA and t != T.GRAMA_SECA:
			return t
	elif is_sidewalk(c):
		return T.CALCADA
	else:
		var n := noise.get_noise_2d(c.x, c.y)
		t = T.GRAMA
		if n > 0.34:
			t = T.TERRA
		elif n > 0.24 or n < -0.25:
			t = T.GRAMA_SECA
	for dz in dead_zones:
		var dd := Vector2(c).distance_to(dz[0])
		var k := spore_noise.get_noise_2d(c.x * 2.3, c.y * 2.3) * 3.0
		if dd < float(dz[1]) + k:
			return T.ESPOROS
		if dd < float(dz[1]) + 4.0 + k:
			return T.GRAMA_ESPOROS
	var edge := smoothstep(RADIUS * 0.55, RADIUS, d)
	var sn := spore_noise.get_noise_2d(c.x * 1.7, c.y * 1.7) * 0.5 + 0.5
	if d > RADIUS - 1.5 or sn < edge * 0.9:
		return T.ESPOROS
	if sn < edge * 0.9 + 0.1:
		return T.GRAMA_ESPOROS
	return t


## Calçada: célula fora da pista encostada numa rua asfaltada, dentro de uma cidade.
func is_sidewalk(c: Vector2i) -> bool:
	if road_cells.has(c) or house_cells.has(c):
		return false
	var in_town := false
	for pl in places:
		if pl["tipo"] == "cidade" and Vector2(c - pl["cell"]).length() <= float(pl["r"]) + 1.5:
			in_town = true
			break
	if not in_town:
		return false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var rt: int = road_cells.get(c + Vector2i(dx, dy), -1)
			if rt >= 0 and rt != T.TERRA_BATIDA:
				return true
	return false


## Esporos no centro de uma célula (para a geração escolher árvores mortas etc.).
func spore_level_cell(c: Vector2i) -> float:
	return 0.08 + 1.4 * smoothstep(RADIUS * 0.55, RADIUS, Vector2(c).length())


## Vaga livre na pista para um veículo abandonado.
func _free_road(c: Vector2i) -> bool:
	if occupied.has(c):
		return false
	occupied[c] = true
	return true


static func chunk_of(c: Vector2i) -> Vector2i:
	return Vector2i(floori(c.x / float(CHUNK)), floori(c.y / float(CHUNK)))


func _plan_add(c: Vector2i, e: Dictionary) -> void:
	var ch := chunk_of(c)
	if not plan.has(ch):
		plan[ch] = []
	plan[ch].append(e)


func _add_building(art: String, v: int, c: Vector2i, fp: Vector2i) -> void:
	var e := {"t": "b", "art": art, "v": v, "cell": c, "fp": fp}
	_plan_add(c, e)
	planned_buildings[c] = e
	for i in fp.x:
		for j in fp.y:
			occupied[c + Vector2i(i, j)] = true
			building_cells[c + Vector2i(i, j)] = true


func _make_building(e: Dictionary) -> Structure:
	var s := Structure.new()
	s.kind = "edificio"
	s.cell = e["cell"]
	s.world = self
	s.art = e["art"]
	s.art_variant = e["v"]
	s.fp = e["fp"]
	# centro da pegada: topo da célula inicial + deslocamento até o centro do losango
	var top := ground.map_to_local(s.cell) + Vector2(0, -HALF_H)
	var w := float(s.fp.x)
	var d := float(s.fp.y)
	s.position = top + Vector2(HALF_W * 0.5 * (w - d), HALF_H * 0.5 * (w + d))
	entities.add_child(s)
	for cell in s.cells():
		structures[cell] = s
	return s


## Prédio explorável: só o telhado vira nó (o resto é chão, paredes e objetos).
func _make_house(id: int) -> House:
	var hd: Dictionary = houses[id]
	var h := House.new()
	h.id = id
	h.rect = hd["rect"]
	h.roof = hd["roof"]
	h.world = self
	var w := float(h.rect.size.x)
	var d := float(h.rect.size.y)
	var top := ground.map_to_local(h.rect.position) + Vector2(0, -HALF_H)
	h.position = top + Vector2(HALF_W * 0.5 * (w - d), HALF_H * 0.5 * (w + d))
	entities.add_child(h)
	return h


func _add_prop(art: String, v: int, c: Vector2i, source := "gen") -> void:
	_plan_add(c, {"t": "p", "art": art, "v": v, "cell": c, "source": source})
	occupied[c] = true


func _make_prop(e: Dictionary) -> Node2D:
	var pr := Prop.new()
	pr.art = e["art"]
	pr.variant = e["v"]
	pr.source = e["source"]
	pr.position = ground.map_to_local(e["cell"])
	entities.add_child(pr)
	return pr


## Tira o nó de uma estrutura carregada (não mexe nos dados).
func _free_structure_node(s: Structure) -> void:
	for cell in s.cells():
		if structures.get(cell) == s:
			structures.erase(cell)
	s.queue_free()


func _build_shelter(v: VillageData) -> void:
	built[v.cell + Vector2i(2, -2)] = {"kind": "gerador", "fuel": 100.0, "open": false, "eternal": true}
	built[v.cell + Vector2i(-1, -1)] = {"kind": "purificador", "fuel": 0.0, "open": false, "eternal": true}
	built[v.cell + Vector2i(1, 1)] = {"kind": "vedacao", "fuel": 0.0, "open": false, "eternal": true}
	for c in [v.cell + Vector2i(2, -2), v.cell + Vector2i(-1, -1), v.cell + Vector2i(1, 1)]:
		occupied[c] = true
	var starter := _add_container(v.cell + Vector2i(-2, 1), "comum", v.id)
	container_data[starter]["items"] = Items.from_counts({"feijao": 3, "agua_limpa": 3, "bandagem": 2, "sucata": 4, "madeira": 4,
		"metal": 2, "fita": 1, "faca": 1, "martelo": 1, "pregos": 16}, null, 0.0)


func _free_cell(c: Vector2i) -> bool:
	return not occupied.has(c) and not road_cells.has(c) and not field_cells.has(c) and not house_cells.has(c) \
		and Vector2(c).length() < RADIUS - 3.0


## Nó de uma construção (dados em 'built').
func _make_structure(c: Vector2i, d: Dictionary) -> Structure:
	var s := Structure.new()
	s.kind = d["kind"]
	s.cell = c
	s.world = self
	s.eternal = bool(d.get("eternal", false))
	s.fuel = float(d.get("fuel", 0.0))
	s.open = bool(d.get("open", false))
	s.apply_extra(d)
	s.position = ground.map_to_local(c)
	entities.add_child(s)
	structures[c] = s
	return s


static var _light_tex: Texture2D


## Textura radial das luzes (lanterna, luminárias, postes).
static func light_texture() -> Texture2D:
	if _light_tex == null:
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		g.width = 256
		g.height = 256
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		g.gradient = grad
		_light_tex = g
	return _light_tex


## Meio da borda (x, y, d) em coordenadas do mundo.
func edge_pos(k: Vector3i) -> Vector2:
	return ground.map_to_local(Vector2i(k.x, k.y)) + WallEdge.edge_offset(k.z)


func _make_wall(k: Vector3i, from_map := false) -> WallEdge:
	var src: Dictionary = map_walls[k] if from_map else walls[k]
	var w := WallEdge.new()
	w.kind = str(src["kind"])
	w.map = from_map
	w.house_id = int(src.get("h", -1))
	w.partition = bool(src.get("p", false))
	w.cell = Vector2i(k.x, k.y)
	w.dir = k.z
	w.open = bool(src.get("open", false))
	w.world = self
	w.position = edge_pos(k)
	entities.add_child(w)
	wall_nodes[k] = w
	return w


## Borda mais próxima do mouse (para construir e demolir paredes).
func mouse_edge() -> Vector3i:
	var t := tile_pos(get_global_mouse_position())
	var c := Vector2i(floori(t.x), floori(t.y))
	var f := t - Vector2(c)
	var opts := [[f.x, Vector3i(c.x - 1, c.y, 0)], [1.0 - f.x, Vector3i(c.x, c.y, 0)],
		[f.y, Vector3i(c.x, c.y - 1, 1)], [1.0 - f.y, Vector3i(c.x, c.y, 1)]]
	var best: Array = opts[0]
	for o in opts:
		if float(o[0]) < float(best[0]):
			best = o
	_edge_dist = float(best[0])
	return best[1]


var _edge_dist := 1.0


## Alvo do modo demolição sob o mouse: [x, y, d] de uma parede (quando o mouse está perto da
## borda) ou [x, y] de uma célula.
func demolish_target() -> Array:
	var k := mouse_edge()
	if walls.has(k) and _edge_dist < 0.3:
		return [k.x, k.y, k.z]
	var c := mouse_cell()
	return [c.x, c.y]


func has_demolishable(c: Vector2i) -> bool:
	return structures.has(c) or chests.has(c) or build_layer.get_cell_source_id(c) != -1


func _make_chest(c: Vector2i) -> LootContainer:
	var lc := LootContainer.new()
	lc.chest = true
	lc.cell = c
	lc.table = "bau"
	lc.items = chest_data.get(c, [])
	lc.position = ground.map_to_local(c)
	entities.add_child(lc)
	chests[c] = lc
	return lc


## Planeja uma caixa do mapa; devolve o id.
func _add_container(c: Vector2i, table: String, village_id: int) -> int:
	var id := container_data.size()
	# o estado de cada item (durabilidade, carga, validade) usa um gerador próprio por caixa,
	# para não mudar a sequência do gerador do mapa
	var srng := RandomNumberGenerator.new()
	srng.seed = hash([seed_value, id])
	container_data.append({"cell": c, "table": table, "village": village_id,
		"items": DB.roll_loot(table, rng.randi_range(2, 4), rng, srng, 0.0), "dirty": false})
	_plan_add(c, {"t": "c", "id": id, "cell": c})
	occupied[c] = true
	return id


func _make_container(id: int) -> LootContainer:
	var cd: Dictionary = container_data[id]
	var lc := LootContainer.new()
	lc.id = id
	lc.table = cd["table"]
	lc.village_id = int(cd["village"])
	lc.items = cd["items"]
	lc.dirty = bool(cd["dirty"])
	lc.position = ground.map_to_local(cd["cell"])
	entities.add_child(lc)
	container_nodes[id] = lc
	return lc


# ======================================================================= chunks
## Posições de quem precisa do mundo carregado: todos os jogadores no anfitrião (física,
## IA e colisão acontecem lá), só o próprio jogador nos clientes.
func _viewers() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if Net.is_server():
		for k in players:
			var p: Player = players[k]
			out.append(p.position if p.is_local() else p.net_pos)
	else:
		var lp := local_player()
		if lp != null:
			out.append(lp.position)
	if out.is_empty():
		out.append(ground.map_to_local(Vector2i.ZERO))
	return out


## Carrega os chunks perto de quem olha e descarrega os distantes. 'limit' chunks por
## chamada (0 = todos de uma vez, usado no começo).
func update_chunks(limit := 3) -> void:
	var centers: Array[Vector2i] = []
	for pos in _viewers():
		centers.append(chunk_of(ground.local_to_map(pos)))
	var want: Array[Vector2i] = []
	var max_ch := ceili((RADIUS + 6.0) / CHUNK)
	for cc in centers:
		for dx in range(-LOAD_R, LOAD_R + 1):
			for dy in range(-LOAD_R, LOAD_R + 1):
				var ch := cc + Vector2i(dx, dy)
				if absi(ch.x) > max_ch or absi(ch.y) > max_ch or loaded.has(ch) or ch in want:
					continue
				want.append(ch)
	# os mais próximos primeiro
	var c0 := centers[0]
	want.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - c0).length_squared() < (b - c0).length_squared())
	var n := 0
	for ch in want:
		if limit > 0 and n >= limit:
			break
		_load_chunk(ch)
		n += 1
	for ch: Vector2i in loaded.keys():
		var far := true
		for cc in centers:
			if maxi(absi(ch.x - cc.x), absi(ch.y - cc.y)) <= UNLOAD_R:
				far = false
				break
		if far:
			_unload_chunk(ch)


func is_loaded(c: Vector2i) -> bool:
	return loaded.has(chunk_of(c))


func _load_chunk(ch: Vector2i) -> void:
	var nodes: Array = []
	var holder := Node2D.new()
	art_ground.add_child(holder)
	var base := ch * CHUNK
	for x in CHUNK:
		for y in CHUNK:
			var c := base + Vector2i(x, y)
			var t := _terrain(c)
			if t < 0:
				continue
			ground.set_cell(c, 0, _gtile(t, c))
			if terrain_deltas.has(c):
				build_layer.set_cell(c, 0, _gtile(int(terrain_deltas[c]), c))
	var entries: Array = plan.get(ch, [])
	var art: Array = []
	for e in entries:
		match String(e["t"]):
			"g":
				art.append(e)
			"b":
				if not removed_cells.has(e["cell"]):
					nodes.append(_make_building(e))
			"h":
				nodes.append(_make_house(int(e["id"])))
			"p":
				nodes.append(_make_prop(e))
			"c":
				nodes.append(_make_container(int(e["id"])))
	# arte de chão: calçadas antes das estradas, depois em ordem de profundidade
	art.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["layer"] != b["layer"]:
			return a["layer"] < b["layer"]
		var ka: int = a["cell"].x + a["cell"].y
		var kb: int = b["cell"].x + b["cell"].y
		if ka != kb:
			return ka < kb
		return a["cell"].x < b["cell"].x)
	for e in art:
		var sp := ArtDB.sprite(e["art"], e["v"], "top")
		sp.position += ground.map_to_local(e["cell"]) + Vector2(0, -HALF_H)
		holder.add_child(sp)
	for c: Vector2i in built:
		if chunk_of(c) == ch:
			nodes.append(_make_structure(c, built[c]))
	for c: Vector2i in chest_data:
		if chunk_of(c) == ch:
			nodes.append(_make_chest(c))
	for k: Vector3i in walls:
		if chunk_of(Vector2i(k.x, k.y)) == ch:
			nodes.append(_make_wall(k))
	for k: Vector3i in map_walls_by_chunk.get(ch, []):
		if not wall_nodes.has(k):
			nodes.append(_make_wall(k, true))
	loaded[ch] = {"nodes": nodes, "art": holder}


func _unload_chunk(ch: Vector2i) -> void:
	var info: Dictionary = loaded[ch]
	for node in info["nodes"]:
		if not is_instance_valid(node):
			continue
		if node is Structure:
			var st := node as Structure
			if built.has(st.cell):
				built[st.cell]["fuel"] = st.fuel
				built[st.cell]["open"] = st.open
				built[st.cell].merge(st.state_extra(), true)
			_free_structure_node(st)
			continue
		if node is WallEdge:
			var we := node as WallEdge
			if walls.has(we.key()):
				walls[we.key()]["open"] = we.open
			elif map_walls.has(we.key()):
				map_walls[we.key()]["open"] = we.open
			wall_nodes.erase(we.key())
		if node is LootContainer:
			var lc := node as LootContainer
			if lc.chest:
				chest_data[lc.cell] = lc.items
				chests.erase(lc.cell)
			else:
				container_data[lc.id]["items"] = lc.items
				container_nodes.erase(lc.id)
		node.queue_free()
	(info["art"] as Node2D).queue_free()
	var base := ch * CHUNK
	for x in CHUNK:
		for y in CHUNK:
			var c := base + Vector2i(x, y)
			ground.erase_cell(c)
			build_layer.erase_cell(c)
	loaded.erase(ch)


# ======================================================================= esporos
func tile_pos(world_pos: Vector2) -> Vector2:
	return Vector2((world_pos.x / HALF_W + world_pos.y / HALF_H) * 0.5, (world_pos.y / HALF_H - world_pos.x / HALF_W) * 0.5)


func edge_ratio(world_pos: Vector2) -> float:
	return clampf(tile_pos(world_pos).length() / RADIUS, 0.0, 1.5)


func spore_at(world_pos: Vector2) -> float:
	var tp := tile_pos(world_pos)
	var s := 0.08 + 1.4 * smoothstep(RADIUS * 0.55, RADIUS, tp.length())
	# a chuva lava o ar; a névoa de esporos piora tudo
	match str(weather.get("tipo", "")):
		"chuva":
			s *= 0.85
		"tempestade":
			s *= 0.8
		"neblina":
			s += 0.12
	s += spore_noise.get_noise_2d(tp.x * 0.6, tp.y * 0.6) * 0.04
	# lugares tomados por esporos
	for dz in dead_zones:
		var dd := tp.distance_to(dz[0])
		if dd < float(dz[1]) + 6.0:
			s += 0.75 * (1.0 - smoothstep(float(dz[1]) * 0.6, float(dz[1]) + 6.0, dd))
	# vilas que caíram viram zonas mortas tomadas por esporos
	for v in villages:
		if v.infested:
			var dv := tp.distance_to(Vector2(v.cell))
			if dv < 14.0:
				s += 0.45 * (1.0 - smoothstep(6.0, 14.0, dv))
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


# ======================================================================= jogadores
func local_player() -> Player:
	return players.get(Net.my_id())


func alive_players() -> Array[Player]:
	var out: Array[Player] = []
	for k in players:
		var p: Player = players[k]
		if p.alive:
			out.append(p)
	return out


## Jogador vivo mais próximo (distância isométrica) ou null.
func nearest_player(pos: Vector2, max_iso := 1e9) -> Player:
	var best: Player = null
	var best_d := max_iso
	for p in alive_players():
		var off := p.position - pos
		var d := Vector2(off.x, off.y * 2.0).length()
		if d < best_d:
			best_d = d
			best = p
	return best


func nearest_infected_dist(pos: Vector2) -> float:
	var best := 1e9
	for n in get_tree().get_nodes_in_group("infected"):
		var off := (n as Node2D).position - pos
		best = minf(best, Vector2(off.x, off.y * 2.0).length())
	return best


## Onde um sobrevivente novo acorda: numa cama da equipe, se houver; senão, no abrigo.
func spawn_pos() -> Vector2:
	var beds: Array = []
	for c in built:
		if built[c]["kind"] == "cama":
			beds.append(c)
	if beds.is_empty():
		return shelter_pos()
	return ground.map_to_local(beds[Game.rng.randi() % beds.size()]) + Vector2(0, 14)


func shelter_pos() -> Vector2:
	return ground.map_to_local(Vector2i.ZERO) + Vector2(Game.rng.randf_range(-20, 20), Game.rng.randf_range(4, 14))


## Servidor: cria o personagem de um jogador (sobrevivente salvo pelo nome ou um novo).
func spawn_player(peer: int) -> Player:
	var pname := Net.name_of(peer)
	var saved: Dictionary = Game.survivor_cache.get(pname, {})
	var pos := shelter_pos()
	if not saved.is_empty():
		pos = Game.v2(saved.get("pos", [pos.x, pos.y]))
	var p: Player = spawn_net({"t": "player", "peer": peer, "nome": pname, "pos": [pos.x, pos.y]})
	if saved.is_empty():
		# sobrevivente novo: o jogador monta a ficha (CreationScreen) e envia
		p.alive = false
		p.pending = true
	else:
		var data := SurvivorData.from_dict(saved.get("data", {}))
		_attach_data(p, data)
		Game.tell(peer, "Bem-vindo de volta, %s." % data.nome)
	if peer != Net.my_id():
		Game.say_all("%s entrou na sessão." % pname)
	return p


func _attach_data(p: Player, data: SurvivorData) -> void:
	p.data = data
	p.alive = true
	var peer := p.peer
	data.message.connect(func(t: String) -> void: Game.tell(peer, t))
	data.overflow.connect(func(list: Array) -> void: drop_items(p.position if p.is_local() else p.net_pos, list))
	p._last_sync = ""
	if p.is_local():
		p.data_changed.emit()


## Servidor: jogador saiu; guarda o sobrevivente para quando ele voltar.
func remove_player(peer: int, pname: String) -> void:
	var p: Player = players.get(peer)
	if p == null:
		return
	if p.data != null and p.alive:
		Game.survivor_cache[pname] = {"data": p.data.to_dict(), "pos": [p.net_pos.x, p.net_pos.y]}
	players.erase(peer)
	p.queue_free()
	Game.say_all("%s saiu da sessão." % pname)


# ======================================================================= entidades replicadas
## Servidor: cria uma entidade replicada (ver _spawn_entity).
func spawn_net(d: Dictionary) -> Node:
	if not Net.is_server():
		return null
	_net_counter += 1
	if not d.has("name"):
		d["name"] = "%s%d" % [d["t"], _net_counter]
	return spawner.spawn(d)


## Roda em todos os peers com os mesmos dados (o servidor manda via MultiplayerSpawner).
func _spawn_entity(d: Dictionary) -> Node:
	var node: Node2D
	match String(d["t"]):
		"player":
			var p := Player.new()
			p.world = self
			p.nome = str(d["nome"])
			p.setup_net(int(d["peer"]))
			p.position = Game.v2(d["pos"])
			p.net_pos = p.position
			players[int(d["peer"])] = p
			p.tree_exiting.connect(func() -> void:
				if players.get(p.peer) == p:
					players.erase(p.peer))
			node = p
		"inf":
			var e := Infected.new()
			e.world = self
			e.setup(bool(d["elite"]))
			e.legacy = bool(d.get("legacy", false))
			e.legacy_name = str(d.get("legacy_name", ""))
			e.position = Game.v2(d["pos"])
			e.home = Game.v2(d.get("home", d["pos"]))
			if d.has("hp"):
				e.hp = float(d["hp"])
			e.setup_net()
			node = e
		"corpse":
			var c := Corpse.new()
			c.world = self
			c.nome = str(d["nome"])
			c.items = Items.sanitize(d.get("items", []))
			c.decomp = float(d.get("decomp", 0.0))
			c.position = Game.v2(d["pos"])
			c.setup_net()
			node = c
		"bag":
			var lc := LootContainer.new()
			lc.temporary = true
			lc.items = Items.sanitize(d.get("items", []))
			lc.position = Game.v2(d["pos"])
			lc.setup_net()
			node = lc
		"npc":
			var npc := Npc.new()
			npc.world = self
			npc.village_id = int(d["vid"])
			npc.role = str(d["role"])
			npc.nome = str(d["nome"])
			npc.position = Game.v2(d["pos"])
			npc.home = Game.v2(d.get("home", d["pos"]))
			npc.setup_net()
			node = npc
		"veh":
			var vh := Vehicle.new()
			vh.world = self
			vh.kind = str(d["kind"])
			vh.position = Game.v2(d["pos"])
			vh.fuel = float(d.get("fuel", 0.0))
			vh.cond = float(d.get("cond", 50.0))
			vh.locked = bool(d.get("locked", true))
			vh.items = Items.sanitize(d.get("items", []))
			vh.setup_net()
			node = vh
		"car":
			var car := Caravan.new()
			car.world = self
			car.from_id = int(d["from"])
			car.to_id = int(d["to"])
			car.cargo = d.get("cargo", {})
			car.path = route(car.from_id, car.to_id)
			car.position = car.path[0] if car.path.size() > 0 else Vector2.ZERO
			car.setup_net()
			node = car
	node.name = str(d["name"])
	return node


## Chave estável de um objeto interativo (igual em todos os peers).
func key_of(node: Node) -> String:
	if node is LootContainer and (node as LootContainer).chest:
		var cc := (node as LootContainer).cell
		return "b:%d,%d" % [cc.x, cc.y]
	if node is LootContainer and not (node as LootContainer).temporary:
		return "c:%d" % (node as LootContainer).id
	if node is Structure:
		var c := (node as Structure).cell
		return "s:%d,%d" % [c.x, c.y]
	if node is WallEdge:
		var k := (node as WallEdge).key()
		return "w:%d,%d,%d" % [k.x, k.y, k.z]
	return "n:" + String(node.name)


func node_of(key: String) -> Node:
	var kind := key.substr(0, 2)
	var rest := key.substr(2)
	match kind:
		"c:":
			return container_nodes.get(int(rest))
		"s:", "b:":
			var xy := rest.split(",")
			if xy.size() < 2:
				return null
			var cell := Vector2i(int(xy[0]), int(xy[1]))
			return structures.get(cell) if kind == "s:" else chests.get(cell)
		"n:":
			return net_root.get_node_or_null(NodePath(rest))
		"w:":
			var xyz := rest.split(",")
			if xyz.size() < 3:
				return null
			return wall_nodes.get(Vector3i(int(xyz[0]), int(xyz[1]), int(xyz[2])))
	return null


func _near(p: Player, node: Node2D, reach := 90.0) -> bool:
	var off := node.position - p.net_pos if not p.is_local() else node.position - p.position
	return Vector2(off.x, off.y * 2.0).length() <= reach


## Servidor: o jogador interage com um objeto (validando a distância).
func interact(p: Player, key: String) -> void:
	var node := node_of(key) as Node2D
	if node == null or not node.is_in_group("interactable") or not _near(p, node):
		return
	node.interact(p)


# ======================================================================= transferência de itens
## Recipiente do mundo (caixa, baú, saco no chão ou cadáver) ao alcance do jogador.
func _loot_node(p: Player, key: String) -> Node2D:
	var node := node_of(key) as Node2D
	if node == null or not (node is LootContainer or node is Corpse or node is Vehicle) or not _near(p, node, 110.0):
		return null
	return node


## Servidor: pega 'n' unidades do item 'idx' de um recipiente. mode "vestir" veste mochilas,
## coldres e máscaras direto (uma mochila não cabe nos bolsos).
func take_from(p: Player, key: String, idx: int, n: int, mode: String, id: String) -> void:
	var node := _loot_node(p, key)
	if node == null:
		return
	var items: Array = node.items
	if idx < 0 or idx >= items.size() or items[idx]["id"] != id:
		return
	var part := Items.split(items, items[idx], maxi(1, n))
	if mode == "vestir" and String(Items.def(part["id"])["tipo"]) in SurvivorData.EQUIP_SLOTS:
		if int(part["n"]) > 1:
			var extra := part.duplicate()
			extra["n"] = int(part["n"]) - 1
			part["n"] = 1
			Items.add(items, extra)
		p.data.wear(part)
	else:
		var prefer := mode.substr(5) if mode.begins_with("para:") else ""
		var left := p.data.store(part, prefer)
		if not left.is_empty():
			Items.add(items, left)
			Game.tell(p.peer, "Sem espaço para %s." % Items.label(left))
	container_changed(node)


## Servidor: reordena um item dentro de um recipiente do mundo.
func loot_order(p: Player, key: String, from: int, to: int) -> void:
	var node := _loot_node(p, key)
	if node == null:
		return
	var items: Array = node.items
	if from < 0 or from >= items.size():
		return
	var it = items[from]
	items.remove_at(from)
	items.insert(clampi(to, 0, items.size()), it)
	container_changed(node)


## Servidor: organiza um recipiente do mundo.
func sort_loot(p: Player, key: String) -> void:
	var node := _loot_node(p, key)
	if node == null:
		return
	Items.sort_list(node.items)
	Items.compact(node.items)
	container_changed(node)


## Servidor: pega tudo o que couber.
func take_all(p: Player, key: String) -> void:
	var node := _loot_node(p, key)
	if node == null or node.items.is_empty():
		return
	var left := p.data.receive(node.items)
	node.items = left
	if not left.is_empty():
		Game.tell(p.peer, "Sem espaço: %s ficou." % Items.describe_list(left))
	container_changed(node)


## Servidor: guarda um item do inventário num recipiente do mundo.
func store_into(p: Player, key: String, u: int, n: int) -> void:
	var node := _loot_node(p, key)
	if node == null:
		return
	if node is Vehicle:
		var f := p.data.find(u)
		if f.is_empty():
			return
		var vol := float(Items.def(f[1]["id"]).get("vol", 0.5)) * float(mini(maxi(1, n), int(f[1]["n"])))
		if (node as Vehicle).trunk_volume() + vol > float((node as Vehicle).def()["porta_malas"]):
			Game.tell(p.peer, "O porta-malas está cheio (%d L)." % int((node as Vehicle).def()["porta_malas"]))
			return
	var part := p.data.remove_u(u, maxi(1, n))
	if part.is_empty():
		return
	Items.add(node.items, part)
	container_changed(node)


## Recipientes do mundo perto do jogador cujos materiais valem para construir e fabricar
## (baús, sacos no chão e caixas a até ~2 tiles).
func _near_storage(p: Player) -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("containers"):
		var lc := n as LootContainer
		if not lc.is_queued_for_deletion() and _near(p, lc, 130.0) and not lc.items.is_empty():
			out.append(lc)
	return out


func afford_near(p: Player, cost: Dictionary) -> bool:
	var stores := _near_storage(p)
	for k in cost:
		var have := p.data.count(k)
		for lc in stores:
			have += Items.count(lc.items, k)
		if have < int(cost[k]):
			return false
	return true


## Paga primeiro com o inventário e o que faltar com os recipientes próximos.
func pay_near(p: Player, cost: Dictionary) -> void:
	var stores := _near_storage(p)
	for k in cost:
		var need := int(cost[k])
		var mine := mini(need, p.data.count(k))
		if mine > 0:
			p.data.take_item(k, mine)
			need -= mine
		for lc in stores:
			if need <= 0:
				break
			var here := mini(need, Items.count(lc.items, k))
			if here > 0:
				Items.take(lc.items, k, here)
				need -= here
				container_changed(lc)


## Servidor: larga itens no chão (junta num saco próximo, se houver).
func drop_items(pos: Vector2, list: Array) -> void:
	if list.is_empty():
		return
	for n in get_tree().get_nodes_in_group("containers"):
		var lc := n as LootContainer
		if lc.temporary and not lc.is_queued_for_deletion() and lc.position.distance_to(pos) < 40.0:
			for inst in list:
				Items.add(lc.items, Items.strip(inst))
			container_changed(lc)
			return
	spawn_net({"t": "bag", "pos": [pos.x, pos.y], "items": Items.strip_all(list)})


# ======================================================================= estado compartilhado
## Servidor: o conteúdo de um recipiente mudou. Caixas e baús vão por RPC (e ficam nos
## dados); sacos e cadáveres são replicados pelo sincronizador (a lista é trocada para ele
## perceber a mudança).
func container_changed(node: Node2D) -> void:
	node.items = node.items.duplicate(true)
	node.queue_redraw()
	if node is LootContainer:
		var lc := node as LootContainer
		if lc.temporary:
			if lc.items.is_empty():
				lc.queue_free()
			return
		lc.dirty = true
		_store_items(key_of(lc), lc.items)
		_container_items.rpc(key_of(lc), lc.items)


## Grava o conteúdo nos dados (caixa "c:id" ou baú "b:x,y") e no nó, se carregado.
func _store_items(key: String, items: Array) -> void:
	if key.begins_with("c:"):
		var id := int(key.substr(2))
		if id >= 0 and id < container_data.size():
			container_data[id]["items"] = items
			container_data[id]["dirty"] = true
	elif key.begins_with("b:"):
		var xy := key.substr(2).split(",")
		var cell := Vector2i(int(xy[0]), int(xy[1]))
		if chest_data.has(cell):
			chest_data[cell] = items
	var lc := node_of(key) as LootContainer
	if lc != null and lc.items != items:
		lc.items = items
		lc.dirty = true
		lc.queue_redraw()


@rpc("authority", "reliable")
func _container_items(key: String, items: Array) -> void:
	_store_items(key, Items.sanitize(items))


## Servidor: estado de uma estrutura (combustível, porta) mudou.
func structure_changed(st: Structure) -> void:
	var extra := st.state_extra()
	if built.has(st.cell):
		built[st.cell]["fuel"] = st.fuel
		built[st.cell]["open"] = st.open
		built[st.cell].merge(extra, true)
	_structure_state.rpc(st.cell.x, st.cell.y, st.fuel, st.open, extra)


@rpc("authority", "reliable")
func _structure_state(x: int, y: int, fuel: float, open: bool, extra: Dictionary) -> void:
	var c := Vector2i(x, y)
	if built.has(c):
		built[c]["fuel"] = fuel
		built[c]["open"] = open
		built[c].merge(extra, true)
	var st: Structure = structures.get(c)
	if st != null:
		st.apply_state(fuel, open)
		if not extra.is_empty():
			st.apply_extra(extra)


## Servidor: porta ou portão de borda abriu/fechou.
func wall_changed(w: WallEdge) -> void:
	if walls.has(w.key()):
		walls[w.key()]["open"] = w.open
	elif map_walls.has(w.key()):
		map_walls[w.key()]["open"] = w.open
	_wall_state.rpc(w.cell.x, w.cell.y, w.dir, w.open)


@rpc("authority", "reliable")
func _wall_state(x: int, y: int, d: int, open: bool) -> void:
	var k := Vector3i(x, y, d)
	if walls.has(k):
		walls[k]["open"] = open
	elif map_walls.has(k):
		map_walls[k]["open"] = open
	var w: WallEdge = wall_nodes.get(k)
	if w != null:
		w.set_open(open)


## Há uma construção desse tipo perto (cozinhar no fogareiro)?
func station_near(pos: Vector2, kind: String) -> bool:
	for n in get_tree().get_nodes_in_group("station_" + kind):
		var off := (n as Node2D).position - pos
		if Vector2(off.x, off.y * 2.0).length() < 110.0:
			return true
	return false


@rpc("authority", "unreliable")
func turret_fx(x: int, y: int, aim: int, target: Vector2) -> void:
	var st: Structure = structures.get(Vector2i(x, y))
	if st != null:
		st.show_shot(aim, target)


@rpc("authority", "reliable")
func _villages_state(list: Array) -> void:
	for vd in list:
		var vid := int(vd["id"])
		if vid < villages.size():
			villages[vid].apply_dict(vd)


# ======================================================================= construção
func mouse_cell() -> Vector2i:
	return ground.local_to_map(ground.to_local(get_global_mouse_position()))


## Tipo de uma construção: piso, parede, porta, objeto ou bau.
static func build_type(kind: String) -> String:
	return String(DB.BUILDS.get(kind, {}).get("tipo", "objeto"))


static func is_edge_kind(kind: String) -> bool:
	return build_type(kind) in ["parede", "porta"]


func _in_reach(p: Player, pos: Vector2) -> bool:
	var ppos := p.position if p.is_local() else p.net_pos
	var off := pos - ppos
	return Vector2(off.x, off.y * 2.0).length() <= 275.0


## Dá para construir? 'd' = borda (0/1) para paredes e portas; -1 para o resto.
func can_place_at(kind: String, c: Vector2i, p: Player = null, d := -1) -> bool:
	if Vector2(c).length() > RADIUS - 3.0 or not DB.BUILDS.has(kind):
		return false
	var t := build_type(kind)
	if t in ["parede", "porta"]:
		if d < 0:
			return false
		var k := Vector3i(c.x, c.y, d)
		if walls.has(k) or map_walls.has(k):
			return false
		var other := c + (Vector2i(1, 0) if d == 0 else Vector2i(0, 1))
		if building_cells.has(c) or building_cells.has(other):
			return false
		return p == null or _in_reach(p, edge_pos(k))
	if t == "piso":
		if int(terrain_deltas.get(c, -1)) == int(DB.BUILDS[kind]["chao"]) or building_cells.has(c):
			return false
		return p == null or _in_reach(p, ground.map_to_local(c))
	if occupied.has(c):
		return false
	if p != null:
		if not _in_reach(p, ground.map_to_local(c)):
			return false
		if not DB.BUILDS[kind].get("andavel", false):
			for other_p in alive_players():
				var opos := other_p.position if other_p.is_local() else other_p.net_pos
				var o2 := ground.map_to_local(c) - opos
				if Vector2(o2.x, o2.y * 2.0).length() < 30.0:
					return false
	return true


## Servidor: valida e constrói; todos os peers recebem a construção.
func try_place(kind: String, c: Vector2i, p: Player, d := -1) -> bool:
	if not DB.BUILDS.has(kind):
		return false
	var def: Dictionary = DB.BUILDS[kind]
	if not can_place_at(kind, c, p, d):
		Game.tell(p.peer, "Não dá para construir aqui.")
		return false
	if not p.data.meets(def["req"]):
		Game.tell(p.peer, "Conhecimento insuficiente: exige %s." % DB.req_text(def["req"]))
		return false
	if not afford_near(p, def["custo"]):
		Game.tell(p.peer, "Faltam materiais: %s." % DB.cost_text(def["custo"]))
		return false
	var miss := p.data.missing_tools(def.get("ferramentas", []))
	if miss != "":
		Game.tell(p.peer, "Falta ferramenta: %s." % miss)
		return false
	pay_near(p, def["custo"])
	make_noise(ground.map_to_local(c), 240.0)
	var extra := {}
	if kind == "eolico":
		extra = {"mods": 1, "aberto": _openness(c)}
	_build_done.rpc(kind, c.x, c.y, d, extra)
	p.data.add_xp_map(def["xp"])
	Game.tell(p.peer, "Construído: %s." % def["nome"])
	return true


## Quanto o vento chega num lugar (prédios e construções ao redor atrapalham): 0,35 a 1.
func _openness(c: Vector2i) -> float:
	var n := 0
	for dx in range(-4, 5):
		for dy in range(-4, 5):
			if building_cells.has(c + Vector2i(dx, dy)):
				n += 1
	return clampf(1.0 - 0.025 * float(n), 0.35, 1.0)


@rpc("authority", "call_local", "reliable")
func _build_done(kind: String, x: int, y: int, d: int, extra: Dictionary) -> void:
	var c := Vector2i(x, y)
	var t := build_type(kind)
	if t in ["parede", "porta"]:
		var k := Vector3i(x, y, d)
		if not walls.has(k):
			walls[k] = {"kind": kind, "open": false}
			if is_loaded(c):
				_track(c, _make_wall(k))
	elif t == "bau":
		if not chest_data.has(c):
			chest_data[c] = []
			occupied[c] = true
			if is_loaded(c):
				_track(c, _make_chest(c))
	elif t == "piso":
		var tt := int(DB.BUILDS[kind]["chao"])
		terrain_deltas[c] = tt
		if is_loaded(c):
			build_layer.set_cell(c, 0, _gtile(tt, c))
	elif not built.has(c):
		built[c] = {"kind": kind, "fuel": 0.0, "open": false, "eternal": false}
		built[c].merge(extra, true)
		if not DB.BUILDS[kind].get("andavel", false):
			occupied[c] = true
		else:
			occupied[c] = true
		if is_loaded(c):
			_track(c, _make_structure(c, built[c]))


## Registra um nó criado depois do carregamento no chunk dele (para descarregar junto).
func _track(c: Vector2i, node: Node) -> void:
	var ch := chunk_of(c)
	if loaded.has(ch):
		loaded[ch]["nodes"].append(node)


## Servidor: valida e demole; devolve materiais ao jogador.
func try_demolish(c: Vector2i, p: Player, d := -1) -> bool:
	if d >= 0:
		var k := Vector3i(c.x, c.y, d)
		if map_walls.has(k):
			Game.tell(p.peer, "Paredes dos prédios do mapa não dá para desmontar.")
			return false
		if not walls.has(k):
			return false
		if not _in_reach(p, edge_pos(k)):
			Game.tell(p.peer, "Longe demais.")
			return false
		var cost: Dictionary = DB.BUILDS[walls[k]["kind"]]["custo"]
		for item in cost:
			var back := floori(float(cost[item]) / 2.0)
			if back > 0:
				p.data.give(item, back)
		_wall_removed.rpc(k.x, k.y, k.z)
		Game.tell(p.peer, "Parede desmontada (50% dos materiais).")
		return true
	var ppos := p.position if p.is_local() else p.net_pos
	var off := ground.map_to_local(c) - ppos
	if Vector2(off.x, off.y * 2.0).length() > 275.0:
		Game.tell(p.peer, "Longe demais.")
		return false
	if chests.has(c):
		var ch: LootContainer = chests[c]
		drop_items(ch.position, ch.items)
		ch.items = []
		_demolish_done.rpc(c.x, c.y, false)
		p.data.give("madeira", 1)
		Game.tell(p.peer, "Baú desmontado (o conteúdo ficou no chão).")
		return true
	if structures.has(c):
		var s: Structure = structures[c]
		if s.eternal:
			Game.tell(p.peer, "Você não pode demolir isto.")
			return false
		if s.kind == "ruina" or s.kind == "edificio":
			var big := s.kind == "edificio"
			p.data.give("sucata", rng.randi_range(3, 5) if big else rng.randi_range(1, 2))
			if rng.randf() < (0.8 if big else 0.25):
				p.data.give("metal", rng.randi_range(1, 2) if big else 1)
			if big and rng.randf() < 0.6:
				p.data.give("sucata_eletronica", rng.randi_range(1, 2))
			if big and rng.randf() < 0.4:
				p.data.give("fios", 1)
			make_noise(s.position, 320.0)
			Game.tell(p.peer, "Você desmontou %s (+materiais)." % ("um prédio" if big else "uma ruína"))
		else:
			var cost: Dictionary = DB.BUILDS[s.kind]["custo"]
			for k in cost:
				var back := floori(float(cost[k]) / 2.0)
				if back > 0:
					p.data.give(k, back)
			Game.tell(p.peer, "Estrutura desmontada (50% dos materiais).")
		_demolish_done.rpc(s.cell.x, s.cell.y, false)
		return true
	if build_layer.get_cell_source_id(c) != -1:
		_demolish_done.rpc(c.x, c.y, true)
		var kind_back := "sucata"
		for bk in DB.BUILDS:
			if int(DB.BUILDS[bk].get("chao", -1)) == int(terrain_deltas.get(c, -2)):
				kind_back = (DB.BUILDS[bk]["custo"] as Dictionary).keys()[0]
		p.data.give(kind_back, 1)
		Game.tell(p.peer, "Piso removido.")
		return true
	return false


@rpc("authority", "call_local", "reliable")
func _wall_removed(x: int, y: int, d: int) -> void:
	var k := Vector3i(x, y, d)
	walls.erase(k)
	var w: WallEdge = wall_nodes.get(k)
	if w != null:
		wall_nodes.erase(k)
		w.queue_free()


## Todos os peers: aplica uma demolição nos dados e, se o chunk estiver carregado, nos nós.
## (x, y) é a célula de origem da estrutura.
@rpc("authority", "call_local", "reliable")
func _demolish_done(x: int, y: int, floor_only: bool) -> void:
	var c := Vector2i(x, y)
	if chest_data.has(c):
		chest_data.erase(c)
		occupied.erase(c)
		if chests.has(c):
			(chests[c] as LootContainer).queue_free()
			chests.erase(c)
		return
	if floor_only:
		build_layer.erase_cell(c)
		terrain_deltas.erase(c)
		return
	if planned_buildings.has(c):
		removed_cells[c] = true
		var e: Dictionary = planned_buildings[c]
		for i in e["fp"].x:
			for j in e["fp"].y:
				occupied.erase(c + Vector2i(i, j))
	elif built.has(c):
		built.erase(c)
		occupied.erase(c)
	var s: Structure = structures.get(c)
	if s != null:
		_free_structure_node(s)


# ======================================================================= som
## Servidor: barulho em 'pos' (raio isométrico em px). Infectados no raio vão investigar.
func make_noise(pos: Vector2, radius: float) -> void:
	for n in get_tree().get_nodes_in_group("infected"):
		var e := n as Infected
		var off := e.position - pos
		if Vector2(off.x, off.y * 2.0).length() <= radius:
			e.hear(pos)


## Efeito de tiro em todos os peers (rastros e clarão do cano).
@rpc("authority", "call_local", "unreliable")
func shot_fx(from: Vector2, tos: PackedVector2Array) -> void:
	var fx := ShotFx.new()
	fx.from = from
	fx.tos = tos
	add_child(fx)


# ======================================================================= inimigos / loot
## Servidor: cria um infectado replicado.
func spawn_infected(pos: Vector2, elite: bool, extra := {}) -> Infected:
	var d := {"t": "inf", "pos": [pos.x, pos.y], "elite": elite}
	d.merge(extra)
	return spawn_net(d)


func drop_loot(pos: Vector2, items: Array) -> void:
	drop_items(pos, items)


func _random_spawn_pos(around: Vector2) -> Vector2:
	var a := rng.randf() * TAU
	return around + Vector2(cos(a) * rng.randf_range(440.0, 540.0), sin(a) * rng.randf_range(260.0, 330.0))


## Servidor: população de infectados ao redor de cada jogador vivo.
func _spawn_step() -> void:
	var alive := alive_players()
	if alive.is_empty():
		return
	var infected := get_tree().get_nodes_in_group("infected")
	for n in infected:
		var e := n as Infected
		if e.legacy:
			continue
		var near_any := false
		for p in alive:
			if e.position.distance_to(p.net_pos) <= 950.0:
				near_any = true
				break
		if not near_any:
			e.queue_free()
	for p in alive:
		var ppos := p.net_pos
		var normal := 0
		var elites := 0
		for n in infected:
			var e2 := n as Infected
			if not is_instance_valid(e2) or e2.legacy or e2.is_queued_for_deletion():
				continue
			if e2.position.distance_to(ppos) < 700.0:
				if e2.elite:
					elites += 1
				else:
					normal += 1
		var s := spore_at(ppos)
		if s >= 0.5:
			if elites < 12:
				var pos := _random_spawn_pos(ppos)
				if tile_pos(pos).length() < RADIUS + 3.0:
					spawn_infected(pos, true)
			continue
		var cap := 3 + int(clampf(tile_pos(ppos).length() / RADIUS, 0.0, 1.0) * 6.0)
		if normal < cap:
			var pos2 := _random_spawn_pos(ppos)
			if tile_pos(pos2).length() < RADIUS and not in_safe_zone(pos2):
				spawn_infected(pos2, false)
	for v in villages:
		if not v.infested:
			continue
		var vpos := ground.map_to_local(v.cell)
		if nearest_player(vpos, 1800.0) == null:
			continue
		var near := 0
		for n in infected:
			if is_instance_valid(n) and (n as Node2D).position.distance_to(vpos) < 320.0:
				near += 1
		if near < 6:
			spawn_infected(vpos + Vector2(rng.randf_range(-150, 150), rng.randf_range(-75, 75)), rng.randf() < 0.2)


# ======================================================================= simulação de vilas
func _village_step() -> void:
	for v in villages:
		var was := v.infested
		v.step(rng, clampf(Vector2(v.cell).length() / RADIUS, 0.0, 1.0))
		_request_step(v)
		if v.infested and not was:
			Game.say_all("A vila %s caiu: virou uma zona morta tomada por esporos e infectados." % v.nome)
		_npc_step(v)
		if v.infested:
			_check_cleared(v)
			continue
		v.caravan_cd -= 6.0
		if v.caravan_cd <= 0.0:
			v.caravan_cd = rng.randf_range(40.0, 80.0)
			_try_spawn_caravan(v)
		for i in container_data.size():
			var cd: Dictionary = container_data[i]
			if int(cd["village"]) == v.id and cd["items"].is_empty() and rng.randf() < 0.08:
				var total := float(v.stock["comida"]) + float(v.stock["sucata"]) + float(v.stock["medico"])
				if total > 15.0:
					var keys := ["comida", "sucata", "medico"]
					var k: String = keys[rng.randi() % 3]
					v.stock[k] = maxf(0.0, float(v.stock[k]) - 4.0)
					var items := DB.roll_loot(cd["table"], 1, rng)
					_store_items("c:%d" % i, items)
					_container_items.rpc("c:%d" % i, items)
	_villages_state.rpc(_villages_list())


func _check_cleared(v: VillageData) -> void:
	var vpos := ground.map_to_local(v.cell)
	var near := 0
	for n in get_tree().get_nodes_in_group("infected"):
		if (n as Node2D).position.distance_to(vpos) < 320.0:
			near += 1
	if near == 0 and nearest_player(vpos, 1000.0) != null:
		v.clear_t += 6.0
		if v.clear_t >= 30.0:
			v.infested = false
			v.infestation = 25.0
			v.pop = 3
			v.prosperity = 10.0
			v.clear_t = 0.0
			Game.say_all("A vila %s foi libertada! Sobreviventes voltam a ela." % v.nome)
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
	if route(v.id, best.id).is_empty():
		return
	var cargo := {"comida": 10.0, "sucata": 5.0, "medico": 2.0}
	for k in cargo:
		v.stock[k] = maxf(0.0, float(v.stock[k]) - float(cargo[k]))
	spawn_net({"t": "car", "from": v.id, "to": best.id, "cargo": cargo})


## Caminho das caravanas pelas ruas e estradas (busca em largura na malha viária),
## calculado na primeira vez e guardado. Pontos no mundo, só nas curvas.
func route(a_id: int, b_id: int) -> PackedVector2Array:
	var key := "%d>%d" % [a_id, b_id]
	if routes.has(key):
		return routes[key]
	var a := villages[a_id].cell
	var b := villages[b_id].cell
	var start := _nearest_road(a)
	var goal := _nearest_road(b)
	var prev := {start: start}
	var queue: Array[Vector2i] = [start]
	var qi := 0
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while qi < queue.size():
		var c: Vector2i = queue[qi]
		qi += 1
		if c == goal:
			break
		for d: Vector2i in dirs:
			var n := c + d
			if road_cells.has(n) and not prev.has(n):
				prev[n] = c
				queue.append(n)
	var pts := PackedVector2Array()
	if not prev.has(goal):
		routes[key] = pts
		return pts
	var cells: Array[Vector2i] = [b, goal]
	var cur := goal
	while cur != start:
		cur = prev[cur]
		cells.append(cur)
	cells.append(a)
	cells.reverse()
	for i in cells.size():
		if i == 0 or i == cells.size() - 1:
			pts.append(ground.map_to_local(cells[i]))
			continue
		var d1 := cells[i] - cells[i - 1]
		var d2 := cells[i + 1] - cells[i]
		if d1 != d2:
			pts.append(ground.map_to_local(cells[i]))
	routes[key] = pts
	return pts


func _nearest_road(c: Vector2i) -> Vector2i:
	for r in range(0, 30):
		for dx in range(-r, r + 1):
			for dy in [-r, r]:
				if road_cells.has(c + Vector2i(dx, dy)):
					return c + Vector2i(dx, dy)
				if road_cells.has(c + Vector2i(dy, dx)):
					return c + Vector2i(dy, dx)
	return c


func caravan_arrived(c: Caravan) -> void:
	var dest := villages[c.to_id]
	if dest.infested or rng.randf() < 0.12:
		dest.infestation = minf(100.0, dest.infestation + 8.0)
		return
	for k in c.cargo:
		dest.stock[k] = float(dest.stock[k]) + float(c.cargo[k])
	dest.infestation = maxf(0.0, dest.infestation - 8.0)
	var p := nearest_player(c.position, 1400.0)
	if p != null:
		Game.tell(p.peer, "Uma caravana chegou a %s." % dest.nome)


# ======================================================================= tempo e clima
## Hora do dia (0-24). O jogo começa às 8h.
func hour() -> float:
	return fmod(8.0 + Game.play_time / (DAY_SECONDS / 24.0), 24.0)


## 0 = dia claro, 1 = noite fechada (com transição no anoitecer e no amanhecer).
func darkness() -> float:
	var h := hour()
	if h >= 7.0 and h < 18.0:
		return 0.0
	if h >= 18.0 and h < 20.0:
		return (h - 18.0) / 2.0
	if h >= 5.0 and h < 7.0:
		return 1.0 - (h - 5.0) / 2.0
	return 1.0


func is_raining() -> bool:
	return str(weather.get("tipo", "")) in ["chuva", "tempestade"]


func clock_text() -> String:
	var h := hour()
	return "%02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)]


## Escurece o mundo conforme a hora e o clima (as luzes aparecem por cima).
func _update_sky() -> void:
	var dk := darkness()
	var c := Color.WHITE.lerp(Color(0.24, 0.26, 0.42), dk * 0.92)
	match str(weather.get("tipo", "")):
		"nublado":
			c = c.darkened(0.08)
		"chuva":
			c = c.darkened(0.16)
		"tempestade":
			c = c.darkened(0.28)
		"neblina":
			c = c.lerp(Color(0.62, 0.72, 0.58), 0.3)
	canvas_mod.color = c


## Multiplicador da distância em que os infectados enxergam um jogador (escuridão e clima).
var _sight_cache := {}


func sight_factor(p: Player) -> float:
	var ce: Array = _sight_cache.get(p.peer, [-1.0, 1.0])
	if Game.play_time - float(ce[0]) < 0.5:
		return float(ce[1])
	var v := _sight_factor(p)
	_sight_cache[p.peer] = [Game.play_time, v]
	return v


func _sight_factor(p: Player) -> float:
	var k := 1.0
	var pos := p.position if p.is_local() else p.net_pos
	var dk := darkness()
	if dk > 0.0 and not (p.data != null and p.data.lantern_on()) and not lit_at(pos):
		k *= 1.0 - 0.4 * dk
	match str(weather.get("tipo", "")):
		"neblina":
			k *= 0.6
		"tempestade":
			k *= 0.75
		"chuva":
			k *= 0.9
	return k


## Multiplicador do barulho (a chuva abafa os passos).
func noise_factor() -> float:
	match str(weather.get("tipo", "")):
		"chuva":
			return 0.75
		"tempestade":
			return 0.55
	return 1.0


## Há uma luz ligada perto (luminárias, postes, letreiros)?
func lit_at(pos: Vector2) -> bool:
	for n in get_tree().get_nodes_in_group("lights"):
		var st := n as Structure
		if st.powered:
			var off := pos - st.position
			if Vector2(off.x, off.y * 2.0).length() < 110.0 * float(DB.BUILDS[st.kind]["luz"][1]):
				return true
	return false


## Servidor: troca o clima de tempos em tempos.
func _weather_step() -> void:
	if Game.play_time < _weather_until:
		return
	var total := 0.0
	for k in WEATHERS:
		total += float(WEATHERS[k][0])
	var r := rng.randf() * total
	var pick := "limpo"
	for k in WEATHERS:
		r -= float(WEATHERS[k][0])
		if r <= 0.0:
			pick = k
			break
	var w: Array = WEATHERS[pick]
	_weather_until = Game.play_time + rng.randf_range(180.0, 420.0)
	_set_weather.rpc(pick, snappedf(rng.randf_range(float(w[1]), float(w[2])), 0.01))


@rpc("authority", "call_local", "reliable")
func _set_weather(tipo: String, vento: float) -> void:
	var was := str(weather.get("tipo", ""))
	weather = {"tipo": tipo, "vento": vento}
	if tipo != was and Game.hud != null:
		Game.say("Clima: %s · vento %d%%." % [WEATHER_NAMES.get(tipo, tipo), int(vento * 100.0)])
	_update_sky()


# ======================================================================= energia
## Servidor: redes de energia. Construções a até GRID_LINK tiles umas das outras formam uma
## rede: geradores (eólico de graça; combustão só queima o que falta) abastecem os
## consumidores por prioridade; a sobra carrega os bancos de baterias, que cobrem a falta.
func _power_step(dt: float) -> void:
	var nodes: Array = get_tree().get_nodes_in_group("power")
	if nodes.is_empty():
		return
	# agrupa por proximidade (busca em largura)
	var seen := {}
	for start in nodes:
		if seen.has(start):
			continue
		var grid: Array = [start]
		seen[start] = true
		var i := 0
		while i < grid.size():
			var a: Structure = grid[i]
			for b in nodes:
				if not seen.has(b) and Vector2(a.cell - (b as Structure).cell).length() <= GRID_LINK:
					seen[b] = true
					grid.append(b)
			i += 1
		_power_grid(grid, dt)


func _power_grid(grid: Array, dt: float) -> void:
	var dk := darkness()
	var free := 0.0
	var gens: Array = []
	var gen_cap := 0.0
	var bats: Array = []
	var bat_store := 0.0
	var bat_room := 0.0
	var consumers: Array = []
	var demand := 0.0
	for n in grid:
		var st := n as Structure
		var def: Dictionary = DB.BUILDS.get(st.kind, {})
		match st.kind:
			"gerador":
				if st.eternal:
					free += 250.0
				elif st.fuel > 0.0:
					gens.append(st)
					gen_cap += float(def["gera"])
			"eolico":
				st.output = float(def["gera"]) * float(st.mods) * clampf(0.15 + float(weather.get("vento", 0.3)), 0.0, 1.15) * st.aberto
				free += st.output
			"bateria_casa":
				bats.append(st)
				bat_store += st.charge
				bat_room += float(def["capacidade"]) - st.charge
			_:
				var need := float(def.get("consome", 0.0))
				if def.has("luz") and dk < 0.15:
					need = 0.0  # luzes só acendem com o escuro
				st.demand = need
				if need > 0.0:
					consumers.append(st)
					demand += need
	consumers.sort_custom(func(a: Structure, b: Structure) -> bool:
		return POWER_PRIORITY.find(a.kind) < POWER_PRIORITY.find(b.kind))
	var rem := demand
	var from_free := minf(free, rem)
	rem -= from_free
	var from_gen := minf(gen_cap, rem)
	rem -= from_gen
	var from_bat := minf(bat_store / dt, rem)
	rem -= from_bat
	var budget := demand - rem
	var changed: Array = []
	for st: Structure in consumers:
		var on := budget >= st.demand - 0.01
		if on:
			budget -= st.demand
		if st.powered != on:
			st.powered = on
			changed.append(st)
	for n in grid:
		var st2 := n as Structure
		if st2.demand <= 0.0 and not st2.kind in ["gerador", "eolico", "bateria_casa"] and st2.powered:
			st2.powered = false
			changed.append(st2)
	# geradores a combustão: queimam proporcional ao que entregaram
	for g: Structure in gens:
		var share := from_gen * float(DB.BUILDS["gerador"]["gera"]) / maxf(gen_cap, 1.0)
		var before := int(g.fuel)
		g.fuel = maxf(0.0, g.fuel - 0.12 * share / 100.0 * dt * 1.0)
		var running := share > 0.5
		if g.powered != running or int(g.fuel) != before:
			g.powered = running
			changed.append(g)
	# baterias: descarregam o que cobriram, carregam com a sobra do que é de graça
	var surplus := (free - from_free) * dt
	var drain := from_bat * dt
	for b: Structure in bats:
		var cap := float(DB.BUILDS["bateria_casa"]["capacidade"])
		var before_pct := int(b.charge / cap * 100.0)
		if drain > 0.0:
			var take := minf(drain, b.charge)
			b.charge -= take
			drain -= take
		if surplus > 0.0:
			var put := minf(surplus, cap - b.charge)
			b.charge += put
			surplus -= put
		b.powered = b.charge > 1.0
		if int(b.charge / cap * 100.0) != before_pct:
			changed.append(b)
	for n in grid:
		var st3 := n as Structure
		if st3.kind == "eolico" and st3.powered != (st3.output > 0.5):
			st3.powered = st3.output > 0.5
			changed.append(st3)
	# resumo da rede para os avisos (produção possível, consumo, bateria)
	var cap_total := 0.0
	for b2: Structure in bats:
		cap_total += float(DB.BUILDS["bateria_casa"]["capacidade"])
	var info := {"gp": int(free + gen_cap), "gc": int(demand), "gb": int((bat_store / cap_total) * 100.0) if cap_total > 0.0 else -1}
	for n in grid:
		var st4 := n as Structure
		if st4.grid != info:
			st4.grid = info
			if not st4 in changed:
				changed.append(st4)
	for st5 in changed:
		structure_changed(st5)


# ======================================================================= vilas vivas (fase 7)
## Distância (em tiles) de uma posição até o centro da vila.
func village_dist(v: VillageData, pos: Vector2) -> float:
	return tile_pos(pos).distance_to(Vector2(v.cell))


## Servidor: pedidos de socorro (abrir, vencer o prazo, concluir).
func _request_step(v: VillageData) -> void:
	if v.maybe_request(rng, Game.play_time, 6.0):
		Game.say_all("PEDIDO DE SOCORRO — %s: %s. Prazo: %d min." % [v.nome, v.request_text(), int(VillageData.REQUEST_TIME / 60.0)])
		return
	if v.request.is_empty():
		return
	if v.request_done():
		_village_success(v)
	elif Game.play_time > float(v.request.get("prazo", 0.0)):
		v.fail()
		Game.say_all("Ninguém ajudou %s a tempo. A vila perdeu moradores e está mais vulnerável." % v.nome)
		if v.infested:
			Game.say_all("A vila %s caiu: virou uma zona morta tomada por esporos e infectados." % v.nome)


func _village_success(v: VillageData) -> void:
	v.succeed()
	Game.say_all("%s recebeu ajuda! A vila prospera (nível %d) e a reputação da equipe subiu." % [v.nome, v.level()])


## Servidor: um infectado morreu (conta para pedidos de "eliminar infectados").
func on_infected_killed(pos: Vector2) -> void:
	for v in villages:
		if v.request.is_empty() or int(v.request.get("kills", 0)) <= 0:
			continue
		if village_dist(v, pos) < 30.0:
			v.request["kills"] = int(v.request["kills"]) - 1
			if v.request_done():
				_village_success(v)
				_villages_state.rpc(_villages_list())


func _villages_list() -> Array:
	var list: Array = []
	for v in villages:
		list.append(v.to_dict())
	return list


## Servidor: NPCs aparecem quando alguém se aproxima de uma vila viva e somem quando
## todos se afastam ou a vila cai.
func _npc_step(v: VillageData) -> void:
	var mine: Array = []
	for n in get_tree().get_nodes_in_group("npcs"):
		if (n as Npc).village_id == v.id and not n.is_queued_for_deletion():
			mine.append(n)
	var near := false
	for k in players:
		var p: Player = players[k]
		if village_dist(v, p.position if p.is_local() else p.net_pos) < 40.0:
			near = true
			break
	if v.infested or not near:
		for n in mine:
			n.queue_free()
		return
	if not mine.is_empty():
		return
	var center := ground.map_to_local(v.cell)
	var roles: Array[String] = ["comerciante"]
	for i in maxi(1, v.level()):
		roles.append("guarda")
	for i in mini(3, maxi(1, v.pop / 3)):
		roles.append("morador")
	if v.safe:
		roles = ["comerciante", "guarda", "morador"]
	for role in roles:
		var off := Vector2(rng.randf_range(-120, 120), rng.randf_range(-60, 60))
		if role == "comerciante":
			off = Vector2(-90, 50) if not v.safe else Vector2(-150, 10)
		var pos := center + off
		spawn_net({"t": "npc", "vid": v.id, "role": role, "nome": SurvivorData.NAMES[rng.randi() % SurvivorData.NAMES.size()],
			"pos": [pos.x, pos.y], "home": [pos.x, pos.y]})


func _village_ok_for(p: Player, vid: int) -> VillageData:
	if vid < 0 or vid >= villages.size():
		return null
	var v := villages[vid]
	if v.infested or village_dist(v, p.position if p.is_local() else p.net_pos) > 16.0:
		Game.tell(p.peer, "Você precisa estar na vila.")
		return null
	return v


## Servidor: entrega itens para o pedido de socorro da vila.
func deliver(p: Player, vid: int) -> void:
	var v := _village_ok_for(p, vid)
	if v == null or v.request.is_empty():
		return
	var given := 0
	var need: Dictionary = v.request["need"]
	for cat in need:
		var left := int(need[cat])
		for inst in p.data.all_items().duplicate():
			if left <= 0:
				break
			if VillageData.item_category(inst["id"]) != cat or int(inst.get("u", 0)) == p.data.hand_u:
				continue
			if Items.spoiled(inst):
				continue
			var k := mini(left, int(inst["n"]))
			p.data.remove_u(int(inst["u"]), k)
			left -= k
			given += k
		need[cat] = left
	if given == 0:
		Game.tell(p.peer, "Você não tem o que a vila precisa.")
		return
	v.rep += float(given)
	Game.tell(p.peer, "Você entregou %d itens para %s." % [given, v.nome])
	if v.request_done():
		_village_success(v)
		# recompensa para quem completou a entrega
		var reward := {"comida": {"feijao": 2, "agua_limpa": 2}, "sucata": {"pregos": 12, "metal": 2},
			"medico": {"bandagem": 2, "antisseptico": 1}}[v.specialty] as Dictionary
		for id in reward:
			p.data.give(id, int(reward[id]))
		Game.tell(p.peer, "Recompensa de %s: %s." % [v.nome, DB.cost_text(reward)])
	_villages_state.rpc(_villages_list())


## Servidor: doação (sobe a reputação e o estoque da vila).
func donate(p: Player, vid: int, u: int, n: int) -> void:
	var v := _village_ok_for(p, vid)
	if v == null:
		return
	var f := p.data.find(u)
	if f.is_empty() or String(f[0]).begins_with("equip:"):
		return
	var cat := VillageData.item_category(f[1]["id"])
	if cat == "":
		Game.tell(p.peer, "A vila não precisa disso.")
		return
	var part := p.data.remove_u(u, n)
	var k := int(part.get("n", 0))
	v.rep += float(VillageData.DONATE_REP[cat]) * float(k)
	var stock_key := {"comida": "comida", "med": "medico", "material": "sucata", "eletronico": "sucata"}[cat] as String
	v.stock[stock_key] = float(v.stock[stock_key]) + float(k)
	Game.tell(p.peer, "Doação para %s: %s (+%d reputação)." % [v.nome, Items.label(part), int(VillageData.DONATE_REP[cat] * k)])
	_villages_state.rpc(_villages_list())


## Servidor: compra do comerciante com a reputação da equipe.
func buy(p: Player, vid: int, item_id: String) -> void:
	var v := _village_ok_for(p, vid)
	if v == null:
		return
	for o in VillageData.OFFERS[v.specialty]:
		if o[0] != item_id or v.level() < int(o[2]):
			continue
		if v.rep < float(o[1]):
			Game.tell(p.peer, "Reputação insuficiente com %s." % v.nome)
			return
		v.rep -= float(o[1])
		p.data.give(item_id, 1)
		Game.tell(p.peer, "Você recebeu %s de %s." % [DB.item_name(item_id), v.nome])
		_villages_state.rpc(_villages_list())
		return


# ======================================================================= veículos (fase 8)
func vehicle_of(peer: int) -> Vehicle:
	for n in get_tree().get_nodes_in_group("vehicles"):
		var v := n as Vehicle
		if v.driver == peer or peer in v.passengers:
			return v
	return null


## Servidor: ações num veículo (entrar, sair, ligação direta, abastecer, consertar).
func vehicle_action(p: Player, key: String, op: String) -> void:
	var v := node_of(key) as Vehicle
	var inside := vehicle_of(p.peer)
	if op == "exit":
		if inside == null:
			return
		if inside.driver == p.peer:
			inside.driver = 0
		inside.passengers.erase(p.peer)
		p.teleport(inside.position + Vector2(0, 26))
		Game.tell(p.peer, "Você saiu do veículo.")
		return
	if v == null or not _near(p, v, 120.0):
		return
	var d := p.data
	match op:
		"drive", "ride":
			if inside != null:
				return
			if v.locked:
				Game.tell(p.peer, "Está trancado. Faça uma ligação direta (Mecânica 2).")
				return
			if v.seats_free() <= 0:
				Game.tell(p.peer, "Não há lugar.")
				return
			if op == "drive" and v.driver == 0:
				v.driver = p.peer
				p.teleport(v.position)
				Game.tell(p.peer, "Você assumiu o volante. [E] sai." + ("" if v.can_run() else " Sem energia ou quebrado: não anda."))
			else:
				v.passengers.append(p.peer)
				Game.tell(p.peer, "Você entrou como passageiro. [E] sai.")
		"refuel":
			var need := 100.0 - v.fuel
			if need <= 0.5:
				Game.tell(p.peer, "Já está cheio.")
				return
			if String(v.def()["energia"]) == "combustivel":
				var got := d.pour_fuel(need / 2.0) * 2.0
				if got <= 0.0:
					Game.tell(p.peer, "Você precisa de um galão de combustível.")
					return
				v.fuel = minf(100.0, v.fuel + got)
			else:
				var bat := d.first_of("bateria")
				if bat.is_empty():
					Game.tell(p.peer, "Você precisa de uma bateria.")
					return
				var add := minf(need, float(bat["carga"]) * 0.5)
				bat["carga"] = float(bat["carga"]) - add / 0.5
				if float(bat["carga"]) <= 0.5:
					d.remove_u(int(bat["u"]))
				v.fuel = minf(100.0, v.fuel + add)
			Game.tell(p.peer, "Energia do veículo: %d%%." % int(v.fuel))
		"hotwire":
			if not v.locked:
				return
			if d.level("mecanica") < 2:
				Game.tell(p.peer, "Ligação direta exige Mecânica 2.")
				return
			if randf() < maxf(0.05, 0.35 - 0.08 * float(d.level("mecanica"))):
				d.damage_limb("braco_d", 6.0)
				d.add_xp("mecanica", 4.0)
				Game.tell(p.peer, "Levou um choque! A ligação direta falhou.")
				return
			v.locked = false
			d.add_xp("mecanica", 15.0)
			make_noise(v.position, 300.0)
			Game.tell(p.peer, "O motor pegou: veículo destrancado.")
		"repair":
			if v.cond >= 99.0:
				Game.tell(p.peer, "Não precisa de conserto.")
				return
			if d.missing_tools(["martelo", "chave_fenda"]) != "":
				Game.tell(p.peer, "Falta ferramenta: %s." % d.missing_tools(["martelo", "chave_fenda"]))
				return
			if not d.can_afford({"metal": 1, "sucata": 2}):
				Game.tell(p.peer, "Conserto precisa de 1 metal e 2 sucatas.")
				return
			d.pay({"metal": 1, "sucata": 2})
			v.cond = minf(100.0, v.cond + 20.0 + 4.0 * float(d.level("mecanica")))
			d.add_xp("mecanica", 8.0)
			Game.tell(p.peer, "Veículo consertado: %d%%." % int(v.cond))


# ======================================================================= vida e morte
func _process(delta: float) -> void:
	_chunk_t -= delta
	if _chunk_t <= 0.0:
		_chunk_t = 0.25
		update_chunks(0 if loaded.is_empty() else 3)
	_sky_t -= delta
	if _sky_t <= 0.0:
		_sky_t = 0.25
		_update_sky()
	if not Net.is_server() or players.is_empty():
		return
	_weather_step()
	_power_t -= delta
	if _power_t <= 0.0:
		_power_t = 1.0
		_power_step(1.0)
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = 1.2
		_spawn_step()
	_village_t -= delta
	if _village_t <= 0.0:
		_village_t = 6.0
		_village_step()


## Servidor: o sobrevivente de um jogador morreu (legado, corpo ou elite, renascimento).
func on_player_died(p: Player) -> void:
	p.cancel_busy("Você morreu.")
	var veh := vehicle_of(p.peer)
	if veh != null:
		if veh.driver == p.peer:
			veh.driver = 0
		veh.passengers.erase(p.peer)
	var data := p.data
	var pos := p.position if p.is_local() else p.net_pos
	Game.add_legacy({"nome": data.nome, "jogador": p.nome, "causa": data.death_cause, "tipo": data.death_kind,
		"tempo": data.time_alive, "pos": [pos.x, pos.y]})
	var carried := Items.strip_all(data.all_items())
	for slot in data.equip:
		if not data.equip[slot].is_empty():
			Items.add(carried, Items.strip(data.equip[slot]))
	var inv := carried.duplicate(true)
	for slot in data.implants:
		Items.add(inv, {"id": String(data.implants[slot]["id"]), "n": 1})
	if data.death_kind == "infeccao":
		var e := spawn_infected(pos, true, {"legacy": true, "legacy_name": data.nome, "home": [pos.x, pos.y]})
		# inventário e implantes ficam só no servidor (caem quando o elite morre)
		e.loot = carried
		e.implants = data.implants.duplicate(true)
		Game.say_all("%s se reergue como um infectado de elite..." % data.nome)
	else:
		spawn_net({"t": "corpse", "pos": [pos.x, pos.y], "nome": data.nome, "items": inv})
		Game.say_all("%s morreu (%s)." % [data.nome, data.death_cause])
	var info := {"nome": data.nome, "causa": data.death_cause, "tipo": data.death_kind, "tempo": data.time_alive}
	if p.is_local():
		p.show_death_ui(info)
	else:
		p.show_death_ui.rpc_id(p.peer, info)
	p.respawn_t = 5.0
	Game.survivor_cache.erase(p.nome)
	Game.save_game()


## Servidor: depois da morte, o jogador cria um sobrevivente novo.
func respawn_player(p: Player) -> void:
	p.pending = true


## Servidor: ficha validada -> sobrevivente novo no abrigo.
func create_survivor(p: Player, spec: Dictionary) -> void:
	var data := SurvivorData.from_spec(spec, Game.rng)
	_attach_data(p, data)
	p.pending = false
	p.teleport(spawn_pos())
	Game.tell(p.peer, "Novo sobrevivente: %s. Você acorda no Abrigo Alfa." % data.nome)
	if p.peer != Net.my_id():
		Game.say_all("%s chegou ao abrigo." % data.nome)


# ======================================================================= persistência (deltas)
## Alterações do mundo gerado (iguais para save e para quem entra na sessão).
func world_deltas() -> Dictionary:
	var st: Array = []
	for c: Vector2i in built:
		var b: Dictionary = built[c]
		if b.get("eternal", false):
			continue
		var node: Structure = structures.get(c)
		if node != null:
			b["fuel"] = node.fuel
			b["open"] = node.open
			b.merge(node.state_extra(), true)
		var sd := b.duplicate()
		sd.erase("eternal")
		sd["cell"] = [c.x, c.y]
		st.append(sd)
	var floors: Array = []
	for c in terrain_deltas:
		floors.append([c.x, c.y, int(terrain_deltas[c])])
	var removed: Array = []
	for c in removed_cells:
		removed.append([c.x, c.y])
	var cont := {}
	for i in container_data.size():
		if container_data[i]["dirty"]:
			cont[str(i)] = container_data[i]["items"].duplicate(true)
	var vil: Array = []
	for v in villages:
		vil.append(v.to_dict())
	var ch: Array = []
	for c: Vector2i in chest_data:
		ch.append([c.x, c.y, chest_data[c].duplicate(true)])
	var wl: Array = []
	for k: Vector3i in walls:
		var wn: WallEdge = wall_nodes.get(k)
		wl.append([k.x, k.y, k.z, walls[k]["kind"], wn.open if wn != null else bool(walls[k].get("open", false))])
	var doors: Array = []
	for k2: Vector3i in map_walls:
		var wn2: WallEdge = wall_nodes.get(k2)
		if (wn2.open if wn2 != null else bool(map_walls[k2].get("open", false))):
			doors.append([k2.x, k2.y, k2.z])
	return {"version": SAVE_VERSION, "seed": seed_value, "structures": st, "floors": floors, "removed": removed,
		"containers": cont, "chests": ch, "villages": vil, "walls": wl, "map_doors": doors, "weather": weather.duplicate(),
		"weather_until": _weather_until}


## Save completo (servidor): alterações + entidades persistentes + sobreviventes por nome.
func to_dict() -> Dictionary:
	var d := world_deltas()
	var corpses: Array = []
	for n in get_tree().get_nodes_in_group("corpses"):
		var co := n as Corpse
		corpses.append({"pos": [co.position.x, co.position.y], "nome": co.nome, "items": co.items.duplicate(true),
			"decomp": co.decomp})
	var elites: Array = []
	for n in get_tree().get_nodes_in_group("infected"):
		var e := n as Infected
		if e.legacy:
			elites.append({"pos": [e.position.x, e.position.y], "home": [e.home.x, e.home.y], "nome": e.legacy_name,
				"loot": e.loot.duplicate(true), "implants": e.implants.duplicate(true), "hp": e.hp})
	var survivors := Game.survivor_cache.duplicate(true)
	for k in players:
		var p: Player = players[k]
		if p.data != null and p.alive:
			var pos := p.position if p.is_local() else p.net_pos
			survivors[p.nome] = {"data": p.data.to_dict(), "pos": [pos.x, pos.y]}
	d["corpses"] = corpses
	d["elites"] = elites
	var vehs: Array = []
	for n in get_tree().get_nodes_in_group("vehicles"):
		vehs.append((n as Vehicle).to_dict())
	d["vehicles"] = vehs
	d["survivors"] = survivors
	return d


## Aplica as alterações do mundo (servidor ao carregar e clientes ao entrar).
func apply_deltas(save: Dictionary) -> void:
	# chamado logo depois de generate(), antes de qualquer chunk carregar: só mexe nos dados
	for r in save.get("removed", []):
		var c := Game.v2i(r)
		removed_cells[c] = true
		if planned_buildings.has(c):
			var e: Dictionary = planned_buildings[c]
			for i in e["fp"].x:
				for j in e["fp"].y:
					occupied.erase(c + Vector2i(i, j))
	for f in save.get("floors", []):
		terrain_deltas[Vector2i(int(f[0]), int(f[1]))] = int(f[2])
	for sd in save.get("structures", []):
		var c3 := Game.v2i(sd["cell"])
		if built.has(c3) or not DB.BUILDS.has(str(sd["kind"])):
			continue
		var bd: Dictionary = sd.duplicate()
		bd.erase("cell")
		bd["kind"] = str(sd["kind"])
		bd["fuel"] = float(sd.get("fuel", 0.0))
		bd["open"] = bool(sd.get("open", false))
		bd["eternal"] = false
		built[c3] = bd
		occupied[c3] = true
	var cont: Dictionary = save.get("containers", {})
	for k in cont:
		var idx := int(k)
		if idx >= 0 and idx < container_data.size():
			container_data[idx]["items"] = Items.sanitize(cont[k])
			container_data[idx]["dirty"] = true
	for cd in save.get("chests", []):
		var cc := Vector2i(int(cd[0]), int(cd[1]))
		chest_data[cc] = Items.sanitize(cd[2])
		occupied[cc] = true
	for wd in save.get("walls", []):
		if DB.BUILDS.has(str(wd[3])) and is_edge_kind(str(wd[3])):
			walls[Vector3i(int(wd[0]), int(wd[1]), int(wd[2]))] = {"kind": str(wd[3]), "open": bool(wd[4])}
	for k3 in map_walls:
		map_walls[k3]["open"] = false
	for dd in save.get("map_doors", []):
		var kd := Vector3i(int(dd[0]), int(dd[1]), int(dd[2]))
		if map_walls.has(kd):
			map_walls[kd]["open"] = true
			var wn3: WallEdge = wall_nodes.get(kd)
			if wn3 != null:
				wn3.set_open(true)
	if save.has("weather"):
		weather = save["weather"]
		_weather_until = float(save.get("weather_until", _weather_until))
	for vd in save.get("villages", []):
		var vid := int(vd["id"])
		if vid < villages.size():
			villages[vid].apply_dict(vd)


## Servidor ao carregar um save: entidades persistentes (cadáveres e elites de legado).
func restore_entities(save: Dictionary) -> void:
	# veículos: os do save, ou os abandonados do plano num mundo novo
	if save.has("vehicles"):
		for vd in save["vehicles"]:
			spawn_net({"t": "veh", "kind": str(vd["kind"]), "pos": vd["pos"], "fuel": float(vd.get("fuel", 0.0)),
				"cond": float(vd.get("cond", 50.0)), "locked": bool(vd.get("locked", true)), "items": vd.get("items", [])})
	else:
		var vr := RandomNumberGenerator.new()
		vr.seed = seed_value + 992
		for spot in vehicle_spots:
			var pos := ground.map_to_local(spot["cell"])
			var loot: Array = DB.roll_loot("comum", vr.randi_range(0, 2), vr) if vr.randf() < 0.6 else []
			spawn_net({"t": "veh", "kind": spot["kind"], "pos": [pos.x, pos.y], "fuel": vr.randf_range(0.0, 35.0),
				"cond": vr.randf_range(20.0, 70.0), "locked": true, "items": loot})
	for cd in save.get("corpses", []):
		var items := Items.sanitize(cd["items"])
		spawn_net({"t": "corpse", "pos": cd["pos"], "nome": str(cd["nome"]), "items": items,
			"decomp": float(cd.get("decomp", 0.0))})
	for ed in save.get("elites", []):
		var e := spawn_infected(Game.v2(ed["pos"]), true, {"legacy": true, "legacy_name": str(ed["nome"]),
			"home": ed["home"], "hp": float(ed.get("hp", 110.0))})
		e.loot = Items.sanitize(ed["loot"])
		e.implants = ed["implants"]


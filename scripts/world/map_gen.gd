class_name MapGen
extends RefCounted
## Geração do mapa: cidades pequenas e aldeias espalhadas pelo campo, ligadas por estradas.
## Cada lugar tem um estado:
##   viva       uma das 16 vilas vivas (NPCs, comércio, pedidos de socorro)
##   abandonada janelas quebradas, paredes caídas, entulho e mais saque
##   esporos    tomada pelos esporos: fungo dentro e fora das casas, ar pesado, mais infectados
##
## Cidade pequena: praça no centro, uma rua em anel e quatro ruas saindo dela, com lojas,
## mercado, bar, clínica, oficina e casas de frente para a rua. Aldeia: uma clareira com
## algumas casas, celeiro e lavouras. Os prédios são exploráveis: piso no chão, paredes nas
## bordas das células (World.map_walls), telhado (House), móveis e caixas nos cômodos.
## Tudo sai da seed: o plano é igual em todos os peers.

const DEAD_NAMES: Array[String] = ["Vila Fantasma", "Ruínas de Ipê", "Lagoa Cinza", "Morro Calado", "Santa Cruz Velha",
	"Parada 14", "Fazenda Sombra", "Bairro Verde", "Vale do Bolor", "Ponte Partida", "Colônia Muda", "Serra Fria",
	"Mina Baixa", "Estância Rubra"]
const TYPES := {
	# tipo: [w mín, w máx, d mín, d máx, materiais, piso, telhado, móveis, mesa de saque]
	"casa": [3, 5, 3, 5, ["reboco", "madeira", "tijolo"], World.T.PISO_MADEIRA, ["telha", "telha_cinza"],
		["cama", "armario", "sofa", "tv", "mesa", "cadeira", "geladeira", "fogao", "pia", "estante", "vaso"], ["comum", "comum", "medico"]],
	"loja": [3, 4, 3, 4, ["tijolo", "concreto"], World.T.AZULEJO, ["laje"],
		["balcao", "prateleira", "prateleira", "prateleira", "geladeira"], ["comum", "comum", "tecnico"]],
	"mercado": [5, 7, 4, 6, ["concreto", "tijolo"], World.T.AZULEJO, ["laje", "laje_metal"],
		["prateleira", "prateleira", "prateleira", "prateleira", "prateleira", "balcao", "geladeira", "geladeira"], ["comum", "comum", "comum"]],
	"bar": [4, 5, 3, 4, ["tijolo", "madeira"], World.T.PISO_MADEIRA, ["laje", "telha"],
		["balcao", "mesa", "mesa", "cadeira", "cadeira", "cadeira", "geladeira"], ["comum", "comum"]],
	"clinica": [4, 6, 4, 5, ["reboco", "concreto"], World.T.AZULEJO, ["laje"],
		["maca", "maca", "arquivo", "armario", "pia"], ["medico", "medico", "comum"]],
	"oficina": [4, 6, 4, 6, ["chapa", "concreto"], World.T.PISO_CONCRETO, ["laje_metal"],
		["paletes", "tambores", "pneus", "gerador_velho", "arquivo"], ["tecnico", "tecnico", "comum"]],
	"celeiro": [4, 5, 3, 4, ["madeira"], World.T.PISO_MADEIRA, ["telha", "telha_cinza"],
		["feno", "feno", "paletes", "tambores"], ["comum"]],
}
const TOWN_MIX := {"casa": 40, "loja": 18, "mercado": 8, "bar": 10, "clinica": 10, "oficina": 14}
const HAMLET_MIX := {"casa": 70, "celeiro": 18, "oficina": 12}

var w: World
var rng: RandomNumberGenerator
var _dead_name := 0


func _init(world: World) -> void:
	w = world
	rng = world.rng


func generate() -> void:
	_places()
	for pl in w.places:
		if pl["tipo"] == "cidade":
			_town_streets(pl)
		else:
			_hamlet_core(pl)
	_connect_places()
	for pl in w.places:
		if pl.has("cerca"):
			_fence(pl)
	for pl in w.places:
		_populate(pl)
	_countryside()
	_vehicles()


# ------------------------------------------------------------------ lugares
func _places() -> void:
	var specs: Array = []
	for e in ["viva", "viva", "viva", "abandonada", "abandonada", "esporos"]:
		specs.append(["cidade", e])
	for i in 13:
		specs.append(["aldeia", "viva"])
	for i in 6:
		specs.append(["aldeia", "abandonada"])
	for i in 3:
		specs.append(["aldeia", "esporos"])
	for sp in specs:
		var tipo: String = sp[0]
		var estado: String = sp[1]
		var r := rng.randi_range(12, 14) if tipo == "cidade" else rng.randi_range(7, 9)
		var dmin := 12.0
		var dmax := World.RADIUS * 0.7
		if estado == "abandonada":
			dmax = World.RADIUS * 0.82
		elif estado == "esporos":
			dmin = World.RADIUS * 0.5
			dmax = World.RADIUS * 0.82
		for attempt in 400:
			var ang := rng.randf() * TAU
			var dist := rng.randf_range(dmin, dmax)
			var c := Vector2i(roundi(cos(ang) * dist), roundi(sin(ang) * dist))
			var ok := true
			for o in w.places:
				if Vector2(c - o["cell"]).length() < float(r + int(o["r"])) + 12.0:
					ok = false
					break
			if not ok:
				continue
			var pl := {"cell": c, "tipo": tipo, "estado": estado, "r": r, "nome": "", "vid": -1}
			w.places.append(pl)
			break
	# vilas vivas (cercadas, com NPCs)
	for pl in w.places:
		if pl["estado"] == "viva" and w.villages.size() < World.N_VILLAGES:
			var vd := VillageData.new()
			vd.setup(w.villages.size(), World.VILLAGE_NAMES[w.villages.size()], pl["cell"], false, rng)
			pl["vid"] = vd.id
			pl["nome"] = vd.nome
			pl["cerca"] = int(pl["r"]) + 2
			w.villages.append(vd)
		else:
			if pl["estado"] == "viva":
				pl["estado"] = "abandonada"
			pl["nome"] = DEAD_NAMES[_dead_name % DEAD_NAMES.size()]
			_dead_name += 1
		if pl["estado"] == "esporos":
			w.dead_zones.append([Vector2(pl["cell"]), float(pl["r"])])
	# a rede das caravanas: cada vila ligada à mais próxima já listada
	for i in range(1, w.villages.size()):
		var bi := 0
		var bd := 1e9
		for j in i:
			var d := Vector2(w.villages[i].cell - w.villages[j].cell).length()
			if d < bd:
				bd = d
				bi = j
		w.villages[i].links.append(bi)
		w.villages[bi].links.append(i)


## Cerca de chapas em volta da vila viva (quadrado de meio-lado "cerca"), com portões onde
## as estradas passam. Infectados não atravessam; jogadores e NPCs usam os portões.
func _fence(pl: Dictionary) -> void:
	var c: Vector2i = pl["cell"]
	var R: int = pl["cerca"]
	var keys: Array = []
	for i in range(-R, R + 1):
		var edges := [Vector3i(c.x + i, c.y - R - 1, 1), Vector3i(c.x + i, c.y + R, 1),
			Vector3i(c.x - R - 1, c.y + i, 0), Vector3i(c.x + R, c.y + i, 0)]
		for k: Vector3i in edges:
			var a := Vector2i(k.x, k.y)
			var b := a + (Vector2i(1, 0) if k.z == 0 else Vector2i(0, 1))
			if Vector2(a).length() > World.RADIUS - 3.0:
				continue
			var gate := w.road_cells.has(a) or w.road_cells.has(b)
			w.map_walls[k] = {"kind": "w_muro_porta" if gate else "w_muro_parede", "open": false, "h": -1,
				"vid": int(pl["vid"]), "hp": World.FENCE_HP[1], "max": World.FENCE_HP[1], "broken": false}
			keys.append(k)
			var ch := World.chunk_of(a)
			if not w.map_walls_by_chunk.has(ch):
				w.map_walls_by_chunk[ch] = []
			w.map_walls_by_chunk[ch].append(k)
			# armadilhas de espetos do lado de fora dos portões
			if gate:
				var outside := a if absi(a.x - c.x) > R or absi(a.y - c.y) > R else b
				var out_dir := outside - (b if outside == a else a)
				for step in [1, 2]:
					var tc: Vector2i = outside + out_dir * step
					if not w.built.has(tc) and Vector2(tc).length() < World.RADIUS - 3.0:
						w.built[tc] = {"kind": "armadilha", "fuel": 0.0, "open": false, "eternal": true, "vila": int(pl["vid"])}
	pl["fence_keys"] = keys
	# torres automáticas nos cantos de dentro (só funcionam com o muro de nível 2 ou mais)
	for corner in [Vector2i(-R + 1, -R + 1), Vector2i(R - 1, -R + 1), Vector2i(-R + 1, R - 1), Vector2i(R - 1, R - 1)]:
		var tcell: Vector2i = c + corner
		if w._free_cell(tcell) and not w.ground_cells.has(tcell):
			w.built[tcell] = {"kind": "torre", "fuel": 0.0, "open": false, "eternal": true, "vila": int(pl["vid"])}
			w.occupied[tcell] = true


# ------------------------------------------------------------------ ruas
func _road(c: Vector2i, t: int) -> void:
	if Vector2(c).length() > World.RADIUS - 2.0:
		return
	if not w.road_cells.has(c) or (t != World.T.TERRA_BATIDA and int(w.road_cells[c]) == World.T.TERRA_BATIDA):
		w.road_cells[c] = t
		w.ground_cells.erase(c)


## Praça, rua em anel e quatro ruas saindo dela.
func _town_streets(pl: Dictionary) -> void:
	var c: Vector2i = pl["cell"]
	var r: int = pl["r"]
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			w.ground_cells[c + Vector2i(dx, dy)] = World.T.VILA
	for dx in range(-5, 6):
		for dy in range(-5, 6):
			if maxi(absi(dx), absi(dy)) >= 4:
				_road(c + Vector2i(dx, dy), World.T.ESTRADA)
	for k in range(6, r + 1):
		for o in 2:
			_road(c + Vector2i(k, o), World.T.FAIXA_X if o == 1 else World.T.ESTRADA)
			_road(c + Vector2i(-k, o), World.T.FAIXA_X if o == 1 else World.T.ESTRADA)
			_road(c + Vector2i(o, k), World.T.FAIXA_Y if o == 1 else World.T.ESTRADA)
			_road(c + Vector2i(o, -k), World.T.FAIXA_Y if o == 1 else World.T.ESTRADA)
	# faixas de pedestre na saída do anel
	for o in 2:
		for k in [6, -6]:
			w.road_cells[c + Vector2i(k, o)] = World.T.ZEBRA_Y
			w.road_cells[c + Vector2i(o, k)] = World.T.ZEBRA_X


## Aldeia: clareira de terra batida no centro.
func _hamlet_core(pl: Dictionary) -> void:
	var c: Vector2i = pl["cell"]
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			w.ground_cells[c + Vector2i(dx, dy)] = World.T.VILA if pl["estado"] == "viva" else World.T.TERRA


## Estradas entre os lugares: cada um liga ao mais próximo já ligado (asfalto entre
## cidades, terra batida para as aldeias).
func _connect_places() -> void:
	var order: Array = w.places.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Vector2(a["cell"]).length() < Vector2(b["cell"]).length())
	for i in range(1, order.size()):
		var a: Dictionary = order[i]
		var best: Dictionary = order[0]
		var bd := 1e9
		for j in i:
			var d := Vector2(a["cell"] - order[j]["cell"]).length()
			if d < bd:
				bd = d
				best = order[j]
		var asphalt: bool = a["tipo"] == "cidade" and best["tipo"] == "cidade"
		_carve(_exit(a, best["cell"]), _exit(best, a["cell"]), asphalt)


## Ponto de saída de um lugar na direção de outro (fim de uma das ruas da cidade).
func _exit(pl: Dictionary, toward: Vector2i) -> Vector2i:
	var c: Vector2i = pl["cell"]
	if pl["tipo"] != "cidade":
		return c
	var r: int = pl["r"]
	var best := c
	var bd := 1e9
	for e in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r)]:
		var d := Vector2(c + e - toward).length()
		if d < bd:
			bd = d
			best = c + e
	return best


func _carve(a: Vector2i, b: Vector2i, asphalt: bool) -> void:
	var c := a
	var x_first := rng.randf() < 0.5
	var path: Array = []
	for phase in 2:
		var on_x := (phase == 0) == x_first
		if on_x:
			while c.x != b.x:
				c.x += signi(b.x - c.x)
				path.append([c, true])
		else:
			while c.y != b.y:
				c.y += signi(b.y - c.y)
				path.append([c, false])
	for e in path:
		var p: Vector2i = e[0]
		var along_x: bool = e[1]
		if asphalt:
			_road(p, World.T.ESTRADA)
			_road(p + (Vector2i(0, 1) if along_x else Vector2i(1, 0)), World.T.FAIXA_X if along_x else World.T.FAIXA_Y)
		else:
			_road(p, World.T.TERRA_BATIDA)
			_road(p + (Vector2i(0, 1) if along_x else Vector2i(1, 0)), World.T.TERRA_BATIDA)


# ------------------------------------------------------------------ lugares: prédios e objetos
func _populate(pl: Dictionary) -> void:
	var c: Vector2i = pl["cell"]
	var r: int = pl["r"]
	var estado: String = pl["estado"]
	var vid: int = pl["vid"]
	var town: bool = pl["tipo"] == "cidade"
	var tries := 40 if town else 40
	var want := rng.randi_range(4, 7)
	var made := 0
	if town:
		made = _town_lots(pl)
		want = made + rng.randi_range(2, 4)
	for attempt in tries:
		if made >= want:
			break
		var tipo := _pick(TOWN_MIX if town else HAMLET_MIX)
		var spec: Array = TYPES[tipo]
		var sz := Vector2i(rng.randi_range(spec[0], spec[1]), rng.randi_range(spec[2], spec[3]))
		if rng.randf() < 0.5:
			sz = Vector2i(sz.y, sz.x)
		sz = Vector2i(clampi(sz.x, 3, 8), clampi(sz.y, 3, 7))
		var pos := c + Vector2i(rng.randi_range(-r, r - sz.x), rng.randi_range(-r, r - sz.y))
		var rect := Rect2i(pos, sz)
		if Vector2(rect.get_center() - c).length() > float(r) + 1.0:
			continue
		var side := _facing(rect, c, town)
		if side < 0:
			continue
		if _house(rect, tipo, estado, side, vid):
			made += 1
	# objetos da praça e do entorno
	match estado:
		"viva":
			if true:
				_scatter(c, 1, 3, 4, _group("vila"))
				for k in 6:
					var e: Vector2i = c + [Vector2i(-3, -3), Vector2i(3, -3), Vector2i(-3, 3), Vector2i(3, 3), Vector2i(-3, 0), Vector2i(3, 2)][k]
					if w._free_cell(e) and rng.randf() < 0.7:
						w._add_prop("barricada", 0, e)
				for i in 2:
					var cc := c + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
					if w._free_cell(cc):
						w._add_container(cc, ["comum", "medico", "tecnico"][rng.randi() % 3], vid)
			_scatter(c, 2, r, 3, _group("abrigo"))
		"abandonada":
			_scatter(c, 0, r, rng.randi_range(5, 9), ["carro_queimado", "tambores", "pneus", "entulho", "entulho", "cacamba", "barreira"])
		"esporos":
			_scatter(c, 0, r + 3, rng.randi_range(14, 22), ["cogumelo", "cogumelo", "casulo", "fungo", "arvore_morta"])
	if town:
		_town_furniture(pl)
	else:
		for i in rng.randi_range(1, 2):
			_field_near(c, r)


## Lotes ao longo das quatro ruas da cidade, dos dois lados, de frente para a calçada.
func _town_lots(pl: Dictionary) -> int:
	var c: Vector2i = pl["cell"]
	var r: int = pl["r"]
	var made := 0
	# eixo: (direção ao longo da rua, direção para fora da rua); a rua ocupa as linhas 0 e 1
	for axis in 4:
		var along: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][axis]
		for side_sign in [-1, 1]:
			var t := 7
			while t < r:
				var tipo := _pick(TOWN_MIX)
				var spec: Array = TYPES[tipo]
				var length := rng.randi_range(spec[0], spec[1])
				var depth := rng.randi_range(spec[2], spec[3])
				length = clampi(length, 3, 7)
				depth = clampi(depth, 3, 6)
				if t + length > r + 1:
					break
				var rect: Rect2i
				var door: int
				if along.x != 0:
					var x0 := c.x + (t if along.x > 0 else -t - length + 1)
					if side_sign < 0:
						rect = Rect2i(x0, c.y - 1 - depth, length, depth)
						door = 0
					else:
						rect = Rect2i(x0, c.y + 3, length, depth)
						door = 2
				else:
					var y0 := c.y + (t if along.y > 0 else -t - length + 1)
					if side_sign < 0:
						rect = Rect2i(c.x - 1 - depth, y0, depth, length)
						door = 3
					else:
						rect = Rect2i(c.x + 3, y0, depth, length)
						door = 1
				if _house(rect, tipo, pl["estado"], door, pl["vid"]):
					made += 1
					t += length + 1
				else:
					t += 1
	return made


## Lado da porta (0 = +y, 1 = -x, 2 = -y, 3 = +x): na cidade, o lado com rua mais perto
## (até 3 células); na aldeia, o lado virado para o centro. -1 = não serve.
func _facing(rect: Rect2i, center: Vector2i, town: bool) -> int:
	var mids := [Vector2i(rect.position.x + rect.size.x / 2, rect.end.y), Vector2i(rect.position.x - 1, rect.position.y + rect.size.y / 2),
		Vector2i(rect.position.x + rect.size.x / 2, rect.position.y - 1), Vector2i(rect.end.x, rect.position.y + rect.size.y / 2)]
	var dirs := [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0)]
	if town:
		var best := -1
		var bd := 99
		for s in 4:
			for k in 3:
				if w.road_cells.has(mids[s] + dirs[s] * k):
					if k < bd:
						bd = k
						best = s
					break
		return best
	var to_c := Vector2(center - rect.get_center())
	var bs := 0
	var bdot := -1e9
	for s in 4:
		var dot := Vector2(dirs[s]).dot(to_c)
		if dot > bdot:
			bdot = dot
			bs = s
	return bs


func _pick(mix: Dictionary) -> String:
	var total := 0.0
	for k in mix:
		total += float(mix[k])
	var r := rng.randf() * total
	for k in mix:
		r -= float(mix[k])
		if r <= 0.0:
			return k
	return mix.keys()[0]


## Prédio explorável: piso, paredes nas bordas (porta, janelas, divisória), telhado, móveis e caixas.
func _house(rect: Rect2i, tipo: String, estado: String, door_side: int, vid := -1) -> bool:
	# não atravessa a cerca de nenhuma vila
	for pl in w.places:
		if pl.has("cerca"):
			var R: int = pl["cerca"]
			var inner := Rect2i(pl["cell"] - Vector2i(R, R), Vector2i(2 * R + 1, 2 * R + 1))
			var outer := inner.grow(2)
			if rect.intersects(outer) and not inner.grow(-1).encloses(rect):
				return false
	for x in range(rect.position.x - 1, rect.end.x + 1):
		for y in range(rect.position.y - 1, rect.end.y + 1):
			var q := Vector2i(x, y)
			var inside := rect.has_point(q)
			if inside and (not w._free_cell(q) or w.ground_cells.has(q)):
				return false
			if not inside and (w.house_cells.has(q) or w.occupied.has(q)):
				return false
	var spec: Array = TYPES[tipo]
	var mats: Array = spec[4]
	var mat: String = mats[rng.randi() % mats.size()]
	var roofs: Array = spec[6]
	var roof := "%s_%dx%d" % [roofs[rng.randi() % roofs.size()], rect.size.x, rect.size.y]
	if estado == "esporos":
		roof = "" if rng.randf() < 0.35 else "esporos_%dx%d" % [rect.size.x, rect.size.y]
	elif estado == "abandonada" and rng.randf() < 0.3:
		roof = ""
	var id := w.houses.size()
	# "windows": bordas por onde dá para espiar o interior (janelas, vitrines, buracos)
	w.houses[id] = {"rect": rect, "roof": roof, "tipo": tipo, "estado": estado, "windows": []}
	w._plan_add(rect.position, {"t": "h", "id": id, "cell": rect.position})
	for x in rect.size.x:
		for y in rect.size.y:
			var q2 := rect.position + Vector2i(x, y)
			w.house_cells[q2] = id
			var floor_t: int = spec[5]
			if estado == "esporos" and rng.randf() < 0.65:
				floor_t = World.T.ESPOROS
			elif estado == "abandonada" and rng.randf() < 0.12:
				floor_t = World.T.MANCHA
			w.ground_cells[q2] = floor_t
	# paredes externas
	var shop := tipo in ["loja", "mercado", "bar"]
	var big := rect.size.x * rect.size.y >= 16
	for side in 4:
		var n := rect.size.x if side % 2 == 0 else rect.size.y
		for i in n:
			var k := _edge(rect, side, i)
			var variant := "parede"
			var mid := n / 2
			if side == door_side and i == mid:
				variant = "porta"
			elif side == (door_side + 2) % 4 and big and i == mid and rng.randf() < 0.5:
				variant = "porta"
			elif shop and side == door_side:
				variant = "vitrine"
			elif i % 2 == 1:
				variant = "janela"
			match estado:
				"abandonada":
					if variant == "janela" and rng.randf() < 0.6:
						variant = "janela_q"
					elif variant == "vitrine" and rng.randf() < 0.5:
						variant = "janela_q"
					elif variant == "parede" and rng.randf() < 0.14:
						variant = "quebrada"
					if variant != "porta" and rng.randf() < 0.05:
						w.houses[id]["windows"].append(k)
						continue
				"esporos":
					if variant in ["janela", "vitrine"]:
						variant = "janela_q"
					elif variant == "parede" and rng.randf() < 0.55:
						variant = "esporos"
					elif variant == "parede" and rng.randf() < 0.2:
						variant = "quebrada"
			if variant in ["janela", "janela_q", "vitrine", "quebrada"]:
				w.houses[id]["windows"].append(k)
			var wk := "w_%s_%s" % [mat, variant]
			var open := variant == "porta" and estado != "viva" and rng.randf() < 0.5
			_add_map_wall(k, wk, open)
	# divisória nas casas maiores (com uma passagem)
	var door_cells: Array[Vector2i] = [_inside_cell(rect, door_side)]
	if tipo in ["casa", "clinica"] and maxi(rect.size.x, rect.size.y) >= 5:
		if rect.size.x >= rect.size.y:
			var px := rect.position.x + rect.size.x / 2 - 1
			var gap := rect.position.y + rng.randi_range(0, rect.size.y - 1)
			for y in range(rect.position.y, rect.end.y):
				if y != gap:
					_add_map_wall(Vector3i(px, y, 0), "w_%s_parede" % mat, false, true)
			door_cells.append(Vector2i(px, gap))
			door_cells.append(Vector2i(px + 1, gap))
		else:
			var py := rect.position.y + rect.size.y / 2 - 1
			var gap2 := rect.position.x + rng.randi_range(0, rect.size.x - 1)
			for x in range(rect.position.x, rect.end.x):
				if x != gap2:
					_add_map_wall(Vector3i(x, py, 1), "w_%s_parede" % mat, false, true)
			door_cells.append(Vector2i(gap2, py))
			door_cells.append(Vector2i(gap2, py + 1))
	# móveis encostados nas paredes; o caminho da porta fica livre
	var blocked := {}
	for dc in door_cells:
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				blocked[dc + Vector2i(dx, dy)] = true
	var edge_cells: Array[Vector2i] = []
	var inner_cells: Array[Vector2i] = []
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var q3 := Vector2i(x, y)
			if blocked.has(q3):
				continue
			if x == rect.position.x or y == rect.position.y or x == rect.end.x - 1 or y == rect.end.y - 1:
				edge_cells.append(q3)
			else:
				inner_cells.append(q3)
	_shuffle(edge_cells)
	var furn: Array = (spec[7] as Array).duplicate()
	_shuffle(furn)
	var limit := int(edge_cells.size() * 0.5)
	var placed := 0
	for f in furn:
		if placed >= limit or edge_cells.is_empty():
			break
		var cell: Vector2i = edge_cells.pop_back()
		w._add_prop(f, rng.randi() % int(CityCatalog.PROPS[f]["frames"]), cell)
		placed += 1
	if estado == "abandonada":
		for i in rng.randi_range(1, 3):
			if not inner_cells.is_empty():
				w._add_prop("entulho", rng.randi() % 3, inner_cells.pop_back())
	elif estado == "esporos":
		for i in rng.randi_range(2, 4):
			if not inner_cells.is_empty():
				w._add_prop("fungo", 0, inner_cells.pop_back())
	# caixas de saque
	var tables: Array = spec[8]
	var n_loot := rng.randi_range(1, 2) + (1 if estado != "viva" else 0)
	if vid >= 0:
		n_loot = 1
	for i in n_loot:
		var pool := edge_cells if not edge_cells.is_empty() else inner_cells
		if pool.is_empty():
			break
		w._add_container(pool.pop_back(), tables[rng.randi() % tables.size()], vid)
	return true


## Borda i do lado 'side' do retângulo (0 = +y, 1 = -x, 2 = -y, 3 = +x).
func _edge(rect: Rect2i, side: int, i: int) -> Vector3i:
	match side:
		0:
			return Vector3i(rect.position.x + i, rect.end.y - 1, 1)
		1:
			return Vector3i(rect.position.x - 1, rect.position.y + i, 0)
		2:
			return Vector3i(rect.position.x + i, rect.position.y - 1, 1)
	return Vector3i(rect.end.x - 1, rect.position.y + i, 0)


func _inside_cell(rect: Rect2i, side: int) -> Vector2i:
	match side:
		0:
			return Vector2i(rect.position.x + rect.size.x / 2, rect.end.y - 1)
		1:
			return Vector2i(rect.position.x, rect.position.y + rect.size.y / 2)
		2:
			return Vector2i(rect.position.x + rect.size.x / 2, rect.position.y)
	return Vector2i(rect.end.x - 1, rect.position.y + rect.size.y / 2)


func _add_map_wall(k: Vector3i, kind: String, open: bool, partition := false) -> void:
	if w.map_walls.has(k):
		return  # a cerca da vila tem prioridade
	w.map_walls[k] = {"kind": kind, "open": open, "h": w.houses.size() - 1, "p": partition}
	var ch := World.chunk_of(Vector2i(k.x, k.y))
	if not w.map_walls_by_chunk.has(ch):
		w.map_walls_by_chunk[ch] = []
	w.map_walls_by_chunk[ch].append(k)


## Postes nas calçadas, bancos e lixeiras perto da praça.
func _town_furniture(pl: Dictionary) -> void:
	var c: Vector2i = pl["cell"]
	var r: int = pl["r"]
	var dead: bool = pl["estado"] != "viva"
	for x in range(-r - 1, r + 2):
		for y in range(-r - 1, r + 2):
			var q := c + Vector2i(x, y)
			if not w.is_sidewalk(q) or not w._free_cell(q):
				continue
			if (q.x + q.y) % 6 == 0 and rng.randf() < 0.8:
				w._add_prop("poste_rua", 1 if dead or rng.randf() < 0.1 else 0, q)
			elif rng.randf() < 0.06:
				var list := ["lixeira", "hidrante", "banco", "placa", "arvore_rua", "orelhao"]
				var kind: String = list[rng.randi() % list.size()]
				w._add_prop(kind, 0, q)


func _field_near(c: Vector2i, r: int) -> void:
	for attempt in 12:
		var size := Vector2i(rng.randi_range(5, 8), rng.randi_range(3, 5))
		var ang := rng.randf() * TAU
		var p := c + Vector2i(roundi(cos(ang) * (r + 4)), roundi(sin(ang) * (r + 4))) - size / 2
		var ok := true
		for x in range(-1, size.x + 1):
			for y in range(-1, size.y + 1):
				var q := p + Vector2i(x, y)
				if not w._free_cell(q) or w.ground_cells.has(q):
					ok = false
		if not ok:
			continue
		for x in size.x:
			for y in size.y:
				w.ground_cells[p + Vector2i(x, y)] = World.T.LAVOURA
				w.field_cells[p + Vector2i(x, y)] = true
		for x in size.x:
			if w._free_cell(p + Vector2i(x, size.y)):
				w._add_prop("cerca", 1, p + Vector2i(x, size.y))
		if w._free_cell(p + Vector2i(size.x, 1)):
			w._add_prop("espantalho", 0, p + Vector2i(size.x, 1))
		return


# ------------------------------------------------------------------ campo
func _countryside() -> void:
	# casas isoladas (fazendas e ruínas) perto das estradas
	var keys: Array = w.road_cells.keys()
	for i in 34:
		var rc: Vector2i = keys[rng.randi() % keys.size()]
		if _near_place(rc, 4):
			continue
		var tipo := "casa" if rng.randf() < 0.7 else "celeiro"
		var sz := Vector2i(rng.randi_range(3, 5), rng.randi_range(3, 4))
		var off := Vector2i(rng.randi_range(2, 4) * (1 if rng.randf() < 0.5 else -1), rng.randi_range(2, 4) * (1 if rng.randf() < 0.5 else -1))
		var rect := Rect2i(rc + off, sz)
		var estado := "abandonada" if rng.randf() < 0.75 else "esporos"
		if w.spore_level_cell(rect.position) < 0.4 and estado == "esporos":
			estado = "abandonada"
		var side := _facing(rect, rc, false)
		if _house(rect, tipo, estado, side) and rng.randf() < 0.4:
			_field_near(rect.get_center(), 3)
	# bosques
	for i in 80:
		var c2 := _random_open()
		var dead := w.spore_level_cell(c2) > 0.45
		for t in rng.randi_range(5, 14):
			var p := c2 + Vector2i(rng.randi_range(-4, 4), rng.randi_range(-4, 4))
			if w._free_cell(p) and not w.ground_cells.has(p):
				var kind: String = "arvore_morta" if dead and rng.randf() < 0.7 else ["arvore", "arvore", "pinheiro"][rng.randi() % 3]
				w._add_prop(kind, (rng.randi() % 2) if kind == "arvore" else 0, p)
	# pedras, arbustos e fungos
	for i in 450:
		var c4 := _random_open()
		if w._free_cell(c4) and not w.ground_cells.has(c4):
			w._add_prop("pedra" if rng.randf() < 0.4 else "arbusto", 0, c4)
	for i in 280:
		var c5 := _random_open()
		if w._free_cell(c5) and w._terrain(c5) == World.T.ESPOROS:
			w._add_prop("cogumelo" if rng.randf() < 0.65 else "casulo", 0, c5)
	# carcaças na beira das estradas
	for i in 40:
		var rc2: Vector2i = keys[rng.randi() % keys.size()]
		if _near_place(rc2, 2):
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if w._free_cell(rc2 + d) and not w.road_cells.has(rc2 + d):
				w._add_prop("carro_queimado", rng.randi() % 2, rc2 + d)
				break


func _near_place(c: Vector2i, extra: int) -> bool:
	for pl in w.places:
		if Vector2(c - pl["cell"]).length() < float(pl["r"]) + float(extra):
			return true
	return false


func _random_open() -> Vector2i:
	for attempt in 20:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(10.0, World.RADIUS - 4.0)
		var c := Vector2i(roundi(cos(ang) * dist), roundi(sin(ang) * dist))
		if not _near_place(c, 2):
			return c
	return Vector2i(roundi(World.RADIUS * 0.8), 0)


## Vagas de veículos abandonados nas estradas fora dos lugares (gerador próprio).
func _vehicles() -> void:
	var vr := RandomNumberGenerator.new()
	vr.seed = w.seed_value + 991
	for c: Vector2i in w.road_cells.keys():
		if vr.randf() > 0.012 or Vector2(c).length() < 10.0 or Vector2(c).length() > World.RADIUS * 0.8:
			continue
		if _near_place(c, 0):
			continue
		if w._free_road(c):
			w.vehicle_spots.append({"kind": "moto" if vr.randf() < 0.3 else "picape", "cell": c})


# ------------------------------------------------------------------ utilidades
func _group(g: String) -> Array:
	var out: Array = []
	for n in CityCatalog.PROPS:
		if CityCatalog.PROPS[n]["grupo"] == g:
			out.append(n)
	return out


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _scatter(center: Vector2i, rmin: int, rmax: int, count: int, list: Array) -> void:
	var placed := 0
	for attempt in count * 8:
		if placed >= count:
			return
		var c := center + Vector2i(rng.randi_range(-rmax, rmax), rng.randi_range(-rmax, rmax))
		if maxi(absi(c.x - center.x), absi(c.y - center.y)) < rmin or not w._free_cell(c):
			continue
		var kind: String = list[rng.randi() % list.size()]
		w._add_prop(kind, rng.randi() % int(CityCatalog.PROPS[kind]["frames"]), c)
		placed += 1

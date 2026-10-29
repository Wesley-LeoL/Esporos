class_name MapGen
extends RefCounted
## Geração do mapa: uma cidade de verdade no centro, que vira subúrbio, campo e, perto da
## borda, o mar de esporos.
##
##  * Grade de ruas: passo de 12 células (rua de 2 + calçada + miolo de 8x8 + calçada).
##    O quarteirão do Abrigo Alfa fica na origem. Superquarteirões de 24x24 (2x2
##    quarteirões) recebem uma zona:
##      centro    (até ~40 células)  todas as ruas; prédios altos, lojas, praças, estacionamentos
##      suburbio  (até ~76)          só as ruas pares (quarteirões de 20x20); casas com quintal
##      industria (uma fatia do subúrbio) galpões, fábricas, tanques
##      campo     (o resto)          grama, terra, bosques, fazendas, ruínas; só as rodovias
##  * Duas rodovias cruzam o mapa pelo centro; estradas de terra ligam as vilas do campo.
##  * Vilas: as da cidade ocupam um quarteirão (praça cercada de barricadas); as do campo,
##    uma clareira com casas em volta.
## Tudo sai da seed: o plano é igual em todos os peers.

const P := 12
const SB := 24
const OFF := 6
const CITY_R := 40.0
const SUBURB_R := 76.0
const URBAN := ["centro", "suburbio", "industria"]

var w: World
var rng: RandomNumberGenerator
var _reserved := {}
var _city_buildings := {}


func _init(world: World) -> void:
	w = world
	rng = world.rng


# ------------------------------------------------------------------ grade e zonas
## Posição dentro do passo da grade: 0 e 1 = rua, 2 e 11 = calçada, 3 a 10 = miolo.
static func line_pos(v: int) -> int:
	return posmod(v + OFF, P)


static func sb_of(c: Vector2i) -> Vector2i:
	return Vector2i(floori((c.x + OFF) / float(SB)), floori((c.y + OFF) / float(SB)))


static func sb_origin(sb: Vector2i) -> Vector2i:
	return sb * SB - Vector2i(OFF, OFF)


static func zone_at(world: World, c: Vector2i) -> String:
	return world.sb_zone.get(sb_of(c), "campo")


func _zone(c: Vector2i) -> String:
	return w.sb_zone.get(sb_of(c), "campo")


func _urban(sb: Vector2i) -> bool:
	return String(w.sb_zone.get(sb, "campo")) in URBAN


func assign_zones() -> void:
	var n := ceili((World.RADIUS + 12.0) / SB) + 1
	var ind_angle := rng.randf() * TAU
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var sb := Vector2i(i, j)
			var center := Vector2(sb_origin(sb)) + Vector2(SB / 2.0, SB / 2.0)
			var d := center.length() + w.noise.get_noise_2d(i * 13.0, j * 13.0) * 14.0
			var z := "campo"
			if d < CITY_R:
				z = "centro"
			elif d < SUBURB_R:
				z = "suburbio"
				if absf(angle_difference(center.angle(), ind_angle)) < 0.75:
					z = "industria"
			w.sb_zone[sb] = z


## Rua ao longo de y na coluna x (linha "x") está ativa na célula c?
func _active_line(c: Vector2i, along_y: bool) -> bool:
	var v := c.x if along_y else c.y
	var p24 := posmod(v + OFF, SB)
	var sb := sb_of(c)
	if p24 <= 1:
		# linha par: divisa entre dois superquarteirões; rodovia se passa pelo centro
		if floori((v + OFF) / float(SB)) == 0:
			return true
		var other := sb - (Vector2i(1, 0) if along_y else Vector2i(0, 1))
		return _urban(sb) or _urban(other)
	return String(w.sb_zone.get(sb, "campo")) == "centro"


func carve_grid() -> void:
	var r := int(World.RADIUS) - 2
	var crossings := {}
	for x in range(-r, r + 1):
		var lx := line_pos(x) <= 1
		for y in range(-r, r + 1):
			var ly := line_pos(y) <= 1
			if not lx and not ly:
				continue
			var c := Vector2i(x, y)
			if Vector2(c).length() > World.RADIUS - 2.0:
				continue
			var ax := lx and _active_line(c, true)
			var ay := ly and _active_line(c, false)
			if not ax and not ay:
				continue
			var t: int = World.T.ESTRADA
			if ax and ay:
				crossings[c] = true
			elif ax:
				t = World.T.FAIXA_Y if line_pos(x) == 1 else World.T.ESTRADA
			else:
				t = World.T.FAIXA_X if line_pos(y) == 1 else World.T.ESTRADA
			w.road_cells[c] = t
	# faixas de pedestre junto aos cruzamentos do centro
	for c: Vector2i in w.road_cells.keys():
		if crossings.has(c) or _zone(c) != "centro":
			continue
		var t2: int = w.road_cells[c]
		var along_y := line_pos(c.x) <= 1 and not (line_pos(c.y) <= 1)
		if along_y and (crossings.has(c + Vector2i(0, 1)) or crossings.has(c - Vector2i(0, 1))):
			w.road_cells[c] = World.T.ZEBRA_Y
		elif not along_y and (crossings.has(c + Vector2i(1, 0)) or crossings.has(c - Vector2i(1, 0))):
			w.road_cells[c] = World.T.ZEBRA_X
		else:
			w.road_cells[c] = t2


# ------------------------------------------------------------------ vilas
func place_villages() -> void:
	var v0 := VillageData.new()
	v0.setup(0, World.VILLAGE_NAMES[0], Vector2i.ZERO, true, rng)
	w.villages.append(v0)
	var tries := 0
	while w.villages.size() < World.N_VILLAGES and tries < 800:
		tries += 1
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(18.0, World.RADIUS * 0.72)
		var c := Vector2i(roundi(cos(ang) * dist), roundi(sin(ang) * dist))
		if _zone(c) in URBAN:
			c = Vector2i(roundi(c.x / 12.0) * 12, roundi(c.y / 12.0) * 12)
		if Vector2(c).length() > World.RADIUS * 0.72:
			continue
		var ok := true
		for v in w.villages:
			if Vector2(v.cell - c).length() < 26.0:
				ok = false
		if not ok or w.road_cells.has(c):
			continue
		var vd := VillageData.new()
		vd.setup(w.villages.size(), World.VILLAGE_NAMES[w.villages.size()], c, false, rng)
		w.villages.append(vd)
	for v in w.villages:
		var rad := village_radius(v)
		for dx in range(-rad, rad + 1):
			for dy in range(-rad, rad + 1):
				var c2 := v.cell + Vector2i(dx, dy)
				if not w.road_cells.has(c2):
					w.ground_cells[c2] = World.T.VILA
		_reserved[v.cell] = true


## Raio (xadrez) da praça: 3 no quarteirão da cidade, 5 na clareira do campo.
func village_radius(v: VillageData) -> int:
	return 3 if _zone(v.cell) in URBAN else 5


## Estradas de terra das vilas do campo até a estrada mais próxima; depois liga cada vila
## à mais próxima já ligada (rede das caravanas).
func connect_villages() -> void:
	var keys: Array = w.road_cells.keys()
	for v in w.villages:
		if _zone(v.cell) in URBAN:
			continue
		var best := Vector2i.ZERO
		var best_d := 1e9
		for k: Vector2i in keys:
			var dd := Vector2(k - v.cell).length_squared()
			if dd < best_d:
				best_d = dd
				best = k
		_carve_dirt(v.cell, best)
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


func _carve_dirt(a: Vector2i, b: Vector2i) -> void:
	var c := a
	var path: Array[Vector2i] = []
	while c.x != b.x:
		c.x += signi(b.x - c.x)
		path.append(c)
	while c.y != b.y:
		c.y += signi(b.y - c.y)
		path.append(c)
	for i in path.size():
		var p := path[i]
		for q in [p, p + (Vector2i(0, 1) if i < absi(b.x - a.x) else Vector2i(1, 0))]:
			if not w.road_cells.has(q) and Vector2(q).length() < World.RADIUS - 2.0:
				w.road_cells[q] = World.T.TERRA_BATIDA
				w.ground_cells.erase(q)


func decorate_villages() -> void:
	for v in w.villages:
		var urban := _zone(v.cell) in URBAN
		var rad := village_radius(v)
		if v.safe:
			w._build_shelter(v)
			_scatter(v.cell, 2, rad, 4, _group("abrigo"))
			continue
		# barricadas nos cantos e nas bordas da praça
		for k in 8:
			var e: Vector2i = [Vector2i(-rad, -rad), Vector2i(rad, -rad), Vector2i(-rad, rad), Vector2i(rad, rad),
				Vector2i(0, -rad), Vector2i(-rad, 0), Vector2i(rad, 1), Vector2i(1, rad)][k]
			if w._free_cell(v.cell + e) and rng.randf() < 0.8:
				w._add_prop("barricada", 0, v.cell + e)
		_scatter(v.cell, 1, rad - 1, 5, _group("vila"))
		for i in 4:
			var c2 := v.cell + Vector2i(rng.randi_range(-rad + 1, rad - 1), rng.randi_range(-rad + 1, rad - 1))
			if w._free_cell(c2):
				w._add_container(c2, ["comum", "medico", "tecnico"][rng.randi() % 3], v.id)
		if not urban:
			for i in 7:
				_building_ring(v.cell, rad + 1, rad + 5, "vila")


# ------------------------------------------------------------------ preenchimento
func fill() -> void:
	for sb: Vector2i in w.sb_zone:
		var z: String = w.sb_zone[sb]
		var o := sb_origin(sb)
		match z:
			"centro":
				for bi in 2:
					for bj in 2:
						_city_block(Rect2i(o + Vector2i(bi * P + 3, bj * P + 3), Vector2i(8, 8)))
			"suburbio":
				_suburb_block(Rect2i(o + Vector2i(3, 3), Vector2i(20, 20)))
			"industria":
				_industrial_block(Rect2i(o + Vector2i(3, 3), Vector2i(20, 20)))
	_countryside()
	_street_furniture()
	_vehicles()


func _has_village(r: Rect2i) -> bool:
	for v in w.villages:
		if r.grow(1).has_point(v.cell):
			return true
	return false


func _pick_building(zone: String) -> String:
	var total := 0.0
	for n in CityCatalog.BUILDINGS:
		if zone in CityCatalog.BUILDINGS[n]["zona"]:
			total += float(CityCatalog.BUILDINGS[n]["peso"])
	var fs := 18.0 if zone == "centro" else 0.0
	var r := rng.randf() * (total + fs)
	if r >= total:
		var t := rng.randf() * 100.0
		for b in World.BUILDINGS:
			t -= float(b[1])
			if t <= 0.0:
				return b[0]
		return World.BUILDINGS[0][0]
	for n in CityCatalog.BUILDINGS:
		if zone in CityCatalog.BUILDINGS[n]["zona"]:
			r -= float(CityCatalog.BUILDINGS[n]["peso"])
			if r <= 0.0:
				return n
	return "casa_a"


## Vista em que a porta (face +y do modelo) dá para o lado pedido: 0 = +y, 1 = -x, 2 = -y, 3 = +x.
func _fp(art: String, v: int) -> Vector2i:
	return ArtDB.footprint(art, v)


func _fits(c: Vector2i, fp: Vector2i, area: Rect2i) -> bool:
	if not area.encloses(Rect2i(c, fp)):
		return false
	for i in fp.x:
		for j in fp.y:
			var q := c + Vector2i(i, j)
			if not w._free_cell(q) or w.ground_cells.get(q, -1) == World.T.VILA:
				return false
	return true


## Põe um prédio encostado num lado da área, de frente para a rua daquele lado.
## side: 0 = +y, 1 = -x, 2 = -y, 3 = +x. setback = células de recuo (quintal).
func _place_on_side(area: Rect2i, zone: String, side: int, setback := 0) -> bool:
	for attempt in 6:
		var art := _pick_building(zone)
		var v := side if CityCatalog.DATA.has(art) else rng.randi() % 4
		var fp := _fp(art, v)
		var c: Vector2i
		var a0 := area.position
		var a1 := area.end - Vector2i.ONE
		match side:
			0:
				c = Vector2i(rng.randi_range(a0.x, a1.x - fp.x + 1), a1.y - setback - fp.y + 1)
			1:
				c = Vector2i(a0.x + setback, rng.randi_range(a0.y, a1.y - fp.y + 1))
			2:
				c = Vector2i(rng.randi_range(a0.x, a1.x - fp.x + 1), a0.y + setback)
			_:
				c = Vector2i(a1.x - setback - fp.x + 1, rng.randi_range(a0.y, a1.y - fp.y + 1))
		if _fits(c, fp, area):
			w._add_building(art, v, c, fp)
			return true
	return false


func _city_block(r: Rect2i) -> void:
	if _has_village(r):
		return
	var k := rng.randf()
	if k < 0.09:
		# praça com árvores
		for x in r.size.x:
			for y in r.size.y:
				w.ground_cells[r.position + Vector2i(x, y)] = World.T.GRAMA
		_scatter_in(r, 5, ["arvore_rua", "arvore", "arbusto"])
		_scatter_in(r, 3, ["banco", "poste_rua", "lixeira"])
		return
	if k < 0.16:
		# estacionamento com carcaças
		for x in r.size.x:
			for y in r.size.y:
				w.ground_cells[r.position + Vector2i(x, y)] = World.T.MANCHA
		_scatter_in(r, 3, ["carro_queimado"])
		_scatter_in(r, 3, ["cone", "pneus", "barreira"])
		_containers_in(r, 1, ["comum", "tecnico"])
		return
	if k < 0.26:
		# quarteirão desabado
		for i in 2:
			_place_on_side(r, "suburbio", rng.randi() % 4)
		_scatter_in(r, 5, ["pneus", "paletes", "tambores", "cacamba"])
		_containers_in(r, 2, ["comum", "comum", "tecnico"])
		return
	var sides := [0, 3, 1, 2]
	for s in sides:
		for i in 2:
			_place_on_side(r, "centro", s)
	_scatter_in(r, rng.randi_range(1, 3), ["cacamba", "lixeira", "ar_cond", "tambores"])
	if rng.randf() < 0.25:
		var c := r.position + Vector2i(rng.randi_range(0, r.size.x - 1), rng.randi_range(0, r.size.y - 1))
		if w._free_cell(c):
			w._add_prop(World.PROPS[rng.randi() % World.PROPS.size()], rng.randi() % 4, c, "fs")
	_containers_in(r, 3, ["comum", "comum", "medico", "tecnico"])


func _suburb_block(r: Rect2i) -> void:
	if _has_village(r):
		# a vila ocupa um dos quatro quarteirões: preenche o resto como casas
		pass
	for side in [0, 3, 1, 2]:
		for i in 4:
			_place_on_side(r, "suburbio", side, 1)
	_scatter_in(r, rng.randi_range(4, 8), ["arvore", "arvore", "pinheiro", "arbusto", "arbusto"])
	_scatter_in(r, rng.randi_range(1, 3), ["cerca", "lixeira", "carro_queimado", "caixa_dagua"])
	_containers_in(r, 5, ["comum", "comum", "medico", "tecnico"])


func _industrial_block(r: Rect2i) -> void:
	for i in 4:
		var art := "galpao" if rng.randf() < 0.65 else "fabrica"
		var v := rng.randi() % 4
		var fp := _fp(art, v)
		for attempt in 10:
			var c := r.position + Vector2i(rng.randi_range(1, r.size.x - fp.x - 1), rng.randi_range(1, r.size.y - fp.y - 1))
			if _fits(c - Vector2i.ONE, fp + Vector2i(2, 2), r):
				w._add_building(art, v, c, fp)
				break
	_scatter_in(r, rng.randi_range(6, 11), _group("industria"))
	_containers_in(r, 4, ["tecnico", "tecnico", "comum"])


## Prédio num anel ao redor de um ponto (vilas do campo).
func _building_ring(center: Vector2i, rmin: int, rmax: int, zone: String) -> void:
	for attempt in 30:
		var art := _pick_building(zone)
		var v := rng.randi() % 4
		var fp := _fp(art, v)
		var c := center + Vector2i(rng.randi_range(-rmax, rmax), rng.randi_range(-rmax, rmax))
		if maxi(absi(c.x - center.x), absi(c.y - center.y)) < rmin:
			continue
		var ok := true
		for i in fp.x:
			for j in fp.y:
				if not w._free_cell(c + Vector2i(i, j)) or w.ground_cells.get(c + Vector2i(i, j), -1) == World.T.VILA:
					ok = false
		if ok:
			w._add_building(art, v, c, fp)
			return


# ------------------------------------------------------------------ campo
func _countryside() -> void:
	# fazendas: casa, celeiro, silo e uma lavoura cercada
	var farms := 0
	for attempt in 300:
		if farms >= 18:
			break
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(SUBURB_R + 4.0, World.RADIUS * 0.85)
		var c := Vector2i(roundi(cos(ang) * dist), roundi(sin(ang) * dist))
		if _zone(c) != "campo" or not _area_free(Rect2i(c - Vector2i(2, 2), Vector2i(14, 10))):
			continue
		_farm(c)
		farms += 1
	# bosques
	for i in 80:
		var c2 := _random_campo()
		var trees := rng.randi_range(5, 14)
		var dead := w.spore_level_cell(c2) > 0.45
		for t in trees:
			var p := c2 + Vector2i(rng.randi_range(-4, 4), rng.randi_range(-4, 4))
			if w._free_cell(p) and not w.ground_cells.has(p):
				var kind: String = "arvore_morta" if dead and rng.randf() < 0.7 else ["arvore", "arvore", "pinheiro"][rng.randi() % 3]
				w._add_prop(kind, (rng.randi() % 2) if kind == "arvore" else 0, p)
	# ruínas soltas
	for i in 55:
		var c3 := _random_campo()
		var art := "casa_ruina" if rng.randf() < 0.7 else "casa_a"
		var v := rng.randi() % 4
		var fp := _fp(art, v)
		if _fits(c3, fp, Rect2i(c3, fp)):
			w._add_building(art, v, c3, fp)
			var cc := c3 + Vector2i(fp.x, rng.randi_range(0, fp.y - 1))
			if w._free_cell(cc):
				w._add_container(cc, ["comum", "comum", "medico", "tecnico"][rng.randi() % 4], -1)
	# pedras e arbustos
	for i in 420:
		var c4 := _random_campo()
		if w._free_cell(c4) and not w.ground_cells.has(c4):
			w._add_prop("pedra" if rng.randf() < 0.4 else "arbusto", 0, c4)
	# fungos na zona de esporos
	for i in 260:
		var c5 := _random_campo()
		if w._free_cell(c5) and w._terrain(c5) == World.T.ESPOROS:
			w._add_prop("cogumelo" if rng.randf() < 0.65 else "casulo", 0, c5)


func _random_campo() -> Vector2i:
	for attempt in 20:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(SUBURB_R - 6.0, World.RADIUS - 4.0)
		var c := Vector2i(roundi(cos(ang) * dist), roundi(sin(ang) * dist))
		if _zone(c) == "campo":
			return c
	return Vector2i(roundi(World.RADIUS * 0.8), 0)


func _area_free(r: Rect2i) -> bool:
	for x in r.size.x:
		for y in r.size.y:
			var c := r.position + Vector2i(x, y)
			if not w._free_cell(c) or w.ground_cells.has(c):
				return false
	return true


func _farm(c: Vector2i) -> void:
	w._add_building("fazenda", 0, c, _fp("fazenda", 0))
	w._add_building("celeiro", 3, c + Vector2i(4, 0), _fp("celeiro", 3))
	w._add_building("silo", 0, c + Vector2i(7, 0), _fp("silo", 0))
	var field := Rect2i(c + Vector2i(0, 4), Vector2i(8, 4))
	for x in field.size.x:
		for y in field.size.y:
			w.ground_cells[field.position + Vector2i(x, y)] = World.T.LAVOURA
	for x in range(field.position.x, field.end.x):
		if w._free_cell(Vector2i(x, field.end.y)):
			w._add_prop("cerca", 1, Vector2i(x, field.end.y))
	w._add_prop("espantalho", 0, field.position + Vector2i(4, 2))
	occupied_mark(field)
	for i in 2:
		var h := c + Vector2i(rng.randi_range(0, 7), -1 - rng.randi_range(0, 1))
		if w._free_cell(h):
			w._add_prop("feno", 0, h)
	var cc := c + Vector2i(-1, 1)
	if w._free_cell(cc):
		w._add_container(cc, "comum", -1)


## Lavoura: não deixa outros objetos caírem nela (mas dá para andar).
func occupied_mark(r: Rect2i) -> void:
	for x in r.size.x:
		for y in r.size.y:
			var c := r.position + Vector2i(x, y)
			if not w.occupied.has(c):
				w.field_cells[c] = true


# ------------------------------------------------------------------ rua
## Postes, lixeiras, hidrantes e bancos nas calçadas da cidade e do subúrbio.
func _street_furniture() -> void:
	for sb: Vector2i in w.sb_zone:
		var z: String = w.sb_zone[sb]
		if not z in URBAN:
			continue
		var o := sb_origin(sb)
		for x in SB:
			for y in SB:
				var c := o + Vector2i(x, y)
				if not w.is_sidewalk(c) or not w._free_cell(c):
					continue
				if (c.x + c.y) % 7 == 0 and rng.randf() < 0.75:
					w._add_prop("poste_neon" if z == "centro" and rng.randf() < 0.3 else "poste_rua", 0 if rng.randf() < 0.85 else 1, c)
				elif rng.randf() < 0.035:
					var list := ["lixeira", "hidrante", "banco", "placa", "frade", "arvore_rua"]
					if z == "centro":
						list += ["maquina_venda", "orelhao", "painel"]
					var kind: String = list[rng.randi() % list.size()]
					w._add_prop(kind, rng.randi() % int(CityCatalog.PROPS[kind]["frames"]), c)


## Vagas de veículos abandonados (gerador próprio: não muda o resto do mapa).
func _vehicles() -> void:
	var vr := RandomNumberGenerator.new()
	vr.seed = w.seed_value + 991
	var keys: Array = w.road_cells.keys()
	for c: Vector2i in keys:
		if vr.randf() > 0.006 or Vector2(c).length() < 8.0 or Vector2(c).length() > World.RADIUS * 0.8:
			continue
		if int(w.road_cells[c]) == World.T.TERRA_BATIDA and vr.randf() < 0.5:
			continue
		if w._free_road(c):
			w.vehicle_spots.append({"kind": "moto" if vr.randf() < 0.3 else "picape", "cell": c})
	# carcaças queimadas na beira das rodovias do campo
	for c2: Vector2i in keys:
		if vr.randf() < 0.01 and _zone(c2) == "campo":
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if w._free_cell(c2 + d) and not w.road_cells.has(c2 + d):
					w._add_prop("carro_queimado", vr.randi() % 2, c2 + d)
					break


# ------------------------------------------------------------------ utilidades
func _group(g: String) -> Array:
	var out: Array = []
	for n in CityCatalog.PROPS:
		if CityCatalog.PROPS[n]["grupo"] == g:
			out.append(n)
	return out


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


func _scatter_in(r: Rect2i, count: int, list: Array) -> void:
	var placed := 0
	for attempt in count * 8:
		if placed >= count:
			return
		var c := r.position + Vector2i(rng.randi_range(0, r.size.x - 1), rng.randi_range(0, r.size.y - 1))
		if not w._free_cell(c):
			continue
		var kind: String = list[rng.randi() % list.size()]
		w._add_prop(kind, rng.randi() % int(CityCatalog.PROPS[kind]["frames"]), c)
		placed += 1


func _containers_in(r: Rect2i, count: int, tables: Array) -> void:
	var placed := 0
	for attempt in count * 10:
		if placed >= count:
			return
		var c := r.position + Vector2i(rng.randi_range(0, r.size.x - 1), rng.randi_range(0, r.size.y - 1))
		if not w._free_cell(c):
			continue
		w._add_container(c, tables[rng.randi() % tables.size()], -1)
		placed += 1

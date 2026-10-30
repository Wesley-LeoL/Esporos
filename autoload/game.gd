extends Node
## Estado global: mensagens (locais, para um jogador ou para todos), legado de personagens
## mortos, salvamento (deltas, só no anfitrião) e comandos de depuração dos testes.

signal log_message(text: String)

const SAVE_PATH := "user://esporos_save.json"

var world: World
var hud: HUD
var console: DevConsole
var legacy: Array = []
## Sobreviventes de jogadores que não estão na sessão agora (nome do jogador -> dados).
var survivor_cache := {}
## Relógio do mundo em segundos de jogo (todos os peers avançam; o anfitrião corrige a cada
## 5 s). Itens perecíveis guardam o instante em que estragam (Items).
var play_time := 0.0
var clock: float:
	get:
		return play_time
var rng := RandomNumberGenerator.new()

var _autosave_t := 25.0
var _clock_t := 5.0
var _log_stdout := false


func _ready() -> void:
	rng.randomize()
	_log_stdout = "--log-msgs" in OS.get_cmdline_user_args()


## Mensagem só nesta máquina.
func say(text: String) -> void:
	log_message.emit(text)
	if _log_stdout:
		print("[msg %s] %s" % [Net.player_name, text])


## Servidor: mensagem para um jogador.
func tell(peer: int, text: String) -> void:
	if peer == Net.my_id() or peer == 0:
		say(text)
	elif Net.is_server():
		_say.rpc_id(peer, text)


## Servidor: mensagem para todos.
func say_all(text: String) -> void:
	if not Net.is_server():
		return
	say(text)
	_say.rpc(text)


@rpc("authority", "reliable")
func _say(text: String) -> void:
	say(text)


## Servidor: registra uma morte no legado e repassa a lista a todos.
func add_legacy(entry: Dictionary) -> void:
	legacy.append(entry)
	_set_legacy.rpc(legacy)


@rpc("authority", "unreliable_ordered")
func _set_clock(t: float) -> void:
	play_time = t


@rpc("authority", "reliable")
func _set_legacy(list: Array) -> void:
	legacy = list


func _process(delta: float) -> void:
	if world == null:
		return
	play_time += delta
	if not Net.is_server():
		return
	_clock_t -= delta
	if _clock_t <= 0.0:
		_clock_t = 5.0
		_set_clock.rpc(play_time)
	_autosave_t -= delta
	if _autosave_t <= 0.0:
		_autosave_t = 25.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and Net.is_server():
		save_game()


static func v2i(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


static func v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


func has_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	# saves de versões anteriores da geração do mundo não batem com o mapa atual
	return int(read_save().get("version", 0)) in World.SAVE_COMPAT


func read_save() -> Dictionary:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func save_game() -> void:
	if world == null or not Net.is_server() or Net.mode == "":
		return
	var dict := world.to_dict()
	dict["legacy"] = legacy
	dict["play_time"] = play_time
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(dict))


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## Comandos de depuração (usados por tools/screenshot.gd e tools/selftest.gd).
func debug_command(cmd: String) -> void:
	var parts := cmd.split(":", true, 1)
	var command := parts[0]
	var arg := parts[1] if parts.size() > 1 else ""
	var a := arg.split(",")
	var p: Player = world.local_player() if world != null else null
	if p == null:
		return
	match command:
		"give":
			p.data.give(a[0], int(a[1]) if a.size() > 1 else 1)
		"skill":
			p.data.skills[a[0]]["lv"] = int(a[1])
		"pathogen":
			p.data.pathogen = float(arg)
		"hurt":
			p.data.damage_limb(a[0], float(a[1]))
		"wound":
			# wound:membro,1|2 -> abre ferida direto (testes)
			var wl: Dictionary = p.data.limbs[a[0]]
			wl["wound"] = int(a[1]) if a.size() > 1 else 1
			wl["bleed"] = 0.25 * float(wl["wound"])
			wl["hp"] = minf(float(wl["hp"]), 60.0)
		"fall":
			p.data.fall_injury(float(arg))
		"wear":
			for id in a:
				p.data.wear(Items.make(id)[0])
		"tp":
			p.teleport(world.ground.map_to_local(Vector2i(int(a[0]), int(a[1]))))
		"tab":
			hud.open_menu(int(arg))
		"close":
			hud.close_menu()
		"battery":
			p.data.battery = float(arg)
		"filter":
			if p.data.has_mask():
				p.data.equip["mascara"]["filtro"] = float(arg)
		"spawn":
			world.spawn_infected(p.position + Vector2(70, 35), arg == "elite")
		"build":
			p.build_kind = arg
		"face":
			p.facing = int(arg)
		"infect":
			p.data.pathogen = 100.0
		"bleed":
			p.data.blood = 0.0
			p.data.kill("Sangramento", "fisica")
		"place":
			var base := world.ground.local_to_map(world.ground.to_local(p.position))
			var target := base + Vector2i(int(a[1]), int(a[2]))
			p.act("build", [a[0], target.x, target.y, int(a[3]) if a.size() > 3 else -1])
		"siege":
			# horda na vila mais perto (testes): siege ou siege:extra
			var pc4 := world.tile_pos(p.position)
			var bv: VillageData = null
			for v4 in world.villages:
				if bv == null or Vector2(v4.cell).distance_to(pc4) < Vector2(bv.cell).distance_to(pc4):
					bv = v4
			world.spawn_horde(bv, int(arg) if arg != "" else 0)
		"tpfence":
			# vai para dentro da cerca, junto do trecho mais danificado da vila mais perto
			var pc6 := world.tile_pos(p.position)
			var bk := Vector3i(0, 0, -1)
			var bhp := 1e9
			for v6 in world.villages:
				if Vector2(v6.cell).distance_to(pc6) < 30.0:
					for k6 in world._place_of(v6.id)["fence_keys"]:
						var e6: Dictionary = world.map_walls[k6]
						var h6 := 0.0 if e6["broken"] else float(e6["hp"])
						if h6 < bhp:
							bhp = h6
							bk = k6
			if bk.z >= 0:
				var mid := world.edge_pos(bk)
				var vc := world.ground.map_to_local(world.villages[world.village_at(mid + Vector2(0, -1))].cell) if world.village_at(mid + Vector2(0, -1)) >= 0 else mid
				p.teleport(mid + (vc - mid).normalized() * 60.0)
		"fenceinfo":
			var pc5 := world.tile_pos(p.position)
			for v5 in world.villages:
				if Vector2(v5.cell).distance_to(pc5) < 30.0:
					var broken := 0
					var dmg := 0
					for k5 in world._place_of(v5.id)["fence_keys"]:
						var e5: Dictionary = world.map_walls[k5]
						if e5["broken"]:
							broken += 1
						elif e5["hp"] < e5["max"]:
							dmg += 1
					print("[cerca] %s nível %d pop %d infest %.0f danificados %d derrubados %d dentro %d caiu %s" % [v5.nome, v5.wall_tier, v5.pop, v5.infestation, dmg, broken, world._infected_inside(v5.id), v5.infested])
		"buildmode":
			hud.set_build_mode(arg != "0")
		"hot":
			hud.hot_set(int(a[0]), a[1])
		"hotuse":
			hud.hot_use(int(arg))
		"hotsel":
			hud.hot_select(int(arg))
		"tpplace":
			# vai ao lugar n do tipo/estado pedido: tpplace:esporos,0 · tpplace:abandonada,1 · tpplace:aldeia,0
			var found := 0
			for pl in world.places:
				if pl["estado"] == a[0] or pl["tipo"] == a[0]:
					if found == int(a[1]):
						p.teleport(world.ground.map_to_local(pl["cell"] + Vector2i(2, 2)))
						break
					found += 1
		"tpwindow":
			# fica do lado de fora de uma janela do prédio mais perto
			var pc3 := world.tile_pos(p.position)
			var bh := -1
			var bdd := 1e9
			for hid in world.houses:
				if world.houses[hid]["windows"].is_empty():
					continue
				var dd2 := Vector2(world.houses[hid]["rect"].get_center()).distance_to(pc3)
				if dd2 < bdd:
					bdd = dd2
					bh = hid
			if bh >= 0:
				var kw: Vector3i = world.houses[bh]["windows"][0]
				var c1 := Vector2i(kw.x, kw.y)
				var c2 := c1 + (Vector2i(1, 0) if kw.z == 0 else Vector2i(0, 1))
				var outc := c2 if world.houses[bh]["rect"].has_point(c1) else c1
				p.teleport(world.ground.map_to_local(outc))
		"houseinfo":
			var pc2 := world.tile_pos(p.position)
			for hid in world.houses:
				var hr2: Rect2i = world.houses[hid]["rect"]
				if Vector2(hr2.get_center()).distance_to(pc2) < 8.0:
					print("[casa] ", hid, " ", world.houses[hid]["estado"], " ", world.houses[hid]["tipo"], " roof=", world.houses[hid]["roof"], " open=", world.house_open.get(hid))
			for wn in world.wall_nodes.values():
				if wn.low and wn.house_id >= 0:
					print("[parede baixa] ", wn.kind, " casa ", wn.house_id)
		"tphouse":
			# entra no prédio n mais perto (n = 0, 1, ...); "out" = para fora, na frente da porta
			var hl: Array = world.houses.keys()
			var pc := world.tile_pos(p.position)
			hl.sort_custom(func(ia, ib): return Vector2(world.houses[ia]["rect"].get_center()).distance_to(pc) < Vector2(world.houses[ib]["rect"].get_center()).distance_to(pc))
			var hr: Rect2i = world.houses[hl[int(a[0])]]["rect"]
			var cc := hr.get_center()
			if a.size() > 1:
				cc = Vector2i(hr.end.x + 1, hr.end.y + 1)
			p.teleport(world.ground.map_to_local(cc))
		"demo":
			var base2 := world.ground.local_to_map(world.ground.to_local(p.position))
			var t2 := base2 + Vector2i(int(a[0]), int(a[1]))
			p.act("demolish", [t2.x, t2.y] + ([int(a[2])] if a.size() > 2 else []))
		"door":
			var b3 := world.ground.local_to_map(world.ground.to_local(p.position))
			world.interact(p, "w:%d,%d,%d" % [b3.x + int(a[0]), b3.y + int(a[1]), int(a[2])])
		"walls":
			print("[walls] ", world.walls)
		"tpb":
			# teleporta para a frente do maior prédio próximo (teste de ordenação de profundidade)
			var best: Structure = null
			var best_d := 1e9
			for c in world.structures:
				var st: Structure = world.structures[c]
				if st.kind == "edificio" and st.fp.x * st.fp.y >= 8 and st.position.distance_to(p.position) < best_d:
					best_d = st.position.distance_to(p.position)
					best = st
			if best != null:
				var w := float(best.fp.x)
				var d := float(best.fp.y)
				var side := float(arg) if arg != "" else 0.5
				var front := best.position + Vector2(-World.HALF_W * 0.5 * (w + d), World.HALF_H * 0.5 * (d - w)).lerp(
					Vector2(World.HALF_W * 0.5 * (w - d), World.HALF_H * 0.5 * (w + d)), side)
				p.teleport(front + Vector2(0, 14))
		"tproad":
			# teleporta para um trecho de estrada longe das vilas (teste do mobiliário urbano)
			var blocks: Array = world.road_cells.keys()
			blocks.sort()
			var n := int(arg) if arg != "" else 0
			var count := 0
			for b: Vector2i in blocks:
				var far := true
				for v in world.villages:
					if (Vector2(b - v.cell)).length() < 12.0:
						far = false
				if far:
					if count == n:
						p.teleport(world.ground.map_to_local(b) + Vector2(0, World.HALF_H))
						break
					count += 1
		"use":
			p.act("use_item", [arg])
		"goto_loot":
			# vai até a caixa mais próxima com itens (testes)
			var best: Node2D = null
			for n in get_tree().get_nodes_in_group("containers"):
				var lc := n as LootContainer
				if not lc.items.is_empty() and (best == null or lc.position.distance_to(p.position) < best.position.distance_to(p.position)):
					best = lc
			if best != null:
				p.teleport(best.position + Vector2(0, 12))
		"loot":
			# abre a janela de saque do recipiente mais próximo (testes)
			p._update_nearby()
			if p.nearby != null and (p.nearby is LootContainer or p.nearby is Corpse):
				hud.open_loot(p.nearby)
		"drop_first":
			var all := p.data.all_items()
			if not all.is_empty():
				p.act("drop", [int(all[0]["u"]), int(all[0]["n"])])
		"reload":
			p.act("reload")
		"shoot":
			# atira no infectado mais próximo (testes)
			var best: Node2D = null
			for n in get_tree().get_nodes_in_group("infected"):
				if best == null or (n as Node2D).position.distance_to(p.position) < best.position.distance_to(p.position):
					best = n
			if best != null:
				var off := best.position - p.position
				p.act("attack", [p.facing, Vector2(off.x, off.y * 2.0).angle()])
		"sneak":
			p.sneaking = not p.sneaking
		"patient":
			hud.patient_peer = int(arg)
			p.act("examine", [int(arg)])
		"treat_ally":
			p.act("treat", [a[0], a[1], int(a[2]) if a.size() > 2 else 1])
		"tpv":
			var v: VillageData = world.villages[int(arg)]
			p.teleport(world.ground.map_to_local(v.cell + Vector2i(2, 3)))
		"village":
			hud.open_village(int(arg))
		"request":
			# força um pedido de socorro na vila (testes)
			var v2: VillageData = world.villages[int(a[0])]
			v2.request_cd = 0.0
			v2.request = {}
			v2.stock["comida"] = 5.0
		"deliver":
			p.act("deliver", [int(arg)])
		"goto_veh":
			var bv: Node2D = null
			for n in get_tree().get_nodes_in_group("vehicles"):
				if bv == null or (n as Node2D).position.distance_to(p.position) < bv.position.distance_to(p.position):
					bv = n
			if bv != null:
				p.teleport(bv.position + Vector2(0, 20))
		"veh":
			var vv: Node2D = null
			for n in get_tree().get_nodes_in_group("vehicles"):
				if vv == null or (n as Node2D).position.distance_to(p.position) < vv.position.distance_to(p.position):
					vv = n
			if vv != null:
				p.act("vehicle", [world.key_of(vv), arg])
		"vehtab":
			for n in get_tree().get_nodes_in_group("vehicles"):
				if (n as Node2D).position.distance_to(p.position) < 140.0:
					hud.open_vehicle(n)
		"press":
			Input.action_press(arg)
		"release":
			Input.action_release(arg)
		"vehpos":
			for n in get_tree().get_nodes_in_group("vehicles"):
				if (n as Node2D).position.distance_to(p.position) < 60.0:
					print("veiculo %s em %s · energia %.1f · jogador em %s" % [(n as Vehicle).kind, (n as Node2D).position, (n as Vehicle).fuel, p.position])
		"goto_kind":
			var bs: Node2D = null
			for c in world.structures:
				var st: Structure = world.structures[c]
				if st.kind == arg and (bs == null or st.position.distance_to(p.position) < bs.position.distance_to(p.position)):
					bs = st
			if bs != null:
				p.teleport(bs.position + Vector2(0, 14))
		"craft":
			p.act("craft", [arg])
		"built":
			print("construções salvas: %d · baús: %d · veículos: %d · %s" % [world.built.size(), world.chest_data.size(),
				get_tree().get_nodes_in_group("vehicles").size(), str(world.built.values().map(func(b): return b["kind"]))])
		"window":
			hud.open_window(arg)
		"buildtab":
			hud.build_tab = arg
			hud._rebuild_window()
			if hud.build_mode:
				hud._fill_build_bar(p)
		"ctxfirst":
			# abre o menu de contexto do primeiro item do inventário (testes)
			for n in hud.find_children("*", "InvSlot", true, false):
				var sl := n as InvSlot
				if sl.side == "inv" and not sl.inst.is_empty():
					hud.slot_menu(sl)
					break
		"chunks":
			print("chunks carregados: %d · estruturas: %d · caixas: %d · infectados: %d" % [world.loaded.size(),
				world.structures.size(), world.container_nodes.size(), get_tree().get_nodes_in_group("infected").size()])
		"clock":
			play_time += float(arg)
		"power":
			for n in get_tree().get_nodes_in_group("power"):
				var st := n as Structure
				print("[power] %s fuel=%.1f pw=%s out=%.1f dem=%.1f mods=%d aberto=%.2f carga=%.0f grid=%s light=%s" % [st.kind, st.fuel, st.powered,
					st.output, st.demand, st.mods, st.aberto, st.charge, st.grid, st._light.enabled if st._light != null else "-"])
		"hour":
			# vai até a hora pedida (0-24)
			var h := world.hour()
			play_time += fposmod(float(arg) - h, 24.0) * World.DAY_SECONDS / 24.0
			world._update_sky()
		"weather":
			var wa := arg.split(",")
			world._set_weather.rpc(wa[0], float(wa[1]) if wa.size() > 1 else 0.5)
			world._weather_until = play_time + 9999.0
		"take_all_near":
			p._update_nearby()
			if p.nearby != null:
				p.act("take_all", [world.key_of(p.nearby)])
		"goto_corpse":
			var cs := get_tree().get_nodes_in_group("corpses")
			if not cs.is_empty():
				p.teleport((cs[0] as Node2D).position + Vector2(0, 12))
		"openfurn":
			# vai até o móvel com itens mais perto e abre (testes)
			var bestc: LootContainer = null
			for n in get_tree().get_nodes_in_group("containers"):
				var lc := n as LootContainer
				if lc.art != "" and not lc.items.is_empty() and (bestc == null or lc.position.distance_to(p.position) < bestc.position.distance_to(p.position)):
					bestc = lc
			if bestc != null:
				p.teleport(bestc.position + Vector2(0, 30))
				hud.open_loot(bestc)
		"openst":
			# abre a janela da estação mais perto (testes)
			var bs: Structure = null
			for n in get_tree().get_nodes_in_group("stations"):
				if bs == null or (n as Node2D).position.distance_to(p.position) < bs.position.distance_to(p.position):
					bs = n as Structure
			if bs != null:
				hud.open_station(bs)
		"stfuel":
			for n in get_tree().get_nodes_in_group("stations"):
				if (n as Node2D).position.distance_to(p.position) < 200.0:
					p.act("refuel_station", [world.key_of(n)])
					break
		"usest":
			# [E] na construção mais perto do tipo pedido (testes)
			var bu: Structure = null
			for n in get_tree().get_nodes_in_group("station_" + arg):
				if bu == null or (n as Node2D).position.distance_to(p.position) < bu.position.distance_to(p.position):
					bu = n as Structure
			if bu != null:
				p.act("interact", [world.key_of(bu)])
		"tplock":
			# vai até a porta trancada mais perto (testes)
			var bk := Vector3i.ZERO
			var bdist := 1e9
			for k5: Vector3i in world.map_walls:
				var e5: Dictionary = world.map_walls[k5]
				var h5 := int(e5.get("h", -1))
				if h5 >= 0 and String(e5["kind"]).ends_with("_porta") and world.lock_level("h:%d" % h5) > 0:
					var d5 := world.edge_pos(k5).distance_to(p.position)
					if d5 < bdist:
						bdist = d5
						bk = k5
			if bdist < 1e9:
				# para fora da porta (o lado de fora fica do outro lado da borda)
				var hr5: Rect2i = world.houses[int(world.map_walls[bk]["h"])]["rect"]
				var out_c := Vector2i(bk.x, bk.y)
				if hr5.has_point(out_c):
					out_c += Vector2i(1, 0) if bk.z == 0 else Vector2i(0, 1)
				p.teleport(world.ground.map_to_local(out_c))
		"unlocknear":
			p._update_nearby()
			if p.nearby != null:
				p.act("unlock", [world.key_of(p.nearby)])
		"interact_near":
			p._update_nearby()
			if p.nearby != null:
				p.act("interact", [world.key_of(p.nearby)])
		"con":
			console.execute(arg)
		"conopen":
			console.open()
		"save":
			save_game()

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
			p.act("build", [a[0], target.x, target.y])
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
			var blocks: Array = world.road_blocks.keys()
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
		"clock":
			play_time += float(arg)
		"take_all_near":
			p._update_nearby()
			if p.nearby != null:
				p.act("take_all", [world.key_of(p.nearby)])
		"goto_corpse":
			var cs := get_tree().get_nodes_in_group("corpses")
			if not cs.is_empty():
				p.teleport((cs[0] as Node2D).position + Vector2(0, 12))
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

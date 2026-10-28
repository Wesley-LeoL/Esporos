extends Node
## Estado global: log de mensagens, legado de personagens mortos, salvamento (deltas)
## e comandos de depuração usados pelas ferramentas de teste.

signal log_message(text: String)

const SAVE_PATH := "user://esporos_save.json"

var world: World
var hud: HUD
var console: DevConsole
var god := false
var legacy: Array = []
var play_time := 0.0
var rng := RandomNumberGenerator.new()

var _autosave_t := 25.0


func _ready() -> void:
	rng.randomize()


func say(text: String) -> void:
	log_message.emit(text)


func _process(delta: float) -> void:
	if world == null:
		return
	play_time += delta
	_autosave_t -= delta
	if _autosave_t <= 0.0:
		_autosave_t = 25.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


static func v2i(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


static func v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


func has_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	# saves de versões anteriores da geração do mundo não batem com o mapa atual
	return int(read_save().get("version", 0)) == World.SAVE_VERSION


func read_save() -> Dictionary:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func save_game() -> void:
	if world == null or world.player == null or world.player.data == null:
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
	var p: Player = world.player if world != null else null
	match command:
		"give":
			p.data.add_item(a[0], int(a[1]) if a.size() > 1 else 1)
		"skill":
			p.data.skills[a[0]]["lv"] = int(a[1])
		"pathogen":
			p.data.pathogen = float(arg)
		"hurt":
			p.data.damage_limb(a[0], float(a[1]))
		"tp":
			p.position = world.ground.map_to_local(Vector2i(int(a[0]), int(a[1])))
			p.camera.reset_smoothing()
		"tab":
			hud.open_menu(int(arg))
		"close":
			hud.close_menu()
		"battery":
			p.data.battery = float(arg)
		"filter":
			p.data.filter = float(arg)
		"spawn":
			world.spawn_infected(p.position + Vector2(70, 35), arg == "elite")
		"build":
			p.build_kind = arg
		"face":
			p.facing = int(arg) as Player.Facing
		"infect":
			p.data.pathogen = 100.0
		"bleed":
			p.data.blood = 0.0
		"place":
			var base := world.ground.local_to_map(world.ground.to_local(p.position))
			world.try_place(a[0], base + Vector2i(int(a[1]), int(a[2])), p)
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
				p.position = front + Vector2(0, 14)
				p.camera.reset_smoothing()
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
						p.position = world.ground.map_to_local(b) + Vector2(0, World.HALF_H)
						p.camera.reset_smoothing()
						break
					count += 1
		"con":
			console.execute(arg)
		"conopen":
			console.open()
		"save":
			save_game()

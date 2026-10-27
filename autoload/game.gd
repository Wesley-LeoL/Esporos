extends Node
## Estado global: log de mensagens, legado de personagens mortos, salvamento (deltas)
## e comandos de depuração usados pelas ferramentas de teste.

signal log_message(text: String)

const SAVE_PATH := "user://esporos_save.json"

var world: World
var hud: HUD
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
	return FileAccess.file_exists(SAVE_PATH)


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
		"save":
			save_game()

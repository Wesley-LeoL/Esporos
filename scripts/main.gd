extends Node2D
## Controlador principal: tela de título, criação/continuação do mundo e HUD.

var world: World
var hud: HUD
var _title: CanvasLayer
var _status: Label
var _title_msg := ""


func _ready() -> void:
	hud = HUD.new()
	add_child(hud)
	Game.hud = hud
	Game.console = DevConsole.new()
	Game.console.name = "DevConsole"
	add_child(Game.console)
	Net.snapshot_provider = _snapshot
	Net.welcome_received.connect(_on_welcome)
	Net.peer_ready.connect(func(peer: int) -> void:
		if world != null:
			world.spawn_player(peer))
	Net.peer_left.connect(func(peer: int, pname: String) -> void:
		if world != null:
			world.remove_player(peer, pname))
	Net.session_failed.connect(_on_session_failed)
	var auto := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autostart="):
			auto = a.substr(12)
		elif a.begins_with("--name="):
			Net.player_name = a.substr(7)
	match auto:
		"":
			_show_title()
		"new", "continue":
			start_server(auto == "continue", false)
		"host", "host-continue":
			start_server(auto == "host-continue", true)
		_:
			if auto.begins_with("join:"):
				Net.join(auto.substr(5))
			else:
				_show_title()


func _show_title() -> void:
	_title = CanvasLayer.new()
	_title.layer = 30
	add_child(_title)
	var bg := ColorRect.new()
	bg.color = Color("#070b10")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.add_child(bg)
	# interface em resolução dupla, como o HUD (ver UITheme.UI_SCALE)
	var ui := Control.new()
	ui.scale = Vector2.ONE / UITheme.UI_SCALE
	ui.theme = UITheme.build_theme()
	ui.size = get_viewport().get_visible_rect().size * UITheme.UI_SCALE
	_title.add_child(ui)
	var grid := TextureRect.new()
	grid.texture = UITheme.tex("grid")
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.stretch_mode = TextureRect.STRETCH_TILE
	grid.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ui.add_child(grid)
	var vig := TextureRect.new()
	vig.texture = UITheme.tex("vignette")
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	ui.add_child(vig)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	center.add_child(vb)
	var mark := UITheme.icon_rect("contaminacao", UITheme.CONTAMINATION, 64)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(mark)
	var t := Label.new()
	t.text = "ESPOROS"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", UITheme.FONT_S * 6)
	t.add_theme_color_override("font_color", UITheme.CONTAMINATION)
	t.add_theme_constant_override("shadow_offset_x", 8)
	t.add_theme_constant_override("shadow_offset_y", 8)
	t.add_theme_color_override("font_shadow_color", Color("#2a6b66"))
	vb.add_child(t)
	var sub := Label.new()
	sub.text = "SOBREVIVÊNCIA TÁTICA CIBER-APOCALÍPTICA"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", UITheme.FONT_L)
	sub.add_theme_color_override("font_color", UITheme.ACCENT)
	vb.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	vb.add_child(gap)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(name_row)
	var name_lbl := Label.new()
	name_lbl.text = "NOME"
	name_lbl.add_theme_color_override("font_color", UITheme.MUTED)
	name_row.add_child(name_lbl)
	var name_edit := LineEdit.new()
	name_edit.text = Net.player_name
	name_edit.max_length = 18
	name_edit.custom_minimum_size = Vector2(360, 0)
	name_edit.text_changed.connect(func(t: String) -> void: Net.player_name = t)
	name_row.add_child(name_edit)
	var coop := Button.new()
	coop.toggle_mode = true
	coop.custom_minimum_size = Vector2(460, 0)
	coop.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	coop.text = "CO-OP: SÓ EU (offline)"
	coop.toggled.connect(func(on: bool) -> void:
		coop.text = "CO-OP: ABERTO (porta %d)" % Net.PORT if on else "CO-OP: SÓ EU (offline)")
	for def in [["NOVO JOGO", false], ["CONTINUAR", true]]:
		var b := Button.new()
		b.text = def[0]
		b.add_theme_font_size_override("font_size", UITheme.FONT_L)
		b.custom_minimum_size = Vector2(460, 64)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if def[1]:
			b.disabled = not Game.has_save()
		var cont: bool = def[1]
		b.pressed.connect(func() -> void:
			_close_title()
			start_server(cont, coop.button_pressed))
		vb.add_child(b)
	vb.add_child(coop)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 12)
	join_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(join_row)
	var ip_edit := LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.placeholder_text = "IP do anfitrião"
	ip_edit.custom_minimum_size = Vector2(300, 0)
	join_row.add_child(ip_edit)
	var join := Button.new()
	join.text = "ENTRAR NA SESSÃO"
	join.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	join.pressed.connect(func() -> void:
		_status.text = "Conectando a %s..." % ip_edit.text
		Net.join(ip_edit.text))
	join_row.add_child(join)
	_status = Label.new()
	_status.text = _title_msg
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", UITheme.WARN)
	vb.add_child(_status)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UITheme.box("panel", 16, Vector4(28, 20, 28, 22)))
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(box)
	var help := Label.new()
	help.text = "WASD MOVER · ESPAÇO/CLIQUE ATACAR · E INTERAGIR · TAB MENU\nX DEMOLIR · F5 SALVAR · ESC CANCELA · F1 CONSOLE DE TESTES"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", UITheme.MUTED)
	box.add_child(help)


func _close_title() -> void:
	if _title != null:
		_title.queue_free()
		_title = null


func _new_world(seed_value: int) -> void:
	world = World.new()
	add_child(world)
	move_child(world, 0)
	world.generate(seed_value)
	Game.world = world


## Anfitrião (ou solo): carrega/cria o mundo e o próprio personagem.
func start_server(continue_save: bool, coop: bool) -> void:
	if not Net.host(coop):
		return
	var save := {}
	if continue_save and Game.has_save():
		save = Game.read_save()
	else:
		Game.delete_save()
	Game.legacy = save.get("legacy", [])
	Game.play_time = float(save.get("play_time", 0.0))
	Game.survivor_cache = save.get("survivors", {})
	_new_world(int(save.get("seed", Game.rng.randi())))
	world.apply_deltas(save)
	world.restore_entities(save)
	world.spawn_player(1)
	hud.set_active(true)
	if coop:
		Game.say("Sessão co-op aberta na porta %d. Os amigos entram pelo seu IP." % Net.PORT)


## Pacote de boas-vindas para quem entra: seed + alterações do mundo + legado.
func _snapshot() -> Dictionary:
	if world == null:
		return {}
	var d := world.world_deltas()
	d["legacy"] = Game.legacy
	return d


## Cliente: gera o mesmo mundo, aplica as alterações e avisa que está pronto.
func _on_welcome(seed_value: int, snapshot: Dictionary) -> void:
	_close_title()
	Game.legacy = snapshot.get("legacy", [])
	_new_world(seed_value)
	world.apply_deltas(snapshot)
	hud.set_active(true)
	Net.send_ready()


func _on_session_failed(reason: String) -> void:
	if world != null:
		world.queue_free()
		world = null
	Game.world = null
	hud.set_active(false)
	hud.close_menu()
	hud.hide_death()
	get_tree().paused = false
	_title_msg = reason
	if _title == null:
		_show_title()
	else:
		_status.text = reason

extends Node2D
## Controlador principal: tela de título, criação/continuação do mundo e HUD.

var world: World
var hud: HUD
var _title: CanvasLayer


func _ready() -> void:
	hud = HUD.new()
	add_child(hud)
	Game.hud = hud
	Game.console = DevConsole.new()
	add_child(Game.console)
	var auto := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autostart="):
			auto = a.substr(12)
	if auto != "":
		start_game(auto == "continue")
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
	vb.add_theme_constant_override("separation", 18)
	center.add_child(vb)
	var mark := UITheme.icon_rect("contaminacao", UITheme.CONTAMINATION, 96)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(mark)
	var t := Label.new()
	t.text = "ESPOROS"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", UITheme.FONT_S * 8)
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
	gap.custom_minimum_size = Vector2(0, 20)
	vb.add_child(gap)
	for def in [["NOVO JOGO", false], ["CONTINUAR", true]]:
		var b := Button.new()
		b.text = def[0]
		b.add_theme_font_size_override("font_size", UITheme.FONT_L)
		b.custom_minimum_size = Vector2(460, 76)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if def[1]:
			b.disabled = not Game.has_save()
		var cont: bool = def[1]
		b.pressed.connect(func() -> void: _begin(cont))
		vb.add_child(b)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UITheme.box("panel", 16, Vector4(28, 20, 28, 22)))
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(box)
	var help := Label.new()
	help.text = "WASD MOVER · ESPAÇO/CLIQUE ATACAR · E INTERAGIR · TAB MENU\nX DEMOLIR · F5 SALVAR · ESC CANCELA · F1 CONSOLE DE TESTES\n\nTodos carregam o patógeno. Gerencie sua carga (0-100%).\nNão chegue perto da borda: o Mar de Esporos é letal."
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", UITheme.MUTED)
	box.add_child(help)


func _begin(continue_save: bool) -> void:
	if _title != null:
		_title.queue_free()
		_title = null
	start_game(continue_save)


func start_game(continue_save: bool) -> void:
	var save := {}
	if continue_save and Game.has_save():
		save = Game.read_save()
	else:
		Game.delete_save()
		Game.legacy = []
		Game.play_time = 0.0
	world = World.new()
	add_child(world)
	move_child(world, 0)
	world.generate(int(save.get("seed", Game.rng.randi())))
	Game.world = world
	if save.is_empty():
		world.spawn_new_survivor()
	else:
		world.apply_save(save)
	hud.set_active(true)

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
	var theme := Theme.new()
	theme.default_font_size = 10
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.04, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = theme
	_title.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	center.add_child(vb)
	var t := Label.new()
	t.text = "ESPOROS"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", Color("#9be04a"))
	vb.add_child(t)
	var sub := Label.new()
	sub.text = "sobrevivência tática ciber-apocalíptica"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var b_new := Button.new()
	b_new.text = "Novo jogo"
	b_new.pressed.connect(func() -> void: _begin(false))
	vb.add_child(b_new)
	var b_cont := Button.new()
	b_cont.text = "Continuar"
	b_cont.disabled = not Game.has_save()
	b_cont.pressed.connect(func() -> void: _begin(true))
	vb.add_child(b_cont)
	var help := Label.new()
	help.text = "\nWASD mover · Espaço/clique atacar · E interagir\nTab menu (inventário, corpo, habilidades, construção, implantes)\nX demolir · F5 salvar · Esc cancela · F1 console de testes\n\nTodos carregam o patógeno. Gerencie sua carga (0-100%).\nNão chegue perto da borda: o Mar de Esporos é letal."
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	vb.add_child(help)


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

class_name HUD
extends CanvasLayer
## Interface do jogo: barras de status, log, prompts e o menu em abas
## (inventário, corpo, habilidades, construção, implantes, mundo e legado).

const BAR_DEFS := [
	["pathogen", "☣", "CONTAMINAÇÃO", UITheme.CONTAMINATION],
	["blood", "♥", "VIDA", UITheme.LIFE],
	["hunger", "F", "FOME", UITheme.HUNGER],
	["thirst", "S", "SEDE", UITheme.THIRST],
]
const TAB_DEFS := [["inv", "Inventário"], ["corpo", "Corpo"], ["skills", "Habilidades"],
	["build", "Construção"], ["impl", "Implantes"], ["mundo", "Mundo"], ["legado", "Legado"]]

var root: Control
var bars := {}
var status_label: Label
var name_label: Label
var log_label: Label
var prompt_label: Label
var help_label: Label
var fog: ColorRect
var hurt: ColorRect
var death_panel: ColorRect
var death_label: Label
var menu_root: Control
var tabs: TabContainer
var boxes := {}
var msgs: Array = []
var _refresh_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	Game.log_message.connect(_on_log)
	var game_theme := Theme.new()
	game_theme.default_font_size = 10
	game_theme.set_color("font_color", "Label", UITheme.TEXT)
	game_theme.set_color("font_color", "Button", UITheme.TEXT)
	game_theme.set_color("font_hover_color", "Button", UITheme.ACCENT)
	game_theme.set_color("font_pressed_color", "Button", UITheme.ACCENT)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = game_theme
	root.visible = false
	add_child(root)

	fog = _overlay(Color(0.36, 0.56, 0.32, 0.0))
	hurt = _overlay(Color(0.9, 0.1, 0.1, 0.0))
	root.add_child(ScanOverlay.new())

	var bar_panel := PanelContainer.new()
	bar_panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color("#101820e8"), 7))
	root.add_child(bar_panel)
	bar_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 8)
	bar_panel.custom_minimum_size.x = 590
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	bar_panel.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", UITheme.ACCENT)
	header.add_child(name_label)
	var status_tag := Label.new()
	status_tag.text = "SISTEMA DE SOBREVIVÊNCIA"
	status_tag.add_theme_color_override("font_color", UITheme.MUTED)
	status_tag.add_theme_font_size_override("font_size", 8)
	status_tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(status_tag)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 6)
	layout.add_child(cards)
	for def in BAR_DEFS:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(136, 48)
		card.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL, 4, Color("#2b424c")))
		cards.add_child(card)
		var card_layout := VBoxContainer.new()
		card_layout.add_theme_constant_override("separation", 4)
		card.add_child(card_layout)
		var card_header := HBoxContainer.new()
		card_header.add_theme_constant_override("separation", 5)
		card_layout.add_child(card_header)
		var icon := Label.new()
		icon.text = def[1]
		icon.add_theme_color_override("font_color", def[3])
		icon.add_theme_font_size_override("font_size", 12)
		card_header.add_child(icon)
		var lbl := Label.new()
		lbl.text = def[2]
		lbl.add_theme_color_override("font_color", UITheme.MUTED)
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_header.add_child(lbl)
		var val := Label.new()
		val.text = "100%"
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.add_theme_color_override("font_color", UITheme.TEXT)
		card_header.add_child(val)
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(0, 7)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pb.show_percentage = false
		pb.max_value = 100.0
		pb.add_theme_stylebox_override("fill", UITheme.bar_fill(def[3]))
		pb.add_theme_stylebox_override("background", UITheme.bar_background())
		card_layout.add_child(pb)
		bars[def[0]] = [pb, val]

	status_label = Label.new()
	status_label.add_theme_color_override("font_color", UITheme.MUTED)
	status_label.add_theme_font_size_override("font_size", 9)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status_label)

	log_label = Label.new()
	log_label.add_theme_color_override("font_color", UITheme.TEXT)
	log_label.add_theme_font_size_override("font_size", 10)
	root.add_child(log_label)
	log_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 8)
	log_label.grow_vertical = Control.GROW_DIRECTION_BEGIN

	prompt_label = Label.new()
	prompt_label.add_theme_color_override("font_color", UITheme.HUNGER)
	prompt_label.add_theme_font_size_override("font_size", 12)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt_label)
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 40)
	prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_label.grow_vertical = Control.GROW_DIRECTION_BEGIN

	help_label = Label.new()
	help_label.text = "WASD mover · Espaço/clique atacar · E interagir · Tab menu · X demolir · F5 salvar · F1 console"
	help_label.add_theme_color_override("font_color", UITheme.MUTED)
	help_label.add_theme_font_size_override("font_size", 9)
	root.add_child(help_label)
	help_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	help_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	_build_menu()
	_build_death()


func set_active(on: bool) -> void:
	root.visible = on


func _overlay(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)
	return r


func _box_style(col: Color, margin: float) -> StyleBoxFlat:
	var sb := UITheme.panel_style(col, 5)
	sb.set_content_margin_all(margin)
	return sb


func _build_menu() -> void:
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.visible = false
	root.add_child(menu_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 350)
	var sb := _box_style(Color(0.06, 0.07, 0.09, 0.97), 6)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.3, 0.45, 0.35)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	tabs = TabContainer.new()
	panel.add_child(tabs)
	for def in TAB_DEFS:
		var sc := ScrollContainer.new()
		sc.name = def[1]
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(sc)
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 3)
		sc.add_child(box)
		boxes[def[0]] = box
	tabs.tab_changed.connect(func(_i: int) -> void: _rebuild())


func _build_death() -> void:
	death_panel = ColorRect.new()
	death_panel.color = Color(0.0, 0.0, 0.0, 0.72)
	death_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_panel.visible = false
	root.add_child(death_panel)
	death_label = Label.new()
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_label.add_theme_font_size_override("font_size", 14)
	death_panel.add_child(death_label)


func show_death(d: SurvivorData) -> void:
	close_menu()
	var fate := "Seu corpo se reergue como um infectado de elite, com tudo o que você carregava."
	if d.death_kind != "infeccao":
		fate = "Seu corpo ficou no mapa. Um novo sobrevivente pode recuperá-lo antes que se decomponha."
	death_label.text = "%s morreu\nCausa: %s\nSobreviveu %s\n\n%s\n\nUm novo sobrevivente chega ao abrigo..." % [
		d.nome, d.death_cause, _fmt_time(d.time_alive), fate]
	death_panel.visible = true


func hide_death() -> void:
	death_panel.visible = false


func _fmt_time(sec: float) -> String:
	return "%d:%02d" % [int(sec) / 60, int(sec) % 60]


func _on_log(text: String) -> void:
	msgs.append({"t": Time.get_ticks_msec() / 1000.0, "text": text})
	while msgs.size() > 8:
		msgs.pop_front()


func _player() -> Player:
	return Game.world.player if Game.world != null else null


# ------------------------------------------------------------------ menu
func open_menu(tab: int = -1) -> void:
	var p := _player()
	if p == null or p.data == null or p.is_dead():
		return
	if Game.console != null and Game.console.is_open():
		return
	if tab >= 0:
		tabs.current_tab = tab
	menu_root.visible = true
	get_tree().paused = true
	_rebuild()


func close_menu() -> void:
	menu_root.visible = false
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	if not root.visible:
		return
	if Game.console != null and Game.console.is_open():
		return
	if event.is_action_pressed("menu"):
		if menu_root.visible:
			close_menu()
		else:
			open_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel") and menu_root.visible:
		close_menu()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ atualização por frame
func _process(delta: float) -> void:
	var p := _player()
	if not root.visible or p == null or p.data == null:
		return
	var d := p.data
	var now := Time.get_ticks_msec() / 1000.0
	var lines: Array[String] = []
	for m in msgs:
		if now - float(m["t"]) < 14.0:
			lines.append(m["text"])
	log_label.text = "\n".join(lines)

	name_label.text = "%s  ·  %s" % [d.nome, _fmt_time(d.time_alive)]
	_set_bar("pathogen", d.pathogen)
	_set_bar("blood", d.blood)
	_set_bar("hunger", 100.0 - d.calories / SurvivorData.MAX_CAL * 100.0)
	_set_bar("thirst", d.water)

	var spore := Game.world.spore_at(p.position)
	var mask := "OFF"
	if d.mask_on:
		mask = "ON (filtro %d%%)" % int(d.filter)
	var extra: Array[String] = []
	if d.suppress_t > 0.0:
		extra.append("supressor %ds" % int(d.suppress_t))
	if d.antibiotic_t > 0.0:
		extra.append("antibiótico %ds" % int(d.antibiotic_t))
	if d.weapon != "":
		extra.append(DB.item_name(d.weapon))
	var edge_tiles := World.RADIUS - Game.world.tile_pos(p.position).length()
	var st := "Máscara %s · Esporos %.2f · borda a %d tiles" % [mask, spore, int(edge_tiles)]
	if not extra.is_empty():
		st += "\n" + " · ".join(extra)
	if p.build_kind != "":
		st += "\nCONSTRUINDO: %s (clique, Esc cancela)" % DB.BUILDS[p.build_kind]["nome"]
	elif p.demolish:
		st += "\nMODO DEMOLIÇÃO (clique, X sai)"
	status_label.text = st

	fog.color.a = clampf((spore - 0.12) * 0.36, 0.0, 0.3)
	hurt.color.a = clampf(p.hurt_flash * 1.2, 0.0, 0.22)
	if d.pathogen > 40.0:
		hurt.color = Color(0.25, 0.5, 0.15, clampf((d.pathogen - 40.0) / 60.0 * 0.2, 0.0, 0.2))
	else:
		hurt.color = Color(0.9, 0.1, 0.1, hurt.color.a)

	if p.nearby != null and is_instance_valid(p.nearby) and not menu_root.visible and p.build_kind == "":
		prompt_label.text = p.nearby.prompt()
	else:
		prompt_label.text = ""

	if menu_root.visible:
		_refresh_t -= delta
		if _refresh_t <= 0.0 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_refresh_t = 1.0
			_rebuild()


func _set_bar(key: String, value: float) -> void:
	var pair: Array = bars[key]
	var pb: ProgressBar = pair[0]
	var lbl: Label = pair[1]
	var amount := clampf(value, 0.0, 100.0)
	pb.value = amount
	lbl.text = "%d%%" % int(amount)


func _clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _lbl(parent: Control, text: String, col: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if col != Color.WHITE:
		l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _btn(parent: Control, text: String, cb: Callable, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _head(parent: Control, text: String) -> void:
	_lbl(parent, text, Color(0.6, 0.9, 0.6))


func _rebuild() -> void:
	var p := _player()
	if p == null or p.data == null or not menu_root.visible:
		return
	var d := p.data
	match tabs.current_tab:
		0: _tab_inventory(d)
		1: _tab_body(d)
		2: _tab_skills(d)
		3: _tab_build(p)
		4: _tab_implants(d)
		5: _tab_world(p)
		6: _tab_legacy(d)


func _act(cb: Callable) -> Callable:
	return func() -> void:
		cb.call()
		_rebuild()


# ------------------------------------------------------------------ abas
func _tab_inventory(d: SurvivorData) -> void:
	var box: VBoxContainer = boxes["inv"]
	_clear(box)
	_lbl(box, "Máscara: %s · Filtro: %d%% · Arma: %s" % [("ON" if d.mask_on else "OFF"), int(d.filter),
		(DB.item_name(d.weapon) if d.weapon != "" else "nenhuma")])
	_head(box, "— Itens —")
	if d.inventory.is_empty():
		_lbl(box, "Inventário vazio.", Color(0.6, 0.6, 0.6))
	var ids: Array = d.inventory.keys()
	ids.sort()
	for id: String in ids:
		var def: Dictionary = DB.ITEMS[id]
		var row := HBoxContainer.new()
		box.add_child(row)
		var ic := TextureRect.new()
		ic.texture = GenArt.icon(id)
		ic.custom_minimum_size = Vector2(GenCatalog.ICON_SIZE, GenCatalog.ICON_SIZE)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(ic)
		var l := Label.new()
		l.text = "%s x%d" % [def["nome"], d.count(id)]
		l.custom_minimum_size.x = 150
		row.add_child(l)
		var dl := _lbl(row, str(def["desc"]), Color(0.6, 0.65, 0.7))
		dl.autowrap_mode = TextServer.AUTOWRAP_OFF
		var verb := ""
		match String(def["tipo"]):
			"comida": verb = "Comer"
			"bebida": verb = "Beber"
			"mascara": verb = "Equipar" if not d.mask_on else "Tirar"
			"filtro": verb = "Trocar"
			"supressor": verb = "Aplicar"
			"bateria": verb = "Recarregar"
			"manual": verb = "Ler"
			"arma": verb = "Equipar" if d.weapon != id else "Guardar"
		if verb != "":
			_btn(row, verb, _act(func() -> void: d.use_item(id)))
	_head(box, "— Fabricação —")
	for rid: String in DB.CRAFTS:
		var cdef: Dictionary = DB.CRAFTS[rid]
		var crow := HBoxContainer.new()
		box.add_child(crow)
		var ok := d.meets(cdef["req"]) and d.can_afford(cdef["custo"])
		var cl := _lbl(crow, "%s: %s · exige %s" % [cdef["nome"], DB.cost_text(cdef["custo"]), DB.req_text(cdef["req"])],
			Color.WHITE if ok else Color(0.65, 0.5, 0.5))
		cl.autowrap_mode = TextServer.AUTOWRAP_OFF
		_btn(crow, "Fabricar", _act(func() -> void: d.craft(rid)), d.meets(cdef["req"]))


func _tab_body(d: SurvivorData) -> void:
	var box: VBoxContainer = boxes["corpo"]
	_clear(box)
	_lbl(box, "Carga patogênica %d%% · Sangue %d%% · Água %d%%" % [int(d.pathogen), int(d.blood), int(d.water)])
	var top := HBoxContainer.new()
	box.add_child(top)
	_btn(top, "Antibiótico (x%d)" % d.count("antibiotico"), _act(func() -> void: d.treat("torso", "antibiotico")), d.count("antibiotico") > 0)
	_lbl(top, "Ativo por %ds" % int(d.antibiotic_t) if d.antibiotic_t > 0.0 else "Cura sepse e infecção fúngica.", Color(0.6, 0.65, 0.7))
	for l: String in SurvivorData.LIMBS:
		var limb: Dictionary = d.limbs[l]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		box.add_child(row)
		var name_l := Label.new()
		name_l.text = SurvivorData.LIMB_NAMES[l]
		name_l.custom_minimum_size.x = 62
		row.add_child(name_l)
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(60, 7)
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pb.show_percentage = false
		pb.value = float(limb["hp"])
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("#6bcf6b") if float(limb["hp"]) > 50.0 else Color("#e0a63b") if float(limb["hp"]) > 20.0 else Color("#d13b3b")
		pb.add_theme_stylebox_override("fill", fill)
		row.add_child(pb)
		var st: Array[String] = []
		if int(limb["wound"]) == 2:
			st.append("ferida PROFUNDA")
		elif int(limb["wound"]) == 1:
			st.append("ferida leve")
		if int(limb["wound"]) > 0 and float(limb["bleed"]) > 0.0 and not (limb["bandaged"] and int(limb["wound"]) == 1):
			st.append("sangrando")
		if float(limb["infection"]) > 1.0:
			st.append("infecção %d%%" % int(limb["infection"]))
		if limb["disinfected"]:
			st.append("desinf.")
		if limb["sutured"]:
			st.append("suturado")
		if limb["bandaged"]:
			st.append("enfaixado")
		var sl := _lbl(row, "saudável" if st.is_empty() else ", ".join(st),
			Color(0.6, 0.65, 0.7) if st.is_empty() else Color(1.0, 0.8, 0.5))
		sl.autowrap_mode = TextServer.AUTOWRAP_OFF
		var wounded := int(limb["wound"]) > 0
		_btn(row, "Desinfetar", _act(func() -> void: d.treat(l, "desinfetar")), wounded and d.count("antisseptico") > 0)
		_btn(row, "Suturar", _act(func() -> void: d.treat(l, "suturar")), int(limb["wound"]) == 2 and d.count("kit_sutura") > 0)
		_btn(row, "Enfaixar", _act(func() -> void: d.treat(l, "enfaixar")), wounded and not limb["bandaged"] and d.count("bandagem") > 0)
	_lbl(box, "Dica: feridas profundas só param de sangrar de vez após sutura + bandagem. Feridas abertas deixam esporos entrarem.", Color(0.6, 0.65, 0.7))


func _tab_skills(d: SurvivorData) -> void:
	var box: VBoxContainer = boxes["skills"]
	_clear(box)
	_lbl(box, "As habilidades evoluem praticando (construir, tratar feridos, consertar) ou lendo manuais.")
	for key: String in DB.SKILLS:
		var row := HBoxContainer.new()
		box.add_child(row)
		var l := Label.new()
		l.text = "%s  Nv %d" % [DB.SKILLS[key], d.level(key)]
		l.custom_minimum_size.x = 170
		row.add_child(l)
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(160, 7)
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pb.show_percentage = false
		pb.max_value = d.xp_needed(d.level(key))
		pb.value = float(d.skills[key]["xp"])
		row.add_child(pb)
	_head(box, "— Parede de conhecimento: construções —")
	for k: String in DB.BUILDS:
		var req: Dictionary = DB.BUILDS[k]["req"]
		_lbl(box, "%s: %s" % [DB.BUILDS[k]["nome"], DB.req_text(req)], Color(0.55, 0.9, 0.55) if d.meets(req) else Color(0.7, 0.55, 0.55))
	_head(box, "— Parede de conhecimento: implantes (Medicina + Eletrônica/Cibernética) —")
	for k: String in DB.IMPLANTS:
		var req2: Dictionary = DB.IMPLANTS[k]["req"]
		_lbl(box, "%s: %s" % [DB.item_name(k), DB.req_text(req2)], Color(0.55, 0.9, 0.55) if d.meets(req2) else Color(0.7, 0.55, 0.55))


func _tab_build(p: Player) -> void:
	var box: VBoxContainer = boxes["build"]
	_clear(box)
	var d := p.data
	_lbl(box, "Escolha uma estrutura e clique no mapa. Esc/botão direito cancela. X liga o modo demolição (devolve 50%).")
	for k: String in DB.BUILDS:
		var def: Dictionary = DB.BUILDS[k]
		var row := HBoxContainer.new()
		box.add_child(row)
		var meets := d.meets(def["req"])
		var col := Color.WHITE if meets else Color(0.7, 0.55, 0.55)
		var l := _lbl(row, "%s — %s\nCusto: %s · Exige: %s" % [def["nome"], def["desc"], DB.cost_text(def["custo"]), DB.req_text(def["req"])], col)
		l.custom_minimum_size.x = 440
		_btn(row, "Construir", func() -> void:
			p.build_kind = k
			p.demolish = false
			close_menu(), meets)


func _tab_implants(d: SurvivorData) -> void:
	var box: VBoxContainer = boxes["impl"]
	_clear(box)
	_lbl(box, "Bateria %d%% · Estresse térmico %d%% · Kit cirúrgico x%d · Baterias x%d" % [int(d.battery), int(d.heat), d.count("kit_cirurgico"), d.count("bateria")])
	_btn(box, "Recarregar bateria (+60%)", _act(func() -> void: d.use_item("bateria")), d.count("bateria") > 0)
	_lbl(box, "Implantes mal mantidos, sem bateria ou superaquecidos enfraquecem sua imunidade e aceleram a infecção nas áreas ligadas ao metal.", Color(0.6, 0.65, 0.7))
	for slot: String in DB.IMPLANT_SLOTS:
		_head(box, "— %s —" % DB.IMPLANT_SLOTS[slot])
		if d.implants.has(slot):
			var imp: Dictionary = d.implants[slot]
			var def: Dictionary = DB.IMPLANTS[imp["id"]]
			var state := "ATIVO" if d.implant_active(slot) else "DESLIGADO"
			if d.implant_damaged(slot):
				state += " · DANIFICADO"
			var row := HBoxContainer.new()
			box.add_child(row)
			var l := _lbl(row, "%s · integridade %d%% · %s\n%s" % [DB.item_name(imp["id"]), int(imp["integ"]), state, def["efeito"]],
				Color(0.55, 0.9, 0.55) if d.implant_active(slot) and not d.implant_damaged(slot) else Color(1.0, 0.7, 0.5))
			l.custom_minimum_size.x = 440
			_btn(row, "Manutenção (1 sucata)", _act(func() -> void: d.maintain_implant(slot)), d.count("sucata") > 0)
		else:
			var found := false
			for id: String in DB.IMPLANTS:
				if DB.IMPLANTS[id]["slot"] == slot and d.count(id) > 0:
					found = true
					var def2: Dictionary = DB.IMPLANTS[id]
					var row2 := HBoxContainer.new()
					box.add_child(row2)
					var meets := d.meets(def2["req"])
					var txt := "%s (exige %s)" % [DB.item_name(id), DB.req_text(def2["req"])]
					if not meets:
						txt += "\nRISCO: falha crítica ou morte na cirurgia!"
					var l2 := _lbl(row2, txt, Color.WHITE if meets else Color(1.0, 0.5, 0.5))
					l2.custom_minimum_size.x = 440
					_btn(row2, "Instalar", _act(func() -> void: d.install_implant(id)), d.count("kit_cirurgico") > 0)
			if not found:
				_lbl(box, "Vazio. Encontre um implante e um kit cirúrgico.", Color(0.6, 0.6, 0.6))


func _tab_world(p: Player) -> void:
	var box: VBoxContainer = boxes["mundo"]
	_clear(box)
	var w := Game.world
	var tp := w.tile_pos(p.position)
	_lbl(box, "Seed %d · raio do mundo %d tiles · você está a %d do centro · esporos %.2f" % [w.seed_value, int(World.RADIUS), int(tp.length()), w.spore_at(p.position)])
	_head(box, "— Vilas (simulação em segundo plano) —")
	for v in w.villages:
		var col := Color(1.0, 0.45, 0.45) if v.infested else Color(0.55, 0.9, 0.55) if v.safe else Color.WHITE
		_lbl(box, "%s [%d,%d] — %s · pop %d · comida %d · sucata %d · médico %d · risco %d%%" % [v.nome, v.cell.x, v.cell.y,
			v.status_text(), v.pop, int(v.stock["comida"]), int(v.stock["sucata"]), int(v.stock["medico"]), int(v.infestation)], col)
	_lbl(box, "Caravanas viajam pelas estradas levando recursos. Vilas sem comida acumulam risco e podem ser infestadas; liberte-as matando os infectados.", Color(0.6, 0.65, 0.7))


func _tab_legacy(d: SurvivorData) -> void:
	var box: VBoxContainer = boxes["legado"]
	_clear(box)
	_lbl(box, "Sobrevivente atual: %s — %s" % [d.nome, _fmt_time(d.time_alive)])
	_head(box, "— Legado (sobreviventes anteriores) —")
	if Game.legacy.is_empty():
		_lbl(box, "Ninguém morreu ainda.", Color(0.6, 0.6, 0.6))
	for i in range(Game.legacy.size() - 1, -1, -1):
		var e: Dictionary = Game.legacy[i]
		var fate := "virou infectado de elite" if e["tipo"] == "infeccao" else "corpo no mapa"
		_lbl(box, "%s — %s — %s — %s" % [e["nome"], e["causa"], _fmt_time(float(e["tempo"])), fate])

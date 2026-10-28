class_name HUD
extends CanvasLayer
## Interface do jogo em pixel art ciberpunk: vitais em barras segmentadas, painel de ar,
## atalhos, equipamento e efeitos, registro estilo terminal, aviso de interação e o menu
## "terminal de campo" (inventário, corpo, habilidades, construção, implantes, mundo, legado).
##
## A interface é montada em resolução dupla (UITheme.UI_SCALE): 1 unidade = 1 px da janela
## padrão de 1600x900. A arte de assets/art/ui usa 2x2 px por pixel de desenho, como o mundo.

const VITALS := [
	["pathogen", "contaminacao", "CONTAMINAÇÃO", UITheme.CONTAMINATION, true],
	["blood", "vida", "VIDA", UITheme.LIFE, false],
	["hunger", "fome", "FOME", UITheme.HUNGER, true],
	["thirst", "sede", "SEDE", UITheme.THIRST, false],
]
const TAB_DEFS := [["inv", "Inventário", "mochila"], ["corpo", "Corpo", "corpo"], ["skills", "Habilidades", "chip"],
	["build", "Construção", "martelo"], ["impl", "Implantes", "bateria"], ["mundo", "Mundo", "mundo"],
	["legado", "Legado", "legado"]]
const HINTS := [["WASD", "MOVER"], ["ESPAÇO", "ATACAR"], ["E", "INTERAGIR"], ["TAB", "MENU"],
	["X", "DEMOLIR"], ["F5", "SALVAR"], ["F1", "CONSOLE"]]
const OK_COLOR := Color("#7fe0a0")
const NO_COLOR := Color("#c07a84")
const S := UITheme.FONT_S
const L := UITheme.FONT_L

var root: Control
var ui: Control
var bars := {}
var name_label: Label
var time_label: Label
var fog: ColorRect
var hurt: ColorRect
var vignette: TextureRect
var vitals_panel: PanelContainer
var log_box: VBoxContainer
var filter_bar: PixelBar
var filter_val: Label
var air_label: Label
var air_val: Label
var edge_val: Label
var slots := {}
var effects_box: VBoxContainer
var equip_box: HBoxContainer
var prompt_panel: PanelContainer
var prompt_key: PanelContainer
var prompt_label: Label
var banner: PanelContainer
var banner_label: Label
var death_panel: Control
var death_title: Label
var death_info: Label
var death_fate: Label
var menu_root: Control
var menu_sub: Label
var tabs: TabContainer
var boxes := {}
var msgs: Array = []
var _refresh_t := 0.0
var _menu_data: SurvivorData
var _effects_key := ""
var _log_key := ""
var _t := 0.0
## Recipiente aberto na janela de saque (caixa, baú, saco ou cadáver); null = fechado.
var loot_node: Node2D
var _loot_key := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	Game.log_message.connect(_on_log)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	add_child(root)
	fog = _overlay(Color(0.36, 0.56, 0.32, 0.0))
	hurt = _overlay(Color(0.9, 0.1, 0.1, 0.0))
	root.add_child(ScanOverlay.new())

	ui = Control.new()
	ui.scale = Vector2.ONE / UITheme.UI_SCALE
	ui.theme = UITheme.build_theme()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ui)
	get_viewport().size_changed.connect(_fit)
	_fit()

	_build_screen_fx()
	_build_air_panel()
	_build_hints()
	_build_vitals()
	_build_log()
	_build_equipment()
	_build_prompt()
	_build_banner()
	_build_menu()
	_build_death()


func _fit() -> void:
	ui.size = get_viewport().get_visible_rect().size * UITheme.UI_SCALE


func set_active(on: bool) -> void:
	root.visible = on


func _overlay(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)
	return r


# ------------------------------------------------------------------ peças reutilizáveis
func _label(text: String, size := S, color := UITheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _panel(style := "panel", margin := 16, content := Vector4(20, 14, 20, 14)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.box(style, margin, content))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _keycap(key: String) -> PanelContainer:
	var p := _panel("keycap", 6, Vector4(8, 2, 8, 6))
	var l := _label(key, S, UITheme.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	p.add_child(l)
	return p


func _hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


func _vbox(sep := 4) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _pixel_line(color := UITheme.BORDER, h := 2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _item_icon(item: String, px := 56) -> TextureRect:
	var ic := TextureRect.new()
	ic.texture = GenArt.icon(item)
	ic.custom_minimum_size = Vector2(px, px)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return ic


# ------------------------------------------------------------------ montagem do HUD
func _build_screen_fx() -> void:
	vignette = TextureRect.new()
	vignette.texture = UITheme.tex("vignette")
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(vignette)
	if UITheme.SCANLINES:
		var sl := TextureRect.new()
		sl.texture = UITheme.tex("scanlines")
		sl.set_anchors_preset(Control.PRESET_FULL_RECT)
		sl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sl.stretch_mode = TextureRect.STRETCH_TILE
		sl.modulate.a = 0.55
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(sl)


func _build_air_panel() -> void:
	var p := _panel()
	ui.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	var row := _hbox(14)
	p.add_child(row)
	# filtro da máscara
	row.add_child(UITheme.icon_rect("mascara", UITheme.ACCENT, 40))
	var fcol := _vbox(2)
	row.add_child(fcol)
	var fhead := _hbox(10)
	fcol.add_child(fhead)
	fhead.add_child(_label("FILTRO", S, UITheme.MUTED))
	filter_val = _label("100%", S, UITheme.TEXT)
	fhead.add_child(filter_val)
	filter_bar = PixelBar.new(UITheme.ACCENT, 10, false)
	filter_bar.custom_minimum_size = Vector2(170, 18)
	filter_bar.critical_at = 15.0
	fcol.add_child(filter_bar)
	row.add_child(_vsep())
	# qualidade do ar
	row.add_child(UITheme.icon_rect("esporos", UITheme.CONTAMINATION, 40))
	var acol := _vbox(2)
	row.add_child(acol)
	acol.add_child(_label("AR", S, UITheme.MUTED))
	var aline := _hbox(8)
	acol.add_child(aline)
	air_label = _label("LIMPO", S, OK_COLOR)
	aline.add_child(air_label)
	air_val = _label("0.00", S, UITheme.MUTED)
	aline.add_child(air_val)
	row.add_child(_vsep())
	# distância da borda
	row.add_child(UITheme.icon_rect("mundo", UITheme.MUTED, 40))
	var ecol := _vbox(2)
	row.add_child(ecol)
	ecol.add_child(_label("BORDA", S, UITheme.MUTED))
	edge_val = _label("--", S, UITheme.TEXT)
	ecol.add_child(edge_val)


func _vsep() -> ColorRect:
	var r := ColorRect.new()
	r.color = UITheme.BORDER
	r.custom_minimum_size = Vector2(2, 44)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _build_hints() -> void:
	var back := _panel("card", 8, Vector4(14, 8, 14, 8))
	ui.add_child(back)
	var box := _hbox(16)
	back.add_child(box)
	for h in HINTS:
		var pair := _hbox(6)
		pair.add_child(_keycap(h[0]))
		var l := _label(h[1], S, UITheme.MUTED)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(l)
		box.add_child(pair)
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	back.grow_horizontal = Control.GROW_DIRECTION_BEGIN


func _build_vitals() -> void:
	vitals_panel = _panel()
	vitals_panel.custom_minimum_size = Vector2(600, 0)
	ui.add_child(vitals_panel)
	vitals_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	vitals_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var col := _vbox(8)
	vitals_panel.add_child(col)
	var head := _hbox(10)
	col.add_child(head)
	head.add_child(UITheme.icon_rect("corpo", UITheme.ACCENT, 32))
	name_label = _label("", S, UITheme.ACCENT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(name_label)
	time_label = _label("T+00:00", S, UITheme.MUTED)
	time_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(time_label)
	col.add_child(_pixel_line())
	for def in VITALS:
		var row := _hbox(12)
		col.add_child(row)
		row.add_child(UITheme.icon_rect(def[1], def[3], 32))
		var lbl := _label(def[2], S, UITheme.MUTED)
		lbl.custom_minimum_size.x = 150
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lbl)
		var bar := PixelBar.new(def[3], 16, def[4])
		bar.custom_minimum_size = Vector2(250, 22)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var val := _label("100%", L, UITheme.TEXT)
		val.custom_minimum_size.x = 100
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val)
		bars[def[0]] = [bar, val]


func _build_log() -> void:
	log_box = _vbox(2)
	log_box.custom_minimum_size = Vector2(760, 0)
	ui.add_child(log_box)


func _build_equipment() -> void:
	equip_box = _hbox(10)
	ui.add_child(equip_box)
	for def in [["carga", "CARGA"], ["arma", "ARMA"], ["filtro", "MÁSCARA"], ["bateria", "BATERIA"]]:
		var slot := _panel("slot", 12, Vector4(8, 8, 8, 6))
		slot.custom_minimum_size = Vector2(96, 96)
		equip_box.add_child(slot)
		var v := _vbox(0)
		slot.add_child(v)
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(56, 56)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v.add_child(ic)
		var cap := _label(def[1], S, UITheme.MUTED)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(cap)
		slots[def[0]] = [ic, cap, def[1]]
	equip_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	equip_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	equip_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	effects_box = _vbox(6)
	effects_box.alignment = BoxContainer.ALIGNMENT_END
	ui.add_child(effects_box)


func _build_prompt() -> void:
	prompt_panel = _panel("card", 8, Vector4(14, 8, 18, 10))
	ui.add_child(prompt_panel)
	var row := _hbox(10)
	prompt_panel.add_child(row)
	prompt_key = _keycap("E")
	row.add_child(prompt_key)
	prompt_label = _label("", S, UITheme.TEXT)
	prompt_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(prompt_label)
	prompt_panel.visible = false


func _build_banner() -> void:
	banner = _panel("panel_warn", 16, Vector4(16, 10, 16, 10))
	ui.add_child(banner)
	var row := _hbox(14)
	banner.add_child(row)
	row.add_child(_stripes())
	row.add_child(UITheme.icon_rect("martelo", UITheme.WARN, 32))
	banner_label = _label("", S, UITheme.WARN)
	banner_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(banner_label)
	row.add_child(_stripes())
	banner.visible = false


func _stripes() -> TextureRect:
	var r := TextureRect.new()
	r.texture = UITheme.tex("stripes")
	r.custom_minimum_size = Vector2(64, 20)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_TILE
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


func _build_menu() -> void:
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.visible = false
	ui.add_child(menu_root)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.03, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(center)
	var panel := _panel("panel_solid", 16, Vector4(18, 16, 18, 18))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(1340, 760)
	center.add_child(panel)
	var col := _vbox(12)
	panel.add_child(col)
	var head := PanelContainer.new()
	var hsb := UITheme.box("header", 8, Vector4(16, 6, 56, 8))
	hsb.texture_margin_right = 48
	head.add_theme_stylebox_override("panel", hsb)
	col.add_child(head)
	var hrow := _hbox(14)
	head.add_child(hrow)
	hrow.add_child(UITheme.icon_rect("chip", UITheme.ACCENT, 40))
	hrow.add_child(_label("TERMINAL DE CAMPO", L, UITheme.ACCENT))
	menu_sub = _label("", S, UITheme.MUTED)
	menu_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hrow.add_child(menu_sub)
	var close := _hbox(6)
	close.add_child(_keycap("TAB"))
	var cl := _label("FECHAR", S, UITheme.MUTED)
	cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.add_child(cl)
	hrow.add_child(close)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(tabs)
	for i in TAB_DEFS.size():
		var def: Array = TAB_DEFS[i]
		var sc := ScrollContainer.new()
		sc.name = def[1]
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(sc)
		tabs.set_tab_title(i, String(def[1]).to_upper())
		tabs.set_tab_icon(i, UITheme.icon(def[2]))
		var box := _vbox(8)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.mouse_filter = Control.MOUSE_FILTER_PASS
		sc.add_child(box)
		boxes[def[0]] = box
	tabs.tab_changed.connect(func(_i: int) -> void: _rebuild())


func _build_death() -> void:
	death_panel = Control.new()
	death_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_panel.visible = false
	ui.add_child(death_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.0, 0.01, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_panel.add_child(center)
	var p := _panel("panel_alert", 16, Vector4(48, 32, 48, 36))
	p.custom_minimum_size = Vector2(980, 0)
	center.add_child(p)
	var col := _vbox(14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(col)
	var sk := UITheme.icon_rect("caveira", UITheme.DANGER, 96)
	sk.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(sk)
	death_title = _label("SINAL VITAL PERDIDO", UITheme.FONT_XL, UITheme.DANGER)
	death_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(death_title)
	col.add_child(_pixel_line(Color("#6b2a3a")))
	death_info = _label("", L, UITheme.TEXT)
	death_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(death_info)
	death_fate = _label("", S, UITheme.MUTED)
	death_fate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_fate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	death_fate.custom_minimum_size.x = 860
	col.add_child(death_fate)


## info: {nome, causa, tipo ("infeccao" ou "fisica"), tempo}
func show_death(info: Dictionary) -> void:
	close_menu()
	var fate := "Seu corpo se reergue como um infectado de elite, com tudo o que você carregava."
	if str(info.get("tipo", "")) != "infeccao":
		fate = "Seu corpo ficou no mapa. Um novo sobrevivente pode recuperá-lo antes que se decomponha."
	death_info.text = "%s\n%s · sobreviveu %s" % [str(info.get("nome", "")).to_upper(), str(info.get("causa", "")),
		_fmt_time(float(info.get("tempo", 0.0)))]
	death_fate.text = fate + "\n\nUm novo sobrevivente chega ao abrigo..."
	death_panel.visible = true


func hide_death() -> void:
	death_panel.visible = false


func _fmt_time(sec: float) -> String:
	return "%d:%02d" % [int(sec) / 60, int(sec) % 60]


func _on_log(text: String) -> void:
	msgs.append({"t": Time.get_ticks_msec() / 1000.0, "text": text})
	while msgs.size() > 7:
		msgs.pop_front()


func _player() -> Player:
	return Game.world.local_player() if Game.world != null else null


# ------------------------------------------------------------------ menu
## Abre a janela de saque de um recipiente (aba Inventário em duas colunas).
func open_loot(node: Node2D) -> void:
	open_menu(0)
	if menu_root.visible:
		loot_node = node
		_loot_key = ""
		_rebuild()


func open_menu(tab: int = -1) -> void:
	var p := _player()
	if p == null or p.data == null or p.is_dead():
		return
	if Game.console != null and Game.console.is_open():
		return
	if tab >= 0:
		tabs.current_tab = tab
	menu_root.visible = true
	# no co-op o mundo continua rodando com o menu aberto; só o jogo solo pausa
	get_tree().paused = Net.is_solo()
	_rebuild()


func close_menu() -> void:
	loot_node = null
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
	_t += delta
	var d := p.data
	_update_log()
	name_label.text = d.nome.to_upper()
	time_label.text = "T+" + _fmt_time(d.time_alive)
	_set_bar("pathogen", d.pathogen)
	_set_bar("blood", d.blood)
	_set_bar("hunger", 100.0 - d.calories / SurvivorData.MAX_CAL * 100.0)
	_set_bar("thirst", d.water)

	# ar e filtro
	var spore := Game.world.spore_at(p.position)
	var mask_on := d.has_mask()
	filter_bar.value = d.filter_pct() if mask_on else 0.0
	filter_val.text = ("%d%%" % int(d.filter_pct())) if mask_on else "SEM MÁSCARA"
	filter_val.add_theme_color_override("font_color", UITheme.TEXT if mask_on and d.filter_pct() > 15.0 else UITheme.DANGER)
	var q := ["LIMPO", OK_COLOR]
	if spore >= 1.0:
		q = ["LETAL", UITheme.DANGER]
	elif spore > 0.5:
		q = ["DENSO", UITheme.WARN]
	elif spore > 0.15:
		q = ["CONTAMINADO", UITheme.CONTAMINATION]
	air_label.text = q[0]
	air_label.add_theme_color_override("font_color", q[1])
	air_val.text = "%.2f" % spore
	var edge_tiles := World.RADIUS - Game.world.tile_pos(p.position).length()
	edge_val.text = "%d TILES" % int(edge_tiles)
	edge_val.add_theme_color_override("font_color", UITheme.DANGER if edge_tiles < 12.0 else UITheme.TEXT)

	_update_equipment(d)
	_update_effects(d, spore)

	# efeitos de tela
	fog.color.a = clampf((spore - 0.12) * 0.36, 0.0, 0.3)
	hurt.color.a = clampf(p.hurt_flash * 1.2, 0.0, 0.22)
	if d.pathogen > 40.0:
		hurt.color = Color(0.25, 0.5, 0.15, clampf((d.pathogen - 40.0) / 60.0 * 0.2, 0.0, 0.2))
	else:
		hurt.color = Color(0.9, 0.1, 0.1, hurt.color.a)
	var low := d.blood < 30.0 or float(d.limbs["torso"]["hp"]) < 25.0
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	vignette.self_modulate = Color(1.0, 0.25, 0.3).lerp(Color.WHITE, pulse * 0.5) if low else Color.WHITE

	# aviso de interação
	if p.nearby != null and is_instance_valid(p.nearby) and not menu_root.visible and p.build_kind == "":
		var txt: String = p.nearby.prompt()
		prompt_panel.visible = txt != ""
		prompt_key.visible = txt.begins_with("[E]")
		prompt_label.text = txt.trim_prefix("[E] ").to_upper()
	else:
		prompt_panel.visible = false
	if prompt_panel.visible:
		prompt_panel.reset_size()
		prompt_panel.position = Vector2((ui.size.x - prompt_panel.size.x) / 2.0, ui.size.y - prompt_panel.size.y - 180.0).round()

	# faixa de construção / demolição
	banner.visible = p.build_kind != "" or p.demolish
	if p.build_kind != "":
		banner_label.text = "MODO CONSTRUÇÃO · %s · CLIQUE PARA POSICIONAR · ESC CANCELA" % String(DB.BUILDS[p.build_kind]["nome"]).to_upper()
	elif p.demolish:
		banner_label.text = "MODO DEMOLIÇÃO · CLIQUE NA ESTRUTURA · X PARA SAIR"
	if banner.visible:
		banner.reset_size()
		banner.position = Vector2((ui.size.x - banner.size.x) / 2.0, 120.0).round()

	# posições que dependem do tamanho de outros blocos
	log_box.position = Vector2(16, vitals_panel.position.y - log_box.size.y - 12)
	effects_box.position = Vector2(ui.size.x - effects_box.size.x - 16, equip_box.position.y - effects_box.size.y - 10)

	if loot_node != null and (not is_instance_valid(loot_node) or loot_node.is_queued_for_deletion()
			or Vector2(loot_node.position.x - p.position.x, (loot_node.position.y - p.position.y) * 2.0).length() > 130.0):
		loot_node = null
		_rebuild()
	if menu_root.visible and loot_node != null:
		var lk := str(loot_node.items.hash())
		if lk != _loot_key:
			_loot_key = lk
			_rebuild()
	if menu_root.visible and d != _menu_data:
		_menu_data = d
		_rebuild()
	if menu_root.visible:
		menu_sub.text = "// %s · T+%s" % [d.nome.to_upper(), _fmt_time(d.time_alive)]
		_refresh_t -= delta
		if _refresh_t <= 0.0 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_refresh_t = 1.0
			_rebuild()


func _set_bar(key: String, value: float) -> void:
	var pair: Array = bars[key]
	var bar: PixelBar = pair[0]
	var lbl: Label = pair[1]
	var amount := clampf(value, 0.0, 100.0)
	bar.value = amount
	lbl.text = "%d%%" % int(amount)
	lbl.add_theme_color_override("font_color", UITheme.DANGER if bar.is_critical() else UITheme.TEXT)


func _update_log() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var live: Array = []
	for m in msgs:
		if now - float(m["t"]) < 14.0:
			live.append(m)
	var key := ""
	for m in live:
		key += str(m["t"]) + "|"
	if key != _log_key:
		_log_key = key
		for c in log_box.get_children():
			log_box.remove_child(c)
			c.queue_free()
		for i in live.size():
			var newest := i == live.size() - 1
			var l := _label("› " + String(live[i]["text"]), S, UITheme.TEXT if newest else UITheme.MUTED)
			l.set_meta("t", live[i]["t"])
			log_box.add_child(l)
		log_box.reset_size()
	for c in log_box.get_children():
		var age := now - float(c.get_meta("t"))
		c.modulate.a = clampf((14.0 - age) / 3.0, 0.0, 1.0)


func _update_equipment(d: SurvivorData) -> void:
	var carga: Array = slots["carga"]
	var pack: Dictionary = d.equip["mochila"]
	(carga[0] as TextureRect).texture = GenArt.icon(pack["id"] if not pack.is_empty() else "mochila_escolar")
	(carga[0] as TextureRect).self_modulate = Color.WHITE if not pack.is_empty() else Color(1, 1, 1, 0.3)
	(carga[1] as Label).text = "%.1f KG" % d.carried_weight()
	(carga[1] as Label).add_theme_color_override("font_color", UITheme.DANGER if d.load_ratio() > 1.0 else UITheme.MUTED)
	var arma: Array = slots["arma"]
	var w := d.weapon_inst()
	(arma[0] as TextureRect).texture = GenArt.icon(w["id"]) if not w.is_empty() else UITheme.icon("arma")
	(arma[0] as TextureRect).self_modulate = Color.WHITE if not w.is_empty() else Color(1, 1, 1, 0.18)
	(arma[1] as Label).text = "ARMA" if w.is_empty() else "%d%%" % int(float(w.get("dur", 100.0)))
	(arma[1] as Label).add_theme_color_override("font_color",
		UITheme.DANGER if not w.is_empty() and float(w.get("dur", 100.0)) < 25.0 else UITheme.MUTED)
	var mask: Array = slots["filtro"]
	(mask[0] as TextureRect).texture = GenArt.icon("mascara")
	(mask[0] as TextureRect).self_modulate = Color.WHITE if d.has_mask() else Color(1, 1, 1, 0.18)
	(mask[1] as Label).text = ("VED. %d%%" % int(d.mask_seal())) if d.has_mask() else "SEM MÁSCARA"
	(mask[1] as Label).add_theme_color_override("font_color",
		UITheme.DANGER if d.has_mask() and d.mask_seal() < 30.0 else UITheme.MUTED)
	var bat: Array = slots["bateria"]
	(bat[0] as TextureRect).texture = GenArt.icon("bateria")
	var has_impl := not d.implants.is_empty()
	(bat[0] as TextureRect).self_modulate = Color.WHITE if has_impl else Color(1, 1, 1, 0.18)
	(bat[1] as Label).text = ("%d%%" % int(d.battery)) if has_impl else "SEM IMPL."
	(bat[1] as Label).add_theme_color_override("font_color", UITheme.DANGER if has_impl and d.battery < 15.0 else UITheme.MUTED)


func _update_effects(d: SurvivorData, spore: float) -> void:
	var list: Array = []
	if spore >= 1.0:
		list.append(["alerta", "ESPOROS LETAIS", UITheme.DANGER])
	if d.has_mask() and d.filter_pct() <= 0.0:
		list.append(["filtro", "FILTRO ESGOTADO", UITheme.DANGER])
	if d.load_ratio() > 1.0:
		list.append(["mochila", "SOBRECARGA", UITheme.WARN])
	if d.pathogen > 75.0:
		list.append(["contaminacao", "CARGA CRÍTICA", UITheme.DANGER])
	var bleeding := false
	var infected := false
	for l in SurvivorData.LIMBS:
		var limb: Dictionary = d.limbs[l]
		if int(limb["wound"]) > 0 and float(limb["bleed"]) > 0.0 and not (limb["bandaged"] and int(limb["wound"]) == 1):
			bleeding = true
		if float(limb["infection"]) >= 50.0:
			infected = true
	if bleeding:
		list.append(["sangue", "SANGRANDO", UITheme.LIFE])
	if infected:
		list.append(["alerta", "INFECÇÃO EM FERIDA", UITheme.WARN])
	if d.heat > 70.0:
		list.append(["calor", "SUPERAQUECIMENTO", UITheme.WARN])
	if d.suppress_t > 0.0:
		list.append(["supressor", "SUPRESSOR %ds" % int(d.suppress_t), UITheme.CONTAMINATION])
	if d.antibiotic_t > 0.0:
		list.append(["antibiotico", "ANTIBIÓTICO %ds" % int(d.antibiotic_t), OK_COLOR])
	var key := str(list)
	if key == _effects_key:
		return
	_effects_key = key
	for c in effects_box.get_children():
		effects_box.remove_child(c)
		c.queue_free()
	for e in list:
		var chip := _panel("card", 8, Vector4(10, 6, 14, 8))
		chip.size_flags_horizontal = Control.SIZE_SHRINK_END
		var row := _hbox(8)
		chip.add_child(row)
		row.add_child(UITheme.icon_rect(e[0], e[2], 28))
		var l := _label(e[1], S, e[2])
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		effects_box.add_child(chip)
	effects_box.reset_size()


# ------------------------------------------------------------------ helpers do menu
func _clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _lbl(parent: Control, text: String, col: Color = UITheme.TEXT) -> Label:
	var l := _label(text, S, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(l)
	return l


func _btn(parent: Control, text: String, cb: Callable, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.disabled = not enabled
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## Cabeçalho de seção: marcador, título em destaque e linha até o fim.
func _head(parent: Control, text: String) -> void:
	var row := _hbox(10)
	row.add_theme_constant_override("separation", 10)
	var mark := ColorRect.new()
	mark.color = UITheme.MAGENTA
	mark.custom_minimum_size = Vector2(8, 8)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	row.add_child(_label(text.replace("—", "").strip_edges().to_upper(), S, UITheme.ACCENT))
	var line := _pixel_line(UITheme.BORDER)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	parent.add_child(row)


## Linha em cartão (fundo de painel discreto) para listas do menu.
func _row(parent: Control) -> HBoxContainer:
	var card := _panel("card", 8, Vector4(12, 6, 12, 6))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(card)
	var row := _hbox(14)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(row)
	return row


func _bar(parent: Control, value: float, max_value: float, color: Color, width := 200, segs := 12) -> PixelBar:
	var b := PixelBar.new(color, segs, false)
	b.critical_at = -1.0
	b.custom_minimum_size = Vector2(width, 18)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.value = 0.0 if max_value <= 0.0 else value / max_value * 100.0
	parent.add_child(b)
	return b


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
	# carga total
	var top := _row(box)
	top.add_child(UITheme.icon_rect("mochila", UITheme.ACCENT, 36))
	var ratio := d.load_ratio()
	var wl := _label("CARGA %.1f / %.0f KG" % [d.carried_weight(), d.carry_max()], S, UITheme.DANGER if ratio > 1.0 else UITheme.TEXT)
	wl.custom_minimum_size.x = 300
	wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(wl)
	_bar(top, minf(ratio, 1.5), 1.5, UITheme.DANGER if ratio > 1.0 else UITheme.ACCENT, 260, 15)
	_lbl(top, ("SOBRECARGA: você anda mais devagar." if ratio > 1.0 else "Acima de %.0f kg você fica lento." % d.carry_max()),
		UITheme.WARN if ratio > 1.0 else UITheme.MUTED)
	if loot_node != null and is_instance_valid(loot_node):
		var cols := _hbox(16)
		cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(cols)
		var left := _vbox(6)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.size_flags_stretch_ratio = 1.0
		cols.add_child(left)
		var right := _vbox(6)
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(right)
		_loot_column(left, d)
		_inventory_lists(right, d, true)
		return
	_inventory_lists(box, d, false)
	_head(box, "Fabricação")
	for rid: String in DB.CRAFTS:
		var cdef: Dictionary = DB.CRAFTS[rid]
		var crow := _row(box)
		crow.add_child(_item_icon(rid, 48))
		var ok := d.meets(cdef["req"]) and d.can_afford(cdef["custo"])
		_lbl(crow, "%s: %s · exige %s" % [cdef["nome"], DB.cost_text(cdef["custo"]), DB.req_text(cdef["req"])],
			UITheme.TEXT if ok else NO_COLOR)
		_btn(crow, "Fabricar", _act(func() -> void: _player().act("craft", [rid])), d.meets(cdef["req"]))


## Cor do texto de estado de um item (estragado/quebrando em vermelho, passado em amarelo).
func _state_color(inst: Dictionary) -> Color:
	if Items.spoiled(inst) or float(inst.get("dur", 100.0)) < 20.0:
		return UITheme.DANGER
	if Items.fresh_label(inst) == "Passado" or float(inst.get("dur", 100.0)) < 50.0:
		return UITheme.WARN
	return UITheme.MUTED


## Ícone + nome + estado + peso, numa linha compacta.
func _item_line(row: HBoxContainer, inst: Dictionary, extra := "") -> void:
	row.add_child(_item_icon(inst["id"], 40))
	var col := _vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	col.add_child(_label(Items.label(inst) + extra, S, UITheme.TEXT))
	var st := Items.state_text(inst)
	var info := "%.1f kg · %.1f L" % [Items.weight(inst), Items.volume(inst)]
	col.add_child(_label(info + ("  ·  " + st if st != "" else ""), S, _state_color(inst)))


func _verb_for(d: SurvivorData, inst: Dictionary) -> String:
	var u := int(inst.get("u", 0))
	match String(Items.def(inst["id"])["tipo"]):
		"comida": return "Comer"
		"bebida": return "Beber"
		"mascara", "mochila", "coldre": return "Vestir"
		"filtro": return "Trocar filtro" if d.has_mask() else ""
		"supressor": return "Aplicar"
		"bateria": return "Recarregar"
		"manual": return "Ler"
		"arma": return "Guardar" if d.hand_u == u else "Empunhar"
	return ""


func _inventory_lists(box: VBoxContainer, d: SurvivorData, looting: bool) -> void:
	_head(box, "Vestindo")
	var worn := false
	for slot in SurvivorData.EQUIP_SLOTS:
		var inst: Dictionary = d.equip[slot]
		if inst.is_empty():
			continue
		worn = true
		var row := _row(box)
		var extra := ""
		if slot != "mascara":
			extra = "  (%.0f L)" % d.capacity(slot)
		_item_line(row, inst, extra)
		if inst.has("dur") and float(inst["dur"]) < 100.0 and not looting:
			var u0 := int(inst["u"])
			_btn(row, "Consertar", _act(func() -> void: _player().act("repair", [u0])), d.count("fita") > 0)
		var sl: String = slot
		_btn(row, "Tirar", _act(func() -> void: _player().act("unwear", [sl])))
	if not worn:
		_lbl(box, "Nada vestido.", UITheme.MUTED)
	for c in ["coldre", "mochila", "bolsos"]:
		var cap := d.capacity(c)
		if cap <= 0.0 and d.bags[c].is_empty():
			continue
		var used := d.used_volume(c)
		_head(box, "%s  %.1f / %.0f L" % [SurvivorData.CONT_NAMES[c], used, cap])
		if d.bags[c].is_empty():
			_lbl(box, "Vazio.", UITheme.MUTED)
		for inst: Dictionary in d.bags[c]:
			var u := int(inst["u"])
			var n := int(inst["n"])
			var row := _row(box)
			_item_line(row, inst, "  · NA MÃO" if d.hand_u == u else "")
			if looting:
				var key := Game.world.key_of(loot_node)
				_btn(row, "Guardar", _act(func() -> void: _player().act("store", [key, u, n])))
				continue
			var verb := _verb_for(d, inst)
			if verb != "":
				_btn(row, verb, _act(func() -> void: _player().act("use_item", [u])))
			if inst.has("dur") and float(inst["dur"]) < 100.0:
				_btn(row, "Consertar", _act(func() -> void: _player().act("repair", [u])), d.count("fita") > 0)
			for dest in ["mochila", "bolsos", "coldre"]:
				if dest != c and d.fits(dest, inst) >= n:
					var dn: String = dest
					_btn(row, "→ " + SurvivorData.CONT_NAMES[dest], _act(func() -> void: _player().act("move", [u, dn])))
					break
			_btn(row, "Largar", _act(func() -> void: _player().act("drop", [u, n])))


func _loot_column(box: VBoxContainer, _d: SurvivorData) -> void:
	var node := loot_node
	var key := Game.world.key_of(node)
	var items: Array = node.items
	_head(box, String(node.title()))
	var bar := _row(box)
	_lbl(bar, "%d itens · %.1f kg" % [Items.total_units(items), Items.list_weight(items)], UITheme.MUTED)
	_btn(bar, "Pegar tudo", _act(func() -> void: _player().act("take_all", [key])), not items.is_empty())
	if items.is_empty():
		_lbl(box, "Vazio.", UITheme.MUTED)
	for i in items.size():
		var inst: Dictionary = items[i]
		var row := _row(box)
		_item_line(row, inst)
		var idx := i
		var n := int(inst["n"])
		var id: String = inst["id"]
		if String(Items.def(id)["tipo"]) in SurvivorData.EQUIP_SLOTS:
			_btn(row, "Vestir", _act(func() -> void: _player().act("take", [key, idx, 1, "vestir", id])))
		_btn(row, "Pegar", _act(func() -> void: _player().act("take", [key, idx, n, "", id])))


func _tab_body(d: SurvivorData) -> void:
	var box: VBoxContainer = boxes["corpo"]
	_clear(box)
	_lbl(box, "Carga patogênica %d%% · Sangue %d%% · Água %d%%" % [int(d.pathogen), int(d.blood), int(d.water)], UITheme.MUTED)
	var top := _row(box)
	top.add_child(_item_icon("antibiotico", 48))
	_btn(top, "Antibiótico (x%d)" % d.count("antibiotico"), _act(func() -> void: _player().act("treat", ["torso", "antibiotico"])), d.count("antibiotico") > 0)
	_lbl(top, "Ativo por %ds" % int(d.antibiotic_t) if d.antibiotic_t > 0.0 else "Cura sepse e infecção fúngica.", UITheme.MUTED)
	_head(box, "Membros")
	for l: String in SurvivorData.LIMBS:
		var limb: Dictionary = d.limbs[l]
		var row := _row(box)
		var name_l := _label(SurvivorData.LIMB_NAMES[l], S, UITheme.TEXT)
		name_l.custom_minimum_size.x = 130
		name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name_l)
		var hp := float(limb["hp"])
		var hcol := OK_COLOR if hp > 50.0 else UITheme.WARN if hp > 20.0 else UITheme.DANGER
		_bar(row, hp, 100.0, hcol, 150, 10)
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
		_lbl(row, "saudável" if st.is_empty() else ", ".join(st), UITheme.MUTED if st.is_empty() else UITheme.WARN)
		var wounded := int(limb["wound"]) > 0
		_btn(row, "Desinfetar", _act(func() -> void: _player().act("treat", [l, "desinfetar"])), wounded and d.count("antisseptico") > 0)
		_btn(row, "Suturar", _act(func() -> void: _player().act("treat", [l, "suturar"])), int(limb["wound"]) == 2 and d.count("kit_sutura") > 0)
		_btn(row, "Enfaixar", _act(func() -> void: _player().act("treat", [l, "enfaixar"])), wounded and not limb["bandaged"] and d.count("bandagem") > 0)
	_lbl(box, "Dica: feridas profundas só param de sangrar de vez após sutura + bandagem. Feridas abertas deixam esporos entrarem.", UITheme.MUTED)


func _tab_skills(d: SurvivorData) -> void:
	var box: VBoxContainer = boxes["skills"]
	_clear(box)
	_lbl(box, "As habilidades evoluem praticando (construir, tratar feridos, consertar) ou lendo manuais.", UITheme.MUTED)
	for key: String in DB.SKILLS:
		var row := _row(box)
		var l := _label(DB.SKILLS[key], S, UITheme.TEXT)
		l.custom_minimum_size.x = 300
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		var lv := _label("NV %d" % d.level(key), L, UITheme.ACCENT)
		lv.custom_minimum_size.x = 110
		row.add_child(lv)
		_bar(row, float(d.skills[key]["xp"]), d.xp_needed(d.level(key)), UITheme.MAGENTA, 360, 20)
	_head(box, "Parede de conhecimento: construções")
	for k: String in DB.BUILDS:
		var req: Dictionary = DB.BUILDS[k]["req"]
		_lbl(box, "%s: %s" % [DB.BUILDS[k]["nome"], DB.req_text(req)], OK_COLOR if d.meets(req) else NO_COLOR)
	_head(box, "Parede de conhecimento: implantes (Medicina + Eletrônica/Cibernética)")
	for k: String in DB.IMPLANTS:
		var req2: Dictionary = DB.IMPLANTS[k]["req"]
		_lbl(box, "%s: %s" % [DB.item_name(k), DB.req_text(req2)], OK_COLOR if d.meets(req2) else NO_COLOR)


func _tab_build(p: Player) -> void:
	var box: VBoxContainer = boxes["build"]
	_clear(box)
	var d := p.data
	_lbl(box, "Escolha uma estrutura e clique no mapa. Esc/botão direito cancela. X liga o modo demolição (devolve 50%).", UITheme.MUTED)
	for k: String in DB.BUILDS:
		var def: Dictionary = DB.BUILDS[k]
		var row := _row(box)
		var meets := d.meets(def["req"])
		row.add_child(UITheme.icon_rect("martelo", UITheme.WARN if meets else NO_COLOR, 40))
		_lbl(row, "%s — %s\nCusto: %s · Exige: %s" % [def["nome"], def["desc"], DB.cost_text(def["custo"]), DB.req_text(def["req"])],
			UITheme.TEXT if meets else NO_COLOR)
		_btn(row, "Construir", func() -> void:
			p.build_kind = k
			p.demolish = false
			close_menu(), meets)


func _tab_implants(d: SurvivorData) -> void:
	var box: VBoxContainer = boxes["impl"]
	_clear(box)
	var top := _row(box)
	top.add_child(_item_icon("bateria", 48))
	var info := _vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	info.add_child(_label("BATERIA %d%% · ESTRESSE TÉRMICO %d%% · KIT CIRÚRGICO x%d · BATERIAS x%d" % [int(d.battery), int(d.heat), d.count("kit_cirurgico"), d.count("bateria")], S, UITheme.TEXT))
	var bars_row := _hbox(14)
	info.add_child(bars_row)
	_bar(bars_row, d.battery, 100.0, UITheme.ACCENT, 260, 14)
	_bar(bars_row, d.heat, 100.0, UITheme.WARN, 260, 14)
	_btn(top, "Recarregar (+60%)", _act(func() -> void: _player().act("use_item", ["bateria"])), d.count("bateria") > 0)
	_lbl(box, "Implantes mal mantidos, sem bateria ou superaquecidos enfraquecem sua imunidade e aceleram a infecção nas áreas ligadas ao metal.", UITheme.MUTED)
	for slot: String in DB.IMPLANT_SLOTS:
		_head(box, DB.IMPLANT_SLOTS[slot])
		if d.implants.has(slot):
			var imp: Dictionary = d.implants[slot]
			var def: Dictionary = DB.IMPLANTS[imp["id"]]
			var state := "ATIVO" if d.implant_active(slot) else "DESLIGADO"
			if d.implant_damaged(slot):
				state += " · DANIFICADO"
			var row := _row(box)
			row.add_child(_item_icon(imp["id"], 48))
			_lbl(row, "%s · integridade %d%% · %s\n%s" % [DB.item_name(imp["id"]), int(imp["integ"]), state, def["efeito"]],
				OK_COLOR if d.implant_active(slot) and not d.implant_damaged(slot) else UITheme.WARN)
			_btn(row, "Manutenção (1 sucata)", _act(func() -> void: _player().act("maintain", [slot])), d.count("sucata") > 0)
		else:
			var found := false
			for id: String in DB.IMPLANTS:
				if DB.IMPLANTS[id]["slot"] == slot and d.count(id) > 0:
					found = true
					var def2: Dictionary = DB.IMPLANTS[id]
					var row2 := _row(box)
					row2.add_child(_item_icon(id, 48))
					var meets := d.meets(def2["req"])
					var txt := "%s (exige %s)" % [DB.item_name(id), DB.req_text(def2["req"])]
					if not meets:
						txt += "\nRISCO: falha crítica ou morte na cirurgia!"
					_lbl(row2, txt, UITheme.TEXT if meets else UITheme.DANGER)
					_btn(row2, "Instalar", _act(func() -> void: _player().act("install", [id])), d.count("kit_cirurgico") > 0)
			if not found:
				_lbl(box, "Vazio. Encontre um implante e um kit cirúrgico.", UITheme.MUTED)


func _tab_world(p: Player) -> void:
	var box: VBoxContainer = boxes["mundo"]
	_clear(box)
	var w := Game.world
	var tp := w.tile_pos(p.position)
	_lbl(box, "Seed %d · raio do mundo %d tiles · você está a %d do centro · esporos %.2f" % [w.seed_value, int(World.RADIUS), int(tp.length()), w.spore_at(p.position)], UITheme.MUTED)
	_head(box, "Vilas (simulação em segundo plano)")
	for v in w.villages:
		var col := UITheme.DANGER if v.infested else OK_COLOR if v.safe else UITheme.TEXT
		var row := _row(box)
		row.add_child(UITheme.icon_rect("caveira" if v.infested else "mundo", col, 32))
		_lbl(row, "%s [%d,%d] — %s · pop %d · comida %d · sucata %d · médico %d · risco %d%%" % [v.nome, v.cell.x, v.cell.y,
			v.status_text(), v.pop, int(v.stock["comida"]), int(v.stock["sucata"]), int(v.stock["medico"]), int(v.infestation)], col)
	_lbl(box, "Caravanas viajam pelas estradas levando recursos. Vilas sem comida acumulam risco e podem ser infestadas; liberte-as matando os infectados.", UITheme.MUTED)


func _tab_legacy(d: SurvivorData) -> void:
	var box: VBoxContainer = boxes["legado"]
	_clear(box)
	_lbl(box, "Sobrevivente atual: %s — %s" % [d.nome, _fmt_time(d.time_alive)], UITheme.TEXT)
	_head(box, "Legado (sobreviventes anteriores)")
	if Game.legacy.is_empty():
		_lbl(box, "Ninguém morreu ainda.", UITheme.MUTED)
	for i in range(Game.legacy.size() - 1, -1, -1):
		var e: Dictionary = Game.legacy[i]
		var infected: bool = e["tipo"] == "infeccao"
		var fate := "virou infectado de elite" if infected else "corpo no mapa"
		var row := _row(box)
		row.add_child(UITheme.icon_rect("caveira" if infected else "legado", UITheme.MAGENTA if infected else UITheme.MUTED, 32))
		_lbl(row, "%s — %s — %s — %s" % [e["nome"], e["causa"], _fmt_time(float(e["tempo"])), fate], UITheme.TEXT)

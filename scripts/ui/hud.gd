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
	["stamina", "estamina", "ESTAMINA", Color("#e6d26a"), false],
]
const TAB_DEFS := [["inv", "Inventário", "mochila"], ["corpo", "Corpo", "corpo"], ["skills", "Habilidades", "chip"],
	["impl", "Implantes", "bateria"], ["mapa", "Mapa", "mundo"]]
const TAB_INV := 0
const TAB_MAP := 4
const HINTS := [["SHIFT", "CORRER"], ["C", "AGACHAR"], ["R", "RECARREGAR"], ["E", "INTERAGIR"],
	["TAB", "MENU"], ["I", "INVENTÁRIO"], ["M", "MAPA"], ["B", "CONSTRUIR"]]
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
var clock_val: Label
var weather_val: Label
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
## Tela de criação de personagem (fase 3).
var creation_root: Control
var creation_box: VBoxContainer
var spec := {}
var _creation_sent := false
## Medicina cooperativa: paciente escolhido na aba Corpo (0 = você) e dados recebidos.
var patient_peer := 0
## Membro escolhido na aba Corpo; body_auto = segue o mais grave até o jogador clicar.
var body_sel := "torso"
var body_auto := true
var patient_info := {}
## Vila aberta pela conversa com um NPC (-1 = a mais próxima).
var village_open := -1
## Janela separada do menu principal: "build", "village" ou "vehicle" ("" = fechada).
var window_kind := ""
var window_root: Control
var window_title: Label
var window_box: VBoxContainer
var _window_t := 0.0
## Menu de contexto da grade de itens (botão direito).
var ctx_root: Control
var ctx_box: VBoxContainer
## Mapa: chunks descobertos por este jogador (Vector2i -> true), salvo em user://.
var map_known := {}
var map_view: MapView
var map_info: VBoxContainer
var _map_dirty := false
var _map_t := 0.0
var _map_save_t := 10.0
var _map_file := ""
## Botão na tela para o status do veículo (aparece dentro de um veículo).
var veh_button: Button
var air_panel: PanelContainer
## Barra rápida (5 espaços na direita).
var hotbar_root: VBoxContainer
var hot_slots: Array[HotSlot] = []
## Espaço escolhido na barra rápida (-1 = nenhum). A tecla escolhe; o clique usa.
var hot_sel := -1
## Modo construção: faixa embaixo com as abas, moldura na tela e HUD normal escondida.
var build_mode := false
var build_bar: PanelContainer
var build_tabs_row: HBoxContainer
var build_items: HBoxContainer
var build_info: Label
var build_frame: Control
var _build_t := 0.0
var _build_key := ""
var busy_panel: PanelContainer
var busy_text: Label
var busy_bar: PixelBar


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
	_build_vitals()
	_build_log()
	_build_equipment()
	_build_hotbar()
	_build_build_bar()
	_build_prompt()
	_build_banner()
	_build_busy()
	_build_menu()
	_build_window()
	_build_ctx()
	_build_vehicle_button()
	_build_death()
	_build_creation()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _map_dirty:
		save_map()


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
	air_panel = p
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
	row.add_child(_vsep())
	# hora e clima
	var ccol := _vbox(2)
	row.add_child(ccol)
	clock_val = _label("08:00", S, UITheme.TEXT)
	ccol.add_child(clock_val)
	weather_val = _label("CÉU LIMPO", S, UITheme.MUTED)
	ccol.add_child(weather_val)


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
	vitals_panel.custom_minimum_size = Vector2(380, 0)
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
		var ic := UITheme.icon_rect(def[1], def[3], 32)
		ic.tooltip_text = String(def[2]).capitalize()
		ic.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(ic)
		var bar := PixelBar.new(def[3], 16, def[4])
		bar.custom_minimum_size = Vector2(300, 22)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		# só ícone e barra (o valor fica num rótulo fora da tela, usado pelos testes)
		var val := _label("100%", L, UITheme.TEXT)
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


## Barra da ação com tempo em andamento (centro da tela, acima do aviso de interação).
func _build_busy() -> void:
	busy_panel = _panel("card", 8, Vector4(16, 10, 16, 10))
	busy_panel.visible = false
	ui.add_child(busy_panel)
	var col := _vbox(6)
	busy_panel.add_child(col)
	busy_text = _label("", S, UITheme.ACCENT)
	busy_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(busy_text)
	busy_bar = PixelBar.new(UITheme.ACCENT, 20, false)
	busy_bar.critical_at = -1.0
	busy_bar.custom_minimum_size = Vector2(380, 18)
	col.add_child(busy_bar)
	var hint := _label("MOVA-SE PARA CANCELAR", S, UITheme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)


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
	if build_mode:
		set_build_mode(false)
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
## Veículo perto (ou o veículo em que você está): janela de status e ações.
var vehicle_node: Vehicle


func open_vehicle(v: Vehicle) -> void:
	vehicle_node = v
	open_window("vehicle")


## Estação (bancada, fogareiro, fornalha, mesa de reparos): janela de fabricação ou consertos.
var station_node: Structure


func open_station(st: Structure) -> void:
	station_node = st
	open_window("station")


## Conversa com um NPC: janela da vila.
func open_village(vid: int) -> void:
	village_open = vid
	open_window("village")


## O menu principal, uma janela separada, o menu de contexto ou a criação de personagem
## estão abertos (o personagem não anda).
func blocks_input() -> bool:
	return menu_root.visible or window_kind != "" or creation_root.visible


# ------------------------------------------------------------------ janela separada
func _build_window() -> void:
	window_root = Control.new()
	window_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	window_root.visible = false
	ui.add_child(window_root)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.03, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	window_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	window_root.add_child(center)
	var panel := _panel("panel_solid", 16, Vector4(18, 14, 18, 16))
	panel.custom_minimum_size = Vector2(1100, 640)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	var col := _vbox(10)
	panel.add_child(col)
	var head := _hbox(12)
	col.add_child(head)
	window_title = _label("", L, UITheme.ACCENT)
	window_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(window_title)
	var close := _btn(head, "Fechar [Esc]", close_window)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(_pixel_line())
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size.y = 540
	col.add_child(sc)
	window_box = _vbox(8)
	window_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(window_box)


func open_window(kind: String) -> void:
	var p := _player()
	if p == null or p.data == null or p.is_dead():
		return
	if menu_root.visible:
		menu_root.visible = false
		loot_node = null
	window_kind = kind
	window_root.visible = true
	get_tree().paused = Net.is_solo()
	_rebuild_window()


func close_window() -> void:
	window_kind = ""
	window_root.visible = false
	village_open = -1
	vehicle_node = null
	station_node = null
	_close_ctx()
	if not menu_root.visible:
		get_tree().paused = false


func _rebuild_window() -> void:
	var p := _player()
	if p == null or p.data == null or window_kind == "":
		return
	match window_kind:
		"build":
			window_title.text = "CONSTRUÇÃO"
			_win_build(p)
		"village":
			window_title.text = "VILA"
			_tab_village(p)
		"vehicle":
			window_title.text = "VEÍCULO"
			_tab_vehicle(p)
		"station":
			if station_node == null or not is_instance_valid(station_node) or \
					Vector2(station_node.position.x - p.position.x, (station_node.position.y - p.position.y) * 2.0).length() > 150.0:
				close_window()
				return
			window_title.text = String(DB.BUILDS[station_node.kind]["nome"]).to_upper()
			_win_station(p, station_node)


func _win_act(cb: Callable) -> Callable:
	return func() -> void:
		cb.call()
		_rebuild_window()


# ------------------------------------------------------------------ menu de contexto
func _build_ctx() -> void:
	ctx_root = Control.new()
	ctx_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctx_root.visible = false
	ctx_root.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(ctx_root)
	ctx_root.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_close_ctx())
	var panel := _panel("card", 8, Vector4(8, 8, 8, 8))
	panel.name = "Panel"
	ctx_root.add_child(panel)
	ctx_box = _vbox(4)
	panel.add_child(ctx_box)


## Abre o menu de contexto na posição do mouse com as opções [[texto, Callable], ...].
func _open_ctx(title: String, options: Array) -> void:
	_clear(ctx_box)
	var t := _label(title, S, UITheme.ACCENT)
	ctx_box.add_child(t)
	for o in options:
		var cb: Callable = o[1]
		var b := _btn(ctx_box, o[0], func() -> void:
			_close_ctx()
			cb.call()
			_rebuild())
		b.size_flags_horizontal = Control.SIZE_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	ctx_root.visible = true
	var panel: PanelContainer = ctx_root.get_node("Panel")
	panel.reset_size()
	var mp := ui.get_local_mouse_position()
	panel.position = Vector2(minf(mp.x, ui.size.x - panel.size.x - 8), minf(mp.y, ui.size.y - panel.size.y - 8))


func _close_ctx() -> void:
	if ctx_root != null:
		ctx_root.visible = false


# ------------------------------------------------------------------ botão do veículo
func _build_vehicle_button() -> void:
	veh_button = Button.new()
	veh_button.text = "[V] STATUS DO VEÍCULO"
	veh_button.visible = false
	veh_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	veh_button.pressed.connect(func() -> void:
		var v := Game.world.vehicle_of(_player().peer)
		if v != null:
			open_vehicle(v))
	ui.add_child(veh_button)


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
	_close_ctx()
	menu_root.visible = false
	if window_kind == "":
		get_tree().paused = false


func _input(event: InputEvent) -> void:
	if not root.visible:
		return
	if Game.console != null and Game.console.is_open():
		return
	if creation_root.visible:
		return
	var p := _player()
	if p == null or p.data == null:
		return
	if event.is_action_pressed("cancel") and ctx_root.visible:
		_close_ctx()
	elif event.is_action_pressed("cancel") and window_kind != "":
		close_window()
	elif event.is_action_pressed("cancel") and menu_root.visible:
		close_menu()
	elif event.is_action_pressed("menu"):
		if window_kind != "":
			close_window()
		elif menu_root.visible:
			close_menu()
		else:
			open_menu()
	elif event.is_action_pressed("inventory"):
		_toggle_tab(TAB_INV)
	elif event.is_action_pressed("map"):
		_toggle_tab(TAB_MAP)
	elif event.is_action_pressed("build_menu"):
		set_build_mode(not build_mode)
	elif event.is_action_pressed("cancel") and build_mode:
		set_build_mode(false)
	elif build_mode and event.is_action_pressed("demolish"):
		p.demolish = not p.demolish
		p.build_kind = ""
		_build_key = ""
		_update_build_bar(p)
	elif not blocks_input() and not build_mode and _hot_key(event) >= 0:
		hot_select(_hot_key(event))
	elif event.is_action_pressed("vehicle_status"):
		var v := Game.world.vehicle_of(p.peer)
		if window_kind == "vehicle":
			close_window()
		elif v != null:
			open_vehicle(v)
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()


## Atalho (I, M): abre o menu direto na aba; se já está nela, fecha.
func _toggle_tab(tab: int) -> void:
	if menu_root.visible and tabs.current_tab == tab:
		close_menu()
		return
	if window_kind != "":
		close_window()
	open_menu(tab)


# ------------------------------------------------------------------ atualização por frame
func _process(delta: float) -> void:
	var p := _player()
	if root.visible and p != null and p.pending:
		if not creation_root.visible:
			open_creation()
		return
	if creation_root.visible:
		creation_root.visible = false
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
	_set_bar("stamina", d.stamina / d.max_stamina() * 100.0)

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
	var w := Game.world
	var dk := w.darkness()
	clock_val.text = "%s · %s" % [w.clock_text(), "NOITE" if dk >= 0.99 else ("DIA" if dk <= 0.0 else "CREPÚSCULO")]
	var wt := str(w.weather.get("tipo", "limpo"))
	weather_val.text = "%s · VENTO %d%%" % [String(World.WEATHER_NAMES.get(wt, wt)).to_upper(), int(float(w.weather.get("vento", 0.2)) * 100.0)]
	weather_val.add_theme_color_override("font_color", UITheme.WARN if wt in ["tempestade", "neblina"] else UITheme.MUTED)

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
	_neural_glitch(d)

	# aviso de interação
	var in_veh := Game.world.vehicle_of(p.peer) != null
	if in_veh and not menu_root.visible:
		prompt_panel.visible = true
		prompt_key.visible = true
		prompt_label.text = "SAIR DO VEÍCULO"
	elif p.nearby != null and is_instance_valid(p.nearby) and not menu_root.visible and p.build_kind == "":
		var txt: String = p.nearby.prompt()
		prompt_panel.visible = txt != ""
		prompt_key.visible = txt.begins_with("[E]")
		prompt_label.text = txt.trim_prefix("[E] ").to_upper()
	else:
		prompt_panel.visible = false
	if prompt_panel.visible:
		prompt_panel.reset_size()
		prompt_panel.position = Vector2((ui.size.x - prompt_panel.size.x) / 2.0, ui.size.y - prompt_panel.size.y - 180.0).round()

	# ação com tempo
	var busy := p.busy_label != "" and p.busy_end > Game.play_time and p.busy_total > 0.0
	busy_panel.visible = busy
	if busy:
		busy_text.text = p.busy_label.to_upper()
		busy_bar.value = clampf(1.0 - (p.busy_end - Game.play_time) / p.busy_total, 0.0, 1.0) * 100.0
		busy_panel.reset_size()
		busy_panel.position = Vector2((ui.size.x - busy_panel.size.x) / 2.0, ui.size.y - busy_panel.size.y - 260.0).round()

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
	if window_kind != "":
		_window_t -= delta
		if _window_t <= 0.0 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_window_t = 1.0
			_rebuild_window()
	_map_tick(delta, p)
	# botão de status do veículo
	var inside := Game.world.vehicle_of(p.peer)
	veh_button.visible = inside != null and not blocks_input() and not build_mode
	if veh_button.visible:
		veh_button.reset_size()
		veh_button.position = Vector2((ui.size.x - veh_button.size.x) / 2.0, ui.size.y - veh_button.size.y - 120.0).round()
	_update_hotbar(d)
	if build_mode:
		for wdg in _play_widgets():
			wdg.visible = false
		prompt_panel.visible = false
		_build_t -= delta
		if _build_t <= 0.0:
			_build_t = 0.4
			_update_build_bar(p)


func _fence_text(v: VillageData) -> String:
	var fs: Array = Game.world.fence_summary(v.id)
	var names := ["", "chapa remendada", "chapa reforçada", "muralha de concreto"]
	var t := "Cerca: %s (nível %d) · integridade %d%%" % [names[clampi(v.wall_tier, 1, 3)], v.wall_tier, int(fs[0])]
	if int(fs[1]) > 0:
		t += " · %d BRECHA(S)" % int(fs[1])
	if v.wall_tier < 3:
		t += " · sobe de nível com prosperidade e sucata no estoque"
	return t


# ------------------------------------------------------------------ barra rápida
func _build_hotbar() -> void:
	hotbar_root = _vbox(8)
	ui.add_child(hotbar_root)
	for i in 5:
		var hs := HotSlot.new()
		hs.hud = self
		hs.index = i
		hotbar_root.add_child(hs)
		hot_slots.append(hs)
	hotbar_root.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	hotbar_root.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hotbar_root.grow_vertical = Control.GROW_DIRECTION_BOTH


func _update_hotbar(d: SurvivorData) -> void:
	if hot_sel >= 0 and String(d.hotbar[hot_sel]) == "":
		hot_sel = -1
	for i in hot_slots.size():
		var id: String = d.hotbar[i] if i < d.hotbar.size() else ""
		hot_slots[i].show_item(id, d.count(id) if id != "" else 0)
		hot_slots[i].set_selected(i == hot_sel)


static func _is_weapon(id: String) -> bool:
	return String(Items.def(id).get("tipo", "")) in ["arma", "arma_fogo"]


## Escolhe o espaço i (tecla 1-5 ou clique no espaço). Arma escolhida vai para a mão e o
## clique ataca; outro item espera o clique do mouse para ser usado. Escolher de novo solta.
func hot_select(i: int) -> void:
	var p := _player()
	if p == null or p.data == null:
		return
	var d := p.data
	var id: String = d.hotbar[i]
	if id == "":
		hot_sel = -1
		return
	if hot_sel == i:
		hot_sel = -1
		var w := d.weapon_inst()
		if _is_weapon(id) and not w.is_empty() and String(w["id"]) == id:
			p.act("use_item", [int(w["u"])])  # guarda a arma
		return
	hot_sel = i
	var inst := d.first_of(id)
	if inst.is_empty():
		Game.say("Sem %s no inventário." % DB.item_name(id).to_lower())
		return
	if _is_weapon(id):
		if int(inst["u"]) != d.hand_u:
			p.act("use_item", [int(inst["u"])])
	else:
		Game.say("Pronto para usar: %s (clique)." % DB.item_name(id).to_lower())


## O clique do mouse no mundo vai usar o item escolhido (em vez de atacar)?
func hot_consumes_click() -> bool:
	var p := _player()
	if hot_sel < 0 or p == null or p.data == null or build_mode or blocks_input():
		return false
	var id: String = p.data.hotbar[hot_sel]
	return id != "" and not _is_weapon(id)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and hot_consumes_click():
		hot_use(hot_sel)
		get_viewport().set_input_as_handled()


func _hot_key(event: InputEvent) -> int:
	for i in 5:
		if event.is_action_pressed("hot_%d" % (i + 1)):
			return i
	return -1


## Põe (ou tira, com id "") um tipo de item no espaço i da barra rápida.
func hot_set(i: int, id: String) -> void:
	var p := _player()
	if p == null or p.data == null:
		return
	p.data.hotbar[i] = id
	p.act("hotbar", [i, id])


## Usa o item do espaço i: come, bebe, empunha, aplica curativo...
func hot_use(i: int) -> void:
	var p := _player()
	if p == null or p.data == null:
		return
	var d := p.data
	var id: String = d.hotbar[i]
	if id == "":
		return
	var inst := d.first_of(id)
	if inst.is_empty():
		Game.say("Sem %s no inventário." % DB.item_name(id).to_lower())
		return
	match id:
		"bandagem", "gaze":
			var l := _worst_limb(d, func(limb: Dictionary) -> bool:
				return int(limb["wound"]) > 0 and not limb["bandaged"])
			if l == "":
				Game.say("Nenhum ferimento para enfaixar.")
			else:
				p.act("treat", [l, "enfaixar", 0])
			return
		"antisseptico", "alcool":
			var l2 := _worst_limb(d, func(limb: Dictionary) -> bool:
				return int(limb["wound"]) > 0 and not limb["disinfected"])
			if l2 == "":
				Game.say("Nenhum ferimento para desinfetar.")
			else:
				p.act("treat", [l2, "desinfetar", 0])
			return
		"tala":
			var l3 := _worst_limb(d, func(limb: Dictionary) -> bool:
				return int(limb.get("osso", 0)) > 0 and not limb.get("tala", false))
			if l3 == "":
				Game.say("Nenhum osso para imobilizar.")
			else:
				p.act("treat", [l3, "imobilizar", 0])
			return
		"antibiotico":
			p.act("treat", ["torso", "antibiotico", 0])
			return
	if _verb_for(d, inst) == "":
		Game.say("%s não tem uso rápido." % DB.item_name(id))
		return
	p.act("use_item", [int(inst["u"])])


## Membro mais ferido que atende à condição ("" = nenhum).
func _worst_limb(d: SurvivorData, ok: Callable) -> String:
	var best := ""
	var worst := 1e9
	for l in SurvivorData.LIMBS:
		var limb: Dictionary = d.limbs[l]
		if ok.call(limb) and float(limb["hp"]) - float(limb["bleed"]) * 10.0 < worst:
			worst = float(limb["hp"]) - float(limb["bleed"]) * 10.0
			best = l
	return best


# ------------------------------------------------------------------ modo construção
func _play_widgets() -> Array:
	return [air_panel, vitals_panel, equip_box, effects_box, hotbar_root, log_box]


func _build_build_bar() -> void:
	# moldura da tela
	build_frame = Control.new()
	build_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_frame.visible = false
	ui.add_child(build_frame)
	build_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in 4:
		var r := ColorRect.new()
		r.color = Color(UITheme.WARN, 0.85)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		build_frame.add_child(r)
		match side:
			0:
				r.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
				r.offset_bottom = 8
			1:
				r.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
				r.offset_top = -8
			2:
				r.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
				r.offset_right = 8
			_:
				r.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
				r.offset_left = -8
	var tag := _panel("panel_warn", 12, Vector4(18, 6, 18, 8))
	build_frame.add_child(tag)
	var trow := _hbox(10)
	tag.add_child(trow)
	trow.add_child(UITheme.icon_rect("martelo", UITheme.WARN, 28))
	trow.add_child(_label("MODO CONSTRUÇÃO · B ou ESC sai · X demolir · botão direito solta o item", S, UITheme.WARN))
	tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 20)
	tag.grow_horizontal = Control.GROW_DIRECTION_BOTH
	# faixa de baixo: abas em cima, uma linha de construções
	build_bar = _panel("panel", 12, Vector4(16, 10, 16, 10))
	build_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	build_bar.visible = false
	ui.add_child(build_bar)
	build_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 16)
	build_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var col := _vbox(8)
	build_bar.add_child(col)
	build_tabs_row = _hbox(8)
	col.add_child(build_tabs_row)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 150)
	col.add_child(sc)
	build_items = _hbox(8)
	sc.add_child(build_items)
	build_info = _label("", S, UITheme.MUTED)
	col.add_child(build_info)


## Entra ou sai do modo construção: faixa embaixo, moldura, HUD normal escondida e a câmera
## desliza para o personagem ficar no alto da tela.
func set_build_mode(on: bool) -> void:
	var p := _player()
	if p == null or p.data == null or (on and (p.is_dead() or p.pending)):
		return
	if on:
		if menu_root.visible:
			close_menu()
		if window_kind != "":
			close_window()
	build_mode = on
	build_bar.visible = on
	build_frame.visible = on
	if not on:
		p.build_kind = ""
		p.demolish = false
		_build_key = ""
		for wdg in _play_widgets():
			wdg.visible = true
	else:
		_fill_build_bar(p)
		_update_build_bar(p)
	if p.camera != null:
		var tw := create_tween()
		tw.tween_property(p.camera, "offset", Vector2(0, 150) if on else Vector2.ZERO, 0.35).set_trans(Tween.TRANS_SINE)


func _fill_build_bar(p: Player) -> void:
	_clear(build_tabs_row)
	for t: Array in DB.BUILD_TABS:
		var tid: String = t[0]
		var b := _btn(build_tabs_row, t[1], func() -> void:
			build_tab = tid
			_fill_build_bar(_player())
			_update_build_bar(_player()))
		b.toggle_mode = true
		b.button_pressed = build_tab == tid
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_tabs_row.add_child(sp)
	_btn(build_tabs_row, "Demolir [X]", func() -> void:
		var pl := _player()
		pl.demolish = not pl.demolish
		pl.build_kind = ""
		_build_key = ""
		_update_build_bar(pl))
	_btn(build_tabs_row, "Sair [B]", func() -> void: set_build_mode(false))
	_clear(build_items)
	for k: String in DB.BUILDS:
		var def: Dictionary = DB.BUILDS[k]
		if String(def.get("aba", "")) != build_tab:
			continue
		var card := Button.new()
		card.custom_minimum_size = Vector2(118, 140)
		card.toggle_mode = true
		card.set_meta("kind", k)
		card.tooltip_text = "%s\n%s\nCusto: %s%s" % [def["nome"], def.get("desc", ""), DB.cost_text(def["custo"]),
			"" if (def["req"] as Dictionary).is_empty() else "\nExige: " + DB.req_text(def["req"])]
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var v := _vbox(2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		card.add_child(v)
		var th := TextureRect.new()
		th.custom_minimum_size = Vector2(0, 84)
		th.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		th.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		th.mouse_filter = Control.MOUSE_FILTER_IGNORE
		th.texture = _build_thumb(k, def)
		v.add_child(th)
		var nl := _label(String(def["nome"]).to_upper(), S, UITheme.TEXT)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size = Vector2(108, 0)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(nl)
		card.pressed.connect(func() -> void:
			var pl := _player()
			pl.build_kind = k
			pl.demolish = false
			_build_key = k
			_update_build_bar(pl))
		build_items.add_child(card)


func _build_thumb(k: String, def: Dictionary) -> Texture2D:
	if def.has("chao"):
		var at := AtlasTexture.new()
		at.atlas = load(GenCatalog.GROUND_PATH)
		at.region = Rect2(int(def["chao"]) * World.TILE_W, 0, World.TILE_W, World.TILE_H)
		return at
	var tex := GenArt.frame_texture(k, 0, 0)
	return tex if tex != null else UITheme.icon("martelo")


## Destaque do item escolhido, cores de "dá para construir" e a linha de informação.
func _update_build_bar(p: Player) -> void:
	var d := p.data
	for c in build_items.get_children():
		var b := c as Button
		var k: String = b.get_meta("kind")
		var def: Dictionary = DB.BUILDS[k]
		var ok := d.meets(def["req"]) and d.missing_tools(def.get("ferramentas", [])) == "" and _afford_local(def["custo"])
		b.button_pressed = p.build_kind == k
		b.modulate = Color.WHITE if ok else Color(1.0, 0.6, 0.65, 0.75)
	var txt := ""
	if p.demolish:
		txt = "DEMOLIR: clique numa construção (devolve metade dos materiais)."
	elif p.build_kind != "" and DB.BUILDS.has(p.build_kind):
		var def2: Dictionary = DB.BUILDS[p.build_kind]
		var tl: Array = def2.get("ferramentas", [])
		txt = "%s · custo %s%s%s · clique no mapa para colocar" % [String(def2["nome"]).to_upper(), DB.cost_text(def2["custo"]),
			"" if (def2["req"] as Dictionary).is_empty() else " · exige " + DB.req_text(def2["req"]),
			"" if tl.is_empty() else " · " + DB.tools_text(tl)]
	else:
		txt = "Escolha uma construção. Materiais em baús e sacos a até 2 tiles também contam."
	var pw := _power_summary(p)
	if pw != "":
		txt += "   |   " + pw
	if not msgs.is_empty():
		txt += "   |   " + String(msgs[-1]["text"])
	build_info.text = txt


## Sobrecarga sináptica: a interface treme, pisca e muda de cor (GDD 4: distorções de HUD).
func _neural_glitch(d: SurvivorData) -> void:
	if not d.overloaded():
		if ui.position != Vector2.ZERO or ui.modulate != Color.WHITE:
			ui.position = Vector2.ZERO
			ui.modulate = Color.WHITE
		return
	if randf() < 0.25:
		ui.position = Vector2(randf_range(-7, 7), randf_range(-4, 4)).round()
		ui.modulate = Color(1.0, randf_range(0.55, 1.0), 1.0, randf_range(0.7, 1.0))
	if randf() < 0.04:
		ui.modulate = Color(1, 0.3, 1, 0.35)
	hurt.color = Color(0.7, 0.1, 0.9, 0.12 + 0.08 * sin(_t * 23.0))


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
	if w.has("mun"):
		(arma[1] as Label).text = "%d/%d" % [int(float(w["mun"])), int(Items.def(w["id"])["pente"])]
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
	var lp := _player()
	if lp != null and lp.sneaking:
		list.append(["olho", "AGACHADO", UITheme.ACCENT])
	if d.lantern_on():
		list.append(["alerta", "LANTERNA ACESA", UITheme.WARN])
	if d.well_fed_t > 0.0:
		list.append(["panela", "BEM ALIMENTADO %ds" % int(d.well_fed_t), OK_COLOR])
	if d.pain_t > 0.0:
		list.append(["antibiotico", "ANALGÉSICO %ds" % int(d.pain_t), OK_COLOR])
	if d.overloaded():
		list.append(["cerebro", "SOBRECARGA SINÁPTICA", UITheme.MAGENTA])
	elif d.synaptic > 60.0:
		list.append(["cerebro", "ESTRESSE NEURAL %d%%" % int(d.synaptic), UITheme.MAGENTA])
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
	# não reconstrói no meio de um arraste ou com o menu de contexto aberto
	if get_viewport().gui_is_dragging() or ctx_root.visible:
		return
	var d := p.data
	match tabs.current_tab:
		0: _tab_inventory(d)
		1: _tab_body(d)
		2: _tab_skills(d)
		3: _tab_implants(d)
		4: _tab_map(p)


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
	wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(wl)
	_bar(top, minf(ratio, 1.5), 1.5, UITheme.DANGER if ratio > 1.0 else UITheme.ACCENT, 240, 15)
	_lbl(top, ("SOBRECARGA: você anda mais devagar." if ratio > 1.0 else "Botão direito: opções · arrastar: organizar · dois cliques: passar"),
		UITheme.WARN if ratio > 1.0 else UITheme.MUTED)
	var cols := _hbox(16)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(cols)
	var looting := loot_node != null and is_instance_valid(loot_node)
	if looting:
		_loot_grid(_scroll_col(cols, 560), d)
	_inventory_grid(_scroll_col(cols, 560), d, looting)
	if not looting:
		_crafting(_scroll_col(cols, 0), d)


## Coluna com rolagem própria (largura mínima 'w'; 0 = ocupa o resto).
func _scroll_col(parent: Control, w: int) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(w, 540)
	if w == 0:
		sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sc)
	var v := _vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return v


## Grade de 4 colunas (com espaços vazios até completar a linha, para soltar itens).
func _grid(parent: Control, side: String, cont: String, items: Array, d: SurvivorData) -> void:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	parent.add_child(g)
	var total := items.size() + 1
	total = int(ceil(float(total) / 4.0)) * 4
	for i in total:
		var sl := InvSlot.new()
		sl.hud = self
		sl.side = side
		sl.cont = cont
		if i < items.size():
			sl.inst = items[i]
			sl.index = i
			sl.in_hand = side == "inv" and int(items[i].get("u", 0)) == d.hand_u
		g.add_child(sl)


func _inventory_grid(box: VBoxContainer, d: SurvivorData, looting: bool) -> void:
	var head := _hbox(10)
	box.add_child(head)
	var t := _label("INVENTÁRIO", S, UITheme.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_btn(head, "Organizar", _act(func() -> void: _player().act("sort_inv")))
	# itens vestidos
	var worn := _hbox(6)
	box.add_child(worn)
	for slot in SurvivorData.EQUIP_SLOTS:
		var sl := InvSlot.new()
		sl.hud = self
		sl.side = "equip"
		sl.cont = slot
		sl.inst = d.equip[slot]
		worn.add_child(sl)
	var wl := _label("VESTINDO: máscara · mochila · coldre", S, UITheme.MUTED)
	wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	worn.add_child(wl)
	for c in ["coldre", "mochila", "bolsos"]:
		var cap := d.capacity(c)
		if cap <= 0.0 and d.bags[c].is_empty():
			continue
		_head(box, "%s  %.1f / %.0f L" % [SurvivorData.CONT_NAMES[c], d.used_volume(c), cap])
		_grid(box, "inv", c, d.bags[c], d)


func _loot_grid(box: VBoxContainer, _d: SurvivorData) -> void:
	var node := loot_node
	var key := Game.world.key_of(node)
	var items: Array = node.items
	var head := _hbox(10)
	box.add_child(head)
	var t := _label(String(node.title()).to_upper(), S, UITheme.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_btn(head, "Organizar", _act(func() -> void: _player().act("sort_loot", [key])), items.size() > 1)
	_btn(head, "Pegar tudo", _act(func() -> void: _player().act("take_all", [key])), not items.is_empty())
	var info := "%d itens · %.1f kg" % [Items.total_units(items), Items.list_weight(items)]
	if node is Vehicle:
		info += " · %.0f / %.0f L" % [(node as Vehicle).trunk_volume(), float((node as Vehicle).def()["porta_malas"])]
	_lbl(box, info, UITheme.MUTED)
	_grid(box, "loot", key, items, _d)


func _crafting(box: VBoxContainer, d: SurvivorData) -> void:
	_head(box, "Fabricação à mão")
	_lbl(box, "Receitas de bancada, fogareiro e fornalha: chegue perto da estação e aperte [E].", UITheme.MUTED)
	_recipes(box, d, "", _act)


## Linhas de receita de uma estação ("" = feitas à mão). 'wrap' refaz a tela depois do clique.
func _recipes(box: VBoxContainer, d: SurvivorData, station: String, wrap: Callable) -> void:
	for rid: String in DB.CRAFTS:
		var cdef: Dictionary = DB.CRAFTS[rid]
		if String(cdef.get("estacao", "")) != station:
			continue
		var crow := _row(box)
		crow.add_child(_item_icon(String(cdef.get("saida", rid)), 40))
		var tools: Array = cdef.get("ferramentas", [])
		var near := station == "" or Game.world.station_near(_player().position, station)
		var ok := d.meets(cdef["req"]) and _afford_local(cdef["custo"]) and d.missing_tools(tools) == "" and near
		_lbl(crow, "%s\n%s · exige %s · ferramentas: %s" % [cdef["nome"], DB.cost_text(cdef["custo"]), DB.req_text(cdef["req"]),
			DB.tools_text(tools)], UITheme.TEXT if ok else NO_COLOR)
		_btn(crow, "Fabricar", wrap.call(func() -> void: _player().act("craft", [rid])), d.meets(cdef["req"]))


func _win_station(p: Player, st: Structure) -> void:
	var box := window_box
	_clear(box)
	var d := p.data
	_lbl(box, String(DB.BUILDS[st.kind]["desc"]), UITheme.MUTED)
	var sup := Structure.supply_of(st.kind)
	if not sup.is_empty():
		var row := _row(box)
		row.add_child(_item_icon(String(sup["itens"][0]), 40))
		var lvl := _label("%s: %d%%" % [String(sup["nome"]).capitalize(), int(st.fuel)], S, UITheme.TEXT if st.fuel > 0.0 else UITheme.DANGER)
		lvl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lvl)
		_bar(row, st.fuel, 100.0, UITheme.WARN, 200, 10)
		var have := 0
		for it: String in sup["itens"]:
			have += d.count(it)
		var key := Game.world.key_of(st)
		_btn(row, "Pôr %s (madeira x%d)" % [sup["nome"], have], _win_act(func() -> void: _player().act("refuel_station", [key])),
			have > 0 and st.fuel < 100.0 - float(sup["por_item"]) * 0.5)
		if sup.has("uso"):
			_lbl(row, "Cada receita gasta %d%%." % int(sup["uso"]), UITheme.MUTED)
	if st.kind == "mesa_reparo":
		_win_repairs(box, d)
		return
	_head(box, "Receitas")
	_recipes(box, d, st.kind, _win_act)


## Mesa de reparos: tudo o que está gasto, no inventário e vestido.
func _win_repairs(box: VBoxContainer, d: SurvivorData) -> void:
	_head(box, "Consertos (fita adesiva x%d · sucata x%d)" % [d.count("fita"), d.count("sucata")])
	var any := false
	var lists: Array = []
	for c: String in d.bags:
		lists.append_array(d.bags[c])
	for slot: String in d.equip:
		if not d.equip[slot].is_empty():
			lists.append(d.equip[slot])
	for inst: Dictionary in lists:
		if not inst.has("dur") or float(inst["dur"]) >= 100.0:
			continue
		any = true
		var row := _row(box)
		row.add_child(_item_icon(inst["id"], 40))
		_lbl(row, "%s · %d%%" % [DB.item_name(inst["id"]), int(float(inst["dur"]))], UITheme.TEXT)
		var gun := String(Items.def(inst["id"]).get("tipo", "")) == "arma_fogo"
		var u := int(inst.get("u", 0))
		_btn(row, "Consertar (fita%s)" % (" + sucata" if gun else ""), _win_act(func() -> void: _player().act("repair", [u])),
			d.count("fita") > 0 and (not gun or d.count("sucata") > 0))
	if not any:
		_lbl(box, "Nada para consertar.", UITheme.MUTED)


# ------------------------------------------------------------------ ações da grade
## Texto da opção de conserto (vazio se não dá para consertar aqui).
func _repair_label(d: SurvivorData, inst: Dictionary) -> String:
	if not inst.has("dur") or float(inst["dur"]) >= 100.0 or d.count("fita") <= 0:
		return ""
	var bench := Game.world.station_near(_player().position, "mesa_reparo")
	var id: String = inst["id"]
	if SurvivorData.needs_bench(id) and not bench:
		return ""
	if String(Items.def(id).get("tipo", "")) == "arma_fogo":
		return "Consertar na mesa (fita + sucata)" if d.count("sucata") > 0 else ""
	return "Consertar na mesa (fita)" if bench else "Consertar (fita)"



## Botão direito num item: opções conforme onde ele está.
func slot_menu(sl: InvSlot) -> void:
	var p := _player()
	var d := p.data
	var inst := sl.inst
	var opts: Array = []
	var looting := loot_node != null and is_instance_valid(loot_node)
	match sl.side:
		"equip":
			var u0 := int(inst.get("u", 0))
			var rl := _repair_label(d, inst)
			if rl != "":
				opts.append([rl, func() -> void: p.act("repair", [u0])])
			var c0 := sl.cont
			opts.append(["Tirar", func() -> void: p.act("unwear", [c0])])
		"loot":
			var key := sl.cont
			var idx := sl.index
			var n := int(inst["n"])
			var id: String = inst["id"]
			if SurvivorData.slot_of(id) != "":
				opts.append(["Vestir", func() -> void: p.act("take", [key, idx, 1, "vestir", id])])
			opts.append(["Pegar" + (" (%d)" % n if n > 1 else ""), func() -> void: p.act("take", [key, idx, n, "", id])])
			if n > 1:
				opts.append(["Pegar 1", func() -> void: p.act("take", [key, idx, 1, "", id])])
			opts.append(["Pegar tudo do recipiente", func() -> void: p.act("take_all", [key])])
		"inv":
			var u := int(inst["u"])
			var n2 := int(inst["n"])
			var verb := _verb_for(d, inst)
			if verb != "":
				opts.append([verb, func() -> void: p.act("use_item", [u])])
			var rl := _repair_label(d, inst)
			if rl != "":
				opts.append([rl, func() -> void: p.act("repair", [u])])
			if looting:
				var key2 := Game.world.key_of(loot_node)
				opts.append(["Guardar" + (" (%d)" % n2 if n2 > 1 else ""), func() -> void: p.act("store", [key2, u, n2])])
				if n2 > 1:
					opts.append(["Guardar 1", func() -> void: p.act("store", [key2, u, 1])])
			for dest in ["mochila", "bolsos", "coldre"]:
				if dest != sl.cont and d.fits(dest, inst) >= n2:
					var dn: String = dest
					opts.append(["Mover para %s" % SurvivorData.CONT_NAMES[dest].to_lower(), func() -> void: p.act("move", [u, dn])])
			opts.append(["Largar no chão" + (" (%d)" % n2 if n2 > 1 else ""), func() -> void: p.act("drop", [u, n2])])
			if n2 > 1:
				opts.append(["Largar 1", func() -> void: p.act("drop", [u, 1])])
	if not opts.is_empty():
		_open_ctx(Items.label(inst), opts)


## Dois cliques: passa o item entre o recipiente aberto e o inventário.
func slot_double(sl: InvSlot) -> void:
	if loot_node == null or not is_instance_valid(loot_node):
		return
	var p := _player()
	var n := int(sl.inst["n"])
	if sl.side == "loot":
		p.act("take", [sl.cont, sl.index, n, "", str(sl.inst["id"])])
	elif sl.side == "inv":
		p.act("store", [Game.world.key_of(loot_node), int(sl.inst["u"]), n])
	_rebuild.call_deferred()


## Arrastar e soltar: reordena no mesmo recipiente ou move entre recipientes.
func slot_drop(src: InvSlot, dst: InvSlot) -> void:
	var p := _player()
	if src.inst.is_empty():
		return
	var n := int(src.inst["n"])
	match [src.side, dst.side]:
		["inv", "inv"]:
			var u := int(src.inst["u"])
			if src.cont == dst.cont:
				p.act("reorder", [u, dst.index])
			else:
				p.act("move", [u, dst.cont])
		["loot", "inv"]:
			p.act("take", [src.cont, src.index, n, "para:" + dst.cont, str(src.inst["id"])])
		["inv", "loot"]:
			p.act("store", [dst.cont, int(src.inst["u"]), n])
		["loot", "loot"]:
			if src.cont == dst.cont:
				p.act("loot_order", [src.cont, src.index, dst.index])
	_rebuild.call_deferred()


# ------------------------------------------------------------------ mapa
func _tab_map(p: Player) -> void:
	var box: VBoxContainer = boxes["mapa"]
	if map_view == null or not is_instance_valid(map_view):
		_clear(box)
		var row := _hbox(14)
		box.add_child(row)
		map_view = MapView.new()
		map_view.hud = self
		map_view.custom_minimum_size = Vector2(920, 560)
		row.add_child(map_view)
		map_info = _vbox(6)
		map_info.custom_minimum_size.x = 330
		map_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(map_info)
		map_view.resized.connect(func() -> void:
			map_view.zoom = 2.0
			map_view.center_on(Game.world.tile_pos(_player().position))
			map_view.queue_redraw(), CONNECT_ONE_SHOT)
	map_view._spore_cache.clear()
	map_view.queue_redraw()
	if map_info.get_child_count() == 0:
		map_hovered(World.chunk_of(Vector2i(Game.world.tile_pos(p.position).floor())))


## Atualiza o painel ao lado do mapa com o que se sabe da área sob o mouse.
func map_hovered(ch: Vector2i) -> void:
	if map_info == null:
		return
	_clear(map_info)
	map_info.add_child(_label("ÁREA %d, %d" % [ch.x, ch.y], S, UITheme.ACCENT))
	if not map_known.has(ch):
		_lbl(map_info, "Área não explorada.", UITheme.MUTED)
		_map_legend()
		return
	var w := Game.world
	var center := ch * World.CHUNK + Vector2i(World.CHUNK / 2, World.CHUNK / 2)
	var sp := w.spore_at(w.ground.map_to_local(center))
	var air := "limpo" if sp < 0.15 else ("contaminado" if sp < 0.5 else ("denso" if sp < 1.0 else "LETAL"))
	_lbl(map_info, "%d tiles do centro · ar %s (%.2f)" % [int(Vector2(center).length()), air, sp],
		UITheme.DANGER if sp >= 1.0 else UITheme.TEXT)
	for v in w.villages:
		if World.chunk_of(v.cell) == ch:
			_lbl(map_info, "%s — %s · nível %d · pop %d" % [v.nome, v.status_text(), v.level(), v.pop], UITheme.ACCENT)
			if not v.request.is_empty():
				_lbl(map_info, "Pedido de socorro: %s" % v.request_text(), UITheme.WARN)
			_lbl(map_info, "Comerciante: %s" % {"comida": "comida e sementes", "sucata": "materiais e ferramentas", "medico": "remédios"}[v.specialty], UITheme.MUTED)
	var buildings := 0
	for e in w.plan.get(ch, []):
		if e["t"] == "b" and not w.removed_cells.has(e["cell"]):
			buildings += 1
	if buildings > 0:
		_lbl(map_info, "Prédios: %d" % buildings, UITheme.TEXT)
	var counts := {}
	var empty := 0
	for e in w.plan.get(ch, []):
		if e["t"] != "c":
			continue
		var cd: Dictionary = w.container_data[int(e["id"])]
		counts[cd["table"]] = int(counts.get(cd["table"], 0)) + 1
		if cd["items"].is_empty():
			empty += 1
	if not counts.is_empty():
		var kinds := {"comum": "comida, água e materiais", "medico": "remédios e curativos", "tecnico": "peças, baterias, ferramentas e implantes"}
		_lbl(map_info, "Lugares com itens: %d (%d já vazios)" % [counts.values().reduce(func(a, b): return a + b, 0), empty], UITheme.TEXT)
		var names := {"comum": "comuns", "medico": "médicos", "tecnico": "técnicos", "geladeira": "geladeiras", "cozinha": "fogões",
			"pia": "pias", "armario": "armários", "estante": "estantes e arquivos", "prateleira": "prateleiras", "balcao": "balcões", "tambores": "tambores"}
		for t in counts:
			_lbl(map_info, "• %d %s%s" % [int(counts[t]), names.get(t, t), (": " + kinds[t]) if kinds.has(t) else ""],
				MapView.TABLE_COLORS.get(t, UITheme.MUTED))
	var vehs := 0
	for n in get_tree().get_nodes_in_group("vehicles"):
		var vt := w.tile_pos((n as Node2D).position)
		if World.chunk_of(Vector2i(vt.floor())) == ch:
			vehs += 1
	if vehs > 0:
		_lbl(map_info, "Veículos abandonados: %d" % vehs, Color("#ff9a3c"))
	var mine := 0
	for c in w.built:
		if World.chunk_of(c) == ch and not w.built[c].get("eternal", false):
			mine += 1
	if mine > 0:
		_lbl(map_info, "Construções da equipe: %d" % mine, Color("#ffd166"))
	_map_legend()


func _map_legend() -> void:
	_head(map_info, "Legenda")
	_lbl(map_info, "Roda: zoom · arrastar: mover\nTriângulo: você · círculos: aliados\nQuadrados: vilas (amarelo = pedido de socorro, vermelho = zona morta)\nLaranja: veículos · amarelo pequeno: construções\nPontos (com zoom): caixas comuns, médicas e técnicas", UITheme.MUTED)


## Marca como descobertos os chunks ao redor do jogador e salva de tempos em tempos.
func _map_tick(delta: float, p: Player) -> void:
	if _map_file == "":
		var nm := Net.player_name.strip_edges().to_lower().replace(" ", "_").validate_filename()
		_map_file = "user://mapa_%d_%s.json" % [Game.world.seed_value, nm if nm != "" else "jogador"]
		var f := FileAccess.open(_map_file, FileAccess.READ)
		if f != null:
			var data: Variant = JSON.parse_string(f.get_as_text())
			if data is Array:
				for a in data:
					map_known[Vector2i(int(a[0]), int(a[1]))] = true
	_map_t -= delta
	if _map_t <= 0.0:
		_map_t = 0.5
		var c := World.chunk_of(Vector2i(Game.world.tile_pos(p.position).floor()))
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var ch := c + Vector2i(dx, dy)
				if not map_known.has(ch):
					map_known[ch] = true
					_map_dirty = true
		if _map_dirty and menu_root.visible and tabs.current_tab == TAB_MAP and map_view != null:
			map_view.queue_redraw()
	_map_save_t -= delta
	if _map_save_t <= 0.0 and _map_dirty:
		_map_save_t = 10.0
		save_map()


func save_map() -> void:
	if _map_file == "":
		return
	_map_dirty = false
	var arr: Array = []
	for ch: Vector2i in map_known:
		arr.append([ch.x, ch.y])
	var f := FileAccess.open(_map_file, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(arr))


## Materiais no inventário + recipientes por perto (como o anfitrião confere).
func _afford_local(cost: Dictionary) -> bool:
	var p := _player()
	var d := p.data
	for k in cost:
		var have := d.count(k)
		for n in get_tree().get_nodes_in_group("containers"):
			var lc := n as LootContainer
			var off := lc.position - p.position
			if Vector2(off.x, off.y * 2.0).length() <= 130.0:
				have += Items.count(lc.items, k)
		if have < int(cost[k]):
			return false
	return true


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
		"mascara", "mochila", "coldre", "roupa": return "Vestir"
		"filtro": return "Trocar filtro" if d.has_mask() else ""
		"supressor": return "Aplicar"
		"bateria": return "Recarregar"
		"manual": return "Ler"
		"arma", "arma_fogo": return "Guardar" if d.hand_u == u else "Empunhar"
		"lanterna": return "Apagar" if d.light_u == u else "Acender"
		"pilha": return "Pôr na lanterna" if d.count("lanterna") > 0 else ""
		"cantil": return "Beber" if float(inst.get("carga", 0.0)) >= 1.0 else ("Encher" if d.count("agua_limpa") > 0 else "")
		"analgesico": return "Tomar"
		"regador": return "Encher" if float(inst.get("carga", 0.0)) < 99.0 and d.count("agua_suja") + d.count("agua_limpa") > 0 else ""
	return ""


## Aliados vivos perto o bastante para receber tratamento.
func _nearby_allies(p: Player) -> Array[Player]:
	var out: Array[Player] = []
	for k in Game.world.players:
		var o: Player = Game.world.players[k]
		if o == p or not o.alive:
			continue
		var off := o.position - p.position
		if Vector2(off.x, off.y * 2.0).length() <= 95.0:
			out.append(o)
	return out


func _tab_body(d: SurvivorData) -> void:
	var box: VBoxContainer = boxes["corpo"]
	_clear(box)
	var p := _player()
	# escolha do paciente
	var allies := _nearby_allies(p)
	var sel := _hbox(8)
	box.add_child(sel)
	sel.add_child(_sec_title("PACIENTE"))
	var ids: Array[int] = [0]
	for o in allies:
		ids.append(o.peer)
	if not patient_peer in ids:
		patient_peer = 0
	for pid in ids:
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = pid == patient_peer
		var nm := "VOCÊ" if pid == 0 else Net.name_of(pid).to_upper()
		if pid != 0 and patient_info.has(pid):
			nm = String(patient_info[pid]["nome"]).to_upper()
		b.text = nm
		var pp := pid
		b.pressed.connect(func() -> void:
			patient_peer = pp
			if pp != 0:
				_player().act("examine", [pp])
			_rebuild())
		sel.add_child(b)
	if allies.is_empty():
		_lbl(sel, "Chegue perto de um aliado para tratá-lo.", UITheme.MUTED)
	var target := 0
	var limbs: Dictionary = d.limbs
	var pname := "você"
	var blood := d.blood
	var pathogen := d.pathogen
	var antib := d.antibiotic_t
	if patient_peer != 0:
		p.act("examine", [patient_peer])
		if not patient_info.has(patient_peer):
			_lbl(box, "Examinando o paciente...", UITheme.MUTED)
			return
		var info: Dictionary = patient_info[patient_peer]
		target = patient_peer
		limbs = info["limbs"]
		pname = str(info["nome"])
		blood = float(info["blood"])
		pathogen = float(info["pathogen"])
		antib = float(info["antibiotic_t"])
	var cols := _hbox(14)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(cols)
	if target == 0:
		_body_equipment(cols, d)
	_body_limbs(cols, d, limbs, target, pname, blood, pathogen, antib)
	if target != 0:
		_patient_surgery(box, d, target)


func _sec_title(text: String) -> Label:
	var l := _label(text, S, UITheme.ACCENT)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _card(parent: Control, pad := Vector4(14, 10, 14, 12)) -> PanelContainer:
	var c := _panel("card", 8, pad)
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(c)
	return c


## Coluna de equipamento: espaços de roupa (e a máscara), conjuntos e roupas no inventário.
func _body_equipment(cols: HBoxContainer, d: SurvivorData) -> void:
	var panel := _card(cols)
	panel.custom_minimum_size.x = 600
	var v := _vbox(8)
	panel.add_child(v)
	v.add_child(_sec_title("EQUIPAMENTO"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for slot: String in ["cabeca", "mascara", "torso", "maos", "pernas", "pes"]:
		_body_slot(grid, d, slot)
	# conjuntos
	var any_set := false
	for cj: String in DB.CONJUNTOS:
		var n := d.set_pieces(cj)
		if n <= 0:
			continue
		if not any_set:
			v.add_child(_sec_title("CONJUNTOS"))
			any_set = true
		var total := (DB.CONJUNTOS[cj]["pecas"] as Array).size()
		var full := n >= total
		_lbl(v, "%s %d/%d · %s%s" % [DB.CONJUNTOS[cj]["nome"], n, total, DB.CONJUNTOS[cj]["desc"],
			" · ATIVO" if full else " (complete para ativar)"], OK_COLOR if full else UITheme.MUTED)
	var bon: Array[String] = []
	for k: String in DB.BONUS_NAMES:
		var b := d.gear_bonus(k)
		if b > 0.001:
			bon.append("%s +%d%%" % [DB.BONUS_NAMES[k], int(round(b * 100.0))])
	if not bon.is_empty():
		_lbl(v, "Bônus: " + " · ".join(bon), UITheme.ACCENT)
	# roupas guardadas
	var spare: Array = []
	for c: String in d.bags:
		for inst: Dictionary in d.bags[c]:
			if String(Items.def(inst["id"]).get("tipo", "")) == "roupa":
				spare.append(inst)
	if not spare.is_empty():
		v.add_child(_sec_title("NO INVENTÁRIO"))
		for inst: Dictionary in spare:
			var row := _hbox(8)
			v.add_child(row)
			row.add_child(_item_icon(inst["id"], 36))
			var t := _label("%s · %s" % [DB.item_name(inst["id"]), Items.cloth_text(inst["id"]).get_slice("\n", 0)], S, UITheme.TEXT)
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			t.clip_text = true
			row.add_child(t)
			var u := int(inst["u"])
			_btn(row, "Vestir", _act(func() -> void: _player().act("use_item", [u])))


## Um espaço de roupa: o item (menu com botão direito, como no inventário) e a proteção.
func _body_slot(grid: GridContainer, d: SurvivorData, slot: String) -> void:
	var inst: Dictionary = d.equip[slot]
	var nb := _card(grid, Vector4(6, 6, 10, 6))
	nb.custom_minimum_size = Vector2(280, 0)
	var row := _hbox(8)
	nb.add_child(row)
	var sl := InvSlot.new()
	sl.hud = self
	sl.side = "equip"
	sl.cont = slot
	sl.inst = inst
	row.add_child(sl)
	var info := _vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	var slot_name: String = "Rosto" if slot == "mascara" else DB.ROUPA_SLOT_NAMES[slot]
	info.add_child(_label(slot_name.to_upper(), S, UITheme.ACCENT))
	if inst.is_empty():
		info.add_child(_label("vazio", S, UITheme.MUTED))
		return
	var nm := _label(DB.item_name(inst["id"]), S, UITheme.TEXT)
	nm.clip_text = true
	nm.custom_minimum_size.x = 160
	info.add_child(nm)
	var dd := Items.def(inst["id"])
	if slot == "mascara":
		info.add_child(_label("vedação %d%% · filtro %d%%" % [int(d.mask_seal()), int(d.filter_pct())], S, UITheme.MUTED))
		return
	var k := SurvivorData.cloth_cond(inst)
	var worn := float(inst.get("dur", 100.0)) <= 0.0
	info.add_child(_label("DEF %d%% · CORTE %d%%%s" % [int(float(dd.get("def", 0.0)) * k * 100.0), int(float(dd.get("corte", 0.0)) * k * 100.0),
		" · FARRAPOS" if worn else ""], S, UITheme.DANGER if worn else UITheme.MUTED))


## Membros: os seis em linha (só o nome; contorno vermelho pulsando quando machucado) e,
## embaixo, os detalhes e o tratamento do membro escolhido.
func _body_limbs(cols: HBoxContainer, d: SurvivorData, limbs: Dictionary, target: int, pname: String,
		blood: float, pathogen: float, antib: float) -> void:
	var panel := _card(cols)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := _vbox(10)
	panel.add_child(v)
	v.add_child(_sec_title("CORPO · %s" % pname.to_upper()))
	var vit := _hbox(10)
	v.add_child(vit)
	vit.add_child(UITheme.icon_rect("sangue", UITheme.LIFE, 28))
	_bar(vit, blood, 100.0, UITheme.LIFE, 150, 10)
	vit.add_child(UITheme.icon_rect("contaminacao", UITheme.CONTAMINATION, 28))
	_bar(vit, pathogen, 100.0, UITheme.CONTAMINATION, 150, 10)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	v.add_child(line)
	if not body_sel in SurvivorData.LIMBS:
		body_sel = "torso"
	# começa no membro mais grave
	if body_auto:
		var worst := ""
		var wv := 0.0
		for l: String in SurvivorData.LIMBS:
			var sc := _limb_severity(limbs[l])
			if sc > wv:
				wv = sc
				worst = l
		if worst != "":
			body_sel = worst
	for l: String in SurvivorData.LIMBS:
		var limb: Dictionary = limbs[l]
		var hurt := _limb_severity(limb) > 0.0
		var nb := NeonBox.new()
		nb.clickable = true
		nb.pulse = hurt
		nb.selected = l == body_sel
		nb.pad = Vector4(6, 10, 6, 10)
		nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(nb)
		var nl := _label(String(SurvivorData.LIMB_NAMES[l]).to_upper(), S,
			NeonBox.NEON.lerp(Color.WHITE, 0.35) if hurt else (UITheme.TEXT if l == body_sel else UITheme.MUTED))
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nb.add_child(nl)
		var ll := l
		nb.pressed.connect(func() -> void:
			body_sel = ll
			body_auto = false
			_rebuild())
	_limb_detail(v, d, limbs[body_sel], body_sel, target)
	var top := _hbox(10)
	v.add_child(top)
	top.add_child(_item_icon("antibiotico", 40))
	_btn(top, "Antibiótico (x%d)" % d.count("antibiotico"), _act(func() -> void: _player().act("treat", ["torso", "antibiotico", target])), d.count("antibiotico") > 0)
	_lbl(top, "Ativo por %ds" % int(antib) if antib > 0.0 else "Cura sepse e infecção fúngica.", UITheme.MUTED)
	_lbl(v, "Nem todo golpe abre ferida; com uma ferida aberta, novos cortes pioram a mesma. A bandagem segura o sangramento e fecha a ferida com o tempo; torções e fraturas pedem tala. Você usa os seus suprimentos e a sua Medicina.", UITheme.MUTED)


## 0 = saudável; > 0 = machucado (ferida, infecção ou vida baixa).
func _limb_severity(limb: Dictionary) -> float:
	var s := 0.0
	if int(limb["wound"]) > 0:
		s += 50.0 * float(limb["wound"]) + float(limb["bleed"]) * 100.0
	if float(limb["infection"]) > 10.0:
		s += float(limb["infection"])
	if float(limb["hp"]) < 70.0:
		s += 70.0 - float(limb["hp"])
	s += 40.0 * float(limb.get("osso", 0))
	return s


func _limb_detail(v: VBoxContainer, d: SurvivorData, limb: Dictionary, l: String, target: int) -> void:
	var hurt := _limb_severity(limb) > 0.0
	var card := _card(v, Vector4(14, 10, 14, 10))
	var cv := _vbox(8)
	card.add_child(cv)
	var head := _hbox(12)
	cv.add_child(head)
	var title := _label(String(SurvivorData.LIMB_NAMES[l]).to_upper(), L, UITheme.TEXT)
	head.add_child(title)
	var hp := float(limb["hp"])
	var hcol := OK_COLOR if hp > 50.0 else UITheme.WARN if hp > 20.0 else UITheme.DANGER
	var hb := _bar(head, hp, 100.0, hcol, 220, 12)
	hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hl := _label("%d%%" % int(hp), S, hcol)
	hl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hl)
	var st: Array[String] = []
	if int(limb["wound"]) == 2:
		st.append("ferida PROFUNDA")
	elif int(limb["wound"]) == 1:
		st.append("ferida leve")
	if int(limb["wound"]) > 0 and float(limb["bleed"]) > 0.0 and not (limb["bandaged"] and int(limb["wound"]) == 1):
		st.append("sangrando (%.1f/s)" % (float(limb["bleed"]) * (0.15 if limb["bandaged"] else 1.0)))
	if float(limb["infection"]) > 1.0:
		st.append("infecção %d%%" % int(limb["infection"]))
	if limb["disinfected"]:
		st.append("desinfetado")
	if limb["bandaged"]:
		st.append("enfaixado")
	var osso := int(limb.get("osso", 0))
	if osso > 0:
		st.append(("FRATURA" if osso == 2 else "torção") + (" imobilizada (%d%%)" % int(float(limb.get("osso_t", 0.0))) if limb.get("tala", false) else ""))
	var stt := ", ".join(st)
	_lbl(cv, "Saudável." if st.is_empty() else stt.left(1).to_upper() + stt.substr(1) + ".", UITheme.MUTED if st.is_empty() else UITheme.WARN)
	if target == 0:
		var arm := d.limb_armor(l)
		_lbl(cv, "Proteção da roupa: %d%% do dano · %d%% menos chance de sangrar" % [int(float(arm[0]) * 100.0), int(float(arm[1]) * 100.0)], UITheme.MUTED)
	var bt := _hbox(8)
	cv.add_child(bt)
	var wounded := int(limb["wound"]) > 0
	_btn(bt, "Desinfetar", _act(func() -> void: _player().act("treat", [l, "desinfetar", target])), wounded and d.count("antisseptico") + d.count("alcool") > 0)
	_btn(bt, "Enfaixar", _act(func() -> void: _player().act("treat", [l, "enfaixar", target])), wounded and not limb["bandaged"] and d.count("bandagem") + d.count("gaze") > 0)
	if l in SurvivorData.BONE_LIMBS:
		_btn(bt, "Imobilizar (tala x%d)" % d.count("tala"), _act(func() -> void: _player().act("treat", [l, "imobilizar", target])),
			osso > 0 and not limb.get("tala", false) and d.count("tala") > 0)


## Cirurgia no aliado: remover implantes dele ou instalar um dos seus.
func _patient_surgery(box: VBoxContainer, d: SurvivorData, target: int) -> void:
	var info: Dictionary = patient_info[target]
	var imps: Dictionary = info["implants"]
	_head(box, "Cirurgia no paciente (núcleo neural %d/%d)" % [int(info["general"]), int(info["cap"])])
	for slot: String in imps:
		var row := _row(box)
		row.add_child(_item_icon(imps[slot]["id"], 40))
		_lbl(row, "%s · integridade %d%%" % [DB.item_name(imps[slot]["id"]), int(imps[slot]["integ"])], UITheme.TEXT)
		var sl := slot
		_btn(row, "Remover (kit)", _act(func() -> void: _player().act("remove_implant", [sl, target])), d.count("kit_cirurgico") > 0)
	for id: String in DB.IMPLANTS:
		if d.count(id) <= 0 or imps.has(DB.IMPLANTS[id]["slot"]):
			continue
		var def: Dictionary = DB.IMPLANTS[id]
		var row2 := _row(box)
		row2.add_child(_item_icon(id, 40))
		var meets := d.meets(def["req"])
		_lbl(row2, "Instalar %s no paciente (exige %s)%s" % [DB.item_name(id), DB.req_text(def["req"]),
			"" if meets else " · RISCO DE FALHA"], UITheme.TEXT if meets else UITheme.DANGER)
		var iid := id
		_btn(row2, "Operar", _act(func() -> void: _player().act("install", [iid, target])), d.count("kit_cirurgico") > 0)


func _tab_skills(d: SurvivorData) -> void:
	var box: VBoxContainer = boxes["skills"]
	_clear(box)
	var top := _row(box)
	_lbl(top, "FORÇA %d · RESISTÊNCIA %d · CARGA MÁX. %.0f KG · ESTAMINA MÁX. %.0f" % [d.forca, d.resist, d.carry_max(), d.max_stamina()], UITheme.ACCENT)
	if not d.traits.is_empty():
		var names: Array[String] = []
		for t in d.traits:
			names.append(String(DB.TRAITS[t]["nome"]))
		_lbl(box, "Traços: " + ", ".join(names), UITheme.MUTED)
	for g in DB.SKILL_GROUPS:
		_head(box, g[0])
		for key: String in g[1]:
			var row := _row(box)
			var l := _label(DB.SKILLS[key], S, UITheme.TEXT)
			l.custom_minimum_size.x = 300
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(l)
			var lv := _label("NV %d" % d.level(key), L, UITheme.ACCENT)
			lv.custom_minimum_size.x = 110
			row.add_child(lv)
			_bar(row, float(d.skills[key]["xp"]), d.xp_needed(d.level(key)), UITheme.MAGENTA, 300, 16)
			_lbl(row, DB.SKILL_DESC[key], UITheme.MUTED)
	_head(box, "Parede de conhecimento: construções")
	for k: String in DB.BUILDS:
		var req: Dictionary = DB.BUILDS[k]["req"]
		_lbl(box, "%s: %s" % [DB.BUILDS[k]["nome"], DB.req_text(req)], OK_COLOR if d.meets(req) else NO_COLOR)
	_head(box, "Parede de conhecimento: implantes (Medicina + Cibernética)")
	for k: String in DB.IMPLANTS:
		var req2: Dictionary = DB.IMPLANTS[k]["req"]
		_lbl(box, "%s: %s" % [DB.item_name(k), DB.req_text(req2)], OK_COLOR if d.meets(req2) else NO_COLOR)


# ------------------------------------------------------------------ criação de personagem
func _build_creation() -> void:
	creation_root = Control.new()
	creation_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	creation_root.visible = false
	ui.add_child(creation_root)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.03, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	creation_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	creation_root.add_child(center)
	var panel := _panel("panel_solid", 16, Vector4(22, 16, 22, 18))
	panel.custom_minimum_size = Vector2(1540, 840)
	center.add_child(panel)
	creation_box = _vbox(10)
	panel.add_child(creation_box)


func open_creation() -> void:
	close_menu()
	hide_death()
	creation_root.visible = true
	_creation_sent = false
	var r := RandomNumberGenerator.new()
	r.randomize()
	spec = SurvivorData.random_spec(r)
	_rebuild_creation()
	var args := " ".join(OS.get_cmdline_user_args())
	if "--autostart" in args and not "--no-autocreate" in args:
		_submit_creation()


func creation_refused() -> void:
	_creation_sent = false
	_rebuild_creation()


func _submit_creation() -> void:
	var p := _player()
	if p == null or _creation_sent or DB.creation_error(spec) != "":
		return
	_creation_sent = true
	p.send_creation(spec.duplicate(true))
	_rebuild_creation()


func _spec_skill(k: String) -> int:
	return int(spec["skills"].get(k, 0))


func _spec_change(cb: Callable) -> Callable:
	return func() -> void:
		cb.call()
		_rebuild_creation()


func _stepper(parent: Control, value: String, minus: Callable, plus: Callable, can_minus: bool, can_plus: bool) -> void:
	var b1 := _btn(parent, "-", _spec_change(minus), can_minus)
	b1.custom_minimum_size.x = 44
	var v := _label(value, L, UITheme.ACCENT)
	v.custom_minimum_size.x = 44
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(v)
	var b2 := _btn(parent, "+", _spec_change(plus), can_plus)
	b2.custom_minimum_size.x = 44


func _rebuild_creation() -> void:
	var box := creation_box
	_clear(box)
	var cost := DB.creation_cost(spec)
	var left := DB.CREATION_POINTS - cost
	# cabeçalho
	var head := _hbox(14)
	box.add_child(head)
	head.add_child(UITheme.icon_rect("pessoa", UITheme.ACCENT, 40))
	var t := _label("NOVO SOBREVIVENTE", L, UITheme.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_label("PONTOS", S, UITheme.MUTED))
	head.add_child(_label("%d" % left, L, UITheme.DANGER if left < 0 else OK_COLOR))
	# nome e modelos
	var row := _hbox(10)
	box.add_child(row)
	row.add_child(_label("NOME", S, UITheme.MUTED))
	var name_edit := LineEdit.new()
	name_edit.text = str(spec.get("nome", ""))
	name_edit.max_length = 20
	name_edit.custom_minimum_size = Vector2(320, 0)
	name_edit.text_changed.connect(func(tx: String) -> void: spec["nome"] = tx)
	row.add_child(name_edit)
	row.add_child(_label("MODELOS", S, UITheme.MUTED))
	for pname: String in DB.PRESETS:
		var pn := pname
		_btn(row, pn, _spec_change(func() -> void:
			var keep := str(spec.get("nome", ""))
			spec = DB.PRESETS[pn].duplicate(true)
			spec["nome"] = keep))
	var cols := _hbox(18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(cols)
	var c1 := _vbox(4)
	c1.custom_minimum_size.x = 600
	cols.add_child(c1)
	var c2 := _vbox(2)
	c2.custom_minimum_size.x = 420
	cols.add_child(c2)
	var c3 := _vbox(4)
	c3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(c3)
	# atributos
	_head(c1, "Atributos (2 pontos cada)")
	for a: String in DB.ATTRS:
		var ar := _row(c1)
		var al := _label(DB.ATTRS[a], S, UITheme.TEXT)
		al.custom_minimum_size.x = 170
		al.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ar.add_child(al)
		var v := int(spec.get(a, 5))
		var key := a
		_stepper(ar, str(v), func() -> void: spec[key] = int(spec.get(key, 5)) - 1,
			func() -> void: spec[key] = int(spec.get(key, 5)) + 1, v > DB.ATTR_MIN, v < DB.ATTR_MAX)
		_lbl(ar, DB.ATTR_DESC[a], UITheme.MUTED)
	# traços
	_head(c1, "Qualidades")
	_trait_rows(c1, true)
	_head(c3, "Defeitos (devolvem até %d)" % DB.TRAIT_REFUND_MAX)
	_trait_rows(c3, false)
	# habilidades
	_head(c2, "Habilidades iniciais (nível 1/2/3 = 2/5/9 pontos)")
	for g in DB.SKILL_GROUPS:
		for k: String in g[1]:
			var sr := _hbox(8)
			c2.add_child(sr)
			var sl := _label(DB.SKILLS[k], S, UITheme.TEXT)
			sl.custom_minimum_size.x = 220
			sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			sr.add_child(sl)
			var lv := _spec_skill(k)
			var sk := k
			_stepper(sr, str(lv), func() -> void:
				var n := _spec_skill(sk) - 1
				if n <= 0:
					spec["skills"].erase(sk)
				else:
					spec["skills"][sk] = n,
				func() -> void: spec["skills"][sk] = _spec_skill(sk) + 1, lv > 0, lv < DB.SKILL_START_MAX)
	# resumo
	var preview := SurvivorData.new()
	preview.forca = int(spec.get("forca", 5))
	preview.resist = int(spec.get("resist", 5))
	preview.traits.assign(spec.get("traits", []))
	for k in spec["skills"]:
		preview.skills[k]["lv"] = int(spec["skills"][k])
	_head(c3, "Resumo")
	_lbl(c3, "Carga confortável: %.1f kg\nEstamina máxima: %.0f\nDano corpo a corpo: %.0f" % [preview.carry_max(),
		preview.max_stamina(), preview.melee_damage()], UITheme.TEXT)
	var err := DB.creation_error(spec)
	var foot := _hbox(14)
	box.add_child(foot)
	var el := _label(err if err != "" else ("Enviando ficha..." if _creation_sent else "Morte é definitiva: escolha com cuidado."),
		S, UITheme.DANGER if err != "" else UITheme.MUTED)
	el.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	el.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(el)
	_btn(foot, "Sortear", _spec_change(func() -> void:
		var r := RandomNumberGenerator.new()
		r.randomize()
		spec = SurvivorData.random_spec(r)), not _creation_sent)
	var go := _btn(foot, "Começar", _submit_creation, err == "" and not _creation_sent)
	go.add_theme_font_size_override("font_size", L)


func _trait_rows(parent: VBoxContainer, positive: bool) -> void:
	var chosen: Array = spec["traits"]
	for t: String in DB.TRAITS:
		var def: Dictionary = DB.TRAITS[t]
		var c := int(def["custo"])
		if (c > 0) != positive:
			continue
		var on := t in chosen
		var tr := _hbox(10)
		parent.add_child(tr)
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = on
		b.text = ("%s %+d" % [def["nome"], -c]).to_upper()
		b.custom_minimum_size.x = 250
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = def["desc"]
		var tid := t
		b.toggled.connect(func(_v: bool) -> void:
			if tid in spec["traits"]:
				spec["traits"].erase(tid)
			else:
				spec["traits"].append(tid)
			_rebuild_creation.call_deferred())
		tr.add_child(b)
		var dl := _label(def["desc"], S, UITheme.MUTED)
		dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tr.add_child(dl)


## Janela de construção (B). Será redesenhada depois; por enquanto lista as estruturas.
var build_tab := "fundacao"


## Janela de construção: abas Fundação / Utilidades / Decoração, cartões com prévia, custo,
## requisitos e ferramentas; demolição e o resumo da rede de energia mais próxima.
func _win_build(p: Player) -> void:
	var box := window_box
	_clear(box)
	var d := p.data
	var tabs := _hbox(8)
	box.add_child(tabs)
	for t: Array in DB.BUILD_TABS:
		var tid: String = t[0]
		var b := _btn(tabs, t[1], func() -> void:
			build_tab = tid
			_rebuild_window())
		b.toggle_mode = true
		b.button_pressed = build_tab == tid
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(sp)
	_btn(tabs, "Demolir [X]", func() -> void:
		p.demolish = true
		p.build_kind = ""
		close_window())
	var hint := {"fundacao": "Pisos ocupam a célula; paredes, janelas e portas ficam nas BORDAS (aponte para o lado do quadrado).",
		"utilidades": "Objetos de base. Geradores, eólicos e baterias a até %d tiles formam uma rede que alimenta o que estiver perto." % int(World.GRID_LINK),
		"decoracao": "Móveis e iluminação. Luzes gastam energia da rede e só acendem no escuro."}
	_lbl(box, String(hint.get(build_tab, "")) + " Materiais em baús e sacos a até 2 tiles também contam. Botão direito/Esc cancela.", UITheme.MUTED)
	var info := _power_summary(p)
	if info != "":
		_lbl(box, info, UITheme.ACCENT)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(980, 520)
	box.add_child(sc)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(g)
	for k: String in DB.BUILDS:
		var def: Dictionary = DB.BUILDS[k]
		if String(def.get("aba", "")) != build_tab:
			continue
		g.add_child(_build_card(p, d, k, def))


func _build_card(p: Player, d: SurvivorData, k: String, def: Dictionary) -> Control:
	var card := _panel("card", 8, Vector4(10, 8, 10, 8))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.custom_minimum_size = Vector2(318, 0)
	var row := _hbox(10)
	card.add_child(row)
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(72, 72)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tex := GenArt.frame_texture(k, 0, 0)
	if def.has("chao"):
		# piso: o próprio ladrilho do chão
		var at := AtlasTexture.new()
		at.atlas = load(GenCatalog.GROUND_PATH)
		at.region = Rect2(int(def["chao"]) * World.TILE_W, 0, World.TILE_W, World.TILE_H)
		tex = at
	if tex == null:
		thumb.texture = UITheme.icon("martelo")
		thumb.self_modulate = UITheme.WARN
	else:
		thumb.texture = tex
	row.add_child(thumb)
	var col := _vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var tools2: Array = def.get("ferramentas", [])
	var meets := d.meets(def["req"])
	var ok := meets and d.missing_tools(tools2) == "" and _afford_local(def["custo"])
	col.add_child(_label(String(def["nome"]).to_upper(), S, UITheme.TEXT if ok else NO_COLOR))
	var extra := ""
	if def.has("gera"):
		extra = " · gera até %d W" % int(def["gera"]) if k != "eolico" else ""
	elif def.has("consome"):
		extra = " · consome %d W" % int(def["consome"])
	elif def.has("capacidade"):
		extra = " · guarda %d kJ" % int(float(def["capacidade"]) / 1000.0)
	var desc := String(def.get("desc", ""))
	if " W" in desc or "kJ" in desc:
		extra = ""
	_lbl(col, desc + extra, UITheme.MUTED)
	var req := "" if (def["req"] as Dictionary).is_empty() else " · exige " + DB.req_text(def["req"])
	var tl := "" if tools2.is_empty() else " · " + DB.tools_text(tools2)
	_lbl(col, DB.cost_text(def["custo"]) + req + tl, UITheme.TEXT if ok else UITheme.DANGER)
	var b := _btn(col, "Construir", func() -> void:
		p.build_kind = k
		p.demolish = false
		close_window(), meets)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	return card


## Resumo da rede de energia mais próxima do jogador.
func _power_summary(p: Player) -> String:
	var best: Structure = null
	var best_d := 1e9
	for n in get_tree().get_nodes_in_group("power"):
		var st := n as Structure
		var dd := st.position.distance_to(p.position)
		if dd < best_d and not st.grid.is_empty():
			best_d = dd
			best = st
	if best == null or best_d > World.GRID_LINK * World.HALF_W * 2.0:
		return ""
	var gr := best.grid
	var t := "REDE PRÓXIMA: produção %d W · consumo %d W" % [int(gr.get("gp", 0)), int(gr.get("gc", 0))]
	if int(gr.get("gb", -1)) >= 0:
		t += " · baterias %d%%" % int(gr["gb"])
	return t


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
	_btn(top, "Recarregar", _act(func() -> void: _player().act("use_item", ["bateria"])), d.count("bateria") > 0)
	# núcleo neural
	var nrow := _row(box)
	nrow.add_child(UITheme.icon_rect("cerebro", UITheme.MAGENTA, 44))
	var ninfo := _vbox(4)
	ninfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nrow.add_child(ninfo)
	var cap := d.neural_capacity()
	var over := d.general_count() > cap
	ninfo.add_child(_label("NÚCLEO NEURAL: %d / %d IMPLANTES GERAIS · ESTRESSE SINÁPTICO %d%%%s" % [d.general_count(), cap, int(d.synaptic),
		("  ·  SOBRECARGA!" if d.overloaded() else "")], S, UITheme.DANGER if d.overloaded() else UITheme.TEXT))
	_bar(ninfo, d.synaptic, 100.0, UITheme.DANGER if over else UITheme.MAGENTA, 540, 20)
	_lbl(box, "Sem processador neural o corpo aguenta 1 implante geral; mais que isso é rejeitado na cirurgia. Se a bateria acabar ou o processador falhar com vários implantes, vem a sobrecarga: espasmos, controle atrasado, HUD distorcido e nenhuma ação complexa.", UITheme.MUTED)
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
			_btn(row, "Remover (kit)", _act(func() -> void: _player().act("remove_implant", [slot])), d.count("kit_cirurgico") > 0)
		else:
			var found := false
			for id: String in DB.IMPLANTS:
				if DB.IMPLANTS[id]["slot"] == slot and d.count(id) > 0:
					found = true
					var def2: Dictionary = DB.IMPLANTS[id]
					var row2 := _row(box)
					row2.add_child(_item_icon(id, 48))
					var meets := d.meets(def2["req"])
					var reject := slot != "cerebro" and d.general_count() >= cap
					var txt := "%s (exige %s)\n%s" % [DB.item_name(id), DB.req_text(def2["req"]), def2["efeito"]]
					if reject:
						txt += "\nREJEIÇÃO: seu cérebro já está no limite (%d/%d). Instale um processador neural." % [d.general_count(), cap]
					elif not meets:
						txt += "\nRISCO: falha crítica ou morte na cirurgia!"
					_lbl(row2, txt, UITheme.TEXT if meets and not reject else UITheme.DANGER)
					_btn(row2, "Instalar", _act(func() -> void: _player().act("install", [id])), d.count("kit_cirurgico") > 0)
			if not found:
				_lbl(box, "Vazio. Encontre um implante e um kit cirúrgico.", UITheme.MUTED)


func _tab_vehicle(p: Player) -> void:
	var box := window_box
	_clear(box)
	var v := vehicle_node
	if v == null or not is_instance_valid(v):
		var best := 1e9
		for n in get_tree().get_nodes_in_group("vehicles"):
			var dd := (n as Node2D).position.distance_to(p.position)
			if dd < best and dd < 140.0:
				best = dd
				v = n
	if v == null or not is_instance_valid(v) or v.position.distance_to(p.position) > 160.0:
		_lbl(box, "Chegue perto de um veículo e aperte [E].", UITheme.MUTED)
		return
	var key := Game.world.key_of(v)
	var def := v.def()
	var top := _row(box)
	top.add_child(UITheme.icon_rect("carro", UITheme.ACCENT, 44))
	var info := _vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	info.add_child(_label("%s · %s · %d/%d LUGARES · PORTA-MALAS %.0f/%.0f L" % [String(def["nome"]).to_upper(),
		"TRANCADO" if v.locked else "DESTRANCADO", v.occupants().size(), int(def["lugares"]), v.trunk_volume(),
		float(def["porta_malas"])], S, UITheme.ACCENT))
	var bars_row := _hbox(14)
	info.add_child(bars_row)
	bars_row.add_child(_label("ENERGIA", S, UITheme.MUTED))
	_bar(bars_row, v.fuel, 100.0, UITheme.WARN, 240, 14)
	bars_row.add_child(_label("ESTADO", S, UITheme.MUTED))
	_bar(bars_row, v.cond, 100.0, OK_COLOR, 240, 14)
	var probs: Array[String] = []
	if v.locked:
		probs.append("Trancado: precisa de ligação direta (Mecânica 2).")
	if v.fuel <= 0.0:
		probs.append("Sem energia: abasteça com %s." % ("um galão de combustível" if String(def["energia"]) == "combustivel" else "baterias"))
	elif v.fuel < 15.0:
		probs.append("Energia baixa (%d%%)." % int(v.fuel))
	if v.cond <= 0.0:
		probs.append("Quebrado: não anda até ser consertado.")
	elif v.cond < 30.0:
		probs.append("Estado crítico (%d%%): perde velocidade. Conserte." % int(v.cond))
	if v.trunk_volume() >= float(def["porta_malas"]) - 0.5:
		probs.append("Porta-malas cheio.")
	_head(box, "Problemas")
	if probs.is_empty():
		_lbl(box, "Nenhum problema: o veículo está pronto.", OK_COLOR)
	for pr in probs:
		_lbl(box, "• " + pr, UITheme.WARN)
	var d := p.data
	var inside := Game.world.vehicle_of(p.peer) == v
	var row := _row(box)
	if inside:
		_btn(row, "Sair do veículo", _win_act(func() -> void: _player().act("vehicle", [key, "exit"])))
	else:
		_btn(row, "Dirigir", _win_act(func() -> void:
			_player().act("vehicle", [key, "drive"])
			close_window()), not v.locked and v.driver == 0 and v.seats_free() > 0)
		_btn(row, "Entrar como passageiro", _win_act(func() -> void:
			_player().act("vehicle", [key, "ride"])
			close_window()), not v.locked and v.seats_free() > 0 and int(def["lugares"]) > 1)
	_btn(row, "Porta-malas", func() -> void:
		close_window()
		open_loot(v))
	var energy := "galão de combustível" if String(def["energia"]) == "combustivel" else "bateria"
	var row2 := _row(box)
	_btn(row2, "Abastecer (%s)" % energy, _win_act(func() -> void: _player().act("vehicle", [key, "refuel"])),
		d.count("combustivel" if energy.begins_with("galão") else "bateria") > 0)
	_btn(row2, "Ligação direta", _win_act(func() -> void: _player().act("vehicle", [key, "hotwire"])), v.locked)
	_btn(row2, "Consertar (1 metal + 2 sucatas)", _win_act(func() -> void: _player().act("vehicle", [key, "repair"])), v.cond < 99.0)
	_lbl(box, "Veículos abandonados ficam trancados: a ligação direta exige Mecânica 2 (pode dar choque). A picape gasta combustível e leva até 4 pessoas; a moto elétrica é rápida e silenciosa, mas leva só o piloto e gasta baterias. Atropelar infectados desgasta o veículo; o motor faz barulho.", UITheme.MUTED)


## Painel da vila: pedido de socorro, comerciante e doações.
func _tab_village(p: Player) -> void:
	var box := window_box
	_clear(box)
	var w := Game.world
	var v: VillageData = null
	if village_open >= 0 and village_open < w.villages.size():
		v = w.villages[village_open]
	else:
		for vv in w.villages:
			if w.village_dist(vv, p.position) < 16.0:
				v = vv
	if v == null or w.village_dist(v, p.position) > 16.0:
		_lbl(box, "Vá até uma vila e fale com um morador [E].", UITheme.MUTED)
		return
	var d := p.data
	var top := _row(box)
	top.add_child(UITheme.icon_rect("pessoa", UITheme.ACCENT, 44))
	var info := _vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	info.add_child(_label("%s · %s · NÍVEL %d · POPULAÇÃO %d · REPUTAÇÃO DA EQUIPE %d" % [v.nome.to_upper(), v.status_text().to_upper(),
		v.level(), v.pop, int(v.rep)], S, UITheme.ACCENT))
	_bar(info, v.prosperity, 100.0, OK_COLOR, 400, 16)
	info.add_child(_label("Especialidade: %s · risco de infestação %d%%" % [{"comida": "comida", "sucata": "materiais", "medico": "remédios"}[v.specialty],
		int(v.infestation)], S, UITheme.MUTED))
	info.add_child(_label(_fence_text(v), S, UITheme.WARN if Game.world.fence_summary(v.id)[1] > 0 else UITheme.MUTED))
	if v.infested:
		_lbl(box, "Esta vila caiu. Limpe os infectados por perto para que os sobreviventes voltem.", UITheme.DANGER)
		return
	_head(box, "Pedido de socorro")
	if v.request.is_empty():
		_lbl(box, "Nenhum pedido agora.", UITheme.MUTED)
	else:
		var rr := _row(box)
		var left := maxf(0.0, float(v.request.get("prazo", 0.0)) - Game.play_time)
		_lbl(rr, "%s · prazo %s" % [v.request_text(), _fmt_time(left)], UITheme.WARN)
		var can := false
		for cat in v.request["need"]:
			if int(v.request["need"][cat]) <= 0:
				continue
			for inst in d.all_items():
				if VillageData.item_category(inst["id"]) == cat and not Items.spoiled(inst):
					can = true
		var vid := v.id
		_btn(rr, "Entregar", _win_act(func() -> void: _player().act("deliver", [vid])), can)
	_head(box, "Comerciante (paga com reputação)")
	for o in VillageData.OFFERS[v.specialty]:
		var row := _row(box)
		row.add_child(_item_icon(o[0], 40))
		var ok_lv := v.level() >= int(o[2])
		_lbl(row, "%s · %d de reputação%s" % [DB.item_name(o[0]), int(o[1]), "" if ok_lv else " · exige vila nível %d" % int(o[2])],
			UITheme.TEXT if ok_lv else NO_COLOR)
		var id: String = o[0]
		var vid2 := v.id
		_btn(row, "Trocar", _win_act(func() -> void: _player().act("buy", [vid2, id])), ok_lv and v.rep >= float(o[1]))
	_head(box, "Doar (sobe a reputação)")
	var any := false
	for inst in d.all_items():
		var cat := VillageData.item_category(inst["id"])
		if cat == "" or int(inst["u"]) == d.hand_u:
			continue
		any = true
		var row2 := _row(box)
		_item_line(row2, inst)
		var u := int(inst["u"])
		var n := int(inst["n"])
		var vid3 := v.id
		_btn(row2, "Doar (+%d)" % int(VillageData.DONATE_REP[cat] * n), _win_act(func() -> void: _player().act("donate", [vid3, u, n])))
	if not any:
		_lbl(box, "Você não tem comida, remédios ou materiais para doar.", UITheme.MUTED)



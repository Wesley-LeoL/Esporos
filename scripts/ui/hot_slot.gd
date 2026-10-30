class_name HotSlot
extends PanelContainer
## Espaço da barra rápida (hotbar). Guarda só o tipo do item (o item continua no
## inventário). Arraste um item do inventário para cá; clique ou tecla 1-5 usa; botão
## direito limpa.

const SIZE := 84

var hud: HUD
var index := 0
var item_id := ""
var count := 0
var _icon: TextureRect
var _num: Label
var _key: Label
var _selected := false


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UITheme.box("slot", 12, Vector4(4, 4, 4, 4)))
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 8
	_icon.offset_top = 8
	_icon.offset_right = -8
	_icon.offset_bottom = -12
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_icon)
	_key = Label.new()
	_key.text = str(index + 1)
	_key.add_theme_font_size_override("font_size", UITheme.FONT_S)
	_key.add_theme_color_override("font_color", UITheme.ACCENT)
	_key.position = Vector2(6, 0)
	_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_key)
	_num = Label.new()
	_num.add_theme_font_size_override("font_size", UITheme.FONT_S)
	_num.add_theme_color_override("font_color", UITheme.TEXT)
	_num.add_theme_color_override("font_shadow_color", Color.BLACK)
	_num.add_theme_constant_override("shadow_offset_x", 2)
	_num.add_theme_constant_override("shadow_offset_y", 2)
	_num.position = Vector2(SIZE - 34, SIZE - 30)
	_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_num)


func show_item(id: String, n: int) -> void:
	if id == item_id and n == count:
		return
	item_id = id
	count = n
	_icon.texture = GenArt.icon(id) if id != "" else null
	_icon.modulate = Color.WHITE if n > 0 else Color(1, 1, 1, 0.3)
	_num.text = str(n) if id != "" and n != 1 else ""
	tooltip_text = ("%s (x%d)\nTecla %d ou clique: escolher · escolhido, o clique usa · botão direito: tirar" % [DB.item_name(id), n, index + 1]) if id != "" else \
		"Arraste um item do inventário para cá"


func set_selected(v: bool) -> void:
	if v != _selected:
		_selected = v
		queue_redraw()


func _draw() -> void:
	if _selected:
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), UITheme.ACCENT, false, 3.0)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and item_id != "":
		# o primeiro clique escolhe; com o espaço já escolhido, o clique usa
		if hud.hot_sel == index and not HUD._is_weapon(item_id):
			hud.hot_use(index)
		else:
			hud.hot_select(index)
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT and item_id != "":
		hud.hot_set(index, "")
		accept_event()


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("slot") and not (data["slot"] as InvSlot).inst.is_empty()


func _drop_data(_at: Vector2, data: Variant) -> void:
	hud.hot_set(index, String((data["slot"] as InvSlot).inst["id"]))

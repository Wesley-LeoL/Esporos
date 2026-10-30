class_name InvSlot
extends PanelContainer
## Um espaço da grade de itens (inventário, recipiente aberto ou item vestido).
## Botão direito: menu de opções. Botão esquerdo: arrastar para organizar ou mover.
## Dois cliques: passa o item entre o recipiente aberto e o inventário.

const SIZE := 84

var hud: HUD
## "inv" (inventário), "loot" (recipiente aberto) ou "equip" (item vestido).
var side := "inv"
## inv: bolsos/mochila/coldre · equip: mascara/mochila/coldre · loot: chave do recipiente.
var cont := ""
var inst: Dictionary = {}
## Posição do item na lista do recipiente (-1 = espaço vazio no fim da grade).
var index := -1
var in_hand := false


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := UITheme.box("slot", 12, Vector4(4, 4, 4, 4))
	add_theme_stylebox_override("panel", sb)
	if inst.is_empty():
		modulate = Color(1, 1, 1, 0.55)
		return
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	var ic := TextureRect.new()
	ic.texture = GenArt.icon(inst["id"])
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 6
	ic.offset_top = 4
	ic.offset_right = -6
	ic.offset_bottom = -10
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ic)
	var n := int(inst["n"])
	if n > 1:
		var q := Label.new()
		q.text = str(n)
		q.add_theme_font_size_override("font_size", UITheme.FONT_S)
		q.add_theme_color_override("font_color", UITheme.TEXT)
		q.add_theme_color_override("font_shadow_color", Color.BLACK)
		q.add_theme_constant_override("shadow_offset_x", 2)
		q.add_theme_constant_override("shadow_offset_y", 2)
		q.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		q.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		q.grow_vertical = Control.GROW_DIRECTION_BEGIN
		q.position = Vector2(-4, -22)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(q)
	var frac := _state_fraction()
	if frac >= 0.0:
		var bar := ColorRect.new()
		bar.color = UITheme.DANGER if frac < 0.25 else (UITheme.WARN if frac < 0.5 else Color("#7fe0a0"))
		bar.position = Vector2(4, SIZE - 14)
		bar.size = Vector2((SIZE - 16) * clampf(frac, 0.02, 1.0), 4)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(bar)
	if in_hand:
		var mark := ColorRect.new()
		mark.color = UITheme.ACCENT
		mark.position = Vector2(4, 4)
		mark.size = Vector2(10, 10)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(mark)
	tooltip_text = _tooltip()


## Barrinha de estado: durabilidade, frescor ou carga (0-1); -1 = sem barra.
func _state_fraction() -> float:
	if inst.has("dur"):
		return float(inst["dur"]) / 100.0
	if inst.has("venc"):
		return Items.freshness(inst)
	if inst.has("carga"):
		return float(inst["carga"]) / 100.0
	return -1.0


func _tooltip() -> String:
	var t := Items.label(inst)
	var st := Items.state_text(inst)
	if st != "":
		t += "\n" + st
	t += "\n%.2f kg · %.1f L" % [Items.weight(inst), Items.volume(inst)]
	if in_hand:
		t += "\nNa mão"
	var dd := Items.def(inst["id"])
	if String(dd.get("tipo", "")) == "roupa":
		t += "\n" + Items.cloth_text(inst["id"])
	var desc := str(dd.get("desc", ""))
	if desc != "":
		t += "\n" + desc
	return t


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT and not inst.is_empty():
		hud.slot_menu(self)
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click and not inst.is_empty():
		hud.slot_double(self)
		accept_event()


func _get_drag_data(_at: Vector2) -> Variant:
	if inst.is_empty() or side == "equip":
		return null
	var prev := TextureRect.new()
	prev.texture = GenArt.icon(inst["id"])
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prev.custom_minimum_size = Vector2(56, 56)
	prev.size = Vector2(56, 56)
	prev.modulate.a = 0.8
	set_drag_preview(prev)
	return {"slot": self}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("slot") and data["slot"] != self and side != "equip"


func _drop_data(_at: Vector2, data: Variant) -> void:
	hud.slot_drop(data["slot"], self)

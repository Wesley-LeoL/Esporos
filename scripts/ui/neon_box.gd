class_name NeonBox
extends PanelContainer
## Caixa clicável no estilo normal da interface. Com 'pulse' (membro machucado), o contorno
## fica vermelho neon e pulsa. 'selected' destaca o contorno. Emite 'pressed' no clique
## esquerdo quando 'clickable'.

signal pressed

const NEON := Color("#ff2a4d")

var pulse := false
var selected := false
var clickable := false
var pad := Vector4(10, 8, 10, 8)
var _sb: StyleBoxFlat
var _phase := 0.0


func _ready() -> void:
	_sb = StyleBoxFlat.new()
	_sb.bg_color = UITheme.PANEL_SOFT
	_sb.set_border_width_all(2)
	_sb.set_corner_radius_all(2)
	_sb.content_margin_left = pad.x
	_sb.content_margin_top = pad.y
	_sb.content_margin_right = pad.z
	_sb.content_margin_bottom = pad.w
	_sb.anti_aliasing = false
	add_theme_stylebox_override("panel", _sb)
	mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_PASS
	if clickable:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_phase = randf() * 0.2
	_apply(1.0)
	set_process(pulse)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0 + _phase
	_apply(0.5 + 0.5 * sin(t * TAU * 1.2))


func _apply(k: float) -> void:
	if not pulse:
		_sb.border_color = UITheme.ACCENT if selected else UITheme.BORDER
		_sb.bg_color = UITheme.PANEL if selected else UITheme.PANEL_SOFT
		_sb.shadow_size = 0
	else:
		var c := NEON
		c.a = 0.45 + 0.55 * k
		_sb.set_border_width_all(3 if selected else 2)
		_sb.border_color = c.lerp(Color.WHITE, 0.25) if selected else c
		_sb.shadow_color = Color(NEON.r, NEON.g, NEON.b, 0.5 * k)
		_sb.shadow_size = int(round(2.0 + 7.0 * k))
		_sb.bg_color = UITheme.PANEL_SOFT.lerp(Color(0.35, 0.02, 0.08), 0.35 * k)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if clickable and event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()

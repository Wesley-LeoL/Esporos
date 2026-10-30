class_name NeonBox
extends PanelContainer
## Caixa com contorno neon (vermelho por padrão, estilo cyberpunk). 'pulse' faz o contorno
## e o brilho pulsarem (membro machucado); 'strength' é o brilho base (0-1). Emite 'pressed'
## no clique esquerdo quando 'clickable'.

signal pressed

const NEON := Color("#ff2a4d")
const BG := Color(0.07, 0.015, 0.035, 0.92)

var color := NEON
var pulse := false
var strength := 1.0
var selected := false
var clickable := false
var glow := true
var pad := Vector4(10, 8, 10, 8)
var _sb: StyleBoxFlat
var _phase := 0.0


func _ready() -> void:
	_sb = StyleBoxFlat.new()
	_sb.bg_color = BG
	_sb.set_border_width_all(3 if selected else 2)
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
	var c := color
	var a := strength * (0.45 + 0.55 * k) if pulse else strength
	c.a = clampf(a, 0.0, 1.0)
	if selected:
		c = c.lerp(Color.WHITE, 0.25)
	_sb.border_color = c
	if glow and a > 0.4:
		_sb.shadow_color = Color(color.r, color.g, color.b, 0.5 * a)
		_sb.shadow_size = int(round(2.0 + (8.0 * k if pulse else 4.0) * strength))
	else:
		_sb.shadow_size = 0
	if pulse:
		_sb.bg_color = BG.lerp(Color(color.r * 0.35, 0.0, color.b * 0.2, 0.95), 0.35 * k)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if clickable and event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()

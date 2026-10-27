class_name UITheme
extends RefCounted
## Paleta central da interface. Ajuste estes valores ao substituir a arte provisória.

const BACKGROUND := Color("#101820")
const PANEL := Color("#182630")
const PANEL_SOFT := Color("#202f39")
const BORDER := Color("#3d6570")
const TEXT := Color("#e4edf0")
const MUTED := Color("#91a6ad")
const ACCENT := Color("#66d9d0")
const CONTAMINATION := Color("#a6d65c")
const LIFE := Color("#ef6268")
const HUNGER := Color("#e9ad52")
const THIRST := Color("#59b9ed")


static func panel_style(color: Color = PANEL, radius: int = 5, border_color: Color = BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1)
	style.border_color = border_color
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


static func bar_fill(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(2)
	return style


static func bar_background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0b1116")
	style.set_corner_radius_all(2)
	return style


# ====================================================================== pixel art
## A interface é montada em resolução dupla: 1 unidade = 1 px da janela padrão (1600x900).
## A arte de assets/art/ui foi desenhada com cada pixel de desenho ocupando 2x2 (UI_SCALE).
const UI_SCALE := 2
const FONT_PATH := "res://assets/art/ui/fonts/Jersey10-Regular.ttf"
const FONT_S := 19  # tamanho nativo da grade da fonte (pixels finos)
const FONT_L := 38  # 2x (pixels grossos, como o mundo)
const FONT_XL := 76
const MAGENTA := Color("#e070ff")
const DANGER := Color("#ef6268")
const WARN := Color("#e9ad52")
const SHADOW_INK := Color(0.0, 0.02, 0.04, 0.85)
const SCANLINES := true

static var _font: FontFile
static var _theme: Theme
static var _icons: Texture2D
static var _icon_cache := {}


static func font() -> FontFile:
	if _font == null:
		_font = (load(FONT_PATH) as FontFile).duplicate()
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.hinting = TextServer.HINTING_NONE
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_font.fixed_size = FONT_S
		_font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	return _font


static func tex(name: String) -> Texture2D:
	return load("res://assets/art/ui/%s.png" % name)


## StyleBox de 9 fatias a partir de assets/art/ui/<name>.png. Margens em pixels da textura.
static func box(name: String, margin: int, content: Vector4 = Vector4(16, 12, 16, 12),
		tile := false) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex(name)
	sb.texture_margin_left = margin
	sb.texture_margin_top = margin
	sb.texture_margin_right = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	if tile:
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return sb


static func icon(name: String) -> Texture2D:
	if _icon_cache.has(name):
		return _icon_cache[name]
	if _icons == null:
		_icons = load(UICatalog.ICONS_PATH)
	var i: int = UICatalog.ICONS.get(name, 0)
	var at := AtlasTexture.new()
	at.atlas = _icons
	var c := UICatalog.ICON_CELL
	at.region = Rect2((i % UICatalog.ICON_COLS) * c, (i / UICatalog.ICON_COLS) * c, c, c)
	_icon_cache[name] = at
	return at


## Ícone tingido (os ícones são cinza; a cor multiplica e o contorno preto se mantém).
static func icon_rect(name: String, color: Color = TEXT, px: int = 32) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(name)
	r.self_modulate = color
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


## Tema completo da interface (fonte, rótulos, botões, abas, rolagem, campos).
static func build_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = FONT_S
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", SHADOW_INK)
	t.set_constant("shadow_offset_x", "Label", 2)
	t.set_constant("shadow_offset_y", "Label", 2)
	t.set_constant("line_spacing", "Label", 2)
	# botões
	var c := Vector4(14, 6, 14, 8)
	t.set_stylebox("normal", "Button", box("button_normal", 8, c))
	t.set_stylebox("hover", "Button", box("button_hover", 8, c))
	t.set_stylebox("pressed", "Button", box("button_pressed", 8, Vector4(14, 8, 14, 6)))
	t.set_stylebox("disabled", "Button", box("button_disabled", 8, c))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", Color("#e6fffb"))
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color("#4a5d64"))
	t.set_color("font_hover_pressed_color", "Button", Color("#e6fffb"))
	# abas
	var tc := Vector4(14, 8, 14, 6)
	t.set_stylebox("tab_unselected", "TabContainer", box("tab_normal", 8, tc))
	t.set_stylebox("tab_hovered", "TabContainer", box("tab_hover", 8, tc))
	t.set_stylebox("tab_selected", "TabContainer", box("tab_selected", 8, tc))
	t.set_stylebox("tab_disabled", "TabContainer", box("tab_normal", 8, tc))
	t.set_stylebox("tab_focus", "TabContainer", StyleBoxEmpty.new())
	t.set_stylebox("panel", "TabContainer", box("grid", 0, Vector4(20, 16, 12, 16), true))
	t.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())
	t.set_color("font_selected_color", "TabContainer", ACCENT)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", TEXT)
	t.set_constant("icon_separation", "TabContainer", 8)
	t.set_constant("side_margin", "TabContainer", 0)
	# rolagem (retângulos simples: ficam nítidos e garantem a largura mínima)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#0b1218")
	track.border_width_left = 2
	track.border_color = BORDER
	track.content_margin_left = 7
	track.content_margin_right = 7
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color("#2a6b66")
	grab.border_width_left = 2
	grab.border_width_right = 2
	grab.border_color = ACCENT
	grab.content_margin_top = 12
	grab.content_margin_bottom = 12
	var grab_hi := grab.duplicate() as StyleBoxFlat
	grab_hi.bg_color = ACCENT
	for item in ["scroll", "scroll_focus"]:
		t.set_stylebox(item, "VScrollBar", track)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_hi)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_hi)
	for icon_name in ["increment", "decrement", "increment_highlight", "decrement_highlight"]:
		t.set_icon(icon_name, "VScrollBar", ImageTexture.new())
	# painéis e barras simples
	t.set_stylebox("panel", "PanelContainer", box("panel", 16, Vector4(20, 16, 20, 16)))
	t.set_stylebox("background", "ProgressBar", bar_background())
	t.set_stylebox("fill", "ProgressBar", bar_fill(ACCENT))
	_theme = t
	return t

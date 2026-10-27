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

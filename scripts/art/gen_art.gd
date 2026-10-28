class_name GenArt
extends RefCounted
## Desenha quadros das folhas geradas por tools/gen_art.py (ver gen_catalog.gd).
## Os nós desenham no próprio _draw(), o que permite sombra por baixo e barras por cima.

static var _tex := {}
static var _icons: Texture2D
static var _icon_cache := {}


static func texture(sheet: String) -> Texture2D:
	if not _tex.has(sheet):
		_tex[sheet] = load(GenCatalog.SHEETS[sheet]["path"])
	return _tex[sheet]


## Desenha o quadro (linha, coluna) com a âncora (pé / centro da célula) em 'at'.
static func draw_frame(ci: CanvasItem, sheet: String, row: int, col: int,
		at: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE) -> void:
	var s: Dictionary = GenCatalog.SHEETS[sheet]
	var fw := float(s["fw"])
	var fh := float(s["fh"])
	var src := Rect2(col * fw, row * fh, fw, fh)
	var dst := Rect2(at.x - float(s["ox"]), at.y - float(s["oy"]), fw, fh)
	ci.draw_texture_rect_region(texture(sheet), dst, src, tint)


## Um quadro da folha como textura (miniaturas da janela de construção).
static func frame_texture(sheet: String, row: int = 0, col: int = 0) -> Texture2D:
	if not GenCatalog.SHEETS.has(sheet):
		return null
	var s: Dictionary = GenCatalog.SHEETS[sheet]
	var at := AtlasTexture.new()
	at.atlas = texture(sheet)
	at.region = Rect2(col * float(s["fw"]), row * float(s["fh"]), float(s["fw"]), float(s["fh"]))
	return at


static func icon(item: String) -> Texture2D:
	if not GenCatalog.ICONS.has(item):
		return null
	if _icon_cache.has(item):
		return _icon_cache[item]
	if _icons == null:
		_icons = load(GenCatalog.ICONS_PATH)
	var i: int = GenCatalog.ICONS[item]
	var at := AtlasTexture.new()
	at.atlas = _icons
	var sz := GenCatalog.ICON_SIZE
	at.region = Rect2((i % GenCatalog.ICON_COLS) * sz, (i / GenCatalog.ICON_COLS) * sz, sz, sz)
	_icon_cache[item] = at
	return at


## Índice de direção (enum Facing: L, SE, S, SO, O, NO, N, NE) para um vetor de tela.
## O vetor é "desachatado" (y*2) para medir o ângulo no plano do chão.
static func facing_of(screen_vec: Vector2) -> int:
	var iso := Vector2(screen_vec.x, screen_vec.y * 2.0)
	return posmod(int(round(iso.angle() / (PI / 4.0))), 8)

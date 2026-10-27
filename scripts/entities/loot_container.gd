class_name LootContainer
extends Node2D
## Caixa/armário com itens. Também usada para itens largados por infectados.

var id := -1
var table := "comum"
var items := {}
var temporary := false
var dirty := false
var village_id := -1


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("containers")


func prompt() -> String:
	if items.is_empty():
		return "Vazio"
	return "[E] Saquear (%d itens)" % _total()


func _total() -> int:
	var n := 0
	for k in items:
		n += int(items[k])
	return n


func interact(player: Player) -> void:
	if items.is_empty():
		return
	var parts: Array[String] = []
	for k in items:
		player.data.add_item(k, int(items[k]))
		parts.append("%dx %s" % [int(items[k]), DB.item_name(k)])
	Game.say("Você pegou: " + ", ".join(parts) + ".")
	items.clear()
	dirty = true
	if temporary:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var col := Color("#b08a3e")
	if table == "medico":
		col = Color("#d9d9d9")
	elif table == "tecnico":
		col = Color("#4a7bd1")
	if temporary:
		col = Color("#8a6a4a")
	if items.is_empty():
		col = col.darkened(0.55)
	draw_rect(Rect2(-8, -12, 16, 12), col)
	draw_rect(Rect2(-8, -12, 16, 3), col.lightened(0.25))
	if table == "medico" and not items.is_empty():
		draw_rect(Rect2(-1, -10, 2, 8), Color("#d03030"))
		draw_rect(Rect2(-4, -7, 8, 2), Color("#d03030"))

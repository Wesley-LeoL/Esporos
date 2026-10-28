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


## Só para sacos largados (replicados). As caixas do mapa são geradas igual em todos os
## peers e mudam pelo World.container_changed.
func setup_net() -> void:
	Net.make_sync(self, [".:items"], 0.2)


func prompt() -> String:
	if items.is_empty():
		return "Vazio"
	return "[E] Saquear (%d itens)" % _total()


func _total() -> int:
	var n := 0
	for k in items:
		n += int(items[k])
	return n


## Servidor.
func interact(player: Player) -> void:
	if items.is_empty():
		return
	var parts: Array[String] = []
	for k in items:
		player.data.add_item(k, int(items[k]))
		parts.append("%dx %s" % [int(items[k]), DB.item_name(k)])
	Game.tell(player.peer, "Você pegou: " + ", ".join(parts) + ".")
	items = {}
	if temporary:
		queue_free()
	else:
		var w: World = Game.world
		if w != null:
			w.container_changed(self)
		queue_redraw()


func _process(_delta: float) -> void:
	if temporary:
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# folha "containers": comum, médico, técnico (cheia/vazia) e o saco (índice 6)
	var col := 6
	if not temporary:
		col = ["comum", "medico", "tecnico"].find(table) * 2 + (1 if items.is_empty() else 0)
	GenArt.draw_frame(self, "containers", 0, col)

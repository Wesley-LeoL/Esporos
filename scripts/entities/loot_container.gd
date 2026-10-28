class_name LootContainer
extends Node2D
## Caixa/armário com itens. Também usada para itens largados por infectados.

var id := -1
var table := "comum"
var items: Array = []
var temporary := false
## Baú construído por um jogador (chave pela célula).
var chest := false
var cell := Vector2i.ZERO
var dirty := false
var village_id := -1


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("containers")


## Só para sacos largados (replicados). As caixas do mapa são geradas igual em todos os
## peers e mudam pelo World.container_changed.
func setup_net() -> void:
	Net.make_sync(self, [".:items"], 0.2)


func title() -> String:
	if chest:
		return "Baú"
	if temporary:
		return "Itens no chão"
	return {"comum": "Caixa", "medico": "Armário médico", "tecnico": "Caixa técnica"}.get(table, "Caixa")


func prompt() -> String:
	var n := Items.total_units(items)
	if chest:
		return "[E] Abrir baú (%d itens)" % n
	if items.is_empty():
		return "Vazio"
	return "[E] Revistar (%d itens)" % n


## Abrir é local (a janela de saque lê 'items'); a transferência vai pelo Player.act.
func interact(_player: Player) -> void:
	pass


func _process(_delta: float) -> void:
	if temporary:
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# folha "containers": comum, médico, técnico (cheia/vazia) e o saco (índice 6)
	var col := 6
	if chest:
		col = 1 if items.is_empty() else 0
		GenArt.draw_frame(self, "containers", 0, col, Vector2.ZERO, Color(0.85, 0.75, 0.6))
		return
	if not temporary:
		col = ["comum", "medico", "tecnico"].find(table) * 2 + (1 if items.is_empty() else 0)
	GenArt.draw_frame(self, "containers", 0, col)

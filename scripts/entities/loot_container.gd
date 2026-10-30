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
## Móvel que guarda os itens (geladeira, armário...; "" = caixa). Desenhado e com colisão pelo
## Prop filho; o recipiente só cuida dos itens.
var art := ""
var art_v := 0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("containers")
	if art != "":
		var pr := Prop.new()
		pr.art = art
		pr.variant = art_v
		add_child(pr)


## Só para sacos largados (replicados). As caixas do mapa são geradas igual em todos os
## peers e mudam pelo World.container_changed.
func setup_net() -> void:
	Net.make_sync(self, [".:items"], 0.2)


func title() -> String:
	if chest:
		return "Baú"
	if temporary:
		return "Itens no chão"
	if art != "" and DB.FURN_LOOT.has(art):
		return String(DB.FURN_LOOT[art][0])
	return {"comum": "Caixa", "medico": "Armário médico", "tecnico": "Caixa técnica"}.get(table, "Caixa")


func prompt() -> String:
	var n := Items.total_units(items)
	var w := Game.world
	if w != null and w.is_locked(self):
		return "[E] %s trancad%s: %s" % [title(), "a" if title().ends_with("a") else "o", _lock_hint(w)]
	if chest:
		return "[E] Abrir baú (%d itens)" % n
	if art != "":
		var nm := title().to_lower()
		return ("[E] Abrir %s (vazio)" % nm) if items.is_empty() else ("[E] Abrir %s" % nm)
	if items.is_empty():
		return "Vazio"
	return "[E] Revistar (%d itens)" % n


func _lock_hint(w: World) -> String:
	var p := w.local_player()
	if p == null or p.data == null:
		return "forçar"
	if not p.data.key_for(w.lock_of(self)).is_empty():
		return "usar a chave"
	return "forçar com gazua" if p.data.count("gazua") > 0 else "forçar (ou ache a chave)"


## Abrir é local (a janela de saque lê 'items'); a transferência vai pelo Player.act.
func interact(_player: Player) -> void:
	pass


func _process(_delta: float) -> void:
	if temporary:
		queue_redraw()


func _draw() -> void:
	if art != "":
		return
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

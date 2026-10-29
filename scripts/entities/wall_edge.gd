class_name WallEdge
extends StaticBody2D
## Parede numa BORDA de célula (estilo The Sims). A borda é (célula, d): d=0 é a borda
## entre a célula e a vizinha x+1 (lado de baixo-direita do losango); d=1, entre a célula
## e a vizinha y+1 (baixo-esquerda). O nó fica no meio da borda (chave de profundidade).
## Serve para as paredes que o jogador constrói (kind = id em DB.BUILDS) e para as dos
## prédios do mapa (kind = folha w_<material>_<variação>, map = true).
##
## Corte do The Sims: quando o jogador local está logo atrás da parede (ela fica entre ele
## e a câmera), a parede é desenhada baixa. Nos prédios do mapa isso só acontece com o
## prédio "aberto" (jogador dentro ou logo atrás; telhado escondido). A colisão não muda.

var kind := "parede_madeira"
var cell := Vector2i.ZERO
var dir := 0
var open := false
var map := false
## Prédio do mapa a que a parede pertence (-1 = construída pelo jogador).
var house_id := -1
var world: World
var low := false
var _shape: CollisionPolygon2D
var _cut_t := 0.0


## Meio da borda em relação ao centro da célula.
static func edge_offset(d: int) -> Vector2:
	return Vector2(World.HALF_W * 0.5, World.HALF_H * 0.5) if d == 0 else Vector2(-World.HALF_W * 0.5, World.HALF_H * 0.5)


## Pontas da borda em relação ao meio dela.
static func edge_ends(d: int) -> Array[Vector2]:
	var hw := World.HALF_W * 0.5
	var hh := World.HALF_H * 0.5
	if d == 0:
		return [Vector2(hw, -hh), Vector2(-hw, hh)]
	return [Vector2(hw, hh), Vector2(-hw, -hh)]


static func kind_is_door(k: String) -> bool:
	return k.ends_with("_porta") or String(DB.BUILDS.get(k, {}).get("tipo", "")) == "porta"


func is_door() -> bool:
	return kind_is_door(kind)


func key() -> Vector3i:
	return Vector3i(cell.x, cell.y, dir)


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("walls")
	if is_door():
		add_to_group("interactable")
	var ends := edge_ends(dir)
	var a := ends[0]
	var b := ends[1]
	var n := Vector2(0, 3.0)
	_shape = CollisionPolygon2D.new()
	_shape.polygon = PackedVector2Array([a - n, b - n, b + n, a + n])
	add_child(_shape)
	_cut_t = randf() * 0.1
	_apply_open()


func _apply_open() -> void:
	_shape.set_deferred("disabled", open)
	queue_redraw()


func prompt() -> String:
	if not is_door():
		return ""
	var nome := "porta"
	if DB.BUILDS.has(kind):
		nome = String(DB.BUILDS[kind]["nome"]).to_lower()
	return "[E] %s %s" % ["Fechar" if open else "Abrir", nome]


## Servidor.
func interact(_p: Player) -> void:
	if not is_door():
		return
	open = not open
	_apply_open()
	world.wall_changed(self)
	world.make_noise(position, 140.0)


func set_open(v: bool) -> void:
	if v != open:
		open = v
		_apply_open()


func _process(delta: float) -> void:
	_cut_t -= delta
	if _cut_t > 0.0:
		return
	_cut_t = 0.1
	var want := false
	var pl: Player = world.local_player() if world != null else null
	var house_ok := house_id < 0 or bool(world.house_open.get(house_id, false))
	if pl != null and pl.alive and house_ok:
		var off := position - pl.position
		# a parede está à frente (mais embaixo na tela) e perto do jogador
		if off.y > -6.0 and Vector2(off.x, off.y * 2.0).length() < 210.0:
			want = true
	if want != low:
		low = want
		queue_redraw()


func _draw() -> void:
	var col := (2 if (open and is_door()) else 0) + (1 if low else 0)
	if GenCatalog.SHEETS.has(kind):
		GenArt.draw_frame(self, kind, dir, mini(col, int(GenCatalog.SHEETS[kind]["cols"]) - 1))

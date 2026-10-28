class_name WallEdge
extends StaticBody2D
## Parede numa BORDA de célula (estilo The Sims). A borda é (célula, d): d=0 é a borda
## entre a célula e a vizinha x+1 (lado de baixo-direita do losango); d=1, entre a célula
## e a vizinha y+1 (baixo-esquerda). O nó fica no meio da borda (chave de profundidade).
## Portas e portões abrem e fecham ([E]); a colisão é só a faixa fina da borda.

var kind := "parede_madeira"
var cell := Vector2i.ZERO
var dir := 0
var open := false
var world: World
var _shape: CollisionPolygon2D
var _fade_t := 0.0


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


func is_door() -> bool:
	return String(DB.BUILDS.get(kind, {}).get("tipo", "")) == "porta"


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
	_apply_open()


func _apply_open() -> void:
	_shape.set_deferred("disabled", open)
	queue_redraw()


func prompt() -> String:
	if is_door():
		return "[E] %s %s" % ["Fechar" if open else "Abrir", DB.BUILDS[kind]["nome"].to_lower()]
	return ""


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
	# fica translúcida quando o jogador local está logo atrás dela
	_fade_t -= delta
	if _fade_t > 0.0:
		return
	_fade_t = 0.12
	var target := 1.0
	var pl: Player = world.local_player() if world != null else null
	if pl != null and pl.alive and kind != "meia_parede":
		var off := pl.position - position
		if off.y < 0.0 and off.y > -70.0 and absf(off.x) < 34.0:
			target = 0.35
	if not is_equal_approx(modulate.a, target):
		modulate.a = move_toward(modulate.a, target, 0.35)


func _draw() -> void:
	var col := 1 if (open and is_door()) else 0
	GenArt.draw_frame(self, kind, dir, col)

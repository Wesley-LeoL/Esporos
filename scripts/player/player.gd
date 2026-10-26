class_name Player
extends CharacterBody2D
## Jogador com movimentação isométrica em 8 direções.
## Visual provisório desenhado por código até os sprites em pixel art existirem.

# Ordem alinhada com o ângulo (0 = leste, sentido horário na tela).
enum Facing { E, SE, S, SW, W, NW, N, NE }

const FACING_NAMES := ["L", "SE", "S", "SO", "O", "NO", "N", "NE"]
const SPEED := 90.0
## Razão 2:1 da projeção isométrica: o movimento vertical na tela é achatado.
const ISO_Y_SCALE := 0.5

var facing: Facing = Facing.S


func _physics_process(_delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO:
		var new_facing := _vector_to_facing(input)
		if new_facing != facing:
			facing = new_facing
			queue_redraw()
	velocity = Vector2(input.x, input.y * ISO_Y_SCALE) * SPEED
	move_and_slide()


func _vector_to_facing(direction: Vector2) -> Facing:
	var index := int(round(direction.angle() / (PI / 4.0)))
	return posmod(index, 8) as Facing


func _draw() -> void:
	# Sombra (elipse achatada)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, ISO_Y_SCALE))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Corpo e cabeça
	draw_rect(Rect2(-5, -22, 10, 20), Color("#3fb8af"))
	draw_circle(Vector2(0, -26), 5.0, Color("#e8d5b7"))
	# Indicador de direção
	var dir := Vector2.from_angle(float(facing) * PI / 4.0)
	var tip := Vector2(dir.x, dir.y * ISO_Y_SCALE) * 14.0
	draw_line(Vector2(0, -12), Vector2(0, -12) + tip, Color("#ff5a5f"), 2.0)

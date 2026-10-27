class_name Player
extends CharacterBody2D
## Jogador: movimentação isométrica em 8 direções, combate corpo a corpo,
## interação e modo de construção. O estado de sobrevivência fica em SurvivorData.

signal died(data: SurvivorData, pos: Vector2)

enum Facing { E, SE, S, SW, W, NW, N, NE }

const FACING_NAMES := ["L", "SE", "S", "SO", "O", "NO", "N", "NE"]
const SPEED := 100.0
const ISO_Y_SCALE := 0.5

var data: SurvivorData
var world: World
var facing: Facing = Facing.S
var attack_cd := 0.0
var attack_flash := 0.0
var hurt_flash := 0.0
var build_kind := ""
var demolish := false
var nearby: Node = null
var camera: Camera2D
var spores: CPUParticles2D
var _dead := false
var _anim_t := 0.0
var _attack_anim := 0.0
var _moving := false
var _frame := -1


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("player")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	add_child(camera)
	spores = CPUParticles2D.new()
	spores.amount = 50
	spores.lifetime = 5.0
	spores.preprocess = 5.0
	spores.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	spores.emission_rect_extents = Vector2(540, 310)
	spores.direction = Vector2(1, 0.2)
	spores.spread = 60.0
	spores.gravity = Vector2.ZERO
	spores.initial_velocity_min = 4.0
	spores.initial_velocity_max = 12.0
	spores.scale_amount_min = 1.0
	spores.scale_amount_max = 2.5
	spores.color = Color(0.55, 0.9, 0.35, 0.5)
	spores.z_index = 40
	add_child(spores)


func is_dead() -> bool:
	return _dead


func respawn(new_data: SurvivorData, pos: Vector2) -> void:
	data = new_data
	position = pos
	_dead = false
	build_kind = ""
	demolish = false
	velocity = Vector2.ZERO
	visible = true
	collision_layer = 4
	camera.reset_smoothing()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if data == null or _dead:
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var moving := input != Vector2.ZERO
	_moving = moving
	if moving:
		var new_facing := _vector_to_facing(input)
		if new_facing != facing:
			facing = new_facing
			queue_redraw()
	velocity = Vector2(input.x, input.y * ISO_Y_SCALE) * SPEED * data.speed_mult()
	move_and_slide()

	attack_cd = maxf(0.0, attack_cd - delta)
	attack_flash = maxf(0.0, attack_flash - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta)

	var spore := world.spore_at(position)
	data.tick(delta, {"spore": spore, "moving": moving, "combat": attack_flash > 0.0,
		"purifier": world.purifier_near(position)})
	spores.modulate.a = clampf(spore * 1.6, 0.15, 1.0)
	if not data.alive:
		_dead = true
		collision_layer = 0
		visible = false
		died.emit(data, position)
		return

	_update_nearby()
	if build_kind == "" and not demolish and attack_cd <= 0.0 and Input.is_action_pressed("attack"):
		_attack()
	_attack_anim = maxf(0.0, _attack_anim - delta)
	_anim_t += delta
	var f := _anim_frame()
	if f != _frame or hurt_flash > 0.0:
		_frame = f
		queue_redraw()


## Coluna da folha do sobrevivente para o estado atual (ver GenCatalog.SURVIVOR_ANIMS).
func _anim_frame() -> int:
	var anims := GenCatalog.SURVIVOR_ANIMS
	if _attack_anim > 0.0:
		var a: Array = anims["attack"]
		var i := clampi(int((1.0 - _attack_anim / 0.33) * a.size()), 0, a.size() - 1)
		return a[i] + 100 * int(facing)
	if _moving:
		var w: Array = anims["walk"]
		return w[int(_anim_t * 8.0 * data.speed_mult()) % w.size()] + 100 * int(facing)
	var idle: Array = anims["idle"]
	return idle[int(_anim_t * 1.6) % idle.size()] + 100 * int(facing)


func _sheet() -> String:
	return "survivor_m%d_a%d_e%d" % [int(data.mask_on), int(data.implant_active("braco_d")),
		int(data.implant_active("olho"))]


func _unhandled_input(event: InputEvent) -> void:
	if data == null or _dead:
		return
	if event.is_action_pressed("interact") and nearby != null and is_instance_valid(nearby):
		nearby.interact(self)
	elif event.is_action_pressed("cancel"):
		build_kind = ""
		demolish = false
	elif event.is_action_pressed("demolish"):
		demolish = not demolish
		build_kind = ""
		Game.say("Modo demolição %s." % ("ligado (clique)" if demolish else "desligado"))
	elif event.is_action_pressed("save"):
		Game.save_game()
		Game.say("Jogo salvo.")
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			build_kind = ""
			demolish = false
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			var cell := world.mouse_cell()
			if build_kind != "":
				world.try_place(build_kind, cell, self)
			elif demolish:
				world.try_demolish(cell, self)


func _process(_delta: float) -> void:
	if data == null or _dead:
		world.ghost.hide_ghost()
		return
	if build_kind != "":
		var cell := world.mouse_cell()
		world.ghost.show_at(build_kind, world.ground.map_to_local(cell), world.can_place_at(build_kind, cell, self))
	elif demolish:
		var cell2 := world.mouse_cell()
		world.ghost.show_at("demolir", world.ground.map_to_local(cell2), world.structures.has(cell2) or world.build_layer.get_cell_source_id(cell2) != -1)
	else:
		world.ghost.hide_ghost()


func _update_nearby() -> void:
	var best: Node = null
	var best_d := 48.0
	for n in get_tree().get_nodes_in_group("interactable"):
		var node := n as Node2D
		var off := node.position - position
		var d := Vector2(off.x, off.y * 2.0).length()
		if d < best_d:
			best_d = d
			best = node
	nearby = best


func _attack() -> void:
	attack_cd = 0.55
	attack_flash = 0.15
	_attack_anim = 0.33
	var dir := Vector2.from_angle(float(facing) * PI / 4.0)
	var dmg := data.melee_damage()
	for n in get_tree().get_nodes_in_group("infected"):
		var e := n as Infected
		var off := e.position - position
		var iso := Vector2(off.x, off.y * 2.0)
		if iso.length() < 65.0 and iso.normalized().dot(dir) > 0.3:
			e.take_damage(dmg, self)
	queue_redraw()


func _vector_to_facing(direction: Vector2) -> Facing:
	var index := int(round(direction.angle() / (PI / 4.0)))
	return posmod(index, 8) as Facing


func _draw() -> void:
	if data == null:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, ISO_Y_SCALE))
	draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var tint := Color.WHITE
	if hurt_flash > 0.0:
		tint = Color(1.0, 0.45, 0.45)
	GenArt.draw_frame(self, _sheet(), int(facing), _frame % 100 if _frame >= 0 else 0, Vector2.ZERO, tint)

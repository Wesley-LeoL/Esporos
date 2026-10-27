class_name Infected
extends CharacterBody2D
## Infectado comum ou de elite. Elites "legado" são ex-sobreviventes mortos por
## infecção: guardam inventário e implantes e rondam o local da morte.

var hp := 40.0
var max_hp := 40.0
var speed := 48.0
var dmg := 9.0
var elite := false
var legacy := false
var legacy_name := ""
var home := Vector2.ZERO
var loot := {}
var implants := {}
var world: World
var player: Player

var _cd := 0.0
var _wander_t := 0.0
var _wander_dir := Vector2.ZERO
var _flash := 0.0
var _avoid_t := 0.0
var _avoid_sign := 1.0


func setup(is_elite: bool) -> void:
	elite = is_elite
	if elite:
		max_hp = 110.0
		speed = 74.0
		dmg = 17.0
	hp = max_hp


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("infected")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	if home == Vector2.ZERO:
		home = position
	_wander_dir = Vector2.from_angle(randf() * TAU)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_cd = maxf(0.0, _cd - delta)
	_flash = maxf(0.0, _flash - delta)
	_avoid_t = maxf(0.0, _avoid_t - delta)
	var p_alive := not player.is_dead() and player.data != null
	var to_p := player.position - position
	var iso := Vector2(to_p.x, to_p.y * 2.0)
	var dist := iso.length()
	var aggro := 270.0 if elite else 190.0
	var dir := Vector2.ZERO
	var mult := 1.0
	if p_alive and dist < aggro and not world.in_safe_zone(player.position):
		dir = iso.normalized()
	else:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(1.5, 4.0)
			_wander_dir = Vector2.from_angle(randf() * TAU) if randf() < 0.7 else Vector2.ZERO
			if legacy:
				var back := Vector2(home.x - position.x, (home.y - position.y) * 2.0)
				if back.length() > 90.0:
					_wander_dir = back.normalized()
		dir = _wander_dir
		mult = 0.35
	if _avoid_t > 0.0:
		dir = dir.rotated(_avoid_sign * 1.1)
	velocity = Vector2(dir.x, dir.y * 0.5) * speed * mult
	move_and_slide()
	if get_slide_collision_count() > 0 and dir != Vector2.ZERO and _avoid_t <= 0.0:
		_avoid_t = 0.6
		_avoid_sign = 1.0 if randf() < 0.5 else -1.0
	if p_alive and dist < 22.0 and _cd <= 0.0:
		_attack()


func _attack() -> void:
	_cd = 0.9 if elite else 1.15
	var limb: String = ["torso", "torso", "braco_e", "braco_d", "perna_e", "perna_d", "cabeca"][randi() % 7]
	player.data.damage_limb(limb, dmg * randf_range(0.7, 1.3))
	player.data.pathogen = minf(100.0, player.data.pathogen + (4.0 if elite else 2.5))
	player.hurt_flash = 0.25


func take_damage(amount: float, _from: Node2D) -> void:
	hp -= amount
	_flash = 0.15
	var off := position - _from.position
	position += Vector2(off.x, off.y * 0.5).normalized() * 5.0
	queue_redraw()
	if hp <= 0.0:
		_die()


func _die() -> void:
	var drops := loot.duplicate()
	for slot in implants:
		var id: String = implants[slot]["id"]
		drops[id] = int(drops.get(id, 0)) + 1
	if not elite and randf() < 0.18:
		drops = DB.roll_loot("comum", 1, world.rng)
	world.drop_loot(position, drops)
	if legacy:
		Game.say("Você abateu o infectado de elite que era %s." % legacy_name)
	queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var body := Color("#6b7a4a") if not elite else Color("#7a2f5a")
	var skin := Color("#9ab07a") if not elite else Color("#b07a9a")
	if _flash > 0.0:
		body = Color.WHITE
	var wob := sin(Time.get_ticks_msec() * 0.008 + get_instance_id() % 7) * 1.5
	draw_rect(Rect2(-5 + wob, -22, 10, 20), body)
	draw_circle(Vector2(wob, -26), 5.0, skin)
	draw_rect(Rect2(-3 + wob, -27, 2, 2), Color("#ff3b3b"))
	draw_rect(Rect2(1 + wob, -27, 2, 2), Color("#ff3b3b"))
	if elite:
		draw_rect(Rect2(5 + wob, -20, 3, 9), Color("#9aa7b5"))
		if not implants.is_empty():
			draw_rect(Rect2(-1 + wob, -30, 4, 2), Color("#52e6ff"))
	if hp < max_hp:
		draw_rect(Rect2(-8, -36, 16, 2), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-8, -36, 16.0 * clampf(hp / max_hp, 0.0, 1.0), 2), Color("#ff5a5f"))

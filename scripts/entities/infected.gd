class_name Infected
extends CharacterBody2D
## Infectado comum ou de elite. Elites "legado" são ex-sobreviventes mortos por
## infecção: guardam inventário e implantes e rondam o local da morte.

var hp := 40.0
var max_hp := 40.0
var speed := 60.0
var dmg := 9.0
var elite := false
var legacy := false
var legacy_name := ""
var home := Vector2.ZERO
var loot: Array = []
var implants := {}
var world: World

# ---- replicado pelo servidor (os clientes só desenham)
var net_pos := Vector2.ZERO
var facing := 2
var atk_seq := 0

var _cd := 0.0
var _wander_t := 0.0
var _wander_dir := Vector2.ZERO
var _flash := 0.0
var _avoid_t := 0.0
var _avoid_sign := 1.0
var _anim_t := 0.0
var _atk_anim := 0.0
var _seen_atk := 0
var _seen_hp := -1.0


func setup(is_elite: bool) -> void:
	elite = is_elite
	if elite:
		max_hp = 110.0
		speed = 92.0
		dmg = 17.0
	hp = max_hp


## Sincronizador (autoridade: servidor). Chamado antes de entrar na árvore.
func setup_net() -> void:
	net_pos = position
	Net.make_sync(self, [".:net_pos", ".:facing", ".:atk_seq", ".:hp"], 0.05)


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("infected")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	if home == Vector2.ZERO:
		home = position
	net_pos = position
	_seen_hp = hp
	_wander_dir = Vector2.from_angle(randf() * TAU)


func _physics_process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	_atk_anim = maxf(0.0, _atk_anim - delta)
	if atk_seq != _seen_atk:
		_seen_atk = atk_seq
		_atk_anim = 0.4
	if hp < _seen_hp - 0.01:
		_flash = 0.15
	_seen_hp = hp
	if not Net.is_server():
		var before := position
		if position.distance_to(net_pos) > 160.0:
			position = net_pos
		else:
			position = position.lerp(net_pos, clampf(delta * 12.0, 0.0, 1.0))
		var moved := position - before
		if moved.length() > 0.05:
			_anim_t += moved.length() / 9.0
		return
	_server_ai(delta)


## IA (só no servidor): persegue o jogador vivo mais próximo fora da zona segura.
func _server_ai(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)
	_avoid_t = maxf(0.0, _avoid_t - delta)
	var aggro := 340.0 if elite else 240.0
	var target: Player = world.nearest_player(position, aggro)
	if target != null and world.in_safe_zone(target.net_pos):
		target = null
	var dir := Vector2.ZERO
	var mult := 1.0
	var dist := 1e9
	if target != null:
		var to_p := target.net_pos - position
		var iso := Vector2(to_p.x, to_p.y * 2.0)
		dist = iso.length()
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
	net_pos = position
	if velocity.length() > 4.0:
		facing = GenArt.facing_of(velocity)
		_anim_t += delta * velocity.length() / 9.0
	if get_slide_collision_count() > 0 and dir != Vector2.ZERO and _avoid_t <= 0.0:
		_avoid_t = 0.6
		_avoid_sign = 1.0 if randf() < 0.5 else -1.0
	if target != null and dist < 28.0 and _cd <= 0.0:
		_attack(target)


func _attack(target: Player) -> void:
	_cd = 0.9 if elite else 1.15
	atk_seq += 1
	facing = GenArt.facing_of(target.net_pos - position)
	var limb: String = ["torso", "torso", "braco_e", "braco_d", "perna_e", "perna_d", "cabeca"][randi() % 7]
	target.server_hurt(limb, dmg * randf_range(0.7, 1.3), 4.0 if elite else 2.5)


## Servidor: dano de um jogador ou de uma torre.
func take_damage(amount: float, from: Node2D) -> void:
	if not Net.is_server():
		return
	hp -= amount
	var src := from.position
	if from is Player and not (from as Player).is_local():
		src = (from as Player).net_pos
	var off := position - src
	position += Vector2(off.x, off.y * 0.5).normalized() * 5.0
	net_pos = position
	if hp <= 0.0:
		_die()


func _die() -> void:
	var drops: Array = loot.duplicate(true)
	for slot in implants:
		Items.add(drops, {"id": String(implants[slot]["id"]), "n": 1})
	if not elite and randf() < 0.18:
		drops = DB.roll_loot("comum", 1, world.rng)
	world.drop_loot(position, drops)
	if legacy:
		Game.say_all("O infectado de elite que era %s foi abatido." % legacy_name)
	queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 11.0 if not elite else 13.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var anims := GenCatalog.INFECTED_ANIMS
	var col := 0
	if _atk_anim > 0.0:
		var a: Array = anims["attack"]
		col = a[0] if _atk_anim > 0.2 else a[1]
	else:
		var w: Array = anims["walk"]
		col = w[int(_anim_t) % w.size()]
	var tint := Color(2.2, 2.2, 2.2) if _flash > 0.0 else Color.WHITE
	GenArt.draw_frame(self, "elite" if elite else "infected", facing, col, Vector2.ZERO, tint)
	if hp < max_hp:
		var top := -50.0 if elite else -42.0
		draw_rect(Rect2(-9, top, 18, 3), Color(0, 0, 0, 0.75))
		draw_rect(Rect2(-9, top, 18.0 * clampf(hp / max_hp, 0.0, 1.0), 3), Color("#ff5a5f"))

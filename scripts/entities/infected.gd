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
## Barulho ouvido (vai investigar) e memória do último alvo visto.
var _heard_pos := Vector2.ZERO
var _heard_t := 0.0
var _target: Node2D
var _chase_t := 0.0
## Horda: vila que este infectado foi atacar (-1 = nenhuma).
var siege_vid := -1
## Muro que está batendo agora (chave da borda) e o tempo até repensar o caminho.
var _wall_k := Vector3i(0, 0, -1)
var _path_t := 0.0


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


## Servidor: ouviu um barulho (passos, tiro, construção) e vai investigar.
func hear(pos: Vector2) -> void:
	if _target != null and _chase_t > 0.0:
		return
	_heard_pos = pos
	_heard_t = 10.0


## Quem este infectado enxerga agora (jogador ou morador de vila). A distância de visão
## do jogador depende de quanto ele se expõe (agachado, correndo, lanterna, Furtividade).
## Gente atrás da cerca de uma vila também é vista: aí o infectado tenta entrar.
func _pick_target(aggro: float) -> Node2D:
	var best: Node2D = null
	var best_d := 1e9
	for p in world.alive_players():
		if p.data == null:
			continue
		var off := p.net_pos - position
		var d := Vector2(off.x, off.y * 2.0).length()
		var sight := aggro * p.data.visibility(p.sprinting, p.sneaking) * world.sight_factor(p)
		if p == _target and _chase_t > 0.0:
			sight *= 1.6
		if d < sight and d < best_d:
			best_d = d
			best = p
	for n in get_tree().get_nodes_in_group("npcs"):
		var npc := n as Npc
		if npc.hp <= 0.0:
			continue
		var off2 := npc.position - position
		var d2 := Vector2(off2.x, off2.y * 2.0).length()
		if d2 < aggro * 0.9 and d2 < best_d:
			best_d = d2
			best = npc
	return best


static func _pos_of(n: Node2D) -> Vector2:
	return (n as Player).net_pos if n is Player else n.position


## IA (só no servidor): persegue quem enxerga, investiga barulhos ou vaga. Se o alvo está
## atrás da cerca de uma vila, vai até uma brecha ou um portão aberto; sem passagem, bate
## no trecho de muro mais perto até derrubar.
func _server_ai(delta: float) -> void:
	if _target != null and not is_instance_valid(_target):
		_target = null
	_cd = maxf(0.0, _cd - delta)
	_avoid_t = maxf(0.0, _avoid_t - delta)
	_chase_t = maxf(0.0, _chase_t - delta)
	_heard_t = maxf(0.0, _heard_t - delta)
	_path_t = maxf(0.0, _path_t - delta)
	var aggro := 340.0 if elite else 240.0
	var target: Node2D = _pick_target(aggro)
	if target != null:
		_target = target
		_chase_t = 4.0
	elif _target != null and is_instance_valid(_target) and _chase_t <= 0.0:
		# perdeu de vista: vai até onde viu por último
		_heard_pos = _pos_of(_target)
		_heard_t = 6.0
		_target = null
	var goal := Vector2.INF
	var mult := 1.0
	if target != null:
		goal = _pos_of(target)
	elif _heard_t > 0.0:
		goal = _heard_pos
		mult = 0.75
	elif siege_vid >= 0:
		goal = world.ground.map_to_local(world.villages[siege_vid].cell)
		mult = 0.85
	# cerca no caminho?
	var hit_wall := false
	if goal != Vector2.INF:
		var vid := world.village_at(goal)
		if vid >= 0 and world.village_at(position) != vid:
			if _path_t <= 0.0:
				_path_t = 1.0
				_wall_k = world.fence_goal(vid, position)
			if _wall_k.z >= 0:
				var wp := world.edge_pos(_wall_k)
				if world.fence_open(_wall_k):
					# brecha ou portão aberto: passa por ela
					var into := world.ground.map_to_local(world.villages[vid].cell)
					goal = wp if position.distance_to(wp) > 14.0 else into
				else:
					goal = wp
					if world.edge_dist(_wall_k, position) < 26.0:
						hit_wall = true
	var dir := Vector2.ZERO
	var dist := 1e9
	if goal != Vector2.INF:
		var to := goal - position
		var iso := Vector2(to.x, to.y * 2.0)
		dist = iso.length()
		if dist < 6.0 and target == null:
			_heard_t = 0.0
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
	if hit_wall:
		dir = Vector2.ZERO
		if _cd <= 0.0:
			_cd = 1.0 if elite else 1.3
			atk_seq += 1
			facing = GenArt.facing_of(world.edge_pos(_wall_k) - position)
			world.damage_fence(_wall_k, dmg * (1.0 if elite else 0.6))
	if _avoid_t > 0.0:
		dir = dir.rotated(_avoid_sign * 1.1)
	velocity = Vector2(dir.x, dir.y * 0.5) * speed * mult
	move_and_slide()
	net_pos = position
	if velocity.length() > 4.0:
		facing = GenArt.facing_of(velocity)
		_anim_t += delta * velocity.length() / 9.0
	if get_slide_collision_count() > 0 and dir != Vector2.ZERO and _avoid_t <= 0.0 and not hit_wall:
		_avoid_t = 0.6
		_avoid_sign = 1.0 if randf() < 0.5 else -1.0
	if target != null and _cd <= 0.0:
		var tp := _pos_of(target) - position
		if Vector2(tp.x, tp.y * 2.0).length() < 28.0:
			_attack(target)


func _attack(target: Node2D) -> void:
	_cd = 0.9 if elite else 1.15
	atk_seq += 1
	facing = GenArt.facing_of(_pos_of(target) - position)
	if target is Npc:
		(target as Npc).take_hit(dmg * randf_range(0.8, 1.3), self)
		return
	var limb: String = ["torso", "torso", "braco_e", "braco_d", "perna_e", "perna_d", "cabeca"][randi() % 7]
	(target as Player).server_hurt(limb, dmg * randf_range(0.7, 1.3), 4.0 if elite else 2.5)


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
	world.on_infected_killed(position)
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

class_name Npc
extends CharacterBody2D
## Morador de uma vila viva (fase 7). Papéis: "morador" (vaga pela vila), "guarda" (ataca
## infectados que chegam perto) e "comerciante" (troca itens por reputação). [E] abre o
## painel da vila. O servidor move; os clientes interpolam.

const ROLE_NAMES := {"morador": "Morador", "guarda": "Guarda", "comerciante": "Comerciante"}
const TINTS := {"morador": Color(0.85, 0.82, 0.78), "guarda": Color(0.7, 0.85, 1.0), "comerciante": Color(1.0, 0.85, 0.55)}

var village_id := 0
var role := "morador"
var nome := ""
var home := Vector2.ZERO
var world: World

# ---- replicado pelo servidor
var net_pos := Vector2.ZERO
var facing := 2
var moving := false
var atk_seq := 0

var _wander_t := 0.0
var _goal := Vector2.ZERO
var _cd := 0.0
var _anim_t := 0.0
var _atk_anim := 0.0
var _seen_atk := 0


func setup_net() -> void:
	net_pos = position
	Net.make_sync(self, [".:net_pos", ".:facing", ".:moving", ".:atk_seq"], 0.1)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("npcs")
	add_to_group("interactable")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	if home == Vector2.ZERO:
		home = position
	_goal = position
	net_pos = position


func prompt() -> String:
	var v := _village()
	return "[E] Falar com %s (%s · %s)" % [nome, ROLE_NAMES[role].to_lower(), v.nome if v != null else "?"]


func _village() -> VillageData:
	if world == null or village_id < 0 or village_id >= world.villages.size():
		return null
	return world.villages[village_id]


## A conversa é local (painel da vila no HUD); as trocas vão pelo Player.act.
func interact(_p: Player) -> void:
	pass


func _physics_process(delta: float) -> void:
	_atk_anim = maxf(0.0, _atk_anim - delta)
	if atk_seq != _seen_atk:
		_seen_atk = atk_seq
		_atk_anim = 0.4
	if not Net.is_server():
		var before := position
		position = position.lerp(net_pos, clampf(delta * 10.0, 0.0, 1.0))
		if (position - before).length() > 0.05:
			_anim_t += (position - before).length() / 9.0
		queue_redraw()
		return
	_server_ai(delta)
	queue_redraw()


func _server_ai(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)
	var target: Infected = null
	if role == "guarda":
		var best := 170.0
		for n in get_tree().get_nodes_in_group("infected"):
			var e := n as Infected
			var off := e.position - position
			var d := Vector2(off.x, off.y * 2.0).length()
			var from_home := Vector2(e.position.x - home.x, (e.position.y - home.y) * 2.0).length()
			if d < best and from_home < 420.0:
				best = d
				target = e
	var speed := 38.0
	if target != null:
		_goal = target.position
		speed = 70.0
		var off2 := target.position - position
		if Vector2(off2.x, off2.y * 2.0).length() < 30.0 and _cd <= 0.0:
			_cd = 1.0
			atk_seq += 1
			facing = GenArt.facing_of(off2)
			target.take_damage(18.0, self)
	else:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(2.0, 6.0)
			var r := 150.0 if role != "comerciante" else 40.0
			_goal = home + Vector2(randf_range(-r, r), randf_range(-r, r) * 0.5)
	var to := _goal - position
	var iso := Vector2(to.x, to.y * 2.0)
	moving = iso.length() > 8.0
	if moving:
		var dir := iso.normalized()
		velocity = Vector2(dir.x, dir.y * 0.5) * speed
		move_and_slide()
		facing = GenArt.facing_of(velocity)
		_anim_t += delta * speed / 9.0
		if get_slide_collision_count() > 0:
			_goal = position
	net_pos = position


func _frame() -> int:
	var anims := GenCatalog.SURVIVOR_ANIMS
	if _atk_anim > 0.0:
		var a: Array = anims["attack"]
		return a[clampi(int((1.0 - _atk_anim / 0.4) * a.size()), 0, a.size() - 1)]
	if moving:
		var w: Array = anims["walk"]
		return w[int(_anim_t) % w.size()]
	var idle: Array = anims["idle"]
	return idle[int(Time.get_ticks_msec() / 600) % idle.size()]


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	GenArt.draw_frame(self, "survivor_m0_a0_e0", facing, _frame(), Vector2.ZERO, TINTS.get(role, Color.WHITE))
	if role != "morador":
		draw_set_transform(Vector2(0, -50), 0.0, Vector2(0.5, 0.5))
		var f := UITheme.font()
		var label: String = String(ROLE_NAMES[role]).to_upper()
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_S).x
		draw_string(f, Vector2(-w / 2.0 + 2, 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_S, Color(0, 0, 0, 0.8))
		draw_string(f, Vector2(-w / 2.0, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_S, UITheme.WARN)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

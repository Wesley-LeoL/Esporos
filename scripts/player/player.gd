class_name Player
extends CharacterBody2D
## Jogador em rede. Cada personagem tem um dono (peer):
## - o DONO lê o teclado, move o personagem e replica posição, direção e animação;
## - o SERVIDOR é dono do SurvivorData (vitais, inventário, implantes), simula o
##   metabolismo e executa as ações pedidas (usar item, construir, atacar, interagir),
##   devolvendo ao dono uma cópia do estado a cada 0,2 s;
## - os outros jogadores só veem posição, animação e aparência.
## No jogo solo o jogador local é dono e servidor ao mesmo tempo.

enum Facing { E, SE, S, SW, W, NW, N, NE }

const FACING_NAMES := ["L", "SE", "S", "SO", "O", "NO", "N", "NE"]
const SPEED := 100.0
const ISO_Y_SCALE := 0.5
const ACTIONS := ["use_item", "treat", "craft", "install", "maintain", "interact", "build", "demolish",
	"attack", "save", "move", "drop", "repair", "unwear", "take", "take_all", "store"]

## Dono deste personagem (id do peer) e nome do jogador.
var peer := 1
var nome := ""
## Servidor: estado autoritativo. Dono: cópia recebida do servidor. Outros: null.
var data: SurvivorData
var world: World

# ---- replicado pelo dono
var net_pos := Vector2.ZERO
var facing: int = Facing.S
var moving := false
var attack_seq := 0
# ---- replicado pelo servidor
var look := 1  # bits: 1 máscara, 2 braço cibernético, 4 olho (HUD)
var alive := true
var hurt_seq := 0

# ---- locais
var attack_cd := 0.0
var attack_flash := 0.0
var hurt_flash := 0.0
var build_kind := ""
var demolish := false
var nearby: Node = null
var camera: Camera2D
var spores: CPUParticles2D
var respawn_t := -1.0
var _anim_t := 0.0
var _attack_anim := 0.0
var _frame := -1
var _seen_attack := 0
var _seen_hurt := 0
var _sync_t := 0.0
var _last_sync := ""
var _was_alive := true

signal data_changed


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
	net_pos = position
	if is_local():
		camera = Camera2D.new()
		camera.position_smoothing_enabled = true
		add_child(camera)
		camera.make_current()
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


## Sincronizadores: um do dono (movimento) e um do servidor (aparência e estado).
## Chamado pela função de spawn antes de o nó entrar na árvore.
func setup_net(owner_peer: int) -> void:
	peer = owner_peer
	var own := Net.make_sync(self, [".:net_pos", ".:facing", ".:moving", ".:attack_seq"], 0.05)
	own.name = "SyncDono"
	var srv := Net.make_sync(self, [".:look", ".:alive", ".:hurt_seq", ".:nome"], 0.1)
	srv.name = "SyncServidor"
	# a autoridade é aplicada depois de criar os filhos (set_multiplayer_authority é recursivo)
	set_multiplayer_authority(owner_peer)
	srv.set_multiplayer_authority(1)


func is_local() -> bool:
	return peer == Net.my_id()


func is_dead() -> bool:
	return not alive


# ------------------------------------------------------------------ simulação
func _physics_process(delta: float) -> void:
	if is_local() and alive:
		_local_control(delta)
	elif not is_local():
		# posição de quem não é o dono: interpolação até a última posição recebida
		if position.distance_to(net_pos) > 160.0:
			position = net_pos
		else:
			position = position.lerp(net_pos, clampf(delta * 14.0, 0.0, 1.0))
	if Net.is_server():
		_server_tick(delta)
	_animate(delta)


func _local_control(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var console_open := Game.console != null and Game.console.is_open()
	var menu_open := Game.hud != null and Game.hud.menu_root.visible
	if console_open or menu_open:
		input = Vector2.ZERO
	moving = input != Vector2.ZERO
	if moving:
		facing = _vector_to_facing(input)
	var mult := data.speed_mult() if data != null else 1.0
	velocity = Vector2(input.x, input.y * ISO_Y_SCALE) * SPEED * mult
	move_and_slide()
	net_pos = position
	attack_cd = maxf(0.0, attack_cd - delta)
	_update_nearby()
	if build_kind == "" and not demolish and attack_cd <= 0.0 and Input.is_action_pressed("attack") \
			and not console_open and not menu_open:
		attack_cd = 0.55
		attack_seq += 1
		act("attack", [facing])
	if spores != null and world != null:
		spores.modulate.a = clampf(world.spore_at(position) * 1.6, 0.15, 1.0)


func _server_tick(delta: float) -> void:
	if data == null:
		return
	attack_flash = maxf(0.0, attack_flash - delta)
	if alive:
		var pos := position if is_local() else net_pos
		data.tick(delta, {"spore": world.spore_at(pos), "moving": moving, "combat": attack_flash > 0.0,
			"purifier": world.purifier_near(pos)})
		look = int(data.has_mask()) | (2 if data.implant_active("braco_d") else 0) | (4 if data.implant_active("olho") else 0)
		if not data.alive:
			alive = false
			world.on_player_died(self)
	elif respawn_t > 0.0:
		respawn_t -= delta
		if respawn_t <= 0.0:
			world.respawn_player(self)
	# cópia do estado para o dono (só quando mudou)
	_sync_t -= delta
	if _sync_t <= 0.0 and not is_local():
		_sync_t = 0.2
		var d := data.to_dict()
		var key := str(d.hash())
		if key != _last_sync:
			_last_sync = key
			_receive_data.rpc_id(peer, d)


func _animate(delta: float) -> void:
	if hurt_seq != _seen_hurt:
		_seen_hurt = hurt_seq
		hurt_flash = 0.25
	if attack_seq != _seen_attack:
		_seen_attack = attack_seq
		_attack_anim = 0.33
	hurt_flash = maxf(0.0, hurt_flash - delta)
	_attack_anim = maxf(0.0, _attack_anim - delta)
	_anim_t += delta
	visible = alive
	collision_layer = 4 if alive else 0
	if _was_alive != alive:
		_was_alive = alive
		if alive and is_local() and Game.hud != null:
			Game.hud.hide_death()
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
		return a[i] + 100 * facing
	if moving:
		var w: Array = anims["walk"]
		return w[int(_anim_t * 8.0) % w.size()] + 100 * facing
	var idle: Array = anims["idle"]
	return idle[int(_anim_t * 1.6) % idle.size()] + 100 * facing


func _sheet() -> String:
	return "survivor_m%d_a%d_e%d" % [look & 1, (look >> 1) & 1, (look >> 2) & 1]


# ------------------------------------------------------------------ ações (dono -> servidor)
## Pede uma ação ao servidor. No anfitrião executa direto.
func act(action: String, args: Array = []) -> void:
	if Net.is_server():
		_do_act(action, args)
	else:
		_req_act.rpc_id(1, action, args)


@rpc("any_peer", "reliable")
func _req_act(action: String, args: Array) -> void:
	if not Net.is_server() or multiplayer.get_remote_sender_id() != peer:
		return
	_do_act(action, args)


func _do_act(action: String, args: Array) -> void:
	if data == null or not action in ACTIONS:
		return
	if not alive and action != "save":
		return
	match action:
		"use_item":
			data.use_item(args[0] if (args[0] is int or args[0] is String) else str(args[0]))
		"move":
			data.move_item(int(args[0]), str(args[1]))
		"drop":
			var part := data.remove_u(int(args[0]), int(args[1]))
			if not part.is_empty():
				world.drop_items(position if is_local() else net_pos, [part])
		"repair":
			data.repair(int(args[0]))
		"unwear":
			data.unwear(str(args[0]))
		"take":
			world.take_from(self, str(args[0]), int(args[1]), int(args[2]), str(args[3]), str(args[4]))
		"take_all":
			world.take_all(self, str(args[0]))
		"store":
			world.store_into(self, str(args[0]), int(args[1]), int(args[2]))
		"treat":
			data.treat(str(args[0]), str(args[1]))
		"craft":
			data.craft(str(args[0]))
		"install":
			data.install_implant(str(args[0]))
		"maintain":
			data.maintain_implant(str(args[0]))
		"interact":
			world.interact(self, str(args[0]))
		"build":
			world.try_place(str(args[0]), Vector2i(int(args[1]), int(args[2])), self)
		"demolish":
			world.try_demolish(Vector2i(int(args[0]), int(args[1])), self)
		"attack":
			_server_attack(int(args[0]))
		"save":
			Game.save_game()
			Game.tell(peer, "Jogo salvo pelo anfitrião.")
	_sync_t = 0.0
	if is_local():
		data_changed.emit()


func _server_attack(dir_index: int) -> void:
	attack_flash = 0.15
	var pos := position if is_local() else net_pos
	var dir := Vector2.from_angle(float(posmod(dir_index, 8)) * PI / 4.0)
	var dmg := data.melee_damage()
	var hit := false
	for n in get_tree().get_nodes_in_group("infected"):
		var e := n as Infected
		var off := e.position - pos
		var iso := Vector2(off.x, off.y * 2.0)
		if iso.length() < 65.0 and iso.normalized().dot(dir) > 0.3:
			e.take_damage(dmg, self)
			hit = true
	if hit:
		data.wear_weapon()


## Dano vindo dos infectados (servidor).
func server_hurt(limb: String, amount: float, pathogen_gain: float) -> void:
	if data == null or not alive or data.god:
		return
	data.damage_limb(limb, amount)
	data.pathogen = minf(100.0, data.pathogen + pathogen_gain)
	hurt_seq += 1


@rpc("any_peer", "reliable")
func _receive_data(d: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	data = SurvivorData.from_dict(d)
	data_changed.emit()


## Teleporte: quem move o personagem é o dono, então o servidor pede a ele.
func teleport(pos: Vector2) -> void:
	if is_local():
		_set_pos(pos)
	else:
		net_pos = pos
		_set_pos.rpc_id(peer, pos)


@rpc("any_peer", "reliable")
func _set_pos(pos: Vector2) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	position = pos
	net_pos = pos
	velocity = Vector2.ZERO
	if camera != null:
		camera.reset_smoothing()


## Tela de morte e renascimento no dono (enviadas pelo servidor).
@rpc("any_peer", "reliable")
func show_death_ui(info: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	build_kind = ""
	demolish = false
	if Game.hud != null:
		Game.hud.show_death(info)


# ------------------------------------------------------------------ entrada local
func _unhandled_input(event: InputEvent) -> void:
	if not is_local() or not alive:
		return
	if event.is_action_pressed("interact") and nearby != null and is_instance_valid(nearby):
		if (nearby is LootContainer or nearby is Corpse) and Game.hud != null:
			Game.hud.open_loot(nearby)
		else:
			act("interact", [world.key_of(nearby)])
	elif event.is_action_pressed("cancel"):
		build_kind = ""
		demolish = false
	elif event.is_action_pressed("demolish"):
		demolish = not demolish
		build_kind = ""
		Game.say("Modo demolição %s." % ("ligado (clique)" if demolish else "desligado"))
	elif event.is_action_pressed("save"):
		act("save")
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			build_kind = ""
			demolish = false
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			var cell := world.mouse_cell()
			if build_kind != "":
				act("build", [build_kind, cell.x, cell.y])
			elif demolish:
				act("demolish", [cell.x, cell.y])


func _process(_delta: float) -> void:
	if not is_local():
		return
	if not alive:
		world.ghost.hide_ghost()
		return
	if build_kind != "":
		var cell := world.mouse_cell()
		world.ghost.show_at(build_kind, world.ground.map_to_local(cell), world.can_place_at(build_kind, cell, self))
	elif demolish:
		var cell2 := world.mouse_cell()
		world.ghost.show_at("demolir", world.ground.map_to_local(cell2), world.structures.has(cell2) or world.chests.has(cell2) or world.build_layer.get_cell_source_id(cell2) != -1)
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


func _vector_to_facing(direction: Vector2) -> int:
	var index := int(round(direction.angle() / (PI / 4.0)))
	return posmod(index, 8)


func _draw() -> void:
	if not alive:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, ISO_Y_SCALE))
	draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var tint := Color.WHITE
	if hurt_flash > 0.0:
		tint = Color(1.0, 0.45, 0.45)
	GenArt.draw_frame(self, _sheet(), facing, _frame % 100 if _frame >= 0 else 0, Vector2.ZERO, tint)
	if not is_local() and nome != "":
		# nome dos outros jogadores sobre a cabeça, na fonte pixelada em escala nativa
		draw_set_transform(Vector2(0, -50), 0.0, Vector2(0.5, 0.5))
		var f := UITheme.font()
		var w := f.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_S).x
		draw_string(f, Vector2(-w / 2.0 + 2, 2), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_S, Color(0, 0, 0, 0.8))
		draw_string(f, Vector2(-w / 2.0, 0), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_S, UITheme.ACCENT)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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
const ACTIONS := ["hotbar", "use_item", "treat", "craft", "install", "maintain", "interact", "build", "demolish",
	"attack", "save", "move", "drop", "repair", "refuel_station", "unlock", "unwear", "take", "take_all", "store", "remove_implant", "reload", "cancel", "examine", "deliver", "donate", "buy", "vehicle", "reorder", "sort_inv",
	"loot_order", "sort_loot"]
## Ações que levam tempo (barra de progresso; mover-se ou levar dano interrompe).
const TIMED := ["treat", "install", "remove_implant", "maintain", "craft", "reload", "repair", "use_item", "vehicle", "unlock"]
const TREAT_NAMES := {"antibiotico": "Aplicando antibiótico", "desinfetar": "Desinfetando", "enfaixar": "Enfaixando",
	"imobilizar": "Imobilizando"}
## Vestir (roupa, máscara, mochila, coldre) é imediato.
const USE_TIME := {"comida": 1.5, "bebida": 1.5, "cantil": 1.2, "filtro": 2.5, "manual": 8.0,
	"analgesico": 1.0, "supressor": 1.5, "bateria": 2.0, "pilha": 1.0}
## Ações que a sobrecarga sináptica impede (GDD 4: incapacidade de ações complexas).
const COMPLEX := ["treat", "craft", "install", "maintain", "build", "repair"]

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
var sprinting := false
var sneaking := false
var attack_seq := 0
# ---- replicado pelo servidor
var look := 1  # bits: 1 máscara, 2 braço cibernético, 4 olho (HUD), 8 lanterna acesa
var alive := true
var hurt_seq := 0
## Esperando o jogador criar um sobrevivente (entrada na sessão ou depois de morrer).
var pending := false
## Ação com tempo em andamento (texto, fim no relógio do mundo, duração).
var busy_label := ""
var busy_end := 0.0
var busy_total := 0.0

# ---- locais
var attack_cd := 0.0
var attack_flash := 0.0
var hurt_flash := 0.0
## Servidor: este jogador já morreu nesta sessão (o próximo sobrevivente acorda noutro prédio).
var has_died_before := false
var build_kind := ""
var demolish := false
var nearby: Node = null
var camera: Camera2D
var spores: CPUParticles2D
var rain: CPUParticles2D
var lamp: PointLight2D
var _sky_t := 0.0
var respawn_t := -1.0
var _anim_t := 0.0
var _attack_anim := 0.0
var _frame := -1
var _seen_attack := 0
var _seen_hurt := 0
var _sync_t := 0.0
var _last_sync := ""
var _was_alive := true
# ---- sobrecarga sináptica (só no dono): atraso e desvio do controle, espasmos
var _input_buf: Array[Vector2] = []
var _spasm_t := 0.0
var _spasm_dir := Vector2.ZERO
var _glitch_t := 1.0
var _step_t := 0.0
var _drive_k := 0.0
var _fire_cd := 0.0
var _light: PointLight2D
## Servidor: ação com tempo em andamento {action, args, partner} ou {passive, partner}.
var _busy := {}

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
		rain = CPUParticles2D.new()
		rain.amount = 260
		rain.lifetime = 0.7
		rain.preprocess = 1.0
		rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		rain.emission_rect_extents = Vector2(620, 40)
		rain.position = Vector2(80, -360)
		rain.direction = Vector2(-0.25, 1)
		rain.spread = 3.0
		rain.gravity = Vector2.ZERO
		rain.initial_velocity_min = 900.0
		rain.initial_velocity_max = 1100.0
		var gt := GradientTexture2D.new()
		gt.width = 2
		gt.height = 14
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(0, 1)
		var gr := Gradient.new()
		gr.set_color(0, Color(0.7, 0.8, 1.0, 0.0))
		gr.set_color(1, Color(0.75, 0.85, 1.0, 0.55))
		gt.gradient = gr
		rain.texture = gt
		rain.z_index = 45
		rain.emitting = false
		add_child(rain)
	lamp = PointLight2D.new()
	lamp.texture = World.light_texture()
	lamp.texture_scale = 1.6
	lamp.color = Color(1.0, 0.95, 0.8)
	lamp.position = Vector2(0, -16)
	lamp.enabled = false
	add_child(lamp)


## Sincronizadores: um do dono (movimento) e um do servidor (aparência e estado).
## Chamado pela função de spawn antes de o nó entrar na árvore.
func setup_net(owner_peer: int) -> void:
	peer = owner_peer
	var own := Net.make_sync(self, [".:net_pos", ".:facing", ".:moving", ".:sprinting", ".:sneaking", ".:attack_seq"], 0.05)
	own.name = "SyncDono"
	var srv := Net.make_sync(self, [".:look", ".:alive", ".:hurt_seq", ".:nome", ".:pending",
		".:busy_label", ".:busy_end", ".:busy_total"], 0.1)
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
	var menu_open := Game.hud != null and Game.hud.blocks_input()
	if console_open or menu_open:
		input = Vector2.ZERO
	if data != null and data.overloaded():
		input = _overload_input(input, delta)
	else:
		_input_buf.clear()
	var veh := world.vehicle_of(peer) if world != null else null
	if veh != null and veh.driver != peer:
		# passageiro: vai junto com o veículo
		position = veh.position
		net_pos = position
		moving = false
		sprinting = false
		return
	moving = input != Vector2.ZERO
	if veh != null:
		if moving:
			facing = _vector_to_facing(input)
	elif not console_open and not menu_open:
		# o personagem olha para o mouse (não para onde anda)
		var to_mouse := get_global_mouse_position() - position
		if to_mouse.length() > 6.0:
			facing = GenArt.facing_of(to_mouse)
	elif moving:
		facing = _vector_to_facing(input)
	var mult := data.speed_mult() if data != null else 1.0
	sprinting = moving and not sneaking and Input.is_action_pressed("sprint") and data != null and data.can_sprint()
	if veh != null:
		# motorista: o personagem anda na velocidade do veículo (se ele puder andar)
		sprinting = false
		_drive_k = move_toward(_drive_k, veh.speed_mult() if veh.can_run() and moving else 0.0, delta * 2.5)
		mult = _drive_k
	elif sprinting:
		mult *= 1.55
	elif sneaking:
		mult *= 0.55
	velocity = Vector2(input.x, input.y * ISO_Y_SCALE) * SPEED * mult
	move_and_slide()
	net_pos = position
	attack_cd = maxf(0.0, attack_cd - delta)
	_update_nearby()
	var building_mode := Game.hud != null and Game.hud.build_mode
	var hot_click := Game.hud != null and Game.hud.hot_consumes_click()
	if build_kind == "" and not demolish and not building_mode and attack_cd <= 0.0 and Input.is_action_pressed("attack") \
			and not console_open and not menu_open and veh == null and not hot_click:
		attack_cd = 0.55
		attack_seq += 1
		# golpe e tiro vão na direção do mouse (ângulo no espaço isométrico)
		var to_m := get_global_mouse_position() - position
		var aim_angle := Vector2(to_m.x, to_m.y * 2.0).angle()
		facing = GenArt.facing_of(to_m)
		var aim := facing
		if data != null and data.overloaded():
			aim = posmod(facing + randi_range(-2, 2), 8)  # não consegue mirar
			aim_angle += randf_range(-1.2, 1.2)
		act("attack", [aim, aim_angle])
	if spores != null and world != null:
		spores.modulate.a = clampf(world.spore_at(position) * 1.6, 0.15, 1.0)
		_sky_t -= delta
		if _sky_t <= 0.0:
			_sky_t = 0.5
			var wt := str(world.weather.get("tipo", ""))
			rain.emitting = wt in ["chuva", "tempestade"]
			rain.amount = 420 if wt == "tempestade" else 260
			rain.direction = Vector2(-0.6 if wt == "tempestade" else -0.25, 1)


## Sobrecarga: o comando chega atrasado (~0,3 s), desvia e às vezes o corpo dá espasmos.
func _overload_input(input: Vector2, delta: float) -> Vector2:
	_input_buf.append(input)
	var delayed: Vector2 = _input_buf.pop_front() if _input_buf.size() > 18 else Vector2.ZERO
	var k := 1.0 - 0.06 * float(data.level("cibernetica"))
	_glitch_t -= delta
	if _glitch_t <= 0.0:
		_glitch_t = randf_range(1.0, 3.0) / maxf(k, 0.3)
		_spasm_t = randf_range(0.15, 0.45) * k
		_spasm_dir = Vector2.from_angle(randf() * TAU)
	if _spasm_t > 0.0:
		_spasm_t -= delta
		return _spasm_dir
	if delayed != Vector2.ZERO:
		delayed = delayed.rotated(randf_range(-0.7, 0.7) * k)
	return delayed


func _server_tick(delta: float) -> void:
	if data == null:
		return
	attack_flash = maxf(0.0, attack_flash - delta)
	if alive:
		var pos := position if is_local() else net_pos
		data.tick(delta, {"spore": world.spore_at(pos), "moving": moving, "sprinting": sprinting, "combat": attack_flash > 0.0,
			"purifier": world.purifier_near(pos)})
		look = int(data.has_mask()) | (2 if data.implant_active("braco_d") else 0) | (4 if data.implant_active("olho") else 0) \
			| (8 if data.lantern_on() else 0)
		_fire_cd = maxf(0.0, _fire_cd - delta)
		_tick_busy()
		if moving:
			_step_t -= delta
			if _step_t <= 0.0:
				_step_t = 0.5
				world.make_noise(pos, data.step_noise(sprinting, sneaking) * world.noise_factor())
				if sneaking and world.nearest_infected_dist(pos) < 360.0:
					data.add_xp("furtividade", 0.3)
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


## Luz da lanterna (todos os peers veem quem está com ela acesa).
func _update_light() -> void:
	var on := (look & 8) != 0 and alive
	if on and _light == null:
		_light = PointLight2D.new()
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		g.width = 256
		g.height = 256
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		g.gradient = grad
		_light.texture = g
		_light.texture_scale = 1.6
		_light.color = Color(1.0, 0.9, 0.7)
		_light.energy = 0.55
		_light.position = Vector2(0, -10)
		add_child(_light)
	if _light != null:
		_light.visible = on


func _animate(delta: float) -> void:
	_update_light()
	if busy_label != "":
		queue_redraw()
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
	# ação com tempo fecha o inventário ou a janela aberta (o jogador vê a barra de progresso)
	if is_local() and action in TIMED and Game.hud != null and data != null and _duration(action, args, self) > 0.0:
		Game.hud.close_for_action()
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
	if action in COMPLEX:
		var why := data.complex_block()
		if why != "":
			Game.tell(peer, why)
			return
	if action == "cancel":
		cancel_busy("Ação cancelada.")
		return
	if action == "examine":
		_examine(int(args[0]))
		return
	if is_busy() and (action in TIMED or action in ["attack", "build", "demolish", "interact"]):
		Game.tell(peer, "Você está ocupado (%s). Mova-se para cancelar." % busy_label)
		return
	if action == "craft" and not _station_ok(str(args[0])):
		return
	if action in TIMED:
		var patient := _patient_of(action, args)
		if patient == null:
			return
		var dur := _duration(action, args, patient)
		if dur > 0.0:
			_start_busy(action, args, dur, patient)
			return
	_run_act(action, args)


func _run_act(action: String, args: Array) -> void:
	if data == null or not alive:
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
			data.repair(int(args[0]), world.station_near(position if is_local() else net_pos, "mesa_reparo"))
		"unwear":
			data.unwear(str(args[0]))
		"take":
			world.take_from(self, str(args[0]), int(args[1]), int(args[2]), str(args[3]), str(args[4]))
		"take_all":
			world.take_all(self, str(args[0]))
		"store":
			world.store_into(self, str(args[0]), int(args[1]), int(args[2]))
		"treat":
			var pt := _patient_of(action, args)
			if pt != null:
				pt.data.treat(str(args[0]), str(args[1]), data if pt != self else null)
				pt._sync_t = 0.0
		"craft":
			var rid := str(args[0])
			if _station_ok(rid):
				var cdef: Dictionary = DB.CRAFTS[rid]
				var done := false
				if not data.can_afford(cdef["custo"]) and data.meets(cdef["req"]) and data.missing_tools(cdef.get("ferramentas", [])) == "" \
						and world.afford_near(self, cdef["custo"]):
					# usa materiais dos baús e sacos por perto
					world.pay_near(self, cdef["custo"])
					done = data.craft(rid, true)
				else:
					done = data.craft(rid)
				var sn := _station_fuel_node(rid)
				if done and sn != null:
					sn.use_supply(float(Structure.supply_of(sn.kind)["uso"]))
		"install":
			var pi := _patient_of(action, args)
			if pi != null:
				pi.data.install_implant(str(args[0]), data if pi != self else null)
				pi._sync_t = 0.0
		"maintain":
			data.maintain_implant(str(args[0]))
		"remove_implant":
			var pr := _patient_of(action, args)
			if pr != null:
				pr.data.remove_implant(str(args[0]), data if pr != self else null)
				pr._sync_t = 0.0
		"interact":
			world.interact(self, str(args[0]))
		"unlock":
			world.try_unlock(self, str(args[0]))
		"refuel_station":
			var sn2 := world.node_of(str(args[0])) as Structure
			if sn2 != null and sn2.kind in Structure.STATIONS and Structure.supply_of(sn2.kind).size() > 0 \
					and Vector2(sn2.position.x - (position if is_local() else net_pos).x,
						(sn2.position.y - (position if is_local() else net_pos).y) * 2.0).length() < 140.0:
				sn2.refill(self)
		"hotbar":
			var hi := int(args[0])
			if hi >= 0 and hi < 5:
				data.hotbar[hi] = str(args[1]) if DB.ITEMS.has(str(args[1])) else ""
		"build":
			world.try_place(str(args[0]), Vector2i(int(args[1]), int(args[2])), self, int(args[3]) if args.size() > 3 else -1)
		"demolish":
			world.try_demolish(Vector2i(int(args[0]), int(args[1])), self, int(args[2]) if args.size() > 2 else -1)
		"attack":
			_server_attack(int(args[0]), float(args[1]) if args.size() > 1 else float(int(args[0])) * PI / 4.0)
		"reload":
			data.reload()
		"deliver":
			world.deliver(self, int(args[0]))
		"donate":
			world.donate(self, int(args[0]), int(args[1]), int(args[2]))
		"buy":
			world.buy(self, int(args[0]), str(args[1]))
		"vehicle":
			world.vehicle_action(self, str(args[0]), str(args[1]))
		"reorder":
			data.reorder(int(args[0]), int(args[1]))
		"sort_inv":
			data.sort_bags()
		"loot_order":
			world.loot_order(self, str(args[0]), int(args[1]), int(args[2]))
		"sort_loot":
			world.sort_loot(self, str(args[0]))
		"save":
			Game.save_game()
			Game.tell(peer, "Jogo salvo pelo anfitrião.")
	_sync_t = 0.0
	if is_local():
		data_changed.emit()


func _station_ok(recipe: String) -> bool:
	if not DB.CRAFTS.has(recipe):
		return false
	var st := String(DB.CRAFTS[recipe].get("estacao", ""))
	if st == "":
		return true
	var node := world.station_node(position if is_local() else net_pos, st)
	if node == null:
		Game.tell(peer, "Precisa usar: %s." % String(DB.BUILDS[st]["nome"]).to_lower())
		return false
	var sup := Structure.supply_of(st)
	if sup.has("uso") and node.fuel + 0.01 < float(sup["uso"]):
		Game.tell(peer, "%s sem %s: ponha madeira." % [DB.BUILDS[st]["nome"], sup["nome"]])
		return false
	return true


## Estação que vai gastar insumo nesta receita (fogareiro, fornalha), ou null.
func _station_fuel_node(recipe: String) -> Structure:
	var st := String(DB.CRAFTS[recipe].get("estacao", ""))
	if st == "" or not Structure.supply_of(st).has("uso"):
		return null
	return world.station_node(position if is_local() else net_pos, st)


# ------------------------------------------------------------------ ações com tempo (servidor)
func is_busy() -> bool:
	return not _busy.is_empty() or (busy_label != "" and busy_end > Game.play_time)


## Paciente de uma ação médica (o próprio jogador ou um aliado próximo e livre).
func _patient_of(action: String, args: Array) -> Player:
	var idx := {"treat": 2, "install": 1, "remove_implant": 1}.get(action, -1) as int
	if idx < 0 or args.size() <= idx or int(args[idx]) == peer or int(args[idx]) == 0:
		return self
	var other: Player = world.players.get(int(args[idx]))
	if other == null or not other.alive or other.data == null:
		Game.tell(peer, "O paciente não está disponível.")
		return null
	var a := position if is_local() else net_pos
	var b := other.position if other.is_local() else other.net_pos
	if Vector2(b.x - a.x, (b.y - a.y) * 2.0).length() > 95.0:
		Game.tell(peer, "Chegue mais perto de %s." % other.data.nome)
		return null
	if other.is_busy() and other._busy.get("partner") != self:
		Game.tell(peer, "%s está ocupado." % other.data.nome)
		return null
	return other


func _duration(action: String, args: Array, patient: Player) -> float:
	var med := (1.0 - 0.06 * float(data.level("medicina"))) * (1.0 - clampf(data.gear_bonus("medico"), 0.0, 0.5))
	var mec := 1.0 - clampf(data.gear_bonus("reparo"), 0.0, 0.6)
	var cib := 1.0 - 0.05 * float(data.level("cibernetica"))
	match action:
		"treat":
			return {"antibiotico": 2.0, "desinfetar": 3.0, "enfaixar": 4.0, "imobilizar": 6.0}.get(str(args[1]), 3.0) * med \
				* (1.25 if patient == self else 1.0)
		"install":
			return 14.0 * cib
		"remove_implant":
			return 10.0 * cib
		"maintain":
			return 5.0 * cib
		"craft":
			return 3.5
		"unlock":
			var un := world.node_of(str(args[0]))
			return world.unlock_time(self, world.lock_of(un)) if un != null and world.is_locked(un) else 0.0
		"repair":
			return 3.0 * mec
		"reload":
			var gun := data.firearm()
			if gun.is_empty():
				return 0.0
			return (1.6 if int(Items.def(gun["id"])["pente"]) > 2 else 2.4) * (1.0 - 0.06 * float(data.level("pontaria"))) \
				* (1.0 - clampf(data.gear_bonus("combate") * 1.5, 0.0, 0.4))
		"vehicle":
			return {"hotwire": 6.0 * (1.0 - 0.08 * float(data.level("mecanica"))) * mec, "repair": 6.0 * mec, "refuel": 2.0}.get(str(args[1]), 0.0)
		"use_item":
			var inst := data._resolve(args[0] if (args[0] is int or args[0] is String) else str(args[0]))
			if inst.is_empty():
				return 0.0
			var tipo := String(Items.def(inst["id"])["tipo"])
			# tirar o que está vestido é rápido
			var es := SurvivorData.slot_of(String(inst["id"]))
			if es != "" and int(data.equip[es].get("u", -1)) == int(inst.get("u", 0)):
				return 0.0
			return float(USE_TIME.get(tipo, 0.0))
	return 0.0


func _busy_text(action: String, args: Array, patient: Player) -> String:
	var who := "" if patient == self else " em %s" % patient.data.nome
	match action:
		"treat":
			var limb: String = "" if str(args[1]) == "antibiotico" else " " + str(SurvivorData.LIMB_NAMES[str(args[0])])
			return TREAT_NAMES.get(str(args[1]), "Tratando") + limb + who
		"install":
			return "Cirurgia: " + DB.item_name(str(args[0])) + who
		"remove_implant":
			return "Removendo implante" + who
		"maintain":
			return "Manutenção do implante"
		"craft":
			return "Fabricando " + String(DB.CRAFTS[str(args[0])]["nome"])
		"unlock":
			var un2 := world.node_of(str(args[0]))
			return "Destrancando" if un2 != null and not data.key_for(world.lock_of(un2)).is_empty() else "Forçando a fechadura"
		"reload":
			return "Recarregando"
		"repair":
			return "Consertando"
		"vehicle":
			return {"hotwire": "Ligação direta", "repair": "Consertando o veículo", "refuel": "Abastecendo"}.get(str(args[1]), "Veículo")
		"use_item":
			var inst := data._resolve(args[0] if (args[0] is int or args[0] is String) else str(args[0]))
			return "Usando " + DB.item_name(inst["id"]) if not inst.is_empty() else "Usando"
	return "Ocupado"


func _start_busy(action: String, args: Array, dur: float, patient: Player) -> void:
	busy_label = _busy_text(action, args, patient)
	busy_total = dur
	busy_end = Game.play_time + dur
	_busy = {"action": action, "args": args, "partner": patient}
	if patient != self:
		patient.busy_label = "%s cuida de você" % data.nome
		patient.busy_total = dur
		patient.busy_end = busy_end
		patient._busy = {"passive": true, "partner": self}
		Game.tell(patient.peer, "%s está tratando você. Fique parado (%ds)." % [data.nome, ceili(dur)])


func _clear_busy() -> void:
	_busy = {}
	busy_label = ""
	busy_end = 0.0
	busy_total = 0.0


## Interrompe a ação (e a do parceiro, se houver).
func cancel_busy(reason: String) -> void:
	if _busy.is_empty():
		return
	var partner: Player = _busy.get("partner")
	_clear_busy()
	Game.tell(peer, reason)
	if partner != null and is_instance_valid(partner) and partner != self and not partner._busy.is_empty():
		partner._clear_busy()
		Game.tell(partner.peer, "O procedimento foi interrompido.")


func _tick_busy() -> void:
	if _busy.is_empty():
		return
	var partner: Player = _busy.get("partner")
	if moving:
		cancel_busy("Ação interrompida: você se moveu.")
		return
	if partner != null and (not is_instance_valid(partner) or not partner.alive):
		cancel_busy("Ação interrompida.")
		return
	if _busy.get("passive", false) or Game.play_time < busy_end:
		return
	var b := _busy
	_clear_busy()
	if partner != null and partner != self:
		partner._clear_busy()
	_run_act(b["action"], b["args"])
	_sync_t = 0.0


## Servidor: manda os dados médicos de um aliado próximo para quem pediu (aba Corpo).
func _examine(target: int) -> void:
	var other: Player = world.players.get(target)
	if other == null or other.data == null or not other.alive:
		return
	var a := position if is_local() else net_pos
	var b := other.position if other.is_local() else other.net_pos
	if Vector2(b.x - a.x, (b.y - a.y) * 2.0).length() > 160.0:
		return
	var od := other.data
	var info := {"nome": od.nome, "limbs": od.limbs.duplicate(true), "blood": od.blood, "pathogen": od.pathogen,
		"implants": od.implants.duplicate(true), "antibiotic_t": od.antibiotic_t, "cap": od.neural_capacity(),
		"general": od.general_count()}
	if is_local():
		_patient_info(target, info)
	else:
		_patient_info.rpc_id(peer, target, info)


@rpc("any_peer", "reliable")
func _patient_info(target: int, info: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	if Game.hud != null:
		Game.hud.patient_info[target] = info


func _server_attack(_dir_index: int, aim_angle: float) -> void:
	attack_flash = 0.15
	var gun := data.firearm()
	if not gun.is_empty():
		_server_fire(gun, aim_angle)
		return
	var pos := position if is_local() else net_pos
	# direção exata do mouse (espaço isométrico); o índice de 8 direções fica para o desenho
	var dir := Vector2.from_angle(aim_angle)
	data.spend_stamina(data.attack_stamina())
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
		data.on_melee_hit()
		world.make_noise(pos, 150.0)


## Servidor: disparo de arma de fogo (hitscan no espaço isométrico, com dispersão).
func _server_fire(gun: Dictionary, aim_angle: float) -> void:
	if _fire_cd > 0.0:
		return
	var def := Items.def(gun["id"])
	_fire_cd = float(def.get("cadencia", 0.4))
	if float(gun.get("mun", 0.0)) < 1.0:
		Game.tell(peer, "Clique! Sem munição. [R] recarrega.")
		return
	var dur := float(gun.get("dur", 100.0))
	if dur < 30.0 and randf() < (30.0 - dur) / 60.0:
		Game.tell(peer, "A arma engasgou!")
		return
	gun["mun"] = float(gun["mun"]) - 1.0
	gun["dur"] = maxf(0.0, dur - float(def.get("gasto", 0.3)))
	var pos := position if is_local() else net_pos
	var muzzle := pos + Vector2(0, -16)
	var aim_lv := float(data.level("pontaria"))
	var spread := float(def["dispersao"]) * (1.0 - 0.07 * aim_lv)
	if data.stamina < 8.0:
		spread *= 1.6
	var reach := float(def["alcance"])
	var ends := PackedVector2Array()
	var hits := 0
	for i in int(def.get("chumbos", 1)):
		var dir := Vector2.from_angle(aim_angle + randf_range(-spread, spread))
		var best: Infected = null
		var best_t := reach
		for n in get_tree().get_nodes_in_group("infected"):
			var e := n as Infected
			var off := e.position - pos
			var iso := Vector2(off.x, off.y * 2.0)
			var t := iso.dot(dir)
			if t < 0.0 or t > best_t:
				continue
			if absf(iso.cross(dir)) < 16.0:
				best = e
				best_t = t
		var end_iso := dir * best_t
		ends.append(pos + Vector2(end_iso.x, end_iso.y * 0.5) + Vector2(0, -14))
		if best != null:
			best.take_damage(float(def["dano"]) * (1.0 - 0.4 * best_t / reach), self)
			hits += 1
	data.add_xp("pontaria", 0.6 + 2.0 * float(hits))
	world.shot_fx.rpc(muzzle, ends)
	world.make_noise(pos, float(def["ruido"]) * (1.0 - 0.04 * aim_lv))
	if float(gun["dur"]) <= 0.0:
		Game.tell(peer, "Sua arma quebrou: %s!" % DB.item_name(gun["id"]))
		data.remove_u(int(gun["u"]))
		data.hand_u = 0
	_sync_t = 0.0


## Dono: envia a ficha de criação ao servidor.
func send_creation(spec: Dictionary) -> void:
	if Net.is_server():
		_create(spec)
	else:
		_req_create.rpc_id(1, spec)


@rpc("any_peer", "reliable")
func _req_create(spec: Dictionary) -> void:
	if not Net.is_server() or multiplayer.get_remote_sender_id() != peer:
		return
	_create(spec)


func _create(spec: Dictionary) -> void:
	if not pending:
		return
	var err := DB.creation_error(spec)
	if err != "":
		Game.tell(peer, "Ficha recusada: " + err)
		if is_local():
			_creation_refused()
		else:
			_creation_refused.rpc_id(peer)
		return
	world.create_survivor(self, spec)


@rpc("any_peer", "reliable")
func _creation_refused() -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	if Game.hud != null:
		Game.hud.creation_refused()


## Dano vindo dos infectados (servidor).
func server_hurt(limb: String, amount: float, pathogen_gain: float) -> void:
	if data == null or not alive or data.god:
		return
	data.damage_limb(limb, amount)
	data.pathogen = minf(100.0, data.pathogen + pathogen_gain)
	hurt_seq += 1
	if not _busy.is_empty():
		cancel_busy("Ação interrompida: você foi atacado!")


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
	var in_veh := world.vehicle_of(peer)
	if event.is_action_pressed("interact") and in_veh != null:
		act("vehicle", [world.key_of(in_veh), "exit"])
	elif event.is_action_pressed("interact") and nearby != null and is_instance_valid(nearby):
		if world.is_locked(nearby):
			act("unlock", [world.key_of(nearby)])
		elif nearby is Vehicle and Game.hud != null:
			Game.hud.open_vehicle(nearby)
		elif (nearby is LootContainer or nearby is Corpse) and Game.hud != null:
			Game.hud.open_loot(nearby)
		elif nearby is Npc and Game.hud != null:
			Game.hud.open_village((nearby as Npc).village_id)
		elif nearby is Structure and (nearby as Structure).kind in Structure.STATIONS and Game.hud != null:
			Game.hud.open_station(nearby as Structure)
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
	elif event.is_action_pressed("sneak"):
		sneaking = not sneaking
		Game.say("Agachado: passos quase sem barulho." if sneaking else "Você se levantou.")
	elif event.is_action_pressed("reload"):
		act("reload")
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			build_kind = ""
			demolish = false
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if build_kind != "":
				act("build", _build_args())
			elif demolish:
				act("demolish", world.demolish_target())


func _process(_delta: float) -> void:
	if lamp != null and world != null:
		var dk := world.darkness()
		lamp.enabled = alive and (look & 8) != 0 and dk > 0.05
		lamp.energy = 1.1 * dk
	if not is_local():
		return
	if not alive:
		world.ghost.hide_ghost()
		return
	if build_kind != "":
		var a := _build_args()
		var c := Vector2i(int(a[1]), int(a[2]))
		var d := int(a[3])
		var pos := world.edge_pos(Vector3i(c.x, c.y, d)) if d >= 0 else world.ground.map_to_local(c)
		world.ghost.show_at(build_kind, pos, world.can_place_at(build_kind, c, self, d), d)
	elif demolish:
		var t := world.demolish_target()
		if t.size() == 3:
			world.ghost.show_at("demolir", world.edge_pos(Vector3i(t[0], t[1], t[2])), true, int(t[2]))
		else:
			var c2 := Vector2i(t[0], t[1])
			world.ghost.show_at("demolir", world.ground.map_to_local(c2), world.has_demolishable(c2))
	else:
		world.ghost.hide_ghost()


## [tipo, x, y, borda] da construção sob o mouse (borda -1 para o que ocupa a célula).
func _build_args() -> Array:
	if World.is_edge_kind(build_kind):
		var k := world.mouse_edge()
		return [build_kind, k.x, k.y, k.z]
	var c := world.mouse_cell()
	return [build_kind, c.x, c.y, -1]


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
	if is_local() and moving and data != null:
		# raio do barulho dos passos (ajuda a jogar furtivo)
		var r := data.step_noise(sprinting, sneaking)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.9, 0.9, 1.0, 0.08 if sneaking else 0.12), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var in_vehicle := world != null and world.vehicle_of(peer) != null
	if not in_vehicle:
		GenArt.draw_frame(self, _sheet(), facing, _frame % 100 if _frame >= 0 else 0, Vector2.ZERO, tint)
	if busy_label != "" and busy_end > Game.play_time and busy_total > 0.0:
		var k := clampf(1.0 - (busy_end - Game.play_time) / busy_total, 0.0, 1.0)
		draw_rect(Rect2(-16, -58, 32, 4), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-15, -57, 30.0 * k, 2), UITheme.ACCENT)
	if not is_local() and nome != "":
		# nome dos outros jogadores sobre a cabeça, na fonte pixelada em escala nativa
		draw_set_transform(Vector2(0, -50), 0.0, Vector2(0.5, 0.5))
		var f := UITheme.font()
		var w := f.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_S).x
		draw_string(f, Vector2(-w / 2.0 + 2, 2), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_S, Color(0, 0, 0, 0.8))
		draw_string(f, Vector2(-w / 2.0, 0), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_S, UITheme.ACCENT)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

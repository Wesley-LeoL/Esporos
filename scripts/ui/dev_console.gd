class_name DevConsole
extends CanvasLayer
## Terminal de cheats para testes. Abre/fecha com F1 ou ` (acento grave/apóstrofo,
## tecla à esquerda do 1). Pausa o jogo enquanto aberto. Digite "ajuda".

const COMMANDS: Array[String] = ["ajuda", "itens", "dar", "dano", "curar", "restaurar", "set", "skill",
	"spawn", "limpar", "tp", "pos", "matar", "infectar", "implante", "god", "salvar", "cls",
	"kit", "kit_medico", "kit_build", "kit_cyber"]

const LIMB_ALIASES := {"cabeca": "cabeca", "cabeça": "cabeca", "tronco": "torso", "torso": "torso",
	"braco_e": "braco_e", "braço_e": "braco_e", "braco_d": "braco_d", "braço_d": "braco_d",
	"perna_e": "perna_e", "perna_d": "perna_d"}

const STATS := {"patogeno": ["pathogen", 100.0], "sangue": ["blood", 100.0], "calorias": ["calories", 2000.0],
	"agua": ["water", 100.0],
	"bateria": ["battery", 100.0], "filtro": ["filter", 100.0], "calor": ["heat", 100.0], "estamina": ["stamina", 200.0]}

const HELP := """[color=#9be04a]COMANDOS[/color] (Tab completa · setas ↑↓ histórico · F1 ou ` fecha)
[color=#ffe066]dar[/color] <item> [qtd]        adiciona item (ex: dar metal 20 · dar tudo 5). "itens [filtro]" lista os ids
[color=#ffe066]dano[/color] <membro|todos> <n>  causa dano (cabeca, tronco, braco_e, braco_d, perna_e, perna_d)
[color=#ffe066]curar[/color]                  cura ferimentos, sangue e infecções
[color=#ffe066]restaurar[/color]              cura tudo e zera patógeno; enche fome, sede, filtro e bateria
[color=#ffe066]set[/color] <stat> <valor>       patogeno, sangue, calorias (fome), agua (sede), bateria, filtro, calor, estamina
[color=#ffe066]skill[/color] <nome|todas> <0-10>  combate pontaria atletismo furtividade mecanica eletronica carpintaria metalurgia medicina cibernetica agricultura culinaria
[color=#ffe066]spawn[/color] [normal|elite] [n]  cria inimigos perto de você
[color=#ffe066]limpar[/color]                 remove todos os infectados
[color=#ffe066]tp[/color] <x> <y>               teleporta para o tile (x,y) · também: tp abrigo | tp vila <n|nome> | tp borda | tp cadaver | tp elite
[color=#ffe066]pos[/color]                    mostra sua posição em tiles e os esporos
[color=#ffe066]implante[/color] <pulmao|hud|braco>  instala o implante na hora
[color=#ffe066]god[/color]                    liga/desliga invulnerabilidade
[color=#ffe066]matar[/color] · [color=#ffe066]infectar[/color]    morte física · morte por infecção (testa o legado)
[color=#ffe066]salvar[/color] · [color=#ffe066]cls[/color]          salva o jogo · limpa o console
[color=#9be04a]CÓDIGOS PRONTOS[/color]: [color=#ffe066]kit[/color] (suprimentos) · [color=#ffe066]kit_medico[/color] · [color=#ffe066]kit_build[/color] (materiais + habilidades) · [color=#ffe066]kit_cyber[/color] (implantes + cirurgia)"""

var output: RichTextLabel
var line: LineEdit
var history: Array[String] = []
var _hist_i := -1
var _open := false
var _capture = null


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var theme := Theme.new()
	theme.default_font_size = 9
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	add_child(root)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.custom_minimum_size = Vector2(0, 310)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.04, 0.94)
	sb.set_content_margin_all(6)
	sb.border_width_bottom = 2
	sb.border_color = Color("#9be04a")
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	output = RichTextLabel.new()
	output.bbcode_enabled = true
	output.scroll_following = true
	output.selection_enabled = true
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(output)
	var row := HBoxContainer.new()
	vb.add_child(row)
	var prompt := Label.new()
	prompt.text = "›"
	prompt.add_theme_color_override("font_color", Color("#9be04a"))
	row.add_child(prompt)
	line = LineEdit.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.placeholder_text = "digite um comando (ajuda)"
	line.text_submitted.connect(_on_submit)
	row.add_child(line)
	_out("[color=#9be04a]Console de testes[/color] — digite [color=#ffe066]ajuda[/color] para ver os comandos.")


func is_open() -> bool:
	return _open


func open() -> void:
	if Game.world == null or Game.world.local_player() == null:
		return
	visible = true
	_open = true
	get_tree().paused = Net.is_solo()
	_focus.call_deferred()


func _focus() -> void:
	line.grab_focus()


func close() -> void:
	visible = false
	_open = false
	line.release_focus()
	var menu_open: bool = Game.hud != null and Game.hud.menu_root.visible
	get_tree().paused = menu_open and Net.is_solo()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := event as InputEventKey
	if k.keycode == KEY_F1 or k.physical_keycode == KEY_QUOTELEFT:
		if _open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if not _open:
		return
	if k.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_UP:
		_history(1)
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_DOWN:
		_history(-1)
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_TAB:
		_complete()
		get_viewport().set_input_as_handled()


func _history(step: int) -> void:
	if history.is_empty():
		return
	_hist_i = clampi(_hist_i + step, -1, history.size() - 1)
	line.text = "" if _hist_i < 0 else history[history.size() - 1 - _hist_i]
	line.caret_column = line.text.length()


func _complete() -> void:
	var parts := line.text.split(" ")
	var matches: Array[String] = []
	if parts.size() <= 1:
		var pre := _norm(parts[0])
		for c in COMMANDS:
			if c.begins_with(pre):
				matches.append(c)
	elif parts.size() == 2 and _norm(parts[0]) in ["dar", "give"]:
		var pre2 := _norm(parts[1])
		for id: String in DB.ITEMS:
			if id.begins_with(pre2):
				matches.append(id)
	if matches.size() == 1:
		parts[parts.size() - 1] = matches[0]
		line.text = " ".join(parts) + " "
		line.caret_column = line.text.length()
	elif matches.size() > 1:
		_out("[color=#888]" + "  ".join(matches) + "[/color]")


func _on_submit(text: String) -> void:
	if text.strip_edges() != "":
		history.append(text)
	_hist_i = -1
	line.clear()
	execute(text)
	_focus.call_deferred()


# ------------------------------------------------------------------ saída
func _out(bb: String) -> void:
	if _capture != null:
		_capture.append(bb)
	else:
		output.append_text(bb + "\n")


func _ok(text: String) -> void:
	_out("[color=#7fe07f]%s[/color]" % text)


func _err(text: String) -> void:
	_out("[color=#ff6b6b]%s[/color]" % text)


func _norm(s: String) -> String:
	return s.to_lower().replace("ç", "c").replace("ã", "a").replace("á", "a").replace("â", "a") \
		.replace("é", "e").replace("ê", "e").replace("í", "i").replace("ó", "o").replace("õ", "o") \
		.replace("ú", "u")


func _resolve_item(raw: String) -> String:
	var s := _norm(raw)
	if DB.ITEMS.has(s):
		return s
	var found: Array[String] = []
	for id: String in DB.ITEMS:
		if id.begins_with(s):
			found.append(id)
	if found.is_empty():
		for id: String in DB.ITEMS:
			if id.contains(s) or _norm(DB.item_name(id)).replace(" ", "_").contains(s):
				found.append(id)
	if found.size() == 1:
		return found[0]
	if found.is_empty():
		_err("Item '%s' não existe. Use 'itens' para listar." % raw)
	else:
		_err("Item ambíguo: " + ", ".join(found))
	return ""


# ------------------------------------------------------------------ execução
## Executa um comando. No co-op os comandos rodam no anfitrião (que é dono dos dados)
## sobre o personagem de quem digitou, e a resposta volta para o console de quem pediu.
func execute(raw: String) -> void:
	var text := raw.strip_edges()
	if text == "":
		return
	_out("[color=#7fd]› %s[/color]" % text.replace("[", "[lb]"))
	if _norm(text.split(" ", false)[0]) in ["cls", "clear"]:
		output.clear()
		return
	if Net.is_server():
		_run(text, Game.world.local_player() if Game.world != null else null)
	else:
		_remote_exec.rpc_id(1, text)


@rpc("any_peer", "reliable")
func _remote_exec(text: String) -> void:
	if not Net.is_server() or Game.world == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	_capture = []
	_run(text, Game.world.players.get(sender))
	var lines: Array = _capture
	_capture = null
	_remote_out.rpc_id(sender, lines)


@rpc("authority", "reliable")
func _remote_out(lines: Array) -> void:
	for l in lines:
		output.append_text(str(l) + "\n")


func _run(text: String, p: Player) -> void:
	var t := text.split(" ", false)
	var cmd := _norm(t[0])
	var args: PackedStringArray = t.slice(1)
	var w := Game.world
	if w == null or p == null or p.data == null:
		_err("Nenhum jogo em andamento.")
		return
	var d := p.data
	var pp := p.position if p.is_local() else p.net_pos
	match cmd:
		"ajuda", "help", "?":
			_out(HELP)
		"cls", "clear":
			output.clear()
		"itens", "items":
			_cmd_items(args)
		"dar", "give":
			_cmd_give(d, args)
		"dano", "damage", "hurt":
			_cmd_damage(d, args)
		"curar", "heal":
			_heal(d)
			_ok("Ferimentos, sangue e infecções curados.")
		"restaurar", "restore":
			_heal(d)
			d.pathogen = 0.0
			d.calories = SurvivorData.MAX_CAL
			d.water = 100.0
			if d.has_mask():
				d.equip["mascara"]["filtro"] = 100.0
				d.equip["mascara"]["dur"] = 100.0
			d.battery = 100.0
			d.heat = 0.0
			_ok("Tudo restaurado.")
		"set":
			_cmd_set(d, args)
		"skill":
			_cmd_skill(d, args)
		"spawn", "inimigo":
			_cmd_spawn(w, p, args)
		"limpar":
			var n := 0
			for e in get_tree().get_nodes_in_group("infected"):
				e.queue_free()
				n += 1
			_ok("%d infectados removidos." % n)
		"tp", "teleport":
			_cmd_tp(w, p, args)
		"pos":
			var tp := w.tile_pos(pp)
			_ok("Tile (%d, %d) · distância do centro %.1f/%d · esporos %.2f" % [roundi(tp.x), roundi(tp.y), tp.length(), int(World.RADIUS), w.spore_at(pp)])
		"matar", "kill":
			d.kill("Comando de console", "fisica")
			_ok("Morte física aplicada.")
		"infectar":
			d.kill("Comando de console (carga 100%)", "infeccao")
			_ok("Morte por infecção aplicada.")
		"implante", "implant":
			_cmd_implant(d, args)
		"god", "deus":
			d.god = not d.god
			_ok("Invulnerabilidade %s." % ("LIGADA" if d.god else "desligada"))
		"salvar", "save":
			Game.save_game()
			_ok("Jogo salvo.")
		"kit", "kit_medico", "kit_build", "kit_cyber":
			_cmd_kit(d, cmd)
		_:
			_err("Comando desconhecido: '%s'. Digite 'ajuda'." % cmd)


func _cmd_items(args: PackedStringArray) -> void:
	var filt := _norm(args[0]) if args.size() > 0 else ""
	var ids: Array = DB.ITEMS.keys()
	ids.sort()
	for id: String in ids:
		if filt == "" or id.contains(filt) or str(DB.ITEMS[id]["tipo"]).contains(filt):
			_out("[color=#ffe066]%s[/color] — %s [color=#888](%s)[/color]" % [id, DB.item_name(id), DB.ITEMS[id]["tipo"]])


func _cmd_give(d: SurvivorData, args: PackedStringArray) -> void:
	if args.is_empty():
		_err("Uso: dar <item> [qtd]   (ex: dar metal 20 · dar tudo 5)")
		return
	var n := clampi(int(args[1]) if args.size() > 1 and args[1].is_valid_int() else 1, 1, 999)
	if _norm(args[0]) == "tudo":
		for id: String in DB.ITEMS:
			d.give(id, n)
		_ok("Todos os itens adicionados (x%d); o que não coube ficou no chão." % n)
		return
	var id2 := _resolve_item(args[0])
	if id2 == "":
		return
	d.give(id2, n)
	_ok("+%d %s" % [n, DB.item_name(id2)])


func _cmd_damage(d: SurvivorData, args: PackedStringArray) -> void:
	if args.size() < 2 or not args[1].is_valid_float():
		_err("Uso: dano <membro|todos> <quantidade>   (membros: cabeca tronco braco_e braco_d perna_e perna_d)")
		return
	var amount := float(args[1])
	var which := args[0].to_lower()
	var targets: Array[String] = []
	if which in ["todos", "tudo"]:
		targets.assign(SurvivorData.LIMBS)
	elif LIMB_ALIASES.has(which):
		targets.append(LIMB_ALIASES[which])
	else:
		_err("Membro '%s' inválido." % which)
		return
	for l in targets:
		d.damage_limb(l, amount)
	_ok("Dano %d em %s.%s" % [int(amount), which, "  (god ativo: ignorado)" if d.god else ""])


func _heal(d: SurvivorData) -> void:
	for l in SurvivorData.LIMBS:
		var limb: Dictionary = d.limbs[l]
		limb["hp"] = 100.0
		limb["wound"] = 0
		limb["bleed"] = 0.0
		limb["infection"] = 0.0
		limb["disinfected"] = false
		limb["sutured"] = false
		limb["bandaged"] = false
		limb["heal"] = 0.0
	d.blood = 100.0
	d.antibiotic_t = 0.0


func _cmd_set(d: SurvivorData, args: PackedStringArray) -> void:
	if args.size() < 2 or not args[1].is_valid_float() or not STATS.has(_norm(args[0])):
		_err("Uso: set <stat> <valor>   stats: " + ", ".join(STATS.keys()))
		return
	var def: Array = STATS[_norm(args[0])]
	var v := clampf(float(args[1]), 0.0, float(def[1]))
	if def[0] == "filter":
		if not d.has_mask():
			_err("Vista uma máscara primeiro.")
			return
		d.equip["mascara"]["filtro"] = v
	else:
		d.set(def[0], v)
	_ok("%s = %d" % [_norm(args[0]), int(v)])


func _cmd_skill(d: SurvivorData, args: PackedStringArray) -> void:
	if args.size() < 2 or not args[1].is_valid_int():
		_err("Uso: skill <habilidade|todas> <0-10>   (" + " ".join(DB.SKILLS.keys()) + ")")
		return
	var lv := clampi(int(args[1]), 0, 10)
	var key := _norm(args[0])
	if key == "engenharia":
		key = "eletronica"
	var keys: Array[String] = []
	if key in ["todas", "todos"]:
		keys.assign(DB.SKILLS.keys())
	elif DB.SKILLS.has(key):
		keys.append(key)
	else:
		_err("Habilidade '%s' inválida." % key)
		return
	for k in keys:
		d.skills[k]["lv"] = lv
		d.skills[k]["xp"] = 0.0
	_ok("Habilidade(s) definida(s) para o nível %d." % lv)


func _cmd_spawn(w: World, p: Player, args: PackedStringArray) -> void:
	var elite := false
	var n := 1
	for a in args:
		if _norm(a) == "elite":
			elite = true
		elif a.is_valid_int():
			n = clampi(int(a), 1, 30)
	for i in n:
		var ang := randf() * TAU
		var off := Vector2.from_angle(ang) * randf_range(70.0, 120.0)
		w.spawn_infected((p.position if p.is_local() else p.net_pos) + Vector2(off.x, off.y * 0.5), elite)
	_ok("%d infectado(s) %s criado(s)." % [n, "de elite" if elite else "comum(ns)"])


func _cmd_tp(w: World, p: Player, args: PackedStringArray) -> void:
	var dest := Vector2.ZERO
	var label := ""
	if args.size() >= 2 and args[0].is_valid_int() and args[1].is_valid_int():
		var c := Vector2i(int(args[0]), int(args[1]))
		dest = w.ground.map_to_local(c)
		label = "tile (%d, %d)" % [c.x, c.y]
		if Vector2(c).length() > World.RADIUS * 0.85:
			label += " — ATENÇÃO: zona letal de esporos!"
	elif args.size() >= 1:
		match _norm(args[0]):
			"abrigo", "base", "casa":
				dest = w.ground.map_to_local(Vector2i.ZERO) + Vector2(0, 10)
				label = "Abrigo Alfa"
			"borda":
				var dir := w.tile_pos(p.position if p.is_local() else p.net_pos)
				if dir.length() < 1.0:
					dir = Vector2(1, 0)
				var c2 := Vector2i((dir.normalized() * World.RADIUS * 0.8).round())
				dest = w.ground.map_to_local(c2)
				label = "perto da borda (tile %d, %d)" % [c2.x, c2.y]
			"cadaver", "corpo":
				var nodes := get_tree().get_nodes_in_group("corpses")
				if nodes.is_empty():
					_err("Não há cadáveres no mapa.")
					return
				dest = (nodes[0] as Node2D).position + Vector2(24, 12)
				label = "o cadáver mais antigo"
			"elite":
				var found: Node2D = null
				for e in get_tree().get_nodes_in_group("infected"):
					if (e as Infected).legacy:
						found = e
						break
				if found == null:
					_err("Não há elites de legado no mapa.")
					return
				dest = found.position + Vector2(90, 45)
				label = "um infectado de elite (legado)"
			"vila":
				var v := _find_village(w, args.slice(1))
				if v == null:
					_err("Vila não encontrada. Use 'vila <0-%d>' ou parte do nome." % (w.villages.size() - 1))
					return
				dest = w.ground.map_to_local(v.cell) + Vector2(0, 40)
				label = "vila %s" % v.nome
			_:
				_err("Destino inválido. Veja 'ajuda'.")
				return
	else:
		_err("Uso: tp <x> <y> | tp abrigo | tp vila <n|nome> | tp borda | tp cadaver | tp elite")
		return
	p.teleport(dest)
	_ok("Teleportado para " + label + ".")


func _find_village(w: World, args: PackedStringArray) -> VillageData:
	if args.is_empty():
		return null
	if args[0].is_valid_int():
		var i := int(args[0])
		return w.villages[i] if i >= 0 and i < w.villages.size() else null
	var q := _norm(" ".join(args))
	for v in w.villages:
		if _norm(v.nome).contains(q):
			return v
	return null


func _cmd_implant(d: SurvivorData, args: PackedStringArray) -> void:
	if args.is_empty():
		_err("Uso: implante <pulmao|hud|braco|pernas|derme|mk1|mk2> (instala direto, sem cirurgia)")
		return
	var q := _norm(args[0])
	var id := ""
	for k: String in DB.IMPLANTS:
		if k.contains(q):
			id = k
			break
	if id == "":
		_err("Implante inválido. Opções: pulmao, hud, braco, pernas, derme, mk1, mk2.")
		return
	var slot: String = DB.IMPLANTS[id]["slot"]
	d.implants[slot] = {"id": id, "integ": 100.0}
	if d.battery <= 0.0:
		d.battery = 100.0
	_ok("Implante instalado: %s (bateria %d%%)." % [DB.item_name(id), int(d.battery)])


func _cmd_kit(d: SurvivorData, which: String) -> void:
	var items := {}
	match which:
		"kit":
			d.wear(Items.make("mochila_militar")[0])
			d.wear(Items.make("coldre")[0])
			items = {"feijao": 4, "carne_seca": 3, "barra_cereal": 3, "agua_limpa": 5, "filtro": 3, "supressor": 3,
				"bandagem": 6, "bateria": 2, "machete": 1, "fita": 2}
		"kit_medico":
			items = {"bandagem": 10, "antisseptico": 10, "kit_sutura": 6, "antibiotico": 6, "supressor": 4, "kit_cirurgico": 2}
		"kit_build":
			# muito material: o que não couber fica num saco no chão
			d.wear(Items.make("mochila_militar")[0])
			items = {"metal": 30, "sucata": 30, "madeira": 30, "combustivel": 4, "filtro": 2, "bateria": 3}
			for s in ["carpintaria", "metalurgia", "eletronica"]:
				d.skills[s]["lv"] = maxi(d.level(s), 5)
		"kit_cyber":
			items = {"proc_neural_mk1": 1, "implante_pulmao": 1, "implante_hud": 1, "implante_braco": 1, "kit_cirurgico": 4, "bateria": 4}
			d.battery = 100.0
			for s in ["medicina", "cibernetica"]:
				d.skills[s]["lv"] = maxi(d.level(s), 6)
	for k in items:
		d.give(k, int(items[k]))
	_ok("Código '%s' ativado (o que não coube ficou no chão)." % which)

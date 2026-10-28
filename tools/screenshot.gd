extends SceneTree
## Roda uma cena por N frames (opcionalmente segurando ações de input) e salva
## um PNG da tela. Chamado por tools/screenshot.sh.
##
## Argumentos (depois do "--"):
##   --out=/caminho/arquivo.png
##   --scene=res://scenes/main.tscn
##   --frames=60
##   --hold=move_right:40,move_down:20   (ação:frame até o qual fica pressionada)
##   --debug="30:give:metal,5;40:tab:3"  (frame:comando de Game.debug_command)
##   --autostart=new|continue|host|join:IP (repassado ao Main: pula a tela de título)
##   --stay=300                          (continua rodando N quadros depois do print; testes de rede)

var _out := "/tmp/shot.png"
var _scene_path := "res://scenes/main.tscn"
var _frames := 60
var _holds: Array[Dictionary] = []
var _debug: Array[Dictionary] = []
var _frame := 0
var _stay := 0
var _captured := -1


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--scene="):
			_scene_path = arg.substr(8)
		elif arg.begins_with("--stay="):
			_stay = int(arg.substr(7))
		elif arg.begins_with("--frames="):
			_frames = int(arg.substr(9))
		elif arg.begins_with("--debug="):
			for part in arg.substr(8).split(";"):
				var kv2 := part.split(":", true, 1)
				if kv2.size() == 2:
					_debug.append({"frame": int(kv2[0]), "cmd": kv2[1]})
		elif arg.begins_with("--hold="):
			for part in arg.substr(7).split(","):
				var kv := part.split(":")
				if kv.size() == 2:
					_holds.append({"action": kv[0], "until": int(kv[1])})
	root.add_child(load(_scene_path).instantiate())


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		for hold in _holds:
			Input.action_press(hold.action)
	for dbg in _debug:
		if _frame == dbg.frame:
			var game := root.get_node_or_null("Game")
			if game != null:
				game.call("debug_command", dbg.cmd)
	for hold in _holds:
		if _frame == hold.until:
			Input.action_release(hold.action)
	if _frame == _frames:
		_capture()
		_captured = _frame
	return _captured >= 0 and _frame >= _captured + _stay


func _capture() -> void:
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	var err := img.save_png(_out)
	print("screenshot: %s (%dx%d) erro=%d" % [_out, img.get_width(), img.get_height(), err])

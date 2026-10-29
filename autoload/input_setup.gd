extends Node
## Registra as ações de input por código, para o mapeamento ficar versionado
## de forma legível (em vez de serializado no project.godot).

const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"attack": [KEY_SPACE, KEY_J],
	"interact": [KEY_E],
	"menu": [KEY_TAB],
	"inventory": [KEY_I],
	"map": [KEY_M],
	"build_menu": [KEY_B],
	"vehicle_status": [KEY_V],
	"cancel": [KEY_ESCAPE],
	"demolish": [KEY_X],
	"save": [KEY_F5],
	"sprint": [KEY_SHIFT],
	"sneak": [KEY_C],
	"reload": [KEY_R],
	"hot_1": [KEY_1],
	"hot_2": [KEY_2],
	"hot_3": [KEY_3],
	"hot_4": [KEY_4],
	"hot_5": [KEY_5],
}


func _ready() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", click)

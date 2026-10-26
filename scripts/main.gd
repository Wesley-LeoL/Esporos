extends Node2D
## Cena principal de desenvolvimento.

@onready var _player: Player = $Player
@onready var _debug_label: Label = $HUD/DebugLabel


func _process(_delta: float) -> void:
	_debug_label.text = "Esporos - dev build\nDireção: %s\nPos: %s" % [
		Player.FACING_NAMES[_player.facing],
		_player.position.round(),
	]

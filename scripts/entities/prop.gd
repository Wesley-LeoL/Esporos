class_name Prop
extends Node2D
## Objeto de cenário sem colisão (placas, antenas). O nó fica na base do objeto,
## que é a chave de ordenação em profundidade.

var art := ""
var variant := 0


func _ready() -> void:
	add_child(ArtDB.sprite(art, variant, "base"))

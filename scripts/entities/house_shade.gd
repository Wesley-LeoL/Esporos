class_name HouseShade
extends Node2D
## Sombra sobre o piso de um prédio visto de fora (desenhada na camada do chão, abaixo das
## entidades). O nível vem de House.

var world: World
var rect := Rect2i()
var alpha := 0.0


func _draw() -> void:
	if alpha <= 0.01:
		return
	var g := world.ground
	var p0 := g.map_to_local(rect.position) + Vector2(0, -World.HALF_H)
	var hx := Vector2(World.HALF_W, World.HALF_H)
	var hy := Vector2(-World.HALF_W, World.HALF_H)
	var w := float(rect.size.x)
	var d := float(rect.size.y)
	var pts := PackedVector2Array([p0, p0 + hx * w, p0 + hx * w + hy * d, p0 + hy * d])
	draw_colored_polygon(pts, Color(0.02, 0.02, 0.05, alpha))

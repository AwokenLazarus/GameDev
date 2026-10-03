class_name WallBlock
extends Node2D
## One free-standing block of masonry inside the arena (cover, pillar, tomb). Sits at its
## footprint's centre so the stage camera can depth-sort it against actors.

var _half := Vector2(20.0, 20.0)
var _height := 58.0

@onready var occluder: LightOccluder2D = $Occluder


func setup(size: Vector2, height: float, masonry: Material) -> void:
	_half = size * 0.5
	_height = height
	material = masonry
	var shape := OccluderPolygon2D.new()
	shape.polygon = PackedVector2Array(
		[
			Vector2(-_half.x, -_half.y),
			Vector2(_half.x, -_half.y),
			Vector2(_half.x, _half.y),
			Vector2(-_half.x, _half.y)
		]
	)
	occluder.occluder = shape
	queue_redraw()


func _draw() -> void:
	var lift := IsoView.up(_height)
	var a := Vector2(-_half.x, -_half.y)
	var b := Vector2(_half.x, -_half.y)
	var c := Vector2(_half.x, _half.y)
	var d := Vector2(-_half.x, _half.y)
	## Masonry runs on in world units so neighbouring blocks join without a seam.
	var o := global_position
	_face(b, c, lift, StageWalls.LIT, o.y + b.y, o.y + c.y)
	_face(d, c, lift, StageWalls.SHADE, o.x + d.x, o.x + c.x)
	var uv := Vector2(0.0, 0.95)
	var cap := StageWalls.CAP
	draw_polygon(
		PackedVector2Array([a + lift, b + lift, c + lift, d + lift]),
		PackedColorArray([cap, cap, cap, cap]),
		PackedVector2Array([uv, uv, uv, uv])
	)


func _face(p0: Vector2, p1: Vector2, lift: Vector2, tint: Color, u0: float, u1: float) -> void:
	draw_polygon(
		PackedVector2Array([p0, p1, p1 + lift, p0 + lift]),
		PackedColorArray([tint, tint, tint, tint]),
		PackedVector2Array([Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 1.0), Vector2(u0, 1.0)])
	)

class_name StageWalls
extends Node2D
## Draws the arena's built edge on the iso stage: either the two far walls with their
## corner piers (WALLS), or the cut face of the floor slab on the two near edges (SLAB).
## Geometry is world-space; height is added with IsoView.up().

enum Part { WALLS, SLAB }

const PIER := 26.0
const THICK := 20.0
## Face tints: +x faces look toward the moon, +y faces are in shade.
const LIT := Color(1.0, 0.98, 1.06)
const SHADE := Color(0.5, 0.5, 0.62)
const CAP := Color(1.25, 1.22, 1.3)

@export var part: Part = Part.WALLS

var _half := Vector2(480.0, 320.0)
var _height := 124.0
var _on := true


func build(half: Vector2, height: float, on: bool = true) -> void:
	_half = half
	_height = height
	_on = on
	queue_redraw()


func _draw() -> void:
	if not _on:
		return
	var a := Vector2(-_half.x, -_half.y)
	var b := Vector2(_half.x, -_half.y)
	var c := Vector2(_half.x, _half.y)
	var d := Vector2(-_half.x, _half.y)
	if part == Part.SLAB:
		var drop := IsoView.up(-_height)
		_quad(b, c, drop, LIT, b.y, c.y)
		_quad(d, c, drop, SHADE, d.x, c.x)
		return
	var rise := IsoView.up(_height)
	## Far-right wall (faces +y, shaded) and far-left wall (faces +x, moonlit).
	_quad(a, b, rise, SHADE, a.x, b.x)
	_quad(a, d, rise, LIT, a.y, d.y)
	_cap(a + rise, b + rise, Vector2(0.0, -THICK))
	_cap(a + rise, d + rise, Vector2(-THICK, 0.0))
	for corner: Vector2 in [a, b, d]:
		_pier(corner, _height + 30.0)


func _quad(p0: Vector2, p1: Vector2, lift: Vector2, tint: Color, u0: float, u1: float) -> void:
	draw_polygon(
		PackedVector2Array([p0, p1, p1 + lift, p0 + lift]),
		PackedColorArray([tint, tint, tint, tint]),
		PackedVector2Array(
			[Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 1.0), Vector2(u0, 1.0)]
		)
	)


func _cap(p0: Vector2, p1: Vector2, out: Vector2) -> void:
	var uv := Vector2(0.0, 0.95)
	draw_polygon(
		PackedVector2Array([p0, p1, p1 + out, p0 + out]),
		PackedColorArray([CAP, CAP, CAP, CAP]),
		PackedVector2Array([uv, uv, uv, uv])
	)


## Square pier: its two near faces and its top.
func _pier(at: Vector2, h: float) -> void:
	var r := PIER * 0.5
	var lift := IsoView.up(h)
	_quad(at + Vector2(r, -r), at + Vector2(r, r), lift, LIT, 0.0, PIER)
	_quad(at + Vector2(-r, r), at + Vector2(r, r), lift, SHADE, 0.0, PIER)
	var uv := Vector2(0.0, 0.95)
	draw_polygon(
		PackedVector2Array(
			[
				at + Vector2(-r, -r) + lift,
				at + Vector2(r, -r) + lift,
				at + Vector2(r, r) + lift,
				at + Vector2(-r, r) + lift
			]
		),
		PackedColorArray([CAP, CAP, CAP, CAP]),
		PackedVector2Array([uv, uv, uv, uv])
	)

class_name SetPiece
extends Node2D
## Code-drawn standing object on the iso stage: reward doorway, strongbox, moon altar,
## blood well. Drawn in screen units with the ground point at the origin, y up negative.

const STONE := Color(0.2, 0.17, 0.18)
const STONE_LIT := Color(0.42, 0.37, 0.36)
const IRON := Color(0.13, 0.12, 0.14)

@export var kind: String = "door":
	set(value):
		kind = value
		queue_redraw()
@export var tint: Color = MWPalette.GILT:
	set(value):
		tint = value
		queue_redraw()
## Used up: the glow goes out.
@export var spent: bool = false:
	set(value):
		spent = value
		queue_redraw()


func _ready() -> void:
	IsoView.stand(self)


func _glow(strength: float = 1.0) -> Color:
	if spent:
		return Color(0.22, 0.2, 0.2)
	## Over 1.0 so the stage glow picks it up.
	return Color(tint.r * 1.5 * strength, tint.g * 1.5 * strength, tint.b * 1.5 * strength)


func _draw() -> void:
	match kind:
		"chest":
			_strongbox()
		"moon_altar":
			_altar()
		"blood_well":
			_well()
		_:
			_door()


func _arch(half_w: float, spring: float, apex: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(-half_w, 0.0), Vector2(-half_w, -spring)])
	for i: int in range(1, 8):
		var t := float(i) / 8.0
		pts.append(Vector2(-half_w * (1.0 - t), -spring - (apex - spring) * sin(t * PI * 0.5)))
	pts.append(Vector2(0.0, -apex))
	for i: int in range(7, 0, -1):
		var t := float(i) / 8.0
		pts.append(Vector2(half_w * (1.0 - t), -spring - (apex - spring) * sin(t * PI * 0.5)))
	pts.append(Vector2(half_w, -spring))
	pts.append(Vector2(half_w, 0.0))
	return pts


## Lancet doorway: light in the opening, dark stone round it, a keystone in the reward's colour.
func _door() -> void:
	var inner := _arch(21.0, 50.0, 86.0)
	var colors := PackedColorArray()
	for p: Vector2 in inner:
		colors.append(Color(_glow(), lerpf(0.8, 0.12, clampf(-p.y / 86.0, 0.0, 1.0))))
	draw_polygon(inner, colors)
	var frame := _arch(27.0, 52.0, 96.0)
	draw_polyline(frame, STONE, 10.0, true)
	draw_polyline(_arch(32.0, 53.0, 102.0), STONE_LIT, 2.0, true)
	draw_rect(Rect2(-36.0, -6.0, 13.0, 6.0), STONE_LIT)
	draw_rect(Rect2(23.0, -6.0, 13.0, 6.0), STONE_LIT)
	var key := Vector2(0.0, -98.0)
	draw_colored_polygon(
		PackedVector2Array(
			[key + Vector2(0, -9), key + Vector2(6, 0), key + Vector2(0, 9), key + Vector2(-6, 0)]
		),
		_glow(1.2)
	)


func _strongbox() -> void:
	var body := PackedVector2Array(
		[Vector2(-24, 0), Vector2(24, 0), Vector2(24, -22), Vector2(-24, -22)]
	)
	draw_colored_polygon(body, Color(0.24, 0.17, 0.12))
	var lid := PackedVector2Array(
		[Vector2(-24, -22), Vector2(24, -22), Vector2(19, -35), Vector2(-19, -35)]
	)
	draw_colored_polygon(lid, Color(0.36, 0.26, 0.18))
	for x: float in [-16.0, 0.0, 16.0]:
		draw_line(Vector2(x, 0.0), Vector2(x, -22.0), IRON, 3.0)
		draw_line(Vector2(x, -22.0), Vector2(x * 0.8, -35.0), IRON, 3.0)
	draw_polyline(
		PackedVector2Array([body[0], body[1], body[2], lid[2], lid[3], body[3], body[0]]),
		IRON,
		2.0,
		true
	)
	draw_line(body[3], body[2], IRON, 2.0)
	var lock := Vector2(0.0, -20.0)
	draw_colored_polygon(
		PackedVector2Array(
			[
				lock + Vector2(0, -6),
				lock + Vector2(5, 0),
				lock + Vector2(0, 6),
				lock + Vector2(-5, 0)
			]
		),
		_glow()
	)


func _altar() -> void:
	var stone := PackedVector2Array(
		[Vector2(-15, 0), Vector2(15, 0), Vector2(10, -62), Vector2(0, -76), Vector2(-10, -62)]
	)
	draw_polygon(stone, PackedColorArray([STONE, STONE, STONE_LIT, STONE_LIT, STONE_LIT]))
	draw_rect(Rect2(-22.0, -5.0, 44.0, 5.0), STONE_LIT)
	draw_arc(Vector2(0.0, -44.0), 9.0, PI * 0.5, PI * 1.5, 16, _glow(), 2.6, true)
	draw_arc(Vector2(4.0, -44.0), 7.0, PI * 0.6, PI * 1.4, 12, _glow(0.6), 1.6, true)
	for y: float in [-24.0, -18.0]:
		draw_line(Vector2(-5.0, y), Vector2(5.0, y), _glow(0.5), 1.3, true)


func _well() -> void:
	var rim := PackedVector2Array()
	var pool := PackedVector2Array()
	for i: int in 24:
		var a := TAU * float(i) / 24.0
		rim.append(Vector2(cos(a) * 30.0, -16.0 + sin(a) * 13.0))
		pool.append(Vector2(cos(a) * 22.0, -16.0 + sin(a) * 9.0))
	var wall := PackedVector2Array([Vector2(-30, -16), Vector2(-30, 0)])
	for i: int in 13:
		var a := PI - PI * float(i) / 12.0
		wall.append(Vector2(cos(a) * 30.0, sin(a) * 13.0))
	wall.append(Vector2(30, -16))
	draw_colored_polygon(wall, STONE)
	draw_colored_polygon(rim, STONE_LIT)
	draw_colored_polygon(pool, _glow(0.8))
	rim.append(rim[0])
	draw_polyline(rim, IRON, 1.5, true)

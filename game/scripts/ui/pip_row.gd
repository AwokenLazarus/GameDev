class_name PipRow
extends Control
## A row of small lozenges: feed stacks, cast charges, bursts cleared.

@export var count: int = 5:
	set(v):
		count = maxi(v, 0)
		_resize()
@export var lit: int = 0:
	set(v):
		lit = v
		queue_redraw()
## Index drawn as "here now" (bright outline, breathing); -1 for none.
@export var current: int = -1:
	set(v):
		current = v
		queue_redraw()
@export var color: Color = MWPalette.BLOOD_BRIGHT:
	set(v):
		color = v
		queue_redraw()
@export var pip: float = 10.0:
	set(v):
		pip = v
		_resize()
@export var gap: float = 8.0:
	set(v):
		gap = v
		_resize()


func _ready() -> void:
	_resize()


func _resize() -> void:
	custom_minimum_size = Vector2(count * pip + maxi(count - 1, 0) * gap, pip * 1.5)
	queue_redraw()


func _draw() -> void:
	var cy := size.y * 0.5
	for i: int in count:
		var c := Vector2(pip * 0.5 + float(i) * (pip + gap), cy)
		var h := pip * 0.72
		var pts := PackedVector2Array(
			[c + Vector2(0, -h), c + Vector2(pip * 0.5, 0), c + Vector2(0, h), c + Vector2(-pip * 0.5, 0)]
		)
		if i < lit:
			draw_colored_polygon(pts, color)
		pts.append(pts[0])
		var edge := Color(MWPalette.BONE, 0.9) if i == current else Color(MWPalette.BONE, 0.35)
		if i < lit:
			edge = color.lightened(0.35)
		draw_polyline(pts, edge, 1.2 if i != current else 1.8, true)

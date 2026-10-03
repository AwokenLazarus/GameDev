class_name PatronSigil
extends Control
## Code-drawn patron mark, crisp at any size (HUD pips to boon cards).
##   dust_compact  marshal's star over a rail
##   red_petition  flame rising through chevrons
##   house_veyra   crowned blood drop
##   church        the pale sun in eclipse

@export var patron: String = "":
	set(value):
		patron = value
		queue_redraw()
@export var tint: Color = MWPalette.BONE:
	set(value):
		tint = value
		queue_redraw()
## Draw a thin ring round the mark (boon cards).
@export var ringed: bool = false:
	set(value):
		ringed = value
		queue_redraw()


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	var w := maxf(1.3, r / 13.0)
	if ringed:
		draw_arc(c, r - w, 0.0, TAU, 64, Color(tint, 0.55), w, true)
		draw_arc(c, r - w * 4.0, 0.0, TAU, 64, Color(tint, 0.2), w * 0.7, true)
		r *= 0.68
	match patron:
		"dust_compact":
			_star(c, r, w)
		"red_petition":
			_flame(c, r, w)
		"house_veyra":
			_drop(c, r, w)
		"church":
			_sun(c, r, w)
		_:
			_lozenge(c, r * 0.6, w)


func _path(c: Vector2, r: float, pts: Array[Vector2], w: float, closed: bool = true) -> void:
	var line := PackedVector2Array()
	for p: Vector2 in pts:
		line.append(c + p * r)
	if closed:
		line.append(line[0])
	draw_polyline(line, tint, w, true)


func _fill(c: Vector2, r: float, pts: Array[Vector2], alpha: float) -> void:
	var poly := PackedVector2Array()
	for p: Vector2 in pts:
		poly.append(c + p * r)
	draw_colored_polygon(poly, Color(tint, alpha))


func _lozenge(c: Vector2, r: float, w: float) -> void:
	_path(c, r, [Vector2(0, -1), Vector2(0.7, 0), Vector2(0, 1), Vector2(-0.7, 0)], w)


## Dust Compact: a spur rowel on its rail. Frontier iron, deliberately not a
## hexagram or any other religious star (lead review, 2026-10-03).
func _star(c: Vector2, r: float, w: float) -> void:
	var spikes: int = 10
	var hub: float = 0.3
	for i: int in spikes:
		var a := TAU * float(i) / float(spikes) - PI * 0.5
		var tip := Vector2(cos(a), sin(a)) * 0.9
		var side := Vector2(-sin(a), cos(a)) * 0.07
		var base := Vector2(cos(a), sin(a)) * hub
		var spike: Array[Vector2] = [base + side, tip, base - side]
		_fill(c, r, spike, 0.5)
		_path(c, r, spike, w * 0.6)
	draw_arc(c, r * hub, 0.0, TAU, 32, tint, w, true)
	draw_circle(c, r * 0.1, tint, true, -1.0, true)
	## The axle the rowel turns on.
	draw_line(c + Vector2(-0.5, 0.0) * r, c + Vector2(-0.12, 0.0) * r, Color(tint, 0.8), w, true)
	## The rail it rides.
	draw_line(c + Vector2(-0.95, 0.98) * r, c + Vector2(0.95, 0.98) * r, Color(tint, 0.7), w, true)


func _flame(c: Vector2, r: float, w: float) -> void:
	var flame: Array[Vector2] = [
		Vector2(0.0, -1.0),
		Vector2(0.3, -0.52),
		Vector2(0.44, -0.12),
		Vector2(0.3, 0.2),
		Vector2(0.0, 0.34),
		Vector2(-0.3, 0.2),
		Vector2(-0.44, -0.12),
		Vector2(-0.16, -0.42),
	]
	_fill(c, r, flame, 0.22)
	_path(c, r, flame, w)
	for i: int in 2:
		var y := 0.52 + 0.3 * float(i)
		var reach := 0.62 - 0.14 * float(i)
		_path(c, r, [Vector2(-reach, y + 0.2), Vector2(0.0, y), Vector2(reach, y + 0.2)], w, false)


func _drop(c: Vector2, r: float, w: float) -> void:
	var drop: Array[Vector2] = [Vector2(0.0, -0.42)]
	for i: int in 13:
		var a := lerpf(-0.42, PI + 0.42, float(i) / 12.0)
		drop.append(Vector2(cos(a) * 0.48, 0.44 + sin(a) * 0.48))
	_fill(c, r, drop, 0.22)
	_path(c, r, drop, w)
	## Coronet.
	_path(
		c,
		r,
		[
			Vector2(-0.62, -0.5),
			Vector2(-0.62, -0.98),
			Vector2(-0.3, -0.7),
			Vector2(0.0, -1.0),
			Vector2(0.3, -0.7),
			Vector2(0.62, -0.98),
			Vector2(0.62, -0.5),
		],
		w,
		false
	)


func _sun(c: Vector2, r: float, w: float) -> void:
	draw_arc(c, r * 0.46, 0.0, TAU, 40, tint, w, true)
	## Eclipse: the moon's limb crossing the disc.
	draw_arc(
		c + Vector2(0.2, -0.08) * r, r * 0.4, PI * 0.62, PI * 1.5, 24, Color(tint, 0.75), w, true
	)
	for i: int in 12:
		var a := TAU * float(i) / 12.0
		var d := Vector2(cos(a), sin(a))
		var far := 1.0 if i % 3 == 0 else 0.78
		draw_line(c + d * r * 0.62, c + d * r * far, tint, w, true)

class_name BloodBar
extends Control
## Thin gauge: a hairline track, a fill, and a pale chip that trails the fill when it
## drops. Used for HP, the hunt gate and the general's bar.

@export var max_value: float = 100.0:
	set(v):
		max_value = maxf(v, 0.001)
		queue_redraw()
@export var value: float = 100.0:
	set(v):
		if v < value:
			_hold = 0.35
		value = v
		_lag = maxf(_lag, value)
		queue_redraw()
@export var fill: Color = MWPalette.BLOOD_BRIGHT
@export var track: Color = Color(0.0, 0.0, 0.0, 0.55)
@export var frame: Color = Color(0.9, 0.84, 0.76, 0.5)
## Fractions (0..1) where a notch is cut, e.g. boss phase thresholds.
@export var notches: PackedFloat32Array = []:
	set(v):
		notches = v
		queue_redraw()
## Grow from the centre outward instead of from the left.
@export var centred: bool = false

var _lag: float = 0.0
var _hold: float = 0.0


func _process(delta: float) -> void:
	if _lag <= value:
		return
	if _hold > 0.0:
		_hold -= delta
		return
	_lag = maxf(value, _lag - max_value * delta * 0.9)
	queue_redraw()


func _span(frac: float) -> Rect2:
	var w := size.x * clampf(frac, 0.0, 1.0)
	if centred:
		return Rect2((size.x - w) * 0.5, 0.0, w, size.y)
	return Rect2(0.0, 0.0, w, size.y)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), track)
	draw_rect(_span(_lag / max_value), Color(0.95, 0.9, 0.84, 0.8))
	var body := _span(value / max_value)
	draw_rect(body, fill)
	## Lit upper edge so the fill reads as liquid, not a flat strip.
	draw_rect(Rect2(body.position, Vector2(body.size.x, maxf(1.0, size.y * 0.3))), fill.lightened(0.3))
	draw_rect(Rect2(-1.0, -1.0, size.x + 2.0, size.y + 2.0), frame, false, 1.0)
	## End ticks.
	draw_line(Vector2(-1.0, -4.0), Vector2(-1.0, size.y + 4.0), frame, 1.0)
	draw_line(Vector2(size.x + 1.0, -4.0), Vector2(size.x + 1.0, size.y + 4.0), frame, 1.0)
	for n: float in notches:
		var x := size.x * n
		draw_line(Vector2(x, -3.0), Vector2(x, size.y + 3.0), Color(MWPalette.INK, 0.95), 2.0)
		draw_line(Vector2(x, -3.0), Vector2(x, -1.0), frame, 1.0)

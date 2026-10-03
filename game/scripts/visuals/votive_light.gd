class_name VotiveLight
extends PointLight2D
## Small flickering flame light (wall niches, landmarks, doors).

var _base := 1.0
var _seed := 0.0


func setup(tint: Color, strength: float, reach: float) -> void:
	color = tint
	_base = strength
	energy = strength
	texture_scale = reach / 128.0
	_seed = randf() * 100.0


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001 + _seed
	energy = _base * (0.86 + 0.1 * sin(t * 9.0) + 0.06 * sin(t * 23.0 + 1.7))

extends Node2D
## Telegraphed puddle: void hurts players on a cooldown; ward hastes nearby foes.

var kind: String = "void"
var life: float = 2.4
var pulse_cd: float = 0.75
var damage: float = 8.0
var radius: float = 54.0
var _pulse: float = 0.0
var _hit_cd: Dictionary = {}
var _vis: Polygon2D


func setup(pos: Vector2, zone_kind: String, seconds: float = 2.4, dmg: float = 8.0) -> void:
	global_position = pos
	kind = zone_kind
	life = seconds
	damage = dmg
	_vis = Polygon2D.new()
	_vis.z_index = -4
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	_vis.polygon = pts
	if kind == "ward":
		_vis.color = Color(0.35, 0.72, 0.45, 0.38)
	else:
		_vis.color = Color(0.42, 0.18, 0.55, 0.40)
	add_child(_vis)


func _process(delta: float) -> void:
	life -= delta
	_pulse -= delta
	for id in _hit_cd.keys():
		_hit_cd[id] = float(_hit_cd[id]) - delta
		if float(_hit_cd[id]) <= 0.0:
			_hit_cd.erase(id)
	if _vis:
		_vis.modulate.a = 0.55 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
	if _pulse <= 0.0:
		_pulse = pulse_cd
		_pulse_once()
	if life <= 0.0:
		queue_free()


func _pulse_once() -> void:
	if kind == "ward":
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e) or e == self:
				continue
			if global_position.distance_to(e.global_position) > radius + 8.0:
				continue
			if e.has_method("apply_haste"):
				e.apply_haste(1.1, 1.22)
		return
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or not p.has_method("apply_hit"):
			continue
		if global_position.distance_to(p.global_position) > radius:
			continue
		var id := p.get_instance_id()
		if _hit_cd.has(id):
			continue
		_hit_cd[id] = pulse_cd
		p.apply_hit(damage, global_position)

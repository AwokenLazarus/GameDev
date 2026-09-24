extends "res://scripts/combat/enemy.gd"
## Caster / support — holds mid-range, telegraphs a ward (allies) or void puddle.

const ZONE := preload("res://scripts/combat/hazard_zone.gd")
const WANT := 200.0
const BAND := 40.0
const CAST_WIND := 0.46

var _cast_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	archetype = "caster"
	move_speed = 70.0
	contact_damage = 8.0
	_attack_cd = 0.9
	super._ready()


func _ai_tick(delta: float) -> void:
	if _player == null:
		return
	var dir := (_player.global_position - global_position)
	var dist := dir.length()
	if _winding:
		_windup -= delta
		_wind_t += delta
		scale = _base_scale * (1.0 + 0.13 * sin(_wind_t * 17.0))
		velocity = Vector2.ZERO
		move_and_slide()
		if _windup <= 0.0:
			_winding = false
			scale = _base_scale
			_attack_cd = 1.6
			_drop_zone()
		return
	_keep_range(dir, dist, WANT, BAND, current_move_speed())
	_attack_cd -= delta
	if dist < 340.0 and _attack_cd <= 0.0:
		_cast_pos = _pick_zone_pos(dir, dist)
		_start_windup(CAST_WIND, Color(0.7, 0.4, 1.0), _cast_pos - global_position, Vector2(1.2, 1.2))


func _pick_zone_pos(dir: Vector2, dist: float) -> Vector2:
	if _ally_nearby():
		return global_position + dir.normalized() * 36.0
	if dist < 80.0:
		return _player.global_position
	return global_position + dir.normalized() * clampf(dist * 0.55, 70.0, 160.0)


func _ally_nearby() -> bool:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not is_instance_valid(e):
			continue
		if global_position.distance_to(e.global_position) < 130.0:
			return true
	return false


func _drop_zone() -> void:
	if actor_visual:
		actor_visual.play_oneshot("attack", 10.0)
	var zone: Node2D = ZONE.new()
	get_parent().add_child(zone)
	var kind := "ward" if _ally_nearby() else "void"
	zone.setup(_cast_pos, kind, 2.3, strike_damage())

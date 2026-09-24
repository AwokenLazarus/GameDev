extends "res://scripts/combat/enemy.gd"
## Charger / brute — telegraph, then a one-hit dash (hit_ids per player).

const DASH_WIND := 0.45
const DASH_TIME := 0.38
const DASH_SPEED := 320.0
const DASH_RANGE := 34.0

var _dashing: bool = false
var _dash_left: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _hit_ids: Dictionary = {}


func _ready() -> void:
	archetype = "charger"
	move_speed = 82.0
	contact_damage = 12.0
	max_hp = 48.0
	_attack_cd = 0.4
	super._ready()


func _on_attack_cancelled() -> void:
	_dashing = false
	_dash_left = 0.0
	_hit_ids.clear()


func _ai_tick(delta: float) -> void:
	if _player == null:
		return
	var dir := (_player.global_position - global_position)
	var dist := dir.length()
	if _dashing:
		_tick_dash(delta)
		return
	if _winding:
		_windup -= delta
		_wind_t += delta
		scale = _base_scale * (1.0 + 0.16 * sin(_wind_t * 16.0))
		velocity = Vector2.ZERO
		move_and_slide()
		if _windup <= 0.0:
			_winding = false
			scale = _base_scale
			_begin_dash()
		return
	_chase(dir, current_move_speed())
	_attack_cd -= delta
	if dist < 168.0 and _attack_cd <= 0.0:
		var mark := dir.normalized() * minf(dist, 140.0)
		_start_windup(DASH_WIND, Color(1.5, 0.4, 0.2), mark, Vector2(1.15, 0.5))


func _begin_dash() -> void:
	_dashing = true
	_dash_left = DASH_TIME
	_hit_ids.clear()
	if _player != null and is_instance_valid(_player):
		_dash_dir = (_player.global_position - global_position).normalized()
	if _dash_dir.length() < 0.1:
		_dash_dir = Vector2.RIGHT
	if actor_visual:
		actor_visual.play_oneshot("attack", 12.0)
	_VFX.dust_puff(get_parent(), global_position)


func _tick_dash(delta: float) -> void:
	_dash_left -= delta
	velocity = _dash_dir * DASH_SPEED
	move_and_slide()
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or not p.has_method("apply_hit"):
			continue
		var id := p.get_instance_id()
		if _hit_ids.has(id):
			continue
		if global_position.distance_to(p.global_position) >= DASH_RANGE:
			continue
		_hit_ids[id] = true
		p.apply_hit(strike_damage(), global_position)
	if _dash_left <= 0.0:
		_dashing = false
		_attack_cd = 1.15
		velocity = Vector2.ZERO

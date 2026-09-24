extends "res://scripts/combat/enemy.gd"
## Ranged shooter — holds distance, telegraphs a straight bolt.

const PROJ := preload("res://scenes/entities/projectile.tscn")
const WANT := 210.0
const BAND := 36.0
const SHOT_WIND := 0.42

func _ready() -> void:
	archetype = "ranged"
	move_speed = 76.0
	contact_damage = 8.0
	_attack_cd = 0.55
	super._ready()


func _ai_tick(delta: float) -> void:
	if _player == null:
		return
	var dir := (_player.global_position - global_position)
	var dist := dir.length()
	if _winding:
		_windup -= delta
		_wind_t += delta
		scale = _base_scale * (1.0 + 0.12 * sin(_wind_t * 18.0))
		velocity = Vector2.ZERO
		move_and_slide()
		if _windup <= 0.0:
			_winding = false
			scale = _base_scale
			_attack_cd = 1.15
			_fire_bolt()
		return
	_keep_range(dir, dist, WANT, BAND, current_move_speed())
	_attack_cd -= delta
	if dist < 320.0 and dist > 70.0 and _attack_cd <= 0.0:
		var aim := dir.normalized() * minf(dist, 200.0)
		_start_windup(SHOT_WIND, Color(1.45, 0.75, 0.25), aim, Vector2(0.7, 0.7))


func _fire_bolt() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var dir := (_player.global_position - global_position)
	if dir.length() < 4.0:
		return
	if actor_visual:
		actor_visual.play_oneshot("attack", 12.0)
	var bolt: Node = PROJ.instantiate()
	get_parent().add_child(bolt)
	bolt.setup(global_position, dir.normalized(), strike_damage(), self, false, 260.0)
	if bolt.has_method("make_hostile"):
		bolt.make_hostile()
	if "visual" in bolt and bolt.visual:
		bolt.visual.modulate = Color(0.95, 0.7, 0.28)

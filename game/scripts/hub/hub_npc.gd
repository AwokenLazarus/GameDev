extends Node2D
## Wandering Ashwick faction NPC with idle / walk / talk anims.

const ActorVisualScript = preload("res://scripts/visuals/actor_visual.gd")

@export var npc_id: String = "npc_mayor"
@export var display_name: String = "Mayor"
@export var home: Vector2 = Vector2.ZERO
@export var wander_radius: float = 70.0

var _visual: Node2D
var _target: Vector2
var _wait: float = 0.0
var _talking: float = 0.0
var _speed: float = 38.0


func _ready() -> void:
	_visual = ActorVisualScript.new()
	add_child(_visual)
	_visual.load_sprite("npcs", npc_id)
	home = global_position
	_pick_target()
	_wait = randf_range(0.5, 2.0)


func talk(seconds: float = 2.2) -> void:
	_talking = seconds
	if _visual:
		_visual.play("talk", true, 5.0)


func _pick_target() -> void:
	var ang := randf() * TAU
	_target = home + Vector2(cos(ang), sin(ang)) * randf_range(16.0, wander_radius)


func _process(delta: float) -> void:
	if _talking > 0.0:
		_talking -= delta
		if _talking <= 0.0 and _visual:
			_visual.set_moving(false)
		return
	if _wait > 0.0:
		_wait -= delta
		if _visual:
			_visual.set_moving(false)
		return
	var to := _target - global_position
	if to.length() < 6.0:
		_wait = randf_range(1.2, 3.5)
		_pick_target()
		if _visual:
			_visual.set_moving(false)
		return
	var step := to.normalized() * _speed * delta
	global_position += step
	if _visual:
		_visual.set_moving(true)
		_visual.set_facing_x(step.x)

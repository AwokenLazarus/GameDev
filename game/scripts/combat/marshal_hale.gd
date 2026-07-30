extends CharacterBody2D
## Marshal Corvin Hale — Dust Meridian general.

signal defeated

const MOVE_SPEED := 130.0
const CHARGE_SPEED := 380.0

@onready var visual: Polygon2D = $Visual
@onready var health: Health = $Health
@onready var telegraph: Polygon2D = $Telegraph

var _player: Node2D
var _phase: int = 0
var _cd: float = 2.0
var _charging: bool = false
var _charge_dir: Vector2 = Vector2.RIGHT
var _alive: bool = true


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	health.max_hp = 520.0
	health.hp = 520.0
	health.died.connect(_on_died)
	telegraph.visible = false
	visual.color = Color(0.45, 0.38, 0.32)


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return

	_cd -= delta
	if _charging:
		velocity = _charge_dir * CHARGE_SPEED
		move_and_slide()
		if _player.global_position.distance_to(global_position) < 30.0:
			if _player.has_method("apply_hit"):
				_player.apply_hit(22.0)
		return

	var dir := (_player.global_position - global_position).normalized()
	velocity = dir * MOVE_SPEED
	move_and_slide()

	if _player.global_position.distance_to(global_position) < 34.0:
		if _player.has_method("apply_hit"):
			_player.apply_hit(14.0 * delta * 8.0)

	if _cd <= 0.0:
		_cd = 2.8 - clampf(1.0 - health.hp / health.max_hp, 0.0, 0.8)
		_start_charge()


func _start_charge() -> void:
	if _player == null:
		return
	_charge_dir = (_player.global_position - global_position).normalized()
	telegraph.visible = true
	telegraph.rotation = _charge_dir.angle()
	await get_tree().create_timer(0.45).timeout
	if not _alive:
		return
	telegraph.visible = false
	_charging = true
	visual.color = Color(0.7, 0.25, 0.2)
	await get_tree().create_timer(0.55).timeout
	_charging = false
	if is_instance_valid(visual):
		visual.color = Color(0.45, 0.38, 0.32)


func _on_died() -> void:
	if not _alive:
		return
	_alive = false
	RunState.register_kill(true)
	defeated.emit()
	queue_free()

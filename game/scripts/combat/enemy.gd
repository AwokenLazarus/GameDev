extends CharacterBody2D
const _VFX = preload("res://scripts/visuals/vfx.gd")
## Basic Dominion foe with 2.5D actor visual. Human variant can be fed upon.

signal killed(is_human: bool)

@export var is_human: bool = false
@export var is_elite: bool = false
@export var max_hp: float = 40.0
@export var move_speed: float = 90.0
@export var contact_damage: float = 10.0
@export var xp_color: Color = Color(0.55, 0.2, 0.22)

@onready var visual: CanvasItem = $Visual
@onready var health: Health = $Health
@onready var corpse_area: Area2D = $CorpseArea
@onready var actor_visual: Node2D = $ActorVisual

const WINDUP := 0.38
const ATTACK_RANGE := 28.0
const STRIKE_RANGE := 34.0

var _player: Node2D
var _alive: bool = true
var _corpse: bool = false
var _attack_cd: float = 0.0
var enemy_sprite: String = "dominion_grub"
var _winding: bool = false
var _windup: float = 0.0
var _wind_t: float = 0.0
var _stagger: float = 0.0
var _knock: Vector2 = Vector2.ZERO
var _spawn_lock: float = 0.0
var _base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	add_to_group("enemy")
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	corpse_area.monitoring = false
	corpse_area.monitorable = false
	_apply_role_visuals()


func setup(player: Node2D, human: bool = false, elite: bool = false) -> void:
	_player = player
	is_human = human
	is_elite = elite
	if is_node_ready():
		_apply_role_visuals()


func _scaled_hp() -> float:
	var elite_m := 1.6 if is_elite else 1.0
	var diff := GameState.difficulty_enemy_mult() if GameState else 1.0
	return max_hp * elite_m * diff


func begin_spawn_telegraph(seconds: float = 0.45) -> void:
	_spawn_lock = seconds
	modulate.a = 0.5
	if actor_visual:
		actor_visual.flash(Color(1.7, 0.75, 0.3), seconds)
	_VFX.telegraph_mark(get_parent(), global_position, seconds, Vector2(1.1, 1.1))


func apply_stagger(from: Vector2, force: float = 200.0) -> void:
	if not _alive:
		return
	_winding = false
	_windup = 0.0
	_stagger = 0.22
	var dir := (global_position - from).normalized()
	if dir.length() < 0.1:
		dir = Vector2.RIGHT
	_knock = dir * force
	if actor_visual:
		actor_visual.flash(Color(1.4, 1.2, 0.9), 0.12)


func _apply_role_visuals() -> void:
	var hp := _scaled_hp()
	health.max_hp = hp
	health.hp = hp
	_base_scale = Vector2(1.35, 1.35) if is_elite else Vector2.ONE
	scale = _base_scale
	## Pick sprite by role + sector flavor
	if is_elite:
		enemy_sprite = "dominion_elite"
	elif is_human:
		enemy_sprite = "church_zealot" if RunState.sector_id in ["salt_choir", "pale_spire"] else "human_enforcer"
	else:
		match RunState.sector_id:
			"gloampine", "iron_orchard":
				enemy_sprite = "beast_hound"
			"noir_cathedral", "umbral_marches", "pale_spire":
				enemy_sprite = "void_wretch"
			_:
				enemy_sprite = "dominion_grub"
	if actor_visual:
		actor_visual.load_sprite("enemies", enemy_sprite)
	if visual is Polygon2D:
		if is_human:
			(visual as Polygon2D).color = Color(0.62, 0.48, 0.4)
		elif is_elite:
			(visual as Polygon2D).color = Color(0.55, 0.15, 0.55)
		else:
			(visual as Polygon2D).color = xp_color


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	if _spawn_lock > 0.0:
		_spawn_lock -= delta
		if _spawn_lock <= 0.0:
			modulate.a = 1.0
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if _stagger > 0.0:
		_stagger -= delta
		velocity = _knock
		_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
		scale = _base_scale
		move_and_slide()
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	var dir := (_player.global_position - global_position)
	var dist := dir.length()
	if _winding:
		_windup -= delta
		_wind_t += delta
		scale = _base_scale * (1.0 + 0.14 * sin(_wind_t * 20.0))
		velocity = Vector2.ZERO
		move_and_slide()
		if _windup <= 0.0:
			_winding = false
			scale = _base_scale
			_attack_cd = 0.7
			if dist < STRIKE_RANGE and _player.has_method("apply_hit"):
				if actor_visual:
					actor_visual.play_oneshot("attack", 12.0)
				_player.apply_hit(contact_damage * (1.4 if is_elite else 1.0), global_position)
		return
	if dist > 4.0:
		velocity = dir.normalized() * move_speed * (0.85 if is_human else 1.0)
	else:
		velocity = Vector2.ZERO
	if actor_visual:
		actor_visual.set_running(velocity.length() > move_speed * 0.85)
		actor_visual.set_moving(velocity.length() > 4.0)
		actor_visual.set_facing_x(dir.x)
	move_and_slide()

	_attack_cd -= delta
	if dist < ATTACK_RANGE and _attack_cd <= 0.0:
		_start_windup()


func _start_windup() -> void:
	_winding = true
	_windup = WINDUP
	_wind_t = 0.0
	if actor_visual:
		actor_visual.flash(Color(1.55, 0.55, 0.25), WINDUP)
	_VFX.telegraph_mark(get_parent(), global_position + Vector2(0, 18), WINDUP, Vector2(0.85, 0.55))


func _on_damaged(_amount: float, _remaining: float) -> void:
	if actor_visual:
		actor_visual.flash(Color(1.3, 1.1, 0.9), 0.08)


func _on_died() -> void:
	if not _alive:
		return
	_alive = false
	velocity = Vector2.ZERO
	set_physics_process(false)
	_VFX.blood(get_parent(), global_position)
	killed.emit(is_human)
	RunState.register_kill(is_human)
	remove_from_group("enemy")
	if is_human:
		_become_corpse()
	else:
		queue_free()


func _become_corpse() -> void:
	_corpse = true
	add_to_group("feedable_corpse")
	if actor_visual:
		actor_visual.modulate = Color(0.45, 0.15, 0.15, 0.85)
		actor_visual.scale = Vector2(1.0, 0.55)
	if visual is Polygon2D:
		(visual as Polygon2D).color = Color(0.35, 0.12, 0.14)
		visual.scale = Vector2(1.0, 0.55)
	corpse_area.monitoring = true
	corpse_area.monitorable = true
	await get_tree().create_timer(12.0).timeout
	if is_instance_valid(self) and _corpse:
		queue_free()


func consume() -> void:
	queue_free()

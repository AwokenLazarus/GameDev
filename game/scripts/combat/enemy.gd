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

var _player: Node2D
var _alive: bool = true
var _corpse: bool = false
var _attack_cd: float = 0.0
var enemy_sprite: String = "dominion_grub"


func _ready() -> void:
	add_to_group("enemy")
	health.max_hp = max_hp * (1.6 if is_elite else 1.0)
	health.hp = health.max_hp
	health.died.connect(_on_died)
	corpse_area.monitoring = false
	corpse_area.monitorable = false
	_apply_role_visuals()


func setup(player: Node2D, human: bool = false, elite: bool = false) -> void:
	_player = player
	is_human = human
	is_elite = elite
	if is_node_ready():
		_apply_role_visuals()


func _apply_role_visuals() -> void:
	var hp := max_hp * (1.6 if is_elite else 1.0)
	health.max_hp = hp
	health.hp = hp
	scale = Vector2(1.35, 1.35) if is_elite else Vector2.ONE
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
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	var dir := (_player.global_position - global_position)
	var dist := dir.length()
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
	if dist < 28.0 and _attack_cd <= 0.0:
		_attack_cd = 0.7
		if actor_visual:
			actor_visual.play_oneshot("attack", 12.0)
		if _player.has_method("apply_hit"):
			_player.apply_hit(contact_damage * (1.4 if is_elite else 1.0))


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

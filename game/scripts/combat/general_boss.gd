extends CharacterBody2D
## Configurable sector general / Aurelian.

signal defeated

@export var general_id: String = "marshal_hale"
@export var display_name: String = "General"
@export var max_hp: float = 520.0
@export var move_speed: float = 130.0
@export var color: Color = Color(0.45, 0.38, 0.32)
@export var pattern: String = "charge" ## charge, barrage, leap, hymn, thorns, void, fleet, aurelian

@onready var visual: Polygon2D = $Visual
@onready var health: Health = $Health
@onready var telegraph: Polygon2D = $Telegraph
@onready var badge: Polygon2D = $Badge

var _player: Node2D
var _cd: float = 2.0
var _busy: bool = false
var _alive: bool = true

const PROJ := preload("res://scenes/entities/projectile.tscn")


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	_apply_def()
	health.max_hp = max_hp * GameState.difficulty_enemy_mult()
	health.hp = health.max_hp
	health.died.connect(_on_died)
	telegraph.visible = false
	visual.color = color


func _apply_def() -> void:
	if general_id == "" or SectorDB == null:
		return
	var g: Dictionary = SectorDB.get_general(general_id)
	if g.is_empty():
		return
	display_name = str(g.get("name", display_name))
	max_hp = float(g.get("max_hp", max_hp))
	move_speed = float(g.get("move_speed", move_speed))
	color = g.get("color", color)
	pattern = str(g.get("pattern", pattern))


func configure(gid: String) -> void:
	general_id = gid
	if is_node_ready():
		_apply_def()
		visual.color = color
		health.max_hp = max_hp * GameState.difficulty_enemy_mult()
		health.hp = health.max_hp


func _physics_process(delta: float) -> void:
	if not _alive or _busy:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	var dir := (_player.global_position - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()
	if _player.global_position.distance_to(global_position) < 32.0:
		if _player.has_method("apply_hit"):
			_player.apply_hit(12.0 * delta * 6.0)
	_cd -= delta
	if _cd <= 0.0:
		_cd = 2.6 - clampf(1.0 - health.hp / health.max_hp, 0.0, 1.0)
		_use_pattern()


func _use_pattern() -> void:
	match pattern:
		"barrage":
			_pat_barrage()
		"leap":
			_pat_leap()
		"hymn":
			_pat_hymn()
		"thorns":
			_pat_thorns()
		"void":
			_pat_void()
		"fleet":
			_pat_fleet()
		"aurelian":
			_pat_aurelian()
		_:
			_pat_charge()


func _pat_charge() -> void:
	_busy = true
	var dir := (_player.global_position - global_position).normalized()
	telegraph.visible = true
	telegraph.rotation = dir.angle()
	await get_tree().create_timer(0.45).timeout
	if not _alive:
		return
	telegraph.visible = false
	velocity = dir * 380.0
	var t := 0.0
	while t < 0.55 and _alive:
		move_and_slide()
		if _player and _player.global_position.distance_to(global_position) < 30.0:
			_player.apply_hit(22.0)
		t += get_process_delta_time()
		await get_tree().process_frame
	_busy = false


func _pat_barrage() -> void:
	_busy = true
	for i in 8:
		if not _alive or _player == null:
			break
		var dir := (_player.global_position - global_position).normalized().rotated(randf_range(-0.3, 0.3))
		var p: Node = PROJ.instantiate()
		get_parent().add_child(p)
		p.setup(global_position, dir, 12.0 * GameState.difficulty_enemy_mult(), self, false, 360.0)
		p.visual.color = Color(0.9, 0.4, 0.2)
		if p.has_method("make_hostile"):
			p.make_hostile()
		await get_tree().create_timer(0.08).timeout
	_busy = false


func _pat_leap() -> void:
	_busy = true
	telegraph.visible = true
	telegraph.global_position = _player.global_position
	await get_tree().create_timer(0.5).timeout
	if _alive:
		global_position = telegraph.global_position
		for e in get_tree().get_nodes_in_group("player"):
			if global_position.distance_to(e.global_position) < 70.0 and e.has_method("apply_hit"):
				e.apply_hit(28.0)
	telegraph.visible = false
	telegraph.position = Vector2.ZERO
	_busy = false


func _pat_hymn() -> void:
	_busy = true
	visual.modulate = Color(1.2, 1.1, 0.8)
	## Heal slightly + smite ring
	health.heal(health.max_hp * 0.04)
	for e in get_tree().get_nodes_in_group("player"):
		if global_position.distance_to(e.global_position) < 140.0 and e.has_method("apply_hit"):
			e.apply_hit(18.0)
	await get_tree().create_timer(0.6).timeout
	visual.modulate = Color.WHITE
	_busy = false


func _pat_thorns() -> void:
	_busy = true
	for i in 12:
		var a := TAU * float(i) / 12.0
		var p: Node = PROJ.instantiate()
		get_parent().add_child(p)
		p.setup(global_position, Vector2(cos(a), sin(a)), 10.0, self, false, 280.0)
		p.visual.color = Color(0.4, 0.7, 0.3)
		if p.has_method("make_hostile"):
			p.make_hostile()
	await get_tree().create_timer(0.4).timeout
	_busy = false


func _pat_void() -> void:
	_busy = true
	## Pull players inward then spike
	for e in get_tree().get_nodes_in_group("player"):
		var pull: Vector2 = (global_position - (e as Node2D).global_position).normalized() * 90.0
		(e as Node2D).global_position += pull
	await get_tree().create_timer(0.35).timeout
	for e in get_tree().get_nodes_in_group("player"):
		if global_position.distance_to(e.global_position) < 100.0 and e.has_method("apply_hit"):
			e.apply_hit(26.0)
	_busy = false


func _pat_fleet() -> void:
	_busy = true
	for i in 3:
		await _pat_charge()
		await get_tree().create_timer(0.15).timeout
	_busy = false


func _pat_aurelian() -> void:
	_busy = true
	## Mix: hymn heal, void pull, barrage
	await _pat_hymn()
	if _alive:
		await _pat_void()
	if _alive:
		await _pat_barrage()
	_busy = false


func _on_died() -> void:
	if not _alive:
		return
	_alive = false
	RunState.register_kill(true)
	defeated.emit()
	queue_free()

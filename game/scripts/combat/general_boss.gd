extends CharacterBody2D
## Configurable sector general / Aurelian.

signal defeated

@export var general_id: String = "marshal_hale"
@export var display_name: String = "General"
@export var max_hp: float = 520.0
@export var move_speed: float = 130.0
@export var color: Color = Color(0.45, 0.38, 0.32)
@export var pattern: String = "charge" ## charge, barrage, leap, hymn, thorns, void, fleet, aurelian

@onready var visual: CanvasItem = $Visual
@onready var health: Health = $Health
@onready var telegraph: CanvasItem = $Telegraph
@onready var badge: CanvasItem = $Badge
@onready var actor_visual: Node2D = $ActorVisual
@onready var nameplate: Label = $Nameplate

const CONTACT_DMG := 12.0
const CONTACT_CD := 0.55
const TELEGRAPH_MIN := 0.42

var _player: Node2D
var _cd: float = 2.0
var _busy: bool = false
var _alive: bool = true
var _contact_cd: Dictionary = {} ## instance_id -> remaining

const PROJ := preload("res://scenes/entities/projectile.tscn")


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	_apply_def()
	health.max_hp = max_hp * GameState.difficulty_enemy_mult()
	health.hp = health.max_hp
	health.died.connect(_on_died)
	telegraph.visible = false
	if telegraph is Sprite2D:
		var tp := "res://assets/textures/vfx/telegraph.png"
		if ResourceLoader.exists(tp):
			(telegraph as Sprite2D).texture = load(tp)
	if visual is Polygon2D:
		(visual as Polygon2D).color = color
	if actor_visual:
		actor_visual.load_sprite("generals", general_id)
	if nameplate:
		nameplate.text = display_name


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
		if visual is Polygon2D:
			(visual as Polygon2D).color = color
		if actor_visual:
			actor_visual.load_sprite("generals", general_id)
		if nameplate:
			nameplate.text = display_name
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
	if actor_visual:
		actor_visual.set_running(true)
		actor_visual.set_moving(true)
		actor_visual.set_facing_x(dir.x)
	move_and_slide()
	_tick_contact(delta)
	_cd -= delta
	if _cd <= 0.0:
		_cd = 2.6 - clampf(1.0 - health.hp / health.max_hp, 0.0, 1.0)
		_use_pattern()


func _tick_contact(delta: float) -> void:
	for id in _contact_cd.keys():
		_contact_cd[id] = float(_contact_cd[id]) - delta
		if float(_contact_cd[id]) <= 0.0:
			_contact_cd.erase(id)
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or not p.has_method("apply_hit"):
			continue
		if global_position.distance_to(p.global_position) >= 32.0:
			continue
		var id := p.get_instance_id()
		if _contact_cd.has(id):
			continue
		p.apply_hit(CONTACT_DMG, global_position)
		_contact_cd[id] = CONTACT_CD


func apply_stagger(from: Vector2, force: float = 90.0) -> void:
	if not _alive or _busy:
		return
	var dir := (global_position - from).normalized()
	if dir.length() < 0.1:
		dir = Vector2.RIGHT
	velocity = dir * force
	if actor_visual:
		actor_visual.flash(Color(1.3, 1.15, 0.85), 0.1)


func _show_telegraph(seconds: float, scl: Vector2 = Vector2.ONE, world_pos: Vector2 = Vector2.ZERO) -> void:
	if telegraph:
		telegraph.visible = true
		telegraph.scale = scl
		if world_pos != Vector2.ZERO:
			telegraph.global_position = world_pos
		else:
			telegraph.position = Vector2.ZERO
	if actor_visual:
		actor_visual.flash(Color(1.35, 0.55, 0.3), seconds)
	await get_tree().create_timer(seconds).timeout
	if telegraph:
		telegraph.visible = false
		telegraph.position = Vector2.ZERO
		telegraph.scale = Vector2.ONE


func _use_pattern() -> void:
	if actor_visual:
		actor_visual.play_oneshot("attack", 12.0)
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
	var hit_ids: Dictionary = {}
	var dir := (_player.global_position - global_position).normalized()
	if telegraph:
		telegraph.visible = true
		telegraph.rotation = dir.angle()
		telegraph.position = Vector2.ZERO
	if actor_visual:
		actor_visual.flash(Color(1.4, 0.45, 0.25), 0.45)
	await get_tree().create_timer(0.45).timeout
	if not _alive:
		_busy = false
		return
	if telegraph:
		telegraph.visible = false
	velocity = dir * 380.0
	var t := 0.0
	while t < 0.55 and _alive:
		move_and_slide()
		for p in get_tree().get_nodes_in_group("player"):
			if not is_instance_valid(p) or not p.has_method("apply_hit"):
				continue
			var id := p.get_instance_id()
			if hit_ids.has(id):
				continue
			if p.global_position.distance_to(global_position) < 30.0:
				hit_ids[id] = true
				p.apply_hit(22.0, global_position)
		t += get_process_delta_time()
		await get_tree().process_frame
	_busy = false


func _pat_barrage() -> void:
	_busy = true
	await _show_telegraph(TELEGRAPH_MIN, Vector2(1.4, 1.4))
	for i in 8:
		if not _alive or _player == null:
			break
		var dir := (_player.global_position - global_position).normalized().rotated(randf_range(-0.3, 0.3))
		var p: Node = PROJ.instantiate()
		get_parent().add_child(p)
		p.setup(global_position, dir, 12.0 * GameState.difficulty_enemy_mult(), self, false, 360.0)
		p.visual.modulate = Color(0.9, 0.4, 0.2)
		if p.has_method("make_hostile"):
			p.make_hostile()
		await get_tree().create_timer(0.08).timeout
	_busy = false


func _pat_leap() -> void:
	_busy = true
	var land := _player.global_position if _player else global_position
	await _show_telegraph(0.5, Vector2(1.6, 1.6), land)
	if _alive:
		global_position = land
		for e in get_tree().get_nodes_in_group("player"):
			if global_position.distance_to(e.global_position) < 70.0 and e.has_method("apply_hit"):
				e.apply_hit(28.0, global_position)
	_busy = false


func _pat_hymn() -> void:
	_busy = true
	visual.modulate = Color(1.2, 1.1, 0.8)
	await _show_telegraph(TELEGRAPH_MIN, Vector2(2.2, 2.2))
	if _alive:
		health.heal(health.max_hp * 0.04)
		for e in get_tree().get_nodes_in_group("player"):
			if global_position.distance_to(e.global_position) < 140.0 and e.has_method("apply_hit"):
				e.apply_hit(18.0, global_position)
	await get_tree().create_timer(0.2).timeout
	visual.modulate = Color.WHITE
	_busy = false


func _pat_thorns() -> void:
	_busy = true
	await _show_telegraph(TELEGRAPH_MIN, Vector2(1.8, 1.8))
	if not _alive:
		_busy = false
		return
	for i in 12:
		var a := TAU * float(i) / 12.0
		var p: Node = PROJ.instantiate()
		get_parent().add_child(p)
		p.setup(global_position, Vector2(cos(a), sin(a)), 10.0, self, false, 280.0)
		p.visual.modulate = Color(0.4, 0.7, 0.3)
		if p.has_method("make_hostile"):
			p.make_hostile()
	await get_tree().create_timer(0.2).timeout
	_busy = false


func _pat_void() -> void:
	_busy = true
	await _show_telegraph(TELEGRAPH_MIN, Vector2(2.0, 2.0))
	if not _alive:
		_busy = false
		return
	for e in get_tree().get_nodes_in_group("player"):
		var pull: Vector2 = (global_position - (e as Node2D).global_position).normalized() * 90.0
		(e as Node2D).global_position += pull
	await get_tree().create_timer(0.2).timeout
	for e in get_tree().get_nodes_in_group("player"):
		if global_position.distance_to(e.global_position) < 100.0 and e.has_method("apply_hit"):
			e.apply_hit(26.0, global_position)
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

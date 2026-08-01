extends Node
## RoR2-like spawn director for wild / dungeon phases.

signal spawned(enemy: Node)

@export var enemy_scene: PackedScene
@export var spawn_radius_min: float = 420.0
@export var spawn_radius_max: float = 640.0
@export var max_alive: int = 40

var active: bool = false
var _acc: float = 0.0
var _arena_center: Vector2 = Vector2.ZERO
var _arena_half: Vector2 = Vector2(500, 350)
var player: Node2D


func configure(center: Vector2, half_extents: Vector2) -> void:
	_arena_center = center
	_arena_half = half_extents


func start(p: Node2D) -> void:
	player = p
	active = true
	_acc = 0.0


func stop() -> void:
	active = false


func _process(delta: float) -> void:
	if not active or enemy_scene == null:
		return
	if player == null or not is_instance_valid(player):
		return
	var intensity := RunState.get_director_intensity()
	var interval := clampf(1.4 - intensity * 0.7, 0.35, 1.4)
	_acc += delta
	if _acc < interval:
		return
	_acc = 0.0
	var alive := get_tree().get_nodes_in_group("enemy").size()
	if alive >= max_alive:
		return
	var burst := 1 + int(intensity * 2.0)
	for i in burst:
		_spawn_one()


func _spawn_one() -> void:
	var e: Node2D = enemy_scene.instantiate()
	var angle := randf() * TAU
	var dist := randf_range(spawn_radius_min, spawn_radius_max)
	var pos := player.global_position + Vector2(cos(angle), sin(angle)) * dist
	pos.x = clampf(pos.x, _arena_center.x - _arena_half.x + 40.0, _arena_center.x + _arena_half.x - 40.0)
	pos.y = clampf(pos.y, _arena_center.y - _arena_half.y + 40.0, _arena_center.y + _arena_half.y - 40.0)
	e.global_position = pos
	var elite := false
	var human := false
	var t := RunState.run_time
	## Elites rare early, common later.
	var elite_chance := clampf((t - 60.0) / 180.0, 0.02, 0.28)
	if randf() < elite_chance:
		elite = true
	var human_chance := 0.35
	if SectorDB and RunState:
		var s: Dictionary = SectorDB.get_sector(RunState.sector_id)
		human_chance = float(s.get("enemy_human_chance", 0.35))
	if randf() < human_chance:
		human = true
	get_parent().add_child(e)
	if e.has_method("setup"):
		e.setup(player, human, elite)
	else:
		e.is_human = human
		e.is_elite = elite
	spawned.emit(e)

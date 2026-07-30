extends Node2D
## Dust Meridian V0: 5 dungeon bursts → wild → Marshal Hale.

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const ENEMY_SCENE := preload("res://scenes/entities/enemy.tscn")
const BOSS_SCENE := preload("res://scenes/entities/marshal_hale.tscn")

@onready var world: Node2D = $World
@onready var ground: Polygon2D = $World/Ground
@onready var walls: StaticBody2D = $World/Walls
@onready var entities: Node2D = $World/Entities
@onready var director: Node = $Director
@onready var hud: CanvasLayer = $HUD
@onready var boon_ui: CanvasLayer = $BoonSelect
@onready var banner: Label = $HUD/Root/Banner

var player: CharacterBody2D
var _room_cleared: bool = false
var _general_spawned: bool = false
var _burst_kills_at_start: int = 0


func _ready() -> void:
	RunState.start_run("severin", "dust_meridian")
	director.enemy_scene = ENEMY_SCENE
	boon_ui.chosen.connect(_on_boon_chosen)
	_build_arena(Vector2(900, 600))
	_spawn_player(Vector2(0, 0))
	_start_dungeon_burst()


func _build_arena(size: Vector2) -> void:
	ground.polygon = PackedVector2Array([
		-size.x, -size.y, size.x, -size.y, size.x, size.y, -size.x, size.y
	])
	ground.color = Color(0.22, 0.18, 0.14)
	## Clear old walls
	for c in walls.get_children():
		c.queue_free()
	_add_wall(Vector2(0, -size.y), Vector2(size.x * 2, 24))
	_add_wall(Vector2(0, size.y), Vector2(size.x * 2, 24))
	_add_wall(Vector2(-size.x, 0), Vector2(24, size.y * 2))
	_add_wall(Vector2(size.x, 0), Vector2(24, size.y * 2))
	director.configure(Vector2.ZERO, size)


func _add_wall(pos: Vector2, size: Vector2) -> void:
	var body := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	body.shape = shape
	body.position = pos
	walls.add_child(body)
	var vis := Polygon2D.new()
	vis.color = Color(0.12, 0.1, 0.11)
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	vis.polygon = PackedVector2Array([-hx, -hy, hx, -hy, hx, hy, -hx, hy])
	vis.position = pos
	walls.add_child(vis)


func _spawn_player(pos: Vector2) -> void:
	player = PLAYER_SCENE.instantiate()
	player.global_position = pos
	entities.add_child(player)
	player.died.connect(_on_player_died)


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	for c in get_tree().get_nodes_in_group("feedable_corpse"):
		c.queue_free()


func _start_dungeon_burst() -> void:
	RunState.set_phase(RunState.Phase.DUNGEON)
	_room_cleared = false
	_general_spawned = false
	banner.text = "Dust Meridian — Burst %d / %d" % [RunState.dungeon_index + 1, RunState.dungeons_total]
	_build_arena(Vector2(480, 320))
	player.global_position = Vector2.ZERO
	_clear_enemies()
	director.stop()
	## Authored small wave, not full director
	var count := 4 + RunState.dungeon_index
	for i in count:
		_spawn_burst_enemy(i, count)
	_burst_kills_at_start = _alive_enemies()


func _spawn_burst_enemy(i: int, total: int) -> void:
	var e: Node2D = ENEMY_SCENE.instantiate()
	var angle := TAU * float(i) / float(total)
	e.global_position = Vector2(cos(angle), sin(angle)) * 220.0
	entities.add_child(e)
	var human := i % 3 == 0
	var elite := RunState.run_time > 70.0 and i == 0
	e.setup(player, human, elite)


func _alive_enemies() -> int:
	return get_tree().get_nodes_in_group("enemy").size()


func _process(_delta: float) -> void:
	if RunState.phase == RunState.Phase.DUNGEON and not _room_cleared:
		if _alive_enemies() == 0:
			_room_cleared = true
			_on_burst_cleared()
	elif RunState.phase == RunState.Phase.WILD:
		if RunState.can_spawn_general() and not _general_spawned:
			_spawn_general()


func _on_burst_cleared() -> void:
	banner.text = "Burst cleared"
	await _offer_boon_if_needed()
	RunState.dungeon_index += 1
	if RunState.dungeon_index >= RunState.dungeons_total:
		_start_wild()
	else:
		await get_tree().create_timer(0.6).timeout
		_start_dungeon_burst()


func _start_wild() -> void:
	RunState.set_phase(RunState.Phase.WILD)
	banner.text = "Wild Stage — Dust Meridian"
	_build_arena(Vector2(1100, 700))
	player.global_position = Vector2.ZERO
	_clear_enemies()
	director.start(player)
	await _offer_boon_if_needed()


func _spawn_general() -> void:
	_general_spawned = true
	director.stop()
	RunState.set_phase(RunState.Phase.BOSS)
	banner.text = "Marshal Corvin Hale"
	var boss: Node = BOSS_SCENE.instantiate()
	boss.global_position = Vector2(0, -180)
	entities.add_child(boss)
	boss.defeated.connect(_on_general_defeated)


func _on_general_defeated() -> void:
	RunState.general_defeated = true
	RunState.set_phase(RunState.Phase.VICTORY)
	banner.text = "Sector seized — returning to Ashwick"
	director.stop()
	await _offer_boon_if_needed()
	RunState.grant_run_rewards(true)
	await get_tree().create_timer(2.0).timeout
	RunState.end_to_hub()
	get_tree().change_scene_to_file("res://scenes/hub/ashwick.tscn")


func _offer_boon_if_needed() -> void:
	if RunState.boon_picks_done >= RunState.boon_picks_target:
		return
	## Offer after each burst and once entering wild / after boss — capped at 8.
	RunState.awaiting_boon = true
	boon_ui.open_choices()
	await boon_ui.chosen


func _on_boon_chosen(_boon: Dictionary) -> void:
	banner.text = "Pact taken"


func _on_player_died() -> void:
	director.stop()
	RunState.timer_active = false
	RunState.set_phase(RunState.Phase.DEAD)
	RunState.grant_run_rewards(false)
	GameState.mark_moon()
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file("res://scenes/ui/death_screen.tscn")

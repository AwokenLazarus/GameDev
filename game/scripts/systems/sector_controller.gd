extends Node2D
const BiomePresenterScript = preload("res://scripts/visuals/biome_presenter.gd")
## Generic sector runner: bursts → wild → kill-gated general → Ashwick.

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const ENEMY_SCENE := preload("res://scenes/entities/enemy.tscn")
const GENERAL_SCENE := preload("res://scenes/entities/general.tscn")
const GEAR_SCENE := preload("res://scenes/entities/gear_drop.tscn")

@onready var world: Node2D = $World
@onready var ground: Polygon2D = $World/Ground
@onready var accent_patch: Polygon2D = $World/DustPatch
@onready var walls: StaticBody2D = $World/Walls
@onready var entities: Node2D = $World/Entities
@onready var director: Node = $Director
@onready var hud: CanvasLayer = $HUD
@onready var boon_ui: CanvasLayer = $BoonSelect
@onready var banner: Label = $HUD/Root/Banner

var players: Array[CharacterBody2D] = []
var _room_cleared: bool = false
var _general_spawned: bool = false
var _sector: Dictionary = {}
var _biome: Node2D


func _ready() -> void:
	var sector_id := GameState.selected_sector
	var party: Array = GameState.party
	if party.is_empty():
		party = [{"character_id": "severin", "alt_id": "", "device": -1}]
	var lead: Dictionary = party[0]
	RunState.start_run(
		str(lead.get("character_id", "severin")),
		sector_id,
		str(lead.get("alt_id", "")),
		party.size()
	)
	_sector = SectorDB.get_sector(sector_id)
	director.enemy_scene = ENEMY_SCENE
	boon_ui.chosen.connect(_on_boon_chosen)
	world.y_sort_enabled = true
	entities.y_sort_enabled = true
	_biome = BiomePresenterScript.new()
	_biome.z_index = -15
	world.add_child(_biome)
	_paint_biome()
	_build_arena(Vector2(900, 600))
	_spawn_party(party)
	_start_dungeon_burst()


func _paint_biome() -> void:
	ground.visible = false
	if accent_patch:
		accent_patch.visible = false
	if _biome:
		_biome.present_sector(_sector, Vector2(900, 600))


func _build_arena(size: Vector2) -> void:
	ground.polygon = PackedVector2Array([
		-size.x, -size.y, size.x, -size.y, size.x, size.y, -size.x, size.y
	])
	ground.visible = false
	for c in walls.get_children():
		c.queue_free()
	_add_wall(Vector2(0, -size.y), Vector2(size.x * 2, 24))
	_add_wall(Vector2(0, size.y), Vector2(size.x * 2, 24))
	_add_wall(Vector2(-size.x, 0), Vector2(24, size.y * 2))
	_add_wall(Vector2(size.x, 0), Vector2(24, size.y * 2))
	director.configure(Vector2.ZERO, size)
	director.spawn_radius_min = minf(size.x, size.y) * 0.55
	director.spawn_radius_max = minf(size.x, size.y) * 0.9
	if _biome:
		_biome.present_sector(_sector, size)


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


func _spawn_party(party: Array) -> void:
	players.clear()
	for i in party.size():
		var slot: Dictionary = party[i]
		var p: CharacterBody2D = PLAYER_SCENE.instantiate()
		p.global_position = Vector2(i * 36.0 - (party.size() - 1) * 18.0, 0)
		entities.add_child(p)
		if p.has_method("configure"):
			p.configure(i, str(slot.get("character_id", "severin")), str(slot.get("alt_id", "")), int(slot.get("device", -1)))
		p.died.connect(_on_player_died.bind(p))
		players.append(p)


func _lead() -> CharacterBody2D:
	for p in players:
		if is_instance_valid(p) and not p.dead:
			return p
	return players[0] if players.size() else null


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	for c in get_tree().get_nodes_in_group("feedable_corpse"):
		c.queue_free()


func _start_dungeon_burst() -> void:
	RunState.set_phase(RunState.Phase.DUNGEON)
	_room_cleared = false
	_general_spawned = false
	var sname := str(_sector.get("name", "Sector"))
	banner.text = "%s — Burst %d / %d" % [sname, RunState.dungeon_index + 1, RunState.dungeons_total]
	_build_arena(Vector2(480, 320))
	var lead := _lead()
	if lead:
		lead.global_position = Vector2.ZERO
	_clear_enemies()
	director.stop()
	var count := 4 + RunState.dungeon_index
	if bool(_sector.get("nightmare", false)):
		count += 3
	for i in count:
		_spawn_burst_enemy(i, count)


func _spawn_burst_enemy(i: int, total: int) -> void:
	var e: Node2D = ENEMY_SCENE.instantiate()
	var angle := TAU * float(i) / float(total)
	e.global_position = Vector2(cos(angle), sin(angle)) * 220.0
	entities.add_child(e)
	var human_chance := float(_sector.get("enemy_human_chance", 0.3))
	var human := randf() < human_chance
	var elite := RunState.run_time > 70.0 and randf() < 0.15
	var lead := _lead()
	e.setup(lead, human, elite)
	e.max_hp *= GameState.difficulty_enemy_mult()
	e.health.max_hp = e.max_hp
	e.health.hp = e.max_hp


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
	if randf() < 0.35:
		_spawn_gear_drop(Vector2(randf_range(-80, 80), randf_range(-40, 40)))
	await _offer_boon_if_needed()
	RunState.dungeon_index += 1
	if RunState.dungeon_index >= RunState.dungeons_total:
		_start_wild()
	else:
		await get_tree().create_timer(0.5).timeout
		_start_dungeon_burst()


func _start_wild() -> void:
	RunState.set_phase(RunState.Phase.WILD)
	banner.text = "Wild Stage — %s" % str(_sector.get("name", ""))
	var wild_size := Vector2(1100, 700)
	if bool(_sector.get("nightmare", false)):
		wild_size = Vector2(1200, 800)
	_build_arena(wild_size)
	var lead := _lead()
	if lead:
		lead.global_position = Vector2.ZERO
		director.start(lead)
	_clear_enemies()
	await _offer_boon_if_needed()


func _spawn_general() -> void:
	_general_spawned = true
	director.stop()
	RunState.set_phase(RunState.Phase.BOSS)
	var gid := str(_sector.get("general_id", "marshal_hale"))
	var gname := str(_sector.get("general_name", "General"))
	banner.text = gname
	var boss: Node = GENERAL_SCENE.instantiate()
	boss.global_position = Vector2(0, -180)
	entities.add_child(boss)
	if boss.has_method("configure"):
		boss.configure(gid)
	boss.defeated.connect(_on_general_defeated)


func _on_general_defeated() -> void:
	RunState.general_defeated = true
	RunState.set_phase(RunState.Phase.VICTORY)
	banner.text = "Sector seized — returning to Ashwick"
	director.stop()
	_spawn_gear_drop(Vector2.ZERO)
	await _offer_boon_if_needed()
	RunState.grant_run_rewards(true)
	GameState.mark_sector_clear(RunState.sector_id)
	await get_tree().create_timer(2.0).timeout
	RunState.end_to_hub()
	get_tree().change_scene_to_file("res://scenes/hub/ashwick.tscn")


func _spawn_gear_drop(pos: Vector2) -> void:
	var g: Node = GEAR_SCENE.instantiate()
	entities.add_child(g)
	g.global_position = pos
	if g.has_method("setup"):
		g.setup(_roll_gear())


func _roll_gear() -> Dictionary:
	var pool := [
		{"slot": "charm", "name": "Dust Charm", "rarity": "common", "move": 0.06},
		{"slot": "charm", "name": "Blood Bead", "rarity": "rare", "lifesteal": 0.05},
		{"slot": "relic", "name": "Rail Spike", "rarity": "common", "damage": 0.08},
		{"slot": "relic", "name": "Veyra Seal", "rarity": "epic", "damage": 0.12},
		{"slot": "coat", "name": "Ash Coat", "rarity": "common", "max_hp": 15.0},
		{"slot": "coat", "name": "Iron Mantle", "rarity": "rare", "max_hp": 25.0, "damage": 0.04},
	]
	return pool[randi() % pool.size()].duplicate()


func _offer_boon_if_needed() -> void:
	if RunState.boon_picks_done >= RunState.boon_picks_target:
		return
	RunState.awaiting_boon = true
	boon_ui.open_choices()
	await boon_ui.chosen


func _on_boon_chosen(_boon: Dictionary) -> void:
	banner.text = "Pact taken"


func _on_player_died(p: CharacterBody2D) -> void:
	## Co-op: wipe only if all dead
	var any_alive := false
	for pl in players:
		if is_instance_valid(pl) and not pl.dead:
			any_alive = true
			break
	if any_alive:
		banner.text = "%s falls — the brood fights on" % str(p.character_id).capitalize()
		return
	director.stop()
	RunState.timer_active = false
	RunState.set_phase(RunState.Phase.DEAD)
	RunState.grant_run_rewards(false)
	GameState.mark_moon()
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file("res://scenes/ui/death_screen.tscn")

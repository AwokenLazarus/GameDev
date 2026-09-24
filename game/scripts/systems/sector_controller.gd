extends Node2D
const BiomePresenterScript = preload("res://scripts/visuals/biome_presenter.gd")
const ExitDoorScript = preload("res://scripts/systems/exit_door.gd")
const GreedShrineScript = preload("res://scripts/systems/greed_shrine.gd")
## Generic sector runner: burst rooms → wild expanse → kill-gated general → Ashwick.

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const ENEMY_SCENE := preload("res://scenes/entities/enemy.tscn")
const GENERAL_SCENE := preload("res://scenes/entities/general.tscn")
const GEAR_SCENE := preload("res://scenes/entities/gear_drop.tscn")
const SECTOR_CLEAR_TARGET := 1800.0
## Burst rooms come in waves (Hades-like); the next wave lands when ≤ WAVE_NEXT_AT remain.
const WAVE_SIZE := 5
const WAVE_NEXT_AT := 1
const MOON_ALTAR_CLOCK := 90.0
const BLOOD_WELL_BLEED := 0.25

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
var _arena_half: Vector2 = Vector2(480, 320)
var _pending_spawns: int = 0
var _burst_left: int = 0
var _burst_total: int = 0
var _burst_archetypes: Array = []
var _room: Dictionary = {}
var _queued_room_id: String = "chamber"
var _awaiting_exit: bool = false
var _wild_start: Vector2 = Vector2.ZERO
var _wild_reward: String = "wild_camp"
var chest_points: Array[Vector2] = []
var shrine_points: Array[Vector2] = []


func _ready() -> void:
	get_tree().paused = false
	var sector_id := GameState.selected_sector
	if sector_id == "":
		sector_id = "dust_meridian"
		GameState.selected_sector = sector_id
	var party: Array = GameState.party
	if party.is_empty():
		party = [{"character_id": "severin", "alt_id": "", "device": -1}]
		GameState.party = party
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
	_build_arena(Vector2(900, 600), [])
	_spawn_party(party)
	_start_dungeon_burst()
	banner.text = "FIGHT — %s · Burst 1/%d · red rings = you/enemies" % [
		str(_sector.get("name", "Sector")), RunState.dungeons_total
	]


func _paint_biome() -> void:
	ground.visible = false
	if accent_patch:
		accent_patch.visible = false
	if _biome:
		_biome.present_sector(_sector, Vector2(900, 600), "room")


func _build_arena(size: Vector2, inner_walls: Array = []) -> void:
	_arena_half = size
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
	for w in inner_walls:
		if typeof(w) != TYPE_DICTIONARY:
			continue
		_add_wall(w.get("pos", Vector2.ZERO), w.get("size", Vector2(40, 40)))
	director.configure(Vector2.ZERO, size)
	if RunState.phase == RunState.Phase.WILD:
		director.spawn_radius_min = 280.0
		director.spawn_radius_max = 520.0
	else:
		director.spawn_radius_min = minf(size.x, size.y) * 0.55
		director.spawn_radius_max = minf(size.x, size.y) * 0.9
	if _biome:
		var mode := "wild" if RunState.phase == RunState.Phase.WILD else "room"
		_biome.present_sector(_sector, size, mode)
	_apply_party_camera()


func _apply_party_camera() -> void:
	var zoom := StageLayout.WILD_CAM_ZOOM if RunState.phase == RunState.Phase.WILD else StageLayout.BURST_CAM_ZOOM
	for p in players:
		if is_instance_valid(p) and p.has_method("configure_stage_camera"):
			p.configure_stage_camera(_arena_half, zoom)


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
	_apply_party_camera()


func _lead() -> CharacterBody2D:
	for p in players:
		if is_instance_valid(p) and not p.dead:
			return p
	return players[0] if players.size() else null


func _place_party(at: Vector2) -> void:
	for i in players.size():
		var p: CharacterBody2D = players[i]
		if is_instance_valid(p):
			p.global_position = at + Vector2(i * 36.0 - (players.size() - 1) * 18.0, 0)


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	for c in get_tree().get_nodes_in_group("feedable_corpse"):
		c.queue_free()


func _clear_exits() -> void:
	for d in get_tree().get_nodes_in_group("exit_door"):
		d.queue_free()
	_awaiting_exit = false


func _clear_hooks() -> void:
	for n in get_tree().get_nodes_in_group("greed_hook"):
		n.queue_free()
	chest_points.clear()
	shrine_points.clear()


func _start_dungeon_burst() -> void:
	RunState.set_phase(RunState.Phase.DUNGEON)
	_room_cleared = false
	_general_spawned = false
	_awaiting_exit = false
	_clear_exits()
	_clear_hooks()
	var rid := _queued_room_id if not _queued_room_id.is_empty() else StageLayout.room_id_for_index(RunState.dungeon_index)
	_room = StageLayout.room(rid)
	var sname := str(_sector.get("name", "Sector"))
	banner.text = "%s — Burst %d / %d · %s" % [
		sname, RunState.dungeon_index + 1, RunState.dungeons_total, str(_room.get("id", "room"))
	]
	_build_arena(_room.get("half", Vector2(480, 320)), _room.get("inner_walls", []))
	_place_party(_room.get("entry", Vector2.ZERO))
	_clear_enemies()
	director.stop()
	var count := 6 + 2 * RunState.dungeon_index
	if bool(_sector.get("nightmare", false)):
		count += 3
	_burst_total = count
	_burst_left = count
	_pending_spawns = 0
	_burst_archetypes.clear()
	print(
		"STAGE_LAYOUT phase=dungeon room=%s half=%.0fx%.0f burst=%d/%d enemies=%d"
		% [str(_room.get("id", "")), _arena_half.x, _arena_half.y, RunState.dungeon_index + 1, RunState.dungeons_total, count]
	)
	_spawn_burst_wave()
	RunState.begin_room()


func _spawn_burst_wave() -> void:
	var n := mini(WAVE_SIZE, _burst_left)
	if n <= 0:
		return
	var offset := _burst_total - _burst_left
	_burst_left -= n
	_pending_spawns += n
	for i in n:
		_kick_burst_spawn(offset + i, n, i)


func _kick_burst_spawn(i: int, total: int, slot: int) -> void:
	var delay := 0.0 if total <= 1 else 1.5 * float(slot) / float(maxi(total - 1, 1))
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_inside_tree() or RunState.phase != RunState.Phase.DUNGEON:
		_pending_spawns = maxi(_pending_spawns - 1, 0)
		return
	_spawn_burst_enemy(i, total)
	_pending_spawns = maxi(_pending_spawns - 1, 0)


func _edge_spawn_pos() -> Vector2:
	var inset := 52.0
	var hx := maxf(40.0, _arena_half.x - inset)
	var hy := maxf(40.0, _arena_half.y - inset)
	match randi() % 4:
		0:
			return Vector2(randf_range(-hx, hx), -hy)
		1:
			return Vector2(randf_range(-hx, hx), hy)
		2:
			return Vector2(-hx, randf_range(-hy, hy))
		_:
			return Vector2(hx, randf_range(-hy, hy))


func _room_spawn_pos(i: int) -> Vector2:
	var pts: Array = _room.get("spawn_points", [])
	if pts.is_empty():
		return _edge_spawn_pos()
	var base: Vector2 = pts[i % pts.size()]
	return base + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))


func _spawn_burst_enemy(i: int, _total: int) -> void:
	var lead := _lead()
	var e: Node2D = MWEnemyFactory.spawn(entities, _room_spawn_pos(i), lead, {
		"sector_id": str(_sector.get("id", RunState.sector_id)),
		"elite": MWEnemyFactory.burst_elite(),
		"avoid_archetypes": _burst_archetypes,
		"telegraph": true,
		"telegraph_s": 0.45,
	})
	var arch := str(e.get("archetype"))
	if arch != "" and not _burst_archetypes.has(arch):
		_burst_archetypes.append(arch)
	if _burst_archetypes.size() >= 4:
		_burst_archetypes.clear()


func _alive_enemies() -> int:
	return get_tree().get_nodes_in_group("enemy").size()


func _process(_delta: float) -> void:
	if RunState.phase == RunState.Phase.DUNGEON and not _room_cleared:
		if _pending_spawns <= 0:
			var alive := _alive_enemies()
			if _burst_left > 0 and alive <= WAVE_NEXT_AT:
				_spawn_burst_wave()
			elif _burst_left <= 0 and alive == 0:
				_room_cleared = true
				_on_burst_cleared()
	elif RunState.phase == RunState.Phase.WILD:
		if RunState.can_spawn_general() and not _general_spawned:
			_spawn_general()


func _on_burst_cleared() -> void:
	banner.text = "Burst cleared — choose a door"
	if randf() < 0.35:
		_spawn_gear_drop(Vector2(randf_range(-80, 80), randf_range(-40, 40)))
	if RunState.dungeon_index == 0:
		## Hades-style opening boon: the first room always pays a pact.
		await _offer_boon_if_needed()
	_open_exit_doors()


func _open_exit_doors() -> void:
	_clear_exits()
	_awaiting_exit = true
	var last := RunState.dungeon_index + 1 >= RunState.dungeons_total
	var specs: Array = StageLayout.last_burst_doors(_arena_half) if last else _room.get("doors", [])
	if specs.size() < 2:
		specs = StageLayout.room("chamber").get("doors", [])
	for spec in specs:
		if typeof(spec) != TYPE_DICTIONARY:
			continue
		var door: ExitDoor = ExitDoorScript.new()
		entities.add_child(door)
		door.setup(
			str(spec.get("reward", "boon")),
			str(spec.get("label", "Door")),
			str(spec.get("next", "")),
			spec.get("pos", Vector2(_arena_half.x - 80.0, 0))
		)
		door.chosen.connect(_on_exit_chosen)
	print("BURST_EXIT_DOORS count=%d last=%s" % [specs.size(), last])


func _on_exit_chosen(door: ExitDoor) -> void:
	if not _awaiting_exit:
		return
	_awaiting_exit = false
	var reward := door.reward
	var next_id := door.next_room
	print("BURST_EXIT_CHOICE picked=%s next=%s" % [reward, next_id])
	_clear_exits()
	_apply_door_reward(reward, next_id)


func _apply_door_reward(reward: String, next_id: String) -> void:
	if reward == "gear":
		_spawn_gear_drop(Vector2(40, 0))
		## Cache doors trade a boon for gear plus a small haul (banked at run end).
		RunState.add_cache(3, 2, 1)
	elif reward == "boon":
		await _offer_boon_if_needed()
	elif reward.begins_with("wild"):
		_wild_reward = reward
		_wild_start = StageLayout.wild_start(reward, StageLayout.wild_half(bool(_sector.get("nightmare", false))))
	RunState.dungeon_index += 1
	if RunState.dungeon_index >= RunState.dungeons_total:
		_start_wild()
	else:
		if not next_id.is_empty() and next_id != "wild":
			_queued_room_id = next_id
		else:
			_queued_room_id = StageLayout.room_id_for_index(RunState.dungeon_index)
		await get_tree().create_timer(0.5).timeout
		_start_dungeon_burst()


func _start_wild() -> void:
	RunState.set_phase(RunState.Phase.WILD)
	banner.text = "Wild Stage — %s" % str(_sector.get("name", ""))
	var nightmare := bool(_sector.get("nightmare", false))
	var wild_size := StageLayout.wild_half(nightmare)
	_build_arena(wild_size, [])
	_place_greed_hooks(wild_size)
	if _wild_start == Vector2.ZERO:
		_wild_start = StageLayout.wild_start(_wild_reward, wild_size)
	_place_party(_wild_start)
	var lead := _lead()
	if lead:
		director.start(lead)
	_clear_enemies()
	var view := get_viewport().get_visible_rect().size / StageLayout.WILD_CAM_ZOOM
	print(
		"STAGE_LAYOUT phase=wild half=%.0fx%.0f zoom=%.2f view≈%.0fx%.0f travel=1 start=%s"
		% [wild_size.x, wild_size.y, StageLayout.WILD_CAM_ZOOM, view.x, view.y, _wild_reward]
	)
	await _offer_boon_if_needed()
	RunState.begin_room()


func _place_greed_hooks(half: Vector2) -> void:
	_clear_hooks()
	var hooks: Dictionary = StageLayout.greed_hooks(half)
	chest_points.clear()
	shrine_points.clear()
	for p in hooks.get("chest", []):
		chest_points.append(p)
	for p in hooks.get("shrine", []):
		shrine_points.append(p)
	for pos in chest_points:
		_spawn_greed(pos, "chest")
	var shrine_kinds: PackedStringArray = StageLayout.SHRINE_KINDS
	for i in shrine_points.size():
		_spawn_greed(shrine_points[i], shrine_kinds[i % shrine_kinds.size()])
	print("WILD_GREED_HOOKS chests=%d shrines=%d" % [chest_points.size(), shrine_points.size()])


func _spawn_greed(pos: Vector2, kind: String) -> void:
	var g: GreedShrine = GreedShrineScript.new()
	g.setup(kind, pos)
	entities.add_child(g)
	g.activated.connect(_on_greed_activated)


func _on_greed_activated(shrine: GreedShrine, who: Node) -> void:
	var kind := shrine.kind
	var detail := ""
	match kind:
		"chest":
			if randf() < 0.35:
				_spawn_gear_drop(shrine.global_position + Vector2(0, 28))
				detail = "gear"
			else:
				var roll := randi() % 3
				var amt := 6 + randi() % 5
				match roll:
					0:
						RunState.add_cache(amt, 0, 0)
						detail = "blood+%d" % amt
					1:
						RunState.add_cache(0, amt, 0)
						detail = "ash+%d" % amt
					_:
						RunState.add_cache(0, 0, maxi(3, amt / 2))
						detail = "tech+%d" % maxi(3, amt / 2)
			banner.text = "Strongbox pried — %s" % detail
		"moon_altar":
			## Boon now; the director clock jumps ahead for the whole party.
			RunState.clock_bonus += MOON_ALTAR_CLOCK
			detail = "clock+%.0f" % MOON_ALTAR_CLOCK
			banner.text = "The moon hurries — %s" % RunState.get_difficulty_label()
		"blood_well":
			## Feed-for-power: pour hunger (feed stacks earned on humans in combat) or bleed.
			if RunState.feed_buff_stacks >= 2:
				detail = "hunger-%d" % RunState.feed_buff_stacks
				RunState.feed_buff_stacks = 0
				RunState.feed_buff_timer = 0.0
				RunState.feed_buff_changed.emit(0)
			else:
				var h: Health = who.get_node_or_null("Health") if who else null
				if h:
					var cost := h.max_hp * BLOOD_WELL_BLEED
					h.hp = maxf(1.0, h.hp - cost)
					if players.size() and who == players[0]:
						RunState.player_hp = h.hp
					detail = "bleed-%.0f" % cost
			banner.text = "The well drinks — %s" % detail
	RunState.note_greed(kind)
	print("GREED_USED kind=%s detail=%s t=%.1f wild_kills=%d" % [kind, detail, RunState.run_time, RunState.wild_kills])
	if kind != "chest":
		await _offer_boon_if_needed(true)


func _spawn_general() -> void:
	_general_spawned = true
	director.stop()
	RunState.set_phase(RunState.Phase.BOSS)
	var gid := str(_sector.get("general_id", "marshal_hale"))
	var gname := str(_sector.get("general_name", "General"))
	banner.text = gname
	var boss: Node = GENERAL_SCENE.instantiate()
	var lead := _lead()
	var at := Vector2(0, -180)
	if lead:
		at = lead.global_position + Vector2(0, -220)
		at.x = clampf(at.x, -_arena_half.x + 80.0, _arena_half.x - 80.0)
		at.y = clampf(at.y, -_arena_half.y + 80.0, _arena_half.y - 80.0)
	boss.global_position = at
	entities.add_child(boss)
	if boss.has_method("configure"):
		boss.configure(gid)
	boss.defeated.connect(_on_general_defeated)


func _on_general_defeated() -> void:
	RunState.general_defeated = true
	RunState.set_phase(RunState.Phase.VICTORY)
	banner.text = "Sector seized — returning to Ashwick"
	director.stop()
	print(
		"SECTOR_CLEAR_TIME sector=%s seconds=%.1f target=%.1f"
		% [RunState.sector_id, RunState.run_time, SECTOR_CLEAR_TARGET]
	)
	_spawn_gear_drop(Vector2.ZERO if _lead() == null else _lead().global_position)
	## The general always pays a pact, even past the soft target.
	await _offer_boon_if_needed(true)
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


## Soft target (~8/sector): automatic offers stop at it; shrines and the general (force) do not.
func _offer_boon_if_needed(force: bool = false) -> void:
	if not force and RunState.boon_picks_done >= RunState.boon_picks_target:
		return
	if RunState.awaiting_boon:
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

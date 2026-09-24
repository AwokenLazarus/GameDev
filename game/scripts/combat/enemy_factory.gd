class_name MWEnemyFactory
extends RefCounted
## Instantiates the shared enemy scene with an archetype script + family row.

const SCENE := preload("res://scenes/entities/enemy.tscn")
const SCRIPTS := {
	"melee": preload("res://scripts/combat/archetypes/enemy_melee.gd"),
	"ranged": preload("res://scripts/combat/archetypes/enemy_ranged.gd"),
	"charger": preload("res://scripts/combat/archetypes/enemy_charger.gd"),
	"caster": preload("res://scripts/combat/archetypes/enemy_caster.gd"),
}


static func spawn(parent: Node, pos: Vector2, player: Node2D, opts: Dictionary = {}) -> Node2D:
	var sector_id := str(opts.get("sector_id", RunState.sector_id if RunState else "dust_meridian"))
	var used: Array = opts.get("avoid_archetypes", [])
	var family: Dictionary
	if opts.has("family"):
		family = (opts["family"] as Dictionary).duplicate(true)
	else:
		family = SectorDB.roll_enemy_family(sector_id, str(opts.get("archetype", "")), used)
	var archetype := str(family.get("archetype", opts.get("archetype", "melee")))
	var e: Node2D = SCENE.instantiate()
	var script: Script = SCRIPTS.get(archetype, SCRIPTS["melee"])
	e.set_script(script)
	e.global_position = pos
	parent.add_child(e)
	var elite := bool(opts.get("elite", false))
	if not opts.has("elite"):
		elite = roll_elite()
	var human := bool(family.get("human", false))
	if not family.has("human"):
		human = randf() < float(SectorDB.get_sector(sector_id).get("enemy_human_chance", 0.35))
	if e.has_method("setup_family"):
		e.setup_family(player, family, human, elite)
	elif e.has_method("setup"):
		e.setup(player, human, elite)
	if bool(opts.get("telegraph", true)) and e.has_method("begin_spawn_telegraph"):
		e.begin_spawn_telegraph(float(opts.get("telegraph_s", 0.45)))
	return e


static func roll_elite() -> bool:
	## Elites rare → common over the 25 min difficulty clock (L4).
	var t := RunState.difficulty_clock() if RunState else 0.0
	var elite_chance := clampf(0.02 + 0.3 * (t - 120.0) / 1380.0, 0.02, 0.32)
	return randf() < elite_chance


static func burst_elite() -> bool:
	return RunState.run_time > 70.0 and randf() < 0.15

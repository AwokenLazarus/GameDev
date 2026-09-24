extends Node
## Sector biomes, generals, and raid metadata for Moonwake.

var _sectors: Dictionary = {} ## id -> Dictionary
var _generals: Dictionary = {} ## id -> Dictionary


func _ready() -> void:
	_build_generals()
	_build_sectors()


func _build_generals() -> void:
	_generals = {
		"marshal_hale": {
			"id": "marshal_hale",
			"name": "Marshal Corvin Hale",
			"title": "Human enforcer",
			"sector_id": "dust_meridian",
			"description": "Dominion rail marshal who keeps Dust Meridian under a hard badge and harder gallows.",
			"max_hp": 520.0,
			"move_speed": 130.0,
			"pattern": "charge",
			"color": Color(0.45, 0.38, 0.32),
		},
		"lady_sable": {
			"id": "lady_sable",
			"name": "Lady Sable Veyra",
			"title": "Rival-house industrialist",
			"sector_id": "cinder_barrens",
			"description": "House Veyra industrialist who feeds the Barrens' furnaces with blood-tech contracts.",
			"max_hp": 580.0,
			"move_speed": 120.0,
			"pattern": "barrage",
			"color": Color(0.55, 0.2, 0.25),
		},
		"marrowfang": {
			"id": "marrowfang",
			"name": "Marrowfang",
			"title": "Beast-blood loyalist general",
			"sector_id": "gloampine",
			"description": "Beast-blood war-general who hunts the fog redwoods for Aurelian's court.",
			"max_hp": 640.0,
			"move_speed": 160.0,
			"pattern": "leap",
			"color": Color(0.35, 0.45, 0.28),
		},
		"cantor_belis": {
			"id": "cantor_belis",
			"name": "Cantor Belis",
			"title": "Church execution-saint",
			"sector_id": "salt_choir",
			"description": "Pale Sun execution-saint whose hymns drown the salt flats in judgment light.",
			"max_hp": 600.0,
			"move_speed": 110.0,
			"pattern": "hymn",
			"color": Color(0.85, 0.8, 0.65),
		},
		"provost_rhea": {
			"id": "provost_rhea",
			"name": "Provost Rhea Sol",
			"title": "Famine collaborator",
			"sector_id": "iron_orchard",
			"description": "Agri-dome overseer who trades famine quotas for Dominion favor.",
			"max_hp": 620.0,
			"move_speed": 115.0,
			"pattern": "thorns",
			"color": Color(0.4, 0.55, 0.3),
		},
		"duke_orlokis": {
			"id": "duke_orlokis",
			"name": "Duke Thane Orlokis",
			"title": "Court vampire rival-kin",
			"sector_id": "noir_cathedral",
			"description": "Chromegoth court duke and rival-kin who rules the shaded megacity.",
			"max_hp": 700.0,
			"move_speed": 140.0,
			"pattern": "void",
			"color": Color(0.25, 0.2, 0.35),
		},
		"admiral_drus": {
			"id": "admiral_drus",
			"name": "Admiral Kael Drus",
			"title": "Fleet-warden",
			"sector_id": "umbral_marches",
			"description": "Orbital fleet-warden guarding the scrap-ring approaches to the Pale Spire.",
			"max_hp": 750.0,
			"move_speed": 150.0,
			"pattern": "fleet",
			"color": Color(0.3, 0.35, 0.45),
		},
		"aurelian": {
			"id": "aurelian",
			"name": "Aurelian the Undying",
			"title": "Galactic vampire tyrant",
			"sector_id": "pale_spire",
			"description": "Emperor of the moon-curse. Defeat opens NG+ heat and new generals.",
			"max_hp": 1400.0,
			"move_speed": 145.0,
			"pattern": "aurelian",
			"color": Color(0.7, 0.15, 0.18),
		},
	}


func _build_sectors() -> void:
	_sectors.clear()
	_add_sector({
		"id": "dust_meridian",
		"name": "Dust Meridian",
		"general_id": "marshal_hale",
		"general_name": "Marshal Corvin Hale",
		"biome_color": Color(0.78, 0.68, 0.48, 1.0),
		"accent": Color(0.55, 0.42, 0.28, 1.0),
		"ground_color": Color(0.62, 0.54, 0.38, 1.0),
		"burst_count": 5,
		"kill_gate_base": 1150,
		"nightmare": false,
		"patron_weights": {
			"dust_compact": 1.4,
			"red_petition": 1.3,
			"house_veyra": 0.45,
			"church": 0.4,
		},
		"enemy_human_chance": 0.35,
		"enemy_families": _families_dust(),
		"description": "Bleached flats and rail wrecks under a hard Dominion badge.",
		"unlock_hint": "Available from the first moon.",
	})
	_add_sector({
		"id": "cinder_barrens",
		"name": "Cinder Barrens",
		"general_id": "lady_sable",
		"general_name": "Lady Sable Veyra",
		"biome_color": Color(0.72, 0.32, 0.22, 1.0),
		"accent": Color(0.95, 0.55, 0.18, 1.0),
		"ground_color": Color(0.35, 0.18, 0.14, 1.0),
		"burst_count": 5,
		"kill_gate_base": 1150,
		"nightmare": false,
		"patron_weights": {
			"dust_compact": 0.9,
			"red_petition": 1.35,
			"house_veyra": 0.35,
			"church": 1.2,
		},
		"enemy_human_chance": 0.28,
		"enemy_families": _families_cinder(),
		"description": "Volcanic slag and mining pits owned by House Veyra industry.",
		"unlock_hint": "Clear Dust Meridian, or spend Ash on the map petition.",
	})
	_add_sector({
		"id": "gloampine",
		"name": "Gloampine",
		"general_id": "marrowfang",
		"general_name": "Marrowfang",
		"biome_color": Color(0.28, 0.42, 0.36, 1.0),
		"accent": Color(0.55, 0.75, 0.45, 1.0),
		"ground_color": Color(0.18, 0.26, 0.22, 1.0),
		"burst_count": 5,
		"kill_gate_base": 1150,
		"nightmare": false,
		"patron_weights": {
			"dust_compact": 1.1,
			"red_petition": 1.0,
			"house_veyra": 0.85,
			"church": 0.7,
		},
		"enemy_human_chance": 0.18,
		"enemy_families": _families_gloam(),
		"description": "Fog redwoods, rope bridges, and beast-blood hunting grounds.",
		"unlock_hint": "Unlock after Cinder Barrens or Kin trail leads.",
	})
	_add_sector({
		"id": "salt_choir",
		"name": "Salt Choir",
		"general_id": "cantor_belis",
		"general_name": "Cantor Belis",
		"biome_color": Color(0.82, 0.84, 0.86, 1.0),
		"accent": Color(0.95, 0.88, 0.55, 1.0),
		"ground_color": Color(0.70, 0.72, 0.74, 1.0),
		"burst_count": 5,
		"kill_gate_base": 1150,
		"nightmare": false,
		"patron_weights": {
			"dust_compact": 1.35,
			"red_petition": 1.1,
			"house_veyra": 1.0,
			"church": 0.3,
		},
		"enemy_human_chance": 0.40,
		"enemy_families": _families_salt(),
		"description": "Salt flats and drowned chapels under Pale Sun judgment.",
		"unlock_hint": "Church pressure rises after Gloampine clears.",
	})
	_add_sector({
		"id": "iron_orchard",
		"name": "Iron Orchard",
		"general_id": "provost_rhea",
		"general_name": "Provost Rhea Sol",
		"biome_color": Color(0.42, 0.55, 0.28, 1.0),
		"accent": Color(0.70, 0.35, 0.25, 1.0),
		"ground_color": Color(0.30, 0.38, 0.20, 1.0),
		"burst_count": 5,
		"kill_gate_base": 1150,
		"nightmare": false,
		"patron_weights": {
			"dust_compact": 0.8,
			"red_petition": 1.45,
			"house_veyra": 0.75,
			"church": 0.9,
		},
		"enemy_human_chance": 0.32,
		"enemy_families": _families_orchard(),
		"description": "Feral agri-domes and thorn trains under famine quotas.",
		"unlock_hint": "Petition missions open after Salt Choir.",
	})
	_add_sector({
		"id": "noir_cathedral",
		"name": "Noir Cathedral",
		"general_id": "duke_orlokis",
		"general_name": "Duke Thane Orlokis",
		"biome_color": Color(0.18, 0.16, 0.28, 1.0),
		"accent": Color(0.75, 0.25, 0.35, 1.0),
		"ground_color": Color(0.12, 0.11, 0.16, 1.0),
		"burst_count": 5,
		"kill_gate_base": 1150,
		"nightmare": false,
		"patron_weights": {
			"dust_compact": 0.7,
			"red_petition": 1.0,
			"house_veyra": 0.5,
			"church": 1.25,
		},
		"enemy_human_chance": 0.45,
		"enemy_families": _families_noir(),
		"description": "Chromegoth megacity under permanent shade and court intrigue.",
		"unlock_hint": "Court access after Iron Orchard.",
	})
	_add_sector({
		"id": "umbral_marches",
		"name": "Umbral Marches",
		"general_id": "admiral_drus",
		"general_name": "Admiral Kael Drus",
		"biome_color": Color(0.22, 0.24, 0.40, 1.0),
		"accent": Color(0.45, 0.70, 0.90, 1.0),
		"ground_color": Color(0.14, 0.15, 0.22, 1.0),
		"burst_count": 5,
		"kill_gate_base": 1150,
		"nightmare": false,
		"patron_weights": {
			"dust_compact": 1.2,
			"red_petition": 1.15,
			"house_veyra": 0.9,
			"church": 0.85,
		},
		"enemy_human_chance": 0.22,
		"enemy_families": _families_umbral(),
		"description": "Orbital scrap-rings on the climb toward the Pale Spire.",
		"unlock_hint": "Open the Marches after Noir Cathedral.",
	})
	_add_sector({
		"id": "pale_spire",
		"name": "Pale Spire",
		"general_id": "aurelian",
		"general_name": "Aurelian the Undying",
		"biome_color": Color(0.90, 0.90, 0.95, 1.0),
		"accent": Color(0.70, 0.15, 0.22, 1.0),
		"ground_color": Color(0.55, 0.55, 0.62, 1.0),
		"burst_count": 5,
		"kill_gate_base": 1500,
		"nightmare": true,
		"patron_weights": {
			"dust_compact": 1.0,
			"red_petition": 1.0,
			"house_veyra": 1.0,
			"church": 1.0,
		},
		"enemy_human_chance": 0.25,
		"enemy_families": _families_spire(),
		"description": "Gothic castle fused to an orbital fortress. Scaled nightmare end raid.",
		"unlock_hint": "Always raidable. Underbuilt runs die here.",
	})


func _add_sector(data: Dictionary) -> void:
	var id: String = str(data.get("id", ""))
	if id.is_empty():
		return
	_sectors[id] = data


func get_sector(id: String) -> Dictionary:
	return _sectors.get(id, {}).duplicate(true)


func all_raidable_sectors() -> Array[Dictionary]:
	## All sectors including Pale Spire (always raidable nightmare).
	var out: Array[Dictionary] = []
	var order := [
		"dust_meridian",
		"cinder_barrens",
		"gloampine",
		"salt_choir",
		"iron_orchard",
		"noir_cathedral",
		"umbral_marches",
		"pale_spire",
	]
	for id in order:
		if _sectors.has(id):
			out.append(_sectors[id].duplicate(true))
	return out


func get_general(id: String) -> Dictionary:
	return _generals.get(id, {}).duplicate(true)


func _row(id: String, archetype: String, weight: float, sprite: String, human: bool) -> Dictionary:
	return {
		"id": id,
		"archetype": archetype,
		"weight": weight,
		"sprite": sprite,
		"human": human,
	}


func _families_dust() -> Array:
	## Dust Meridian — rail badge, all four verbs on-stage.
	return [
		_row("rail_grub", "melee", 34.0, "dominion_grub", false),
		_row("badge_rifle", "ranged", 24.0, "human_enforcer", true),
		_row("gallows_brute", "charger", 22.0, "dominion_elite", false),
		_row("dust_cantor", "caster", 20.0, "church_zealot", true),
	]


func _families_cinder() -> Array:
	return [
		_row("slag_grub", "melee", 20.0, "dominion_grub", false),
		_row("contract_rifle", "ranged", 18.0, "human_enforcer", true),
		_row("furnace_brute", "charger", 40.0, "dominion_elite", false),
		_row("veyra_hex", "caster", 22.0, "void_wretch", false),
	]


func _families_gloam() -> Array:
	return [
		_row("pine_hound", "melee", 42.0, "beast_hound", false),
		_row("kin_rifle", "ranged", 10.0, "human_enforcer", true),
		_row("marrow_brute", "charger", 36.0, "beast_hound", false),
		_row("fog_hex", "caster", 12.0, "void_wretch", false),
	]


func _families_salt() -> Array:
	return [
		_row("choir_zealot", "melee", 18.0, "church_zealot", true),
		_row("psalm_rifle", "ranged", 22.0, "church_zealot", true),
		_row("gavel_brute", "charger", 12.0, "dominion_elite", false),
		_row("cantor_hex", "caster", 48.0, "church_zealot", true),
	]


func _families_orchard() -> Array:
	return [
		_row("briar_grub", "melee", 30.0, "beast_hound", false),
		_row("quota_rifle", "ranged", 15.0, "human_enforcer", true),
		_row("thorn_train", "charger", 40.0, "beast_hound", false),
		_row("famine_hex", "caster", 15.0, "dominion_grub", false),
	]


func _families_noir() -> Array:
	return [
		_row("court_wretch", "melee", 15.0, "void_wretch", false),
		_row("shade_rifle", "ranged", 35.0, "void_wretch", false),
		_row("duke_brute", "charger", 15.0, "dominion_elite", false),
		_row("orlok_hex", "caster", 35.0, "void_wretch", false),
	]


func _families_umbral() -> Array:
	return [
		_row("scrap_grub", "melee", 16.0, "dominion_grub", false),
		_row("fleet_rifle", "ranged", 38.0, "human_enforcer", true),
		_row("warden_brute", "charger", 32.0, "dominion_elite", false),
		_row("orbit_hex", "caster", 14.0, "void_wretch", false),
	]


func _families_spire() -> Array:
	return [
		_row("pale_wretch", "melee", 25.0, "void_wretch", false),
		_row("spire_zealot", "ranged", 25.0, "church_zealot", true),
		_row("undying_brute", "charger", 25.0, "dominion_elite", false),
		_row("moon_hex", "caster", 25.0, "void_wretch", false),
	]


func enemy_families(sector_id: String) -> Array:
	var s: Dictionary = get_sector(sector_id)
	var rows: Array = s.get("enemy_families", [])
	if rows.is_empty():
		return _families_dust()
	return rows


func family_signature(sector_id: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for row in enemy_families(sector_id):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		parts.append("%s:%.0f:%s" % [str(d.get("archetype", "")), float(d.get("weight", 0.0)), str(d.get("sprite", ""))])
	return "|".join(parts)


func roll_enemy_family(sector_id: String, force_archetype: String = "", avoid_archetypes: Array = []) -> Dictionary:
	var rows: Array = enemy_families(sector_id)
	var pool: Array = []
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		var arch := str(d.get("archetype", "melee"))
		if force_archetype != "" and arch != force_archetype:
			continue
		if force_archetype == "" and not avoid_archetypes.is_empty() and avoid_archetypes.has(arch):
			continue
		pool.append(d)
	if pool.is_empty():
		for row in rows:
			if typeof(row) == TYPE_DICTIONARY:
				pool.append(row)
	if pool.is_empty():
		return _row("rail_grub", "melee", 1.0, "dominion_grub", false)
	var total := 0.0
	for row in pool:
		total += float((row as Dictionary).get("weight", 1.0))
	var pick := randf() * maxf(total, 0.001)
	var acc := 0.0
	for row in pool:
		acc += float((row as Dictionary).get("weight", 1.0))
		if pick <= acc:
			return (row as Dictionary).duplicate(true)
	return (pool[pool.size() - 1] as Dictionary).duplicate(true)

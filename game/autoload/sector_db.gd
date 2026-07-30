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
		},
		"lady_sable": {
			"id": "lady_sable",
			"name": "Lady Sable Veyra",
			"title": "Rival-house industrialist",
			"sector_id": "cinder_barrens",
			"description": "House Veyra industrialist who feeds the Barrens' furnaces with blood-tech contracts.",
		},
		"marrowfang": {
			"id": "marrowfang",
			"name": "Marrowfang",
			"title": "Beast-blood loyalist general",
			"sector_id": "gloampine",
			"description": "Beast-blood war-general who hunts the fog redwoods for Aurelian's court.",
		},
		"cantor_belis": {
			"id": "cantor_belis",
			"name": "Cantor Belis",
			"title": "Church execution-saint",
			"sector_id": "salt_choir",
			"description": "Pale Sun execution-saint whose hymns drown the salt flats in judgment light.",
		},
		"provost_rhea": {
			"id": "provost_rhea",
			"name": "Provost Rhea Sol",
			"title": "Famine collaborator",
			"sector_id": "iron_orchard",
			"description": "Agri-dome overseer who trades famine quotas for Dominion favor.",
		},
		"duke_orlokis": {
			"id": "duke_orlokis",
			"name": "Duke Thane Orlokis",
			"title": "Court vampire rival-kin",
			"sector_id": "noir_cathedral",
			"description": "Chromegoth court duke and rival-kin who rules the shaded megacity.",
		},
		"admiral_drus": {
			"id": "admiral_drus",
			"name": "Admiral Kael Drus",
			"title": "Fleet-warden",
			"sector_id": "umbral_marches",
			"description": "Orbital fleet-warden guarding the scrap-ring approaches to the Pale Spire.",
		},
		"aurelian": {
			"id": "aurelian",
			"name": "Aurelian the Undying",
			"title": "Galactic vampire tyrant",
			"sector_id": "pale_spire",
			"description": "Emperor of the moon-curse. Defeat opens NG+ heat and new generals.",
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
		"kill_gate_base": 40,
		"nightmare": false,
		"patron_weights": {
			"dust_compact": 1.4,
			"red_petition": 1.3,
			"house_veyra": 0.45,
			"church": 0.4,
		},
		"enemy_human_chance": 0.35,
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
		"kill_gate_base": 40,
		"nightmare": false,
		"patron_weights": {
			"dust_compact": 0.9,
			"red_petition": 1.35,
			"house_veyra": 0.35,
			"church": 1.2,
		},
		"enemy_human_chance": 0.28,
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
		"kill_gate_base": 40,
		"nightmare": false,
		"patron_weights": {
			"dust_compact": 1.1,
			"red_petition": 1.0,
			"house_veyra": 0.85,
			"church": 0.7,
		},
		"enemy_human_chance": 0.18,
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
		"kill_gate_base": 40,
		"nightmare": false,
		"patron_weights": {
			"dust_compact": 1.35,
			"red_petition": 1.1,
			"house_veyra": 1.0,
			"church": 0.3,
		},
		"enemy_human_chance": 0.40,
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
		"kill_gate_base": 40,
		"nightmare": false,
		"patron_weights": {
			"dust_compact": 0.8,
			"red_petition": 1.45,
			"house_veyra": 0.75,
			"church": 0.9,
		},
		"enemy_human_chance": 0.32,
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
		"kill_gate_base": 40,
		"nightmare": false,
		"patron_weights": {
			"dust_compact": 0.7,
			"red_petition": 1.0,
			"house_veyra": 0.5,
			"church": 1.25,
		},
		"enemy_human_chance": 0.45,
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
		"kill_gate_base": 40,
		"nightmare": false,
		"patron_weights": {
			"dust_compact": 1.2,
			"red_petition": 1.15,
			"house_veyra": 0.9,
			"church": 0.85,
		},
		"enemy_human_chance": 0.22,
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
		"kill_gate_base": 80,
		"nightmare": true,
		"patron_weights": {
			"dust_compact": 1.0,
			"red_petition": 1.0,
			"house_veyra": 1.0,
			"church": 1.0,
		},
		"enemy_human_chance": 0.25,
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

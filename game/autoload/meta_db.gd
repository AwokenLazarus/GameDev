extends Node
## Persistent Blood / Ash / Tech meta nodes for Moonwake.

var _nodes: Dictionary = {} ## id -> Dictionary
var _branches: Dictionary = {} ## branch -> Array[Dictionary]


func _ready() -> void:
	_build_nodes()


func _build_nodes() -> void:
	_nodes.clear()
	_branches = {"blood": [], "ash": [], "tech": []}

	## Blood rites — account passives / rite powers.
	_add_node({
		"id": "blood_vitality",
		"branch": "blood",
		"name": "Moonbone Vitality",
		"desc": "+8 max HP per rank at run start.",
		"cost": {"blood": 15, "ash": 0, "tech": 0},
		"max_rank": 5,
		"effects": {"max_hp_bonus": 8.0},
	})
	_add_node({
		"id": "blood_fang",
		"branch": "blood",
		"name": "Fang Temper",
		"desc": "+4% damage per rank.",
		"cost": {"blood": 20, "ash": 0, "tech": 0},
		"max_rank": 5,
		"effects": {"damage_bonus": 0.04},
	})
	_add_node({
		"id": "blood_feed_rite",
		"branch": "blood",
		"name": "Hungry Moon Rite",
		"desc": "+1 starting feed-buff stack capacity equivalent (damage on feed).",
		"cost": {"blood": 30, "ash": 5, "tech": 0},
		"max_rank": 3,
		"effects": {"feed_damage_bonus": 0.03},
	})
	_add_node({
		"id": "blood_lifesteal",
		"branch": "blood",
		"name": "Crimson Sip",
		"desc": "+2% lifesteal per rank.",
		"cost": {"blood": 25, "ash": 0, "tech": 5},
		"max_rank": 4,
		"effects": {"lifesteal_bonus": 0.02},
	})
	_add_node({
		"id": "blood_earn",
		"branch": "blood",
		"name": "Moon Tithe",
		"desc": "+10% Blood earned from raids per rank.",
		"cost": {"blood": 20, "ash": 0, "tech": 0},
		"max_rank": 3,
		"effects": {"blood_earn": 0.10},
	})

	## Ash rebuild — Ashwick vendors / missions.
	_add_node({
		"id": "ash_vendor_church",
		"branch": "ash",
		"name": "Churchyard Stall",
		"desc": "Rebuild the pale-sun stall in Ashwick (vendor access).",
		"cost": {"blood": 0, "ash": 40, "tech": 5},
		"max_rank": 1,
		"effects": {"ashwick_vendor_church": true},
	})
	_add_node({
		"id": "ash_vendor_compact",
		"branch": "ash",
		"name": "Rail Rat Market",
		"desc": "Reopen Dust Compact fencing in the ash lanes.",
		"cost": {"blood": 5, "ash": 35, "tech": 10},
		"max_rank": 1,
		"effects": {"ashwick_vendor_compact": true},
	})
	_add_node({
		"id": "ash_mission_petition",
		"branch": "ash",
		"name": "Petition Board",
		"desc": "Unlock Red Petition mission petitions from the mayor's yard.",
		"cost": {"blood": 10, "ash": 50, "tech": 0},
		"max_rank": 1,
		"effects": {"unlock_mission_petition": true},
	})
	_add_node({
		"id": "ash_kin_hearth",
		"branch": "ash",
		"name": "Kin Hearth",
		"desc": "Restore Kin lodging; soft quests and trust recover faster.",
		"cost": {"blood": 0, "ash": 45, "tech": 0},
		"max_rank": 2,
		"effects": {"ashwick_kin_hearth": true, "ash_reward_bonus": 2},
	})
	_add_node({
		"id": "ash_map_table",
		"branch": "ash",
		"name": "Charred Map Table",
		"desc": "+1 starting boon pick target toward mid-raid pressure relief.",
		"cost": {"blood": 0, "ash": 60, "tech": 15},
		"max_rank": 2,
		"effects": {"boon_picks_bonus": 1},
	})
	_add_node({
		"id": "ash_veyra_eyes",
		"branch": "ash",
		"name": "Veyra Safehouse",
		"desc": "Rebuild House Veyra's spy nest in Ashwick.",
		"cost": {"blood": 15, "ash": 55, "tech": 20},
		"max_rank": 1,
		"effects": {"vendor_veyra": true, "ashwick_vendor_veyra": true},
	})
	_add_node({
		"id": "ash_earn",
		"branch": "ash",
		"name": "Tithe Pits",
		"desc": "+10% Ash earned from raids per rank.",
		"cost": {"blood": 0, "ash": 30, "tech": 0},
		"max_rank": 3,
		"effects": {"ash_earn": 0.10},
	})

	## Tech — salvaged Dominion tools / passives.
	_add_node({
		"id": "tech_servo",
		"branch": "tech",
		"name": "Servo Spurs",
		"desc": "+3% move speed per rank.",
		"cost": {"blood": 0, "ash": 5, "tech": 20},
		"max_rank": 5,
		"effects": {"move_bonus": 0.03},
	})
	_add_node({
		"id": "tech_chamber",
		"branch": "tech",
		"name": "Quick Chamber Coil",
		"desc": "+3% attack speed per rank.",
		"cost": {"blood": 0, "ash": 0, "tech": 25},
		"max_rank": 5,
		"effects": {"attack_speed_bonus": 0.03},
	})
	_add_node({
		"id": "tech_dash",
		"branch": "tech",
		"name": "Dust Jet Boots",
		"desc": "+5% dodge / dash distance per rank.",
		"cost": {"blood": 5, "ash": 10, "tech": 30},
		"max_rank": 3,
		"effects": {"dash_bonus": 0.05},
	})
	_add_node({
		"id": "tech_scanner",
		"branch": "tech",
		"name": "Killgate Scanner",
		"desc": "Reduce kill gate by 2 per rank (min floor applied by run logic).",
		"cost": {"blood": 0, "ash": 15, "tech": 40},
		"max_rank": 3,
		"effects": {"kill_gate_bonus": -2},
	})
	_add_node({
		"id": "tech_earn",
		"branch": "tech",
		"name": "Salvage Rights",
		"desc": "+10% Tech earned from raids per rank.",
		"cost": {"blood": 0, "ash": 0, "tech": 25},
		"max_rank": 3,
		"effects": {"tech_earn": 0.10},
	})


func _add_node(data: Dictionary) -> void:
	var id: String = str(data.get("id", ""))
	var branch: String = str(data.get("branch", ""))
	if id.is_empty() or branch.is_empty():
		return
	_nodes[id] = data
	if not _branches.has(branch):
		_branches[branch] = []
	(_branches[branch] as Array).append(data)


func get_branch(branch: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw: Array = _branches.get(branch, [])
	for n in raw:
		if typeof(n) == TYPE_DICTIONARY:
			out.append((n as Dictionary).duplicate(true))
	return out


func get_upgrade(id: String) -> Dictionary:
	return _nodes.get(id, {}).duplicate(true)


func all_nodes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in _nodes.keys():
		out.append(_nodes[id].duplicate(true))
	return out


func _resolve_ranks(stats: Dictionary) -> Dictionary:
	## Prefer ranks embedded on the stats dict; else GameState.meta_ranks if present.
	if stats.has("meta_ranks") and typeof(stats["meta_ranks"]) == TYPE_DICTIONARY:
		return stats["meta_ranks"]
	if GameState != null:
		var mr: Variant = GameState.get("meta_ranks")
		if typeof(mr) == TYPE_DICTIONARY:
			return mr
	return {}


## Apply owned meta ranks onto a RunState-like stats Dictionary.
## Returns a modifiers Dictionary (bonuses / flags) without mutating stats unless caller merges.
func apply_ranks_to_run(stats: Dictionary) -> Dictionary:
	var ranks := _resolve_ranks(stats)
	var mods := {
		"max_hp_bonus": 0.0,
		"damage_bonus": 0.0,
		"move_bonus": 0.0,
		"attack_speed_bonus": 0.0,
		"lifesteal_bonus": 0.0,
		"dash_bonus": 0.0,
		"feed_damage_bonus": 0.0,
		"kill_gate_bonus": 0,
		"boon_picks_bonus": 0,
		"ash_reward_bonus": 0,
		"ashwick_vendor_church": false,
		"ashwick_vendor_compact": false,
		"unlock_mission_petition": false,
		"ashwick_kin_hearth": false,
		"vendor_veyra": false,
		"blood_earn": 0.0,
		"ash_earn": 0.0,
		"tech_earn": 0.0,
	}

	for node_id in ranks.keys():
		var rank := int(ranks[node_id])
		if rank <= 0:
			continue
		var node: Dictionary = _nodes.get(str(node_id), {})
		if node.is_empty():
			continue
		var max_rank := int(node.get("max_rank", 1))
		rank = mini(rank, max_rank)
		var effects: Dictionary = node.get("effects", {})
		for key in effects.keys():
			var value: Variant = effects[key]
			match typeof(value):
				TYPE_BOOL:
					if bool(value) and rank > 0:
						mods[key] = true
				TYPE_INT:
					mods[key] = int(mods.get(key, 0)) + int(value) * rank
				TYPE_FLOAT:
					mods[key] = float(mods.get(key, 0.0)) + float(value) * rank
				_:
					mods[key] = value

	## Optional: fold numeric bonuses into a mutable stats snapshot when keys exist.
	if stats.has("player_max_hp"):
		stats["player_max_hp"] = float(stats["player_max_hp"]) + float(mods["max_hp_bonus"])
	if stats.has("player_hp") and stats.has("player_max_hp"):
		stats["player_hp"] = minf(float(stats["player_hp"]) + float(mods["max_hp_bonus"]), float(stats["player_max_hp"]))
	if stats.has("damage_mult"):
		stats["damage_mult"] = float(stats["damage_mult"]) + float(mods["damage_bonus"])
	if stats.has("move_mult"):
		stats["move_mult"] = float(stats["move_mult"]) + float(mods["move_bonus"])
	if stats.has("attack_speed_mult"):
		stats["attack_speed_mult"] = float(stats["attack_speed_mult"]) + float(mods["attack_speed_bonus"])
	if stats.has("lifesteal"):
		stats["lifesteal"] = float(stats["lifesteal"]) + float(mods["lifesteal_bonus"])
	if stats.has("dash_mult"):
		stats["dash_mult"] = float(stats["dash_mult"]) + float(mods["dash_bonus"])
	if stats.has("kill_gate"):
		stats["kill_gate"] = maxi(1, int(stats["kill_gate"]) + int(mods["kill_gate_bonus"]))
	if stats.has("boon_picks_target"):
		stats["boon_picks_target"] = int(stats["boon_picks_target"]) + int(mods["boon_picks_bonus"])

	return mods

extends Node
## Character definitions, kits, and unlock queries for Moonwake.

var _characters: Dictionary = {} ## id -> Dictionary
var _alts: Dictionary = {} ## character_id -> Array[Dictionary]


func _ready() -> void:
	_build_roster()


func _build_roster() -> void:
	_characters.clear()
	_alts.clear()

	_register_character({
		"id": "severin",
		"name": "Severin",
		"unlocked_by_default": true,
		"unlock_cost": {"blood": 0, "ash": 0, "tech": 0},
		"description": "Moon-edge longblade and peace-cord draws. Manual melee hunter from Ashwick's gunsmith line.",
		"color": Color(0.72, 0.78, 0.88, 1.0),
		"kit_type": "melee",
		"base_hp": 110.0,
		"move_speed": 220.0,
		"attack_cooldown": 0.42,
		"damage": 14.0,
		"special_notes": "Peace-cord: brief lunge that cancels into a heavy draw. Strong close-range commits.",
	}, [
		{
			"id": "severin_gunsmith",
			"name": "Ashwick Gunsmith Edge",
			"unlock_cost": {"blood": 25, "ash": 40, "tech": 15},
			"kit_modifiers": {
				"kit_type": "hybrid_gun",
				"damage": -2.0,
				"attack_cooldown": -0.08,
				"move_speed": 10.0,
				"special_notes": "Sidearm volleys between blade draws. Safer poke, softer burst.",
			},
		},
	])

	_register_character({
		"id": "mira",
		"name": "Mira",
		"unlocked_by_default": false,
		"unlock_cost": {"blood": 40, "ash": 20, "tech": 35},
		"description": "Wrist-rail silverstorm. Hybrid aim with seeking auto volleys. Rail-town preacher's daughter.",
		"color": Color(0.85, 0.82, 0.55, 1.0),
		"kit_type": "hybrid_gun",
		"base_hp": 90.0,
		"move_speed": 235.0,
		"attack_cooldown": 0.28,
		"damage": 8.0,
		"special_notes": "Seeking bolt rain while aiming; volleys continue briefly after release.",
	}, [
		{
			"id": "mira_choir_rail",
			"name": "Choir Rail",
			"unlock_cost": {"blood": 20, "ash": 15, "tech": 50},
			"kit_modifiers": {
				"damage": 2.0,
				"attack_cooldown": 0.06,
				"base_hp": 10.0,
				"special_notes": "Slower charged beams that pierce; fewer bolts, harder hits.",
			},
		},
	])

	_register_character({
		"id": "cassian",
		"name": "Cassian",
		"unlocked_by_default": false,
		"unlock_cost": {"blood": 35, "ash": 25, "tech": 40},
		"description": "Twin crescent throwers that orbit and recall. Positioning-first court exile.",
		"color": Color(0.55, 0.70, 0.78, 1.0),
		"kit_type": "orbit",
		"base_hp": 95.0,
		"move_speed": 225.0,
		"attack_cooldown": 0.55,
		"damage": 10.0,
		"special_notes": "Crescents orbit nearby foes; recall snaps them home for a burst.",
	}, [
		{
			"id": "cassian_scholar_orbit",
			"name": "Scholar's Recall",
			"unlock_cost": {"blood": 30, "ash": 10, "tech": 45},
			"kit_modifiers": {
				"damage": -1.0,
				"attack_cooldown": -0.10,
				"move_speed": 15.0,
				"special_notes": "Wider orbit radius, weaker impact; better crowd control.",
			},
		},
	])

	_register_character({
		"id": "odette",
		"name": "Odette",
		"unlocked_by_default": false,
		"unlock_cost": {"blood": 45, "ash": 35, "tech": 20},
		"description": "Sepulcher maul with shockwave anti-armor commits. Mining colony survivor.",
		"color": Color(0.78, 0.45, 0.38, 1.0),
		"kit_type": "maul",
		"base_hp": 130.0,
		"move_speed": 195.0,
		"attack_cooldown": 0.70,
		"damage": 22.0,
		"special_notes": "Heavy shockwave slams crack armor; punish telegraphed windows.",
	}, [
		{
			"id": "odette_pit_hammer",
			"name": "Pit Hammer",
			"unlock_cost": {"blood": 35, "ash": 45, "tech": 10},
			"kit_modifiers": {
				"damage": -4.0,
				"attack_cooldown": -0.18,
				"move_speed": 20.0,
				"base_hp": -10.0,
				"special_notes": "Faster chained swings, smaller shockwaves. Mobility over crush.",
			},
		},
	])

	_register_character({
		"id": "vesper",
		"name": "Vesper",
		"unlocked_by_default": false,
		"unlock_cost": {"blood": 80, "ash": 40, "tech": 60},
		"description": "Soulspike astral projection. Spirit hunts mostly auto; body is the weak point. Glass cannon unlock.",
		"color": Color(0.62, 0.48, 0.85, 1.0),
		"kit_type": "astral",
		"base_hp": 70.0,
		"move_speed": 210.0,
		"attack_cooldown": 0.35,
		"damage": 16.0,
		"special_notes": "Astral form seeks and pierces; manual detonate collapses the spike for burst. Body takes full damage.",
	}, [
		{
			"id": "vesper_anchor_spike",
			"name": "Anchor Spike",
			"unlock_cost": {"blood": 50, "ash": 25, "tech": 70},
			"kit_modifiers": {
				"base_hp": 20.0,
				"damage": -3.0,
				"move_speed": -10.0,
				"special_notes": "Spirit stays closer to body; safer glass, lower reach.",
			},
		},
	])

func _register_character(data: Dictionary, alts: Array) -> void:
	var id: String = str(data.get("id", ""))
	if id.is_empty():
		return
	_characters[id] = data
	var alt_list: Array[Dictionary] = []
	for a in alts:
		if typeof(a) == TYPE_DICTIONARY:
			alt_list.append(a)
	_alts[id] = alt_list


func get_character(id: String) -> Dictionary:
	return _characters.get(id, {}).duplicate(true)


func all_characters() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in _characters.keys():
		out.append(_characters[id].duplicate(true))
	return out


func is_unlocked(id: String) -> bool:
	var data: Dictionary = _characters.get(id, {})
	if data.is_empty():
		return false
	if bool(data.get("unlocked_by_default", false)):
		return true
	if GameState == null:
		return false
	return id in GameState.unlocked_characters


func get_alts(id: String) -> Array[Dictionary]:
	var raw: Array = _alts.get(id, [])
	var out: Array[Dictionary] = []
	for a in raw:
		if typeof(a) == TYPE_DICTIONARY:
			out.append((a as Dictionary).duplicate(true))
	return out

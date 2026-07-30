extends Node
## V0 boon definitions for Dust Compact + Red Petition (Dust Meridian slice).

var boons: Array[Dictionary] = []


func _ready() -> void:
	boons = [
		{
			"id": "dust_dash",
			"patron": "dust_compact",
			"name": "Gunsmoke Step",
			"desc": "+15% dodge distance. Dust trails linger.",
			"dash": 0.15,
			"theme": "dust",
			"verb": "dash",
		},
		{
			"id": "dust_bleed",
			"patron": "dust_compact",
			"name": "Scrap Teeth",
			"desc": "+12% damage. Hits feel jagged.",
			"damage": 0.12,
			"theme": "scrap",
			"verb": "bleed",
		},
		{
			"id": "dust_reload",
			"patron": "dust_compact",
			"name": "Quick Chamber",
			"desc": "+18% attack speed.",
			"attack_speed": 0.18,
			"theme": "gunsmoke",
			"verb": "reload",
		},
		{
			"id": "dust_loot",
			"patron": "dust_compact",
			"name": "Rail Rat Eyes",
			"desc": "+20 max HP. Smuggler's stamina.",
			"max_hp": 20.0,
			"theme": "dust",
			"verb": "loot",
		},
		{
			"id": "petition_execute",
			"patron": "red_petition",
			"name": "Widow's Writ",
			"desc": "+16% damage vs wounded foes (V0: flat damage).",
			"damage": 0.16,
			"theme": "rebellion",
			"verb": "execute",
		},
		{
			"id": "petition_trap",
			"patron": "red_petition",
			"name": "Iron Snare",
			"desc": "+12% move speed after a kill spirit (V0: move).",
			"move": 0.12,
			"theme": "iron",
			"verb": "trap",
		},
		{
			"id": "petition_team",
			"patron": "red_petition",
			"name": "Shared Blood",
			"desc": "+8% lifesteal.",
			"lifesteal": 0.08,
			"theme": "rebellion",
			"verb": "buff",
		},
		{
			"id": "petition_elite",
			"patron": "red_petition",
			"name": "Anti-Banner",
			"desc": "+10% attack speed, +8% damage.",
			"attack_speed": 0.10,
			"damage": 0.08,
			"theme": "iron",
			"verb": "anti-elite",
		},
		{
			"id": "veyra_crit",
			"patron": "house_veyra",
			"name": "Debt Edge",
			"desc": "+20% damage. Elegant cruelty.",
			"damage": 0.20,
			"theme": "blood-tech",
			"verb": "crit",
		},
		{
			"id": "veyra_life",
			"patron": "house_veyra",
			"name": "Courtesy Sip",
			"desc": "+10% lifesteal.",
			"lifesteal": 0.10,
			"theme": "elegance",
			"verb": "lifesteal",
		},
		{
			"id": "church_smite",
			"patron": "church",
			"name": "Pale Decree",
			"desc": "+14% damage. Judgment light.",
			"damage": 0.14,
			"theme": "hymn",
			"verb": "smite",
		},
		{
			"id": "church_ward",
			"patron": "church",
			"name": "Sunlit Ward",
			"desc": "+30 max HP.",
			"max_hp": 30.0,
			"theme": "ward",
			"verb": "aura",
		},
	]


func get_choices(count: int = 3) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for b in boons:
		var patron: String = str(b.get("patron", ""))
		if patron in RunState.blocked_patrons:
			continue
		## Dust Meridian V0 weights Compact + Petition higher.
		if RunState.sector_id == "dust_meridian" and patron in ["house_veyra", "church"]:
			if randf() > 0.25:
				continue
		pool.append(b)
	pool.shuffle()
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for b in pool:
		var id: String = str(b.get("id", ""))
		if seen.has(id):
			continue
		## Prefer not repeating identical ids already owned too often.
		seen[id] = true
		result.append(b)
		if result.size() >= count:
			break
	while result.size() < count and pool.size() > 0:
		result.append(pool[result.size() % pool.size()])
	return result

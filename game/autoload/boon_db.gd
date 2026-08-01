extends Node
## Boon definitions for Dust Compact, Red Petition, House Veyra, and Church.

var boons: Array[Dictionary] = []


func _ready() -> void:
	boons = [
		## --- Dust Compact (6+) ---
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
			"id": "dust_sidestep",
			"patron": "dust_compact",
			"name": "Cinder Slip",
			"desc": "+10% move speed. Harder to pin down.",
			"move": 0.10,
			"theme": "gunsmoke",
			"verb": "dash",
		},
		{
			"id": "dust_jacket",
			"patron": "dust_compact",
			"name": "Scrap Jacket",
			"desc": "+12 max HP and +6% damage.",
			"max_hp": 12.0,
			"damage": 0.06,
			"theme": "scrap",
			"verb": "loot",
		},
		## --- Red Petition (6+) ---
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
			"id": "petition_sabotage",
			"patron": "red_petition",
			"name": "Fuse Kiss",
			"desc": "+14% attack speed. Sabotage tempo.",
			"attack_speed": 0.14,
			"theme": "sabotage",
			"verb": "trap",
		},
		{
			"id": "petition_cell",
			"patron": "red_petition",
			"name": "Cell Oath",
			"desc": "+18 max HP. Hold the line for the cell.",
			"max_hp": 18.0,
			"theme": "rebellion",
			"verb": "buff",
		},
		## --- House Veyra (6+) ---
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
			"id": "veyra_shadowstep",
			"patron": "house_veyra",
			"name": "Ledger Step",
			"desc": "+12% dodge distance. Vanish between debts.",
			"dash": 0.12,
			"theme": "elegance",
			"verb": "shadowstep",
		},
		{
			"id": "veyra_evolve",
			"patron": "house_veyra",
			"name": "Gilded Vein",
			"desc": "+10% damage and +8% attack speed.",
			"damage": 0.10,
			"attack_speed": 0.08,
			"theme": "blood-tech",
			"verb": "evolve",
		},
		{
			"id": "veyra_contract",
			"patron": "house_veyra",
			"name": "Blood Contract",
			"desc": "+15 max HP and +5% lifesteal.",
			"max_hp": 15.0,
			"lifesteal": 0.05,
			"theme": "debt",
			"verb": "lifesteal",
		},
		{
			"id": "veyra_pointe",
			"patron": "house_veyra",
			"name": "Pointe of Courtesy",
			"desc": "+11% move speed. Courtly aggression.",
			"move": 0.11,
			"theme": "elegance",
			"verb": "shadowstep",
		},
		## --- Church of the Pale Sun (6+) ---
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
		{
			"id": "church_cleanse",
			"patron": "church",
			"name": "Salt Cleanse",
			"desc": "+10% attack speed. Ritual tempo.",
			"attack_speed": 0.10,
			"theme": "decree",
			"verb": "cleanse",
		},
		{
			"id": "church_cooldown",
			"patron": "church",
			"name": "Bell Interval",
			"desc": "+12% dodge distance. Step between hymns.",
			"dash": 0.12,
			"theme": "hymn",
			"verb": "cooldown",
		},
		{
			"id": "church_judgment",
			"patron": "church",
			"name": "Judgment Flare",
			"desc": "+10% damage and +10 max HP.",
			"damage": 0.10,
			"max_hp": 10.0,
			"theme": "judgment-light",
			"verb": "smite",
		},
		{
			"id": "church_procession",
			"patron": "church",
			"name": "Pale Procession",
			"desc": "+8% move speed and +6% lifesteal.",
			"move": 0.08,
			"lifesteal": 0.06,
			"theme": "ward",
			"verb": "aura",
		},
	]


func _patron_weight(patron: String) -> float:
	## Prefer SectorDB.patron_weights for RunState.sector_id when present.
	if RunState != null:
		var sector: Dictionary = SectorDB.get_sector(RunState.sector_id)
		if not sector.is_empty():
			var weights: Dictionary = sector.get("patron_weights", {})
			if weights.has(patron):
				return maxf(0.0, float(weights[patron]))
		## Fallback: Dust Meridian V0 bias if sector data missing.
		if RunState.sector_id == "dust_meridian":
			if patron in ["house_veyra", "church"]:
				return 0.35
			return 1.2
	return 1.0


func get_choices(count: int = 3) -> Array[Dictionary]:
	var weighted: Array[Dictionary] = []
	for b in boons:
		var patron: String = str(b.get("patron", ""))
		if patron in RunState.blocked_patrons:
			continue
		var w := _patron_weight(patron)
		if w <= 0.0:
			continue
		## Soft reject by inverse weight so low-weight patrons appear less often.
		if randf() > clampf(w / 1.5, 0.15, 1.0):
			continue
		weighted.append(b)

	if weighted.is_empty():
		## Safety: if weights filtered everything, fall back to unblocked pool.
		for b in boons:
			var patron: String = str(b.get("patron", ""))
			if patron in RunState.blocked_patrons:
				continue
			weighted.append(b)

	weighted.shuffle()
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for b in weighted:
		var id: String = str(b.get("id", ""))
		if seen.has(id):
			continue
		seen[id] = true
		result.append(b)
		if result.size() >= count:
			break
	while result.size() < count and weighted.size() > 0:
		result.append(weighted[result.size() % weighted.size()])
	return result

extends Node
## Boon catalogue (MW-018, approved 2026-09-24): 4 patrons × 12 boons. Every boon is a
## theme + verb that changes what a slot does; none is a flat stat. Behaviour lives in
## scripts/combat/boon_kit.gd, keyed by id. `slot` is attack/special/cast/dash (one boon
## per slot, a new one replaces the old) or "trigger" (event boons, no cap).

const SLOTS := ["attack", "special", "cast", "dash"]
const RARITY_WEIGHT := {"common": 60.0, "rare": 28.0, "epic": 10.0, "legendary": 2.0}
## Pseudo-boon offered when the aligned pool runs thin (Mike, MW-018 Q3).
const FALLBACK_HEAL := {
	"id": "fallback_heal",
	"patron": "",
	"name": "Field Dressing",
	"slot": "none",
	"verb": "heal",
	"rarity": "common",
	"desc": "No patron answers. Heal 35 HP.",
	"heal": 35.0,
	"is_fallback": true,
}

var boons: Array[Dictionary] = []
var _by_id: Dictionary = {}


func _ready() -> void:
	boons = []
	_add("dust_compact", [
		["dust_bleed", "Scrap Teeth", "attack", "bleed", "common",
			"Attacks apply 1 Bleed; heavy hits apply 2."],
		["dust_buckshot", "Buckshot Draw", "special", "bleed", "common",
			"Special also throws a 5-shard scrap cone; each shard applies 1 Bleed."],
		["dust_smoke", "Smoke Canister", "cast", "gunsmoke", "common",
			"Cast bursts into a gunsmoke cloud on arrival. Enemies inside are Blinded."],
		["dust_dash", "Gunsmoke Step", "dash", "dash", "common",
			"Dash leaves a smoke trail for 2 s. Enemies crossing it are Blinded."],
		["dust_reload", "Quick Chamber", "trigger", "reload", "common",
			"Ending a dash Chambers your next Attack (it hits twice)."],
		["dust_loot", "Rail Rat Eyes", "trigger", "loot", "common",
			"Elites drop a Scrap cache (1 Cast charge + 5 HP); generals drop 3."],
		["dust_sidestep", "Cinder Slip", "trigger", "dash", "common",
			"Taking a hit drops a smoke puff and refunds your dash (8 s cooldown)."],
		["dust_shrapnel", "Rust Bloom", "trigger", "bleed", "rare",
			"Enemies that die Bleeding burst into shrapnel: 2 Bleed to foes nearby."],
		["dust_cashin", "Cash In", "trigger", "bleed", "rare",
			"Special hits consume all Bleed on the target and deal it at once."],
		["dust_doublehold", "Double Hold", "trigger", "loot", "epic",
			"+1 Cast charge. Siblings who walk through your smoke are Chambered."],
		["dust_devil", "Dust Devil", "trigger", "dash", "epic",
			"Dashing through 3+ foes spins a dust devil that pulls, Blinds and Bleeds."],
		["dust_tally", "Dead Man's Tally", "trigger", "bleed", "legendary",
			"A foe at 5 Bleed ruptures for all its Bleed ×1.5 and Blinds everything near it.",
			{"all": ["dust_bleed"], "any": ["dust_smoke", "dust_dash"]}],
	])
	_add("red_petition", [
		["petition_execute", "Widow's Writ", "attack", "execute", "common",
			"Attacks execute enemies below 15% HP (elites 7.5%)."],
		["petition_sabotage", "Fuse Kiss", "special", "sabotage", "common",
			"Special hits attach a fuse: 1.5 s later it bursts for area damage and Stagger."],
		["petition_trap", "Iron Snare", "cast", "trap", "common",
			"Cast plants an iron snare (max 3). The first foe in is Rooted and takes Cast ×2."],
		["petition_caltrops", "Cell Runner", "dash", "trap", "common",
			"Dash scatters caltrops at your start point for 4 s: slows and ticks damage."],
		["petition_elite", "Anti-Banner", "trigger", "anti-elite", "common",
			"Every 4th hit on an elite strips its affix; with none left, Stagger 1 s."],
		["petition_team", "Shared Blood", "trigger", "team buff", "common",
			"Executes drop a blood ration. The first sibling to touch it heals 8."],
		["petition_rally", "Bread & Powder", "trigger", "team buff", "common",
			"Executing Chambers you and every ally within 200."],
		["petition_warrant", "Warrant", "trigger", "execute", "rare",
			"Cast hits Warrant the target for 8 s: execute threshold +10% for every player."],
		["petition_cell", "Cell Oath", "trigger", "rally", "rare",
			"Hurt below 30%: rally bell. You and allies near get 1 s i-frames and Chamber (20 s cd)."],
		["petition_chain", "Guillotine Hour", "trigger", "execute", "epic",
			"Each execute re-checks every foe within 120 against the threshold."],
		["petition_manifest", "Sabotage Manifest", "trigger", "sabotage", "epic",
			"Hitting a foe mid wind-up cancels the attack, Staggers it and deals Special ×3."],
		["petition_redletter", "Red Letter Day", "trigger", "execute", "legendary",
			"Generals become executable below 8%. Any sibling's Special performs the Writ.",
			{"all": ["petition_execute"], "any": ["petition_trap", "petition_caltrops"]}],
	])
	_add("house_veyra", [
		["veyra_crit", "Debt Edge", "attack", "crit", "common",
			"Attacks always crit foes facing away, Staggered, Rooted or Blinded."],
		["veyra_pointe", "Pointe of Courtesy", "special", "shadowstep", "common",
			"Special opens with a shadowstep to the nearest foe ahead; its first hit crits."],
		["veyra_contract", "Blood Contract", "cast", "debt", "common",
			"With no charges, cast anyway for 8 Debt. Debt-paid casts lifesteal 50%."],
		["veyra_shadowstep", "Ledger Step", "dash", "shadowstep", "common",
			"Dash becomes a shadowstep through foes and shots. The afterimage draws aggro 1 s."],
		["veyra_life", "Courtesy Sip", "trigger", "lifesteal", "common",
			"Feeding heals 20 and your next 3 hits lifesteal 30%."],
		["veyra_evolve", "Gilded Vein", "trigger", "evolve", "common",
			"Crits heal 1 HP. Evolves to 2 at 15 raid kills and 3 at 40."],
		["veyra_spray", "Exsanguinate", "trigger", "lifesteal", "common",
			"Crit kills spray blood: you and allies within 100 heal 3."],
		["veyra_collateral", "Promissory Mark", "trigger", "crit", "rare",
			"The first hit within 1 s of a dash crits and marks Collateral. Its death clears your Debt."],
		["veyra_poise", "Noble Poise", "trigger", "debt", "rare",
			"Once per room, lethal damage becomes Debt and leaves you at 1 HP."],
		["veyra_couture", "Sanguine Couture", "trigger", "shadowstep", "epic",
			"A Special kill makes your next dash leave 2 afterimages that each Attack once."],
		["veyra_duel", "Duel of Houses", "trigger", "crit", "epic",
			"First elite/general hit each room becomes your Duelist: always crit it; after a crit, others' contact misses you 3 s."],
		["veyra_collects", "The House Always Collects", "trigger", "debt", "legendary",
			"Debt no longer drains. At 30 it is called in: a nova for 3× Debt, then Debt clears.",
			{"all": ["veyra_crit"], "any": ["veyra_contract", "veyra_poise"]}],
	])
	_add("church", [
		["church_smite", "Pale Decree", "attack", "smite", "common",
			"Every 3rd Attack calls a Smite on the target point."],
		["church_judgment", "Judgment Flare", "special", "decree", "common",
			"Special hits Condemn (Smites deal ×2 and spread Condemn)."],
		["church_ward", "Sunlit Ward", "cast", "ward", "common",
			"Cast raises a hymn circle on arrival. You and allies inside gain 1 Ward."],
		["church_procession", "Pale Procession", "dash", "aura", "common",
			"Dash ends in a sanctified ring that pushes foes out and damages them."],
		["church_cleanse", "Salt Cleanse", "trigger", "cleanse", "common",
			"Dashing cleanses you and destroys enemy shots along the path."],
		["church_cooldown", "Bell Interval", "trigger", "cooldown", "common",
			"Each Cast hit takes 1 s off your Special cooldown."],
		["church_vow", "Vow of Abstinence", "trigger", "ward", "common",
			"While you haven't fed this raid, start each room with 2 Ward."],
		["church_litany", "Litany", "trigger", "aura", "rare",
			"After you cast, a hymn aura pulses around you 3 times, damaging and slowing."],
		["church_anathema", "Anathema", "trigger", "decree", "rare",
			"Condemned foes leave consecrated ground: foes on it slow, allies on it cleanse."],
		["church_choir", "Choir of Wards", "trigger", "smite", "epic",
			"Each Ward that breaks calls an instant Smite on whoever broke it."],
		["church_sunwheel", "Sunwheel", "trigger", "cooldown", "epic",
			"Smite kills refund 1 Cast charge. The 5th Smite kill in 6 s resets Special and Dash."],
		["church_fatherslight", "The Father's Light", "trigger", "smite", "legendary",
			"While you keep attacking, a Smite falls every 4 s on the highest-HP foe. Generals you hit stay Condemned.",
			{"all": ["church_smite"], "any": ["church_ward", "church_vow"]}],
	])
	_by_id.clear()
	for b in boons:
		_by_id[str(b["id"])] = b


func _add(patron: String, rows: Array) -> void:
	for r in rows:
		var b := {
			"id": str(r[0]),
			"patron": patron,
			"name": str(r[1]),
			"slot": str(r[2]),
			"verb": str(r[3]),
			"rarity": str(r[4]),
			"desc": str(r[5]),
		}
		if r.size() > 6:
			b["requires"] = r[6]
		boons.append(b)


func get_boon(id: String) -> Dictionary:
	return _by_id.get(id, {})


func requirements_met(boon: Dictionary) -> bool:
	var req: Dictionary = boon.get("requires", {})
	if req.is_empty():
		return true
	for id in req.get("all", []):
		if not RunState.has_boon(str(id)):
			return false
	var any: Array = req.get("any", [])
	if any.is_empty():
		return true
	for id in any:
		if RunState.has_boon(str(id)):
			return true
	return false


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


## Offer weight from rarity. Rare/Epic rise with burst index; Legendary 2 → 6.
func _rarity_weight(rarity: String) -> float:
	var depth := float(RunState.dungeon_index) if RunState else 0.0
	match rarity:
		"rare":
			return 28.0 + 3.0 * depth
		"epic":
			return 10.0 + 2.0 * depth
		"legendary":
			return minf(2.0 + depth, 6.0)
	return float(RARITY_WEIGHT.get(rarity, 60.0))


## Boons that can be offered now: unblocked, unowned, prerequisites met.
func available_pool() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in boons:
		if str(b.get("patron", "")) in RunState.blocked_patrons:
			continue
		if RunState.has_boon(str(b["id"])):
			continue
		if not requirements_met(b):
			continue
		out.append(b)
	return out


func get_choices(count: int = 3) -> Array[Dictionary]:
	var pool := available_pool()
	var result: Array[Dictionary] = []
	## Thin aligned pool: one slot falls back to a heal so the pick is never dead.
	var boon_slots := count
	if pool.size() < count * 2 and RunState.aligned_patron != "":
		boon_slots = count - 1
	var weights: Array[float] = []
	for b in pool:
		weights.append(_patron_weight(str(b["patron"])) * _rarity_weight(str(b["rarity"])))
	while result.size() < boon_slots and not pool.is_empty():
		var total := 0.0
		for w in weights:
			total += w
		var i := 0
		if total > 0.0:
			var roll := randf() * total
			while i < weights.size() - 1 and roll > weights[i]:
				roll -= weights[i]
				i += 1
		else:
			i = randi() % pool.size()
		result.append(pool[i])
		pool.remove_at(i)
		weights.remove_at(i)
	while result.size() < count:
		result.append(FALLBACK_HEAL.duplicate())
	return result

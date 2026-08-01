extends Node
## Persistent meta progression between moons.

signal currencies_changed
signal unlocks_changed
signal ashwick_changed
signal ng_changed

var blood: int = 0
var ash: int = 0
var tech: int = 0

var unlocked_characters: Array[String] = ["severin"]
var unlocked_alts: Array[String] = [] ## alt kit ids
var unlocked_skins: Array[String] = []
var meta_ranks: Dictionary = {} ## upgrade_id -> rank

var kin_met: bool = false
var mayor_met: bool = false
var church_met: bool = false
var petition_met: bool = false
var veyra_met: bool = false
var moons_survived: int = 0

## Story difficulty for next raid: dust | blood | eclipse
var selected_difficulty: String = "dust"
## Party: list of {character_id, alt_id, device} — device -1 = keyboard
var party: Array[Dictionary] = [{"character_id": "severin", "alt_id": "", "device": -1}]
var selected_sector: String = "dust_meridian"

var ng_plus: int = 0
var aurelian_defeated: bool = false
var sectors_cleared: Dictionary = {} ## sector_id -> clear count
var heat_modifiers: Array[String] = [] ## active NG+ heats

## Ashwick rebuild unlocks from ash branch
var hub_flags: Dictionary = {
	"vendor_dust": true,
	"vendor_church": false,
	"vendor_petition": false,
	"vendor_veyra": false,
	"mission_board": false,
	"rite_chamber": true,
	"tech_bench": false,
}

const SAVE_PATH := "user://moonwake_save.json"

const DIFFICULTY_MULT := {
	"dust": 1.0,
	"blood": 1.35,
	"eclipse": 1.75,
}


func _ready() -> void:
	load_game()
	if "severin" not in unlocked_characters:
		unlocked_characters.append("severin")


func difficulty_enemy_mult() -> float:
	var m := float(DIFFICULTY_MULT.get(selected_difficulty, 1.0))
	m *= 1.0 + 0.2 * float(ng_plus)
	for h in heat_modifiers:
		if h == "swarm":
			m *= 1.1
		elif h == "iron":
			m *= 1.15
		elif h == "pale":
			m *= 1.25
	return m


func difficulty_label() -> String:
	match selected_difficulty:
		"blood":
			return "Blood"
		"eclipse":
			return "Eclipse"
		_:
			return "Dust"


func add_currency(kind: String, amount: int) -> void:
	if amount == 0:
		return
	match kind:
		"blood":
			blood += amount
		"ash":
			ash += amount
		"tech":
			tech += amount
	currencies_changed.emit()
	save_game()


func can_spend_cost(cost: Dictionary) -> bool:
	return blood >= int(cost.get("blood", 0)) \
		and ash >= int(cost.get("ash", 0)) \
		and tech >= int(cost.get("tech", 0))


func spend_cost(cost: Dictionary) -> bool:
	if not can_spend_cost(cost):
		return false
	blood -= int(cost.get("blood", 0))
	ash -= int(cost.get("ash", 0))
	tech -= int(cost.get("tech", 0))
	currencies_changed.emit()
	save_game()
	return true


func can_spend(kind: String, amount: int) -> bool:
	match kind:
		"blood":
			return blood >= amount
		"ash":
			return ash >= amount
		"tech":
			return tech >= amount
	return false


func spend(kind: String, amount: int) -> bool:
	var cost := {"blood": 0, "ash": 0, "tech": 0}
	cost[kind] = amount
	return spend_cost(cost)


func unlock_character(id: String) -> bool:
	if id in unlocked_characters:
		return true
	var c: Dictionary = CharacterDB.get_character(id)
	if c.is_empty():
		return false
	if not spend_cost(c.get("unlock_cost", {})):
		return false
	unlocked_characters.append(id)
	unlocks_changed.emit()
	save_game()
	return true


func unlock_alt(alt_id: String, cost: Dictionary) -> bool:
	if alt_id in unlocked_alts:
		return true
	if not spend_cost(cost):
		return false
	unlocked_alts.append(alt_id)
	unlocks_changed.emit()
	save_game()
	return true


func meta_rank(id: String) -> int:
	return int(meta_ranks.get(id, 0))


func buy_meta(id: String) -> bool:
	var up: Dictionary = MetaDB.get_upgrade(id) if MetaDB.has_method("get_upgrade") else {}
	if up.is_empty():
		return false
	var rank := meta_rank(id)
	var max_rank := int(up.get("max_rank", 1))
	if rank >= max_rank:
		return false
	var cost: Dictionary = up.get("cost", {})
	## Scale cost lightly per rank
	var scaled := {
		"blood": int(cost.get("blood", 0)) * (rank + 1),
		"ash": int(cost.get("ash", 0)) * (rank + 1),
		"tech": int(cost.get("tech", 0)) * (rank + 1),
	}
	if not spend_cost(scaled):
		return false
	meta_ranks[id] = rank + 1
	_apply_hub_flags_from_meta()
	unlocks_changed.emit()
	ashwick_changed.emit()
	save_game()
	return true


func _apply_hub_flags_from_meta() -> void:
	for id in meta_ranks.keys():
		var up: Dictionary = MetaDB.get_upgrade(str(id)) if MetaDB.has_method("get_upgrade") else {}
		var effects: Dictionary = up.get("effects", {})
		for k in effects.keys():
			if str(k).begins_with("ashwick_") or str(k).begins_with("vendor_") or str(k).begins_with("mission_") or str(k) in hub_flags:
				hub_flags[str(k).replace("ashwick_", "")] = true
				if str(k).begins_with("vendor_"):
					hub_flags[str(k)] = true
				if str(k).begins_with("mission_"):
					hub_flags["mission_board"] = true
					hub_flags[str(k)] = true


func mark_moon() -> void:
	moons_survived += 1
	save_game()


func mark_sector_clear(sector_id: String) -> void:
	sectors_cleared[sector_id] = int(sectors_cleared.get(sector_id, 0)) + 1
	if sector_id == "pale_spire":
		aurelian_defeated = true
		ng_plus += 1
		_roll_new_heats()
		ng_changed.emit()
	## Unlock next characters cheaply on first clears
	_check_story_unlocks(sector_id)
	save_game()


func _roll_new_heats() -> void:
	var pool := ["swarm", "iron", "pale", "silence", "debt"]
	pool.shuffle()
	heat_modifiers.clear()
	var n := mini(ng_plus, 3)
	for i in n:
		heat_modifiers.append(pool[i])


func _check_story_unlocks(sector_id: String) -> void:
	## Progressive unlocks without forcing shop
	var map := {
		"dust_meridian": "mira",
		"cinder_barrens": "cassian",
		"gloampine": "odette",
		"salt_choir": "vesper",
	}
	if map.has(sector_id):
		var cid: String = map[sector_id]
		if cid not in unlocked_characters:
			unlocked_characters.append(cid)
			unlocks_changed.emit()


func set_party_solo(character_id: String, alt_id: String = "") -> void:
	party = [{"character_id": character_id, "alt_id": alt_id, "device": -1}]


func party_size() -> int:
	return maxi(party.size(), 1)


func save_game() -> void:
	var data := {
		"blood": blood,
		"ash": ash,
		"tech": tech,
		"unlocked_characters": unlocked_characters,
		"unlocked_alts": unlocked_alts,
		"unlocked_skins": unlocked_skins,
		"meta_ranks": meta_ranks,
		"kin_met": kin_met,
		"mayor_met": mayor_met,
		"church_met": church_met,
		"petition_met": petition_met,
		"veyra_met": veyra_met,
		"moons_survived": moons_survived,
		"selected_difficulty": selected_difficulty,
		"ng_plus": ng_plus,
		"aurelian_defeated": aurelian_defeated,
		"sectors_cleared": sectors_cleared,
		"heat_modifiers": heat_modifiers,
		"hub_flags": hub_flags,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	blood = int(data.get("blood", 0))
	ash = int(data.get("ash", 0))
	tech = int(data.get("tech", 0))
	unlocked_characters.clear()
	for c in data.get("unlocked_characters", ["severin"]):
		unlocked_characters.append(str(c))
	unlocked_alts.clear()
	for a in data.get("unlocked_alts", []):
		unlocked_alts.append(str(a))
	unlocked_skins.clear()
	for s in data.get("unlocked_skins", []):
		unlocked_skins.append(str(s))
	meta_ranks = data.get("meta_ranks", {})
	kin_met = bool(data.get("kin_met", false))
	mayor_met = bool(data.get("mayor_met", false))
	church_met = bool(data.get("church_met", false))
	petition_met = bool(data.get("petition_met", false))
	veyra_met = bool(data.get("veyra_met", false))
	moons_survived = int(data.get("moons_survived", 0))
	selected_difficulty = str(data.get("selected_difficulty", "dust"))
	ng_plus = int(data.get("ng_plus", 0))
	aurelian_defeated = bool(data.get("aurelian_defeated", false))
	sectors_cleared = data.get("sectors_cleared", {})
	heat_modifiers.clear()
	for h in data.get("heat_modifiers", []):
		heat_modifiers.append(str(h))
	var flags = data.get("hub_flags", {})
	if typeof(flags) == TYPE_DICTIONARY:
		for k in flags.keys():
			hub_flags[str(k)] = flags[k]
	_apply_hub_flags_from_meta()

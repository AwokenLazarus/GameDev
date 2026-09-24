extends Node
## Character definitions, kits, and unlock queries for Moonwake.

## Per-kit slot blocks: attack / special / cast / dash. Every slot is a player input;
## nothing here fires on its own (anti-pillar: not AFK auto-survivor). Numbers are
## multipliers on the sibling's base damage and seconds. Boons (MW-006) read these
## blocks and hook Player.slot_used / Player.slot_hit / Player.slot_mods by slot name.
const KIT_SLOTS := {
	"melee": {
		"attack": {"name": "Moon-edge Combo", "desc": "Three draws; the third is a wide finisher that knocks back.",
			"combo_damage": [1.0, 1.0, 1.7], "combo_cooldown": [0.6, 0.65, 1.3],
			"combo_radius": [58.0, 58.0, 74.0], "combo_arc": [1.1, 1.1, 1.6], "combo_window": 0.6},
		"special": {"name": "Lunging Cleave", "desc": "Lunge forward and cleave everything in a wide arc.",
			"damage": 2.0, "cooldown": 2.6, "lunge": 150.0, "radius": 82.0, "arc": 2.2},
		"cast": {"name": "Blood Stake", "desc": "Throw a stake that marks its target; marked foes take more from every hunter.",
			"damage": 0.8, "charges": 2, "recharge": 3.5, "speed": 640.0, "mark_time": 4.0, "mark_bonus": 0.3},
		"dash": {"name": "Dodge"},
	},
	"hybrid_gun": {
		"attack": {"name": "Rail Shot", "desc": "Aimed piercing rail shot. Mouse / right stick aims.",
			"damage": 1.8, "cooldown": 1.0, "speed": 780.0, "pierce": 1},
		"special": {"name": "Silverstorm Volley", "desc": "Unload a rain of seeking bolts.",
			"damage": 0.6, "cooldown": 3.2, "bolts": 8, "interval": 0.045},
		"cast": {"name": "Silver Flare", "desc": "Lob a flare that bursts after a short fuse.",
			"damage": 2.4, "charges": 2, "recharge": 4.0, "range": 190.0, "radius": 72.0, "fuse": 0.55},
		"dash": {"name": "Dodge"},
	},
	"orbit": {
		"attack": {"name": "Crescent Throw", "desc": "Throw a crescent out and catch it on the return; hits both ways.",
			"damage": 1.2, "cooldown": 1.0, "range": 200.0, "speed": 560.0},
		"special": {"name": "Recall Burst", "desc": "Snap both crescents home and spin them out in a ring.",
			"damage": 1.3, "cooldown": 3.0, "radius": 120.0, "time": 0.4},
		"cast": {"name": "Court Sigil", "desc": "Plant a spinning sigil that cuts whatever stands in it.",
			"damage": 0.35, "charges": 1, "recharge": 6.0, "range": 150.0, "radius": 56.0, "life": 2.5, "interval": 0.25},
		"dash": {"name": "Dodge"},
	},
	"maul": {
		"attack": {"name": "Sepulcher Slam", "desc": "Heavy frontal slam that staggers.",
			"damage": 1.35, "cooldown": 1.0, "radius": 84.0, "arc": 1.8, "windup": 0.18},
		"special": {"name": "Shockwave", "desc": "Drive a travelling line of ground blasts forward.",
			"damage": 1.0, "cooldown": 3.0, "steps": 4, "spacing": 58.0, "radius": 46.0, "interval": 0.09},
		"cast": {"name": "Grave Hook", "desc": "Throw a chain hook that drags its target to you.",
			"damage": 0.6, "charges": 2, "recharge": 4.0, "speed": 560.0, "pull": 520.0},
		"dash": {"name": "Dodge"},
	},
	"astral": {
		"attack": {"name": "Spirit Spike", "desc": "Command the spirit to fire a piercing spike at the nearest foe.",
			"damage": 1.0, "cooldown": 1.0, "speed": 560.0, "pierce": 2, "seek_range": 280.0, "leash": 80.0},
		"special": {"name": "Collapse", "desc": "Detonate the spirit where it stands; it reforms at your side.",
			"damage": 1.6, "cooldown": 3.0, "radius": 100.0},
		"cast": {"name": "Projection", "desc": "Hurl the spirit forward through foes; it anchors there for a moment.",
			"damage": 0.8, "charges": 2, "recharge": 4.0, "range": 230.0, "radius": 30.0, "time": 0.22, "anchor": 3.0},
		"dash": {"name": "Dodge (body)"},
	},
}
const SLOT_NAMES := ["attack", "special", "cast", "dash"]

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
		"description": "Wrist-rail silverstorm. Aimed rail shots, a seeking volley on command. Rail-town preacher's daughter.",
		"color": Color(0.85, 0.82, 0.55, 1.0),
		"kit_type": "hybrid_gun",
		"base_hp": 90.0,
		"move_speed": 235.0,
		"attack_cooldown": 0.28,
		"damage": 8.0,
		"special_notes": "Aimed rail shots; the seeking volley is a special you call, not a passive.",
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
				"slot_overrides": {"attack": {"pierce": 3, "damage": 2.1}, "special": {"bolts": 6}},
			},
		},
	])

	_register_character({
		"id": "cassian",
		"name": "Cassian",
		"unlocked_by_default": false,
		"unlock_cost": {"blood": 35, "ash": 25, "tech": 40},
		"description": "Twin crescents thrown and recalled on command. Positioning-first court exile.",
		"color": Color(0.55, 0.70, 0.78, 1.0),
		"kit_type": "orbit",
		"base_hp": 95.0,
		"move_speed": 225.0,
		"attack_cooldown": 0.55,
		"damage": 10.0,
		"special_notes": "Throw crescents out and back; recall snaps them home in a cutting ring.",
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
				"slot_overrides": {"special": {"radius": 150.0}, "cast": {"radius": 70.0}},
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
				"slot_overrides": {"attack": {"radius": 70.0}, "special": {"steps": 3, "radius": 38.0}},
			},
		},
	])

	_register_character({
		"id": "vesper",
		"name": "Vesper",
		"unlocked_by_default": false,
		"unlock_cost": {"blood": 80, "ash": 40, "tech": 60},
		"description": "Soulspike astral projection. The spirit strikes only when commanded; body is the weak point. Glass cannon unlock.",
		"color": Color(0.62, 0.48, 0.85, 1.0),
		"kit_type": "astral",
		"base_hp": 70.0,
		"move_speed": 210.0,
		"attack_cooldown": 0.35,
		"damage": 16.0,
		"special_notes": "Spirit spikes on command; collapse detonates it for burst. Body takes extra damage.",
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
				"slot_overrides": {"attack": {"leash": 50.0}, "cast": {"range": 160.0}},
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


## Resolved slot blocks for a sibling + alt: the kit's defaults, then the character's
## own `slot_overrides` (only when the alt keeps the native kit), then the alt's.
func get_slots(id: String, alt_id: String = "") -> Dictionary:
	var data: Dictionary = _characters.get(id, {})
	var kit := str(data.get("kit_type", "melee"))
	var alt: Dictionary = {}
	if alt_id != "":
		for a in _alts.get(id, []):
			if str(a.get("id", "")) == alt_id:
				alt = a.get("kit_modifiers", {})
				break
	var native := true
	if alt.has("kit_type"):
		native = str(alt["kit_type"]) == kit
		kit = str(alt["kit_type"])
	var out: Dictionary = (KIT_SLOTS.get(kit, KIT_SLOTS["melee"]) as Dictionary).duplicate(true)
	if native:
		_merge_slots(out, data.get("slot_overrides", {}))
	_merge_slots(out, alt.get("slot_overrides", {}))
	return out


func _merge_slots(into: Dictionary, overrides: Dictionary) -> void:
	for slot in overrides.keys():
		if into.has(slot):
			(into[slot] as Dictionary).merge(overrides[slot], true)


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

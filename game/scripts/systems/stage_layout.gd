extends RefCounted
class_name StageLayout
## Burst room templates (Hades-like) and wild-map extents (RoR2-like).
## Greed contents live in GreedShrine / SectorController (MW-025).

const BURST_CAM_ZOOM := 0.82
const WILD_CAM_ZOOM := 1.2
const WILD_HALF := Vector2(2200, 1400)
const WILD_HALF_NIGHTMARE := Vector2(2400, 1600)

## Wild shrine hook i gets SHRINE_KINDS[i] (MW-025 greed).
const SHRINE_KINDS: PackedStringArray = ["moon_altar", "blood_well"]

const ROOM_ORDER: PackedStringArray = ["chamber", "long_hall", "crossroads", "gauntlet", "chapel"]


static func wild_half(nightmare: bool) -> Vector2:
	return WILD_HALF_NIGHTMARE if nightmare else WILD_HALF


static func room_id_for_index(index: int) -> String:
	if ROOM_ORDER.is_empty():
		return "chamber"
	return ROOM_ORDER[index % ROOM_ORDER.size()]


static func room(id: String) -> Dictionary:
	match id:
		"long_hall":
			return {
				"id": "long_hall",
				"half": Vector2(560, 240),
				"entry": Vector2(-420, 0),
				"inner_walls": [
					{"pos": Vector2(-80, -140), "size": Vector2(160, 36)},
					{"pos": Vector2(80, 140), "size": Vector2(160, 36)},
				],
				"spawn_points": [
					Vector2(480, -150), Vector2(480, 150),
					Vector2(0, -180), Vector2(0, 180),
					Vector2(-480, -150), Vector2(-480, 150),
				],
				"doors": [
					{"pos": Vector2(500, -70), "label": "Pact", "reward": "boon", "next": "crossroads"},
					{"pos": Vector2(500, 70), "label": "Cache", "reward": "gear", "next": "gauntlet"},
				],
			}
		"crossroads":
			return {
				"id": "crossroads",
				"half": Vector2(400, 400),
				"entry": Vector2(0, 280),
				"inner_walls": [
					{"pos": Vector2(0, 0), "size": Vector2(70, 70)},
				],
				"spawn_points": [
					Vector2(-320, -320), Vector2(320, -320),
					Vector2(-320, 320), Vector2(320, 320),
					Vector2(0, -340), Vector2(0, 340),
				],
				"doors": [
					{"pos": Vector2(-80, -360), "label": "Pact", "reward": "boon", "next": "chapel"},
					{"pos": Vector2(80, -360), "label": "Cache", "reward": "gear", "next": "chamber"},
				],
			}
		"gauntlet":
			return {
				"id": "gauntlet",
				"half": Vector2(520, 280),
				"entry": Vector2(0, 200),
				"inner_walls": [
					{"pos": Vector2(-180, -40), "size": Vector2(36, 180)},
					{"pos": Vector2(180, 40), "size": Vector2(36, 180)},
				],
				"spawn_points": [
					Vector2(-450, -200), Vector2(450, -200),
					Vector2(-450, 200), Vector2(450, 200),
					Vector2(0, -220),
				],
				"doors": [
					{"pos": Vector2(-80, -240), "label": "Pact", "reward": "boon", "next": "long_hall"},
					{"pos": Vector2(80, -240), "label": "Cache", "reward": "gear", "next": "crossroads"},
				],
			}
		"chapel":
			return {
				"id": "chapel",
				"half": Vector2(420, 340),
				"entry": Vector2(0, 250),
				"inner_walls": [
					{"pos": Vector2(-220, -180), "size": Vector2(80, 40)},
					{"pos": Vector2(220, -180), "size": Vector2(80, 40)},
				],
				"spawn_points": [
					Vector2(-350, -250), Vector2(350, -250),
					Vector2(-350, 250), Vector2(350, 250),
					Vector2(0, -280),
				],
				"doors": [
					{"pos": Vector2(-90, -300), "label": "Pact", "reward": "boon", "next": "chamber"},
					{"pos": Vector2(90, -300), "label": "Cache", "reward": "gear", "next": "long_hall"},
				],
			}
		_:
			return {
				"id": "chamber",
				"half": Vector2(480, 320),
				"entry": Vector2(0, 180),
				"inner_walls": [],
				"spawn_points": [
					Vector2(-400, -250), Vector2(400, -250),
					Vector2(-400, 250), Vector2(400, 250),
					Vector2(0, -260), Vector2(0, 260),
				],
				"doors": [
					{"pos": Vector2(400, -90), "label": "Pact", "reward": "boon", "next": "long_hall"},
					{"pos": Vector2(400, 90), "label": "Cache", "reward": "gear", "next": "crossroads"},
				],
			}


static func last_burst_doors(half: Vector2) -> Array:
	## Both exits enter the wild; choice is approach, not a skip.
	return [
		{"pos": Vector2(half.x - 80.0, -70.0), "label": "Open flats", "reward": "wild_camp", "next": "wild"},
		{"pos": Vector2(half.x - 80.0, 70.0), "label": "Ridge path", "reward": "wild_ridge", "next": "wild"},
	]


static func wild_landmarks(sector_id: String, half: Vector2) -> Array:
	## Named props + greed hook points. Contents (chests/shrines) are later work.
	var hx := half.x * 0.72
	var hy := half.y * 0.68
	var props: Array = []
	match sector_id:
		"cinder_barrens":
			props = [
				{"kind": "ruin", "pos": Vector2(-hx * 0.6, -hy * 0.4), "scale": 1.4, "name": "Furnace pile"},
				{"kind": "ruin", "pos": Vector2(hx * 0.55, hy * 0.2), "scale": 1.2, "name": "Slag ridge"},
				{"kind": "crate", "pos": Vector2(0, hy * 0.55), "scale": 1.3, "name": "Ash crates"},
				{"kind": "rail", "pos": Vector2(hx * 0.15, -hy * 0.15), "scale": 2.4, "name": "Cinder rail"},
			]
		"gloampine":
			props = [
				{"kind": "ruin", "pos": Vector2(-hx * 0.7, -hy * 0.5), "scale": 0.9, "name": "Fog redwood"},
				{"kind": "ruin", "pos": Vector2(-hx * 0.2, hy * 0.1), "scale": 1.0, "name": "Hollow trunk"},
				{"kind": "ruin", "pos": Vector2(hx * 0.5, -hy * 0.25), "scale": 0.85, "name": "Canopy ruin"},
				{"kind": "ruin", "pos": Vector2(hx * 0.15, hy * 0.6), "scale": 1.1, "name": "Moss nave"},
			]
		"salt_choir":
			props = [
				{"kind": "chapel", "pos": Vector2(0, -hy * 0.55), "scale": 1.2, "name": "Salt chapel"},
				{"kind": "ruin", "pos": Vector2(-hx * 0.55, hy * 0.2), "scale": 1.0, "name": "Choir wreck"},
				{"kind": "ruin", "pos": Vector2(hx * 0.5, hy * 0.35), "scale": 0.9, "name": "Hymn stones"},
			]
		"iron_orchard":
			props = [
				{"kind": "crate", "pos": Vector2(-hx * 0.5, -hy * 0.2), "scale": 1.4, "name": "Grain silos"},
				{"kind": "crate", "pos": Vector2(hx * 0.45, hy * 0.15), "scale": 1.2, "name": "Quota stacks"},
				{"kind": "rail", "pos": Vector2(0, hy * 0.5), "scale": 2.6, "name": "Orchard rail"},
			]
		"noir_cathedral":
			props = [
				{"kind": "chapel", "pos": Vector2(-hx * 0.15, -hy * 0.6), "scale": 1.5, "name": "Noir nave"},
				{"kind": "ruin", "pos": Vector2(hx * 0.55, 0), "scale": 1.2, "name": "Court wreck"},
				{"kind": "ruin", "pos": Vector2(-hx * 0.55, hy * 0.35), "scale": 1.0, "name": "Shade block"},
			]
		"umbral_marches":
			props = [
				{"kind": "rail", "pos": Vector2(-hx * 0.2, -hy * 0.1), "scale": 2.2, "name": "March rail"},
				{"kind": "crate", "pos": Vector2(hx * 0.5, -hy * 0.4), "scale": 1.1, "name": "Border cache"},
				{"kind": "ruin", "pos": Vector2(-hx * 0.55, hy * 0.45), "scale": 1.1, "name": "Watch ruin"},
			]
		"pale_spire":
			props = [
				{"kind": "chapel", "pos": Vector2(0, -hy * 0.65), "scale": 1.7, "name": "Pale chapel"},
				{"kind": "ruin", "pos": Vector2(-hx * 0.6, hy * 0.2), "scale": 1.3, "name": "Spire wreck L"},
				{"kind": "ruin", "pos": Vector2(hx * 0.6, hy * 0.15), "scale": 1.3, "name": "Spire wreck R"},
			]
		_:
			props = [
				{"kind": "rail", "pos": Vector2(-hx * 0.35, hy * 0.25), "scale": 2.2, "name": "Dust rail"},
				{"kind": "rail", "pos": Vector2(hx * 0.4, -hy * 0.2), "scale": 1.8, "name": "Spur line"},
				{"kind": "ruin", "pos": Vector2(-hx * 0.65, -hy * 0.45), "scale": 1.15, "name": "Gallows ruin"},
				{"kind": "crate", "pos": Vector2(hx * 0.55, hy * 0.4), "scale": 1.05, "name": "Depot crates"},
				{"kind": "crate", "pos": Vector2(-hx * 0.1, -hy * 0.55), "scale": 0.95, "name": "Waystation"},
			]
	props.append({"kind": "ruin", "pos": Vector2(0, 0), "scale": 0.7, "name": "Camp"})
	return props


static func greed_hooks(half: Vector2) -> Dictionary:
	## Chests (Blood/Ash/Tech or gear) + shrines (SHRINE_KINDS); SectorController fills them.
	return {
		"chest": [
			Vector2(-half.x * 0.55, -half.y * 0.35),
			Vector2(half.x * 0.6, half.y * 0.25),
			Vector2(half.x * 0.1, -half.y * 0.6),
		],
		"shrine": [
			Vector2(-half.x * 0.25, half.y * 0.5),
			Vector2(half.x * 0.45, -half.y * 0.15),
		],
	}


static func wild_start(reward: String, half: Vector2) -> Vector2:
	match reward:
		"wild_ridge":
			return Vector2(half.x * 0.35, -half.y * 0.4)
		_:
			return Vector2(0, half.y * 0.15)

class_name MWPalette
extends RefCounted
## UI colours: bone on ink, dried crimson, a little gilt. One hue per patron.

const BONE := Color(0.9, 0.84, 0.76)
const ASH := Color(0.62, 0.57, 0.54)
const INK := Color(0.045, 0.035, 0.05)
const BLOOD := Color(0.62, 0.08, 0.12)
const BLOOD_BRIGHT := Color(0.9, 0.16, 0.2)
const GILT := Color(0.88, 0.72, 0.44)
const PATRON := {
	"dust_compact": Color(0.88, 0.66, 0.34),
	"red_petition": Color(0.93, 0.33, 0.18),
	"house_veyra": Color(0.86, 0.32, 0.46),
	"church": Color(0.9, 0.93, 0.86),
}
const RARITY := {
	"common": Color(0.72, 0.68, 0.62),
	"rare": Color(0.45, 0.66, 0.9),
	"epic": Color(0.8, 0.5, 0.9),
	"legendary": Color(1.0, 0.8, 0.36),
}


static func patron(id: String) -> Color:
	return PATRON.get(id, ASH)


static func rarity(id: String) -> Color:
	return RARITY.get(id, ASH)

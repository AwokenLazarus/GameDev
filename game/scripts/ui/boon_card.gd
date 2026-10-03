class_name BoonCard
extends Button
## One offered boon: patron sigil, name, slot and verb, what it does, what it costs.

const SLOT_WORD := {
	"attack": "ATTACK", "special": "SPECIAL", "cast": "CAST", "dash": "DASH", "trigger": "OATH"
}

@onready var frame: Panel = $Frame
@onready var wash: ColorRect = $Frame/Wash
@onready var sigil: PatronSigil = $Frame/Body/Sigil
@onready var patron_label: Label = $Frame/Body/Patron
@onready var rule: TextureRect = $Frame/Body/Rule
@onready var name_label: Label = $Frame/Body/Name
@onready var verb_label: Label = $Frame/Body/Verb
@onready var desc_label: Label = $Frame/Body/Desc
@onready var note_label: Label = $Frame/Body/Note
@onready var rarity_label: Label = $Frame/Body/Foot/Rarity
@onready var key_label: Label = $Frame/Body/Foot/Key

var boon: Dictionary = {}
var _tint := MWPalette.ASH
var _box: StyleBoxFlat
var _lift: Tween


func _ready() -> void:
	_box = (frame.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	frame.add_theme_stylebox_override("panel", _box)
	mouse_entered.connect(grab_focus)
	focus_entered.connect(_glow.bind(true))
	focus_exited.connect(_glow.bind(false))


## `replaces` is the name of the boon this one would push out of its slot ("" if none);
## `forsakes` the rival patrons taking it would block.
func show_boon(data: Dictionary, index: int, replaces: String, forsakes: PackedStringArray) -> void:
	boon = data
	var patron: String = data.get("patron", "")
	var rarity: String = data.get("rarity", "common")
	var slot: String = data.get("slot", "trigger")
	_tint = MWPalette.patron(patron)
	sigil.patron = patron
	sigil.tint = _tint
	wash.color = _tint
	rule.modulate = _tint
	patron_label.text = RunState.patron_display(patron).to_upper() if patron != "" else "NO PATRON"
	patron_label.add_theme_color_override("font_color", _tint)
	name_label.text = str(data.get("name", ""))
	var verb := str(data.get("verb", "")).to_upper()
	verb_label.text = "%s  ·  %s" % [SLOT_WORD.get(slot, "BOON"), verb] if slot != "none" else verb
	desc_label.text = str(data.get("desc", ""))
	var notes: PackedStringArray = []
	if replaces != "":
		notes.append("Replaces %s" % replaces)
	if not forsakes.is_empty():
		notes.append("Forsakes %s" % " and ".join(forsakes))
	note_label.text = "\n".join(notes)
	note_label.visible = not notes.is_empty()
	rarity_label.text = rarity.to_upper()
	rarity_label.add_theme_color_override("font_color", MWPalette.rarity(rarity))
	key_label.text = "[ %d ]" % (index + 1)
	_glow(false)


func _glow(on: bool) -> void:
	_box.border_color = Color(_tint, 0.95) if on else Color(MWPalette.BONE, 0.22)
	_box.bg_color = Color(0.085, 0.06, 0.075, 0.97) if on else Color(0.05, 0.04, 0.055, 0.94)
	wash.modulate.a = 1.0 if on else 0.45
	if _lift:
		_lift.kill()
	_lift = create_tween()
	_lift.tween_property(frame, "position:y", -10.0 if on else 0.0, 0.12)

extends CanvasLayer
## Boon choice (MW-029): three cards, one per offer, each led by its patron's sigil.
## Pauses the run. Mouse, 1/2/3, or focus + accept on any device picks.

signal chosen(boon: Dictionary)

const CARD := preload("res://scenes/ui/boon_card.tscn")
const PICK_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]

var _choices: Array[Dictionary] = []

@onready var dim: ColorRect = $Dim
@onready var title: Label = $Center/VBox/Title
@onready var subtitle: Label = $Center/VBox/Subtitle
@onready var cards: HBoxContainer = $Center/VBox/Cards
@onready var body: VBoxContainer = $Center/VBox


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("boon_select")


func open_choices() -> void:
	_choices = BoonDB.get_choices(3)
	for c: Node in cards.get_children():
		c.queue_free()
	var left := maxi(0, RunState.boon_picks_target - RunState.boon_picks_done)
	title.text = "A PATRON ANSWERS" if RunState.aligned_patron == "" else "YOUR PATRON ANSWERS"
	subtitle.text = "Take one.  %d more this hunt." % left if left > 0 else "Take one."
	for i: int in _choices.size():
		var boon := _choices[i]
		var card: BoonCard = CARD.instantiate()
		cards.add_child(card)
		card.show_boon(boon, i, _replaced_by(boon), _forsaken_by(boon))
		card.pressed.connect(_pick.bind(boon))
		if i == 0:
			card.grab_focus.call_deferred()
	visible = true
	get_tree().paused = true
	var mat := dim.material as ShaderMaterial
	body.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("amount", v), 0.0, 1.0, 0.25)
	tw.tween_property(body, "modulate:a", 1.0, 0.25)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	var at := PICK_KEYS.find(key.physical_keycode)
	if at >= 0 and at < _choices.size():
		get_viewport().set_input_as_handled()
		_pick(_choices[at])


func _pick(boon: Dictionary) -> void:
	RunState.add_boon(boon)
	visible = false
	get_tree().paused = false
	RunState.awaiting_boon = false
	chosen.emit(boon)


## Slot boons push out whatever holds their slot (one per slot).
func _replaced_by(boon: Dictionary) -> String:
	if bool(boon.get("is_fallback", false)):
		return ""
	return str(RunState.boon_in_slot(str(boon.get("slot", "trigger"))).get("name", ""))


## Aligning with a patron blocks its rivals for the whole party.
func _forsaken_by(boon: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var patron := str(boon.get("patron", ""))
	if RunState.aligned_patron != "" or bool(boon.get("is_fallback", false)):
		return out
	for r: String in RunState.PATRON_RIVALS.get(patron, []):
		out.append(RunState.patron_display(r))
	return out

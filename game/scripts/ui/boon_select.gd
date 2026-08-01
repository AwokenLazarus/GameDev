extends CanvasLayer

signal chosen(boon: Dictionary)

@onready var panel: PanelContainer = $Center/Panel
@onready var title: Label = $Center/Panel/VBox/Title
@onready var buttons: VBoxContainer = $Center/Panel/VBox/Buttons
@onready var dim: ColorRect = $Dim

var _choices: Array[Dictionary] = []
var _subtitle: Label


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	if dim:
		dim.color = Color(0.04, 0.03, 0.05, 0.38)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.modulate = Color(0.85, 0.75, 0.65)
	var vbox := $Center/Panel/VBox
	vbox.add_child(_subtitle)
	vbox.move_child(_subtitle, 1)


func open_choices() -> void:
	_choices = BoonDB.get_choices(3)
	for c in buttons.get_children():
		c.queue_free()
	var left := maxi(0, RunState.boon_picks_target - RunState.boon_picks_done)
	title.text = "PICK A BOON"
	if _subtitle:
		_subtitle.text = "Combat is paused (%d picks left this run). Click one pact to continue fighting." % left
	for boon in _choices:
		var btn := Button.new()
		btn.text = "%s — %s\n%s" % [
			RunState.patron_display(str(boon.get("patron", ""))),
			str(boon.get("name", "")),
			str(boon.get("desc", "")),
		]
		btn.custom_minimum_size = Vector2(560, 78)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var captured := boon
		btn.pressed.connect(func(): _pick(captured))
		buttons.add_child(btn)
	visible = true
	get_tree().paused = true


func _pick(boon: Dictionary) -> void:
	RunState.add_boon(boon)
	visible = false
	get_tree().paused = false
	RunState.awaiting_boon = false
	chosen.emit(boon)

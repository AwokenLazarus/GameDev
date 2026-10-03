extends Area2D
class_name GreedShrine
## Wild-stage greed interactable (MW-025): stand in it to channel, then SectorController pays out.
## Kinds: chest (Blood/Ash/Tech haul or gear), moon_altar (boon, moon hurries the director),
## blood_well (boon, paid in feed stacks or blood). The timer keeps running while you channel.

signal activated(shrine: GreedShrine, player: Node)

const CHANNEL_S := {"chest": 1.5, "moon_altar": 1.0, "blood_well": 1.0}
const TITLES := {
	"chest": "Strongbox",
	"moon_altar": "Moon Altar",
	"blood_well": "Blood Well",
}
const HINTS := {
	"chest": "stand to pry open",
	"moon_altar": "a boon · the moon hurries",
	"blood_well": "a boon · pay in hunger or blood",
}

const TINTS := {
	"chest": Color(0.95, 0.75, 0.35),
	"moon_altar": Color(0.72, 0.82, 1.0),
	"blood_well": Color(0.9, 0.14, 0.18),
}
const RADIUS := 46.0

var kind: String = "chest"
var used: bool = false
var _channel: float = 0.0
var _inside: Array[Node] = []

@onready var body_piece: SetPiece = $Body
@onready var light: VotiveLight = $Light
@onready var caption: WorldLabel = $Caption


func _ready() -> void:
	add_to_group("greed_hook")
	add_to_group("greed_shrine")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visual()


func setup(kind_id: String, pos: Vector2) -> void:
	kind = kind_id
	position = pos
	set_meta("kind", kind)
	if is_node_ready():
		_build_visual()


func channel_seconds() -> float:
	return float(CHANNEL_S.get(kind, 1.2)) * RunState.shrine_cost_mult()


func _physics_process(delta: float) -> void:
	if used:
		return
	var who: Node = null
	for b: Node in _inside:
		if is_instance_valid(b) and not bool(b.get("dead")):
			who = b
			break
	if who == null:
		_channel = maxf(0.0, _channel - delta * 2.0)
	else:
		_channel += delta
		if _channel >= channel_seconds():
			_activate(who)
	_update_bar()


func _activate(who: Node) -> void:
	used = true
	_channel = 0.0
	body_piece.spent = true
	light.visible = false
	caption.text = "%s\nSPENT" % str(TITLES.get(kind, kind)).to_upper()
	caption.tint = Color(MWPalette.ASH, 0.6)
	queue_redraw()
	activated.emit(self, who)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not _inside.has(body):
		_inside.append(body)


func _on_body_exited(body: Node) -> void:
	_inside.erase(body)


func _update_bar() -> void:
	queue_redraw()


func _tint() -> Color:
	return TINTS.get(kind, MWPalette.GILT)


func _build_visual() -> void:
	var tint := _tint()
	body_piece.kind = kind
	body_piece.tint = tint
	light.setup(tint, 1.0, 300.0)
	caption.text = "%s\n%s" % [str(TITLES.get(kind, kind)), str(HINTS.get(kind, ""))]
	caption.text = caption.text.to_upper()
	caption.tint = tint.lightened(0.4)
	caption.position = IsoView.up(104.0)
	queue_redraw()


## Flat on the floor: the reach of the shrine, and the channel filling round it.
func _draw() -> void:
	if used:
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, Color(MWPalette.ASH, 0.2), 1.2, true)
		return
	var tint := _tint()
	draw_circle(Vector2.ZERO, RADIUS, Color(tint, 0.1))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, Color(tint, 0.5), 1.4, true)
	var f := clampf(_channel / maxf(channel_seconds(), 0.01), 0.0, 1.0)
	if f > 0.0:
		draw_arc(
			Vector2.ZERO,
			RADIUS + 5.0,
			-PI * 0.5,
			-PI * 0.5 + TAU * f,
			48,
			MWPalette.BONE,
			3.0,
			true
		)

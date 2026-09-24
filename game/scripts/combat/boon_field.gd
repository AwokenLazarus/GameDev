extends Node2D
class_name MWBoonField
## Ground object a boon leaves behind: smoke cloud, snare, caltrops, hymn circle,
## consecrated ground, dust devil, scrap cache, blood ration. Always drawn as a ring in
## the patron's colour (P2 readable). Callbacks:
##   on_enemy(foe)   every `interval` for each foe inside (or once, with `enemy_once`)
##   on_player(p)    once per player per field when they step inside
## `pickup` frees the field after its first player; `enemy_once` after its first foe.

var radius: float = 60.0
var life: float = 3.0
var interval: float = 0.25
var color: Color = Color(0.8, 0.7, 0.5)
var on_enemy: Callable
var on_player: Callable
var pickup: bool = false
var enemy_once: bool = false
var follow: Node2D = null
var marker: bool = false ## small diamond instead of an ellipse (pickups, snares)

var _t: float = 0.0
var _players_in: Dictionary = {}
var _done: bool = false
var _fill: Polygon2D


func setup(pos: Vector2, r: float, seconds: float, tint: Color) -> MWBoonField:
	global_position = pos
	radius = r
	life = seconds
	color = tint
	return self


func _ready() -> void:
	z_index = -4
	add_to_group("boon_field")
	var pts := PackedVector2Array()
	if marker:
		var m := minf(radius, 12.0)
		pts = PackedVector2Array([Vector2(0, -m), Vector2(m, 0), Vector2(0, m), Vector2(-m, 0)])
	else:
		for i in 24:
			var a := TAU * float(i) / 24.0
			pts.append(Vector2(cos(a), sin(a) * 0.6) * radius)
	_fill = Polygon2D.new()
	_fill.polygon = pts
	_fill.color = Color(color, 0.55 if marker else 0.18)
	add_child(_fill)
	var ring := Line2D.new()
	var closed := pts.duplicate()
	closed.append(pts[0])
	ring.points = closed
	ring.width = 2.0
	ring.default_color = Color(color, 0.85)
	add_child(ring)


func _physics_process(delta: float) -> void:
	if _done:
		return
	if follow != null and is_instance_valid(follow):
		global_position = follow.global_position
	life -= delta
	if life <= 0.0:
		_finish()
		return
	if on_player.is_valid():
		for p in get_tree().get_nodes_in_group("player"):
			if not is_instance_valid(p) or bool(p.get("dead")):
				continue
			var id: int = p.get_instance_id()
			if _players_in.has(id) or not _inside(p.global_position, 18.0):
				continue
			_players_in[id] = true
			on_player.call(p)
			if pickup:
				_finish()
				return
	if not on_enemy.is_valid():
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = interval
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not _inside(e.global_position, 12.0):
			continue
		on_enemy.call(e)
		if enemy_once:
			_finish()
			return


func _inside(pos: Vector2, pad: float) -> bool:
	var off := pos - global_position
	if not marker:
		off.y /= 0.6
	return off.length() <= radius + pad


func _finish() -> void:
	if _done:
		return
	_done = true
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)

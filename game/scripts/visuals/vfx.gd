extends Node
class_name MWVFX
## Static helpers to spawn combat / moon VFX.

static var _hitstopping: bool = false


static func slash(parent: Node, pos: Vector2, angle: float) -> void:
	_spawn_sprite(parent, "res://assets/textures/vfx/slash.png", pos, angle, 0.18, Vector2(1.2, 1.2))


static func blood(parent: Node, pos: Vector2) -> void:
	_spawn_sprite(parent, "res://assets/textures/vfx/blood.png", pos, randf() * TAU, 0.35, Vector2(0.8, 0.8))


static func dust_puff(parent: Node, pos: Vector2) -> void:
	_spawn_sprite(parent, "res://assets/textures/vfx/dust.png", pos, 0.0, 0.4, Vector2(1.4, 1.0))


static func telegraph_mark(parent: Node, pos: Vector2, life: float = 0.45, scl: Vector2 = Vector2(1.15, 1.15)) -> void:
	_spawn_sprite(parent, "res://assets/textures/vfx/telegraph.png", pos, 0.0, life, scl)


static func hitstop(tree: SceneTree, seconds: float = 0.045) -> void:
	if _hitstopping or tree == null:
		return
	_hitstopping = true
	Engine.time_scale = 0.18
	await tree.create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstopping = false


static func _spawn_sprite(parent: Node, path: String, pos: Vector2, angle: float, life: float, scl: Vector2) -> void:
	if parent == null or not ResourceLoader.exists(path):
		return
	var s := Sprite2D.new()
	s.texture = load(path)
	s.global_position = pos
	s.rotation = angle
	s.scale = scl
	s.z_index = 20
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(s)
	var tw := parent.get_tree().create_tween()
	tw.tween_property(s, "modulate:a", 0.0, life)
	tw.parallel().tween_property(s, "scale", scl * 1.35, life)
	tw.tween_callback(s.queue_free)

extends Node2D
class_name ActorVisual
## 2.5D stylized actor: shadow, animated sprite, facing, bob, flash.

@export var sprite_folder: String = "characters"
@export var sprite_name: String = "severin"
@export var pixels_per_unit: float = 1.0
@export var bob_amount: float = 2.0
@export var shadow_scale: Vector2 = Vector2(1.0, 0.45)

var _sprite: Sprite2D
var _shadow: Sprite2D
var _frames: Array[Texture2D] = []
var _frame_i: int = 0
var _frame_t: float = 0.0
var _moving: bool = false
var _facing_right: bool = true
var _flash_t: float = 0.0


func _ready() -> void:
	z_as_relative = true
	_shadow = Sprite2D.new()
	_shadow.z_index = -1
	_shadow.modulate = Color(0, 0, 0, 0.45)
	_shadow.scale = shadow_scale
	add_child(_shadow)
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.position = Vector2(0, -8)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	load_sprite(sprite_folder, sprite_name)


func load_sprite(folder: String, name: String) -> void:
	sprite_folder = folder
	sprite_name = name
	_frames.clear()
	for i in 4:
		var path := "res://assets/textures/%s/%s_f%d.png" % [folder, name, i]
		if ResourceLoader.exists(path):
			_frames.append(load(path))
	var base := "res://assets/textures/%s/%s.png" % [folder, name]
	if _frames.is_empty() and ResourceLoader.exists(base):
		_frames.append(load(base))
	if not _frames.is_empty():
		_sprite.texture = _frames[0]
		_shadow.texture = _frames[0]
		_shadow.modulate = Color(0, 0, 0, 0.4)
		_shadow.position = Vector2(0, 28)


func set_moving(moving: bool) -> void:
	_moving = moving


func set_facing_x(dir_x: float) -> void:
	if absf(dir_x) < 0.05:
		return
	_facing_right = dir_x >= 0.0
	_sprite.flip_h = not _facing_right


func flash(color: Color = Color(1.0, 0.4, 0.4), seconds: float = 0.1) -> void:
	_flash_t = seconds
	_sprite.modulate = color


func set_ghost(on: bool) -> void:
	_sprite.modulate = Color(0.75, 0.85, 1.0, 0.65) if on else Color.WHITE


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_sprite.modulate = Color.WHITE
	## Idle / walk bob + frame cycle
	var speed := 10.0 if _moving else 3.0
	_frame_t += delta * speed
	if _frames.size() > 1 and _frame_t >= 1.0:
		_frame_t = 0.0
		_frame_i = (_frame_i + 1) % _frames.size()
		_sprite.texture = _frames[_frame_i]
	var bob := sin(Time.get_ticks_msec() * 0.01 * (1.6 if _moving else 1.0)) * bob_amount
	_sprite.position.y = -8.0 + bob
	## Slight 2.5D squash on shadow when bobbing
	_shadow.scale = Vector2(shadow_scale.x * (1.0 - bob * 0.02), shadow_scale.y)

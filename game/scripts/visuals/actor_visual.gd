extends Node2D
class_name ActorVisual
## 2.5D actor with real anim states: idle / walk / run / attack / dodge / talk.

@export var sprite_folder: String = "characters"
@export var sprite_name: String = "severin"
@export var bob_amount: float = 1.2
@export var shadow_scale: Vector2 = Vector2(1.0, 0.45)
@export var show_marker: bool = true

var _sprite: Sprite2D
var _outline: Sprite2D
var _shadow: Sprite2D
var _marker: Polygon2D
var _anims: Dictionary = {} ## String -> Array[Texture2D]
var _anim: String = "idle"
var _frames: Array[Texture2D] = []
var _frame_i: int = 0
var _frame_t: float = 0.0
var _loop: bool = true
var _locked: bool = false
var _moving: bool = false
var _running: bool = false
var _facing_right: bool = true
var _flash_t: float = 0.0
var _fps: float = 8.0
var _base_modulate: Color = Color(1.25, 1.18, 1.15, 1.0)


func _ready() -> void:
	z_as_relative = true
	_marker = Polygon2D.new()
	_marker.z_index = -2
	_marker.color = Color(0.95, 0.35, 0.3, 0.55)
	_marker.polygon = PackedVector2Array([
		-22, 0, -16, 8, 16, 8, 22, 0, 16, -6, -16, -6
	])
	_marker.visible = show_marker
	add_child(_marker)
	_shadow = Sprite2D.new()
	_shadow.z_index = -1
	_shadow.modulate = Color(0, 0, 0, 0.45)
	_shadow.scale = shadow_scale
	add_child(_shadow)
	_outline = Sprite2D.new()
	_outline.centered = true
	_outline.position = Vector2(0, -8)
	_outline.z_index = 0
	_outline.modulate = Color(1.0, 0.85, 0.75, 0.85)
	_outline.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_outline)
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.position = Vector2(0, -8)
	_sprite.z_index = 1
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.modulate = _base_modulate
	add_child(_sprite)
	load_sprite(sprite_folder, sprite_name)


func load_sprite(folder: String, name: String) -> void:
	sprite_folder = folder
	sprite_name = name
	_anims.clear()
	for anim in ["idle", "walk", "run", "attack", "dodge", "talk"]:
		var frames: Array[Texture2D] = []
		for i in 8:
			var path := "res://assets/textures/%s/%s_%s_f%d.png" % [folder, name, anim, i]
			if ResourceLoader.exists(path):
				frames.append(load(path))
			else:
				break
		if not frames.is_empty():
			_anims[anim] = frames
	## Legacy fallback: name_f0..f3 as walk/idle
	if not _anims.has("walk"):
		var legacy: Array[Texture2D] = []
		for i in 4:
			var path := "res://assets/textures/%s/%s_f%d.png" % [folder, name, i]
			if ResourceLoader.exists(path):
				legacy.append(load(path))
		if not legacy.is_empty():
			_anims["walk"] = legacy
			_anims["idle"] = [legacy[0]]
	var base := "res://assets/textures/%s/%s.png" % [folder, name]
	if _anims.is_empty() and ResourceLoader.exists(base):
		var t: Texture2D = load(base)
		_anims["idle"] = [t]
		_anims["walk"] = [t]
	_locked = false
	_play_internal(_default_locomotion(), true)
	_apply_scale()
	## Marker color by role
	if _marker:
		match folder:
			"characters":
				_marker.color = Color(0.95, 0.4, 0.32, 0.65)
				_marker.scale = Vector2(1.15, 0.7)
			"enemies":
				_marker.color = Color(0.85, 0.2, 0.55, 0.45)
				_marker.scale = Vector2(0.85, 0.55)
			"generals":
				_marker.color = Color(1.0, 0.75, 0.25, 0.7)
				_marker.scale = Vector2(1.6, 0.85)
			"npcs":
				_marker.color = Color(0.55, 0.75, 0.95, 0.5)
				_marker.scale = Vector2(1.0, 0.6)
			_:
				_marker.color = Color(0.9, 0.9, 0.9, 0.4)


func _apply_scale() -> void:
	if _sprite.texture == null:
		return
	## Larger on-screen presence so painterly dark coats read in combat
	var target_h := 128.0
	if sprite_folder == "generals":
		target_h = 168.0
	elif sprite_folder == "enemies":
		target_h = 96.0
	elif sprite_folder == "npcs":
		target_h = 110.0
	var tex_h := float(_sprite.texture.get_height())
	if tex_h > 1.0:
		var s := target_h / tex_h
		_sprite.scale = Vector2(s, s)
		_outline.scale = Vector2(s * 1.06, s * 1.06)
		_shadow.scale = Vector2(shadow_scale.x * s * 1.2, shadow_scale.y * s)
		_shadow.texture = _sprite.texture
		_outline.texture = _sprite.texture
		_shadow.position = Vector2(0, 40)


func _default_locomotion() -> String:
	if _moving:
		return "run" if _running and _anims.has("run") else "walk"
	return "idle" if _anims.has("idle") else "walk"


func play(anim: String, loop: bool = true, fps: float = -1.0) -> void:
	if _locked and anim != _anim:
		return
	_play_internal(anim, loop, fps)


func play_oneshot(anim: String, fps: float = 12.0) -> void:
	if not _anims.has(anim):
		return
	_locked = true
	_play_internal(anim, false, fps)


func _play_internal(anim: String, loop: bool = true, fps: float = -1.0) -> void:
	if not _anims.has(anim):
		if _anims.has("idle"):
			anim = "idle"
		elif _anims.has("walk"):
			anim = "walk"
		else:
			return
	if anim == _anim and loop == _loop and not _frames.is_empty():
		return
	_anim = anim
	_frames = _anims[anim]
	_frame_i = 0
	_frame_t = 0.0
	_loop = loop
	if fps > 0.0:
		_fps = fps
	else:
		match anim:
			"idle":
				_fps = 3.0
			"walk":
				_fps = 8.0
			"run":
				_fps = 12.0
			"attack":
				_fps = 14.0
			"dodge":
				_fps = 14.0
			"talk":
				_fps = 5.0
			_:
				_fps = 8.0
	if not _frames.is_empty():
		_sprite.texture = _frames[0]
		_outline.texture = _frames[0]
		_shadow.texture = _frames[0]


func set_moving(moving: bool) -> void:
	_moving = moving
	if _locked:
		return
	_play_internal(_default_locomotion(), true)


func set_running(running: bool) -> void:
	_running = running
	if _locked:
		return
	if _moving:
		_play_internal(_default_locomotion(), true)


func set_facing_x(dir_x: float) -> void:
	if absf(dir_x) < 0.05:
		return
	_facing_right = dir_x >= 0.0
	_sprite.flip_h = not _facing_right
	_outline.flip_h = not _facing_right


func flash(color: Color = Color(1.0, 0.4, 0.4), seconds: float = 0.1) -> void:
	_flash_t = seconds
	_sprite.modulate = color


func set_ghost(on: bool) -> void:
	_sprite.modulate = Color(0.75, 0.85, 1.0, 0.65) if on else _base_modulate


func current_anim() -> String:
	return _anim


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_sprite.modulate = _base_modulate
	if _frames.is_empty():
		return
	_frame_t += delta * _fps
	if _frame_t >= 1.0:
		_frame_t = 0.0
		if _frame_i + 1 >= _frames.size():
			if _loop:
				_frame_i = 0
			else:
				_locked = false
				_play_internal(_default_locomotion(), true)
				return
		else:
			_frame_i += 1
		_sprite.texture = _frames[_frame_i]
		_outline.texture = _frames[_frame_i]
		_shadow.texture = _frames[_frame_i]
	var bob := sin(Time.get_ticks_msec() * 0.01 * (1.6 if _moving else 1.0)) * bob_amount
	if _anim == "attack" or _anim == "dodge":
		bob *= 0.25
	_sprite.position.y = -8.0 + bob
	_outline.position.y = -8.0 + bob
	_shadow.scale.y = shadow_scale.y * _sprite.scale.y * (1.0 - bob * 0.01)
	if _marker and show_marker:
		_marker.rotation = Time.get_ticks_msec() * 0.001

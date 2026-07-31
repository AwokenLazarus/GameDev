extends Node2D
class_name ActorVisual
## 2.5D actor with real anim states: idle / walk / run / attack / dodge / talk.

@export var sprite_folder: String = "characters"
@export var sprite_name: String = "severin"
@export var bob_amount: float = 1.2
@export var shadow_scale: Vector2 = Vector2(1.0, 0.45)

var _sprite: Sprite2D
var _shadow: Sprite2D
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
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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


func _apply_scale() -> void:
	if _sprite.texture == null:
		return
	var target_h := 96.0
	if sprite_folder == "generals":
		target_h = 128.0
	elif sprite_folder == "enemies":
		target_h = 72.0
	elif sprite_folder == "npcs":
		target_h = 88.0
	var tex_h := float(_sprite.texture.get_height())
	if tex_h > 1.0:
		var s := target_h / tex_h
		_sprite.scale = Vector2(s, s)
		_shadow.scale = Vector2(shadow_scale.x * s * 1.1, shadow_scale.y * s)
		_shadow.texture = _sprite.texture
		_shadow.position = Vector2(0, 36)


func _default_locomotion() -> String:
	if _moving:
		return "run" if _running and _anims.has("run") else "walk"
	return "idle" if _anims.has("idle") else "walk"


func play(anim: String, loop: bool = true, fps: float = -1.0) -> void:
	if _locked and anim != _anim:
		return
	_play_internal(anim, loop, fps)


func play_oneshot(anim: String, fps: float = 12.0) -> void:
	## Attack / dodge — locks until finished then returns to locomotion.
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
	if anim == _anim and _frames == _anims[anim] and loop == _loop:
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


func flash(color: Color = Color(1.0, 0.4, 0.4), seconds: float = 0.1) -> void:
	_flash_t = seconds
	_sprite.modulate = color


func set_ghost(on: bool) -> void:
	_sprite.modulate = Color(0.75, 0.85, 1.0, 0.65) if on else Color.WHITE


func current_anim() -> String:
	return _anim


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_sprite.modulate = Color.WHITE
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
		_shadow.texture = _frames[_frame_i]
	var bob := sin(Time.get_ticks_msec() * 0.01 * (1.6 if _moving else 1.0)) * bob_amount
	if _anim == "attack" or _anim == "dodge":
		bob *= 0.25
	_sprite.position.y = -8.0 + bob
	_shadow.scale.y = shadow_scale.y * _sprite.scale.y * (1.0 - bob * 0.01)

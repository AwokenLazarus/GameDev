extends CharacterBody2D
const _VFX = preload("res://scripts/visuals/vfx.gd")
## Multi-kit dhampir controller. Kits: melee, hybrid_gun, orbit, maul, astral.

signal died
signal fed

const PROJ := preload("res://scenes/entities/projectile.tscn")
const DODGE_SPEED := 520.0
const DODGE_TIME := 0.18
const DODGE_COOLDOWN := 0.55

@onready var body_visual: CanvasItem = $BodyVisual
@onready var blade_visual: CanvasItem = $BladeVisual
@onready var accent: CanvasItem = $Accent
@onready var hitbox: Area2D = $AttackHitbox
@onready var feed_area: Area2D = $FeedArea
@onready var health: Health = $Health
@onready var camera: Camera2D = $Camera2D
@onready var spirit_visual: CanvasItem = $SpiritVisual
@onready var actor_visual: Node2D = $ActorVisual

var player_index: int = 0
var device: int = -1 ## -1 keyboard, >=0 joypad
var character_id: String = "severin"
var alt_id: String = ""
var kit_type: String = "melee"

var facing: Vector2 = Vector2.RIGHT
var dodge_timer: float = 0.0
var dodge_cd: float = 0.0
var attack_cd: float = 0.0
var attacking: bool = false
var dead: bool = false
var _hit_ids: Dictionary = {}

var move_speed: float = 220.0
var base_damage: float = 22.0
var base_attack_cd: float = 0.38

## Orbit kit
var _crescents: Array[Node2D] = []
var _orbit_angle: float = 0.0

## Astral kit
var _spirit: Node2D
var _spirit_pos: Vector2 = Vector2.ZERO
var _spirit_out: bool = false


func _ready() -> void:
	add_to_group("player")
	hitbox.monitoring = false
	hitbox.body_entered.connect(_on_hitbox_body)
	hitbox.area_entered.connect(_on_hitbox_area)
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	spirit_visual.visible = false
	_apply_character()
	if player_index == 0:
		camera.enabled = true
	else:
		camera.enabled = false


func configure(index: int, char_id: String, alt: String = "", dev: int = -1) -> void:
	player_index = index
	character_id = char_id
	alt_id = alt
	device = dev
	if is_node_ready():
		_apply_character()


func _apply_character() -> void:
	var data: Dictionary = CharacterDB.get_character(character_id) if CharacterDB else {}
	kit_type = str(data.get("kit_type", "melee"))
	move_speed = float(data.get("move_speed", 220.0))
	base_damage = float(data.get("damage", 14.0)) * 1.5
	base_attack_cd = float(data.get("attack_cooldown", 0.4))
	var col: Color = data.get("color", Color(0.7, 0.7, 0.75))
	if body_visual is Polygon2D:
		(body_visual as Polygon2D).color = Color(col.darkened(0.55))
	if accent is Polygon2D:
		(accent as Polygon2D).color = col
	if alt_id != "" and CharacterDB:
		for a in CharacterDB.get_alts(character_id):
			if str(a.get("id", "")) == alt_id:
				var mods: Dictionary = a.get("kit_modifiers", {})
				if mods.has("kit_type"):
					kit_type = str(mods["kit_type"])
				move_speed += float(mods.get("move_speed", 0.0))
				base_damage += float(mods.get("damage", 0.0))
				base_attack_cd += float(mods.get("attack_cooldown", 0.0))
				break
	health.max_hp = RunState.player_max_hp if player_index == 0 else float(data.get("base_hp", 100.0))
	health.hp = health.max_hp
	if player_index == 0:
		health.hp = RunState.player_hp
		health.max_hp = RunState.player_max_hp
	if actor_visual:
		actor_visual.load_sprite("characters", character_id)
	_setup_kit_visuals()


func _setup_kit_visuals() -> void:
	blade_visual.visible = false
	if blade_visual is Sprite2D:
		var slash := "res://assets/textures/vfx/slash.png"
		if ResourceLoader.exists(slash):
			(blade_visual as Sprite2D).texture = load(slash)
	if spirit_visual is Sprite2D:
		var path := "res://assets/textures/characters/vesper.png"
		if ResourceLoader.exists(path):
			(spirit_visual as Sprite2D).texture = load(path)
			(spirit_visual as Sprite2D).modulate = Color(0.75, 0.85, 1.0, 0.55)
	match kit_type:
		"melee":
			pass
		"hybrid_gun":
			pass
		"orbit":
			_spawn_crescents()
		"maul":
			blade_visual.scale = Vector2(1.4, 1.6)
		"astral":
			if actor_visual:
				actor_visual.set_ghost(false)


func _spawn_crescents() -> void:
	for c in _crescents:
		if is_instance_valid(c):
			c.queue_free()
	_crescents.clear()
	var tex_path := "res://assets/textures/vfx/crescent.png"
	var tex: Texture2D = load(tex_path) if ResourceLoader.exists(tex_path) else null
	for i in 2:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.modulate = Color(0.7, 0.9, 1.0, 0.95)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(spr)
		_crescents.append(spr)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if player_index == 0:
		RunState.player_hp = health.hp
		RunState.player_max_hp = health.max_hp

	if dodge_cd > 0.0:
		dodge_cd -= delta
	if attack_cd > 0.0:
		attack_cd -= delta

	if kit_type == "orbit":
		_update_orbit(delta)
	if kit_type == "astral":
		_update_astral(delta)
	if kit_type == "hybrid_gun":
		_auto_gun(delta)

	if dodge_timer > 0.0:
		dodge_timer -= delta
		move_and_slide()
		return

	var input_dir := _move_vector()
	if input_dir.length() > 0.1:
		facing = input_dir.normalized()
		blade_visual.rotation = facing.angle()
	if actor_visual:
		var moving := input_dir.length() > 0.1
		actor_visual.set_running(input_dir.length() > 0.75)
		actor_visual.set_moving(moving)
		actor_visual.set_facing_x(facing.x)

	velocity = input_dir * move_speed * RunState.move_mult

	if _just_pressed("dodge") and dodge_cd <= 0.0 and input_dir.length() > 0.1:
		_start_dodge(input_dir.normalized())
	elif _just_pressed("attack") and attack_cd <= 0.0 and not attacking:
		_start_attack()
	elif _just_pressed("feed"):
		_try_feed()

	move_and_slide()


func _move_vector() -> Vector2:
	if player_index == 0 and device == -1:
		return Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if device == -2 or (player_index == 1 and device < 0):
		var v2 := Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_LEFT):
			v2.x -= 1
		if Input.is_physical_key_pressed(KEY_RIGHT):
			v2.x += 1
		if Input.is_physical_key_pressed(KEY_UP):
			v2.y -= 1
		if Input.is_physical_key_pressed(KEY_DOWN):
			v2.y += 1
		return v2.normalized() if v2.length() > 0 else Vector2.ZERO
	if device >= 0:
		var x := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
		var y := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
		var v := Vector2(x, y)
		if v.length() < 0.25:
			return Vector2.ZERO
		return v.normalized()
	## P2 keyboard fallback (arrows)
	if player_index == 1:
		var v := Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_LEFT):
			v.x -= 1
		if Input.is_physical_key_pressed(KEY_RIGHT):
			v.x += 1
		if Input.is_physical_key_pressed(KEY_UP):
			v.y -= 1
		if Input.is_physical_key_pressed(KEY_DOWN):
			v.y += 1
		return v.normalized() if v.length() > 0 else Vector2.ZERO
	return Vector2.ZERO


func _just_pressed(action: String) -> bool:
	if player_index == 0 and device == -1:
		return Input.is_action_just_pressed(action)
	if device >= 0:
		match action:
			"attack":
				return Input.is_joy_button_pressed(device, JOY_BUTTON_X)
			"dodge":
				return Input.is_joy_button_pressed(device, JOY_BUTTON_A)
			"feed":
				return Input.is_joy_button_pressed(device, JOY_BUTTON_Y)
		return false
	if device == -2 or player_index >= 1:
		match action:
			"attack":
				return Input.is_physical_key_pressed(KEY_CTRL)
			"dodge":
				return Input.is_physical_key_pressed(KEY_SHIFT)
			"feed":
				return Input.is_physical_key_pressed(KEY_F)
	return false


func _start_dodge(dir: Vector2) -> void:
	dodge_timer = DODGE_TIME
	dodge_cd = DODGE_COOLDOWN / maxf(0.5, RunState.dash_mult)
	velocity = dir * DODGE_SPEED * RunState.dash_mult
	health.set_invuln(DODGE_TIME + 0.05)
	_VFX.dust_puff(get_parent(), global_position)
	if actor_visual:
		actor_visual.play_oneshot("dodge", 14.0)
		actor_visual.flash(Color(0.85, 0.85, 1.0, 0.7), DODGE_TIME)
	body_visual.modulate = Color(0.85, 0.85, 1.0, 0.55)
	await get_tree().create_timer(DODGE_TIME).timeout
	if is_instance_valid(body_visual):
		body_visual.modulate = Color.WHITE


func _start_attack() -> void:
	attack_cd = base_attack_cd / maxf(0.25, RunState.attack_speed_mult * RunState.cooldown_mult)
	if actor_visual:
		actor_visual.play_oneshot("attack", 14.0)
	match kit_type:
		"melee":
			await _attack_melee()
		"hybrid_gun":
			await _attack_gun_burst()
		"orbit":
			await _attack_orbit_recall()
		"maul":
			await _attack_maul()
		"astral":
			await _attack_astral_detonate()


func _dmg() -> float:
	var d := base_damage * RunState.damage_mult * (1.0 + RunState.get_feed_damage_bonus())
	if RunState.has_pact("dust_compact"):
		d *= 1.15
	if RunState.has_pact("red_petition"):
		d *= 1.2
	if RunState.has_pact("house_veyra"):
		d *= 1.18
	if RunState.has_pact("church"):
		d *= 1.12
	if RunState.crit_chance > 0.0 and randf() < RunState.crit_chance:
		d *= 1.75
	return d


func _attack_melee() -> void:
	attacking = true
	_hit_ids.clear()
	hitbox.monitoring = true
	blade_visual.visible = true
	blade_visual.rotation = facing.angle()
	hitbox.rotation = facing.angle()
	_VFX.slash(get_parent(), global_position + facing * 28.0, facing.angle())
	## Peace-cord lunge
	velocity = facing * 280.0
	await get_tree().create_timer(0.14).timeout
	if is_instance_valid(hitbox):
		hitbox.monitoring = false
	if is_instance_valid(blade_visual):
		blade_visual.visible = false
	attacking = false


func _auto_gun(delta: float) -> void:
	## Passive auto volleys
	if attack_cd > base_attack_cd * 0.35:
		return
	_gun_cd_acc = _gun_cd_acc + delta if "_gun_cd_acc" in self else delta
	if not has_meta("gun_acc"):
		set_meta("gun_acc", 0.0)
	var acc: float = float(get_meta("gun_acc")) + delta
	if acc < 0.22 / maxf(0.4, RunState.attack_speed_mult):
		set_meta("gun_acc", acc)
		return
	set_meta("gun_acc", 0.0)
	_spawn_bolt(facing.rotated(randf_range(-0.15, 0.15)), _dmg() * 0.45, true)


var _gun_cd_acc: float = 0.0


func _attack_gun_burst() -> void:
	attacking = true
	var aim := facing
	if player_index == 0:
		var mouse := get_global_mouse_position()
		aim = (mouse - global_position).normalized()
		facing = aim
	for i in 5:
		_spawn_bolt(aim.rotated(randf_range(-0.2, 0.2)), _dmg() * 0.55, true)
		await get_tree().create_timer(0.04).timeout
	attacking = false


func _spawn_bolt(dir: Vector2, dmg: float, seeking: bool) -> void:
	var p: Node = PROJ.instantiate()
	get_parent().add_child(p)
	p.setup(global_position + dir * 18.0, dir, dmg, self, seeking)


func _update_orbit(delta: float) -> void:
	_orbit_angle += delta * 3.2 * RunState.attack_speed_mult
	var radius := 42.0
	if RunState.has_pact("house_veyra"):
		radius = 54.0
	for i in _crescents.size():
		var a := _orbit_angle + TAU * float(i) / float(_crescents.size())
		var pos := Vector2(cos(a), sin(a)) * radius
		_crescents[i].position = pos
		_crescents[i].rotation = a
		## Damage nearby enemies
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e):
				continue
			if _crescents[i].global_position.distance_to(e.global_position) < 22.0:
				var idkey := "%s_%d" % [e.get_instance_id(), i]
				if has_meta(idkey):
					continue
				set_meta(idkey, true)
				var h: Health = e.get_node_or_null("Health")
				if h:
					h.take_damage(_dmg() * 0.35 * delta * 18.0)
					on_deal_damage(_dmg() * 0.1)
				## clear meta soon
				get_tree().create_timer(0.15).timeout.connect(func():
					if has_meta(idkey):
						remove_meta(idkey)
				)


func _attack_orbit_recall() -> void:
	attacking = true
	## Expand crescents outward then snap back
	for t in 8:
		for i in _crescents.size():
			var a := _orbit_angle + TAU * float(i) / float(_crescents.size())
			_crescents[i].position = Vector2(cos(a), sin(a)) * (42.0 + t * 10.0)
		await get_tree().create_timer(0.03).timeout
	attacking = false


func _attack_maul() -> void:
	attacking = true
	_hit_ids.clear()
	blade_visual.visible = true
	blade_visual.rotation = facing.angle()
	hitbox.rotation = facing.angle()
	hitbox.scale = Vector2(1.6, 1.6)
	hitbox.monitoring = true
	## Shockwave visual
	var wave := Polygon2D.new()
	wave.color = Color(0.6, 0.3, 0.25, 0.35)
	wave.polygon = PackedVector2Array([-10, -10, 70, -40, 70, 40, -10, 10])
	wave.rotation = facing.angle()
	add_child(wave)
	await get_tree().create_timer(0.2).timeout
	## AOE damage
	for e in get_tree().get_nodes_in_group("enemy"):
		if global_position.distance_to(e.global_position) < 90.0:
			var h: Health = e.get_node_or_null("Health")
			if h:
				h.take_damage(_dmg() * 1.35)
				on_deal_damage(_dmg() * 1.35)
	hitbox.monitoring = false
	hitbox.scale = Vector2.ONE
	blade_visual.visible = false
	wave.queue_free()
	attacking = false


func _update_astral(delta: float) -> void:
	if not _spirit_out:
		if _just_pressed("attack") or true:
			_spirit_out = true
			_spirit_pos = global_position + facing * 80.0
			spirit_visual.visible = true
	spirit_visual.global_position = _spirit_pos
	## Spirit drifts toward nearest enemy and auto-beams
	var target := _nearest_enemy_from(_spirit_pos)
	if target:
		_spirit_pos = _spirit_pos.move_toward(target.global_position, 160.0 * delta)
		if not has_meta("astral_acc"):
			set_meta("astral_acc", 0.0)
		var acc: float = float(get_meta("astral_acc")) + delta
		if acc >= 0.35 / maxf(0.4, RunState.attack_speed_mult):
			set_meta("astral_acc", 0.0)
			var dir := (target.global_position - _spirit_pos).normalized()
			var p: Node = PROJ.instantiate()
			get_parent().add_child(p)
			p.setup(_spirit_pos, dir, _dmg() * 0.6, self, false, 500.0)
			p.visual.modulate = Color(0.7, 0.85, 1.0)
		else:
			set_meta("astral_acc", acc)
	## Body is fragile — slight slow
	move_speed = float(CharacterDB.get_character(character_id).get("move_speed", 200.0)) * 0.9


func _attack_astral_detonate() -> void:
	attacking = true
	for e in get_tree().get_nodes_in_group("enemy"):
		if _spirit_pos.distance_to(e.global_position) < 100.0:
			var h: Health = e.get_node_or_null("Health")
			if h:
				h.take_damage(_dmg() * 1.6)
				on_deal_damage(_dmg() * 1.6)
	var flash := Polygon2D.new()
	flash.color = Color(0.8, 0.9, 1.0, 0.4)
	flash.polygon = PackedVector2Array([-80, -80, 80, -80, 80, 80, -80, 80])
	get_parent().add_child(flash)
	flash.global_position = _spirit_pos
	await get_tree().create_timer(0.15).timeout
	flash.queue_free()
	attacking = false


func _nearest_enemy_from(pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := 9999.0
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d := pos.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func on_deal_damage(amount: float) -> void:
	var ls := RunState.lifesteal + RunState.get_feed_lifesteal_bonus()
	if ls > 0.0:
		health.heal(amount * ls)


func _on_hitbox_body(body: Node) -> void:
	_try_damage_target(body)


func _on_hitbox_area(area: Area2D) -> void:
	_try_damage_target(area.get_parent())


func _try_damage_target(node: Node) -> void:
	if node == null or node == self or not node.is_in_group("enemy"):
		return
	var id := node.get_instance_id()
	if _hit_ids.has(id):
		return
	_hit_ids[id] = true
	var h: Health = node.get_node_or_null("Health")
	if h:
		var d := _dmg()
		h.take_damage(d)
		on_deal_damage(d)


func _try_feed() -> void:
	for body in feed_area.get_overlapping_bodies():
		if body.is_in_group("feedable_corpse"):
			_feed(body)
			return
	for area in feed_area.get_overlapping_areas():
		var p := area.get_parent()
		if p and p.is_in_group("feedable_corpse"):
			_feed(p)
			return


func _feed(corpse: Node) -> void:
	RunState.feed_on_human()
	fed.emit()
	if corpse.has_method("consume"):
		corpse.consume()
	else:
		corpse.queue_free()
	if actor_visual:
		actor_visual.flash(Color(0.9, 0.3, 0.35), 0.2)
	_VFX.blood(get_parent(), global_position)
	body_visual.modulate = Color(0.9, 0.3, 0.35)
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(body_visual):
		body_visual.modulate = Color.WHITE


func apply_hit(amount: float) -> void:
	## Astral body is fragile
	if kit_type == "astral":
		amount *= 1.25
	health.take_damage(amount)


func _on_damaged(_amount: float, remaining: float) -> void:
	if player_index == 0:
		RunState.player_hp = remaining
	if actor_visual:
		actor_visual.flash()
	body_visual.modulate = Color(1.0, 0.4, 0.4)
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(body_visual) and not dead:
		body_visual.modulate = Color.WHITE


func _on_died() -> void:
	dead = true
	died.emit()

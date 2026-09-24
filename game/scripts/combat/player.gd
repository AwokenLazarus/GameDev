extends CharacterBody2D
const _VFX = preload("res://scripts/visuals/vfx.gd")
const _ZONE = preload("res://scripts/combat/kit_zone.gd")
## Multi-kit dhampir controller. Kits: melee, hybrid_gun, orbit, maul, astral.
## Every kit has four inputs — attack, special, cast, dash — and deals damage only in
## response to one of them (anti-pillar: not an AFK auto-survivor). Slot data lives in
## CharacterDB.KIT_SLOTS; boons hook the slot_used / slot_hit signals and slot_mods.

signal died
signal fed
## Boon hooks (MW-006). `slot` is one of CharacterDB.SLOT_NAMES.
signal slot_used(slot: String)
signal slot_hit(slot: String, target: Node, damage: float)

const PROJ := preload("res://scenes/entities/projectile.tscn")
const DODGE_SPEED := 520.0
const DODGE_TIME := 0.18
const DODGE_COOLDOWN := 0.55
const HIT_IFRAME := 0.5
const HIT_KNOCK := 260.0
const HIT_KNOCK_TIME := 0.16
const MAX_HIT := 35.0
const INPUT_BUFFER := 0.18
const ACTIONS := ["attack", "special", "cast", "dodge", "feed"]
const MARK_META := "blood_mark"

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
var device: int = -1 ## -1 keyboard, -2 P2 keyboard, >=0 joypad
var character_id: String = "severin"
var alt_id: String = ""
var kit_type: String = "melee"

var facing: Vector2 = Vector2.RIGHT
var dodge_timer: float = 0.0
var dodge_cd: float = 0.0
var attack_cd: float = 0.0
var special_cd: float = 0.0
var cast_charges: int = 0
var cast_max: int = 0
var dead: bool = false
var _kb_timer: float = 0.0

var move_speed: float = 220.0
var base_damage: float = 22.0
var base_attack_cd: float = 0.38

## Resolved slot blocks from CharacterDB.get_slots().
var slots: Dictionary = {}
## Per-slot multipliers boons may write: {"attack": {"damage": 1.0, "cooldown": 1.0}, ...}.
var slot_mods: Dictionary = {}

var _busy: float = 0.0 ## commit lock: no new attack/special/cast until it runs out
var _lunge_t: float = 0.0
var _cast_recharge: float = 0.0
var _buffered: String = ""
var _buffer_t: float = 0.0
var _held: Dictionary = {}
var _just: Dictionary = {}
var _mouse_aim: bool = false

## Melee combo
var _combo_step: int = 0
var _combo_window: float = 0.0

## Orbit kit: each crescent is {node, mode (home|out|back|burst), pos, dir, dist, hits}
var _crescents: Array[Dictionary] = []
var _orbit_angle: float = 0.0
var _burst_t: float = 0.0

## Astral kit
var _spirit_pos: Vector2 = Vector2.ZERO
var _anchor_t: float = 0.0
var _project_t: float = 0.0
var _project_from: Vector2 = Vector2.ZERO
var _project_to: Vector2 = Vector2.ZERO
var _project_hits: Dictionary = {}


func _ready() -> void:
	add_to_group("player")
	hitbox.monitoring = false
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


func configure_stage_camera(half: Vector2, zoom: float) -> void:
	## P1 follow-cam; limits keep the view inside the current room / wild map.
	if camera == null:
		return
	if player_index != 0:
		camera.enabled = false
		return
	camera.enabled = true
	camera.zoom = Vector2(zoom, zoom)
	camera.limit_left = int(-half.x)
	camera.limit_right = int(half.x)
	camera.limit_top = int(-half.y)
	camera.limit_bottom = int(half.y)
	camera.limit_smoothed = true
	camera.position_smoothing_enabled = true


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
	if kit_type == "astral":
		move_speed *= 0.9 ## fragile body walks a touch slower
	slots = CharacterDB.get_slots(character_id, alt_id) if CharacterDB else {}
	for s in ["attack", "special", "cast", "dash"]:
		if not slot_mods.has(s):
			slot_mods[s] = {"damage": 1.0, "cooldown": 1.0}
	cast_max = int(_slot("cast").get("charges", 1))
	cast_charges = cast_max
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
		"orbit":
			_spawn_crescents()
		"maul":
			blade_visual.scale = Vector2(1.4, 1.6)
		"astral":
			if actor_visual:
				actor_visual.set_ghost(false)
			spirit_visual.visible = true
			_spirit_pos = global_position + facing * float(_slot("attack").get("leash", 80.0))


func _spawn_crescents() -> void:
	for c in _crescents:
		if is_instance_valid(c.node):
			c.node.queue_free()
	_crescents.clear()
	var tex_path := "res://assets/textures/vfx/crescent.png"
	var tex: Texture2D = load(tex_path) if ResourceLoader.exists(tex_path) else null
	for i in 2:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.modulate = Color(0.7, 0.9, 1.0, 0.95)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(spr)
		_crescents.append({"node": spr, "mode": "home", "pos": Vector2.ZERO, "dir": Vector2.RIGHT, "dist": 0.0, "hits": {}})


# --- Frame loop --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if dead:
		return
	if player_index == 0:
		RunState.player_hp = health.hp
		RunState.player_max_hp = health.max_hp

	_poll_input()
	_tick_timers(delta)
	if kit_type == "orbit":
		_update_orbit(delta)
	if kit_type == "astral":
		_update_astral(delta)

	if dodge_timer > 0.0:
		dodge_timer -= delta
		move_and_slide()
		return
	if _lunge_t > 0.0:
		_lunge_t -= delta
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

	var wish := input_dir * move_speed * RunState.move_mult
	if _kb_timer > 0.0:
		_kb_timer -= delta
		velocity = velocity.move_toward(wish, 1400.0 * delta)
	else:
		velocity = wish

	if _just.get("dodge", false) and dodge_cd <= 0.0:
		_start_dodge(input_dir.normalized() if input_dir.length() > 0.1 else facing)
	else:
		for s in ["special", "cast", "attack"]:
			if _just.get(s, false):
				_buffered = s
				_buffer_t = INPUT_BUFFER
				break
		if _buffered != "" and can_use_slot(_buffered):
			var slot := _buffered
			_buffered = ""
			use_slot(slot)
		elif _just.get("feed", false):
			_try_feed()

	move_and_slide()


func _tick_timers(delta: float) -> void:
	if dodge_cd > 0.0:
		dodge_cd -= delta
	if attack_cd > 0.0:
		attack_cd -= delta
	if special_cd > 0.0:
		special_cd -= delta
	if _busy > 0.0:
		_busy -= delta
	if _combo_window > 0.0:
		_combo_window -= delta
	if _buffer_t > 0.0:
		_buffer_t -= delta
		if _buffer_t <= 0.0:
			_buffered = ""
	if cast_charges < cast_max:
		_cast_recharge -= delta
		if _cast_recharge <= 0.0:
			cast_charges += 1
			_cast_recharge = _cd("cast", float(_slot("cast").get("recharge", 4.0)))


# --- Input -------------------------------------------------------------------

func _move_vector() -> Vector2:
	if player_index == 0 and device == -1:
		return Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if device >= 0:
		var v := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		if v.length() < 0.25:
			return Vector2.ZERO
		return v.normalized()
	if device == -2 or player_index >= 1:
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
	return Vector2.ZERO


## Edge-detects every action once per physics frame. P1 keyboard uses the InputMap;
## pads and the P2 keyboard read raw state, so they need their own previous-frame copy.
func _poll_input() -> void:
	for a in ACTIONS:
		if player_index == 0 and device == -1:
			_just[a] = Input.is_action_just_pressed(a)
			continue
		var now := _raw_pressed(a)
		_just[a] = now and not bool(_held.get(a, false))
		_held[a] = now


func _raw_pressed(action: String) -> bool:
	if device >= 0:
		match action:
			"attack":
				return Input.is_joy_button_pressed(device, JOY_BUTTON_X)
			"special":
				return Input.is_joy_button_pressed(device, JOY_BUTTON_B)
			"cast":
				return Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER)
			"dodge":
				return Input.is_joy_button_pressed(device, JOY_BUTTON_A)
			"feed":
				return Input.is_joy_button_pressed(device, JOY_BUTTON_Y)
		return false
	if device == -2 or player_index >= 1:
		match action:
			"attack":
				return Input.is_physical_key_pressed(KEY_CTRL)
			"special":
				return Input.is_physical_key_pressed(KEY_SLASH)
			"cast":
				return Input.is_physical_key_pressed(KEY_PERIOD)
			"dodge":
				return Input.is_physical_key_pressed(KEY_SHIFT)
			"feed":
				return Input.is_physical_key_pressed(KEY_F)
	return false


func _unhandled_input(event: InputEvent) -> void:
	if player_index != 0 or device != -1:
		return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_mouse_aim = true
	elif event is InputEventKey and event.pressed:
		if event.is_action("attack") or event.is_action("special") or event.is_action("cast"):
			_mouse_aim = false


## Mouse for P1 when the mouse was used last, right stick on pads, else facing.
func _aim_dir() -> Vector2:
	if player_index == 0 and device == -1 and _mouse_aim:
		var d := get_global_mouse_position() - global_position
		if d.length() > 4.0:
			return d.normalized()
	if device >= 0:
		var r := Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
		if r.length() > 0.35:
			return r.normalized()
	return facing


# --- Slots -------------------------------------------------------------------

func _slot(slot: String) -> Dictionary:
	return slots.get(slot, {})


func _slot_mod(slot: String, key: String) -> float:
	return float((slot_mods.get(slot, {}) as Dictionary).get(key, 1.0))


## Cooldown in seconds after RunState speed stats and boon slot mods.
func _cd(slot: String, seconds: float) -> float:
	var speed := RunState.cooldown_mult
	if slot == "attack":
		speed *= RunState.attack_speed_mult
	return seconds / maxf(0.25, speed) * _slot_mod(slot, "cooldown")


func _slot_dmg(slot: String, mult: float) -> float:
	return _dmg() * mult * _slot_mod(slot, "damage")


func can_use_slot(slot: String) -> bool:
	if dead:
		return false
	match slot:
		"dash":
			return dodge_cd <= 0.0
		"attack":
			if kit_type == "orbit" and _home_crescent() < 0:
				return false
			return attack_cd <= 0.0 and _busy <= 0.0
		"special":
			return special_cd <= 0.0 and _busy <= 0.0
		"cast":
			return cast_charges > 0 and _busy <= 0.0
	return false


## Fires a slot as if its input was pressed. Returns false if it's on cooldown.
## Input polling, bots and tests all come through here.
func use_slot(slot: String) -> bool:
	if not can_use_slot(slot):
		return false
	if slot == "dash":
		_start_dodge(facing)
		return true
	var dir := _aim_dir()
	facing = dir
	blade_visual.rotation = dir.angle()
	match slot:
		"attack":
			attack_cd = _cd("attack", base_attack_cd * float(_slot("attack").get("cooldown", 1.0)))
			if actor_visual:
				actor_visual.play_oneshot("attack", 14.0)
		"special":
			special_cd = _cd("special", float(_slot("special").get("cooldown", 3.0)))
			if actor_visual:
				actor_visual.play_oneshot("attack", 16.0)
		"cast":
			if cast_charges == cast_max:
				_cast_recharge = _cd("cast", float(_slot("cast").get("recharge", 4.0)))
			cast_charges -= 1
	slot_used.emit(slot)
	match kit_type + ":" + slot:
		"melee:attack":
			_melee_combo(dir)
		"melee:special":
			_melee_cleave(dir)
		"melee:cast":
			_melee_stake(dir)
		"hybrid_gun:attack":
			_gun_rail(dir)
		"hybrid_gun:special":
			_gun_volley(dir)
		"hybrid_gun:cast":
			_gun_flare(dir)
		"orbit:attack":
			_orbit_throw(dir)
		"orbit:special":
			_orbit_burst()
		"orbit:cast":
			_orbit_sigil(dir)
		"maul:attack":
			_maul_slam(dir)
		"maul:special":
			_maul_shockwave(dir)
		"maul:cast":
			_maul_hook(dir)
		"astral:attack":
			_astral_spike(dir)
		"astral:special":
			_astral_collapse()
		"astral:cast":
			_astral_project(dir)
	return true


## One-line HUD readout of the non-attack slots.
func slot_status() -> String:
	var sp: String = str(_slot("special").get("name", "Special"))
	var ca: String = str(_slot("cast").get("name", "Cast"))
	var sp_state := "ready" if special_cd <= 0.0 else "%.1fs" % special_cd
	return "%s %s · %s %d/%d" % [sp, sp_state, ca, cast_charges, cast_max]


func _start_dodge(dir: Vector2) -> void:
	dodge_timer = DODGE_TIME
	dodge_cd = DODGE_COOLDOWN / maxf(0.5, RunState.dash_mult) * _slot_mod("dash", "cooldown")
	velocity = dir * DODGE_SPEED * RunState.dash_mult
	_lunge_t = 0.0
	health.set_invuln(DODGE_TIME + 0.05)
	slot_used.emit("dash")
	_VFX.dust_puff(get_parent(), global_position)
	if actor_visual:
		actor_visual.play_oneshot("dodge", 14.0)
		actor_visual.flash(Color(0.85, 0.85, 1.0, 0.7), DODGE_TIME)
	body_visual.modulate = Color(0.85, 0.85, 1.0, 0.55)
	await get_tree().create_timer(DODGE_TIME).timeout
	if is_instance_valid(body_visual):
		body_visual.modulate = Color.WHITE


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


# --- Hit helpers -------------------------------------------------------------

## Enemies within `radius` of `center` and within `half_arc` radians of `dir`.
func _enemies_in_arc(center: Vector2, radius: float, dir: Vector2, half_arc: float = PI) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var off: Vector2 = e.global_position - center
		if off.length() > radius + 14.0:
			continue
		if half_arc < PI and off.length() > 18.0 and absf(dir.angle_to(off)) > half_arc:
			continue
		out.append(e)
	return out


## Every player-caused hit lands here: blood marks, lifesteal, stagger and boon hooks.
func land_slot_hit(node: Node, dmg: float, slot: String, do_hitstop: bool = false, knock: float = 200.0) -> void:
	if node == null or not is_instance_valid(node):
		return
	var h: Health = node.get_node_or_null("Health")
	if h == null or not h.is_alive():
		return
	var d := dmg * (1.0 + mark_bonus(node))
	h.take_damage(d)
	on_deal_damage(d)
	if knock > 0.0 and node.has_method("apply_stagger"):
		node.apply_stagger(global_position, knock)
	slot_hit.emit(slot, node, d)
	if do_hitstop:
		_VFX.hitstop(get_tree())


func land_projectile_hit(p: Node, node: Node) -> void:
	match str(p.tag):
		"stake":
			land_slot_hit(node, p.damage, p.slot, false, 120.0)
			var c := _slot("cast")
			apply_mark(node, float(c.get("mark_time", 4.0)), float(c.get("mark_bonus", 0.3)))
		"hook":
			land_slot_hit(node, p.damage, p.slot, false, 0.0)
			if node.has_method("apply_stagger") and is_instance_valid(node):
				var away: Vector2 = (node.global_position - global_position).normalized()
				node.apply_stagger(node.global_position + away * 10.0, float(_slot("cast").get("pull", 520.0)))
		_:
			land_slot_hit(node, p.damage, p.slot, false, 140.0)


func _spawn_projectile(origin: Vector2, dir: Vector2, dmg: float, slot: String, tag: String = "",
		seeking: bool = false, speed: float = 420.0, pierce: int = 0, tint: Color = Color.WHITE) -> Node:
	var p: Node = PROJ.instantiate()
	get_parent().add_child(p)
	p.setup(origin + dir * 18.0, dir, dmg, self, seeking, speed)
	p.slot = slot
	p.tag = tag
	p.pierce = pierce
	p.visual.modulate = tint
	return p


func _spawn_zone(pos: Vector2, radius: float, dmg: float, slot: String, fuse: float = 0.0,
		ticks: int = 1, interval: float = 0.25, knock: float = 0.0, tint: Color = Color(0.85, 0.25, 0.3)) -> Node2D:
	var z: Node2D = _ZONE.new()
	z.setup(self, slot, pos, radius, dmg, fuse, ticks, interval, knock, tint)
	get_parent().add_child(z)
	return z


## Blood mark (Severin's stake): marked foes take +bonus damage from every sibling.
static func mark_bonus(node: Node) -> float:
	if node == null or not node.has_meta(MARK_META):
		return 0.0
	var m: Dictionary = node.get_meta(MARK_META)
	if Time.get_ticks_msec() > int(m.get("until", 0)):
		return 0.0
	return float(m.get("bonus", 0.0))


func apply_mark(node: Node, seconds: float, bonus: float) -> void:
	if node == null or not is_instance_valid(node) or not (node is Node2D):
		return
	var old: Dictionary = node.get_meta(MARK_META, {})
	var icon: Node2D = old.get("icon") if is_instance_valid(old.get("icon")) else null
	if icon == null:
		## The icon owns its expiry timer, so it dies with the enemy and a re-mark just restarts it.
		icon = Polygon2D.new()
		(icon as Polygon2D).polygon = PackedVector2Array([Vector2(0, -7), Vector2(5, 0), Vector2(0, 7), Vector2(-5, 0)])
		(icon as Polygon2D).color = Color(0.9, 0.12, 0.2, 0.95)
		icon.position = Vector2(0, -38)
		icon.z_index = 30
		var timer := Timer.new()
		timer.name = "Expire"
		timer.one_shot = true
		timer.timeout.connect(icon.queue_free)
		icon.add_child(timer)
		node.add_child(icon)
	(icon.get_node("Expire") as Timer).start(seconds)
	node.set_meta(MARK_META, {"until": Time.get_ticks_msec() + int(seconds * 1000.0), "bonus": bonus, "icon": icon})


# --- Severin: melee ----------------------------------------------------------

func _melee_combo(dir: Vector2) -> void:
	var a := _slot("attack")
	if _combo_window <= 0.0:
		_combo_step = 0
	var i := _combo_step
	var finisher := i == 2
	var cds: Array = a.get("combo_cooldown", [1.0, 1.0, 1.0])
	attack_cd = _cd("attack", base_attack_cd * float(cds[i]))
	_busy = minf(attack_cd, 0.16)
	_combo_step = (i + 1) % 3
	_combo_window = 0.0 if finisher else float(a.get("combo_window", 0.6))
	var radius := float((a.get("combo_radius", [58.0, 58.0, 74.0]) as Array)[i])
	var arc := float((a.get("combo_arc", [1.1, 1.1, 1.6]) as Array)[i])
	var mult := float((a.get("combo_damage", [1.0, 1.0, 1.7]) as Array)[i])
	## Short step into the swing; the long peace-cord lunge is the special now.
	velocity = dir * (220.0 if finisher else 120.0)
	_lunge_t = 0.06
	_VFX.slash(get_parent(), global_position + dir * 28.0, dir.angle())
	if finisher:
		_VFX.slash(get_parent(), global_position + dir * 40.0, dir.angle() + 0.5)
	for e in _enemies_in_arc(global_position, radius, dir, arc):
		land_slot_hit(e, _slot_dmg("attack", mult), "attack", finisher, 320.0 if finisher else 160.0)
	_flash_blade(dir, 0.12)


func _melee_cleave(dir: Vector2) -> void:
	var s := _slot("special")
	var lunge_time := 0.16
	_busy = 0.3
	velocity = dir * float(s.get("lunge", 150.0)) / lunge_time
	_lunge_t = lunge_time
	_VFX.dust_puff(get_parent(), global_position)
	await get_tree().create_timer(lunge_time).timeout
	if dead or not is_inside_tree():
		return
	velocity = Vector2.ZERO
	for off in [-0.8, 0.0, 0.8]:
		_VFX.slash(get_parent(), global_position + dir.rotated(off) * 44.0, dir.angle() + off)
	for e in _enemies_in_arc(global_position, float(s.get("radius", 82.0)), dir, float(s.get("arc", 2.2))):
		land_slot_hit(e, _slot_dmg("special", float(s.get("damage", 2.0))), "special", true, 360.0)
	_flash_blade(dir, 0.16)


func _melee_stake(dir: Vector2) -> void:
	var c := _slot("cast")
	_busy = 0.12
	_spawn_projectile(global_position, dir, _slot_dmg("cast", float(c.get("damage", 0.8))), "cast", "stake",
		false, float(c.get("speed", 640.0)), 0, Color(1.0, 0.25, 0.3))


func _flash_blade(dir: Vector2, seconds: float) -> void:
	blade_visual.visible = true
	blade_visual.rotation = dir.angle()
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(blade_visual):
		blade_visual.visible = false


# --- Mira: hybrid_gun --------------------------------------------------------

func _gun_rail(dir: Vector2) -> void:
	var a := _slot("attack")
	_busy = 0.08
	_spawn_projectile(global_position, dir, _slot_dmg("attack", float(a.get("damage", 1.8))), "attack", "rail",
		false, float(a.get("speed", 780.0)), int(a.get("pierce", 1)), Color(1.0, 0.95, 0.75))


func _gun_volley(dir: Vector2) -> void:
	var s := _slot("special")
	var bolts := int(s.get("bolts", 8))
	_busy = float(s.get("interval", 0.045)) * bolts
	for i in bolts:
		if dead or not is_inside_tree():
			return
		_spawn_projectile(global_position, dir.rotated(randf_range(-0.5, 0.5)),
			_slot_dmg("special", float(s.get("damage", 0.6))), "special", "", true, 420.0)
		await get_tree().create_timer(float(s.get("interval", 0.045))).timeout


func _gun_flare(dir: Vector2) -> void:
	var c := _slot("cast")
	_busy = 0.12
	var target := global_position + dir * float(c.get("range", 190.0))
	_spawn_zone(target, float(c.get("radius", 72.0)), _slot_dmg("cast", float(c.get("damage", 2.4))), "cast",
		float(c.get("fuse", 0.55)), 1, 0.25, 220.0, Color(1.0, 0.9, 0.55))


# --- Cassian: orbit ----------------------------------------------------------

func _home_crescent() -> int:
	for i in _crescents.size():
		if _crescents[i].mode == "home":
			return i
	return -1


func _update_orbit(delta: float) -> void:
	_orbit_angle += delta * 3.2
	var home_r := 54.0 if RunState.has_pact("house_veyra") else 42.0
	var a := _slot("attack")
	var speed := float(a.get("speed", 560.0))
	if _burst_t > 0.0:
		_burst_t -= delta
	var burst_time := float(_slot("special").get("time", 0.4))
	for i in _crescents.size():
		var c: Dictionary = _crescents[i]
		var spr: Sprite2D = c.node
		if not is_instance_valid(spr):
			continue
		var ang := _orbit_angle + TAU * float(i) / float(_crescents.size())
		match c.mode:
			"home":
				## Cosmetic only: a crescent at rest never deals damage.
				spr.position = Vector2(cos(ang), sin(ang)) * home_r
			"burst":
				var t := 1.0 - clampf(_burst_t / burst_time, 0.0, 1.0)
				var r := lerpf(home_r, float(_slot("special").get("radius", 120.0)), sin(t * PI))
				spr.position = Vector2(cos(ang * 2.0), sin(ang * 2.0)) * r
				_crescent_hits(c, spr.global_position, "special", float(_slot("special").get("damage", 1.3)))
				if _burst_t <= 0.0:
					c.mode = "home"
			"out":
				c.pos += c.dir * speed * delta
				c.dist += speed * delta
				spr.global_position = c.pos
				_crescent_hits(c, c.pos, "attack", float(a.get("damage", 1.2)))
				if c.dist >= float(a.get("range", 200.0)):
					c.mode = "back"
					c.hits = {}
			"back":
				c.pos = c.pos.move_toward(global_position, speed * 1.15 * delta)
				spr.global_position = c.pos
				_crescent_hits(c, c.pos, "attack", float(a.get("damage", 1.2)))
				if c.pos.distance_to(global_position) < 16.0:
					c.mode = "home"
		spr.rotation += delta * 14.0 if c.mode != "home" else 0.0


func _crescent_hits(c: Dictionary, pos: Vector2, slot: String, mult: float) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or c.hits.has(e.get_instance_id()):
			continue
		if pos.distance_to(e.global_position) < 24.0:
			c.hits[e.get_instance_id()] = true
			land_slot_hit(e, _slot_dmg(slot, mult), slot, false, 120.0)


func _orbit_throw(dir: Vector2) -> void:
	var i := _home_crescent()
	if i < 0:
		return
	var c: Dictionary = _crescents[i]
	c.mode = "out"
	c.pos = global_position + dir * 18.0
	c.dir = dir
	c.dist = 0.0
	c.hits = {}
	_busy = 0.08


func _orbit_burst() -> void:
	## Recall: thrown crescents snap home and every crescent spins out in a ring.
	_burst_t = float(_slot("special").get("time", 0.4))
	_busy = _burst_t
	for c in _crescents:
		c.mode = "burst"
		c.hits = {}


func _orbit_sigil(dir: Vector2) -> void:
	var c := _slot("cast")
	_busy = 0.12
	var life := float(c.get("life", 2.5))
	var interval := float(c.get("interval", 0.25))
	_spawn_zone(global_position + dir * float(c.get("range", 150.0)), float(c.get("radius", 56.0)),
		_slot_dmg("cast", float(c.get("damage", 0.35))), "cast", 0.0, int(life / interval), interval, 0.0,
		Color(0.6, 0.85, 1.0))


# --- Odette: maul ------------------------------------------------------------

func _maul_slam(dir: Vector2) -> void:
	var a := _slot("attack")
	var windup := float(a.get("windup", 0.18))
	_busy = windup + 0.1
	blade_visual.visible = true
	blade_visual.rotation = dir.angle()
	var wave := Polygon2D.new()
	wave.color = Color(0.6, 0.3, 0.25, 0.35)
	wave.polygon = PackedVector2Array([-10, -10, 70, -40, 70, 40, -10, 10])
	wave.rotation = dir.angle()
	add_child(wave)
	await get_tree().create_timer(windup).timeout
	if is_instance_valid(wave):
		wave.queue_free()
	if is_instance_valid(blade_visual):
		blade_visual.visible = false
	if dead or not is_inside_tree():
		return
	_VFX.dust_puff(get_parent(), global_position + dir * 40.0)
	for e in _enemies_in_arc(global_position, float(a.get("radius", 84.0)), dir, float(a.get("arc", 1.8))):
		land_slot_hit(e, _slot_dmg("attack", float(a.get("damage", 1.35))), "attack", true, 300.0)


func _maul_shockwave(dir: Vector2) -> void:
	var s := _slot("special")
	_busy = 0.22
	var spacing := float(s.get("spacing", 58.0))
	var interval := float(s.get("interval", 0.09))
	for i in int(s.get("steps", 4)):
		_spawn_zone(global_position + dir * spacing * float(i + 1), float(s.get("radius", 46.0)),
			_slot_dmg("special", float(s.get("damage", 1.0))), "special", 0.12 + interval * i, 1, 0.1, 240.0,
			Color(0.8, 0.45, 0.3))


func _maul_hook(dir: Vector2) -> void:
	var c := _slot("cast")
	_busy = 0.15
	_spawn_projectile(global_position, dir, _slot_dmg("cast", float(c.get("damage", 0.6))), "cast", "hook",
		false, float(c.get("speed", 560.0)), 0, Color(0.7, 0.7, 0.75))


# --- Vesper: astral ----------------------------------------------------------

func _update_astral(delta: float) -> void:
	if _project_t > 0.0:
		var total := float(_slot("cast").get("time", 0.22))
		_project_t -= delta
		var t := 1.0 - clampf(_project_t / total, 0.0, 1.0)
		_spirit_pos = _project_from.lerp(_project_to, t)
		var radius := float(_slot("cast").get("radius", 30.0))
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e) or _project_hits.has(e.get_instance_id()):
				continue
			if _spirit_pos.distance_to(e.global_position) < radius + 14.0:
				_project_hits[e.get_instance_id()] = true
				land_slot_hit(e, _slot_dmg("cast", float(_slot("cast").get("damage", 0.8))), "cast", false, 160.0)
	elif _anchor_t > 0.0:
		_anchor_t -= delta
	else:
		## Hovers at the leash point; moves, never strikes, on its own.
		var home := global_position + facing * float(_slot("attack").get("leash", 80.0))
		_spirit_pos = _spirit_pos.move_toward(home, 320.0 * delta)
	spirit_visual.global_position = _spirit_pos


func _astral_spike(dir: Vector2) -> void:
	var a := _slot("attack")
	_busy = 0.08
	var aim := dir
	var target := _nearest_enemy_from(_spirit_pos)
	if target and target.global_position.distance_to(_spirit_pos) <= float(a.get("seek_range", 280.0)):
		aim = (target.global_position - _spirit_pos).normalized()
	## Origin offset cancels _spawn_projectile's muzzle offset so the spike leaves the spirit.
	_spawn_projectile(_spirit_pos - aim * 18.0, aim, _slot_dmg("attack", float(a.get("damage", 1.0))),
		"attack", "", false, float(a.get("speed", 560.0)), int(a.get("pierce", 2)), Color(0.7, 0.85, 1.0))


func _astral_collapse() -> void:
	var s := _slot("special")
	_busy = 0.15
	var radius := float(s.get("radius", 100.0))
	for e in _enemies_in_arc(_spirit_pos, radius, Vector2.RIGHT):
		land_slot_hit(e, _slot_dmg("special", float(s.get("damage", 1.6))), "special", true, 260.0)
	var flash := Polygon2D.new()
	flash.color = Color(0.8, 0.9, 1.0, 0.4)
	flash.polygon = PackedVector2Array([-radius, -radius * 0.6, radius, -radius * 0.6, radius, radius * 0.6, -radius, radius * 0.6])
	get_parent().add_child(flash)
	flash.global_position = _spirit_pos
	## The spirit reforms at the body.
	_spirit_pos = global_position
	_anchor_t = 0.0
	_project_t = 0.0
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(flash):
		flash.queue_free()


func _astral_project(dir: Vector2) -> void:
	var c := _slot("cast")
	_busy = 0.1
	_project_from = _spirit_pos
	_project_to = global_position + dir * float(c.get("range", 230.0))
	_project_t = float(c.get("time", 0.22))
	_anchor_t = float(c.get("anchor", 3.0))
	_project_hits = {}


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


# --- Feed / damage taken -----------------------------------------------------

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


func apply_hit(amount: float, from: Vector2 = Vector2.ZERO) -> void:
	if dead:
		return
	if health.invuln_timer > 0.0:
		return
	if kit_type == "astral":
		amount *= 1.25
	amount = minf(amount, MAX_HIT)
	if amount <= 0.0:
		return
	health.take_damage(amount)
	health.set_invuln(HIT_IFRAME)
	RunState.note_hit(amount)
	var kb_dir := (global_position - from).normalized() if from != Vector2.ZERO else -facing
	if kb_dir.length() < 0.1:
		kb_dir = Vector2.RIGHT
	velocity = kb_dir * HIT_KNOCK
	_kb_timer = HIT_KNOCK_TIME
	_lunge_t = 0.0


func _on_damaged(_amount: float, remaining: float) -> void:
	if player_index == 0:
		RunState.player_hp = remaining
	if actor_visual:
		actor_visual.flash(Color(1.55, 0.45, 0.4), HIT_IFRAME)
	body_visual.modulate = Color(1.6, 0.45, 0.4)
	await get_tree().create_timer(HIT_IFRAME).timeout
	if is_instance_valid(body_visual) and not dead:
		body_visual.modulate = Color.WHITE


func _on_died() -> void:
	dead = true
	died.emit()

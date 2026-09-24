extends CharacterBody2D
class_name MWEnemy
const _VFX = preload("res://scripts/visuals/vfx.gd")
const _AFFIX = preload("res://scripts/combat/elite_affixes.gd")
## Base foe. Archetypes override `_ai_tick`. Human flag still gates feeding.

signal killed(is_human: bool)

@export var is_human: bool = false
@export var is_elite: bool = false
@export var max_hp: float = 40.0
@export var move_speed: float = 90.0
@export var contact_damage: float = 10.0
@export var xp_color: Color = Color(0.55, 0.2, 0.22)

@onready var visual: CanvasItem = $Visual
@onready var health: Health = $Health
@onready var corpse_area: Area2D = $CorpseArea
@onready var actor_visual: Node2D = $ActorVisual

const WINDUP := 0.38
const ATTACK_RANGE := 28.0
const STRIKE_RANGE := 34.0

var archetype: String = "melee"
var family_id: String = ""
var affix_id: String = ""
var affix_name: String = ""
var affix_color: Color = Color(0.7, 0.2, 0.7)
var affix_speed: float = 1.0
var affix_damage: float = 1.0
var affix_incoming: float = 1.0
var _player: Node2D
var _alive: bool = true
var _corpse: bool = false
var _attack_cd: float = 0.0
var enemy_sprite: String = "dominion_grub"
var _winding: bool = false
var _windup: float = 0.0
var _wind_t: float = 0.0
var _stagger: float = 0.0
var _knock: Vector2 = Vector2.ZERO
var _spawn_lock: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _haste: float = 0.0
var _haste_mult: float = 1.0
var _affix_wind: float = 0.0
var _void_cd: float = 2.4
var _aura: Polygon2D
var _affix_label: Label
var _tether: Line2D
var _family_sprite: String = ""


func _ready() -> void:
	add_to_group("enemy")
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	corpse_area.monitoring = false
	corpse_area.monitorable = false
	_apply_role_visuals()


func setup(player: Node2D, human: bool = false, elite: bool = false) -> void:
	setup_family(player, {}, human, elite)


func setup_family(player: Node2D, family: Dictionary, human: bool, elite: bool) -> void:
	_player = player
	is_human = human
	is_elite = elite
	if not family.is_empty():
		archetype = str(family.get("archetype", archetype))
		family_id = str(family.get("id", family_id))
		_family_sprite = str(family.get("sprite", ""))
		if family.has("human"):
			is_human = bool(family["human"])
	if is_elite and affix_id.is_empty():
		apply_affix_def(_AFFIX.def(_AFFIX.roll()))
	if is_node_ready():
		_apply_role_visuals()


func apply_affix_def(d: Dictionary) -> void:
	affix_id = str(d.get("id", ""))
	affix_name = str(d.get("name", affix_id.capitalize()))
	affix_color = d.get("color", affix_color)
	affix_speed = float(d.get("speed_mult", 1.0))
	affix_damage = float(d.get("damage_mult", 1.0))
	affix_incoming = float(d.get("incoming_mult", 1.0))
	if health:
		health.incoming_mult = affix_incoming


func _scaled_hp() -> float:
	var elite_m := 1.6 if is_elite else 1.0
	var diff := GameState.difficulty_enemy_mult() if GameState else 1.0
	return max_hp * elite_m * diff


func begin_spawn_telegraph(seconds: float = 0.45) -> void:
	_spawn_lock = seconds
	modulate.a = 0.5
	if actor_visual:
		actor_visual.flash(Color(1.7, 0.75, 0.3), seconds)
	_VFX.telegraph_mark(get_parent(), global_position, seconds, Vector2(1.1, 1.1))


func apply_stagger(from: Vector2, force: float = 200.0) -> void:
	if not _alive:
		return
	_winding = false
	_windup = 0.0
	_affix_wind = 0.0
	_on_attack_cancelled()
	_stagger = 0.22
	var dir := (global_position - from).normalized()
	if dir.length() < 0.1:
		dir = Vector2.RIGHT
	_knock = dir * force
	if actor_visual:
		actor_visual.flash(Color(1.4, 1.2, 0.9), 0.12)


func apply_haste(seconds: float, mult: float = 1.2) -> void:
	if not _alive:
		return
	_haste = maxf(_haste, seconds)
	_haste_mult = maxf(_haste_mult, mult)


func _on_attack_cancelled() -> void:
	pass


func _apply_role_visuals() -> void:
	var hp := _scaled_hp()
	health.max_hp = hp
	health.hp = hp
	health.incoming_mult = affix_incoming
	_base_scale = Vector2(1.35, 1.35) if is_elite else Vector2.ONE
	scale = _base_scale
	if _family_sprite != "":
		enemy_sprite = _family_sprite
	elif is_human:
		enemy_sprite = "church_zealot" if RunState.sector_id in ["salt_choir", "pale_spire"] else "human_enforcer"
	else:
		match RunState.sector_id:
			"gloampine", "iron_orchard":
				enemy_sprite = "beast_hound"
			"noir_cathedral", "umbral_marches", "pale_spire":
				enemy_sprite = "void_wretch"
			_:
				enemy_sprite = "dominion_grub"
	if actor_visual:
		actor_visual.load_sprite("enemies", enemy_sprite)
	if visual is Polygon2D:
		if is_human:
			(visual as Polygon2D).color = Color(0.62, 0.48, 0.4)
		elif is_elite:
			(visual as Polygon2D).color = affix_color
		else:
			(visual as Polygon2D).color = xp_color
	if is_elite:
		_build_affix_aura()


func _build_affix_aura() -> void:
	if _aura == null:
		_aura = Polygon2D.new()
		_aura.z_index = -3
		var pts := PackedVector2Array()
		for i in 16:
			var a := TAU * float(i) / 16.0
			pts.append(Vector2(cos(a), sin(a)) * 26.0)
		_aura.polygon = pts
		add_child(_aura)
	_aura.color = Color(affix_color.r, affix_color.g, affix_color.b, 0.38)
	if _affix_label == null:
		_affix_label = Label.new()
		_affix_label.position = Vector2(-46, -52)
		_affix_label.size = Vector2(92, 16)
		_affix_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_affix_label.add_theme_font_size_override("font_size", 11)
		_affix_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		_affix_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_affix_label.add_theme_constant_override("outline_size", 4)
		add_child(_affix_label)
	_affix_label.text = "ELITE · %s" % (affix_name if affix_name != "" else "Elite")
	_affix_label.modulate = affix_color.lightened(0.25)
	if affix_id == "blood_linked" and _tether == null:
		_tether = Line2D.new()
		_tether.width = 2.0
		_tether.default_color = Color(0.85, 0.18, 0.28, 0.55)
		_tether.z_index = -2
		add_child(_tether)


func current_move_speed() -> float:
	var human_m := 0.85 if is_human else 1.0
	var haste := _haste_mult if _haste > 0.0 else 1.0
	return move_speed * affix_speed * haste * human_m


func strike_damage() -> float:
	var elite_m := 1.4 if is_elite else 1.0
	return contact_damage * elite_m * affix_damage


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	if _haste > 0.0:
		_haste -= delta
		if _haste <= 0.0:
			_haste_mult = 1.0
	if _spawn_lock > 0.0:
		_spawn_lock -= delta
		if _spawn_lock <= 0.0:
			modulate.a = 1.0
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if _stagger > 0.0:
		_stagger -= delta
		velocity = _knock
		_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
		scale = _base_scale
		move_and_slide()
		return
	_ensure_target()
	if _tick_affix(delta):
		return
	_ai_tick(delta)


func _ensure_target() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = get_tree().get_first_node_in_group("player") as Node2D


func _tick_affix(delta: float) -> bool:
	if _aura:
		_aura.modulate.a = 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.007)
	if affix_id == "blood_linked":
		_update_blood_tether()
	if affix_id != "void_pull":
		return false
	if _affix_wind > 0.0:
		_affix_wind -= delta
		_wind_t += delta
		scale = _base_scale * (1.0 + 0.12 * sin(_wind_t * 18.0))
		velocity = Vector2.ZERO
		move_and_slide()
		if _affix_wind <= 0.0:
			scale = _base_scale
			_do_void_pull()
		return true
	_void_cd -= delta
	if _void_cd <= 0.0 and _player != null and is_instance_valid(_player):
		if global_position.distance_to(_player.global_position) < 240.0:
			_void_cd = 3.2
			_affix_wind = 0.42
			_wind_t = 0.0
			if actor_visual:
				actor_visual.flash(affix_color, 0.42)
			_VFX.telegraph_mark(get_parent(), _player.global_position, 0.42, Vector2(1.05, 1.05))
			return true
	return false


func _do_void_pull() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p):
			continue
		var n := p as Node2D
		if n.global_position.distance_to(global_position) > 260.0:
			continue
		var dir := (global_position - n.global_position)
		if dir.length() < 8.0:
			continue
		n.global_position += dir.normalized() * 52.0


func _nearest_blood_link() -> Node2D:
	var best: Node2D = null
	var best_d := 220.0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not is_instance_valid(e):
			continue
		if str(e.get("affix_id")) != "blood_linked":
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _update_blood_tether() -> void:
	if _tether == null:
		return
	var other := _nearest_blood_link()
	if other == null:
		_tether.points = PackedVector2Array()
		return
	_tether.points = PackedVector2Array([Vector2.ZERO, to_local(other.global_position)])


func _ai_tick(delta: float) -> void:
	## Default melee chaser (used when the scene is instanced without a subclass).
	if _player == null:
		return
	var dir := (_player.global_position - global_position)
	var dist := dir.length()
	if _winding:
		_windup -= delta
		_wind_t += delta
		scale = _base_scale * (1.0 + 0.14 * sin(_wind_t * 20.0))
		velocity = Vector2.ZERO
		move_and_slide()
		if _windup <= 0.0:
			_winding = false
			scale = _base_scale
			_attack_cd = 0.7
			_melee_strike(dist)
		return
	_chase(dir, current_move_speed())
	_attack_cd -= delta
	if dist < ATTACK_RANGE and _attack_cd <= 0.0:
		_start_windup()


func _chase(dir: Vector2, spd: float) -> void:
	if dir.length() > 4.0:
		velocity = dir.normalized() * spd
	else:
		velocity = Vector2.ZERO
	_face_move(dir)
	move_and_slide()


func _keep_range(dir: Vector2, dist: float, want: float, band: float, spd: float) -> void:
	if dist > want + band:
		velocity = dir.normalized() * spd
	elif dist < want - band:
		velocity = -dir.normalized() * spd * 0.85
	else:
		velocity = dir.normalized().orthogonal() * spd * 0.35
	_face_move(dir)
	move_and_slide()


func _face_move(dir: Vector2) -> void:
	if actor_visual:
		actor_visual.set_running(velocity.length() > current_move_speed() * 0.85)
		actor_visual.set_moving(velocity.length() > 4.0)
		actor_visual.set_facing_x(dir.x)


func _start_windup(seconds: float = WINDUP, tint: Color = Color(1.55, 0.55, 0.25), mark_off: Vector2 = Vector2(0, 18), mark_scl: Vector2 = Vector2(0.85, 0.55)) -> void:
	_winding = true
	_windup = seconds
	_wind_t = 0.0
	if actor_visual:
		actor_visual.flash(tint, seconds)
	_VFX.telegraph_mark(get_parent(), global_position + mark_off, seconds, mark_scl)


func _melee_strike(dist: float) -> void:
	if dist < STRIKE_RANGE and _player != null and _player.has_method("apply_hit"):
		if actor_visual:
			actor_visual.play_oneshot("attack", 12.0)
		_player.apply_hit(strike_damage(), global_position)


func _on_damaged(amount: float, _remaining: float) -> void:
	if actor_visual:
		actor_visual.flash(Color(1.3, 1.1, 0.9), 0.08)
	if affix_id == "blood_linked" and amount > 0.0:
		var other := _nearest_blood_link()
		if other != null:
			var h: Health = other.get_node_or_null("Health")
			if h:
				h.heal(amount * 0.22)


func _on_died() -> void:
	if not _alive:
		return
	_alive = false
	velocity = Vector2.ZERO
	set_physics_process(false)
	_VFX.blood(get_parent(), global_position)
	killed.emit(is_human)
	RunState.register_kill(is_human)
	remove_from_group("enemy")
	if is_human:
		_become_corpse()
	else:
		queue_free()


func _become_corpse() -> void:
	_corpse = true
	add_to_group("feedable_corpse")
	if _aura:
		_aura.visible = false
	if _affix_label:
		_affix_label.visible = false
	if _tether:
		_tether.visible = false
	if actor_visual:
		actor_visual.modulate = Color(0.45, 0.15, 0.15, 0.85)
		actor_visual.scale = Vector2(1.0, 0.55)
	if visual is Polygon2D:
		(visual as Polygon2D).color = Color(0.35, 0.12, 0.14)
		visual.scale = Vector2(1.0, 0.55)
	corpse_area.monitoring = true
	corpse_area.monitorable = true
	await get_tree().create_timer(12.0).timeout
	if is_instance_valid(self) and _corpse:
		queue_free()


func consume() -> void:
	queue_free()

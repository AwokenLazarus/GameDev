extends CharacterBody2D
const _VFX = preload("res://scripts/visuals/vfx.gd")
const _ZONE = preload("res://scripts/combat/hazard_zone.gd")
## Sector general / Aurelian. HP-threshold phases from SectorDB `phases`; each phase has a
## telegraphed move rotation plus optional adds (MWEnemyFactory) and arena hazards.
## Telegraph rule (MW-022): wind-up >= TELEGRAPH_MIN, no damage during wind-up, one hit per player per move.

signal defeated
signal phase_changed(index: int, title: String)

@export var general_id: String = "marshal_hale"
@export var display_name: String = "General"
@export var title: String = ""
@export var max_hp: float = 520.0
@export var move_speed: float = 130.0
@export var color: Color = Color(0.45, 0.38, 0.32)
@export var pattern: String = "charge" ## legacy single-pattern id; used when a general has no `phases`

@onready var visual: CanvasItem = $Visual
@onready var health: Health = $Health
@onready var telegraph: CanvasItem = $Telegraph
@onready var badge: CanvasItem = $Badge
@onready var actor_visual: Node2D = $ActorVisual
@onready var nameplate: Label = $Nameplate

const CONTACT_DMG := 12.0
const CONTACT_CD := 0.55
const TELEGRAPH_MIN := 0.42
const TELE_COLOR := Color(0.95, 0.22, 0.16, 0.42)
const TELE_RING := Color(1.0, 0.45, 0.3, 0.8)
const SHIFT_PAUSE := 1.1

var phases: Array = []
var phase_index: int = 0
var phase_title: String = ""
var _player: Node2D
var _cd: float = 2.0
var _busy: bool = false
var _alive: bool = true
var _contact_cd: Dictionary = {} ## instance_id -> remaining
var _move_i: int = 0
var _adds_cd: float = 0.0
var _hazard_cd: float = 0.0
var _winding: bool = false
var _sabotaged: bool = false ## Sabotage Manifest: the current move lands nothing

const PROJ := preload("res://scenes/entities/projectile.tscn")


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	_apply_def()
	health.max_hp = max_hp * GameState.difficulty_enemy_mult()
	health.hp = health.max_hp
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	telegraph.visible = false
	if telegraph is Sprite2D:
		var tp := "res://assets/textures/vfx/telegraph.png"
		if ResourceLoader.exists(tp):
			(telegraph as Sprite2D).texture = load(tp)
	if visual is Polygon2D:
		(visual as Polygon2D).color = color
	if actor_visual:
		actor_visual.load_sprite("generals", general_id)
	if nameplate:
		nameplate.text = display_name


func _apply_def() -> void:
	if general_id == "" or SectorDB == null:
		return
	var g: Dictionary = SectorDB.get_general(general_id)
	if g.is_empty():
		return
	display_name = str(g.get("name", display_name))
	title = str(g.get("title", title))
	max_hp = float(g.get("max_hp", max_hp))
	move_speed = float(g.get("move_speed", move_speed))
	color = g.get("color", color)
	pattern = str(g.get("pattern", pattern))
	phases = g.get("phases", [])
	if phases.is_empty():
		phases = [{"title": display_name, "moves": [pattern]}]
	phase_index = 0
	phase_title = str((phases[0] as Dictionary).get("title", ""))
	_move_i = 0


func configure(gid: String) -> void:
	general_id = gid
	if is_node_ready():
		_apply_def()
		if visual is Polygon2D:
			(visual as Polygon2D).color = color
		if actor_visual:
			actor_visual.load_sprite("generals", general_id)
		if nameplate:
			nameplate.text = display_name
		health.max_hp = max_hp * GameState.difficulty_enemy_mult()
		health.hp = health.max_hp


func phase_count() -> int:
	return phases.size()


func hp_frac() -> float:
	return health.hp / maxf(health.max_hp, 1.0)


func _phase() -> Dictionary:
	return phases[phase_index] if phase_index < phases.size() else {}


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	_tick_phase_timers(delta)
	if _busy:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	var dir := (_player.global_position - global_position).normalized()
	var st := MWBoonStatus.peek(self)
	velocity = dir * move_speed * float(_phase().get("speed", 1.0)) * (st.move_mult() if st else 1.0)
	if actor_visual:
		actor_visual.set_running(true)
		actor_visual.set_moving(true)
		actor_visual.set_facing_x(dir.x)
	move_and_slide()
	_tick_contact(delta)
	_cd -= delta
	if _cd <= 0.0:
		var lost := clampf(1.0 - hp_frac(), 0.0, 1.0)
		_cd = (2.5 - 0.6 * lost) * float(_phase().get("cd", 1.0))
		_use_next_move()


func _tick_contact(delta: float) -> void:
	for id in _contact_cd.keys():
		_contact_cd[id] = float(_contact_cd[id]) - delta
		if float(_contact_cd[id]) <= 0.0:
			_contact_cd.erase(id)
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or not p.has_method("apply_hit"):
			continue
		if global_position.distance_to(p.global_position) >= 32.0:
			continue
		var id := p.get_instance_id()
		if _contact_cd.has(id):
			continue
		p.apply_hit(CONTACT_DMG, global_position)
		_contact_cd[id] = CONTACT_CD


func apply_stagger(from: Vector2, force: float = 90.0) -> void:
	if not _alive or _busy:
		return
	var dir := (global_position - from).normalized()
	if dir.length() < 0.1:
		dir = Vector2.RIGHT
	velocity = dir * force
	if actor_visual:
		actor_visual.flash(Color(1.3, 1.15, 0.85), 0.1)


# --- Phases ---------------------------------------------------------------

func _on_damaged(_amount: float, _remaining: float) -> void:
	if not _alive:
		return
	while phase_index + 1 < phases.size() and hp_frac() <= float((phases[phase_index + 1] as Dictionary).get("at", 0.0)):
		_enter_phase(phase_index + 1)


func _enter_phase(i: int) -> void:
	phase_index = i
	var ph := _phase()
	phase_title = str(ph.get("title", "Phase %d" % (i + 1)))
	_move_i = 0
	## Roar: a readable beat before the new rotation, not an invuln window (autoplay keeps hitting).
	_cd = maxf(_cd, SHIFT_PAUSE)
	if actor_visual:
		actor_visual.flash(Color(1.6, 0.35, 0.3), 0.5)
	_VFX.telegraph_mark(get_parent(), global_position, 0.6, Vector2(2.2, 2.2))
	print("BOSS_PHASE general=%s phase=%d title=%s" % [general_id, i + 1, phase_title])
	phase_changed.emit(i, phase_title)
	var adds: Dictionary = ph.get("adds", {})
	if not adds.is_empty():
		_spawn_adds(adds)
		_adds_cd = float(adds.get("every", 0.0))
	var hz: Dictionary = ph.get("hazard", {})
	if not hz.is_empty():
		_hazard_cd = 1.5


func _tick_phase_timers(delta: float) -> void:
	var ph := _phase()
	var adds: Dictionary = ph.get("adds", {})
	if not adds.is_empty() and float(adds.get("every", 0.0)) > 0.0:
		_adds_cd -= delta
		if _adds_cd <= 0.0:
			_adds_cd = float(adds["every"])
			_spawn_adds(adds)
	var hz: Dictionary = ph.get("hazard", {})
	if not hz.is_empty():
		_hazard_cd -= delta
		if _hazard_cd <= 0.0:
			_hazard_cd = float(hz.get("every", 7.0))
			_drop_hazards(hz)


func _spawn_adds(adds: Dictionary) -> void:
	var parent := get_parent()
	if parent == null or _player == null or not is_instance_valid(_player):
		return
	var alive := get_tree().get_nodes_in_group("boss_add").size()
	## Co-op: one extra add per extra player, same cap bump.
	var extra := maxi(RunState.player_count - 1, 0)
	var cap := int(adds.get("cap", 3)) + extra
	var n := mini(int(adds.get("count", 2)) + extra, cap - alive)
	var archs: Array = adds.get("archetypes", ["melee"])
	for k in n:
		var a := TAU * float(k) / float(maxi(n, 1)) + randf() * 0.6
		var pos := global_position + Vector2(cos(a), sin(a)) * 90.0
		var e := MWEnemyFactory.spawn(parent, pos, _player, {
			"archetype": str(archs[k % archs.size()]),
			"elite": bool(adds.get("elite", false)),
			"telegraph_s": 0.6,
		})
		e.add_to_group("boss_add")


func _drop_hazards(hz: Dictionary) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var n := int(hz.get("count", 2))
	for k in n:
		var pos := _player.global_position + Vector2(randf_range(-120, 120), randf_range(-90, 90))
		if k == 0:
			pos = _player.global_position
		_delayed_zone(pos, str(hz.get("kind", "void")), float(hz.get("life", 3.5)), float(hz.get("dmg", 8.0)))


func _delayed_zone(pos: Vector2, kind: String, life: float, dmg: float) -> void:
	## Hazard zones pulse on their first frame, so the telegraph must come first.
	var parent := get_parent()
	_tele_circle(pos, 54.0, 0.7)
	await get_tree().create_timer(0.7).timeout
	if not is_instance_valid(parent):
		return
	var z: Node2D = _ZONE.new()
	parent.add_child(z)
	z.setup(pos, kind, life, dmg)


# --- Move rotation --------------------------------------------------------

func _use_next_move() -> void:
	var moves: Array = _phase().get("moves", [pattern])
	if moves.is_empty():
		moves = [pattern]
	var id := str(moves[_move_i % moves.size()])
	_move_i += 1
	if actor_visual:
		actor_visual.play_oneshot("attack", 12.0)
	_busy = true
	await _run_move(id)
	_busy = false
	if _sabotaged:
		_sabotaged = false
		_cd = maxf(_cd, 1.2)


func _run_move(id: String) -> void:
	match id:
		"charge":
			await _mv_charge()
		"charge_chain", "fleet":
			await _mv_charge_chain(3 if id == "fleet" else 2)
		"volley":
			await _mv_volley()
		"slam":
			await _mv_slam()
		"barrage":
			await _mv_barrage()
		"leap":
			await _mv_leap()
		"hymn":
			await _mv_hymn()
		"thorns":
			await _mv_thorns()
		"void":
			await _mv_void()
		"gallows":
			await _mv_gallows()
		"furnace_lines":
			await _mv_furnace_lines()
		"pack_pounce":
			await _mv_pack_pounce()
		"judgment_pillars":
			await _mv_judgment_pillars()
		"blight_bloom":
			await _mv_blight_bloom()
		"eclipse_step":
			await _mv_eclipse_step()
		"broadside":
			await _mv_broadside()
		"sun_lance":
			await _mv_sun_lance()
		"moonfall":
			await _mv_moonfall()
		_:
			await _mv_charge()


# --- Telegraph + hit helpers ---------------------------------------------

func _circle_pts(radius: float, n: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


func _tele_node(pos: Vector2, shape: PackedVector2Array, seconds: float, rot: float = 0.0, grow_x_only: bool = false) -> void:
	## Ground marker: faint outline of the exact hit shape, fill grows to full at impact.
	var parent := get_parent()
	if parent == null:
		return
	var root := Node2D.new()
	root.z_index = -3
	parent.add_child(root)
	root.global_position = pos
	root.rotation = rot
	var outline := Polygon2D.new()
	outline.polygon = shape
	outline.color = Color(TELE_COLOR, 0.16)
	root.add_child(outline)
	var edge := Line2D.new()
	var closed := shape.duplicate()
	closed.append(shape[0])
	edge.points = closed
	edge.width = 2.0
	edge.default_color = TELE_RING
	root.add_child(edge)
	var fill := Polygon2D.new()
	fill.polygon = shape
	fill.color = TELE_COLOR
	fill.scale = Vector2(0.0, 1.0) if grow_x_only else Vector2.ZERO
	root.add_child(fill)
	var tw := root.create_tween()
	tw.tween_property(fill, "scale", Vector2.ONE, seconds)
	tw.tween_callback(root.queue_free)


func _tele_circle(pos: Vector2, radius: float, seconds: float) -> void:
	_tele_node(pos, _circle_pts(radius), seconds)


func _tele_lane(from: Vector2, dir: Vector2, length: float, width: float, seconds: float) -> void:
	var hw := width * 0.5
	var shape := PackedVector2Array([Vector2(0, -hw), Vector2(length, -hw), Vector2(length, hw), Vector2(0, hw)])
	_tele_node(from, shape, seconds, dir.angle(), true)


func _players() -> Array:
	var out: Array = []
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.has_method("apply_hit"):
			out.append(p)
	return out


func _hit_circle(pos: Vector2, radius: float, dmg: float, hit_ids: Dictionary = {}) -> void:
	if _sabotaged:
		return
	for p in _players():
		var id: int = p.get_instance_id()
		if hit_ids.has(id) or pos.distance_to(p.global_position) > radius:
			continue
		hit_ids[id] = true
		p.apply_hit(dmg, pos)


func _hit_lane(from: Vector2, dir: Vector2, length: float, width: float, dmg: float, hit_ids: Dictionary = {}) -> void:
	if _sabotaged:
		return
	for p in _players():
		var id: int = p.get_instance_id()
		if hit_ids.has(id):
			continue
		var rel: Vector2 = p.global_position - from
		var along := rel.dot(dir)
		if along < 0.0 or along > length or absf(rel.cross(dir)) > width * 0.5:
			continue
		hit_ids[id] = true
		p.apply_hit(dmg, from)


func _windup(seconds: float) -> void:
	if actor_visual:
		actor_visual.flash(Color(1.4, 0.45, 0.25), seconds)
	_winding = true
	await get_tree().create_timer(maxf(seconds, TELEGRAPH_MIN)).timeout
	_winding = false


func is_winding() -> bool:
	return _alive and _winding


## Sabotage Manifest (MW-006): a hit mid wind-up cancels the telegraphed move's damage.
func sabotage(_seconds: float) -> void:
	if not is_winding():
		return
	_sabotaged = true
	if actor_visual:
		actor_visual.flash(Color(1.6, 0.55, 0.35), 0.3)


func _target_pos() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return global_position
	return _player.global_position


func _shoot(dir: Vector2, dmg: float, spd: float, tint: Color) -> void:
	if _sabotaged:
		return
	var p: Node = PROJ.instantiate()
	get_parent().add_child(p)
	p.setup(global_position, dir, dmg * GameState.difficulty_enemy_mult(), self, false, spd)
	p.visual.modulate = tint
	if p.has_method("make_hostile"):
		p.make_hostile()


# --- Shared moves ---------------------------------------------------------

func _mv_charge() -> void:
	var dir := (_target_pos() - global_position).normalized()
	if dir.length() < 0.1:
		dir = Vector2.RIGHT
	const LEN := 210.0
	_tele_lane(global_position, dir, LEN, 44.0, 0.45)
	await _windup(0.45)
	if not _alive:
		return
	var hit_ids: Dictionary = {}
	velocity = dir * 380.0
	var t := 0.0
	while t < 0.55 and _alive:
		move_and_slide()
		_hit_circle(global_position, 30.0, 22.0, hit_ids)
		t += get_physics_process_delta_time()
		await get_tree().physics_frame


func _mv_charge_chain(n: int) -> void:
	for i in n:
		if not _alive:
			return
		await _mv_charge()
		await get_tree().create_timer(0.15).timeout


func _mv_volley() -> void:
	## Aimed fan; the five lanes are drawn so the gaps are readable.
	var aim := (_target_pos() - global_position).normalized()
	for k in 5:
		_tele_lane(global_position, aim.rotated((k - 2) * 0.22), 150.0, 10.0, 0.5)
	await _windup(0.5)
	if not _alive:
		return
	for k in 5:
		_shoot(aim.rotated((k - 2) * 0.22), 12.0, 340.0, Color(0.95, 0.75, 0.35))


func _mv_slam() -> void:
	const R := 95.0
	_tele_circle(global_position, R, 0.6)
	await _windup(0.6)
	if not _alive:
		return
	_VFX.dust_puff(get_parent(), global_position)
	_hit_circle(global_position, R, 24.0)


func _mv_barrage() -> void:
	_tele_circle(global_position, 40.0, TELEGRAPH_MIN)
	await _windup(TELEGRAPH_MIN)
	for i in 8:
		if not _alive or _player == null:
			return
		var dir := (_target_pos() - global_position).normalized().rotated(randf_range(-0.3, 0.3))
		_shoot(dir, 12.0, 360.0, Color(0.9, 0.4, 0.2))
		await get_tree().create_timer(0.08).timeout


func _mv_leap() -> void:
	var land := _target_pos()
	_tele_circle(land, 70.0, 0.55)
	await _windup(0.55)
	if not _alive:
		return
	global_position = land
	_VFX.dust_puff(get_parent(), land)
	_hit_circle(land, 70.0, 28.0)


func _mv_hymn() -> void:
	visual.modulate = Color(1.2, 1.1, 0.8)
	_tele_circle(global_position, 140.0, 0.55)
	await _windup(0.55)
	if _alive:
		health.heal(health.max_hp * 0.04)
		_hit_circle(global_position, 140.0, 18.0)
	await get_tree().create_timer(0.2).timeout
	visual.modulate = Color.WHITE


func _mv_thorns() -> void:
	for i in 12:
		_tele_lane(global_position, Vector2.from_angle(TAU * float(i) / 12.0), 90.0, 8.0, TELEGRAPH_MIN)
	await _windup(TELEGRAPH_MIN)
	if not _alive:
		return
	for i in 12:
		_shoot(Vector2.from_angle(TAU * float(i) / 12.0), 10.0, 280.0, Color(0.4, 0.7, 0.3))
	await get_tree().create_timer(0.2).timeout


func _mv_void() -> void:
	const R := 100.0
	_tele_circle(global_position, R, 0.5)
	await _windup(0.5)
	if not _alive:
		return
	## Pull is capped so it never drags a player past the centre.
	for e in get_tree().get_nodes_in_group("player"):
		var to_me: Vector2 = global_position - (e as Node2D).global_position
		(e as Node2D).global_position += to_me.normalized() * minf(90.0, to_me.length() * 0.6)
	_tele_circle(global_position, R, 0.25)
	await get_tree().create_timer(0.25).timeout
	if _alive:
		_hit_circle(global_position, R, 26.0)


# --- Signature phase-2 moves ---------------------------------------------

func _mv_gallows() -> void:
	## Hale: nooses drop on the player and two flanks, then a second row where they dodged to.
	for wave in 2:
		var c := _target_pos()
		var spots := [c, c + Vector2(-80, 30), c + Vector2(80, 30)]
		for s in spots:
			_tele_circle(s, 44.0, 0.7)
		await _windup(0.7)
		if not _alive:
			return
		var hit_ids: Dictionary = {}
		for s in spots:
			_VFX.dust_puff(get_parent(), s)
			_hit_circle(s, 44.0, 20.0, hit_ids)
		await get_tree().create_timer(0.25).timeout


func _mv_furnace_lines() -> void:
	## Sable Veyra: three parallel furnace lanes toward the player; the middle one leaves slag.
	var dir := (_target_pos() - global_position).normalized()
	var side := dir.orthogonal()
	const LEN := 320.0
	for k in [-1, 0, 1]:
		_tele_lane(global_position + side * 70.0 * k - dir * 20.0, dir, LEN, 40.0, 0.65)
	await _windup(0.65)
	if not _alive:
		return
	var hit_ids: Dictionary = {}
	for k in [-1, 0, 1]:
		_hit_lane(global_position + side * 70.0 * k - dir * 20.0, dir, LEN, 40.0, 22.0, hit_ids)
	_delayed_zone(global_position + dir * LEN * 0.6, "void", 3.0, 8.0)


func _mv_pack_pounce() -> void:
	## Marrowfang: three short pounces, each re-aimed, the last one wider.
	for k in 3:
		var land := _target_pos()
		var r := 60.0 if k < 2 else 90.0
		_tele_circle(land, r, 0.5)
		await _windup(0.5)
		if not _alive:
			return
		global_position = land
		_VFX.dust_puff(get_parent(), land)
		_hit_circle(land, r, 20.0 if k < 2 else 26.0)
		await get_tree().create_timer(0.15).timeout


func _mv_judgment_pillars() -> void:
	## Cantor Belis: a cross of light pillars on the player, then the diagonals.
	var c := _target_pos()
	for pass_i in 2:
		var offs := [Vector2.ZERO, Vector2(90, 0), Vector2(-90, 0), Vector2(0, 90), Vector2(0, -90)]
		if pass_i == 1:
			offs = [Vector2(70, 70), Vector2(-70, 70), Vector2(70, -70), Vector2(-70, -70)]
		for o in offs:
			_tele_circle(c + o, 38.0, 0.6)
		await _windup(0.6)
		if not _alive:
			return
		var hit_ids: Dictionary = {}
		for o in offs:
			_hit_circle(c + o, 38.0, 22.0, hit_ids)
		await get_tree().create_timer(0.1).timeout


func _mv_blight_bloom() -> void:
	## Provost Rhea: a ring of thorns, then blight patches bloom where the thorns land.
	await _mv_thorns()
	if not _alive:
		return
	for k in 3:
		var a := randf() * TAU
		_delayed_zone(global_position + Vector2(cos(a), sin(a)) * randf_range(90, 170), "void", 3.5, 7.0)


func _mv_eclipse_step() -> void:
	## Orlokis / Aurelian: blink behind the player and cut a crescent.
	var p := _target_pos()
	var face := (p - global_position).normalized()
	if face.length() < 0.1:
		face = Vector2.RIGHT
	var behind := p + face * 70.0
	_tele_circle(behind, 22.0, 0.45)
	await _windup(0.45)
	if not _alive:
		return
	global_position = behind
	var dir := (_target_pos() - global_position).normalized()
	if dir.length() < 0.1:
		dir = -face
	_tele_lane(global_position, dir, 110.0, 70.0, 0.4)
	await _windup(0.4)
	if not _alive:
		return
	_VFX.slash(get_parent(), global_position + dir * 40.0, dir.angle())
	_hit_lane(global_position, dir, 110.0, 70.0, 24.0)


func _mv_broadside() -> void:
	## Admiral Drus: the fleet shells a line across the player, left to right.
	var c := _target_pos()
	var hit_ids: Dictionary = {}
	var spots: Array = []
	for k in 6:
		spots.append(c + Vector2(-200 + 80 * k, randf_range(-20, 20)))
		_tele_circle(spots[k], 48.0, 0.6 + 0.08 * k)
	await _windup(0.6)
	for s in spots:
		if not _alive:
			return
		_VFX.dust_puff(get_parent(), s)
		_hit_circle(s, 48.0, 22.0, hit_ids)
		await get_tree().create_timer(0.08).timeout


func _mv_sun_lance() -> void:
	## Aurelian: three long lances aimed through the player, staggered.
	for k in 3:
		var dir := (_target_pos() - global_position).normalized().rotated((k - 1) * 0.35)
		_tele_lane(global_position, dir, 420.0, 30.0, 0.5 + 0.15 * k)
	var base := global_position
	var aim := (_target_pos() - base).normalized()
	await _windup(0.5)
	var hit_ids: Dictionary = {}
	for k in 3:
		if not _alive:
			return
		_hit_lane(base, aim.rotated((k - 1) * 0.35), 420.0, 30.0, 22.0, hit_ids)
		await get_tree().create_timer(0.15).timeout


func _mv_moonfall() -> void:
	## Aurelian phase 3: two rings of moon shards close in, then the centre falls.
	var c := _target_pos()
	for ring in [170.0, 90.0, 0.0]:
		var spots: Array = [c]
		if ring > 0.0:
			spots.clear()
			for k in 8:
				spots.append(c + Vector2.from_angle(TAU * k / 8.0 + ring * 0.01) * ring)
		for s in spots:
			_tele_circle(s, 48.0, 0.6)
		await _windup(0.6)
		if not _alive:
			return
		var hit_ids: Dictionary = {}
		for s in spots:
			_hit_circle(s, 48.0, 22.0, hit_ids)
		await get_tree().create_timer(0.15).timeout


func _on_died() -> void:
	if not _alive:
		return
	_alive = false
	## Adds rout when their general falls.
	for a in get_tree().get_nodes_in_group("boss_add"):
		if is_instance_valid(a):
			var h: Health = a.get_node_or_null("Health")
			if h:
				h.kill()
	RunState.register_kill(true)
	defeated.emit()
	queue_free()

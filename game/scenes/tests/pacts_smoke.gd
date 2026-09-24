extends Node2D
## Headless (MW-005): for every patron × kit, force the deep pact and check the transform
## changes attack shape or behaviour (pellet cones, ricochets, traps, statuses, blinks,
## smites) with 0 script errors. Also: each pact passive, the pact FX, pact formation from
## 3 boons, and that the pact leaves player._dmg() unscaled (no legacy multiplier).

const PLAYER := preload("res://scenes/entities/player.tscn")
const ENEMY := preload("res://scenes/entities/enemy.tscn")
const PROJ := preload("res://scenes/entities/projectile.tscn")
const PATRONS := ["dust_compact", "red_petition", "house_veyra", "church"]
const KITS := {"melee": "severin", "hybrid_gun": "mira", "orbit": "cassian", "maul": "odette", "astral": "vesper"}
const DUMMY_HP := 100000.0


class ErrorCounter extends Logger:
	var count: int = 0
	var first: String = ""

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		count += 1
		if first == "":
			first = "%s:%d %s %s %s" % [file, line, function, code, rationale]

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _fails: Array[String] = []
var _errors := ErrorCounter.new()
var _arena: Node2D
var _p: Node
var _slot_hits: Dictionary = {}
var _scale: float = 2.0


func _ready() -> void:
	print("PACTS_SMOKE_START")
	OS.add_logger(_errors)
	GameState.selected_sector = "dust_meridian"
	await _check_formation()
	_check_no_multiplier()
	for patron in PATRONS:
		for kit in KITS:
			await _run_case(patron, kit)
	await _check_passives()
	_scale = 1.0
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	OS.remove_logger(_errors)
	if _errors.count > 0:
		_fail("%d engine/script errors; first: %s" % [_errors.count, _errors.first])
	if _fails.is_empty():
		print("PACTS_SMOKE_PASS")
		get_tree().quit(0)
		return
	for f in _fails:
		print("PACTS_SMOKE_FAIL ", f)
	get_tree().quit(1)


func _fail(msg: String) -> void:
	_fails.append(msg)


# --- Fixtures ----------------------------------------------------------------------

## Fresh raid with `patron`'s pact forced on and no boons (isolates the transform).
func _setup(patron: String, kit: String) -> Node:
	RunState.start_run(KITS[kit], "dust_meridian")
	RunState.player_max_hp = 1000.0
	RunState.player_hp = 1000.0
	RunState.crit_chance = 0.0
	if patron != "":
		RunState._apply_pact_transform(patron)
	_arena = Node2D.new()
	add_child(_arena)
	_p = PLAYER.instantiate()
	_p.configure(0, KITS[kit])
	_arena.add_child(_p)
	_p.global_position = Vector2.ZERO
	_p.facing = Vector2.RIGHT
	_slot_hits = {}
	_p.slot_hit.connect(func(s: String, _t: Node, _d: float): _slot_hits[s] = true)
	return _p


func _teardown() -> void:
	if is_instance_valid(_arena):
		_arena.queue_free()
	await _wait(0.05)
	for f in get_tree().get_nodes_in_group("boon_field"):
		f.queue_free()
	RunState.pact_patron = ""


func _dummy(pos: Vector2, hp: float = DUMMY_HP, elite: bool = false) -> Node:
	var e: Node = ENEMY.instantiate()
	_arena.add_child(e)
	if elite:
		e.setup(null, false, true)
	e.global_position = pos
	e.health.max_hp = hp
	e.health.hp = hp
	e.set_physics_process(false)
	return e


func _use(slot: String, dir: Vector2 = Vector2.RIGHT) -> void:
	_p.facing = dir
	if not _p.use_slot(slot):
		_fail("%s %s would not fire" % [_p.kit_type, slot])


func _ev(key: String) -> int:
	return int(_p.pacts.events.get(key, 0))


func _hurt(e: Node) -> bool:
	return is_instance_valid(e) and e.health.hp < e.health.max_hp


func _st(e: Node) -> MWBoonStatus:
	return MWBoonStatus.peek(e) if is_instance_valid(e) else null


func _bleed(e: Node) -> int:
	var st := _st(e)
	return st.bleed if st else 0


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fail(what)


# --- Formation / damage --------------------------------------------------------------

## 3 boons from one patron form the pact on a live sibling: tint, aura, banner-able name.
func _check_formation() -> void:
	_setup("", "melee")
	var before: Color = _p.blade_visual.modulate
	for id in ["dust_reload", "dust_loot", "dust_sidestep"]:
		RunState.add_boon(BoonDB.get_boon(id))
	await _wait(0.1)
	_expect(RunState.pact_of(_p) == "dust_compact", "3 Dust boons did not form the Dust pact")
	_expect(_p.pact() == "dust_compact", "player.pact() does not read RunState.pact_of")
	_expect(_p.blade_visual.modulate != before and _p.blade_visual.modulate == MWBoonKit.C_DUST,
		"pact did not tint the weapon")
	_expect(_p.pacts._aura != null, "pact did not draw its aura")
	_expect(MWPactKit.PACT_NAMES.size() == 4, "pact names missing")
	for pat in PATRONS:
		_expect((MWPactKit.TRANSFORMS[pat] as Dictionary).size() == 5, "%s lacks 5 kit transforms" % pat)
	await _teardown()
	print("PACTS formation ok")


## The legacy ×1.12–1.2 pact multipliers are gone: a pact never changes _dmg().
func _check_no_multiplier() -> void:
	RunState.start_run("severin", "dust_meridian")
	RunState.crit_chance = 0.0
	var p: Node = PLAYER.instantiate()
	p.configure(0, "severin")
	add_child(p)
	var base: float = p._dmg()
	for pat in PATRONS:
		RunState.pact_patron = pat
		if not is_equal_approx(p._dmg(), base):
			_fail("%s pact scales _dmg() %.2f -> %.2f" % [pat, base, p._dmg()])
	RunState.pact_patron = ""
	var src: String = (load("res://scripts/combat/player.gd") as GDScript).source_code
	var start := src.find("func _dmg()")
	var body := src.substr(start, src.find("\nfunc ", start + 1) - start)
	if body.contains("has_pact") or body.contains("pact()"):
		_fail("_dmg() still reads the pact")
	p.queue_free()
	print("PACTS no multiplier ok")


# --- Patron × kit ----------------------------------------------------------------------

func _run_case(patron: String, kit: String) -> void:
	_setup(patron, kit)
	var n := _fails.size()
	await call("_case_%s_%s" % [patron.split("_")[0] if patron != "house_veyra" else "veyra", kit])
	if _p.dead:
		_fail("%s × %s: player died" % [patron, kit])
	print("PACTS %s × %s (%s) ok=%s events=%s" % [patron, kit, MWPactKit.TRANSFORMS[patron][kit],
		_fails.size() == n, _p.pacts.events])
	await _teardown()


## Dust --------------------------------------------------------------------------------

func _case_dust_melee() -> void:
	var fan: Array[Node] = [_dummy(Vector2(60, -18)), _dummy(Vector2(60, 0)), _dummy(Vector2(60, 18))]
	for i in 3:
		_use("attack")
		await _wait(0.32)
	await _wait(0.3)
	_expect(_ev("dust_sidearm") == 1, "dust melee: finisher was not the sidearm blast")
	_expect(fan.filter(func(e): return _bleed(e) >= 2).size() >= 2, "dust melee: sidearm pellets applied no 2-Bleed cone")


func _case_dust_hybrid_gun() -> void:
	var fan: Array[Node] = [_dummy(Vector2(60, -20)), _dummy(Vector2(60, 0)), _dummy(Vector2(60, 20))]
	_use("attack")
	await _wait(0.4)
	_expect(_ev("dust_buckshot_rail") == 1, "dust mira: rail shot not replaced")
	_expect(fan.filter(func(e): return _bleed(e) >= 1).size() == 3, "dust mira: buckshot cone did not bleed all 3 in the fan")
	var far := _dummy(Vector2(400, 0))
	_use("attack")
	await _wait(0.6)
	_expect(not _hurt(far), "dust mira: buckshot reached rail range")


func _case_dust_orbit() -> void:
	var a := _dummy(Vector2(80, 0))
	var b := _dummy(Vector2(120, 110))
	_use("attack")
	await _wait(1.0)
	_expect(_ev("dust_ricochet") >= 1, "dust cassian: saw-disc did not ricochet")
	_expect(_hurt(a) and _hurt(b), "dust cassian: ricochet did not reach a second foe")
	_dummy(Vector2(100, 42)) ## in the recall's path
	_dummy(Vector2(100, -42))
	_use("attack")
	await _wait(0.15)
	_use("special")
	await _wait(0.8)
	_expect(_ev("dust_drag") == 1 and _ev("dust_dragged") >= 1, "dust cassian: recall did not drag through a foe")


func _case_dust_maul() -> void:
	var front := _dummy(Vector2(60, 0))
	var behind := _dummy(Vector2(-40, 0))
	_use("attack")
	await _wait(0.8)
	_expect(_ev("dust_shrapnel") == 1, "dust odette: slam threw no shrapnel ring")
	_expect(_bleed(behind) >= 1, "dust odette: shrapnel did not fly outward (no Bleed behind)")
	_expect(_st(front) != null and _st(front).blinded(), "dust odette: impact smoke did not Blind")


func _case_dust_astral() -> void:
	var ds: Array[Node] = [_dummy(Vector2(60, 0)), _dummy(Vector2(100, 0)), _dummy(Vector2(140, 0))]
	await _wait(0.5) ## spirit drifts to its leash point
	_use("special")
	await _wait(0.2)
	_expect(_ev("dust_gunsmoke_burst") == 1, "dust vesper: detonate not a gunsmoke burst")
	_expect(ds.all(func(e): return _st(e) != null and _st(e).blinded() and _bleed(e) >= 3),
		"dust vesper: burst did not Blind + 3 Bleed everything in radius")


## Petition -----------------------------------------------------------------------------

func _case_red_melee() -> void:
	var low := _dummy(Vector2(70, 0))
	low.health.hp = DUMMY_HP * 0.08 ## above the 5% pact threshold, below the doubled 10%
	var tall := _dummy(Vector2(80, 30))
	for i in 3:
		_use("attack")
		await _wait(0.32)
	await _wait(0.4)
	_expect(_ev("petition_guillotine") == 1, "petition severin: finisher was not the guillotine drop")
	_expect(not is_instance_valid(low) or not low.health.is_alive(), "petition severin: guillotine did not execute at double threshold")
	_expect(_hurt(tall) and tall.health.is_alive(), "petition severin: guillotine executed a healthy foe")
	_expect(_ev("petition_rally") >= 1 and _p.chambered, "petition: execute did not ring the rally bell")
	_expect(get_tree().get_nodes_in_group("boon_field").size() >= 1, "petition severin: no caltrops left")


func _case_red_hybrid_gun() -> void:
	var first := _dummy(Vector2(80, 0))
	var second := _dummy(Vector2(140, 0))
	_use("attack")
	await _wait(0.4)
	_expect(_st(first) != null and _st(first).rooted() and _st(first).warranted(), "petition mira: nail-rail did not pin + Warrant the first target")
	_expect(_st(second) != null and _st(second).rooted() and not _st(second).warranted(), "petition mira: nail-rail did not pin the pierced foe")


func _case_red_orbit() -> void:
	var e := _dummy(Vector2(150, 0))
	_use("attack")
	await _wait(0.5)
	_expect(_st(e) != null and _st(e).rooted(), "petition cassian: bolas did not Root")
	var before: Vector2 = e.global_position
	_p.facing = Vector2.DOWN
	_use("special", Vector2.DOWN)
	await _wait(0.3)
	_expect(_ev("petition_yank") == 1 and e.global_position.distance_to(before) > 40.0, "petition cassian: recall did not yank the Rooted foe")


func _case_red_maul() -> void:
	var e := _dummy(Vector2(60, 0))
	_use("attack")
	await _wait(0.5)
	_expect(_ev("petition_trap") == 1, "petition odette: slam planted no spike trap")
	var hp: float = e.health.hp
	_use("special")
	await _wait(0.3)
	_expect(_ev("petition_trap_blast") == 1, "petition odette: shockwave did not detonate the trap")
	_expect(e.health.hp < hp, "petition odette: trap blast dealt nothing")


func _case_red_astral() -> void:
	var elite := _dummy(Vector2(240, 0), DUMMY_HP, true)
	await _wait(0.5)
	_expect(str(elite.affix_id) != "", "fixture: elite has no affix")
	_use("attack")
	await _wait(0.5)
	_expect(elite.has_meta(MWPactKit.CHARGE_META), "petition vesper: spike did not stick a sabotage charge")
	_use("special")
	await _wait(0.2)
	_expect(str(elite.affix_id) == "" and _ev("petition_affix_stripped") == 1, "petition vesper: detonate did not strip the elite affix")
	_expect(_ev("petition_staggered") >= 1, "petition vesper: detonate staggered nothing")


## Veyra ---------------------------------------------------------------------------------

func _case_veyra_melee() -> void:
	var reach := _dummy(Vector2(80, 0)) ## past the stock 58 px combo reach
	_use("attack")
	await _wait(0.32)
	_expect(_hurt(reach), "veyra severin: whip-blade did not reach 1.5×")
	_use("attack")
	await _wait(0.32)
	var hp: float = reach.health.hp
	_use("attack")
	await _wait(0.3)
	_expect(_ev("veyra_shadowstep") == 1 and _p.global_position.x > reach.global_position.x,
		"veyra severin: finisher did not shadowstep through the target")
	var stock: float = _p.slot_hit_damage("attack", 1.7)
	_expect(hp - reach.health.hp >= stock * 1.9, "veyra severin: finisher did not crit (%.0f vs %.0f)" % [hp - reach.health.hp, stock])


func _case_veyra_hybrid_gun() -> void:
	var line: Array[Node] = [_dummy(Vector2(60, 0)), _dummy(Vector2(100, 0)), _dummy(Vector2(140, 0)), _dummy(Vector2(180, 0))]
	_use("attack")
	await _wait(0.5)
	_expect(line.all(func(e): return _hurt(e)), "veyra mira: blood lance did not pierce the whole line")
	_expect(_ev("veyra_lance_siphon") >= 4, "veyra mira: lance did not lifesteal per pierce")
	_use("attack", Vector2.UP)
	await _wait(0.8)
	_expect(_p.debt >= 3.0, "veyra mira: a lance that hit nothing cost no Debt")


func _case_veyra_orbit() -> void:
	await _wait(0.2)
	var r: float = _p._crescents[0].node.position.length()
	_expect(absf(r - 54.0) < 2.0, "veyra cassian: blood halo orbit is %.0f, want 54" % r)
	var a := _dummy(Vector2(100, 0))
	var b := _dummy(Vector2(-60, 60))
	_use("attack")
	await _wait(0.4)
	var hp: float = b.health.hp
	await _wait(1.1)
	_expect(_ev("veyra_tether") >= 2, "veyra cassian: crescents did not tether 2 foes")
	_expect(b.health.hp < hp and _ev("veyra_siphon") >= 2, "veyra cassian: tethers did not siphon")
	_expect(_hurt(a), "veyra cassian: crescent missed")


func _case_veyra_maul() -> void:
	var e := _dummy(Vector2(150, 0))
	_use("attack")
	await _wait(0.5)
	_expect(_ev("veyra_gavel") == 1 and _p.global_position.x > 90.0, "veyra odette: slam did not shadowstep to the target")
	_expect(_hurt(e), "veyra odette: gavel missed")


func _case_veyra_astral() -> void:
	await _wait(0.5)
	var spirit: Vector2 = _p._spirit_pos
	_use("special")
	await _wait(0.05)
	_expect(_ev("veyra_swap") == 1 and _p.global_position.distance_to(spirit) < 4.0, "veyra vesper: detonate did not swap body and spirit")
	_expect(_p.pacts._crit_next, "veyra vesper: no crit armed after the swap")


## Church ---------------------------------------------------------------------------------

func _case_church_melee() -> void:
	_dummy(Vector2(60, 0))
	for i in 3:
		_use("attack")
		await _wait(0.32)
	await _wait(0.8)
	_expect(_ev("church_tip_smite") == 1 and _slot_hits.has("smite"), "church severin: finisher called no Smite at the tip")
	var shot: Node = PROJ.instantiate()
	_arena.add_child(shot)
	shot.setup(Vector2(250, 0), Vector2.LEFT, 5.0, null, false, 0.1) ## the cleave lunges ~150 px first
	shot.make_hostile()
	await _wait(0.05)
	_use("special")
	await _wait(0.4)
	_expect(not is_instance_valid(shot) and _ev("church_shots_burned") == 1, "church severin: light arc did not destroy the projectile")


func _case_church_hybrid_gun() -> void:
	_dummy(Vector2(80, 0))
	for i in 5:
		_use("attack")
		await _wait(0.35)
	await _wait(1.0)
	_expect(_ev("church_note") >= 5, "church mira: bolts left no hymn notes")
	_expect(_ev("church_note_smite") >= 1 and _slot_hits.has("smite"), "church mira: 5 notes did not converge into a Smite")


func _case_church_orbit() -> void:
	var e := _dummy(Vector2(70, 0))
	_use("attack")
	await _wait(0.6)
	_expect(_ev("church_halo") == 1 and _hurt(e), "church cassian: fixed halo did not cut on contact")
	_expect(_p._crescents.all(func(c): return c.mode == "halo"), "church cassian: crescents left the halo")
	await _wait(0.8)
	var far := _dummy(Vector2(150, 0))
	_use("special")
	await _wait(0.5)
	_expect(_ev("church_flare") == 1 and _st(far) != null and _st(far).condemned(), "church cassian: judgment flare did not Condemn")


func _case_church_maul() -> void:
	var e := _dummy(Vector2(90, 0))
	_use("special")
	await _wait(1.6)
	_expect(_ev("church_judgment_ring") == 1 and _st(e) != null and _st(e).condemned(), "church odette: judgment ring did not Condemn")
	_expect(_ev("church_ring_smite") >= 1 and _slot_hits.has("smite"), "church odette: second pass did not Smite the Condemned")


func _case_church_astral() -> void:
	var e := _dummy(Vector2(110, 0))
	await _wait(0.5)
	_use("attack")
	await _wait(0.1)
	_expect(_ev("church_sun_ray") == 1 and _st(e) != null and _st(e).condemned(), "church vesper: sun-ray did not Condemn")
	var wards: int = _p.wards
	_use("special")
	await _wait(0.9)
	_expect(_p.wards == wards + 1 and _ev("church_lantern_ward") == 1, "church vesper: detonate did not Ward the body")
	_expect(_slot_hits.has("smite"), "church vesper: detonate called no Smite")


# --- Passives -----------------------------------------------------------------------------

func _check_passives() -> void:
	## Dust: a sibling's smoke refunds your dash and Chambers you (co-op: any owner).
	_setup("dust_compact", "melee")
	var p2: Node = PLAYER.instantiate()
	p2.configure(1, "mira")
	_arena.add_child(p2)
	p2.global_position = Vector2(-300, 0)
	await _wait(0.1)
	p2.boons.smoke(Vector2(40, 0), 50.0, 3.0, 1.0)
	await _wait(0.1)
	_p.chambered = false
	_use("dash")
	await _wait(0.12)
	_expect(_ev("dust_smoke_dash") == 1 and _p.dodge_cd <= 0.0 and _p.chambered, "dust passive: dash through a sibling's smoke did not refund + Chamber")
	await _teardown()

	## Veyra: Debt cap 40; kills in Debt pay back 7 (2 + 5).
	_setup("house_veyra", "melee")
	_p.boons.add_debt(100.0)
	_expect(is_equal_approx(_p.debt, 40.0), "veyra passive: Debt cap is %.0f, want 40" % _p.debt)
	var e := _dummy(Vector2(40, 0), 5.0)
	_p.land_slot_hit(e, 50.0, "attack")
	_expect(is_equal_approx(_p.debt, 33.0), "veyra passive: kill in Debt paid back %.0f, want 7" % (40.0 - _p.debt))
	await _teardown()

	## Church: 1 Ward at room start; every Smite leaves a cleansing hymn ring.
	_setup("church", "melee")
	_p.wards = 0
	RunState.begin_room()
	_expect(_p.wards == 1, "church passive: room start gave %d wards" % _p.wards)
	_p.boons.smite(Vector2(40, 0))
	await _wait(0.8)
	_expect(_ev("church_hymn") == 1, "church passive: Smite left no hymn ring")
	await _teardown()

	## Petition: +5 execute threshold even without Widow's Writ; the rally bell is checked in the Severin case.
	_setup("red_petition", "melee")
	var low := _dummy(Vector2(40, 0))
	_expect(is_equal_approx(_p.boons.execute_threshold(low), 0.05), "petition passive: threshold %.2f, want 0.05" % _p.boons.execute_threshold(low))
	await _teardown()
	print("PACTS passives ok")


## Game-time wait at the test's time scale (hitstop resets Engine.time_scale to 1).
func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		if Engine.time_scale > 0.5 and not MWVFX._hitstopping:
			Engine.time_scale = _scale
		Engine.physics_ticks_per_second = int(60.0 * _scale)
		Engine.max_physics_steps_per_frame = int(8.0 * _scale)
		var step := minf(left, 0.1)
		await get_tree().create_timer(step).timeout
		left -= step

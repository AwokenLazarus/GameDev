extends Node
class_name MWBoonKit
## Runs the owned boons for one sibling (MW-006). The player calls in at fixed points:
##   before_hit / after_hit   every player hit (land_slot_hit)
##   on_kill                  a foe this player hit died
##   before_hurt / after_hurt / try_lethal   damage taken
## and the kit listens to slot_used, dash_started/ended, fed and RunState.room_started.
## Behaviour is keyed by the ids in BoonDB (catalogue MW-018). Owned boons are the party's
## RunState loadout, so every sibling runs them (per-player ownership is MW-027).
## Deep-pact transforms (MW-005) hang off RunState.pact_formed → on_pact_formed().

const _FIELD = preload("res://scripts/combat/boon_field.gd")
const _VFX = preload("res://scripts/visuals/vfx.gd")

const COMBAT_SLOTS := ["attack", "special", "cast", "echo"]
const CRIT_MULT := 2.0
const DEBT_CAP := 30.0
const DEBT_GRACE := 5.0
const DEBT_DRAIN := 2.0
const MAX_WARD := 3
const SMITE_TELEGRAPH := 0.6

const C_DUST := Color(0.85, 0.66, 0.35)
const C_PETITION := Color(0.78, 0.22, 0.16)
const C_VEYRA := Color(0.62, 0.08, 0.16)
const C_VEYRA_GILT := Color(1.0, 0.78, 0.35)
const C_CHURCH := Color(1.0, 0.95, 0.72)

var p: Node2D ## owning player

var _owned: Dictionary = {}
var _attack_count: int = 0
var _last_attack_ms: int = -100000
var _father_t: float = 4.0
var _cinder_cd: float = 0.0
var _cell_cd: float = 0.0
var _poise_used: bool = false
var _duelist: Node2D = null
var _duel_guard_ms: int = 0
var _promissory_ms: int = 0
var _couture: int = 0
var _sip_hits: int = 0
var _pointe_crit: bool = false
var _smite_kills: Array[int] = []
var _cast_pending: Dictionary = {}
var _snares: Array[Node] = []
var _elite_hits: Dictionary = {}
var _dashing: bool = false
var _dash_from: Vector2 = Vector2.ZERO
var _dash_passed: Dictionary = {}
var _trail_t: float = 0.0
var _debt_age: float = 0.0
var _chain_depth: int = 0


func _init(owner_player: Node2D = null) -> void:
	p = owner_player
	name = "BoonKit"


func _ready() -> void:
	if p == null:
		p = get_parent() as Node2D
	p.slot_used.connect(_on_slot_used)
	p.dash_started.connect(_on_dash_started)
	p.dash_ended.connect(_on_dash_ended)
	p.fed.connect(_on_fed)
	RunState.boons_changed.connect(refresh)
	RunState.room_started.connect(_on_room_started)
	RunState.pact_formed.connect(on_pact_formed)
	refresh()


func has(id: String) -> bool:
	return _owned.has(id)


## Re-reads the loadout (after a pick or a slot replacement).
func refresh() -> void:
	_owned.clear()
	for b in RunState.owned_boons:
		_owned[str(b.get("id", ""))] = true
	var bonus := 1 if has("dust_doublehold") else 0
	p.set_cast_bonus(bonus)


## Hook for MW-005: the 3rd boon from one patron. Pact passives and kit transforms go here.
func on_pact_formed(_patron: String) -> void:
	pass


# --- Frame ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if p == null or p.dead:
		return
	if _cinder_cd > 0.0:
		_cinder_cd -= delta
	if _cell_cd > 0.0:
		_cell_cd -= delta
	if not _cast_pending.is_empty():
		_cast_pending["t"] = float(_cast_pending["t"]) - delta
		if float(_cast_pending["t"]) <= 0.0:
			_cast_arrive(_cast_pending["pos"])
	if _dashing:
		_tick_dash(delta)
	_tick_debt(delta)
	if has("church_fatherslight") and Time.get_ticks_msec() - _last_attack_ms < 1200:
		_father_t -= delta
		if _father_t <= 0.0:
			_father_t = 4.0
			var target := _highest_hp_foe(520.0)
			if target:
				smite(target.global_position)


func _tick_dash(delta: float) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.global_position.distance_to(p.global_position) < 34.0:
			_dash_passed[e.get_instance_id()] = true
	if has("dust_dash"):
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = 0.05
			_smoke(p.global_position, 26.0, 2.0, 1.5)
	if has("church_cleanse"):
		_destroy_shots(p.global_position, 40.0)


func _tick_debt(delta: float) -> void:
	if p.debt <= 0.0:
		_debt_age = 0.0
		return
	if has("veyra_collects"):
		if p.debt >= DEBT_CAP:
			var dmg: float = p.debt * 3.0
			p.debt = 0.0
			_ring(p.global_position, 140.0, C_VEYRA_GILT)
			for e in _foes_near(p.global_position, 140.0):
				p.land_slot_hit(e, dmg, "boon", true, 260.0)
		return
	_debt_age += delta
	if _debt_age < DEBT_GRACE:
		return
	var drain := minf(p.debt, DEBT_DRAIN * delta)
	p.debt -= drain
	p.health.take_damage(drain, true)


# --- Slot events -----------------------------------------------------------------

func _on_slot_used(slot: String) -> void:
	match slot:
		"attack":
			_last_attack_ms = Time.get_ticks_msec()
			p.echo_armed = p.chambered
			p.chambered = false
			if has("church_smite"):
				_attack_count += 1
				if _attack_count % 3 == 0:
					var t := _foe_ahead(220.0, 0.9)
					smite(t.global_position if t else p.global_position + p.facing * 110.0)
		"special":
			if has("veyra_pointe"):
				var t := _foe_ahead(140.0, 1.05)
				if t:
					_afterimage(p.global_position, C_VEYRA)
					p.global_position = t.global_position - p.facing * 26.0
					_pointe_crit = true
			if has("dust_buckshot"):
				for i in 5:
					var d: Vector2 = p.facing.rotated((float(i) - 2.0) * 0.16)
					p.spawn_boon_projectile(d, p.base_hit(0.4), "shard", C_DUST)
		"cast":
			var c: Dictionary = p.slot_data("cast")
			var reach := float(c.get("range", 180.0))
			_cast_pending = {"pos": p.global_position + p.facing * reach, "t": 0.35}
			if has("church_litany"):
				_litany()


func _on_dash_started(_dir: Vector2) -> void:
	_dashing = true
	_dash_from = p.global_position
	_dash_passed.clear()
	_trail_t = 0.0
	if has("petition_caltrops"):
		var f := _field(_dash_from, 46.0, 4.0, C_PETITION)
		f.interval = 0.5
		var dmg: float = p.base_hit(0.2)
		f.on_enemy = func(e: Node) -> void:
			MWBoonStatus.of(e).slow(0.6, 0.5)
			p.land_slot_hit(e, dmg, "boon", false, 0.0)
	if has("veyra_shadowstep"):
		p.health.set_invuln(0.35)
		var decoy := _afterimage(_dash_from, C_VEYRA, 1.0)
		for e in _foes_near(_dash_from, 240.0):
			if e.has_method("taunt"):
				e.taunt(decoy, 1.0)
	if has("church_cleanse"):
		p.cleanse()
	if _couture > 0:
		_couture -= 1
		for off in [0.0, 0.5]:
			_couture_image(_dash_from.lerp(p.global_position + p.velocity * 0.18, off))


func _on_dash_ended() -> void:
	_dashing = false
	_promissory_ms = Time.get_ticks_msec() + 1000
	if has("dust_reload"):
		p.chambered = true
	if has("church_procession"):
		_ring(p.global_position, 80.0, C_CHURCH)
		for e in _foes_near(p.global_position, 80.0):
			p.land_slot_hit(e, p.base_hit(0.8), "boon", false, 320.0)
	if has("dust_devil") and _dash_passed.size() >= 3:
		_dust_devil(p.global_position)
	_dash_passed.clear()


func _on_fed() -> void:
	if has("veyra_life"):
		p.heal_hp(20.0)
		_sip_hits = 3


func _on_room_started() -> void:
	_poise_used = false
	_duelist = null
	if has("church_vow") and RunState.feed_count == 0:
		p.wards = maxi(p.wards, 2)


# --- Hits -------------------------------------------------------------------------

## Damage modifiers before the hit lands. Returns {dmg, crit}.
func before_hit(foe: Node, dmg: float, slot: String) -> Dictionary:
	var crit := false
	var st := MWBoonStatus.peek(foe)
	if slot in COMBAT_SLOTS:
		if has("veyra_crit") and slot in ["attack", "echo"] and _crit_condition(foe, st):
			crit = true
		if slot == "special" and _pointe_crit:
			_pointe_crit = false
			crit = true
		if has("veyra_collateral") and Time.get_ticks_msec() <= _promissory_ms:
			_promissory_ms = 0
			crit = true
			MWBoonStatus.of(foe).collateral = true
		if has("veyra_duel") and foe == _duelist:
			crit = true
		if has("petition_manifest") and _is_winding(foe):
			dmg += p.base_hit(3.0)
	if slot == "smite" and st and st.condemned():
		dmg *= 2.0
	if crit:
		dmg *= CRIT_MULT
	return {"dmg": dmg, "crit": crit}


## Verb effects after the hit landed (the foe may be dead).
func after_hit(foe: Node, dmg: float, slot: String, heavy: bool, crit: bool) -> void:
	var h: Health = foe.get_node_or_null("Health")
	var alive := h != null and h.is_alive()
	var st := MWBoonStatus.of(foe) if alive else MWBoonStatus.peek(foe)
	if crit:
		_crit_fx(foe)
		if has("veyra_evolve"):
			p.heal_hp(1.0 if RunState.kills < 15 else (2.0 if RunState.kills < 40 else 3.0))
		if foe == _duelist:
			_duel_guard_ms = Time.get_ticks_msec() + 3000
	if slot in COMBAT_SLOTS:
		if _sip_hits > 0:
			_sip_hits -= 1
			p.heal_hp(dmg * 0.3)
		if has("veyra_duel") and _duelist == null and alive and (MWBoonStatus.is_elite(foe) or MWBoonStatus.is_general(foe)):
			_duelist = foe as Node2D
		if has("petition_manifest") and alive and _is_winding(foe):
			_sabotage(foe, 1.2)
		if has("petition_elite") and alive and MWBoonStatus.is_elite(foe):
			var id := foe.get_instance_id()
			_elite_hits[id] = int(_elite_hits.get(id, 0)) + 1
			if int(_elite_hits[id]) % 4 == 0:
				if not (foe.has_method("strip_affix") and foe.strip_affix()):
					_sabotage(foe, 1.0)
	if not alive:
		return
	match slot:
		"attack", "echo":
			if has("dust_bleed"):
				st.add_bleed(2 if heavy else 1, p)
		"special":
			if has("dust_cashin") and st.bleed > 0:
				var owed := st.bleed_remaining()
				st.clear_bleed()
				p.land_slot_hit(foe, owed, "boon", false, 0.0)
			if has("church_judgment") and is_instance_valid(foe):
				st.condemn(5.0)
			if has("petition_sabotage") and is_instance_valid(foe) and not st.fused:
				_fuse(foe)
		"cast":
			if has("petition_warrant"):
				st.warrant(8.0)
			if has("church_cooldown"):
				p.special_cd = maxf(0.0, p.special_cd - 1.0)
			if p.debt_cast:
				p.heal_hp(dmg * 0.5)
			if not _cast_pending.is_empty():
				_cast_arrive((foe as Node2D).global_position)
		"smite":
			if st.condemned():
				var next := _nearest_foe((foe as Node2D).global_position, 200.0, foe)
				if next:
					MWBoonStatus.of(next).condemn(5.0)
		"boon":
			pass
	if has("church_fatherslight") and MWBoonStatus.is_general(foe) and slot in COMBAT_SLOTS:
		st.condemn(5.0)
	if slot in ["attack", "echo"] and has("petition_execute"):
		try_execute(foe)
	if slot == "special" and has("petition_redletter") and MWBoonStatus.is_general(foe):
		if h.hp / maxf(h.max_hp, 1.0) < 0.08:
			execute(foe)


## Execute threshold as a fraction of max HP (0 = can't be executed by Writ).
func execute_threshold(foe: Node) -> float:
	if not has("petition_execute") or MWBoonStatus.is_general(foe):
		return 0.0
	var t := 0.15
	var st := MWBoonStatus.peek(foe)
	if st and st.warranted():
		t += 0.10
	if MWBoonStatus.is_elite(foe):
		t *= 0.5
	return t


func try_execute(foe: Node) -> bool:
	var h: Health = foe.get_node_or_null("Health")
	if h == null or not h.is_alive():
		return false
	if h.hp / maxf(h.max_hp, 1.0) >= execute_threshold(foe):
		return false
	execute(foe)
	return true


func execute(foe: Node) -> void:
	var h: Health = foe.get_node_or_null("Health")
	if h == null or not h.is_alive():
		return
	var pos: Vector2 = (foe as Node2D).global_position
	_ring(pos, 46.0, Color(0.55, 0.55, 0.6))
	_ring(pos, 30.0, C_PETITION)
	h.take_damage(h.hp + 1.0, true)
	p.note_kill(foe, "execute", false)
	print("MW006_EXECUTE foe=%s" % foe.name)
	if has("petition_team"):
		var f := _field(pos, 14.0, 10.0, C_PETITION)
		f.marker = true
		f.pickup = true
		f.on_player = func(pl: Node) -> void:
			pl.heal_hp(8.0)
	if has("petition_rally"):
		for pl in _players_near(p.global_position, 200.0):
			pl.chambered = true
	if has("petition_chain") and _chain_depth < 6:
		_chain_depth += 1
		for e in _foes_near(pos, 120.0):
			try_execute(e)
		_chain_depth -= 1


## A foe this player damaged died. `slot` is what killed it (attack/…/bleed/smite/execute).
func on_kill(foe: Node, slot: String, crit: bool) -> void:
	var pos: Vector2 = (foe as Node2D).global_position
	var st := MWBoonStatus.peek(foe)
	if p.debt > 0.0:
		p.debt = maxf(0.0, p.debt - 2.0)
	if has("dust_loot"):
		if MWBoonStatus.is_general(foe):
			for i in 3:
				_scrap_cache(pos + Vector2(30, 0).rotated(TAU * i / 3.0))
		elif MWBoonStatus.is_elite(foe):
			_scrap_cache(pos)
	if has("dust_shrapnel") and st and st.bleed > 0:
		_ring(pos, 60.0, C_DUST)
		for e in _foes_near(pos, 60.0):
			MWBoonStatus.of(e).add_bleed(2, p)
	if has("veyra_spray") and crit:
		for pl in _players_near(pos, 100.0):
			pl.heal_hp(3.0)
	if has("veyra_collateral") and st and st.collateral:
		p.debt = 0.0
	if has("veyra_couture") and slot == "special":
		_couture = 1
	if has("church_anathema") and st and st.condemned():
		_consecrate(pos)
	if has("church_sunwheel") and slot == "smite":
		p.refund_cast(1)
		var now := Time.get_ticks_msec()
		_smite_kills.append(now)
		_smite_kills.assign(_smite_kills.filter(func(t: int) -> bool: return now - t <= 6000))
		if _smite_kills.size() >= 5:
			_smite_kills.clear()
			p.special_cd = 0.0
			p.dodge_cd = 0.0


## Called by MWBoonStatus when a foe this player bled reaches 5 stacks.
func on_bleed_capped(foe: Node) -> void:
	if not has("dust_tally"):
		return
	var st := MWBoonStatus.peek(foe)
	if st == null:
		return
	var owed := st.bleed_remaining() * 1.5
	st.clear_bleed()
	var pos: Vector2 = (foe as Node2D).global_position
	_ring(pos, 90.0, C_DUST)
	for e in _foes_near(pos, 90.0):
		MWBoonStatus.of(e).blind(3.0)
	p.land_slot_hit.call_deferred(foe, owed, "boon", true, 0.0)


# --- Damage taken ------------------------------------------------------------------

## Returns the damage left after Wards and the Duel guard (0 = ignored).
func before_hurt(amount: float, from: Vector2) -> float:
	if has("veyra_duel") and Time.get_ticks_msec() < _duel_guard_ms:
		if not is_instance_valid(_duelist) or from.distance_to(_duelist.global_position) > 48.0:
			return 0.0
	if p.wards > 0:
		p.wards -= 1
		_ring(p.global_position, 34.0, C_CHURCH)
		if has("church_choir") and from != Vector2.ZERO:
			smite(from, true)
		return 0.0
	return amount


func after_hurt(_amount: float) -> void:
	if has("dust_sidestep") and _cinder_cd <= 0.0:
		_cinder_cd = 8.0
		_smoke(p.global_position, 50.0, 1.5, 1.5)
		p.dodge_cd = 0.0
	if has("petition_cell") and _cell_cd <= 0.0 and p.health.hp < p.health.max_hp * 0.3:
		_cell_cd = 20.0
		_ring(p.global_position, 200.0, C_PETITION)
		for pl in _players_near(p.global_position, 200.0):
			pl.health.set_invuln(1.0)
			pl.chambered = true


## Noble Poise: lethal damage becomes Debt once per room. True if it saved you.
func try_lethal(amount: float) -> bool:
	if not has("veyra_poise") or _poise_used:
		return false
	_poise_used = true
	var owed := amount - maxf(p.health.hp - 1.0, 0.0)
	p.health.hp = 1.0
	add_debt(owed)
	_ring(p.global_position, 40.0, C_VEYRA)
	return true


# --- Debt ------------------------------------------------------------------------

func add_debt(amount: float) -> void:
	p.debt = minf(DEBT_CAP, p.debt + amount)
	_debt_age = 0.0


func can_debt_cast() -> bool:
	return has("veyra_contract") and p.debt + 8.0 <= DEBT_CAP


# --- Verb objects -------------------------------------------------------------------

## Smite: light pillar after a 0.6 s telegraph ring (instant for Choir of Wards).
func smite(pos: Vector2, instant: bool = false) -> void:
	p.spawn_smite(pos, 42.0, p.base_hit(1.6), 0.0 if instant else SMITE_TELEGRAPH, C_CHURCH)


func _cast_arrive(pos: Vector2) -> void:
	_cast_pending = {}
	if has("dust_smoke"):
		_smoke(pos, 70.0, 3.0, 1.0)
	if has("petition_trap"):
		_snares.assign(_snares.filter(func(n: Node) -> bool: return is_instance_valid(n) and not n.is_queued_for_deletion()))
		if _snares.size() >= 3:
			_snares.pop_front().queue_free()
		var c: Dictionary = p.slot_data("cast")
		var dmg: float = p.slot_hit_damage("cast", float(c.get("damage", 1.0)) * 2.0)
		var f := _field(pos, 16.0, 20.0, Color(0.6, 0.6, 0.66))
		f.marker = true
		f.enemy_once = true
		f.interval = 0.05
		f.on_enemy = func(e: Node) -> void:
			MWBoonStatus.of(e).root(2.0)
			p.land_slot_hit(e, dmg, "boon", false, 0.0)
		_snares.append(f)
	if has("church_ward"):
		var f := _field(pos, 80.0, 3.0, C_CHURCH)
		f.on_player = func(pl: Node) -> void:
			pl.wards = mini(MAX_WARD, pl.wards + 1)


func _smoke(pos: Vector2, r: float, seconds: float, blind_s: float) -> void:
	var f := _field(pos, r, seconds, Color(0.72, 0.68, 0.6))
	f.on_enemy = func(e: Node) -> void:
		MWBoonStatus.of(e).blind(blind_s)
	if has("dust_doublehold"):
		f.on_player = func(pl: Node) -> void:
			pl.chambered = true


func _dust_devil(pos: Vector2) -> void:
	var f := _field(pos, 90.0, 2.0, C_DUST)
	f.interval = 0.5
	f.on_enemy = func(e: Node) -> void:
		var n := e as Node2D
		n.global_position = n.global_position.move_toward(pos, 22.0)
		var st := MWBoonStatus.of(e)
		st.blind(1.0)
		st.add_bleed(1, p)


func _consecrate(pos: Vector2) -> void:
	var f := _field(pos, 60.0, 4.0, C_CHURCH)
	f.on_enemy = func(e: Node) -> void:
		MWBoonStatus.of(e).slow(0.4, 0.5)
	f.on_player = func(pl: Node) -> void:
		pl.cleanse()


func _litany() -> void:
	var dmg: float = p.base_hit(0.5)
	for i in 3:
		await get_tree().create_timer(1.0 if i > 0 else 0.1).timeout
		if p == null or p.dead or not is_inside_tree():
			return
		_ring(p.global_position, 90.0, C_CHURCH)
		for e in _foes_near(p.global_position, 90.0):
			MWBoonStatus.of(e).slow(1.0, 0.55)
			p.land_slot_hit(e, dmg, "boon", false, 0.0)


func _fuse(foe: Node) -> void:
	var st := MWBoonStatus.of(foe)
	st.fused = true
	var dmg: float = p.base_hit(0.9)
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(foe) or not is_inside_tree():
		return
	st.fused = false
	var pos: Vector2 = (foe as Node2D).global_position
	_ring(pos, 60.0, C_PETITION)
	for e in _foes_near(pos, 60.0):
		p.land_slot_hit(e, dmg, "boon", false, 0.0)
		_sabotage(e, 0.6)


func _scrap_cache(pos: Vector2) -> void:
	var f := _field(pos, 14.0, 12.0, C_DUST)
	f.marker = true
	f.pickup = true
	f.on_player = func(pl: Node) -> void:
		pl.refund_cast(1)
		pl.heal_hp(5.0)


func _couture_image(pos: Vector2) -> void:
	_afterimage(pos, C_VEYRA_GILT, 0.3)
	var dmg: float = p.slot_hit_damage("attack", 1.0)
	await get_tree().create_timer(0.12).timeout
	if p == null or not is_inside_tree():
		return
	_VFX.slash(p.get_parent(), pos, p.facing.angle())
	for e in _foes_near(pos, 64.0):
		p.land_slot_hit(e, dmg, "echo", false, 160.0)


func _sabotage(foe: Node, seconds: float) -> void:
	if foe.has_method("sabotage"):
		foe.sabotage(seconds)
	elif foe.has_method("apply_stagger"):
		foe.apply_stagger(p.global_position, 60.0)


func _destroy_shots(pos: Vector2, r: float) -> void:
	for s in get_tree().get_nodes_in_group("hostile_projectile"):
		if is_instance_valid(s) and (s as Node2D).global_position.distance_to(pos) <= r:
			s.queue_free()


# --- Queries ---------------------------------------------------------------------

func _crit_condition(foe: Node, st: MWBoonStatus) -> bool:
	if st and (st.blinded() or st.rooted()):
		return true
	if foe.has_method("is_staggered") and foe.is_staggered():
		return true
	## Facing away: its last movement points away from us.
	var v: Vector2 = foe.get("velocity") if foe.get("velocity") != null else Vector2.ZERO
	if v.length() > 5.0:
		var to_me: Vector2 = p.global_position - (foe as Node2D).global_position
		return v.dot(to_me) < 0.0
	return false


func _is_winding(foe: Node) -> bool:
	return foe.has_method("is_winding") and foe.is_winding()


func _foes_near(pos: Vector2, r: float) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.global_position.distance_to(pos) <= r + 12.0:
			out.append(e)
	return out


func _players_near(pos: Vector2, r: float) -> Array[Node]:
	var out: Array[Node] = []
	for pl in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(pl) and not bool(pl.get("dead")) and pl.global_position.distance_to(pos) <= r:
			out.append(pl)
	return out


func _nearest_foe(pos: Vector2, r: float, skip: Node = null) -> Node2D:
	var best: Node2D = null
	var best_d := r
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e == skip:
			continue
		var d: float = e.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = e
	return best


## Nearest foe within `r` and `half_arc` radians of facing.
func _foe_ahead(r: float, half_arc: float) -> Node2D:
	var best: Node2D = null
	var best_d := r
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var off: Vector2 = e.global_position - p.global_position
		if off.length() < best_d and (off.length() < 12.0 or absf(p.facing.angle_to(off)) <= half_arc):
			best_d = off.length()
			best = e
	return best


func _highest_hp_foe(r: float) -> Node2D:
	var best: Node2D = null
	var best_hp := 0.0
	for e in _foes_near(p.global_position, r):
		var h: Health = e.get_node_or_null("Health")
		if h and h.hp > best_hp:
			best_hp = h.hp
			best = e
	return best


# --- Visuals ---------------------------------------------------------------------

func _field(pos: Vector2, r: float, seconds: float, tint: Color) -> MWBoonField:
	var f: MWBoonField = _FIELD.new()
	f.setup(pos, r, seconds, tint)
	p.get_parent().add_child.call_deferred(f)
	return f


func _ring(pos: Vector2, r: float, tint: Color) -> void:
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for i in 25:
		var a := TAU * float(i) / 24.0
		pts.append(Vector2(cos(a), sin(a) * 0.6) * r)
	ring.points = pts
	ring.width = 3.0
	ring.default_color = Color(tint, 0.9)
	ring.z_index = 18
	p.get_parent().add_child(ring)
	ring.global_position = pos
	ring.scale = Vector2(0.4, 0.4)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2.ONE, 0.18)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
	tw.tween_callback(ring.queue_free)


## Fading silhouette; stays in group "decoy" for `life` seconds (Ledger Step aggro).
func _afterimage(pos: Vector2, tint: Color, life: float = 0.35) -> Node2D:
	var ghost := Polygon2D.new()
	ghost.polygon = PackedVector2Array([Vector2(0, -22), Vector2(10, -4), Vector2(8, 14), Vector2(-8, 14), Vector2(-10, -4)])
	ghost.color = Color(tint, 0.6)
	ghost.z_index = 10
	ghost.add_to_group("decoy")
	p.get_parent().add_child(ghost)
	ghost.global_position = pos
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, life)
	tw.tween_callback(ghost.queue_free)
	return ghost


func _crit_fx(foe: Node) -> void:
	var av: Node = foe.get_node_or_null("ActorVisual")
	if av and av.has_method("flash"):
		av.flash(Color(1.9, 0.75, 0.3), 0.14)

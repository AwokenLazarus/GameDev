extends Node
class_name MWPactKit
## Deep pacts (MW-005, Boon Catalogue §4). The 3rd boon from one patron applies that
## patron's passive and rewrites this sibling's weapon: attack shape or behaviour, never a
## damage multiplier. The player's kit functions call the hooks below; a hook returns true
## when the transform replaced the stock move. The pact is read through player.pact()
## (RunState.pact_of), so it is party-wide today and per-player once MW-027/MW-011 land.
##
## Passives: Dust — dashing through any smoke refunds the dash and Chambers you.
##   Petition — execute threshold +5 (in MWBoonKit) and every execute rings the rally bell.
##   Veyra — Debt cap 40, kills in Debt pay back 5 more (in MWBoonKit).
##   Church — 1 Ward at room start; every Smite leaves a 1 s hymn ring that cleanses.

const _VFX = preload("res://scripts/visuals/vfx.gd")

const PACT_NAMES := {
	"dust_compact": "Contraband Law",
	"red_petition": "The Cell Rises",
	"house_veyra": "The Blood Ledger",
	"church": "Liturgy of the Pale Sun",
}
## patron -> kit_type -> transform name (HUD banner and tests).
const TRANSFORMS := {
	"dust_compact": {"melee": "Peace-cord Sidearm", "hybrid_gun": "Buckshot Rail", "orbit": "Serrated Saw-discs",
		"maul": "Shrapnel Ring", "astral": "Gunsmoke Spirit"},
	"red_petition": {"melee": "Guillotine Drop", "hybrid_gun": "Nail-rail", "orbit": "Bolas",
		"maul": "Iron Spike Traps", "astral": "Sabotage Charge"},
	"house_veyra": {"melee": "Whip-blade", "hybrid_gun": "Blood Lance", "orbit": "Blood Halo",
		"maul": "The Gavel", "astral": "Body Swap"},
	"church": {"melee": "Sun-tip Smite", "hybrid_gun": "Hymn Notes", "orbit": "Fixed Halo",
		"maul": "Judgment Ring", "astral": "Lantern"},
}
const COLORS := {
	"dust_compact": MWBoonKit.C_DUST,
	"red_petition": MWBoonKit.C_PETITION,
	"house_veyra": MWBoonKit.C_VEYRA_GILT,
	"church": MWBoonKit.C_CHURCH,
}
const RALLY_RADIUS := 200.0
const MAX_TRAPS := 4
const NOTES_PER_SMITE := 5
const CHARGE_META := "mw_pact_charge"

var p: Node2D ## owning player
## How often each transform/passive fired, by key (tests and telemetry read this).
var events: Dictionary = {}

var _dashing: bool = false
var _dash_refunded: bool = false
var _crit_now: bool = false ## the hits in flight crit (whip-blade finisher)
var _crit_next: bool = false ## the next combat hit crits (body swap)
var _aura: Line2D
var _wake_t: float = 0.0
var _trail_t: float = 0.0
var _traps: Array[Node] = []
var _notes: Array[Node] = []
var _note_count: int = 0
var _note_target: Node2D = null
var _last_note_pos: Vector2 = Vector2.ZERO
var _tethers: Array[Dictionary] = [] ## {foe, t, line}
var _siphon_t: float = 0.0


func _init(owner_player: Node2D = null) -> void:
	p = owner_player
	name = "PactKit"


func _ready() -> void:
	if p == null:
		p = get_parent() as Node2D
	p.dash_started.connect(_on_dash_started)
	p.dash_ended.connect(_on_dash_ended)
	RunState.pact_formed.connect(_on_pact_formed)
	RunState.room_started.connect(_on_room_started)


func patron() -> String:
	return p.pact()


func _on(pat: String, kit: String = "") -> bool:
	return patron() == pat and (kit == "" or p.kit_type == kit)


func color() -> Color:
	return COLORS.get(patron(), Color.WHITE)


func _count(key: String) -> void:
	events[key] = int(events.get(key, 0)) + 1


# --- Pact formed / FX ----------------------------------------------------------------

func _on_pact_formed(pat: String) -> void:
	if pat != patron():
		return
	refresh_fx()
	_VFX.pact_burst(p.get_parent(), p.global_position, color())
	if pat == "church":
		p.wards = maxi(p.wards, 1)
	print("MW005_PACT patron=%s kit=%s transform=%s" % [pat, p.kit_type, TRANSFORMS[pat].get(p.kit_type, "?")])


## Patron-coloured weapon tint plus a ground aura ring under the sibling.
func refresh_fx() -> void:
	p.apply_weapon_tint()
	if patron() == "":
		if _aura:
			_aura.queue_free()
			_aura = null
		return
	if _aura == null:
		_aura = Line2D.new()
		_aura.points = _VFX.ellipse(20.0, 20, true)
		_aura.width = 2.0
		_aura.z_index = -1
		_aura.position = Vector2(0, 14)
		p.add_child(_aura)
	_aura.default_color = Color(color(), 0.75)


func _physics_process(delta: float) -> void:
	if p == null or p.dead or patron() == "":
		return
	_tick_wake(delta)
	if _dashing and not _dash_refunded and _on("dust_compact"):
		_check_smoke_dash()
	if not _tethers.is_empty():
		_tick_tethers(delta)


## Wake: patron-coloured puffs at the feet while moving (Dust: ochre dust wake).
func _tick_wake(delta: float) -> void:
	_wake_t -= delta
	if _wake_t <= 0.0 and p.velocity.length() > 60.0:
		_wake_t = 0.1
		_puff(p.global_position + Vector2(0, 12), 6.0 if patron() != "dust_compact" else 9.0, color(), 0.4)
	if p.kit_type == "astral" and _on("dust_compact"):
		## The spirit trails dust.
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = 0.12
			_puff(p.spirit_visual.global_position, 8.0, MWBoonKit.C_DUST, 0.5)


func _puff(pos: Vector2, r: float, tint: Color, life: float) -> void:
	var puff := Polygon2D.new()
	puff.polygon = _VFX.ellipse(r, 10)
	puff.color = Color(tint, 0.45)
	puff.z_index = -3
	p.get_parent().add_child(puff)
	puff.global_position = pos
	var tw := puff.create_tween()
	tw.tween_property(puff, "modulate:a", 0.0, life)
	tw.parallel().tween_property(puff, "scale", Vector2(1.6, 1.6), life)
	tw.tween_callback(puff.queue_free)


# --- Passives ------------------------------------------------------------------------

func _on_dash_started(_dir: Vector2) -> void:
	_dashing = true
	_dash_refunded = false


func _on_dash_ended() -> void:
	_dashing = false


## Contraband Law: any sibling's smoke works, so co-op smoke feeds every Dust-pact sibling.
func _check_smoke_dash() -> void:
	for f in get_tree().get_nodes_in_group("smoke_cloud"):
		if is_instance_valid(f) and f.contains(p.global_position, 10.0):
			_dash_refunded = true
			p.dodge_cd = 0.0
			p.chambered = true
			_puff(p.global_position, 26.0, MWBoonKit.C_DUST, 0.5)
			_count("dust_smoke_dash")
			return


func _on_room_started() -> void:
	if _on("church"):
		p.wards = maxi(p.wards, 1)


## The Cell Rises: every execute rings the rally bell (allies within 200 are Chambered).
func on_execute(pos: Vector2) -> void:
	if not _on("red_petition"):
		return
	_count("petition_rally")
	_VFX.ring(p.get_parent(), p.global_position, RALLY_RADIUS, MWBoonKit.C_PETITION, 3.0, 0.5)
	_sparks(pos)
	for pl in p.boons.players_near(p.global_position, RALLY_RADIUS):
		pl.chambered = true


## Iron sparks and rust-red banner tatters on an execute.
func _sparks(pos: Vector2) -> void:
	for i in 6:
		var bit := Polygon2D.new()
		bit.polygon = PackedVector2Array([Vector2(-3, -1), Vector2(3, -1), Vector2(3, 1), Vector2(-3, 1)])
		bit.color = MWBoonKit.C_PETITION if i % 2 == 0 else Color(0.62, 0.62, 0.66)
		bit.z_index = 22
		p.get_parent().add_child(bit)
		bit.global_position = pos
		var to := pos + Vector2(26.0, 0.0).rotated(TAU * float(i) / 6.0 + randf() * 0.4)
		var tw := bit.create_tween()
		tw.tween_property(bit, "global_position", to, 0.3)
		tw.parallel().tween_property(bit, "modulate:a", 0.0, 0.35)
		tw.tween_callback(bit.queue_free)


## Liturgy: every Smite (any source) leaves a 1 s hymn ring that cleanses allies inside.
func on_smite(pos: Vector2, fuse: float) -> void:
	if not _on("church"):
		return
	await get_tree().create_timer(fuse).timeout
	if p == null or not is_inside_tree():
		return
	_count("church_hymn")
	var f: MWBoonField = p.boons.field(pos, 56.0, 1.0, MWBoonKit.C_CHURCH)
	f.on_player = func(pl: Node) -> void:
		pl.cleanse()


## Crits a pact grants (read by MWBoonKit.before_hit).
func wants_crit(foe: Node, slot: String) -> bool:
	if _crit_now:
		return true
	if _crit_next and slot in ["attack", "special", "cast"]:
		_crit_next = false
		return true
	## The Gavel crits armored enemies.
	return _on("house_veyra", "maul") and slot == "attack" and _armored(foe)


func _armored(foe: Node) -> bool:
	if MWBoonStatus.is_general(foe) or str(foe.get("affix_id")) == "armored":
		return true
	var h: Health = foe.get_node_or_null("Health")
	return h != null and h.incoming_mult < 1.0


# --- Severin: melee ------------------------------------------------------------------

## Whip-blade reach (Veyra): the moon-edge reaches 1.5× as far.
func melee_reach() -> float:
	return 1.5 if _on("house_veyra", "melee") else 1.0


## The combo finisher. True when the transform replaced it.
func melee_finisher(dir: Vector2, radius: float, arc: float, dmg: float) -> bool:
	match patron():
		"dust_compact":
			## Peace-cord sidearm: short scatter cone; each pellet applies 2 Bleed.
			_count("dust_sidearm")
			_muzzle(dir)
			for i in 6:
				var d := dir.rotated((float(i) - 2.5) * 0.17)
				var shot: Node = p.spawn_shot(p.global_position, d, dmg * 0.3, "attack", "pact_pellet", 700.0, 0,
					MWBoonKit.C_DUST, 0.22)
				shot.set_meta("bleed", 2)
			return true
		"red_petition":
			_guillotine(dir, dmg)
			return true
		"house_veyra":
			_whip_finisher(dir, radius, arc, dmg)
			return true
		"church":
			## The finisher also calls a Smite at the blade's tip.
			_count("church_tip_smite")
			var tip: Node2D = p.boons.foe_ahead(radius + 20.0, arc)
			p.boons.smite(tip.global_position if tip else p.global_position + dir * radius)
	return false


## Guillotine drop: leaping overhead chop that executes at double threshold, leaves caltrops.
func _guillotine(dir: Vector2, dmg: float) -> void:
	_count("petition_guillotine")
	p.lunge(dir, 420.0, 0.14)
	await get_tree().create_timer(0.14).timeout
	if p == null or p.dead or not is_inside_tree():
		return
	var at: Vector2 = p.global_position + dir * 20.0
	_VFX.ring(p.get_parent(), at, 64.0, Color(0.62, 0.62, 0.66), 4.0, 0.3)
	for e in p.boons.foes_near(at, 64.0):
		p.land_slot_hit(e, dmg, "attack", true, 220.0)
		if is_instance_valid(e):
			p.boons.try_execute(e, 2.0)
	var f: MWBoonField = p.boons.field(at, 46.0, 4.0, MWBoonKit.C_PETITION)
	f.interval = 0.5
	var tick: float = p.base_hit(0.2)
	f.on_enemy = func(e: Node) -> void:
		MWBoonStatus.of(e).slow(0.6, 0.5)
		p.land_slot_hit(e, tick, "boon", false, 0.0)


## Whip-blade finisher: shadowstep through the target; the finisher always crits.
func _whip_finisher(dir: Vector2, radius: float, arc: float, dmg: float) -> void:
	_count("veyra_whip")
	var reach := radius * melee_reach()
	var target: Node2D = p.boons.foe_ahead(reach, arc)
	var hits: Array[Node2D] = []
	if target:
		p.boons.afterimage(p.global_position, MWBoonKit.C_VEYRA_GILT, 0.35)
		p.global_position = target.global_position + dir * 34.0
		p.health.set_invuln(0.2)
		_count("veyra_shadowstep")
		hits = p.boons.foes_near(target.global_position, 46.0)
	else:
		hits = p.enemies_in_arc(p.global_position, reach, dir, arc)
	_crit_now = true
	for e in hits:
		p.land_slot_hit(e, dmg, "attack", true, 260.0)
	_crit_now = false


## Light arc (Church): the lunging cleave destroys projectiles in its arc.
func after_cleave(dir: Vector2, radius: float, arc: float) -> void:
	if not _on("church"):
		return
	_count("church_light_arc")
	_VFX.ring(p.get_parent(), p.global_position, radius * 1.3, MWBoonKit.C_CHURCH, 4.0, 0.25)
	for s in get_tree().get_nodes_in_group("hostile_projectile"):
		if not is_instance_valid(s):
			continue
		var off: Vector2 = (s as Node2D).global_position - p.global_position
		if off.length() <= radius * 1.3 and absf(dir.angle_to(off)) <= arc:
			s.queue_free()
			_count("church_shots_burned")


# --- Mira: hybrid_gun ----------------------------------------------------------------

## The aimed rail shot. True when the transform fired instead.
func gun_rail(dir: Vector2, dmg: float, a: Dictionary) -> bool:
	var speed := float(a.get("speed", 780.0))
	match patron():
		"dust_compact":
			## Buckshot rail: 5-pellet cone, shorter range, 1 Bleed each.
			_count("dust_buckshot_rail")
			_muzzle(dir)
			for i in 5:
				var shot: Node = p.spawn_shot(p.global_position, dir.rotated((float(i) - 2.0) * 0.16), dmg * 0.4,
					"attack", "pact_pellet", speed * 0.9, 0, MWBoonKit.C_DUST, 0.3)
				shot.set_meta("bleed", 1)
		"red_petition":
			_count("petition_nail_rail")
			p.spawn_shot(p.global_position, dir, dmg, "attack", "pact_nail", speed, int(a.get("pierce", 1)),
				MWBoonKit.C_PETITION)
		"house_veyra":
			## Blood lance: pierces every foe in line; a shot that hits nothing costs 3 Debt.
			_count("veyra_lance")
			var lance: Node = p.spawn_shot(p.global_position, dir, dmg, "attack", "pact_lance", speed, 99,
				MWBoonKit.C_VEYRA, 0.6)
			lance.expired.connect(_on_lance_expired)
		"church":
			var note: Node = p.spawn_shot(p.global_position, dir, dmg, "attack", "pact_note", speed,
				int(a.get("pierce", 1)), MWBoonKit.C_CHURCH, 0.5)
			note.expired.connect(_on_note_expired)
		_:
			return false
	return true


## Volley bolts become hymn notes too (Church).
func tag_bolt(shot: Node) -> void:
	if _on("church", "hybrid_gun"):
		shot.tag = "pact_note"
		shot.visual.modulate = MWBoonKit.C_CHURCH
		shot.expired.connect(_on_note_expired)


func _muzzle(dir: Vector2) -> void:
	_puff(p.global_position + dir * 22.0, 10.0, Color(0.72, 0.68, 0.6), 0.35)


## Every player shot tagged "pact_*" lands here.
func projectile_hit(shot: Node, foe: Node) -> void:
	var slot: String = shot.slot
	match str(shot.tag):
		"pact_pellet":
			p.land_slot_hit(foe, shot.damage, slot, false, 90.0)
			if is_instance_valid(foe) and foe.get_node("Health").is_alive():
				MWBoonStatus.of(foe).add_bleed(int(shot.get_meta("bleed", 1)), p)
		"pact_nail":
			p.land_slot_hit(foe, shot.damage, slot, false, 60.0)
			if is_instance_valid(foe) and foe.get_node("Health").is_alive():
				var st := MWBoonStatus.of(foe)
				if st.root(1.0):
					_count("petition_pinned")
				if int(shot.hits) == 1:
					st.warrant(8.0)
		"pact_lance":
			p.land_slot_hit(foe, shot.damage, slot, false, 60.0)
			p.heal_hp(2.0)
			_count("veyra_lance_siphon")
		"pact_note":
			p.land_slot_hit(foe, shot.damage, slot, false, 120.0)
			if is_instance_valid(foe):
				_note_target = foe as Node2D
				_add_note((foe as Node2D).global_position)
		"pact_charge":
			p.land_slot_hit(foe, shot.damage, slot, false, 80.0)
			if is_instance_valid(foe) and foe.get_node("Health").is_alive():
				_attach_charge(foe)
		_:
			p.land_slot_hit(foe, shot.damage, slot, false, 120.0)


func _on_lance_expired(shot: Node) -> void:
	if int(shot.hits) == 0 and p != null and not p.dead:
		p.boons.add_debt(3.0)
		_count("veyra_lance_debt")


func _on_note_expired(shot: Node) -> void:
	if p != null and not p.dead:
		_add_note((shot as Node2D).global_position)


## A hymn note hangs where the bolt landed; every 5th converges into a Smite.
func _add_note(pos: Vector2) -> void:
	var f: MWBoonField = p.boons.field(pos, 9.0, 8.0, MWBoonKit.C_CHURCH)
	f.marker = true
	_notes.append(f)
	_last_note_pos = pos
	_note_count += 1
	_count("church_note")
	if _note_count % NOTES_PER_SMITE == 0:
		_converge.call_deferred()


func _converge() -> void:
	var at: Vector2 = _note_target.global_position if is_instance_valid(_note_target) else _last_note_pos
	_count("church_note_smite")
	for n in _notes:
		if is_instance_valid(n) and n.is_inside_tree():
			var tw: Tween = n.create_tween()
			tw.tween_property(n, "global_position", at, 0.2)
			tw.tween_callback(n.queue_free)
	_notes.clear()
	p.boons.smite(at)


# --- Cassian: orbit ------------------------------------------------------------------

## Orbit radius at rest (the Blood Halo widens it 42 → 54).
func orbit_radius(base: float) -> float:
	return 54.0 if _on("house_veyra", "orbit") else base


## Crescent throw. True when replaced (Church: the crescents become a fixed halo).
func orbit_throw(_dir: Vector2) -> bool:
	if not _on("church", "orbit"):
		return false
	_count("church_halo")
	p.start_halo(1.1)
	return true


## Recall. True when replaced.
func orbit_recall() -> bool:
	match patron():
		"dust_compact":
			## Recall drags the saw-discs back *through* enemies.
			_count("dust_drag")
			p.start_drag()
			return true
		"red_petition":
			_yank_rooted()
		"church":
			_judgment_flare()
			return true
	return false


## Bolas recall: every Rooted enemy is yanked together into a pile in front of you.
func _yank_rooted() -> void:
	var pile: Vector2 = p.global_position + p.facing * 70.0
	for e in p.boons.foes_near(p.global_position, 420.0):
		var st := MWBoonStatus.peek(e)
		if st == null or not st.rooted():
			continue
		_count("petition_yank")
		var to := pile + Vector2(randf_range(-14, 14), randf_range(-10, 10))
		var tw: Tween = e.create_tween()
		tw.tween_property(e, "global_position", to, 0.18)
	_VFX.ring(p.get_parent(), pile, 40.0, MWBoonKit.C_PETITION)


## Judgment flare: an expanding ring that Condemns everything it passes.
func _judgment_flare() -> void:
	_count("church_flare")
	var s: Dictionary = p.slot_data("special")
	var dmg: float = p.slot_hit_damage("special", float(s.get("damage", 1.3)))
	var on_hit := func(e: Node) -> void:
		p.land_slot_hit(e, dmg, "special", false, 180.0)
		if is_instance_valid(e) and e.get_node("Health").is_alive():
			MWBoonStatus.of(e).condemn(5.0)
	_expanding_ring(p, 30.0, 170.0, 0.35, on_hit)


## A crescent hit a foe (any mode). Saw-discs ricochet, bolas wrap, the halo tethers.
func crescent_hit(c: Dictionary, foe: Node2D) -> void:
	match patron():
		"dust_compact":
			if c.mode == "out":
				c.bounces = int(c.get("bounces", 0)) + 1
				var next: Node2D = null
				if c.bounces < 3:
					next = _nearest_unhit(c.pos, 220.0, c.hits)
				if next:
					c.dir = (next.global_position - c.pos).normalized()
					c.dist = 0.0
					_count("dust_ricochet")
				else:
					c.mode = "back"
					c.hits = {}
			elif c.mode == "drag" and is_instance_valid(foe):
				var away: Vector2 = (foe.global_position - p.global_position).normalized()
				foe.apply_stagger(foe.global_position + away * 10.0, 420.0)
				_count("dust_dragged")
		"red_petition":
			if c.mode == "out" and is_instance_valid(foe) and foe.get_node("Health").is_alive():
				if MWBoonStatus.of(foe).root(2.0):
					_count("petition_bolas")
				c.mode = "back"
				c.hits = {}
		"house_veyra":
			_tether_nearest()


func _nearest_unhit(pos: Vector2, r: float, hit: Dictionary) -> Node2D:
	var best: Node2D = null
	var best_d := r
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or hit.has(e.get_instance_id()):
			continue
		var d: float = e.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = e
	return best


## Blood halo: tether the 2 nearest enemies and siphon them every 0.5 s for 2.5 s.
func _tether_nearest() -> void:
	var foes: Array[Node2D] = p.boons.foes_near(p.global_position, 220.0)
	foes.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position))
	for e in foes.slice(0, 2):
		var found := false
		for t in _tethers:
			if t.foe == e:
				t.t = 2.5
				found = true
		if found:
			continue
		if _tethers.size() >= 2:
			var old: Dictionary = _tethers.pop_front()
			if is_instance_valid(old.line):
				old.line.queue_free()
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = Color(MWBoonKit.C_VEYRA, 0.85)
		line.z_index = 12
		p.get_parent().add_child(line)
		_tethers.append({"foe": e, "t": 2.5, "line": line})
		_count("veyra_tether")


func _tick_tethers(delta: float) -> void:
	_siphon_t -= delta
	var siphon := _siphon_t <= 0.0
	if siphon:
		_siphon_t = 0.5
	for t in _tethers.duplicate():
		t.t -= delta
		var foe: Node2D = t.foe if is_instance_valid(t.foe) else null
		if foe == null or t.t <= 0.0 or not foe.get_node("Health").is_alive():
			if is_instance_valid(t.line):
				t.line.queue_free()
			_tethers.erase(t)
			continue
		t.line.points = PackedVector2Array([p.global_position, foe.global_position])
		if siphon:
			p.land_slot_hit(foe, p.base_hit(0.2), "boon", false, 0.0)
			p.heal_hp(1.0)
			_count("veyra_siphon")


# --- Odette: maul --------------------------------------------------------------------

## The Gavel (Veyra): each slam shadowsteps Odette to the target point first.
func before_slam(dir: Vector2) -> void:
	if not _on("house_veyra", "maul"):
		return
	var t: Node2D = p.boons.foe_ahead(180.0, 0.9)
	if t == null:
		return
	p.boons.afterimage(p.global_position, MWBoonKit.C_VEYRA_GILT, 0.35)
	p.global_position = t.global_position - dir * 40.0
	p.health.set_invuln(0.3)
	_count("veyra_gavel")


## After the slam lands at `at`.
func after_slam(at: Vector2) -> void:
	match patron():
		"dust_compact":
			## Shrapnel ring: 8 shards fly outward with Bleed; the impact raises smoke.
			_count("dust_shrapnel")
			for i in 8:
				var shot: Node = p.spawn_shot(at, Vector2.RIGHT.rotated(TAU * float(i) / 8.0), p.base_hit(0.35),
					"attack", "pact_pellet", 460.0, 0, MWBoonKit.C_DUST, 0.35)
				shot.set_meta("bleed", 1)
			p.boons.smoke(at, 50.0, 1.5, 1.5)
		"red_petition":
			_plant_trap(at)


## Iron spike trap (max 4): Roots and nicks whatever stands on it until the Shockwave blows it.
func _plant_trap(at: Vector2) -> void:
	_traps.assign(_traps.filter(func(n: Node) -> bool: return is_instance_valid(n) and not n.is_queued_for_deletion()))
	if _traps.size() >= MAX_TRAPS:
		_traps.pop_front().queue_free()
	var f: MWBoonField = p.boons.field(at, 18.0, 20.0, Color(0.62, 0.62, 0.66))
	f.marker = true
	f.interval = 0.5
	var dmg: float = p.base_hit(0.3)
	f.on_enemy = func(e: Node) -> void:
		MWBoonStatus.of(e).root(1.5)
		p.land_slot_hit(e, dmg, "boon", false, 0.0)
	_traps.append(f)
	_count("petition_trap")


## Shockwave. True when replaced (Church judgment ring); Petition also detonates traps.
func shockwave(_dir: Vector2) -> bool:
	match patron():
		"red_petition":
			_detonate_traps()
		"church":
			_judgment_ring()
			return true
	return false


func _detonate_traps() -> void:
	var dmg: float = p.slot_hit_damage("special", 1.0)
	for f in _traps:
		if not is_instance_valid(f) or f.is_queued_for_deletion():
			continue
		var at: Vector2 = (f as Node2D).global_position
		_VFX.ring(p.get_parent(), at, 70.0, MWBoonKit.C_PETITION)
		_sparks(at)
		for e in p.boons.foes_near(at, 70.0):
			p.land_slot_hit(e, dmg, "special", false, 200.0)
			if is_instance_valid(e):
				p.boons.sabotage(e, 0.8)
		f.queue_free()
		_count("petition_trap_blast")
	_traps.clear()


## Judgment ring: expands out and contracts back, hitting twice. The first pass
## Condemns; the second pass Smites whatever is Condemned.
func _judgment_ring() -> void:
	_count("church_judgment_ring")
	var s: Dictionary = p.slot_data("special")
	var dmg: float = p.slot_hit_damage("special", float(s.get("damage", 1.0)))
	var center: Vector2 = p.global_position
	var outward := func(e: Node) -> void:
		p.land_slot_hit(e, dmg, "special", false, 120.0)
		if is_instance_valid(e) and e.get_node("Health").is_alive():
			MWBoonStatus.of(e).condemn(5.0)
	var inward := func(e: Node) -> void:
		p.land_slot_hit(e, dmg, "special", false, 0.0)
		var st := MWBoonStatus.peek(e)
		if is_instance_valid(e) and st and st.condemned():
			p.boons.smite((e as Node2D).global_position)
			_count("church_ring_smite")
	await _expanding_ring(center, 24.0, 150.0, 0.3, outward)
	if p == null or p.dead or not is_inside_tree():
		return
	await _expanding_ring(center, 150.0, 24.0, 0.3, inward)


# --- Vesper: astral ------------------------------------------------------------------

## Spirit spike. True when replaced.
func spirit_spike(origin: Vector2, aim: Vector2, dmg: float, a: Dictionary) -> bool:
	match patron():
		"red_petition":
			## Sabotage charge: sticks to its target; Detonate sets it off.
			_count("petition_charge_thrown")
			p.spawn_shot(origin - aim * 18.0, aim, dmg, "attack", "pact_charge", float(a.get("speed", 560.0)), 0,
				MWBoonKit.C_PETITION)
			return true
		"church":
			_sun_ray(origin, aim, dmg)
			return true
	return false


## Lantern sun-ray: an instant beam from the spirit that Condemns everything on it.
func _sun_ray(origin: Vector2, aim: Vector2, dmg: float) -> void:
	_count("church_sun_ray")
	var length := 300.0
	var to := origin + aim * length
	var beam := Line2D.new()
	beam.points = PackedVector2Array([origin, to])
	beam.width = 7.0
	beam.default_color = Color(MWBoonKit.C_CHURCH, 0.85)
	beam.z_index = 19
	p.get_parent().add_child(beam)
	var tw := beam.create_tween()
	tw.tween_property(beam, "modulate:a", 0.0, 0.2)
	tw.tween_callback(beam.queue_free)
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var along: float = (e.global_position - origin).dot(aim)
		if along < 0.0 or along > length:
			continue
		if (origin + aim * along).distance_to(e.global_position) <= 18.0:
			p.land_slot_hit(e, dmg, "attack", false, 100.0)
			if is_instance_valid(e) and e.get_node("Health").is_alive():
				MWBoonStatus.of(e).condemn(5.0)


func _attach_charge(foe: Node) -> void:
	if foe.has_meta(CHARGE_META):
		return
	var icon := Polygon2D.new()
	icon.polygon = PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)])
	icon.color = MWBoonKit.C_PETITION
	icon.position = Vector2(8, -30)
	icon.z_index = 30
	foe.add_child(icon)
	foe.set_meta(CHARGE_META, icon)
	_count("petition_charge_stuck")


## After Detonate at `at` (the spirit has already reformed at the body).
func after_collapse(at: Vector2, radius: float) -> void:
	match patron():
		"dust_compact":
			## Gunsmoke burst: Blinds everything in radius and applies 3 Bleed.
			_count("dust_gunsmoke_burst")
			p.boons.smoke(at, radius * 0.8, 2.0, 2.5)
			for e in p.boons.foes_near(at, radius):
				MWBoonStatus.of(e).blind(2.5)
				MWBoonStatus.of(e).add_bleed(3, p)
		"red_petition":
			_detonate_charges(at, radius)
		"house_veyra":
			## Detonate swaps body and spirit; the first hit after the swap crits.
			p.boons.afterimage(p.global_position, MWBoonKit.C_VEYRA_GILT, 0.35)
			p.spirit_swap(at)
			_crit_next = true
			_count("veyra_swap")
		"church":
			## Detonate calls a Smite and Wards the body.
			p.boons.smite(at)
			p.wards = mini(MWBoonKit.MAX_WARD, p.wards + 1)
			_count("church_lantern_ward")


## Every charge this sibling planted blows: elites lose an affix, everything in the blast
## (and in the Detonate itself) is Staggered.
func _detonate_charges(at: Vector2, radius: float) -> void:
	var blasts: Array[Vector2] = [at]
	var radii: Array[float] = [radius]
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.has_meta(CHARGE_META):
			var icon: Node = e.get_meta(CHARGE_META)
			if is_instance_valid(icon):
				icon.queue_free()
			e.remove_meta(CHARGE_META)
			blasts.append(e.global_position)
			radii.append(60.0)
	for i in blasts.size():
		_VFX.ring(p.get_parent(), blasts[i], radii[i], MWBoonKit.C_PETITION)
		for e in p.boons.foes_near(blasts[i], radii[i]):
			if i > 0 and MWBoonStatus.is_elite(e) and e.has_method("strip_affix") and e.strip_affix():
				_count("petition_affix_stripped")
			p.boons.sabotage(e, 1.0)
			_count("petition_staggered")


# --- Shared --------------------------------------------------------------------------

## Ring that sweeps from r0 to r1 around `center` (a Vector2, or a Node2D it follows) and
## calls on_hit once per foe it passes.
func _expanding_ring(center: Variant, r0: float, r1: float, seconds: float, on_hit: Callable) -> void:
	var line := Line2D.new()
	line.points = _VFX.ellipse(1.0, 28, true)
	line.width = 4.0 / r0
	line.default_color = Color(color(), 0.9)
	line.z_index = 18
	p.get_parent().add_child(line)
	var hit: Dictionary = {}
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		if p == null or p.dead or not is_inside_tree() or not is_instance_valid(line):
			break
		t += get_physics_process_delta_time()
		var r := lerpf(r0, r1, clampf(t / seconds, 0.0, 1.0))
		var c: Vector2 = (center as Node2D).global_position if center is Node2D else center
		line.global_position = c
		line.scale = Vector2(r, r)
		line.width = 4.0 / r
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e) or hit.has(e.get_instance_id()):
				continue
			var off: Vector2 = e.global_position - c
			off.y /= 0.6
			var d := off.length()
			## Crossed by the ring front this frame (either direction).
			if (r1 >= r0 and d <= r + 12.0) or (r1 < r0 and d >= r - 12.0 and d <= r0 + 12.0):
				hit[e.get_instance_id()] = true
				on_hit.call(e)
	if is_instance_valid(line):
		line.queue_free()

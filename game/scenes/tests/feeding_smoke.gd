extends Node
## Headless: each reputation tier has an in-run effect, Church rep is not double-counted,
## and feeding is refused in Ashwick. `--fixed-fps 60`. `-- seed=N` overrides.

const DEFAULT_SEED := 28
const ENEMY := preload("res://scenes/entities/enemy.tscn")
const HUD := preload("res://scenes/ui/hud.tscn")
const SHRINE := preload("res://scenes/entities/greed_shrine.tscn")

var _seed: int = 0
var _mark: Node2D
var _failed: bool = false


func _ready() -> void:
	_seed = SmokeSeed.begin(DEFAULT_SEED)
	print("FEEDING_START")
	_case_church_penalty()
	_case_ashwick_refused()
	_case_tier_numbers()
	if not _failed:
		await _run_motion()
	if not _failed:
		_case_hated_militia()
		_case_hated_shrine_cost()
		await _case_hud_line()
	if _failed:
		return
	print("FEEDING_PASS")
	get_tree().quit(0)


func _run_motion() -> void:
	await _case_neutral_chases()
	if _failed:
		return
	await _case_wary_standoff()
	if _failed:
		return
	await _case_feared_flees()


func _case_church_penalty() -> void:
	RunState.start_run()
	RunState.feed_on_human()
	_expect(RunState.reputation == -1, "neutral feed reputation %d" % RunState.reputation)
	var smite := BoonDB.get_boon("church_smite")
	_expect(not smite.is_empty(), "church_smite missing")
	RunState.add_boon(smite)
	_expect(RunState.aligned_patron == "church", "church boon did not align")
	_expect(
		RunState.reputation == -1, "add_boon subtracted after a feed (%d)" % RunState.reputation
	)
	RunState.feed_on_human()
	_expect(
		RunState.reputation == -3, "church feed should cost 2, reputation %d" % RunState.reputation
	)
	var ward := BoonDB.get_boon("church_ward")
	_expect(not ward.is_empty(), "church_ward missing")
	RunState.add_boon(ward)
	_expect(RunState.reputation == -3, "second church boon subtracted (%d)" % RunState.reputation)
	print("FEEDING church penalty ok")


func _case_ashwick_refused() -> void:
	RunState.start_run()
	RunState.feed_on_human()
	_expect(RunState.feed_count == 1, "raid feed did not count")
	RunState.set_phase(RunState.Phase.HUB)
	RunState.feed_on_human()
	_expect(RunState.feed_count == 1, "hub feed counted")
	_expect(RunState.reputation == -1, "hub feed changed reputation")
	RunState.set_phase(RunState.Phase.DUNGEON)
	RunState.sector_id = "ashwick"
	_expect(not RunState.feeding_allowed(), "ashwick sector allowed feeding")
	RunState.feed_on_human()
	_expect(RunState.feed_count == 1, "ashwick sector feed counted")
	print("FEEDING ashwick refused ok")


func _case_tier_numbers() -> void:
	RunState.start_run()
	RunState.set_reputation(0)
	_expect(RunState.reputation_label() == "Neutral", "neutral label")
	_expect(RunState.human_standoff() == 0.0, "neutral standoff")
	_expect(RunState.human_flee_chance() == 0.0, "neutral flee")
	_expect(RunState.militia_chance() == 0.0, "neutral militia")
	_expect(is_equal_approx(RunState.shrine_cost_mult(), 1.0), "neutral shrine")
	RunState.set_reputation(-2)
	_expect(RunState.reputation_label() == "Wary", "wary label")
	_expect(is_equal_approx(RunState.human_standoff(), RunState.WARY_STANDOFF), "wary standoff")
	RunState.aligned_patron = "church"
	_expect(
		is_equal_approx(RunState.human_standoff(), RunState.WARY_STANDOFF_CHURCH),
		"church wary standoff"
	)
	RunState.aligned_patron = ""
	RunState.set_reputation(-4)
	_expect(RunState.reputation_label() == "Feared", "feared label")
	_expect(is_equal_approx(RunState.human_flee_chance(), 0.40), "feared flee")
	RunState.aligned_patron = "church"
	_expect(is_equal_approx(RunState.human_flee_chance(), 0.70), "church feared flee")
	RunState.aligned_patron = ""
	RunState.set_reputation(-6)
	_expect(RunState.reputation_label() == "Hated", "hated label")
	_expect(RunState.wants_militia(0.39), "hated militia roll 0.39")
	_expect(not RunState.wants_militia(0.50), "hated militia roll 0.50 should miss")
	RunState.aligned_patron = "church"
	_expect(RunState.wants_militia(0.50), "church hated militia roll 0.50")
	_expect(is_equal_approx(RunState.shrine_cost_mult(), 2.0), "church shrine mult")
	_expect(is_equal_approx(RunState.scaled_shrine_cost(90.0), 180.0), "church altar debt")
	print("FEEDING tier numbers ok")


func _case_neutral_chases() -> void:
	RunState.start_run()
	RunState.set_reputation(0)
	var arena := _arena()
	var foe := _human(arena, Vector2(80, 0))
	var x0 := foe.global_position.x
	await _frames(15)
	_expect(
		foe.global_position.x < x0 - 8.0,
		"neutral human did not close (x=%.1f)" % foe.global_position.x
	)
	_expect(not foe.is_fleeing(), "neutral human fled")
	arena.queue_free()
	print("FEEDING neutral chase ok")


func _case_wary_standoff() -> void:
	RunState.start_run()
	RunState.set_reputation(-1)
	var arena := _arena()
	var foe := _human(arena, Vector2(40, 0))
	var x0 := foe.global_position.x
	await _frames(15)
	_expect(
		foe.global_position.x > x0 + 8.0,
		"wary human did not back off (x=%.1f)" % foe.global_position.x
	)
	_expect(not foe.is_fleeing(), "wary human fled instead of hesitating")
	arena.queue_free()
	print("FEEDING wary standoff ok")


func _case_feared_flees() -> void:
	RunState.start_run()
	RunState.set_reputation(-4)
	var arena := _arena()
	var foe := _human(arena, Vector2(80, 0))
	foe.force_social_roll(0.0)
	var x0 := foe.global_position.x
	await _frames(8)
	_expect(is_instance_valid(foe) and foe.is_fleeing(), "feared human did not flee")
	_expect(foe.global_position.x > x0 + 4.0, "feared human did not run away")
	await _frames(90)
	var gone := not is_instance_valid(foe)
	_expect(gone or foe.routed, "feared human did not rout")
	_expect(gone or not foe.is_in_group("enemy"), "routed human still in the enemy group")
	arena.queue_free()
	print("FEEDING feared rout ok")


func _case_hated_militia() -> void:
	RunState.start_run()
	RunState.set_reputation(0)
	var arena := _arena()
	var calm: Node2D = MWEnemyFactory.spawn(
		arena, Vector2(220, 0), _mark, {"elite": false, "social_roll": 0.0, "telegraph": false}
	)
	_expect(not calm.has_meta("militia"), "neutral spawn was militia")
	calm.queue_free()
	RunState.set_reputation(-6)
	var militia: Node2D = MWEnemyFactory.spawn(
		arena, Vector2(260, 0), _mark, {"elite": false, "social_roll": 0.0, "telegraph": false}
	)
	_expect(bool(militia.get_meta("militia", false)), "hated roll 0 did not spawn militia")
	_expect(bool(militia.get("is_elite")), "militia was not elite")
	_expect(bool(militia.get("is_human")), "militia was not human")
	militia.queue_free()
	RunState.aligned_patron = ""
	var miss: Node2D = MWEnemyFactory.spawn(
		arena, Vector2(300, 0), _mark, {"elite": false, "social_roll": 0.5, "telegraph": false}
	)
	_expect(not miss.has_meta("militia"), "non-church hated roll 0.5 spawned militia")
	miss.queue_free()
	RunState.aligned_patron = "church"
	var harsh: Node2D = MWEnemyFactory.spawn(
		arena, Vector2(340, 0), _mark, {"elite": false, "social_roll": 0.5, "telegraph": false}
	)
	_expect(bool(harsh.get_meta("militia", false)), "church hated roll 0.5 did not spawn militia")
	harsh.queue_free()
	arena.queue_free()
	print("FEEDING hated militia ok")


func _case_hated_shrine_cost() -> void:
	RunState.start_run()
	var shrine: GreedShrine = SHRINE.instantiate()
	shrine.setup("moon_altar", Vector2.ZERO)
	add_child(shrine)
	RunState.set_reputation(0)
	_expect(is_equal_approx(shrine.channel_seconds(), 1.0), "altar channel at neutral")
	RunState.set_reputation(-6)
	RunState.aligned_patron = ""
	_expect(is_equal_approx(shrine.channel_seconds(), 1.5), "altar channel at hated")
	_expect(RunState.tax_shrine_payout(9) == 6, "hated chest tax")
	RunState.aligned_patron = "church"
	_expect(is_equal_approx(shrine.channel_seconds(), 2.0), "altar channel at church hated")
	_expect(RunState.tax_shrine_payout(9) == 4, "church chest tax")
	shrine.queue_free()
	print("FEEDING shrine cost ok")


func _case_hud_line() -> void:
	RunState.start_run()
	RunState.set_reputation(0)
	var hud: Node = HUD.instantiate()
	add_child(hud)
	await _frames(1)
	var rep: Label = hud.get_node(^"Root/RepLabel")
	var toast: Label = hud.get_node(^"Root/ToastLabel")
	_expect(rep.text.begins_with("Reputation: Neutral"), "hud line '%s'" % rep.text)
	RunState.set_reputation(-1)
	_expect("Wary" in rep.text, "hud did not show Wary ('%s')" % rep.text)
	_expect(toast.text == "Ashwick turns Wary.", "toast '%s'" % toast.text)
	RunState.set_reputation(-4)
	_expect("Feared" in rep.text, "hud did not show Feared")
	_expect(toast.text == "Ashwick turns Feared.", "feared toast '%s'" % toast.text)
	RunState.set_reputation(-6)
	_expect("Hated" in rep.text, "hud did not show Hated")
	_expect(toast.text == "Ashwick turns Hated.", "hated toast '%s'" % toast.text)
	hud.queue_free()
	print("FEEDING hud ok")


func _arena() -> Node2D:
	var arena := Node2D.new()
	add_child(arena)
	_mark = Node2D.new()
	_mark.add_to_group("player")
	arena.add_child(_mark)
	_mark.global_position = Vector2.ZERO
	return arena


func _human(arena: Node2D, pos: Vector2) -> MWEnemy:
	var foe: MWEnemy = ENEMY.instantiate()
	arena.add_child(foe)
	foe.setup(_mark, true, false)
	foe.global_position = pos
	return foe


func _frames(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame


func _expect(ok: bool, detail: String) -> void:
	if ok or _failed:
		return
	_failed = true
	var msg := SmokeSeed.fail_line("FEEDING_FAIL", _seed, detail)
	push_error(msg)
	print(msg)
	get_tree().quit(1)

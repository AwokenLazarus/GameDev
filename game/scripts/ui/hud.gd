extends CanvasLayer
## Raid HUD (MW-029): vitals bottom-left, moon clock top-right, the gate (bursts, hunt or
## the general) top-centre, patron boons bottom-right. Sparse and wordless where it can be;
## what must be said fades in as a toast or a title card and leaves.

const BOON_ICON := preload("res://scenes/ui/boon_icon.tscn")
const Player := preload("res://scripts/combat/player.gd")
const Boss := preload("res://scripts/combat/general_boss.gd")
## The HUD stays inside a 2:1 frame so ultrawide corners do not strand it.
const SAFE_ASPECT := 2.0
const LOW_HP := 0.35
const MAX_BOON_ICONS := 14
const HINTS := {
	"dungeon":
	"WASD  MOVE     LMB  ATTACK     RMB  SPECIAL     Q  CAST     SPACE  DODGE     F  FEED",
	"wild": "STAND AT A STRONGBOX, ALTAR OR WELL TO CLAIM IT",
}
const NUMERALS: PackedStringArray = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

@onready var root: Control = $Root
@onready var safe: Control = $Root/Safe
@onready var danger: ColorRect = $Root/Danger
@onready var hp_bar: BloodBar = $Root/Safe/Vitals/HpBar
@onready var hp_label: Label = $Root/Safe/Vitals/HpRow/HpLabel
@onready var hp_max: Label = $Root/Safe/Vitals/HpRow/HpMax
@onready var feed_pips: PipRow = $Root/Safe/Vitals/Feed/FeedPips
@onready var feed_label: Label = $Root/Safe/Vitals/Feed/FeedLabel
@onready var rep_label: Label = $Root/Safe/Vitals/Feed/RepLabel
@onready var special_glyph: SlotGlyph = $Root/Safe/Vitals/Kit/Special
@onready var special_name: Label = $Root/Safe/Vitals/Kit/SpecialName
@onready var cast_glyph: SlotGlyph = $Root/Safe/Vitals/Kit/Cast
@onready var cast_name: Label = $Root/Safe/Vitals/Kit/CastName
@onready var cast_pips: PipRow = $Root/Safe/Vitals/Kit/CastPips
@onready var kit_label: Label = $Root/Safe/Vitals/KitLabel
@onready var moon_disc: TextureRect = $Root/Safe/Moon/MoonDisc
@onready var timer_label: Label = $Root/Safe/Moon/TimerLabel
@onready var diff_label: Label = $Root/Safe/Moon/DiffLabel
@onready var gate: VBoxContainer = $Root/Safe/Gate
@onready var phase_label: Label = $Root/Safe/Gate/PhaseLabel
@onready var burst_pips: PipRow = $Root/Safe/Gate/BurstPips
@onready var hunt_bar: BloodBar = $Root/Safe/Gate/HuntBar
@onready var kills_label: Label = $Root/Safe/Gate/KillsLabel
@onready var boss_panel: VBoxContainer = $Root/Safe/BossPanel
@onready var boss_name: Label = $Root/Safe/BossPanel/BossName
@onready var boss_bar: BloodBar = $Root/Safe/BossPanel/BossBar
@onready var boss_phase: Label = $Root/Safe/BossPanel/BossPhase
@onready var boon_label: Label = $Root/Safe/Boons/BoonLabel
@onready var boon_row: HBoxContainer = $Root/Safe/Boons/BoonRow
@onready var banner: Label = $Root/Safe/Banner
@onready var title_card: VBoxContainer = $Root/Safe/TitleCard
@onready var card_title: Label = $Root/Safe/TitleCard/CardTitle
@onready var card_sub: Label = $Root/Safe/TitleCard/CardSub
@onready var hint_label: Label = $Root/Safe/HintLabel

var _boss: Boss
var _boss_phase_seen: int = -1
var _hinted: Dictionary[String, bool] = {}
var _toast: Tween
var _card: Tween
var _hint: Tween


func _ready() -> void:
	RunState.timer_changed.connect(_on_timer)
	RunState.kills_changed.connect(_on_kills)
	RunState.phase_changed.connect(_on_phase)
	RunState.boons_changed.connect(_on_boons)
	RunState.reputation_changed.connect(_on_rep)
	RunState.feed_buff_changed.connect(_on_feed)
	RunState.pact_formed.connect(_on_pact_formed)
	RunState.room_started.connect(_on_room)
	root.resized.connect(_fit_safe)
	_fit_safe()
	_refresh()


## A line that fades in over the lower third and leaves by itself.
func announce(text: String, seconds: float = 2.6) -> void:
	banner.text = text
	if _toast:
		_toast.kill()
	_toast = create_tween()
	_toast.tween_property(banner, "modulate:a", 1.0, 0.2)
	_toast.tween_interval(seconds)
	_toast.tween_property(banner, "modulate:a", 0.0, 0.7)


func _fit_safe() -> void:
	var view := root.size
	var w := minf(view.x, view.y * SAFE_ASPECT)
	safe.position = Vector2((view.x - w) * 0.5, 0.0)
	safe.size = Vector2(w, view.y)


func _show_card(title: String, sub: String = "", tint: Color = MWPalette.BONE) -> void:
	card_title.text = title.to_upper()
	card_title.add_theme_color_override("font_color", tint)
	card_sub.text = sub
	card_sub.visible = sub != ""
	if _card:
		_card.kill()
	_card = create_tween()
	_card.tween_property(title_card, "modulate:a", 1.0, 0.35)
	_card.tween_interval(2.0)
	_card.tween_property(title_card, "modulate:a", 0.0, 0.8)


func _show_hint(key: String) -> void:
	if _hinted.has(key) or not HINTS.has(key):
		return
	_hinted[key] = true
	hint_label.text = HINTS[key]
	if _hint:
		_hint.kill()
	_hint = create_tween()
	_hint.tween_property(hint_label, "modulate:a", 0.75, 0.6)
	_hint.tween_interval(9.0)
	_hint.tween_property(hint_label, "modulate:a", 0.0, 1.5)


func _tick_boss() -> void:
	if _boss == null or not is_instance_valid(_boss):
		_boss = get_tree().get_first_node_in_group("boss") as Boss
		_boss_phase_seen = -1
		if _boss == null:
			boss_panel.visible = false
			return
		boss_name.text = _boss.display_name.to_upper()
		boss_bar.notches = _boss.phase_thresholds()
		_show_card(_boss.display_name, _boss.title, MWPalette.BLOOD_BRIGHT)
	var h: Health = _boss.get_node_or_null("Health")
	if h == null:
		return
	boss_panel.visible = true
	gate.visible = false
	boss_bar.max_value = h.max_hp
	boss_bar.value = h.hp
	var idx := _boss.phase_index
	if idx != _boss_phase_seen:
		boss_phase.text = _boss.phase_title.to_upper()
		if _boss_phase_seen >= 0:
			_show_card(_boss.phase_title, "", MWPalette.BLOOD_BRIGHT)
		_boss_phase_seen = idx


func _process(_delta: float) -> void:
	if RunState.phase == RunState.Phase.HUB:
		visible = false
		return
	visible = true
	hp_bar.max_value = RunState.player_max_hp
	hp_bar.value = RunState.player_hp
	hp_label.text = str(int(ceilf(RunState.player_hp)))
	hp_max.text = "/ %d" % int(RunState.player_max_hp)
	var frac := RunState.player_hp / maxf(RunState.player_max_hp, 1.0)
	var low := clampf((LOW_HP - frac) / LOW_HP, 0.0, 1.0)
	(danger.material as ShaderMaterial).set_shader_parameter("amount", low)
	hp_label.modulate = MWPalette.BONE.lerp(MWPalette.BLOOD_BRIGHT, low)
	_tick_kit()
	_tick_boss()


func _tick_kit() -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null:
		return
	var kit := p.kit_readout()
	special_name.text = kit.special_name.to_upper()
	special_glyph.ready_frac = kit.special_ready
	cast_name.text = kit.cast_name.to_upper()
	cast_glyph.ready_frac = 1.0 if kit.cast_charges > 0 else 0.0
	cast_pips.count = kit.cast_max
	cast_pips.lit = kit.cast_charges
	var tags: PackedStringArray = []
	if kit.chambered:
		tags.append("CHAMBERED")
	if kit.wards > 0:
		tags.append("WARD %d" % kit.wards)
	if kit.debt > 0:
		tags.append("DEBT %d" % kit.debt)
	kit_label.text = "   ".join(tags)
	kit_label.visible = not tags.is_empty()


func _refresh() -> void:
	_on_timer(RunState.run_time, RunState.get_difficulty_label())
	_on_boons()
	_on_rep(RunState.reputation)
	_on_feed(RunState.feed_buff_stacks)
	_on_room()
	_show_gate()


func _on_timer(seconds: float, difficulty: String) -> void:
	var m := int(seconds) / 60
	var s := int(seconds) % 60
	timer_label.text = "%02d:%02d" % [m, s]
	diff_label.text = difficulty.replace("→", "  ·  ").to_upper()
	## The moon bloodies as the sector's clock runs.
	moon_disc.modulate = Color.WHITE.lerp(Color(1.0, 0.42, 0.36), RunState.difficulty_ramp())


func _on_kills(current: int, needed: int) -> void:
	## Only wild-stage kills feed the general's gate.
	hunt_bar.max_value = float(maxi(needed, 1))
	hunt_bar.value = float(mini(current, needed))
	kills_label.text = "%d  /  %d" % [current, needed]


func _on_room() -> void:
	burst_pips.count = RunState.dungeons_total
	burst_pips.lit = RunState.dungeon_index
	burst_pips.current = RunState.dungeon_index


## Top-centre shows where the sector stands: bursts cleared, then the hunt meter.
func _show_gate() -> void:
	var wild := RunState.phase == RunState.Phase.WILD
	gate.visible = RunState.phase != RunState.Phase.BOSS
	burst_pips.visible = RunState.phase == RunState.Phase.DUNGEON
	hunt_bar.visible = wild
	kills_label.visible = wild
	var sector := str(SectorDB.get_sector(RunState.sector_id).get("name", ""))
	phase_label.text = ("THE HUNT" if wild else sector.to_upper())


func _on_phase(phase: String) -> void:
	_show_gate()
	var sector := str(SectorDB.get_sector(RunState.sector_id).get("name", ""))
	match phase:
		"dungeon":
			_on_room()
			if RunState.dungeon_index == 0:
				_show_card(sector, "Burst I of %s" % NUMERALS[RunState.dungeons_total - 1])
			_show_hint("dungeon")
		"wild":
			_on_kills(RunState.wild_kills, RunState.kill_gate)
			_show_card("The Wild", "Hunt until the general answers")
			_show_hint("wild")


## One-time "Deep Pact" card: the pact's name and what it did to this sibling's weapon.
func _on_pact_formed(patron: String) -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	var kit: String = p.kit_type if p else ""
	var transforms: Dictionary = MWPactKit.TRANSFORMS.get(patron, {})
	var change: String = transforms.get(kit, RunState.patron_display(patron))
	_show_card(MWPactKit.PACT_NAMES.get(patron, patron), "Deep Pact  ·  %s" % change, MWPalette.patron(patron))


func _on_boons() -> void:
	for c: Node in boon_row.get_children():
		c.queue_free()
	var owned := RunState.owned_boons
	for i: int in range(maxi(0, owned.size() - MAX_BOON_ICONS), owned.size()):
		var patron: String = owned[i].get("patron", "")
		var icon: PatronSigil = BOON_ICON.instantiate()
		icon.patron = patron
		icon.tint = MWPalette.patron(patron)
		icon.ringed = patron == RunState.pact_patron
		icon.tooltip_text = owned[i].get("name", "")
		boon_row.add_child(icon)
	var who := RunState.aligned_patron
	boon_label.text = RunState.patron_display(who).to_upper() if who != "" else ""
	boon_label.add_theme_color_override("font_color", Color(MWPalette.patron(who), 0.85))


## Run-scoped social cost of feeding (L7): only shown once Ashwick has noticed.
func _on_rep(value: int) -> void:
	rep_label.text = "ASHWICK  ·  %s" % RunState.reputation_label().to_upper() if value < 0 else ""


func _on_feed(stacks: int) -> void:
	feed_pips.lit = stacks
	feed_pips.modulate.a = 1.0 if stacks > 0 else 0.35
	feed_label.text = "HUNGER" if stacks > 0 else ""

class_name StallLickShow
extends ErrandWorkStage
## 庆功宴摊位「舔盐耐力赛」（女仆主持，对手派对主人）：两人并排坐，脚底抹盐，各有一只蘑菇羊在舔；谁先笑满谁输。台词 data/after/stall_lick.json。
##   她的闷笑：每秒 +RATE（放松时 +RELAX_RATE）；加强（羊舔得起劲）+STRONG_LAUGH。J 绷住脚趾：闷笑每秒 −TENSE_RATE，体力每秒 −TENSE_COST；
##     体力耗光自动松开；K 放松：体力每秒 +RECOVER。J / K 再按一次回到平常。
##   主人的闷笑 host_laugh：每秒 +HOST_RATE；她的闷笑停在 [EDGE_LO, EDGE_HI]（临界点）时，围观的人起哄、女仆给主人加盐：主人每秒再 +EDGE_BONUS。
##   主人笑满 = 赢（completed = 1）；她先笑满（ErrandWorkStage 的闷笑满）= 这一局输，两人都回到 ROUND_RESET 重来。魔力释放见 ErrandWorkStage。不存档。
## 测试：quiet、fixed_seed、press()、simulate()、host_laugh、stamina、mode。

const PATH := "res://data/after/stall_lick.json"
const RATE := 0.03
const RELAX_RATE := 0.045
const TENSE_RATE := 0.05
const TENSE_COST := 0.28
const RECOVER := 0.22
const STRONG_LAUGH := 0.09
const HOST_RATE := 0.022
const EDGE_LO := 0.7
const EDGE_HI := 0.92
const EDGE_BONUS := 0.05
const ROUND_RESET := 0.2
const FATIGUE_RATE := 0.012

static var quiet := false
static var fixed_seed := -1
static var _text := {}

var host_laugh := 0.0
var stamina := 1.0
var mode := 0
var rounds := 1
var edge_time := 0.0
var _edge_said := 0.0
var _info: Label
var _rig: LickRig


static func data() -> Dictionary:
	if _text.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_text = parsed if parsed is Dictionary else {}
	return _text


func work_text() -> Dictionary:
	return data()


func phase_limits() -> Array:
	return [1]


func panel_title() -> String:
	return str(data().get("name", ""))


func stage_cast() -> Dictionary:
	return {"princess": {"kind": "princess", "character": "pink", "at": [-18, 4], "visual": "normal", "anim": "idle", "dir": "down"},
		"host": {"kind": "npc:bonfire_host", "at": [18, 4], "dir": "down"},
		"goat": {"kind": "npc:goat", "at": [-18, 22], "dir": "up"},
		"goat2": {"kind": "npc:goat", "at": [18, 22], "dir": "up"},
		"maid": {"kind": "npc:maid", "at": [50, -4], "dir": "left"}}


func play() -> bool:
	if not prepare_work(fixed_seed, quiet):
		return false
	tickler = "goat"
	active_tool = "tongue"
	_build_ui()
	hint_label.text = str(data()["hint"])
	_info = _label(TEXT, 8)
	_info.size = panel_body.size
	panel_body.add_child(_info)
	_enter_game()
	_rig = LickRig.new()
	_rig.stage = self
	view.add_child(_rig)
	if not await start_work():
		return false
	return await work_result()


func _begin_segment() -> void:
	busy = false
	_refresh()


func _on_key(k: String) -> void:
	if recovery_left > 0.0:
		return
	match k:
		"J", "E":
			mode = 0 if mode == -1 else -1
		"K":
			mode = 0 if mode == 1 else 1
	_refresh()


func in_edge() -> bool:
	var r := player.laugh.ratio() if player.laugh else 0.0
	return r >= EDGE_LO and r <= EDGE_HI


## 她先笑满：这一局输，两人都回到起点重来
func recover() -> void:
	rounds += 1
	mode = 0
	stamina = 1.0
	host_laugh = ROUND_RESET
	recovery_left = RECOVER_TIME
	if player.laugh:
		player.laugh.set_value(laugh_max() * ROUND_RESET)
	var full: Dictionary = data().get("full", {})
	narrate(str(full.get("desc", "")), RECOVER_TIME + 0.6, true)
	_pop_random(full.get("react", []), PINK, RECOVER_TIME)
	var lines: Array = data().get("lose_host", [])
	if not lines.is_empty():
		say("host", str(lines[rng.randi_range(0, lines.size() - 1)]))


func _process(delta: float) -> void:
	if playing and not _alive():
		cancel()
		return
	if not playing or busy or _done or _suspended():
		return
	if handle_overflow():
		_refresh()
		return
	_update_bars()
	simulate(delta * time_scale)


func simulate(delta: float) -> void:
	if not _alive() or busy or _done or _suspended():
		return
	var dt := clampf(delta, 0.0, WorkInterference.MAX_DELTA)
	if recovery_left > 0.0:
		recovery_left = maxf(0.0, recovery_left - dt)
		return
	var event := work_clock(dt)
	match mode:
		-1:
			stamina = maxf(0.0, stamina - TENSE_COST * dt)
			if player.laugh:
				player.laugh.set_value(maxf(0.0, player.laugh.value - laugh_max() * TENSE_RATE * dt))
			if stamina <= 0.0:
				mode = 0
				narrate(str(data()["tired"]), 1.6, true)
		1:
			stamina = minf(1.0, stamina + RECOVER * dt)
			work_laugh(laugh_max() * RELAX_RATE * dt)
		_:
			stamina = minf(1.0, stamina + RECOVER * 0.4 * dt)
			work_laugh(laugh_max() * RATE * dt)
	add_fatigue(fatigue_max() * FATIGUE_RATE * dt)
	host_laugh += HOST_RATE * dt
	if in_edge():
		edge_time += dt
		host_laugh += EDGE_BONUS * dt
		_edge_said -= dt
		if _edge_said <= 0.0:
			_edge_said = 5.0
			var lines: Array = data().get("edge", [])
			narrate(str(lines[rng.randi_range(0, lines.size() - 1)]), 2.4, true)
	if event["strong"]:
		work_laugh(laugh_max() * STRONG_LAUGH)
	if event["reaction"]:
		_play_event(data().get("licks", []), tickler)
		if rng.randf() < 0.5:
			var tier := "light" if host_laugh < 0.4 else ("mid" if host_laugh < 0.75 else "heavy")
			var hl: Array = data().get("host", {}).get(tier, [])
			if not hl.is_empty():
				say("host", str(hl[rng.randi_range(0, hl.size() - 1)]))
	if host_laugh >= 1.0:
		host_laugh = 1.0
		advance_step()
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(_info):
		return
	_info.text = str(data()["panel"]) % [roundi(host_laugh * 100), roundi(stamina * 100), rounds]
	count_label.text = str(data()["count"])
	if _rig:
		_rig.queue_redraw()


## 两人头上的闷笑条（她的标出临界点），体力条
class LickRig extends Node2D:
	var stage: StallLickShow

	func meter(at: Vector2, ratio: float, col: Color, edge: bool) -> void:
		draw_rect(Rect2(at, Vector2(26, 4)), Color("2c2236"))
		if edge:
			draw_rect(Rect2(at + Vector2(26 * EDGE_LO, 0), Vector2(26 * (EDGE_HI - EDGE_LO), 4)), Color(1, 0.85, 0.45, 0.45))
		draw_rect(Rect2(at, Vector2(26 * clampf(ratio, 0.0, 1.0), 4)), col)

	func _draw() -> void:
		var pr := stage.player.laugh.ratio() if stage.player.laugh else 0.0
		meter(Vector2(-31, -38), pr, Color("ff9cc6"), true)
		meter(Vector2(5, -38), stage.host_laugh, Color("ffb36b"), false)
		draw_rect(Rect2(Vector2(-31, -33), Vector2(26 * stage.stamina, 2)), Color("9fe0b0"))
		draw_rect(Rect2(-36, 10, 72, 4), Color("8b6644"))

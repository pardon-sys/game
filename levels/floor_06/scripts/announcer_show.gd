class_name AnnouncerShow
extends ErrandWorkStage
## 派对主人的补罚「忍笑报幕练习」（AfterPenance 的 announcer）：她光脚站在报幕台后报节目，台子挡住观众，主人蹲在台下挠她的脚。
## 台词 AfterPenance.data()["announcer"]（← after_text/penalty.py）。
##   三轮各 PER_PHASE 个节目（PROGRAMS）：1~3 选节目卡，节拍指针（BEAT_PERIOD）进 BEAT_LOW~BEAT_HIGH 时按 J 鸣铃；选错 / 不合拍 = 卡片散开重排 SCATTER_TIME 秒。
##   笑场：闷笑 ≥ CRACK_AT 时鸣铃，有 CRACK_CHANCE 的机会声音笑破，这一项重报（已完成的不扣）。
##   K 深呼吸：闷笑 −BREATH_DROP（冷却 BREATH_CD），但下一次加强的闷笑 ×BREATH_BONUS。
##   台下的道具按轮换：羽毛（指针轻摆）→ 手指（加强后偏拍 OFFSET_TIME）→ 掰脚趾（轻摆）/ 刮脚心（偏拍）交替。
##   只在当场有效（Esc 离开就从头练），十二个都报完才交回 AfterPenance 结算；闷笑满 / 魔力释放见 ErrandWorkStage。
## 测试：quiet、fixed_seed、press()、simulate()、ring()、breath()、marker()。

const TOTAL := 12
const PER_PHASE := 4
const LIMITS := [4, 8, 12]
const BEAT_PERIOD := 2.4
const BEAT_LOW := 0.40
const BEAT_HIGH := 0.60
const OFFSET_TIME := 0.8
const SCATTER_TIME := 0.8
const BASE_RATE := 0.004
const STRONG_LAUGH := 0.03
const STRONG_FATIGUE := 0.01
const CRACK_AT := 0.7
const CRACK_CHANCE := 0.5
const BREATH_DROP := 0.08
const BREATH_CD := 4.0
const BREATH_BONUS := 1.5
const SWAY_TOOLS := ["feather", "toes"]
const PROGRAMS := [0, 1, 2, 0, 2, 0, 1, 2, 1, 2, 0, 1]
const COLORS := [Color("f4bf69"), Color("86cbd7"), Color("dbaaed")]

static var quiet := false
static var fixed_seed := -1

var selected := -1
var cards: Array[int] = [0, 1, 2]
var offset_left := 0.0
var scatter_left := 0.0
var cracks := 0
var breaths := 0
var breath_cd := 0.0
var _breath_bonus := false
var _info: Label
var _stage_info: Label
var _card_labels: Array[Label] = []
var _rig: PodiumRig


static func data() -> Dictionary:
	return AfterPenance.data().get("announcer", {})


func work_text() -> Dictionary:
	return data()


func phase_limits() -> Array:
	return LIMITS


func panel_title() -> String:
	return str(data()["name"])


func stage_cast() -> Dictionary:
	return {"princess": {"kind": "princess", "at": [50, 20], "visual": "normal", "anim": "idle", "dir": "left"},
		"worker": {"kind": "npc:bonfire_host", "at": [66, 28], "dir": "left"}}


func play() -> bool:
	if not prepare_work(fixed_seed, quiet):
		return false
	completed = 0
	phase = 0
	tickler = "worker"
	_build_ui()
	hint_label.text = str(data()["hint"])
	_info = _label(TEXT, 7)
	_info.add_theme_constant_override("line_spacing", -2)
	_info.size = panel_body.size
	_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel_body.add_child(_info)
	_enter_game()
	_stage_info = _label(TEXT, 8)
	_stage_info.position = Vector2(8, 8)
	_stage_info.size = Vector2(300, 46)
	overlay.add_child(_stage_info)
	for i in 3:
		var label := _label(TEXT, 7)
		label.position = to_frame(Vector2(-64 + i * 30, -15))
		label.size = Vector2(60, 12)
		overlay.add_child(label)
		_card_labels.append(label)
	_rig = PodiumRig.new()
	_rig.stage = self
	_rig.position.y = -12
	view.add_child(_rig)
	view.move_child(_rig, 1)
	rotate_tool()
	if not await start_work():
		return false
	return await work_result()


func _begin_segment() -> void:
	selected = -1
	busy = false
	_refresh()


func _reset_segment() -> void:
	selected = -1


func _on_phase_changed() -> void:
	rotate_tool()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and playing and event.keycode in [KEY_1, KEY_2, KEY_3]:
		if event.pressed and not event.echo:
			press(str(event.keycode - KEY_1 + 1))
		get_viewport().set_input_as_handled()
		return
	super(event)


func _on_key(key: String) -> void:
	if recovery_left > 0.0 or scatter_left > 0.0:
		return
	if key in ["1", "2", "3"]:
		selected = cards[int(key) - 1]
	elif key == "J":
		ring()
	elif key == "K":
		breath()
	_refresh()


## 节拍指针（0~1）：羽毛 / 掰脚趾时跟着笑轻轻摆，手指 / 刮脚心加强后偏一下
func marker() -> float:
	var pos := 0.5 + sin(elapsed * TAU / BEAT_PERIOD) * 0.44
	if active_tool in SWAY_TOOLS:
		pos += sin(elapsed * 7.0) * 0.06
	if offset_left > 0.0:
		pos += sin(PI * offset_left / OFFSET_TIME) * 0.16
	return clampf(pos, 0.0, 1.0)


## J：鸣铃报幕。卡对、拍对才过；笑太狠可能笑场重报。
func ring() -> bool:
	if busy or _done or _suspended() or recovery_left > 0.0 or scatter_left > 0.0:
		return false
	var on_beat := marker() >= BEAT_LOW and marker() <= BEAT_HIGH
	if selected == PROGRAMS[completed] and on_beat:
		var ratio := player.laugh.ratio() if player.laugh else 0.0
		if ratio >= CRACK_AT and rng.randf() < CRACK_CHANCE:
			_crack()
			return false
		advance_step()
		return true
	_scatter()
	work_reaction(data(), phase, active_tool, tickler, "error_react")
	return false


func _crack() -> void:
	cracks += 1
	_scatter()
	var c: Array = data().get("crack", [])
	if not c.is_empty():
		narrate(str(c[rng.randi_range(0, c.size() - 1)]), 2.4, true)
	_pop_random(data().get("crack_react", []), PINK, 1.6)


func _scatter() -> void:
	selected = -1
	cards.append(cards.pop_front())
	scatter_left = SCATTER_TIME


## K：深呼吸压下闷笑；主人等着下一下加力
func breath() -> bool:
	if breath_cd > 0.0 or busy or _done:
		return false
	breaths += 1
	breath_cd = BREATH_CD
	_breath_bonus = true
	if player.laugh:
		player.laugh.set_value(maxf(0.0, player.laugh.value - laugh_max() * BREATH_DROP))
	var b: Array = data().get("breath", [])
	if not b.is_empty():
		narrate(str(b[rng.randi_range(0, b.size() - 1)]), 1.6, true)
	_pop_random(data().get("breath_react", []), TEXT, 1.4)
	var taunts: Array = data().get("breath_taunt", [])
	if not taunts.is_empty():
		say(tickler, str(taunts[rng.randi_range(0, taunts.size() - 1)]))
	return true


func _process(delta: float) -> void:
	if playing and not _alive():
		cancel()
		return
	if not playing or busy or _done:
		return
	if _suspended():
		return
	simulate(delta * time_scale)
	_update_bars()


func simulate(delta: float) -> void:
	if not _alive() or busy or _done or _suspended():
		return
	if handle_overflow():
		_refresh()
		return
	var dt := clampf(delta, 0.0, WorkInterference.MAX_DELTA)
	breath_cd = maxf(0.0, breath_cd - dt)
	if recovery_left > 0.0:
		recovery_left = maxf(0.0, recovery_left - dt)
		return
	var event := work_clock(dt)
	offset_left = maxf(0.0, offset_left - dt)
	scatter_left = maxf(0.0, scatter_left - dt)
	work_laugh(laugh_max() * BASE_RATE * dt)
	add_fatigue(fatigue_max() * BASE_RATE * dt)
	if event["strong"]:
		work_laugh(laugh_max() * STRONG_LAUGH * (BREATH_BONUS if _breath_bonus else 1.0))
		_breath_bonus = false
		add_fatigue(fatigue_max() * STRONG_FATIGUE)
		if not (active_tool in SWAY_TOOLS):
			offset_left = OFFSET_TIME
	if event["reaction"]:
		work_reaction(data(), phase, active_tool, tickler)
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(_info):
		return
	var labels: Array = data()["labels"]
	_info.text = str(data()["panel"]) % [phase_info()["name"], mini(completed - phase_start(), PER_PHASE), completed]
	_info.text += "\n" + str(labels[0])
	for i in PER_PHASE:
		var n := phase * PER_PHASE + i
		_info.text += "\n" + ("› " if n == completed else "  ") + str(labels[5 + PROGRAMS[n]])
	count_label.text = str(data()["count"]) % [completed, TOTAL]
	for i in _card_labels.size():
		_card_labels[i].text = "%d %s" % [i + 1, labels[5 + cards[i]]]
	_stage_info.text = str(labels[1]) % labels[5 + PROGRAMS[mini(completed, TOTAL - 1)]] + "\n" \
		+ str(labels[2]) % (labels[3] if selected < 0 else labels[5 + selected])
	if scatter_left > 0.0:
		_stage_info.text += "\n" + str(labels[4])
	if interference.warning():
		_stage_info.text += "\n" + str(data()["warning"])
	if _rig:
		_rig.queue_redraw()


## 节目卡、节拍条、铃、报幕台，以及台下派对主人伸过来的手
class PodiumRig extends Node2D:
	var stage: AnnouncerShow

	func _draw() -> void:
		for i in 3:
			var p := Vector2(-53 + i * 30, -7)
			if stage.scatter_left > 0.0:
				p.y += sin(stage.scatter_left * 15 + i) * 4
			draw_rect(Rect2(p - Vector2(11, 12), Vector2(22, 25)), Color("6f5272"))
			ErrandWorkStage.draw_shape(self, p, stage.cards[i], COLORS[stage.cards[i]])
		draw_rect(Rect2(-65, 27, 90, 8), Color("382b45"))
		draw_rect(Rect2(-65 + BEAT_LOW * 90, 27, (BEAT_HIGH - BEAT_LOW) * 90, 8), Color("547f6e"))
		var mx := -65 + stage.marker() * 90
		draw_line(Vector2(mx, 24), Vector2(mx, 38), Color("ffdc8b"), 2)
		draw_arc(Vector2(35, 27), 5, PI, TAU, 10, Color("efc97c"), 2)
		draw_line(Vector2(30, 28), Vector2(40, 28), Color("efc97c"), 2)
		for i in TOTAL:
			draw_rect(Rect2(-55 + i * 9, 43, 6, 3), Color("a2dabc") if i < stage.completed else Color("584252"))
		# 报幕台在她面前（观众那一侧），台下的手从右边伸到她脚边
		var feet: Vector2 = (stage.actors["princess"] as Node2D).position - position
		draw_rect(Rect2(feet + Vector2(-16, -18), Vector2(10, 20)), Color("8a5f4a"))
		draw_rect(Rect2(feet + Vector2(-18, -20), Vector2(14, 3)), Color("b0805f"))
		if stage.playing and not stage.busy and stage.recovery_left <= 0.0:
			var tip: Vector2 = feet + Vector2(2 + sin(stage.elapsed * 14) * 2, 1)
			draw_line(stage.actors["worker"].position - position + Vector2(-4, -6), tip, Color("c49c73"), 2)
			if stage.active_tool == "feather":
				draw_line(tip - Vector2(3, 3), tip + Vector2(3, 3), Color("f6ddbd"), 3)
			else:
				draw_circle(tip, 2, Color("f1c4b5"))

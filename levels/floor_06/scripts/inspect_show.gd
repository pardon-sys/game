class_name InspectShow
extends TrainingStage
## 陷阱验收：体验一个脚部陷阱原型（借训练小游戏的画面；舞台上是 cgs.json 的陷阱演员）。台词 data/after/inspect.json 的 stations。
##   kind（每种的挣脱方式不同）：
##     curtain  风扇一阵阵把帘子吹起来（lifted）——吹起来的时候按 J 冲过去；帘子垂着时按 = 被羽毛扫一阵（再等下一次）
##     holes    洞口冒泡预警 → 那一下按 J 把脚抽开；没抽开就被抓住，连按 J ESC_HOLES 下蹬开（要过 HOLES_NEED 个洞）
##     toes     踏板夹住脚趾：连按 J ESC_TOES 下挣开，越晚挣开刷得越快
##     hoist    单脚吊起：按住 W 踮脚（踮脚体力 tiptoe 掉，松开回），脚跟落地被刷；同时连按 J ESC_HOIST 下挣开
##     kneel    跪台锁住：按提示左右交替 A / D（按错了重数）ESC_KNEEL 下挣开
##   挠痒强度 = 基础 × 陷阱倍率 mul × 状态倍率 status_mul × 评分调整 tune；闷笑满 = 笑倒（任务判失败：失败小剧场 + CG）。
##   体验时闷笑不清零（keep_laugh，综合演练用）还是从当前值开始；结束时返回 {gain 涨了多少（比例）, escaped, laughed_out}。
## 测试：auto_escape（直接挣开）、press(键)。

const ESC_HOLES := 4
const HOLES_NEED := 3
const ESC_TOES := 10
const ESC_HOIST := 12
const ESC_KNEEL := 10
const BASE_RATE := 0.07
const FATIGUE_RATE := 0.045                       # 被挠时魔力疲倦每秒涨（× 挠的力度）；满了自动释放：清空、闷笑降一半
const MAX_TIME := 14.0

static var auto_escape := false

var station := {}
var station_id := ""
var status_mul := 1.0
var tune := 1.0
var keep_laugh := false
var bursts := 0
var escaped := false
var laughed_out := false
var presses := 0
var lifted := false
var holes_passed := 0
var grabbed := false
var bubble := false
var tiptoe := 1.0
var holding := false
var next_side := "A"
var _t := 0.0
var _cycle := 0.0
var _hit_t := 0.0
var _say_t := 0.0
var _laugh0 := 0.0
var _done := false
var _info: Label


func panel_title() -> String:
	return "陷阱验收：" + str(station.get("name", ""))


func quit() -> void:
	pass


func stage_cast() -> Dictionary:
	var trap := str(station.get("trap", "brush"))
	return {"princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
		"trap": {"kind": "trap:" + trap, "at": [0, 12]},
		"g": {"kind": "npc:guard", "at": [-40, 6], "dir": "right"}}


func play_station(id: String, info: Dictionary, smul := 1.0, tune_k := 1.0, keep := false) -> Dictionary:
	station_id = id
	station = info
	status_mul = smul
	tune = tune_k
	keep_laugh = keep
	player = GameState.player
	rng.randomize()
	layer = 14
	t = {"name": panel_title()}
	_build_ui()
	hint_label.text = _hint()
	_info = _label(TEXT, 8)
	_info.size = panel_body.size
	_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel_body.add_child(_info)
	if is_instance_valid(player) and player.laugh:
		_start_fatigue = player.fatigue.value if player.fatigue else 0.0
		_start_laugh = player.laugh.value
		_laugh0 = player.laugh.value
	_enter_game()
	grabbed = str(station.get("kind", "")) in ["toes", "hoist", "kneel"]
	while not _done:
		await get_tree().process_frame
	var gain := (player.laugh.value - _laugh0) / player.laugh.max_value if is_instance_valid(player) and player.laugh else 0.0
	var end_laugh := player.laugh.value if is_instance_valid(player) and player.laugh else 0.0
	await _exit_game()
	# 体验时涨的闷笑留着（_exit_game 会还原成开始时的值）
	if is_instance_valid(player) and player.laugh:
		player.laugh.set_value(end_laugh)
	finished.emit()
	return {"gain": gain, "escaped": escaped, "laughed_out": laughed_out}


func _hint() -> String:
	match str(station.get("kind", "")):
		"curtain":
			return "风扇把帘子吹起来的时候按 J 冲过去"
		"holes":
			return "冒泡的那一下按 J 抽脚，被抓住了连按 J"
		"toes":
			return "连按 J 挣开夹子"
		"hoist":
			return "按住 W 踮脚，同时连按 J 挣开吊环"
		"kneel":
			return "按提示左右交替 A / D"
	return ""


func _refresh() -> void:
	if _info == null:
		return
	var k := str(station.get("kind", ""))
	var s := "%s\n" % station.get("name", "")
	match k:
		"curtain":
			s += "帘子：%s" % ("吹起来了！" if lifted else "垂着")
		"holes":
			s += "过了 %d / %d 个洞%s" % [holes_passed, HOLES_NEED, ("\n被抓住了！蹬 %d / %d" % [presses, ESC_HOLES]) if grabbed else ("\n冒泡了！" if bubble else "")]
		"toes":
			s += "挣扎 %d / %d" % [presses, ESC_TOES]
		"hoist":
			s += "挣扎 %d / %d\n踮脚体力 %d%%" % [presses, ESC_HOIST, int(tiptoe * 100.0)]
		"kneel":
			s += "挣扎 %d / %d　下一下：%s" % [presses, ESC_KNEEL, next_side]
	_info.text = s


func _rate() -> float:
	return BASE_RATE * float(station.get("mul", 1.0)) * status_mul * tune


func _tick(delta: float) -> void:
	_t += delta
	if auto_escape:
		_escape()
		return
	match str(station.get("kind", "")):
		"curtain":
			_cycle += delta
			lifted = fmod(_cycle, 2.4) > 1.7
			if _t > MAX_TIME:
				_escape()
		"holes":
			if grabbed:
				_tickle(delta, 1.0)
			else:
				_cycle += delta
				bubble = fmod(_cycle, 1.3) > 0.85
				if fmod(_cycle, 1.3) < delta and _cycle > 1.0:
					# 冒泡的那一下没抽脚：被抓住
					grabbed = true
					presses = 0
		"toes":
			_tickle(delta, 1.0 + _t * 0.12)
			if _t > MAX_TIME:
				_escape()
		"hoist":
			holding = Input.is_action_pressed("move_up")
			if holding:
				tiptoe = maxf(0.0, tiptoe - delta * 0.28)
			else:
				tiptoe = minf(1.0, tiptoe + delta * 0.4)
			# 吊起来的脚一直被羽毛扫；踮不住（体力 0 或松开）脚跟落地被刷
			_tickle(delta, 0.8 + (0.0 if holding and tiptoe > 0.0 else 0.8))
			if _t > MAX_TIME:
				_escape()
		"kneel":
			_tickle(delta, 1.0)
			if _t > MAX_TIME:
				_escape()
	_refresh()


func _tickle(delta: float, k: float) -> void:
	add_laugh(laugh_max() * _rate() * k * delta, 1.0)
	add_fatigue(fatigue_max() * FATIGUE_RATE * k * delta)
	_hit_t -= delta
	if _hit_t <= 0.0:
		_hit_t = 0.35
		tickle("trap", "sole", rng.randf() < 0.1)
	_say_t -= delta
	if _say_t <= 0.0:
		_say_t = 2.2
		var caps: Array = station.get("cap", [])
		if not caps.is_empty():
			narrate(str(caps.pick_random()))
		say("princess", react_line())


func react_line() -> String:
	var r: Dictionary = TaskInspect.data().get("react", {})
	var lr := player.laugh.ratio() if is_instance_valid(player) and player.laugh else 0.0
	var pool: Array = r.get("light" if lr < 0.35 else ("mid" if lr < 0.7 else "heavy"), ["……"])
	return str(pool.pick_random())


func _on_key(k: String) -> void:
	match str(station.get("kind", "")):
		"curtain":
			if k == "J":
				if lifted:
					_escape()
				else:
					# 帘子垂着就冲：被扫一阵
					for i in 3:
						_tickle(0.4, 1.4)
		"holes":
			if k != "J":
				return
			if grabbed:
				presses += 1
				if presses >= ESC_HOLES:
					grabbed = false
					holes_passed += 1
					_cycle = 0.0
			elif bubble:
				holes_passed += 1
				_cycle = 0.0
				pop(actors.get("princess"), "抽开了！", GOOD, 0.6)
			if holes_passed >= HOLES_NEED:
				_escape()
		"toes":
			if k == "J":
				presses += 1
				if presses >= ESC_TOES:
					_escape()
		"hoist":
			if k == "J":
				presses += 1
				if presses >= ESC_HOIST:
					_escape()
		"kneel":
			if k in ["A", "D"]:
				if k == next_side:
					presses += 1
					next_side = "D" if k == "A" else "A"
				else:
					presses = maxi(0, presses - 2)
				if presses >= ESC_KNEEL:
					_escape()
	_refresh()


func _escape() -> void:
	if _done:
		return
	escaped = true
	var es: Array = station.get("escape", [])
	if not es.is_empty():
		narrate(str(es.pick_random()), 1.2)
	_done = true


## 闷笑满：笑倒（综合演练里就是失败）
func _punish(kind: String) -> void:
	if kind != "laugh":
		# 魔力满：自动释放——清空魔力、闷笑降一半
		bursts += 1
		if player.fatigue:
			player.fatigue.clear()
		if player.laugh:
			player.laugh.set_value(player.laugh.value * 0.5)
		flash(Color(1, 0.95, 0.8, 0.8), 0.5)
		Audio.play("star_burst", -3.0)
		var caps: Array = TaskInspect.data().get("magic_burst", ["魔力释放！"])
		pop(actors.get("princess"), "魔力释放！", GOLD, 1.4)
		narrate(str(caps.pick_random()), 1.6)
		var pr: CGActor = actors.get("princess")
		if pr:
			pr.shake(0.5)
		return
	laughed_out = true
	# 笑倒：台上笑软一下，这一站结束（TaskInspect 判失败 → 失败小剧场 + CG）
	busy = true
	var pa: CGActor = actors.get("princess")
	if pa:
		pa.set_pose("helpless_2", "helpless")
		pa.shake(0.8)
	pop(pa, "笑、笑倒了……", PINK, 1.4)
	Audio.play("laugh", -2.0)
	await _sleep(1.2)
	busy = false
	_done = true


func _update_count() -> void:
	pass

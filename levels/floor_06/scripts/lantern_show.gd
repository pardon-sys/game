class_name LanternShow
extends TrainingStage
## 第 6 天晚上 镇长「笑声灯笼」（借训练小游戏的画面）：两只脚伸进祖传的「欢笑踏板」，里面的软毛刷刷脚底，笑声给灯笼充能。台词 data/after/night.json 的 lantern。
##   ↑↓ 调刷子的强度（level 0~4）：闷笑每秒按 RATES[level] 涨落；魔力疲倦每秒 +level × FATIGUE。
##   每盏灯笼要求闷笑停在 [lo, hi] 里 HOLD 秒就点亮；超过 hi = 灯泡炸了（这盏重来，闷笑回落）；
##   魔力疲倦满 = 自动释放：震碎一盏已点亮的灯（那一盏要重新点亮）；全部点亮优先完成。
##   Esc 退出小游戏：委托没做完（play() 返回 null → 任务算中断，走回镇长那里能重新开始）。
## await play() → true。测试：quiet、press(键)、level。

const RATES := [-0.14, -0.03, 0.05, 0.1, 0.16]
const FATIGUE := 0.035
const HOLD := 2.2
const MIN_LOSS := 1
const MAX_LOSS := 1

static var quiet := false

var level := 0
var lit := 0
var hold := 0.0
var bursts := 0
var blown := 0
var last_extinguished := 0
var _done := false
var _info: Label
var _gauge: Control
var _crowd_t := 3.0
var _brush_t := 0.0


func panel_title() -> String:
	return "笑声灯笼"


func quit() -> void:
	if playing and not busy and not _done:
		quitting = true


func data() -> Dictionary:
	return AfterNight.data().get("lantern", {})


func lanterns() -> Array:
	return data().get("lanterns", [])


func stage_cast() -> Dictionary:
	return {"princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
		"seat": {"kind": "trap:foot_bath", "at": [0, 12]},
		"mayor": {"kind": "npc:mayor", "at": [-34, 4], "dir": "right"},
		"kid": {"kind": "npc:kid", "at": [32, 16], "dir": "left"}}


class Gauge extends Control:
	var stage: LanternShow
	func _draw() -> void:
		var h := size.y
		draw_rect(Rect2(0, 0, 10, h), Color(0.2, 0.14, 0.24))
		var ls := stage.lanterns()
		if stage.lit < ls.size():
			var L: Dictionary = ls[stage.lit]
			var lo := float(L["lo"])
			var hi := float(L["hi"])
			draw_rect(Rect2(0, h * (1.0 - hi), 10, h * (hi - lo)), Color(1, 0.85, 0.4, 0.7))
		var r := stage.player.laugh.ratio() if is_instance_valid(stage.player) and stage.player.laugh else 0.0
		draw_rect(Rect2(-2, h * (1.0 - r) - 1, 14, 2), Color(1, 0.5, 0.7))
		# 灯笼
		for i in ls.size():
			var c := Vector2(22 + i * 14, h - 8)
			draw_circle(c, 5.0, Color(1, 0.85, 0.45) if i < stage.lit else Color(0.3, 0.25, 0.32))
		var f := get_theme_default_font()
		draw_string(f, Vector2(20, 10), "刷子：%s" % stage.level_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)


func level_name() -> String:
	var lv: Array = data().get("levels", [])
	return str(lv[level]) if level < lv.size() else str(level)


func play() -> Variant:
	player = GameState.player
	rng.randomize()
	layer = 14
	t = {"name": panel_title()}
	_build_ui()
	hint_label.text = "↑↓ 调刷子的强度　让闷笑停在黄色的范围里"
	_info = _label(TEXT, 8)
	_info.size = Vector2(panel_body.size.x, 24)
	panel_body.add_child(_info)
	_gauge = Gauge.new()
	_gauge.stage = self
	_gauge.position = Vector2(4, 28)
	_gauge.size = Vector2(panel_body.size.x - 8, 56)
	panel_body.add_child(_gauge)
	if is_instance_valid(player):
		_start_fatigue = player.fatigue.value if player.fatigue else 0.0
		_start_laugh = player.laugh.value if player.laugh else 0.0
		if player.laugh:
			player.laugh.set_value(0.0)
		if player.fatigue:
			player.fatigue.clear()
	_enter_game()
	busy = true
	await _lines(data().get("intro", []))
	busy = false
	while not _done and not quitting:
		await get_tree().process_frame
	if quitting and not _done:
		# Esc：不做了（灯笼不算数，下次从头点）
		await _exit_game()
		finished.emit()
		return null
	busy = true
	await _lines(data().get("done", []))
	await _exit_game()
	finished.emit()
	return true


func _lines(lines: Array) -> void:
	if quiet or lines.is_empty():
		return
	Dialogue.start_lines(lines, "lantern_show")
	while Dialogue.is_active():
		await get_tree().process_frame
	GameState.in_dialogue = true


func _refresh() -> void:
	var ls := lanterns()
	if _info:
		_info.text = "%s\n点亮 %d / %d" % [str(ls[lit]["name"]) if lit < ls.size() else "全部点亮！", lit, ls.size()]
	if _gauge:
		_gauge.queue_redraw()


func _on_key(k: String) -> void:
	if k in ["UP", "W"]:
		level = mini(4, level + 1)
	elif k in ["DOWN", "S"]:
		level = maxi(0, level - 1)
	var br: Dictionary = data().get("brush", {})
	var pool: Array = br.get(str(level), [])
	if not pool.is_empty():
		narrate(str(pool.pick_random()), 1.4)
	_refresh()


func _tick(delta: float) -> void:
	if not is_instance_valid(player) or player.laugh == null:
		return
	var l := player.laugh
	# 刷子开着：闷笑只按刷子的强度涨落（不走平时的自然回落）
	if level > 0:
		l.notify_attacked()
	l.set_value(clampf(l.value + l.max_value * float(RATES[level]) * delta, 0.0, l.max_value * 0.99))
	if level > 0:
		add_fatigue(fatigue_max() * FATIGUE * level * delta)
		_brush_t -= delta
		if _brush_t <= 0.0:
			_brush_t = 0.9 - level * 0.12
			tickle("seat", "sole", level >= 4 and rng.randf() < 0.3)
			if rng.randf() < 0.35:
				say("princess", AfterNight.react(l.ratio()))
	var ls := lanterns()
	if lit >= ls.size():
		_done = true
		return
	var L: Dictionary = ls[lit]
	var r := l.ratio()
	if r > float(L["hi"]):
		_burst()
	elif r >= float(L["lo"]):
		hold += delta
		if hold >= HOLD:
			hold = 0.0
			lit += 1
			var lt: Array = data().get("lit", [])
			if not lt.is_empty():
				narrate(str(lt.pick_random()), 1.6)
			Audio.play("pickup", -6.0)
			flash(Color(1, 0.9, 0.5, 0.5), 0.4)
	else:
		hold = maxf(0.0, hold - delta * 0.5)
	_crowd_t -= delta
	if _crowd_t <= 0.0:
		_crowd_t = rng.randf_range(3.0, 5.0)
		var cr: Array = data().get("crowd", [])
		if not cr.is_empty():
			say("kid", str(cr.pick_random()))
	_refresh()


func _burst() -> void:
	bursts += 1
	hold = 0.0
	var b: Array = data().get("burst", [])
	if not b.is_empty():
		narrate(str(b.pick_random()), 1.6)
	Audio.play("hit", -4.0)
	flash(Color(1, 1, 1, 0.6), 0.3)
	var L: Dictionary = lanterns()[lit]
	player.laugh.set_value(player.laugh.max_value * float(L["lo"]) * 0.5)
	level = maxi(0, level - 2)


## 魔力疲倦满：只吹灭少量灯；完成后不再倒扣。last_extinguished供边界测试使用。
func _punish(kind: String) -> void:
	if kind != "fatigue" or _done:
		return
	if lit >= lanterns().size():
		_done = true
		return
	blown += 1
	if player.fatigue:
		player.fatigue.clear()
	last_extinguished = mini(lit, rng.randi_range(MIN_LOSS, MAX_LOSS))
	var bl: Array = data().get("blown" if last_extinguished > 0 else "blown_none", [])
	if not bl.is_empty():
		var caption := str(bl.pick_random())
		narrate(caption % last_extinguished if last_extinguished > 0 else caption, 2.0)
	flash(Color(1, 0.9, 1, 0.8), 0.5)
	Audio.play("star_burst", -4.0)
	lit -= last_extinguished
	hold = 0.0
	_refresh()


func _update_count() -> void:
	pass

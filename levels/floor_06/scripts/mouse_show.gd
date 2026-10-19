class_name MouseShow
extends TrainingStage
## 第 3 天晚上「逃跑的痒痒鼠」：五只喝过痒痒药的小白鼠钻进了粉色公主的衣服里（借训练小游戏的画面）。台词 data/after/night.json 的 mice。
##   身体图六格（Q 袖子 / W 腋下 / E 腰 / A 大腿 / S 膝盖窝 / D 鞋里）：每只小鼠待在一格，每 move_t 秒沿着 links 窜到相邻的格子（越往后窜得越快）。
##   每只小鼠在身上就一直挠（闷笑每秒 +RATE，腋下 / 鞋里更痒）；按那一格的键「拍」：有小鼠 = 抓住一只，没有 = 拍到自己的痒处（闷笑 +MISS）。
##   抓到四只以后，最后一只钻进鞋里不出来：限时连按 D LAST_MASH 下把它抖出来（没抖出来就再挠一阵、重来）。
##   闷笑满 = 失败（after_fail_mice）。await play() → 抓完了没有。测试：quiet、press(键)。

const MICE := 5
const RATE := 0.03
const MISS := 0.06
const LAST_MASH := 8
const LAST_TIME := 4.0

static var quiet := false

var mice: Array = []
var caught := 0
var misses := 0
var last_phase := false
var mash := 0
var _move_t := 1.2
var _last_t := LAST_TIME
var _say_t := 1.0
var _hit_t := 0.0
var _done := false
var _failed := false
var _info: Label
var _chart: Control


func panel_title() -> String:
	return "逃跑的痒痒鼠"


func quit() -> void:
	pass


func stage_cast() -> Dictionary:
	return {"princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
		"ph": {"kind": "npc:pharmacist", "at": [-34, 6], "dir": "right"}}


func data() -> Dictionary:
	return AfterNight.data().get("mice", {})


func spots() -> Array:
	return data().get("spots", [])


class Chart extends Control:
	var stage: MouseShow
	func _draw() -> void:
		var sp: Array = stage.spots()
		var cw := size.x / 3.0
		var f := get_theme_default_font()
		for i in sp.size():
			var s: Dictionary = sp[i]
			var r := Rect2((i % 3) * cw + 1, (i / 3) * 15 + 1, cw - 2, 13)
			var n := stage.mice.count(str(s["id"]))
			draw_rect(r, Color(0.95, 0.75, 0.85) if n > 0 else Color(0.2, 0.16, 0.26))
			draw_string(f, r.position + Vector2(2, 10), "%s %s%s" % [s["key"], s["name"], (" ×%d" % n) if n > 0 else ""], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 2, 7,
				Color(0.15, 0.08, 0.15) if n > 0 else Color.WHITE)


func play() -> bool:
	player = GameState.player
	rng.randomize()
	layer = 14
	t = {"name": panel_title()}
	_build_ui()
	hint_label.text = "小鼠在哪一格就按哪一格的键拍"
	_info = _label(TEXT, 8)
	_info.size = Vector2(panel_body.size.x, 40)
	panel_body.add_child(_info)
	_chart = Chart.new()
	_chart.stage = self
	_chart.position = Vector2(2, 50)
	_chart.size = Vector2(panel_body.size.x - 4, 32)
	panel_body.add_child(_chart)
	if is_instance_valid(player):
		_start_fatigue = player.fatigue.value if player.fatigue else 0.0
		_start_laugh = player.laugh.value if player.laugh else 0.0
		if player.laugh:
			player.laugh.set_value(0.0)
	_enter_game()
	var ids: Array = spots().map(func(s): return str(s["id"]))
	for i in MICE:
		mice.append(str(ids[i % ids.size()]))
	busy = true
	await _lines(data().get("intro", []))
	busy = false
	while not _done:
		await get_tree().process_frame
	busy = true
	if not _failed:
		await _lines(data().get("done", []))
	await _exit_game()
	finished.emit()
	return not _failed


func _lines(lines: Array) -> void:
	if quiet or lines.is_empty():
		return
	Dialogue.start_lines(lines, "mouse_show")
	while Dialogue.is_active():
		await get_tree().process_frame
	GameState.in_dialogue = true


func _spot_of(id: String) -> Dictionary:
	for s in spots():
		if str(s["id"]) == id:
			return s
	return {}


func _refresh() -> void:
	if _info:
		_info.text = "抓到 %d / %d　拍空 %d%s" % [caught, MICE, misses, ("\n鞋里那只：连按 D %d / %d" % [mash, LAST_MASH]) if last_phase else ""]
	if _chart:
		_chart.queue_redraw()


func _tick(delta: float) -> void:
	if last_phase:
		_last_t -= delta
		add_laugh(laugh_max() * RATE * 1.4 * delta)
		_tickle_fx("shoe", delta)
		if _last_t <= 0.0:
			_last_t = LAST_TIME
			mash = 0
			add_laugh(laugh_max() * 0.1)
			say("princess", "哈哈……抖、抖不出来……！")
		_refresh()
		return
	# 小鼠乱窜
	_move_t -= delta
	if _move_t <= 0.0:
		_move_t = lerpf(1.3, 0.6, float(caught) / MICE)
		var links: Dictionary = data().get("links", {})
		for i in mice.size():
			if rng.randf() < 0.7:
				var nb: Array = links.get(str(mice[i]), [])
				if not nb.is_empty():
					mice[i] = str(nb.pick_random())
		if not mice.is_empty():
			narrate(str(_spot_of(str(mice.pick_random())).get("desc", "")), 1.6)
	# 挠
	for m in mice:
		var k := 1.3 if str(m) in ["armpit", "shoe"] else 1.0
		add_laugh(laugh_max() * RATE * k * delta)
		_tickle_fx(str(m), delta)
	_refresh()


func _tickle_fx(spot_id: String, delta: float) -> void:
	_hit_t -= delta
	if _hit_t <= 0.0:
		_hit_t = 0.4
		tickle("princess", str(_spot_of(spot_id).get("zone", "waist")))
	_say_t -= delta
	if _say_t <= 0.0:
		_say_t = 1.8
		say("princess", AfterNight.react(player.laugh.ratio() if is_instance_valid(player) and player.laugh else 0.0))


func _on_key(k: String) -> void:
	if last_phase:
		if k == "D":
			mash += 1
			if mash >= LAST_MASH:
				caught += 1
				mice.clear()
				_done = true
		_refresh()
		return
	var sp := {}
	for s in spots():
		if str(s["key"]) == k:
			sp = s
	if sp.is_empty():
		return
	var id := str(sp["id"])
	if id in mice:
		mice.erase(id)
		caught += 1
		var c: Array = data().get("caught", ["抓到了！"])
		say("princess", str(c.pick_random()))
		Audio.play("pickup", -8.0, 0.1)
		if caught >= MICE - 1:
			_last()
	else:
		misses += 1
		var ms: Array = data().get("miss", [])
		if not ms.is_empty():
			narrate(str(ms.pick_random()), 1.4)
		tickle("princess", str(sp.get("zone", "waist")))
		add_laugh(laugh_max() * MISS)
	_refresh()


func _last() -> void:
	busy = true
	mice = ["shoe"]
	last_phase = true
	mash = 0
	_last_t = LAST_TIME
	await _lines(data().get("last", []))
	busy = false


func _punish(kind: String) -> void:
	if kind == "fatigue":
		if player.fatigue:
			player.fatigue.clear()
		return
	_failed = true
	_done = true


func _update_count() -> void:
	pass

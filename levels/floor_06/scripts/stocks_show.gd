class_name StocksShow
extends TrainingStage
## 第 2 天早上的广场足枷示众（七日赎罪）：借用训练小游戏的画面（右边小舞台、左上面板、魔力疲倦 / 闷笑条）。
## 规则：
##   示众 TIME 秒倒计时，孩子一个接一个来挠（工具按 TOOLS 轮换），每个孩子自己挑一个部位（PARTS），挠完这个部位的时长换下一个。
##   J / E 挣扎：闷笑 −STRUGGLE（「硬撑」减半、「挑衅」×1.5），挠的手停 0.3 秒；同一部位连挣 SWITCH_AFTER 次，孩子嫌你乱动、换部位。
##   1~4：花一次求情（初始 PLEAS 次）把这一下引到别的部位，倒计时 +PLEA_TIME 秒。
##   孩子挠完一段：暂停示众，对话框里问怎么应对（装没事 / 求饶 / 顶嘴，选项页），挂负面状态（RESPONSES）到下一个孩子结束。
##   闷笑满 = 笑出声（bursts +1、闷笑回到 40%，赎罪簿另外罚工时）；魔力疲倦满 = 自动释放魔法，队长「不符合管教，加时！」倒计时 +EXTRA。
##   倒计时到 0 = 过关；释放超过 FAINT_AFTER 次 = 笑晕（也算过关，结局过场不一样）。
## 演出：孩子登场、换人的应对、笑出声、魔力释放，都暂停示众（busy）在对话框里演一小段（data/after/stocks.json ← after_text/stocks.py：
##   原来过场里的挠法描写和对话）；挠的过程中公主的反应用立绘旁的反应字（GameState.princess_reacted，不暂停）。
##   await play_show() → {bursts, releases, fainted, pleads_used}
## 测试：press("J") / plead(部位序号) / respond(id) / time_scale；auto_respond 让间隙自动选；quiet = true 不演对话（直接测数值）。

const TIME := 120.0
const EXTRA := 15.0
const FAINT_AFTER := 5
const STRUGGLE := 0.025
const SWITCH_AFTER := 6
const PLEAS := 3
const PLEA_TIME := 2.0
const TEXT_PATH := "res://data/after/stocks.json"
## 部位：闷笑每秒涨上限的比例、魔力疲倦倍率、这个孩子挠多久
const PARTS := [
	{"id": "ball", "name": "前脚掌", "desc": "非常痒", "rate": 0.09, "fatigue": 1.2, "time": 5.0},
	{"id": "sole", "name": "脚心", "desc": "第二痒", "rate": 0.07, "fatigue": 1.0, "time": 7.0},
	{"id": "toes", "name": "脚趾缝", "desc": "痒，但有点舒服", "rate": 0.04, "fatigue": 1.8, "time": 9.0},
	{"id": "arch", "name": "脚弓", "desc": "能忍，但还是挺痒", "rate": 0.03, "fatigue": 0.8, "time": 11.0},
]
## 孩子自己挑部位的权重（前脚掌、脚心最受欢迎）
const PICK_WEIGHTS := [3.0, 3.0, 1.5, 1.0]
const TOOLS := [
	{"id": "feather", "name": "羽毛", "mul": 1.0, "fx": "feather", "kid": "小汤姆"},
	{"id": "grass", "name": "狗尾巴草", "mul": 1.1, "fx": "feather", "kid": "小莉莉"},
	{"id": "brush", "name": "小刷子", "mul": 1.25, "fx": "brush", "kid": "派对主人和汤姆"},
	{"id": "crowd", "name": "一群小孩", "mul": 1.45, "fx": "hand", "kid": "一群小孩"},
]
const RESPONSES := {
	"calm": {"name": "装没事", "debuff": "硬撑", "desc": "挣扎效果减半"},
	"beg": {"name": "求饶", "debuff": "丢脸", "desc": "闷笑涨 +25%，下一个孩子时间 −30%，求情 +1"},
	"sass": {"name": "顶嘴", "debuff": "挑衅", "desc": "两只脚一起挠、疲倦 +30%，挣扎 ×1.5，求情 −1"},
}
const RESPONSE_IDS := ["calm", "beg", "sass"]
## 魔力疲倦：涨的速度 = 闷笑涨的绝对值 × 这个系数（× 部位 / 状态倍率）
const FATIGUE_K := 1.35
## 挠的过程中公主的反应字隔多久冒一句
const LIVE_EVERY := 2.4

static var auto_respond := ""
static var quiet := false
static var _text := {}

var time_left := TIME
var bursts := 0
var releases := 0
var fainted := false
var pleads := PLEAS
var pleads_used := 0
var kid_no := 0
var tool := {}
var part := {}
var part_left := 0.0
var debuff := ""
var both_feet := false
var upgrade := 0
var responding := false
var _pause := 0.0
var _struggles := 0
var _hit_t := 0.0
var _live_t := 1.0
var _info: Label
var _done := false


static func text() -> Dictionary:
	if _text.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEXT_PATH)) if FileAccess.file_exists(TEXT_PATH) else null
		_text = parsed if parsed is Dictionary else {}
	return _text


# ------------------------------------------------------------------ 流程
func play_show() -> Dictionary:
	player = GameState.player
	rng.randomize()
	layer = 14
	t = {"name": "广场足枷示众"}
	_build_ui()
	hint_label.text = "J / E 挣扎（降闷笑）　1~4 求情换部位"
	_info = _label(TEXT, 8)
	_info.size = panel_body.size
	_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel_body.add_child(_info)
	if is_instance_valid(player):
		_start_fatigue = player.fatigue.value if player.fatigue else 0.0
		_start_laugh = player.laugh.value if player.laugh else 0.0
		if player.fatigue:
			player.fatigue.clear()
		if player.laugh:
			player.laugh.set_value(player.laugh.max_value * 0.15)
	_enter_game()
	await _next_kid()
	while not _done:
		await get_tree().process_frame
	await _exit_game()
	finished.emit()
	return {"bursts": bursts, "releases": releases, "fainted": fainted, "pleads_used": pleads_used}


func panel_title() -> String:
	return "广场足枷示众"


func quit() -> void:
	pass   # 示众不能中途退出


func stage_cast() -> Dictionary:
	return {"princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
		"stocks": {"kind": "trap:stocks", "at": device_at("stocks")},
		"kid": {"kind": "npc:kid", "at": [-18, 22], "dir": "right"},
		"kid2": {"kind": "npc:kid", "at": [18, 22], "dir": "left"},
		"cap": {"kind": "npc:captain", "at": [-56, 2], "dir": "right"},
		"sup": {"kind": "npc:supervisor", "at": [-70, 12], "dir": "right"},
		"v1": {"kind": "npc:merchant", "at": [52, 2], "dir": "left"},
		"v2": {"kind": "npc:maid", "at": [66, 10], "dir": "left"}}


## 暂停示众，在对话框里演几句（quiet 时跳过）。
func _lines(lines: Array) -> void:
	if quiet or lines.is_empty():
		return
	busy = true
	Dialogue.start_lines(lines, "stocks_show")
	while Dialogue.is_active():
		await get_tree().process_frame
	GameState.in_dialogue = true
	busy = false


# ------------------------------------------------------------------ 孩子 / 部位
func _next_kid() -> void:
	tool = TOOLS[(kid_no + upgrade) % TOOLS.size()]
	var kids: Array = text().get("kids", [])
	var script_kid: Dictionary = kids[kid_no] if kid_no < kids.size() and kid_no < TOOLS.size() and upgrade == 0 else {}
	kid_no += 1
	_pick_part(-1, false)
	part_left = float(part["time"])
	if debuff == "beg":
		part_left *= 0.7
	both_feet = debuff == "sass"
	var k2: CGActor = actors.get("kid2")
	if k2:
		k2.visible = both_feet or str(tool["id"]) in ["brush", "crowd"]
	_refresh_info()
	# 登场 + 开挠的描写
	var lines: Array = []
	if not script_kid.is_empty():
		lines.append_array(script_kid.get("intro", []))
	else:
		var pool: Array = text().get("generic", {}).get("intro", {}).get(str(tool["id"]), [])
		if not pool.is_empty():
			lines.append_array(pool.pick_random())
	lines.append_array(_start_lines())
	await _lines(lines)
	pop(actors.get("kid"), "%s · %s → %s" % [tool["kid"], tool["name"], part["name"]], GOLD, 1.4)


## 开挠的描写：旁白（工具 × 部位）+ 公主的第一句（部位）
func _start_lines() -> Array:
	var out: Array = []
	var nar := str(text().get("narration", {}).get(str(tool["id"]), {}).get(str(part["id"]), ""))
	if nar != "":
		out.append({"speaker": "", "text": nar})
	var st: Array = text().get("start", {}).get(str(part["id"]), [])
	if not st.is_empty():
		out.append(st.pick_random())
	return out


## 孩子挑部位（avoid：刚挣扎过的部位不挑）
func _pick_part(avoid: int, announce := true) -> void:
	var total := 0.0
	for i in PARTS.size():
		if i != avoid:
			total += PICK_WEIGHTS[i]
	var r := rng.randf() * total
	for i in PARTS.size():
		if i == avoid:
			continue
		r -= PICK_WEIGHTS[i]
		if r <= 0.0:
			_set_part(i, announce)
			return
	_set_part(0 if avoid != 0 else 1, announce)


func _set_part(i: int, announce := true) -> void:
	part = PARTS[i]
	_struggles = 0
	if announce:
		pop(actors.get("princess"), "→ %s（%s）" % [part["name"], part["desc"]], PINK, 1.2)
	_refresh_info()


func part_index() -> int:
	return PARTS.find(part)


## 1~4：求情换部位
func plead(i: int) -> void:
	if responding or i < 0 or i >= PARTS.size() or PARTS[i] == part:
		return
	if pleads <= 0:
		pop(actors.get("princess"), "没有求情次数了……", BAD, 1.0)
		return
	pleads -= 1
	pleads_used += 1
	time_left += PLEA_TIME
	var pl: Array = text().get("plead", ["换个地方……"])
	say("princess", str(pl[pleads % pl.size()]))
	say("kid", "好吧～那就%s！" % PARTS[i]["name"])
	_set_part(i)
	var nar := str(text().get("narration", {}).get(str(tool["id"]), {}).get(str(part["id"]), ""))
	if nar != "":
		GameState.princess_reacted.emit(nar.trim_prefix("（").trim_suffix("）"), 2.0)


## 孩子挠完一段：暂停，问怎么应对。
func _start_respond() -> void:
	responding = true
	GameState.princess_reacted.emit("", 0.0)
	say("cap", "下一个。")
	_refresh_info()
	var kids: Array = text().get("kids", [])
	var idx := kid_no - 1
	var sk: Dictionary = kids[idx] if idx < kids.size() and idx < TOOLS.size() and upgrade == 0 else {}
	var gen: Dictionary = text().get("generic", {})
	var prompt := str(sk.get("prompt", (gen.get("prompt", ["怎么办？"]) as Array).pick_random()))
	var texts: Array = []
	var opts: Array = sk.get("options", ["（装作没事）", "求、求求你们……", "哼！一点都不痒！"])
	for i in RESPONSE_IDS.size():
		texts.append("%s〔%s〕" % [opts[i], RESPONSES[RESPONSE_IDS[i]]["debuff"]])
	if count_label:
		count_label.add_theme_color_override("font_color", GOLD)
		count_label.text = "　".join(RESPONSE_IDS.map(func(id): return "%s：%s" % [RESPONSES[id]["debuff"], RESPONSES[id]["desc"]]))
	var pick := "calm"
	if auto_respond != "":
		pick = auto_respond
	elif not quiet:
		busy = true
		var i: int = await Dialogue.runner.choice_menu.ask(texts, prompt)
		pick = RESPONSE_IDS[clampi(i, 0, 2)]
		busy = false
	else:
		return     # quiet：等测试调 respond()
	if responding:
		await respond(pick, sk)


func respond(id: String, sk := {}) -> void:
	if not responding or not RESPONSES.has(id):
		return
	responding = false
	debuff = id
	if id == "beg":
		pleads += 1
	elif id == "sass" and pleads > 0:
		pleads -= 1
	var lines: Array = sk.get("replies", {}).get(id, [])
	if lines.is_empty():
		var pool: Array = text().get("generic", {}).get("replies", {}).get(id, [])
		if not pool.is_empty():
			lines = pool.pick_random()
	pop(actors.get("princess"), "状态：%s（%s）" % [RESPONSES[id]["debuff"], RESPONSES[id]["desc"]], BAD, 1.6)
	await _lines(lines)
	await _next_kid()


# ------------------------------------------------------------------ 每帧
func _tick(delta: float) -> void:
	if responding:
		return
	time_left -= delta
	if time_left <= 0.0:
		_finish(false)
		return
	part_left -= delta
	if part_left <= 0.0:
		if str(part["id"]) == "arch":
			upgrade += 1
			say("kid", "脚弓不好玩……下一个用更厉害的！")
		_start_respond()
		return
	if _pause > 0.0:
		_pause -= delta
		_refresh_info()
		return
	# 挠：闷笑 / 魔力疲倦
	var mul := float(tool["mul"]) * (1.25 if debuff == "beg" else 1.0) * (1.6 if both_feet else 1.0)
	var gain := laugh_max() * float(part["rate"]) * mul * delta
	add_laugh(gain)
	add_fatigue(gain * FATIGUE_K * float(part["fatigue"]) * (1.3 if debuff == "sass" else 1.0))
	_hit_t -= delta
	if _hit_t <= 0.0:
		_hit_t = 0.35
		tickle("kid", "sole", rng.randf() < 0.12)
		if both_feet:
			tickle("kid2", "sole")
	_live_t -= delta
	if _live_t <= 0.0:
		_live_t = LIVE_EVERY
		var live: Array = text().get("live", {}).get(str(part["id"]), [])
		if not live.is_empty():
			var line := str(live.pick_random())
			GameState.princess_reacted.emit(line, 1.6)
			say("princess", line)
	_refresh_info()


func _on_key(k: String) -> void:
	if k == "J" or k == "E":
		_struggle()


func _input(event: InputEvent) -> void:
	if playing and not busy and not responding and event is InputEventKey and event.pressed and not event.echo:
		var kc: int = (event as InputEventKey).keycode
		if kc >= KEY_1 and kc <= KEY_4:
			get_viewport().set_input_as_handled()
			plead(kc - KEY_1)
			return
	super(event)


func _struggle() -> void:
	if responding or not is_instance_valid(player) or player.laugh == null:
		return
	var k := (0.5 if debuff == "calm" else (1.5 if debuff == "sass" else 1.0))
	player.laugh.set_value(maxf(0.0, player.laugh.value - player.laugh.max_value * STRUGGLE * k))
	_pause = 0.3
	_struggles += 1
	var p: CGActor = actors.get("princess")
	if p:
		p.shake(0.12)
	if _struggles >= SWITCH_AFTER:
		say("kid", "别乱动！……那换这里！")
		_pick_part(part_index())


# ------------------------------------------------------------------ 满了
## 闷笑满（笑出声）/ 魔力疲倦满（自动释放）：都暂停演一小段
func _punish(kind: String) -> void:
	busy = true
	var p: CGActor = actors.get("princess")
	if kind == "laugh":
		bursts += 1
		flash(Color(1, 0.7, 0.85, 0.7), 0.4)
		Audio.play("laugh", -3.0)
		pop(p, "笑出声了！", PINK, 1.4)
		if player.laugh:
			player.laugh.set_value(player.laugh.max_value * 0.4)
		var pool: Array = text().get("burst", [])
		await _lines(pool[(bursts - 1) % pool.size()] if not pool.is_empty() else [])
		if quiet:
			await _sleep(0.8)
	else:
		releases += 1
		flash(Color(1, 0.85, 1, 0.9), 0.6)
		Audio.play("star_burst", -2.0)
		pop(p, "魔力释放！", GOLD, 1.4)
		if p:
			p.set_pose("helpless_2", "helpless")
			p.shake(0.6)
		await _sleep(0.7)
		if player.fatigue:
			player.fatigue.clear()
		if player.laugh:
			player.laugh.set_value(player.laugh.max_value * 0.5)
		if releases > FAINT_AFTER:
			pop(p, "……", DIM, 2.0)
			await _sleep(1.0)
			_finish(true)
			busy = false
			return
		time_left += EXTRA
		pop(actors.get("cap"), "+%d 秒" % int(EXTRA), BAD, 1.4)
		var pool: Array = text().get("release", [])
		await _lines(pool[(releases - 1) % pool.size()] if not pool.is_empty() else [])
		if quiet:
			say("cap", "不符合管教！加时！")
			await _sleep(0.6)
		if p:
			p.set_pose("helpless_1", "helpless")
	busy = false


func _finish(faint: bool) -> void:
	fainted = faint
	_done = true


func _refresh_info() -> void:
	if _info == null or part.is_empty():
		return
	var lines := ["剩余 %d 秒" % ceili(maxf(time_left, 0.0)),
		"%s·%s" % [tool.get("kid", ""), tool.get("name", "")],
		"部位：%s" % part["name"],
		"求情 ×%d　%s" % [pleads, (RESPONSES[debuff]["debuff"] if debuff != "" else "")],
		"笑出声 %d　释放 %d" % [bursts, releases]]
	_info.text = "\n".join(lines)
	if count_label and not responding:
		count_label.add_theme_color_override("font_color", TEXT)
		count_label.text = "求情换部位：1 前脚掌　2 脚心　3 脚趾缝　4 脚弓"


func _update_count() -> void:
	pass

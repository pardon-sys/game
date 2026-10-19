class_name TomPrankShow
extends TrainingStage
## 第 5 天夜里「小汤姆的恶作剧」（借训练小游戏的画面，文本选择）：玩家扮演小汤姆，带着小猫橘子溜进蓝色小屋挠熟睡的姐姐的脚。台词 data/after/tom.json。
##   四段（phases：观察 / 轻挠 / 橘子上场 / 一起来），每段几轮，每轮从选项里挑一个（选项页）：
##     itch（痒）/ comfort（舒服）按选项涨落；每轮痒自己退 ITCH_DECAY。画面上的两条计量借用公主的闷笑条（= 痒）和魔力疲倦条（= 舒服）。
##     描写进画面下方的反应框，姐姐睡梦中的反应飘在她旁边（按两条里更高的那条分档）。
##   痒满 → 笑醒（caught）；舒服满 → 魔力自动释放 → 选「加大强度」= 一直笑到第二次释放、笑晕（fainted），选「住手」= 被惊醒（caught）；
##   四段做完两条都没满 → 悄悄溜走（quiet）。结果写 vars.tom_prank_result、剧情标记 tom_prank_<结果>。
## await play() → 结果字符串。测试：quiet（不演对话）、auto_picks（每轮选第几个）、auto_release（"intensify" / "stop"）。

const TEXT_PATH := "res://data/after/tom.json"
const ITCH_DECAY := 5.0
const FULL := 100.0

static var quiet := false
static var auto_picks: Array = []
static var auto_release := ""
static var _text := {}

var itch := 0.0
var comfort := 0.0
var result := ""
var picks_made := 0


static func text() -> Dictionary:
	if _text.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEXT_PATH)) if FileAccess.file_exists(TEXT_PATH) else null
		_text = parsed if parsed is Dictionary else {}
	return _text


func panel_title() -> String:
	return "小汤姆的恶作剧"


func quit() -> void:
	pass


func stage_cast() -> Dictionary:
	return {"princess": {"kind": "princess", "at": [0, 4], "visual": "normal", "anim": "idle", "dir": "down"},
		"bed": {"kind": "trap:cushion", "at": [0, 8]},
		"tom": {"kind": "npc:kid", "at": [-6, 26], "dir": "up"}}


## 小猫橘子（程序画：橘色的团子 + 尾巴）
class Cat extends Node2D:
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		var o := Color(0.95, 0.6, 0.25)
		draw_circle(Vector2(0, -4), 5.0, o)
		draw_circle(Vector2(5, -8), 3.5, o)
		draw_colored_polygon(PackedVector2Array([Vector2(3, -11), Vector2(4, -14), Vector2(6, -11)]), o)
		draw_colored_polygon(PackedVector2Array([Vector2(6, -11), Vector2(8, -14), Vector2(8, -10)]), o)
		draw_line(Vector2(-5, -4), Vector2(-9, -8 + sin(_t * 4.0) * 2.0), o, 2.0)
		draw_circle(Vector2(6, -8), 0.7, Color(0.1, 0.1, 0.1))


func play() -> String:
	player = GameState.player
	rng.randomize()
	layer = 14
	t = {"name": panel_title()}
	_build_ui()
	hint_label.text = "别把姐姐弄醒：痒（闷笑条）满了会笑醒，舒服（魔力疲倦条）满了会被魔力惊醒"
	if is_instance_valid(player):
		_start_fatigue = player.fatigue.value if player.fatigue else 0.0
		_start_laugh = player.laugh.value if player.laugh else 0.0
	_enter_game()
	var cat := Cat.new()
	cat.position = Vector2(14, 26)
	cast_root.add_child(cat)
	_sync_bars()
	busy = true
	await _lines(text().get("intro", []))
	result = await _run_phases()
	await _ending()
	GameState.vars["tom_prank_result"] = result
	for r in ["caught", "quiet", "fainted"]:
		GameState.set_flag("tom_prank_" + r, r == result)
	busy = false
	await _exit_game()
	finished.emit()
	return result


func _lines(lines: Array) -> void:
	if quiet or lines.is_empty():
		return
	Dialogue.start_lines(lines, "tom_prank")
	while Dialogue.is_active():
		await get_tree().process_frame
	GameState.in_dialogue = true


func _run_phases() -> String:
	for ph in text().get("phases", []):
		var phase: Dictionary = ph
		for r in int(phase.get("rounds", 1)):
			var opt := await _pick(phase)
			_apply(opt)
			if itch >= FULL:
				return "caught_itch"
			if comfort >= FULL:
				return await _release()
			itch = maxf(0.0, itch - ITCH_DECAY)
			_sync_bars()
	return "quiet"


func _pick(phase: Dictionary) -> Dictionary:
	var opts: Array = phase.get("options", [])
	var i := 0
	if not auto_picks.is_empty():
		i = int(auto_picks.pop_front())
	elif not quiet:
		var texts: Array = opts.map(func(o): return str(o.get("text", "")))
		var prompt := "%s（痒 %d%%　舒服 %d%%）" % [str(phase.get("prompt", "")), int(itch), int(comfort)]
		i = await Dialogue.runner.choice_menu.ask(texts, prompt)
	picks_made += 1
	return opts[clampi(i, 0, opts.size() - 1)]


func _apply(opt: Dictionary) -> void:
	itch = clampf(itch + float(opt.get("itch", 0)), 0.0, FULL)
	comfort = clampf(comfort + float(opt.get("comfort", 0)), 0.0, FULL)
	var desc := str(opt.get("desc", ""))
	if desc != "":
		narrate(desc, 2.8)
	if str(opt.get("tom", "")) != "":
		say("tom", str(opt["tom"]))
	if opt.has("zone"):
		var by := str(opt.get("by", "tom"))
		tickle("tom" if by != "cat" else "princess", str(opt["zone"]), bool(opt.get("special", false)))
	say("princess", _sleep_line())
	_sync_bars()


## 姐姐睡梦中的反应：按痒 / 舒服里更高的那条分档
func _sleep_line() -> String:
	var s: Dictionary = text().get("sleep", {})
	var key := "itch" if itch >= comfort else "comfort"
	var v := maxf(itch, comfort)
	var tier := "low" if v < 40.0 else ("mid" if v < 75.0 else "high")
	var pool: Array = s.get(key, {}).get(tier, ["……"])
	return str(pool.pick_random())


## 舒服满了：魔力自动释放 → 加大强度（笑晕）还是住手（被惊醒）
func _release() -> String:
	flash(Color(1, 0.9, 0.6, 0.8), 0.6)
	Audio.play("star_burst", -4.0)
	await _lines(text().get("release", []))
	var choice := auto_release
	if choice == "" and not quiet:
		var i: int = await Dialogue.runner.choice_menu.ask(text().get("release_options", []), str(text().get("release_prompt", "")))
		choice = "intensify" if i == 0 else "stop"
	if choice == "intensify":
		for k in 6:
			tickle("tom", "sole", k % 2 == 0)
			await get_tree().create_timer(0.15).timeout
		flash(Color(1, 0.9, 0.6, 0.8), 0.6)
		return "fainted"
	return "caught_release"


func _ending() -> void:
	match result:
		"caught_itch":
			await _lines(text().get("wake_itch", []))
			await _lines(text().get("caught_after", []))
			result = "caught"
		"caught_release":
			await _lines(text().get("wake_release", []))
			await _lines(text().get("caught_after", []))
			result = "caught"
		"fainted":
			await _lines(text().get("faint", []))
		_:
			await _lines(text().get("quiet", []))


## 借公主的闷笑条 / 魔力疲倦条显示痒 / 舒服
func _sync_bars() -> void:
	if not is_instance_valid(player):
		return
	if player.laugh:
		player.laugh.set_value(player.laugh.max_value * itch / FULL * 0.99)
	if player.fatigue:
		player.fatigue.set_value(player.fatigue.max_value * comfort / FULL * 0.99)
	_update_bars()


func _tick(_delta: float) -> void:
	pass


## 计量是自己算的，不走训练小游戏的惩罚
func _punish(_kind: String) -> void:
	pass


func _update_count() -> void:
	pass

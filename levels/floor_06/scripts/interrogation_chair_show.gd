class_name InterrogationChairShow
extends ErrandWorkStage
## 骑士篇 D 夜探地牢被发现时：被按上挠痒审问椅（小游戏画面）。台词 data/after/knight.json 的 chair。
##   手腕、脚踝扣在椅子上，鞋被脱掉；两个队员一个挠脚心、一个挠腰，边挠边问「谁让你来的」。撑过 ENDURE 秒就被送回通风口。
##   闷笑每秒 +RATE，加强（WorkInterference）+STRONG_LAUGH；J 挣扎：闷笑 −STRUGGLE（冷却 STRUGGLE_COOL 秒，手腕扣着，用处不大）。
##   闷笑满：笑出声 → 队员「还没问完」，加时 EXTRA 秒（recover）。魔力释放见 ErrandWorkStage。
## 不存档、不算失败。测试：quiet、fixed_seed、press()、simulate()、left。

const PATH := "res://data/after/knight.json"
const ENDURE := 14.0
const EXTRA := 4.0
const RATE := 0.035
const STRONG_LAUGH := 0.08
const STRUGGLE := 0.03
const STRUGGLE_COOL := 0.5
const FATIGUE_RATE := 0.012

static var quiet := false
static var fixed_seed := -1
static var _text := {}

var left := ENDURE
var struggle_cool := 0.0
var bursts := 0
var _info: Label


static func data() -> Dictionary:
	if _text.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_text = (parsed.get("chair", {}) if parsed is Dictionary else {})
	return _text


func work_text() -> Dictionary:
	return data()


func phase_limits() -> Array:
	return [1]


func panel_title() -> String:
	return str(data().get("name", ""))


func quit() -> void:
	pass


func stage_cast() -> Dictionary:
	return {"princess": {"kind": "princess", "character": "pink", "at": [0, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
		"seat": {"kind": "trap:cushion", "at": [0, 18]},
		"guard": {"kind": "npc:guard", "at": [22, 12], "dir": "left"},
		"guard2": {"kind": "npc:guard", "at": [-22, 6], "dir": "right"}}


func play() -> bool:
	if not prepare_work(fixed_seed, quiet):
		return false
	tickler = "guard"
	_build_ui()
	hint_label.text = str(data()["hint"])
	_info = _label(TEXT, 8)
	_info.size = panel_body.size
	_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel_body.add_child(_info)
	_enter_game()
	rotate_tool()
	if not await start_work():
		return false
	return await work_result()


func _begin_segment() -> void:
	busy = false
	_refresh()


func _on_key(k: String) -> void:
	if k in ["J", "E"] and struggle_cool <= 0.0 and recovery_left <= 0.0:
		struggle_cool = STRUGGLE_COOL
		if player.laugh:
			player.laugh.set_value(maxf(0.0, player.laugh.value - laugh_max() * STRUGGLE))
		var a: CGActor = actors.get("princess")
		if a:
			a.shake(0.2)
		_pop_random(data().get("struggle", []), TEXT, 0.8)


## 笑出声：加时
func recover() -> void:
	bursts += 1
	left += EXTRA
	super()
	if actors.has("guard"):
		var lines: Array = data().get("extra", [])
		if not lines.is_empty():
			say("guard", str(lines[rng.randi_range(0, lines.size() - 1)]))


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
	struggle_cool = maxf(0.0, struggle_cool - dt)
	if recovery_left > 0.0:
		recovery_left = maxf(0.0, recovery_left - dt)
		return
	var event := work_clock(dt)
	work_laugh(laugh_max() * RATE * dt)
	add_fatigue(fatigue_max() * FATIGUE_RATE * dt)
	if event["strong"]:
		work_laugh(laugh_max() * STRONG_LAUGH)
		var q: Array = data().get("question", [])
		if not q.is_empty():
			say("guard2", str(q[rng.randi_range(0, q.size() - 1)]))
	if event["reaction"]:
		work_reaction(data(), 0, active_tool, tickler)
	left -= dt
	if left <= 0.0:
		advance_step()
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(_info):
		return
	_info.text = str(data()["panel"]) % [ceili(maxf(0.0, left)), bursts]
	count_label.text = str(data()["count"]) % ceili(maxf(0.0, left))

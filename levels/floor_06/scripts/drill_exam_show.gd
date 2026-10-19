class_name DrillExamShow
extends IceSitShow
## 特训考核「反过来的玩闹」：粉色公主全力挠蓝色公主，撑过 time 秒（借第一课的身体图和规则：亮起来的地方 Q W E / A S D 冻住、寒冷、表情、破功）。
##   多了两样：J 指挥小手挡下粉色公主的下一下（听话度 −BLOCK_COST，慢慢回来）；U 千手解放（把她推开 PUSH 秒，之后 BACKLASH 秒小手挠自己）。
##   释放算「失控」：加时 EXTRA 秒。破功三次 = 笑出声（不及格，演 fail；不算任务失败）；撑过时间 = 及格（演 pass）。
## 结果：passed（true / false）。

const BLOCK_COST := 35.0
const OBEY_REGEN := 6.0
const PUSH := 3.0
const BACKLASH := 5.0
const EXTRA := 8.0

var passed := false
var obedience := 100.0
var guard := false
var pushed_t := 0.0
var backlash_t := 0.0
var blocks := 0
var bursts := 0


func lesson_id() -> String:
	return "exam"


func hint_text() -> String:
	return "Q W E / A S D 冻住　J 小手挡　U 千手解放"


func stage_cast() -> Dictionary:
	return {"cap": {"kind": "npc:captain", "at": [-40, 2], "dir": "right"}}


func _build_cast(cast: Dictionary) -> void:
	super(cast)
	# 粉色公主就站在她旁边挠
	var pk: CGActor = actors.get("pink")
	if pk:
		pk.position = Vector2(16, 6)


func _begin() -> void:
	super()
	_pink_t = 99.0          # 第一课里的「粉色公主帮忙」不要：这里她就是主角
	time_left = float(lesson().get("time", 45.0))
	obedience = 100.0
	guard = false
	pushed_t = 0.0
	backlash_t = 0.0
	passed = false


func _refresh() -> void:
	if _info:
		_info.text = "剩余 %d 秒　笑出声 %d / %d\n表情 %d%%　寒冷 %d%%\n听话度 %d%s%s" % [ceili(time_left), marks, MARKS, int(face), int(cold),
			int(obedience), "　小手护着" if guard else "", ("\n释放后敏感！") if sensitive_t > 0.0 else ""]
	if _chart:
		_chart.queue_redraw()


func _on_key(k: String) -> void:
	if k == "J":
		order_guard()
		return
	super(k)


func _input(event: InputEvent) -> void:
	super(event)
	if playing and not busy and event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_U:
		burst()


## J：小手挡下一下
func order_guard() -> void:
	if guard:
		return
	if obedience < BLOCK_COST:
		say("princess", "……不、听……")
		hit("princess", "thigh", "（听话度不够，小手反倒挠了她一下）", 0.05)
		return
	obedience -= BLOCK_COST
	guard = true
	say("princess", "……挡。")


## U：千手解放——推开粉色公主，之后小手挠自己
func burst() -> bool:
	if pushed_t > 0.0 or backlash_t > 0.0:
		return false
	bursts += 1
	pushed_t = PUSH
	backlash_t = BACKLASH
	target = ""
	decoy = ""
	flash(Color(1, 0.75, 0.9, 0.7), 0.4)
	var pk: CGActor = actors.get("pink")
	if pk:
		pk.create_tween().tween_property(pk, "position:x", 44.0, 0.25)
	busy = true
	await _lines(lesson().get("burst_skill", []))
	busy = false
	return true


func _tick(delta: float) -> void:
	obedience = minf(100.0, obedience + OBEY_REGEN * delta)
	if pushed_t > 0.0:
		pushed_t -= delta
		gap_t = maxf(gap_t, 0.3)
		target = ""
		if pushed_t <= 0.0:
			var pk: CGActor = actors.get("pink")
			if pk:
				pk.create_tween().tween_property(pk, "position:x", 16.0, 0.3)
	if backlash_t > 0.0:
		backlash_t -= delta
		if int(backlash_t * 2.0) != int((backlash_t + delta) * 2.0):
			hit("princess", ["thigh", "butt"].pick_random(), "", 0.03)
	super(delta)
	if _done and not passed:
		passed = marks < MARKS


func _strike(id: String, by: String) -> void:
	if guard:
		guard = false
		blocks += 1
		var bl: Array = lesson().get("block", [])
		narrate(str(bl.pick_random()) if not bl.is_empty() else "（挡住了）", 1.4)
		return
	var pk: Array = lesson().get("pink", [])
	if not pk.is_empty() and rng.randf() < 0.6:
		say("pink", str(pk.pick_random()))
	super(id, "pink")


## 粉色公主挑地方：和第一课一样（亮起来的地方），挠的人换成她
func _pick_target() -> void:
	super()


func _mark() -> void:
	marks += 1
	face = 100.0
	busy = true
	await _lines(lesson().get("break", []) if marks < MARKS else [])
	busy = false
	if marks >= MARKS:
		passed = false
		_done = true


## 释放 = 失控：加时
func _punish(kind: String) -> void:
	if kind == "fatigue":
		time_left += EXTRA
		pop(actors.get("cap"), "失控。加时。", BAD, 1.2)
	await super(kind)


## 考核里释放不会让这节课重来
func redo() -> void:
	releases = 0


func play() -> bool:
	await super()
	return passed

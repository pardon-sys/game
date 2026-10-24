class_name StallFishShow
extends ErrandWorkStage
## 庆功宴摊位「捞痒痒鱼」（小汤姆）：坐在大木盆边，光脚泡在水里，小鱼一直来啄脚底；用纸网捞鱼。台词 data/after/stall_fish.json。
##   盆里 FISH_COUNT 条鱼游来游去，脚在水里时往脚边聚（离脚 NIBBLE_R 以内的在啄：闷笑每秒 +NIBBLE × 条数）。
##   ← → 挪纸网（NET_SPEED），J 捞：网下（NET_R 以内）有鱼就捞到一条（completed +1），每捞一次网湿 NET_WEAR；
##     闷笑过 SPLASH_AT 时每次加强脚一抖、水花溅到网上（+SPLASH_WEAR）。网湿透就破，换下一张；三张网都破了还不够 GOAL → retry 从头来。
##   K 抬脚 LIFT_TIME 秒：鱼散开、闷笑 −LIFT_RELIEF，冷却 LIFT_COOL 秒。闷笑满：脚一踢，网直接泡烂；魔力释放见 ErrandWorkStage。不存档。
## 测试：quiet、fixed_seed、press()、simulate()、fish、net_x、scoop()、lift()。

const PATH := "res://data/after/stall_fish.json"
const GOAL := 6
const NETS := 3
const FISH_COUNT := 8
const BASIN := Rect2(-40, -14, 80, 30)
const FEET := Vector2(-30, 4)
const NIBBLE_R := 12.0
const NIBBLE := 0.006
const NET_R := 8.0
const NET_SPEED := 70.0
const NET_WEAR := 0.25
const SPLASH_AT := 0.6
const SPLASH_WEAR := 0.2
const LIFT_TIME := 2.0
const LIFT_COOL := 4.0
const LIFT_RELIEF := 0.15
const FISH_SPEED := 22.0
const FATIGUE_RATE := 0.01

static var quiet := false
static var fixed_seed := -1
static var _text := {}

var fish: Array[Dictionary] = []
var net_x := 10.0
var net_dir := 0
var nets := NETS
var wear := 0.0
var lifted := 0.0
var lift_cool := 0.0
var scoop_flash := 0.0
var _info: Label
var _rig: BasinRig


static func data() -> Dictionary:
	if _text.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_text = parsed if parsed is Dictionary else {}
	return _text


func work_text() -> Dictionary:
	return data()


func phase_limits() -> Array:
	return [GOAL]


func panel_title() -> String:
	return str(data().get("name", ""))


func stage_cast() -> Dictionary:
	return {"princess": {"kind": "princess", "character": "pink", "at": [-50, 2], "visual": "normal", "anim": "idle", "dir": "right"},
		"keeper": {"kind": "npc:kid", "at": [52, -6], "dir": "left"}}


func play() -> bool:
	if not prepare_work(fixed_seed, quiet):
		return false
	tickler = "keeper"
	_build_ui()
	hint_label.text = str(data()["hint"])
	_info = _label(TEXT, 8)
	_info.size = panel_body.size
	panel_body.add_child(_info)
	_enter_game()
	for i in FISH_COUNT:
		fish.append(_new_fish())
	_rig = BasinRig.new()
	_rig.stage = self
	view.add_child(_rig)
	view.move_child(_rig, 1)
	active_tool = "fish"
	if not await start_work():
		return false
	return await work_result()


func _new_fish() -> Dictionary:
	return {"pos": Vector2(rng.randf_range(BASIN.position.x + 6, BASIN.end.x - 6), rng.randf_range(BASIN.position.y + 4, BASIN.end.y - 4)),
		"vel": Vector2.from_angle(rng.randf() * TAU) * FISH_SPEED}


func _begin_segment() -> void:
	busy = false
	_refresh()


func feet_in_water() -> bool:
	return lifted <= 0.0


func nibbling() -> int:
	if not feet_in_water():
		return 0
	return fish.filter(func(f): return (f["pos"] as Vector2).distance_to(FEET) <= NIBBLE_R).size()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and playing and not event.echo:
		var key: String = KEY_NAMES.get(event.keycode, "")
		if key in ["LEFT", "RIGHT", "A", "D"]:
			var dir := -1 if key in ["LEFT", "A"] else 1
			if event.pressed:
				net_dir = dir
			elif net_dir == dir:
				net_dir = 0
			get_viewport().set_input_as_handled()
			return
	super(event)


func _on_key(k: String) -> void:
	if recovery_left > 0.0:
		return
	match k:
		"J", "E", "SPACE":
			scoop()
		"K", "S", "DOWN":
			lift()


## J 捞：网下面有鱼就捞到；网湿一点，湿透就破
func scoop() -> bool:
	if busy or nets <= 0:
		return false
	scoop_flash = 0.3
	var got := -1
	for i in fish.size():
		if (fish[i]["pos"] as Vector2).distance_to(Vector2(net_x, 0)) <= NET_R:
			got = i
			break
	_wear(NET_WEAR)
	if got < 0:
		_pop_random(data().get("empty", []), BAD, 1.0)
		return false
	fish[got] = _new_fish()
	_pop_random(data().get("catch", []), GOOD, 1.0)
	advance_step()
	return true


func _wear(amount: float) -> void:
	wear += amount
	if wear < 1.0:
		return
	wear = 0.0
	nets -= 1
	var caps: Array = data().get("net_break", [])
	narrate(str(caps[rng.randi_range(0, caps.size() - 1)]), 2.0, true)
	_pop_random(data().get("net_break_react", []), PINK, 1.4)
	if nets <= 0 and completed < GOAL:
		_retry()


## 三张网都破了还不够：从头来
func _retry() -> void:
	busy = true
	await _lines(data().get("retry", []))
	if not _alive():
		return
	nets = NETS
	wear = 0.0
	completed = 0
	busy = false
	_refresh()


## K 抬脚：鱼散开、闷笑降一截
func lift() -> bool:
	if lift_cool > 0.0 or busy:
		return false
	lifted = LIFT_TIME
	lift_cool = LIFT_COOL
	if player.laugh:
		player.laugh.set_value(maxf(0.0, player.laugh.value - laugh_max() * LIFT_RELIEF))
	for f in fish:
		var away := ((f["pos"] as Vector2) - FEET).normalized()
		f["vel"] = (away if away != Vector2.ZERO else Vector2.RIGHT) * FISH_SPEED * 1.6
	var caps: Array = data().get("lift", [])
	narrate(str(caps[rng.randi_range(0, caps.size() - 1)]), 1.8)
	_pop_random(data().get("lift_react", []), GOOD, 1.2)
	return true


## 闷笑满：脚一踢，网泡烂
func recover() -> void:
	super()
	_wear(1.0)


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
	scoop_flash = maxf(0.0, scoop_flash - dt)
	lifted = maxf(0.0, lifted - dt)
	lift_cool = maxf(0.0, lift_cool - dt)
	net_x = clampf(net_x + net_dir * NET_SPEED * dt, BASIN.position.x + 4, BASIN.end.x - 4)
	_swim(dt)
	if recovery_left > 0.0:
		recovery_left = maxf(0.0, recovery_left - dt)
		return
	var event := work_clock(dt)
	var n := nibbling()
	work_laugh(laugh_max() * NIBBLE * n * dt * 10.0)
	add_fatigue(fatigue_max() * FATIGUE_RATE * dt)
	if event["strong"] and player.laugh and player.laugh.ratio() >= SPLASH_AT:
		narrate(str(data()["splash"]), 1.6, true)
		_wear(SPLASH_WEAR)
	if event["reaction"] and n > 0:
		work_reaction(data(), 0, active_tool, tickler)
	if interference.warning() and feet_in_water():
		narrate(str(data()["warning"]), 0.8)
	if event["fx"] and n > 0:
		tickle(tickler, "sole", false, "princess", "suck")
	_refresh()


## 鱼游：脚在水里往脚边聚，抬脚时散开；碰到盆边弹回来
func _swim(dt: float) -> void:
	for f in fish:
		var pos: Vector2 = f["pos"]
		var vel: Vector2 = f["vel"]
		if feet_in_water() and rng.randf() < 0.6:
			vel = vel.lerp((FEET - pos).normalized() * FISH_SPEED, 0.8 * dt)
		vel = vel.rotated(rng.randf_range(-1.5, 1.5) * dt)
		pos += vel * dt
		if pos.x < BASIN.position.x + 2 or pos.x > BASIN.end.x - 2:
			vel.x = -vel.x
		if pos.y < BASIN.position.y + 2 or pos.y > BASIN.end.y - 2:
			vel.y = -vel.y
		f["pos"] = pos.clamp(BASIN.position + Vector2(2, 2), BASIN.end - Vector2(2, 2))
		f["vel"] = vel


func _refresh() -> void:
	if not is_instance_valid(_info):
		return
	_info.text = str(data()["panel"]) % [completed, GOAL, nets, roundi(wear * 100)]
	count_label.text = str(data()["count"]) % [completed, GOAL]
	if _rig:
		_rig.queue_redraw()


## 木盆、水、小鱼、她泡在水里的两只脚、纸网
class BasinRig extends Node2D:
	var stage: StallFishShow

	func _draw() -> void:
		draw_rect(BASIN.grow(4), Color("8b6644"))
		draw_rect(BASIN, Color(0.45, 0.7, 0.85, 0.9))
		for i in 5:
			var y := BASIN.position.y + 4 + i * 6 + sin(stage.elapsed * 2.0 + i) * 1.0
			draw_line(Vector2(BASIN.position.x + 2, y), Vector2(BASIN.end.x - 2, y), Color(1, 1, 1, 0.12), 1)
		var feet := FEET + (Vector2(-6, -10) if not stage.feet_in_water() else Vector2.ZERO)
		for y in [-3.0, 3.0]:
			draw_rect(Rect2(feet + Vector2(-14, y - 2), Vector2(14, 4)), Color("f6d3c4"))
			draw_circle(feet + Vector2(0, y), 2.2, Color("f6d3c4"))
		for f in stage.fish:
			var p: Vector2 = f["pos"]
			var v: Vector2 = f["vel"]
			var d := v.normalized() if v != Vector2.ZERO else Vector2.RIGHT
			draw_circle(p, 2.0, Color("f2a65a"))
			draw_line(p - d * 2.0, p - d * 4.5 + d.orthogonal() * sin(stage.elapsed * 14.0) * 1.5, Color("e88b3a"), 1.5)
		var n := Vector2(stage.net_x, 0)
		var col := Color(1, 1, 1, 0.8).lerp(Color(0.6, 0.6, 0.7, 0.8), stage.wear)
		draw_arc(n, NET_R, 0, TAU, 18, col, 1.5 + stage.scoop_flash * 3.0)
		draw_line(n + Vector2(NET_R, -NET_R), n + Vector2(NET_R + 10, -NET_R - 14), Color("c39a6b"), 2)

class_name QuestHide
extends QuestRunner
## 支线「骑士救公主」第四段「那一天的躲猫猫」（没有灯的小巷 floor_06_knight_alley）：孩子们玩大人不许玩的「灯全灭了」，粉色公主提着小灯当「鬼」。
##   FIND 个小孩藏在木桶 / 木箱 / 布帘后面（SPOTS 里随机挑），巷子很暗，只有她手里的灯（PointLight2D，半径 lamp_r）照到才看得见。
##   走到小孩身边（FOUND_R）= 找到：小孩跳出来扑上去挠脚心（定身 POUNCE_ROOT 秒、闷笑 +POUNCE_LAUGH），然后站到巷口去。
##   靠近还没找到的小孩时，偶尔会听见他憋不住的「嘻……」（提示）。
##   她自己笑出声（闷笑过 HEARD_AT）：剩下的小孩全换地方藏（冷却 HEARD_COOL）。闷笑满 = 鬼被抓走：重新藏、重来。
##   灯芯不稳：每隔 DIM_EVERY 秒暗 DIM_TIME 秒（半径缩到 DIM_R）——黑里的影子小手（ShadowHand）趁机伸出来挠。
##   找齐 → 过场 kq_shoes_hide_end（奶奶「谁教你们玩这个的！」）→ 这一段做完。第一次进巷子演 kq_shoes_hide_start。
## 测试：hiders、found、lamp_r、dim_left、find(hider)、heard()、caught()、shadows。

const FIND := 5
const SPOTS := [Vector2i(8, 4), Vector2i(13, 6), Vector2i(17, 4), Vector2i(21, 6), Vector2i(25, 4), Vector2i(29, 6), Vector2i(31, 5),
	Vector2i(10, 6), Vector2i(19, 4), Vector2i(27, 5), Vector2i(15, 5), Vector2i(23, 4)]
const SHADOW_AT := [Vector2i(11, 5), Vector2i(18, 6), Vector2i(24, 4), Vector2i(30, 5)]
const ENTRANCE := Vector2i(4, 5)
const LAMP_R := 46.0
const DIM_R := 16.0
const DIM_EVERY := 7.0
const DIM_TIME := 1.8
const FOUND_R := 20.0
const POUNCE_ROOT := 0.8
const POUNCE_LAUGH := 0.1
const HEARD_AT := 0.6
const HEARD_COOL := 10.0
const CAUGHT_AT := 0.97
const KID_SHEET := preload("res://assets/generated/npcs/kid.png")

var hiders: Array = []
var shadows: Array = []
var found := 0
var lamp_r := LAMP_R
var dim_left := 0.0
var _dim_t := DIM_EVERY
var _heard := 0.0
var _light: PointLight2D
var _rng := RandomNumberGenerator.new()


func h() -> Dictionary:
	return q.get("hide", {})


func setup() -> void:
	_rng.randomize()
	if is_instance_valid(pink):
		_light = PointLight2D.new()
		_light.name = "HideLamp"
		_light.texture = preload("res://assets/lights/light_soft.tres")
		_light.color = Color(1.0, 0.86, 0.6)
		_light.energy = 1.3
		_light.position = Vector2(0, -8)
		pink.add_child(_light)
	for c in SHADOW_AT:
		var sh := put(ShadowHand.new(), Cutscene.cell_to_world(c)) as ShadowHand
		sh.target = pink
		shadows.append(sh)
	_hide_all()
	_intro()


func cleanup() -> void:
	if is_instance_valid(_light):
		_light.queue_free()


func _intro() -> void:
	var cut := str(h().get("intro_cut", ""))
	if cut == "" or GameState.has_flag("kq_shoes_hide_intro") or not Cutscene.has_cutscene(cut):
		return
	GameState.set_flag("kq_shoes_hide_intro")
	await get_tree().process_frame
	await TrainingDB.wait_dialogue_free()
	await Cutscene.play(cut)


## 小孩们藏起来（已经找到的不动）
func _hide_all() -> void:
	var free := SPOTS.duplicate()
	free.shuffle()
	for hd in hiders:
		if is_instance_valid(hd) and not hd.found:
			free.erase(hd.spot)
	while hiders.size() < FIND:
		var hd := put(Hider.new(), Vector2.ZERO) as Hider
		hd.runner = self
		hiders.append(hd)
	for hd in hiders:
		if not hd.found:
			hd.spot = free.pop_back()
			hd.global_position = Cutscene.cell_to_world(hd.spot)
			hd.visible = true


func status() -> String:
	return str(h().get("status", "%d / %d %s")) % [found, FIND, "暗！" if dim_left > 0.0 else "亮"]


func _process(delta: float) -> void:
	if not live() or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink) or GameState.player != pink:
		return
	tick(delta)


func tick(delta: float) -> void:
	_heard = maxf(0.0, _heard - delta)
	# 灯芯：每隔一阵暗一下
	if dim_left > 0.0:
		dim_left -= delta
	else:
		_dim_t -= delta
		if _dim_t <= 0.0:
			_dim_t = DIM_EVERY + _rng.randf_range(-1.5, 1.5)
			dim_left = DIM_TIME
			say(h().get("dim", []), 1.4)
	lamp_r = DIM_R if dim_left > 0.0 else LAMP_R
	if is_instance_valid(_light):
		_light.texture_scale = lamp_r * 1.4 / 80.0 + 0.04 * sin(Time.get_ticks_msec() / 90.0)
	for sh in shadows:
		if is_instance_valid(sh):
			sh.lamp_r = lamp_r
	for hd in hiders:
		if not is_instance_valid(hd) or hd.found:
			continue
		var d := pink.global_position.distance_to(hd.global_position)
		if d <= FOUND_R:
			find(hd)
		elif d < 60.0 and _rng.randf() < delta * 0.25:
			SpeechBubble.say(hd, str((h().get("giggle", ["嘻……"]) as Array).pick_random()), 18.0, 0.9)
	if pink.laugh:
		var r := pink.laugh.ratio()
		if r >= CAUGHT_AT:
			caught()
		elif r >= HEARD_AT and _heard <= 0.0:
			heard()


## 找到一个：扑上来挠脚心，然后站到巷口去
func find(hd: Hider) -> void:
	if hd.found:
		return
	hd.found = true
	found += 1
	say(h().get("found", []), 1.6)
	SpeechBubble.say(hd, str((h().get("pounce", ["嘿嘿！"]) as Array).pick_random()), 24.0, 1.2)
	if pink.status:
		pink.status.apply_root(POUNCE_ROOT)
	if pink.laugh:
		pink.laugh.add(pink.laugh.max_value * POUNCE_LAUGH)
	ZoneFx.play("sole", pink.get_parent(), ZoneFx.body_point(pink, "sole"), 0.9, false)
	Audio.play("tickle", -6.0, 0.1)
	hd.go_to(Cutscene.cell_to_world(ENTRANCE) + Vector2(10 + (found - 1) * 9, 18))
	if found >= FIND:
		_finish()


## 她笑出了声：剩下的小孩全换地方
func heard() -> void:
	_heard = HEARD_COOL
	say(h().get("heard", []), 2.2)
	_hide_all()
	Audio.play("swish", -6.0)


## 笑得蹲在地上：鬼被抓走，重新藏、重来
func caught() -> void:
	say(h().get("caught", ""), 2.6)
	found = 0
	for hd in hiders:
		if is_instance_valid(hd):
			hd.found = false
	_hide_all()
	if pink.laugh:
		pink.laugh.set_value(pink.laugh.max_value * 0.3)
	pink.global_position = Cutscene.cell_to_world(ENTRANCE)
	_heard = HEARD_COOL


func _finish() -> void:
	var cut := str(h().get("end_cut", ""))
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return
	if cut != "" and Cutscene.has_cutscene(cut):
		await TrainingDB.wait_dialogue_free()
		await Cutscene.play(cut)
	advance()


## 藏着的小孩：缩成一团（暗处看不见，灯照到才看得见）；找到以后站起来跑去巷口
class Hider extends Node2D:
	var runner: QuestHide
	var spot := Vector2i.ZERO
	var found := false
	var _goal := Vector2.INF
	var _t := 0.0

	func go_to(at: Vector2) -> void:
		_goal = at

	func _process(delta: float) -> void:
		_t += delta
		if _goal != Vector2.INF:
			global_position = global_position.move_toward(_goal, 60.0 * delta)
		queue_redraw()

	func _draw() -> void:
		var walking := _goal != Vector2.INF and global_position.distance_to(_goal) > 1.0
		var src := Rect2((int(_t * 7.0) % 4 if walking else 0) * 32, 0, 32, 32)
		if found:
			draw_texture_rect_region(QuestHide.KID_SHEET, Rect2(-16, -28, 32, 32), src)
		else:
			# 缩成一团、偶尔发抖（憋笑）
			draw_set_transform(Vector2(sin(_t * 30.0) * 0.5 if fmod(_t, 2.5) < 0.3 else 0.0, 4), 0.0, Vector2(1.0, 0.75))
			draw_texture_rect_region(QuestHide.KID_SHEET, Rect2(-16, -28, 32, 32), src)
			draw_set_transform(Vector2.ZERO)

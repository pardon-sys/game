class_name KnightDispel
extends Node
## 骑士 Boss 最后阶段「笑雾之中」的驱散（四盏灯笼点满、骑士落地以后 TaskKnightBoss._start_dispel 摆上）：
##   粉色公主站在骑士身边（DISPEL_R 以内、没被打断、玩家操控她时站着不动）吟唱，读条 DISPEL_TIME 秒满 = 驱散成功 → 净化（TaskKnightBoss._dispel_done）。
##   黑雾每 HAND_EVERY 秒从雾圈边上放出一只黑气小手（FogHand，走格子路 GridPath）扑向粉色公主：
##     碰到她 = 打断：读条 −HIT_SETBACK、闷笑 +HIT_LAUGH（释放后敏感 ×SENSITIVE_MULT），INTERRUPT 秒后她自己重新起唱；
##     蓝色公主拦：攻击时 HAND_KILL_R 以内的小手散掉，J 冻住（TaskKnightBoss.freeze_part → freeze_hands）冻碎范围里的；AI 蓝色贴近就能拍散。
##   粉色公主闷笑到 FAIL_AT：第一次 = 魔力释放（小手全震散、闷笑回到 RELEASE_LAUGH，之后 SENSITIVE_TIME 秒更敏感）；第二次 = 驱散失败
##     （TaskKnightBoss._dispel_failed → 失败小剧场 knight_fail_fog → 从驱散重来，灯笼保持点亮）。
##   开始时操控交给蓝色公主（玩家拦小手），右上角小窗（SideWindow）看粉色公主读条；按 C 换人，小窗换成看另一个人。
## 测试：quiet（不开小窗、不说台词）、progress、hands、bursts、channeling、tick(dt)、spawn_hand()、hit_pink(手)、freeze_hands(谁, 范围)、ai_plan(谁)。

const DISPEL_TIME := 20.0
const DISPEL_R := 30.0
const HAND_EVERY := 2.2
## 读条过半以后小手来得更勤
const HAND_EVERY_LATE := 1.6
const HAND_SPEED := 34.0
const HAND_HIT_R := 9.0
const HAND_KILL_R := 18.0
const AI_KILL_R := 12.0
const HIT_SETBACK := 0.15
const HIT_LAUGH := 0.2
const INTERRUPT := 1.0
const FAIL_AT := 0.97
const RELEASE_LAUGH := 0.45
const SENSITIVE_TIME := 6.0
const SENSITIVE_MULT := 1.5
## 小手从多远的地方钻出来（没有雾圈时）
const SPAWN_R := 110.0
const HAND_COL := Color(0.18, 0.08, 0.26)
const HAND_COL_D := Color(0.06, 0.02, 0.1)

static var quiet := false

var task: TaskKnightBoss
var progress := 0.0
var hands: Array = []
var bursts := 0
var sensitive_left := 0.0
var interrupt_left := 0.0
var channeling := false
var done := false
var _hand_t := 1.5
var _window: SideWindow
var _bar: DispelBar
var _say_t := 0.0


func _ready() -> void:
	# 玩家操控蓝色公主拦小手；小窗看粉色公主读条
	if is_instance_valid(task.blue) and GameState.player != task.blue and task.blue.is_alive():
		GameState.switch_control(task.blue)
	if quiet:
		return
	_bar = DispelBar.new()
	_bar.dispel = self
	_window = SideWindow.open(task.pink, {"title": "驱散 · 粉色公主", "zoom": 1.6, "hint": "按 C 换人"})
	_window.set_overlay(_bar)
	var lines: Array = TaskKnightBoss.data().get("fog", {}).get("dispel_start", [])
	if not lines.is_empty():
		Dialogue.start_lines(lines, "knight_dispel_start")
	GameState.notify(str(TaskKnightBoss.data().get("fog", {}).get("dispel_tip", "")))


func _exit_tree() -> void:
	if is_instance_valid(_window):
		_window.close(true)
	if is_instance_valid(task) and is_instance_valid(task.pink):
		task.pink.puppet_anim = ""
	for h in hands:
		if is_instance_valid(h):
			h.queue_free()


func _process(delta: float) -> void:
	if done or GameState.in_dialogue or GameState.in_cutscene or get_tree().paused:
		return
	tick(delta)


func body_pos() -> Vector2:
	return task.body_pos()


func tick(delta: float) -> void:
	var pink := task.pink
	if not is_instance_valid(pink):
		return
	sensitive_left = maxf(0.0, sensitive_left - delta)
	interrupt_left = maxf(0.0, interrupt_left - delta)
	_say_t = maxf(0.0, _say_t - delta)
	# 小窗看「不是玩家的那个人」
	if is_instance_valid(_window):
		var other: PlayableCharacter = task.blue if GameState.player == pink else pink
		if _window.target != other:
			_window.retarget(other)
			_window.set_title("驱散 · %s" % other.display_name())
	# 粉色公主吟唱：在骑士身边、没被打断、没被抓；玩家操控她时要站着不动
	var near := pink.global_position.distance_to(body_pos()) <= DISPEL_R
	var moving := GameState.player == pink and pink.velocity.length() > 5.0
	channeling = near and interrupt_left <= 0.0 and not moving and task.grabbed != pink
	pink.puppet_anim = "channel" if channeling else ""
	if channeling:
		progress = minf(1.0, progress + delta / DISPEL_TIME)
		if pink.animator:
			pink.animator.progress = fmod(progress * 4.0, 1.0)
		if progress > 0.5 and _say_t <= 0.0 and not quiet:
			_say_t = 6.0
			var pr: Array = TaskKnightBoss.data().get("fog", {}).get("progress", [])
			if not pr.is_empty():
				SpeechBubble.say(pink, str(pr.pick_random()), 30.0, 1.6)
	if progress >= 1.0:
		_finish()
		return
	# 黑气小手
	_hand_t -= delta
	if _hand_t <= 0.0:
		_hand_t = HAND_EVERY_LATE if progress > 0.5 else HAND_EVERY
		spawn_hand()
	var blue := task.blue
	var attacking := is_instance_valid(blue) and blue.state == PlayableCharacter.State.ATTACK
	for h in hands.duplicate():
		if not is_instance_valid(h):
			hands.erase(h)
			continue
		var fh := h as FogHand
		if is_instance_valid(blue) and ((attacking and fh.global_position.distance_to(blue.global_position) <= HAND_KILL_R)
				or (blue != GameState.player and fh.global_position.distance_to(blue.global_position) <= AI_KILL_R)):
			_pop(fh, true)
			continue
		fh.step(pink, delta)
		if fh.global_position.distance_to(pink.global_position) <= HAND_HIT_R:
			hit_pink(fh)
	# 闷笑满：第一次释放，第二次失败
	if pink.laugh and pink.laugh.ratio() >= FAIL_AT:
		_overflow()


## 从雾圈边上（没有雾圈就离骑士 SPAWN_R）放一只小手
func spawn_hand() -> FogHand:
	var r := SPAWN_R
	if is_instance_valid(task.fog_ring):
		r = task.fog_ring.radius
	var at := body_pos()
	for i in 10:
		at = body_pos() + Vector2.from_angle(randf() * TAU) * r
		if GridPath.walkable(task.level(), GridPath.cell(at)):
			break
	var h := FogHand.new()
	task.get_parent().add_child(h)
	h.global_position = at
	h.lv = task.level()
	hands.append(h)
	return h


## 小手碰到粉色公主：打断，读条倒退，闷笑涨
func hit_pink(h: FogHand) -> void:
	var pink := task.pink
	progress = maxf(0.0, progress - HIT_SETBACK)
	interrupt_left = INTERRUPT
	if pink.laugh:
		var add := pink.laugh.max_value * HIT_LAUGH * (SENSITIVE_MULT if sensitive_left > 0.0 else 1.0)
		pink.laugh.add(minf(add, maxf(0.0, pink.laugh.max_value * 0.985 - pink.laugh.value)))
	ZoneFx.play("sole", pink.get_parent(), ZoneFx.body_point(pink, "sole"), 1.0, false)
	Audio.play("tickle", -4.0, 0.1)
	if not quiet:
		var lines: Array = TaskKnightBoss.data().get("fog", {}).get("interrupt", [])
		if not lines.is_empty():
			GameState.princess_reacted.emit(str(lines.pick_random()), 1.8)
	_pop(h, false)


## 蓝色公主 J：冻碎范围里的小手
func freeze_hands(who: Node2D, reach: float) -> bool:
	var hit := false
	for h in hands.duplicate():
		if is_instance_valid(h) and (h as Node2D).global_position.distance_to(who.global_position) <= reach:
			_pop(h, true)
			hit = true
	return hit


func nearest_hand(from: Node2D) -> Node2D:
	var best: Node2D = null
	for h in hands:
		if is_instance_valid(h) and (best == null or (h as Node2D).global_position.distance_to(from.global_position) < best.global_position.distance_to(from.global_position)):
			best = h
	return best


## AI：粉色公主去骑士身边站定吟唱；蓝色公主去拦离粉色公主最近的小手（冻得到就冻），没手的时候守在她身边
func ai_plan(ai: PlayableCharacter) -> Dictionary:
	if ai == task.pink:
		var spot := body_pos() + Vector2(0, 22)
		if ai.global_position.distance_to(body_pos()) <= DISPEL_R - 6.0:
			return {"hold": true}
		return {"to": spot, "near": 6.0, "dash": true}
	var h := nearest_hand(task.pink)
	if h:
		if h.global_position.distance_to(ai.global_position) <= task.freeze_reach() - 8.0 and task.freeze_cool <= 0.0:
			task.freeze_part(ai)
			return {"hold": true}
		return {"to": h.global_position, "near": 6.0, "dash": true}
	return {"to": task.pink.global_position + Vector2(18, 4), "near": 10.0}


func _pop(h: FogHand, by_blue: bool) -> void:
	hands.erase(h)
	if not is_instance_valid(h):
		return
	Fx.burst(h.get_parent(), h.global_position, "dust", 6, 24.0, 0.35, Vector2(0, -6), Color(0.35, 0.2, 0.5))
	if by_blue:
		Audio.play("chime", -10.0)
		if not quiet and randf() < 0.3 and is_instance_valid(task.blue):
			var lines: Array = TaskKnightBoss.data().get("fog", {}).get("blue_block", [])
			if not lines.is_empty():
				SpeechBubble.say(task.blue, str(lines.pick_random()), 30.0, 1.2)
	h.queue_free()


func _overflow() -> void:
	var pink := task.pink
	if bursts == 0:
		bursts = 1
		sensitive_left = SENSITIVE_TIME
		for h in hands.duplicate():
			_pop(h, false)
		if pink.laugh:
			pink.laugh.set_value(pink.laugh.max_value * RELEASE_LAUGH)
		Audio.play("star_burst", -2.0)
		Audio.play("water_release", -4.0)
		Fx.burst(pink.get_parent(), pink.global_position, "drop", 14, 46.0, 0.6, Vector2(0, -14), Color(1, 0.75, 0.9))
		if not quiet:
			var lines: Array = TaskKnightBoss.data().get("fog", {}).get("release", [])
			if not lines.is_empty():
				GameState.princess_reacted.emit(str(lines[0]), 3.0)
		return
	done = true
	task._dispel_failed()


func _finish() -> void:
	done = true
	for h in hands.duplicate():
		_pop(h, false)
	if is_instance_valid(task.pink):
		task.pink.puppet_anim = ""
	if is_instance_valid(_window):
		_window.close()
	task._dispel_done()


## 黑气小手：从雾里钻出来，沿格子路爬向粉色公主
class FogHand extends Node2D:
	var lv: Node
	var _t := 0.0
	var _path: Array[Vector2] = []
	var _repath := 0.0

	func _ready() -> void:
		z_index = 3
		add_to_group("knight_fog_hand")

	func step(target: Node2D, delta: float) -> void:
		_t += delta
		_repath -= delta
		if _repath <= 0.0 or _path.is_empty():
			_repath = 0.4
			_path = GridPath.find(lv, global_position, target.global_position)
			_path.append(target.global_position)
		GridPath.follow(self, _path, KnightDispel.HAND_SPEED, delta)
		queue_redraw()

	func _draw() -> void:
		# 一团黑雾 + 一只伸出来的小手
		for i in 4:
			var k := fmod(_t * 1.5 + i * 0.25, 1.0)
			draw_circle(Vector2(sin(i * 1.7 + _t * 3.0) * 4.0, -2.0 - k * 6.0), 4.0 * (1.0 - k) + 1.0, Color(0.12, 0.05, 0.18, 0.45 * (1.0 - k)))
		CurseHand.draw_hand(self, Vector2(0, -6), 0.7, KnightDispel.HAND_COL, KnightDispel.HAND_COL_D, 0.9, sin(_t * 14.0))


## 小窗下面的读条
class DispelBar extends Control:
	var dispel: KnightDispel

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(dispel):
			return
		var w := size.x - 20.0
		var y := size.y - 30.0
		draw_rect(Rect2(10, y, w, 7), Color(0.1, 0.05, 0.15, 0.85))
		var col := Color(1, 0.6, 0.85) if dispel.channeling else Color(0.6, 0.45, 0.65)
		draw_rect(Rect2(10, y, w * dispel.progress, 7), col)
		draw_rect(Rect2(10, y, w, 7), Color(1, 0.85, 0.95, 0.8), false, 1.0)
		var label := "驱散 %d%%" % int(dispel.progress * 100.0) + ("　（被打断）" if dispel.interrupt_left > 0.0 else "")
		draw_string(ThemeDB.fallback_font, Vector2(10, y - 3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.95, 0.98))

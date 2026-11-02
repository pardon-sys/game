class_name KnightDispel
extends Node
## 骑士 Boss 最后阶段「笑雾之中」的驱散（四盏灯笼点满、骑士落地以后 TaskKnightBoss._start_dispel 摆上）：
##   粉色公主站在骑士身边（DISPEL_R 以内、没被打断、玩家操控她时站着不动）吟唱，读条 DISPEL_TIME 秒满 = 驱散成功 → 净化（TaskKnightBoss._dispel_done）。
##   黑雾每 HAND_EVERY 秒从雾圈边上放出一只黑气小手（FogHand，走格子路 GridPath）扑向粉色公主：
##     碰到她 = 打断：读条 −HIT_SETBACK、闷笑 +HIT_LAUGH（释放后敏感 ×SENSITIVE_MULT），INTERRUPT 秒后她自己重新起唱；
##     蓝色公主拦：攻击时 HAND_KILL_R 以内的小手散掉，J 冻住（TaskKnightBoss.freeze_part → freeze_hands）冻碎范围里的；AI 蓝色贴近就能拍散。
##   粉色公主闷笑到 FAIL_AT：第一次 = 魔力释放（小手全震散、闷笑回到 RELEASE_LAUGH，之后 SENSITIVE_TIME 秒更敏感）；第二次 = 驱散失败
##     （TaskKnightBoss._dispel_failed → 失败小剧场 knight_fail_fog → 从驱散重来，灯笼保持点亮）。
##   开始时操控交给蓝色公主（玩家拦小手 / 关雾口），粉色公主的读条画在她头顶 + 屏幕上方（第八轮去掉了分屏小窗）；按 C 换人。
##   骑士落地后不动不出招，只吸引怪物：召怪雾口吐现有的怪（MONSTERS，最多 MONSTER_MAX 只）、笑声潮汐、怪多读条慢（见下面的常量）；驱散结束全部收走。
## 测试：quiet（不开小窗、不说台词）、progress、hands、monsters、bursts、channeling、tick(dt)、spawn_hand()、spawn_monster(种类)、hit_pink(手)、freeze_hands(谁, 范围)、ai_plan(谁)。

const DISPEL_TIME := 20.0
const DISPEL_R := 30.0
const HAND_EVERY := 2.4
## 读条过半以后小手来得更勤
const HAND_EVERY_LATE := 1.8
const HAND_SPEED := 42.0
## 第八轮改版：骑士落地后不动不出招，改成「吸引怪物」——
##   召怪雾口（FogMouth ×MOUTHS，雾圈边上）：每个每 MOUTH_EVERY 秒吐一只现有的怪；蓝色公主攻击 MOUTH_HP 下 / J 冻碎关掉，关掉一个剩下的刷得慢一截（×MOUTH_SLOWER）；
##   笑声潮汐：每 TIDE_EVERY 秒骑士蓄力 TIDE_WARN 秒（紫光往外扩），然后 TIDE_TIME 秒里场上的怪和小手都加速朝粉色公主冲；
##   怪多读条慢：粉色公主 SLOW_R 以内有怪 / 小手，吟唱速度 ×SLOW_MULT（地上画出这一圈，有怪时变红）。去掉分屏：读条画在她头顶 + 屏幕上方。
const MONSTER_MAX := 6
const MOUTHS := 3
const MOUTH_EVERY := 4.5
const MOUTH_FIRST := 2.0
const MOUTH_HP := 3
const MOUTH_SLOWER := 0.6
const TIDE_EVERY := 12.0
const TIDE_WARN := 1.6
const TIDE_TIME := 3.0
const TIDE_SPEED := 70.0
const SLOW_R := 40.0
const SLOW_MULT := 0.5
const MONSTERS := {
	"ghost": "res://scenes/actors/monsters/tickle_ghost.tscn",
	"glove": "res://scenes/actors/monsters/ghost_glove.tscn",
	"bat": "res://scenes/actors/monsters/feather_bat.tscn",
	"caterpillar": "res://scenes/actors/monsters/caterpillar.tscn",
	"rat": "res://scenes/actors/monsters/foot_rat.tscn",
}
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
var monsters: Array = []
var mouths: Array = []
var tide_t := TIDE_EVERY
var tide_warn := 0.0
var tide_left := 0.0
var slowed := false
var _ring: SlowRing
var _top: TopBar
var bursts := 0
var sensitive_left := 0.0
var interrupt_left := 0.0
var channeling := false
var done := false
var _hand_t := 1.5
var _say_t := 0.0


func _ready() -> void:
	# 玩家操控蓝色公主拦小手；小窗看粉色公主读条
	if is_instance_valid(task.blue) and GameState.player != task.blue and task.blue.is_alive():
		GameState.switch_control(task.blue)
	# 召怪雾口、粉色公主身边那一圈、读条（第八轮：不开分屏）
	var r := task.fog_ring.radius if is_instance_valid(task.fog_ring) else SPAWN_R
	for i in MOUTHS:
		var m := FogMouth.new()
		m.dispel = self
		m.left = MOUTH_FIRST + i * 1.2
		task.get_parent().add_child(m)
		var at := body_pos() + Vector2.from_angle(TAU * i / MOUTHS + 0.5) * r * 0.85
		m.global_position = at if GridPath.walkable(task.level(), GridPath.cell(at)) else body_pos() + Vector2.from_angle(TAU * i / MOUTHS + 0.5) * r * 0.6
		mouths.append(m)
	_ring = SlowRing.new()
	_ring.dispel = self
	task.get_parent().add_child(_ring)
	if quiet:
		return
	_top = TopBar.new()
	_top.dispel = self
	add_child(_top)
	var lines: Array = TaskKnightBoss.data().get("fog", {}).get("dispel_start", [])
	if not lines.is_empty():
		Dialogue.start_lines(lines, "knight_dispel_start")
	GameState.notify(str(TaskKnightBoss.data().get("fog", {}).get("dispel_tip", "")))


func _exit_tree() -> void:
	for m in mouths:
		if is_instance_valid(m):
			(m as Node).queue_free()
	if is_instance_valid(_ring):
		_ring.queue_free()
	if is_instance_valid(task) and is_instance_valid(task.pink):
		task.pink.puppet_anim = ""
	for h in hands:
		if is_instance_valid(h):
			h.queue_free()
	_clear_monsters()


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
	# 粉色公主吟唱：在骑士身边、没被打断、没被抓；玩家操控她时要站着不动
	var near := pink.global_position.distance_to(body_pos()) <= DISPEL_R
	var moving := GameState.player == pink and pink.velocity.length() > 5.0
	channeling = near and interrupt_left <= 0.0 and not moving and task.grabbed != pink
	pink.puppet_anim = "channel" if channeling else ""
	# 怪多读条慢：她身边一圈里有怪 / 小手
	slowed = monsters.any(func(m): return is_instance_valid(m) and m.global_position.distance_to(pink.global_position) <= SLOW_R) \
		or hands.any(func(h): return is_instance_valid(h) and h.global_position.distance_to(pink.global_position) <= SLOW_R)
	if channeling:
		progress = minf(1.0, progress + delta / DISPEL_TIME * (SLOW_MULT if slowed else 1.0))
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
		# 后半段：一次一到两只
		if progress > 0.5 and randf() < 0.5:
			spawn_hand()
	# 召怪雾口吐怪
	monsters = monsters.filter(func(m): return is_instance_valid(m) and m.is_alive())
	mouths = mouths.filter(func(m): return is_instance_valid(m))
	var closed := MOUTHS - mouths.size()
	for m in mouths:
		m.left -= delta
		if m.left <= 0.0:
			m.left = MOUTH_EVERY / pow(MOUTH_SLOWER, closed)
			if monsters.size() < MONSTER_MAX:
				spawn_monster("", m.global_position)
	# 笑声潮汐
	_tick_tide(delta, pink)
	var blue := task.blue
	var attacking := is_instance_valid(blue) and blue.state == PlayableCharacter.State.ATTACK
	for m in mouths.duplicate():
		if is_instance_valid(m) and is_instance_valid(blue) and m.global_position.distance_to(blue.global_position) <= HAND_KILL_R + 6.0:
			if attacking and m.hit_cool <= 0.0:
				m.hit_cool = 0.35
				hit_mouth(m)
			elif blue != GameState.player and m.hit_cool <= 0.0:
				m.hit_cool = 0.6
				hit_mouth(m)
	for h in hands.duplicate():
		if not is_instance_valid(h):
			hands.erase(h)
			continue
		var fh := h as FogHand
		if tide_left > 0.0:
			fh.step(pink, delta)   # 潮汐：小手也加速
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


## 雾圈边上钻出一只现有的怪（随机），平常的怪物 AI 会去挠离得近的人；返回它
## 笑声潮汐：预警 → 场上的怪和小手一起加速冲向粉色公主
func _tick_tide(delta: float, pink: Node2D) -> void:
	if tide_left > 0.0:
		tide_left -= delta
		for m in monsters:
			if is_instance_valid(m):
				(m as Node2D).global_position += (m as Node2D).global_position.direction_to(pink.global_position) * TIDE_SPEED * delta
		return
	if tide_warn > 0.0:
		tide_warn -= delta
		if tide_warn <= 0.0:
			tide_left = TIDE_TIME
			Audio.play("rumble", -3.0)
			task._shake(0.3, 3.0)
		return
	tide_t -= delta
	if tide_t <= 0.0:
		start_tide()


func start_tide() -> void:
	tide_t = TIDE_EVERY
	tide_warn = TIDE_WARN
	var ring := SiegeFx.ring(task.get_parent(), body_pos(), 30.0, Color(0.8, 0.4, 1.0, 0.9), TIDE_WARN, 0.12)
	if ring:
		ring.create_tween().tween_property(ring, "scale", Vector2(5, 3.5), TIDE_WARN)
	if not quiet:
		GameState.notify(str(TaskKnightBoss.data().get("fog", {}).get("tide", "笑声潮汐要来了——挡在粉色公主前面！")), 1.6)


## 蓝色公主打 / 冻雾口（攻击一下 −1，J 冻碎）
func hit_mouth(m: Node2D, freeze := false) -> void:
	if not is_instance_valid(m):
		return
	m.hp -= MOUTH_HP if freeze else 1
	m.flash = 0.2
	if m.hp <= 0:
		Fx.burst(task.get_parent(), m.global_position, "dust", 14, 40.0, 0.6, Vector2(0, -10), Color(0.6, 0.4, 0.9))
		Audio.play("ice_crack", -4.0)
		mouths.erase(m)
		m.queue_free()


func spawn_monster(key := "", at_pos := Vector2.INF) -> Node2D:
	if key == "":
		key = MONSTERS.keys()[randi() % MONSTERS.size()]
	var scn := load(str(MONSTERS[key])) as PackedScene
	if scn == null:
		return null
	var m := scn.instantiate() as Node2D
	var lv := task.level()
	var parent: Node = lv.get_node_or_null("Entities") if lv else null
	if parent == null:
		parent = task.get_parent()
	parent.add_child(m)
	var r := task.fog_ring.radius if is_instance_valid(task.fog_ring) else SPAWN_R
	var at := at_pos
	if at == Vector2.INF:
		at = body_pos()
		for i in 10:
			at = body_pos() + Vector2.from_angle(randf() * TAU) * r
			if GridPath.walkable(lv, GridPath.cell(at)):
				break
	m.global_position = at
	Fx.burst(task.get_parent(), at, "dust", 10, 30.0, 0.5, Vector2(0, -10), Color(0.4, 0.2, 0.55))
	monsters.append(m)
	return m


func _clear_monsters() -> void:
	for m in monsters:
		if is_instance_valid(m):
			(m as Node).queue_free()
	monsters.clear()


## 小手碰到粉色公主：打断，读条倒退，闷笑涨
func hit_pink(h: FogHand) -> void:
	var pink := task.pink
	progress = maxf(0.0, progress - HIT_SETBACK)
	interrupt_left = INTERRUPT
	KnightTickle.hit(pink, HIT_LAUGH * (SENSITIVE_MULT if sensitive_left > 0.0 else 1.0), h, "sole", KnightTickle.BOSS_CRIT, 0.985)
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
	for m in mouths.duplicate():
		if is_instance_valid(m) and (m as Node2D).global_position.distance_to(who.global_position) <= reach + 8.0:
			hit_mouth(m, true)
			hit = true
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
	# 粉色公主身边没有手 / 怪的时候：去关雾口
	if (h == null or h.global_position.distance_to(task.pink.global_position) > SLOW_R * 1.5) and not mouths.is_empty() and tide_left <= 0.0 and tide_warn <= 0.0:
		var mo: Node2D = null
		for m in mouths:
			if is_instance_valid(m) and (mo == null or (m as Node2D).global_position.distance_to(ai.global_position) < mo.global_position.distance_to(ai.global_position)):
				mo = m
		if mo:
			return {"to": mo.global_position, "near": 8.0, "dash": true}
	# 潮汐：挡在粉色公主前面
	if tide_warn > 0.0 or tide_left > 0.0:
		return {"to": task.pink.global_position + task.pink.global_position.direction_to(body_pos()) * -14.0, "near": 6.0, "dash": true}
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
	_clear_monsters()
	task._dispel_failed()


func _finish() -> void:
	done = true
	_clear_monsters()
	for h in hands.duplicate():
		_pop(h, false)
	if is_instance_valid(task.pink):
		task.pink.puppet_anim = ""
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


## 召怪雾口：雾圈边上一团翻滚的紫雾，隔一会儿吐一只怪；蓝色公主打 / 冻能关掉
class FogMouth extends Node2D:
	var dispel: KnightDispel
	var hp := KnightDispel.MOUTH_HP
	var left := 2.0
	var flash := 0.0
	var hit_cool := 0.0
	var _t := 0.0

	func _ready() -> void:
		z_index = 2
		add_to_group("knight_fog_mouth")

	func _process(delta: float) -> void:
		_t += delta
		flash = maxf(0.0, flash - delta)
		hit_cool = maxf(0.0, hit_cool - delta)
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, IsoView.ground_scale())
		var pulse := 1.0 + 0.12 * sin(_t * 4.0)
		draw_circle(Vector2.ZERO, 14.0 * pulse, Color(0.12, 0.04, 0.2, 0.8))
		draw_circle(Vector2.ZERO, 9.0 * pulse, Color(0.35, 0.12, 0.5, 0.85))
		draw_arc(Vector2.ZERO, 15.0 * pulse, 0, TAU, 24, Color(0.8, 0.5, 1.0, 0.8 if flash <= 0.0 else 1.0), 2.0)
		draw_set_transform(Vector2.ZERO)
		for i in hp:
			draw_circle(Vector2(-6 + i * 6, -20), 2.0, Color(0.9, 0.7, 1.0))


## 粉色公主身边那一圈（SLOW_R）：有怪 / 小手进来就变红（吟唱变慢）；头顶的读条
class SlowRing extends Node2D:
	var dispel: KnightDispel

	func _process(_delta: float) -> void:
		if not is_instance_valid(dispel) or not is_instance_valid(dispel.task.pink):
			return
		global_position = dispel.task.pink.global_position
		z_index = 1
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(dispel):
			return
		var col := Color(1.0, 0.35, 0.4, 0.7) if dispel.slowed else Color(1.0, 0.75, 0.9, 0.45)
		draw_set_transform(Vector2.ZERO, 0.0, IsoView.ground_scale())
		draw_arc(Vector2.ZERO, KnightDispel.SLOW_R, 0, TAU, 40, col, 1.5)
		draw_set_transform(Vector2.ZERO)
		# 头顶读条
		var w := 30.0
		draw_rect(Rect2(-w * 0.5, -46, w, 4), Color(0.1, 0.05, 0.15, 0.85))
		draw_rect(Rect2(-w * 0.5, -46, w * dispel.progress, 4), Color(1, 0.6, 0.85) if dispel.channeling else Color(0.6, 0.45, 0.65))
		if dispel.slowed:
			draw_string(ThemeDB.fallback_font, Vector2(-16, -50), "变慢了", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.5, 0.55))


## 屏幕上方的驱散进度（代替以前的分屏小窗）
class TopBar extends CanvasLayer:
	var dispel: KnightDispel
	var _c: Control

	func _ready() -> void:
		layer = 12
		_c = Control.new()
		_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_c.size = Vector2(480, 30)
		_c.draw.connect(_draw_bar)
		add_child(_c)

	func _process(_delta: float) -> void:
		_c.queue_redraw()

	func _draw_bar() -> void:
		if not is_instance_valid(dispel):
			return
		var x := 140.0
		var w := 200.0
		_c.draw_rect(Rect2(x - 2, 6, w + 4, 12), Color(0.06, 0.03, 0.08, 0.85))
		_c.draw_rect(Rect2(x, 8, w * dispel.progress, 8), Color(1, 0.6, 0.85))
		var label := "驱散 %d%%" % int(dispel.progress * 100.0)
		if dispel.slowed:
			label += "（身边有怪：变慢）"
		if dispel.tide_warn > 0.0 or dispel.tide_left > 0.0:
			label += "　笑声潮汐！"
		label += "　雾口 %d" % dispel.mouths.size()
		_c.draw_string(ThemeDB.fallback_font, Vector2(x, 28), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.92, 0.98))

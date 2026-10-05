class_name BossSkills
extends Node
## 千手痒痒魔的大技能（挂在 ThousandHand 下面，节点名 Skills；第八层专属）：
##   俯冲撞墙 dash   阶段一起（阶段三连续两次）：整条横 / 竖通道先亮红色预警带 DASH_WARN 秒，本体沿通道冲过去，
##                   撞到的人挠一大口并击飞；冲到墙边撞墙：全屏大震 + 白闪 + 落石，随机掉 2~3 个落笼（先有影子）。
##                   特效：速度线 + 残影 + 尘土拖尾。
##   手臂雨 rain     阶段二起：6~8 个砸地圈按十字 / 圆环 / 追人的队形陆续落下（阶段二起不抓人，砸中积累闷笑）。
##   羽毛风暴 storm  阶段三：屏幕边上先出风向箭头 1 秒，然后全场往一侧推 STORM_TIME 秒（推向漩涡 / 落笼），风里的羽毛轻挠。
##   千手乱舞 dance  阶段三大招（约 30 秒一次）：全屏压暗 + 红色暗角闪烁，地上 2~3 个发光的安全圈 DANCE_WARN 秒，
##                   不在圈里的人挨一大口闷笑，全屏白闪。
## 预警都加进 danger 组（AI 搭档会躲）；千手乱舞的安全圈在 safe_spots 里（AI 搭档会往圈里跑）。

const DASH_WARN := 1.0
const DASH_TIME := 0.5
const DASH_TICKLE := 16.0
const DAZE_TIME := 1.5
const RAIN_GAP := 0.14
const STORM_TIME := 3.0
const STORM_PUSH := 62.0
const DANCE_WARN := 3.0
const DANCE_TICKLE := 34.0
const SAFE_RADIUS := 18.0
const CAGE_SCENE := "res://scenes/traps/cage.tscn"
const RING_TEX := preload("res://assets/generated/sacrifice_circle.png")
const BODY_TEX := preload("res://assets/generated/thousand_hand.png")
## 每个阶段能用的技能和冷却（秒）。
const COOLDOWNS := {
	1: {"dash": 10.0},
	2: {"dash": 12.0, "rain": 8.0},
	3: {"dash": 11.0, "rain": 9.0, "storm": 15.0, "dance": 30.0},
}

var boss: ThousandHand
## 千手乱舞时地上的安全圈（世界坐标）。
var safe_spots: Array[Vector2] = []
var current := ""
var _cd := {"dash": 5.0, "rain": 6.0, "storm": 10.0, "dance": 18.0}
var _serial := 0
var _nodes: Array[Node] = []
var _fx: Array[ScreenFx] = []


func busy() -> bool:
	return current != ""


## 打断正在放的技能（冻住、阶段切换、战败），清掉预警。
func cancel() -> void:
	_serial += 1
	current = ""
	# 俯冲到一半被打断（冻住 / 转阶段 / 战败）：本体直接回到原位
	if _dash_tw and _dash_tw.is_valid():
		_dash_tw.kill()
	if _dash_home != Vector2.INF and is_instance_valid(boss):
		boss.return_home(_dash_home, _dash_raised, true)
		boss.sprite.flip_h = false
	_dash_home = Vector2.INF
	safe_spots.clear()
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	for f in _fx:
		if is_instance_valid(f):
			f.fade_out(0.2)
	_fx.clear()


func reset_cooldowns() -> void:
	_cd = {"dash": 5.0, "rain": 6.0, "storm": 10.0, "dance": 18.0}


func think(delta: float) -> void:
	if busy():
		return
	var table: Dictionary = COOLDOWNS.get(boss.phase, {})
	for k in _cd:
		_cd[k] = _cd[k] - delta
	for k in ["dance", "storm", "dash", "rain"]:
		if table.has(k) and _cd[k] <= 0.0:
			_cd[k] = float(table[k]) * randf_range(0.9, 1.15)
			use(k)
			return


## 放一个技能（测试也直接调它）。
func use(k: String) -> void:
	match k:
		"dash":
			_dash(2 if boss.phase >= 3 else 1)
		"rain":
			_rain()
		"storm":
			_storm()
		"dance":
			_dance()


func _alive(serial: int) -> bool:
	return serial == _serial and is_instance_valid(boss) and boss.fighting and not boss.is_frozen()


func _targets() -> Array[PlayableCharacter]:
	return boss._targets()


func _parent() -> Node:
	return boss.get_parent()


func _danger_rect(r: Rect2, col := Color(1, 0.2, 0.3, 0.3)) -> Node2D:
	var holder := Node2D.new()
	holder.add_to_group("danger")
	holder.set_meta("rect", r)
	holder.z_index = 1
	var cr := ColorRect.new()
	cr.color = col
	cr.position = r.position
	cr.size = r.size
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(cr)
	_parent().add_child(holder)
	_nodes.append(holder)
	return holder


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, false).timeout


# ------------------------------------------------------------------ 俯冲撞墙（本体真的冲出去）
var _dash_home := Vector2.INF
var _dash_raised := false
var _dash_tw: Tween


func _dash(times: int) -> void:
	current = "dash"
	var serial := _serial
	_dash_home = boss.global_position
	_dash_raised = boss.raised
	boss.begin_dash()
	for i in times:
		var ts := _targets()
		if ts.is_empty():
			break
		var t: PlayableCharacter = ts.pick_random()
		var a := boss.arena
		var horizontal := randf() < 0.5
		var lane := Rect2(a.position.x, t.global_position.y - 16.0, a.size.x, 30.0) if horizontal \
			else Rect2(t.global_position.x - 18.0, a.position.y, 36.0, a.size.y)
		var warn := _danger_rect(lane)
		Audio.play("swish", -6.0, 0.0, 0.5)
		var tt := 0.0
		while tt < DASH_WARN:
			if not _alive(serial):
				return
			if is_instance_valid(warn):
				(warn.get_child(0) as ColorRect).color.a = 0.18 + 0.22 * (0.5 + 0.5 * sin(tt * 26.0))
			await get_tree().process_frame
			tt += get_process_delta_time()
		if is_instance_valid(warn):
			warn.queue_free()
		await _dash_run(lane, horizontal, serial)
		if not _alive(serial):
			return
		_wall_impact(lane, horizontal)
		# 撞墙撞晕：DAZE_TIME 秒里能打本体
		boss.daze(DAZE_TIME)
		await _wait(DAZE_TIME)
		if not _alive(serial):
			return
	var home := _dash_home
	_dash_home = Vector2.INF
	await boss.return_home(home, _dash_raised)
	if serial == _serial:
		current = ""


## 本体从现在的位置飞到通道一头，再沿通道冲过去：残影 + 速度线 + 尘土拖尾，撞到的人挠一大口并击飞。
func _dash_run(lane: Rect2, horizontal: bool, serial: int) -> void:
	var from := Vector2(lane.position.x + 20.0, lane.get_center().y) if horizontal else Vector2(lane.get_center().x, lane.position.y + 40.0)
	var to := Vector2(lane.end.x - 20.0, lane.get_center().y) if horizontal else Vector2(lane.get_center().x, lane.end.y - 4.0)
	# 从离自己近的那一头开始冲
	if boss.global_position.distance_to(to) < boss.global_position.distance_to(from):
		var tmp := from
		from = to
		to = tmp
	var off := Vector2(0, 30)   # 节点在本体脚下：本体中心对准通道中线
	_dash_tw = boss.create_tween()
	_dash_tw.tween_property(boss, "global_position", from + off, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _dash_tw.finished
	if serial != _serial:
		return
	var dir := (to - from).normalized()
	boss.sprite.flip_h = dir.x < 0.0
	var hit: Array = []
	var tt := 0.0
	var ghost_t := 0.0
	Audio.play("wind", -4.0, 0.0, 1.6)
	while tt < DASH_TIME:
		if serial != _serial or not is_instance_valid(boss):
			return
		var d := get_process_delta_time()
		tt += d
		boss.global_position = from.lerp(to, clampf(tt / DASH_TIME, 0.0, 1.0)) + off
		ghost_t -= d
		var body_center := boss.global_position + Vector2(0, -40)
		if ghost_t <= 0.0:
			ghost_t = 0.04
			_afterimage(boss.sprite)
			Fx.burst(_parent(), boss.global_position, "dust", 2, 20.0, 0.4, Vector2(0, 10))
			_speed_line(body_center, dir)
		for m in _targets():
			if m in hit:
				continue
			if m.global_position.distance_to(body_center + Vector2(0, 24)) < 40.0:
				hit.append(m)
				boss.deliver_tickle(m, DASH_TICKLE, false, 240.0)
				boss.play_tickle_sound()
				m.shake(0.3)
		await get_tree().process_frame
	boss.sprite.flip_h = false


func _afterimage(src: Sprite2D) -> void:
	var g := Sprite2D.new()
	g.texture = src.texture
	g.hframes = src.hframes
	g.frame = src.frame
	g.scale = src.scale
	g.flip_h = src.flip_h
	g.offset = src.offset
	g.modulate = Color(0.9, 0.6, 1.0, 0.5)
	g.z_index = 3
	_parent().add_child(g)
	g.global_position = src.global_position
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.25)
	tw.tween_callback(g.queue_free)


func _speed_line(at: Vector2, dir: Vector2) -> void:
	var l := Line2D.new()
	l.width = 1.0
	l.default_color = Color(1, 1, 1, 0.7)
	var side := dir.orthogonal() * randf_range(-22.0, 22.0)
	l.points = PackedVector2Array([at + side, at + side - dir * randf_range(20.0, 40.0)])
	l.z_index = 4
	_parent().add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 0.2)
	tw.tween_callback(l.queue_free)


## 撞墙：全屏大震 + 白闪 + 落石碎屑，随机掉 2~3 个落笼（落笼自己先出影子再落）。
func _wall_impact(lane: Rect2, horizontal: bool) -> void:
	ScreenFx.flash(Color.WHITE, 0.25)
	for m in Duo.members if Duo.active else [GameState.player]:
		if is_instance_valid(m):
			m.shake(0.45)
	Audio.play("break", 0.0, 0.05, 0.6)
	var a := boss.arena
	for i in 8:
		var p := Vector2(randf_range(a.position.x, a.end.x), a.position.y + randf_range(10, 40))
		Fx.burst(_parent(), p, "chip", 3, 40.0, 0.6, Vector2(0, 160), Color(0.7, 0.66, 0.72))
	for i in randi_range(2, 3):
		var cage: Trap = load(CAGE_SCENE).instantiate()
		cage.set("group_name", "f8_dash_cage")
		cage.set("content", ["feather", "slime"].pick_random())
		_parent().add_child(cage)
		var t := _targets()
		var spot := Vector2(randf_range(a.position.x + 24, a.end.x - 24), randf_range(a.position.y + 48, a.end.y - 20))
		if not t.is_empty() and randf() < 0.5:
			spot = t.pick_random().global_position + Vector2(randf_range(-30, 30), randf_range(-20, 20))
		cage.global_position = spot
		cage.trigger()
		boss.get_tree().create_timer(6.0, false).timeout.connect(func(): if is_instance_valid(cage): cage.queue_free())


# ------------------------------------------------------------------ 手臂雨
func _rain() -> void:
	current = "rain"
	var serial := _serial
	var ts := _targets()
	if ts.is_empty():
		current = ""
		return
	var t: PlayableCharacter = ts.pick_random()
	var c := t.global_position
	var pts: Array[Vector2] = []
	match randi() % 3:
		0:   # 十字
			for k in [-2, -1, 1, 2]:
				pts.append(c + Vector2(k * 22.0, 0))
			for k in [-1, 1]:
				pts.append(c + Vector2(0, k * 24.0))
			pts.append(c)
		1:   # 圆环
			for k in 8:
				pts.append(c + Vector2.from_angle(TAU * k / 8.0) * Vector2(40, 26))
		_:   # 追人：一个接一个落在她现在的位置
			for k in 7:
				pts.append(Vector2.INF)
	for p in pts:
		if not _alive(serial):
			return
		var at := p if p != Vector2.INF else (t.global_position if is_instance_valid(t) else c)
		at.x = clampf(at.x, boss.arena.position.x + 8, boss.arena.end.x - 8)
		at.y = clampf(at.y, boss.arena.position.y + 24, boss.arena.end.y - 8)
		boss.begin_slam(at)
		await _wait(RAIN_GAP if p != Vector2.INF else 0.35)
	await _wait(boss.slam_warn)
	if serial == _serial:
		current = ""


# ------------------------------------------------------------------ 羽毛风暴
func _storm() -> void:
	current = "storm"
	var serial := _serial
	var dir := Vector2.LEFT if randf() < 0.5 else Vector2.RIGHT
	# 屏幕边上的风向箭头
	var arrows := Label.new()
	arrows.text = ("◀◀◀ 风！" if dir.x < 0 else "风！ ▶▶▶")
	arrows.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	arrows.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.2))
	arrows.add_theme_constant_override("outline_size", 4)
	var layer := CanvasLayer.new()
	layer.layer = 9
	layer.add_child(arrows)
	boss.get_tree().root.add_child(layer)
	_nodes.append(layer)
	var vp := boss.get_viewport().get_visible_rect().size
	arrows.position = Vector2(10 if dir.x < 0 else vp.x - 90, vp.y * 0.45)
	Audio.play("wind", -2.0, 0.0, 0.8)
	await _wait(1.0)
	if not _alive(serial):
		return
	var a := boss.arena
	var feathers := Fx.emitter(_parent(), "feather", 40, 1.6, {"extents": Vector2(a.size.x * 0.5, a.size.y * 0.5), "dir": dir,
		"spread": 10.0, "speed": [160.0, 220.0], "z": 5})
	if feathers:
		feathers.global_position = a.get_center()
		_nodes.append(feathers)
	var tt := 0.0
	var tick := 0.0
	while tt < STORM_TIME and _alive(serial):
		var d := get_physics_process_delta_time()
		tt += d
		tick -= d
		for m in _targets():
			if m.is_dashing() or (m.status and m.status.is_grabbed()):
				continue
			m.move_and_collide(dir * STORM_PUSH * d)
			if tick <= 0.0:
				boss.deliver_tickle(m, 3.0)
		if tick <= 0.0:
			tick = 0.6
		await get_tree().physics_frame
	if is_instance_valid(feathers):
		feathers.emitting = false
		boss.get_tree().create_timer(1.6).timeout.connect(func(): if is_instance_valid(feathers): feathers.queue_free())
	if is_instance_valid(layer):
		layer.queue_free()
	if serial == _serial:
		current = ""


# ------------------------------------------------------------------ 千手乱舞
func _dance() -> void:
	current = "dance"
	var serial := _serial
	var dark := ScreenFx.darken(0.5, 0.4)
	var vig := ScreenFx.vignette(Color(0.95, 0.1, 0.2), 0.85, true)
	_fx.append(dark)
	_fx.append(vig)
	SpeechBubble.say(boss, "……千手……一起……！", 70.0)
	Audio.play("vine", -2.0, 0.0, 0.4)
	# 安全圈：离 Boss 远一点、彼此分开
	safe_spots.clear()
	var a := boss.arena
	var rings: Array[Node2D] = []
	for i in randi_range(2, 3):
		var p := Vector2.ZERO
		for attempt in 30:
			p = Vector2(randf_range(a.position.x + 30, a.end.x - 30), randf_range(a.position.y + 70, a.end.y - 20))
			if safe_spots.all(func(s): return s.distance_to(p) > 70.0):
				break
		safe_spots.append(p)
		var ring := Sprite2D.new()
		ring.texture = RING_TEX
		ring.hframes = 2
		ring.modulate = Color(0.6, 1.0, 0.7)
		ring.scale = Vector2(0.75, 0.75)
		ring.z_index = 6     # 压暗时也看得见
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		ring.material = mat
		_parent().add_child(ring)
		ring.global_position = p
		rings.append(ring)
		_nodes.append(ring)
	var tt := 0.0
	while tt < DANCE_WARN:
		if not _alive(serial):
			return
		for r in rings:
			r.frame = int(tt * 6.0) % 2
		await get_tree().process_frame
		tt += get_process_delta_time()
	ScreenFx.flash(Color.WHITE, 0.35)
	Audio.play("tickle_special", 0.0, 0.0, 0.7)
	for m in _targets():
		if not safe_spots.any(func(s): return s.distance_to(m.global_position) <= SAFE_RADIUS):
			boss.deliver_tickle(m, DANCE_TICKLE, true, 80.0)
			m.shake(0.4)
	for r in rings:
		if is_instance_valid(r):
			r.queue_free()
	safe_spots.clear()
	dark.fade_out(0.5)
	vig.fade_out(0.5)
	_fx.clear()
	await _wait(0.5)
	if serial == _serial:
		current = ""

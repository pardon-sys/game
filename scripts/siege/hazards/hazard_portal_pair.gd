class_name HazardPortalPair
extends SiegeHazard
## 挠痒传送门：一对门。入口 A 开在粉色公主附近，出口 B 开在怪最多的地方（或者挠痒敌塔旁边）。
## 双向（第十轮）：公主和怪走进哪扇门都从另一扇出来（公主落地时门里的小手顺手挠一下：粉色公主挠脚心，蓝色公主挠大腿 / 屁股）。
## 同一个人 / 怪 COOL 秒内不会再被传送。传送门怪潮：每 TIDE_GAP 秒从一扇门里涌出 TIDE_N 只小怪，冲向最近的公主。
## 蓝色公主的法术打到其中一扇门（冰锥雨 / 冰川突刺 / 暴风雪……落在门旁 FREEZE_R 以内）就把它冰封 FROZEN 秒：
## 冰封期间整对门都不传送，冰封的门也不涌怪。
## 门的位置：global_position = A，exit = B（世界坐标）。来源键 hazard_portal。

const RADIUS := 20.0
const FREEZE_R := 40.0
const FROZEN := 6.0
const COOL := 2.5
const TICKLE := 4.0
const TIDE_GAP := 4.0
const TIDE_N := 3
const TIDE_KEYS := ["rat", "slime", "imp"]

var exit := Vector2.ZERO
## 召唤者指定出口（狂欢要塞的传送门空降：出口开在城墙顶）；INF = 按 _exit_spot 挑
var exit_override := Vector2.INF
var frozen := [0.0, 0.0]
var _cool := {}
var _hits := 0
var _tide_t := 2.0
## 测试用：门里涌出来的怪有几只
var tide := 0


func _begin() -> void:
	reaction_key = "hazard_portal"
	life = 14.0
	add_to_group("siege_portal")
	exit = exit_override if exit_override != Vector2.INF else _exit_spot()
	SiegeFx.ring(get_parent(), global_position, RADIUS * 1.8, Color(0.75, 0.5, 1.0, 0.8), WARN)
	SiegeFx.ring(get_parent(), exit, RADIUS * 1.8, Color(1, 0.5, 0.8, 0.8), WARN)
	Audio.play("chant", -6.0, 0.1, 0.7)


## 出口：挠痒类敌塔旁边（有的话一半几率），不然怪最多的地方。
func _exit_spot() -> Vector2:
	var towers: Array = []
	for t in get_tree().get_nodes_in_group("siege_enemy_tower"):
		if t is EnemyTower and SiegeTools.alive(t) and str(t.kind) in ["sole_tower", "thigh_tower", "brush_battery", "net", "glue"]:
			towers.append(t)
	if not towers.is_empty() and randf() < 0.5:
		var t: Node2D = towers.pick_random()
		return director.clamp_in_map(t.global_position + Vector2(randf_range(-30, 30), 36))
	var crowd: Variant = director.densest(60.0, global_position, 900.0)
	var p: Vector2 = crowd if crowd is Vector2 and (crowd as Vector2).distance_to(global_position) > 120.0 else global_position + Vector2(randf_range(-260, 260), 220)
	p = director.clamp_in_map(p)
	p.y = maxf(p.y, director.wall_foot_y() + 60.0)
	return p


func door(i: int) -> Vector2:
	return global_position if i == 0 else exit


func _active(delta: float) -> void:
	frozen[0] = maxf(0.0, float(frozen[0]) - delta)
	frozen[1] = maxf(0.0, float(frozen[1]) - delta)
	for k in _cool.keys():
		_cool[k] = float(_cool[k]) - delta
	# 双向：走进哪扇就从另一扇出来；冰封的门既进不去也出不来
	if float(frozen[0]) <= 0.0 and float(frozen[1]) <= 0.0:
		for i in 2:
			var src := door(i)
			var dst := door(1 - i)
			for c in chars():
				if director.is_on_wall(c) or float(_cool.get(c.get_instance_id(), 0.0)) > 0.0 or not SiegeTools.can_move(null, c) or c.is_airborne():
					continue
				if c.global_position.distance_to(src) <= RADIUS:
					_send_princess(c, dst, i == 0)
			for m in director.enemies_near(src, RADIUS + 4.0):
				if SiegeTools.displaceable(m) and float(_cool.get(m.get_instance_id(), 0.0)) <= 0.0:
					_cool[m.get_instance_id()] = COOL
					m.global_position = dst + Vector2(randf_range(-10, 10), randf_range(6, 12))
					# 出口在城墙顶：落下来就是墙顶的怪
					if dst.y < director.wall_foot_y():
						m.global_position.y = dst.y + randf_range(-2, 4)
						TeamworkEffects.put_on_wall(m, m.global_position)
					Fx.burst(get_parent(), m.global_position, "spark", 6, 40.0, 0.4, Vector2.ZERO, Color(0.8, 0.6, 1.0))
	# 传送门怪潮：每 TIDE_GAP 秒从一扇没冰封的门里涌出一小队，冲向离那扇门最近的公主
	_tide_t -= delta
	if _tide_t <= 0.0:
		_tide_t = TIDE_GAP
		var open: Array[int] = []
		for i in 2:
			if float(frozen[i]) <= 0.0:
				open.append(i)
		if not open.is_empty():
			var at := door(open.pick_random())
			var target: PlayableCharacter = null
			for c in chars():
				if target == null or c.global_position.distance_to(at) < target.global_position.distance_to(at):
					target = c
			for m in ambush(at + Vector2(0, RADIUS + 4.0), TIDE_KEYS, TIDE_N, target):
				_cool[m.get_instance_id()] = COOL
				tide += 1


func _send_princess(c: PlayableCharacter, to_door: Vector2, to_exit: bool) -> void:
	_cool[c.get_instance_id()] = COOL
	Fx.burst(get_parent(), c.global_position + Vector2(0, -10), "spark", 12, 50.0, 0.5, Vector2.ZERO, Color(0.8, 0.6, 1.0))
	var to := to_door + Vector2(randf_range(-8, 8), RADIUS + 6.0)
	var safe := SiegeTools.safe_spot(c, to)
	c.global_position = safe if safe != Vector2.INF else to
	c.velocity = Vector2.ZERO
	Fx.burst(get_parent(), c.global_position + Vector2(0, -10), "spark", 12, 50.0, 0.5, Vector2.ZERO, Color(1, 0.6, 0.85))
	Audio.play("chime", -4.0, 0.1)
	tickle(c, TICKLE, SiegeTools.zone(c, _hits))
	_hits += 1
	var pink := c.character_id == "pink"
	if to_exit:
		SpeechBubble.say(c, "诶？我怎么跑到怪堆里来了！" if pink else "……这里是哪。……怪好多。", 28.0, 1.4)
	else:
		SpeechBubble.say(c, "又、又被传回来了！" if pink else "……又回来了。……绕晕了。", 28.0, 1.4)


## 法术落在门旁：冰封那扇门（SiegeSpells 施法后调用）。返回冰封了几扇。
func on_spell(point: Vector2, radius: float) -> int:
	var n := 0
	for i in 2:
		var at: Vector2 = global_position if i == 0 else exit
		if at.distance_to(point) <= radius + FREEZE_R:
			frozen[i] = FROZEN
			n += 1
			Fx.burst(get_parent(), at + Vector2(0, -8), "crystal", 14, 40.0, 0.6, Vector2(0, 30), Color(0.8, 0.95, 1.0))
	if n > 0:
		Audio.play("ice_crack", -4.0, 0.1, 1.2)
	return n


func _draw() -> void:
	for i in 2:
		var at: Vector2 = Vector2.ZERO if i == 0 else exit - global_position
		var ice := float(frozen[i]) > 0.0
		var col := Color(0.8, 0.95, 1.0, 0.9) if ice else (Color(0.7, 0.45, 1.0, 0.85) if i == 0 else Color(1, 0.5, 0.8, 0.85))
		var a := 1.0 if warned else 0.4
		draw_set_transform(at + Vector2(0, -12), 0.0, Vector2(0.7, 1.0))
		draw_circle(Vector2.ZERO, RADIUS, Color(0.12, 0.05, 0.2, 0.75 * a))
		for k in 3:
			var start := _t * (3.0 - k) * (1.0 if i == 0 else -1.0) + k * 2.0
			draw_arc(Vector2.ZERO, RADIUS - k * 3.5, start, start + 3.5, 20, Color(col, a), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if ice:
			draw_rect(Rect2(at + Vector2(-11, -26), Vector2(22, 26)), Color(0.85, 0.97, 1.0, 0.45))

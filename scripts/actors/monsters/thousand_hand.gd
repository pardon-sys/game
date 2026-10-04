class_name ThousandHand
extends Monster
## 千手痒痒魔（第八层 Boss）：巨大的身体盘在场地上方，垂下很多手臂。不移动；三个阶段由 Floor8Director 推进。
##   阶段一：本体趴在高台边上，能打（attackable）。手臂砸地、羽毛扫击、召唤两组小怪。
##   阶段二：本体缩到天花板（raised），打不到；被两块压力板拉动的锁链拽下来 pull_down(秒) 期间能打、受到伤害 ×PULLED_MULT。
##   阶段三：一直在上面；手臂砸地 / 扫击更快，三组小怪都召。献祭：sacrifice_grab(角色) 把她抓到巢穴里挠（导演管小窗和挣扎）。
## 招式：
##   手臂砸地 slam：目标脚下出预警圈（danger 组，AI 会躲），slam_warn 秒后手臂砸下，砸中就抓起来挠（连按挣脱）。
##   羽毛扫击 sweep：目标所在的一整行出预警（danger 组，meta rect），sweep_warn 秒后一只大羽毛手横扫过去，扫到的挠一下并推开。
##   召唤 summon：从场地两边的召唤点放出小怪（按阶段：松鼠 + 刺猬、毛毛虫 + 章鱼宝宝、泡泡鱼 + 蜘蛛 + 羽毛小精灵群）。
## 血量按阶段有下限（PHASE_FLOOR；阶段三是 1 点）：打到下限就停住、发出 threshold_reached(阶段)，导演播过场后进入下一阶段 / 胜利。

signal threshold_reached(phase: int)

const SHEET := preload("res://assets/generated/thousand_hand.png")
const ARM := preload("res://assets/generated/thousand_hand_arm.png")
const MARK_TEX := preload("res://assets/generated/strike_mark.png")
const PHASE_FLOOR := {1: 0.7, 2: 0.35, 3: 0.0}
const PULLED_MULT := 1.5
const RAISE_Y := -72.0
const SUMMONS := {
	1: [["squirrel", "hedgehog"], ["caterpillar", "octopus"]],
	2: [["squirrel", "hedgehog"]],
	3: [["squirrel", "hedgehog"], ["caterpillar", "octopus"], ["bubble_fish", "spider", "fairy"]],
}
const MONSTER_SCENES := {
	"squirrel": "res://scenes/actors/monsters/brush_squirrel.tscn", "hedgehog": "res://scenes/actors/monsters/brush_hedgehog.tscn",
	"caterpillar": "res://scenes/actors/monsters/caterpillar.tscn", "octopus": "res://scenes/actors/monsters/suction_octopus.tscn",
	"bubble_fish": "res://scenes/actors/monsters/bubble_fish.tscn", "spider": "res://scenes/actors/monsters/tickle_spider.tscn",
	"fairy": "res://scenes/actors/monsters/fairy_swarm.tscn",
}

@export var slam_warn := 0.8
@export var sweep_warn := 1.0
@export var grab_tickle := 7.0
@export var grab_interval := 0.45
@export var grab_presses := 10

var phase := 1
## 导演打开后才开始行动（开场过场里不动）。
var fighting := false
var attackable := true
var raised := false
## 场地（世界坐标）：扫击横跨整个场地；召唤点在左右两边。
var arena := Rect2()
var summon_points: Array[Vector2] = []
var victim: PlayableCharacter
var sacrificed: PlayableCharacter
var _slam_cd := 2.0
var _sweep_cd := 5.0
var _summon_cd := 3.0
var _grab_tick := 0.0
var _pulled_left := 0.0
var _hurt_flash := 0.0
var _floor_hit := false
## 正在预警的招式：[{kind, time, pos / rect, node}]
var _pending: Array[Dictionary] = []
## 这一刻画出来的手臂（一闪而过的砸地、抓人、扫击）：[{from, to, hand, life}]
var _flashes: Array[Dictionary] = []
var _sweep_hand := {}
var _arm_layer: Node2D
var _rage := false


func _setup() -> void:
	super()
	add_to_group("thousand_hand")
	sprite.texture = SHEET
	sprite.hframes = 6
	sprite.vframes = 1
	sprite.offset = Vector2(0, -48)
	_arm_layer = Node2D.new()
	_arm_layer.name = "Arms"
	_arm_layer.z_index = 3
	add_child(_arm_layer)
	_arm_layer.draw.connect(_draw_arms)
	set_meta("hit_radius", 34.0)


# ------------------------------------------------------------------ 受伤（阶段下限、拽下来时加倍）
func receive_hit(hit: HitData) -> bool:
	if not attackable:
		return false
	return apply_hit(hit)


## 下来的手臂（BossLimb）挨打时转给本体：不看 attackable。
func apply_hit(hit: HitData) -> bool:
	if not fighting or _dead:
		return false
	if hit.kind == HitData.Kind.ATTACK and _pulled_left > 0.0:
		hit.damage = int(ceil(hit.damage * PULLED_MULT))
	# 阶段三的下限是 1 点：不会真的打死（胜利过场里它还要恼怒、砸墙），打到 1 点就算赢
	var floor_hp := 1 if phase >= 3 else int(ceil(health.max_hp * float(PHASE_FLOOR.get(phase, 0.0))))
	if hit.kind == HitData.Kind.ATTACK and floor_hp > 0:
		hit.damage = mini(hit.damage, maxi(0, health.hp - floor_hp))
		if hit.damage <= 0:
			_reach_floor()
			return false
	var ok: bool = super.receive_hit(hit)
	if ok:
		_hurt_flash = 0.15
	if floor_hp > 0 and health.hp <= floor_hp:
		_reach_floor()
	return ok


func _reach_floor() -> void:
	if _floor_hit:
		return
	_floor_hit = true
	fighting = false
	cancel_attacks()
	threshold_reached.emit(phase)


## 进入阶段 p（导演在过场之后调用）。
func set_phase(p: int) -> void:
	phase = p
	_floor_hit = false
	_rage = p >= 3
	slam_warn = {1: 0.8, 2: 0.75, 3: 0.65}[p]
	sweep_warn = {1: 1.0, 2: 0.9, 3: 0.8}[p]
	set_raised(p >= 2)
	_slam_cd = 1.5
	_sweep_cd = 4.0
	_summon_cd = 2.0


## 阶段开始时的血量（战败重来时回到这里）。
func phase_start_hp(p: int) -> int:
	return int(ceil(health.max_hp * {1: 1.0, 2: 0.7, 3: 0.35}[p]))


## 缩到天花板（打不到）/ 趴回高台边（能打）。
func set_raised(up: bool) -> void:
	raised = up
	attackable = not up
	var shape := get_node_or_null("Shape") as CollisionShape2D
	if shape:
		shape.set_deferred("disabled", up)
	var tw := create_tween()
	tw.tween_property(sprite, "position:y", RAISE_Y if up else 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 阶段二：锁链把它拽下来 sec 秒（僵直、能打、伤害加倍），之后升回去。
func pull_down(sec: float) -> void:
	_pulled_left = sec
	cancel_attacks()
	set_raised(false)
	Audio.play("locked", -2.0, 0.0, 0.6)
	SpeechBubble.say(self, "……！", 60.0)


func is_pulled() -> bool:
	return _pulled_left > 0.0


# ------------------------------------------------------------------ 行动
func _tick(delta: float) -> void:
	_t += delta
	velocity = Vector2.ZERO
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	for f in _flashes.duplicate():
		f["life"] -= delta
		if f["life"] <= 0.0:
			_flashes.erase(f)
	var frozen := GameState.in_dialogue
	if _pulled_left > 0.0 and not frozen:
		_pulled_left -= delta
		if _pulled_left <= 0.0 and phase >= 2:
			set_raised(true)
	if fighting and not frozen and not _dead:
		_update_pending(delta)
		_update_grab(delta)
		_update_sweep(delta)
		if _pulled_left <= 0.0:
			_think_attacks(delta)
	_animate(delta)
	_arm_layer.queue_redraw()


func _targets() -> Array[PlayableCharacter]:
	var out: Array[PlayableCharacter] = []
	for m in Duo.members if Duo.active else [GameState.player]:
		if is_instance_valid(m) and m.is_alive() and not Downed.is_downed(m) and m != sacrificed:
			out.append(m)
	return out


func _think_attacks(delta: float) -> void:
	var ts := _targets()
	if ts.is_empty():
		return
	var fast := 0.75 if phase == 3 else (0.9 if phase == 2 else 1.0)
	_slam_cd -= delta
	_sweep_cd -= delta
	_summon_cd -= delta
	if _slam_cd <= 0.0 and victim == null:
		_slam_cd = randf_range(1.8, 2.6) * fast
		begin_slam(ts.pick_random().global_position)
		if phase == 3 and ts.size() > 1 and randf() < 0.5:
			begin_slam(ts.pick_random().global_position + Vector2(randf_range(-20, 20), randf_range(-12, 12)))
	if _sweep_cd <= 0.0:
		_sweep_cd = randf_range(5.5, 7.5) * fast
		begin_sweep(ts.pick_random().global_position.y)
	if _summon_cd <= 0.0:
		_summon_cd = 9.0 if phase == 3 else 11.0
		summon()


## 手臂砸地：pos 出预警圈，slam_warn 秒后砸下。
func begin_slam(pos: Vector2) -> void:
	var mark := Sprite2D.new()
	mark.texture = MARK_TEX
	mark.hframes = 2
	mark.scale = Vector2(1.6, 1.6)
	mark.add_to_group("danger")
	mark.set_meta("radius", 16.0)
	get_parent().add_child(mark)
	mark.global_position = pos
	_pending.append({"kind": "slam", "time": slam_warn, "pos": pos, "node": mark})
	Audio.play("vine", -6.0, 0.1, 0.6)


## 羽毛扫击：y 那一行（高 22 像素）出预警，sweep_warn 秒后从一边扫到另一边。
func begin_sweep(y: float) -> void:
	var r := Rect2(arena.position.x, y - 14.0, arena.size.x, 22.0)
	var warn := ColorRect.new()
	warn.color = Color(1, 0.3, 0.55, 0.28)
	warn.position = r.position
	warn.size = r.size
	warn.z_index = 1
	var holder := Node2D.new()
	holder.add_to_group("danger")
	holder.set_meta("rect", r)
	holder.add_child(warn)
	get_parent().add_child(holder)
	_pending.append({"kind": "sweep", "time": sweep_warn, "rect": r, "node": holder})
	Audio.play("swish", -8.0, 0.05, 0.6)


func _update_pending(delta: float) -> void:
	for s in _pending.duplicate():
		s["time"] -= delta
		var n: Node = s["node"]
		if n is Sprite2D and is_instance_valid(n):
			(n as Sprite2D).frame = int(s["time"] * 10.0) % 2
		elif is_instance_valid(n) and n.get_child_count() > 0:
			(n.get_child(0) as ColorRect).color.a = 0.2 + 0.25 * (0.5 + 0.5 * sin(s["time"] * 24.0))
		if s["time"] <= 0.0:
			_pending.erase(s)
			if is_instance_valid(n):
				n.queue_free()
			if s["kind"] == "slam":
				_slam(s["pos"])
			else:
				_start_sweep(s["rect"])


func _slam(pos: Vector2) -> void:
	_flashes.append({"from": _arm_root(pos), "to": pos, "hand": 2, "life": 0.25})
	Audio.play("swish", -2.0, 0.05, 0.7)
	Fx.burst(get_parent(), pos, "dust", 6, 40.0, 0.4, Vector2(0, 30))
	if victim != null:
		return
	for m in _targets():
		if m.global_position.distance_to(pos) <= 16.0 and m.can_be_grabbed() and m.status.grab(self, 3.5, grab_presses):
			victim = m
			_grab_tick = 0.3
			Audio.play("grab", -2.0, 0.05, 0.8)
			maybe_taunt(true)
			return


func _update_grab(delta: float) -> void:
	if victim == null:
		return
	if not is_instance_valid(victim) or not victim.is_alive() or not victim.status.is_grabbed_by(self):
		victim = null
		_slam_cd = maxf(_slam_cd, 1.2)
		return
	_grab_tick -= delta
	if _grab_tick <= 0.0:
		_grab_tick = grab_interval
		if deliver_tickle(victim, grab_tickle):
			play_tickle_sound()
			maybe_taunt()


func _start_sweep(r: Rect2) -> void:
	var left := randf() < 0.5
	_sweep_hand = {"rect": r, "x": r.position.x if left else r.end.x, "dir": 1.0 if left else -1.0, "hit": []}
	Audio.play("wind", -6.0, 0.0, 1.2)


func _update_sweep(delta: float) -> void:
	if _sweep_hand.is_empty():
		return
	var r: Rect2 = _sweep_hand["rect"]
	_sweep_hand["x"] += _sweep_hand["dir"] * r.size.x / 0.55 * delta
	var x: float = _sweep_hand["x"]
	for m in _targets():
		if m in _sweep_hand["hit"]:
			continue
		if absf(m.global_position.x - x) < 14.0 and r.grow(2.0).has_point(m.global_position):
			_sweep_hand["hit"].append(m)
			deliver_tickle(m, 9.0, false, 160.0)
			play_tickle_sound()
	if x < r.position.x - 10.0 or x > r.end.x + 10.0:
		_sweep_hand = {}


func cancel_attacks() -> void:
	for s in _pending:
		if is_instance_valid(s["node"]):
			s["node"].queue_free()
	_pending.clear()
	_sweep_hand = {}
	if victim and is_instance_valid(victim) and victim.status.is_grabbed_by(self):
		victim.status.release(false)
	victim = null


func pending_attacks() -> int:
	return _pending.size()


# ------------------------------------------------------------------ 召唤
func summon() -> void:
	var groups: Array = SUMMONS.get(phase, [])
	if groups.is_empty() or summon_points.is_empty():
		return
	var alive := get_tree().get_nodes_in_group("f8_summon").filter(func(n): return n is Actor and n.is_alive()).size()
	var cap := 6 if phase == 3 else 4
	var group: Array = groups.pick_random() if phase < 3 else groups[randi() % groups.size()]
	for key in group:
		if alive >= cap:
			break
		var m: Monster = load(MONSTER_SCENES[key]).instantiate()
		m.add_to_group("f8_summon")
		get_parent().add_child(m)
		m.global_position = summon_points.pick_random() + Vector2(randf_range(-12, 12), randf_range(-8, 8))
		m.rally_to(_targets().pick_random() if not _targets().is_empty() else GameState.player)
		Fx.burst(get_parent(), m.global_position, "dust", 5, 30.0, 0.4)
		alive += 1
	Audio.play("chime", -4.0, 0.0, 0.6)
	maybe_taunt(true)


func clear_summons() -> void:
	for n in get_tree().get_nodes_in_group("f8_summon"):
		n.queue_free()


# ------------------------------------------------------------------ 献祭（阶段三）
## 把 c 抓到巢穴（lair_pos）里：她动不了，由导演的 SacrificeStruggle 管挣扎。
func sacrifice_grab(c: PlayableCharacter, lair_pos: Vector2) -> void:
	sacrificed = c
	if c.status.is_grabbed():
		c.status.release(false)
	c.status.grab(self, 9999.0, 99999)
	_flashes.append({"from": _arm_root(c.global_position), "to": c.global_position, "hand": 2, "life": 0.4})
	c.global_position = lair_pos
	Audio.play("grab", -1.0, 0.0, 0.6)
	maybe_taunt(true)


func sacrifice_release(c: PlayableCharacter, drop_pos: Vector2) -> void:
	if is_instance_valid(c) and c.status.is_grabbed_by(self):
		c.status.release(true)
	if is_instance_valid(c):
		c.global_position = drop_pos
		c.set_invulnerable(1.5, true)
	sacrificed = null


# ------------------------------------------------------------------ 表现
func _arm_root(to: Vector2) -> Vector2:
	var base := global_position + Vector2(0, -6 + sprite.position.y)
	return base + Vector2(clampf(to.x - base.x, -50.0, 50.0), 0)


func _animate(_delta: float) -> void:
	if _hurt_flash > 0.0:
		sprite.frame = 2
	elif _pulled_left > 0.0:
		sprite.frame = 3
	elif _rage:
		sprite.frame = 4 + int(_t * 6.0) % 2
	else:
		sprite.frame = int(_t * 1.6) % 2
	# 恼怒 / 被拽下来时微微抖动
	sprite.position.x = (sin(_t * 40.0) * 1.0) if (_rage or _pulled_left > 0.0) else 0.0


func _arm_part(i: int) -> Rect2:
	return Rect2(i * 24, 0, 24, 24)


func _chain(from: Vector2, to: Vector2, hand_idx: int, wiggle := 0.0) -> void:
	var a := _arm_layer.to_local(from)
	var b := _arm_layer.to_local(to)
	var n := maxi(2, int(a.distance_to(b) / 9.0))
	for i in n:
		var f := float(i) / n
		var p := a.lerp(b, f) + Vector2(sin(_t * 3.0 + f * 6.0) * wiggle * f, 0)
		_arm_layer.draw_texture_rect_region(ARM, Rect2(p - Vector2(12, 12), Vector2(24, 24)), _arm_part(i % 2))
	var frame := hand_idx + (int(_t * 8.0) % 2)
	_arm_layer.draw_texture_rect_region(ARM, Rect2(b - Vector2(12, 14), Vector2(24, 24)), _arm_part(frame))


func _draw_arms() -> void:
	var top := global_position + Vector2(0, -6 + sprite.position.y)
	# 平时垂着的四只手（轻轻晃）
	if not raised or phase < 3:
		for i in 4:
			var x := -45.0 + i * 30.0
			var dangle := 22.0 + 6.0 * sin(_t * 1.7 + i)
			_chain(top + Vector2(x, 0), top + Vector2(x + sin(_t * 1.3 + i * 1.7) * 6.0, dangle), [2, 4, 6, 2][i], 3.0)
	for f in _flashes:
		_chain(f["from"], f["to"], f["hand"])
	if is_instance_valid(victim):
		_chain(_arm_root(victim.global_position), victim.global_position + Vector2(sin(_t * 9.0) * 4.0, -10), 2, 2.0)
	if not _sweep_hand.is_empty():
		var r: Rect2 = _sweep_hand["rect"]
		var p := Vector2(_sweep_hand["x"], r.get_center().y)
		_chain(Vector2(p.x, top.y), p, 4)
	# 被拽下来：两条锁链从天花板勒住
	if _pulled_left > 0.0:
		for dx in [-60.0, 60.0]:
			var from := global_position + Vector2(dx, -140)
			var to := global_position + Vector2(dx * 0.3, -40)
			var la := _arm_layer.to_local(from)
			var lb := _arm_layer.to_local(to)
			var n := int(la.distance_to(lb) / 6.0)
			for i in n:
				_arm_layer.draw_circle(la.lerp(lb, float(i) / n), 2.0, Color(0.75, 0.76, 0.84), false, 1.0)


func _on_died() -> void:
	cancel_attacks()
	fighting = false
	super()

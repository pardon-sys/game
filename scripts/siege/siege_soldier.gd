class_name SiegeSoldier
extends Actor
## 攻防战的友军士兵（SiegeDirector.ROSTER / add_soldiers 生成；行走图 assets/generated/siege/soldier_<角色>.png，
## 由 tools/art/gen_siege_art.py 从镇民守卫的图 guard.png 上色、加道具生成，32x32 × 4 帧 × 4 行）：
##   spear   长矛兵：墙下守自己那一段，打附近 SPEAR_RANGE 内的怪 / 敌塔（近战、有击退）；没怪时在岗位附近巡逻。
##   archer  弓箭手：站在墙顶，往墙下 ARCHER_RANGE 内的怪 / 敌塔射箭，也打爬上墙的怪；没怪时在墙顶小范围来回走。
##   shield  盾兵：站到受伤最重的那段城墙下，嘲讽 TAUNT 像素内的怪（lure：怪物优先挠他）；攻城车撞上来会被他挡下一次（他撤退）。
##   medic   医护兵：跟着粉色公主 / 受伤的士兵，每 MEDIC_GAP 秒给范围内的人降闷笑、回血；也能和长矛兵一起抬蓝色公主。
##   artisan 工匠：去修城墙最破的一段、修受伤的冰塔；没得修时去拆附近敌塔地基的搭建进度。
##   mage    冰吟诵学徒：去最近的「等冰光」的冰塔基座旁边帮忙放冰光（效率是蓝色公主的一半，BuildPad.HELPER_RATE）；没活时在岗位附近转。
## 怪物会挠士兵（他们是怪物的目标之一：SiegeDirector.extra_targets；血量 = 还能撑多久），被挠时头顶冒气泡；
## 撑不住了（血量到 RETREAT_HP 以下 / 归零）就跑回城门，RETURN_TIME 秒后满血回到岗位，不会真的倒下。
## 抬蓝色公主：SiegeDirector.call_bearers 叫两个长矛兵 / 医护兵（她倒在墙下）/ 一个弓箭手（倒在墙顶）过去：
##   长矛兵把她抬到最近的梯子、抬上墙顶 → 她复活；弓箭手走到她身边扶 HELP_TIME 秒 → 她复活。
## 镇民支援的倍数：soldier_atk 攻击、soldier_hp 血量、soldier_return 撤退时间、ally_cd 攻击间隔、detect 索敌；移速走 town_* 状态（stat_mul speed）。

const SPEED := 46.0
const SPEAR_RANGE := 130.0
const ARCHER_RANGE := 320.0
const TAUNT := 90.0
const MEDIC_GAP := 3.0
const MEDIC_RANGE := 46.0
const REPAIR_RATE := 4.0
const RETREAT_HP := 1
const RETURN_TIME := 20.0
const HELP_TIME := 6.0
## 冰吟诵学徒离开帮忙的位置这么远才算走开
const MAGE_LEAVE := 16.0
const LINES := ["哈哈别挠了！", "痒、痒——站住！", "哈哈哈……顶住！", "别挠胳肢窝……哈哈！"]
const ROLE_NAMES := {"spear": "长矛兵", "archer": "弓箭手", "shield": "盾兵", "medic": "医护兵", "artisan": "工匠", "mage": "冰吟诵学徒", "builder": "冰筑工匠"}
const HP := {"spear": 8, "archer": 5, "shield": 14, "medic": 5, "artisan": 6, "mage": 5, "builder": 7}
const ART_DIR := "res://assets/generated/siege/"

@export var role := "spear"

var post := Vector2.ZERO
var director: Node
var retreating := false
## 盾兵的嘲讽半径（SiegeDirector.nearest_target 读 lure：在这个距离内的怪优先找他）
var lure := 0.0
## 抬蓝色公主的任务：null = 没有
var carry_target: PlayableCharacter
var carry_partner: SiegeSoldier
var _cd := 0.0
var _t := 0.0
var _wander_to := Vector2.ZERO
var _wander_t := 0.0
var _say_t := 0.0
var _help := 0.0
var _retreat_tw: Tween
var _job_t := 0.0
var _job: Variant = null
var builder: SiegeBuilder


func _setup() -> void:
	set_faction(Faction.Type.ALLY)
	add_to_group("siege_soldier")
	add_to_group("siege_temp_keep")
	collision_layer = 2
	collision_mask = 0 if role == "archer" else 1
	var cs := CollisionShape2D.new()
	var r := CircleShape2D.new()
	r.radius = 6.0 if role == "shield" else 5.0
	cs.shape = r
	add_child(cs)
	var hc := HealthComponent.new()
	hc.name = "Health"
	hc.max_hp = int(HP.get(role, 6))
	add_child(hc)
	health = hc
	hc.fill()
	hc.died.connect(_die)
	sprite = Sprite2D.new()
	sprite.name = "Sprite"
	var path := ART_DIR + "soldier_%s.png" % role
	sprite.texture = load(path) if ResourceLoader.exists(path) else load("res://assets/generated/npcs/guard.png")
	sprite.hframes = 4
	sprite.vframes = 4
	sprite.offset = Vector2(0, -14)
	add_child(sprite)
	hurt_invuln_time = 0.5
	if role == "shield":
		lure = TAUNT
	post = global_position
	_wander_to = post
	if role == "builder": builder = SiegeBuilder.new(self)


func _town(key: String) -> float:
	var d := director as SiegeDirector
	return d.town.mul(key) if d and d.town else 1.0


## 镇民支援之后的血量上限（卫兵队长的号令 ×1.5）。
func refresh_max_hp() -> void:
	var want := int(round(int(HP.get(role, 6)) * _town("soldier_hp")))
	if health and health.max_hp != want:
		var add := want - health.max_hp
		health.max_hp = want
		health.heal(maxi(add, 0))


func is_alive() -> bool:
	return not retreating and super()


## 能不能派去抬蓝色公主。
func available() -> bool:
	return not retreating and carry_target == null and is_inside_tree()


func _on_damaged(_hit: HitData) -> void:
	_say_t -= 1.0
	if _say_t <= 0.0:
		_say_t = 2.5
		SpeechBubble.say(self, LINES.pick_random(), 26.0, 1.2)
	if health.hp <= RETREAT_HP:
		_retreat()


## 别真的倒下：归零也只是撤退。
func _die() -> void:
	_retreat()


func _retreat() -> void:
	if retreating:
		return
	retreating = true
	_leave_build()
	_drop_carry()
	SpeechBubble.say(self, "撑、撑不住了……先撤！", 26.0, 1.4)
	var d: Node = director
	var gate: Vector2 = d.get("gate_pos") if d else post
	var tw := create_tween()
	_retreat_tw = tw
	tw.tween_property(self, "global_position", gate, maxf(0.4, global_position.distance_to(gate) / (SPEED * 1.6)))
	tw.tween_callback(func(): visible = false)
	tw.tween_interval(RETURN_TIME * _town("soldier_return"))
	tw.tween_callback(func():
		health.fill()
		global_position = post
		visible = true
		retreating = false
		SpeechBubble.say(self, "回来了！", 26.0, 1.0))


## 这一波失败重来：满血、回岗位、不再撤退。
func reset_post() -> void:
	_leave_build()
	if builder: builder.reset()
	if _retreat_tw and _retreat_tw.is_valid():
		_retreat_tw.kill()
	_drop_carry()
	retreating = false
	health.fill()
	global_position = post
	visible = true
	velocity = Vector2.ZERO


func _tick(delta: float) -> void:
	if SiegeTools.paused():
		velocity = Vector2.ZERO
		return
	_t += delta
	_cd -= delta
	refresh_max_hp()
	if retreating or director == null:
		velocity = Vector2.ZERO
		_animate()
		return
	if carry_target:
		_carry_tick(delta)
	else:
		match role:
			"spear": _spear(delta)
			"archer": _archer(delta)
			"shield": _shield(delta)
			"medic": _medic(delta)
			"artisan": _artisan(delta)
			"mage": _mage(delta)
			"builder": builder.tick(delta)
	# 速度加成乘在这一帧算出来的速度上（先限一下长度：有的分支沿用上一帧的速度，不能越乘越大）
	velocity = velocity.limit_length(SPEED * 1.6) * stat_mul("speed")
	move_with_push()
	_animate()


## 最近的目标：怪（迷雾里的除外）优先，没有怪时打范围内的敌塔。
func _nearest(r: float) -> Actor:
	r *= _town("detect")
	var best: Actor = null
	var best_d := r
	for m in director.enemies_near(global_position, r, false):
		var dd := global_position.distance_to(m.global_position)
		if dd < best_d:
			best_d = dd
			best = m
	if best == null:
		for t in get_tree().get_nodes_in_group("siege_enemy_tower"):
			var dd2 := global_position.distance_to((t as Node2D).global_position)
			if dd2 < best_d and (t as Actor).is_alive():
				best_d = dd2
				best = t
	return best


func _atk() -> int:
	var v := _town("soldier_atk")
	return int(v) + (1 if randf() < v - floorf(v) else 0)


func _cooldown(base: float) -> float:
	return base * _town("ally_cd") * stat_mul("tickle_cd")


func _spear(delta: float) -> void:
	var m := _nearest(SPEAR_RANGE)
	if m == null or global_position.distance_to(post) > SPEAR_RANGE * 1.8:
		_wander(delta, 40.0)
		return
	var to := m.global_position - global_position
	if to.length() > 14.0:
		velocity = to.normalized() * SPEED
	else:
		velocity = Vector2.ZERO
		if _cd <= 0.0:
			_cd = _cooldown(0.8)
			m.receive_hit(HitData.make_attack(self, _atk(), 120.0))
			_stab_fx(m.global_position)


## 长矛刺出的闪光 + 碎屑。
func _stab_fx(at: Vector2) -> void:
	var from := global_position + Vector2(0, -10)
	SiegeFx.lane(get_parent(), from, at + Vector2(0, -6), 1.5, Color(1, 1, 0.85), 0.12)
	Fx.burst(get_parent(), at + Vector2(0, -6), "chip", 3, 30.0, 0.3, Vector2(0, 40), Color(0.9, 0.9, 0.8))
	Audio.play("hit", -12.0, 0.2, 1.3)


func _archer(delta: float) -> void:
	var m := _nearest(ARCHER_RANGE)
	if m == null:
		_wander(delta, 30.0, true)
		return
	velocity = Vector2.ZERO
	if _cd <= 0.0:
		_cd = _cooldown(1.4)
		var dmg := _atk()
		SiegeProjectile.shoot(get_parent(), global_position + Vector2(0, -16), m, "proj_arrow", 300.0, func(t: Node):
			if is_instance_valid(t) and t is Actor:
				(t as Actor).receive_hit(HitData.make_attack(self, dmg, 40.0))
				Fx.burst(t.get_parent(), (t as Node2D).global_position + Vector2(0, -8), "chip", 2, 25.0, 0.25, Vector2(0, 30), Color(0.9, 0.8, 0.6)))
		Fx.burst(get_parent(), global_position + Vector2(0, -16), "dust", 1, 10.0, 0.2, Vector2.ZERO, Color(1, 1, 0.9))
		Audio.play("swish", -12.0, 0.2, 1.6)


## 盾兵：岗位跟着受伤最重的城墙段走；嘲讽（lure）由导演的目标表处理，这里负责站位和顶回去。
func _shield(delta: float) -> void:
	_job_t -= delta
	if _job_t <= 0.0:
		_job_t = 3.0
		var worst: SiegeWall = null
		for w in director.walls:
			if worst == null or w.taken > worst.taken:
				worst = w
		if worst and worst.taken > 0.0:
			post = Vector2(clampf(worst.global_position.x + randf_range(-20, 20), worst.left_x() + 10, worst.right_x() - 10), director.wall_foot_y() + 24.0)
	var m := _nearest(30.0) as Actor
	if m and _cd <= 0.0:
		_cd = _cooldown(1.0)
		m.receive_hit(HitData.make_attack(self, 1, 200.0))
		Fx.burst(get_parent(), global_position + Vector2(0, -10), "chip", 5, 40.0, 0.3, Vector2(0, 30), Color(1, 0.9, 0.5))
	var to := post - global_position
	velocity = to.normalized() * SPEED if to.length() > 6.0 else Vector2.ZERO
	if randf() < delta * 0.6 and lure > 0.0:
		SiegeFx.ring(get_parent(), global_position + Vector2(0, -6), 12.0, Color(1, 0.85, 0.4, 0.5), 0.5, 0.04)


## 攻城车撞上盾兵：挡下一次（车停下重新瞄准），盾兵撤退。返回挡没挡住。
func block_cart(cart: Node2D) -> bool:
	if role != "shield" or retreating:
		return false
	Fx.burst(get_parent(), global_position + Vector2(0, -12), "chip", 14, 70.0, 0.5, Vector2(0, 60), Color(1, 0.9, 0.5))
	SiegeFx.ring(get_parent(), global_position + Vector2(0, -8), 10.0, Color(1, 0.9, 0.5, 0.9), 0.4, 0.2)
	SpeechBubble.say(self, "挡、挡住了——！", 26.0, 1.2)
	Audio.play("wall_crash", -6.0, 0.1, 1.4)
	apply_knockback(cart.global_position, 200.0)
	_retreat()
	return true


## 医护兵：跟着最需要的人（粉色公主闷笑高 / 受伤的士兵），每 MEDIC_GAP 秒给范围内的人治疗。
func _medic(delta: float) -> void:
	_job_t -= delta
	if _job_t <= 0.0:
		_job_t = 1.0
		_job = _patient()
	var target: Node2D = _job if _job != null and is_instance_valid(_job) else null
	var goal := target.global_position + Vector2(10, 6) if target else post
	var to := goal - global_position
	velocity = to.normalized() * SPEED * 1.1 if to.length() > 8.0 else Vector2.ZERO
	if _cd <= 0.0:
		_cd = _cooldown(MEDIC_GAP)
		var healed := false
		for c: PlayableCharacter in [director.pink, director.blue]:
			if c and is_instance_valid(c) and c.global_position.distance_to(global_position) < MEDIC_RANGE and c.laugh and c.laugh.value > 5.0:
				c.laugh.reduce_ratio(0.15)
				healed = true
		for s2 in director.soldiers:
			if is_instance_valid(s2) and s2 != self and not s2.retreating and s2.global_position.distance_to(global_position) < MEDIC_RANGE \
					and s2.health.hp < s2.health.max_hp:
				s2.health.heal(1)
				healed = true
		if healed:
			SiegeFx.ring(get_parent(), global_position + Vector2(0, -6), MEDIC_RANGE, Color(0.5, 1.0, 0.6, 0.6), 0.6, 0.05)
			Fx.burst(get_parent(), global_position + Vector2(0, -10), "heart", 6, 30.0, 0.6, Vector2(0, -20), Color(0.6, 1.0, 0.6))
			Audio.play("chime", -10.0, 0.1, 1.6)
		else:
			_cd = 0.5


func _patient() -> Node2D:
	var best: Node2D = null
	var best_need := 0.0
	var p: PlayableCharacter = director.pink
	if p and is_instance_valid(p) and p.laugh and not director.is_on_wall(p):
		best_need = p.laugh.value / p.laugh.max_value
		best = p
	for s2 in director.soldiers:
		if is_instance_valid(s2) and s2 != self and not s2.retreating and s2.role != "archer":
			var need := 1.0 - float(s2.health.hp) / float(s2.health.max_hp)
			if need > best_need:
				best_need = need
				best = s2
	return best if best_need > 0.15 else null


## 工匠：修城墙最破的一段 → 修受伤的冰塔 → 拆附近敌塔地基的搭建进度。
func _artisan(delta: float) -> void:
	_job_t -= delta
	if _job_t <= 0.0:
		_job_t = 2.0
		_job = _work()
	if _job == null or not is_instance_valid(_job):
		_wander(delta, 40.0)
		return
	var target := _job as Node2D
	var spot := target.global_position + Vector2(0, 14) if target is SiegeWall else target.global_position + Vector2(8, 6)
	if target is SiegeWall:
		spot = Vector2(clampf(global_position.x, (target as SiegeWall).left_x() + 8, (target as SiegeWall).right_x() - 8), director.wall_foot_y() + 14.0)
	var to := spot - global_position
	if to.length() > 8.0:
		velocity = to.normalized() * SPEED
		return
	velocity = Vector2.ZERO
	if target is SiegeWall:
		var w := target as SiegeWall
		var amt := REPAIR_RATE * delta / _town("ally_cd")
		w.taken = maxf(0.0, w.taken - amt)
		director.repair_wall(w, amt)
		w.queue_redraw()
	elif target is IceTower:
		var it := target as IceTower
		if it.health:
			_cd -= delta
			if _cd <= 0.0:
				_cd = _cooldown(1.0)
				it.health.heal(1)
	elif target is EnemySite:
		(target as EnemySite).build_progress = maxf(0.0, (target as EnemySite).build_progress - delta * 1.5)
	if randf() < delta * 6.0:
		Fx.burst(get_parent(), global_position + Vector2(6, -10), "spark", 2, 30.0, 0.3, Vector2(0, 50), Color(1, 0.85, 0.4))
	if randf() < delta * 2.0:
		Audio.play("hammer", -14.0, 0.2)


func _work() -> Node2D:
	var worst: SiegeWall = null
	for w in director.walls:
		if w.taken > 20.0 and (worst == null or w.taken > worst.taken):
			worst = w
	if worst:
		return worst
	for n in get_tree().get_nodes_in_group("siege_tower"):
		var it := n as IceTower
		if it and it.health and it.health.hp < it.health.max_hp and it.global_position.distance_to(global_position) < 500.0:
			return it
	for n in get_tree().get_nodes_in_group("siege_enemy_site"):
		var es := n as EnemySite
		if es and es.build_progress > 0.0 and es.builders.is_empty() and es.global_position.distance_to(global_position) < 360.0:
			return es
	return null


## 冰吟诵学徒：走到最近的等冰光的基座旁边（左右两个位置），站定后帮忙放冰光；基座造好 / 没人要了就回去。
func _mage(delta: float) -> void:
	if not can_build():
		_leave_build()
		velocity = Vector2.ZERO
		return
	var pad: BuildPad = null
	if is_instance_valid(_job) and _job is BuildPad:   # 先判断还在不在（释放了的对象不能用 is）
		pad = _job
	if pad and pad.pending.is_empty():
		pad.helper_leave(self)
		pad = null
		_job = null
	_job_t -= delta
	if pad == null and _job_t <= 0.0:
		_job_t = 0.8
		pad = _pick_pad()
		_job = pad
	if pad == null:
		_wander(delta, 30.0)
		return
	var slot := pad.reserve(self)
	if slot < 0:
		_job = null   # 人满了：换一座
		return
	var to := pad.helper_spot(slot) - global_position
	var helping := pad.helpers.has(self)
	# 到位才开始帮忙；已经在帮的被挤开一点不算走开（离开 MAGE_LEAVE 以上才停）
	if to.length() > (MAGE_LEAVE if helping else 6.0):
		if helping:
			pad.helpers.erase(self)
		velocity = to.normalized() * SPEED
		return
	velocity = to.normalized() * SPEED * 0.5 if to.length() > 3.0 else Vector2.ZERO
	facing = global_position.direction_to(pad.global_position)
	pad.helper_join(self)
	if randf() < delta * 4.0:
		Fx.burst(get_parent(), global_position + Vector2(0, -20), "crystal", 1, 10.0, 0.4, Vector2(0, -10), Color(0.7, 0.9, 1.0))


func can_build() -> bool:
	return is_alive() and is_physics_processing() and stat_mul("speed") > 0.0 and (status == null or not status.is_immobile())


func build_rate() -> float:
	return 1.0 if role == "builder" else BuildPad.HELPER_RATE


func _leave_build() -> void:
	if is_instance_valid(_job) and _job is BuildPad: _job.helper_leave(self)
	_job = null


func _exit_tree() -> void:
	_leave_build()


## 最近的、还有空位的等冰光的基座。
func _pick_pad() -> BuildPad:
	var best: BuildPad = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("siege_pad"):
		var p := n as BuildPad
		if p == null or p.is_queued_for_deletion() or p.helper_slots() <= 0:
			continue
		var dist := p.global_position.distance_to(global_position)
		if dist < best_d:
			best_d = dist
			best = p
	return best


func _wander(delta: float, r: float, horizontal := false) -> void:
	_wander_t -= delta
	if _wander_t <= 0.0 or global_position.distance_to(_wander_to) < 4.0:
		_wander_t = randf_range(2.0, 4.0)
		var off := Vector2(randf_range(-r, r), 0.0 if horizontal else randf_range(-r * 0.5, r * 0.5))
		_wander_to = post + off if randf() > 0.25 else global_position
	var to := _wander_to - global_position
	velocity = to.normalized() * SPEED * 0.5 if to.length() > 4.0 else Vector2.ZERO


# ------------------------------------------------------------------ 抬蓝色公主
func assign_carry(target: PlayableCharacter, partner: SiegeSoldier) -> void:
	carry_target = target
	carry_partner = partner
	_help = 0.0


func _drop_carry() -> void:
	if carry_target and is_instance_valid(carry_target):
		carry_target.set_meta("siege_carried", false)
	carry_target = null
	if carry_partner and is_instance_valid(carry_partner) and carry_partner.carry_target:
		carry_partner.carry_target = null
	carry_partner = null


func _carry_tick(delta: float) -> void:
	var b := carry_target
	if not is_instance_valid(b) or not Downed.is_downed(b):
		carry_target = null
		carry_partner = null
		velocity = Vector2.ZERO
		return
	# 倒在墙顶：弓箭手走过去扶，扶够 HELP_TIME 秒
	if director.is_on_wall(b):
		var to := b.global_position + Vector2(12, 0) - global_position
		if to.length() > 6.0:
			velocity = to.normalized() * SPEED
			return
		velocity = Vector2.ZERO
		_help += delta
		if int(_help * 2.0) % 2 == 0 and randf() < delta * 2.0:
			SpeechBubble.say(self, "公主殿下，撑住！", 26.0, 1.2)
		if _help >= HELP_TIME:
			director.revive_blue(b, "士兵扶起了蓝色的公主")
			carry_target = null
		return
	# 倒在墙下：两个长矛兵抬起来，走到梯子、抬上墙顶
	var carried: bool = b.get_meta("siege_carried", false)
	if not carried:
		var to2 := b.global_position - global_position
		if to2.length() > 10.0:
			velocity = to2.normalized() * SPEED * 1.3
			return
		velocity = Vector2.ZERO
		if carry_partner == null or not is_instance_valid(carry_partner) or carry_partner.global_position.distance_to(b.global_position) < 14.0:
			b.set_meta("siege_carried", true)
			SpeechBubble.say(self, "一、二——抬！", 26.0, 1.2)
		return
	# 抬着走：两个人里由「领头」的那个带路，另一个跟着
	if carry_partner and is_instance_valid(carry_partner) and carry_partner.get_instance_id() < get_instance_id():
		velocity = (carry_partner.global_position + Vector2(10, 0) - global_position) * 4.0
		return
	var lad: Node2D = director.nearest_ladder(global_position)
	if lad == null:
		return
	var bottom: Vector2 = lad.call("bottom_pos")
	var to3 := bottom - global_position
	b.global_position = global_position + Vector2(5, -8)
	if to3.length() > 6.0:
		velocity = to3.normalized() * SPEED * 0.8
		return
	velocity = Vector2.ZERO
	var top: Vector2 = lad.call("top_pos")
	carry_target = null
	var me_partner := carry_partner
	carry_partner = null
	b.set_meta("siege_carried", false)
	var tw := create_tween()
	tw.tween_property(b, "global_position", top, 1.4)
	tw.tween_callback(func():
		if is_instance_valid(director):
			director.revive_blue(b, "士兵把蓝色的公主抬上了城墙"))
	if me_partner and is_instance_valid(me_partner):
		me_partner.carry_target = null


func _animate() -> void:
	if sprite == null:
		return
	var moving := velocity.length() > 1.0
	var row := 0
	if absf(velocity.x) > absf(velocity.y):
		row = 1 if velocity.x < 0 else 2
	elif velocity.y < -1.0:
		row = 3
	sprite.frame = row * 4 + (int(_t * 6.0) % 4 if moving else 0)

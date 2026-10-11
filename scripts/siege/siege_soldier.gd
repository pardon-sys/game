class_name SiegeSoldier
extends Actor
## 攻防战的友军士兵（SiegeDirector 按城墙段生成；用镇民守卫的行走图 assets/generated/npcs/guard.png，32x32 × 4 帧 × 4 行）：
##   spear  长矛兵：墙下守自己那一段，打附近 SPEAR_RANGE 内的怪（近战、有击退）；没怪时在岗位附近巡逻。
##   archer 弓箭手：站在墙顶，往墙下 ARCHER_RANGE 内的怪射箭，也打爬上墙的怪；没怪时在墙顶小范围来回走。
## 怪物会挠士兵（他们是怪物的目标之一：SiegeDirector.extra_targets；血量 = 还能撑多久），被挠时头顶冒气泡；
## 撑不住了（血量到 RETREAT_HP 以下 / 归零）就跑回城门，RETURN_TIME 秒后满血回到岗位，不会真的倒下。
## 抬蓝色公主：SiegeDirector.call_bearers 叫两个长矛兵（她倒在墙下）/ 一个弓箭手（倒在墙顶）过去：
##   长矛兵把她抬到最近的梯子、抬上墙顶 → 她复活；弓箭手走到她身边扶 HELP_TIME 秒 → 她复活。

const SHEET := preload("res://assets/generated/npcs/guard.png")
const SPEED := 46.0
const SPEAR_RANGE := 70.0
const ARCHER_RANGE := 220.0
const RETREAT_HP := 1
const RETURN_TIME := 20.0
const HELP_TIME := 6.0
const LINES := ["哈哈别挠了！", "痒、痒——站住！", "哈哈哈……顶住！", "别挠胳肢窝……哈哈！"]

@export var role := "spear"

var post := Vector2.ZERO
var director: Node
var retreating := false
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


func _setup() -> void:
	set_faction(Faction.Type.ALLY)
	add_to_group("siege_soldier")
	add_to_group("siege_temp_keep")
	collision_layer = 2
	collision_mask = 1 if role == "spear" else 0
	var cs := CollisionShape2D.new()
	var r := CircleShape2D.new()
	r.radius = 5.0
	cs.shape = r
	add_child(cs)
	var hc := HealthComponent.new()
	hc.name = "Health"
	hc.max_hp = 8 if role == "spear" else 5
	add_child(hc)
	health = hc
	hc.fill()
	hc.died.connect(_die)
	sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = SHEET
	sprite.hframes = 4
	sprite.vframes = 4
	sprite.offset = Vector2(0, -14)
	if role == "archer":
		sprite.modulate = Color(0.85, 0.95, 1.0)
	add_child(sprite)
	hurt_invuln_time = 0.5
	post = global_position
	_wander_to = post


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
	_drop_carry()
	SpeechBubble.say(self, "撑、撑不住了……先撤！", 26.0, 1.4)
	var d: Node = director
	var gate: Vector2 = d.get("gate_pos") if d else post
	var tw := create_tween()
	_retreat_tw = tw
	tw.tween_property(self, "global_position", gate, maxf(0.4, global_position.distance_to(gate) / (SPEED * 1.6)))
	tw.tween_callback(func(): visible = false)
	tw.tween_interval(RETURN_TIME)
	tw.tween_callback(func():
		health.fill()
		global_position = post
		visible = true
		retreating = false
		SpeechBubble.say(self, "回来了！", 26.0, 1.0))


## 这一波失败重来：满血、回岗位、不再撤退。
func reset_post() -> void:
	if _retreat_tw and _retreat_tw.is_valid():
		_retreat_tw.kill()
	_drop_carry()
	retreating = false
	health.fill()
	global_position = post
	visible = true
	velocity = Vector2.ZERO


func _tick(delta: float) -> void:
	_t += delta
	_cd -= delta
	if retreating or director == null:
		velocity = Vector2.ZERO
		_animate()
		return
	if carry_target:
		_carry_tick(delta)
	else:
		match role:
			"spear": _spear(delta)
			_: _archer(delta)
	move_with_push()
	_animate()


func _nearest(r: float) -> Monster:
	var best: Monster = null
	var best_d := r
	for m in director.enemies_near(global_position, r, false):
		var dd := global_position.distance_to(m.global_position)
		if dd < best_d:
			best_d = dd
			best = m
	return best


func _spear(delta: float) -> void:
	var m := _nearest(SPEAR_RANGE)
	if m == null or global_position.distance_to(post) > SPEAR_RANGE * 1.6:
		_wander(delta, 40.0)
		return
	var to := m.global_position - global_position
	if to.length() > 14.0:
		velocity = to.normalized() * SPEED
	else:
		velocity = Vector2.ZERO
		if _cd <= 0.0:
			_cd = 0.8
			m.receive_hit(HitData.make_attack(self, 1, 120.0))
			Fx.burst(get_parent(), m.global_position + Vector2(0, -6), "chip", 3, 30.0, 0.3, Vector2(0, 40), Color(0.9, 0.9, 0.8))


func _archer(delta: float) -> void:
	var m := _nearest(ARCHER_RANGE)
	if m == null:
		_wander(delta, 30.0, true)
		return
	velocity = Vector2.ZERO
	if _cd <= 0.0:
		_cd = 1.4
		SiegeProjectile.shoot(get_parent(), global_position + Vector2(0, -16), m, "proj_arrow", 280.0, func(t: Node):
			if is_instance_valid(t) and t is Actor:
				(t as Actor).receive_hit(HitData.make_attack(self, 1, 40.0)))
		Audio.play("swish", -12.0, 0.2, 1.6)


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

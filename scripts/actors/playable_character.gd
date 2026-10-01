class_name PlayableCharacter
extends Actor
## 可操作角色基类：由 CharacterController 驱动（键盘 / 脚本 / AI）。
## 能力：8 方向移动、近战攻击、冲刺（全无敌）、与前方物体交互、使用背包物品。
## 闷笑值：GIGGLING 移动变慢并时不时发笑；HELPLESS 无法行动、持续大笑，连按攻击/交互键挣扎。
## 状态效果（Status 组件）：减速；被抓住（GRABBED）时不能行动，连按挣扎同时挣脱并降闷笑值。
## 魔法（星光爆发）：按住 magic 进入 CHANNEL 吟唱，不能移动；按住越久档位越高（channel_tiers），
##   松开释放 StarBurst。吟唱时弱点暴露：附近怪物锁定过来，受到的挠痒 ×exposed_tickle_mult。
##   闷笑值超过失控线不能开始；吟唱中进入失控、被抓住、受到攻击都会打断。
##   释放（1 档及以上）后进入 CAST，原地定住 cast_time 秒播放释放动作（受到攻击 / 被抓 / 失控会中断）。
##
## 约定的子节点（除 Actor 的之外）：
##   Controller (CharacterController)  Emotion (EmotionComponent)  Animator (SpriteSheetAnimator)
##   Hitbox (HitboxComponent)  InteractArea (Area2D)  Slash (Sprite2D)  Prompt (Sprite2D)  Camera (Camera2D)
##
## 子类可重写：_on_damaged / _on_tickled / _on_laugh_level_changed / _on_laugh_overflow / _on_died / _on_respawned

signal giggled
signal state_changed(state: State)
## 魔法事件："channel" 开始吟唱、"tier" 升档、"burst" 释放、"fizzle" 蓄力不足落空、"interrupted" 被打断。
signal magic_event(event: String, tier: int)

enum State { IDLE, MOVE, ATTACK, DASH, HURT, HELPLESS, GRABBED, DEAD, CHANNEL, CAST }

@export_group("移动")
@export var move_speed := 80.0
@export var accel := 900.0
@export var friction := 1100.0
@export_group("冲刺")
@export var dash_speed := 240.0
@export var dash_time := 0.17
@export var dash_invuln := 0.3
@export var dash_cooldown := 0.55
@export_group("攻击")
@export var attack_time := 0.3
@export var attack_active_from := 0.05
@export var attack_active_to := 0.2
@export var hurt_time := 0.25
@export_group("闷笑表现")
## GIGGLING 时两次笑声的随机间隔（秒）。
@export var giggle_interval := Vector2(1.0, 2.5)
## HELPLESS 时笑声间隔（秒）。
@export var helpless_laugh_interval := 0.6
@export_group("魔法")
## 学会魔法的剧情标记（空 = 一开始就会）。
@export var magic_flag := "magic_unlocked"
## 升到 1/2/3 档所需的吟唱时间；到最后一档自动释放。
@export var channel_tiers := PackedFloat32Array([0.6, 1.2, 2.0])
@export var magic_cooldown := 6.0
## 落空或被打断后的短冷却。
@export var fizzle_cooldown := 1.5
## 吟唱时吸引怪物的半径。
@export var expose_radius := 180.0
## 吟唱时受到的挠痒倍率（弱点暴露）。
@export var exposed_tickle_mult := 1.5
## 释放后原地定住、播放释放动作的时间。
@export var cast_time := 0.5
@export_group("")
@export var respawn_delay := 1.25
## 挣脱抓取后的全无敌时间。
@export var grab_escape_invuln := 0.6

@onready var controller: CharacterController = get_node_or_null("Controller")
@onready var emotion: EmotionComponent = get_node_or_null("Emotion")
@onready var animator: SpriteSheetAnimator = get_node_or_null("Animator")
@onready var hitbox: HitboxComponent = get_node_or_null("Hitbox")
@onready var interact_area: Area2D = get_node_or_null("InteractArea")
@onready var slash: Sprite2D = get_node_or_null("Slash")
@onready var prompt: Sprite2D = get_node_or_null("Prompt")
@onready var camera: Camera2D = get_node_or_null("Camera")
@onready var combo: ComboTracker = get_node_or_null("Combo")
@onready var fatigue: MagicFatigue = get_node_or_null("Fatigue")
## 正在进行疲倦爆发（CAST 期间用战损释放姿势）。
var fatigue_bursting := false

var state := State.IDLE
var _state_time := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector2.DOWN
var _ghost_time := 0.0
var _step_time := 0.0
var _shake := 0.0
var _laugh_timer := 0.0
var _target: Interactable = null
var _channel_time := 0.0
var _channel_tier := 0
var _magic_cd := 0.0
var _magic_fx: MagicCircle
var _chant: AudioStreamPlayer


func _setup() -> void:
	if fatigue:
		fatigue.full.connect(fatigue_burst)
	if controller == null:
		set_controller(PlayerInputController.new())
	if faction == Faction.Type.PLAYER:
		GameState.register_player(self)
		if GameState.checkpoint == Vector2.ZERO:
			GameState.checkpoint = global_position
	if laugh:
		laugh.level_changed.connect(_on_laugh_level_changed)
	if health:
		health.changed.connect(func(_hp: int, _max: int): _refresh_emotion())
	if slash:
		slash.hide()
	if prompt:
		prompt.hide()


## 更换输入来源（Controllable 接口）。
func set_controller(c: CharacterController) -> void:
	if controller and controller != c:
		controller.queue_free()
	c.name = "Controller"
	if c.get_parent() == null:
		add_child(c)
	controller = c


func _tick(delta: float) -> void:
	_state_time += delta
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_magic_cd = maxf(_magic_cd - delta, 0.0)
	var can_control := not GameState.in_dialogue and state != State.DEAD
	var input := controller.get_move_vector() if can_control else Vector2.ZERO
	if stat_add("invert_controls") > 0.0:
		input = -input  # 晕头转向：方向颠倒
	_update_lift(delta)
	_update_focus()
	if _forced_time > 0.0 and state not in [State.IDLE, State.MOVE]:
		end_forced_move()  # 被抓住 / 笑到失控等打断了强制位移
	if status and status.is_grabbed() and state not in [State.GRABBED, State.DEAD]:
		interrupt_channel()
		_end_attack()
		_set_state(State.GRABBED)
	elif laugh and laugh.is_helpless() and state in [State.IDLE, State.MOVE, State.ATTACK, State.CHANNEL, State.CAST]:
		interrupt_channel()
		_enter_helpless()

	match state:
		State.IDLE, State.MOVE:
			if is_force_moving():
				_tick_forced(delta)
			else:
				var speed := move_speed * (laugh.speed_multiplier() if laugh else 1.0) \
						* (status.speed_multiplier() if status else 1.0) * stat_mul("speed")
				var rooted := status != null and status.is_rooted()
				if rooted:
					# 定身：原地挣动，只能转向和攻击
					if input != Vector2.ZERO:
						facing = input.normalized()
					velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
					_set_state(State.IDLE)
				elif input != Vector2.ZERO:
					facing = input.normalized()
					velocity = velocity.move_toward(input.limit_length(1.0) * speed, accel * delta)
					_set_state(State.MOVE)
					_footsteps(delta)
				else:
					velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
					_set_state(State.IDLE)
				if can_control:
					if controller.is_action_just_pressed(&"attack"):
						attack()
					elif controller.is_action_just_pressed(&"dash") and not rooted:
						dash(input)
					elif controller.is_action_just_pressed(&"magic"):
						begin_channel()
					elif controller.is_action_just_pressed(&"interact"):
						interact()
					elif controller.is_action_just_pressed(&"use_item"):
						use_item()
					elif controller.is_action_just_pressed(&"use_special"):
						use_item("use_special")
		State.ATTACK:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			if hitbox and _state_time >= attack_active_from and _state_time <= attack_active_to:
				hitbox.scan()
			if slash:
				slash.frame = clampi(int(_state_time / attack_time * 4.0), 0, 3)
			if _state_time >= attack_time:
				_end_attack()
		State.DASH:
			velocity = _dash_dir * dash_speed
			_ghost_time -= delta
			if _ghost_time <= 0.0:
				_ghost_time = 0.035
				_spawn_ghost()
			if _state_time >= dash_time:
				velocity *= 0.35
				_set_state(State.IDLE)
		State.HURT:
			velocity = velocity.move_toward(Vector2.ZERO, friction * 0.6 * delta)
			if _state_time >= hurt_time:
				_set_state(State.IDLE)
		State.HELPLESS:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			if can_control and (controller.is_action_just_pressed(&"attack") or controller.is_action_just_pressed(&"interact")):
				struggle()
			if not (laugh and laugh.is_helpless()):
				_set_state(State.IDLE)
		State.GRABBED:
			velocity = Vector2.ZERO
			if can_control and (controller.is_action_just_pressed(&"attack") or controller.is_action_just_pressed(&"interact")):
				struggle()
			if not status.is_grabbed():
				set_invulnerable(grab_escape_invuln, true)
				_set_state(State.HELPLESS if laugh and laugh.is_helpless() else State.IDLE)
		State.CHANNEL:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			if not GameState.in_dialogue:
				_channel_time += delta
				var tier := channel_tier_for(_channel_time)
				if tier != _channel_tier:
					_channel_tier = tier
					_on_channel_tier(tier)
				if animator:
					animator.progress = _channel_time / channel_tiers[channel_tiers.size() - 1]
				if _channel_time >= channel_tiers[channel_tiers.size() - 1] or not controller.is_action_pressed(&"magic"):
					release_magic()
		State.CAST:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			if _state_time >= cast_time:
				fatigue_bursting = false
				_set_state(State.IDLE)
		State.DEAD:
			velocity = Vector2.ZERO

	move_with_push()
	if forced_kind == "slide" and _forced_time > 0.0 and get_slide_collision_count() > 0:
		end_forced_move()  # 滑到墙边停下
	_update_laughing(delta)
	_update_interact_target()
	_update_animation(delta)
	_update_effects(delta)
	controller.end_frame()


# ------------------------------------------------------------------ 动作（公开，AI/测试也可直接调用）
func can_act() -> bool:
	return state in [State.IDLE, State.MOVE]


func attack() -> void:
	if not can_act():
		return
	_set_state(State.ATTACK)
	var d := dir4()
	if hitbox:
		hitbox.position = Vector2(0, -8) + d * 13.0
		hitbox.begin()
	if slash:
		slash.rotation = d.angle()
		slash.frame = 0
		slash.show()
	Audio.play("swing", -4.0)


func dash(input := Vector2.ZERO) -> void:
	if not can_act() or _dash_cd > 0.0 or (status and status.is_rooted()):
		return
	_dash_dir = input.normalized() if input != Vector2.ZERO else facing
	_dash_cd = dash_cooldown
	set_invulnerable(dash_invuln, true)
	_ghost_time = 0.0
	_set_state(State.DASH)
	Audio.play("dash", -6.0)


func interact() -> void:
	if can_act() and _target and _target.enabled:
		_target.interact(self)


## 使用背包里第一个可用的消耗品（目前是薄荷糖）。
func use_item(hotkey := "use_item") -> bool:
	if state == State.DEAD:
		return false
	var used := GameState.inventory.use_hotkey(self, hotkey)
	if not used:
		Audio.play("locked", -8.0)
	return used


## 笑瘫 / 被抓时挣扎一次：降闷笑值，被抓时同时计入挣脱次数。
func struggle() -> void:
	if laugh:
		laugh.struggle()
	if status and status.is_grabbed():
		status.struggle()
	_shake = maxf(_shake, 0.05)
	if sprite:
		sprite.position.x = [-1.0, 1.0].pick_random()


func shake(duration: float) -> void:
	_shake = maxf(_shake, duration)


func is_helpless() -> bool:
	return state == State.HELPLESS


# ------------------------------------------------------------------ 魔法
func is_magic_unlocked() -> bool:
	return magic_flag == "" or GameState.has_flag(magic_flag)


func is_channeling() -> bool:
	return state == State.CHANNEL


## 星光糖：魔法冷却立即清零。
func reset_magic_cooldown() -> void:
	_magic_cd = 0.0


func magic_cooldown_left() -> float:
	return _magic_cd


## 能否开始吟唱：已学会、不在冷却、能正常行动、闷笑值没到失控线。
func can_cast() -> bool:
	return is_magic_unlocked() and _magic_cd <= 0.0 and can_act() and not (laugh and laugh.is_helpless()) \
			and stat_flag("can_channel")


func channel_tier_for(t: float) -> int:
	var tier := 0
	for i in channel_tiers.size():
		if t + 0.0001 >= channel_tiers[i]:
			tier = i + 1
	return tier


func channel_time() -> float:
	return _channel_time if state == State.CHANNEL else 0.0


func begin_channel() -> bool:
	if not can_cast():
		if is_magic_unlocked() and can_act():
			Audio.play("locked", -8.0)
		return false
	_channel_time = 0.0
	_channel_tier = 0
	_set_state(State.CHANNEL)
	if _magic_fx == null:
		_magic_fx = MagicCircle.new()
		add_child(_magic_fx)
	_magic_fx.set_stage(0)
	_magic_fx.show()
	if _chant == null:
		_chant = AudioStreamPlayer.new()
		_chant.stream = Audio.loop_stream("chant")
		_chant.volume_db = -10.0
		add_child(_chant)
	_chant.pitch_scale = 0.85
	_chant.play()
	magic_event.emit("channel", 0)
	return true


## 松开：按当前档位释放；不到 1 档算落空。返回释放的档位（0 = 落空）。
func release_magic() -> int:
	if state != State.CHANNEL:
		return 0
	var tier := _channel_tier
	_end_channel()
	if tier <= 0:
		_magic_cd = fizzle_cooldown
		Audio.play("fizzle", -4.0)
		magic_event.emit("fizzle", 0)
		return 0
	StarBurst.cast(self, tier)
	_magic_cd = magic_cooldown
	shake(0.06 * tier)
	_set_state(State.CAST)
	magic_event.emit("burst", tier)
	return tier


func is_casting() -> bool:
	return state == State.CAST


## 吟唱被打断（失控、被抓、受到攻击）。不在吟唱时什么也不做。
func interrupt_channel() -> void:
	if state != State.CHANNEL:
		return
	_end_channel()
	_magic_cd = fizzle_cooldown
	Audio.play("fizzle", -4.0)
	magic_event.emit("interrupted", 0)


func _end_channel() -> void:
	if _magic_fx:
		_magic_fx.hide()
	if _chant:
		_chant.stop()
	_channel_time = 0.0
	_channel_tier = 0
	if state == State.CHANNEL:
		_set_state(State.IDLE)


func _on_channel_tier(tier: int) -> void:
	if _magic_fx:
		_magic_fx.set_stage(tier)
	if _chant:
		_chant.pitch_scale = 0.85 + tier * 0.15
	Audio.play("chime", -8.0, 0.02, 0.8 + tier * 0.2)
	magic_event.emit("tier", tier)


## 受到的挠痒倍率：状态（易痒、增益减益）× 吟唱时弱点暴露 × 魔力疲倦加成。
func _tickle_multiplier(hit: HitData) -> float:
	var k := super(hit) * (exposed_tickle_mult if state == State.CHANNEL else 1.0)
	k *= 1.0 + (fatigue.laugh_bonus() if fatigue else 0.0)
	return k * (combo.hit_multiplier(hit) if combo else 1.0)


func is_grabbed() -> bool:
	return state == State.GRABBED


## 动不了：被抓、定身、吟唱、失控（挠脚鼠此时挠痒加倍）。
func is_immobile() -> bool:
	return state in [State.GRABBED, State.HELPLESS, State.CHANNEL, State.CAST] or (status != null and status.is_immobile())


# ------------------------------------------------------------------ Actor 钩子
func _on_damaged(_hit: HitData) -> void:
	Audio.play("hurt")
	shake(0.18)
	interrupt_channel()
	_end_attack()
	if state not in [State.HELPLESS, State.GRABBED]:
		_set_state(State.HURT)


func _on_tickled(hit: HitData) -> void:
	shake(0.04)
	if fatigue:
		fatigue.from_tickle(hit)


func _on_laugh_level_changed(level: LaughMeter.Level) -> void:
	_laugh_timer = 0.0 if level == LaughMeter.Level.HELPLESS else randf_range(0.3, 0.8)
	_refresh_emotion()


func _on_laugh_overflow() -> void:
	super()
	shake(0.2)


func _on_died() -> void:
	Audio.set_voice_state("")
	_end_channel()
	_set_state(State.DEAD)
	_end_attack()
	if _play_death_cutscene():
		return
	var tw := create_tween()
	tw.tween_interval(respawn_delay)
	if sprite:
		tw.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tw.tween_callback(respawn)


## 在检查点复活。
func respawn() -> void:
	global_position = GameState.checkpoint
	if sprite:
		sprite.modulate.a = 1.0
	velocity = Vector2.ZERO
	facing = Vector2.DOWN
	revive()
	set_invulnerable(1.5, true)
	_set_state(State.IDLE)
	if camera:
		if _focus_base != Vector2.ZERO:
			camera.zoom = _focus_base
			_focus_base = Vector2.ZERO
		camera.reset_smoothing()
	_on_respawned()


func _on_respawned() -> void:
	pass


# ------------------------------------------------------------------ 魔力疲倦爆发
## 魔力疲倦满 500：原地自动爆发（满蓄力档一半伤害，战损释放姿势定住 cast_time），
## 留下疲倦水液，疲倦清零，获得一层永久的「疲倦印记」（闷笑积累 +1%）。被抓着会被炸开。
func fatigue_burst() -> void:
	if not is_alive() or fatigue == null:
		return
	fatigue.clear()
	if status and status.is_grabbed():
		status.release(true)
	interrupt_channel()
	_end_attack()
	fatigue_bursting = true
	_set_state(State.CAST)
	StarBurst.cast_fatigue(self)
	FatiguePuddle.spawn(get_parent(), global_position)
	add_buff("fatigue_scar", -1.0)
	shake(0.3)
	# 魔力反噬：爆发时身边有怪物（在爆发台词之前触发，让公主最后说的是爆发台词）
	if combo and not combo.monsters_near(StarBurst.FATIGUE["radius"] + 24.0).is_empty():
		combo.trigger("mana_backlash", self)
	magic_event.emit("fatigue_burst", 0)


## 子类钩子：死亡时要播过场就返回 true（由子类负责之后调用 respawn）。
func _play_death_cutscene() -> bool:
	return false


# ------------------------------------------------------------------ 组合技表现：抬起、镜头聚焦
var _lift_t := 0.0
## 强制位移（弹弹床 bounce / 滑溜肥皂地板 slide）：期间不能操作、不能冲刺。
var forced_kind := ""
var _forced_vel := Vector2.ZERO
var _forced_time := 0.0
var _forced_total := 0.0
## 弹飞时小人抬高的最大像素。
const BOUNCE_HEIGHT := 12.0
var _focus_base := Vector2.ZERO
var _focus_since := 0.0


## 抬起：被举在半空（buff lifted），小人上浮晃动。
func _update_lift(delta: float) -> void:
	if sprite == null:
		return
	if has_buff("lifted"):
		_lift_t += delta
		sprite.position.y = -6.0 + roundf(sin(_lift_t * 7.0) * 1.5)
	elif sprite.position.y != 0.0:
		_lift_t = 0.0
		sprite.position.y = 0.0


## 镜头聚焦（三来源组合）：放大对准自己；停止被挠 1 秒后还原。
func focus_camera(mult := 1.5) -> void:
	if camera == null:
		return
	if _focus_base == Vector2.ZERO:
		_focus_base = camera.zoom
	_focus_since = Time.get_ticks_msec() / 1000.0
	var tw := camera.create_tween()
	tw.tween_property(camera, "zoom", _focus_base * mult, 0.25)


func is_camera_focused() -> bool:
	return _focus_base != Vector2.ZERO


func _update_focus() -> void:
	if _focus_base == Vector2.ZERO or camera == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - maxf(last_tickle_time, _focus_since) >= 1.0:
		var base := _focus_base
		_focus_base = Vector2.ZERO
		camera.create_tween().tween_property(camera, "zoom", base, 0.4)


# ------------------------------------------------------------------ 内部
# ------------------------------------------------------------------ 强制位移
## 开始强制位移：time 秒内按 v 移动。kind = "bounce"（弹在空中：脚下陷阱不生效）/ "slide"（滑行：撞墙停）。
## 被抓住、失控、倒下时不能开始；吟唱、攻击会被打断。
func force_move(v: Vector2, time: float, kind: String) -> bool:
	if state in [State.GRABBED, State.HELPLESS, State.DEAD] or (status and status.is_grabbed()):
		return false
	interrupt_channel()
	_end_attack()
	if state not in [State.IDLE, State.MOVE]:
		_set_state(State.IDLE)
	forced_kind = kind
	_forced_vel = v
	_forced_time = time
	_forced_total = time
	if v != Vector2.ZERO:
		facing = v.normalized()
	return true


## 延长当前的强制位移（滑行时每帧续上）。
func extend_forced_move(time: float) -> void:
	_forced_time = maxf(_forced_time, time)


func end_forced_move() -> void:
	if _forced_time <= 0.0 and forced_kind == "":
		return
	var was := forced_kind
	_forced_time = 0.0
	forced_kind = ""
	velocity = _forced_vel * 0.15 if was == "bounce" else Vector2.ZERO
	_forced_vel = Vector2.ZERO
	if sprite and not has_buff("lifted"):
		sprite.position.y = 0.0
	if was == "bounce" and is_inside_tree():
		Fx.burst(get_parent(), global_position, "dust", 6, 30.0, 0.35)
		Audio.play("step", -4.0, 0.1, 0.8)


func is_force_moving() -> bool:
	return _forced_time > 0.0 and state in [State.IDLE, State.MOVE]


func forced_velocity() -> Vector2:
	return _forced_vel if is_force_moving() else Vector2.ZERO


## 被弹弹床弹在空中（脚下的陷阱不生效）。
func is_airborne() -> bool:
	return is_force_moving() and forced_kind == "bounce"


func is_dashing() -> bool:
	return state == State.DASH


func _tick_forced(delta: float) -> void:
	_forced_time -= delta
	velocity = _forced_vel
	_set_state(State.MOVE if forced_kind == "slide" else State.IDLE)
	if forced_kind == "bounce" and sprite:
		var k := clampf(1.0 - _forced_time / maxf(_forced_total, 0.001), 0.0, 1.0)
		sprite.position.y = -roundf(sin(PI * k) * BOUNCE_HEIGHT)
	if (status and (status.is_grabbed() or status.is_rooted())) or _forced_time <= 0.0:
		end_forced_move()


func _set_state(s: State) -> void:
	if s != state:
		state = s
		_state_time = 0.0
		state_changed.emit(s)


func _enter_helpless() -> void:
	_end_attack()
	_set_state(State.HELPLESS)


func _end_attack() -> void:
	if slash:
		slash.hide()
	if state == State.ATTACK:
		_set_state(State.IDLE)


func _refresh_emotion() -> void:
	if emotion:
		emotion.refresh()


## 闷笑时的笑声节奏（音效 + 气泡）。
func _update_laughing(delta: float) -> void:
	if laugh == null or not laugh.is_giggling() or state == State.DEAD:
		return
	_laugh_timer -= delta
	if _laugh_timer > 0.0:
		return
	if laugh.is_helpless():
		_laugh_timer = helpless_laugh_interval
		Audio.play("laugh")
	else:
		_laugh_timer = randf_range(giggle_interval.x, giggle_interval.y)
		Audio.play("giggle")
	if emotion:
		emotion.show_bubble("laugh")
	giggled.emit()


func _update_interact_target() -> void:
	if interact_area == null:
		return
	interact_area.position = Vector2(0, -5) + dir4() * 9.0
	var best: Interactable = null
	var best_d := INF
	if can_act() and not GameState.in_dialogue:
		for a in interact_area.get_overlapping_areas():
			var it := a as Interactable
			if it and it.enabled:
				var d := it.global_position.distance_squared_to(interact_area.global_position)
				if d < best_d:
					best_d = d
					best = it
	_target = best
	if prompt == null:
		return
	if best:
		prompt.show()
		prompt.global_position = best.global_position + best.prompt_offset + Vector2(0, sin(Time.get_ticks_msec() / 150.0) * 1.5).round()
	else:
		prompt.hide()


func _anim_name() -> String:
	if state == State.IDLE and status and status.is_rooted():
		return "grabbed"
	match state:
		State.MOVE:
			return "giggle" if laugh and laugh.is_giggling() else "walk"
		State.ATTACK: return "attack"
		State.DASH: return "dash"
		State.HURT: return "hurt"
		State.HELPLESS: return "helpless"
		State.GRABBED: return "grabbed"
		State.DEAD: return "faint"
		State.CHANNEL: return "channel"
		State.CAST: return "cast"
	return "idle"


func _update_animation(delta: float) -> void:
	if animator == null:
		return
	animator.play(_anim_name())
	animator.update(delta, dir_name(), facing.x < 0, emotion.row() if emotion else 0)


func _update_effects(delta: float) -> void:
	if sprite:
		# 受攻击无敌时闪烁（冲刺无敌不闪）
		if _attack_invuln > 0.0 and state not in [State.DASH, State.DEAD, State.GRABBED]:
			sprite.visible = int(_attack_invuln * 20.0) % 2 == 0
		else:
			sprite.visible = true
	if camera:
		if _shake > 0.0:
			_shake -= delta
			camera.offset = Vector2(randf_range(-2, 2), randf_range(-2, 2)).round()
		else:
			camera.offset = Vector2.ZERO


func _footsteps(delta: float) -> void:
	_step_time -= delta
	if _step_time <= 0.0:
		_step_time = 0.32
		Audio.play("step", -16.0, 0.15)


func _spawn_ghost() -> void:
	if sprite == null:
		return
	var g := Sprite2D.new()
	g.texture = sprite.texture
	g.hframes = sprite.hframes
	g.vframes = sprite.vframes
	g.frame = sprite.frame
	g.flip_h = sprite.flip_h
	g.offset = sprite.offset
	g.modulate = Color(1.0, 0.55, 0.85, 0.55)
	get_parent().add_child(g)
	g.global_position = global_position
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.25)
	tw.tween_callback(g.queue_free)

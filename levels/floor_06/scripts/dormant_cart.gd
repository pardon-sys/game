class_name DormantCart
extends Node2D
## 城门外战场上哑火的攻城车（弥补任务「拆除哑火的攻城车」）：睡着（头上冒 Zzz），车灯（VisionCone）朝前方左右来回扫。
##   粉色公主被车灯照到（连续 SEE_TIME 秒）或者在 NOISE_R 以内冲刺 → 惊醒（woke 信号，TaskCart 处理：捞进车斗挠）。
##   绕到车尾（REAR_R 以内）按住 E：拆车轴进度 +1/秒，DISMANTLE 秒拆完（dismantled 信号）；离开 / 松手进度慢慢掉。
##   蓝色公主冻住车轮（freeze(秒)）：冻着的时候车灯不扫、不会醒。
## 难度：sweep（扫的角度）、speed（扫的速度）、range（车灯远近）按第几辆车递增。

signal woke(cart: DormantCart)
signal dismantled(cart: DormantCart)

const TEX := preload("res://assets/generated/siege/monsters.png")
const REGION := Rect2(0, 176, 32, 26)
## 被照到累计多久就醒（离开光里慢慢退：扫过去又扫回来照到两三次也会醒）
const SEE_TIME := 0.4
const SEE_DECAY := 0.25
const NOISE_R := 90.0
const REAR_R := 16.0
const DISMANTLE := 3.0

## 第几辆（任务里按它排：0 最简单）
@export var index := 0
## 车头朝向（图例 dir=down / up / left / right）
@export var dir := "down"
var front := Vector2.DOWN
@export var sweep := 45.0
@export var speed := 1.0
@export var range_px := 96.0

var done := false
var awake := false
var progress := 0.0
var frozen_t := 0.0
var _t := 0.0
var _seen_t := 0.0
var _spr: Sprite2D
var cone: VisionCone


func _ready() -> void:
	front = Trap.dir_vector(dir)
	add_to_group("dormant_cart")
	_spr = Sprite2D.new()
	_spr.texture = TEX
	_spr.region_enabled = true
	_spr.region_rect = REGION
	_spr.offset = Vector2(0, -13)
	_spr.flip_h = front.x < 0.0
	add_child(_spr)
	cone = VisionCone.new()
	cone.range_px = range_px
	cone.angle_deg = 46.0
	cone.dark_radius = 99999.0
	cone.position = Vector2(0, -8)
	add_child(cone)
	var body := StaticBody2D.new()
	var sh := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 10)
	sh.shape = rect
	sh.position = Vector2(0, -5)
	body.add_child(sh)
	add_child(body)


func rear_point() -> Vector2:
	return global_position - front.normalized() * 22.0


func freeze(sec: float) -> void:
	frozen_t = maxf(frozen_t, sec)


func is_frozen() -> bool:
	return frozen_t > 0.0


func reset_sleep() -> void:
	awake = false
	_seen_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	frozen_t = maxf(0.0, frozen_t - delta)
	queue_redraw()
	if done:
		cone.visible = false
		return
	cone.visible = not is_frozen()
	_spr.modulate = Color(0.75, 0.9, 1.2) if is_frozen() else Color.WHITE
	if not is_frozen():
		cone.facing = front.normalized().rotated(deg_to_rad(sweep) * sin(_t * speed))
	var p := GameState.player
	if awake or not is_instance_valid(p) or GameState.in_dialogue or GameState.in_cutscene:
		return
	# 拆车轴（只有粉色公主会拆）
	var at_rear := p.character_id == "pink" and p.global_position.distance_to(rear_point()) <= REAR_R
	if at_rear and Input.is_action_pressed("interact"):
		progress += delta
		if progress >= DISMANTLE:
			_finish()
			return
	else:
		progress = maxf(0.0, progress - delta * 0.5)
	if is_frozen() or p.character_id != "pink":
		cone.alerting = false
		return
	var seen := cone.sees(p) > 0.0
	_seen_t = _seen_t + delta if seen else maxf(0.0, _seen_t - delta * SEE_DECAY)
	cone.alerting = _seen_t > 0.0
	var noisy := p.is_dashing() and p.global_position.distance_to(global_position) <= NOISE_R
	if _seen_t >= SEE_TIME or noisy:
		awake = true
		woke.emit(self)


func _finish() -> void:
	done = true
	progress = DISMANTLE
	Audio.play("wall_crash", -6.0, 0.05, 1.4)
	Fx.burst(get_parent(), global_position + Vector2(0, -10), "dust", 12, 50.0, 0.6, Vector2(0, 30))
	_spr.rotation = 0.25
	_spr.modulate = Color(0.6, 0.55, 0.55)
	dismantled.emit(self)


## 拆车轴的进度（给测试 / 外面直接推）
func add_progress(sec: float) -> void:
	if done:
		return
	progress += sec
	if progress >= DISMANTLE:
		_finish()


func _draw() -> void:
	if done:
		return
	if not awake and not is_frozen():
		var y := -30.0 - fmod(_t * 6.0, 10.0)
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(8, y), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.85, 0.9, 1.0, 1.0 - fmod(_t * 0.6, 1.0)))
		draw_string(f, Vector2(13, y - 6), "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.9, 1.0, 1.0 - fmod(_t * 0.6 + 0.4, 1.0)))
	if is_frozen():
		draw_arc(Vector2(0, -8), 16.0, 0, TAU, 20, Color(0.7, 0.9, 1.0, 0.6), 2.0)
	# 车尾：拆车轴的位置 + 进度条
	var rear := to_local(rear_point())
	draw_arc(rear, 6.0, 0, TAU, 12, Color(1, 0.86, 0.4, 0.5 + 0.3 * sin(_t * 4.0)), 1.0)
	if progress > 0.0:
		draw_rect(Rect2(-12, -34, 24, 3), Color(0.15, 0.1, 0.15))
		draw_rect(Rect2(-12, -34, 24.0 * progress / DISMANTLE, 3), Color(1, 0.86, 0.4))

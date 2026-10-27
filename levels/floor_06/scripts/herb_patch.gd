class_name HerbPatch
extends Node2D
## 草药洞里的一丛药草（骑士篇支线「手印样本」·旧药方）。三种，踩上去 / 摘的时候各有各的痒法（光着脚才摘得了）：
##   bell 笑铃草：碰一下就叮铃铃响，铃铛花在脚心上打转——踩上去闷笑 +STEP_LAUGH，摘的时候每秒 +PICK_LAUGH。
##   moss 软须苔：缠住脚趾、须子钻进趾缝——踩上去定身 STICK 秒、闷笑 +STEP_LAUGH；摘的时候一直缠着（定身）。
##   yawn 哈欠花：「噗」地喷一团粉，让人打哈欠——开始摘的时候喷粉：打哈欠 YAWN 秒动不了（这时候手印会扑上来）。
##   picked：摘过了（剩一截草根，不再有效果）。
## 测试：kind、picked、step(角色)、pick_tick(角色, delta)、take()。

signal yawned(who: PlayableCharacter)

const R := 10.0
const STEP_LAUGH := 0.05
const PICK_LAUGH := 0.12
const STICK := 0.9
const YAWN := 1.4
const STEP_COOL := 2.0

var kind := "bell"
var picked := false
var _cool := 0.0
var _t := 0.0
var _puffed := false


func _ready() -> void:
	z_index = 0
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat


func inside(c: Node2D) -> bool:
	return is_instance_valid(c) and c.global_position.distance_to(global_position) <= R


## 踩上去（任务每帧对操控的角色问一次；有冷却）
func step(c: PlayableCharacter, delta: float) -> String:
	_cool = maxf(0.0, _cool - delta)
	if picked or _cool > 0.0 or not inside(c):
		return ""
	_cool = STEP_COOL
	match kind:
		"bell":
			_tickle(c, STEP_LAUGH)
			Audio.play("bell_jingle", -10.0, 0.1)
		"moss":
			_tickle(c, STEP_LAUGH)
			if c.status:
				c.status.apply_root(STICK)
		"yawn":
			_puff(c)
	return kind


## 摘的时候每帧（按住 E）：笑铃草一直挠、软须苔一直缠、哈欠花开始摘时喷一次粉
func pick_tick(c: PlayableCharacter, delta: float) -> void:
	match kind:
		"bell":
			_tickle(c, PICK_LAUGH * delta, false)
		"moss":
			_tickle(c, PICK_LAUGH * 0.8 * delta, false)
			if c.status and not c.status.is_rooted():
				c.status.apply_root(0.3)
		"yawn":
			if not _puffed:
				_puffed = true
				_puff(c)


## 摘下来
func take() -> void:
	picked = true
	_puffed = false
	Audio.play("pickup", -6.0)
	queue_redraw()


func _tickle(c: PlayableCharacter, amount: float, fx := true) -> void:
	if c.laugh:
		c.laugh.add(c.laugh.max_value * amount)
	if fx or randf() < 0.05:
		ZoneFx.play("sole", c.get_parent(), ZoneFx.body_point(c, "sole"), 0.7, false)


func _puff(c: PlayableCharacter) -> void:
	Fx.burst(get_parent(), global_position + Vector2(0, -6), "dust", 10, 30.0, 0.8, Vector2(0, -15), Color(1.0, 0.9, 0.55))
	if c.status:
		c.status.apply_root(YAWN)
	GameState.emote("dots", YAWN, true)
	yawned.emit(c)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if picked:
		draw_line(Vector2(-2, 0), Vector2(-1, -3), Color(0.35, 0.5, 0.3), 1.0)
		draw_line(Vector2(2, 0), Vector2(1, -3), Color(0.35, 0.5, 0.3), 1.0)
		return
	var sway := sin(_t * 2.0 + global_position.x) * 1.0
	match kind:
		"bell":
			# 一丛细茎，挂着淡黄色的小铃铛花
			for i in 4:
				var x := -5.0 + i * 3.4
				draw_line(Vector2(x, 0), Vector2(x + sway, -9), Color(0.45, 0.68, 0.38), 1.0)
				draw_circle(Vector2(x + sway, -10), 1.8, Color(1.0, 0.92, 0.5))
				draw_circle(Vector2(x + sway, -9), 0.8, Color(0.9, 0.75, 0.3))
		"moss":
			# 一团软绵绵的青苔，冒出几根细须
			draw_circle(Vector2(0, -2), 6.0, Color(0.42, 0.62, 0.42))
			draw_circle(Vector2(-3, -3), 3.5, Color(0.55, 0.75, 0.5))
			for i in 5:
				var a := -PI * 0.9 + i * 0.45
				draw_line(Vector2(0, -3), Vector2(0, -3) + Vector2.from_angle(a) * (8.0 + sin(_t * 4.0 + i) * 1.5), Color(0.7, 0.88, 0.6), 1.0)
		"yawn":
			# 一朵大大的、懒洋洋的淡紫色花
			draw_line(Vector2(0, 0), Vector2(sway, -8), Color(0.45, 0.65, 0.4), 1.0)
			for i in 5:
				draw_circle(Vector2(sway, -10) + Vector2.from_angle(i * TAU / 5.0 + _t * 0.3) * 3.0, 2.2, Color(0.82, 0.68, 0.95))
			draw_circle(Vector2(sway, -10), 1.6, Color(1.0, 0.95, 0.6))
	# 一闪一闪：能摘
	draw_circle(Vector2(6, -12), 0.8 + 0.4 * sin(_t * 5.0), Color(1, 1, 0.8, 0.8))

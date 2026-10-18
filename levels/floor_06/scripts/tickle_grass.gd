class_name TickleGrass
extends Node2D
## 痒痒草（七日赎罪：图腾能量渗进地里长出来的，一丛开着粉色小花的草）：公主踩进 RADIUS 以内 → 藤蔓缠住腰（定身 ROOT_TIME 秒），
## 草叶和花穗在腰侧、脚心上乱扫（闷笑上涨，最多到 MAX_LAUGH，小镇里不会笑晕）；冲刺躲得开。松开后 COOL 秒内不会再缠同一个人。
## 委托「捡苹果」、之后修补图腾柱的任务用。画的是程序图形（草叶 + 小花 + 缠起来时的藤蔓），不占道具图集。

const RADIUS := 12.0
const ROOT_TIME := 1.6
const RATE := 0.22
const COOL := 2.5
const MAX_LAUGH := 0.97

var _t := 0.0
var _hold := 0.0
var _cool := 0.0
var _hit_t := 0.0
## 测试用：缠住过几次
var caught := 0


func _ready() -> void:
	z_index = -1
	add_to_group("tickle_grass")


func _process(delta: float) -> void:
	_t += delta
	_cool = maxf(0.0, _cool - delta)
	queue_redraw()
	var p := GameState.player
	if not is_instance_valid(p) or GameState.in_dialogue or GameState.in_cutscene:
		return
	if _hold > 0.0:
		_hold -= delta
		_hit_t -= delta
		if p.laugh and p.laugh.value < p.laugh.max_value * MAX_LAUGH:
			p.laugh.add(minf(p.laugh.max_value * RATE * delta, p.laugh.max_value * MAX_LAUGH - p.laugh.value))
		if _hit_t <= 0.0:
			_hit_t = 0.28
			p.shake(0.12)
			Audio.play("vine", -10.0, 0.1)
			var zone := "waist" if randf() < 0.6 else "sole"
			ZoneFx.play(zone, p.get_parent(), ZoneFx.body_point(p, zone), 1.0, false)
		if _hold <= 0.0:
			_cool = COOL
		return
	if _cool <= 0.0 and not p.is_dashing() and p.global_position.distance_to(global_position) <= RADIUS:
		_hold = ROOT_TIME
		caught += 1
		if p.status:
			p.status.apply_root(ROOT_TIME)
		SpeechBubble.say(p, ["呀！草、草缠上来了！", "哈、哈哈……腰、腰被扫……！", "又是这个草——！"].pick_random(), 30.0, 1.2)
		GameState.emote("helpless_1", 1.2, false)


func _draw() -> void:
	var sway := sin(_t * 2.2) * 1.5
	for i in 7:
		var x := -9.0 + i * 3.0
		var h := 7.0 + float((i * 5) % 4)
		draw_line(Vector2(x, 0), Vector2(x + sway * (0.5 + i * 0.1), -h), Color(0.45, 0.75, 0.4), 1.5)
	for f in [Vector2(-6, -8), Vector2(1, -10), Vector2(7, -7)]:
		draw_circle(f + Vector2(sway, 0), 1.6, Color(1.0, 0.6, 0.85))
	if _hold > 0.0 and is_instance_valid(GameState.player):
		# 缠起来的藤蔓：从草丛伸到公主腰上
		var to := to_local(GameState.player.global_position + Vector2(0, -9))
		for k in 3:
			var off := Vector2(sin(_t * 9.0 + k) * 3.0, 0)
			draw_line(Vector2(-4 + k * 4, 0), to + off, Color(0.4, 0.7, 0.35, 0.9), 1.5)
		draw_arc(to, 7.0, _t * 5.0, _t * 5.0 + 4.5, 12, Color(0.45, 0.8, 0.4), 1.5)

class_name QuestSpear
extends QuestRunner
## 支线「队长的旧剑术」的玩法（队长的训练室 floor_06_after_drill）：队长拿包了布的木矛练骑士那个起手式，她当靶子——Boss 招式的预演。
##   三轮（ROUNDS：几招、最多挨几下、要几次完美闪避）：
##     刺击：矛尖指向她站的地方，地上先亮一道线（THRUST_WARN 秒）再刺；扫腿：她脚下亮一圈（SWEEP_WARN 秒）再扫；实战：两种混着来、出得更快。
##   躲开 = 刺 / 扫的那一下不在线 / 圈里，或者正在冲刺（冲刺无敌）。命中前 PERFECT 秒内才按的冲刺 = 完美闪避：反挠队长一下。
##   被打中：队长的「老办法」挠一下（闷笑 +HIT_LAUGH，最多到 MAX_LAUGH），这一轮挨打超过上限就重来这一轮。三轮过了 = 做完（标记 kq_spear_done：
##   Boss 战里完美闪避会让骑士露出破绽；追逃和 Boss 里队长会替她挡一次）。
##   做完以后找训练室里的队长「再来一次」（start_replay）：同样三轮，练完不给奖励、不推进支线（replay）。
## 测试：round_i、dodged、hits、perfects、warn、attack(种类)、resolve()、dash_at。

const ROUNDS := [{"kinds": ["thrust"], "count": 5, "max_hits": 3, "perfect": 0, "gap": 1.6},
	{"kinds": ["sweep"], "count": 5, "max_hits": 3, "perfect": 0, "gap": 1.6},
	{"kinds": ["thrust", "sweep"], "count": 7, "max_hits": 3, "perfect": 2, "gap": 1.2}]
const THRUST_WARN := 0.8
const SWEEP_WARN := 1.0
const THRUST_LEN := 140.0
const THRUST_W := 14.0
const SWEEP_R := 20.0
const PERFECT := 0.25
const HIT_LAUGH := 0.12
const MAX_LAUGH := 0.9
const CAPTAIN := Vector2i(10, 4)
## 队长出招的精灵图（tools/art/gen_captain_cast.py：行 = 下 / 左 / 右 / 上，列 = 蓄力 / 刺 / 扫 / 收招）
const CAST_SHEET := preload("res://assets/generated/npcs/captain_cast.png")

var round_i := 0
var dodged := 0
var hits := 0
var perfects := 0
## 正在预警的一招：{kind, left, from, to（刺的终点）/ at（扫的圆心）}
var warn := {}
var dash_at := -10.0
var captain: Node2D
var _t := 0.0
var _gap := 1.5
var _was_dashing := false
var _paused := 0.0
## 做完以后的再练一次
var replay := false
## 出招时盖在队长身上的那张图（平时藏着，队长自己的行走图露出来）
var _cast: Sprite2D
var _cast_left := 0.0


static func runs_on(floor_id: String, _st: int) -> bool:
	return floor_id == KnightStory.DRILL


static func reset_items() -> void:
	pass


## 再练一次：在训练室里摆一个 replay 的玩法节点（已经在练就不摆）
static func start_replay() -> void:
	var main := (Engine.get_main_loop() as SceneTree).get_first_node_in_group("main")
	var lv: Node = main.get("level") if main else null
	if lv == null or str(lv.get("floor_id")) != KnightStory.DRILL or lv.get_node_or_null("Entities/Quest_spear") or lv.get_node_or_null("Entities/Replay_spear"):
		return
	var n := QuestSpear.new()
	n.name = "Replay_spear"
	n.replay = true
	lv.get_node("Entities").add_child(n)


func setup() -> void:
	captain = _lv.find_child("after_drill_cap", true, false) as Node2D
	if is_instance_valid(captain):
		_cast = Sprite2D.new()
		_cast.name = "Cast"
		_cast.texture = CAST_SHEET
		_cast.hframes = 4
		_cast.vframes = 4
		_cast.offset = Vector2(0, -14)
		_cast.visible = false
		captain.add_child(_cast)
	_paused = 999.0
	_intro()


func cleanup() -> void:
	_pose(-1)
	if is_instance_valid(_cast):
		_cast.queue_free()


## 队长的出招动作：0 蓄力 / 1 刺 / 2 扫 / 3 收招（-1 = 收起来，露出平时的行走图）；朝着她
func _pose(p: int, hold := 0.0) -> void:
	if not is_instance_valid(_cast) or not is_instance_valid(captain):
		return
	var spr := captain.get_node_or_null("Sprite") as Sprite2D
	_cast.visible = p >= 0
	if spr:
		spr.visible = p < 0
	_cast_left = hold
	if p < 0:
		return
	var d := origin().direction_to(pink.global_position) if is_instance_valid(pink) else Vector2.DOWN
	var row := 0
	if absf(d.x) > absf(d.y):
		row = 1 if d.x < 0 else 2
	elif d.y < 0:
		row = 3
	_cast.frame = row * 4 + p


## 第一次进训练室：演起手式的开场（kq_spear_intro 记着），再开始第一轮
func _intro() -> void:
	var cut := str(q.get("intro_cut", ""))
	if cut != "" and not replay and not GameState.has_flag("kq_spear_intro") and Cutscene.has_cutscene(cut):
		GameState.set_flag("kq_spear_intro")
		await get_tree().process_frame
		await TrainingDB.wait_dialogue_free()
		await Cutscene.play(cut)
	if is_inside_tree():
		_paused = 0.0
		_start_round(0)


func _start_round(i: int) -> void:
	round_i = i
	dodged = 0
	hits = 0
	perfects = 0
	warn = {}
	_gap = 1.8
	var drill: Dictionary = q.get("drill", {})
	GameState.notify(str(drill["rounds"][i]), 2.0)
	say(drill["round_tip"][i], 3.2)


func origin() -> Vector2:
	return captain.global_position if is_instance_valid(captain) else Cutscene.cell_to_world(CAPTAIN)


func _process(delta: float) -> void:
	queue_redraw()
	if GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink) or GameState.player != pink:
		return
	_t += delta
	var dashing := pink.is_dashing()
	if dashing and not _was_dashing:
		dash_at = _t
	_was_dashing = dashing
	if _cast_left > 0.0:
		_cast_left -= delta
		if _cast_left <= 0.0:
			# 刺 / 扫完：收招一下，再回到平时的样子
			if is_instance_valid(_cast) and _cast.visible and _cast.frame % 4 in [1, 2]:
				_pose(3, 0.3)
			else:
				_pose(-1)
	if _paused > 0.0:
		_paused -= delta
		return
	if warn.is_empty():
		_gap -= delta
		if _gap <= 0.0:
			var kinds: Array = ROUNDS[round_i]["kinds"]
			attack(str(kinds[randi() % kinds.size()]))
		return
	warn["left"] = float(warn["left"]) - delta
	if float(warn["left"]) <= 0.0:
		resolve()


## 出招：亮预警
func attack(kind: String) -> void:
	var from := origin()
	if kind == "thrust":
		var dir := from.direction_to(pink.global_position)
		warn = {"kind": kind, "left": THRUST_WARN, "from": from, "to": from + dir * THRUST_LEN}
		say(q["drill"]["thrust"], 1.4)
	else:
		warn = {"kind": kind, "left": SWEEP_WARN, "at": pink.global_position}
		say(q["drill"]["sweep"], 1.4)
	_pose(0)


func in_zone() -> bool:
	if warn.is_empty():
		return false
	var p := pink.global_position
	if str(warn["kind"]) == "thrust":
		var near := Geometry2D.get_closest_point_to_segment(p, warn["from"], warn["to"])
		return p.distance_to(near) <= THRUST_W * 0.5 + 4.0
	return p.distance_to(warn["at"]) <= SWEEP_R


## 刺 / 扫的那一下：打中了没有、完美闪避了没有
func resolve() -> String:
	var res := "dodge"
	_strike_fx()
	if in_zone():
		if pink.is_fully_invulnerable() or pink.is_dashing():
			res = "perfect" if _t - dash_at <= PERFECT else "dodge"
		else:
			res = "hit"
	warn = {}
	var cfg: Dictionary = ROUNDS[round_i]
	_gap = float(cfg["gap"])
	var drill: Dictionary = q.get("drill", {})
	match res:
		"hit":
			hits += 1
			_paused = 0.7
			KnightFx.play(get_parent(), "spear_impact", pink.global_position + Vector2(0, -12), {"size": 40.0})
			var zone: String = ["waist", "sole"].pick_random()
			ZoneFx.play(zone, pink.get_parent(), ZoneFx.body_point(pink, zone), 1.0, false)
			if pink.laugh and pink.laugh.value < pink.laugh.max_value * MAX_LAUGH:
				pink.laugh.add(minf(pink.laugh.max_value * HIT_LAUGH, pink.laugh.max_value * MAX_LAUGH - pink.laugh.value))
			say(drill["hit"], 2.0)
			SpeechBubble.say(pink, str((drill["hit_react"] as Array).pick_random()), 30.0, 1.4)
			if hits >= int(cfg["max_hits"]):
				say(drill["fail"], 2.4)
				_start_round(round_i)
				return res
		"perfect":
			perfects += 1
			dodged += 1
			say(drill["perfect"], 2.0)
			if is_instance_valid(captain):
				SpeechBubble.say(captain, str((drill["cap_react"] as Array).pick_random()), 30.0, 1.4)
			Audio.play("star_burst", -10.0)
		_:
			dodged += 1
	if dodged >= int(cfg["count"]) and perfects >= int(cfg["perfect"]):
		if round_i + 1 < ROUNDS.size():
			_start_round(round_i + 1)
		elif replay:
			GameState.notify("（三轮练完了。队长：「……还行。」）", 2.5)
			queue_free()
		else:
			advance()
	elif dodged >= int(cfg["count"]):
		# 实战轮：躲够了但完美闪避不够，接着来
		pass
	return res


## 刺 / 扫出去的那一下：队长摆出招的动作，矛的光刃 / 扫出去的弧光（codex 生成的特效图）
func _strike_fx() -> void:
	if warn.is_empty():
		return
	if str(warn["kind"]) == "thrust":
		_pose(1, 0.35)
		var a: Vector2 = warn["from"]
		var b: Vector2 = warn["to"]
		KnightFx.play(get_parent(), "spear_thrust", a.lerp(b, 0.5) + Vector2(0, -10), {"size": THRUST_LEN, "rot": (b - a).angle()})
	else:
		_pose(2, 0.35)
		KnightFx.play(get_parent(), "spear_sweep", warn["at"], {"size": SWEEP_R * 2.0 + 24.0, "squash": 0.7})
	Audio.play("swing", -6.0)


func status() -> String:
	var cfg: Dictionary = ROUNDS[round_i]
	var drill: Dictionary = q.get("drill", {})
	var extra := (str(drill["perfect_need"]) % [perfects, int(cfg["perfect"])]) if int(cfg["perfect"]) > 0 else ""
	return str(drill["panel"]) % [str(drill["rounds"][round_i]), dodged, int(cfg["count"]), hits, int(cfg["max_hits"]), extra]


func _draw() -> void:
	if warn.is_empty():
		return
	var k := 1.0 - float(warn["left"]) / (THRUST_WARN if str(warn["kind"]) == "thrust" else SWEEP_WARN)
	var col := Color(1.0, 0.35, 0.35, 0.25 + 0.4 * k)
	if str(warn["kind"]) == "thrust":
		var a: Vector2 = to_local(warn["from"])
		var b: Vector2 = to_local(warn["to"])
		draw_line(a, b, col, THRUST_W)
		draw_line(a, a.lerp(b, k), Color(1, 0.8, 0.5, 0.9), 2.0)
	else:
		var c: Vector2 = to_local(warn["at"])
		draw_circle(c, SWEEP_R, col)
		draw_arc(c, SWEEP_R * (1.0 - k) + 2.0, 0, TAU, 20, Color(1, 0.8, 0.5, 0.9), 1.5)

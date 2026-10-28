class_name QuestDuo
extends QuestSpear
## 支线「队长的旧剑术」第三段「二对一」（训练室）：两位公主一起和队长练（这一段在训练室里能按 C 换人）。
##   队长照旧出招（刺 / 扫混着来，打的是现在操控的那位）；躲开以后他收矛慢半拍——OPEN 秒的空档：走到他身边（CAP_R）按攻击 = 挠他（忍笑 +TICKLE）；
##   完美闪避直接 +PERFECT_TICKLE。蓝色公主不在空档里按 J：冰顺着矛杆爬上去，冻住他的矛 FREEZE 秒（这几秒不出招，冷却 FREEZE_COOL）。
##   被打中：老办法挠一下（同 QuestSpear）。队长的忍笑满 = 他「噗」地笑出来 → 过场 kq_spear_duo_end（手帕）→ 做完（kq_spear_done）。
## 测试：cap_laugh、open_left、freeze_cool、tickle_cap(角色)、freeze_spear(角色)、resolve()。

const OPEN := 1.2
const CAP_R := 30.0
const TICKLE := 0.12
const PERFECT_TICKLE := 0.2
const FREEZE := 3.0
const FREEZE_COOL := 8.0

var cap_laugh := 0.0
var open_left := 0.0
var freeze_cool := 0.0
var _pink0: PlayableCharacter
var _was_no_switch := false
var _had_switch := false
var _ending := false


func d() -> Dictionary:
	return q.get("duo", {})


func setup() -> void:
	_pink0 = pink
	super()
	_was_no_switch = bool(_lv.get("no_switch"))
	_had_switch = _lv.get_meta(&"free_switch", false)
	_lv.set("no_switch", false)
	_lv.set_meta(&"free_switch", true)
	Duo._bind_tab()
	_duo_intro()


func cleanup() -> void:
	super()
	if is_instance_valid(_lv):
		_lv.set("no_switch", _was_no_switch)
		_lv.set_meta(&"free_switch", _had_switch)
	if is_instance_valid(_pink0) and GameState.player != _pink0 and is_instance_valid(GameState.player):
		GameState.switch_control(_pink0)


func _duo_intro() -> void:
	if GameState.has_flag("kq_spear_duo_intro"):
		return
	GameState.set_flag("kq_spear_duo_intro")
	await get_tree().process_frame
	await TrainingDB.wait_dialogue_free()
	Dialogue.start_lines(d().get("intro", []), "kq_duo_intro")


## 实战轮的招式（刺 / 扫混着来），不报轮次
func _start_round(_i: int) -> void:
	round_i = ROUNDS.size() - 1
	warn = {}
	_gap = 1.6


func status() -> String:
	return str(d().get("status", "%d%%")) % int(cap_laugh * 100.0)


func _process(delta: float) -> void:
	if not live() or _ending:
		return
	# 打的是现在操控的那位（换成蓝色公主也打她）
	var me := GameState.player as PlayableCharacter
	if is_instance_valid(me) and (me == _pink0 or me == blue):
		pink = me
	if GameState.in_dialogue or GameState.in_cutscene:
		return
	open_left = maxf(0.0, open_left - delta)
	freeze_cool = maxf(0.0, freeze_cool - delta)
	if Input.is_action_just_pressed("attack") and is_instance_valid(me):
		if open_left > 0.0:
			tickle_cap(me)
		elif me == blue:
			freeze_spear(me)
	super(delta)


## 刺 / 扫的那一下：躲开了开一个空档（完美闪避直接挠一下）；打中了照旧挨老办法
func resolve() -> String:
	var res := "dodge"
	_strike_fx()
	if in_zone():
		if pink.is_fully_invulnerable() or pink.is_dashing():
			res = "perfect" if _t - dash_at <= PERFECT else "dodge"
		else:
			res = "hit"
	warn = {}
	_gap = 1.4
	var drill: Dictionary = q.get("drill", {})
	match res:
		"hit":
			_paused = 0.6
			var zone: String = ["waist", "sole"].pick_random() if pink == _pink0 else "thigh"
			ZoneFx.play(zone, pink.get_parent(), ZoneFx.body_point(pink, zone), 1.0, false)
			if pink.laugh and pink.laugh.value < pink.laugh.max_value * MAX_LAUGH:
				pink.laugh.add(minf(pink.laugh.max_value * HIT_LAUGH, pink.laugh.max_value * MAX_LAUGH - pink.laugh.value))
			say(drill["hit"], 1.6)
		"perfect":
			_add_cap(PERFECT_TICKLE)
			say(drill["perfect"], 1.6)
		_:
			open_left = OPEN
			say(d().get("open", []), 1.0)
	return res


## 空档里挠他
func tickle_cap(who: PlayableCharacter) -> bool:
	if open_left <= 0.0 or not is_instance_valid(captain) or who.global_position.distance_to(captain.global_position) > CAP_R:
		return false
	open_left = 0.0
	say(d().get("tickle", []), 1.2)
	_add_cap(TICKLE)
	return true


## 蓝色公主 J：冻住他的矛
func freeze_spear(who: PlayableCharacter) -> bool:
	if freeze_cool > 0.0 or not is_instance_valid(captain) or who.global_position.distance_to(captain.global_position) > CAP_R + 20.0:
		return false
	freeze_cool = FREEZE_COOL
	_paused = maxf(_paused, FREEZE)
	warn = {}
	say(d().get("freeze", []), 1.6)
	Audio.play("chime", -4.0)
	return true


func _add_cap(amount: float) -> void:
	cap_laugh = minf(1.0, cap_laugh + amount)
	if is_instance_valid(captain):
		SpeechBubble.say(captain, str((d().get("cap_react", ["……"]) as Array).pick_random()), 30.0, 1.2)
	Audio.play("tickle", -6.0, 0.1)
	if cap_laugh >= 1.0:
		_finish()


func _finish() -> void:
	_ending = true
	warn = {}
	_pose(-1)
	var cut := str(q.get("duo_end", ""))
	if cut != "" and Cutscene.has_cutscene(cut):
		await TrainingDB.wait_dialogue_free()
		await Cutscene.play(cut)
	advance()

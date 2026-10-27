class_name QuestWatch
extends QuestRunner
## 支线「队长的旧剑术」第二段「守夜」（城墙上 floor_06_knight_wall，夜里一样的暗）：
##   巡逻：沿着城墙走到哨塔（TOWER）。房檐上挂着爬墙手印（EaveHand，EAVES）：从下面经过就亮影子掉下来抓脚，连按 J 挣开。
##   到了哨塔下：队长蒙上她的眼睛练「听声躲矛」——画面全黑（只剩一点点轮廓），每 CUE_GAP 秒矛杆在左边或右边「嗡」地一响（边上闪一下提示），
##     REACT 秒内往另一边躲（响在左边按 →，响在右边按 ←）= 躲开；按反了 / 没按 = 被戳中，老办法挠腰（闷笑 +HIT_LAUGH）。
##     CUES 下里躲开 NEED 下 = 过；挨打 MAX_HITS 下 = 重来这一轮。过了 → 过场 kq_spear_watch_end（「两个孩子」）→ 这一段做完。
## 测试：eaves、blind、cue（{side, left}）、dodged、hits、start_blind()、answer("left"/"right")。

const EAVES := [Vector2i(10, 3), Vector2i(16, 3), Vector2i(22, 3), Vector2i(28, 3), Vector2i(34, 3), Vector2i(40, 3)]
const TOWER := Vector2i(46, 3)
const TOWER_R := 22.0
const CUES := 8
const NEED := 6
const MAX_HITS := 3
const CUE_GAP := 1.0
const REACT := 1.0
const HIT_LAUGH := 0.1
const CAP_SHEET := preload("res://assets/generated/npcs/captain.png")

var eaves: Array = []
var blind := false
var cue := {}
var dodged := 0
var hits := 0
var given := 0
var _gap := CUE_GAP
var _layer: CanvasLayer
var _shade: ColorRect
var _cue_label: Label
var _captain: Sprite2D
var _starting := false


func w() -> Dictionary:
	return q.get("watch", {})


func setup() -> void:
	eaves.clear()
	for c in EAVES:
		var e := EaveHand.new()
		e.lines = q
		put(e, Cutscene.cell_to_world(c))
		eaves.append(e)
	_captain = put(Sprite2D.new(), Cutscene.cell_to_world(TOWER) + Vector2(0, -12)) as Sprite2D
	_captain.texture = CAP_SHEET
	_captain.hframes = 4
	_captain.vframes = 4
	_captain.frame = 4
	_intro()


func _intro() -> void:
	if GameState.has_flag("kq_spear_watch_intro"):
		return
	GameState.set_flag("kq_spear_watch_intro")
	await get_tree().process_frame
	await TrainingDB.wait_dialogue_free()
	Dialogue.start_lines(w().get("intro", []), "kq_watch_intro")


func cleanup() -> void:
	_lights_on()


func status() -> String:
	if not blind:
		return "走到哨塔下面"
	return str(w().get("status", "%d %d %d %d")) % [dodged, NEED, hits, MAX_HITS]


func _process(delta: float) -> void:
	if not live() or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink) or GameState.player != pink:
		return
	if not blind:
		if not _starting and pink.global_position.distance_to(Cutscene.cell_to_world(TOWER)) <= TOWER_R:
			_begin()
		return
	tick(delta)
	if Input.is_action_just_pressed("move_left"):
		answer("left")
	elif Input.is_action_just_pressed("move_right"):
		answer("right")


func _begin() -> void:
	_starting = true
	await TrainingDB.wait_dialogue_free()
	Dialogue.start_lines(w().get("blind_intro", []), "kq_watch_blind")
	while Dialogue.is_active():
		await get_tree().process_frame
	if is_inside_tree():
		start_blind()


## 蒙上眼睛：画面变黑，开始听声躲矛
func start_blind() -> void:
	blind = true
	dodged = 0
	hits = 0
	given = 0
	cue = {}
	_gap = CUE_GAP
	if pink.status:
		pink.status.apply_root(999.0)
	if not is_instance_valid(_layer):
		_layer = CanvasLayer.new()
		_layer.layer = 12
		add_child(_layer)
		_shade = ColorRect.new()
		_shade.color = Color(0.02, 0.01, 0.04, 0.94)
		_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(_shade)
		_cue_label = Label.new()
		_cue_label.add_theme_font_size_override("font_size", 16)
		_cue_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
		_layer.add_child(_cue_label)
	_layer.visible = true


func _lights_on() -> void:
	if is_instance_valid(_layer):
		_layer.visible = false
	if is_instance_valid(pink) and pink.status:
		pink.status.clear_root()


func tick(delta: float) -> void:
	if not cue.is_empty():
		cue["left"] = float(cue["left"]) - delta
		if float(cue["left"]) <= 0.0:
			_hit()
		return
	_gap -= delta
	if _gap <= 0.0:
		next_cue()


## 下一下：矛杆在左边 / 右边响
func next_cue(side := "") -> Dictionary:
	if side == "":
		side = "left" if randf() < 0.5 else "right"
	given += 1
	cue = {"side": side, "left": REACT}
	Audio.play("swing", -4.0, 0.0, 0.8 if side == "left" else 1.2)
	if is_instance_valid(_cue_label):
		_cue_label.text = "◀ 嗡" if side == "left" else "嗡 ▶"
		_cue_label.position = Vector2(24 if side == "left" else 400, 120)
		_cue_label.modulate.a = 1.0
		_cue_label.create_tween().tween_property(_cue_label, "modulate:a", 0.0, REACT)
	say(w().get("cue", {}).get(side, ""), 1.0)
	return cue


## 往一边躲（"left" / "right"）：要往响的另一边躲
func answer(dir: String) -> bool:
	if cue.is_empty():
		return false
	var ok := dir != str(cue["side"])
	if ok:
		dodged += 1
		say(w().get("dodge", []), 1.0)
		Audio.play("dash", -8.0)
		cue = {}
		_gap = CUE_GAP
		_check()
	else:
		_hit()
	return ok


func _hit() -> void:
	cue = {}
	_gap = CUE_GAP
	hits += 1
	say(w().get("hit", []), 1.4)
	SpeechBubble.say(pink, str((w().get("hit_react", ["哈哈！"]) as Array).pick_random()), 30.0, 1.2)
	if pink.laugh:
		pink.laugh.add(pink.laugh.max_value * HIT_LAUGH)
	ZoneFx.play("waist", pink.get_parent(), ZoneFx.body_point(pink, "waist"), 1.0, false)
	if hits >= MAX_HITS:
		say(w().get("fail", ""), 2.4)
		start_blind()
		return
	_check()


func _check() -> void:
	if dodged >= NEED:
		blind = false
		_lights_on()
		_finish()
	elif given >= CUES and dodged + (CUES - given) < NEED:
		start_blind()


func _finish() -> void:
	var cut := str(q.get("watch_end", ""))
	if cut != "" and Cutscene.has_cutscene(cut):
		await TrainingDB.wait_dialogue_free()
		await Cutscene.play(cut)
	advance()

class_name BrewShow
extends TrainingStage
## 支线「手印样本」第六段「熬药」（借训练小游戏的画面 + 下方的 RhythmLane 音符条）。台词 knight_quests.json 的 samples.brew。
##   三锅（sections）：只是音游——跟着节拍按方向键搅药（RhythmLane）；失误 = 药溢出来一点（overflow +1），小孩拿药草叶子挠一下（闷笑 +MISS_LAUGH）。
##   （以前的打喷嚏方向提示、小孩一直挠的忍耐都去掉了：用户要求熬药只留音游）
##   溢锅 OVERFLOW_MAX 次 = 这一锅重熬。第二锅熬完，奶奶说起很多年前那个发烧的小姑娘和摇篮曲（lullaby）。三锅熬完 → await play() 返回 true。
## 测试：quiet、lane、overflow、section。

const PATH := "res://data/after/knight_quests.json"
const MISS_LAUGH := 0.04
const OVERFLOW_MAX := 3

static var quiet := false

var lane: RhythmLane
var section := -1
var overflow := 0
var _done := false
var _info: Label


static func text() -> Dictionary:
	return KnightQuests.info("samples").get("brew", {})



func _init() -> void:
	follow_laugh = true   # 木偶跟着闷笑换姿势


func panel_title() -> String:
	return str(text().get("name", "熬药"))


func quit() -> void:
	pass


func stage_cast() -> Dictionary:
	return {"granny": {"kind": "npc:pharmacist", "at": [0, -14], "dir": "down"},
		"pot": {"kind": "trap:cauldron", "at": [0, 4]},
		"kid1": {"kind": "npc:kid", "at": [-30, 24], "dir": "right"},
		"kid2": {"kind": "npc:kid", "at": [30, 24], "dir": "left"}}


func _build_cast(cast: Dictionary) -> void:
	cast.erase("pot")
	super(cast)
	for spec in [["princess", "pink", Vector2(-22, 10), "right"], ["blue", "blue", Vector2(22, 10), "left"]]:
		var a := CGActor.make_princess(str(spec[0]), str(spec[1]))
		a.set_pose("normal", "idle", str(spec[3]))
		a.position = spec[2]
		cast_root.add_child(a)
		actors[str(spec[0])] = a
	var pot := PotRig.new()
	pot.show_ref = self
	pot.position = Vector2(0, 8)
	cast_root.add_child(pot)


func play() -> bool:
	player = GameState.player
	rng.randomize()
	layer = 14
	t = {"name": panel_title()}
	_build_ui()
	hint_label.text = str(text().get("hint", ""))
	_info = _label(TEXT, 8)
	_info.size = panel_body.size
	_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel_body.add_child(_info)
	lane = RhythmLane.new()
	lane.position = Vector2(FRAME_RECT.position.x, FRAME_RECT.end.y - 22)
	lane.size = Vector2(FRAME_RECT.size.x, 20)
	root.add_child(lane)
	lane.judged.connect(_on_judged)
	if is_instance_valid(player):
		_start_fatigue = player.fatigue.value if player.fatigue else 0.0
		_start_laugh = player.laugh.value if player.laugh else 0.0
		if player.laugh:
			player.laugh.set_value(0.0)
	_enter_game()
	busy = true
	await _lines(text().get("intro", []))
	await _start_section(0)
	busy = false
	while not _done and is_inside_tree():
		await get_tree().process_frame
	await _exit_game()
	finished.emit()
	return true


func _build_ui() -> void:
	super()
	count_label.position = Vector2(356, 218)
	count_label.size = Vector2(116, 14)
	count_label.add_theme_font_size_override("font_size", 7)
	hint_label.position = Vector2(356, 232)
	hint_label.size = Vector2(116, 37)
	hint_label.add_theme_font_size_override("font_size", 7)


func _lines(lines: Array) -> void:
	if quiet or lines.is_empty():
		return
	var was := busy
	busy = true
	Dialogue.start_lines(lines, "brew_show")
	while Dialogue.is_active():
		await get_tree().process_frame
	GameState.in_dialogue = true
	busy = was


func _start_section(i: int) -> void:
	section = i
	overflow = 0
	var names: Array = text().get("sections", [])
	narrate(str(names[i]) if i < names.size() else "", 1.6)
	lane.load_chart(RhythmLane.make_chart(96.0 + i * 12.0, 12 + i * 2, rng.randi()))
	_refresh()


func _refresh() -> void:
	if _info == null:
		return
	var names: Array = text().get("sections", [])
	var c := lane.counts
	_info.text = str(text().get("panel", "%s\n%d / %d %d %d")) % [str(names[section]) if section >= 0 and section < names.size() else "",
		overflow, OVERFLOW_MAX, int(c["perfect"]), int(c["miss"])]


func _on_key(k: String) -> void:
	lane.press(k)


func _on_judged(res: String, _n: Dictionary) -> void:
	if res == "miss":
		_spill(1)
		tickle("kid1", "sole", false, "princess", "hand")
		add_laugh(laugh_max() * MISS_LAUGH)
		narrate(str((text().get("itch", [""]) as Array).pick_random()), 1.2)
	else:
		pop(actors.get("princess"), "完美！" if res == "perfect" else "不错", GOLD if res == "perfect" else GOOD, 0.5)
	_refresh()


func _spill(n: int) -> void:
	overflow += n
	narrate(str((text().get("spill", [""]) as Array).pick_random()), 1.2)
	if overflow >= OVERFLOW_MAX:
		_redo()


func _redo() -> void:
	busy = true
	narrate(str(text().get("fail", "")), 2.0)
	await get_tree().create_timer(0.1 if quiet else 1.2).timeout
	await _start_section(section)
	busy = false


func _tick(delta: float) -> void:
	if section < 0:
		return
	lane.advance(delta)
	if lane.finished() and lane.time >= lane.end_time():
		_section_end()


func _section_end() -> void:
	busy = true
	if section == 1:
		await _lines(text().get("lullaby", []))
	if section + 1 < (text().get("sections", []) as Array).size():
		await _start_section(section + 1)
		busy = false
		return
	_done = true
	busy = false


## 闷笑满（只靠失误的叶子挠很难满）：笑一阵、闷笑回到一截，不算溢锅
func _punish(kind: String) -> void:
	if kind != "laugh":
		if player.fatigue:
			player.fatigue.clear()
		return
	if player.laugh:
		player.laugh.set_value(player.laugh.max_value * 0.35)


func _update_count() -> void:
	count_label.text = "溢锅 %d / %d" % [overflow, OVERFLOW_MAX]


## 舞台中间的药锅：咕嘟咕嘟冒泡，溢得越多泡越大
class PotRig extends Node2D:
	var show_ref: BrewShow
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2(0, 2), 11.0, Color("3b2f3a"))
		draw_rect(Rect2(-11, -4, 22, 6), Color("4d3d4b"))
		draw_circle(Vector2(0, -4), 9.0, Color("8e6fb8"))
		var o := float(show_ref.overflow) if is_instance_valid(show_ref) else 0.0
		for i in 3:
			var k := fmod(_t * (1.2 + o * 0.4) + i * 0.33, 1.0)
			draw_circle(Vector2(-5 + i * 5, -6 - k * (6.0 + o * 3.0)), 1.6 + o * 0.4, Color(0.8, 0.7, 1.0, 1.0 - k))
		if o > 0.0:
			draw_rect(Rect2(-12, -2, 24, 2), Color(0.6, 0.45, 0.85, 0.3 * o))

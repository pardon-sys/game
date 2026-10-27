class_name QuestBridge
extends QuestRunner
## 支线「点灯笼的小姑娘」第五段「小桥」（floor_06_knight_bridge）：两个人手拉着手（蓝色公主紧跟着）走过排水渠上一格宽的小木桥。
##   桥板缝里的手印（BridgeHand，HANDS）一阵一阵伸上来抓脚：被抓到 = 挠一下；被抓 LET_GO 次 / 冲刺（一冲就松手了）/ 闷笑过 LET_GO_LAUGH
##   = 手被扯开：两个人都退回桥头（START），重来。走到桥那头（END_X 以右）→ 回忆的台词（「那时候，她的手也是这么暖的」）→ 这一段做完。
## 测试：hands、grabs、let_go()、tick(秒)。

const HANDS := [[Vector2i(10, 4), 0.0], [Vector2i(13, 4), 1.1], [Vector2i(16, 4), 0.5], [Vector2i(19, 4), 1.6], [Vector2i(22, 4), 0.9], [Vector2i(24, 4), 2.0]]
const START := Vector2i(5, 4)
const END_X := 26
const LET_GO := 3
const LET_GO_LAUGH := 0.75

var hands: Array = []
var grabs := 0
var _done := false


func br() -> Dictionary:
	return q.get("bridge", {})


func setup() -> void:
	hands.clear()
	grabs = 0
	for spec in HANDS:
		var h := BridgeHand.new()
		h.phase_offset = float(spec[1])
		put(h, Cutscene.cell_to_world(spec[0]))
		h.grabbed.connect(_on_grab)
		hands.append(h)
	_intro()


func _intro() -> void:
	if GameState.has_flag("kq_blue_bridge_intro"):
		return
	GameState.set_flag("kq_blue_bridge_intro")
	await get_tree().process_frame
	await TrainingDB.wait_dialogue_free()
	Dialogue.start_lines(br().get("intro", []), "kq_bridge_intro")


func status() -> String:
	return "被抓 %d / %d（别松手）" % [grabs, LET_GO]


func _process(delta: float) -> void:
	if _done or not live() or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink) or GameState.player != pink:
		return
	tick(delta)


func tick(_delta: float) -> void:
	var on_bridge := pink.global_position.x > Cutscene.cell_to_world(Vector2i(8, 4)).x
	if on_bridge and (pink.is_dashing() or (pink.laugh and pink.laugh.ratio() >= LET_GO_LAUGH)):
		let_go()
		return
	if pink.global_position.x >= Cutscene.cell_to_world(Vector2i(END_X, 4)).x:
		_finish()


func _on_grab(_who: PlayableCharacter) -> void:
	grabs += 1
	say(br().get("grab", []), 1.2)
	if grabs >= LET_GO:
		let_go()


## 手被扯开：两个人都退回桥头
func let_go() -> void:
	grabs = 0
	say(br().get("let_go", ""), 2.0)
	pink.global_position = Cutscene.cell_to_world(START)
	if pink.laugh:
		pink.laugh.set_value(pink.laugh.max_value * 0.3)
	if pink.status:
		pink.status.clear_root()
	if is_instance_valid(blue):
		blue.global_position = Cutscene.cell_to_world(START) + Vector2(-12, 0)


func _finish() -> void:
	_done = true
	await TrainingDB.wait_dialogue_free()
	Dialogue.start_lines(br().get("done", []), "kq_bridge_done")
	while Dialogue.is_active():
		await get_tree().process_frame
	advance()

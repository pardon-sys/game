class_name QuestBridge
extends QuestRunner
## 支线「点灯笼的小姑娘」第五段「小桥」（floor_06_knight_bridge）：两个人手拉着手（蓝色公主紧跟着）走过排水渠上一格宽的小木桥。
##   桥板缝里的手印（BridgeHand，HANDS）一阵一阵伸上来抓脚：被抓到 = 挠一下；被抓 LET_GO 次 / 冲刺（一冲就松手了）/ 闷笑过 LET_GO_LAUGH
##   = 手被扯开：两个人都退回桥头（START），重来。走到桥那头（END，END_R 以内）→ 回忆的台词（「那时候，她的手也是这么暖的」）→ 这一段做完。
## 测试：hands、grabs、let_go()、tick(秒)。

## 地图上的点（QuestMaps：小桥的布局在 tools/build/quest_maps.py，中间拐一个弯）：手印 [格, 错开的时间]
static var HANDS: Array = _hands()
static var START: Vector2i = QuestMaps.cell("floor_06_knight_bridge", "start")
static var END: Vector2i = QuestMaps.cell("floor_06_knight_bridge", "end")
const END_R := 14.0
const LET_GO := 2
const LET_GO_LAUGH := 0.75

var hands: Array = []


static func _hands() -> Array:
	var out := []
	for c in QuestMaps.cells("floor_06_knight_bridge", "hands"):
		out.append([c, fmod(out.size() * 0.55, BridgeHand.EVERY)])
	return out
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
	var on_bridge := pink.global_position.x > Cutscene.cell_to_world(START + Vector2i(4, 0)).x
	if on_bridge and (pink.is_dashing() or (pink.laugh and pink.laugh.ratio() >= LET_GO_LAUGH)):
		let_go()
		return
	if pink.global_position.distance_to(Cutscene.cell_to_world(END)) <= END_R:
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
		blue.global_position = Cutscene.cell_to_world(START) + Vector2(0, 14)


func _finish() -> void:
	_done = true
	await TrainingDB.wait_dialogue_free()
	Dialogue.start_lines(br().get("done", []), "kq_bridge_done")
	while Dialogue.is_active():
		await get_tree().process_frame
	advance()

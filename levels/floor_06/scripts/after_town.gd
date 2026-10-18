class_name AfterTown
extends Node2D
## 地下小镇·战后（floor_06_after，七日赎罪）的导演：
##   蓝色公主跟着粉色公主（这张图 no_switch，不能换人；和她说话是 floor_06/after_partner），节点改名 AfterBlue（过场里用）。
##   镇民（对话文件 floor_06/after_*）的节点改名成对话文件名（after_captain……：过场里直接用这个名字指挥他们），
##   按 DayClock 的日程摆位置 / 换朝向 / 藏起来（apply_schedule）；时间变了（DayClock.TICK）、某个时段的事做完了、过场放完，都重新摆一次。
##   进图：第一次进来 = 第 1 天早上（AfterStory.begin），然后演这里该演的事件（AfterStory.run_pending）。
## 图例：X = f6after

const PARTNER := "floor_06/after_partner"
const PREFIX := "floor_06/after_"
## 藏起来的镇民：show_flag 设成一个永远不会有的标记
const NEVER := "after_never"

## 对话文件名 -> Resident
var residents := {}
var blue: PlayableCharacter


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var lv := _level()
	if lv == null:
		return
	_setup(lv)
	AfterStory.begin()
	apply_schedule()
	GameState.flag_changed.connect(_on_flag_changed)
	Cutscene.finished.connect(_on_cutscene_finished)
	await AfterStory.run_pending(AfterStory.TOWN)


func _level() -> Node:
	var n := get_parent()
	while n and not n.has_node("Walls"):
		n = n.get_parent()
	return n


func _setup(lv: Node) -> void:
	for n in lv.find_children("*", "PlayableCharacter", true, false):
		var c := n as PlayableCharacter
		if c.camera:
			c.camera.zoom = Vector2.ONE
			c.camera.top_level = false
		c.follow = true
		c.partner_talk = PARTNER
		if c.is_controlled():
			c._refresh_partner_area()
		else:
			c.start_following(PARTNER)
			c.name = "AfterBlue"
			blue = c
	for n in lv.find_children("*", "Resident", true, false):
		var r := n as Resident
		if r.dialogue.begins_with(PREFIX):
			var key := r.dialogue.get_file()
			r.name = key
			residents[key] = r


func apply_schedule() -> void:
	for key in residents:
		var r: Resident = residents[key]
		if is_instance_valid(r):
			place(r, DayClock.npc(key))


## 按一条日程摆一个镇民：{at 格, dir, wander, hidden, dialogue}
static func place(r: Resident, info: Dictionary) -> void:
	r.show_flag = NEVER if bool(info.get("hidden", false)) else ""
	if info.has("at"):
		var p: Vector2 = Cutscene.cell_to_world(info["at"])
		r.global_position = p
		r._home = p
		r._goal = p
		r.velocity = Vector2.ZERO
	if info.has("dir"):
		r.facing = Trap.dir_vector(str(info["dir"]))
	if info.has("wander"):
		r.wander = float(info["wander"])
	if info.has("dialogue"):
		r.dialogue = "floor_06/" + str(info["dialogue"])
	r._refresh_visibility()


func _on_flag_changed(flag: String) -> void:
	if flag == DayClock.TICK or flag.begins_with("after_done_"):
		apply_schedule()


## 过场放完：镇民回到日程上的位置；过场留下的黑幕（end_dark）在这里揭开——要是紧接着要过一段时间（DayClock.pass_time）就交给它揭。
func _on_cutscene_finished(_id: String) -> void:
	if not is_inside_tree():
		return
	apply_schedule()
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree() and not DayClock.passing and not Cutscene.is_playing():
		Cutscene.curtain_clear(0.6)

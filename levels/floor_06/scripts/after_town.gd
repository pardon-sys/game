class_name AfterTown
extends Node2D
## 地下小镇·战后（floor_06_after，七日赎罪）的导演：
##   蓝色公主跟着粉色公主（这张图 no_switch，不能换人；和她说话是 floor_06/after_partner），节点改名 AfterBlue（过场里用）。
##   镇民（对话文件 floor_06/after_*）的节点改名成对话文件名（after_captain……：过场里直接用这个名字指挥他们），
##   按 DayClock 的日程摆位置 / 换朝向 / 藏起来（apply_schedule）；时间变了（DayClock.TICK）、某个时段的事做完了、过场放完，都重新摆一次。
##   进图：第一次进来 = 第 1 天早上（AfterStory.begin），然后演这里自动演的事件（AfterStory.run_pending）。
##   目标提示（ObjectiveMarker）：AfterStory.objective 给的目标；走进目标圈（trigger）就演那个事件（AfterStory.trigger）。
##   镇民委托（AfterErrands）：能接委托的人头上冒「！」；接下以后摆上玩法节点（errand_<kind>.gd），目标换成委托的目标。
## 图例：X = f6after

const PARTNER := "floor_06/after_partner"
const PREFIX := "floor_06/after_"
## 藏起来的镇民：show_flag 设成一个永远不会有的标记
const NEVER := "after_never"

## 对话文件名 -> Resident
var residents := {}
var blue: PlayableCharacter
var marker: ObjectiveMarker
var _objective := {}


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var lv := _level()
	if lv == null:
		return
	_setup(lv)
	AfterStory.begin()
	apply_schedule()
	marker = ObjectiveMarker.new()
	marker.name = "Objective"
	marker.extra = AfterErrands.status_text
	lv.get_node("Entities").add_child(marker)
	AfterErrands.refresh()
	_sync_errand()
	refresh_objective()
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
	if flag == DayClock.TICK or flag == PenanceBook.FLAG:
		AfterErrands.refresh()
	if flag == DayClock.TICK or flag.begins_with("after_") or flag.begins_with("errand_") or flag == PenanceBook.FLAG:
		refresh_objective.call_deferred()
		_sync_errand.call_deferred()


func refresh_objective() -> void:
	if not is_instance_valid(marker):
		return
	var e := AfterErrands.objective(AfterStory.TOWN)
	_objective = e if not e.is_empty() else AfterStory.objective(AfterStory.TOWN)
	marker.set_target(_objective)


## 委托：正在做的那个摆上玩法节点（做完 / 失败时节点自己删掉）；能接委托的镇民头上冒「！」。
func _sync_errand() -> void:
	if not is_inside_tree():
		return
	var lv := _level()
	var ents := lv.get_node("Entities") if lv else null
	if ents == null:
		return
	var id := AfterErrands.active()
	if id != "" and ents.get_node_or_null("Errand_" + id) == null:
		var runner := AfterErrands.make_runner(id)
		if runner:
			ents.add_child(runner)
	for key in residents:
		var r: Resident = residents[key]
		if not is_instance_valid(r):
			continue
		var want := false
		for eid in AfterErrands.ids():
			if str(AfterErrands.info(str(eid)).get("npc", "")) == key and GameState.has_flag("errand_%s_open" % eid):
				want = true
		var mark := r.get_node_or_null("ErrandMark") as Label
		if want and mark == null:
			mark = Label.new()
			mark.name = "ErrandMark"
			mark.text = "！"
			mark.add_theme_font_size_override("font_size", 12)
			mark.add_theme_color_override("font_color", Color(1, 0.86, 0.3))
			mark.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.1))
			mark.add_theme_constant_override("outline_size", 3)
			mark.position = Vector2(-5, -46)
			r.add_child(mark)
		elif not want and mark:
			mark.queue_free()


## 走进目标圈：演那个事件。
func _process(_delta: float) -> void:
	if not bool(_objective.get("trigger", false)) or AfterStory.running or DayClock.passing:
		return
	if GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(GameState.player):
		return
	var at: Vector2 = Cutscene.cell_to_world(_objective["cell"])
	if GameState.player.global_position.distance_to(at) <= float(_objective.get("radius", 1.0)) * 16.0:
		_objective = {}
		await AfterStory.trigger(AfterStory.TOWN)
		refresh_objective()


## 过场放完：镇民回到日程上的位置；过场留下的黑幕（end_dark）在这里揭开——要是紧接着要过一段时间（DayClock.pass_time）就交给它揭。
func _on_cutscene_finished(_id: String) -> void:
	if not is_inside_tree():
		return
	apply_schedule()
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree() and not DayClock.passing and not Cutscene.is_playing():
		Cutscene.curtain_clear(0.6)

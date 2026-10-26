class_name KnightQuests
extends RefCounted
## 骑士篇的四个支线（数据 data/after/knight_quests.json ← tools/build/knight_text/quests.py）：可选，彼此相连、和主线相连，最后在 Boss 战里汇集——
##   每个支线做完（kq_<id>_done），那个人在 Boss 最后阶段来帮忙点亮一盏笑声灯笼（helper）。
##   开放（kq_<id>_open，委托人头上冒「！」）：骑士篇的步骤下标在 [opens_at, closes_at) 里、时段在 slots 里、没做完、现在没有别的支线在做。
##   接下（对话 set {vars: {kq_req}, call: kq_start}）：kq_<id>_active + kq_active，阶段 vars.kq_<id>_stage 从 0 开始；有 start_cut 就先演。
##   做的时候：导演（AfterRoom._sync_quest）在这一段所在的图上摆玩法节点（RUNNERS[id]，节点名 Quest_<id>）；玩法节点自己推进阶段（advance）、做完（complete）。
##   最后一段写了 report 的：回去找委托人说话（call: kq_report）才算做完。可以先放一放（call: kq_abandon：阶段清零，回到能接）。
##   一次只能做一个支线；做支线的时候主线的触发不出现（对话条件 not kq_active），床上不能休息 / 睡觉。
## 测试：start(id)、advance(id)、complete(id)、stage(id)、refresh()。

const PATH := "res://data/after/knight_quests.json"
const ACTIVE_FLAG := "kq_active"
## 每个支线的玩法节点（在这一段所在的图上摆；脚本的静态 runs_on(floor_id, stage) 决定摆不摆）
const RUNNERS := {
	"shoes": "res://levels/floor_06/scripts/quest_shoes.gd",
	"samples": "res://levels/floor_06/scripts/quest_samples.gd",
	"spear": "res://levels/floor_06/scripts/quest_spear.gd",
	"fence": "res://levels/floor_06/scripts/quest_fence.gd",
}

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = parsed.get("quests", {}) if parsed is Dictionary else {}
	return _data


static func ids() -> Array:
	return data().keys()


static func info(id: String) -> Dictionary:
	return data().get(id, {})


static func is_done(id: String) -> bool:
	return GameState.has_flag("kq_%s_done" % id)


static func is_active(id: String) -> bool:
	return GameState.has_flag("kq_%s_active" % id)


static func active() -> String:
	for id in ids():
		if is_active(str(id)):
			return str(id)
	return ""


static func stage(id: String) -> int:
	return int(GameState.vars.get("kq_%s_stage" % id, 0))


static func stage_info(id: String) -> Dictionary:
	var st: Array = info(id).get("stages", [])
	var i := stage(id)
	return st[i] if i < st.size() else {}


## 这个支线现在的时间窗口里能不能做（步骤、时段）
static func in_window(id: String) -> bool:
	if not KnightStory.active():
		return false
	var q := info(id)
	var i := KnightStory.step_index()
	if i < KnightStory.index_of(str(q.get("opens_at", ""))) or i >= KnightStory.index_of(str(q.get("closes_at", ""))):
		return false
	# JSON 里的数字读出来是 float，Array.has 不把 0 和 0.0 当成一样：逐个比
	return (q.get("slots", []) as Array).any(func(s): return int(s) == DayClock.slot())


static func is_open(id: String) -> bool:
	return in_window(id) and not is_done(id) and not is_active(id) and active() == ""


## 按现在的步骤 / 时段刷新 kq_<id>_open 和这一段才开的门（导演在步骤变了、时段变了时调；推进阶段时也调）
static func refresh() -> void:
	for id in ids():
		var want := is_open(str(id))
		if GameState.has_flag("kq_%s_open" % id) != want:
			GameState.set_flag("kq_%s_open" % id, want)
	# 这一段才开的门（stages[].unlock：比如工房的地窖）
	for id in ids():
		var st: Array = info(str(id)).get("stages", [])
		for i in st.size():
			var flag := str((st[i] as Dictionary).get("unlock", ""))
			if flag != "":
				var on := is_active(str(id)) and stage(str(id)) == i
				if GameState.has_flag(flag) != on:
					GameState.set_flag(flag, on)
	# 进行中的支线错过了时间窗口（比如夜里的栅栏到第二天）：自动放下，回到能接（窗口过了也就不会再开）
	var a := active()
	if a != "" and not in_window(a) and not KnightStory.running:
		abandon(a)


## 头上冒「！」的人：能接的支线的委托人；进行中、最后一段要回去找他的委托人
static func marked_npcs() -> Array:
	var out := []
	for id in ids():
		var q := info(str(id))
		if is_open(str(id)) or (is_active(str(id)) and bool(stage_info(str(id)).get("report", false))):
			out.append(str(q.get("npc", "")))
	return out


static func start(id: String) -> void:
	if not is_open(id):
		return
	GameState.vars["kq_%s_stage" % id] = 0
	GameState.set_flag("kq_%s_active" % id)
	GameState.set_flag(ACTIVE_FLAG)
	refresh()
	var cut := str(info(id).get("start_cut", ""))
	if cut != "" and Cutscene.has_cutscene(cut):
		await TrainingDB.wait_dialogue_free()
		await Cutscene.play(cut)
	_changed()


## 这一段做完：阶段 +1（到头了就做完）
static func advance(id: String) -> void:
	if not is_active(id):
		return
	GameState.vars["kq_%s_stage" % id] = stage(id) + 1
	if stage(id) >= (info(id).get("stages", []) as Array).size():
		await complete(id)
		return
	_changed()


## 做完：标记、奖励、收尾过场
static func complete(id: String) -> void:
	if not is_active(id):
		return
	GameState.set_flag("kq_%s_active" % id, false)
	GameState.set_flag(ACTIVE_FLAG, false)
	GameState.set_flag("kq_%s_done" % id)
	var rewards: Dictionary = info(id).get("reward", {})
	var cut := str(info(id).get("done_cut", ""))
	if cut != "" and Cutscene.has_cutscene(cut):
		await TrainingDB.wait_dialogue_free()
		await Cutscene.play(cut)
	for item in rewards:
		var it := ItemDB.get_item(str(item))
		if it:
			GameState.give_item(it, int(rewards[item]))
	GameState.hint("支线「%s」完成" % str(info(id).get("name", "")))
	refresh()
	_changed()


## 先放一放：阶段清零、玩法节点收走，回到能接
static func abandon(id: String) -> void:
	if not is_active(id):
		return
	GameState.set_flag("kq_%s_active" % id, false)
	GameState.set_flag(ACTIVE_FLAG, false)
	GameState.vars["kq_%s_stage" % id] = 0
	var scr := _runner_script(id)
	if scr and scr.has_method("reset_items"):
		scr.call("reset_items")
	refresh()
	_changed()


## 进行中的支线的目标提示（这一段在别的图：指过去）
static func objective(floor_id: String) -> Dictionary:
	var id := active()
	if id == "":
		return {}
	var st := stage_info(id)
	var text := str(st.get("text", info(id).get("name", "")))
	var scr := _runner_script(id)
	if scr and scr.has_method("objective_text"):
		text = str(scr.call("objective_text", text))
	var where := str(st.get("where", ""))
	if where == floor_id:
		var c: Array = st.get("cell", [])
		return {"text": text, "cell": c, "radius": 1.0} if c.size() == 2 else {"text": text}
	return KnightStory.guide(floor_id, where, text)


## 进行中的支线在目标下面显示的实时状态（这张图上的玩法节点有 status() 的话）
static func status_text() -> String:
	var id := active()
	if id == "" or not StoryDirector.instance:
		return ""
	var lv: Node = StoryDirector.instance.main.get("level")
	var n: Node = lv.get_node_or_null("Entities/Quest_" + id) if lv else null
	return str(n.call("status")) if n and n.has_method("status") else ""


## 主线目标后面挂的一句：还开着、没做完的支线
static func open_text() -> String:
	var names := []
	for id in ids():
		if is_open(str(id)):
			names.append(str(info(str(id)).get("name", "")))
	return "" if names.is_empty() else "（支线：%s）" % "、".join(names)


## 玩法节点：这一段在这张图上的话，造一个（导演摆进 Entities）
static func make_runner(floor_id: String) -> Node:
	var id := active()
	if id == "":
		return null
	var scr := _runner_script(id)
	if scr == null or not bool(scr.call("runs_on", floor_id, stage(id))):
		return null
	var n: Node = scr.new()
	n.name = "Quest_" + id
	return n


## Boss 最后阶段：做过的支线来帮忙的人（灯笼顺序：shoes、samples、spear、fence）
static func helpers() -> Array:
	return ["shoes", "samples", "spear", "fence"].filter(func(id): return is_done(id))


static func _runner_script(id: String) -> Script:
	return load(RUNNERS[id]) if RUNNERS.has(id) and ResourceLoader.exists(RUNNERS[id]) else null


static func _changed() -> void:
	refresh()
	GameState.flag_changed.emit(KnightStory.STEP_CHANGED)

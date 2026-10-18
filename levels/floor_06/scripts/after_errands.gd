class_name AfterErrands
extends RefCounted
## 七日赎罪的小日常：镇民委托（数据 data/after/errands.json，tools/build/gen_floor06_after.py 从 after_text/errands.py 生成）。
##   每个委托：{name 名字, npc 谁委托的（对话文件名）, from [天, 时段] 从什么时候开始能接, hours 做完减几工时, kind 玩法, objective 目标文字}。
##   有赎罪簿以后、白天（早上 / 下午）、到了 from 的时段、还没做完 → 开放（剧情标记 errand_<id>_open：那个镇民头上冒「！」，对话里能接）。
##   接下：errand_<id>_active，导演把玩法节点（ErrandCookies / ErrandApples……）摆进地图；做完 complete()：errand_<id>_done、减工时。
##   失败不播小剧场：当场被挠一下，委托回到能接的状态（fail）。一次只能接一个。
##   对话里接委托：set {vars: {errand_req: <id>}, call: errand_start}。

const PATH := "res://data/after/errands.json"
const RUNNERS := {"cookies": "res://levels/floor_06/scripts/errand_cookies.gd", "apples": "res://levels/floor_06/scripts/errand_apples.gd"}

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = parsed if parsed is Dictionary else {}
	return _data


static func info(id: String) -> Dictionary:
	return data().get("errands", {}).get(id, {})


static func ids() -> Array:
	return data().get("errands", {}).keys()


static func is_done(id: String) -> bool:
	return GameState.has_flag("errand_%s_done" % id)


static func is_active(id: String) -> bool:
	return GameState.has_flag("errand_%s_active" % id)


## 正在做的委托（没有返回 ""）。
static func active() -> String:
	for id in ids():
		if is_active(str(id)):
			return str(id)
	return ""


## 现在能不能接（不算「已经有别的委托在做」）。
static func is_open(id: String) -> bool:
	if not PenanceBook.started() or is_done(id) or is_active(id) or DayClock.slot() == DayClock.NIGHT or GameState.has_flag(AfterStory.TASK_FLAG):
		return false
	var from: Array = info(id).get("from", [99, 0])
	return DayClock.day() * 3 + DayClock.slot() >= int(from[0]) * 3 + int(from[1])


## 时间变了 / 委托状态变了：重算开放标记（对话的 entries 读它们）。
static func refresh() -> void:
	var busy := active() != ""
	for id in ids():
		var want := is_open(str(id)) and not busy
		var flag := "errand_%s_open" % id
		if GameState.has_flag(flag) != want:
			GameState.set_flag(flag, want)


static func start(id: String) -> void:
	if info(id).is_empty() or active() != "":
		return
	GameState.set_flag("errand_%s_active" % id)
	refresh()
	GameState.hint("委托：" + str(info(id).get("name", id)))


static func complete(id: String, note := "") -> void:
	if not is_active(id):
		return
	GameState.set_flag("errand_%s_active" % id, false)
	GameState.set_flag("errand_%s_done" % id)
	var hrs := int(info(id).get("hours", 2))
	PenanceBook.add(-hrs, "委托：" + str(info(id).get("name", id)) + note)
	refresh()


## 失败：委托回到能接的状态（再去找委托人说话就能重来）。
static func fail(id: String, why: String) -> void:
	if not is_active(id):
		return
	GameState.set_flag("errand_%s_active" % id, false)
	refresh()
	GameState.notify(why)


## 做委托时的目标（盖在剧情目标上面）：{text, cell, radius}；没有返回 {}。
static func objective(floor_id: String) -> Dictionary:
	var id := active()
	if id == "" or floor_id != AfterStory.TOWN:
		return {}
	var inf := info(id)
	var out := {"text": "委托：%s" % inf.get("objective", inf.get("name", id))}
	if inf.has("target"):
		out["cell"] = inf["target"]
		out["radius"] = 1.0
	return out


## 正在做的委托的实时状态（目标提示下面一行）
static func status_text() -> String:
	match active():
		"cookies":
			return "篮子里的饼干：%d 块" % int(GameState.vars.get("errand_cookies_left", 0))
		"apples":
			return str(GameState.vars.get("errand_apples_text", ""))
	return ""


## 地图上的玩法节点（正在做这个委托时导演摆进来）。
static func make_runner(id: String) -> Node2D:
	var kind := str(info(id).get("kind", ""))
	if not RUNNERS.has(kind):
		return null
	var n: Node2D = load(RUNNERS[kind]).new()
	n.set("errand_id", id)
	n.name = "Errand_" + id
	return n

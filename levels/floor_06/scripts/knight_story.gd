class_name KnightStory
extends RefCounted
## 骑士篇（七日赎罪之后，还在地下小镇）的剧情调度：连续推进，不分天。小镇用骑士篇自己的三张图（布局同战后小镇，人物各自摆、不挂委托，导演 AfterRoom）：
##   KDAY 白天（发现骑士、抬担架）/ KNIGHT_N 夜里（以笑为饵、溜进地牢）/ KCHASE 诅咒失控（追逃、Boss；一个镇民都没有）。
##   从小屋 / 工房 / 地牢的门回「小镇」时，换图会被转到这一步对应的那张（redirect：步骤的 where 是小镇图就用它，不然用 town）。
## 沿用七日赎罪的小屋、工房、导演（AfterHouse / AfterRoom）、目标提示和任务的跑法（AfterStory.play_task）——
## 骑士篇开始以后（knight_started），AfterStory 的 objective / 触发 / 状态都转到这里。
##   STEPS 按顺序推进（vars.knight_step）。每一步：
##     where 哪张图、town 不在小镇图上的步骤回小镇时去哪张、auto（进图就演）或 spot [格x, 格y, 半径格]（走进圈才演）、slot 这一步的时段（早 / 夜，换灯光和镇民的位置）、objective 目标文字、
##     cutscene 开场过场、task 玩法（同 AfterStory.TASKS 的写法：script / name / fail / fail_hours / respawn）、done 收尾过场、
##     goto [图, 出生点] 做完去哪；away：人还不在那张图上时的目标文字（比如还在工房里：「出门透透气」）；
##     sleep_first：先回小屋的床上睡一觉才开始（睡觉不显示黑幕标题，醒来就是早上，接着自动演）。
##   时间自然变化：不用黑幕换时段——进小镇图时按这一步的 slot 直接换成早 / 夜（sync_slot），睡觉在床上（AfterStory.sleep → sleep_now）。
##   时钟：骑士篇的第几天记在 DayClock 的 after_day（DAY 起），标签写「骑士篇·时段」（DayClock.label）。没有赎罪簿和工时。
##   蓝色公主一直跟着（AfterBlueRoutine.invited_today）。
## 开始：第 7 天庆功宴放完烟花、回小屋睡觉（AfterStory.sleep → begin）。
## 测试：jump(步骤 id)、step_id()、STEPS。

const STARTED := "knight_started"
const STEP_VAR := "knight_step"
## 步骤变了的时候发的 flag_changed（以 after_ 开头：导演会刷新目标）
const STEP_CHANGED := "after_knight_step"
const DAY := 8
const TOWN := "floor_06_after"
const KDAY := "floor_06_knight_day"
const KNIGHT_N := "floor_06_knight_night"
const KCHASE := "floor_06_knight_chase"
const TOWNS := [KDAY, KNIGHT_N, KCHASE]
## 小镇图上通往各处的门口（指路用，三张小镇图布局相同）、各处回小镇的出口
const DOORS := {"floor_06_after_house": [42, 10], "floor_06_after_pharmacy": [16, 10]}
const EXITS := {"floor_06_after_house": [9, 10], "floor_06_after_pharmacy": [8, 8.5]}
const HOUSE := "floor_06_after_house"
const PHARMACY := "floor_06_after_pharmacy"
const PRISON := "floor_06_after_prison"
const MORNING := 0
const NIGHT := 2
const STEPS := [
	{"id": "morning", "where": HOUSE, "town": KDAY, "auto": true, "slot": MORNING, "cutscene": "knight_morning", "objective": "去东北角的地牢入口"},
	{"id": "found", "where": KDAY, "spot": [53, 8, 2], "slot": MORNING, "objective": "去东北角的地牢入口（矿道口旁边）", "cutscene": "knight_found",
		"task": {"script": "res://levels/floor_06/scripts/task_stretcher.gd", "name": "抬担架", "fail": "knight_fail_stretcher", "fail_hours": 0, "respawn": [52, 9]},
		"done": "knight_carry_done", "goto": [PHARMACY, "from_town"]},
	{"id": "wake", "where": PHARMACY, "town": KDAY, "auto": true, "slot": MORNING, "cutscene": "knight_wake", "objective": ""},
	{"id": "bait", "where": KNIGHT_N, "auto": true, "slot": NIGHT, "objective": "夜里的广场好像出事了，去看看", "away": "出门透透气（天已经黑了）",
		"cutscene": "knight_bait_open",
		"task": {"script": "res://levels/floor_06/scripts/task_bait.gd", "name": "以笑为饵", "fail": "knight_fail_bait", "fail_hours": 0, "respawn": [33, 27]},
		"done": "knight_bait_done"},
	{"id": "sneak", "where": KNIGHT_N, "spot": [58, 39, 1.5], "slot": NIGHT, "objective": "去东南角营地楼梯的路障后面，从通风口溜进地牢",
		"cutscene": "knight_sneak_open", "goto": [PRISON, "vent"]},
	{"id": "cell", "where": PRISON, "town": KNIGHT_N, "auto": true, "slot": NIGHT, "objective": "躲开巡逻，去最里面那间牢房",
		"task": {"script": "res://levels/floor_06/scripts/task_sneak.gd", "name": "夜探地牢", "fail": "", "fail_hours": 0},
		"done": "knight_cell_end", "goto": [HOUSE, "from_town"]},
	{"id": "erupt", "where": HOUSE, "town": KCHASE, "auto": true, "sleep_first": true, "slot": MORNING, "cutscene": "knight_erupt", "objective": "",
		"goto": [KCHASE, "from_house"]},
	{"id": "chase", "where": KCHASE, "auto": true, "slot": MORNING, "cutscene": "knight_chase_open", "objective": "把盔甲引到广场的图腾柱下",
		"task": {"script": "res://levels/floor_06/scripts/task_armor_chase.gd", "name": "镇中追逃", "fail": "knight_fail_chase", "fail_hours": 0, "respawn": [55, 37]}},
	{"id": "boss", "where": KCHASE, "auto": true, "slot": MORNING, "cutscene": "knight_boss_open", "objective": "打碎盔甲上的诅咒",
		"task": {"script": "res://levels/floor_06/scripts/task_knight_boss.gd", "name": "痒铠骑士", "fail": "knight_fail_boss", "fail_hours": 0, "respawn": [41, 29]},
		"done": "knight_epilogue"},
]

static var running := false


static func active() -> bool:
	return GameState.has_flag(STARTED)


static func step_index() -> int:
	return int(GameState.vars.get(STEP_VAR, 0))


static func step() -> Dictionary:
	var i := step_index()
	return STEPS[i] if i < STEPS.size() else {}


static func step_id() -> String:
	return str(step().get("id", ""))


## 庆功宴之后睡一觉：骑士篇开始（第二天早上，小屋里自动演开场）
static func begin() -> void:
	if active():
		return
	GameState.set_flag(STARTED)
	GameState.vars[STEP_VAR] = 0
	await Sleep.sleep("", "", func():
		DayClock.set_time(DAY, MORNING)
		Cutscene.curtain_clear(0.01), false)
	await try_step(HOUSE, false)


## 测试 / 跳关：直接跳到某一步（时段跟着换）
static func jump(id: String) -> void:
	GameState.set_flag(STARTED)
	for i in STEPS.size():
		if str(STEPS[i]["id"]) == id:
			GameState.vars[STEP_VAR] = i
			DayClock.set_time(maxi(DAY, DayClock.day()), int(STEPS[i].get("slot", MORNING)))
			return


## 现在回「小镇」该去哪张骑士篇的小镇图
static func town_now() -> String:
	var s := step()
	if s.is_empty():
		return KDAY
	var where := str(s["where"])
	return where if where in TOWNS else str(s.get("town", KDAY))


## 换图时：骑士篇里去旧小镇（七日赎罪的 floor_06_after，镇民委托还在上面）→ 转到这一步的骑士篇小镇
static func redirect(path: String) -> String:
	if active() and path == Floors.scene(TOWN):
		return Floors.scene(town_now())
	return path


static func objective(floor_id: String) -> Dictionary:
	var s := step()
	if s.is_empty():
		return {"text": "（骑士篇的后续还在制作中……）"}
	if GameState.has_flag(AfterStory.TASK_FLAG):
		return {"text": str(s.get("task", {}).get("name", ""))}
	if needs_sleep():
		if floor_id == HOUSE:
			return {"text": "回床上睡觉", "cell": AfterStory.HOUSE_BED, "radius": 1.0}
		return _guide(floor_id, HOUSE, "回小屋睡觉")
	var text := str(s.get("objective", ""))
	var where := str(s["where"])
	if where != floor_id and s.has("away"):
		text = str(s["away"])
	if where == floor_id:
		if s.has("spot"):
			var sp: Array = s["spot"]
			return {"text": text, "cell": [sp[0], sp[1]], "radius": float(sp[2]), "trigger": true}
		return {"text": text} if text != "" else {}
	return _guide(floor_id, where, text)


## 目标在别的图：小镇图上指向那张图的门口（地牢走营地楼梯后面的通风口，算小镇图上的 spot）；别的图上指向回小镇的出口
static func _guide(floor_id: String, where: String, text: String) -> Dictionary:
	if floor_id in TOWNS and DOORS.has(where):
		return {"text": text, "cell": DOORS[where], "radius": 1.0}
	if not floor_id in TOWNS and where in TOWNS and EXITS.has(floor_id):
		return {"text": text, "cell": EXITS[floor_id], "radius": 1.0}
	return {"text": text}


static func status_text() -> String:
	if not GameState.has_flag(AfterStory.TASK_FLAG):
		return ""
	var task: Dictionary = step().get("task", {})
	return str(load(str(task["script"])).call("status_text")) if not task.is_empty() else ""


## 这一步要先回床上睡一觉（还没到早上）
static func needs_sleep() -> bool:
	return bool(step().get("sleep_first", false)) and DayClock.slot() != MORNING


## 床：骑士篇里能不能睡（AfterStory.sleep 问）
static func can_sleep() -> bool:
	return active() and needs_sleep()


## 在床上睡一觉（不显示黑幕标题）→ 早上 → 这一步接着演
static func sleep_now() -> void:
	await Sleep.sleep("", "", func():
		DayClock.set_time(DayClock.day() + 1, MORNING)
		Cutscene.curtain_clear(0.01), false)
	await try_step(HOUSE, false)


## 进小镇图：按这一步的时段直接换成早 / 夜（不用黑幕）——比如工房里醒来以后出门，外面已经是夜里了
static func sync_slot(floor_id: String) -> void:
	if not active() or not floor_id in TOWNS:
		return
	var s := step()
	var want := int(s.get("slot", DayClock.slot())) if not s.is_empty() else DayClock.slot()
	if str(s.get("where", "")) != floor_id and str(s.get("town", "")) != floor_id:
		return
	if DayClock.slot() != want:
		DayClock.set_time(DayClock.day(), want)
		if want == NIGHT:
			GameState.hint("天已经黑了。")


## 进图（auto）/ 走进目标圈（spot）：演这一步
static func try_step(floor_id: String, by_spot: bool) -> void:
	if not by_spot:
		sync_slot(floor_id)
	if running or not active():
		return
	var s := step()
	if s.is_empty() or str(s["where"]) != floor_id or bool(s.get("auto", false)) == by_spot:
		return
	if needs_sleep():
		return
	running = true
	await TrainingDB.wait_dialogue_free()
	await _run(s)
	running = false


static func _run(s: Dictionary) -> void:
	if str(s.get("cutscene", "")) != "":
		await Cutscene.play(str(s["cutscene"]))
	var task: Dictionary = s.get("task", {})
	if not task.is_empty():
		if not await AfterStory.play_task(str(s["id"]), task):
			return
	if str(s.get("done", "")) != "":
		await Cutscene.play(str(s["done"]))
	GameState.vars[STEP_VAR] = step_index() + 1
	# 步骤记在变量里，不是标记：手动发一下「变了」，导演（AfterRoom / AfterHouse）刷新目标
	GameState.flag_changed.emit(STEP_CHANGED)
	if s.has("goto"):
		await _go(s["goto"])
	# 下一步就在现在这张图、进图就演的：接着演（诅咒失控 → 追逃 → Boss）
	var next := step()
	var here: Node = StoryDirector.instance.main.get("level") if StoryDirector.instance else null
	if not next.is_empty() and bool(next.get("auto", false)) and here and str(here.get("floor_id")) == str(next["where"]):
		running = false
		await try_step(str(next["where"]), false)


static func _go(target: Array) -> void:
	if StoryDirector.instance:
		await StoryDirector.instance.run_sequence([{"level": str(target[0]), "spawn": str(target[1])}])

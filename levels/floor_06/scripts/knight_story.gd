class_name KnightStory
extends RefCounted
## 骑士篇（七日赎罪之后，还在地下小镇）的剧情调度：连续推进，不分天。沿用七日赎罪的地图、导演（AfterTown / AfterHouse / AfterRoom）、
## 目标提示和任务的跑法（AfterStory.play_task）——骑士篇开始以后（knight_started），AfterStory 的 objective / 触发 / 状态都转到这里。
##   STEPS 按顺序推进（vars.knight_step）。每一步：
##     where 哪张图、auto（进图就演）或 spot [格x, 格y, 半径格]（走进圈才演）、slot 这一步的时段（早 / 夜，换灯光和镇民的位置）、objective 目标文字、
##     cutscene 开场过场、task 玩法（同 AfterStory.TASKS 的写法：script / name / fail / fail_hours / respawn）、done 收尾过场、
##     then_slot 做完换时段、goto [图, 出生点] 做完去哪、sleep 做完回床上睡到第二天早上。
##   时钟：骑士篇的第几天记在 DayClock 的 after_day（DAY 起），标签写「骑士篇·时段」（DayClock.label）。没有赎罪簿和工时。
##   蓝色公主一直跟着（AfterBlueRoutine.invited_today）。
## 开始：第 7 天庆功宴放完烟花、回小屋睡觉（AfterStory.sleep → begin）。
## 测试：jump(步骤 id)、step_id()、STEPS。

const STARTED := "knight_started"
const STEP_VAR := "knight_step"
const DAY := 8
const TOWN := "floor_06_after"
const HOUSE := "floor_06_after_house"
const PHARMACY := "floor_06_after_pharmacy"
const PRISON := "floor_06_after_prison"
const MORNING := 0
const NIGHT := 2
const STEPS := [
	{"id": "morning", "where": HOUSE, "auto": true, "slot": MORNING, "cutscene": "knight_morning", "objective": "去东北角的地牢入口"},
	{"id": "found", "where": TOWN, "spot": [53, 8, 2], "slot": MORNING, "objective": "去东北角的地牢入口（矿道口旁边）", "cutscene": "knight_found",
		"task": {"script": "res://levels/floor_06/scripts/task_stretcher.gd", "name": "抬担架", "fail": "knight_fail_stretcher", "fail_hours": 0, "respawn": [52, 9]},
		"done": "knight_carry_done", "goto": [PHARMACY, "from_town"]},
	{"id": "wake", "where": PHARMACY, "auto": true, "slot": MORNING, "cutscene": "knight_wake", "objective": "", "then_slot": NIGHT},
	{"id": "bait", "where": TOWN, "spot": [33, 26, 2], "slot": NIGHT, "objective": "夜里的广场好像出事了，去看看", "cutscene": "knight_bait_open",
		"task": {"script": "res://levels/floor_06/scripts/task_bait.gd", "name": "以笑为饵", "fail": "knight_fail_bait", "fail_hours": 0, "respawn": [33, 27]},
		"done": "knight_bait_done"},
	{"id": "sneak", "where": TOWN, "spot": [58, 39, 1.5], "slot": NIGHT, "objective": "去东南角营地楼梯的路障后面，从通风口溜进地牢",
		"cutscene": "knight_sneak_open", "goto": [PRISON, "vent"]},
	{"id": "cell", "where": PRISON, "auto": true, "slot": NIGHT, "objective": "躲开巡逻，去最里面那间牢房",
		"task": {"script": "res://levels/floor_06/scripts/task_sneak.gd", "name": "夜探地牢", "fail": "", "fail_hours": 0},
		"done": "knight_cell_end", "goto": [HOUSE, "bed"], "sleep": true},
	{"id": "erupt", "where": HOUSE, "auto": true, "slot": MORNING, "cutscene": "knight_erupt", "objective": "", "goto": [TOWN, "from_house"]},
	{"id": "chase", "where": TOWN, "auto": true, "slot": MORNING, "cutscene": "knight_chase_open", "objective": "把盔甲引到广场的图腾柱下",
		"task": {"script": "res://levels/floor_06/scripts/task_armor_chase.gd", "name": "镇中追逃", "fail": "knight_fail_chase", "fail_hours": 0, "respawn": [55, 37]}},
	{"id": "boss", "where": TOWN, "auto": true, "slot": MORNING, "cutscene": "knight_boss_open", "objective": "打碎盔甲上的诅咒",
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
	await Sleep.sleep("", "骑士篇", func():
		DayClock.set_time(DAY, MORNING)
		Cutscene.curtain_clear(0.01))
	await try_step(HOUSE, false)


## 测试 / 跳关：直接跳到某一步（时段跟着换）
static func jump(id: String) -> void:
	GameState.set_flag(STARTED)
	for i in STEPS.size():
		if str(STEPS[i]["id"]) == id:
			GameState.vars[STEP_VAR] = i
			DayClock.set_time(maxi(DAY, DayClock.day()), int(STEPS[i].get("slot", MORNING)))
			return


static func objective(floor_id: String) -> Dictionary:
	var s := step()
	if s.is_empty():
		return {"text": "（骑士篇的后续还在制作中……）"}
	if GameState.has_flag(AfterStory.TASK_FLAG):
		return {"text": str(s.get("task", {}).get("name", ""))}
	var text := str(s.get("objective", ""))
	var where := str(s["where"])
	if where == floor_id:
		if s.has("spot"):
			var sp: Array = s["spot"]
			return {"text": text, "cell": [sp[0], sp[1]], "radius": float(sp[2]), "trigger": true}
		return {"text": text} if text != "" else {}
	return AfterStory._guide(floor_id, where, text)


static func status_text() -> String:
	if not GameState.has_flag(AfterStory.TASK_FLAG):
		return ""
	var task: Dictionary = step().get("task", {})
	return str(load(str(task["script"])).call("status_text")) if not task.is_empty() else ""


## 进图（auto）/ 走进目标圈（spot）：演这一步
static func try_step(floor_id: String, by_spot: bool) -> void:
	if running or not active():
		return
	var s := step()
	if s.is_empty() or str(s["where"]) != floor_id or bool(s.get("auto", false)) == by_spot:
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
	if s.has("then_slot"):
		await DayClock.pass_time(int(s["then_slot"]))
		if int(s["then_slot"]) == NIGHT:
			GameState.hint("天黑了。")
	if bool(s.get("sleep", false)):
		await _go(s.get("goto", [HOUSE, "bed"]))
		await Sleep.sleep("", "骑士篇", func():
			DayClock.set_time(DayClock.day() + 1, MORNING)
			Cutscene.curtain_clear(0.01))
		await try_step(HOUSE, false)
		return
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

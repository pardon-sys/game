class_name KnightStory
extends RefCounted
## 骑士篇（七日赎罪之后，还在地下小镇）的剧情调度：两天，主线每一步都要玩家主动交互才开始（不再一出门就自动开演），中间可以自由活动、做支线。
##   小镇用骑士篇自己的三张图（布局同战后小镇，人物各自摆、不挂委托，导演 AfterRoom）：
##   KDAY 白天（第一天早上 / 下午、第二天早上）/ KNIGHT_N 夜里（以笑为饵、溜进地牢）/ KCHASE 诅咒失控（追逃、Boss；一个镇民都没有）。
##   从小屋 / 工房 / 地牢的门回「小镇」时，换图会被转到这一步对应的那张（redirect：步骤的 where 是小镇图就用它，不然用 town）。
## 沿用七日赎罪的小屋、工房、导演（AfterHouse / AfterRoom）、目标提示和任务的跑法（AfterStory.play_task）——
## 骑士篇开始以后（knight_started），AfterStory 的 objective / 触发 / 休息 / 睡觉 / 状态都转到这里。
##   STEPS 按顺序推进（vars.knight_step = 下标）。每一步：
##     where 哪张图、town 不在小镇图上的步骤回小镇时去哪张、slot 这一步的时段（早 / 午 / 夜：换灯光和镇民的位置）、objective 目标文字、
##     trigger 怎么开始：
##       talk / inspect  和人（npc：对话文件名，头上冒「！」）说话 / 调查道具：对话里 set {call: knight_go}（生成器往这一步的人物 / 道具对话里注入，条件 eq knight_step = 下标）；cell 目标提示指的格子
##       auto            进图就演（连续的剧情：抬到工房以后醒来、溜进地牢、追逃接 Boss）
##       rest            白天在小屋的床上休息 → 下一个时段（AfterStory.rest → rest_now）
##       sleep           夜里在小屋的床上睡觉 → 第二天早上（AfterStory.sleep → sleep_now，不显示黑幕标题）
##     cutscene 开场过场、story 开场过场后接着演的背景大图过场（剧情回顾）、task 玩法（同 AfterStory.TASKS 的写法：script / name / fail / fail_hours / respawn）、done 收尾过场、
##     goto [图, 出生点] 做完去哪；away：人还不在那张图上时的目标文字。
##   时间自然变化：做完一步，下一步的时段在同一天里更晚时直接换过去；进小镇图时也按这一步的 slot 对齐（sync_slot）。
##   时钟：骑士篇的第几天记在 DayClock 的 after_day（DAY 起），标签写「骑士篇·时段」（DayClock.label）。没有赎罪簿和工时。
##   蓝色公主平时在镇上闲逛，主线任务 / 要她帮忙的支线自己跟上，说话能邀请同行（AfterBlueRoutine）。
##   旧存档（vars.knight_steps_v 不是 VERSION）：按 OLD_IDS 把旧的下标换成同一步在新列表里的下标。
## 开始：第 7 天庆功宴放完烟花、回小屋睡觉（AfterStory.sleep → begin）：睡一觉 → 小屋里醒来（knight_morning）→ 自由活动。
## 测试：jump(步骤 id)、step_id()、go()、STEPS、index_of()。

const STARTED := "knight_started"
const STEP_VAR := "knight_step"
const VERSION_VAR := "knight_steps_v"
const VERSION := 2
## 第一版的步骤（旧存档换算用；morning → found、erupt → report）
const OLD_IDS := ["found", "found", "wake", "bait", "sneak", "cell", "report", "chase", "boss"]
## 步骤变了的时候发的 flag_changed（以 after_ 开头：导演会刷新目标）
const STEP_CHANGED := "after_knight_step"
const DAY := 8
const TOWN := "floor_06_after"
const KDAY := "floor_06_knight_day"
const KNIGHT_N := "floor_06_knight_night"
const KCHASE := "floor_06_knight_chase"
const TOWNS := [KDAY, KNIGHT_N, KCHASE]
## 小镇图上通往各处的门口（指路用，三张小镇图布局相同）、各处回小镇的出口
const DOORS := {"floor_06_after_house": [42, 10], "floor_06_after_pharmacy": [16, 10], "floor_06_after_drill": [8, 10], "floor_06_knight_alley": [2, 16],
	"floor_06_knight_wall": [12, 40], "floor_06_after_crack": [38, 29], "floor_06_after_warehouse": [4, 12],
	"floor_06_knight_storage": [2, 34], "floor_06_knight_bridge": [2, 30]}
const EXITS := {"floor_06_after_house": [9, 10], "floor_06_after_pharmacy": [8, 8.5], "floor_06_after_drill": [10, 11.5], "floor_06_after_cellar": [8, 8.5],
	"floor_06_knight_alley": [2, 5], "floor_06_after_herbcave": [2, 8], "floor_06_knight_wall": [2, 3], "floor_06_after_crack": [2, 2],
	"floor_06_after_oldhall": [13, 17], "floor_06_after_warehouse": [2, 7], "floor_06_knight_storage": [2, 3], "floor_06_knight_bridge": [2, 4]}
## 套在别的图里面的图：子图 → [父图, 父图里通往它的门]（指路一层一层往里指：小镇 → 工房 → 地窖 → 草药洞）
const NESTED := {"floor_06_after_cellar": ["floor_06_after_pharmacy", [12, 8]], "floor_06_after_herbcave": ["floor_06_after_cellar", [13, 5]],
	"floor_06_after_oldhall": ["floor_06_after_crack", [43, 2]]}
const ALLEY := "floor_06_knight_alley"
const HERBCAVE := "floor_06_after_herbcave"
const WALL := "floor_06_knight_wall"
const CRACK := "floor_06_after_crack"
const OLDHALL := "floor_06_after_oldhall"
const WAREHOUSE := "floor_06_after_warehouse"
const STORAGE := "floor_06_knight_storage"
const BRIDGE := "floor_06_knight_bridge"
## 工房里通往地窖的活板门
const CELLAR_DOOR := [12, 8]
const HOUSE := "floor_06_after_house"
const PHARMACY := "floor_06_after_pharmacy"
const PRISON := "floor_06_after_prison"
const CELLAR := "floor_06_after_cellar"
const DRILL := "floor_06_after_drill"
const MORNING := 0
const AFTERNOON := 1
const NIGHT := 2
const STEPS := [
	# 第一天·早上：自由活动；地牢入口那边的队员头上冒「！」，和他说话才开始
	{"id": "found", "where": KDAY, "trigger": "talk", "npc": "after_k_guard_dungeon", "slot": MORNING, "cell": [54, 10],
		"objective": "自由活动（东北角地牢入口那边，好像有个队员在喊人……）", "cutscene": "knight_found",
		"task": {"script": "res://levels/floor_06/scripts/task_stretcher.gd", "name": "抬担架", "fail": "knight_fail_stretcher", "fail_hours": 0, "respawn": [52, 9]},
		"done": "knight_carry_done", "goto": [PHARMACY, "from_town"]},
	{"id": "wake", "where": PHARMACY, "town": KDAY, "trigger": "auto", "slot": MORNING, "cutscene": "knight_wake", "objective": ""},
	# 第一天·下午：自由活动；回小屋的床上休息到晚上
	{"id": "afternoon", "where": HOUSE, "town": KDAY, "trigger": "rest", "slot": AFTERNOON,
		"objective": "自由活动（回小屋的床上，可以休息到晚上）"},
	# 第一天·夜里：调查广场上暗掉的灯笼 → 以笑为饵
	{"id": "bait", "where": KNIGHT_N, "trigger": "inspect", "slot": NIGHT, "cell": [34, 26],
		"objective": "广场上有一盏灯笼暗了下去，去看看", "away": "天黑了，出门看看", "cutscene": "knight_bait_open",
		"task": {"script": "res://levels/floor_06/scripts/task_bait.gd", "name": "以笑为饵", "fail": "knight_fail_bait", "fail_hours": 0, "respawn": [33, 27]},
		"done": "knight_bait_done"},
	# 调查营地楼梯路障后面的通风口 → 夜探地牢
	{"id": "sneak", "where": KNIGHT_N, "trigger": "inspect", "slot": NIGHT, "cell": [58, 38],
		"objective": "去营地楼梯的路障后面，找蓝色公主说的那条路", "cutscene": "knight_sneak_open", "goto": [PRISON, "vent"]},
	{"id": "cell", "where": PRISON, "town": KNIGHT_N, "trigger": "auto", "slot": NIGHT, "objective": "躲开巡逻，去最里面那间牢房",
		"task": {"script": "res://levels/floor_06/scripts/task_sneak.gd", "name": "夜探地牢", "fail": "", "fail_hours": 0},
		"done": "knight_cell_end", "goto": [HOUSE, "from_town"]},
	{"id": "sleep", "where": HOUSE, "town": KNIGHT_N, "trigger": "sleep", "slot": NIGHT, "objective": "回小屋的床上睡觉"},
	# 第二天·早上：自由活动；去营地楼梯口找队长 → 诅咒失控
	{"id": "report", "where": KDAY, "trigger": "talk", "npc": "after_k_guard_camp", "slot": MORNING, "cell": [55, 38],
		"objective": "去营地楼梯口，把昨晚的事告诉队长", "cutscene": "knight_erupt", "goto": [KCHASE, "from_prison"]},
	{"id": "chase", "where": KCHASE, "trigger": "auto", "slot": MORNING, "cutscene": "knight_chase_open", "objective": "把盔甲引到广场的图腾柱下",
		"task": {"script": "res://levels/floor_06/scripts/task_armor_chase.gd", "name": "镇中追逃", "fail": "knight_fail_chase", "fail_hours": 0, "respawn": [55, 37]}},
	{"id": "boss", "where": KCHASE, "trigger": "auto", "slot": MORNING, "cutscene": "knight_boss_open", "objective": "打碎盔甲上的诅咒",
		"story": "story_knight_boss",
		"task": {"script": "res://levels/floor_06/scripts/task_knight_boss.gd", "name": "痒铠骑士", "fail": "knight_fail_boss", "fail_hours": 0, "respawn": [41, 29]},
		"done": "knight_epilogue"},
]

static var running := false


static func active() -> bool:
	return GameState.has_flag(STARTED)


static func index_of(id: String) -> int:
	for i in STEPS.size():
		if str(STEPS[i]["id"]) == id:
			return i
	return -1


static func step_index() -> int:
	var i := int(GameState.vars.get(STEP_VAR, 0))
	if active() and int(GameState.vars.get(VERSION_VAR, 0)) != VERSION:
		# 旧存档：第一版的步骤列表换算过来
		i = index_of(OLD_IDS[i]) if i < OLD_IDS.size() else STEPS.size()
		GameState.vars[STEP_VAR] = i
		GameState.vars[VERSION_VAR] = VERSION
	return i


static func step() -> Dictionary:
	var i := step_index()
	return STEPS[i] if i < STEPS.size() else {}


static func step_id() -> String:
	return str(step().get("id", ""))


static func trigger() -> String:
	return str(step().get("trigger", ""))


## 头上冒「！」的人（对话文件名）：这一步要和他说话的那个（没有在做支线时），加上支线的委托人（KnightQuests）
static func marked_npcs() -> Array:
	var s := step()
	var out: Array = [str(s["npc"])] if trigger() == "talk" and s.has("npc") and KnightQuests.active() == "" else []
	return out + KnightQuests.marked_npcs()


## 庆功宴之后睡一觉：骑士篇开始（第二天早上，小屋里醒来，然后自由活动）
static func begin() -> void:
	if active():
		return
	GameState.set_flag(STARTED)
	GameState.vars[STEP_VAR] = 0
	GameState.vars[VERSION_VAR] = VERSION
	await Sleep.sleep("", "", func():
		DayClock.set_time(DAY, MORNING)
		Cutscene.curtain_clear(0.01), false)
	if Cutscene.has_cutscene("knight_morning"):
		await Cutscene.play("knight_morning")
	_changed()


## 测试 / 跳关：直接跳到某一步（时段跟着换）
static func jump(id: String) -> void:
	GameState.set_flag(STARTED)
	GameState.vars[VERSION_VAR] = VERSION
	var i := index_of(id)
	if i < 0:
		return
	GameState.vars[STEP_VAR] = i
	DayClock.set_time(maxi(DAY, DayClock.day()), int(STEPS[i].get("slot", MORNING)))
	_changed()


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
		# 任务节点自己知道该往哪儿走（追逃：下一座信标 / 广场）→ 指过去
		var out := {"text": str(s.get("task", {}).get("name", ""))}
		var lv: Node = StoryDirector.instance.main.get("level") if StoryDirector.instance else null
		var tk: Node = lv.find_child("Task_*", true, false) if lv else null
		if tk and tk.has_method("target_cell"):
			var c: Vector2i = tk.call("target_cell")
			out["cell"] = [c.x, c.y]
			out["radius"] = 1.0
		return out
	if KnightQuests.active() != "":
		return KnightQuests.objective(floor_id)
	var text := str(s.get("objective", "")) + KnightQuests.open_text()
	var where := str(s["where"])
	if trigger() in ["rest", "sleep"]:
		if floor_id == HOUSE:
			return {"text": text, "cell": AfterStory.HOUSE_BED, "radius": 1.0}
		return guide(floor_id, HOUSE, text)
	if where != floor_id and s.has("away"):
		text = str(s["away"])
	if where == floor_id:
		if s.has("cell"):
			var c: Array = s["cell"]
			return {"text": text, "cell": [c[0], c[1]], "radius": 1.0}
		return {"text": text} if text != "" else {}
	return guide(floor_id, where, text)


## 目标在别的图：小镇图上指向那张图的门口（地窖先指工房的门）；工房里指向地窖的活板门；别的图上指向回去的出口
static func guide(floor_id: String, where: String, text: String) -> Dictionary:
	# 套着的图：一层一层往外找，找到「这张图里通往它的门」就指那扇门
	var w := where
	while NESTED.has(w):
		if NESTED[w][0] == floor_id:
			return {"text": text, "cell": NESTED[w][1], "radius": 1.0}
		w = NESTED[w][0]
	var door := w
	if floor_id in TOWNS and DOORS.has(door):
		return {"text": text, "cell": DOORS[door], "radius": 1.0}
	if floor_id != where and EXITS.has(floor_id):
		return {"text": text, "cell": EXITS[floor_id], "radius": 1.0}
	return {"text": text}


static func status_text() -> String:
	if not GameState.has_flag(AfterStory.TASK_FLAG):
		return KnightQuests.status_text()
	var task: Dictionary = step().get("task", {})
	return str(load(str(task["script"])).call("status_text")) if not task.is_empty() else ""


## 床：骑士篇里能不能睡 / 休息（AfterStory.sleep / rest 问）；在做支线时不行
static func can_sleep() -> bool:
	return active() and trigger() == "sleep" and KnightQuests.active() == ""


static func can_rest() -> bool:
	return active() and trigger() == "rest" and DayClock.slot() != NIGHT and KnightQuests.active() == ""


## 床上睡不了 / 休息不了的时候说什么
static func bed_text() -> String:
	var q := KnightQuests.active()
	if q != "":
		return "（先把「%s」做完吧——不想做了，可以去找委托人先放一放。）" % str(KnightQuests.info(q).get("name", ""))
	return "（现在不是睡觉的时候。）"


## 白天在床上休息：→ 下一个时段，这一步算做完
static func rest_now() -> bool:
	if running or not can_rest():
		return false
	running = true
	var next := step_index() + 1
	var slot := int(STEPS[next].get("slot", NIGHT)) if next < STEPS.size() else NIGHT
	await DayClock.pass_time(maxi(slot, DayClock.slot() + 1))
	running = false
	_advance()
	return true


## 夜里在床上睡一觉（不显示黑幕标题）→ 第二天早上，这一步算做完
static func sleep_now() -> void:
	if running or not can_sleep():
		return
	running = true
	await Sleep.sleep("", "", func():
		DayClock.set_time(DayClock.day() + 1, MORNING)
		Cutscene.curtain_clear(0.01), false)
	running = false
	_advance()


## 进小镇图：按这一步的时段直接换过去（不用黑幕）——比如工房里醒来以后出门，外面已经是下午了
static func sync_slot(floor_id: String) -> void:
	if not active() or not floor_id in TOWNS:
		return
	var s := step()
	if s.is_empty() or (str(s.get("where", "")) != floor_id and str(s.get("town", "")) != floor_id):
		return
	var want := int(s.get("slot", DayClock.slot()))
	if DayClock.slot() != want:
		DayClock.set_time(DayClock.day(), want)
		if want == NIGHT:
			GameState.hint("天已经黑了。")


## 进图：演这一步（只管 auto 的步骤；by_spot 是导演「走进目标圈」的调用，骑士篇没有走进圈就演的步骤了）
static func try_step(floor_id: String, by_spot: bool) -> void:
	if not by_spot:
		sync_slot(floor_id)
	if by_spot or running or not active():
		return
	var s := step()
	if s.is_empty() or str(s["where"]) != floor_id or trigger() != "auto":
		return
	running = true
	await TrainingDB.wait_dialogue_free()
	await _run(s)
	running = false


## 对话里调查 / 说话（call: knight_go）：这一步是 talk / inspect 的就开演。返回开演了没有。
static func go() -> bool:
	if running or not active() or not trigger() in ["talk", "inspect"]:
		return false
	if KnightQuests.active() != "":
		GameState.notify(bed_text())
		return false
	running = true
	await TrainingDB.wait_dialogue_free()
	await _run(step())
	running = false
	return true


## 夜探地牢（cell）中途走出来了：从营地楼梯的通风口钻回去，进图以后任务照常从入口重新开始
static func reenter() -> bool:
	if running or not active() or str(step().get("id", "")) != "cell":
		return false
	await TrainingDB.wait_dialogue_free()
	await _go([PRISON, "vent"])
	return true


static func _run(s: Dictionary) -> void:
	if str(s.get("cutscene", "")) != "":
		await Cutscene.play(str(s["cutscene"]))
	# 背景大图过场（剧情回顾）：开场过场演完、开打之前
	if str(s.get("story", "")) != "" and Cutscene.has_cutscene(str(s["story"])):
		await Cutscene.play(str(s["story"]))
	var task: Dictionary = s.get("task", {})
	if not task.is_empty():
		if not await AfterStory.play_task(str(s["id"]), task):
			return
	if str(s.get("done", "")) != "":
		await Cutscene.play(str(s["done"]))
	_advance()
	if s.has("goto"):
		await _go(s["goto"])
	# 下一步就在现在这张图、进图就演的：接着演（溜进地牢 → 牢房、追逃 → Boss）
	var next := step()
	var here: Node = StoryDirector.instance.main.get("level") if StoryDirector.instance else null
	if not next.is_empty() and str(next.get("trigger", "")) == "auto" and here and str(here.get("floor_id")) == str(next["where"]):
		running = false
		await try_step(str(next["where"]), false)


## 这一步做完：下标 +1；下一步的时段在同一天里更晚的话直接换过去（醒来以后已经是下午）
static func _advance() -> void:
	GameState.vars[STEP_VAR] = step_index() + 1
	var next := step()
	if not next.is_empty() and int(next.get("slot", MORNING)) > DayClock.slot():
		DayClock.set_time(DayClock.day(), int(next["slot"]))
	_changed()


## 步骤记在变量里，不是标记：手动发一下「变了」，导演（AfterRoom / AfterHouse）刷新目标、镇民刷新对话入口
static func _changed() -> void:
	GameState.flag_changed.emit(STEP_CHANGED)


static func _go(target: Array) -> void:
	if StoryDirector.instance:
		await StoryDirector.instance.run_sequence([{"level": str(target[0]), "spawn": str(target[1])}])

class_name AfterStory
extends RefCounted
## 七日赎罪（战后的小镇）的剧情调度：StoryDirector 转过来的钩子 + 两个导演（AfterTown / AfterHouse）进图、时间变了时调 run_pending。
## 时间：DayClock（第几天 + 早 / 午 / 夜，日程 data/after/schedule.json）；赎罪簿：PenanceBook。
## 每天每个时段一个事件（schedule.json 的 days.d<N>.<时段>.event）；在哪张图演由 EVENTS 决定。
## 事件开始时记 after_ev_<id>（演到一半换图不会重来），做完 finish_slot()：记 after_done_d<N>_<时段>，
##   早上做完 → 自动到下午；下午做完 → 提示「天黑前回蓝色小屋」（进小屋 = 天黑，AfterHouse）；夜里做完 → 睡觉 → 第二天早上。
## 第一批（D1）：
##   早  d1_open      战后开场（after_d1_open）：千手痒痒裤当着全体队员发作、队长要砍裤子、私下特训 / 粉色公主做苦力
##   午  d1_verdict   广场宣判（after_d1_verdict）：镇长主持、队长宣读，发赎罪簿（PenanceBook.start）
##   夜  d1_sleepwalk 千手痒痒裤半夜梦游（after_d1_night）：楼下被挠醒 → 调查三处手印（after_house_objects#clue_*）
##                    → 上楼（after_d1_night_end）→ 回床上睡觉
## 旧存档：打赢攻防战之后回到战时小镇的，直接送到战后的小镇。

const TOWN := "floor_06_after"
const HOUSE := "floor_06_after_house"
const HOUSE_UP := "floor_06_after_house_up"
const STARTED := "after_started"
## 事件 id -> {where 在哪张图, cutscene 进图后播的过场}
const EVENTS := {
	"d1_open": {"where": TOWN, "cutscene": "after_d1_open"},
	"d1_verdict": {"where": TOWN, "cutscene": "after_d1_verdict"},
	"d1_sleepwalk": {"where": HOUSE, "cutscene": "after_d1_night"},
}
## 梦游的三处手印都看过了 → 楼梯解锁（after_house_objects 里设）
const CLUES_FLAG := "after_d1_clues"
## 夜里的事件演到一半（床还不能睡）
const NIGHT_BUSY := "after_night_busy"

static var running := false


static func on_level_entered(floor_id: String) -> void:
	if floor_id == "floor_06_war" and GameState.has_flag("siege_won") and not GameState.has_flag(STARTED) and StoryDirector.instance:
		await TrainingDB.wait_dialogue_free()
		if not StoryDirector.instance.sequence_running:
			StoryDirector.instance.run_sequence([{"level": TOWN, "spawn": "from_siege"}])


static func on_talk_finished(_file: String) -> void:
	pass


static func on_cutscene_finished(_id: String) -> void:
	pass


## 第一次进战后的小镇：第 1 天早上。
static func begin() -> void:
	if GameState.has_flag(STARTED):
		return
	GameState.set_flag(STARTED)
	DayClock.set_time(1, DayClock.MORNING)


static func ev_flag(ev: String) -> String:
	return "after_ev_" + ev


## 这张图上现在该演的事件（一个接一个：早上的演完到下午，下午的事件也在这里的话接着演）。
static func run_pending(floor_id: String) -> void:
	if running or not GameState.has_flag(STARTED):
		return
	running = true
	while true:
		var ev := DayClock.event()
		var info: Dictionary = EVENTS.get(ev, {})
		if ev == "" or DayClock.done() or GameState.has_flag(ev_flag(ev)) or str(info.get("where", "")) != floor_id:
			break
		await TrainingDB.wait_dialogue_free()
		GameState.set_flag(ev_flag(ev))
		await _run(ev, info)
	running = false


static func _run(ev: String, info: Dictionary) -> void:
	if str(info.get("cutscene", "")) != "":
		await Cutscene.play(str(info["cutscene"]))
	match ev:
		"d1_open":
			await finish_slot()
		"d1_verdict":
			PenanceBook.start()
			GameState.hint("背包里多了一页「赎罪簿」")
			await finish_slot()
		"d1_sleepwalk":
			GameState.set_flag(NIGHT_BUSY)
			# 被挠醒了：顺着手印调查（三处都看过 → 楼梯解锁 → 楼上 AfterHouse 接 night_end）
			GameState.hint("顺着地上的手印找一找")


## 楼上：梦游的结尾（AfterHouse 进楼上时调）。
static func run_upstairs() -> void:
	if running or DayClock.event() != "d1_sleepwalk" or DayClock.done() or not GameState.has_flag(CLUES_FLAG):
		return
	running = true
	await TrainingDB.wait_dialogue_free()
	await Cutscene.play("after_d1_night_end")
	running = false
	await finish_slot()


## 这个时段的事做完了。
static func finish_slot() -> void:
	var info := DayClock.slot_info()
	DayClock.mark_done()
	var hrs := int(info.get("hours", 0))
	if hrs > 0 and PenanceBook.started():
		PenanceBook.add(-hrs, str(info.get("task", "")))
	match DayClock.slot():
		DayClock.MORNING:
			await DayClock.pass_time(DayClock.AFTERNOON)
		DayClock.AFTERNOON:
			GameState.hint("天黑之前回蓝色小屋")
		DayClock.NIGHT:
			GameState.set_flag(NIGHT_BUSY, false)
			await go_to_bed()


## 夜里的事做完：回楼下的床上睡觉 → 第二天早上。
static func go_to_bed() -> void:
	var lv: Node = StoryDirector.instance.main.get("level") if StoryDirector.instance else null
	if lv and str(lv.get("floor_id")) != HOUSE and StoryDirector.instance:
		await StoryDirector.instance.run_sequence([{"level": HOUSE, "spawn": "bed"}])
	await sleep()


## 床：今天的事做完了才能睡（对话里用 sleep_later）。
static func sleep_later() -> void:
	await TrainingDB.wait_dialogue_free()
	await sleep()


static func sleep() -> void:
	if DayClock.day() >= DayClock.DAYS and DayClock.done(DayClock.DAYS, DayClock.NIGHT):
		return
	await DayClock.sleep()
	await after_wake()


## 早上醒来：今天早上的事件（还没做的）就地开演；这一批还没做的日子先提示一下。
static func after_wake() -> void:
	var lv: Node = StoryDirector.instance.main.get("level") if StoryDirector.instance else null
	if lv:
		await run_pending(str(lv.get("floor_id")))
	if DayClock.event() == "":
		GameState.notify("（%s 的内容还在制作中……可以先在镇上走走）" % DayClock.label())


## 进小屋：白天的事都做完了 → 天黑（再看看夜里的事件）。
static func enter_house() -> void:
	if not GameState.has_flag(STARTED) or running:
		return
	if DayClock.slot() < DayClock.NIGHT and day_work_done():
		await DayClock.pass_time(DayClock.NIGHT)
	await run_pending(HOUSE)


## 今天白天（早上、下午）的事件都做完了（没有事件的时段算做完）。
static func day_work_done() -> bool:
	for s in [DayClock.MORNING, DayClock.AFTERNOON]:
		if DayClock.event(DayClock.day(), s) != "" and not DayClock.done(DayClock.day(), s):
			return false
	return true

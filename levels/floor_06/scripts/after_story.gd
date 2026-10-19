class_name AfterStory
extends RefCounted
## 七日赎罪（战后的小镇）的剧情调度：StoryDirector 转过来的钩子 + 两个导演（AfterTown / AfterHouse）进图、走进触发区时调这里。
## 时间：DayClock（第几天 + 早 / 午 / 夜，日程 data/after/schedule.json）；赎罪簿：PenanceBook。
## 推进方式：自由活动 → 走到目标地点（ObjectiveMarker 指路）→ 演事件 → 推进时段（finish_slot）。
##   每天每个时段最多一个事件（schedule.json 的 days.d<N>.<时段>.event）；EVENTS 写它在哪张图（where）、怎么触发：
##     auto = true          进那张图就演（开场紧接攻防战胜利、夜里进小屋的事件）
##     spot = [格x, 格y, 半径格]  走进这个圈才演
##   objective：目标文字（其他图上会指向那张图的入口：小镇 → 小屋门口，小屋 → 门）。
##   事件开始时记 after_ev_<id>（演到一半换图不会重来），做完 finish_slot()：记 after_done_d<N>_<时段>、还工时，
##   早上 → 下午、下午 → 夜晚（夜里宵禁，目标「回蓝色小屋」）、夜里 → 回床上睡 → 第二天早上。
##   没有事件的时段：自由活动（镇民委托、和蓝色公主玩闹），小屋的床可以休息到下一个时段（rest）。
## 第 1 天：早 d1_open 开场（自动）→ 午 d1_verdict 宣判（广场宣判台）→ 夜 d1_sleepwalk 梦游（进小屋，三处手印 → 楼上结尾）。
## 第 2 天：早 d2_stocks 足枷示众（广场足枷）：开场过场 → 小游戏 StocksShow → 结局过场（撑过时间 after_d2_stocks_end /
##   释放超过 5 次笑晕 after_d2_stocks_faint）；笑出声一次 +2 工时，3 次以上去训练营转受罚转盘。
## 旧存档：打赢攻防战之后回到战时小镇的，直接送到战后的小镇。

const TOWN := "floor_06_after"
const HOUSE := "floor_06_after_house"
const HOUSE_UP := "floor_06_after_house_up"
const PHARMACY := "floor_06_after_pharmacy"
const FIELD := "floor_06_after_field"
const TAILOR := "floor_06_after_tailor"
const MINE := "floor_06_after_mine"
const TOTEM := "floor_06_after_totem"
const STARTED := "after_started"
const EVENTS := {
	"d1_open": {"where": TOWN, "auto": true, "cutscene": "after_d1_open"},
	"d1_verdict": {"where": TOWN, "spot": [31, 27, 2.5], "objective": "去广场的宣判台，听候宣判", "cutscene": "after_d1_verdict"},
	"d1_sleepwalk": {"where": HOUSE, "auto": true, "objective": "回蓝色小屋", "cutscene": "after_d1_night"},
	"d2_stocks": {"where": TOWN, "spot": [23, 25.5, 2], "objective": "去广场的足枷示众", "cutscene": "after_d2_stocks"},
	"d2_equip": {"where": TOWN, "spot": [13, 24.5, 1.5], "objective": "去补给站找市场监督（回收痒痒装备）", "cutscene": "after_d2_equip"},
	"d3_potion": {"where": PHARMACY, "spot": [8, 6, 1.0], "objective": "去药剂师工房试药（北边那排房子）", "cutscene": "after_d3_potion"},
	"d3_cart": {"where": FIELD, "auto": true, "objective": "出南边的城门，去城外的战场拆攻城车", "cutscene": "after_d3_cart"},
	"d5_tailor": {"where": TAILOR, "spot": [9, 7, 1.2], "objective": "去裁缝铺当试衣模特（北边那排最右边的房子）", "cutscene": "after_d5_tailor"},
	"d5_mine": {"where": MINE, "auto": true, "objective": "去东北角的矿道口，护送补给矿车", "cutscene": "after_d5_mine"},
	"d7_totem": {"where": TOTEM, "auto": true, "objective": "从西边的小路去图腾柱废地，修补狂欢图腾柱", "cutscene": "after_d7_totem"},
}
## 小镇里通往各张图的门口（指路）、各张图回小镇的出口
const TOWN_DOORS := {"floor_06_after_house": [42, 10], "floor_06_after_house_up": [42, 10], "floor_06_after_pharmacy": [16, 10],
	"floor_06_after_field": [32, 38.5], "floor_06_after_tailor": [32, 10], "floor_06_after_mine": [54, 6], "floor_06_after_totem": [3, 32]}
const ROOM_EXITS := {"floor_06_after_house": [9, 10], "floor_06_after_pharmacy": [8, 8.5], "floor_06_after_field": [21, 3],
	"floor_06_after_tailor": [8, 10.5], "floor_06_after_mine": [3, 6], "floor_06_after_totem": [3, 12]}
## 城门：第 3 天下午拆攻城车的时候才开；矿道门：第 5 天下午护送矿车的时候才开
const FIELD_OPEN := "after_field_open"
const MINE_OPEN := "after_mine_open"
## 西边通往图腾柱废地的小路：第 7 天修图腾柱的时候才开
const TOTEM_OPEN := "after_totem_open"
## 弥补任务进行中（不能接委托、小屋的门锁着）
const TASK_FLAG := "after_task_active"
## 弥补任务的玩法节点：事件 id → 脚本（实例发 finished(ok)；脚本要有静态的 reset_items() / status_text()）、失败小剧场 / 罚工时
const TASKS := {
	"d2_equip": {"script": "res://levels/floor_06/scripts/task_equip.gd", "name": "痒痒装备回收", "fail": "after_fail_equip", "fail_hours": 3,
		"done": "after_d2_equip_done", "respawn": [13, 25.5]},
	"d3_potion": {"script": "res://levels/floor_06/scripts/task_potion.gd", "name": "试药", "fail": "after_fail_potion", "fail_hours": 2,
		"done": "after_d3_potion_done"},
	"d3_cart": {"script": "res://levels/floor_06/scripts/task_cart.gd", "name": "拆除哑火的攻城车", "fail": "after_fail_cart", "fail_hours": 3,
		"done": "after_d3_cart_done", "respawn": [21, 4]},
	"d5_tailor": {"script": "res://levels/floor_06/scripts/task_tailor.gd", "name": "裁缝的试衣模特", "fail": "after_fail_tailor", "fail_hours": 2,
		"done": "after_d5_tailor_done", "respawn": [9, 8]},
	"d5_mine": {"script": "res://levels/floor_06/scripts/task_mine.gd", "name": "矿车护送", "fail": "after_fail_mine", "fail_hours": 3,
		"done": "after_d5_mine_done", "respawn": [5, 7]},
	# 早上开始一直做到傍晚（to_night：做完直接天黑）；修好了工时清零（clear_book）
	"d7_totem": {"script": "res://levels/floor_06/scripts/task_totem.gd", "name": "修补狂欢图腾柱", "fail": "after_fail_totem", "fail_hours": 2,
		"done": "after_d7_totem_done", "respawn": [8, 12], "to_night": true, "clear_book": true},
}
## 指路用的格子：小镇里的小屋门口、小屋里的门、楼下的床
const TOWN_HOUSE_DOOR := [42, 10]
const HOUSE_DOOR := [9, 10]
const HOUSE_BED := [5, 6]
## 足枷示众：笑出声一次罚几工时、几次以上去转转盘
const STOCKS_BURST_HOURS := 2
const STOCKS_ROULETTE := 3
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


## 现在这个时段还没演的事件 id（没有 / 已经开始 / 做完了 → ""）。
static func pending_event() -> String:
	var ev := DayClock.event()
	if ev == "" or DayClock.done() or GameState.has_flag(ev_flag(ev)) or not EVENTS.has(ev):
		return ""
	return ev


## 这张图上的目标：{text, cell（没有就只显示文字）, radius, trigger（走进圈里就演）}；没有目标返回 {}。
static func objective(floor_id: String) -> Dictionary:
	if not GameState.has_flag(STARTED):
		return {}
	sync_doors()
	if GameState.has_flag(NIGHT_BUSY):
		return {"text": "顺着地上的手印找一找"}
	var cur := current_task()
	if cur != "":
		return {"text": str(TASKS[cur]["name"])}
	var ev := pending_event()
	if ev != "":
		var info: Dictionary = EVENTS[ev]
		var text := str(info.get("objective", ""))
		var where := str(info["where"])
		if where == floor_id:
			if info.has("spot"):
				var sp: Array = info["spot"]
				return {"text": text, "cell": [sp[0], sp[1]], "radius": float(sp[2]), "trigger": true}
			return {"text": text} if text != "" else {}
		return _guide(floor_id, where, text)
	if DayClock.slot() == DayClock.NIGHT:
		if floor_id == HOUSE:
			return {"text": "上床睡觉", "cell": HOUSE_BED, "radius": 1.0}
		return _guide(floor_id, HOUSE if floor_id == TOWN else TOWN, "回蓝色小屋睡觉")
	var next: String = DayClock.SLOT_NAMES[DayClock.slot() + 1]
	return {"text": "自由活动（小屋的床上可以休息到%s）" % next}


## 目标在别的图：小镇里指向那张图的门口；别的图里指向回小镇的出口。
static func _guide(floor_id: String, where: String, text: String) -> Dictionary:
	if floor_id == TOWN and TOWN_DOORS.has(where):
		return {"text": text, "cell": TOWN_DOORS[where], "radius": 1.0}
	if floor_id != TOWN and where != floor_id and ROOM_EXITS.has(floor_id):
		return {"text": text, "cell": ROOM_EXITS[floor_id], "radius": 1.0}
	return {"text": text}


## 城门开不开：现在该去战场（拆攻城车还没做完）才开。
static func sync_doors() -> void:
	var want := DayClock.event() == "d3_cart" and not DayClock.done()
	if GameState.has_flag(FIELD_OPEN) != want:
		GameState.set_flag(FIELD_OPEN, want)
	var mine := DayClock.event() == "d5_mine" and not DayClock.done()
	if GameState.has_flag(MINE_OPEN) != mine:
		GameState.set_flag(MINE_OPEN, mine)
	var totem := DayClock.event() == "d7_totem" and not DayClock.done()
	if GameState.has_flag(TOTEM_OPEN) != totem:
		GameState.set_flag(TOTEM_OPEN, totem)


## 进图时：这张图上自动演的事件（auto）。
static func run_pending(floor_id: String) -> void:
	await _try(floor_id, false)


## 走进目标圈（导演检测到）：演这张图上的 spot 事件。
static func trigger(floor_id: String) -> void:
	await _try(floor_id, true)


## 测试跳关时：清掉演到一半的状态
static func reset_runtime() -> void:
	running = false


static func _try(floor_id: String, by_spot: bool) -> void:
	if running or not GameState.has_flag(STARTED):
		return
	if by_spot and AfterErrands.active() != "":
		GameState.notify("先把手上的委托做完吧。")
		return
	var ev := pending_event()
	if ev == "":
		return
	var info: Dictionary = EVENTS[ev]
	if str(info["where"]) != floor_id or (bool(info.get("auto", false)) == by_spot):
		return
	running = true
	await TrainingDB.wait_dialogue_free()
	GameState.set_flag(ev_flag(ev))
	await _run(ev, info)
	running = false


static func _run(ev: String, info: Dictionary) -> void:
	if ev == "d2_stocks":
		GameState.vars["stocks_bursts"] = 0
	if str(info.get("cutscene", "")) != "":
		await Cutscene.play(str(info["cutscene"]))
	if TASKS.has(ev):
		await run_task(ev)
		return
	match ev:
		"d1_open":
			await finish_slot()
		"d1_verdict":
			PenanceBook.start()
			GameState.hint("背包里多了一页「赎罪簿」")
			await finish_slot()
		"d2_stocks":
			var show := StocksShow.new()
			var tree := Engine.get_main_loop() as SceneTree
			tree.root.add_child(show)
			var res: Dictionary = await show.play_show()
			show.queue_free()
			var n := int(res.get("bursts", 0))
			GameState.vars["stocks_bursts"] = n
			GameState.vars["stocks_releases"] = int(res.get("releases", 0))
			GameState.set_flag("after_d2_fainted", bool(res.get("fainted", false)))
			await Cutscene.play("after_d2_stocks_faint" if bool(res.get("fainted", false)) else "after_d2_stocks_end")
			if n > 0:
				PenanceBook.add(n * STOCKS_BURST_HOURS, "示众时笑出声 ×%d" % n)
			if n >= STOCKS_ROULETTE:
				Cutscene.curtain_clear(0.3)
				await PenanceRoulette.spin("示众时笑出声 %d 次" % n)
			await finish_slot()
		"d1_sleepwalk":
			GameState.set_flag(NIGHT_BUSY)
			# 被挠醒了：顺着手印调查（三处都看过 → 楼梯解锁 → 楼上 AfterHouse 接 night_end）
			GameState.hint("顺着地上的手印找一找")


## 弥补任务：摆上玩法节点 → 等它做完；失败 → 失败小剧场、罚工时（PenanceBook.fail）→ 回到起点重来。
static func run_task(ev: String) -> void:
	var spec: Dictionary = TASKS[ev]
	var scr: Script = load(str(spec["script"]))
	GameState.set_flag(TASK_FLAG)
	while true:
		var lv: Node = StoryDirector.instance.main.get("level") if StoryDirector.instance else null
		if lv == null:
			break
		var runner: Node = scr.new()
		runner.name = "Task_" + ev
		lv.get_node("Entities").add_child(runner)
		var ok: bool = await runner.finished
		if bool(runner.get("aborted")):
			# 换图 / 读档：任务节点没了，清掉标记，走回触发点重新开始
			GameState.set_flag(TASK_FLAG, false)
			GameState.set_flag(ev_flag(ev), false)
			return
		if is_instance_valid(runner):
			runner.queue_free()
		if ok:
			break
		await PenanceBook.fail(str(spec["name"]), str(spec["fail"]), int(spec.get("fail_hours", 0)))
		scr.call("reset_items")
		var p := GameState.player
		if is_instance_valid(p):
			if p.laugh:
				p.laugh.clear()
			if spec.has("respawn"):
				p.global_position = Cutscene.cell_to_world(spec["respawn"])
	GameState.set_flag(TASK_FLAG, false)
	if bool(spec.get("clear_book", false)) and PenanceBook.started() and PenanceBook.hours() > 0:
		PenanceBook.add(-PenanceBook.hours(), str(spec["name"]) + "：工时清零", true)
	if str(spec.get("done", "")) != "":
		await Cutscene.play(str(spec["done"]))
	if bool(spec.get("to_night", false)) and DayClock.slot() == DayClock.MORNING:
		# 一直做到傍晚：早上、下午都算做完，直接天黑
		DayClock.mark_done()
		DayClock.mark_done(-1, DayClock.AFTERNOON)
		await DayClock.pass_time(DayClock.NIGHT)
		GameState.hint("天黑了。广场那边，篝火已经点起来了")
		return
	await finish_slot()


## 任务进行中的实时状态（目标提示下面一行）；没有任务时是委托的
static func status_text() -> String:
	var cur := current_task()
	if cur != "":
		return str(load(str(TASKS[cur]["script"])).call("status_text"))
	return AfterErrands.status_text()


## 正在做的弥补任务（这个时段的事件、已经开始、还没做完）
static func current_task() -> String:
	var ev := DayClock.event()
	if GameState.has_flag(TASK_FLAG) and TASKS.has(ev) and GameState.has_flag(ev_flag(ev)) and not DayClock.done():
		return ev
	return ""


## 读档 / 换图时任务演到一半（玩法节点没了）：清掉标记，走回触发点就能重新开始。
static func recover_task() -> void:
	if not GameState.has_flag(TASK_FLAG) or running:
		return
	GameState.set_flag(TASK_FLAG, false)
	for ev in TASKS:
		if GameState.has_flag(ev_flag(ev)) and DayClock.event() == ev and not DayClock.done():
			GameState.set_flag(ev_flag(ev), false)
			load(str(TASKS[ev]["script"])).call("reset_items")


## 楼上：梦游的结尾（AfterHouse 进楼上时调）。
static func run_upstairs() -> void:
	if running or DayClock.event() != "d1_sleepwalk" or DayClock.done() or not GameState.has_flag(CLUES_FLAG):
		return
	running = true
	await TrainingDB.wait_dialogue_free()
	await Cutscene.play("after_d1_night_end")
	running = false
	await finish_slot()


## 这个时段的事做完了：还工时 → 推进到下一个时段（夜里 → 睡觉）。
static func finish_slot() -> void:
	var info := DayClock.slot_info()
	DayClock.mark_done()
	var hrs := int(info.get("hours", 0))
	if hrs > 0 and PenanceBook.started():
		PenanceBook.add(-hrs, str(info.get("task", "")))
	await advance_slot()


static func advance_slot() -> void:
	match DayClock.slot():
		DayClock.MORNING:
			await DayClock.pass_time(DayClock.AFTERNOON)
		DayClock.AFTERNOON:
			await DayClock.pass_time(DayClock.NIGHT)
			GameState.hint("天黑了，宵禁之前回蓝色小屋")
		DayClock.NIGHT:
			GameState.set_flag(NIGHT_BUSY, false)
			await go_to_bed()


## 小屋的床（白天）：这个时段没有要做的事了 → 休息到下一个时段。返回休息了没有。
static func rest() -> bool:
	if running or DayClock.passing or DayClock.slot() == DayClock.NIGHT:
		return false
	var ev := pending_event()
	if ev != "":
		GameState.notify("还有事没做：%s" % str(EVENTS[ev].get("objective", "")))
		return false
	if AfterErrands.active() != "":
		GameState.notify("先把手上的委托做完吧。")
		return false
	await advance_slot()
	return true


## 对话里用：等对话收尾再休息（调用方不要 await）。
static func rest_later() -> void:
	await TrainingDB.wait_dialogue_free()
	await rest()


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


## 早上醒来：这一天还没做内容的先提示一下。
static func after_wake() -> void:
	var lv: Node = StoryDirector.instance.main.get("level") if StoryDirector.instance else null
	if lv:
		await run_pending(str(lv.get("floor_id")))
	if DayClock.day() == 2 and DayClock.slot() == DayClock.MORNING and not DayClock.done():
		GameState.notify("（蓝色公主一早就去训练室了。……桌上留了张纸条：「广场。别迟到。」）", 4.0)
	if DayClock.event() == "":
		GameState.notify("（%s 的剧情还在制作中……可以做做镇民委托，或者在床上休息）" % DayClock.label())


## 进小屋：这张图上自动演的事件（夜里的事件）。
static func enter_house() -> void:
	await run_pending(HOUSE)

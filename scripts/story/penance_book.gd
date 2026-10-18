class_name PenanceBook
extends RefCounted
## 赎罪簿（七日赎罪）：宣判之后发给粉色公主（剧情标记 penance_book）。开局欠 START 工时：做完弥补任务减，犯错加（宵禁外出、偷懒、报仇……）。
## 工时 vars.penance_hours；记录 vars.penance_log = [{day, slot, delta, text}]（新的在后面）。没有失败结局：第七天没还清也能去庆功宴，只是先补罚。
## 受罚记录 vars.penance_punish = [{day, slot, text, theater}]：punish() 记一笔；小剧场看过之后在背包「CG 图鉴」的「七日赎罪」分组里能重看。
## 弥补任务办砸了：fail(任务名, 小剧场 id, 罚加的工时) —— 播那一段失败小剧场、罚工时、记受罚，任务自己再从头来。
## 背包里的「赎罪簿」页读 page_rows()。

const START := 100
const FLAG := "penance_book"
## 页面上最多列多少条记录（最新的在上面）
const LOG_ROWS := 12


static func started() -> bool:
	return GameState.has_flag(FLAG)


static func start() -> void:
	if started():
		return
	GameState.vars["penance_hours"] = START
	GameState.vars["penance_log"] = []
	GameState.set_flag(FLAG)


static func hours() -> int:
	return int(GameState.vars.get("penance_hours", START))


static func cleared() -> bool:
	return started() and hours() <= 0


static func entries() -> Array:
	return GameState.vars.get("penance_log", [])


static func punishments() -> Array:
	return GameState.vars.get("penance_punish", [])


## 记一笔受罚（转盘、补罚、任务失败……）
static func punish(text: String, theater := "") -> void:
	var list: Array = punishments()
	list.append({"day": DayClock.day(), "slot": DayClock.slot(), "text": text, "theater": theater})
	GameState.vars["penance_punish"] = list


## 弥补任务办砸了：失败小剧场 → 罚工时 → 记受罚。
static func fail(task: String, theater: String, hours := 0) -> void:
	if theater != "" and CG.has_theater(theater):
		await CG.play_theater(theater)
	if hours > 0:
		add(hours, task + "办砸了")
	punish(task + "失败的惩罚", theater)


## 改工时（负数 = 还掉，正数 = 罚加）：记一笔，右下角提示。
static func add(delta: int, reason: String, quiet := false) -> void:
	if not started():
		start()
	var before := hours()
	GameState.vars["penance_hours"] = maxi(0, before + delta)
	var log: Array = entries()
	log.append({"day": DayClock.day(), "slot": DayClock.slot(), "delta": delta, "text": reason})
	GameState.vars["penance_log"] = log
	if not quiet:
		GameState.notify("赎罪簿：%s %d 工时（%s）　剩 %d" % ["－" if delta < 0 else "＋", absi(delta), reason, hours()])


## 页面：[{text, color}]（color：gold 标题 / pink 罚加 / dim 次要 / ""）
static func page_rows() -> Array:
	var rows: Array = []
	if not started():
		rows.append({"text": "（还没有赎罪簿）", "color": "dim"})
		return rows
	var h := hours()
	var bar := ""
	var filled := int(round(10.0 * float(h) / float(START)))
	for i in 10:
		bar += "■" if i < filled else "□"
	rows.append({"text": "剩余工时　%d / %d　%s" % [h, START, bar], "color": "gold"})
	rows.append({"text": "现在：%s" % DayClock.label(), "color": ""})
	rows.append({"text": "今天的安排", "color": "gold"})
	for s in 3:
		var info := DayClock.slot_info(DayClock.day(), s)
		var task := str(info.get("task", ""))
		if task == "":
			continue
		var mark := "✔" if DayClock.done(DayClock.day(), s) else ("▶" if s == DayClock.slot() else "　")
		var hrs := int(info.get("hours", 0))
		rows.append({"text": "%s %s：%s%s" % [mark, DayClock.SLOT_NAMES[s], task, ("（－%d）" % hrs) if hrs > 0 else ""],
			"color": "dim" if DayClock.done(DayClock.day(), s) else ""})
	rows.append({"text": "记录", "color": "gold"})
	var log := entries()
	if log.is_empty():
		rows.append({"text": "（还没有记录）", "color": "dim"})
	for i in range(log.size() - 1, maxi(-1, log.size() - 1 - LOG_ROWS), -1):
		var e: Dictionary = log[i]
		var delta := int(e.get("delta", 0))
		rows.append({"text": "%s　%s%d　%s" % [DayClock.label(int(e.get("day", 1)), int(e.get("slot", 0))), "－" if delta < 0 else "＋", absi(delta), str(e.get("text", ""))],
			"color": "pink" if delta > 0 else ""})
	rows.append({"text": "受罚记录（小剧场可以在「CG 图鉴」里重看）", "color": "gold"})
	var pun := punishments()
	if pun.is_empty():
		rows.append({"text": "（还没有受过罚）", "color": "dim"})
	for i in range(pun.size() - 1, -1, -1):
		var e: Dictionary = pun[i]
		rows.append({"text": "%s　%s" % [DayClock.label(int(e.get("day", 1)), int(e.get("slot", 0))), str(e.get("text", ""))], "color": "pink"})
	if h <= 0:
		rows.append({"text": "……还清了！（剩下的日子也要好好过）", "color": "gold"})
	return rows

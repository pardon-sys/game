class_name DialogueRunner
extends Node
## 人物对话（带选项、条件、演绎、选择记忆）。挂在 Dialogue 下：await Dialogue.talk("floor_06/captain"[, 起始节点])。
##
## 人物对话文件：data/dialogues/<楼层组>/<人物>.json（每个人物一个文件）——
##   {"name": 说话人默认名字, "npc": 人物 id（立绘）, "entries": [{"if": 条件, "node": 节点}, ...], "nodes": {节点: {...}}}
## 节点：
##   lines       台词数组 [{speaker?, text, emotion?}]：speaker 省略 = 这个人物；"公主" = 公主；"" = 旁白
##   set         进入节点时的效果（见 apply）
##   cutscene / theater   演绎：地图内过场（Cutscene）/ 小剧场（CG 舞台，data/theater/）；perform_before = true 时在台词前播
##   choices     选项 [{text, next, if?, set?, return?, once?}]：
##                 return = true → 这个分支演完回到选项页（「回到选项页」型）；否则一路走 next 到结束（「继续到结束」型）
##                 if 不满足的选项不显示；once = true 选过一次就不再显示
##   next        没有选项时接着走的节点（空 = 结束）
##   goto        条件跳转 [{if: 条件, node: 节点}, ...]：进入节点时先看，第一个满足的直接跳过去（按选择记忆分支）
## 条件（if）：{flag: 标记 / [标记…]（都要有）, not: 标记 / [标记…]（都没有）, eq: {变量: 值}, var: {变量: [">=", 数]},
##             seen: "文件:节点"（看过）, any: [条件…]（满足一个即可）}
## 效果（set）：{flags: [标记…] 或 {标记: 值}, vars: {变量: 值}, add: {变量: 数}, give_item: {物品: 数量}, coins: 数（负数是花钱）,
##             passive: 被动 id, call: 方法名（调到 Dialogue.talk_handler 上，如打开商店 / 训练）}
## 选择记忆：关键选择写进 GameState.vars（如 f6_attitude），别的人物用 entries / 选项的 if 读它；看过的节点记 dlg_<文件>_<节点>，
## 选过的一次性选项记 dlg_<文件>_<节点>_<序号>，都随存档保存。

signal talk_started(file: String)
signal talk_finished(file: String)
signal node_entered(file: String, node: String)

const DIR := "res://data/dialogues/"

var choice_menu: ChoiceMenu
## 打开商店 / 训练这类效果调到它上面（Dialogue 设为当前场景里负责的节点）。
var handler: Object
var _cache := {}
var _running := false
var current_file := ""


func _ready() -> void:
	choice_menu = ChoiceMenu.new()
	choice_menu.name = "ChoiceMenu"
	add_child(choice_menu)


static func path_of(file: String) -> String:
	return DIR + file + ".json"


func load_file(file: String) -> Dictionary:
	if not _cache.has(file):
		var p := path_of(file)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null
		_cache[file] = parsed if parsed is Dictionary else {}
	return _cache[file]


func has_file(file: String) -> bool:
	return FileAccess.file_exists(path_of(file))


func is_running() -> bool:
	return _running


## 这个人物现在会从哪个节点开始（第一个满足条件的 entry）。
func entry_of(file: String) -> String:
	var d := load_file(file)
	for e in d.get("entries", []):
		if check(e.get("if", {})):
			return str(e["node"])
	return str(d.get("start", "start"))


func talk(file: String, start := "") -> void:
	var d := load_file(file)
	if d.is_empty() or _running:
		return
	_running = true
	current_file = file
	# 整段人物对话期间（包括台词和选项之间、弹出选项时）公主和居民都不动
	GameState.in_dialogue = true
	talk_started.emit(file)
	await _run(file, d, start if start != "" else entry_of(file))
	_running = false
	current_file = ""
	talk_finished.emit(file)
	await get_tree().create_timer(0.12).timeout  # 同一次确认键不触发公主攻击 / 交互
	if not _running and not Dialogue.is_active() and not GameState.in_cutscene:
		GameState.in_dialogue = false


func _run(file: String, d: Dictionary, id: String) -> void:
	var guard := 0
	while id != "" and guard < 200:
		guard += 1
		var n: Dictionary = d.get("nodes", {}).get(id, {})
		if n.is_empty():
			push_warning("对话 %s 没有节点 %s" % [file, id])
			return
		var jumped := ""
		for gt in n.get("goto", []):
			if check(gt.get("if", {})):
				jumped = str(gt["node"])
				break
		if jumped != "":
			id = jumped
			continue
		GameState.set_flag("dlg_%s_%s" % [file, id])
		node_entered.emit(file, id)
		apply(n.get("set", {}))
		await _call(n.get("set", {}))
		if n.get("perform_before", false):
			await _perform(n)
		if not n.get("lines", []).is_empty():
			await _say(d, n["lines"])
		if not n.get("perform_before", false):
			await _perform(n)
		var choices: Array = n.get("choices", [])
		if choices.is_empty():
			id = str(n.get("next", ""))
			continue
		# 选项页：return 型的分支演完回到这里；其它分支接着往下走
		var next := ""
		while true:
			var shown: Array = []
			for i in choices.size():
				var c: Dictionary = choices[i]
				if c.get("once", false) and GameState.has_flag("dlg_%s_%s_%d" % [file, id, i]):
					continue
				if check(c.get("if", {})):
					shown.append(i)
			if shown.is_empty():
				break
			var pick: int = await choice_menu.ask(shown.map(func(i): return str(choices[i]["text"])), str(n.get("prompt", "")))
			var ci: int = shown[clampi(pick, 0, shown.size() - 1)]
			var c: Dictionary = choices[ci]
			GameState.set_flag("dlg_%s_%s_%d" % [file, id, ci])
			apply(c.get("set", {}))
			await _call(c.get("set", {}))
			if c.get("return", false):
				if str(c.get("next", "")) != "":
					await _run(file, d, str(c["next"]))
				continue
			next = str(c.get("next", ""))
			break
		id = next


func _say(d: Dictionary, lines: Array) -> void:
	var out: Array = []
	for l in lines:
		var line: Dictionary = (l as Dictionary).duplicate()
		if not line.has("speaker"):
			line["speaker"] = str(d.get("name", ""))
		if not line.has("npc") and str(line["speaker"]) == str(d.get("name", "")) and d.has("npc"):
			line["npc"] = d["npc"]
		out.append(line)
	if Dialogue.is_active():
		await Dialogue.finished
	Dialogue.start_lines(out, "talk:" + current_file)
	await Dialogue.finished


func _perform(n: Dictionary) -> void:
	if str(n.get("cutscene", "")) != "":
		var was_cut := Cutscene.is_playing()
		if was_cut:
			push_warning("过场里不能再播过场：%s" % n["cutscene"])
		else:
			Cutscene.play(str(n["cutscene"]))
			await Cutscene.finished
	if str(n.get("theater", "")) != "":
		await CG.play_theater(str(n["theater"]))


# ------------------------------------------------------------------ 条件 / 效果
static func check(cond: Dictionary) -> bool:
	if cond.is_empty():
		return true
	for f in _list(cond.get("flag", [])):
		if not GameState.has_flag(str(f)):
			return false
	for f in _list(cond.get("not", [])):
		if GameState.has_flag(str(f)):
			return false
	var eq: Dictionary = cond.get("eq", {})
	for k in eq:
		if GameState.vars.get(k) != eq[k]:
			return false
	var vs: Dictionary = cond.get("var", {})
	for k in vs:
		var op: Array = vs[k]
		var v := float(GameState.vars.get(k, 0))
		var n := float(op[1])
		var ok := true
		match str(op[0]):
			">=": ok = v >= n
			">": ok = v > n
			"<=": ok = v <= n
			"<": ok = v < n
			"==": ok = is_equal_approx(v, n)
			"!=": ok = not is_equal_approx(v, n)
		if not ok:
			return false
	for s in _list(cond.get("seen", [])):
		var parts := str(s).split(":")
		if parts.size() == 2 and not GameState.has_flag("dlg_%s_%s" % [parts[0], parts[1]]):
			return false
	if cond.has("any"):
		return (cond["any"] as Array).any(func(c): return check(c))
	return true


static func _list(v: Variant) -> Array:
	if v is Array:
		return v
	return [] if str(v) == "" else [v]


func apply(fx: Dictionary) -> void:
	if fx.is_empty():
		return
	var flags: Variant = fx.get("flags", [])
	if flags is Dictionary:
		for k in flags:
			GameState.set_flag(str(k), flags[k])
	else:
		for f in flags:
			GameState.set_flag(str(f))
	var vs: Dictionary = fx.get("vars", {})
	for k in vs:
		GameState.set_var(str(k), vs[k])
	var add: Dictionary = fx.get("add", {})
	for k in add:
		GameState.set_var(str(k), float(GameState.vars.get(k, 0)) + float(add[k]))
	var items: Dictionary = fx.get("give_item", {})
	for id in items:
		GameState.give_item(ItemDB.get_item(str(id)), int(items[id]))
	if fx.has("coins"):
		var c := int(fx["coins"])
		if c >= 0:
			GameState.give_item(ItemDB.get_item("coin"), c)
		else:
			GameState.inventory.remove("coin", -c)
	if fx.has("passive"):
		GameState.grant_passive(str(fx["passive"]))


## call 效果：调到 handler（Dialogue）上的方法，await 到它结束（商店关掉、训练结束……）。
func _call(fx: Dictionary) -> void:
	if fx.has("call") and handler and handler.has_method(str(fx["call"])):
		await handler.call(str(fx["call"]))

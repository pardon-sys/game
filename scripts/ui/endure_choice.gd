class_name EndureChoice
extends CanvasLayer
## 忍笑选择（过场步骤 endure，七日赎罪的足枷示众等）：画面上方一条「忍笑」条在 time 秒内涨满，期间一直被挠（tickle 动作参数），
## delay 秒后弹出应对选项（对话选项页 ChoiceMenu）。条满之前选了 → 结果是那个选项的 id；没来得及 → "burst"（笑出声），burst_var 计数 +1。
## 结果写进 GameState.vars[var]，后面的过场步骤用 if 按它分支。公主的闷笑跟着条涨（立绘表情会变）。
##   await EndureChoice.run({time, time_by, prompt, options [[id, 文字], …], var, burst_var, tickle {...}, delay})
##   time_by = {var: 变量, 值: 秒, …}：按上一次的结果换涨满的时间（上一次求饶了，下一个人手下留情……）

const LAYER := 23
const W := 200.0
const COL_BG := Color(0.12, 0.07, 0.15, 0.92)
const COL_FILL := Color(1.0, 0.55, 0.78)
const COL_HOT := Color(1.0, 0.3, 0.45)

## 测试用：不为 null 时直接选这个序号（-1 = 等到笑出声）
static var auto_pick: Variant = null

var _fill: ColorRect
var _label: Label
var ratio := 0.0


static func run(spec: Dictionary) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var ui := EndureChoice.new()
	tree.root.add_child(ui)
	var result: String = await ui._run(spec)
	ui.queue_free()
	return result


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.position = Vector2(240.0 - W / 2.0 - 4.0, 34.0)
	bg.size = Vector2(W + 8.0, 18.0)
	add_child(bg)
	_fill = ColorRect.new()
	_fill.color = COL_FILL
	_fill.position = bg.position + Vector2(4, 11)
	_fill.size = Vector2(0, 4)
	add_child(_fill)
	_label = Label.new()
	_label.text = "忍住……！"
	_label.position = bg.position + Vector2(4, -3)
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color(1, 0.9, 0.95))
	add_child(_label)


func _run(spec: Dictionary) -> String:
	var tree := get_tree()
	var time := float(spec.get("time", 5.0))
	var by: Dictionary = spec.get("time_by", {})
	if not by.is_empty():
		time = float(by.get(str(GameState.vars.get(str(by.get("var", "")), "")), time))
	time = maxf(0.5, time)
	var delay := float(spec.get("delay", 0.6))
	var opts: Array = spec.get("options", [])
	var texts: Array = opts.map(func(o): return str(o[1]))
	var picked := {"i": -2}
	var menu: ChoiceMenu = Dialogue.runner.choice_menu
	var on_pick := func(i: int): if picked["i"] == -2: picked["i"] = i
	menu.chosen.connect(on_pick)
	var asked := false
	var t := 0.0
	var tk_t := 0.0
	var tickle: Dictionary = spec.get("tickle", {})
	var p := GameState.player
	while picked["i"] == -2 and t < time:
		await tree.process_frame
		var dt := tree.root.get_process_delta_time()
		t += dt
		ratio = clampf(t / time, 0.0, 1.0)
		_fill.size.x = W * ratio
		_fill.color = COL_FILL.lerp(COL_HOT, ratio)
		_label.text = "忍住……！" if ratio < 0.7 else "要、要笑出来了……！"
		if is_instance_valid(p) and p.laugh:
			p.laugh.set_value(p.laugh.max_value * minf(0.95, 0.2 + ratio * 0.75))
		if not tickle.is_empty():
			tk_t -= dt
			if tk_t <= 0.0:
				tk_t = 0.45
				Cutscene._do(tickle.merged({"do": "tickle", "repeat": 2, "interval": 0.2}, true), false)
		if not asked and t >= delay and not opts.is_empty():
			asked = true
			if auto_pick != null:
				if int(auto_pick) >= 0:
					picked["i"] = int(auto_pick)
			else:
				menu.ask(texts, str(spec.get("prompt", "")))
	menu.chosen.disconnect(on_pick)
	if menu.is_open():
		menu.panel.hide()
		menu.chosen.emit(-1)     # 让还在等的 ask 收尾
	var result := "burst"
	if picked["i"] >= 0 and picked["i"] < opts.size():
		result = str(opts[picked["i"]][0])
	var key := str(spec.get("var", "endure_last"))
	GameState.vars[key] = result
	if result == "burst":
		var bk := str(spec.get("burst_var", ""))
		if bk != "":
			GameState.vars[bk] = int(GameState.vars.get(bk, 0)) + 1
		if is_instance_valid(p) and p.laugh:
			p.laugh.set_value(p.laugh.max_value * 0.97)
	return result

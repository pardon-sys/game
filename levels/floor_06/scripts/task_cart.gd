class_name TaskCart
extends Node2D
## 弥补任务「拆除哑火的攻城车」（第 3 天下午，城门外的战场）的玩法节点（AfterStory.run_task 摆进来，发 finished(ok)）：
##   地图上的三辆 DormantCart（图例 f6cart）：粉色公主躲开车灯、别冲刺，绕到车尾按住 E 拆车轴。三辆都拆完 = 做完。
##   车惊醒：把她捞进车斗挠（小过场）→ 挣扎连按（KeySequenceQTE）→ 挣开了：被甩出车斗，车过一会儿又睡着；挣不开 = 失败
##   （AfterStory 播 after_fail_cart，回到战场入口，已经拆完的车不用重拆）。
##   蓝色公主（按 C 换人）：在车旁边（FREEZE_R 以内）按住技能键（magic）冻住车轮——冻着的车灯不扫、不会醒；
##   冻得越久千手痒痒裤的反弹条越满（BACKLASH_RATE/秒，松手慢慢退），满了被裤子挠得解冻、BACKLASH_COOL 秒内冻不了。
## 状态存在 vars：task_cart_done（拆完的车的序号）、task_cart_backlash。

signal finished(ok: bool)

## 没做完就被删掉了（换图 / 读档 / 测试跳关）：AfterStory 收拾残局，走回触发点能重新开始
var aborted := false
var _emitted := false

const FREEZE_R := 150.0
const BACKLASH_RATE := 0.28
const BACKLASH_DECAY := 0.15
const BACKLASH_COOL := 5.0
const QTE_KEYS := 5
const QTE_TIME := 3.4
const ENTRY := [21, 4]

## 测试用：惊醒时挣扎的结果（null = 真的弹 QTE）
static var auto_struggle: Variant = null

var carts: Array[DormantCart] = []
var backlash := 0.0
var _cool := 0.0
var _busy := false


func _ready() -> void:
	var done: Array = GameState.vars.get("task_cart_done", [])
	var lv := get_parent()
	var found := lv.get_tree().get_nodes_in_group("dormant_cart")
	found.sort_custom(func(a, b): return int(a.get("index")) < int(b.get("index")))
	for i in found.size():
		var c := found[i] as DormantCart
		if not lv.is_ancestor_of(c):
			continue
		carts.append(c)
		if i in done:
			c.done = true
		else:
			c.reset_sleep()
			c.woke.connect(_on_woke)
			c.dismantled.connect(_on_dismantled)


static func reset_items() -> void:
	GameState.vars["task_cart_backlash"] = 0.0


static func status_text() -> String:
	return "拆完 %d / 3 辆　车尾按住 E 拆车轴　C 换蓝色公主：按住 L 冻住车轮" % (GameState.vars.get("task_cart_done", []) as Array).size()


func _process(delta: float) -> void:
	if _busy or GameState.in_dialogue or GameState.in_cutscene:
		return
	var p := GameState.player
	if not is_instance_valid(p):
		return
	_cool = maxf(0.0, _cool - delta)
	# 蓝色公主冻车轮
	var holding := p.character_id == "blue" and Input.is_action_pressed("magic") and _cool <= 0.0
	var target: DormantCart = null
	if holding:
		var best := FREEZE_R
		for c in carts:
			if not c.done and c.global_position.distance_to(p.global_position) < best:
				best = c.global_position.distance_to(p.global_position)
				target = c
	if target:
		target.freeze(0.25)
		backlash += BACKLASH_RATE * delta
		if backlash >= 1.0:
			_backlash(p)
	else:
		backlash = maxf(0.0, backlash - BACKLASH_DECAY * delta)
	GameState.vars["task_cart_backlash"] = backlash


## 千手痒痒裤反弹：被挠得解冻
func _backlash(p: PlayableCharacter) -> void:
	backlash = 0.0
	_cool = BACKLASH_COOL
	for c in carts:
		c.frozen_t = 0.0
	# 她施法时身上有冰晶守护（闷笑不涨）——裤子的反弹不管这个
	p.remove_buff("frost_guard")
	if p.laugh:
		p.laugh.set_value(minf(p.laugh.value + p.laugh.max_value * 0.3, p.laugh.max_value * 0.95))
	p.shake(0.6)
	Audio.play("hand_grab", -4.0)
	SpeechBubble.say(p, "……哈、哈哈……裤、裤子……别在这时候……！", 30.0, 1.8)
	GameState.notify("千手痒痒裤反弹了！冰化了——%d 秒内冻不了" % int(BACKLASH_COOL), 2.0)


func _on_dismantled(c: DormantCart) -> void:
	var done: Array = GameState.vars.get("task_cart_done", [])
	var i := carts.find(c)
	if not done.has(i):
		done.append(i)
	GameState.vars["task_cart_done"] = done
	GameState.notify("车轴拆下来了！（%d / 3）" % done.size(), 2.0)
	if carts.all(func(x): return x.done):
		_emit(true)


func _on_woke(c: DormantCart) -> void:
	if _busy:
		c.reset_sleep()
		return
	_busy = true
	var p := GameState.player
	var at := [floori(c.global_position.x / 16.0), floori((c.global_position.y - 12.0) / 16.0)]
	await Cutscene.play_data("cart_grab", {"name": "攻城车醒了", "letterbox": true, "skippable": false, "steps": [
		{"actions": [{"do": "sfx", "sound": "cart_rumble", "volume": -2.0}, {"do": "shake", "time": 0.5, "strength": 3.0},
			{"do": "bubble", "who": "princess", "kind": "surprise"}], "wait": 0.4},
		{"speaker": "", "text": "（车灯「唰」地一亮——攻城车醒了！车斗张开，一下子把她捞了进去）",
			"actions": [{"do": "move", "who": "princess", "to": at, "time": 0.3}]},
		{"speaker": "公主", "text": "哇啊！？车、车斗里全是刷子——哈、哈哈哈！放我出去——！", "emotion": "helpless_1",
			"actions": [{"do": "tickle", "who": "princess", "zone": "sole", "fx": "brush", "repeat": 8, "interval": 0.2}]},
	]})
	var ok := true
	if auto_struggle != null:
		ok = bool(auto_struggle)
	elif is_instance_valid(p):
		var q := KeySequenceQTE.start(p, QTE_KEYS, QTE_TIME)
		ok = await q.finished
	if not ok:
		_busy = false
		_emit(false)
		return
	if is_instance_valid(p):
		p.global_position = c.global_position - c.front.normalized() * 40.0 + Vector2(0, 10)
		if p.laugh:
			p.laugh.add(p.laugh.max_value * 0.2)
	SpeechBubble.say(p, "呼……挣、挣出来了……！", 30.0, 1.4)
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(c):
		c.reset_sleep()
	_busy = false


func _emit(ok: bool) -> void:
	if _emitted:
		return
	_emitted = true
	finished.emit(ok)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and not _emitted:
		aborted = true
		_emit(false)

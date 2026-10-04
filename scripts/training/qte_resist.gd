extends TrainingStage
## 训练三：耐笑部位（忍笑节奏条）。公主被选定部位的刑具固定（刑具慢慢挠这个部位），一名卫兵拿专用工具对准这里。
## 卫兵每次出手：先举起工具（预备），然后左边面板的「忍笑条」上指针从左扫到右——指针落进绿色「憋住」区时按 J / 空格把笑意压住。
##   按准 → 成功，train_resist_<部位> + per_success（一阶段每次 0.001，100 次练满 0.1）
##   按早（举工具时就按 / 指针还没到绿区）、按晚、没按 → 挠中，闷笑大涨（按部位倍率）
##   假动作：这一下的「憋住」区是红色的（卫兵只是晃一下），按了就上当（失败），忍住不按算看穿。
## 越练卫兵出手越快、绿区越窄、假动作越多。闷笑满 → 惩罚小剧场 → 继续。

## 一次失败涨闷笑上限的这个比例（再乘部位倍率）。
const FAIL_RATIO := 0.16
const BAR_W := 100.0

## rest 歇一下 / windup 举工具 / sweep 指针扫过 / result 结果停顿
var phase := "rest"
var phase_t := 0.6
var pointer := 0.0
var green_c := 0.5
var green_w := 0.3
var fake := false
var pressed := false
var fails := 0
var feints_seen := 0
var _passive_t := 0.0
var _bar_bg: ColorRect
var _green: ColorRect
var _needle: ColorRect
var _state_label: Label


func stage_cast() -> Dictionary:
	return {
		"princess": {"kind": "princess", "at": [PRINCESS_AT.x, PRINCESS_AT.y], "visual": "helpless_1", "anim": "helpless", "dir": "down"},
		"device": {"kind": "trap:" + device_key, "at": device_at(device_key)},
		"g1": {"kind": "npc:guard", "at": [-30, PRINCESS_AT.y - 2], "dir": "right"},
	}


func intro_lines() -> Array:
	var zn := TickleZones.zone_name(zone)
	return [["保卫队员", "耐笑部位训练——今天专练%s。我会用这把特制的工具对准%s挠。" % [zn, zn]],
		["保卫队员", "我一出手，看准指针进绿区的那一下按 J 或空格憋住。……我可是会假动作的哦。"],
		["公主", "%s……好、好吧，我会憋住的！" % zn]]


func key_hint() -> String:
	return "指针进绿区时按 J / 空格憋住　红区是假动作，别按"


func sweep_time() -> float:
	return maxf(0.45, 1.2 * decay(0.98))


## 绿区宽度和扫过速度同步按 ramp 缩小。
func zone_width() -> float:
	return maxf(0.08, 0.3 * decay(0.985))


func fake_chance() -> float:
	return minf(0.35, 0.1 + successes * 0.01 * ramp())


func windup_time() -> float:
	return rng.randf_range(0.5, 1.0) * maxf(0.5, decay(0.985))


func rest_time() -> float:
	return maxf(0.25, 1.0 * decay(0.97))


func _enter_game() -> void:
	super()
	_state_label = _label(TEXT, 8)
	_state_label.position = Vector2(0, 0)
	_state_label.size = Vector2(panel_body.size.x, 26)
	_state_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY   # 长一点的提示换行，不超出面板
	panel_body.add_child(_state_label)
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.22, 0.15, 0.28)
	_bar_bg.position = Vector2(1, 30)
	_bar_bg.size = Vector2(BAR_W, 14)
	panel_body.add_child(_bar_bg)
	_green = ColorRect.new()
	_green.size = Vector2(0, 14)
	_bar_bg.add_child(_green)
	_needle = ColorRect.new()
	_needle.color = Color(1, 1, 1)
	_needle.size = Vector2(2, 20)
	_needle.position = Vector2(0, -3)
	_bar_bg.add_child(_needle)
	var cap := _label(DIM, 8)
	cap.text = "忍笑条"
	cap.position = Vector2(0, 48)
	panel_body.add_child(cap)
	_set_phase("rest", 1.0)


func _set_phase(p: String, time: float) -> void:
	phase = p
	phase_t = time
	match p:
		"rest":
			_state_label.text = "……"
			_state_label.add_theme_color_override("font_color", DIM)
			_green.size.x = 0
			_needle.visible = false
		"windup":
			fake = rng.randf() < fake_chance()
			green_w = zone_width()
			green_c = rng.randf_range(0.25 + green_w / 2.0, 1.0 - green_w / 2.0)
			pressed = false
			_state_label.text = "卫兵举起了工具……"
			_state_label.add_theme_color_override("font_color", GOLD)
			say("g1", ["要挠了哦——", "这次是%s……" % TickleZones.zone_name(zone), "看招！", "嘿嘿……"][rng.randi() % 4])
			var g: CGActor = actors.get("g1")
			if g:
				g.style = "bounce"
		"sweep":
			pointer = 0.0
			_green.color = BAD if fake else GOOD
			_green.position.x = roundf((green_c - green_w / 2.0) * BAR_W)
			_green.size.x = maxf(2.0, roundf(green_w * BAR_W))
			_needle.visible = true
			_state_label.text = "假动作？！" if fake else "憋住！"
			_state_label.add_theme_color_override("font_color", BAD if fake else GOOD)
			Audio.play("swish", -6.0, 0.1, 1.3)
		"result":
			var g: CGActor = actors.get("g1")
			if g:
				g.style = "idle"


func _tick(delta: float) -> void:
	# 刑具慢慢挠这个部位
	_passive_t -= delta
	if _passive_t <= 0.0:
		_passive_t = 1.2
		tickle("device", zone)
		add_laugh(0.015 * laugh_max() * TickleZones.zone_multiplier(zone))
	phase_t -= delta
	match phase:
		"rest":
			if phase_t <= 0.0:
				_set_phase("windup", windup_time())
		"windup":
			if phase_t <= 0.0:
				_set_phase("sweep", sweep_time())
		"sweep":
			pointer = clampf(1.0 - phase_t / sweep_time(), 0.0, 1.0)
			_needle.position.x = roundf(pointer * (BAR_W - 2))
			if phase_t <= 0.0:
				if fake:
					feints_seen += 1
					pop(actors.get("g1"), "看穿了！", GOLD)
					_set_phase("result", 0.3)
				else:
					_fail("没憋住……")
		"result":
			if phase_t <= 0.0:
				_set_phase("rest", rest_time())


func in_green() -> bool:
	return absf(pointer - green_c) <= green_w / 2.0


func _on_key(k: String) -> void:
	if k != "J" and k != "SPACE":
		return
	match phase:
		"windup":
			_fail("太紧张了，按早了！")
		"sweep":
			if fake:
				_fail("上当了！")
			elif in_green():
				_success()
			else:
				_fail("按早了！" if pointer < green_c else "按晚了！")


func _success() -> void:
	pop(actors.get("princess"), "憋住了！", GOOD)
	Audio.play("chime", -8.0, 0.05, 1.0 + minf(successes, 40) * 0.01)
	var g: CGActor = actors.get("g1")
	if g:
		g.shake(0.15)
	_state_label.text = "憋住了！"
	succeed(TrainingStats.zone_key("train_resist", zone), float(t.get("per_success", {}).get("train_resist", 0.001)))
	_set_phase("result", 0.35)


func _fail(why: String) -> void:
	fails += 1
	tickle("g1", zone, true)
	pop(actors.get("g1"), why, BAD)
	add_laugh(FAIL_RATIO * laugh_max() * TickleZones.zone_multiplier(zone))
	_state_label.text = why
	_state_label.add_theme_color_override("font_color", BAD)
	var pr: CGActor = actors.get("princess")
	if pr and player.laugh:
		pr.set_pose("helpless_2" if player.laugh.ratio() > 0.7 else "helpless_1", "helpless")
	_set_phase("result", 0.6)


func _after_punish(_kind: String) -> void:
	_set_phase("rest", 1.2)

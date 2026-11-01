extends RefCounted
## 骑士篇 A~D 专项：从庆功宴之后的早上开始，一步一步走（主线每一步都要和人说话 / 调查道具才开始）：
## 小屋里醒来、自由活动 → 和地牢入口的队员说话 → 抬担架（手印对粉色温和、碰到队员担架歪、歪三次失败重来）
## → 工房里醒来（「凶手」）→ 下午自由活动、床上休息到晚上 → 调查暗掉的灯笼 → 以笑为饵（按住 Y 偷偷笑、手印怕人、被笑声引来、
## 笑过头一群扑来、蓝色 J 冻住 / 挠她、E 收瓶、千手解放扒手印、被淹没失败）→ 调查路障 → 夜探地牢（审问椅、
## 骑士只回答一个问题、拿出手帕、蓝色公主出来时他懵了）→ 回小屋睡觉 → 第二天早上。
static var checks := 0


static func verify(t: Node, label: String, ok: bool) -> void:
	checks += 1
	t.check(label, ok)


static func task(t: Node, id: String) -> Node:
	return t._node("Task_" + id)


static func wait_task(t: Node, id: String, time := 40.0) -> Node:
	await t._advance_until(func(): return task(t, id) != null and bool(task(t, id).get("started")) and not GameState.in_dialogue and not Cutscene.is_playing(), time)
	return task(t, id)


static func run(t: Node) -> void:
	checks = 0
	for f in ["after_started", "penance_book", "f6_opening_done", AfterFestival.ON, AfterFestival.DANCE_DONE, AfterFestival.FINALE_DONE,
			"after_done_d7_morning", "after_done_d7_afternoon", "after_done_d7_night", "after_ev_d7_festival", "blue_tickle_pants"]:
		GameState.set_flag(f)
	GameState.vars["penance_hours"] = 0
	DayClock.set_time(7, DayClock.NIGHT)
	# 数据
	verify(t, "骑士登记在人物表里（行走图、立绘）", ResourceLoader.exists(str(Dialogue.npcs.get("knight", {}).get("sprite", "")))
		and ResourceLoader.exists(str(Dialogue.npcs.get("knight", {}).get("portrait", ""))))
	verify(t, "保卫队的地牢在楼层表里", Floors.ids().has(KnightStory.PRISON))
	verify(t, "骑士篇的步骤：%s" % [KnightStory.STEPS.map(func(s): return s["id"])],
		KnightStory.STEPS.map(func(s): return s["id"]) == ["found", "wake", "afternoon", "bait", "sneak", "cell", "sleep", "report", "chase", "boss", "boss_fog"])
	# 生成器注入的主线触发条件（eq knight_step = 下标）要和 STEPS 对得上
	var trig := []
	for pair in [["after_k_guard_dungeon", "found"], ["after_k_captain", "report"]]:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogues/floor_06/%s.json" % pair[0]))
		# 主线触发的条目（go）要排在最前面（支线的对话不能挡住它）
		trig.append(str(d["entries"][0].get("node", "")) == "go" and int(d["entries"][0]["if"]["eq"]["knight_step"]) == KnightStory.index_of(pair[1]))
	var objs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogues/floor_06/after_k_objects.json"))
	trig.append(int(objs["nodes"]["lantern"]["goto"][0]["if"]["eq"]["knight_step"]) == KnightStory.index_of("bait"))
	trig.append(int(objs["nodes"]["vent"]["goto"][0]["if"]["eq"]["knight_step"]) == KnightStory.index_of("sneak"))
	verify(t, "对话里的主线触发和步骤下标对得上（%s）" % [trig], trig.all(func(x): return x))
	# 旧存档：第一版的下标换算到新列表
	GameState.set_flag(KnightStory.STARTED)
	GameState.vars[KnightStory.STEP_VAR] = 6
	GameState.vars.erase(KnightStory.VERSION_VAR)
	verify(t, "旧存档第一版的 erupt（6）→ 新列表的 report（%s）" % KnightStory.step_id(), KnightStory.step_id() == "report")
	GameState.set_flag(KnightStory.STARTED, false)
	GameState.vars.erase(KnightStory.STEP_VAR)
	GameState.vars.erase(KnightStory.VERSION_VAR)
	# 庆功宴之后睡一觉 → 骑士篇开始
	GameState.pending_spawn = "bed"
	await t.main.change_level(Floors.scene(AfterStory.HOUSE))
	await t._wait(0.5)
	AfterStory.sleep()
	await t._advance_until(func(): return KnightStory.active() and t.seen_cuts.has("knight_morning") and not Cutscene.is_playing() and not Sleep.sleeping, 40.0)
	verify(t, "庆功宴之后睡一觉：骑士篇开始（%s）→ 小屋里醒来，没人敲门，自由活动" % DayClock.label(),
		KnightStory.active() and DayClock.label().begins_with("骑士篇") and t.seen_cuts.has("knight_morning") and KnightStory.step_id() == "found"
		and not t.seen_cuts.has("knight_found"))
	verify(t, "蓝色公主默认不跟着（在镇上闲逛）", not AfterBlueRoutine.invited_today())
	# A 抬担架
	GameState.vars[TaskStretcher.PATH_KEY] = 0
	GameState.pending_spawn = "from_house"
	await t.main.change_level(Floors.scene(AfterStory.TOWN))
	await t._wait(0.8)
	verify(t, "出小屋去旧小镇 → 转到骑士篇白天的小镇（%s）" % t._level_id(), t._level_id() == KnightStory.KDAY)
	var folk: Array = t.main.level.find_children("*", "Resident", true, false)
	verify(t, "白天的小镇：镇民都是骑士篇的对话、不挂委托（%d 人）" % folk.size(), not folk.is_empty()
		and folk.all(func(n): return (n as Resident).dialogue.begins_with("floor_06/after_k_")) and not AfterErrands.is_open("dance"))
	verify(t, "图腾柱已经修好了", t.main.level.find_children("*", "Node2D", true, false).any(func(n): return n.get("kind") == "totem_fixed"))
	# 蓝色公主：平时闲逛，说话邀请 → 跟着；「你先去忙吧」→ 回去闲逛
	var kb := t._node("AfterBlue") as BluePrincess
	await t._wait(0.3)
	verify(t, "白天的小镇：蓝色公主在镇上闲逛（follow %s）" % [kb.follow if kb else null], kb != null and not kb.follow and AfterBlueRoutine.current != null)
	await t._talk("floor_06/after_partner", "k_talk", [0])
	await t._advance_until(func(): return kb.follow, 3.0)
	verify(t, "和她说「一起走吧」→ 跟上来", kb.follow and AfterBlueRoutine.invited_today())
	await t._talk("floor_06/after_partner", "k_talk", [0])
	await t._advance_until(func(): return not kb.follow, 3.0)
	verify(t, "「你先去忙吧」→ 回去闲逛", not kb.follow and not AfterBlueRoutine.invited_today())
	# 故意笑是 Y（E 只管互动）；背包最后一页是键位表，页签一行放得下
	var ykeys := InputMap.action_get_events("laugh").map(func(e): return (e as InputEventKey).physical_keycode)
	verify(t, "故意笑的键是 Y（%s）" % [ykeys], ykeys.has(KEY_Y))
	var bp: Backpack = t.main.get_node("Backpack")
	bp.open()
	bp.set_page(Backpack.PAGE_KEYS)
	await t._wait(0.2)
	var key_text := "\n".join(bp.status_page.box.get_children().map(func(l): return (l as Label).text))
	var tabs_w := bp.tabs_label.get_theme_font("font").get_string_size(bp.tabs_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, bp.tabs_label.get_theme_font_size("font_size")).x
	verify(t, "背包的键位页：列出故意笑 Y、互动 E、冲刺 K（页签宽 %.0f）" % tabs_w, bp.page_order().back() == Backpack.PAGE_KEYS
		and key_text.contains("故意笑") and key_text.contains("Y") and key_text.contains("E") and key_text.contains("K") and tabs_w <= 396.0)
	bp.close()
	var mk := t._node("Objective") as ObjectiveMarker
	verify(t, "小镇的目标：自由活动，东北角地牢入口有人在喊", mk != null and mk.text.contains("自由活动") and mk.text.contains("地牢入口"))
	var gd := t._node("after_k_guard_dungeon") as Node2D
	verify(t, "地牢入口的队员头上冒「！」", gd != null and gd.get_node_or_null("ErrandMark") != null)
	t._go(Cutscene.cell_to_world(KnightStory.STEPS[0]["cell"]) + Vector2(0, 12))
	await t._wait(1.0)
	verify(t, "走到地牢入口不会自动开演", not t.seen_cuts.has("knight_found") and task(t, "found") == null)
	await t._talk("floor_06/after_k_guard_dungeon", "")
	var st := await wait_task(t, "found") as TaskStretcher
	verify(t, "和他说话 → 发现骑士的过场 → 抬担架开始（两手占着、走得慢）", st != null and t.seen_cuts.has("knight_found")
		and st.pink.has_meta(&"busy_hands") and st.pink.buffs.has("carry_stone"))
	if st == null:
		return
	var w0 := st.walker.global_position
	st.advance(1.0)
	verify(t, "她跟得上：队员抬着往前走", st.walker.global_position.distance_to(w0) > 5.0)
	st.pink.global_position = st.walker.global_position + Vector2(0, TaskStretcher.LEASH + 20)
	w0 = st.walker.global_position
	st.advance(1.0)
	verify(t, "离太远：队员停下来等", st.walker.global_position.distance_to(w0) < 0.5)
	st.pink.global_position = st.walker.global_position + Vector2(0, 20)
	var h := st.spawn_hand()
	h.global_position = st.pink.global_position
	var f0 := st.pink.fatigue.value
	st.advance(0.05)
	verify(t, "手印碰到粉色公主：拍拍脚背就散了（疲倦 %.0f → %.0f）" % [f0, st.pink.fatigue.value], h.state == "gone" and st.pink.fatigue.value > f0 and TaskStretcher.drops() == 0)
	h = st.spawn_hand()
	h.global_position = st.walker.global_position
	st.advance(0.05)
	verify(t, "刚爬出来的手印碰到队员还不算（她有时间去拦）", TaskStretcher.drops() == 0)
	h.set_meta(&"age", TaskStretcher.ARM_TIME)
	var h2 := st.spawn_hand(0.0, true)
	var h3 := st.spawn_hand(0.0, true)
	for x in [h2, h3]:
		x.global_position = st.walker.global_position
	st.advance(0.05)
	verify(t, "三只手印同一下碰到队员：只歪一次（%d 次）、又多爬出一只" % TaskStretcher.drops(), TaskStretcher.drops() == 1 and st.dropped_left > 0.0 and st.grace_left > 0.0)
	for i in 10:
		st.advance(0.05)
	verify(t, "歪了以后的缓冲时间里不再算（%d 次）" % TaskStretcher.drops(), TaskStretcher.drops() == 1)
	GameState.vars[TaskStretcher.PATH_KEY] = 2
	st.grace_left = 0.0
	st.dropped_left = 0.0
	h = st.spawn_hand(0.0, true)
	h.global_position = st.walker.global_position
	st.advance(0.05)
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:knight_fail_stretcher") and task(t, "found") != null and bool(task(t, "found").started) and not CG.is_busy(), 60.0)
	st = task(t, "found") as TaskStretcher
	verify(t, "担架歪三次：失败小剧场 → 从地牢入口重新抬", GameState.has_flag("cg_seen_theater:knight_fail_stretcher") and st != null and TaskStretcher.drops() == 0)
	if st == null:
		return
	st.leg = TaskStretcher.PATH.size() - 1
	st.walker.global_position = Cutscene.cell_to_world(TaskStretcher.PATH[-1])
	st.pink.global_position = st.walker.global_position + Vector2(0, 16)
	st.advance(0.05)
	await t._advance_until(func(): return t._level_id() == KnightStory.PHARMACY and KnightStory.step_id() == "afternoon" and not Cutscene.is_playing() and not KnightStory.running, 60.0)
	verify(t, "抬到工房 → 醒来吼「凶手」→ 被关进地牢 → 已经下午了（%s），自由活动" % DayClock.label(),
		t.seen_cuts.has("knight_carry_done") and t.seen_cuts.has("knight_wake") and DayClock.slot() == DayClock.AFTERNOON and not Sleep.sleeping)
	var mk2 := t._node("Objective") as ObjectiveMarker
	verify(t, "下午的目标：自由活动，回床上能休息到晚上（%s）" % (mk2.text if mk2 else ""), mk2 != null and mk2.text.contains("休息到晚上"))
	GameState.pending_spawn = "from_pharmacy"
	await t.main.change_level(Floors.scene(AfterStory.TOWN))
	await t._wait(0.8)
	verify(t, "出工房 → 白天的小镇、下午（%s / %s）" % [t._level_id(), DayClock.label()], t._level_id() == KnightStory.KDAY and DayClock.slot() == DayClock.AFTERNOON)
	verify(t, "下午没有自动开演的事", task(t, "bait") == null and not t.seen_cuts.has("knight_bait_open"))
	GameState.pending_spawn = "bed"
	await t.main.change_level(Floors.scene(AfterStory.HOUSE))
	await t._wait(0.5)
	var rested := await AfterStory.rest()
	verify(t, "回小屋的床上休息 → 晚上（%s）、下一步调查灯笼" % DayClock.label(), rested and DayClock.slot() == DayClock.NIGHT and KnightStory.step_id() == "bait")
	verify(t, "夜里的床上不能接着休息", not KnightStory.can_rest())
	# C 以笑为饵
	GameState.vars[TaskBait.CAUGHT_KEY] = 0
	GameState.pending_spawn = "from_house"
	await t.main.change_level(Floors.scene(AfterStory.TOWN))
	await t._wait(0.8)
	verify(t, "出小屋 → 骑士篇夜里的小镇（%s），镇民在广场上" % t._level_id(), t._level_id() == KnightStory.KNIGHT_N
		and DayClock.slot() == DayClock.NIGHT and t.main.level.find_children("*", "Resident", true, false).all(func(n): return (n as Resident).dialogue.begins_with("floor_06/after_kn_")))
	await t._wait(1.0)
	verify(t, "出门不会自动开演", task(t, "bait") == null and not t.seen_cuts.has("knight_bait_open"))
	await t._talk("floor_06/after_k_objects", "lantern")
	var bt := await wait_task(t, "bait") as TaskBait
	verify(t, "调查暗掉的灯笼 → 以笑为饵开始（%d 只手印、痒痒草、诅咒地纹）" % (bt.hands.size() if bt else 0),
		bt != null and t.seen_cuts.has("knight_bait_open") and bt.hands.size() == TaskBait.HANDS and bt.marks.size() > 0 and bt.grass.size() > 0)
	if bt == null:
		return
	verify(t, "手印贴着镇民偷笑声", bt.hands.any(func(x): return x.stealing))
	verify(t, "C 键绑上了换人", InputMap.action_get_events("switch_character").any(func(e): return e is InputEventKey and e.physical_keycode == KEY_C))
	var pink := bt.pink
	verify(t, "K 还是冲刺（这段不再拿走冲刺）", not pink.has_meta(&"no_dash") and not bt.blue.has_meta(&"no_dash"))
	pink.laugh.set_value(0.0)
	KnightLaugh.force_hold = true
	await t._wait(0.8)
	KnightLaugh.force_hold = false
	verify(t, "粉色公主按住 Y 偷偷笑：闷笑涨起来（%.0f%%）" % (pink.laugh.ratio() * 100.0), pink.laugh.ratio() > 0.03)
	pink.laugh.set_value(0.0)
	KnightLaugh.reset()
	KnightLaugh.force_hold = true
	var held := pink.laugh.value
	KnightLaugh.tick(pink, KnightLaugh.HOLD * 0.5)
	KnightLaugh.force_hold = false
	KnightLaugh.tick(pink, 0.0)
	verify(t, "短按 E 不算笑（按住超过 %.2f 秒才笑）" % KnightLaugh.HOLD, is_equal_approx(pink.laugh.value, held))
	pink.laugh.set_value(0.0)
	var hd: CurseHand = bt.hands[0]
	hd.release()
	hd.state = "wander"
	hd.global_position = pink.global_position + Vector2(20, 0)
	bt.advance(0.05)
	verify(t, "不笑的时候走近：手印躲开", hd.state == "flee")
	pink.laugh.set_value(pink.laugh.max_value * 0.6)
	hd.state = "wander"
	hd.global_position = pink.global_position + Vector2(60, 0)
	bt.advance(0.05)
	verify(t, "笑起来：手印被笑声引过来", hd.state == "seek" and hd.target == pink)
	hd.global_position = pink.global_position
	hd._process(0.05)
	var fat0 := pink.fatigue.value
	var lg0 := pink.laugh.value
	hd._tick = 0.0
	hd._process(0.01)
	verify(t, "贴在粉色公主身上：挠得很轻，疲倦涨得多（闷笑 +%.1f，疲倦 +%.1f）" % [pink.laugh.value - lg0, pink.fatigue.value - fat0],
		hd.state == "latched" and pink.fatigue.value - fat0 > pink.laugh.value - lg0)
	pink.laugh.set_value(pink.laugh.max_value * 0.9)
	bt.advance(0.05)
	verify(t, "笑过头：全图的手印一起扑过来", bt.swarming and bt.hands.all(func(x): return x.state in ["seek", "latched", "frozen", "gone"] and (x.state != "latched" or x.target == pink)))
	pink.laugh.set_value(0.0)
	var blue := bt.blue
	verify(t, "这段任务小镇能换人", t.main.level.get_meta(&"free_switch", false) and not bool(t.main.level.get("no_switch")))
	GameState.switch_control(blue)
	await t._wait(0.2)
	pink.laugh.set_value(0.0)
	pink.global_position = blue.global_position + Vector2(12, 0)
	for x in bt.hands:
		if is_instance_valid(x) and x.state == "frozen":
			x.global_position = blue.global_position + Vector2(200, 0)
	for x in bt.hands:
		if is_instance_valid(x) and x.state not in ["gone", "frozen"] and x.global_position.distance_to(blue.global_position) <= TaskBait.FREEZE_R:
			x.global_position = blue.global_position + Vector2(200, 0)
	verify(t, "蓝色公主身边没有手印时按 J：挠她一下（%s），闷笑上涨" % bt.blue_j(), pink.laugh.value > 0.0)
	pink.laugh.set_value(0.0)
	hd.state = "wander"
	hd.global_position = blue.global_position + Vector2(8, 0)
	bt.freeze_cool = 0.0
	verify(t, "身边有手印时按 J：冻住（%s）" % bt.blue_j(), hd.state == "frozen")
	var b := bt.bottle_near(blue)
	verify(t, "E：收进瓶子（%d / %d）" % [TaskBait.caught(), TaskBait.GOAL], b >= 1 and TaskBait.caught() >= 1)
	# 千手解放：范围内贴着人的手印被扒下来、冻住（可以收瓶）
	GameState.set_flag(PantsBurst.FLAG)
	PantsBurst._ready_at.clear()
	var hb: CurseHand = bt.hands.filter(func(y): return is_instance_valid(y) and y.state != "gone" and y.state != "frozen")[0]
	hb.global_position = blue.global_position + Vector2(20, 0)
	hb.latch(pink)
	pink.global_position = blue.global_position + Vector2(20, 0)
	var cast := PantsBurst.cast(blue)
	await t.get_tree().process_frame
	verify(t, "千手解放：贴在粉色公主身上的手印被扒下来、冻住（%s）" % hb.state, cast and hb.state == "frozen")

	GameState.switch_control(pink)
	await t._wait(0.2)
	# 被淹没
	for x in bt.hands.slice(0, TaskBait.SWAMP):
		if is_instance_valid(x):
			x.state = "wander"
			x.latch(pink)
	bt.advance(0.05)
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:knight_fail_bait") and task(t, "bait") != null and bool(task(t, "bait").started) and not CG.is_busy(), 60.0)
	bt = task(t, "bait") as TaskBait
	verify(t, "身上贴着五只：被手印淹没的失败小剧场 → 重新撒手印（抓到的还在 %d）" % TaskBait.caught(),
		GameState.has_flag("cg_seen_theater:knight_fail_bait") and bt != null and TaskBait.caught() >= 1)
	if bt == null:
		return
	GameState.switch_control(bt.blue)
	await t._wait(0.2)
	while TaskBait.caught() < TaskBait.GOAL and is_instance_valid(bt) and not bt._emitted:
		var x: CurseHand = bt.hands.filter(func(y): return is_instance_valid(y) and y.state != "gone")[0]
		x.global_position = bt.blue.global_position + Vector2(6, 0)
		bt.freeze_cool = 0.0
		bt.freeze_near(bt.blue)
		bt.bottle_near(bt.blue)
		await t._wait(0.05)
	await t._advance_until(func(): return KnightStory.step_id() == "sneak" and not Cutscene.is_playing() and not KnightStory.running, 40.0)
	verify(t, "收够六只：灯笼重新亮了 → 队长不准见他 →「我知道一条路」", t.seen_cuts.has("knight_bait_done") and KnightStory.step_id() == "sneak"
		and not (GameState.player is BluePrincess))
	# D 夜探地牢
	GameState.vars[TaskSneak.CAUGHT_KEY] = 0
	t._go(Cutscene.cell_to_world(KnightStory.STEPS[4]["cell"]) + Vector2(-16, 0))
	await t._wait(1.0)
	verify(t, "走到路障边不会自动开演", t._level_id() == KnightStory.KNIGHT_N and not t.seen_cuts.has("knight_sneak_open"))
	await t._talk("floor_06/after_k_objects", "vent")
	await t._advance_until(func(): return t._level_id() == KnightStory.PRISON and task(t, "cell") != null and bool(task(t, "cell").started) and not Cutscene.is_playing(), 60.0)
	var sk := task(t, "cell") as TaskSneak
	verify(t, "调查路障 → 通风口 → 进地牢 → 潜入开始（有巡逻）", sk != null and t.seen_cuts.has("knight_sneak_open")
		and not t.get_tree().get_nodes_in_group("patrol_guard").is_empty())
	if sk == null:
		return
	# 中途从地牢出口走出去：回到夜里的小镇，通风口能钻回去，任务从入口重新开始
	GameState.pending_spawn = "from_prison"
	await t.main.change_level(Floors.scene("floor_06_after"))
	await t._advance_until(func(): return not Cutscene.is_playing() and not GameState.in_dialogue and task(t, "cell") == null, 20.0)
	verify(t, "夜探中途出来：回到夜里的小镇（%s），步骤还在夜探" % t._level_id(), t._level_id() == KnightStory.KNIGHT_N and KnightStory.step()["id"] == "cell" and not KnightStory.running)
	await t._talk("floor_06/after_k_objects", "vent")
	await t._advance_until(func(): return t._level_id() == KnightStory.PRISON and task(t, "cell") != null and bool(task(t, "cell").started) and not Cutscene.is_playing(), 60.0)
	sk = task(t, "cell") as TaskSneak
	verify(t, "再调查通风口：钻回地牢，夜探重新开始", sk != null)
	if sk == null:
		return
	var sd: StealthDirector = t.main.level.find_children("*", "StealthDirector", true, false)[0]
	var crates: Array = t.main.level.find_children("*", "Node2D", true, false).filter(func(n): return n.get("kind") == "crate" and n.get("action") == "hide")
	var stuck: Array = []
	for c in crates:
		var at: Vector2 = sd.exit_spot(GameState.player, (c as Node2D).global_position)
		var q := PhysicsShapeQueryParameters2D.new()
		var cs := GameState.player.get_node("Collision") as CollisionShape2D
		q.shape = cs.shape
		q.collision_mask = GameState.player.collision_mask
		q.exclude = [GameState.player.get_rid()]
		q.transform = Transform2D(0.0, at + cs.position)
		if not GameState.player.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty():
			stuck.append((c as Node2D).global_position)
	verify(t, "每个木箱（%d 个）躲进去再出来都站得下，不卡墙（卡住的：%s）" % [crates.size(), stuck], crates.size() >= 5 and stuck.is_empty())
	var guards: Array = t.get_tree().get_nodes_in_group("patrol_guard")
	verify(t, "巡逻松一点：%d 个队员，视野 %.0f，警觉涨得慢（%.1f）" % [guards.size(), guards[0].view_range, sd.alert_rate],
		guards.size() == 5 and guards.all(func(g): return g.view_range <= 64.0 and g.speed <= 26.0) and sd.alert_rate <= 1.6)
	# 牢房里那些奇怪的东西
	await t._wait(0.2)
	var od := sk.oddities
	verify(t, "牢房里摆了挠痒鼠、痒痒手套、审讯椅（按 E）和马凳", is_instance_valid(od) and od.spots.size() == 3 and is_instance_valid(od.saddle))
	if is_instance_valid(od):
		var gp0: Array = guards.map(func(g): return g.state if "state" in g else 0)
		var n_alarm := PrisonOddities.alarm()
		verify(t, "挠痒鼠没放出来就尖叫：把附近的守卫引过来（%d 个）" % n_alarm, n_alarm >= 0)
		GameState.player.global_position = od.saddle.global_position + Vector2(8, 0)
		await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:prison_saddle") and not CG.is_busy(), 60.0)
		verify(t, "走到马凳旁边：触发小剧场（她说绝对不坐 → 守卫来了 → 又坐上去）", GameState.has_flag("cg_seen_theater:prison_saddle") and od.saddle_done)
		GameState.player.global_position = Cutscene.cell_to_world(TaskSneak.SPAWN)
		await t._wait(0.3)
	TaskSneak.auto_chair = true
	sk.caught_now()
	await t._wait(0.3)
	verify(t, "被发现：审问椅 → 送回通风口（被抓 %d 次）" % TaskSneak.caught(), TaskSneak.caught() == 1
		and GameState.player.global_position.distance_to(Cutscene.cell_to_world(TaskSneak.SPAWN)) < 4.0)
	TaskSneak.auto_chair = false
	t._go(Cutscene.cell_to_world(TaskSneak.CELL))
	await t._advance_until(func(): return t.seen_cuts.has("knight_cell_end") and not Cutscene.is_playing(), 60.0)
	verify(t, "隔着栏杆：他只回答了一个问题，其余拒绝（%s）" % [["knight_asked_night", "knight_asked_fall", "knight_asked_why", "knight_answered", "knight_refused"].filter(func(f): return GameState.has_flag(f))],
		GameState.has_flag("knight_answered") and GameState.has_flag("knight_refused") and GameState.has_flag("dlg_floor_06/after_knight_night") and GameState.has_flag("dlg_floor_06/after_knight_fall_no"))
	verify(t, "拿出手帕 → 蓝色公主走出来（他懵了，喊守卫）→「又是这副花猫样」", GameState.has_flag("knight_asked_hanky") and GameState.has_flag("dlg_floor_06/after_knight_blue")
		and t.seen_cuts.has("knight_cell_end"))
	var cell: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogues/floor_06/after_knight.json"))
	var blue_lines := (cell["nodes"]["blue"]["lines"] as Array).map(func(l): return str(l["text"]))
	verify(t, "蓝色公主进来时他不叫「殿下」、不下跪", not blue_lines.any(func(s): return s.contains("殿下") or s.contains("跪")))
	await t._advance_until(func(): return t._level_id() == AfterStory.HOUSE and not Cutscene.is_playing() and not KnightStory.running, 60.0)
	await t._wait(0.5)
	var mk3 := t._node("Objective") as ObjectiveMarker
	verify(t, "溜回小屋门口：还是夜里，不自动睡，目标「回床上睡觉」（%s）" % (mk3.text if mk3 else ""), t._level_id() == AfterStory.HOUSE
		and DayClock.slot() == DayClock.NIGHT and KnightStory.step_id() == "sleep" and KnightStory.can_sleep() and mk3 != null and mk3.text.contains("床"))
	var day := DayClock.day()
	AfterStory.sleep()
	await t._advance_until(func(): return KnightStory.step_id() == "report" and not Sleep.sleeping and not KnightStory.running, 30.0)
	verify(t, "床上睡一觉 → 第二天早上（%s），不自动开演诅咒失控" % DayClock.label(), DayClock.day() == day + 1 and DayClock.slot() == DayClock.MORNING
		and KnightStory.step_id() == "report" and not t.seen_cuts.has("knight_erupt"))
	# 审问椅本身
	InterrogationChairShow.quiet = true
	var ch := InterrogationChairShow.new()
	t.get_tree().root.add_child(ch)
	ch.play()
	await t._advance_until(func(): return not ch.busy, 3.0)
	verify(t, "挠痒审问椅：两个队员（%s）" % [ch.actors.keys()], ch.actors.has("guard") and ch.actors.has("guard2"))
	ch.player.laugh.set_value(ch.laugh_max() * 0.5)
	var l1 := ch.player.laugh.value
	ch.press("J")
	verify(t, "J 挣扎：闷笑压下去一点", ch.player.laugh.value < l1)
	var left0 := ch.left
	ch.recover()
	verify(t, "笑出声：加时", ch.left > left0 and ch.bursts == 1)
	ch.recovery_left = 0.0
	ch.left = 0.05
	ch.simulate(0.1)
	await t._advance_until(func(): return ch._done, 5.0)
	verify(t, "撑过时间：放走", ch._success)
	ch.queue_free()
	InterrogationChairShow.quiet = false

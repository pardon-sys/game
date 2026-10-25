extends RefCounted
## 庆功宴专项（第 7 天晚上）：工时还清才开、从小镇篝火西边的入口进庆功宴的广场（单独一张图）、开场过场、领舞（三段音游 + 邀舞）、
## 五个摊位各自的机制、通关的奖励和广场上的装扮、放烟花（镜头拉远）→ 结局画面 → 回小屋 → 睡觉进骑士篇。
static var checks := 0
static var reward_lines_seen := 0


static func verify(t: Node, label: String, ok: bool) -> void:
	checks += 1
	t.check(label, ok)


static func show_of(t: Node, cls: Variant) -> Node:
	return t._show(cls)


## 走到某个摊主身边说话（选第一项「开始」），等小游戏开演
static func open_stall(t: Node, file: String, cls: Variant) -> Node:
	await t._talk(file, "stall_offer", [0])
	await t._advance_until(func(): return show_of(t, cls) != null and not show_of(t, cls).busy, 10.0)
	return show_of(t, cls)


## 等小游戏收场：通关以后摊主说两句奖品（一路按掉），奖品进背包
static func wait_closed(t: Node, cls: Variant) -> void:
	var said := false
	for i in 600:
		if Dialogue.is_active():
			said = said or str(Dialogue._id).begins_with("festival_reward_")
			Dialogue._finish_typing()
			Dialogue.advance()
		if show_of(t, cls) == null and not AfterFestival.running and not Dialogue.is_active():
			break
		await t.get_tree().process_frame
	if said:
		reward_lines_seen += 1


static func run(t: Node) -> void:
	checks = 0
	reward_lines_seen = 0
	for f in ["after_started", "penance_book", "f6_opening_done", "after_done_d7_morning", "after_done_d7_afternoon", "errand_dance_done"]:
		GameState.set_flag(f)
	for f in [AfterFestival.ON, AfterFestival.DANCE_DONE, AfterFestival.FINALE_DONE, "after_ev_d7_festival", "after_done_d7_night"]:
		GameState.set_flag(f, false)
	for id in AfterFestival.STALLS:
		GameState.set_flag("stall_%s_done" % id, false)
	DayClock.set_time(7, DayClock.NIGHT)
	GameState.vars["penance_hours"] = 5
	verify(t, "日程：第 7 天晚上是庆功宴（工时还清才开）", DayClock.event(7, DayClock.NIGHT) == "d7_festival" and bool(AfterStory.EVENTS["d7_festival"].get("needs_clear", false)))
	verify(t, "还欠 5 工时：庆功宴不开、目标是补罚", AfterStory.pending_event() == "" and AfterStory.objective(AfterStory.TOWN).get("text", "").contains("补罚"))
	GameState.vars["penance_hours"] = 0
	verify(t, "工时还清：庆功宴开放", AfterStory.pending_event() == "d7_festival")
	GameState.pending_spawn = "from_house"
	await t.main.change_level(Floors.scene(AfterStory.TOWN))
	await t._wait(0.8)
	var door: Dictionary = AfterStory.objective(AfterStory.TOWN)
	verify(t, "小镇上的目标指向篝火西边庆功宴的入口（%s）" % [door.get("cell")], door.get("cell") == AfterStory.TOWN_DOORS[AfterStory.FESTIVAL]
		and GameState.has_flag(AfterStory.FESTIVAL_OPEN))
	var towners: Array = t.main.level.find_children("*", "Resident", true, false).filter(func(n): return n.visible and str(n.name) in ["after_granny", "after_captain", "after_kid_lily"])
	verify(t, "小镇上不再摆庆功宴的人（奶奶、队长、小莉莉都不在：%s）" % [towners.map(func(n): return n.name)], towners.is_empty())
	t._go(Cutscene.cell_to_world(AfterStory.TOWN_DOORS[AfterStory.FESTIVAL]))
	await t._advance_until(func(): return t._level_id() == AfterStory.FESTIVAL and GameState.has_flag(AfterFestival.ON) and not Cutscene.is_playing() and not AfterStory.running, 30.0)
	verify(t, "走进入口 → 庆功宴的广场 → 开场过场 → 庆功宴开始（床不能睡）", t._level_id() == AfterStory.FESTIVAL and t.seen_cuts.has("after_d7_festival")
		and AfterFestival.active() and GameState.has_flag(AfterStory.NIGHT_BUSY))
	verify(t, "目标：先去领舞；小镇上指回庆功宴的入口", AfterStory.objective(AfterStory.FESTIVAL).get("text", "").contains("领舞")
		and AfterStory.objective(AfterStory.TOWN).get("cell") == AfterStory.TOWN_DOORS[AfterStory.FESTIVAL])
	verify(t, "派对主人的对话：领舞入口排第一", Dialogue.runner.entry_of("floor_06/after_fest_host") == "festival_dance")
	verify(t, "镇长：先去跳舞", Dialogue.runner.entry_of("floor_06/after_fest_mayor") == "festival_wait")
	verify(t, "队长、小莉莉、市场监督：庆功宴专属的对话（领舞前）", Dialogue.runner.entry_of("floor_06/after_fest_captain") == "before"
		and Dialogue.runner.entry_of("floor_06/after_fest_lily") == "before" and Dialogue.runner.entry_of("floor_06/after_fest_supervisor") == "before")
	var bp := Backpack.new()
	verify(t, "背包里不再有赎罪簿页（%s）" % [bp.page_order()], not bp.page_order().has(Backpack.PAGE_PENANCE))
	bp.free()
	verify(t, "装扮：摊位没通关时冰块还是冰块，冰雕、饼干串灯、咕咕都不在", _prop_visible(t, "ice_raw") and not _prop_visible(t, "ice_sheep")
		and not _prop_visible(t, "cookie_lights") and not _npc_visible(t, "after_fest_gugu"))
	# 领舞
	FestivalDanceShow.quiet = true
	FestivalDanceShow.auto_picks = [0, 3, 2]
	FestivalDanceShow.auto_combo = true
	await t._talk("floor_06/after_fest_host", "festival_dance", [0])
	await t._advance_until(func(): return show_of(t, FestivalDanceShow) != null, 5.0)
	var d := show_of(t, FestivalDanceShow) as FestivalDanceShow
	verify(t, "领舞开演：两位公主都在舞台上", d != null and d.actors.has("princess") and d.actors.has("blue"))
	if d == null:
		return
	verify(t, "四段：领舞 / 邀舞 / 双人舞 / 全镇", d.text()["sections"].map(func(s): return s["kind"]) == ["lane", "invite", "lane", "lane"])
	var l0 := GameState.player.laugh.value
	d.lane.load_chart([{"t": 0.0, "key": "UP", "hit": false}])
	d.lane.advance(1.0)
	verify(t, "领舞踩错一拍：围观的人挠脚心，闷笑上涨", d.misses >= 1 and GameState.player.laugh.value > l0)
	# 直接把领舞段判完：满分谱面
	for sec in 4:
		await t._advance_until(func(): return not d.busy or not is_instance_valid(d), 5.0)
		if not is_instance_valid(d) or d._done:
			break
		if str(d.cur().get("kind", "")) == "invite":
			continue
		d.lane.load_chart([])
		d.lane.time = 99.0
		await t._wait(0.2)
	await t._advance_until(func(): return show_of(t, FestivalDanceShow) == null and not AfterFestival.running, 20.0)
	verify(t, "邀舞：嘴硬值挠到 0（腰 → 屁股 + 连击 → 大腿 + 连击），跳完领舞", GameState.has_flag(AfterFestival.DANCE_DONE))
	FestivalDanceShow.quiet = false
	FestivalDanceShow.auto_picks = []
	FestivalDanceShow.auto_combo = null
	verify(t, "目标：逛摊位 / 找镇长放烟花", AfterStory.objective(AfterStory.FESTIVAL).get("text", "").contains("烟花"))
	verify(t, "领舞以后：队长换了一套话", Dialogue.runner.entry_of("floor_06/after_fest_captain") == "after")
	# 五个摊位
	StallGuessShow.quiet = true
	var g := await open_stall(t, "floor_06/after_fest_granny", StallGuessShow) as StallGuessShow
	verify(t, "脚底猜猜乐：奶奶的摊位开演，四个选项里有答案", g != null and g.options.size() == 4 and g.options.has(g.tool))
	if g:
		g.state_left = 0.0
		g.simulate(0.1)
		verify(t, "挠一阵以后轮到猜", g.state == "guess")
		var wrong := g.options.find(g.options.filter(func(o): return o != g.tool)[0])
		g.completed = 1
		g.guess(wrong)
		verify(t, "猜错：连对清零、罚挠（闷笑涨得快）", g.completed == 0 and g.state == "wrong")
		while is_instance_valid(g) and not g._done:
			await t._advance_until(func(): return not is_instance_valid(g) or not g.busy or g._done, 3.0)
			if not is_instance_valid(g) or g._done:
				break
			g.state = "guess"
			g.guess(g.options.find(g.tool))
		await wait_closed(t, StallGuessShow)
		verify(t, "连对三次：通关", AfterFestival.stall_done("guess"))
		verify(t, "奖励：奶奶的饼干 ×3；摊位上挂起了饼干串灯", GameState.inventory.count("cookie") == 3 and _prop_visible(t, "cookie_lights"))
		verify(t, "奶奶：领舞以后再来，多聊几句（late）", Dialogue.runner.entry_of("floor_06/after_fest_granny") == "late")
	StallGuessShow.quiet = false
	StallRingShow.quiet = true
	var r := await open_stall(t, "floor_06/after_fest_merchant", StallRingShow) as StallRingShow
	verify(t, "忍笑套圈：商人的摊位开演", r != null)
	if r:
		r.aim = StallRingShow.PEGS[2]
		r.elapsed = 0.0
		GameState.player.laugh.set_value(0.0)
		r.jolt_left = 0.0
		verify(t, "准星对准木桩：套中", r.throw())
		await t._advance_until(func(): return not r.busy, 2.0)
		r.aim = (StallRingShow.PEGS[2] + StallRingShow.PEGS[3]) * 0.5
		r.flying = 0.0
		verify(t, "准星在两根木桩中间：没套中", not r.throw())
		GameState.player.laugh.set_value(GameState.player.laugh.max_value * 0.9)
		var a0 := r.aim_x()
		r.elapsed = 0.12
		verify(t, "闷笑越高准星越乱（%.1f → %.1f）" % [a0, r.aim_x()], absf(r.aim_x() - r.aim) > 0.5)
		GameState.player.laugh.set_value(0.0)
		var i := 0
		while is_instance_valid(r) and not r._done:
			await t._advance_until(func(): return not is_instance_valid(r) or not r.busy or r._done, 2.0)
			if not is_instance_valid(r) or r._done:
				break
			GameState.player.laugh.set_value(0.0)
			r.aim = StallRingShow.PEGS[i % 6]
			r.jolt_left = 0.0
			r.flying = 0.0
			r.throw()
			i += 1
		await wait_closed(t, StallRingShow)
		verify(t, "套中六个：通关", AfterFestival.stall_done("ring"))
		verify(t, "奖励：木头小羊 + 薄荷糖；戴彩色发绳的小孩跑出来了", GameState.inventory.count("souvenir_wood_sheep") == 1
			and _prop_visible(t, "ribbon_line") and _npc_visible(t, "after_fest_ribbon_kids"))
	StallRingShow.quiet = false
	StallIceShow.quiet = true
	var ice := await open_stall(t, "floor_06/after_fest_engineer", StallIceShow) as StallIceShow
	verify(t, "冰雕摊：蓝色公主上场刻冰雕，粉色公主在旁边", ice != null and ice.actors.has("blue") and ice.actors.has("pink"))
	if ice:
		var c0 := ice.completed
		ice.carve(ice.want)
		await t._advance_until(func(): return not ice.busy, 2.0)
		verify(t, "按对方向：刻一刀", ice.completed == c0 + 1)
		var wrong_key: String = StallIceShow.KEYS.filter(func(k): return k != ice.want)[0]
		ice.carve(wrong_key)
		verify(t, "按错：刀一滑", ice.slips == 1 and ice.completed == c0 + 1)
		ice.blue_laugh = 0.8
		verify(t, "J 冰封：蓝色公主的闷笑压下去，有冷却", ice.freeze() and ice.blue_laugh < 0.8 and not ice.freeze())
		ice.blue_laugh = 1.0
		ice.recovery_left = 0.0
		ice.simulate(0.05)
		verify(t, "她笑满：冰雕笑塌了，这一座从头刻", ice.collapses == 1 and ice.completed == ice.phase_start())
		ice.recovery_left = 0.0
		while is_instance_valid(ice) and not ice._done:
			await t._advance_until(func(): return not is_instance_valid(ice) or not ice.busy or ice._done, 3.0)
			if not is_instance_valid(ice) or ice._done:
				break
			ice.blue_laugh = 0.0
			ice.carve(ice.want)
		await wait_closed(t, StallIceShow)
		verify(t, "三座冰雕刻完：通关", AfterFestival.stall_done("ice"))
		verify(t, "奖励：冰雕小羊；广场上真的摆出了三座冰雕（冰块不见了）", GameState.inventory.count("souvenir_ice_sheep") == 1
			and _prop_visible(t, "ice_sheep") and _prop_visible(t, "ice_lantern") and _prop_visible(t, "ice_girls") and not _prop_visible(t, "ice_raw"))
	StallIceShow.quiet = false
	StallFishShow.quiet = true
	var fs := await open_stall(t, "floor_06/after_fest_tom", StallFishShow) as StallFishShow
	verify(t, "捞痒痒鱼：小汤姆的摊位开演，盆里 %d 条鱼" % (fs.fish.size() if fs else 0), fs != null and fs.fish.size() == StallFishShow.FISH_COUNT)
	if fs:
		for f in fs.fish:
			f["pos"] = StallFishShow.FEET
		var l1 := GameState.player.laugh.value
		fs.simulate(0.2)
		verify(t, "鱼聚在脚边：在啄（%d 条），闷笑上涨" % fs.nibbling(), fs.nibbling() > 0 and GameState.player.laugh.value > l1)
		verify(t, "K 抬脚：鱼散开、不再啄", fs.lift() and fs.nibbling() == 0)
		fs.fish[0]["pos"] = Vector2(fs.net_x, 0)
		var w0 := fs.wear
		verify(t, "网下面有鱼：捞到一条，网湿了一点", fs.scoop() and fs.completed == 1 and fs.wear > w0)
		await t._advance_until(func(): return not fs.busy, 2.0)
		fs.wear = 0.9
		fs.fish[0]["pos"] = Vector2(-99, -99)
		fs.scoop()
		verify(t, "网湿透：破了，换下一张", fs.nets == StallFishShow.NETS - 1 and fs.wear == 0.0)
		while is_instance_valid(fs) and not fs._done:
			await t._advance_until(func(): return not is_instance_valid(fs) or not fs.busy or fs._done, 3.0)
			if not is_instance_valid(fs) or fs._done:
				break
			fs.wear = 0.0
			fs.fish[0]["pos"] = Vector2(fs.net_x, 0)
			fs.scoop()
		await wait_closed(t, StallFishShow)
		verify(t, "捞够六条：通关", AfterFestival.stall_done("fish"))
		verify(t, "奖励：足疗鱼小盆；鱼盆搬到了篝火边", GameState.inventory.count("souvenir_fish_basin") == 1 and _prop_visible(t, "fish_basin"))
	StallFishShow.quiet = false
	StallLickShow.quiet = true
	var lk := await open_stall(t, "floor_06/after_fest_maid", StallLickShow) as StallLickShow
	verify(t, "舔盐耐力赛：女仆主持，对手派对主人", lk != null and lk.actors.has("host"))
	if lk:
		GameState.player.laugh.set_value(GameState.player.laugh.max_value * 0.5)
		lk.press("J")
		var l2 := GameState.player.laugh.value
		lk.simulate(0.5)
		verify(t, "J 绷住脚趾：闷笑往下压、耗体力", GameState.player.laugh.value < l2 and lk.stamina < 1.0)
		lk.press("J")
		GameState.player.laugh.set_value(GameState.player.laugh.max_value * 0.8)
		var h0 := lk.host_laugh
		lk.simulate(0.2)
		var edge_gain := lk.host_laugh - h0
		GameState.player.laugh.set_value(GameState.player.laugh.max_value * 0.2)
		h0 = lk.host_laugh
		lk.simulate(0.2)
		verify(t, "停在临界点：主人那边涨得更快（%.3f > %.3f）" % [edge_gain, lk.host_laugh - h0], edge_gain > lk.host_laugh - h0)
		lk.recover()
		verify(t, "她先笑满：这一局输，重来", lk.rounds == 2 and is_equal_approx(lk.host_laugh, StallLickShow.ROUND_RESET))
		lk.recovery_left = 0.0
		lk.host_laugh = 0.99
		GameState.player.laugh.set_value(0.0)
		lk.simulate(0.5)
		await wait_closed(t, StallLickShow)
		verify(t, "主人先笑满：赢了", AfterFestival.stall_done("lick"))
		verify(t, "奖励：咕咕的铃铛项圈；戴铃铛的咕咕在广场上闲逛", GameState.inventory.count("souvenir_bell_collar") == 1 and _npc_visible(t, "after_fest_gugu"))
	verify(t, "每个摊位通关：摊主都先说两句奖品（%d / 5）" % reward_lines_seen, reward_lines_seen == 5)
	verify(t, "五个摊位都通关：队长、蓝色公主有专门的话", Dialogue.runner.entry_of("floor_06/after_fest_captain") == "all"
		and Dialogue.runner.entry_of("floor_06/after_partner") == "fest_all")
	StallLickShow.quiet = false
	# 放烟花
	verify(t, "镇长：可以放烟花了", Dialogue.runner.entry_of("floor_06/after_fest_mayor") == "festival_finale")
	var fin: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cutscenes/floor_06/after_d7_finale.json"))
	verify(t, "放烟花时镜头拉远（zoom < 1）看全景", fin["steps"].any(func(st): return st is Dictionary and st.get("actions", []).any(
		func(a): return str(a.get("do", "")) == "camera" and float(a.get("zoom", 1.0)) < 0.7)))
	await t._talk("floor_06/after_fest_mayor", "festival_finale", [0])
	await t._advance_until(func(): return t.get_tree().get_first_node_in_group("main").level.find_children("*", "FestivalFireworks", true, false).size() > 0, 5.0)
	var fws: Array = t.get_tree().get_first_node_in_group("main").level.find_children("*", "FestivalFireworks", true, false)
	verify(t, "烟花铺开到拉远以后的镜头（spread %.1f）" % (fws[0].spread if fws.size() > 0 else 0.0), fws.size() > 0 and fws[0].spread > 1.5)
	await t._advance_until(func(): return Cutscene.chapter_screen.visible and not Cutscene.is_playing(), 60.0)
	verify(t, "烟花 → 哼歌 →「七日赎罪 完」结局画面", t.seen_cuts.has("after_d7_finale") and Cutscene.chapter_title.text.contains("七日赎罪") and DayClock.done(7, DayClock.NIGHT))
	# 像真的玩一样：站在镇长身边按 E 继续（这一下不能顺手又和镇长说起放烟花）
	var mayor: Node2D = t.main.level.find_children("*", "Resident", true, false).filter(func(n): return (n as Resident).dialogue.ends_with("after_fest_mayor"))[0]
	t._go(mayor.global_position + Vector2(0, 14))
	await t._wait(0.2)
	await press(t, "interact")
	await t._advance_until(func(): return t._level_id() == AfterStory.HOUSE and not Cutscene.chapter_screen.visible, 20.0)
	verify(t, "按 E → 回到小屋", t._level_id() == AfterStory.HOUSE)
	await t._wait(0.8)
	verify(t, "回到小屋：没有又弹出镇长放烟花的对话，人能动（对话 %s，锁 %d）" % [Dialogue.runner.is_running(), GameState.dialogue_holds],
		not Dialogue.runner.is_running() and not Dialogue.is_active() and not GameState.in_dialogue and GameState.dialogue_holds == 0)
	verify(t, "小屋的床：庆功宴之后能睡（%s）" % Dialogue.runner.entry_of("floor_06/after_house_objects"),
		GameState.has_flag("night") and not GameState.has_flag(AfterStory.NIGHT_BUSY))
	# 走到床边按 E（不是直接调对话）
	t._go(Cutscene.cell_to_world([4, 5]))
	GameState.player.facing = Vector2.UP
	await t._wait(0.3)
	var opened: Array = []
	var on_talk := func(f: String): opened.append(f)
	Dialogue.runner.talk_started.connect(on_talk)
	await press(t, "interact")
	await t._wait(0.3)
	Dialogue.runner.talk_started.disconnect(on_talk)
	verify(t, "在床边按 E：床的对话开了（%s）" % [opened], opened.has("floor_06/after_house_objects"))
	for i in 40:
		if not Dialogue.runner.is_running():
			break
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await t.get_tree().process_frame
	await t._advance_until(func(): return KnightStory.step_id() == "found" and not Sleep.sleeping and not Cutscene.is_playing() and not KnightStory.running, 40.0)
	verify(t, "和床说话选睡觉 → 骑士篇开始（%s）" % DayClock.label(), KnightStory.active() and DayClock.label().begins_with("骑士篇"))


static func _prop_visible(t: Node, kind: String) -> bool:
	var lv: Node = t.get_tree().get_first_node_in_group("main").level
	return lv.find_children("*", "Node2D", true, false).any(func(n): return n.get_script() == preload("res://scripts/objects/prop.gd") and n.kind == kind and n.is_visible_in_tree())


static func _npc_visible(t: Node, file: String) -> bool:
	var lv: Node = t.get_tree().get_first_node_in_group("main").level
	return lv.find_children("*", "Resident", true, false).any(func(n): return (n as Resident).dialogue == "floor_06/" + file and n.visible)


## 真的按一下键（走输入事件：_input 和 Input.is_action_just_pressed 都会收到）
static func press(t: Node, action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await t.get_tree().process_frame
	await t.get_tree().physics_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await t.get_tree().process_frame

extends RefCounted
## 骑士篇的四个支线专项：开放的时间窗口、「！」、接下以后主线的触发让路、光脚地面的数值、手印碎片 / 手印团 / 爬墙手印、
## 骑士救公主（三处 + 和小莉莉比谁先笑）、手印样本（石板路 / 铁门 / 地窖 → 回去找奶奶）、队长的旧剑术（三轮、挨打、完美闪避）、
## 夜里的栅栏（扛木板、钉门、房檐上的手印）、先放一放、错过时间窗口、做完的奖励和帮手标记、千手解放对新怪物生效。
static var checks := 0


static func verify(t: Node, label: String, ok: bool) -> void:
	checks += 1
	t.check(label, ok)


static func runner(t: Node, id: String) -> Node:
	return t._node("Quest_" + id)


static func go_town(t: Node, spawn := "from_house") -> void:
	GameState.pending_spawn = spawn
	await t.main.change_level(Floors.scene(AfterStory.TOWN))
	await t._wait(0.8)


static func run(t: Node) -> void:
	checks = 0
	for f in ["after_started", "penance_book", "f6_opening_done", AfterFestival.ON, AfterFestival.DANCE_DONE, AfterFestival.FINALE_DONE,
			"after_done_d7_morning", "after_done_d7_afternoon", "after_done_d7_night", "after_ev_d7_festival", "blue_tickle_pants"]:
		GameState.set_flag(f)
	GameState.vars["penance_hours"] = 0
	for id in ["shoes", "samples", "spear", "fence"]:
		for k in ["open", "active", "done"]:
			GameState.set_flag("kq_%s_%s" % [id, k], false)
		GameState.vars.erase("kq_%s_stage" % id)
	GameState.set_flag(KnightQuests.ACTIVE_FLAG, false)
	verify(t, "四个支线的数据（%s）" % [KnightQuests.ids()], KnightQuests.ids().size() == 4 and KnightQuests.info("shoes").has("duel"))
	# 第一天早上：只开骑士救公主
	KnightStory.jump("found")
	await go_town(t)
	KnightQuests.refresh()
	verify(t, "第一天早上：骑士救公主开着，手印样本 / 旧剑术（下午）/ 栅栏（夜里）还没开", KnightQuests.is_open("shoes")
		and not KnightQuests.is_open("samples") and not KnightQuests.is_open("spear") and not KnightQuests.is_open("fence"))
	var kids := t._node("after_k_kids") as Node2D
	var gd := t._node("after_k_guard_dungeon") as Node2D
	verify(t, "孩子们和地牢入口的队员头上都冒「！」", kids != null and kids.get_node_or_null("ErrandMark") != null and gd.get_node_or_null("ErrandMark") != null)
	var mk := t._node("Objective") as ObjectiveMarker
	verify(t, "主线目标后面挂着开着的支线（%s）" % (mk.text if mk else ""), mk != null and mk.text.contains("骑士救公主"))
	# ---------------------------------------------------------------- ① 骑士救公主
	KnightQuests.start("shoes")
	await t._advance_until(func(): return runner(t, "shoes") != null and not Cutscene.is_playing(), 20.0)
	var rs := runner(t, "shoes") as QuestShoes
	var pink: PlayableCharacter = GameState.player
	verify(t, "接下：孩子们抢走了鞋（%s）→ 光着脚、摆上玩法节点" % t.seen_cuts.has("kq_shoes_start"), rs != null and t.seen_cuts.has("kq_shoes_start")
		and pink.has_meta(&"barefoot") and pink.has_buff("barefoot"))
	if rs == null:
		return
	await t._wait(0.2)
	var went := await KnightStory.go()
	verify(t, "做支线的时候：主线的「！」收起来、和队员说话不开演、床上不能休息", gd.get_node_or_null("ErrandMark") == null
		and not went and not KnightStory.can_rest())
	await t._wait(0.2)
	verify(t, "目标换成支线这一段（%s）" % mk.text, mk.text.contains("草"))
	var floors: Array = rs.spawned.filter(func(n): return n is BareFloor)
	verify(t, "三片光脚地面、三个小孩", floors.size() == 3 and rs.spawned.filter(func(n): return n is AfterKid).size() == 3)
	var straw: BareFloor = floors.filter(func(f): return f.kind == "straw")[0]
	var feather: BareFloor = floors.filter(func(f): return f.kind == "feather")[0]
	var pebble: BareFloor = floors.filter(func(f): return f.kind == "pebble")[0]
	pink.laugh.set_value(0.0)
	t._go(straw.rect().get_center())
	straw._last = pink.global_position
	pink.global_position += Vector2(BareFloor.STRAW_STEP + 1.0, 0)
	straw.tick(pink, 0.016)
	verify(t, "稻草垫：走一步扎一下（闷笑 %.1f%%）" % (pink.laugh.ratio() * 100.0), is_equal_approx(pink.laugh.ratio(), BareFloor.STRAW_LAUGH))
	pink.laugh.set_value(0.0)
	feather.tick(pink, 1.0)
	verify(t, "羽毛堆：一秒 +%.0f%%，走得慢（feather_floor）" % (pink.laugh.ratio() * 100.0), is_equal_approx(pink.laugh.ratio(), BareFloor.FEATHER_RATE) and pink.has_buff("feather_floor"))
	pink.laugh.set_value(0.0)
	pink.fatigue.set_value(0.0)
	pebble.tick(pink, 0.5)
	var l1 := pink.laugh.value
	pebble.tick(pink, 1.0)
	verify(t, "鹅卵石：一会儿痒（闷笑 %.1f）一会儿舒服（疲倦 %.1f）" % [l1, pink.fatigue.value], l1 > 0.0 and pink.fatigue.value > 0.0)
	pink.laugh.set_value(0.0)
	pink.remove_meta(&"barefoot")
	var before := pink.laugh.value
	t._go(feather.rect().get_center())
	await t._wait(0.3)
	verify(t, "穿着鞋（不光脚）踩上去没事", is_equal_approx(pink.laugh.value, before))
	pink.set_meta(&"barefoot", true)
	# 0 草垛
	t._go(rs.spot.global_position)
	rs.search_held = true
	await t._advance_until(func(): return KnightQuests.stage("shoes") == 1, 6.0)
	rs.search_held = false
	verify(t, "草垛旁按住 E 翻找 → 第一只鞋（第 %d 段）" % KnightQuests.stage("shoes"), KnightQuests.stage("shoes") == 1)
	await t._wait(0.2)
	# 1 彩带：要站在羽毛堆上够
	t._go(rs.spot.global_position + Vector2(0, -40))
	rs.search_held = true
	await t._wait(0.5)
	verify(t, "不站在羽毛堆上够不着", KnightQuests.stage("shoes") == 1 and rs.progress <= 0.01)
	t._go(rs.spot.global_position)
	await t._advance_until(func(): return KnightQuests.stage("shoes") == 2, 6.0)
	rs.search_held = false
	verify(t, "站上羽毛堆按住 E 够下来 → 第二只鞋", KnightQuests.stage("shoes") == 2)
	await t._wait(0.2)
	# 2 小莉莉：谁先笑
	LilyDuelShow.quiet = true
	LilyDuelShow.fixed_seed = 3
	verify(t, "小路尽头坐着小莉莉", rs.lily != null)
	t._go(rs.lily.global_position + Vector2(0, 10))
	await t._advance_until(func(): return t.get_tree().root.get_children().any(func(n): return n is LilyDuelShow and n.playing), 5.0)
	var duel: LilyDuelShow = null
	for n in t.get_tree().root.get_children():
		if n is LilyDuelShow:
			duel = n
	verify(t, "走到她身边：开始比「谁先笑」", duel != null)
	if duel:
		await t._advance_until(func(): return not duel.busy, 3.0)
		var key: String = ["A", "S", "D"][duel.weak]
		var lily0 := duel.lily_laugh
		duel.press(key)
		verify(t, "挠中她喊漏嘴的弱点：莉莉的笑 +%.0f%%" % ((duel.lily_laugh - lily0) * 100.0), is_equal_approx(duel.lily_laugh - lily0, LilyDuelShow.HIT))
		duel._press = 0.0
		var wrong: String = ["A", "S", "D"][(duel.weak + 1) % 3]
		lily0 = duel.lily_laugh
		duel.press(wrong)
		verify(t, "挠错地方：只 +%.0f%%" % ((duel.lily_laugh - lily0) * 100.0), is_equal_approx(duel.lily_laugh - lily0, LilyDuelShow.MISS))
		duel._start_turn("defend")
		duel.warn_left = LilyDuelShow.WARN
		verify(t, "被挠的时候亮「！」按 J 缩脚：躲开这一下", duel.tuck() and duel.warn_left <= 0.0)
		var p0 := duel.player.laugh.value
		duel.warn_left = 0.01
		duel.simulate(0.05)
		verify(t, "没缩脚：狠狠一下（闷笑 +%.0f）" % (duel.player.laugh.value - p0), duel.player.laugh.value - p0 >= duel.laugh_max() * LilyDuelShow.POKE_LAUGH * 0.9)
		duel._start_turn("attack")
		duel.lily_laugh = 0.95
		duel._press = 0.0
		duel.press(["A", "S", "D"][duel.weak])
	await t._advance_until(func(): return GameState.inventory.count("knight_medal") > 0 and not Cutscene.is_playing(), 20.0)
	await t._wait(0.3)
	verify(t, "莉莉先笑满：鞋还回来、骑士勋章、红绳（引向主线）%s" % [[KnightQuests.is_done("shoes"), t.seen_cuts.has("kq_shoes_done"), GameState.inventory.count("knight_medal"), pink.has_meta(&"barefoot"), KnightQuests.is_active("shoes")]], KnightQuests.is_done("shoes") and t.seen_cuts.has("kq_shoes_done")
		and GameState.inventory.count("knight_medal") == 1 and not pink.has_meta(&"barefoot") and not KnightQuests.is_active("shoes"))
	LilyDuelShow.quiet = false
	LilyDuelShow.fixed_seed = -1
	await t._wait(0.3)
	verify(t, "做完以后：玩法节点收走、主线的「！」回来了", runner(t, "shoes") == null and gd.get_node_or_null("ErrandMark") != null)
	# ---------------------------------------------------------------- ② 手印样本（下午）
	KnightStory.jump("afternoon")
	GameState.pending_spawn = "from_town"
	await t.main.change_level(Floors.scene(KnightStory.PHARMACY))
	await t._wait(0.6)
	KnightQuests.refresh()
	verify(t, "下午：手印样本、队长的旧剑术开了", KnightQuests.is_open("samples") and KnightQuests.is_open("spear") and not KnightQuests.is_open("fence"))
	await t._talk("floor_06/after_pharm", "")
	verify(t, "和奶奶说话接下手印样本", KnightQuests.is_active("samples") and KnightQuests.stage("samples") == 0)
	await t._talk("floor_06/after_pharm", "", [1])
	verify(t, "再找她：可以先放一放（阶段清零、回到能接）", not KnightQuests.is_active("samples") and KnightQuests.is_open("samples"))
	await t._talk("floor_06/after_pharm", "")
	await go_town(t, "from_pharmacy")
	var rp := runner(t, "samples") as QuestSamples
	verify(t, "石板路：几块石头里藏着一块碎片", rp != null and rp.shards.size() == 1 and rp.spawned.size() == 3)
	if rp == null:
		return
	var sh: HandShard = rp.shards[0]
	pink = rp.pink
	t._go(sh.home + Vector2(30, 0))
	KnightLaugh.force_hold = true
	await t._advance_until(func(): return sh.state in ["peek", "crawl", "caught"], 3.0)
	verify(t, "按住 Y 故意笑：碎片探头（%s）" % sh.state, sh.state in ["peek", "crawl", "caught"])
	await t._advance_until(func(): return KnightQuests.stage("samples") == 1, 6.0)
	KnightLaugh.force_hold = false
	KnightLaugh.reset()
	verify(t, "爬到她脚边拍拍脚背、乖乖进瓶子 → 下一处（铁门）", KnightQuests.stage("samples") == 1)
	await t._wait(0.3)
	rp = runner(t, "samples") as QuestSamples
	sh = rp.shards[0]
	var blue: PlayableCharacter = rp.blue
	GameState.switch_control(blue)
	await t._wait(0.2)
	blue.laugh.set_value(0.0)
	blue.global_position = sh.home + Vector2(20, 0)
	await t._advance_until(func(): return sh.state == "flee", 2.0)
	verify(t, "蓝色公主走近：碎片逃开", sh.state == "flee")
	sh._flee_t = HandShard.CORNER_TIME
	blue.global_position = sh.global_position + Vector2(10, 0)
	await t._advance_until(func(): return sh.state == "hidden", 2.0)
	verify(t, "被逼急了：扑上去挠蓝色公主的大腿（闷笑 %.0f）" % blue.laugh.value, blue.laugh.value > 0.0)
	sh.state = "crawl"
	sh.global_position = blue.global_position + Vector2(8, 0)
	verify(t, "蓝色公主 J 冻住（%d）、E 装瓶" % rp.freeze_near(blue), sh.state == "frozen" and rp.bottle_near(blue) == 1)
	await t._advance_until(func(): return KnightQuests.stage("samples") == 2, 3.0)
	GameState.switch_control(pink)
	await t._wait(0.2)
	verify(t, "第三处：工房的地窖，活板门开了（kq_samples_cellar）", KnightQuests.stage("samples") == 2 and GameState.has_flag("kq_samples_cellar"))
	GameState.pending_spawn = "from_pharmacy"
	await t.main.change_level(Floors.scene(KnightStory.CELLAR))
	await t._wait(0.6)
	rp = runner(t, "samples") as QuestSamples
	verify(t, "地窖里一团手印（%s）" % t._level_id(), t._level_id() == KnightStory.CELLAR and rp != null and is_instance_valid(rp.cluster))
	if rp == null:
		return
	var parts: Array = rp.cluster.split()
	verify(t, "冻住 / 拍散：裂成 %d 块碎片" % parts.size(), parts.size() == HandCluster.SPLIT and rp.shards.size() == HandCluster.SPLIT)
	for s in rp.shards:
		s._caught_by_pink(rp.pink)
	await t._advance_until(func(): return KnightQuests.stage("samples") == 3, 3.0)
	verify(t, "三块都收了 → 回去找奶奶（她头上冒「！」）", KnightQuests.stage("samples") == 3 and KnightQuests.marked_npcs().has("after_pharm"))
	GameState.pending_spawn = "from_cellar"
	await t.main.change_level(Floors.scene(KnightStory.PHARMACY))
	await t._wait(0.6)
	await t._talk("floor_06/after_pharm", "")
	await t._advance_until(func(): return GameState.inventory.count("calm_incense") > 0 and not Cutscene.is_playing(), 20.0)
	verify(t, "交给奶奶：笑声做的、一直往盔甲那边爬 → 安神香", KnightQuests.is_done("samples") and GameState.inventory.count("calm_incense") == 1
		and t.seen_cuts.has("kq_samples_done"))
	# ---------------------------------------------------------------- ③ 队长的旧剑术
	await go_town(t, "from_pharmacy")
	await t._talk("floor_06/after_k_captain", "")
	await t._advance_until(func(): return KnightQuests.is_active("spear") and not Cutscene.is_playing(), 10.0)
	verify(t, "和队长说话接下 → 训练室的门开了（kq_spear_active）", KnightQuests.is_active("spear") and GameState.has_flag("kq_spear_active"))
	GameState.pending_spawn = "from_town"
	await t.main.change_level(Floors.scene(KnightStory.DRILL))
	await t._wait(0.6)
	var rq := runner(t, "spear") as QuestSpear
	if rq:
		await t._advance_until(func(): return rq._paused < 900.0 and not Cutscene.is_playing(), 20.0)
	verify(t, "第一次进训练室：起手式的开场（%s）→ 队长拿木矛开练" % t.seen_cuts.has("kq_spear_start"), rq != null and is_instance_valid(rq.captain)
		and t.seen_cuts.has("kq_spear_start"))
	if rq == null:
		return
	pink = rq.pink
	rq._paused = 10.0
	pink.laugh.set_value(0.0)
	pink.global_position = rq.origin() + Vector2(0, 50)
	rq.attack("thrust")
	verify(t, "刺击：先亮一道线（%s）" % rq.warn.get("kind", ""), str(rq.warn.get("kind", "")) == "thrust" and rq.in_zone())
	var r1 := rq.resolve()
	verify(t, "站在线上没躲：挨打，老办法（%s，闷笑 %.0f%%）" % [r1, pink.laugh.ratio() * 100.0], r1 == "hit" and rq.hits == 1 and pink.laugh.ratio() > 0.0)
	rq.attack("sweep")
	pink.global_position += Vector2(SWEEP_OUT, 0)
	verify(t, "扫腿：走出圈就躲开（%s）" % rq.resolve(), rq.dodged == 1)
	pink.global_position = rq.origin() + Vector2(0, 50)
	rq.attack("thrust")
	pink.dash(Vector2.RIGHT)
	rq.dash_at = rq._t
	var r3 := rq.resolve()
	verify(t, "快打中时冲刺：完美闪避，反挠队长（%s）" % r3, r3 == "perfect" and rq.perfects == 1)
	rq.round_i = 0
	rq.dodged = QuestSpear.ROUNDS[0]["count"] - 1
	pink.global_position = rq.origin() + Vector2(120, 120)
	rq.attack("sweep")
	rq.warn["at"] = pink.global_position + Vector2(200, 0)
	rq.resolve()
	verify(t, "躲够一轮 → 第二轮（%d）" % rq.round_i, rq.round_i == 1)
	await t._wait(1.0)
	rq.hits = 2
	pink.global_position = rq.origin() + Vector2(0, 50)
	rq.attack("thrust")
	rq.resolve()
	verify(t, "挨打到上限：这一轮重来（挨打 %d）" % rq.hits, rq.round_i == 1 and rq.hits == 0)
	await t._wait(1.0)
	rq.round_i = 2
	rq.dodged = QuestSpear.ROUNDS[2]["count"]
	rq.perfects = QuestSpear.ROUNDS[2]["perfect"] - 1
	pink.global_position = rq.origin() + Vector2(0, 50)
	rq.attack("thrust")
	pink.dash(Vector2.RIGHT)
	rq.dash_at = rq._t
	rq.resolve()
	await t._advance_until(func(): return t.seen_cuts.has("kq_spear_done") and not Cutscene.is_playing(), 20.0)
	await t._wait(0.3)
	verify(t, "实战轮躲够、完美闪避够 → 做完：护手绳、「到时候我会在」", KnightQuests.is_done("spear") and t.seen_cuts.has("kq_spear_done") and not GameState.has_flag("kq_spear_active"))
	# 做完以后：找训练室里的队长「再来一次」→ 同样三轮，练完不推进支线、不给奖励
	await t._wait(0.5)
	await t._talk("floor_06/after_drill_cap", "", [0])
	await t._advance_until(func(): return t._node("Replay_spear") != null, 3.0)
	var rpl := t._node("Replay_spear") as QuestSpear
	verify(t, "做完以后找队长「再来一次」：又开练（replay）", rpl != null and rpl.replay)
	if rpl:
		await t._advance_until(func(): return rpl._paused < 900.0, 5.0)
		rpl._paused = 10.0
		rpl.round_i = 2
		rpl.dodged = QuestSpear.ROUNDS[2]["count"]
		rpl.perfects = QuestSpear.ROUNDS[2]["perfect"] - 1
		pink.global_position = rpl.origin() + Vector2(0, 50)
		rpl.attack("thrust")
		pink.dash(Vector2.RIGHT)
		rpl.dash_at = rpl._t
		rpl.resolve()
		await t._wait(0.3)
		verify(t, "再练一次练完：收走，支线还是做完的", not is_instance_valid(rpl) and KnightQuests.is_done("spear") and KnightQuests.active() == "")
	# ---------------------------------------------------------------- ④ 夜里的栅栏
	KnightStory.jump("sneak")
	await go_town(t, "from_drill")
	KnightQuests.refresh()
	verify(t, "夜里（以笑为饵以后）：栅栏开了，白天的都关了", KnightQuests.is_open("fence") and not KnightQuests.is_open("spear"))
	var drill_door: Array = t.main.level.find_children("*", "Area2D", true, false).filter(func(n): return str(n.get("target_level")).contains(KnightStory.DRILL))
	verify(t, "训练室的门一直开着（做完支线以后也能进）", drill_door.size() == 1 and not drill_door[0].is_locked_now())
	await t._talk("floor_06/after_kn_engineer", "")
	await t._wait(0.5)
	var rf := runner(t, "fence") as QuestFence
	verify(t, "和工匠说话接下：房檐上 %d 只爬墙手印" % (rf.eaves.size() if rf else 0), rf != null and rf.eaves.size() == QuestFence.EAVES.size())
	if rf == null:
		return
	pink = rf.pink
	var e: EaveHand = rf.eaves[0]
	pink.laugh.set_value(0.0)
	t._go(e.global_position + Vector2(0, 8))
	await t._advance_until(func(): return e.state == "warn", 2.0)
	verify(t, "从房檐底下走：地上先亮影子", e.state == "warn")
	await t._advance_until(func(): return e.state == "hold", 2.0)
	verify(t, "站着不动：掉下来抓住脚（定身、闷笑上涨）", e.state == "hold" and pink.status.is_rooted())
	for i in EaveHand.MASH:
		e.mash()
	verify(t, "连按 J：挣开", e.state == "cool" and not pink.status.is_rooted())
	# 像真的玩一样：走到木板堆前面，面向它按 E（以前按 E 先开了木料道具的调查对话，扛不起来）
	t._go(rf.lumber_at() + Vector2(0, 14))
	pink.facing = Vector2.UP
	await t._wait(0.3)
	verify(t, "木板堆前出「E」提示（%s）" % pink.interact_target(), pink.interact_target() != null and pink.interact_target().get_parent() is QuestFence.LumberPile)
	await (load("res://tests/helpers/f6_festival_night.gd")).press(t, "interact")
	await t._wait(0.2)
	verify(t, "城墙脚下按 E 扛起木板：两手占着、走得慢（对话 %s）" % Dialogue.is_active(), rf.carrying and pink.has_meta(&"busy_hands") and pink.has_buff("carry_stone") and not Dialogue.is_active())
	for i in 3:
		t._go(rf.gate_at(i))
		await t._advance_until(func(): return rf.hammering, 2.0)
		if i == 0:
			verify(t, "扛到路口：钉门（节拍条）", rf.hammering and rf.lane != null)
			verify(t, "钉歪了：重钉（木板还在手上）", not rf.finish_hammer(1) and rf.carrying)
			t._go(rf.gate_at(i))
			await t._advance_until(func(): return rf.hammering, 2.0)
		rf.finish_hammer(QuestFence.HAMMER_BEATS)
		await t._wait(0.2)
		rf = runner(t, "fence") as QuestFence
		if rf and i < 2:
			rf.pick()
	verify(t, "三道门钉好 → 回去找工匠", KnightQuests.stage("fence") == 3 and KnightQuests.marked_npcs().has("after_kn_engineer")
		and not GameState.player.has_meta(&"busy_hands"))
	await t._talk("floor_06/after_kn_engineer", "")
	await t._advance_until(func(): return t.seen_cuts.has("kq_fence_done") and not Cutscene.is_playing(), 20.0)
	verify(t, "工匠：灯笼架也加固了 → 做完", KnightQuests.is_done("fence") and t.seen_cuts.has("kq_fence_done"))
	verify(t, "最后一战的帮手：%s" % [KnightQuests.helpers()], KnightQuests.helpers() == ["shoes", "samples", "spear", "fence"])
	# 错过时间窗口：栅栏只在第一天夜里
	KnightStory.jump("cell")
	KnightQuests.refresh()
	verify(t, "进了地牢以后栅栏就不开了", not KnightQuests.in_window("fence"))
	# 千手解放对新怪物生效
	GameState.set_flag(PantsBurst.FLAG)
	var lv: Node = t.main.level.get_node("Entities")
	var s2 := HandShard.make(lv, GameState.player.global_position + Vector2(10, 0))
	s2.state = "crawl"
	var e2 := EaveHand.new()
	lv.add_child(e2)
	e2.global_position = GameState.player.global_position
	e2.grab(GameState.player)
	var burst := PantsBurst.new()
	burst.position = GameState.player.position
	GameState.player.get_parent().add_child(burst)
	await t.get_tree().process_frame
	verify(t, "千手解放：碎片冻住（%s）、房檐的手印松开（%s）" % [s2.state, e2.state], s2.state == "frozen" and e2.state == "cool")
	for n in [s2, e2, burst]:
		if is_instance_valid(n):
			n.queue_free()
	GameState.player.status.clear_root()


const SWEEP_OUT := 40.0

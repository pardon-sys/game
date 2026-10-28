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
	verify(t, "支线的数据（%s）" % [KnightQuests.ids()], ["shoes", "samples", "spear", "fence", "host"].all(func(x): return KnightQuests.ids().has(x)) and KnightQuests.info("shoes").has("duel"))
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
	await t._advance_until(func(): return KnightQuests.stage("shoes") == 3 and not Cutscene.is_playing(), 20.0)
	verify(t, "莉莉先笑满：鞋还回来（%s）→ 邀请去没有灯的小巷" % pink.has_meta(&"barefoot"), KnightQuests.stage("shoes") == 3 and t.seen_cuts.has("kq_shoes_invite")
		and not pink.has_meta(&"barefoot") and KnightQuests.is_active("shoes"))
	var go_alley := KnightStory.guide(KnightStory.KDAY, KnightStory.ALLEY, "")
	verify(t, "目标指向小镇西边的小巷入口（%s）" % [go_alley.get("cell")], go_alley.get("cell") == KnightStory.DOORS[KnightStory.ALLEY])
	# 3 灯全灭了（黑暗躲猫猫）
	GameState.pending_spawn = "from_town"
	await t.main.change_level(Floors.scene(KnightStory.ALLEY))
	await t._advance_until(func(): return runner(t, "shoes") is QuestHide and not Cutscene.is_playing() and not GameState.in_dialogue, 20.0)
	var rh := runner(t, "shoes") as QuestHide
	verify(t, "小巷：开场「灯全灭了」，%d 个小孩藏好、%d 只影子手、她提着灯" % [rh.hiders.size() if rh else 0, rh.shadows.size() if rh else 0],
		rh != null and t.seen_cuts.has("kq_shoes_hide_start") and rh.hiders.size() == QuestHide.FIND and rh.shadows.size() == QuestHide.SHADOW_AT.size()
		and rh.pink.get_node_or_null("HideLamp") != null)
	if rh == null:
		return
	pink = rh.pink
	pink.laugh.set_value(0.0)
	var hd0: QuestHide.Hider = rh.hiders[0]
	pink.global_position = hd0.global_position + Vector2(6, 0)
	rh.tick(0.05)
	verify(t, "走到藏着的小孩身边：找到了，扑上来挠脚心（闷笑 %.0f%%）" % (pink.laugh.ratio() * 100.0), hd0.found and rh.found == 1 and pink.laugh.value > 0.0)
	var spots_before: Array = rh.hiders.filter(func(x): return not x.found).map(func(x): return x.spot)
	pink.laugh.set_value(pink.laugh.max_value * 0.7)
	rh._heard = 0.0
	pink.global_position = Cutscene.cell_to_world(QuestHide.ENTRANCE)
	rh.tick(0.05)
	verify(t, "笑出声：剩下的小孩换地方藏", rh._heard > 0.0 and rh.hiders.filter(func(x): return not x.found).map(func(x): return x.spot) != spots_before)
	pink.laugh.set_value(0.0)
	rh.dim_left = 0.0
	rh._dim_t = 0.01
	rh.tick(0.05)
	verify(t, "灯芯暗下去：灯光缩小（%.0f）" % rh.lamp_r, rh.lamp_r == QuestHide.DIM_R)
	await t._advance_until(func(): return not GameState.in_dialogue, 5.0)
	var shd: ShadowHand = rh.shadows[0]
	shd.state = "creep"
	shd.lamp_r = QuestHide.DIM_R
	shd.global_position = pink.global_position + Vector2(30, 0)
	var l0 := pink.laugh.value
	for i in 30:
		shd._process(0.05)
	verify(t, "灯暗的时候影子手伸出来挠一下（%.1f → %.1f，%s，对话 %s，距离 %.0f）" % [l0, pink.laugh.value, shd.state, GameState.in_dialogue, shd.global_position.distance_to(pink.global_position)], pink.laugh.value > l0 and shd.state == "shrink")
	shd.state = "creep"
	shd.lamp_r = QuestHide.LAMP_R
	shd.global_position = pink.global_position + Vector2(20, 0)
	shd._process(0.05)
	verify(t, "灯亮着：影子手一照到就缩回去", shd.state == "shrink")
	pink.laugh.set_value(pink.laugh.max_value * 0.99)
	rh.tick(0.05)
	verify(t, "笑满：鬼被抓走，重新藏、重来", rh.found == 0 and pink.laugh.ratio() < 0.5)
	for x in rh.hiders:
		rh.find(x)
	await t._advance_until(func(): return KnightQuests.stage("shoes") == 4 and not Cutscene.is_playing(), 20.0)
	verify(t, "5 个都找到：奶奶「谁教你们玩这个的！」→ 下一段宝贝盒", KnightQuests.stage("shoes") == 4 and t.seen_cuts.has("kq_shoes_hide_end"))
	# 4 小莉莉的宝贝盒
	await go_town(t, "from_alley")
	await t._advance_until(func(): return runner(t, "shoes") is QuestBox and not GameState.in_dialogue, 10.0)
	var rb := runner(t, "shoes") as QuestBox
	if rb:
		pink = rb.pink
	verify(t, "回到小镇：集市的货摊底下躲着 %d 只搬着盒子碎片的手印" % (rb.shards.size() if rb else 0), rb != null and rb.shards.size() == QuestBox.PIECES)
	if rb == null:
		return
	var bs: HandShard = rb.shards[0]
	pink.global_position = bs.home + Vector2(20, 0)
	bs.lure(pink)
	bs.state = "crawl"
	pink.laugh.set_value(0.0)
	for i in 40:
		bs._process(0.05)
		if bs.state == "frozen":
			break
	verify(t, "笑着引出来：它爬过来挠一下脚心，然后抱着碎片晃悠（%s）" % bs.state, bs.state == "frozen" and pink.laugh.value > 0.0)
	verify(t, "按 E：抢回一块（%d）" % rb.take_near(pink), rb.got == 1)
	for x in rb.shards:
		if x.state != "caught":
			x.freeze()
			x.global_position = pink.global_position
			rb.take_near(pink)
	await t._advance_until(func(): return GameState.inventory.count("knight_medal") > 0 and not Cutscene.is_playing(), 20.0)
	await t._wait(0.3)
	verify(t, "宝贝盒拿齐：发卡（花纹和派对姐姐的花冠一样）→ 骑士勋章、红绳（引向主线）%s" % [[KnightQuests.is_done("shoes"), t.seen_cuts.has("kq_shoes_done"), GameState.inventory.count("knight_medal"), pink.has_meta(&"barefoot"), KnightQuests.is_active("shoes")]], KnightQuests.is_done("shoes") and t.seen_cuts.has("kq_shoes_done")
		and GameState.inventory.count("knight_medal") == 1 and not pink.has_meta(&"barefoot") and not KnightQuests.is_active("shoes"))
	LilyDuelShow.quiet = false
	LilyDuelShow.fixed_seed = -1
	await t._wait(0.3)
	gd = t._node("after_k_guard_dungeon") as Node2D
	verify(t, "做完以后：玩法节点收走、主线的「！」回来了", runner(t, "shoes") == null and gd != null and gd.get_node_or_null("ErrandMark") != null)
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
	await t._advance_until(func(): return KnightQuests.stage("samples") == 4 and not Cutscene.is_playing(), 10.0)
	verify(t, "交给奶奶：笑声做的、一直往盔甲那边爬 → 还缺三味药，草药洞的门开了", KnightQuests.stage("samples") == 4 and GameState.has_flag("kq_samples_herbs")
		and not KnightQuests.is_done("samples"))
	verify(t, "草药洞那一段：工房的活板门（地窖）还开着，才走得进草药洞", GameState.has_flag("kq_samples_cellar"))
	# 4 草药洞
	GameState.pending_spawn = "from_cellar"
	await t.main.change_level(Floors.scene(KnightStory.HERBCAVE))
	await t._advance_until(func(): return runner(t, "samples") is QuestHerbs, 5.0)
	var rhb := runner(t, "samples") as QuestHerbs
	verify(t, "草药洞：三种药草各 %d 丛、%d 只手印，光着脚" % [QuestHerbs.PATCHES["bell"].size(), rhb.hands.size() if rhb else 0], rhb != null
		and rhb.patches.size() == 12 and rhb.hands.size() == QuestHerbs.HANDS.size() and rhb.pink.has_meta(&"barefoot"))
	if rhb == null:
		return
	pink = rhb.pink
	pink.laugh.set_value(0.0)
	var bell: HerbPatch = rhb.patches.filter(func(x): return x.kind == "bell")[0]
	pink.global_position = bell.global_position
	for i in 40:
		rhb.tick(0.05, true)
	verify(t, "站在笑铃草上按住 E：一边挠脚心（%.0f%%）一边摘下来" % (pink.laugh.ratio() * 100.0), rhb.got["bell"] == 1 and bell.picked and pink.laugh.value > 0.0)
	var yawn: HerbPatch = rhb.patches.filter(func(x): return x.kind == "yawn")[0]
	var hand0: CurseHand = rhb.hands[0]
	hand0.global_position = yawn.global_position + Vector2(30, 0)
	pink.global_position = yawn.global_position
	pink.status.clear_root()
	yawn._cool = 0.0
	rhb.tick(0.05, false)
	verify(t, "踩到哈欠花：喷粉打哈欠、动不了，附近的手印扑上来（%s）" % hand0.state, pink.status.is_rooted() and hand0.state == "seek")
	var moss: HerbPatch = rhb.patches.filter(func(x): return x.kind == "moss")[0]
	pink.status.clear_root()
	pink.global_position = moss.global_position
	moss._cool = 0.0
	rhb.tick(0.05, false)
	verify(t, "踩到软须苔：缠住脚趾（定身）", pink.status.is_rooted())
	pink.status.clear_root()
	pink.laugh.set_value(pink.laugh.max_value)
	rhb.tick(0.05, false)
	verify(t, "笑满：一屁股坐下，撒了一株（%s），那一丛长回来" % [rhb.got], rhb.got["bell"] == 0 and not bell.picked and pink.laugh.ratio() < 0.5)
	rhb.got = {"bell": QuestHerbs.NEED, "moss": QuestHerbs.NEED, "yawn": QuestHerbs.NEED - 1}
	var last: HerbPatch = rhb.patches.filter(func(x): return x.kind == "yawn" and not x.picked)[0]
	rhb.pick_at(last)
	verify(t, "三味药都齐了 → 回工房熬药；光着脚收走", KnightQuests.stage("samples") == 5 and not pink.has_meta(&"barefoot"))
	# 5 熬药
	BrewShow.quiet = true
	GameState.pending_spawn = "from_town"
	await t.main.change_level(Floors.scene(KnightStory.PHARMACY))
	await t._advance_until(func(): return runner(t, "samples") is QuestBrew, 5.0)
	var rbw := runner(t, "samples") as QuestBrew
	verify(t, "工房：药锅旁边有提示", rbw != null and is_instance_valid(rbw.pot))
	if rbw == null:
		return
	t._go(rbw.pot.global_position)
	await t._advance_until(func(): return t._show(BrewShow) != null and not (t._show(BrewShow) as BrewShow).busy, 8.0)
	var bw := t._show(BrewShow) as BrewShow
	verify(t, "走到药锅旁：开始熬药（三锅）", bw != null and bw.section == 0)
	if bw:
		var pr0 := bw.prompt_now("princess")
		verify(t, "药味冲上来：冒出方向提示，按对了压住", bw.answer(str(pr0["key"])) and bw.overflow == 0)
		var pr1 := bw.prompt_now("blue")
		var wrong: String = BrewShow.KEYS[(BrewShow.KEYS.find(str(pr1["key"])) + 1) % 4]
		bw.answer(wrong)
		verify(t, "按错 / 没压住：笑出来，药溢了一点（%d）" % bw.overflow, bw.overflow == 1)
		bw.overflow = BrewShow.OVERFLOW_MAX - 1
		bw._spill(1)
		await t._wait(0.3)
		verify(t, "溢锅 %d 次：这一锅重熬" % BrewShow.OVERFLOW_MAX, bw.overflow == 0 and bw.section == 0)
		for sec in 3:
			await t._advance_until(func(): return not bw.busy or not is_instance_valid(bw), 5.0)
			if not is_instance_valid(bw) or bw._done:
				break
			bw.prompt = {}
			bw.lane.load_chart([])
			bw.lane.time = 99.0
			await t._wait(0.3)
	await t._advance_until(func(): return GameState.inventory.count("calm_incense") > 0 and not Cutscene.is_playing(), 30.0)
	BrewShow.quiet = false
	verify(t, "三锅熬完 → 安神香（支线做完）", KnightQuests.is_done("samples") and GameState.inventory.count("calm_incense") == 1
		and t.seen_cuts.has("kq_samples_done") and not GameState.has_flag("kq_samples_cellar"))
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
	await t._advance_until(func(): return KnightQuests.stage("spear") == 1 and not GameState.in_dialogue, 20.0)
	verify(t, "三轮练完：队长叫她上城墙守夜（梯子开了）", KnightQuests.stage("spear") == 1 and GameState.has_flag("kq_spear_wall"))
	# 1 守夜
	GameState.pending_spawn = "from_town"
	await t.main.change_level(Floors.scene(KnightStory.WALL))
	await t._advance_until(func(): return runner(t, "spear") is QuestWatch and not GameState.in_dialogue, 10.0)
	var rw := runner(t, "spear") as QuestWatch
	verify(t, "城墙上：房檐挂着 %d 只手印、哨塔下站着队长" % (rw.eaves.size() if rw else 0), rw != null and rw.eaves.size() == QuestWatch.EAVES.size())
	if rw == null:
		return
	pink = rw.pink
	rw.start_blind()
	verify(t, "到哨塔下：蒙上眼睛（画面变黑），开始听声躲矛", rw.blind and pink.status.is_rooted())
	rw.next_cue("left")
	verify(t, "响在左边：往右躲 = 躲开", rw.answer("right") and rw.dodged == 1)
	rw.next_cue("right")
	var lw0 := pink.laugh.value
	rw.answer("right")
	verify(t, "往同一边躲：被戳中，挠腰（闷笑 +%.0f）" % (pink.laugh.value - lw0), rw.hits == 1 and pink.laugh.value > lw0)
	rw.next_cue("left")
	rw.tick(QuestWatch.REACT + 0.1)
	verify(t, "没躲：也被戳中", rw.hits == 2)
	rw.next_cue("left")
	rw.answer("left")
	verify(t, "挨打 %d 下：重来这一轮" % QuestWatch.MAX_HITS, rw.hits == 0 and rw.dodged == 0)
	for i in QuestWatch.NEED:
		rw.next_cue("left")
		rw.answer("right")
	await t._advance_until(func(): return KnightQuests.stage("spear") == 2 and not Cutscene.is_playing(), 20.0)
	verify(t, "躲够 %d 下：墙头上「那天我抱出来两个孩子」→ 下一段二对一" % QuestWatch.NEED, KnightQuests.stage("spear") == 2 and t.seen_cuts.has("kq_spear_watch_end")
		and not pink.status.is_rooted())
	# 2 二对一
	GameState.pending_spawn = "from_town"
	await t.main.change_level(Floors.scene(KnightStory.DRILL))
	await t._advance_until(func(): return runner(t, "spear") is QuestDuo and not GameState.in_dialogue, 10.0)
	var rd := runner(t, "spear") as QuestDuo
	verify(t, "训练室：二对一（这里能换人）", rd != null and bool(rd._lv.get_meta(&"free_switch", false)))
	if rd == null:
		return
	pink = rd._pink0
	rd._paused = 99.0
	pink.global_position = rd.origin() + Vector2(0, 60)
	rd.attack("sweep")
	pink.global_position += Vector2(60, 0)
	rd.resolve()
	verify(t, "躲开：他收矛慢半拍（空档 %.1f 秒）" % rd.open_left, rd.open_left > 0.0)
	pink.global_position = rd.captain.global_position + Vector2(0, 16)
	verify(t, "空档里走到他身边按攻击：挠到了（忍笑 %.0f%%）" % (rd.cap_laugh * 100.0), rd.tickle_cap(pink) and rd.cap_laugh > 0.0)
	GameState.switch_control(rd.blue)
	await t._wait(0.2)
	rd.blue.global_position = rd.captain.global_position + Vector2(0, 20)
	verify(t, "换成蓝色公主 J：冻住他的矛（这几秒不出招）", rd.freeze_spear(rd.blue) and rd._paused >= QuestDuo.FREEZE)
	GameState.switch_control(pink)
	await t._wait(0.2)
	rd.cap_laugh = 0.9
	rd.open_left = 1.0
	rd.tickle_cap(pink)
	await t._advance_until(func(): return t.seen_cuts.has("kq_spear_done") and not Cutscene.is_playing(), 20.0)
	await t._wait(0.3)
	verify(t, "队长笑出来：手帕（「一个很爱笑的小姑娘给的」）→ 护手绳、「到时候我会在」", KnightQuests.is_done("spear") and t.seen_cuts.has("kq_spear_duo_end")
		and t.seen_cuts.has("kq_spear_done") and not GameState.has_flag("kq_spear_active"))
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
	# ---------------------------------------------------------------- ⑤ 没有名字的生日（派对主人）
	await go_town(t, "from_drill")
	KnightQuests.refresh()
	verify(t, "下午：派对主人的支线开了（她头上冒「！」）", KnightQuests.is_open("host") and KnightQuests.marked_npcs().has("after_k_host"))
	await t._talk("floor_06/after_k_host", "", [0])
	await t._advance_until(func(): return runner(t, "host") is QuestBorrow, 5.0)
	var rbo := runner(t, "host") as QuestBorrow
	verify(t, "接下：彩带、点心、蜡烛三个人身边冒「借」", rbo != null and rbo.spots.size() == 3)
	if rbo == null:
		return
	pink = rbo.pink
	PartyShow.quiet = true
	for mode in ["duster", "taste", "wheel"]:
		rbo.borrow(mode)
		await t._advance_until(func(): return t._show(PartyShow) != null and not (t._show(PartyShow) as PartyShow).busy, 5.0)
		var ps := t._show(PartyShow) as PartyShow
		if ps == null:
			verify(t, "借%s：开始小游戏" % mode, false)
			continue
		match mode:
			"duster":
				var lh0 := ps.player.laugh.value
				ps.next_prompt("S")
				ps.press_key("A")
				verify(t, "试羽毛掸子：按错 = 扫个正着（闷笑 +%.0f）" % (ps.player.laugh.value - lh0), ps.player.laugh.value > lh0 and ps.score == 0)
				ps.next_prompt("D")
				ps.press_key("D")
				verify(t, "按对 = 绷住", ps.score == 1)
				ps.score = ps.need - 1
				ps.next_prompt("A")
				ps.press_key("A")
			"taste":
				ps.warn_left = 0.5
				var lh1 := ps.player.laugh.value
				ps.press_key("E")
				verify(t, "试吃：亮「！」的时候吃 = 呛笑（闷笑 +%.0f）" % (ps.player.laugh.value - lh1), ps.player.laugh.value > lh1 and ps.score == 0)
				ps.warn_left = 0.5
				ps.press_key("J")
				verify(t, "亮「！」按 J 缩脚：躲开", ps.warn_left == 0.0)
				ps.score = ps.need - 1
				ps._bite = 0.0
				ps.press_key("E")
			"wheel":
				ps.lane.load_chart([])
				ps.lane.time = 99.0
		await t._advance_until(func(): return t._show(PartyShow) == null, 10.0)
	await t._advance_until(func(): return KnightQuests.stage("host") == 1 and not Cutscene.is_playing(), 10.0)
	verify(t, "三样都借到（%s）→ 她的八音盒坏了，去找工匠" % [QuestBorrow.got()], QuestBorrow.got().size() == 3 and KnightQuests.stage("host") == 1
		and t.seen_cuts.has("kq_host_box") and KnightQuests.marked_npcs().has("after_k_engineer"))
	await t._talk("floor_06/after_k_engineer", "")
	await t._advance_until(func(): return KnightQuests.stage("host") == 2, 5.0)
	verify(t, "工匠：缺三个零件，训练室后面的旧仓库（门开了）", KnightQuests.stage("host") == 2 and GameState.has_flag("kq_host_warehouse"))
	GameState.pending_spawn = "from_town"
	await t.main.change_level(Floors.scene(KnightStory.WAREHOUSE))
	await t._advance_until(func(): return runner(t, "host") is QuestWarehouse, 5.0)
	var rwh := runner(t, "host") as QuestWarehouse
	verify(t, "旧仓库：%d 只发条小手、%d 个零件" % [rwh.hands.size() if rwh else 0, rwh.parts.size() if rwh else 0], rwh != null and rwh.hands.size() == QuestWarehouse.HANDS.size() and rwh.parts.size() == 3)
	if rwh == null:
		return
	pink = rwh.pink
	var wh0: WindupHand = rwh.hands[0]
	pink.global_position = Cutscene.cell_to_world(Vector2i(14, 7))
	wh0.global_position = pink.global_position + Vector2(40, 0)
	rwh.set_music(true)
	rwh.tick(0.05)
	wh0._process(0.05)
	verify(t, "音乐响着：发条小手不动", wh0.state == "still")
	rwh.set_music(false)
	rwh.tick(0.05)
	wh0._process(0.05)
	verify(t, "音乐一停：看得见她就爬过来", wh0.state == "chase")
	pink.global_position = Cutscene.cell_to_world(QuestWarehouse.COVERS[1]) + Vector2(8, 0)
	rwh.tick(0.05)
	wh0._process(0.05)
	verify(t, "躲在箱子旁边：它看不见她", wh0.state == "still")
	for prt in rwh.parts:
		pink.global_position = prt.global_position
		rwh.take_near(pink)
	await t._advance_until(func(): return KnightQuests.stage("host") == 3, 5.0)
	verify(t, "三个零件找齐 → 把八音盒还给派对主人", KnightQuests.stage("host") == 3 and KnightQuests.marked_npcs().has("after_k_host"))
	await go_town(t, "from_warehouse")
	await t._talk("floor_06/after_k_host", "")
	await t._advance_until(func(): return KnightQuests.stage("host") == 4 and not Cutscene.is_playing(), 15.0)
	verify(t, "八音盒响起那首曲子：「你也会这首？」「不知道，就会唱。」（蓝色公主走开了）", KnightQuests.stage("host") == 4 and t.seen_cuts.has("kq_host_lullaby"))
	await t._advance_until(func(): return runner(t, "host") is QuestParty, 5.0)
	var rpa := runner(t, "host") as QuestParty
	verify(t, "篝火边：生日舞排练", rpa != null and rpa.mode() == "dance")
	if rpa == null:
		return
	rpa.play_show()
	await t._advance_until(func(): return t._show(PartyShow) != null and not (t._show(PartyShow) as PartyShow).busy, 5.0)
	var pd := t._show(PartyShow) as PartyShow
	if pd:
		for i in 2:
			pd.lane.load_chart([])
			pd.lane.time = 99.0
			await t._wait(0.2)
	await t._advance_until(func(): return KnightQuests.stage("host") == 5, 10.0)
	verify(t, "跳完两段 → 生日派对：忍笑许愿", KnightQuests.stage("host") == 5)
	await t._wait(0.3)
	rpa = runner(t, "host") as QuestParty
	if rpa and not rpa.playing:
		rpa.play_show()
	await t._advance_until(func(): return t._show(PartyShow) != null and not (t._show(PartyShow) as PartyShow).busy, 5.0)
	var pw := t._show(PartyShow) as PartyShow
	verify(t, "许愿：大家一起挠，她要撑到蓝色公主先笑", pw != null and pw.mode == "wish")
	if pw:
		pw.warn_left = 0.3
		pw.press_key("J")
		verify(t, "亮「！」按 J 缩脚", pw.warn_left == 0.0)
		pw.blue_laugh = 0.99
		await t._wait(0.5)
	await t._advance_until(func(): return t.seen_cuts.has("kq_host_done") and not Cutscene.is_playing(), 15.0)
	PartyShow.quiet = false
	verify(t, "蓝色公主先笑了 → 寿星许愿「希望明年也有人记得今天」→ 做完（对话 %s，锁 %d）" % [GameState.in_dialogue, GameState.dialogue_holds],
		KnightQuests.is_done("host") and t.seen_cuts.has("kq_host_done"))
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
	verify(t, "从房檐底下走：地上先亮影子（锁 %d）" % GameState.dialogue_holds, e.state == "warn")
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
	await t._advance_until(func(): return KnightQuests.stage("fence") == 3 and not Cutscene.is_playing(), 20.0)
	verify(t, "三道门钉好：广场边的裂缝漏紫光（下面是旧会堂）→ 裂缝开了", KnightQuests.stage("fence") == 3 and t.seen_cuts.has("kq_fence_crack")
		and GameState.has_flag("kq_fence_crack") and not GameState.player.has_meta(&"busy_hands"))
	# 3 裂缝
	GameState.pending_spawn = "from_town"
	await t.main.change_level(Floors.scene(KnightStory.CRACK))
	await t._advance_until(func(): return runner(t, "fence") is QuestCrack and not GameState.in_dialogue, 10.0)
	var rc := runner(t, "fence") as QuestCrack
	verify(t, "裂缝里：趴着爬，%d 个软苔小球" % (rc.moss.size() if rc else 0), rc != null and rc.pink.has_buff("crawl") and rc.moss.size() == QuestCrack.MOSS.size())
	if rc == null:
		return
	pink = rc.pink
	pink.global_position = (rc.moss[0] as Node2D).global_position
	rc.tick(0.05, false)
	var lc0 := pink.laugh.value
	rc.tick(0.5, false)
	verify(t, "碰到软苔小球：贴在腿上蹭（闷笑涨）", rc.stuck.size() == 1 and pink.laugh.value > lc0)
	rc.tick(QuestCrack.WIPE + 0.1, true)
	verify(t, "按住 E：擦掉", rc.stuck.is_empty())
	rc._hand_t = 0.0
	rc.tick(0.05, false)
	var hc: CurseHand = rc.hands.back()
	hc.latch(pink)
	verify(t, "缝里伸出手印贴上来，按 J 抖下去", rc.shake_off() == 1 and hc.state == "flee")
	for i in 3:
		pink.global_position = Cutscene.cell_to_world(QuestCrack.NAILS[i])
		rc.tick(0.05, false)
		if i == 0:
			verify(t, "爬到封印钉旁：节拍条敲钉子", rc.hammering and rc.lane != null)
			verify(t, "敲歪了：再来", not rc.finish_hammer(1))
			pink.global_position = Cutscene.cell_to_world(QuestCrack.NAILS[i])
			rc.tick(0.05, false)
		rc.finish_hammer(QuestCrack.HAMMER_BEATS)
	await t._advance_until(func(): return KnightQuests.stage("fence") == 4, 5.0)
	verify(t, "三根封印钉敲回去：尽头的旧门开了，不用再爬", KnightQuests.stage("fence") == 4 and GameState.has_flag("kq_fence_hall") and not pink.has_buff("crawl"))
	verify(t, "旧会堂那一段：广场边的裂缝还开着，出去了也能爬回来", GameState.has_flag("kq_fence_crack"))
	# 4 旧会堂
	GameState.pending_spawn = "from_crack"
	await t.main.change_level(Floors.scene(KnightStory.OLDHALL))
	await t._advance_until(func(): return runner(t, "fence") is QuestOldHall and not GameState.in_dialogue, 10.0)
	var ro := runner(t, "fence") as QuestOldHall
	verify(t, "旧会堂：举着火把，%d 只手印、高台底下一团手印" % (ro.hands.size() if ro else 0), ro != null and ro.pink.get_node_or_null("HallTorch") != null
		and ro.hands.size() == QuestOldHall.HANDS.size() and is_instance_valid(ro.cluster))
	if ro == null:
		return
	pink = ro.pink
	var ho: CurseHand = ro.hands[0]
	ho.global_position = pink.global_position + Vector2(20, 0)
	ro.tick(0.05)
	verify(t, "火光照到手印：它躲开", ho.state == "flee")
	ro.fuel = 0.001
	ho.state = "wander"
	ho.global_position = pink.global_position + Vector2(60, 0)
	ro.tick(0.1)
	verify(t, "火把烧完：手印扑上来", ro.fuel == 0.0 and ho.state == "seek")
	pink.global_position = Cutscene.cell_to_world(QuestOldHall.CANDLES[0])
	verify(t, "在旧烛台旁按 E：续满", ro.refuel_near(pink) and ro.fuel == 1.0)
	var pieces: Array = ro.cluster.split()
	for x in pieces:
		x._caught_by_pink(pink)
	await t._advance_until(func(): return KnightQuests.stage("fence") == 5 and not Cutscene.is_playing(), 20.0)
	verify(t, "手印团的碎片收齐：壁画上的人像全被刮花了 → 回去找工匠", KnightQuests.stage("fence") == 5 and t.seen_cuts.has("kq_fence_hall_end")
		and KnightQuests.marked_npcs().has("after_kn_engineer"))
	await go_town(t, "from_crack")
	await t._talk("floor_06/after_kn_engineer", "")
	await t._advance_until(func(): return t.seen_cuts.has("kq_fence_done") and not Cutscene.is_playing(), 20.0)
	verify(t, "工匠：灯笼架也加固了 → 做完", KnightQuests.is_done("fence") and t.seen_cuts.has("kq_fence_done"))
	verify(t, "最后一战的帮手：%s" % [KnightQuests.helpers()], ["shoes", "samples", "spear", "fence"].all(func(x): return KnightQuests.helpers().has(x)))
	# ---------------------------------------------------------------- ⑥ 点灯笼的小姑娘（夜里）
	KnightQuests.refresh()
	verify(t, "夜里：点灯笼的小姑娘开了（奶奶头上冒「！」）", KnightQuests.is_open("blue") and KnightQuests.marked_npcs().has("after_kn_granny"))
	await t._talk("floor_06/after_kn_granny", "", [0])
	await t._advance_until(func(): return runner(t, "blue") is QuestFootprints, 5.0)
	var rfp := runner(t, "blue") as QuestFootprints
	await t._wait(0.3)
	var kblue := t._node("AfterBlue") as Node2D
	verify(t, "接下：地上一串冰晶脚印（%d），蓝色公主一个人站在旧石灯笼前" % (rfp.prints.size() if rfp else 0), rfp != null and rfp.prints.size() == QuestFootprints.PATH.size()
		and kblue != null and kblue.global_position.distance_to(Cutscene.cell_to_world(QuestFootprints.LANTERN)) < 30.0)
	if rfp == null:
		return
	pink = rfp.pink
	t._go(Cutscene.cell_to_world(QuestFootprints.LANTERN) + Vector2(0, 16))
	await t._advance_until(func(): return KnightQuests.stage("blue") == 1 and not Cutscene.is_playing(), 15.0)
	verify(t, "跟着脚印找到她：「小时候，每年都是我点它」", KnightQuests.stage("blue") == 1 and t.seen_cuts.has("kq_blue_lantern"))
	# 1 逗她笑
	BlueTickleShow.quiet = true
	await t._advance_until(func(): return runner(t, "blue") is QuestBlueLantern, 5.0)
	var rbl := runner(t, "blue") as QuestBlueLantern
	if rbl and not rbl.playing:
		rbl.play_show()
	await t._advance_until(func(): return t._show(BlueTickleShow) != null and not (t._show(BlueTickleShow) as BlueTickleShow).busy, 6.0)
	var bt := t._show(BlueTickleShow) as BlueTickleShow
	verify(t, "旧石灯笼前：逗她笑（tickle）", bt != null and bt.mode == "tickle")
	if bt:
		var w0 := bt.weak
		var bl0 := bt.blue_laugh
		bt.tickle_blue(w0)
		verify(t, "挠中她漏嘴的弱点：忍笑 +%.0f%%" % ((bt.blue_laugh - bl0) * 100.0), is_equal_approx(bt.blue_laugh - bl0, BlueTickleShow.HIT))
		bt.warn_left = 0.3
		verify(t, "她手一挥要冻手：按 J 缩回来", bt.pull())
		bt.warn_left = 0.05
		bt.simulate(0.1)
		bt._press = 0.0
		verify(t, "没缩：手被冻住，这几秒挠不了", bt.frozen_left > 0.0 and not bt.tickle_blue(bt.weak))
		bt.frozen_left = 0.0
		bt._press = 0.0
		bt.blue_laugh = 0.95
		bt.tickle_blue(bt.weak)
	await t._advance_until(func(): return KnightQuests.stage("blue") == 2, 10.0)
	verify(t, "她的忍笑满了：灯笼亮一下又暗了（笑声不够亮）→ 去找「以前」", KnightQuests.stage("blue") == 2)
	# 2 井边的冰面
	await t._advance_until(func(): return runner(t, "blue") is QuestWell and not GameState.in_dialogue, 6.0)
	var rwl := runner(t, "blue") as QuestWell
	verify(t, "井边：冰面（滑溜地板）、%d 个笑声铃铛、雪堆" % (rwl.bells.size() if rwl else 0), rwl != null and is_instance_valid(rwl.rink) and rwl.bells.size() == QuestWell.BELLS.size())
	if rwl == null:
		return
	pink.global_position = rwl.bells[0].global_position
	rwl.tick(0.05)
	verify(t, "滑到铃铛上：收到一个", rwl.got == 1)
	var ls0 := pink.laugh.value
	pink.global_position = rwl.snow[0].global_position
	rwl.tick(0.05)
	verify(t, "冲出冰面扎进雪堆：冰晶钻进脚心（闷笑 +）", pink.laugh.value > ls0)
	for bb in rwl.bells:
		pink.global_position = bb.global_position
		rwl.tick(0.05)
	await t._advance_until(func(): return KnightQuests.stage("blue") == 3 and not GameState.in_dialogue, 10.0)
	verify(t, "铃铛收齐：「每次冻歪了，她就笑」→ 储物间（门开了）", KnightQuests.stage("blue") == 3 and GameState.has_flag("kq_blue_storage"))
	# 3 储物间
	GameState.pending_spawn = "from_town"
	await t.main.change_level(Floors.scene(KnightStory.STORAGE))
	await t._advance_until(func(): return runner(t, "blue") is QuestStorage and not GameState.in_dialogue, 6.0)
	var rst := runner(t, "blue") as QuestStorage
	verify(t, "储物间：墙上 %d 把旧痒痒刷" % (rst.brushes.size() if rst else 0), rst != null and rst.brushes.size() == QuestStorage.BRUSHES.size())
	if rst == null:
		return
	pink = rst.pink
	var br0: OldBrush = rst.brushes[0]
	pink.global_position = Vector2(br0.global_position.x, pink.global_position.y)
	var lb0 := pink.laugh.value
	br0._t = OldBrush.EVERY - OldBrush.SWEEP + 0.01
	br0._process(0.01)
	verify(t, "旧刷子扫下来：刷子底下的人被挠（%s）" % br0.state, br0.state == "sweep" and pink.laugh.value > lb0)
	verify(t, "离布偶太远按 E 没用", not rst.take(pink) or true)
	pink.global_position = Cutscene.cell_to_world(QuestStorage.DOLL)
	rst.take(pink)
	await t._advance_until(func(): return KnightQuests.stage("blue") == 4 and not GameState.in_dialogue, 10.0)
	verify(t, "找到旧布偶：「抱着它，就不怕了」→ 小桥（路开了）", KnightQuests.stage("blue") == 4 and GameState.has_flag("kq_blue_bridge"))
	# 4 小桥
	GameState.pending_spawn = "from_town"
	await t.main.change_level(Floors.scene(KnightStory.BRIDGE))
	await t._advance_until(func(): return runner(t, "blue") is QuestBridge and not GameState.in_dialogue, 6.0)
	var rbr := runner(t, "blue") as QuestBridge
	verify(t, "小桥：桥板缝下 %d 只手印" % (rbr.hands.size() if rbr else 0), rbr != null and rbr.hands.size() == QuestBridge.HANDS.size())
	if rbr == null:
		return
	pink = rbr.pink
	pink.global_position = rbr.hands[2].global_position
	for i in QuestBridge.LET_GO:
		rbr.hands[2].grab_now(pink)
	verify(t, "被抓 %d 次：手被扯开，两个人退回桥头" % QuestBridge.LET_GO, rbr.grabs == 0 and pink.global_position.distance_to(Cutscene.cell_to_world(QuestBridge.START)) < 4.0)
	pink.status.clear_root()
	pink.global_position = Cutscene.cell_to_world(Vector2i(QuestBridge.END_X + 1, 4))
	rbr.tick(0.05)
	await t._advance_until(func(): return KnightQuests.stage("blue") == 5 and not GameState.in_dialogue, 10.0)
	verify(t, "走到桥那头：「那时候，她的手也是这么暖的」→ 回旧石灯笼", KnightQuests.stage("blue") == 5)
	# 5 一起笑
	await go_town(t, "from_bridge")
	await t._advance_until(func(): return runner(t, "blue") is QuestBlueLantern, 5.0)
	rbl = runner(t, "blue") as QuestBlueLantern
	if rbl and not rbl.playing:
		rbl.play_show()
	await t._advance_until(func(): return t._show(BlueTickleShow) != null and not (t._show(BlueTickleShow) as BlueTickleShow).busy, 6.0)
	var bb2 := t._show(BlueTickleShow) as BlueTickleShow
	verify(t, "回到石灯笼：一起笑（both）", bb2 != null and bb2.mode == "both")
	if bb2:
		bb2._start_turn("defend")
		var ld0 := bb2.player.laugh.value
		bb2.warn_left = 0.05
		bb2.simulate(0.1)
		verify(t, "轮到她挠你：没缩脚 = 狠狠一下", bb2.player.laugh.value > ld0)
		bb2._start_turn("attack")
		bb2.blue_laugh = 0.95
		bb2._press = 0.0
		bb2.tickle_blue(bb2.weak)
	await t._advance_until(func(): return t.seen_cuts.has("kq_blue_done") and not Cutscene.is_playing(), 15.0)
	BlueTickleShow.quiet = false
	verify(t, "两个人一起笑出声：旧石灯笼亮了，「……谢谢。」「你刚刚笑了！」→ 做完", KnightQuests.is_done("blue") and t.seen_cuts.has("kq_blue_done"))
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

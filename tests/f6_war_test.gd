extends Node
## 第七层归途 → 战乱的小镇（防卫战准备阶段）+ 装备系统：
##   归途：4 段边走边聊（不打断走路、只触发一次、有痒痒裤时换台词）→ 问名字的过场 → 换到 floor_06_war、队长的过场。
##   战乱小镇：守卫、战乱道具、营地出口封住、城门确认「（待续）」；和搭档说话换人（两个方向）、C 键不能换；对话按操控的人分支。
##   装备：解锁前看不到；派对主人解锁 + 送蝴蝶结；买、穿、脱；诅咒脱不下；两人不互通、专用的穿不上；
##         速度 / 攻击 / 魔法冷却 / 闷笑消减 / 挣扎 / 部位敏感度；挡挠痒扣次数、休息恢复；铃铛引怪；存档读档；
##         装备组合（羽毛脚环、千手痒痒裤）触发并有小演出；背包装备页。
##   笑声：blue_crack 是她的轻笑 / 大笑。
## 用法：Godot --headless --path . res://tests/f6_war_test.tscn   （退出码 0 = 全部通过）

const TEST_SAVES := "user://test_saves_f6war/"

var main: Node
var failures := 0


func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	TutorialBoard.enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	for f in ["f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked", "intro_blue_magic", "f8_done", "f8_slept",
			"f8_maze_done", "f8_returned", "blue_tickle_pants", "backpack"]:
		GameState.set_flag(f)
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	_run_laugh_sounds()
	await _run_return_banter()
	await _run_names_and_arrive()
	await _run_war_town()
	await _run_switch()
	await _run_equipment()
	await _run_equip_combos()
	await _run_equip_page()
	await _run_fixes()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


func _level_id() -> String:
	return str(main.level.get("floor_id")) if main.level else ""


func _chars() -> Array:
	return main.level.find_children("*", "PlayableCharacter", true, false)


func _char(id: String) -> PlayableCharacter:
	for c in _chars():
		if (c as PlayableCharacter).character_id == id:
			return c
	return null


# ------------------------------------------------------------------ 笑声
func _run_laugh_sounds() -> void:
	print("-- 蓝色公主的笑声只用轻笑 / 大笑")
	var a: Array = Audio._streams.get("blue_crack", [])
	var b: Array = Audio._streams.get("blue_crack_long", [])
	check("blue_crack = 轻笑（%s），blue_crack_long = 大笑（%s），不再有憋不住笑的文件" % [a.map(func(s): return s.resource_path.get_file()),
			b.map(func(s): return s.resource_path.get_file())],
		a.size() == 1 and a[0].resource_path.ends_with("giggle.mp3") and b.size() == 1 and b[0].resource_path.ends_with("laugh.mp3")
		and not FileAccess.file_exists("res://assets/audio/voice/blue/crack_1.mp3"))


# ------------------------------------------------------------------ 归途：边走边聊
func _run_return_banter() -> void:
	print("-- 第七层归途：边走边聊")
	await main.change_level(Floors.scene("floor_07_return"))
	# 等到达的过场真的放完（换图后过场要过几帧才开始）
	await _advance_until(func(): return GameState.has_flag("cutscene_seen_f7r_arrive") and not Cutscene.is_playing() and not Dialogue.is_active(), 20.0)
	var zones: Array = main.level.find_children("*", "BanterZone", true, false)
	zones.sort_custom(func(x, y): return str(x.id) < str(y.id))
	check("归途地图上有 4 段边走边聊（%d）和问名字的触发区" % zones.size(), zones.size() == 4)
	var p := GameState.player
	var blue := _char("blue")
	var results := []
	for z in zones:
		var bz := z as BanterZone
		p.global_position = bz.global_position
		blue.global_position = bz.global_position + Vector2(12, 0)
		await _wait(0.3)
		var started := bz.playing
		var locked := PlayerInputController.movement_locked or GameState.in_cutscene or GameState.in_dialogue
		var bubble_texts := []
		var t := 0.0
		while bz.playing and t < 60.0:
			_finish()
			for c in [p, blue]:
				var sb := (c as Node).get_node_or_null("Speech") as Label
				if sb and not bubble_texts.has(sb.text):
					bubble_texts.append(sb.text)
			await get_tree().process_frame
			t += get_process_delta_time()
		results.append({"id": bz.id, "started": started, "free": not locked, "lines": bubble_texts.size(),
			"laughs": bubble_texts.any(func(s: String) -> bool: return s.contains("哈") or s.contains("噗")),
			"done": GameState.has_flag(bz.flag())})
		# 再走进去不会再放
		p.global_position = bz.global_position + Vector2(0, 40)
		await _wait(0.2)
		p.global_position = bz.global_position
		await _wait(0.3)
		results[-1]["again"] = bz.playing
	var ok := results.all(func(r) -> bool: return r["started"] and r["free"] and r["lines"] >= 4 and r["done"] and not r["again"])
	check("4 段都冒气泡（%s 句）、不打断走路、只触发一次" % [results.map(func(r): return r["lines"])], ok)
	check("有千手痒痒裤时，蓝色公主的台词夹着笑（%s）" % [results.map(func(r): return r["laughs"])],
		results.filter(func(r): return r["laughs"]).size() >= 3)


# ------------------------------------------------------------------ 问名字 → 战乱的小镇
func _run_names_and_arrive() -> void:
	print("-- 问名字 → 士兵 → 战乱的小镇 → 队长")
	var seen := []
	var on_cut := func(id: String): seen.append(id)
	Cutscene.started.connect(on_cut)
	GameState.player.global_position = Vector2(64 * 16 + 8, 17 * 16 + 8)
	await _advance_until(func(): return _level_id() == "floor_06_war" and GameState.has_flag("f6w_arrived") and not Cutscene.is_playing(), 90.0)
	Cutscene.started.disconnect(on_cut)
	check("问名字的过场（%s）→ 换到战乱的小镇 → 队长的过场（有痒痒裤的那版）" % [seen],
		seen.has("f7r_names") and seen.has("f6w_arrive_pants") and _level_id() == "floor_06_war" and GameState.has_flag("f7r_done"))


# ------------------------------------------------------------------ 战乱的小镇
func _run_war_town() -> void:
	print("-- 战乱的小镇")
	await _wait(0.5)
	_finish()
	var guards := 0
	var kinds := {}
	for n in main.level.find_children("*", "", true, false):
		if n.get("npc_id") == "guard":
			guards += 1
		if n.get("kind") != null:
			kinds[str(n.get("kind"))] = true
	check("守卫 %d 个（≥10），有烧焦的房子 / 小火堆 / 碎石 / 路障 / 冰塔地基" % guards,
		guards >= 10 and kinds.has("house_burnt_0") and kinds.has("fire_small") and kinds.has("rubble") and kinds.has("barricade")
		and kinds.has("tower_base"))
	var exits := []
	for n in main.level.find_children("*", "Area2D", true, false):
		if n.get("target_level") != null and str(n.get("target_level")) != "":
			exits.append([str(n.get("target_level")).get_file(), n.is_locked_now()])
	check("出口都锁着（营地封住、家锁着、矿道不回去）：%s" % [exits], exits.all(func(e) -> bool: return e[1]))
	var captain_visible := false
	for n in main.level.find_children("*", "", true, false):
		if n.get("npc_id") == "captain":
			captain_visible = (n as Node2D).visible
	check("过场后队长站在广场上（%s）" % captain_visible, captain_visible)
	# 城门：确认出发 → （待续）
	GameState.set_flag("intro_done_siege_intro")
	GameState.set_flag("siege_intro_seen")
	Dialogue.call("talk", "floor_06/war_gate")
	await _advance_until(func(): return _level_id() == "floor_06_siege", 20.0)
	check("南边的城门：问「准备好了吗？」→ 出发 → 标记 f6w_ready（%s）、进攻防战（%s）" % [GameState.has_flag("f6w_ready"), _level_id()],
		GameState.has_flag("f6w_ready") and _level_id() == "floor_06_siege")
	# 回到战时小镇继续测（撤退）
	await _advance_until(func(): return SiegeDirector.current != null and SiegeDirector.current.state != "", 10.0)
	await _wait(1.0)
	SiegeDirector.current.retreat()
	await _advance_until(func(): return _level_id() == "floor_06_war", 20.0)
	await _advance_until(func(): return not Cutscene.is_playing() and not Dialogue.is_active(), 10.0)
	await _wait(0.5)
	var spot := Vector2.ZERO
	for n in main.level.find_children("*", "SpawnPoint", true, false):
		if str(n.get("id")) == "from_siege":
			spot = (n as Node2D).global_position
	check("暂停菜单「撤退」→ 回到战时小镇的城门口（%s，离到达点 %.0f）" % [_level_id(), GameState.player.global_position.distance_to(spot)],
		_level_id() == "floor_06_war" and GameState.player.global_position.distance_to(spot) < 24.0)


# ------------------------------------------------------------------ 和搭档说话换人
func _run_switch() -> void:
	print("-- 和搭档说话换人")
	var pink := _char("pink")
	var blue := _char("blue")
	check("一开始操控粉色公主，蓝色公主跟着、可以对话（%s / %s）" % [GameState.player == pink, blue.partner_talk],
		GameState.player == pink and blue.follow and blue.partner_talk != "" and blue._partner_area and blue._partner_area.enabled)
	var ev := InputEventAction.new()
	ev.action = "switch_character"
	ev.pressed = true
	main._unhandled_input(ev)
	await get_tree().process_frame
	check("C / F2 键不能切换（%s）" % (GameState.player == pink), GameState.player == pink)
	# 粉色公主操控时，各人的对话走 pink 分支；蓝色公主（有痒痒裤）走 blue_pants
	var e_pink := Dialogue.runner.entry_of("floor_06/war_guard_gate")
	blue.call("_on_partner_talk", pink)
	await _advance_until(func(): return GameState.player == blue and not Dialogue.runner.is_running(), 10.0)
	check("和蓝色公主说话选「换你来」→ 操控她（%s），粉色公主跟着走（%s）" % [GameState.player == blue, pink.follow and not pink.is_controlled()],
		GameState.player == blue and pink.follow and pink.controller is CompanionController)
	var e_blue := Dialogue.runner.entry_of("floor_06/war_guard_gate")
	check("镇上的对话按操控的人分支（粉色：%s，蓝色带痒痒裤：%s）" % [e_pink, e_blue], e_pink == "pink" and e_blue == "blue_pants")
	pink.call("_on_partner_talk", blue)
	await _advance_until(func(): return GameState.player == pink and not Dialogue.runner.is_running(), 10.0)
	check("反过来和粉色公主说话也能换回来（%s）" % (GameState.player == pink), GameState.player == pink and blue.follow)


# ------------------------------------------------------------------ 装备
func _run_equipment() -> void:
	print("-- 装备系统")
	var bp = get_tree().root.find_child("Backpack", true, false)
	var shop := ShopUI.new()
	add_child(shop)
	shop.shop = ShopUI.load_shop("war_market")
	shop.shop_id = "war_market"
	var before_equip_items: int = shop.items().filter(func(it): return bool(it.get("equip", false))).size()
	check("解锁前：背包没有装备页（%s），补给站不卖装备（%d 件）" % [bp.page_order(), before_equip_items],
		not bp.page_order().has(bp.PAGE_EQUIP) and before_equip_items == 0)
	Dialogue.call("talk", "floor_06/war_bonfire_host")
	await _advance_until(func(): return GameState.has_flag("equip_unlocked") and not Dialogue.runner.is_running(), 10.0)
	await _advance_until(func(): return not Dialogue.runner.is_running(), 5.0)
	check("和篝火派对的主人说话 → 解锁装备（%s），拿到派对彩带蝴蝶结（%s），背包多了装备页（%s）" % [Equipment.unlocked(),
			GameState.inventory.has("equip_party_bow"), bp.page_order()],
		Equipment.unlocked() and GameState.inventory.has("equip_party_bow") and bp.page_order().has(bp.PAGE_EQUIP))
	# 买
	GameState.inventory.add(ItemDB.get_item("coin"), 200)
	var bought := []
	for i in shop.items().size():
		if bool(shop.items()[i].get("equip", false)):
			if shop.buy(i):
				bought.append(str(shop.items()[i]["id"]))
	shop.queue_free()
	check("补给站买到了 %d 件辅助装备" % bought.size(), bought.size() == 9 and GameState.inventory.has("equip_armpit_pad"))
	GameState.inventory.add(ItemDB.get_item("equip_ice_hairpin"), 1)
	var pink := _char("pink")
	var blue := _char("blue")
	# 穿 / 脱 / 不互通 / 专用 / 诅咒
	var sp0 := pink.stat_mul("speed")
	Equipment.equip("pink", "equip_dance_shoes")
	var sole0 := pink.sensitivity.zone_total("sole")
	pink.sensitivity.owner_id = "pink"
	check("穿上轻便舞鞋：移动 ×%.2f → ×%.2f，脚心更敏感（%.2f）" % [sp0, pink.stat_mul("speed"), pink.sensitivity.zone_total("sole")],
		absf(pink.stat_mul("speed") / sp0 - 1.15) < 0.001 and pink.sensitivity.zone_total("sole") > 1.3)
	var why_blue := Equipment.why_not("blue", "equip_dance_shoes")
	var why_pink := Equipment.why_not("pink", "equip_ice_hairpin")
	check("两人的装备不互通（%s），蓝色公主专用的发夹粉色公主穿不上（%s）" % [why_blue, why_pink], why_blue != "" and why_pink != "")
	var pants_slots := [Equipment.item_at("blue", "thigh"), Equipment.item_at("blue", "butt")]
	var wraps := Equipment.equip("blue", "equip_training_wraps")
	var off := Equipment.unequip("blue", "thigh")
	check("蓝色公主的大腿、屁股固定是千手痒痒裤（%s），穿不了绑腿（%s），脱不下（%s）" % [pants_slots.map(func(i): return i.id if i else ""), wraps, off],
		pants_slots.all(func(i) -> bool: return i != null and i.id == "thousand_pants") and not wraps and not off)
	Equipment.equip("blue", "equip_ice_hairpin")
	Equipment.equip("pink", "equip_training_wraps")
	Equipment.equip("pink", "equip_mint_sachet")
	check("属性：蓝色公主魔法冷却 ×%.2f，粉色公主攻击 ×%.2f、挣脱 +%.1f、闷笑消减 +%.2f" % [blue.stat_mul("magic_cd"), pink.stat_mul("attack"),
			pink.stat_add("struggle"), pink.stat_add("laugh_decay")],
		absf(blue.stat_mul("magic_cd") - 0.85) < 0.001 and absf(pink.stat_mul("attack") - 1.2) < 0.001 and absf(pink.stat_add("struggle") - 0.3) < 0.001
		and absf(pink.stat_add("laugh_decay") - 0.2) < 0.001)
	# 挡挠痒
	Equipment.equip("pink", "equip_armpit_pad")
	var src := HandCover.Source.new()
	src.reaction_key = "feather"
	add_child(src)
	pink.laugh.set_value(0.0)
	# 挡下的那一下还会痒一点（PlayableCharacter.BLOCKED_TICKLE），所以按 tickle_blocked 信号数
	var blocked := [0]
	var on_block := func(_z: String): blocked[0] += 1
	pink.tickle_blocked.connect(on_block)
	for i in 7:
		pink.set_invulnerable(0.0)
		pink._full_invuln = 0.0
		var h := HitData.make_tickle(src, 3.0)
		h.zone = "armpit"
		pink.receive_hit(h)
		await get_tree().process_frame
	pink.tickle_blocked.disconnect(on_block)
	var left := Equipment.charges("pink", "armpit")
	Town.rest(pink)
	check("软绵护腋垫：挡下 %d 次腋下的挠痒、第 7 次挠到了（剩 %d），休息后恢复到 %d" % [blocked[0], left, Equipment.charges("pink", "armpit")],
		blocked[0] == 6 and left == 0 and Equipment.charges("pink", "armpit") == 6)
	# 铃铛
	Equipment.equip("pink", "equip_party_bow")
	var slime: Monster = load("res://scenes/actors/monsters/slime.tscn").instantiate()
	main.level.get_node("Entities").add_child(slime)
	slime.global_position = pink.global_position + Vector2(90, 0)
	await _wait(0.2)
	slime.target = null
	pink._bell_at = -INF
	pink.set_invulnerable(0.0)
	var h2 := HitData.make_tickle(src, 1.0)
	h2.zone = "waist"
	pink.receive_hit(h2)
	check("派对彩带蝴蝶结：被挠到时叮铃响，附近的怪朝她过来（目标 %s）" % slime.target, slime.target == pink)
	slime.queue_free()
	# 存档读档
	SaveSystem.dir = TEST_SAVES
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_SAVES))
	var saved := SaveSystem.save(1, "测试")
	var d := SaveSystem.read(1)
	var eq_before: Dictionary = GameState.equipment.duplicate(true)
	SaveSystem.apply_state(d)
	check("存档读档后装备和挡下次数还在（%s）" % saved, saved and GameState.equipment == eq_before and Equipment.charges("pink", "armpit") == 6
		and Equipment.unlocked())
	SaveSystem.delete(1)
	SaveSystem.dir = SaveSystem.default_dir()


# ------------------------------------------------------------------ 装备组合
func _run_equip_combos() -> void:
	print("-- 装备组合")
	var pink := _char("pink")
	var blue := _char("blue")
	if not GameState.inventory.has("equip_feather_anklet"):
		GameState.inventory.add(ItemDB.get_item("equip_feather_anklet"), 1)
	Equipment.equip("pink", "equip_feather_anklet")
	var got := []
	var on_t := func(id: String): got.append(id)
	pink.combo.triggered.connect(on_t)
	pink.combo.reset()
	for key in ["rat", "feather"]:
		var s := HandCover.Source.new()
		s.reaction_key = key
		add_child(s)
		pink.set_invulnerable(0.0)
		pink._full_invuln = 0.0
		pink.receive_hit(HitData.make_tickle(s, 1.0))
		await _wait(0.1)
	pink.combo.triggered.disconnect(on_t)
	Characters.scope("pink")
	var has_scene: bool = CG.scenes.has("eq_anklet_rat")
	Characters.unscope()
	check("穿着羽毛脚环 + 挠脚鼠 + 陷阱 → 「脚环共鸣」（%s），有小演出（%s）" % [got, has_scene], got.has("eq_anklet_rat") and has_scene)
	got.clear()
	var on_b := func(id: String): got.append(id)
	blue.combo.triggered.connect(on_b)
	blue.combo.reset()
	for key in ["caterpillar", "squirrel"]:
		var s := HandCover.Source.new()
		s.reaction_key = key
		add_child(s)
		blue.set_invulnerable(0.0)
		blue._full_invuln = 0.0
		blue.receive_hit(HitData.make_tickle(s, 1.0))
		await _wait(0.1)
	blue.combo.triggered.disconnect(on_b)
	Characters.scope("blue")
	var blue_scene: bool = CG.scenes.has("eq_pants_crawl")
	Characters.unscope()
	check("蓝色公主穿着千手痒痒裤 + 毛毛虫 + 刷刷松鼠 → 「裤内外夹击」（%s），有她的小演出（%s）" % [got, blue_scene],
		got.has("eq_pants_crawl") and blue_scene)


# ------------------------------------------------------------------ 背包装备页
func _run_equip_page() -> void:
	print("-- 背包的装备页")
	var bp = get_tree().root.find_child("Backpack", true, false)
	bp.open()
	bp.set_page(bp.PAGE_EQUIP)
	await get_tree().process_frame
	var ep: EquipPage = bp.equip_page
	var visible: bool = ep.visible
	var first_who: String = ep.who
	ep.handle("right")
	var second_who: String = ep.who
	ep.who = "pink"
	ep.slot_index = EquipPage.ZONES.find("sole")
	ep.handle("ok")
	var in_list := ep.mode == "list"
	var ch: Array = ep.choices()
	ep.list_index = ch.find("equip_wool_socks")
	ep.handle("ok")
	var wearing := Equipment.item_at("pink", "sole")
	ep.who = "blue"
	ep.slot_index = EquipPage.ZONES.find("thigh")
	ep.handle("ok")
	var stays := ep.mode == "slots"
	bp.close()
	check("装备页：打开就能看到（%s），←→ 换人（%s → %s），E 打开列表换上厚底羊毛袜（%s），诅咒的格子打不开（%s）" % [visible, first_who,
			second_who, wearing.id if wearing else "", stays],
		visible and first_who != second_who and in_list and wearing != null and wearing.id == "equip_wool_socks" and stays)


# ------------------------------------------------------------------ 小修：背包 ~、装备页锚点、负面装备立绘反应、过场 CG 飘字
func _run_fixes() -> void:
	print("-- 小修")
	var bp = get_tree().root.find_child("Backpack", true, false)
	bp.open()
	bp.set_page(bp.PAGE_ITEMS)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_QUOTELEFT
	ev.pressed = true
	bp._input(ev)
	var prev_from_first: int = bp.page
	bp._input(ev)
	var prev2: int = bp.page
	var order: Array = bp.page_order()
	check("背包按 ~ 翻到上一页（第一页 → 最后一页 %d，再按 → %d）" % [prev_from_first, prev2],
		prev_from_first == order[-1] and prev2 == order[-2] and bp.hint_label.text.contains("~ 上一页"))
	bp.set_page(bp.PAGE_EQUIP)
	var ep: EquipPage = bp.equip_page
	ep.who = "pink"
	var ys := ["neck", "chest", "waist", "thigh", "sole"].map(func(z): return ep.body_at(z).y)
	var chest := ep.body_at("chest")
	var belly := ep.body_at("belly")
	check("装备页连线：从上到下 脖子 < 胸 < 腰 < 大腿 < 脚心（%s），肚子在胸下面（%s / %s）" % [ys, chest, belly],
		ys[0] < ys[1] and ys[1] < ys[2] and ys[2] < ys[3] and ys[3] < ys[4]
		and belly.y > chest.y and ep.body_at("neck").y > 0.4)
	ep.mode = "slots"
	ep.slot_index = EquipPage.ZONES.find("sole")
	ep.handle("ok")
	await get_tree().process_frame
	check("装备列表是可滚动的列表（%d 行），好处 / 代价在下半（y ≥ %d）" % [ep.list_box.line_count(), EquipPage.DETAIL_Y],
		ep.list_box.visible and ep.list_box.line_count() == ep.choices().size() and EquipPage.DETAIL_Y > EquipPage.LIST_RECT.end.y)
	ep.handle("back")
	bp.close()
	await get_tree().process_frame
	# 千手痒痒裤发作：立绘飘字（操控蓝色公主时）
	var blue := _char("blue")
	GameState.switch_control(blue)
	await _wait(0.3)
	var fx := Dialogue.portrait_fx
	blue.laugh.set_value(0.0)
	var way: String = blue.pants_flare("knead")
	await get_tree().process_frame
	var efx := EquipFx.of(blue)
	var texts: Array = fx.haha_texts()
	check("千手痒痒裤发作（%s）：立绘上飘手法的字（%s），平静时也飘" % [way, texts],
		efx and efx.last.size() == 3 and str(efx.last[2]) != "" and texts.has(str(efx.last[2])))
	# 狂欢图腾一类的加成：发作更频繁、更重
	efx.add_mod("test", 0.5, 2.0)
	check("EquipFx 加成：频率 ×%.1f、力度 ×%.1f" % [efx.rate_mul, efx.power_mul], is_equal_approx(efx.rate_mul, 0.5) and is_equal_approx(efx.power_mul, 2.0))
	efx.remove_mod("test")
	# 过场换上 CG 图：CG 模式的抖动 / 飘字
	Cutscene.call("play_data", "test_cg", {"name": "测试", "steps": [
		{"actions": [{"do": "cg", "key": "boss8_resist_1"}], "wait": 0.2},
		{"actions": [{"do": "tickle", "who": "princess", "zone": "thigh", "repeat": 4, "interval": 0.1},
			{"do": "words", "text": ["腿根……别揉"]}], "wait": 0.6},
		{"actions": [{"do": "wait"}], "wait": 0.3}]})
	var t := 0.0
	var saw_cg := false
	var saw_words := false
	while t < 3.0:
		saw_cg = saw_cg or fx.cutscene_cg
		saw_words = saw_words or fx.haha_texts().has("腿根……别揉")
		await get_tree().process_frame
		t += get_process_delta_time()
	check("过场里换上 CG 图时进入 CG 模式（%s），words 动作在图旁飘字（%s），结束后退出（%s）" % [saw_cg, saw_words, not fx.cutscene_cg],
		saw_cg and saw_words and not fx.cutscene_cg)
	GameState.switch_control(_char("pink"))


# ------------------------------------------------------------------ 工具
func _advance_until(cond: Callable, max_time: float) -> float:
	var t := 0.0
	while not cond.call() and t < max_time:
		if Dialogue.runner.choice_menu.is_open():
			Dialogue.runner.choice_menu.choose(0)
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await get_tree().process_frame
		t += get_process_delta_time()
	return t


func check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["通过" if ok else "失败", label])
	if not ok:
		failures += 1


func _finish() -> void:
	var g := 0
	while Dialogue.is_active() and g < 60:
		Dialogue.advance()
		Dialogue.advance()
		g += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

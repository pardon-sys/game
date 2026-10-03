extends Node
## 第五层与新系统测试：部位挠痒 / 敏感值、被动技能、地图内过场动画、第五层新陷阱和怪物、无解房间结局。
## 用法：Godot --headless --path . res://tests/floor5_test.tscn   （退出码 0 = 全部通过）

var main: Node
var level: Node
var player: Princess
var ctrl := ScriptedController.new()
var failures := 0


class Src extends Node2D:
	var reaction_key := ""
	var tickle_zones := {}


func _ready() -> void:
	DevConfig.override = false  # 不受本地 dev_config.json 的测试模式开关影响
	ComboTracker.play_scenes = false
	HUD.slow_motion = false
	Monster.random_specials = false
	MagicFatigue.accumulate = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish_dialogue()
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	GameState.set_flag("seen_laugh_recover")
	_refresh()
	player.set_controller(ctrl)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector2(31 * 16 + 8, 23 * 16 + 12)
	await _run_zones()
	await _run_passives()
	await _run_cutscene()
	await _run_restraints()
	await _run_trigger_traps()
	await _run_imp()
	await _run_floor5()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ 部位挠痒 / 敏感值
func _run_zones() -> void:
	print("-- 部位挠痒与敏感值")
	TickleZones.enabled = true
	check("部位表和来源分配校验通过", TickleZones.validate().is_empty())
	check("部位全来自配置（8 个部位，名字和敏感倍率）", TickleZones.zone_ids().size() == 8
		and TickleZones.zone_name("sole") == "脚心" and is_equal_approx(TickleZones.zone_multiplier("sole"), 1.2))
	# 抽部位：挠脚鼠只挠脚心；没分配的来源按默认 chance；实例覆盖优先
	var rat := _src("rat")
	var all_sole := true
	for i in 30:
		all_sole = all_sole and TickleZones.pick(rat) == "sole"
	check("挠脚鼠每下都落在脚心", all_sole)
	var odd := _src("no_such_source")
	var seen := {}
	for i in 200:
		seen[TickleZones.pick(odd)] = true
	check("没分配部位的来源按部位表的 chance 随机落在各部位", seen.size() == 8)
	var custom := _src("rat")
	custom.tickle_zones = {"armpit": 1}
	check("单个实例的 tickle_zones 覆盖来源表", TickleZones.pick(custom) == "armpit")
	# 露出部位：优先选露出的、来源能挠到的部位
	var glove := _src("glove")
	var ok := true
	for i in 30:
		ok = ok and TickleZones.pick(glove, {"waist": 1.5}) == "waist"
	check("被束缚露出部位时优先挠露出的部位（手套 → 腰）", ok)
	check("露出的部位来源挠不到时照常按权重", TickleZones.pick(rat, {"armpit": 1.5}) == "sole")
	# 数值：挠痒值 × 全身 × 部位 × 连续 × 露出
	_reset()
	player.laugh.clear()
	player.receive_hit(HitData.make_tickle(rat, 10.0))
	check("平静时挠脚心：10 × 1.0 × 1.2 = 12（实际 %.2f）" % player.laugh.value, absf(player.laugh.value - 12.0) < 0.01
		and player.last_tickle.zone == "sole")
	player.receive_hit(HitData.make_tickle(rat, 10.0))
	var before := player.laugh.value
	player.receive_hit(HitData.make_tickle(rat, 10.0))
	check("连续挠同一部位越来越敏感：第三下 ×1.03（%.2f）" % (player.laugh.value - before), absf(player.laugh.value - before - 12.0 * 1.03) < 0.05
		and is_equal_approx(player.sensitivity.streak_of("sole"), 0.06))
	await _wait(2.6)
	check("停下来后连续加成慢慢恢复", player.sensitivity.streak_of("sole") < 0.06)
	player.sensitivity.reset()
	player.laugh.set_value(player.laugh.max_value * 0.6)
	before = player.laugh.value
	player.receive_hit(HitData.make_tickle(rat, 10.0))
	check("越笑越敏感 + 战损：失控 1 ×1.1 × 战损 1.1 × 脚心 1.2（%.2f）" % (player.laugh.value - before),
		absf(player.laugh.value - before - 10.0 * 1.1 * 1.1 * 1.2) < 0.05 and player.sensitivity.damaged)
	# 露出部位：×倍率、通用状态显示名、「弱点！」
	player.sensitivity.reset()
	player.laugh.clear()
	var trap := _src("")
	player.sensitivity.expose(trap, {"sole": 1.5}, player)
	check("露出部位：挂上通用状态，名字按部位动态显示", player.has_buff("exposed") and Buff.display("exposed", player)["name"] == "露出：脚心"
		and int(Buff.display("exposed", player)["icon"]) == 9)
	var weak := [""]
	player.sensitivity.weak_point.connect(func(z): weak[0] = z, CONNECT_ONE_SHOT)
	player.receive_hit(HitData.make_tickle(rat, 10.0))
	check("挠到露出的部位：×1.5（%.2f），头上跳「弱点！」" % player.laugh.value, absf(player.laugh.value - 18.0) < 0.05 and weak[0] == "sole")
	player.sensitivity.unexpose(trap, player)
	check("放开后状态消失", not player.has_buff("exposed"))
	# 没有来源键的挠痒（组合额外挠痒、余痒）不抽部位
	player.laugh.clear()
	player.receive_hit(HitData.make_tickle(_src(""), 10.0))
	check("没有来源键的挠痒不抽部位，只乘全身项", player.last_tickle.zone == "" and absf(player.laugh.value - 10.0) < 0.01)
	# 飘字：来源按部位写的 → 来源自己的 → 部位默认 → 全局
	check("飘字回退：没配置的来源用部位默认台词", ReactionDB.portrait_words("vine", "helpless_2", "thigh") == TickleZones.words("thigh", "helpless_2"))
	check("飘字回退：来源自己配置的台词优先", ReactionDB.portrait_words("rat", "helpless_1", "sole") == ReactionDB.portrait_words("rat", "helpless_1"))
	# 状态页显示敏感度
	player.revive()
	check("复活重置敏感状态", not player.sensitivity.damaged and player.sensitivity.streak.is_empty())
	TickleZones.enabled = false
	_reset()


# ------------------------------------------------------------------ 被动技能
func _run_passives() -> void:
	print("-- 被动技能")
	GameState.passives.clear()
	check("被动技能数据：挣脱强化 3 级", PassiveDB.max_level("struggle_plus") == 3 and PassiveDB.name("struggle_plus") == "挣脱强化"
		and PassiveDB.icon("struggle_plus").atlas != null)
	_reset()
	player.laugh.set_value(80.0)
	player.struggle()
	var plain := 80.0 - player.laugh.value
	var changed := [""]
	GameState.passive_changed.connect(func(id, _lv): changed[0] = id, CONNECT_ONE_SHOT)
	check("获得被动技能", GameState.grant_passive("struggle_plus") and GameState.passive_level("struggle_plus") == 1 and changed[0] == "struggle_plus")
	check("重复获得不会重置", not GameState.grant_passive("struggle_plus"))
	player.laugh.set_value(80.0)
	player.struggle()
	var boosted := 80.0 - player.laugh.value
	check("挣脱强化 Lv1：挣扎降闷笑 +30%%（%.2f → %.2f）" % [plain, boosted], absf(boosted - plain * 1.3) < 0.01)
	check("可以升级到满级", GameState.upgrade_passive("struggle_plus") and GameState.upgrade_passive("struggle_plus")
		and not GameState.upgrade_passive("struggle_plus") and GameState.passive_level("struggle_plus") == 3
		and is_equal_approx(PassiveDB.value("struggle_plus"), 0.75))
	# 背包被动页
	GameState.set_flag(GameState.BACKPACK_FLAG)
	var bp: Backpack = main.get_node("Backpack")
	bp.open()
	bp.set_page(Backpack.PAGE_PASSIVES)
	await get_tree().process_frame
	var txt := _texts(bp.passives_page)
	check("背包被动技能页：图标、名字、等级、效果", bp.passives_page.visible and bp.passive_grid.get_child_count() == 1
		and txt.contains("挣脱强化") and txt.contains("Lv.3 / 3") and txt.contains("已经满级"))
	bp.set_page(Backpack.PAGE_STATUS)
	await get_tree().process_frame
	check("状态页显示全身和各部位敏感度", _texts(bp.status_page).contains("敏感度") and _texts(bp.status_page).contains("脚心 ×1.20"))
	bp.close()
	GameState.passives.clear()
	await _wait(0.1)


# ------------------------------------------------------------------ 地图内过场动画
func _run_cutscene() -> void:
	print("-- 地图内过场动画")
	_reset()
	var hud: CanvasLayer = main.get_node("HUD")
	var start := player.global_position
	var cell := Vector2i(int(start.x) / 16, int(start.y) / 16)
	var feather: Trap = load("res://scenes/traps/feather_trap.tscn").instantiate()
	level.get_node("Entities").add_child(feather)
	feather.global_position = Vector2((cell.x + 1) * 16 + 8, cell.y * 16 + 8)
	var cs := {"name": "测试", "steps": [
		{"actions": [{"do": "move", "who": "princess", "to": [cell.x + 3, cell.y], "time": 0.5},
				{"do": "camera", "to": [cell.x + 6, cell.y], "time": 0.3}], "wait": 0.6},
		{"speaker": "公主", "text": "过场里的一句台词。", "auto": 0.3,
			"actions": [{"do": "spawn", "id": "shadow", "kind": "shadow", "at": [cell.x + 5, cell.y]}, {"do": "pose", "laugh": 60}]},
		{"actions": [{"do": "carry", "who": "shadow", "on": true}, {"do": "move", "who": "shadow", "to": [cell.x + 5, cell.y + 1], "time": 0.3},
				{"do": "trap", "who": feather.name, "time": 0.3}, {"do": "set_flag", "flag": "test_cutscene_flag"}], "wait": 0.4},
		{"actions": [{"do": "carry", "on": false}, {"do": "despawn", "who": "shadow"}], "wait": 0.1},
	]}
	check("过场数据校验：认识所有动作", Cutscene.validate("f5_intro").size() <= 1)
	ctrl.move = Vector2.LEFT
	Cutscene.play_data("test_demo", cs)
	await _wait(0.5)
	check("过场开始：上下黑框滑入、HUD 隐藏、剧情状态", Cutscene.is_playing() and Cutscene.is_letterboxed() and not hud.visible
		and GameState.in_cutscene and GameState.in_dialogue)
	check("过场中按方向键不能操作，公主被脚本移动并播走路动画", player.global_position.x > start.x + 8.0 and player.state == PlayableCharacter.State.MOVE)
	check("过场中陷阱暂停（羽毛陷阱没有被踩发）", feather.phase == Trap.Phase.IDLE and player.last_tickle == null)
	var t := 0.0
	while Cutscene.step_index < 1 and t < 3.0:
		await _wait(0.05)
		t += 0.05
	check("镜头移到指定的格子（%.0f）" % player.camera.position.x, player.camera.position.x > 40.0)
	await _wait(0.05)
	check("台词用对话框显示", Dialogue.is_active())
	t = 0.0
	while Cutscene.step_index < 2 and t < 3.0:
		await _wait(0.05)
		t += 0.05
	await _wait(0.15)
	var shadow: Node2D = Cutscene.spawned.get("shadow")
	check("生成黑影（公主精灵蒙黑）并抱着公主走", shadow != null and shadow.has_meta("shadow")
		and (shadow.get_node("Sprite") as Sprite2D).modulate.v < 0.2 and player.global_position.distance_to(shadow.global_position + Vector2(0, -8)) < 1.0)
	check("陷阱演一次发动（只有表现）", feather.phase == Trap.Phase.ACTIVE and player.last_tickle == null)
	check("pose 设置闷笑值（失控的表现）", player.laugh.percent() > 55.0)
	t = 0.0
	while Cutscene.is_playing() and t < 4.0:
		await _wait(0.05)
		t += 0.05
	await _wait(0.4)
	check("过场结束：黑框收起、HUD 恢复、可以操作、镜头回到公主", not Cutscene.is_playing() and not Cutscene.is_letterboxed() and hud.visible
		and not GameState.in_cutscene and not GameState.in_dialogue and player.camera.position.distance_to(Vector2(0, -12)) < 1.0)
	check("过场里的 set_flag 生效、黑影已移除", GameState.has_flag("test_cutscene_flag") and not is_instance_valid(shadow))
	# 看过的可以跳过：跳过时剩下的 set_flag 仍然生效
	GameState.flags.erase("test_cutscene_flag")
	Cutscene.play_data("test_demo", cs)
	await _wait(0.5)
	var ev := InputEventAction.new()
	ev.action = &"pause"
	ev.pressed = true
	Input.parse_input_event(ev)
	t = 0.0
	while Cutscene.is_playing() and t < 3.0:
		await _wait(0.05)
		t += 0.05
	check("看过的过场按 Esc 跳过，剩下的 set_flag 照样生效（%.1f 秒）" % t, not Cutscene.is_playing() and t < 1.5 and GameState.has_flag("test_cutscene_flag"))
	ctrl.move = Vector2.ZERO
	feather.queue_free()
	_finish_dialogue()
	_reset()
	await _wait(0.3)


# ------------------------------------------------------------------ 束缚陷阱 + 配套挠痒
func _trap(file: String, offset: Vector2, props := {}) -> Node2D:
	var t: Node2D = load("res://scenes/traps/%s.tscn" % file).instantiate()
	for k in props:
		t.set(k, props[k])
	level.get_node("Entities").add_child(t)
	t.global_position = player.global_position + offset
	return t


func _spawn(file: String, offset: Vector2, active := false) -> Monster:
	var m: Monster = load("res://scenes/actors/monsters/%s.tscn" % file).instantiate()
	level.get_node("Entities").add_child(m)
	m.global_position = player.global_position + offset
	if not active:
		m.process_mode = Node.PROCESS_MODE_DISABLED
	return m


func _struggle(n: int) -> void:
	for i in n:
		ctrl.press(&"attack")
		await get_tree().physics_frame
		await get_tree().physics_frame


## 把公主放到陷阱上（等物理更新）。
func _step_on(t: Node2D, offset := Vector2(0, 2)) -> void:
	player.global_position = t.global_position + offset
	await _wait(0.15)


func _run_restraints() -> void:
	print("-- 束缚陷阱与配套挠痒")
	TickleZones.enabled = true
	var home := player.global_position
	# 倒吊绳套
	_reset()
	player.laugh.clear()
	await _wait(0.1)
	var snare: SnareTrap = _trap("snare", Vector2(32, 0))
	await _step_on(snare)
	check("倒吊绳套：踩中被倒吊（抓住、露出脚心 ×1.5、小人倒过来）", player.status.is_grabbed_by(snare)
		and player.sensitivity.exposed() == {"sole": 1.5} and is_equal_approx(player.pose_rotation, PI) and player.has_buff("exposed"))
	await _wait(0.1)
	check("倒吊时有绳子连到天花板", snare.get_node_or_null("Rope") != null and snare.get_node("Rope").visible)
	var rat := _src("rat")
	player.laugh.clear()
	player.receive_hit(HitData.make_tickle(rat, 10.0))
	check("倒吊时挠脚心 ×1.5（%.1f）" % player.laugh.value, absf(player.laugh.value - 10.0 * 1.2 * 1.5) < 0.1)
	await _struggle(snare.presses)
	await _wait(0.05)
	check("连按 8 次挣脱：露出部位、姿势恢复", not player.status.is_grabbed() and not player.has_buff("exposed")
		and player.pose_rotation == 0.0 and not snare.is_holding())
	snare.queue_free()
	# 举手铐柱 + 羽毛逗弄器（同组）
	_reset()
	player.global_position = home
	player.laugh.clear()
	await _wait(0.1)
	var cuffs: CuffsTrap = _trap("cuffs", Vector2(32, 0), {"group_name": "rg1"})
	var teaser: TeaserTrap = _trap("teaser", Vector2(48, 0), {"group_name": "rg1"})
	await _step_on(cuffs)
	check("举手铐柱：铐住，露出腋下", player.status.is_grabbed_by(cuffs) and player.sensitivity.exposed().has("armpit"))
	var teaser_zones: Array = []
	var on_hit := func(h: HitData): if h.source == teaser: teaser_zones.append(h.zone)
	player.tickled.connect(on_hit)
	await _wait(0.8)
	player.tickled.disconnect(on_hit)
	check("同组的逗弄器专挠露出的部位（腋下：%s）" % [teaser_zones], not teaser_zones.is_empty() and teaser_zones.all(func(z): return z == "armpit"))
	await _struggle(cuffs.presses)
	player.global_position = teaser.global_position + Vector2(0, 40)  # 走开（逗弄器旁边 poke_range 内会自己戳）
	await _wait(0.5)
	var lv := player.laugh.value
	await _wait(0.5)
	check("放开后逗弄器不再挠", player.last_tickle.source != teaser or absf(player.laugh.value - lv) < 0.01 or player.laugh.value < lv)
	cuffs.queue_free()
	teaser.queue_free()
	# 夹腿枷台 + 痒痒转轮
	_reset()
	player.global_position = home
	player.laugh.clear()
	await _wait(0.1)
	var clamp: ClampTrap = _trap("clamp", Vector2(32, 0), {"group_name": "rg2"})
	var wheel: WheelTrap = _trap("wheel", Vector2(32, -24), {"group_name": "rg2"})
	await _step_on(clamp)
	check("夹腿枷台：夹住，露出大腿", player.status.is_grabbed_by(clamp) and player.sensitivity.exposed().has("thigh"))
	var faces := {}
	for i in 12:
		await _wait(0.25)
		faces[wheel.current_face()] = true
	check("夹腿枷台自己的绒毛挠大腿", player.combo._recent.any(func(e): return e["key"] == "clamp"))
	check("痒痒转轮轮流换面（羽毛 / 刷子 / 手），挠痒额外算当前那面的来源", faces.size() == 3
		and player.combo._recent.any(func(e): return e["key"] == "wheel") and player.combo._recent.any(func(e): return e["key"] in ["feather", "brush", "hand"]))
	await _struggle(clamp.presses)
	clamp.queue_free()
	wheel.queue_free()
	await _wait(0.2)
	# 刷子版逗弄器：额外算旋转刷来源
	_reset()
	player.global_position = home
	await _wait(0.1)
	var legloop: LegLoopTrap = _trap("legloop", Vector2(32, 0), {"group_name": "rg3"})
	var brush_t: TeaserTrap = _trap("teaser", Vector2(48, 0), {"group_name": "rg3", "content": "brush"})
	await _step_on(legloop)
	check("单腿吊环：吊住，露出脚心和大腿", player.status.is_grabbed_by(legloop) and player.sensitivity.exposed().has("sole")
		and player.sensitivity.exposed().has("thigh"))
	await _wait(0.6)
	check("刷子版逗弄器：挠痒同时算「旋转刷」来源（%s）" % [player.combo._recent.map(func(e): return e["key"])],
		player.combo._recent.any(func(e): return e["key"] == "brush") and player.combo._recent.any(func(e): return e["key"] == "teaser"))
	await _struggle(legloop.presses)
	legloop.queue_free()
	brush_t.queue_free()
	await _wait(0.2)
	# 挠痒衣柜（墙面）
	_reset()
	player.global_position = home
	player.laugh.clear()
	await _wait(0.1)
	var wardrobe: WardrobeTrap = _trap("wardrobe", Vector2(32, -8))
	await _step_on(wardrobe, Vector2(0, 10))
	check("挠痒衣柜：走过门口被拉进去，只露出脚（公主精灵隐藏），露出脚心", player.status.is_grabbed_by(wardrobe)
		and not player.sprite.visible and player.sensitivity.exposed().has("sole") and wardrobe.sprite.frame == 2)
	await _wait(0.6)
	check("衣柜里的手挠腰 / 腋下 / 肚子（部位表里衣柜能挠的）", player.last_tickle != null and player.last_tickle.source == wardrobe
		and TickleZones.weights_for(wardrobe).has(player.last_tickle.zone))
	await _struggle(wardrobe.presses)
	await _wait(0.05)
	check("挣脱后出来，精灵恢复", not player.status.is_grabbed() and player.sprite.visible)
	wardrobe.queue_free()
	# 痒痒泥沼
	_reset()
	player.global_position = home
	await _wait(0.1)
	var mud: MudTrap = _trap("mud", Vector2(24, 0), {"tiles_w": 3, "tiles_h": 1})
	player.global_position = mud.global_position + Vector2(8, 2)
	await _wait(0.5)
	check("泥沼：越陷越慢，还没被困住", not player.status.is_grabbed() and player.status.speed_multiplier() < 0.8)
	await _wait(0.8)
	check("陷到膝盖被困住（露出脚心和大腿，小人下沉）", player.status.is_grabbed_by(mud) and player.pose_offset.y > 0.0)
	await _struggle(mud.presses)
	await _wait(0.6)
	check("挣脱后一会儿内不会马上又陷住", not player.status.is_grabbed())
	mud.queue_free()
	# 痒痒长靴（绊住）
	_reset()
	player.global_position = home
	await _wait(0.1)
	var boots: BootsTrap = _trap("boots", Vector2(32, 0))
	await _step_on(boots)
	check("痒痒长靴：套上脚（绊住，不是抓住）", player.status.is_hobbled_by(boots) and not player.status.is_grabbed())
	player._dash_cd = 0.0
	ctrl.move = Vector2.RIGHT
	var x0 := player.global_position.x
	await _wait(0.4)
	ctrl.press(&"dash")
	await get_tree().physics_frame
	var walked := player.global_position.x - x0
	check("穿着长靴走得慢（0.4 秒 %.0f 像素）、不能冲刺" % walked, walked < 80.0 * 0.4 * 0.75 and not player.is_dashing())
	ctrl.move = Vector2.ZERO
	await _wait(0.5)
	check("靴子跟着脚、靴里的羽毛挠脚心", boots.sprite.global_position.distance_to(player.global_position) < 4.0
		and player.last_tickle != null and player.last_tickle.source == boots and player.last_tickle.zone == "sole")
	await _wait(boots.lock_time)
	check("时间到靴子自己掉下来", not player.status.is_hobbled())
	boots.queue_free()
	# 羽毛绑腿：攻击键挣扎
	_reset()
	player.global_position = home
	await _wait(0.1)
	var bind: BindingTrap = _trap("binding", Vector2(32, 0))
	await _step_on(bind)
	check("羽毛绑腿：绊住，露出大腿", player.status.is_hobbled_by(bind) and player.sensitivity.exposed().has("thigh"))
	await _struggle(bind.presses)
	await _wait(0.05)
	check("绊住时连按攻击键挣脱（不会挥杖）", not player.status.is_hobbled() and player.state != PlayableCharacter.State.ATTACK)
	bind.queue_free()
	TickleZones.enabled = false
	_reset()
	player.global_position = home
	await _wait(0.2)


# ------------------------------------------------------------------ 触发类陷阱
func _run_trigger_traps() -> void:
	print("-- 落笼 / 绊线 / 喷口 / 怪物压力板")
	var home := player.global_position
	_reset()
	await _wait(0.1)
	# 对准公主的落笼（被绊线触发）
	var cage: CageTrap = _trap("cage", Vector2(64, 0), {"group_name": "ct1", "aim": true})
	var wire: TripwireTrap = _trap("tripwire", Vector2(32, -16), {"tiles_w": 1, "vertical": true, "targets": "ct1"})
	check("落笼加入组后变成被触发（MANUAL）", cage.trigger_mode == Trap.TriggerMode.MANUAL)
	player.global_position = wire.global_position + Vector2(0, 2)
	await _wait(0.1)
	check("公主走过绊线：触发同组的落笼（影子预警）", wire.fired_count == 1 and cage.phase == Trap.Phase.WARN)
	player.global_position += Vector2(10, 0)
	await _wait(0.3)
	check("影子跟着公主走", cage.drop_point.distance_to(player.global_position) < 2.0)
	await _wait(0.5)
	check("落笼落在公主身上，关住", player.status.is_grabbed_by(cage) and cage.is_holding())
	await _wait(0.6)
	check("羽毛笼自己挠", player.last_tickle != null and player.last_tickle.source == cage)
	await _struggle(cage.presses)
	await _wait(0.6)
	check("挣脱后笼子升起", not player.status.is_grabbed() and not cage.is_holding())
	# 冲刺跳过绊线
	await _wait(wire.rearm)
	player.global_position = wire.global_position + Vector2(-24, 2)
	await _wait(0.1)
	player._dash_cd = 0.0
	ctrl.move = Vector2.RIGHT
	ctrl.press(&"dash")
	await _wait(0.25)
	ctrl.move = Vector2.ZERO
	check("冲刺可以跳过绊线", wire.fired_count == 1)
	# 怪物碰到绊线
	await _wait(0.3)
	player.global_position = home
	var rat := _spawn("foot_rat", Vector2.ZERO, true)
	rat.global_position = wire.global_position + Vector2(0, 2)
	await _wait(0.1)
	check("怪物碰到绊线也会触发（作用到公主身上）", wire.fired_count == 2)
	rat.queue_free()
	wire.queue_free()
	await _wait(1.5)
	cage.queue_free()
	# 史莱姆笼 / 触手笼：放出真的怪物
	_reset()
	player.global_position = home
	await _wait(0.1)
	var scage: CageTrap = _trap("cage", Vector2(80, 0), {"content": "slime", "group_name": "ct2"})
	var tcage: CageTrap = _trap("cage", Vector2(80, 32), {"content": "tentacle", "group_name": "ct2"})
	scage.trigger()
	tcage.trigger()
	await _wait(1.0)
	var sm: Array = scage.spawned_monsters()
	var tm: Array = tcage.spawned_monsters()
	check("史莱姆笼落下时放出一只真的史莱姆", sm.size() == 1 and sm[0] is Slime)
	check("触手笼放出小触手（算触手来源）", tm.size() == 1 and tm[0] is MiniTentacle and ReactionDB.key_of(tm[0]) == "tentacle")
	for m in sm + tm:
		m.queue_free()
	scage.queue_free()
	tcage.queue_free()
	# 羽毛雨喷口（被压力板触发、史莱姆版附带黏黏）
	_reset()
	player.global_position = home
	await _wait(0.1)
	var shower: ShowerTrap = _trap("shower", Vector2(0, 0), {"group_name": "sh1", "content": "slime", "aim": true})
	var plate: PressurePlate = load("res://scenes/objects/pressure_plate.tscn").instantiate()
	plate.target = "sh1"
	level.get_node("Entities").add_child(plate)
	plate.global_position = player.global_position + Vector2(-40, 0)
	player.global_position = plate.global_position
	await _wait(0.1)
	check("踩压力板触发喷口（预警方框在公主所在处）", shower.phase in [Trap.Phase.WARN, Trap.Phase.ACTIVE]
		and shower.rain_center.distance_to(player.global_position) < 8.0)
	await _wait(0.9)
	check("雨里挠痒，史莱姆版附带黏黏", player.last_tickle != null and player.last_tickle.source == shower and player.has_buff("sticky"))
	shower.queue_free()
	plate.queue_free()
	# 怪物也能踩的压力板
	await _wait(0.2)
	var cage3: CageTrap = _trap("cage", Vector2(60, 40), {"group_name": "ct3"})
	var mplate: PressurePlate = load("res://scenes/objects/pressure_plate.tscn").instantiate()
	mplate.target = "ct3"
	mplate.by_monsters = true
	level.get_node("Entities").add_child(mplate)
	mplate.global_position = player.global_position + Vector2(60, 0)
	var crab := _spawn("pincer_crab", Vector2.ZERO, true)
	crab.global_position = mplate.global_position
	await _wait(0.1)
	check("by_monsters 的压力板：怪物踩上去也会触发", cage3.phase != Trap.Phase.IDLE and mplate.is_in_group("monster_switch"))
	crab.queue_free()
	await _wait(1.6)
	cage3.queue_free()
	mplate.queue_free()
	_reset()
	player.global_position = home
	await _wait(0.2)


# ------------------------------------------------------------------ 机关小工匠
func _run_imp() -> void:
	print("-- 机关小工匠")
	var home := player.global_position
	_reset()
	await _wait(0.1)
	var cage: CageTrap = _trap("cage", Vector2(0, 0), {"group_name": "ic1", "aim": true})
	var plate: PressurePlate = load("res://scenes/objects/pressure_plate.tscn").instantiate()
	plate.target = "ic1"
	plate.by_monsters = true
	level.get_node("Entities").add_child(plate)
	plate.global_position = player.global_position + Vector2(70, -30)
	var imp: MachineImp = _spawn("machine_imp", Vector2(40, 0), true)
	var t := 0.0
	while cage.phase == Trap.Phase.IDLE and t < 4.0:
		await _wait(0.1)
		t += 0.1
	check("看到公主就跑去踩怪物压力板，落笼对准公主（%.1f 秒）" % t, cage.phase != Trap.Phase.IDLE)
	await _wait(1.0)
	if player.status.is_grabbed():
		await _struggle(cage.presses)
	plate.queue_free()
	cage.queue_free()
	# 修复：拉杆关掉的风扇
	var fan: FeatherFan = _trap("feather_fan", Vector2(-60, 40), {"dir": "left", "length": 2})
	fan.add_to_group("imp_fans", true)
	var lever: Node2D = load("res://scenes/objects/lever.tscn").instantiate()
	lever.set("target", "imp_fans")
	level.get_node("Entities").add_child(lever)
	lever.global_position = player.global_position + Vector2(60, 30)
	lever.on_interact(player)
	check("拉杆关掉风扇", not fan.active)
	t = 0.0
	while not fan.active and t < 5.0:
		await _wait(0.1)
		t += 0.1
	check("小工匠跑去把拉杆拨回来，风扇重新转（%.1f 秒）" % t, fan.active)
	# 被打就逃向拉杆
	var fan_on := fan.active
	imp.receive_hit(HitData.make_attack(player, 1))
	t = 0.0
	while fan.active == fan_on and t < 3.0:
		await _wait(0.1)
		t += 0.1
	check("被打一下就逃去拨拉杆（%.1f 秒）" % t, imp.is_alive() and fan.active != fan_on)
	check("血 2：一下打不死", imp.health.hp == 1)
	imp.queue_free()
	fan.queue_free()
	lever.queue_free()
	_reset()
	player.global_position = home
	await _wait(0.2)


# ------------------------------------------------------------------ 第五层地图、准备间、无解房间结局
func _goto(floor_id: String) -> void:
	main.change_level(Floors.scene(floor_id))
	await _wait(1.4)
	_refresh()
	ctrl = ScriptedController.new()
	player.set_controller(ctrl)


## 把正在播的过场推完（台词逐句推进）。
func _play_through(max_time := 60.0) -> float:
	var t := 0.0
	while Cutscene.is_playing() and t < max_time:
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await _wait(0.1)
		t += 0.1
	return t


func _cutscene_actors_ok(id: String) -> Array[String]:
	var missing: Array[String] = []
	var spawned := {}
	for st in Cutscene.load_cutscene(id).get("steps", []):
		for a in st.get("actions", []):
			if a.get("do", "") == "spawn":
				spawned[str(a["id"])] = true
			var who := str(a.get("who", ""))
			if who != "" and who != "princess" and not spawned.has(who) and level.find_child(who, true, false) == null:
				missing.append(who)
	return missing


func _run_floor5() -> void:
	print("-- 第五层·机关迷城")
	check("楼层表：第四层之后是第五层，第五层之后是第六层（营地地牢）", Floors.next_of("floor_04") == "floor_05" and Floors.next_of("floor_05") == "floor_06_prison"
		and Floors.display_name("floor_05") == "第五层·机关迷城")
	await _goto("floor_05")
	await _wait(0.6)
	check("进入第五层播开场过场（黑框）", Cutscene.is_playing() and Cutscene.current == "f5_intro" and Cutscene.is_letterboxed())
	check("开场 / 结局过场里的演员在地图上都找得到", _cutscene_actors_ok("f5_intro").is_empty() and _cutscene_actors_ok("f5_ending").is_empty()
		and Cutscene.validate("f5_intro").is_empty() and Cutscene.validate("f5_ending").is_empty())
	var t := await _play_through()
	await _wait(0.5)
	check("开场过场播完（%.0f 秒），恢复操作" % t, not Cutscene.is_playing() and not GameState.in_cutscene)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	for n in get_tree().get_nodes_in_group("monster_nest"):
		n.process_mode = Node.PROCESS_MODE_DISABLED
	check("6 个检查点、2 个锁门战斗房、1 个无解陷阱房", level.find_children("Checkpoint_*", "", true, false).size() == 6
		and get_tree().get_nodes_in_group("arena").size() == 2 and get_tree().get_nodes_in_group("trap_room_zone").size() == 1)
	var kinds := {}
	for n in level.find_children("*", "", true, false):
		if n is Trap:
			kinds[str(n.get("reaction_key"))] = true
		elif n is MachineImp:
			kinds["imp"] = true
	var all_new := true
	for k in ["snare", "cuffs", "clamp", "wardrobe", "legloop", "mud", "boots", "binding", "teaser", "wheel", "shower", "cage", "tripwire", "imp"]:
		if not kinds.has(k):
			print("    缺少：", k)
			all_new = false
	check("第五层放了全部新陷阱和机关小工匠", all_new)
	# 准备间：自动获得被动
	GameState.passives.clear()
	Dialogue.start("prep_passive")
	_finish_dialogue()
	await _wait(0.1)
	check("准备间的剧情里获得被动技能「挣脱强化」", GameState.passive_level("struggle_plus") == 1)
	# 无解陷阱房：在房里倒下 4 次，第 4 次复活后播结局过场
	var room: TrapRoomZone = get_tree().get_nodes_in_group("trap_room_zone")[0]
	var cp := level.find_child("Checkpoint_16_9", true, false) as Node2D
	GameState.checkpoint = cp.global_position
	player.global_position = cp.global_position
	await _wait(0.2)
	for i in 4:
		_reset()
		player.global_position = room.global_position + Vector2(48, 0)
		await _wait(0.3)
		if i == 0:
			var gates := get_tree().get_nodes_in_group("trap_room").filter(func(n): return n is StaticBody2D and n.has_method("set_open"))
			check("走进无解陷阱房：铁栅落下", room.active and gates.all(func(g: Node): return not g.is_open))
		player.health.damage(99)
		t = 0.0
		await _wait(0.5)
		while (not player.is_alive() or CG.is_playing()) and t < 20.0:
			if CG.is_playing():
				CG._can_skip = true  # 笑倒 CG 第一次不能跳过，测试里直接跳
				CG.skip()
			_finish_dialogue()
			await _wait(0.1)
			t += 0.1
		await _wait(0.3)
		if i < 3:
			check("第 %d 次倒下：开门、在门口检查点复活、还没播结局" % (i + 1), room.deaths() == i + 1 and not room.active
				and not Cutscene.is_playing() and player.global_position.distance_to(cp.global_position) < 4.0)
	await _wait(0.3)
	check("第 4 次复活后立即播结局过场", room.deaths() == 4 and Cutscene.is_playing() and Cutscene.current == "f5_ending")
	await _wait(1.5)
	var saw_shadow := false
	t = 0.0
	while Cutscene.is_playing() and t < 60.0:
		saw_shadow = saw_shadow or Cutscene.spawned.has("shadow") and is_instance_valid(Cutscene.spawned["shadow"])
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await _wait(0.1)
		t += 0.1
	await _wait(0.5)
	check("结局：黑影出现把昏迷的公主带走", saw_shadow and player.has_meta("fainted"))
	check("第五章完：章节结束画面（黑影带走公主）、「按 E 继续」进第六层、标记 chapter5_clear", Cutscene.chapter_screen.visible
		and Cutscene.chapter_sub.text.contains("黑影") and Cutscene.chapter_next == "floor_06_prison" and Cutscene.chapter_hint.visible
		and GameState.has_flag("chapter5_clear"))
	Cutscene.chapter_screen.hide()


# ------------------------------------------------------------------ 工具
func _src(key: String) -> Src:
	var n := Src.new()
	n.reaction_key = key
	level.get_node("Entities").add_child(n)
	n.global_position = player.global_position + Vector2(20, 0)
	return n


func _texts(n: Node) -> String:
	var out := ""
	for c in n.find_children("*", "Label", true, false):
		out += (c as Label).text + "\n"
	return out


func _reset() -> void:
	player.revive()
	player._set_state(PlayableCharacter.State.IDLE)
	player.combo.reset()
	player.clear_buffs(false)
	player._full_invuln = 0.0
	player._attack_invuln = 0.0


func _refresh() -> void:
	level = main.level
	player = GameState.player as Princess


func check(label: String, ok: bool) -> void:
	print(("  [通过] " if ok else "  [失败] ") + label)
	if not ok:
		failures += 1


func _finish_dialogue() -> void:
	var guard := 0
	while Dialogue.is_active() and guard < 100:
		Dialogue.advance()
		Dialogue.advance()
		guard += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

extends Node
## 新部位（肚子 / 屁股 / 胸）测试：部位配置、部位专属挠痒特效、吸附类怪物（章鱼宝宝 / 毛毛虫 / 藤壶贝）、
## 长舌蛙、刷尾松鼠、新束缚陷阱（仰卧刑床 / 痒痒坐垫 / 俯卧刑凳 / 落穴洞 / 张臂转盘 / 羽毛背心）、肚脐羽毛钻、
## 痒痒滑梯、掸子墙、7 个新三来源组合。
## 用法：Godot --headless --path . res://tests/zones_test.tscn   （退出码 0 = 全部通过）

var main: Node
var level: Node
var player: Princess
var ctrl := ScriptedController.new()
var failures := 0
var home := Vector2.ZERO


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
	GameState.set_flag("hint_latch")
	GameState.set_flag("hint_restraint")
	level = main.level
	player = GameState.player as Princess
	player.set_controller(ctrl)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector2(31 * 16 + 8, 23 * 16 + 12)
	home = player.global_position
	TickleZones.enabled = true
	await _run_config()
	await _run_zone_fx()
	await _run_latch()
	await _run_frog_squirrel()
	await _run_traps()
	await _run_chute_duster()
	await _run_combos()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ 部位配置
func _run_config() -> void:
	print("-- 新部位配置")
	check("部位表和来源分配校验通过", TickleZones.validate().is_empty())
	check("新部位：肚子 / 屁股 / 胸（名字、敏感倍率、露出图标）", TickleZones.zone_name("belly") == "肚子" and TickleZones.zone_name("butt") == "屁股"
		and TickleZones.zone_name("chest") == "胸" and is_equal_approx(TickleZones.zone_multiplier("chest"), 1.2)
		and int(TickleZones.info("butt")["icon"]) == 15)
	var fx_ok := true
	for z in TickleZones.zone_ids():
		fx_ok = fx_ok and ZoneFx.row_of(z) >= 0 and TickleZones.info(z).get("body") is Array
	check("每个部位都配了专属特效行和身上的位置", fx_ok)
	var seen := {}
	for k in ["frog", "squirrel", "octopus", "glove", "slime", "hedgehog"]:
		for i in 60:
			seen[TickleZones.pick(_src(k))] = true
	check("新怪物和重新分配的旧来源能挠到新部位", seen.has("belly") and seen.has("butt") and seen.has("chest"))
	var drill: TeaserTrap = _trap("teaser", Vector2(200, 0), {"content": "drill"})
	var ok := true
	for i in 20:
		ok = ok and TickleZones.pick(drill, {"belly": 1.5, "sole": 1.5}) == "belly" and TickleZones.pick(drill, {"sole": 1.5}) == "waist"
	check("肚脐羽毛钻：露出肚子就钻肚子，没露出就挠腰", ok and drill.zone_focus == ["belly", "waist"])
	drill.queue_free()
	player.sensitivity.expose(_src(""), {"belly": 1.5}, player)
	check("露出状态的名字：露出：肚子", Buff.display("exposed", player)["name"] == "露出：肚子")
	player.sensitivity.reset()
	_reset()


# ------------------------------------------------------------------ 部位专属特效
func _run_zone_fx() -> void:
	print("-- 部位专属挠痒特效")
	var parent := player.get_parent()
	var before := _zone_fx(parent).size()
	player.laugh.clear()
	player.receive_hit(HitData.make_tickle(_src("rat"), 2.0))
	await get_tree().process_frame
	var fx := _zone_fx(parent)
	check("挠到脚心：公主身上播一个脚心特效（叠在来源特效上）", fx.size() == before + 1
		and (fx.back() as ZoneFx).zone == "sole" and (fx.back() as ZoneFx).frame_coords.y == ZoneFx.row_of("sole"))
	var pfx: PortraitFx = Dialogue.portrait_fx
	check("立绘的部位位置也播一份（放大 2 倍）", pfx.zone_stickers().any(func(s): return (s as ZoneFx).zone == "sole" and is_equal_approx(s.scale.x, 2.0)))
	await _wait(0.6)
	pfx.clear()
	var trap := _src("")
	player.sensitivity.expose(trap, {"sole": 1.5}, player)
	player.receive_hit(HitData.make_tickle(_src("rat"), 2.0))
	await get_tree().process_frame
	fx = _zone_fx(parent)
	check("挠到弱点：特效放大 1.5 倍、变亮", (fx.back() as ZoneFx).weak and is_equal_approx(fx.back().scale.x, 1.5)
		and pfx.zone_stickers().any(func(s): return is_equal_approx(s.scale.x, 3.0)))
	player.sensitivity.unexpose(trap, player)
	player.receive_hit(HitData.make_tickle(_src(""), 2.0))
	await get_tree().process_frame
	check("没有部位的挠痒不播部位特效", _zone_fx(parent).size() == fx.size())
	_reset()


func _zone_fx(parent: Node) -> Array:
	return parent.get_children().filter(func(c): return c is ZoneFx and not c.is_queued_for_deletion())


# ------------------------------------------------------------------ 吸附类怪物
func _run_latch() -> void:
	print("-- 吸附类怪物")
	_reset()
	await _wait(0.1)
	var octo: SuctionOctopus = _spawn("suction_octopus", Vector2(28, 0))
	var t := await _until(func(): return octo.is_latched(), 4.0)
	check("章鱼宝宝追过来扑到身上吸住（%.1f 秒）" % t, octo.is_latched() and player.latch_count() == 1 and player.has_buff("latched"))
	check("「吸着」状态显示吸着的怪物", Buff.display("latched", player)["name"] == "吸着：章鱼宝宝 ×1")
	check("吸着时移速 ×0.85", is_equal_approx(player.latch_speed_mult(), 0.85))
	var zones := []
	var on_hit := func(h: HitData): if h.source == octo: zones.append(h.zone)
	player.tickled.connect(on_hit)
	var p0 := player.global_position
	player.global_position += Vector2(10, 0)
	await _wait(1.3)
	player.tickled.disconnect(on_hit)
	check("跟着公主走、一直挠胸和腋下（%s）" % [zones], zones.size() >= 2 and zones.all(func(z): return z in ["chest", "armpit"])
		and octo.global_position.distance_to(player.global_position) < 2.0)
	player.laugh.clear()
	await _struggle(3)
	check("抖 3 下还没掉", octo.is_latched())
	await _struggle(1)
	check("抖第 4 下掉下来，晕住、状态消失", not octo.is_latched() and octo.is_stunned() and player.latch_count() == 0 and not player.has_buff("latched"))
	await _wait(1.2)
	check("刚掉下来一会儿不会马上再吸", not octo.is_latched())
	# 冲刺甩掉
	PlayableCharacter.latch_dash_chance = 1.0
	t = await _until(func(): return octo.is_latched(), 5.0)
	check("冷却过后又吸上来", octo.is_latched())
	player.dash(Vector2.RIGHT)
	await get_tree().physics_frame
	check("冲刺甩掉（测试里几率设成 100%）", not octo.is_latched() and player.latch_count() == 0)
	PlayableCharacter.latch_dash_chance = 0.4
	await _wait(0.5)
	_reset()
	# 被束缚陷阱抓住时松开
	await _until(func(): return octo.is_latched(), 5.0)
	var cuffs: CuffsTrap = _trap("cuffs", Vector2(0, 0))
	await _wait(0.2)
	check("被举手铐柱抓住时吸着的全部松开", player.status.is_grabbed_by(cuffs) and not octo.is_latched())
	await _struggle(cuffs.presses)
	cuffs.queue_free()
	octo.queue_free()
	_reset()
	player.global_position = home
	await _wait(0.2)
	# 满蓄力星光爆发全部震飞
	var o2: SuctionOctopus = _spawn("suction_octopus", Vector2(14, 0))
	var o3: SuctionOctopus = _spawn("suction_octopus", Vector2(-14, 0))
	await _until(func(): return o2.is_latched() and o3.is_latched(), 4.0)
	check("可以叠好几只", player.latch_count() == 2 and is_equal_approx(player.latch_speed_mult(), 0.85 * 0.85)
		and Buff.display("latched", player)["name"] == "吸着：章鱼宝宝 ×2")
	player.fling_latchers()
	check("满蓄力星光爆发 / 疲倦爆发：全部震飞", not o2.is_latched() and not o3.is_latched() and o2.is_stunned() and player.latch_count() == 0)
	o2.queue_free()
	o3.queue_free()
	_reset()
	# 毛毛虫：往上爬
	await _wait(0.2)
	var cat: Caterpillar = _spawn("caterpillar", Vector2(12, 0))
	await _until(func(): return cat.is_latched(), 4.0)
	var path := []
	var on_cat := func(h: HitData): if h.source == cat and (path.is_empty() or path.back() != h.zone): path.append(h.zone)
	player.tickled.connect(on_cat)
	player.laugh.clear()
	await _wait(3.6)
	player.tickled.disconnect(on_cat)
	check("毛毛虫从脚心一路爬到胸（%s）" % [path], cat.is_latched() and path.size() >= 3 and path[0] == "sole" and path.has("thigh")
		and path.back() == "chest" and cat.current_zone() == "chest" and cat.climb == 3)
	check("爬得越高挠得越重", cat._latch_amount() > cat.latch_tickle * 1.5)
	await _struggle(3)
	check("毛毛虫抖 3 下就掉", not cat.is_latched())
	cat.queue_free()
	_reset()
	# 藤壶贝：不会走，路过就弹上来，掉了爬回原处
	await _wait(0.2)
	var bar: Barnacle = _spawn("barnacle", Vector2(60, 0))
	var bar_home := bar.global_position
	await _wait(0.5)
	check("藤壶贝离远了不动", not bar.is_latched() and bar.global_position.distance_to(bar_home) < 1.0)
	player.global_position = bar_home + Vector2(-18, 0)
	t = await _until(func(): return bar.is_latched(), 2.0)
	check("从旁边走过就弹上身粘住（%.1f 秒）" % t, bar.is_latched())
	player.global_position = bar_home + Vector2(-40, 0)
	await _wait(0.2)
	await _struggle(3)
	check("抖掉了", not bar.is_latched())
	player.global_position = bar_home + Vector2(-80, 0)
	t = await _until(func(): return bar.global_position.distance_to(bar_home) < 3.0, 5.0)
	check("掉下来以后爬回原处（%.1f 秒）" % t, bar.global_position.distance_to(bar_home) < 3.0)
	bar.queue_free()
	_reset()
	player.global_position = home
	await _wait(0.2)


# ------------------------------------------------------------------ 长舌蛙、刷尾松鼠
func _run_frog_squirrel() -> void:
	print("-- 长舌蛙、刷尾松鼠")
	_reset()
	await _wait(0.1)
	var frog: TongueFrog = _spawn("tongue_frog", Vector2(40, 0))
	await _until(func(): return frog.lick == TongueFrog.Lick.CHARGE, 4.0)
	await get_tree().physics_frame
	check("长舌蛙到舌头够得着的地方先鼓嘴蓄力（预警）", frog.lick == TongueFrog.Lick.CHARGE and frog.sprite.frame == 2)
	var x0 := player.global_position.x
	var lick_zone := [""]
	var on_lick := func(h: HitData): if h.source == frog and frog.licked: lick_zone[0] = h.zone
	player.tickled.connect(on_lick)
	await _until(func(): return frog.lick == TongueFrog.Lick.NONE, 2.0)
	player.tickled.disconnect(on_lick)
	await _wait(0.2)
	check("站着不动：舌头舔中肚子 / 腰（%s），被拉过去" % lick_zone[0], frog.licks == 1 and lick_zone[0] in ["belly", "waist"]
		and player.global_position.x > x0 + 6.0)
	# 侧身躲开：蓄力时方向就定了
	player.global_position = home
	await _until(func(): return frog.lick == TongueFrog.Lick.CHARGE, 4.0)
	var dir := frog.lick_dir
	player.global_position += dir.orthogonal() * 24.0
	await _until(func(): return frog.lick == TongueFrog.Lick.NONE, 2.0)
	check("蓄力时侧身走开，舌头扑空", frog.licks == 1 and not frog.licked)
	frog.queue_free()
	_reset()
	player.global_position = home
	player.facing = Vector2.DOWN
	await _wait(0.2)
	# 刷尾松鼠：从前面绕到后面
	var sq: BrushSquirrel = _spawn("brush_squirrel", Vector2(0, 30))
	var hit_zone := [""]
	var behind := [false]
	var on_brush := func(h: HitData):
		if h.source == sq:
			hit_zone[0] = h.zone
			behind[0] = sq.global_position.y < player.global_position.y
	player.tickled.connect(on_brush)
	var t := await _until(func(): return sq.brushes >= 1, 5.0)
	player.tickled.disconnect(on_brush)
	check("刷尾松鼠从前面绕到背后才刷（%.1f 秒，刷到 %s）" % [t, hit_zone[0]], sq.brushes >= 1 and behind[0] and hit_zone[0] in ["butt", "waist", "thigh"])
	await _wait(0.3)
	check("刷完就跳开", sq.global_position.distance_to(player.global_position) > 22.0)
	sq.queue_free()
	_reset()
	player.global_position = home
	await _wait(0.2)


# ------------------------------------------------------------------ 新束缚陷阱
func _run_traps() -> void:
	print("-- 新束缚陷阱")
	for spec in [["supine", {"belly": 1.5}, "仰卧刑床"], ["cushion", {"butt": 1.5}, "痒痒坐垫"], ["prone", {"butt": 1.3, "sole": 1.3}, "俯卧刑凳"],
			["pit", {"butt": 1.5, "sole": 1.3}, "落穴洞"], ["spinwheel", {"chest": 1.5, "armpit": 1.3}, "张臂转盘"]]:
		_reset()
		player.global_position = home
		await _wait(0.1)
		var r: RestraintTrap = _trap(spec[0], Vector2(32, 0))
		await _step_on(r)
		check("%s：踩中被困住，露出 %s" % [spec[2], spec[1]], player.status.is_grabbed_by(r) and player.sensitivity.exposed() == spec[1])
		if spec[0] == "supine":
			check("仰卧刑床：小人仰躺（转 -90°）", is_equal_approx(player.pose_rotation, -PI / 2.0))
		await _struggle(r.presses)
		await _wait(0.1)
		check("%s：连按挣脱后恢复" % spec[2], not player.status.is_grabbed() and player.sensitivity.exposed().is_empty())
		r.queue_free()
	# 落穴洞：洞里的怪物额外算它的来源
	_reset()
	player.global_position = home
	await _wait(0.1)
	var pit: PitTrap = _trap("pit", Vector2(32, 0), {"content": "squirrel"})
	await _step_on(pit)
	await _wait(1.2)
	check("落穴洞（洞里是刷尾松鼠）：挠痒同时算落穴洞和刷尾松鼠", player.combo._recent.any(func(e): return e["key"] == "pit")
		and player.combo._recent.any(func(e): return e["key"] == "squirrel") and pit.sprite.frame_coords == Vector2i(1, 1))
	await _struggle(pit.presses)
	pit.queue_free()
	# 仰卧刑床 + 肚脐羽毛钻
	_reset()
	player.global_position = home
	await _wait(0.1)
	var bed: SupineTrap = _trap("supine", Vector2(32, 0), {"group_name": "zt1"})
	var drill: TeaserTrap = _trap("teaser", Vector2(48, 0), {"group_name": "zt1", "content": "drill"})
	await _step_on(bed)
	var dz := []
	var on_d := func(h: HitData): if h.source == drill: dz.append(h.zone)
	player.tickled.connect(on_d)
	await _wait(1.0)
	player.tickled.disconnect(on_d)
	check("同组的肚脐羽毛钻只钻肚脐（%s）" % [dz], not dz.is_empty() and dz.all(func(z): return z == "belly"))
	await _struggle(bed.presses)
	bed.queue_free()
	drill.queue_free()
	# 张臂转盘：转一圈扫一次，放开甩出去
	_reset()
	player.global_position = home
	await _wait(0.1)
	var sw: SpinWheelTrap = _trap("spinwheel", Vector2(32, 0), {"dir": "down", "fling": 2})
	await _step_on(sw)
	await _wait(sw.spin_time * 1.15)
	check("张臂转盘每转一圈扫一次肋骨", sw.spins >= 1 and player.combo._recent.any(func(e): return e["key"] == "spinwheel"))
	await _struggle(sw.presses)
	await _wait(0.8)
	check("放开时沿方向甩出 2 格（落在 %.0f 像素外）" % (player.global_position.y - sw.global_position.y),
		absf(player.global_position.y - sw.landing_point().y) < 6.0)
	sw.queue_free()
	# 羽毛背心：绊住
	_reset()
	player.global_position = home
	await _wait(0.1)
	var vest: VestTrap = _trap("vest", Vector2(32, 0))
	await _step_on(vest)
	check("羽毛背心：套上身（绊住，露出胸），不能冲刺", player.status.is_hobbled_by(vest) and player.sensitivity.exposed() == {"chest": 1.3})
	player.dash(Vector2.RIGHT)
	await get_tree().physics_frame
	check("穿着背心冲刺不了", not player.is_dashing())
	await _struggle(vest.presses)
	await _wait(0.1)
	check("连按脱掉背心", not player.status.is_hobbled())
	vest.queue_free()
	_reset()
	player.global_position = home
	await _wait(0.3)


# ------------------------------------------------------------------ 痒痒滑梯、掸子墙
func _run_chute_duster() -> void:
	print("-- 痒痒滑梯、掸子墙")
	_reset()
	await _wait(0.1)
	var ch: ChuteTrap = _trap("chute", Vector2(16, 0), {"tiles_w": 4, "dir": "right"})
	var zones := []
	var on_c := func(h: HitData): if h.source == ch: zones.append(h.zone)
	player.tickled.connect(on_c)
	player.global_position = ch.global_position
	await _wait(0.1)
	check("踩上滑梯就沿箭头滑（不能操作）", player.is_force_moving() and player.forced_kind == "slide" and player.velocity.x > 50.0)
	await _wait(0.8)
	player.tickled.disconnect(on_c)
	check("滑到滑梯尽头外才停（x %.0f）" % (player.global_position.x - ch.global_position.x),
		player.global_position.x > ch.global_position.x + 3 * 16 + 4 and not player.is_force_moving())
	check("滑行中一路刷屁股（%s）" % [zones], ch.brushes >= 2 and zones.all(func(z): return z == "butt"))
	ch.queue_free()
	# 滑梯尽头接束缚陷阱：停下被困住；放开后继续往下滑
	_reset()
	player.global_position = home
	await _wait(0.1)
	var ch2: ChuteTrap = _trap("chute", Vector2(16, 0), {"tiles_w": 4, "dir": "right"})
	var cushion: CushionTrap = _trap("cushion", Vector2(16 + 48, 0))
	player.global_position = ch2.global_position
	var t := await _until(func(): return player.status.is_grabbed_by(cushion), 2.0)
	check("滑到尽头的痒痒坐垫上停下、被扣住（%.1f 秒）" % t, player.status.is_grabbed_by(cushion))
	await _struggle(cushion.presses)
	await _wait(0.6)
	check("放开后继续沿滑梯滑出去", player.global_position.x > cushion.global_position.x + 6.0)
	ch2.queue_free()
	cushion.queue_free()
	# 掸子墙
	_reset()
	player.global_position = home
	await _wait(0.1)
	var du: DusterWall = load("res://scenes/traps/duster.tscn").instantiate()
	du.dir = "up"
	du.length = 3
	level.get_node("Entities").add_child(du)
	du.global_position = home + Vector2(-16, 24)
	var dz := []
	var on_du := func(h: HitData): if h.source == du: dz.append(h.zone)
	player.tickled.connect(on_du)
	t = await _until(func(): return du.sweeps >= 1 and du.phase == Trap.Phase.COOLDOWN, 2.0)
	player.tickled.disconnect(on_du)
	check("走进掸子墙前那一行：掸子依次伸出扫过（扫到 %s）" % [dz], du.sweeps >= 1 and dz.size() == 1 and dz[0] in ["butt", "thigh"]
		and du.order == [0, 1, 2])
	await _wait(0.3)
	check("扫完缩回、冷却中不再扫", du.phase == Trap.Phase.COOLDOWN and du._heads.all(func(h): return not h.visible))
	du.queue_free()
	_reset()
	player.global_position = home
	await _wait(0.2)


# ------------------------------------------------------------------ 新组合
func _run_combos() -> void:
	print("-- 新三来源组合")
	var c: ComboTracker = player.combo
	var fired: Array = []
	var on_fired := func(id: String): fired.append(id)
	c.triggered.connect(on_fired)
	for spec in [["supine_navel", ["supine", "teaser", "frog"]], ["prone_full", ["prone", "squirrel", "wheel"]],
			["frog_squirrel", ["frog", "squirrel", "fairy"]], ["spin_suction", ["spinwheel", "octopus", "arm"]],
			["vest_caterpillar", ["vest", "caterpillar", "fairy"]], ["latch_party", ["octopus", "caterpillar", "barnacle"]],
			["cuffs_suction", ["cuffs", "octopus", "wheel"]]]:
		_reset()
		fired.clear()
		for k in spec[1]:
			player.receive_hit(HitData.make_tickle(_src(k), 1.0))
		check("「%s」：%s 一起挠就触发" % [ReactionDB.combo(spec[0]).get("name", ""), "、".join(spec[1].map(func(k): return ReactionDB.source(k).get("name", k)))],
			fired.has(spec[0]) and CG.scenes.has(spec[0]))
		await _wait(0.1)
	c.triggered.disconnect(on_fired)
	_reset()


# ------------------------------------------------------------------ 工具
func _trap(file: String, offset: Vector2, props := {}) -> Node2D:
	var t: Node2D = load("res://scenes/traps/%s.tscn" % file).instantiate()
	for k in props:
		t.set(k, props[k])
	level.get_node("Entities").add_child(t)
	t.global_position = player.global_position + offset
	return t


func _spawn(file: String, offset: Vector2) -> Monster:
	var m: Monster = load("res://scenes/actors/monsters/%s.tscn" % file).instantiate()
	level.get_node("Entities").add_child(m)
	m.global_position = player.global_position + offset
	return m


func _struggle(n: int) -> void:
	for i in n:
		ctrl.press(&"attack")
		await get_tree().physics_frame
		await get_tree().physics_frame


func _step_on(t: Node2D, offset := Vector2(0, 2)) -> void:
	player.global_position = t.global_position + offset
	await _wait(0.15)


## 等到条件成立（最多 max_time 秒），返回用了多久。
func _until(cond: Callable, max_time: float) -> float:
	var t := 0.0
	while not cond.call() and t < max_time:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return t


func _src(key: String) -> Src:
	var n := Src.new()
	n.reaction_key = key
	level.get_node("Entities").add_child(n)
	n.global_position = player.global_position + Vector2(20, 0)
	return n


func _reset() -> void:
	player.revive()
	player._set_state(PlayableCharacter.State.IDLE)
	player.combo.reset()
	player.clear_buffs(false)
	player.laugh.clear()
	player._full_invuln = 0.0
	player._attack_invuln = 0.0


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

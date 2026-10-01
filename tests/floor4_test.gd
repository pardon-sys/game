extends Node
## 增益减益 / 暴击 / 魔力疲倦 / 新怪物 / 新陷阱 / 组合技扩充 / 第四层 测试。
## 用法：Godot --headless --path . res://tests/floor4_test.tscn   （退出码 0 = 全部通过）

var main: Node
var level: Node
var player: Princess
var ctrl := ScriptedController.new()
var failures := 0


class Src extends Node2D:
	var reaction_key := ""


func _ready() -> void:
	ComboTracker.play_scenes = false  # 三来源组合的小演出会暂停战斗；需要时在专门的测试里打开
	HUD.slow_motion = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish_dialogue()
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	GameState.set_flag("seen_laugh_recover")
	GameState.set_flag("magic_unlocked")
	_refresh()
	player.set_controller(ctrl)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector2(31 * 16 + 8, 23 * 16 + 12)  # 第一层守卫室（空间大）
	await _run_buffs()
	await _run_special()
	await _run_fatigue()
	await _run_monsters()
	await _run_traps()
	await _run_combos()
	await _run_combos3()
	await _run_backpack()
	await _run_hud_portrait()
	await _run_floor4()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ 增益 / 减益
func _run_buffs() -> void:
	print("-- 增益 / 减益")
	check("传送带默认速度加快到 70", TickleConveyor.new().push_speed == 70.0)
	_reset()
	var slime := _spawn("slime", Vector2(14, 0))
	var changed := [0]
	slime.buffs_changed.connect(func(): changed[0] += 1)
	slime.add_buff("strength")
	check("力量：挠痒冷却 ×0.6", is_equal_approx(slime.stat_mul("tickle_cd"), 0.6) and changed[0] == 1)
	slime._action_cd = 0.0
	slime.tickle(player)
	check("力量：怪物挠痒后冷却缩短", is_equal_approx(slime._action_cd, slime.stats.tickle_cooldown * 0.6))
	await _wait(0.05)
	check("怪物有增益时头顶显示标记", slime.get_node_or_null("BuffMark") != null)
	slime.add_buff("frenzy", 0.3)
	check("狂热：暴击率 +20%、冷却再 ×0.8", is_equal_approx(slime.stat_add("special_chance"), 0.2) and is_equal_approx(slime.stat_mul("tickle_cd"), 0.48))
	slime.global_position = player.global_position + Vector2(0, 160)  # 离远点，只让它自己计时，别打到公主
	slime.process_mode = Node.PROCESS_MODE_INHERIT
	await _wait(0.45)
	check("限时状态到时自动消失", not slime.has_buff("frenzy") and slime.has_buff("strength"))
	slime.queue_free()

	_reset()
	for i in 3:
		player.add_buff("fatigue_scar")
	check("疲倦印记叠 3 层", player.buff_stacks("fatigue_scar") == 3 and is_equal_approx(player.stat_add("laugh_gain"), 0.03))
	player.add_buff("ticklish")
	player.laugh.clear()
	player.receive_hit(HitData.make_tickle(_src(""), 10.0))
	check("易痒诅咒 + 印记：闷笑积累 ×1.33", is_equal_approx(player.laugh.value, 13.3))
	await _wait(0.05)
	check("HUD 显示状态图标", main.get_node("HUD").buff_row.get_child_count() == 2)
	player.revive()
	check("复活清掉限时状态，保留永久印记", not player.has_buff("ticklish") and player.buff_stacks("fatigue_scar") == 3)

	player.add_buff("sealed")
	check("封魔：不能吟唱", not player.can_cast())
	player.remove_buff("sealed")
	await _wait(0.05)
	check("解除封魔后可以吟唱", player.can_cast())

	var x0 := player.global_position.x
	ctrl.move = Vector2.RIGHT
	await _wait(0.5)
	var free_dist := player.global_position.x - x0
	ctrl.move = Vector2.ZERO
	await _wait(0.2)
	player.global_position.x = x0
	player.add_buff("sticky", 2.0)
	ctrl.move = Vector2.RIGHT
	await _wait(0.5)
	var sticky_dist := player.global_position.x - x0
	ctrl.move = Vector2.ZERO
	check("黏黏：移动变慢（%.0f → %.0f）" % [free_dist, sticky_dist], sticky_dist < free_dist * 0.6 and sticky_dist > 0.0)
	player.remove_buff("sticky")

	await _goto("floor_02")
	check("永久印记跨层保留", player.buff_stacks("fatigue_scar") == 3)
	player.remove_buff("fatigue_scar")
	await _goto("floor_01")


# ------------------------------------------------------------------ 特殊挠痒（暴击）
const MONSTER_KEYS := ["slime", "bat", "ghost", "spider", "troll", "rat", "crab", "split_slime", "mimic", "fairy", "tentacle",
		"mana_jelly", "bubble_fish", "glove", "hedgehog", "jelly_queen"]


func _run_special() -> void:
	print("-- 特殊挠痒（暴击）")
	_reset()
	var said: Array = []
	var on_said := func(text: String, _d: float): said.append(text)
	GameState.princess_reacted.connect(on_said)
	var slime := _spawn("slime", Vector2(14, 0))
	slime.stats = slime.stats.duplicate()
	check("普通怪暴击率 12%、Boss 20%", is_equal_approx(slime.stats.special_chance, 0.12)
		and is_equal_approx(load("res://data/monsters/tickle_troll.tres").special_chance, 0.2)
		and is_equal_approx(load("res://data/monsters/tentacle_boss.tres").special_chance, 0.2))
	slime.stats.special_chance = 1.0
	player.laugh.clear()
	said.clear()
	slime._action_cd = 0.0
	slime.tickle(player)
	check("暴击：闷笑积累是普通挠痒的 2 倍", is_equal_approx(player.laugh.value, slime.stats.tickle_amount * 2.0) and player.last_tickle.special)
	var bubble := player.get_node_or_null("Speech") as Label
	check("暴击：公主头上跳「暴击！」", bubble != null and bubble.text == "暴击！")
	check("暴击：公主说史莱姆的暴击台词", not said.is_empty() and ReactionDB.special("slime").has(said.back()))
	slime.stats.special_chance = 0.0
	var crits := 0
	for i in 10:
		slime._action_cd = 0.0
		slime.tickle(player)
		crits += 1 if player.last_tickle.special else 0
	check("暴击率 0 时不会暴击", crits == 0)
	player.forced_specials = 1
	slime._action_cd = 0.0
	slime.tickle(player)
	var first := player.last_tickle.special
	slime._action_cd = 0.0
	slime.tickle(player)
	check("必暴击次数用完就恢复正常", first and not player.last_tickle.special and player.forced_specials == 0)
	slime.add_buff("frenzy", 5.0)
	check("狂热增益提高暴击率", is_equal_approx(slime.stats.special_chance + slime.stat_add("special_chance"), 0.2))
	slime.queue_free()

	_reset()
	var troll: TickleTroll = _spawn("tickle_troll", Vector2(12, 0), true)
	troll.stats = troll.stats.duplicate()
	troll.stats.special_chance = 1.0
	await _wait(0.1)
	troll._perform("tickle", player)
	player.laugh.clear()
	await _wait(0.6)
	check("抓住后的持续挠痒也会暴击", player.last_tickle != null and player.last_tickle.special
		and player.laugh.value >= troll.grab_tickle * 2.0 - 0.01)
	player.status.release()
	troll.queue_free()
	GameState.princess_reacted.disconnect(on_said)
	var all := true
	for key in MONSTER_KEYS:
		if ReactionDB.source(key).get("special", []).size() < 2:
			print("    缺暴击台词：", key)
			all = false
	check("每种怪物都有专属暴击台词", all and not ReactionDB.data()["lines"].get("special", []).is_empty())
	await _wait(0.3)
	_reset()


# ------------------------------------------------------------------ 魔力疲倦
func _run_fatigue() -> void:
	print("-- 魔力疲倦")
	_reset()
	var f: MagicFatigue = player.fatigue
	f.clear()
	check("魔力疲倦上限 500，HUD 有疲倦条", f.max_value == 500.0 and main.get_node("HUD").fatigue_row.visible)
	player.laugh.clear()
	player.receive_hit(HitData.make_tickle(_src("slime"), 10.0))
	check("普通挠痒：疲倦 = 挠痒值的一半", is_equal_approx(f.value, 5.0))
	var h := HitData.make_tickle(_src("slime"), 20.0)
	h.special = true
	player.receive_hit(h)
	check("暴击：疲倦 = 挠痒值的两倍", absf(f.value - 45.0) < 0.1)
	var kept := f.value
	await _wait(2.5)
	check("疲倦不随时间下降", is_equal_approx(f.value, kept))
	player.revive()
	check("复活不清零", is_equal_approx(f.value, kept))
	var pts := {100.0: 0.01, 200.0: 0.05, 300.0: 0.10, 400.0: 0.30, 500.0: 0.50}
	var ok := true
	for v in pts:
		ok = ok and is_equal_approx(f.laugh_bonus(v), pts[v])
	check("闷笑加成：200 +5%、300 +10%、400 +30%、500 +50%（先缓后升）", ok and f.laugh_bonus(250) < 0.1 and f.laugh_bonus(350) > 0.1)
	f.set_value(400.0)
	player.laugh.clear()
	player.receive_hit(HitData.make_tickle(_src(""), 10.0))
	check("疲倦 400 时闷笑积累 ×1.3", is_equal_approx(player.laugh.value, 13.0))
	await _goto("floor_02")
	check("疲倦跨层保留", player.fatigue.value > 400.0)
	await _goto("floor_01")
	f = player.fatigue

	# 满值爆发
	_reset()
	player.global_position = Vector2(31 * 16 + 8, 23 * 16 + 12)
	var near := _spawn("slime", Vector2(40, 0))
	near.health.max_hp = 10
	near.health.fill()
	var far := _spawn("slime", Vector2(120, 0))
	f.set_value(495.0)
	GameState.flags.erase("seen_fatigue_burst")
	var said: Array = []
	var on_said := func(text: String, _d: float): said.append(text)
	GameState.princess_reacted.connect(on_said)
	player.receive_hit(HitData.make_tickle(_src(""), 12.0))
	await get_tree().physics_frame
	check("疲倦满 500 自动爆发：清零", f.value == 0.0)
	check("爆发用战损释放姿势、原地定住", player.is_casting() and player.emotion.current == "damaged_burst")
	check("爆发伤害 = 满蓄力的一半（2），半径 72", near.health.hp == 8 and far.health.hp == far.health.max_hp)
	check("获得一层永久疲倦印记（闷笑积累 +1%）", player.buff_stacks("fatigue_scar") == 1
		and is_equal_approx(player.buffs["fatigue_scar"].modifier("laugh_gain"), 0.01))
	check("身边有怪物：同时触发魔力反噬", player.has_buff("ticklish"))
	var puddles := get_tree().get_nodes_in_group("fatigue_puddle")
	check("原地留下疲倦水液（30 秒）", puddles.size() == 1 and is_equal_approx(puddles[0].lifetime, 30.0)
		and puddles[0].global_position.distance_to(player.global_position) < 4.0)
	check("第一次爆发播放剧情对话（单独的台词文件）", Dialogue.is_active() and ReactionDB.fatigue("first").size() >= 2)
	_finish_dialogue()
	await _wait(0.6)
	check("爆发后恢复行动", not player.is_casting())
	f.set_value(499.0)
	said.clear()
	player.receive_hit(HitData.make_tickle(_src(""), 10.0))
	await _wait(0.1)
	check("之后爆发：说一句 burst 台词", not said.is_empty() and ReactionDB.fatigue("burst").has(said.back()))
	await _wait(3.2)
	check("几秒后再补一句 after 台词", ReactionDB.fatigue("after").has(said.back()))
	GameState.princess_reacted.disconnect(on_said)
	check("疲倦印记叠到 2 层", player.buff_stacks("fatigue_scar") == 2)

	# 水液：怪物踩进去获得力量
	near.process_mode = Node.PROCESS_MODE_INHERIT
	near.global_position = get_tree().get_nodes_in_group("fatigue_puddle")[0].global_position
	await _wait(0.2)
	check("怪物踩进水液获得力量增益（挠痒冷却 ×0.6）", near.has_buff("strength") and is_equal_approx(near.stat_mul("tickle_cd"), 0.6))
	for p in get_tree().get_nodes_in_group("fatigue_puddle"):
		p.lifetime = p._age + 0.2
	await _wait(0.4)
	check("水液到时间干掉", get_tree().get_nodes_in_group("fatigue_puddle").is_empty())
	near.queue_free()
	far.queue_free()

	# 清心花露
	check("清心花露只在 Boss 掉落表里", _dew_sources() == ["jelly_queen.tres", "tentacle_boss.tres", "tickle_troll.tres"])
	GameState.give_item(ItemDB.get_item("mint"), 1, player)
	GameState.give_item(ItemDB.get_item("clear_dew"), 1, player)
	player.laugh.set_value(30.0)
	player.use_item()
	check("Q 键吃薄荷糖，不会用掉花露", GameState.inventory.count("clear_dew") == 1 and player.buff_stacks("fatigue_scar") == 2)
	player.use_item("use_special")
	check("R 键用清心花露：疲倦印记全部清掉", GameState.inventory.count("clear_dew") == 0 and not player.has_buff("fatigue_scar"))
	f.clear()
	_reset()


# ------------------------------------------------------------------ 新怪物
func _run_monsters() -> void:
	print("-- 新怪物")
	Monster.random_specials = false
	var f: MagicFatigue = player.fatigue

	# 魔力水母
	_reset()
	var jelly := _spawn("mana_jelly", Vector2(12, 0))
	player.laugh.clear()
	jelly._action_cd = 0.0
	jelly.tickle(player)
	check("魔力水母：挠痒 6，疲倦 ×3（6 × 0.5 × 3 = 9）", is_equal_approx(player.laugh.value, 6.0) and is_equal_approx(f.value, 9.0))
	check("魔力水母：暴击率 25%", is_equal_approx(jelly.stats.special_chance, 0.25))
	jelly.health.damage(99)
	await _wait(0.1)
	var puddles := get_tree().get_nodes_in_group("fatigue_puddle")
	check("魔力水母被打散留下一小滩水液（12 秒）", puddles.size() == 1 and is_equal_approx(puddles[0].lifetime, 12.0))
	_clear_puddles()

	# 泡泡鱼
	_reset()
	var fish: BubbleFish = _spawn("bubble_fish", Vector2(60, 0))
	fish.target = player
	player.laugh.clear()
	fish.shoot_bubble()
	await _wait(1.0)
	check("泡泡鱼：泡泡命中把公主关进泡泡（抓取）", player.status.is_grabbed_by(fish) and fish.is_trapping()
		and player.get_children().any(func(c): return c is Sprite2D and c.texture == BubbleFish.CAGE_TEX))
	fish.process_mode = Node.PROCESS_MODE_INHERIT
	await _wait(0.7)
	check("泡泡里持续挠痒（算泡泡鱼的）", player.laugh.value >= 5.9 and player.last_tickle.source == fish)
	for i in fish.trap_presses:
		player.status.struggle()
	await _wait(0.3)
	check("连按 5 次戳破泡泡", not player.status.is_grabbed() and not fish.is_trapping()
		and not player.get_children().any(func(c): return c is Sprite2D and c.texture == BubbleFish.CAGE_TEX))
	fish.queue_free()

	# 发射者在泡泡飞行中被打倒：泡泡照常命中 / 消失，不报错
	_reset()
	var fish2: BubbleFish = _spawn("bubble_fish", Vector2(60, 0))
	fish2.target = player
	fish2.shoot_bubble()
	fish2.free()
	await _wait(1.0)
	check("泡泡鱼被释放后泡泡碰到公主：不报错、泡泡消失", get_tree().get_nodes_in_group("x").is_empty()
		and level.get_node("Entities").get_children().all(func(n): return not (n is BubbleShot)) and not player.status.is_grabbed())

	# 幽灵手套（成对）
	_reset()
	var g1 := _spawn("ghost_glove", Vector2(10, 0), false, {"pair": "t"}) as GhostGlove
	var g2 := _spawn("ghost_glove", Vector2(-10, 0), false, {"pair": "t"}) as GhostGlove
	check("幽灵手套：同名 pair 的两只配成一对", g1.partner() == g2 and g2.partner() == g1)
	check("幽灵手套只挠痒、不打人", g1._choose_action(player) == "tickle" and g1.stats.attack_damage == 0)
	player.laugh.clear()
	g1._action_cd = 0.0
	g1.tickle(player)
	check("两只都在身边：必定暴击 + 搭档补挠（5×2 + 5 = 15）", absf(player.laugh.value - 15.0) < 0.1 and g2._combo_cd > 0.0)
	player.laugh.clear()
	g1._action_cd = 0.0
	g1.tickle(player)
	check("配合技有冷却：下一下是普通挠痒", absf(player.laugh.value - 5.0) < 0.1)
	g1._combo_cd = 0.0
	g2._combo_cd = 0.0
	g2.global_position = player.global_position + Vector2(0, 80)
	check("只有一只在身边时不会配合", not g1.pair_ready(player))
	g2.health.damage(99)
	await _wait(0.1)
	check("搭档被打散后变回单只", g1.partner() == null)
	g1.queue_free()

	# 刷刷刺猬
	_reset()
	var hog: BrushHedgehog = _spawn("brush_hedgehog", Vector2(80, 0), true)
	hog._roll_cd = 0.0
	player.laugh.clear()
	await _wait(0.15)
	check("刺猬：同一行时蜷缩准备滚动", hog.roll_state == BrushHedgehog.Roll.CURL)
	var hp := hog.health.hp
	check("蜷缩时普通攻击打不动", not hog.receive_hit(HitData.make_attack(player, 1)) and hog.health.hp == hp)
	var x0 := player.global_position.x
	await _wait(0.9)
	check("滚中公主：必定暴击的挠痒（7×2）+ 击退", player.last_tickle != null and player.last_tickle.source == hog
		and player.last_tickle.special and player.laugh.value >= 13.9 and player.global_position.x < x0 - 2.0)
	hog.process_mode = Node.PROCESS_MODE_DISABLED
	hog.roll_state = BrushHedgehog.Roll.NONE
	hog.global_position = player.global_position + Vector2(0, 50)
	var wall := _spawn("slime", Vector2(0, 80))
	hog.process_mode = Node.PROCESS_MODE_INHERIT
	hog.begin_curl(Vector2.DOWN)
	await _wait(0.9)
	check("撞到东西会晕（晕的时候能打）", hog.roll_state == BrushHedgehog.Roll.DIZZY and hog.receive_hit(HitData.make_attack(player, 1)))
	hog.global_position = player.global_position + Vector2(0, 50)
	hog.begin_curl(Vector2.DOWN)
	var magic := HitData.make_attack(player, 1)
	magic.tag = "magic_1"
	hog._attack_invuln = 0.0
	check("滚球可以被星光爆发打中", hog.receive_hit(magic))
	hog.queue_free()
	wall.queue_free()

	# 魔力水母女王
	_reset()
	var queen: JellyQueen = _spawn("jelly_queen", Vector2(0, 60))
	check("女王：Boss、血 24、暴击率 35%", queen.stats.is_boss and queen.health.max_hp == 24 and is_equal_approx(queen.stats.special_chance, 0.35))
	queen._update_summon(10.0)
	_freeze_group("summoned_jelly")
	check("每 8 秒召唤 2 只魔力水母", get_tree().get_nodes_in_group("summoned_jelly").size() == 2 and is_equal_approx(queen._summon_cd, 8.0))
	queen._update_summon(10.0)
	_freeze_group("summoned_jelly")
	queen._update_summon(10.0)
	_freeze_group("summoned_jelly")
	check("场上最多 4 只", get_tree().get_nodes_in_group("summoned_jelly").size() == 4)
	queen._update_puddle(10.0)
	check("定时在身下留水液", get_tree().get_nodes_in_group("fatigue_puddle").size() == 1)
	f.clear()
	queen._update_rain(1.0)
	check("满血时没有魔力雨", not queen.raining and f.value == 0.0)
	queen.health.damage(12)
	queen._update_rain(1.0)
	check("半血后魔力雨：每秒 +3 疲倦", queen.raining and absf(f.value - 3.0) < 0.01)
	queen.health.damage(99)
	await _wait(0.2)
	check("女王倒下：召唤的水母一起散掉", get_tree().get_nodes_in_group("summoned_jelly").is_empty())
	check("女王掉落清心花露", level.get_node("Entities").get_children().any(
		func(n): return n is WorldItem and n.item and n.item.id == "clear_dew"))
	for n in level.get_node("Entities").get_children():
		if n is WorldItem:
			n.queue_free()
	_clear_puddles()
	GameState.boss_changed.emit(null)
	Monster.random_specials = true
	f.clear()
	_reset()


# ------------------------------------------------------------------ 新陷阱
func _trap(file: String, offset: Vector2, props := {}) -> Node2D:
	var t: Node2D = load("res://scenes/traps/%s.tscn" % file).instantiate()
	for k in props:
		t.set(k, props[k])
	level.get_node("Entities").add_child(t)
	t.global_position = player.global_position + offset
	return t


func _run_traps() -> void:
	print("-- 新陷阱")
	Monster.random_specials = false
	var f: MagicFatigue = player.fatigue

	# 狂热图腾
	_reset()
	var totem: FrenzyTotem = _trap("frenzy_totem", Vector2(70, 0))
	var slime := _spawn("slime", Vector2(70, 0), true)
	slime.stats = slime.stats.duplicate()
	slime.stats.detect_range = 0.0
	await _wait(0.5)
	check("狂热图腾：光环内的怪物获得狂热", slime.has_buff("frenzy"))
	check("图腾挡路（墙层）", (totem.get_node("Body") as StaticBody2D).collision_layer & 1 == 1)
	for i in 3:
		totem.receive_hit(HitData.make_attack(player, 1))
	check("权杖打三下打碎", totem.broken and not totem.active)
	await _wait(1.5)
	check("打碎后狂热消失", not slime.has_buff("frenzy"))
	slime.queue_free()
	var totem2: FrenzyTotem = _trap("frenzy_totem", Vector2(24, 0))
	StarBurst.cast(player, 1)
	check("1 档星光爆发就能打碎图腾", totem2.broken)
	await _wait(0.6)
	totem.queue_free()
	totem2.queue_free()

	# 诅咒符文
	_reset()
	player.laugh.clear()
	var rune: HexRune = _trap("hex_rune", Vector2.ZERO)
	await _wait(0.15)
	check("诅咒符文：易痒诅咒 10 秒", player.has_buff("ticklish") and player.buffs["ticklish"].time_left > 9.5)
	check("诅咒符文：魔力疲倦 +20", f.value >= 20.0 and f.value < 23.0)
	check("诅咒符文：轻挠一下（算符文的）", player.last_tickle != null and player.last_tickle.source == rune)
	await _wait(0.2)
	check("符文冷却 4 秒", rune.phase == Trap.Phase.COOLDOWN)
	rune.queue_free()
	await _wait(0.1)

	# 足枷台
	_reset()
	player.laugh.clear()
	var stocks: Stocks = _trap("stocks", Vector2.ZERO)
	await _wait(0.15)
	check("足枷台：踩上去被锁住（抓取）", player.status.is_grabbed_by(stocks))
	await _wait(0.9)
	check("羽毛滚轮持续挠脚心", player.laugh.value >= 7.9 and player.last_tickle.source == stocks and not player.last_tickle.special)
	for i in stocks.lock_presses:
		player.status.struggle()
	await _wait(0.1)
	check("连按 6 次挣脱，挣脱时没有暴击", not player.status.is_grabbed() and not stocks.is_locking() and not player.last_tickle.special)
	stocks.queue_free()
	await _wait(0.1)
	player._full_invuln = 0.0  # 挣脱后的短暂无敌
	var stocks2: Stocks = _trap("stocks", Vector2.ZERO)
	await _wait(3.3)
	check("拖到时间结束：最后一下必定暴击（4 × 2）", not player.status.is_grabbed() and player.last_tickle.source == stocks2
		and player.last_tickle.special and absf(player.last_tickle.tickle - 8.0) < 0.3)
	stocks2.queue_free()
	await _wait(0.1)

	# 黏黏毛毯
	_reset()
	player.laugh.clear()
	var carpet: StickyCarpet = _trap("sticky_carpet", Vector2(-16, -8), {"tiles_w": 3, "tiles_h": 2})
	check("毛毯按 w/h 铺成多格", carpet._tiles.size() == 6 and ((carpet.get_node("Shape") as CollisionShape2D).shape as RectangleShape2D).size.x == 46.0)
	await _wait(0.3)
	check("走上毛毯变黏黏（减速）", player.has_buff("sticky"))
	await _wait(1.0)
	check("站着不动超过 1 秒被黏住（定身）", player.status.is_rooted())
	check("绒毛轻挠（算毛毯的）", player.laugh.value > 0.0 and player.last_tickle.source == carpet)
	player.laugh.set_value(player.laugh.helpless_threshold + 5.0)
	var before := player.laugh.value
	carpet._apply_effect(player)
	check("失控时挠痒 ×2", absf(player.laugh.value - before - 2.0) < 0.1)
	carpet.queue_free()
	player.status.clear_root()
	await _wait(0.4)

	# 伸缩羽毛臂
	_reset()
	player.laugh.clear()
	var arm: FeatherArm = _trap("feather_arm", Vector2(0, -12), {"dir": "down", "length": 2})
	await _wait(0.15)
	check("羽毛臂：有人进入探测区先预警", arm.phase == Trap.Phase.WARN)
	await _wait(0.35)
	check("羽毛臂横扫：定身 + 挠痒 8", player.status.is_rooted() and player.last_tickle != null
		and player.last_tickle.source == arm and absf(player.laugh.value - 8.0) < 0.2)
	check("扫一次只挠一下", absf(player.laugh.value - 8.0) < 0.2)
	await _wait(0.3)
	check("扫完缩回冷却", arm.phase == Trap.Phase.COOLDOWN)
	arm.queue_free()

	var has_lines := true
	for k in ["rune", "stocks", "carpet", "arm"]:
		has_lines = has_lines and not ReactionDB.source(k).is_empty() and not ReactionDB.first_encounter(k).is_empty()
	check("新陷阱都有台词和首遇对话", has_lines)
	Monster.random_specials = true
	f.clear()
	await _wait(0.3)
	_reset()


# ------------------------------------------------------------------ 组合技扩充
func _run_combos() -> void:
	print("-- 组合技扩充")
	Monster.random_specials = false
	var f: MagicFatigue = player.fatigue
	var c: ComboTracker = player.combo
	var fired: Array = []
	var on_fired := func(id: String): fired.append(id)
	c.triggered.connect(on_fired)
	var slime := _spawn("slime", Vector2(40, 0))

	_reset()
	c.reset()
	c.trigger("sole_duet")
	check("脚心双重奏：下 1 次必暴击", player.forced_specials == 1)
	c.trigger("sticky_feather")
	check("黏黏羽毛：黏黏 3 秒", player.has_buff("sticky"))
	c.trigger("invisible_web")
	check("无形蛛网：封魔 3 秒", player.has_buff("sealed") and not player.can_cast())
	c.trigger("fairy_cheer")
	check("精灵起哄：附近怪物狂热", slime.has_buff("frenzy"))
	f.clear()
	c.trigger("tentacle_feet")
	check("触手按脚：疲倦 +20", f.value >= 20.0)
	c.trigger("crab_express")
	check("螃蟹夹送：附近怪物力量", slime.has_buff("strength"))
	c.trigger("wind_brush")
	check("风卷刷：易痒", player.has_buff("ticklish"))
	c.trigger("queen_call")
	check("女王的召集：脚下生成水液", get_tree().get_nodes_in_group("fatigue_puddle").size() == 1)
	_clear_puddles()
	var all_extra := true
	for id in ["sole_duet", "sticky_feather", "invisible_web", "fairy_cheer", "tentacle_feet", "assembly_line", "vine_sweep",
			"wind_brush", "crab_express", "vine_rat", "powder_whirlwind", "powdered_bat", "hand_heist"]:
		var types: Array = ComboTracker.combo_def(id).get("effects", []).map(func(e): return e["type"])
		if not types.any(func(t): return t in ["fatigue", "debuff", "seal", "special_next", "buff_monsters", "puddle"]):
			print("    旧组合没有新效果：", id)
			all_extra = false
	check("旧的 13 个组合都加了新效果", all_extra)

	# 新的来源组合：两个来源在时间窗口内先后挠到
	var pairs := {"bubble_bath": ["mana_jelly", "bubble_fish"], "stocks_glove": ["glove", "stocks"],
		"carpet_roll": ["hedgehog", "carpet"], "hex_sweep": ["arm", "rune"],
		"bubble_feather": ["bubble_fish", "arm"], "queen_call": ["jelly_queen", "mana_jelly"]}
	var ok := true
	for id in pairs:
		_reset()
		c.reset()
		fired.clear()
		for key in pairs[id]:
			player.receive_hit(HitData.make_tickle(_src(key), 1.0))
		if not fired.has(id):
			print("    没触发：", id, " 实际：", fired)
			ok = false
	check("6 个新组合都能由对应来源触发", ok)
	_clear_puddles()
	_reset()
	c.reset()
	fired.clear()
	f.clear()
	player.receive_hit(HitData.make_tickle(_src("mana_jelly"), 1.0))
	player.receive_hit(HitData.make_tickle(_src("bubble_fish"), 1.0))
	check("泡泡魔力浴：疲倦 +40、易痒 5 秒", f.value >= 40.0 and player.has_buff("ticklish"))

	# 狂热连击
	_reset()
	c.reset()
	fired.clear()
	f.clear()
	slime.clear_buffs(false)
	slime._action_cd = 0.0
	slime.tickle(player)
	check("没有增益的怪物暴击不算狂热连击", not fired.has("frenzy_strike"))
	slime.add_buff("frenzy", 5.0)
	player.forced_specials = 1
	slime._action_cd = 0.0
	slime.tickle(player)
	check("被狂热怪物暴击：狂热连击（疲倦 +30，附近怪物力量）", fired.has("frenzy_strike") and f.value >= 30.0 and slime.has_buff("strength"))

	# 魔力反噬
	_reset()
	c.reset()
	fired.clear()
	slime.clear_buffs(false)
	slime.health.max_hp = 20
	slime.health.fill()
	f.set_value(499.0)
	player.receive_hit(HitData.make_tickle(_src(""), 10.0))
	await get_tree().physics_frame
	check("疲倦爆发时身边有怪物：魔力反噬（怪物力量、公主易痒）", fired.has("mana_backlash")
		and slime.has_buff("strength") and player.has_buff("ticklish"))
	await _wait(0.8)
	var named := true
	for id in ComboTracker.ids():
		if str(ReactionDB.combo(id).get("name", "")) == "" or ReactionDB.combo(id).get("lines", []).is_empty():
			print("    缺名称 / 台词：", id)
			named = false
	check("63 个组合技都有名称和台词", named and ComboTracker.ids().size() == 63)
	c.triggered.disconnect(on_fired)
	slime.queue_free()
	_clear_puddles()
	Monster.random_specials = true
	player.clear_buffs(false)
	f.clear()
	_reset()


# ------------------------------------------------------------------ 组合技第三批：三来源、连锁、新效果
func _tk(key: String, amount := 1.0) -> void:
	player.receive_hit(HitData.make_tickle(_src(key), amount))


func _run_combos3() -> void:
	print("-- 组合技：三来源、连锁、新效果")
	Monster.random_specials = false
	var c: ComboTracker = player.combo
	var hud: HUD = main.get_node("HUD")
	var fired: Array = []
	var on_fired := func(id: String): fired.append(id)
	c.triggered.connect(on_fired)

	var triples: Array = ComboTracker.data()["combos"].filter(func(x: Dictionary): return ComboTracker.is_triple(x))
	var cats := {}
	for t in triples:
		cats[t["category"]] = true
	check("25 个三来源组合，四种搭配都有", triples.size() == 25 and cats.has("怪+怪+怪") and cats.has("怪+怪+陷阱")
		and cats.has("怪+陷阱+陷阱") and cats.has("陷阱+陷阱+陷阱"))
	var rules_ok := true
	var scenes_ok := true
	for t in triples:
		var has_focus := false
		for e in t["effects"]:
			has_focus = has_focus or e["type"] == "focus"
		rules_ok = rules_ok and has_focus and is_equal_approx(ComboTracker.combo_window(t), 2.5) \
				and is_equal_approx(ComboTracker.combo_cooldown(t), 8.0)
		scenes_ok = scenes_ok and CG.scenes.has(t["id"])
	check("三来源组合：窗口 2.5 秒、冷却 8 秒，都带镜头聚焦", rules_ok)
	check("每个三来源组合都有小演出（单独文件）", scenes_ok and CG.validate().is_empty())
	var lines_ok := true
	var traps_ok := true
	for id in CG.scenes:
		var sc: Dictionary = CG.scenes[id]
		var said := 0
		for st in sc["steps"]:
			if st.get("speaker", "") == "公主":
				said += 1
			if st.has("auto"):
				lines_ok = false
		lines_ok = lines_ok and said >= 5
		for k in ComboTracker.combo_def(id)["keys"]:
			if ComboTracker.group("trap").has(k[0]):
				var has_actor := false
				for w in sc["cast"]:
					has_actor = has_actor or str(sc["cast"][w]["kind"]) == "trap:" + str(k[0])
				traps_ok = traps_ok and has_actor
	check("演出：公主至少 5 句（三段递进 + 高潮），每句等按键推进", lines_ok)
	check("演出：陷阱来源都作为陷阱演员上台", traps_ok)

	# 优先级：指定来源 > 通配符
	_reset()
	fired.clear()
	_tk("glove")
	_tk("stocks")
	check("手套 + 足枷台 → 枷锁手套（指定来源优先于「枷锁围攻」）", fired == ["stocks_glove"])
	_reset()
	fired.clear()
	_tk("slime")
	_tk("stocks")
	check("史莱姆 + 足枷台 → 果冻枷锁", fired == ["slime_stocks"])
	_reset()
	fired.clear()
	_tk("bat")
	_tk("stocks")
	check("蝙蝠 + 足枷台 → 枷锁围攻（通配任意怪物）", fired == ["stocks_mob"])
	_reset()
	fired.clear()
	_tk("bubble_fish")
	_tk("carpet")
	check("泡泡鱼 + 黏黏毛毯 → 黏黏泡泡", fired == ["bubble_carpet"])

	# 连锁升级：两来源 → 三来源
	_reset()
	fired.clear()
	_tk("rat")
	_tk("crab")
	check("挠脚鼠 + 钳钳蟹 先打出脚心双重奏", fired == ["sole_duet"] and c.chain == 1)
	await _wait(0.3)
	_tk("stocks")
	check("再被足枷台挠到 → 连锁升级成三来源「脚心总动员」", fired.has("sole_mobilize") and c.last_upgraded and c.chain >= 2)
	check("HUD：三重组合大字标题、连锁升级横幅、连锁数", hud.combo_title.text.contains("脚心总动员") and hud.combo_label.text.contains("连锁升级")
		and hud.chain_label.text.begins_with("连锁 ×"))
	check("全场暴击：之后怪物 / 陷阱的每一下都是暴击", player.has_buff("crit_storm"))
	player.laugh.clear()
	_tk("vine", 4.0)
	check("全场暴击中普通挠痒变成暴击（4 → 8）", player.last_tickle.special and absf(player.laugh.value - 8.0) < 0.3)
	await _wait(0.3)
	check("镜头聚焦：放大", player.is_camera_focused() and player.camera.zoom.x > 1.01 * player._focus_base.x)
	await _wait(1.6)
	check("停止被挠 1 秒后镜头还原", not player.is_camera_focused())

	# 陷阱三连
	_reset()
	fired.clear()
	for k in ["stocks", "arm", "carpet"]:
		_tk(k)
	check("陷阱 + 陷阱 + 陷阱：全自动刑台", fired.has("auto_stocks"))
	check("晕头转向：方向颠倒", player.has_buff("dizzy"))
	var x0 := player.global_position.x
	ctrl.move = Vector2.RIGHT
	await _wait(0.4)
	ctrl.move = Vector2.ZERO
	check("晕头转向时按右往左走", player.global_position.x < x0 - 2.0)

	# 抬起
	_reset()
	fired.clear()
	for k in ["hedgehog", "glove", "bubble_fish"]:
		_tk(k)
	check("怪 + 怪 + 怪：全身大扫除", fired.has("full_scrub"))
	check("抬起：被举到半空、被组合抓住", player.has_buff("lifted") and player.status.is_grabbed_by(c))
	for i in 20:
		player.status.struggle()
	check("抬起时挣扎无效", player.status.is_grabbed_by(c))
	await _wait(0.2)
	check("抬起时小人上浮", player.sprite.position.y < -2.0)
	await _wait(2.2)
	check("2 秒后放下", not player.status.is_grabbed() and not player.has_buff("lifted"))

	# 召集
	_reset()
	fired.clear()
	var far := _spawn("slime", Vector2(120, 0), true)
	far.stats = far.stats.duplicate()
	far.stats.detect_range = 0.0
	await _wait(0.1)
	for k in ["rat", "crab", "spider"]:
		_tk(k)
	check("召集：远处怪物锁定公主", fired.has("sole_party") and far.target == player and far.state == Monster.State.CHASE)
	far.queue_free()

	# 抓取延长 / 挣脱次数 / 挣脱后定身
	_reset()
	var holder := _src("hand")
	player.status.grab(holder, 1.0, 4)
	await get_tree().physics_frame
	var left := player.status.grab_time_left()
	player.status.extend_grab(1.5, 3)
	check("抓取延长 1.5 秒、挣脱多 3 次", absf(player.status.grab_time_left() - left - 1.5) < 0.05 and player.status.presses_left() == 7)
	player.status.root_after_release(1.5)
	for i in 7:
		player.status.struggle()
	check("挣脱后再定身 1.5 秒", not player.status.is_grabbed() and player.status.root_time_left() > 1.4)

	# 牢笼里的暴击
	_reset()
	fired.clear()
	player.status.grab(holder, 2.0, 10)
	await get_tree().physics_frame
	left = player.status.grab_time_left()
	var crit := HitData.make_tickle(_src("slime"), 2.0)
	crit.special = true
	player.receive_hit(crit)
	check("被困住时被暴击 → 牢笼里的暴击（+1 秒、+2 次）", fired.has("cage_crit") and player.status.grab_time_left() > left + 0.9
		and player.status.presses_left() == 12)
	player.status.release(true)

	# 连锁加成
	_reset()
	player.laugh.clear()
	c.chain = 2
	c._last_fire = c._time
	c.trigger("sole_duet")
	check("连锁 ×3：额外挠痒 ×1.4（15 → 21）", c.chain == 3 and absf(player.laugh.value - 21.0) < 0.3)

	# 小演出：三来源组合第一次触发时播放，可跳过，第二次不播
	_reset()
	ComboTracker.play_scenes = true
	GameState.flags.erase("combo_scene_curse_hall")
	for k in ["rune", "carpet", "arm"]:
		_tk(k)
	await get_tree().process_frame
	check("小演出先等大字标题演完", not CG.is_playing())
	await _wait(ComboTracker.SCENE_DELAY + 0.2)
	check("第一次触发诅咒回廊：播放小演出", CG.is_playing() and CG.current == "combo:curse_hall" and CG.can_skip())
	check("来源栏三格，开始时都暗着", CG.source_bar.get_child_count() == 3 and not CG.source_lit(0))
	check("演出开始时立绘是失控 1", Dialogue.current_portrait() == Dialogue.portrait_for("helpless_1"))
	var lit_guard := 0
	while CG.step_index < 4 and lit_guard < 40:
		lit_guard += 1
		Dialogue.advance()
		Dialogue.advance()
		await _wait(0.1)
	await _wait(0.4)
	check("第三个来源加入后立绘变成失控 2", Dialogue.current_portrait() == Dialogue.portrait_for("helpless_2"))
	check("三个来源依次加入后来源栏全部点亮，陷阱演员在台上发动", CG.source_lit(0) and CG.source_lit(1) and CG.source_lit(2)
		and CG.actors.values().any(func(a): return a.kind == "trap" and a.is_active_trap()))
	CG.skip()
	await _wait(0.8)
	_finish_dialogue()
	check("小演出可以跳过", not CG.is_playing())
	c.reset()
	for k in ["rune", "carpet", "arm"]:
		_tk(k)
	await _wait(ComboTracker.SCENE_DELAY + 0.2)
	check("第二次不再播", not CG.is_playing())
	ComboTracker.play_scenes = false

	c.triggered.disconnect(on_fired)
	await _wait(0.2)
	Monster.random_specials = true
	player.fatigue.clear()
	_reset()


# ------------------------------------------------------------------ 背包
func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _texts(n: Node) -> String:
	var out := ""
	for c in n.find_children("*", "Label", true, false):
		out += (c as Label).text + "\n"
	return out


func _run_backpack() -> void:
	print("-- 背包")
	_reset()
	var bp: Backpack = main.get_node("Backpack")
	GameState.flags.erase(GameState.BACKPACK_FLAG)
	await _press("backpack")
	check("没拿到背包时按 Tab 打不开", not bp.is_open() and not get_tree().paused)
	GameState.give_item(ItemDB.get_item("backpack"), 1, player)
	_finish_dialogue()
	check("拿到冒险背包（拾取即生效，不占背包格）", GameState.has_backpack() and GameState.inventory.count("backpack") == 0)
	for id in ["mint", "clear_dew", "star_candy", "coin"]:
		GameState.give_item(ItemDB.get_item(id), 2, player)
	await _press("backpack")
	check("按 Tab 打开背包，游戏暂停", bp.is_open() and get_tree().paused and bp.page == 0)
	check("物品页列出所有物品", bp._items.any(func(it): return it.id == "star_candy") and bp.grid.get_child_count() == bp._items.size())
	bp.selected = bp._items.find(ItemDB.get_item("star_candy"))
	bp._refresh()
	check("选中显示名称和说明", bp.detail_name.text.contains("星光糖") and bp.detail_desc.text.contains("冷却"))
	await _press("use_item")
	check("选中星光糖按 Q：设为 Q 键（薄荷糖让出 Q）", GameState.hotkey_item("use_item") == "star_candy" and GameState.hotkey_of("mint") == ""
		and GameState.hotkey_item("use_special") == "clear_dew")
	bp.selected = bp._items.find(ItemDB.get_item("mint"))
	bp._refresh()
	await _press("use_special")
	check("选中薄荷糖按 R：设为 R 键", GameState.hotkey_item("use_special") == "mint" and GameState.hotkey_of("clear_dew") == "")
	check("背包里显示当前快捷键", bp.hotkey_label.text.contains("Q：星光糖") and bp.hotkey_label.text.contains("R：薄荷糖"))
	bp.selected = bp._items.find(ItemDB.get_item("star_candy"))
	bp._refresh()
	player._magic_cd = 5.0
	check("背包里直接使用星光糖：魔法冷却清零", bp.use_selected() and player.magic_cooldown_left() == 0.0
		and GameState.inventory.count("star_candy") == 1)
	player.laugh.set_value(90.0)
	player.fatigue.set_value(320.0)
	player.add_buff("ticklish", 6.0)
	player.add_buff("fatigue_scar", -1.0, 2)
	await _press("backpack")
	var txt := _texts(bp.status_page)
	check("Tab 翻到状态页", bp.page == 1 and bp.status_page.visible and not bp.items_page.visible)
	check("状态页：闷笑值百分比和阶段", txt.contains("闷笑值 60%") and txt.contains("失控 1"))
	check("状态页：魔力疲倦百分比、加成和下一档", txt.contains("魔力疲倦 64%") and txt.contains("下一档：80%"))
	check("状态页：每个状态的名称、剩余时间 / 层数和效果", txt.contains("易痒诅咒") and txt.contains("2 层") and txt.contains("闷笑积累 +30%"))
	await _press("pause")
	check("Esc 关闭背包、恢复游戏（不会打开暂停菜单）", not bp.is_open() and not get_tree().paused
		and not main.get_node("PauseMenu").root.visible)
	player.laugh.clear()
	await _wait(0.2)
	player._magic_cd = 5.0
	ctrl.press(&"use_item")
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("回到游戏按 Q：用掉星光糖（按新的绑定）", GameState.inventory.count("star_candy") == 0 and player.magic_cooldown_left() == 0.0)
	await _wait(0.1)
	check("HUD 背包栏按绑定显示 [Q] / [R]", _texts(main.get_node("HUD").inventory_row).contains("[R]"))
	GameState.hotkeys = GameState.DEFAULT_HOTKEYS.duplicate()
	GameState.hotkeys_changed.emit()
	for id in ["mint", "clear_dew", "coin"]:
		GameState.inventory.remove(id, GameState.inventory.count(id))
	player.laugh.clear()
	player.fatigue.clear()
	_reset()


# ------------------------------------------------------------------ HUD 道具栏轮播与立绘反馈
func _run_hud_portrait() -> void:
	print("-- HUD 道具栏轮播与立绘反馈")
	_reset()
	var hud: HUD = main.get_node("HUD")
	for id in ["mint", "clear_dew", "star_candy", "coin", "key_bronze", "key_gold"]:
		GameState.inventory.remove(id, GameState.inventory.count(id))
	GameState.hotkeys = GameState.DEFAULT_HOTKEYS.duplicate()
	GameState.give_item(ItemDB.get_item("mint"), 1, player)
	GameState.give_item(ItemDB.get_item("coin"), 1, player)
	await get_tree().process_frame
	check("道具不超过 3 个时静态全部显示", hud.carousel_items.is_empty() and hud.visible_item_ids().size() == 2)
	for id in ["clear_dew", "star_candy", "key_bronze", "key_gold"]:
		GameState.give_item(ItemDB.get_item(id), 1, player)
	await get_tree().process_frame
	var vis := hud.visible_item_ids()
	check("超过 3 个只显示 3 格，Q / R 的道具固定在前面", vis.size() == 3 and vis[0] == "mint" and vis[1] == "clear_dew")
	check("「+N」显示还有几个没露出来", hud.more_count() == hud.carousel_items.size() - 1 and hud.more_count() == 3)
	var before: String = vis[2]
	await _wait(HUD.CAROUSEL_TIME + 0.4)
	check("轮播窗口每 2.5 秒换一个道具", hud.visible_item_ids()[2] != before)
	var newest := hud.carousel_items[(hud.carousel_index + 2) % hud.carousel_items.size()]
	GameState.give_item(newest, 1, player)
	await get_tree().process_frame
	check("刚拿到的道具立刻转到窗口里", hud.visible_item_ids()[2] == newest.id)
	for id in ["star_candy", "key_bronze", "key_gold", "coin"]:
		GameState.inventory.remove(id, GameState.inventory.count(id))

	# 立绘反馈
	var fx: PortraitFx = Dialogue.portrait_fx
	fx.clear()
	await _wait(0.4)
	var base := Dialogue.portrait.position
	player.laugh.clear()
	var slime_src := _spawn("slime", Vector2(300, 0))   # 真实怪物当来源（有 hit_fx）
	player.receive_hit(HitData.make_tickle(slime_src, 2.0))
	await get_tree().process_frame
	await get_tree().process_frame
	check("被挠时立绘抖动", Dialogue.is_portrait_shaking())
	check("有来源：立绘上出现该来源的特效贴片", fx.sticker_count() >= 1)
	await _wait(0.5)
	check("抖完回到原位", Dialogue.portrait.position == base and not Dialogue.is_portrait_shaking())
	fx.clear()
	player.receive_hit(HitData.make_tickle(_src(""), 2.0))
	await get_tree().process_frame
	check("没有来源（余痒、组合技）只抖不贴片", fx.sticker_count() == 0)
	player.laugh.set_value(player.laugh.max_value * 0.9)
	await _wait(1.0)
	check("立绘背后没有粉色蒙层", Dialogue.find_children("PortraitGlow*", "", true, false).is_empty())
	await _wait(0.4)
	player.receive_hit(HitData.make_tickle(_src("rat"), 1.0))
	await get_tree().process_frame
	var stage := player.laugh.stage()
	check("失控时立绘旁飘出「哈哈」", fx.haha_count() >= 1)
	check("飘字用挠脚鼠自己配置的 portrait_words", fx.haha_texts().all(func(t): return ReactionDB.portrait_words("rat", stage).has(t))
		and ReactionDB.portrait_words("rat", stage) != ReactionDB.data()["portrait_words"][stage])
	fx.clear()
	await _wait(0.4)
	player.receive_hit(HitData.make_tickle(_src("vine"), 1.0))
	await get_tree().process_frame
	check("没配置的来源用全局默认飘字", fx.haha_count() >= 1
		and fx.haha_texts().all(func(t): return ReactionDB.data()["portrait_words"][stage].has(t)))
	fx.clear()
	await _wait(0.2)
	var crit := HitData.make_tickle(_src("crab"), 1.0)
	crit.special = true
	player.receive_hit(crit)
	await get_tree().process_frame
	var crit_shown := false
	for c in fx.get_children():
		crit_shown = crit_shown or (c is HitFx and (c as HitFx).frame_coords.y == HitFx.KINDS.find("crit") and c.scale.x > 2.5)
	check("暴击：立绘上金色星环（放大 3 倍）", crit_shown)
	GameState.combo_triggered.emit("sole_duet", "脚心双重奏")
	await get_tree().process_frame
	check("组合技：立绘周围爆开心形", fx.get_children().any(func(c): return c is CPUParticles2D))
	player.health.damage(99)
	await get_tree().process_frame
	check("倒下后立绘特效清空", fx.sticker_count() == 0 and fx.haha_count() == 0)
	slime_src.queue_free()
	await _wait(0.5)
	_finish_dialogue()
	_reset()
	player.laugh.clear()


# ------------------------------------------------------------------ 第四层「魔力回廊」
func _run_floor4() -> void:
	print("-- 第四层")
	check("楼层表：第三层之后是第四层，第四层是最后一层", Floors.next_of("floor_03") == "floor_04" and Floors.next_of("floor_04") == ""
		and Floors.display_name("floor_04") == "第四层·魔力回廊")
	await _goto("floor_04")
	check("第四层对话已载入", Dialogue.has_dialogue("intro_4") and Dialogue.has_dialogue("boss4_intro")
		and Dialogue.has_dialogue("ending_4") and not Dialogue.has_dialogue("boss3_intro"))
	var counts := {}
	for n in level.find_children("*", "", true, false):
		var k := ""
		if n is Monster:
			k = (n as Monster).stats.reaction_key
		elif n is Trap:
			k = str(n.get("reaction_key"))
		if k != "":
			counts[k] = int(counts.get(k, 0)) + 1
	var types_ok := true
	for k in ["mana_jelly", "bubble_fish", "glove", "hedgehog", "jelly_queen", "totem", "rune", "stocks", "carpet", "arm"]:
		if not counts.has(k):
			print("    第四层缺少：", k)
			types_ok = false
	check("第四层放了全部新怪物和新陷阱", types_ok and counts["jelly_queen"] == 1)
	var bag := level.find_child("Chest_19_49", true, false)
	check("落脚点旁的储藏室宝箱里是冒险背包", bag != null and bag.item != null and bag.item.id == "backpack")
	var plaza: ArenaZone = null
	for a in get_tree().get_nodes_in_group("arena"):
		if a.group_name == "arena_plaza":
			plaza = a
	check("新增刑台广场战斗房", plaza != null)
	var star := 0
	for ch in level.find_children("Chest_*", "", true, false):
		if ch.item and ch.item.id == "star_candy":
			star += 1
	check("两个宝箱里有星光糖", star == 2)
	check("检查点减到 4 个", level.find_children("Checkpoint_*", "", true, false).size() == 4)
	var gloves := level.find_children("*", "GhostGlove", true, false)
	check("幽灵手套都成对（%d 只）" % gloves.size(), gloves.size() % 2 == 0 and gloves.all(func(g2): return g2.partner() != null))
	var carpet := level.find_child("Carpet_56_48", true, false) as StickyCarpet
	check("水道毛毯 5×2 盖住缺口", carpet != null and carpet.tiles_w == 5 and carpet.tiles_h == 2)
	var arm := level.find_child("Arm_63_37", true, false) as FeatherArm
	check("足枷长廊的羽毛臂朝走廊里扫", arm != null and arm.lane == Vector2.RIGHT and arm.length == 2)
	var gate := level.find_child("Gate_39_5", true, false)
	var queen := level.find_child("JellyQueen_22_4", true, false) as JellyQueen
	check("Boss 门初始关闭", gate != null and not gate.is_open and queen != null and queen.open_on_death == "boss_gate")
	queen.process_mode = Node.PROCESS_MODE_INHERIT
	queen.health.damage(99)
	await _wait(0.2)
	check("打倒水母女王后 Boss 门打开", gate.is_open)
	var trig := level.find_child("Trigger_44_5", true, false)
	check("出口剧情触发器", trig != null and trig.dialogue == "ending_4")
	Dialogue.start("ending_4")
	_finish_dialogue()
	await _wait(0.2)
	check("第四章通关标记", GameState.has_flag("chapter4_clear"))
	GameState.boss_changed.emit(null)


func _freeze_group(g: String) -> void:
	for n in get_tree().get_nodes_in_group(g):
		n.process_mode = Node.PROCESS_MODE_DISABLED


func _clear_puddles() -> void:
	for p in get_tree().get_nodes_in_group("fatigue_puddle"):
		p.remove_from_group("fatigue_puddle")
		p.queue_free()


func _dew_sources() -> Array:
	var out: Array = []
	for fname in DirAccess.get_files_at("res://data/monsters"):
		if fname.ends_with(".tres") and FileAccess.get_file_as_string("res://data/monsters/" + fname).contains("clear_dew"):
			out.append(fname)
	for id in Floors.ids():
		if FileAccess.get_file_as_string(Floors.map_path(id)).contains("clear_dew"):
			out.append(id)
	out.sort()
	return out


# ------------------------------------------------------------------ 工具
func _spawn(file: String, offset: Vector2, active := false, props := {}) -> Monster:
	var m: Monster = load("res://scenes/actors/monsters/%s.tscn" % file).instantiate()
	for k in props:
		m.set(k, props[k])
	level.get_node("Entities").add_child(m)
	m.global_position = player.global_position + offset
	if not active:
		m.process_mode = Node.PROCESS_MODE_DISABLED
	return m


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
	player.forced_specials = 0
	player.clear_buffs(false)
	if player.fatigue:
		player.fatigue.clear()
	player._full_invuln = 0.0
	player._attack_invuln = 0.0
	player._magic_cd = 0.0


func _goto(floor_id: String) -> void:
	main.change_level(Floors.scene(floor_id))
	await _wait(1.4)
	_finish_dialogue()
	_refresh()
	ctrl = ScriptedController.new()
	player.set_controller(ctrl)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.process_mode = Node.PROCESS_MODE_DISABLED


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

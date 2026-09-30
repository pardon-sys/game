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
const MONSTER_KEYS := ["slime", "bat", "ghost", "spider", "troll", "rat", "crab", "split_slime", "mimic", "fairy", "tentacle"]


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
	check("获得一层永久疲倦印记（闷笑积累 +1%）", player.buff_stacks("fatigue_scar") == 1 and is_equal_approx(player.stat_add("laugh_gain"), 0.01))
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
	check("清心花露只在 Boss 掉落表里", _dew_sources() == ["tentacle_boss.tres", "tickle_troll.tres"])
	GameState.give_item(ItemDB.get_item("mint"), 1, player)
	GameState.give_item(ItemDB.get_item("clear_dew"), 1, player)
	player.laugh.set_value(30.0)
	player.use_item()
	check("Q 键吃薄荷糖，不会用掉花露", GameState.inventory.count("clear_dew") == 1 and player.buff_stacks("fatigue_scar") == 2)
	player.use_item("use_special")
	check("R 键用清心花露：疲倦印记全部清掉", GameState.inventory.count("clear_dew") == 0 and not player.has_buff("fatigue_scar"))
	f.clear()
	_reset()


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
func _spawn(file: String, offset: Vector2, active := false) -> Monster:
	var m: Monster = load("res://scenes/actors/monsters/%s.tscn" % file).instantiate()
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

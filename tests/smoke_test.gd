extends Node
## 冒烟测试：加载主场景，逐项验证核心交互与各基类/接口。
## 用法：Godot --headless --path . res://tests/smoke_test.tscn   （退出码 0 = 全部通过）

const SLIME_SCENE := "res://scenes/actors/monsters/slime.tscn"
const KNIGHT_SCENE := "res://scenes/actors/allies/knight.tscn"
const FEATHER_SCENE := "res://scenes/traps/feather_trap.tscn"

var level: Node
var player: PlayableCharacter
var ctrl := ScriptedController.new()
var failures := 0


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	level = main.get_node("Floor01")
	player = get_tree().get_first_node_in_group("player")
	player.set_controller(ctrl)
	_mark_all_sources_met()
	await _wait(1.2)
	await _run_basics()
	await _run_visual_states()
	await _run_reactions()
	await _run_combat()
	await _run_laugh()
	await _run_items()
	await _run_ally()
	await _run_traps()
	await _run_death()
	_run_contracts()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ 基础交互
func _run_basics() -> void:
	print("-- 基础交互")
	check("关卡脚本已挂载（main.tscn 没有覆盖掉 level.gd）", level.get_script() != null and level.get_script().resource_path == "res://scripts/level.gd")
	check("开场对话自动播放", Dialogue.is_active())
	check("开场第一句公主表情=难过", player.emotion.current == "sad")
	_finish_dialogue()
	await _wait(0.3)
	check("对话结束后恢复控制", not GameState.in_dialogue)

	var x0 := player.global_position.x
	ctrl.move = Vector2.RIGHT
	await _wait(0.4)
	ctrl.move = Vector2.ZERO
	check("向右移动", player.global_position.x > x0 + 10.0)
	check("朝向为侧面", player.dir_name() == "side")

	var gate1 := _find("Gate_31_36")
	check("牢门初始关闭", not gate1.is_open)
	_find("Lever_34_41").on_interact(player)
	check("拉杆打开牢门（Switchable）", gate1.is_open)
	await _wait(0.1)
	check("牢门碰撞已关闭", gate1.get_node("Shape").disabled)

	var torch := _find("Torch_18_31")
	check("火把初始未点燃", not torch.lit)
	torch.on_interact(player)
	check("点燃火把", torch.lit and torch.get_node("Light").enabled)

	_find("Chest_38_20").on_interact(player)
	check("宝箱把铜钥匙放进背包", GameState.inventory.count("key_bronze") == 1)
	check("开箱表情=开心", player.emotion.current == "happy")
	await _wait(0.7)
	check("获得钥匙后播放对话", Dialogue.is_active())
	_finish_dialogue()
	await _wait(0.3)
	var bronze := _find("Door_52_7")
	bronze.on_interact(player)
	check("铜锁门消耗钥匙并打开", bronze.is_open and GameState.inventory.count("key_bronze") == 0)

	var gold := _find("Door_52_18")
	gold.on_interact(player)
	check("没有金钥匙时门不开", not gold.is_open)
	check("没有金钥匙时提示对话", Dialogue.is_active())
	_finish_dialogue()
	await _wait(0.3)

	_find("Letter_14_12").on_interact(player)
	for i in 4:
		Dialogue.advance()
		Dialogue.advance()
		if player.emotion.current == "shy":
			break
	check("读信后害羞", player.emotion.current == "shy")
	_finish_dialogue()
	await _wait(1.6)
	check("对话结束后表情回到普通", player.emotion.current == "normal")


# ------------------------------------------------------------------ 11-state presentation, boundaries and voice lifecycle
func _run_visual_states() -> void:
	print("-- 11状态与素材映射")
	var princess := player as Princess
	GameState.set_flag("seen_laugh_recover")
	princess.revive()
	_move_player_to(Vector2i(29, 40))
	check("11种状态注册", GameState.EMOTIONS.size() == 11)
	check("11行16列动画图集", player.sprite.hframes == 16 and player.sprite.vframes == 11)
	for e in GameState.EMOTIONS.slice(0, 6):
		GameState.emote(e, 0.0, false)
		check("基础表情 " + e, player.emotion.current == e)
		var i := GameState.EMOTIONS.find(e)
		check("立绘与HUD映射 " + e, Dialogue.portrait_for(e).region.position.x == i * Dialogue.portrait_cell.x and Dialogue.head_for(e).region.position.x == i * Dialogue.head_size)
	GameState.emote("happy", 0.0, false)
	for sample in [[50.0, "happy"], [50.01, "giggle"], [80.0, "giggle"],
		[80.01, "helpless_1"], [100.0, "helpless_1"], [100.01, "helpless_2"],
		[100.0, "helpless_1"], [80.0, "damaged_giggle"], [50.0, "happy"]]:
		player.laugh.set_value(sample[0])
		check("阈值 %.2f → %s" % sample, player.emotion.current == sample[1])
	GameState.emote("", 0.05, false)  # 事件表情结束
	await _wait(0.15)
	check("事件表情结束后显示战损", player.emotion.current == "damaged")
	check("未扣血失控也战损", princess.battle_damaged and player.health.is_full())
	player.health.fill()
	check("满血不修复战损", princess.battle_damaged)
	Dialogue.start_lines([{"speaker": "公主", "emotion": "shy", "text": "状态优先级检查"}])
	check("战损时剧情事件显示原表情", player.emotion.current == "shy" and Dialogue.portrait.texture == Dialogue.portrait_for("shy"))
	player.laugh.set_value(110.0)
	check("对话中同步失控立绘", Dialogue.portrait.texture == Dialogue.portrait_for("helpless_2"))
	var hud := get_tree().root.find_child("HUD", true, false)
	check("HUD同步最终表情", hud != null and hud.portrait.texture == Dialogue.head_for("helpless_2"))
	_finish_dialogue()
	player.laugh.clear()
	await _wait(1.4)
	check("剧情结束后退回战损", player.emotion.current == "damaged" and Dialogue.portrait.texture == Dialogue.portrait_for("damaged"))
	princess.revive()
	check("复活清除异常并回普通", not princess.battle_damaged and player.emotion.current == "normal")
	player.laugh.add(150.0)
	check("一次跨越所有阈值扣血回落到 100", player.health.hp == player.health.max_hp - 1 and player.laugh.value == 100.0 and player.emotion.current == "helpless_1")
	check("轻笑和大笑音频已加载", not Audio._streams["giggle"].is_empty() and not Audio._streams["laugh"].is_empty())
	player.laugh.set_value(60.0)  # 回到憋笑段，语音切到轻笑
	Audio.play_voice("giggle")
	check("专用声音通道播放", Audio._voice.playing)
	var voice_stream := Audio._voice.stream
	Audio.play_voice("giggle")
	check("同一通道不叠加声音", Audio._voice.stream == voice_stream)
	player.laugh.set_value(110.0)
	check("跨笑声类别立即切换连续大笑", Audio._voice.playing and Audio._voice.stream != voice_stream)
	Audio.play_voice("laugh")
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	check("暂停停止声音", not Audio._voice.playing)
	get_tree().paused = false
	player.laugh.clear()
	check("恢复平静停止声音", not Audio._voice.playing)
	princess.revive()
	# Verify actual atlas columns for both independent horizontal directions.
	for e in GameState.EMOTIONS:
		var row := GameState.EMOTIONS.find(e)
		player.animator.play("walk")
		player.animator.time = 0.0
		player.animator.update(0.0, "side", true, row)
		check("左向独立素材 " + e, player.sprite.frame_coords == Vector2i(4, row) and not player.sprite.flip_h)
		player.animator.update(0.0, "side", false, row)
		check("右向独立素材 " + e, player.sprite.frame_coords == Vector2i(8, row) and not player.sprite.flip_h)
	# Overflow damage may kill; the reset to 100 must not override death presentation.
	player.health.set_hp(1)
	player.laugh.add(150.0)
	check("满值致死优先于憋笑", player.state == PlayableCharacter.State.DEAD and player.emotion.current == "damaged" and not Audio._voice.playing)
	await _wait(2.0)
	check("满值致死后复活重置", not princess.battle_damaged and player.health.is_full() and player.laugh.value == 0.0)
	_finish_dialogue()
	await _wait(1.5)


# ------------------------------------------------------------------ 常驻立绘、受挠台词、持续大笑与怪物倾向
func _run_reactions() -> void:
	print("-- 挠痒反馈")
	var princess := player as Princess
	princess.revive()
	_move_player_to(Vector2i(29, 40))
	_clear_invuln()
	check("无对话时左侧立绘常驻", Dialogue.portrait.visible and not Dialogue.is_active())
	Dialogue.portrait.hide()
	Dialogue._show_portrait("normal")
	Dialogue._show_portrait("happy")
	check("快速换表情不遗留入场透明度", Dialogue.portrait.modulate.a == 1.0 and Dialogue.portrait.position.x == 2.0)
	Dialogue._show_portrait(player.emotion.current)
	player.receive_hit(HitData.make_tickle(null, 5.0))
	check("受挠显示独立文本", Dialogue.reaction_panel.visible and Dialogue.reaction_text.text in ReactionDB.lines("", "calm"))
	check("受挠文本不暂停战斗", not GameState.in_dialogue and not Dialogue.is_active())
	var first := Dialogue.reaction_text.text
	player.receive_hit(HitData.make_tickle(null, 5.0))
	check("连续命中不会刷屏", Dialogue.reaction_text.text == first)
	var x0 := player.position.x
	ctrl.move = Vector2.RIGHT
	await _wait(0.2)
	ctrl.move = Vector2.ZERO
	check("显示台词时可以移动", player.position.x > x0)
	player.laugh.set_value(50.0)
	player.receive_hit(HitData.make_tickle(null, 1.0))
	check("跨档立即更新憋笑台词", Dialogue.reaction_text.text in ReactionDB.lines("", "giggle"))
	GameState.emote("shy", 0.0, false)
	check("常驻立绘同步异常状态", Dialogue.portrait.texture == Dialogue.portrait_for("giggle"))
	Dialogue.start_lines([{"speaker": "骑士", "text": "我来帮忙！"}])
	check("其他角色对话也保留公主立绘", Dialogue.portrait.visible)
	check("正式对话隐藏受挠文本", not Dialogue.reaction_panel.visible)
	_finish_dialogue()
	await _wait(0.2)
	princess._reaction_cooldown = 0.0
	player.receive_hit(HitData.make_tickle(null, 1.0))
	await _wait(2.5)
	check("台词到时消失而立绘保留", not Dialogue.reaction_panel.visible and Dialogue.portrait.visible)
	var old_decay := player.laugh.decay_rate
	player.laugh.decay_rate = 0.0
	player.laugh.set_value(85.0)
	check("高闷笑立即连续播放", Audio._voice.playing and (Audio._voice.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD)
	var finished_count := [0]
	var on_finished := func(): finished_count[0] += 1
	Audio._voice.finished.connect(on_finished)
	await _wait(Audio._voice.stream.get_length() + 0.25)
	check("跨越音频长度无结束与重启间隙", Audio._voice.playing and finished_count[0] == 0)
	Audio._voice.finished.disconnect(on_finished)
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	check("循环大笑暂停停止", not Audio._voice.playing)
	get_tree().paused = false
	await get_tree().process_frame
	await get_tree().process_frame
	check("解除暂停继续大笑", Audio._voice.playing)
	player.laugh.set_value(80.0)
	check("降至80停止连续大笑", not Audio._voice.playing and Audio._voice_state == "giggle")
	player.laugh.decay_rate = old_decay
	player.laugh.clear()
	princess.revive()
	var slime: Monster = _find("Slime_35_23")
	check("挠痒冷却小于普通攻击", slime.stats.tickle_cooldown < slime.stats.attack_cooldown)
	var tickles := 0
	for i in 2000:
		if slime._choose_action(player) == "tickle":
			tickles += 1
	check("AI优先挠痒（2000次中%d次）" % tickles, tickles > 1200 and tickles < 1800)


# ------------------------------------------------------------------ 战斗 / 怪物基类
func _run_combat() -> void:
	print("-- 战斗与怪物")
	_move_player_to(Vector2i(31, 40))
	await _wait(0.1)
	_clear_invuln()
	var hp := player.health.hp
	player.receive_hit(HitData.make_attack(null, 1, 100.0))
	check("受到攻击扣血", player.health.hp == hp - 1)
	check("受伤表情=战损", player.emotion.current == "damaged")
	player.receive_hit(HitData.make_attack(null, 1))
	check("受伤后无敌挡住攻击", player.health.hp == hp - 1)
	var lv := player.laugh.value
	player.receive_hit(HitData.make_tickle(null, 5.0))
	check("攻击无敌不挡挠痒", player.laugh.value > lv)
	await _wait(1.2)

	player.dash(Vector2.LEFT)
	check("冲刺状态", player.state == PlayableCharacter.State.DASH)
	check("冲刺期间无敌", player.is_invulnerable())
	lv = player.laugh.value
	check("冲刺无敌挡住挠痒", not player.receive_hit(HitData.make_tickle(null, 10.0)) and player.laugh.value == lv)
	await _wait(0.8)

	# Monster.attack / Monster.tickle
	var slime: Monster = _find("Slime_35_23")
	player.laugh.clear()
	_clear_invuln()
	hp = player.health.hp
	check("怪物 attack() 成功", slime.attack(player))
	check("attack 扣血", player.health.hp == hp - 1)
	check("attack 不加闷笑值", player.laugh.value == 0.0)
	check("行动后进入冷却", not slime.can_act())
	_clear_invuln()
	slime._action_cd = 0.0
	hp = player.health.hp
	check("怪物 tickle() 成功", slime.tickle(player))
	check("tickle 加闷笑值", is_equal_approx(player.laugh.value, slime.stats.tickle_amount))
	check("tickle 不扣血", player.health.hp == hp)
	player.laugh.clear()
	player.health.fill()

	# 攻击史莱姆
	var target := _find("Slime_27_22")
	_move_player_to(Vector2i(27, 23))
	player.facing = Vector2.UP
	# 史莱姆会反击/挠痒让公主进入受伤状态打断挥击；这里只测攻击输出，所以先给全无敌
	player.set_invulnerable(2.0, true)
	for i in 3:
		if is_instance_valid(target):
			target.global_position = player.global_position + Vector2(0, -12)
		while not player.can_act():
			await get_tree().physics_frame
		player.attack()
		await _wait(0.35)
	check("三次攻击击败史莱姆", not is_instance_valid(target))
	await _wait(0.2)

	var barrel := _find("Barrel_5_20")
	check("木桶是 Damageable", Contracts.is_damageable(barrel))
	barrel.receive_hit(HitData.make_attack(player, 1))
	await _wait(0.1)
	check("木桶被打碎", not is_instance_valid(barrel))
	player.laugh.clear()
	player.health.fill()


# ------------------------------------------------------------------ 闷笑值
func _run_laugh() -> void:
	print("-- 闷笑值")
	GameState.set_flag("seen_laugh_recover")  # 避免恢复台词打断测试
	_move_player_to(Vector2i(29, 40))  # 牢房里，周围没有怪物
	await _wait(0.2)
	var m := player.laugh

	# 速度
	m.notify_attacked()
	m.set_value(30.0)
	player.velocity = Vector2.ZERO
	ctrl.move = Vector2.RIGHT
	await _wait(0.3)
	var v_calm := player.velocity.x
	ctrl.move = Vector2.ZERO
	_move_player_to(Vector2i(29, 40))
	m.notify_attacked()
	m.set_value(60.0)
	check("闷笑值 60 → 发笑状态", m.level == LaughMeter.Level.GIGGLING)
	player.velocity = Vector2.ZERO
	ctrl.move = Vector2.RIGHT
	await _wait(0.3)
	var v_giggle := player.velocity.x
	ctrl.move = Vector2.ZERO
	check("闷笑超过 50 移动速度减半 (%.0f → %.0f)" % [v_calm, v_giggle], absf(v_giggle - v_calm * 0.5) < 3.0)
	check("受伤后闷笑表情=战损憋笑", player.emotion.default_emotion() == "damaged_giggle")

	# 笑瘫
	_move_player_to(Vector2i(29, 40))
	m.notify_attacked()
	m.set_value(90.0)
	await _wait(0.1)
	check("闷笑超过 80 → 笑瘫", player.state == PlayableCharacter.State.HELPLESS)
	var p0 := player.global_position
	ctrl.move = Vector2.RIGHT
	await _wait(0.3)
	ctrl.move = Vector2.ZERO
	check("笑瘫时无法移动", player.global_position.distance_to(p0) < 1.0)
	player.attack()
	check("笑瘫时无法攻击", player.state == PlayableCharacter.State.HELPLESS)
	var before := m.value
	for i in 3:
		ctrl.press(&"attack")
		await get_tree().physics_frame
		await get_tree().physics_frame
	check("连打挣扎降低闷笑值", m.value <= before - 9.0 + 0.01)
	m.notify_attacked()
	m.set_value(70.0)
	await _wait(0.1)
	check("降到 80 以下恢复行动", player.state != PlayableCharacter.State.HELPLESS)

	# 衰减
	m.clear()
	player.receive_hit(HitData.make_tickle(null, 30.0))
	await _wait(1.5)
	check("被挠痒后 2 秒内不衰减", is_equal_approx(m.value, 30.0))
	await _wait(1.5)
	check("无攻击 2 秒后开始衰减", m.value < 30.0)
	player.receive_hit(HitData.make_tickle(null, 1.0))
	var held := m.value
	await _wait(1.0)
	check("持续受到挠痒时不衰减", is_equal_approx(m.value, held))

	# 满值：笑到脱力
	player.health.fill()
	m.notify_attacked()
	m.set_value(145.0)
	var hp := player.health.hp
	player.receive_hit(HitData.make_tickle(null, 10.0))
	check("闷笑满 150 扣半颗心", player.health.hp == hp - 1)
	check("满值后回落到 100", is_equal_approx(m.value, 100.0))
	m.set_value(110.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("闷笑超过 100 → 失控状态 2", player.emotion.current == "helpless_2" and player.state == PlayableCharacter.State.HELPLESS)
	m.set_value(99.0)
	await get_tree().physics_frame
	check("降回 100 以下 → 失控状态 1", player.emotion.current == "helpless_1" and player.state == PlayableCharacter.State.HELPLESS)
	m.clear()
	player.health.fill()
	await _wait(0.3)


# ------------------------------------------------------------------ 物品 / 背包
func _run_items() -> void:
	print("-- 物品与背包")
	var inv := GameState.inventory
	var mint := ItemDB.get_item("mint")
	check("物品数据库加载薄荷糖", mint is LaughReliefItem)
	inv.add(mint, 1)
	player.laugh.notify_attacked()
	player.laugh.set_value(70.0)
	ctrl.press(&"use_item")
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("Q 使用薄荷糖降低 40 闷笑值", is_equal_approx(player.laugh.value, 30.0))
	check("使用后薄荷糖被消耗", inv.count("mint") == 0)
	check("没有闷笑值时不能使用薄荷糖", not mint.can_use(player) or player.laugh.value > 0.0)
	player.laugh.clear()
	check("钥匙不能主动使用", not ItemDB.get_item("key_gold").can_use(player))
	var tmp := Inventory.new()
	check("物品堆叠不超过上限", tmp.add(ItemDB.get_item("coin"), 5000) == 999 and tmp.count("coin") == 999)

	var coin := _find("Item_16_33")
	var coins := inv.count("coin")
	player.global_position = coin.global_position
	await _wait(0.3)
	check("拾取金币进背包", inv.count("coin") == mini(coins + 1, 999) and not is_instance_valid(coin))

	player.health.set_hp(2)
	await _wait(0.1)
	check("回血前仍保留战损", player.emotion.default_emotion() == "damaged")
	var heart := WorldItem.spawn(level.get_node("Entities"), player.global_position, ItemDB.get_item("heart"), 1, false)
	await _wait(0.2)
	check("拾取心立即回血", player.health.hp == 4 and not is_instance_valid(heart))
	player.health.fill()


# ------------------------------------------------------------------ 友军
func _run_ally() -> void:
	print("-- 友军")
	_move_player_to(Vector2i(24, 33))  # 火把走廊
	await _wait(0.2)
	var ents := level.get_node("Entities")
	var knight: Ally = load(KNIGHT_SCENE).instantiate()
	ents.add_child(knight)
	knight.global_position = player.global_position + Vector2(70, 0)
	await _wait(1.2)
	check("骑士跟随公主", knight.global_position.distance_to(player.global_position) < 35.0)
	check("骑士不能被挠痒", not Contracts.is_tickleable(knight))

	player.laugh.notify_attacked()
	player.laugh.set_value(70.0)
	await _wait(0.8)
	check("公主闷笑时骑士帮忙降低（%.0f）" % player.laugh.value, player.laugh.value <= 45.5)
	player.laugh.clear()

	var slime: Monster = load(SLIME_SCENE).instantiate()
	ents.add_child(slime)
	slime.global_position = knight.global_position + Vector2(30, 0)
	await _wait(2.5)
	check("骑士攻击怪物", not is_instance_valid(slime) or slime.health.hp < slime.stats.max_hp)
	if is_instance_valid(slime):
		slime.queue_free()
	knight.queue_free()
	player.laugh.clear()
	player.health.fill()
	await _wait(0.2)


# ------------------------------------------------------------------ 陷阱
func _run_traps() -> void:
	print("-- 陷阱")
	var spike: Trap = _find("Spike_16_4")
	check("尖刺是周期陷阱", spike.trigger_mode == Trap.TriggerMode.PERIODIC)
	GameState.checkpoint = Vector2(10 * 16 + 8, 4 * 16 + 8)
	player.health.fill()
	_clear_invuln()
	var hp := player.health.hp
	player.global_position = spike.global_position + Vector2(0, 4)
	await _wait(3.0)
	check("尖刺升起时扣血", player.health.hp < hp)
	check("尖刺不加闷笑值", player.laugh.value == 0.0)
	_move_player_to(Vector2i(29, 40))
	player.health.fill()
	await _wait(1.2)

	var feather: Trap = load(FEATHER_SCENE).instantiate()
	level.get_node("FloorObjects").add_child(feather)
	feather.global_position = Vector2(33 * 16 + 8, 39 * 16 + 8)
	feather.add_to_group("gate1")
	await _wait(0.2)
	hp = player.health.hp
	player.laugh.clear()
	player.global_position = feather.global_position + Vector2(0, 4)
	await _wait(0.6)
	check("踩到羽毛陷阱加闷笑值", player.laugh.value > 0.0)
	check("羽毛陷阱不扣血", player.health.hp == hp)

	_move_player_to(Vector2i(29, 40))
	player.laugh.clear()
	await _wait(1.8)
	var lever := _find("Lever_34_41")
	var gate1 := _find("Gate_31_36")
	lever.on_interact(player)  # 断电：门关，陷阱启用
	lever.on_interact(player)  # 通电：门开，陷阱停用
	check("拉杆同时控制门和陷阱", gate1.is_open and not feather.active)
	player.global_position = feather.global_position + Vector2(0, 4)
	await _wait(0.6)
	check("停用的陷阱不生效", player.laugh.value == 0.0)
	_move_player_to(Vector2i(29, 40))
	feather.queue_free()


# ------------------------------------------------------------------ 死亡与复活
func _run_death() -> void:
	print("-- 死亡与复活")
	await _wait(1.2)
	var cp := Vector2(10 * 16 + 8, 4 * 16 + 8)
	GameState.checkpoint = cp
	player.health.set_hp(1)
	_clear_invuln()
	player.receive_hit(HitData.make_attack(null, 1))
	check("血量归零进入倒下状态", player.state == PlayableCharacter.State.DEAD)
	await _wait(2.2)
	check("在检查点复活", player.global_position.distance_to(cp) < 1.0)
	check("复活后满血", player.health.is_full())
	check("复活清除战损", not (player as Princess).battle_damaged)
	check("复活后闷笑值清零", player.laugh.value == 0.0)
	check("复活后播放对话", Dialogue.is_active())
	_finish_dialogue()


# ------------------------------------------------------------------ 接口检查
func _run_contracts() -> void:
	print("-- 接口约定")
	check("公主满足 PLAYABLE", Contracts.implements(player, Contracts.PLAYABLE))
	var ok := true
	for n in get_tree().get_nodes_in_group("enemy"):
		ok = ok and Contracts.implements(n, Contracts.MONSTER) and n is Monster
	check("所有怪物满足 MONSTER", ok)
	var knight: Node = load(KNIGHT_SCENE).instantiate()
	check("骑士满足 ALLY", Contracts.implements(knight, Contracts.ALLY) and knight is Ally)
	knight.free()
	ok = true
	var traps := 0
	for n in level.get_node("FloorObjects").get_children():
		if n is Trap:
			traps += 1
			ok = ok and Contracts.implements(n, Contracts.TRAP) and Contracts.is_switchable(n)
	check("所有陷阱满足 TRAP（%d 个）" % traps, ok and traps > 0)
	ok = true
	for id in ItemDB.all_ids():
		var it := ItemDB.get_item(id)
		ok = ok and it != null and it.id == id and Contracts.implements(it, Contracts.ITEM) and it.icon != null
	check("所有物品数据有效", ok)


# ------------------------------------------------------------------ 工具
## 首次遭遇对话在 floor2_test 里单独测；这里预先标记，避免打断其它检查。
func _mark_all_sources_met() -> void:
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)


func check(label: String, ok: bool) -> void:
	print(("  [通过] " if ok else "  [失败] ") + label)
	if not ok:
		failures += 1


func _find(n: String) -> Node:
	var node := level.find_child(n, true, false)
	assert(node != null, "找不到节点 " + n)
	return node


func _move_player_to(c: Vector2i) -> void:
	player.global_position = Vector2(c.x * 16 + 8, c.y * 16 + 12)
	player.velocity = Vector2.ZERO


func _clear_invuln() -> void:
	player._attack_invuln = 0.0
	player._full_invuln = 0.0


func _finish_dialogue() -> void:
	var guard := 0
	while Dialogue.is_active() and guard < 60:
		Dialogue.advance()
		guard += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

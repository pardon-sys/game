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

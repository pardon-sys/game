extends Node
## 第八层夜迷宫测试：小房间睡下 → 冰封 → 迷宫开场；2.5D（法线贴图图块、人物光照、冷光）；紫手 QTE；手覆盖（部位上限、敏感度）；
## 节点小剧场；笑声半径；月光灯清手；冰晶结界冻手 / 震手；冷光；节奏；笑倒回灯；回忆碎片；换段带手；第三段出口。
## 用法：Godot --headless --path . res://tests/floor8_maze_test.tscn   （退出码 0 = 全部通过）

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
	for f in ["f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked", "intro_blue_magic", "f8_done"]:
		GameState.set_flag(f)
	await _run_sleep()
	await _run_25d()
	await _run_qte_and_cover()
	await _run_lamp_and_magic()
	await _run_light_and_rhythm()
	await _run_defeat()
	await _run_shards_and_sections()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


func _level_id() -> String:
	return str(main.level.get("floor_id")) if main.level else ""


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


func _maze_ready() -> bool:
	return _level_id() == "floor_08_maze_1" and _dir() != null and _dir().blue != null and not Cutscene.is_playing() \
		and not Dialogue.is_active() and GameState.has_flag("cutscene_seen_f8_maze_intro")


func _dir() -> MazeDirector:
	return MazeDirector.instance


# ------------------------------------------------------------------ 小房间睡下
func _run_sleep() -> void:
	print("-- 小房间睡下 → 夜迷宫")
	await main.change_level(Floors.scene("floor_08_shelter"))
	# 开场标记在过场开始前就设上了：等过场真的播完
	await _wait(1.0)
	await _advance_until(func(): return not Cutscene.is_playing() and not Dialogue.is_active(), 40.0)
	var bed: Node = null
	for n in main.level.find_children("*", "", true, false):
		if n.get("kind") == "old_bed":
			bed = n
	var seen := []
	var on_cut := func(id: String): seen.append(id)
	Cutscene.started.connect(on_cut)
	bed.on_interact(GameState.player)
	await _advance_until(_maze_ready, 60.0)
	Cutscene.started.disconnect(on_cut)
	var p := GameState.player
	check("床 → 睡吧 → 冰封过场（%s）→ 夜迷宫一，开场过场，操控蓝色公主" % [seen],
		seen.has("f8_shelter_sleep") and seen.has("f8_maze_intro") and _level_id() == "floor_08_maze_1" and p is BluePrincess
		and GameState.has_flag("blue_is_hero") and GameState.has_flag("f8_slept"))
	check("冰封过场：冰块盖住她、脚露在外面（有冰块道具）", FileAccess.get_file_as_string("res://data/cutscenes/floor_08/f8_shelter_sleep.json").contains("prop:ice_block"))


# ------------------------------------------------------------------ 2.5D
func _run_25d() -> void:
	print("-- 2.5D")
	var lv: Node = main.level
	var floor_layer := lv.get_node("Floor") as TileMapLayer
	var tex: Texture2D = (floor_layer.tile_set.get_source(0) as TileSetAtlasSource).texture
	var p := GameState.player
	var cl := p.get_node_or_null("CarryLight") as CarryLight
	var sp := p.get_node("Sprite") as Sprite2D
	check("2.5D：图块是带法线 / 高光的贴图，人物套了实时光照，身上有冷光（开阴影），墙上有幽光点",
		lv.get("style") == "2.5d" and tex is CanvasTexture and (tex as CanvasTexture).normal_texture != null
		and sp.material is ShaderMaterial and (sp.material as ShaderMaterial).shader.resource_path.ends_with("lit_sprite.gdshader")
		and cl != null and cl.shadow_enabled and lv.get_node("WallGlows").get_child_count() > 0)


# ------------------------------------------------------------------ 紫手 QTE / 手覆盖
func _run_qte_and_cover() -> void:
	print("-- 紫手 / QTE / 手覆盖")
	var dir := _dir()
	var blue := GameState.player
	_move_out_of_light(blue)
	var cover := dir.cover
	# QTE 成功：手消散
	var h := dir.spawn_hand(blue.global_position + Vector2(12, 0))
	await _wait(0.3)
	var q := KeySequenceQTE.current
	var prm := dir.qte_params()
	check("紫手靠近 → 头顶弹出按键序列 QTE（%d 个键，限时 %.1f 秒），期间只能移动" % [int(prm["count"]), float(prm["limit"])],
		q != null and q.keys.size() >= 2 and q.keys.size() <= 5 and PlayerInputController.actions_locked)
	if q:
		for k in q.keys.duplicate():
			q.press(q.expected())
	await _wait(0.4)
	check("按对 → 手消散，没盖到身上", cover.total() == 0 and not is_instance_valid(h) or (h as MazeHand).is_gone())
	# QTE 失败：盖住一个部位
	h = dir.spawn_hand(blue.global_position + Vector2(12, 0))
	await _wait(0.3)
	q = KeySequenceQTE.current
	if q:
		q.press(KEY_A)
	await _wait(0.4)
	check("按错 → 那只手盖住一个部位（%s）" % [cover.hands], cover.total() == 1)
	cover.clear()
	# 部位上限：普通部位 1 只，大腿 / 屁股不限
	var ok_sole := dir.cover_zone("sole")
	var again_sole := dir.cover_zone("sole")
	for i in 5:
		dir.cover_zone("thigh")
	check("普通部位最多一只手（脚心第二只盖不上），大腿不限（%d 只）" % cover.count("thigh"), ok_sole and not again_sole and cover.count("thigh") == 5)
	# 节点小剧场：第一只 / 大腿第一次 / 大腿屁股超过 4 只
	await _advance_until(func(): return not CG.is_busy(), 120.0)
	check("节点小剧场：第一只手、第一次盖到大腿、大腿屁股超过 4 只都播过", GameState.has_flag("cg_seen_theater:f8_maze_first")
		and GameState.has_flag("cg_seen_theater:f8_maze_weak_first") and GameState.has_flag("cg_seen_theater:f8_maze_weak_4"))
	for i in 3:
		dir.cover_zone("butt")
	for z in ["armpit", "waist", "neck", "belly"]:
		dir.cover_zone(z)
	await _advance_until(func(): return not CG.is_busy(), 120.0)
	check("手总数超过 8 只 / 12 只的小剧场（共 %d 只）" % cover.total(), cover.total() > 12
		and GameState.has_flag("cg_seen_theater:f8_maze_total_8") and GameState.has_flag("cg_seen_theater:f8_maze_total_12"))
	check("立绘上画着盖住的手（部位数 = %d）" % Dialogue.portrait_fx.cover_hands.size(), Dialogue.portrait_fx.cover_hands.size() == cover.hands.size())
	# 闷笑按部位敏感度涨：大腿（1.4）比脚心（0.95）涨得快
	cover.clear()
	blue.laugh.set_value(0.0)
	blue.set_invulnerable(0.0)
	blue._full_invuln = 0.0
	dir.cover_zone("thigh")
	await _wait(3.0)
	var thigh_gain := blue.laugh.value
	cover.clear()
	blue.laugh.set_value(0.0)
	dir.cover_zone("sole")
	await _wait(3.0)
	var sole_gain := blue.laugh.value
	cover.clear()
	blue.laugh.set_value(0.0)
	check("盖着的手慢慢挠，闷笑按部位敏感度涨（大腿 %.1f > 脚心 %.1f，都不算快）" % [thigh_gain, sole_gain],
		thigh_gain > sole_gain and thigh_gain > 0.5 and thigh_gain < 25.0)
	# 笑声半径：笑起来时吸引半径内的手
	var far := dir.spawn_hand(blue.global_position + Vector2(80, 0))
	var attracted_calm := dir.attracts(far)
	blue.laugh.set_value(blue.laugh.helpless_threshold + 1.0)
	await _wait(0.1)
	var attracted_laugh := dir.attracts(far)
	check("笑声半径：平静时不吸引（%s），失控时半径 %.0f 内的手被吸引（%s）" % [attracted_calm, dir.radius.radius(), attracted_laugh],
		not attracted_calm and attracted_laugh)
	far.vanish()
	blue.laugh.set_value(0.0)


func _move_out_of_light(blue: Node2D) -> void:
	var dir := _dir()
	for i in 30:
		if not (dir.light_at(blue.global_position) is Vector2):
			return
		blue.global_position += Vector2(16, 0)
		if GridPath.walkable(main.level, GridPath.cell(blue.global_position)) == false:
			blue.global_position += Vector2(-16, 16)


# ------------------------------------------------------------------ 月光灯 / 冰晶结界
func _run_lamp_and_magic() -> void:
	_finish()   # 第一次被新来源挠到时的初次遭遇对话
	await get_tree().process_frame
	print("-- 月光灯 / 冰晶结界")
	var dir := _dir()
	var blue := GameState.player
	var cover := dir.cover
	for z in ["thigh", "butt", "sole", "armpit"]:
		dir.cover_zone(z)
	var lamp: MoonLamp = get_tree().get_nodes_in_group("moon_lamp")[1]
	blue.global_position = lamp.global_position + Vector2(0, 4)
	await _wait(0.3)
	check("走进亮着的月光灯：身上的手全部散掉，记为重生点", cover.total() == 0 and dir.last_lamp == lamp
		and GameState.checkpoint.distance_to(lamp.global_position) < 20.0)
	lamp.extinguish()
	for z in ["thigh", "sole"]:
		dir.cover_zone(z)
	await _wait(0.3)
	check("被吹灭的灯不能清手", cover.total() == 2)
	lamp.on_interact(blue)
	await _wait(0.3)
	check("按 E 重新点亮 → 又能清手", lamp.lit and cover.total() == 0)
	_move_out_of_light(blue)
	for z in ["thigh", "butt", "sole", "armpit", "waist"]:
		dir.cover_zone(z)
	var h := dir.spawn_hand(blue.global_position + Vector2(20, 0))
	h.cooldown(99.0)
	blue._magic_cd = 0.0
	blue.magic_event.emit("burst", 3)
	await get_tree().process_frame
	check("冰晶结界满蓄力：冻住范围内的手，震掉大腿 / 屁股以外的手（剩 %s）" % [cover.hands],
		h.is_frozen() and cover.count("sole") == 0 and cover.count("armpit") == 0 and cover.count("thigh") == 1 and cover.count("butt") == 1)
	h.vanish()
	cover.clear()


# ------------------------------------------------------------------ 冷光 / 节奏
func _run_light_and_rhythm() -> void:
	_finish()   # 第一次被新来源挠到时的初次遭遇对话
	await get_tree().process_frame
	print("-- 冷光 / 节奏")
	var dir := _dir()
	var blue := GameState.player
	var cl := dir.carry_light()
	cl.level = 1.0
	var bright := dir.qte_params()
	await _wait(1.0)
	var drained := cl.level
	cl.spend(0.9)
	var dark := dir.qte_params()
	check("冷光：随时间变暗（1 秒后 %.3f）、放魔法扣一截；暗的时候 QTE 提示晚出现（%.2f → %.2f 秒）" % [drained, float(bright["delay"]), float(dark["delay"])],
		drained < 1.0 and float(dark["delay"]) > float(bright["delay"]) + 0.3 and dir.hand_visibility() < 0.3)
	var lamp: MoonLamp = get_tree().get_nodes_in_group("moon_lamp")[0]
	blue.global_position = lamp.global_position + Vector2(0, 4)
	await _wait(1.5)
	check("在月光灯下冷光补回来（%.2f）" % cl.level, cl.level > 0.6)
	_move_out_of_light(blue)
	# 节奏：蓄力后的狠挠；冲刺 / 光里能躲
	var cover := dir.cover
	dir.cover_zone("thigh")
	dir.cover_zone("sole")
	var states := []
	var on_r := func(s: String): states.append(s)
	cover.rhythm.connect(on_r)
	blue.laugh.set_value(0.0)
	blue.set_invulnerable(0.0)
	blue._full_invuln = 0.0
	cover.rhythm_now()
	await _advance_until(func(): return states.has("hit") or states.has("miss"), 20.0)
	var hit_gain := blue.laugh.value
	check("节奏：身上的手一起蓄力（屏幕边缘闪紫光）然后狠挠一下（闷笑 %.0f）" % hit_gain, states.has("charge") and states.has("hit") and hit_gain > 8.0)
	states.clear()
	cover.rhythm_now()
	await _advance_until(func(): return states.has("charge"), 20.0)
	blue.global_position = lamp.global_position + Vector2(0, 4)
	await _advance_until(func(): return states.has("hit") or states.has("miss"), 5.0)
	check("蓄力时躲进光里：这一下挠空了", states.has("miss"))
	cover.rhythm.disconnect(on_r)
	cover.clear()
	_move_out_of_light(blue)


# ------------------------------------------------------------------ 笑倒 → 回到上一盏灯
func _run_defeat() -> void:
	_finish()   # 第一次被新来源挠到时的初次遭遇对话
	await get_tree().process_frame
	print("-- 笑倒")
	var dir := _dir()
	var blue := GameState.player
	var lamp := dir.last_lamp
	for z in ["thigh", "butt"]:
		dir.cover_zone(z)
	var seen := []
	var on_cg := func(id: String): seen.append(id)
	CG.started.connect(on_cg)
	blue.set_invulnerable(0.0)
	blue._full_invuln = 0.0
	blue.laugh.set_value(blue.laugh.max_value - 0.5)
	blue.receive_hit(HitData.make_tickle(blue, 10.0))
	await _advance_until(func(): return seen.size() > 0 and not CG.is_busy() and blue.is_alive() and not dir._busy, 60.0)
	CG.started.disconnect(on_cg)
	check("闷笑满 → 迷宫笑倒小剧场（%s）→ 回到上一盏月光灯，手清空" % [seen], seen.has("theater:f8_maze_defeat_1") and dir.cover.total() == 0
		and blue.global_position.distance_to(lamp.global_position) < 24.0 and blue.is_alive())


# ------------------------------------------------------------------ 回忆碎片 / 换段 / 出口
func _run_shards_and_sections() -> void:
	_finish()   # 第一次被新来源挠到时的初次遭遇对话
	await get_tree().process_frame
	print("-- 回忆碎片 / 换段 / 出口")
	var dir := _dir()
	var blue := GameState.player
	var shard: MemoryShard = get_tree().get_nodes_in_group("memory_shard")[0]
	blue.global_position = shard.global_position
	await _wait(0.3)
	check("捡到回忆碎片：闪回她的独白，回忆 1 / 6", MemoryShard.collected() == 1 and Dialogue.is_active())
	_finish()
	await _wait(0.3)
	dir.cover_zone("thigh")
	dir.cover_zone("sole")
	var exit_node: Node = null
	for n in main.level.find_children("*", "", true, false):
		if n.get("target_level") != null:
			exit_node = n
	blue.global_position = (exit_node as Node2D).global_position
	await _advance_until(func(): return _level_id() == "floor_08_maze_2" and _dir() != null and _dir().cover != null, 30.0)
	await _wait(0.3)
	dir = _dir()
	check("走到出口 → 夜迷宫二，身上的手一起带过去（%s）" % [dir.cover.hands if dir else {}], _level_id() == "floor_08_maze_2"
		and dir.cover.count("thigh") == 1 and dir.cover.count("sole") == 1 and GameState.player is BluePrincess)
	await main.change_level(Floors.scene("floor_08_maze_3"))
	await _advance_until(func(): return _dir() != null and _dir().section == 3 and _dir().blue != null, 20.0)
	for i in range(1, 7):
		GameState.set_flag("f8m_mem_%d" % i)
	_finish()
	await _wait(0.3)
	var seen := []
	var on_cg := func(id: String): seen.append(id)
	CG.started.connect(on_cg)
	var on_cut := func(id: String): seen.append(id)
	Cutscene.started.connect(on_cut)
	GameState.player.global_position = _dir()._exit_at
	await _advance_until(func(): return GameState.has_flag("f8_maze_done") and not Cutscene.is_playing() and not CG.is_busy(), 60.0)
	CG.started.disconnect(on_cg)
	Cutscene.started.disconnect(on_cut)
	check("第三段走到出口：收齐 6 片回忆 → 回忆小剧场 → 出口过场（%s），标记 f8_maze_done" % [seen],
		seen.has("theater:f8_maze_memory") and seen.has("f8_maze_exit") and GameState.has_flag("f8_maze_done"))


# ------------------------------------------------------------------ 工具
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

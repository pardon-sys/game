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
	# 新来源的初次遭遇对话会暂停逐帧的逻辑：先都标成见过（_run_devices 里单独测一次）
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	await _run_sleep()
	await _run_25d()
	await _run_qte_and_cover()
	await _run_lamp_and_magic()
	await _run_light_and_rhythm()
	await _run_defeat()
	await _run_shards_and_sections()
	await _run_data()
	await _run_combo_effects()
	await _run_monsters()
	await _run_devices()
	await _run_heartbeat_and_shadow()
	await _run_skip_points()
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


# ------------------------------------------------------------------ 第三阶段：新来源 / 组合 / 怪物 / 机关
const NEW_KEYS := ["maze_hand", "glow_moth", "dream_fluff", "lamp_imp", "laugh_jar", "mirror_puddle", "shadow_vine",
	"feather_curtain", "cradle_bench", "hand_gate", "hand_shadow", "hand_rhythm"]


func _goto_maze(sec: int) -> void:
	await main.change_level(Floors.scene("floor_08_maze_%d" % sec))
	await _advance_until(func(): return _dir() != null and _dir().section == sec and _dir().blue != null and not Cutscene.is_playing(), 20.0)
	_finish()
	await _wait(0.3)
	_dir().cover.clear()
	for e in get_tree().get_nodes_in_group("enemy"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	for h in get_tree().get_nodes_in_group("maze_hand"):
		h.queue_free()
	_dir()._spawn_t = 999.0


func _fresh(blue: PlayableCharacter) -> void:
	blue.laugh.set_value(0.0)
	blue.set_invulnerable(0.0)
	blue._full_invuln = 0.0


func _hands() -> int:
	return get_tree().get_nodes_in_group("maze_hand").filter(func(h: Node): return not h.is_queued_for_deletion() and not (h as MazeHand).is_gone()).size()


func _run_data() -> void:
	print("-- 新来源 / 组合数据")
	var missing: Array = []
	for k in NEW_KEYS:
		if not TickleZones.table()["sources"].has(k) or ReactionDB.first_encounter(k).is_empty() or str(ReactionDB.source(k).get("name", "")) == "":
			missing.append(k)
	check("12 个新来源都有部位权重、蓝色公主的初次遭遇台词和名字（缺：%s）" % [missing], missing.is_empty())
	var combos: Array = ComboTracker.data()["combos"].filter(func(c: Dictionary): return c.get("category", "") == "第八层·夜迷宫")
	var named := combos.filter(func(c: Dictionary): return ReactionDB.combo(c["id"]).get("name", "") != "")
	check("「第八层·夜迷宫」11 组三来源组合，都有名字和蓝色公主的台词（%d / %d）" % [named.size(), combos.size()], combos.size() == 11 and named.size() == 11)


func _run_combo_effects() -> void:
	await _goto_maze(2)
	print("-- 组合技的关卡效果")
	var dir := _dir()
	var blue := dir.blue
	_move_out_of_light(blue)
	_fresh(blue)
	var fx := func(e: Dictionary): dir.on_combo_effect(e, blue, null)
	blue.laugh.set_value(blue.laugh.helpless_threshold + 5.0)
	await _wait(0.1)
	var r0 := dir.radius.radius()
	fx.call({"type": "laugh_radius_boost", "mult": 2.0, "duration": 8.0})
	check("laugh_radius_boost：笑声半径翻倍（%.0f → %.0f）" % [r0, dir.radius.radius()], r0 > 0.0 and dir.radius.radius() >= r0 * 1.9)
	var n0 := _hands()
	fx.call({"type": "summon_hands", "count": 3})
	check("summon_hands：她周围召出紫手（%d → %d）" % [n0, _hands()], _hands() >= n0 + 2)
	for h in get_tree().get_nodes_in_group("maze_hand"):
		(h as MazeHand).vanish()
	fx.call({"type": "cover_hands", "zone": "thigh", "count": 2})
	check("cover_hands：大腿上直接盖 2 只（不给 QTE）", dir.cover.count("thigh") == 2)
	var cl := dir.carry_light()
	cl.level = 1.0
	fx.call({"type": "light_drain", "to": 0.05})
	check("light_drain：冷光一下降到最低（%.2f）" % cl.level, cl.level <= 0.05 and cl.is_dimmed())
	fx.call({"type": "rhythm_now"})
	await _wait(0.1)
	check("rhythm_now：身上的手立刻开始蓄力", dir.cover.is_charging())
	dir.cover.clear()
	cl.level = 1.0
	# 一次真正的组合：千手之门 + 影子缠腿藤 + 紫手 →「门后千手」
	_fresh(blue)
	var tracker: ComboTracker = blue.combo
	var fired := []
	var on_c := func(id: String): fired.append(id)
	tracker.triggered.connect(on_c)
	for key in ["hand_gate", "shadow_vine", "maze_hand"]:
		var src := HandCover.Source.new()
		src.reaction_key = key
		main.level.add_child(src)
		src.global_position = blue.global_position
		blue.set_invulnerable(0.0)
		blue._full_invuln = 0.0
		blue.receive_hit(HitData.make_tickle(src, 1.0))
		await _wait(0.1)
	await _advance_until(func(): return not CG.is_busy() and not Dialogue.is_active(), 10.0)
	tracker.triggered.disconnect(on_c)
	check("三来源「门后千手」触发（%s），大腿直接盖上 2 只手（%s）" % [fired, dir.cover.hands], fired.has("mz_gate_hands") and dir.cover.count("thigh") >= 2)
	dir.cover.clear()


func _run_monsters() -> void:
	print("-- 新怪物")
	var dir := _dir()
	var blue := dir.blue
	_move_out_of_light(blue)
	_fresh(blue)
	# 梦绒球：粘在大腿上一直蹭，冰晶结界甩掉
	var fluff: DreamFluff = load("res://levels/floor_08/scenes/dream_fluff.tscn").instantiate()
	main.level.add_child(fluff)
	fluff.global_position = blue.global_position + Vector2(10, 0)
	await _wait(0.1)
	fluff.tickle(blue)
	await _wait(2.0)
	var stuck := fluff.is_stuck() and fluff.global_position.distance_to(blue.global_position) < 12.0
	var gain := blue.laugh.value
	fluff.on_ice(2.0)
	check("梦绒球：粘在她身上跟着走、一直挠（闷笑 %.1f），冰晶结界甩掉" % gain, stuck and gain > 1.0 and not fluff.is_stuck())
	fluff.queue_free()
	# 笑声收集瓶：装满就「啵」——一大圈笑声 + 叫来紫手
	var jar: LaughJar = load("res://levels/floor_08/scenes/laugh_jar.tscn").instantiate()
	main.level.add_child(jar)
	jar.global_position = blue.global_position + Vector2(20, 0)
	await _wait(0.1)
	blue.laugh.set_value(blue.laugh.helpless_threshold + 1.0)
	var n0 := _hands()
	jar.fill = 0.95
	await _advance_until(func(): return jar.fill < 0.5, 3.0)
	check("笑声收集瓶：她笑的时候装满 → 放出 %.0f 半径的笑声，叫来紫手（%d → %d）" % [dir.radius.radius(), n0, _hands()],
		dir.radius.radius() >= 200.0 and _hands() > n0)
	jar.queue_free()
	for h in get_tree().get_nodes_in_group("maze_hand"):
		(h as MazeHand).vanish()
	blue.laugh.set_value(0.0)
	# 夜光羽蛾：撒中时笑声半径亮一下
	var moth: GlowMoth = load("res://levels/floor_08/scenes/glow_moth.tscn").instantiate()
	main.level.add_child(moth)
	dir.radius._burst_left = 0.0
	dir.radius._boost_left = 0.0
	dir.radius._boost = 1.0
	blue.laugh.set_value(blue.laugh.helpless_threshold + 5.0)
	await _wait(0.1)
	var r0 := dir.radius.radius()
	moth._on_tickle_performed(blue)
	check("夜光羽蛾：鳞粉撒中让笑声半径亮一下（%.0f → %.0f），自己带光" % [r0, dir.radius.radius()],
		dir.radius.radius() > r0 and moth.get_node_or_null("Light") != null)
	moth.queue_free()
	blue.laugh.set_value(0.0)
	# 偷灯小鬼：去吹灭最近的月光灯；碰到她吹暗冷光
	var lamp: MoonLamp = get_tree().get_nodes_in_group("moon_lamp")[1]
	lamp.relight()
	var imp: LampImp = load("res://levels/floor_08/scenes/lamp_imp.tscn").instantiate()
	main.level.add_child(imp)
	imp.global_position = lamp.global_position + Vector2(0, 20)
	await _advance_until(func(): return not lamp.lit, 6.0)
	var blown := not lamp.lit
	imp._on_tickle_performed(blue)
	check("偷灯小鬼：吹灭附近的月光灯（%s），碰到她吹暗冷光（%s）" % [blown, dir.carry_light().is_dimmed()], blown and dir.carry_light().is_dimmed())
	imp.queue_free()
	lamp.relight()


func _run_devices() -> void:
	print("-- 陷阱 / 机关")
	var dir := _dir()
	var blue := dir.blue
	_fresh(blue)
	# 镜面水洼：倒影里伸出一只手，这次失败优先盖屁股
	var puddle: MirrorPuddle = null
	for n in main.level.find_children("*", "MirrorPuddle", true, false):
		puddle = n
	var n0 := _hands()
	puddle._apply_effect(blue)
	check("镜面水洼：倒影里冒出一只紫手（%d → %d），标记屁股" % [n0, _hands()], _hands() > n0 and dir.marked_zone == "butt")
	for h in get_tree().get_nodes_in_group("maze_hand"):
		(h as MazeHand).vanish()
	dir.marked_zone = ""
	# 影子缠腿藤：定身
	var vine: ShadowVine = main.level.find_children("*", "ShadowVine", true, false)[0]
	vine._t = 0.0
	vine._apply_effect(blue)
	check("影子缠腿藤：缠住定身", blue.status.is_rooted())
	blue.status.clear_root()
	# 月光镜：转到正确方向 → 光带照到光开关 → 暗门打开
	var design: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/floor_08_maze_2/design.json"))
	var dev: Dictionary = design["devices"].filter(func(d: Dictionary): return d["kind"] == "moon_mirror")[0]
	var mirror: MoonMirror = main.level.find_children("*", "MoonMirror", true, false)[0]
	for l in get_tree().get_nodes_in_group("moon_lamp"):
		(l as MoonLamp).relight()
	var closed_before: bool = get_tree().get_nodes_in_group(dev["group"]).all(func(g: Node): return not g.get("is_open"))
	while mirror.facing != int(dev["facing"]):
		mirror.on_interact(blue)
	await _wait(1.6)
	var gates: Array = get_tree().get_nodes_in_group(dev["group"]).filter(func(g: Node): return g is StaticBody2D)
	check("月光镜：一开始照不到（门关着 %s），按 E 转到正确方向 → 光带照到光开关 → 暗门打开" % closed_before,
		closed_before and mirror.powered and gates.size() == 2 and gates.all(func(g: Node): return g.get("is_open")))
	blue.global_position = (mirror.source_point() + mirror.beam_end) / 2.0 + Vector2(0, 10)
	dir.cover_zone("thigh")
	dir.cover_zone("sole")
	await _wait(0.2)
	check("站在光带里：算在光里（紫手不进来、狠挠躲得掉）", dir.light_at(blue.global_position) is Vector2)
	dir.cover.clear()
	# 初次遭遇：第一次被羽毛门帘刷到，蓝色公主的初次遭遇对话
	GameState.set_flag("met_feather_curtain", false)
	var curtain: FeatherCurtain = main.level.find_children("*", "FeatherCurtain", true, false)[0]
	_fresh(blue)
	curtain._apply_effect(blue)
	await _wait(0.2)
	check("第一次被新来源挠到：播蓝色公主的初次遭遇对话", Dialogue.is_active())
	_finish()
	# 第三段：千手之门、摇篮长椅
	await _goto_maze(3)
	dir = _dir()
	blue = dir.blue
	_fresh(blue)
	var gate: HandGate = main.level.find_children("*", "HandGate", true, false)[0]
	gate.on_interact(blue)
	var shut := not gate.opened
	for i in 3:
		dir.cover_zone("thigh")
	gate.on_interact(blue)
	check("千手之门：手不够推不开（%s），身上 3 只手以后推开（同组两扇都开）" % shut, shut and gate.opened
		and get_tree().get_nodes_in_group(gate.group_name).all(func(g: Node): return g.get("opened")))
	dir.cover.clear()
	var bench: CradleBench = main.level.find_children("*", "CradleBench", true, false)[0]
	_fresh(blue)
	blue.laugh.set_value(30.0)
	bench.sit(blue)
	await _wait(3.0)
	var rested := blue.laugh.value < 30.0 and blue.status.is_rooted()
	await _wait(CradleBench.SAFE + CradleBench.COVER)
	check("摇篮长椅：坐着闷笑慢慢降（%s），坐久了椅下伸手——屁股盖上一只手（%s）" % [rested, dir.cover.hands], rested and dir.cover.count("butt") >= 1)
	bench.stand()
	check("起来以后可以走", not blue.status.is_rooted())
	dir.cover.clear()


func _run_heartbeat_and_shadow() -> void:
	print("-- 呼吸墙 / 千手的影子")
	var dir := _dir()
	var blue := dir.blue
	var walls: TileMapLayer = main.level.get_node("Walls")
	var pair: Dictionary = dir.breathing[0]
	var wall_at := func(cells: Array) -> bool: return cells.all(func(c: Vector2i): return walls.get_cell_source_id(c) != -1)
	var floor_at := func(cells: Array) -> bool: return cells.all(func(c: Vector2i): return walls.get_cell_source_id(c) == -1)
	var start_ok: bool = floor_at.call(pair["a"]) and wall_at.call(pair["b"])
	blue.global_position = dir.blue.global_position
	dir.heartbeat()
	var flipped: bool = wall_at.call(pair["a"]) and floor_at.call(pair["b"])
	dir.heartbeat()
	var back: bool = floor_at.call(pair["a"]) and wall_at.call(pair["b"])
	check("呼吸墙：开场 a 通 b 封（%s），心跳一次翻转（%s），再跳翻回来（%s）" % [start_ok, flipped, back], start_ok and flipped and back)
	var slow := dir.beat_interval()
	for i in 10:
		dir.cover_zone("thigh")
	check("心跳间隔：40 秒起，手越多越快（%.0f → %.0f 秒，最快 15）" % [slow, dir.beat_interval()], slow == 40.0 and dir.beat_interval() == 20.0)
	dir.cover.clear()
	# 千手的影子：视野里站 1 秒 → 召出紫手；在光里看不见
	var shadow: HandShadow = main.level.find_children("*", "HandShadow", true, false)[0]
	# 找一格不在光里、上面 3 格都是地面的位置：影子从上面看下来
	var spot := Vector2i(-1, -1)
	for c in dir._floor_cells:
		if [1, 2, 3].all(func(k: int) -> bool: return GridPath.walkable(main.level, c + Vector2i(0, -k))) \
				and not (dir.light_at(GridPath.center(c)) is Vector2):
			spot = c
			break
	blue.global_position = GridPath.center(spot)
	shadow.global_position = blue.global_position + Vector2(0, -30)
	shadow.cone.facing = Vector2.DOWN
	shadow._points.clear()
	shadow._cd = 0.0
	var n0 := _hands()
	await _wait(1.5)
	check("千手的影子：看到她 1 秒 → 周围涌出紫手（%d → %d）" % [n0, _hands()], spot.x >= 0 and _hands() >= n0 + 3)
	for h in get_tree().get_nodes_in_group("maze_hand"):
		(h as MazeHand).vanish()
	var lamp: MoonLamp = get_tree().get_nodes_in_group("moon_lamp")[0]
	lamp.relight()
	blue.global_position = lamp.global_position + Vector2(0, 4)
	shadow.global_position = blue.global_position + Vector2(-40, 10)
	shadow.cone.facing = Vector2.RIGHT
	shadow._cd = 0.0
	n0 = _hands()
	await _wait(1.5)
	check("站在月光灯下：影子看不见她（%d → %d）" % [n0, _hands()], _hands() == n0)
	for h in get_tree().get_nodes_in_group("maze_hand"):
		(h as MazeHand).vanish()
	shadow.on_ice(3.0)
	check("冰晶结界冻住影子", shadow.is_frozen())


# ------------------------------------------------------------------ 测试模式跳关
func _run_skip_points() -> void:
	print("-- 第八层的跳关点")
	var points: Array = DevConfig.skip_points().filter(func(p: Dictionary): return str(p["floor"]).begins_with("floor_08"))
	check("第八层有 11 个跳关点（%d）" % points.size(), points.size() == 11)
	for point in points:
		_finish()
		await DevConfig.skip_to(point)
		await _wait(0.2)
		var p := GameState.player
		var problems: Array[String] = []
		if _level_id() != str(point["floor"]):
			problems.append("楼层 %s" % _level_id())
		var want_blue: bool = point["flags"].has("blue_is_hero") or point["flags"].has("f8_slept")
		if (p is BluePrincess) != want_blue:
			problems.append("主角不对（%s）" % p.name)
		if point.has("spawn"):
			var sp_pos := Vector2.INF
			for sp in get_tree().get_nodes_in_group("spawn_point"):
				if str(sp.get("id")) == str(point["spawn"]):
					sp_pos = (sp as Node2D).global_position
			if sp_pos == Vector2.INF or p.global_position.distance_to(sp_pos) > 4.0:
				problems.append("没放到出生点 %s" % point["spawn"])
		if point.has("cell"):
			var c: Array = point["cell"]
			if GridPath.cell(p.global_position) != Vector2i(int(c[0]), int(c[1])):
				problems.append("没放到格子 %s" % [c])
		var phase := int(point.get("vars", {}).get("f8_start_phase", 0))
		if phase > 0:
			await _advance_until(func(): return Floor8Director.instance != null and Floor8Director.instance.phase == phase, 15.0)
			var d := Floor8Director.instance
			if d == null or d.phase != phase or d.boss.health.hp > d.boss.phase_start_hp(phase):
				problems.append("Boss 阶段 %s" % (d.phase if d else -1))
		check("跳关「%s」%s" % [point["name"], "" if problems.is_empty() else "：" + "；".join(problems)], problems.is_empty())
		await _advance_until(func(): return not Cutscene.is_playing() and not CG.is_busy(), 30.0)


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

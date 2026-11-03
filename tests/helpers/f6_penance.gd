extends RefCounted
## 反省篇第一章（--penance-only）：骑士篇尾声接医务帐篷 → 吵架 → 反省牢房（六件道具的小剧场 → 墙缝里的挠脚鼠）
## → 换上鼠鼠装、钻进墙缝 → 章末画面（不脱鼠鼠装）→ 第二章·鼠洞（滴水管、三段小剧场、老鼠窝、猫咪追逐、竖井 → 章末）；
## 鼠鼠装的效果（攻击 ×0.8、乱窜暴击涨魔力疲倦、鼠味引怪）和造型（精灵图集、立绘）。
static var checks := 0


static func verify(t: Node, label: String, ok: bool) -> void:
	checks += 1
	t.check(label, ok)


static func _cell(t: Node) -> PenanceCell:
	for n in t.get_tree().root.find_children("*", "", true, false):
		if n is PenanceCell:
			return n
	return null


static func run(t: Node) -> void:
	checks = 0
	# 骑士篇尾声的章末画面 → 医务帐篷
	var ep: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cutscenes/floor_06/knight_epilogue.json"))
	var nxt := ""
	for st in ep["steps"]:
		for a in st.get("actions", []):
			if str(a.get("do", "")) == "chapter_end":
				nxt = str(a.get("next", ""))
	verify(t, "骑士篇尾声的章末画面接到医务帐篷（%s）" % nxt, nxt == "floor_06_penance_tent")
	for f in ["intro_done_penance_argue", "intro_done_penance_cell_in", PenanceCell.ALL_FLAG, PenanceCell.DONE_FLAG, "cg_seen_theater:prison_rat"]:
		GameState.set_flag(f, false)
	for id in PenanceCell.SPOTS:
		GameState.set_flag("cg_seen_theater:penance_" + id, false)
	# 原来穿着的裤子 / 鞋子：鼠鼠装脱下以后要还回来
	GameState.set_flag(Equipment.UNLOCK_FLAG)
	for id in ["equip_padded_shorts", "equip_dance_shoes"]:
		if not GameState.inventory.has(id):
			GameState.inventory.add(ItemDB.get_item(id))
		Equipment.equip("pink", id)
	await t.main.change_level(Floors.scene("floor_06_penance_tent"))
	await t._advance_until(func(): return t._level_id() == "floor_06_penance_cell" and not Cutscene.is_playing() and t.seen_cuts.has("penance_cell_in"), 120.0)
	verify(t, "进帐篷就演吵架（骑士昏迷、蓝色公主插不上嘴）→ 被关进反省牢房 → 进门独白（%s）" % t._level_id(),
		t.seen_cuts.has("penance_argue") and t.seen_cuts.has("penance_cell_in") and t._level_id() == "floor_06_penance_cell")
	var pc := _cell(t)
	verify(t, "反省牢房里摆着六件道具和调查点（%d）、墙缝还没开" % (pc.spots.size() if pc else -1),
		pc != null and pc.spots.size() == 6 and pc.actors.size() == 6 and not pc.crack_open)
	verify(t, "墙缝：六件没玩完时只有吱吱声（%s）" % Dialogue.runner.entry_of("floor_06/penance_rat"), Dialogue.runner.entry_of("floor_06/penance_rat") == "squeak")
	# 六件道具：调查 → 选「试试」→ 小剧场；玩过以后再调查只有一句
	var ids: Array = PenanceCell.SPOTS.keys()
	for i in ids.size():
		var id := str(ids[i])
		await t._talk("floor_06/penance_" + id, "", [0])
		await t._advance_until(func(): return not CG.is_busy() and not Dialogue.runner.is_running() and not Dialogue.is_active(), 150.0)
		if i == 2:
			verify(t, "玩了三件：墙缝还没开", not pc.crack_open and not GameState.has_flag(PenanceCell.ALL_FLAG))
	var seen := ids.filter(func(id): return PenanceCell.done(str(id)))
	verify(t, "六件道具的小剧场都演过（%s）" % [seen], seen.size() == 6)
	verify(t, "玩过的道具再调查：只有一句（%s）" % Dialogue.runner.entry_of("floor_06/penance_bed"), Dialogue.runner.entry_of("floor_06/penance_bed") == "again")
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	verify(t, "六件都玩过：墙缝里探出挠脚鼠（%s，画的是第 %d 帧）" % [pc.crack_open, pc.crack.sprite.frame], pc.crack_open and GameState.has_flag(PenanceCell.ALL_FLAG) and pc.crack.sprite.frame == 1)
	verify(t, "挠脚鼠：没在地牢放过它 → 记仇的开场（%s）" % Dialogue.runner.entry_of("floor_06/penance_rat"), Dialogue.runner.entry_of("floor_06/penance_rat") == "stranger")
	GameState.set_flag("cg_seen_theater:prison_rat")
	verify(t, "挠脚鼠：在地牢放过它 → 认得她的开场（%s）" % Dialogue.runner.entry_of("floor_06/penance_rat"), Dialogue.runner.entry_of("floor_06/penance_rat") == "met")
	# 鼠鼠装本身
	PenanceCell.wear_mouse()
	var p := GameState.player as PlayableCharacter
	verify(t, "换上鼠鼠短裤 + 鼠爪鞋（诅咒，脱不下）、攻击 ×%.2f" % Equipment.stat_mul("pink", "attack"),
		PenanceCell.wearing_mouse() and not Equipment.unequip("pink", "thigh") and absf(Equipment.stat_mul("pink", "attack") - 0.8) < 0.01)
	var fx := EquipFx.of(p)
	var f0: float = p.fatigue.value if p.fatigue else 0.0
	var plain := HitData.make_tickle(null, EquipFx.entry("pink", PenanceCell.SHORTS).get("amount", 1.2) * EquipFx.FLARE_MULT)
	var plain_f: float = p.fatigue.amount_for(plain) if p.fatigue else 0.0
	fx.flare(PenanceCell.SHORTS, "thigh")
	var gain: float = (p.fatigue.value - f0) if p.fatigue else 0.0
	verify(t, "挠脚鼠乱窜 = 暴击：魔力疲倦大涨（+%.1f，普通的一下 +%.1f）" % [gain, plain_f], gain > plain_f * 3.0)
	var iv: Array = EquipFx.entry("pink", PenanceCell.SHOES).get("interval", [])
	verify(t, "乱窜间隔 8~15 秒（%s）" % [iv], iv == [8.0, 15.0])
	var mon: Monster = load("res://scenes/actors/monsters/foot_rat.tscn").instantiate()
	p.get_parent().add_child(mon)
	mon.global_position = p.global_position + Vector2(50, 0)
	var far: Monster = load("res://scenes/actors/monsters/foot_rat.tscn").instantiate()
	p.get_parent().add_child(far)
	far.global_position = p.global_position + Vector2(300, 0)
	await t.get_tree().process_frame
	var n := fx.scent_now()
	verify(t, "鼠味把附近一小圈的怪引过来（%d 只，远处的不来）" % n, n == 1 and mon.target == p and far.target != p)
	mon.queue_free()
	far.queue_free()
	PenanceCell.take_off_mouse()
	verify(t, "脱下鼠鼠装：原来的短裤和鞋穿回去（%s）" % [Equipment.worn("pink")],
		not PenanceCell.wearing_mouse() and Equipment.worn("pink").get("butt", "") == "equip_padded_shorts" and Equipment.worn("pink").get("sole", "") == "equip_dance_shoes")
	# 答应挠脚鼠 → 过场钻墙缝 → 章末画面；第二章没做之前，鼠鼠装先脱下还原
	var wore := {"v": false}
	var watch := func(id: String):
		if id == "penance_crawl":
			wore["v"] = PenanceCell.wearing_mouse()
	Cutscene.started.connect(watch)
	await t._talk("floor_06/penance_rat", "", [0])
	await t._advance_until(func(): return Cutscene.chapter_screen.visible and not Cutscene.is_playing(), 60.0)
	Cutscene.started.disconnect(watch)
	await t.get_tree().process_frame
	verify(t, "答应挠脚鼠：换上鼠鼠装（%s）→ 钻墙缝 → 章末「第一章　反省牢房　完」（%s → %s）" % [wore["v"], Cutscene.chapter_title.text, Cutscene.chapter_next],
		wore["v"] and t.seen_cuts.has("penance_crawl") and Cutscene.chapter_title.text.contains("反省牢房") and Cutscene.chapter_next == "floor_06_rat_tunnel")
	verify(t, "章末也不脱鼠鼠装（%s）" % [Equipment.worn("pink")], GameState.has_flag(PenanceCell.DONE_FLAG) and PenanceCell.wearing_mouse())
	# 穿着鼠鼠装：精灵图集 / 立绘都换成鼠鼠装那一套
	var anim := (GameState.player as PlayableCharacter).animator
	await t.get_tree().process_frame
	var tex_path: String = anim.sprite.texture.resource_path if anim and anim.sprite.texture else ""
	verify(t, "穿着鼠鼠装：精灵图换成鼠鼠装那一套（%s）" % tex_path, anim != null and anim.outfit == "mouse" and tex_path.contains("_mouse"))
	var por: AtlasTexture = Dialogue.portrait_for("normal")
	verify(t, "穿着鼠鼠装：立绘换成鼠鼠装那一套（%s）" % (por.atlas.resource_path if por else ""), por != null and por.atlas.resource_path.contains("portraits_mouse"))
	# ---- 第二章：鼠洞
	GameState.set_flag("intro_done_tunnel_in", false)
	for f in ["cg_seen_theater:tunnel_thigh", "cg_seen_theater:tunnel_sole", "cg_seen_theater:tunnel_shaft", "cg_seen_theater:tunnel_cat_first",
			"cg_seen_theater:tunnel_cat", "cg_seen_theater:tunnel_nest", RatTunnel.DONE_FLAG, "tunnel_cat_safe"]:
		GameState.set_flag(f, false)
	Cutscene.continue_chapter()
	await t._advance_until(func(): return t._level_id() == "floor_06_rat_tunnel" and not Cutscene.is_playing() and t.seen_cuts.has("tunnel_in"), 60.0)
	var rt: RatTunnel = null
	for nd in t.get_tree().root.find_children("*", "", true, false):
		if nd is RatTunnel:
			rt = nd
	verify(t, "章末按 E → 第二章·鼠洞（等距）、演开场（挠脚鼠说三件事）、鼠鼠装还穿着", rt != null and t.seen_cuts.has("tunnel_in") and PenanceCell.wearing_mouse())
	var pp := GameState.player as PlayableCharacter
	# 滴水管：滴到她 → 鼠鼠装发作（暴击，魔力疲倦涨）
	pp.global_position = rt.drips[0].global_position
	var t_f0: float = pp.fatigue.value
	var hit := rt.drip_hit(0)
	verify(t, "滴水管滴到她：挠脚鼠被惊动乱窜（暴击，魔力疲倦 %.0f → %.0f）" % [t_f0, pp.fatigue.value], hit and pp.fatigue.value > t_f0 + 10.0)
	pp.global_position = rt.drips[0].global_position + Vector2(40, 0)
	verify(t, "离水滴远的时候不会被滴到", not rt.drip_hit(0))
	# 三段小剧场：走到就演（大腿根、脚心）
	for k in ["thigh", "sole"]:
		pp.global_position = Cutscene.cell_to_world(QuestMaps.cell(RatTunnel.MAP, k))
		await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:" + str(RatTunnel.SCENES[k])) and not CG.is_busy() and not Dialogue.is_active(), 150.0)
	verify(t, "走到低矮的缝 / 窄缝：演大腿根、脚心两段小剧场", GameState.has_flag("cg_seen_theater:tunnel_thigh") and GameState.has_flag("cg_seen_theater:tunnel_sole"))
	# 老鼠窝 / 刻字（按 E）
	await t._talk("floor_06/tunnel_nest", "", [0])
	await t._advance_until(func(): return not CG.is_busy() and not Dialogue.runner.is_running() and not Dialogue.is_active(), 120.0)
	verify(t, "老鼠窝：小剧场（小老鼠们认她当老大）", GameState.has_flag("cg_seen_theater:tunnel_nest"))
	# 猫咪追逐：走到起点 → 猫从身后追出来；追上 → 小剧场 → 回检查点
	var cp := Cutscene.cell_to_world(QuestMaps.cells(RatTunnel.MAP, "checkpoints")[1])
	pp.global_position = cp
	await t.get_tree().process_frame
	pp.global_position = Cutscene.cell_to_world(QuestMaps.cell(RatTunnel.MAP, "cat_start"))
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	verify(t, "走到追逐起点：橘猫从身后追出来（%s）" % rt.chasing, rt.chasing and rt.cat.visible)
	pp.global_position += Vector2(200, 0)
	rt.catch_now()
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:tunnel_cat_first") and not CG.is_busy() and not Dialogue.is_active(), 120.0)
	await t.get_tree().process_frame
	verify(t, "被猫追上：小剧场（第一次长一点）→ 回到检查点（离检查点 %.0f）" % pp.global_position.distance_to(cp),
		GameState.has_flag("cg_seen_theater:tunnel_cat_first") and pp.global_position.distance_to(cp) < 2.0 and not rt.chasing)
	pp.global_position = Cutscene.cell_to_world(QuestMaps.cell(RatTunnel.MAP, "cat_start"))
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	pp.global_position = Cutscene.cell_to_world(QuestMaps.cell(RatTunnel.MAP, "cat_end"))
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	verify(t, "跑进小洞：猫进不来，安全了", rt.safe and not rt.chasing)
	# 竖井：章末大段（CG）→ 章末画面
	pp.global_position = Cutscene.cell_to_world(QuestMaps.cell(RatTunnel.MAP, "shaft"))
	await t._advance_until(func(): return Cutscene.chapter_screen.visible and not Cutscene.is_playing(), 180.0)
	verify(t, "竖井：上下窜的章末大段 → 「第二章　鼠洞　完」（%s）、鼠鼠装还穿着" % Cutscene.chapter_title.text,
		GameState.has_flag("cg_seen_theater:tunnel_shaft") and t.seen_cuts.has("tunnel_out") and Cutscene.chapter_title.text.contains("鼠洞") and PenanceCell.wearing_mouse())
	verify(t, "第二章章末接第三章·水道的出口（%s）" % Cutscene.chapter_next, Cutscene.chapter_next == "floor_06_waterway_exit")
	# ---- 第三章：蓝色公主视角 → 汇合（互相调侃裤子）→ 废弃水道
	for f in [MeetExit.DONE_FLAG, "cg_seen_theater:meet_pants", "intro_done_waterway_in", SluiceKeeper.DONE_FLAG, "cg_seen_keeper_intro",
			"cg_seen_theater:waterway_down_first", "cg_seen_theater:keeper_fail", "cg_seen_theater:keeper_win"]:
		GameState.set_flag(f, false)
	GameState.vars.erase(WaterwayDirector.WATER_VAR)
	Cutscene.continue_chapter()
	await t._advance_until(func(): return t._level_id() == "floor_06_waterway" and not Cutscene.is_playing() and t.seen_cuts.has("waterway_in"), 300.0)
	verify(t, "水道出口：蓝色公主视角（背景大图）→ 汇合 → 互相调侃裤子（千手裤挠蓝色、挠脚鼠不甘示弱挠粉色）→ 一起走进废弃水道（%s）" % t._level_id(),
		t.seen_cuts.has("blue_pov") and t.seen_cuts.has("meet_in") and GameState.has_flag("cg_seen_theater:meet_pants") and t.seen_cuts.has("meet_out")
		and t._level_id() == "floor_06_waterway" and PenanceCell.wearing_mouse())
	var wd: WaterwayDirector = null
	for nd in t.get_tree().root.find_children("*", "", true, false):
		if nd is WaterwayDirector:
			wd = nd
	await t.get_tree().process_frame
	verify(t, "废弃水道：两人同行（Duo，蓝色公主是 AI 搭档）", wd != null and Duo.active and is_instance_valid(wd.blue) and wd.blue != GameState.player)
	var pk := wd.pink
	# 水位：开始高水位（浮木能走、格栅淹着）；两个人一起站轮盘转得快 → 换水位
	var log_c: Vector2i = QuestMaps.cells(WaterwayDirector.MAP, "logs")[0]
	var grate_c: Vector2i = QuestMaps.cells(WaterwayDirector.MAP, "grate")[0]
	verify(t, "开始高水位：浮木浮着能走，水下格栅淹着过不去", wd.high and not wd.blocked(log_c) and wd.blocked(grate_c))
	var wheel_at: Vector2 = wd.wheels[0]["pos"]
	pk.global_position = wheel_at
	wd.blue.global_position = wheel_at + Vector2(4, 0)
	for i in 30:
		wd._tick_wheels(0.1, wd.members())
	verify(t, "两个人一起站轮盘：%.1f 秒转满 → 低水位（浮木沉下去、格栅露出来）" % WaterwayDirector.WHEEL_TWO, not wd.high and wd.blocked(log_c) and not wd.blocked(grate_c))
	pk.global_position = wheel_at + Vector2(60, 0)
	wd.blue.global_position = wheel_at + Vector2(70, 0)
	wd._tick_wheels(0.1, wd.members())
	pk.global_position = wheel_at
	for i in 30:
		wd._tick_wheels(0.1, [pk])
	verify(t, "一个人站轮盘 3 秒还没转满（%.0f%%）" % (float(wd.wheels[0]["progress"]) * 100.0), not wd.high)
	for i in 15:
		wd._tick_wheels(0.1, [pk])
	verify(t, "一个人转 %.0f 秒也能转满 → 又是高水位" % WaterwayDirector.WHEEL_ONE, wd.high)
	# 泡泡：裹住粉色公主 → 定身、闷笑涨；AI 蓝色公主走过来戳破
	pk.global_position = Cutscene.cell_to_world(QuestMaps.cells(WaterwayDirector.MAP, "checkpoints")[0])
	wd.blue.global_position = pk.global_position + Vector2(60, 0)
	pk.laugh.set_value(0.0)
	wd.trap(pk)
	var l0 := pk.laugh.value
	for i in 4:
		wd._tick_trap(pk, 0.5)
	verify(t, "被泡泡裹住：定身、闷笑一直涨（%.1f → %.1f）" % [l0, pk.laugh.value], wd.trapped.has(pk) and pk.status.is_rooted() and pk.laugh.value > l0)
	verify(t, "AI 搭档的目标：去戳破泡泡", (WaterwayDirector.WaterwayHooks.new(wd).objective_for(wd.blue) as Vector2).distance_to(pk.global_position) < 1.0)
	wd.blue.global_position = pk.global_position + Vector2(8, 0)
	wd._tick_trap(pk, 0.1)
	verify(t, "搭档走到旁边：泡泡戳破、能动了", not wd.trapped.has(pk) and not pk.status.is_rooted())
	# 浅水小鱼群：站着越聚越多；冲刺甩掉
	var sh: Vector2i = QuestMaps.cells(WaterwayDirector.MAP, "shallow")[10]
	pk.global_position = WaterwayDirector.cell_pos(sh)
	pk.velocity = Vector2.ZERO
	for i in 20:
		wd._tick_fish(pk, 0.1)
	var n_fish := float(wd.fish.get(pk, 0.0))
	verify(t, "站在浅水里：小鱼群越聚越多（%.1f 条）" % n_fish, n_fish >= 3.0)
	# 黑泥：抹上 → 变慢、闷笑涨；踩清水池洗掉；蓝色公主在身边冰掉
	wd.mud_on(pk)
	verify(t, "被黑泥小人抹上泥：变慢", wd.mud.has(pk))
	pk.global_position = WaterwayDirector.cell_pos(QuestMaps.cells(WaterwayDirector.MAP, "fountain")[0])
	wd.blue.global_position = pk.global_position + Vector2(80, 0)
	wd._tick_mud(pk, 0.1)
	verify(t, "踩进清水池：泥洗掉了", not wd.mud.has(pk))
	pk.global_position = WaterwayDirector.cell_pos(sh)
	wd.mud_on(pk)
	wd.blue.global_position = pk.global_position + Vector2(8, 0)
	wd._tick_mud(pk, 0.1)
	verify(t, "蓝色公主（AI）走到身边：用冰把泥冻碎", not wd.mud.has(pk))
	# 两个都被裹住 → 短小剧场 → 回检查点
	wd.trap(wd.blue)
	wd.trap(pk)
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:waterway_down_first") and not CG.is_busy() and not Dialogue.is_active() and not wd._defeat_busy, 120.0)
	verify(t, "两个都被泡泡裹住：短小剧场（第一次长一点）→ 回检查点、都放出来", GameState.has_flag("cg_seen_theater:waterway_down_first")
		and wd.trapped.is_empty() and pk.global_position.distance_to(wd.checkpoint) < 2.0)
	# 水闸守门人
	pk.global_position = Cutscene.cell_to_world(QuestMaps.cell(WaterwayDirector.MAP, "arena"))
	await t._advance_until(func(): return is_instance_valid(wd.keeper) and wd.keeper._started and not Cutscene.is_playing(), 60.0)
	var kp := wd.keeper as SluiceKeeper
	verify(t, "走进场地：水闸守门人登场（开场过场、三个阀门）", kp != null and t.seen_cuts.has("keeper_intro") and kp.valves.size() == 3)
	kp.attack("sweep")
	verify(t, "刷子臂横扫：先亮预警带（AI 会躲：danger 组）", kp._sweeps.size() == 1 and (kp._sweeps[0] as Node).is_in_group("danger"))
	var sw_y: float = (kp._sweeps[0] as SluiceKeeper.Sweep).y
	pk.global_position.y = sw_y
	pk.laugh.set_value(0.0)
	kp._do_sweep(kp._sweeps[0], [pk])
	verify(t, "扫到没冲刺的人：被刷脚底（闷笑 %.0f）" % pk.laugh.value, pk.laugh.value > 0.0)
	kp.close_valve(0)
	verify(t, "关掉一个阀门：它放水淹场（%.1f 秒）" % kp.flooding, kp.valves_closed == 1 and kp.flooding > 0.0)
	verify(t, "淹场时 AI 搭档跑上石堆", (kp.objective_for(wd.blue) as Vector2) in QuestMaps.cells(WaterwayDirector.MAP, "rocks").map(func(c): return Cutscene.cell_to_world(c)))
	# 输了：战败小剧场（四幕 + CG）→ 场地复位
	wd.on_defeat("downed")
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:keeper_fail") and not CG.is_busy() and not Dialogue.is_active() and not wd._defeat_busy, 180.0)
	verify(t, "守门人战输了：战败小剧场 keeper_fail → 阀门复位、回到场地入口", GameState.has_flag("cg_seen_theater:keeper_fail") and kp.valves_closed == 0)
	# 赢了：三个阀门 → 被困住的小剧场 → 章末
	for i in 3:
		kp.close_valve(i)
	await t._advance_until(func(): return Cutscene.chapter_screen.visible and Cutscene.chapter_title.text.contains("废弃水道") and not Cutscene.is_playing(), 180.0)
	verify(t, "三个阀门都关上：被困住、踩着肩膀爬上去 → 旧王宫的走廊 → 「第三章　废弃水道　完」（%s）、鼠鼠装还穿着" % Cutscene.chapter_title.text,
		GameState.has_flag("cg_seen_theater:keeper_win") and GameState.has_flag(SluiceKeeper.DONE_FLAG) and Cutscene.chapter_title.text.contains("废弃水道") and PenanceCell.wearing_mouse())
	Cutscene.chapter_screen.hide()
	Cutscene.chapter_next = ""
	PenanceCell.take_off_mouse()

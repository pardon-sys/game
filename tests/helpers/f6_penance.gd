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
	# 道具提示：流程测试里先当作都提示过（免得中途弹出来打断）；_round4 里单独测
	for k in PalaceRoom.ITEM_HINTS:
		GameState.set_flag(PalaceRoom.item_hint_flag(k))
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
			"cg_seen_theater:tunnel_cat", "cg_seen_theater:tunnel_nest", RatTunnel.DONE_FLAG, "tunnel_cat_safe", RatTunnel.REVENGE_FLAG,
			"cg_seen_theater:tunnel_revenge", RatKing.FLAG, PalaceRoom.badge_flag("rat_king"), "cg_seen_theater:tunnel_rat_king_fail"]:
		GameState.set_flag(f, false)
	for i in 4:
		GameState.flags.erase("tunnel_trap_%d" % i)
	Cutscene.continue_chapter()
	await t._advance_until(func(): return t._level_id() == "floor_06_rat_tunnel" and not Cutscene.is_playing() and t.seen_cuts.has("tunnel_in"), 60.0)
	var rt: RatTunnel = null
	for nd in t.get_tree().root.find_children("*", "", true, false):
		if nd is RatTunnel:
			rt = nd
	verify(t, "章末按 E → 第二章·鼠洞（等距）、演开场（挠脚鼠说三件事）、鼠鼠装还穿着", rt != null and t.seen_cuts.has("tunnel_in") and PenanceCell.wearing_mouse())
	await _rat_king(t, rt)
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
	verify(t, "第三章章末接旧王宫·旧浴场（%s）" % Cutscene.chapter_next, Cutscene.chapter_next == "floor_06_palace_bath")
	# ---- 第四章（上）：旧浴场
	for f in ["intro_done_palace_bath_in", PalaceBath.KEY_FLAG, "cg_seen_theater:bath_pool", "cg_seen_theater:bath_friendship",
			"intro_done_palace_servants_in", PalaceServants.KEY_FLAG, "cg_seen_theater:servants_hide", "cg_seen_theater:servants_caught_first",
			"intro_done_palace_kitchen_in", "cg_seen_theater:kitchen_promoter", "cg_seen_theater:kitchen_farewell", PalaceKitchen.FAREWELL_FLAG,
			PalaceKitchen.PAID_FLAG, PalaceLibrary.CIPHER_FLAG, PalaceLibrary.STUDY_FLAG, "palace_frag_1", "palace_frag_2", "palace_frag_3",
			"cg_seen_theater:library_bookmonster", "cg_seen_theater:wardrobe_measure", "cg_seen_theater:wardrobe_tryon", "cg_seen_theater:wardrobe_trap_out",
			"cg_seen_theater:wardrobe_try_1", "cg_seen_theater:wardrobe_socks", PalaceWardrobe.SHAWL_FLAG, PalaceWardrobe.TRAP_FLAG,
			PalaceTraining.DUMMY_FLAG, PalaceTraining.CLEAR_FLAG, "cg_seen_theater:training_stocks", "cg_seen_theater:training_lose",
			"intro_done_palace_library_in", "intro_done_palace_wardrobe_in", "intro_done_palace_training_in",
			"intro_done_palace_ante_in", "intro_done_palace_clock_in", "intro_done_palace_throne_in", PalaceClock.LADDER_FLAG, PalaceClock.KEEPER_FLAG,
			PalaceClock.BELLS_FLAG, "palace_tchest_2", PalaceTunnels.TOLL_FLAG, "palace_secret_library", "palace_web_0", "palace_web_1", "palace_web_2",
			"palace_web_3", "palace_tunnel_chest_1", "palace_tunnel_chest_2", "palace_tunnel_chest_3", "palace_tunnel_chest_4", "palace_lullaby_heard",
			"cg_seen_theater:clock_gear_ride", "cg_seen_theater:clock_caught", "cg_seen_theater:tunnel_toll", "cg_seen_theater:tunnel_quilt",
			"cg_seen_theater:tunnel_cradle", "cg_seen_theater:throne_fail", "cg_seen_theater:throne_fail_paint", "cg_seen_theater:throne_painting_trapped", PalaceThrone.BOSS_FLAG]:
		GameState.set_flag(f, false)
	Cutscene.continue_chapter()
	await t._advance_until(func(): return t._level_id() == "floor_06_palace_bath" and not Cutscene.is_playing() and t.seen_cuts.has("palace_bath_in"), 60.0)
	var pb := _room(t, "PalaceBath") as PalaceBath
	await t.get_tree().process_frame
	verify(t, "旧王宫·旧浴场：开场、两人同行、鼠鼠装还穿着", pb != null and Duo.active and PenanceCell.wearing_mouse())
	var bp := GameState.player as PlayableCharacter
	bp.global_position = Cutscene.cell_to_world(pb.cells("steam")[5])
	pb._process(0.1)
	verify(t, "走进蒸汽：四周起雾", pb.fog_on)
	# 肥皂泡地板：往西滑 → 掉进泡泡浴池 → 小剧场
	var soap: Array[Vector2i] = pb.cells("soap")
	var west := soap[0]
	for c in soap:
		if c.x < west.x or (c.x == west.x and c.y == 18):
			west = c
	bp.global_position = Cutscene.cell_to_world(Vector2i(west.x + 3, 18))
	bp.velocity = Vector2(-60, 0)
	pb._tick_soap(bp, 0.05)
	verify(t, "踩上肥皂泡地板：顺着进来的方向滑（%s）" % [pb.slide_dir.get(bp, Vector2.ZERO)], pb.slide_dir.get(bp, Vector2.ZERO) == Vector2.LEFT)
	for i in 60:
		if CG.is_busy():
			break
		pb._tick_soap(bp, 0.05)
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:bath_pool") and not CG.is_busy() and not Dialogue.is_active(), 120.0)
	verify(t, "往西滑出去：掉进泡泡浴池（小剧场）", GameState.has_flag("cg_seen_theater:bath_pool"))
	# 雕像「木头人」：没人看着就挪过来，有人面向它就不动，碰到 = 抓住刷脚底（留在原地）
	var cs: PalaceBath.Statue = null
	for st in pb.statues:
		if not (st as PalaceBath.Statue).key:
			cs = st
	var mate_b := Duo.partner_of(bp)
	mate_b.global_position = Vector2(-9999, -9999)
	bp.global_position = cs.home + Vector2(60, 0)
	bp.facing = Vector2.RIGHT
	var p0 := cs.position
	for i in 10:
		cs.step(0.1)
	verify(t, "背对雕像：它慢慢挪过来（%.0f px）" % cs.position.distance_to(p0), cs.position.distance_to(p0) > 5.0)
	bp.facing = (cs.position - bp.global_position).normalized()
	var p1 := cs.position
	for i in 10:
		cs.step(0.1)
	verify(t, "面向雕像：一动不动", cs.position.distance_to(p1) < 0.5)
	bp.facing = Vector2.RIGHT
	bp.global_position = cs.position + Vector2(6, 0)
	cs.step(0.05)
	verify(t, "雕像碰到人：抓住定身、刷脚底，雕像留在原地（不回原位）", bp.status.is_rooted() and cs.position.distance_to(cs.home) > 5.0)
	bp.status.clear_root()
	# 雕像钥匙 / 湿毛巾怪
	var ks: PalaceBath.Statue = null
	for st in pb.statues:
		if (st as PalaceBath.Statue).key:
			ks = st
	bp.global_position = ks.position + Vector2(0, 8)
	bp._set_state(PlayableCharacter.State.ATTACK)
	ks.step(0.05)
	verify(t, "攻击那尊雕像：碎了，掉出钥匙（东门能开了）", GameState.has_flag(PalaceBath.KEY_FLAG) and ks.broken)
	bp._set_state(PlayableCharacter.State.IDLE)
	var tw := pb.towels[0] as PalaceBath.Towel
	bp.global_position = tw.position + Vector2(6, 0)
	tw._cool = 0.0
	tw.step(0.05)
	verify(t, "湿毛巾怪碰到人：缠住腿（定身）", bp.status.is_rooted())
	bp.status.clear_root()
	# 温泉：两个人一起泡（CG）
	bp.global_position = Cutscene.cell_to_world(pb.cells("bath")[0])
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:bath_friendship") and not CG.is_busy() and not Dialogue.is_active(), 180.0)
	verify(t, "走到温泉：两个人一起泡温泉的小剧场（CG、友情、挠脚鼠来捣乱）", GameState.has_flag("cg_seen_theater:bath_friendship"))
	# ---- 仆人回廊（潜入）
	GameState.pending_spawn = "from_bath"
	await t.main.change_level(Floors.scene("floor_06_palace_servants"))
	await t._advance_until(func(): return t._level_id() == "floor_06_palace_servants" and not Cutscene.is_playing() and t.seen_cuts.has("palace_servants_in"), 60.0)
	var ps := _room(t, "PalaceServants") as PalaceServants
	await t.get_tree().process_frame
	var sd := StealthDirector.current
	var maids := t.get_tree().get_nodes_in_group("patrol_guard").size()
	verify(t, "仆人回廊：潜入（人偶女仆 %d 个，被发现交给 palace）" % maids, ps != null and sd != null and sd.on_caught == "palace" and maids >= 5)
	var sp := GameState.player as PlayableCharacter
	# 尘土堆：打喷嚏
	sp.global_position = Cutscene.cell_to_world(ps.cells("dust")[0])
	sp.velocity = Vector2(40, 0)
	ps._process(0.1)
	verify(t, "走过尘土堆：打喷嚏（声音会引来人偶）", not ps.dust_t.is_empty() and ps.dust_t.values().any(func(v): return float(v) > 0.0))
	# 躲藏点：千手裤发作，粉色公主去引开（CG）
	var dummy := Node2D.new()
	t.get_tree().current_scene.add_child(dummy)
	dummy.global_position = Cutscene.cell_to_world(ps.cells("hide_event")[0])
	sd.hidden_in = dummy
	ps._process(0.1)
	sd.hidden_in = null
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:servants_hide") and not CG.is_busy() and not Dialogue.is_active(), 180.0)
	dummy.queue_free()
	verify(t, "躲进那个帘子后面：千手裤发作、粉色公主自告奋勇去引开女仆（CG 剧情）", GameState.has_flag("cg_seen_theater:servants_hide"))
	# 被发现 → 小剧场 → 回入口
	ps.caught()
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:servants_caught_first") and not CG.is_busy() and not Dialogue.is_active() and not ps._defeat_busy, 120.0)
	verify(t, "被人偶女仆发现：按在地上用掸子「打扫」的小剧场 → 回入口", GameState.has_flag("cg_seen_theater:servants_caught_first")
		and sp.global_position.distance_to(Cutscene.cell_to_world(ps.cells("start")[0])) < 2.0)
	# 唤人铃 → 拿钥匙
	var lured := ps.ring_bell()
	ps.take_key()
	verify(t, "拉唤人铃：女仆长过去查看（%d 个）→ 拿到钥匙" % lured, lured >= 1 and GameState.has_flag(PalaceServants.KEY_FLAG))
	# ---- 厨房
	GameState.pending_spawn = "from_servants"
	await t.main.change_level(Floors.scene("floor_06_palace_kitchen"))
	await t._advance_until(func(): return t._level_id() == "floor_06_palace_kitchen" and not Cutscene.is_playing() and t.seen_cuts.has("palace_kitchen_in"), 60.0)
	var kr := _room(t, "PalaceKitchen") as PalaceKitchen
	await t.get_tree().process_frame
	var kp2 := GameState.player as PlayableCharacter
	kp2.global_position = Cutscene.cell_to_world(kr.cells("cream")[0])
	kr._process(0.1)
	verify(t, "踩到奶油：脚底变甜（老鼠会追）", kr.sweet.has(kp2))
	kp2.global_position = Cutscene.cell_to_world(kr.cells("sink")[0])
	kr._process(0.1)
	verify(t, "去水槽：洗掉了", not kr.sweet.has(kp2))
	var ice: Vector2i = kr.cells("ice")[3]
	kp2.global_position = Cutscene.cell_to_world(ice)
	var x0 := kp2.global_position.x
	kr._process(0.2)
	verify(t, "冰窖滑道：站上去往东滑（%.0f → %.0f）" % [x0, kp2.global_position.x], kp2.global_position.x > x0 + 10.0)
	var mints0 := GameState.inventory.count("mint")
	await t._talk("floor_06/kitchen_booth", "", [0])
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:kitchen_promoter") and GameState.has_flag(PalaceKitchen.PAID_FLAG) and not CG.is_busy() and not Dialogue.is_active(), 150.0)
	verify(t, "当试吃推销员（身上放食物让动物吃）→ 拿到薄荷糖 ×%d" % (GameState.inventory.count("mint") - mints0), GameState.inventory.count("mint") - mints0 == PalaceKitchen.MINTS)
	# 大奶酪：挠脚鼠告别，脱下鼠鼠装
	kp2.global_position = Cutscene.cell_to_world(kr.cells("cheese")[0])
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:kitchen_farewell") and not CG.is_busy() and not Dialogue.is_active(), 180.0)
	kr._process(0.1)
	verify(t, "储藏间的大奶酪：挠脚鼠告别 → 脱下鼠鼠装、换回原来的装备", PalaceKitchen.farewell_done() and not PenanceCell.wearing_mouse())
	kp2.global_position = Cutscene.cell_to_world(kr.cells("north")[0])
	await t._advance_until(func(): return t._level_id() == "floor_06_palace_library" and not Cutscene.is_playing() and t.seen_cuts.has("palace_library_in"), 60.0)
	verify(t, "北门：没有「待续」章末画面，直接走进图书馆（%s）" % t._level_id(), t._level_id() == "floor_06_palace_library" and not Cutscene.chapter_screen.visible)
	await _palace_b(t)


## 第四章（中）：图书馆 → 衣帽间 → 骑士训练场
static func _palace_b(t: Node) -> void:
	GameState.vars.erase("palace_frags")
	GameState.passives.erase("knight_endurance")
	var lr := _room(t, "PalaceLibrary") as PalaceLibrary
	await t.get_tree().process_frame
	verify(t, "图书馆：两人同行", lr != null and Duo.active)
	if lr == null:
		return
	var lp := GameState.player as PlayableCharacter
	var mate := Duo.partner_of(lp)
	# 书架里的手
	lp.global_position = Cutscene.cell_to_world(lr.cells("shelf_hands")[0])
	lr._tick_hands(lp, 0.05)
	verify(t, "从书架旁边走过：手伸出来抓住脚踝（定身）", lp.status.is_rooted())
	lp.status.clear_root()
	# 书山：埋住 → 搭档挖出来
	mate.global_position = Vector2(-9999, -9999)
	lp.global_position = Cutscene.cell_to_world(lr.cells("book_piles")[0])
	lr._tick_piles(lp, 0.05)
	verify(t, "踩到书山：塌下来埋住半身", lr.buried.has(lp))
	mate.global_position = lp.global_position + Vector2(8, 0)
	for i in 40:
		lr._tick_piles(lp, 0.05)
	verify(t, "搭档走过来：%.1f 秒挖出来" % PalaceLibrary.DIG_TIME, not lr.buried.has(lp))
	verify(t, "AI 搭档的目标：被埋住的那个人", (lr.ai_hooks() as BattleAIHooks).objective_for(mate) == null)
	lr.buried[lp] = 0.0
	verify(t, "（被埋住时 AI 搭档会跑过来挖）", (lr.ai_hooks() as BattleAIHooks).objective_for(mate) == lp.global_position)
	lr.dig(lp)
	# 书虫
	var w := lr.worms[0] as PalaceLibrary.Worm
	lp.global_position = w.position + Vector2(4, 0)
	w._cool = 0.0
	w.step(0.05)
	verify(t, "书虫追上来：钻进袜子里（%s）" % (w._in != null), w._in == lp)
	# 书（打码）、残页
	var d6: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogues/floor_06/library_book_6.json"))
	var txt0 := JSON.stringify(d6["nodes"]["frag0"])
	verify(t, "书房管理记录：残页 0 张时三行都打了码（□）", txt0.count("□") >= 20 and JSON.stringify(d6["nodes"]["frag3"]).count("□") == 0)
	await t._talk("floor_06/library_fragment", "")
	verify(t, "书山下的残页：残页 +1（%s）" % GameState.vars.get("palace_frags"), int(GameState.vars.get("palace_frags", 0)) == 1 and GameState.has_flag("palace_frag_1"))
	# 密码门：错一次、对一次
	verify(t, "密码门没开：私人书房整间黑着（%d 格遮罩）" % lr.shades.size(), lr.shades.size() >= 30)
	var lvn := t.get_tree().get_first_node_in_group("main").get("level") as Node
	var dc := lr.cells("cipher_door")[0]
	verify(t, "书房只有密码门这一格能进：两边是墙、门口被门挡着", lvn != null and not GridPath.walkable(lvn, dc + Vector2i(-1, 0))
		and not GridPath.walkable(lvn, dc + Vector2i(1, 0)) and is_instance_valid(lr._door))
	await t._talk("floor_06/library_door", "", ["2537"])
	verify(t, "密码门：输错数字，门不开", not GameState.has_flag(PalaceLibrary.CIPHER_FLAG))
	await t._talk("floor_06/library_door", "", ["25730"])
	verify(t, "密码门：要完全一致（多一位也不开）", not GameState.has_flag(PalaceLibrary.CIPHER_FLAG))
	verify(t, "密码门的输入框只收数字", TextPrompt.matches("２５７３", ["2573"], true) and not TextPrompt.matches("", ["2573"], true))
	await t._talk("floor_06/library_door", "", ["2573"])
	verify(t, "密码门：输入 2573（浴场镜子 / 排班表 / 礼服尺码 / 刻痕）→ 门开了", GameState.has_flag(PalaceLibrary.CIPHER_FLAG) and not is_instance_valid(lr._door))
	verify(t, "门开了：书房的遮罩淡掉、露出里面", lr.shades.all(func(sd): return not is_instance_valid(sd) or (sd as PalaceLibrary.StudyShade).fade))
	lp.global_position = Cutscene.cell_to_world(lr.cells("study")[0])
	await t._advance_until(func(): return t.seen_cuts.has("library_study") and not Cutscene.is_playing(), 60.0)
	verify(t, "私人书房：女王的画、没写完的信、两个半圆凹槽（背景大图）", t.seen_cuts.has("library_study") and GameState.has_flag(PalaceLibrary.STUDY_FLAG))
	# 金色大书：投影 → 书怪
	await t._talk("floor_06/library_golden", "", [0])
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:library_bookmonster") and not CG.is_busy() and not Dialogue.is_active() and not Cutscene.is_playing(), 180.0)
	verify(t, "金色大书：投影「那天晚上」→ 恶作剧书怪的小剧场", t.seen_cuts.has("library_flashback") and GameState.has_flag("cg_seen_theater:library_bookmonster"))
	# ---- 衣帽间
	GameState.pending_spawn = "from_library"
	await t.main.change_level(Floors.scene("floor_06_palace_wardrobe"))
	await t._advance_until(func(): return t._level_id() == "floor_06_palace_wardrobe" and not Cutscene.is_playing() and t.seen_cuts.has("palace_wardrobe_in"), 60.0)
	var wr := _room(t, "PalaceWardrobe") as PalaceWardrobe
	await t.get_tree().process_frame
	verify(t, "衣帽间：开场、两人同行、羽毛披肩鬼在飘", wr != null and Duo.active and is_instance_valid(wr._shawl))
	if wr == null:
		return
	await t._talk("floor_06/wardrobe_mannequin", "", [0])
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:wardrobe_measure") and not CG.is_busy() and not Dialogue.is_active(), 120.0)
	verify(t, "礼服人台：量尺寸的小剧场", GameState.has_flag("cg_seen_theater:wardrobe_measure"))
	var rib0 := GameState.inventory.count("equip_palace_ribbon")
	await t._talk("floor_06/wardrobe_rack_1", "", [0])
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:wardrobe_try_1") and not CG.is_busy() and not Dialogue.is_active(), 120.0)
	verify(t, "旧衣架：试穿一小段 → 拿到「小殿下的发带」", GameState.inventory.count("equip_palace_ribbon") == rib0 + 1)
	var st0 := GameState.inventory.count("equip_palace_stockings")
	await t._talk("floor_06/wardrobe_socks", "", [0])
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:wardrobe_socks") and not CG.is_busy() and not Dialogue.is_active(), 150.0)
	verify(t, "自动穿袜机：「清洁」脚底 → 宫廷丝袜", GameState.inventory.count("equip_palace_stockings") == st0 + 1)
	await t._talk("floor_06/wardrobe_favorite", "", [0])
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:wardrobe_tryon") and not CG.is_busy() and not Dialogue.is_active(), 180.0)
	verify(t, "玫瑰色的礼服：试穿、蓝色公主借量尺寸挠她（CG）", GameState.has_flag("cg_seen_theater:wardrobe_tryon"))
	# 羽毛披肩鬼：蓝色公主攻击 → 冻住
	var bl := wr.blue
	wr._shawl.position = bl.global_position + Vector2(6, 0)
	bl._set_state(PlayableCharacter.State.ATTACK)
	wr._shawl.step(0.05)
	bl._set_state(PlayableCharacter.State.IDLE)
	verify(t, "蓝色公主攻击羽毛披肩鬼：冻住 → 掉下「羽毛披肩」", wr.shawl_frozen and GameState.inventory.has("equip_feather_shawl"))
	# 衣柜陷阱
	if GameState.player != wr.pink:
		GameState.switch_control(wr.pink)
	await t._talk("floor_06/wardrobe_trap", "", [0])
	await t._advance_until(func(): return wr.trap_active and not CG.is_busy() and not Dialogue.is_active(), 150.0)
	verify(t, "衣柜陷阱：粉色公主被关进去（CG）→ 换蓝色公主操控", wr.trap_active and GameState.player == wr.blue and GameState.has_flag("cg_seen_theater:wardrobe_trap_in"))
	var lg0 := wr.pink.laugh.value
	for i in 20:
		wr._process(0.1)
	verify(t, "柜子里：粉色公主的闷笑一直涨（%.0f → %.0f）" % [lg0, wr.pink.laugh.value], wr.pink.laugh.value > lg0)
	await t._talk("floor_06/wardrobe_trap", "")
	verify(t, "没钥匙：回到衣柜打不开", wr.trap_active)
	var wrong := (wr.key_at + 1) % 3
	await t._talk("floor_06/wardrobe_key_%d" % (wrong + 1), "")
	verify(t, "翻错了地方：没有钥匙", not wr.has_key)
	await t._talk("floor_06/wardrobe_key_%d" % (wr.key_at + 1), "")
	verify(t, "翻对了地方：找到钥匙", wr.has_key)
	await t._talk("floor_06/wardrobe_trap", "")
	await t._advance_until(func(): return not wr.trap_active and not CG.is_busy() and not Dialogue.is_active(), 150.0)
	verify(t, "回到衣柜开门：救出来的小剧场（她倒出来、蓝色公主戳她脚心）", not wr.trap_active and GameState.has_flag("cg_seen_theater:wardrobe_trap_out") and is_equal_approx(wr.pink.modulate.a, 1.0))
	await t._talk("floor_06/wardrobe_fragment", "")
	verify(t, "大衣口袋里的残页（%s）" % GameState.vars.get("palace_frags"), int(GameState.vars.get("palace_frags", 0)) == 2)
	# ---- 骑士训练场
	GameState.pending_spawn = "from_library"
	await t.main.change_level(Floors.scene("floor_06_palace_training"))
	await t._advance_until(func(): return t._level_id() == "floor_06_palace_training" and not Cutscene.is_playing() and t.seen_cuts.has("palace_training_in"), 60.0)
	var tr := _room(t, "PalaceTraining") as PalaceTraining
	await t.get_tree().process_frame
	verify(t, "骑士训练场：开场、4 个稻草人、%d 把羽毛剑" % (tr.swords.size() if tr else 0), tr != null and tr.dummies.size() == 4 and tr.swords.size() >= 3)
	if tr == null:
		return
	var tp := GameState.player as PlayableCharacter
	var tl0 := tp.laugh.value
	verify(t, "打错了稻草人：还手挠一下、顺序重来", not tr.hit_dummy(1, tp) and tr.order_i == 0 and tp.laugh.value > tl0)
	var mint0 := GameState.inventory.count("mint")
	for i in PalaceTraining.ORDER:
		tr.hit_dummy(i, tp)
	verify(t, "按木牌的顺序（最左 → 最右 → 中间从右往左）打完：薄荷糖", GameState.has_flag(PalaceTraining.DUMMY_FLAG) and GameState.inventory.count("mint") == mint0 + 1)
	var sw := tr.swords[0] as PalaceTraining.Sword
	sw.t = PalaceTraining.SWORD_CYCLE * 0.5
	tp.global_position = sw.position
	var tl1 := tp.laugh.value
	for i in 12:
		tr._process(0.02)
		sw.t = PalaceTraining.SWORD_CYCLE * 0.5
	verify(t, "羽毛剑挥到底：扫到脚底（%.0f → %.0f）" % [tl1, tp.laugh.value], tp.laugh.value > tl1)
	# 对练擂台
	BlueTickleShow.quiet = true
	tr.spar()
	await t._advance_until(func(): return t._show(BlueTickleShow) != null and not (t._show(BlueTickleShow) as BlueTickleShow).busy, 60.0)
	var bt := t._show(BlueTickleShow) as BlueTickleShow
	verify(t, "对练擂台：找痒点（擂台的台词，不是灯笼）", bt != null and str(bt.tx().get("name", "")) == "骑士对练")
	if bt:
		bt.blue_laugh = 0.95
		bt.weak = bt.cursor
		bt._press = 0.0
		bt.tickle_now()
	await t._advance_until(func(): return tr.spar_result != "" and not CG.is_busy() and not Dialogue.is_active(), 150.0)
	verify(t, "她先笑满：对练赢了的小剧场（%s）" % tr.spar_result, tr.spar_result == "win" and GameState.has_flag("cg_seen_theater:training_spar_win"))
	# 遭遇战：输一次、再赢
	await t._talk("floor_06/training_bell", "", [0])
	await t._advance_until(func(): return tr.fighting, 60.0)
	verify(t, "敲钟：门关上、第一波（%d 只）" % tr.spawned.size(), tr.fighting and tr.wave == 0 and tr.spawned.size() == 4 and tr._gates.size() == 2)
	tr.on_defeat("both_down")
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:training_lose") and not CG.is_busy() and not tr._defeat_busy, 150.0)
	verify(t, "遭遇战里两个都倒下：补课的小剧场 → 怪清掉、门打开、可以再敲", not tr.fighting and tr._gates.is_empty() and not GameState.has_flag(PalaceTraining.CLEAR_FLAG))
	await t._talk("floor_06/training_bell", "", [0])
	await t._advance_until(func(): return tr.fighting, 60.0)
	var waves := []
	for k in 3:
		waves.append(tr.spawned.size())
		for m in tr.spawned:
			(m as Node).queue_free()
		await t.get_tree().process_frame
		tr._tick_fight()
	await t._advance_until(func(): return not Cutscene.is_playing(), 30.0)
	verify(t, "三波（%s）全打倒：考验通过、门打开" % [waves], waves == [4, 4, 1] and GameState.has_flag(PalaceTraining.CLEAR_FLAG) and tr._gates.is_empty())
	await t._talk("floor_06/training_chest", "")
	verify(t, "旧箱子打开：最后一张残页（%s）" % GameState.vars.get("palace_frags"), int(GameState.vars.get("palace_frags", 0)) == 3 and GameState.has_flag("palace_frag_3"))
	# 耐痒训练台：被动
	var g0 := tp._extra_stat_add("laugh_gain")
	await t._talk("floor_06/training_stocks", "", [0])
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:training_stocks") and not CG.is_busy() and not Dialogue.is_active(), 150.0)
	verify(t, "耐痒训练台：小剧场 → 被动「骑士的忍耐」（闷笑涨幅 %.2f → %.2f）" % [g0, tp._extra_stat_add("laugh_gain")],
		GameState.passives.has("knight_endurance") and tp._extra_stat_add("laugh_gain") < g0 - 0.05)
	await t._talk("floor_06/training_diary", "")
	tp.global_position = Cutscene.cell_to_world(tr.cells("north")[0])
	await t._advance_until(func(): return t._level_id() == "floor_06_palace_ante" and not Cutscene.is_playing() and t.seen_cuts.has("palace_ante_in"), 60.0)
	verify(t, "训练场北门：通往王座前厅（%s）" % t._level_id(), t._level_id() == "floor_06_palace_ante")
	await _exit_hints(t)
	await _ante_events(t)
	await _palace_c(t)
	await _extra_events(t)
	await _extra_events_c(t)
	await _round4(t)
	await _garden(t)


static func _quiet_beetles(cr: PalaceClock) -> void:
	for i in cr.cells("beetle_nests").size():
		cr._nest_batches[i] = PalaceClock.NEST_MAX
	for b in cr.beetles:
		if is_instance_valid(b):
			(b as Node).queue_free()


## 鼠洞底的胖鼠王（躲猫猫）、奶酪捕鼠夹
static func _rat_king(t: Node, rt: RatTunnel) -> void:
	await t.get_tree().process_frame
	var kg := rt.king
	var pk := GameState.player as PlayableCharacter
	verify(t, "鼠洞底：胖鼠王 + %d 个洞口、%d 个捕鼠夹" % [kg.holes.size() if kg else 0, rt.traps.size()], kg != null and kg.holes.size() == 5 and rt.traps.size() == 4)
	if kg == null:
		return
	kg.reset()
	GameState.flags.erase(RatKing.INTRO_FLAG)
	pk.global_position = kg.home + Vector2(0, 40)
	await t._advance_until(func(): return t.seen_cuts.has("tunnel_king_in") and not Cutscene.is_playing() and kg.phase == "under", 60.0)
	verify(t, "走进洞底：先演开场（女王把笑脸徽记交给鼠族保管），再钻进地下开打（%s）" % kg.phase, t.seen_cuts.has("tunnel_king_in") and kg.phase == "under")
	kg.peek_at(0)
	pk.global_position = kg.holes[0] + Vector2(10, 0)
	var l0 := pk.laugh.value
	await t._wait(0.6)
	verify(t, "它从洞口探头、离得近：胡子扫脚心（%.0f → %.0f）" % [l0, pk.laugh.value], pk.laugh.value > l0)
	kg.hit_now()
	verify(t, "探头的时候打它：缩回去", kg.phase == "under")
	pk.laugh.clear()
	kg.peek_at(1)
	verify(t, "它正从这个洞探头：堵不上", not kg.plug(1))
	kg._dive()
	pk.global_position = kg.home + Vector2(0, 60)
	for i in 4:
		kg.plug(i)
	verify(t, "堵上四个洞：从最后一个洞被逼出来（%s，第 %d 个洞）" % [kg.phase, kg.at_hole], kg.phase == "out" and kg.at_hole == 4)
	kg.fail_now()
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:tunnel_rat_king_fail") and not CG.is_busy() and not Dialogue.is_active(), 150.0)
	await t.get_tree().process_frame
	verify(t, "输给胖鼠王：小剧场（CG）→ 洞口全开、重来", GameState.has_flag("cg_seen_theater:tunnel_rat_king_fail") and kg.plugged_count() == 0 and kg.phase == "idle")
	pk.laugh.clear()
	pk.global_position = kg.home + Vector2(0, 60)
	for i in 4:
		kg.plug(i)
	for i in RatKing.HP:
		kg.hit_now()
	verify(t, "逼出来以后打 %d 下：胖鼠王倒下 → 笑脸徽记" % RatKing.HP, GameState.has_flag(RatKing.FLAG) and GameState.has_flag(PalaceRoom.badge_flag("rat_king"))
		and GameState.inventory.has("smile_badge"))
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:tunnel_revenge") and not CG.is_busy() and not Dialogue.is_active(), 150.0)
	verify(t, "胖鼠王倒下：裤子里的挠脚鼠叫来一群挠脚鼠报复（小剧场 + CG）", GameState.has_flag("cg_seen_theater:tunnel_revenge"))
	# 奶酪捕鼠夹
	pk = GameState.player as PlayableCharacter
	pk.laugh.clear()
	var tr := rt.traps[0] as RatTunnel.Mousetrap
	pk.global_position = tr.global_position
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	verify(t, "踩到奶酪：被捕鼠夹夹住", pk.status.is_grabbed_by(tr))
	var l1 := pk.laugh.value
	await t._wait(0.8)
	verify(t, "夹住的时候小老鼠围上来挠脚心（%.0f → %.0f）" % [l1, pk.laugh.value], pk.laugh.value > l1)
	for i in RatTunnel.TRAP_PRESSES:
		pk.status.struggle()
	await t.get_tree().process_frame
	verify(t, "连按挣扎 %d 下：挣开" % RatTunnel.TRAP_PRESSES, not pk.status.is_grabbed())
	pk.global_position = tr.global_position + Vector2(1, 0)
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	verify(t, "同一个夹子只夹一次", not pk.status.is_grabbed())
	await t._wait(1.5)   # 挣开以后有一小段无敌（grab_escape_invuln），等它过去再测下面的滴水管
	pk.laugh.clear()


## 王座前厅的追加事件：空铠甲卫兵、笑声地砖 → 宝库、石像问答、许愿喷泉、徽记台
static func _ante_events(t: Node) -> void:
	var an := _room(t, "PalaceAnte") as PalaceAnte
	verify(t, "王座前厅：两具空铠甲卫兵在巡逻", an != null and an.guards.size() == 2)
	if an == null:
		return
	for f in [PalaceAnte.VAULT_FLAG, PalaceAnte.VAULT_LOOT, PalaceAnte.STATUE_FLAG, PalaceAnte.BADGES_FLAG, "palace_sheet_1", "palace_sheet_2", "palace_sheet_3"]:
		GameState.flags.erase(f)
	for s in PalaceRoom.BADGE_SOURCES:
		GameState.flags.erase(PalaceRoom.badge_flag(s))
	var p := GameState.player as PlayableCharacter
	var mate := Duo.partner_of(p)
	# 卫兵：视野里看到 → 冲过来 → 举起来挠腋下；从背后推倒
	var g := an.guards[0] as PalaceAnte.ArmorGuard
	var g2 := an.guards[1] as PalaceAnte.ArmorGuard
	g2.push_down()
	g2._t = -9999.0
	p.global_position = an.world(an.cells("statue")[0]) + Vector2(0, 30)
	mate.global_position = g.position + g.facing * 30.0
	g.tick(0.016)
	verify(t, "卫兵的视野里有人：冲过去（%s）" % g.state, g.state == "charge")
	mate.global_position = g.position
	g.tick(0.016)
	verify(t, "碰到：举起来挠腋下", g.state == "hold" and mate.status.is_grabbed_by(g))
	var ml := mate.laugh.value
	for i in 5:
		g.tick(0.1)
	verify(t, "举着的时候挠腋下（%.0f → %.0f）" % [ml, mate.laugh.value], mate.laugh.value > ml)
	mate.status.release()
	g.tick(0.016)
	verify(t, "挣开：卫兵回去巡逻", g.state == "return")
	g.state = "patrol"
	p.global_position = g.position - g.facing * 14.0
	g.on_interact(p)
	verify(t, "从背后按 E：推倒、散架", g.state == "down")
	g._t = -9999.0
	mate.laugh.clear()
	mate.global_position = p.global_position + Vector2(20, 0)
	# 笑声地砖：乐谱没齐时只是响
	an.step_tile(1, p)
	verify(t, "乐谱没齐：地砖只是笑一声", an.tile_progress == 0 and not an.tiles_armed())
	for i in [1, 2, 3]:
		GameState.set_flag("palace_sheet_%d" % i)
	var pl := p.laugh.value
	an.step_tile(1, p)
	verify(t, "三片乐谱齐了：踩错 → 砖缝里的羽毛扫脚心（%.0f → %.0f）" % [pl, p.laugh.value], p.laugh.value > pl and an.tile_progress == 0)
	for i in PalaceAnte.TILE_SEQ:
		an.step_tile(i, p)
	verify(t, "按乐谱踩对六步：地下小宝库打开", an.vault_open())
	await t._talk("floor_06/ante_vault", "")
	verify(t, "宝库：女王最喜欢的花（铃兰）+ 笑脸徽记", GameState.has_flag(PalaceAnte.VAULT_LOOT) and GameState.has_flag(PalaceRoom.badge_flag("vault")))
	# 石像问答
	p.laugh.clear()
	await t._talk("floor_06/ante_statue", "", [0, "十二下"])
	verify(t, "石像问答答错：石手抓住脚踝挠脚心", p.status.is_rooted() and not GameState.has_flag(PalaceAnte.STATUE_FLAG))
	p.status.clear_root()
	await t._talk("floor_06/ante_statue", "", [0, "我觉得是十三下", "7 号", "铃兰花"])
	verify(t, "三题全对（输入里包含「十三 / 七 / 铃兰」就算对）：女王的八音盒 + 笑脸徽记", GameState.has_flag(PalaceAnte.STATUE_FLAG)
		and GameState.inventory.has("queen_music_box") and GameState.has_flag(PalaceRoom.badge_flag("statue")))
	# 许愿喷泉
	p.laugh.clear()
	GameState.give_item(ItemDB.get_item("mint"), 1)
	an.next_wish = 1
	var wl := p.laugh.value
	await t._talk("floor_06/ante_fountain", "", [0])
	verify(t, "许愿喷泉投薄荷糖：水柱喷脚底（%.0f → %.0f）" % [wl, p.laugh.value], p.laugh.value > wl)
	p.laugh.clear()
	mate.laugh.clear()
	# 徽记台：不够 → 提示；七枚 → 女王的羽毛发饰 + 庆祝（CG）
	await t._talk("floor_06/ante_pedestal", "", [0])
	verify(t, "徽记不够七枚：放不上去（%d 枚）" % PalaceRoom.badges(), not GameState.has_flag(PalaceAnte.BADGES_FLAG))
	for s in PalaceRoom.BADGE_SOURCES:
		GameState.set_flag(PalaceRoom.badge_flag(s))
	await t._talk("floor_06/ante_pedestal", "", [0])
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:palace_badge_party") and not CG.is_busy() and not Dialogue.is_active(), 150.0)
	verify(t, "七枚笑脸徽记：女王的羽毛发饰 + 庆祝小剧场（CG）", GameState.has_flag(PalaceAnte.BADGES_FLAG)
		and GameState.inventory.has("equip_queen_hairpin") and GameState.has_flag("cg_seen_theater:palace_badge_party"))
	p.laugh.clear()
	mate.laugh.clear()


static func _goto(t: Node, fid: String) -> void:
	GameState.pending_spawn = ""
	await t.main.change_level(Floors.scene(fid))
	await t._advance_until(func(): return t._level_id() == fid and not Cutscene.is_playing() and not Dialogue.is_active(), 60.0)
	await t.get_tree().process_frame
	await t.get_tree().process_frame


static func _calm(t: Node) -> void:
	for m in t.get_tree().get_nodes_in_group("player_chars"):
		var pc := m as PlayableCharacter
		if pc.status.is_grabbed():
			pc.status.release()
		pc.status.clear_root()
		pc.laugh.clear()


## 追加事件（第二批）：搓澡人偶 / 送餐潜行 / 飞书群与书架暗门 / 旧鞋军团 / 队长的幽影 / 失物招领与黑暗区 / 八音盒
static func _extra_events(t: Node) -> void:
	Cutscene.chapter_screen.hide()
	Cutscene.chapter_next = ""
	# ---- 旧浴场：搓澡人偶（抢海绵）
	for f in [ScrubDoll.FLAG, PalaceRoom.badge_flag("scrub"), "palace_sheet_3", "cg_seen_theater:bath_scrub_grab", "palace_sheet_2", PalaceRoom.TRAY_FLAG,
			PalaceLibrary.BOOKS_FLAG, PalaceLibrary.SHELF_FLAG, PalaceWardrobe.SHOES_FLAG, PalaceTraining.SHADE_FLAG, PalaceRoom.badge_flag("shade"),
			"cg_seen_theater:training_shade", "cg_seen_theater:servants_tasting", PalaceTunnels.LOST_DONE, PalaceRoom.badge_flag("lost")]:
		GameState.flags.erase(f)
	for k in PalaceRoom.LOST_NAMES:
		GameState.flags.erase(PalaceRoom.lost_flag(k))
	GameState.flags.erase(PalaceRoom.LOST_ASKED)
	await _goto(t, "floor_06_palace_bath")
	var pb := _room(t, "PalaceBath") as PalaceBath
	var sd: ScrubDoll = pb.scrub if pb else null
	verify(t, "旧浴场：大浴室南边有搓澡人偶（三块海绵）", sd != null and sd.sponges == ScrubDoll.SPONGES and sd.phase == "idle")
	if sd == null:
		return
	var sheet_spot: Node2D = null
	for c in pb.get_children():
		if c is PrisonOddities.Spot and (c as PrisonOddities.Spot).dialogue == "floor_06/bath_sheet":
			sheet_spot = c
	var mirror_at := pb.world(pb.cells("mirror")[0])
	verify(t, "乐谱片③的拾取点和镜子分开（%.0f 像素）、人偶倒下前看不见" % (sheet_spot.global_position.distance_to(mirror_at) if sheet_spot else 0.0),
		sheet_spot != null and sheet_spot.global_position.distance_to(mirror_at) >= 48.0 and not sheet_spot.visible)
	var p := GameState.player as PlayableCharacter
	var mate := Duo.partner_of(p)
	_calm(t)
	p.global_position = sd.home + Vector2(0, 40)
	mate.global_position = sd.home + Vector2(20, 40)
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	verify(t, "走近：搓澡人偶开打", sd.phase == "fight")
	sd.grab(p)
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:bath_scrub_grab") and not CG.is_busy() and not Dialogue.is_active(), 150.0)
	verify(t, "第一次被抓：按进泡泡桶刷脚底（小剧场 + CG）", GameState.has_flag("cg_seen_theater:bath_scrub_grab"))
	_calm(t)
	sd.grab(p)
	verify(t, "之后在场上抓人：被抓住", sd.phase == "hold" and p.status.is_grabbed_by(sd))
	sd.hit_by(mate)
	verify(t, "搭档打它：松手 + 打掉一块海绵（掉在地上滚过来）", sd.phase == "fight" and not p.status.is_grabbed() and sd.sponges == 2 and sd.sponges_alive.size() == 1)
	var hp0 := sd.hp
	sd.hit_by(mate)
	sd.hit_by(mate)
	verify(t, "海绵还在的时候打不动本体（%d → %d）" % [hp0, sd.hp], sd.sponges == 0 and sd.hp == hp0)
	for i in ScrubDoll.HP:
		sd.hit_by(mate)
	verify(t, "海绵打光以后打 %d 下：搓澡人偶倒下 → 笑脸徽记" % ScrubDoll.HP, sd.phase == "down" and GameState.has_flag(PalaceRoom.badge_flag("scrub")))
	_calm(t)
	await t.get_tree().process_frame
	verify(t, "人偶倒下：倒下的地方浮出乐谱片③", sheet_spot.visible)
	await t._talk("floor_06/palace_mirror", "")
	verify(t, "擦镜子只给线索（不给乐谱）", not GameState.has_flag("palace_sheet_3"))
	await t._talk("floor_06/bath_sheet", "")
	verify(t, "捡起乐谱片③", GameState.has_flag("palace_sheet_3"))
	# ---- 送餐潜行：厨房拿托盘 → 回廊被发现 = 试吃惩罚（CG）；送到女仆长房间 = 乐谱片②
	await _goto(t, "floor_06_palace_kitchen")
	await t._talk("floor_06/kitchen_tray", "", [0])
	await t.get_tree().process_frame
	p = GameState.player as PlayableCharacter
	verify(t, "厨房：端起点心托盘（不能冲刺）", PalaceRoom.carrying_tray() and p.has_meta(&"no_dash"))
	var lost_spot: Node2D = null
	for c in (_room(t, "PalaceKitchen") as Node).get_children():
		if c is PrisonOddities.Spot and (c as PrisonOddities.Spot).dialogue == "floor_06/lost_cheese":
			lost_spot = c
	verify(t, "还没和隧道的小鬼说过「失物招领」：厨房的失物不出现", lost_spot != null and not lost_spot.visible)
	GameState.set_flag(PalaceRoom.LOST_ASKED)
	await t.get_tree().process_frame
	verify(t, "说过以后：失物出现", lost_spot != null and lost_spot.visible)
	await t._talk("floor_06/lost_cheese", "")
	verify(t, "失物①：灶台边的奶酪", GameState.has_flag(PalaceRoom.lost_flag("cheese")))
	await _goto(t, "floor_06_palace_servants")
	var sv := _room(t, "PalaceServants") as PalaceServants
	verify(t, "端着托盘到了仆人回廊：托盘还在", PalaceRoom.carrying_tray())
	sv.caught()
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:servants_tasting") and not CG.is_busy() and not Dialogue.is_active(), 150.0)
	verify(t, "端着托盘被女仆发现：试吃惩罚（小剧场 + CG）、点心没了", GameState.has_flag("cg_seen_theater:servants_tasting") and not PalaceRoom.carrying_tray())
	_calm(t)
	PalaceRoom.set_tray(true)
	await t._talk("floor_06/servants_deliver", "")
	verify(t, "送到女仆长的房间：乐谱片②", GameState.has_flag("palace_sheet_2") and not PalaceRoom.carrying_tray())
	await t._talk("floor_06/lost_bell", "")
	# ---- 图书馆：飞书群三波、衣架书签 → 书架暗门
	await _goto(t, "floor_06_palace_library")
	var lr := _room(t, "PalaceLibrary") as PalaceLibrary
	_calm(t)
	lr.start_books()
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	verify(t, "图书馆·飞书群第一波（%d 本）" % lr.books_alive(), lr.book_wave == 0 and lr.books_alive() == PalaceLibrary.BOOK_WAVES[0])
	var bk := lr.books[0] as FlyingBook
	var pinkc: PlayableCharacter = GameState.player if (GameState.player as PlayableCharacter).character_id == "pink" else Duo.partner_of(GameState.player)
	var hb := HitData.new()
	hb.kind = HitData.Kind.ATTACK
	hb.damage = 1
	hb.source = pinkc
	bk.receive_hit(hb)
	verify(t, "粉色公主的攻击打飞书伤害 ×2（一下就打掉 2 血的书）", not bk.is_alive())
	for w in PalaceLibrary.BOOK_WAVES.size():
		for b in lr.books:
			if is_instance_valid(b) and (b as Monster).is_alive():
				(b as Monster).health.damage(99)
		await t._wait(0.3)
	await t._wait(0.3)
	verify(t, "三波飞书全打完", GameState.has_flag(PalaceLibrary.BOOKS_FLAG))
	_calm(t)
	var shelf: LevelExit = null
	for nd in t.get_tree().root.find_children("*", "Area2D", true, false):
		if nd is LevelExit and (nd as LevelExit).secret:
			shelf = nd
	verify(t, "禁书区的书架暗门：锁着、没走过不显示标志", shelf != null and shelf.is_locked_now() and shelf.secret_hidden())
	await t._talk("floor_06/library_hanger_book", "", [0])
	verify(t, "抽出夹着衣架书签的书：书架暗门开了", GameState.has_flag(PalaceLibrary.SHELF_FLAG) and shelf != null and not shelf.is_locked_now())
	await t._talk("floor_06/lost_quill", "")
	# ---- 衣帽间：旧鞋军团 → 鞋柜
	await _goto(t, "floor_06_palace_wardrobe")
	var wr := _room(t, "PalaceWardrobe") as PalaceWardrobe
	var shoes: Array = wr.shoes()
	verify(t, "衣帽间：%d 只旧鞋在跳" % shoes.size(), shoes.size() == 6)
	var closet := wr.world(wr.cells("shoe_closet")[0])
	for i in shoes.size():
		(shoes[i] as Node2D).global_position = closet + Vector2(10 + i * 4, 10) if i < 4 else closet + Vector2(400, 0)
	var n1 := wr.close_closet()
	verify(t, "引到鞋柜旁边关门：附近的 %d 只关进去" % n1, n1 == 4 and not GameState.has_flag(PalaceWardrobe.SHOES_FLAG))
	await t.get_tree().process_frame
	for m in wr.shoes():
		(m as Node2D).global_position = closet + Vector2(12, 12)
	wr.close_closet()
	verify(t, "剩下的也关进去：旧鞋军团清空", GameState.has_flag(PalaceWardrobe.SHOES_FLAG))
	_calm(t)
	await t._talk("floor_06/lost_sock", "")
	# ---- 骑士训练场：年轻队长的幽影（三回合）
	await _goto(t, "floor_06_palace_training")
	var tr := _room(t, "PalaceTraining") as PalaceTraining
	_calm(t)
	tr.start_shade()
	await t.get_tree().process_frame
	verify(t, "训练场·幽影对练第一回合：一个幽影", tr.shade_round == 1 and tr.shades_alive() == 1)
	for r in 3:
		for sh in tr.shades:
			if is_instance_valid(sh):
				for k in PalaceTraining.SHADE_HP:
					(sh as PalaceTraining.Shade).hurt()
		if r == 0:
			await t.get_tree().process_frame
			await t.get_tree().process_frame
			verify(t, "第二回合：分出两个幽影", tr.shade_round == 2 and tr.shades_alive() == 2)
		elif r == 1:
			await t.get_tree().process_frame
			await t.get_tree().process_frame
			p = GameState.player as PlayableCharacter
			var wl := p.laugh.value
			tr.shade_wave()
			verify(t, "第三回合：队长的绝招·羽毛风暴（%.0f → %.0f）" % [wl, p.laugh.value], tr.shade_round == 3 and p.laugh.value > wl)
		else:
			await t.get_tree().process_frame
			await t.get_tree().process_frame
	await t._advance_until(func(): return not Dialogue.is_active() and not Dialogue.runner.is_running(), 30.0)
	verify(t, "三回合都赢：幽影说起「那两个小女孩」→ 笑脸徽记", GameState.has_flag(PalaceTraining.SHADE_FLAG) and GameState.has_flag(PalaceRoom.badge_flag("shade")))
	GameState.flags.erase(PalaceTraining.SHADE_FLAG)
	tr.start_shade()
	tr.on_defeat("test")
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:training_shade") and not CG.is_busy() and not Dialogue.is_active(), 150.0)
	verify(t, "输给幽影：耐痒训练（小剧场 + CG）", GameState.has_flag("cg_seen_theater:training_shade"))
	GameState.set_flag(PalaceTraining.SHADE_FLAG)
	tr.shade_round = 0
	tr._clear_shades()
	_calm(t)
	# ---- 钟楼二层的钟发条
	await _goto(t, "floor_06_palace_clock_2")
	await t._talk("floor_06/lost_spring", "")
	# ---- 隧道：失物招领、黑暗区
	await _goto(t, "floor_06_palace_tunnels")
	var tu := _room(t, "PalaceTunnels") as PalaceTunnels
	verify(t, "再进隧道：路费又要付了（付过一次不算数）", not tu.toll_paid() and is_instance_valid(tu._toll_body))
	verify(t, "五样失物都找到了（%d / 5）" % PalaceRoom.lost_found(), PalaceRoom.lost_found() == 5)
	await t._talk("floor_06/tunnel_lost", "", [0])
	verify(t, "交给收路费的小鬼：免路费通行证 + 笑脸徽记", GameState.has_flag(PalaceTunnels.LOST_DONE) and tu.toll_paid() and GameState.has_flag(PalaceRoom.badge_flag("lost")))
	_calm(t)
	var dark := PalaceRoom.cell_pos(Vector2i(11, 40))
	tu.pink.global_position = dark
	tu.blue.global_position = dark + Vector2(0, 200)
	verify(t, "黑暗区：离开冰光就一片黑（%.2f），冰光里看得见（%.2f）" % [tu.light_at(dark), tu.light_at(tu.blue.global_position)], tu.in_dark(dark) and tu.light_at(dark) == 0.0 and tu.light_at(tu.blue.global_position) == 1.0)
	var dl := tu.pink.laugh.value
	tu._tick_dark(PalaceTunnels.DARK_GRAB + 0.1)
	verify(t, "粉色公主离开冰光 %.1f 秒：暗处的手抓住挠（%.0f → %.0f）" % [PalaceTunnels.DARK_GRAB, dl, tu.pink.laugh.value], tu.pink.laugh.value > dl)
	var hooks := tu.ai_hooks()
	verify(t, "AI 是蓝色公主时：贴着进了黑暗区的粉色公主走", hooks.objective_for(tu.blue) == tu.pink.global_position)
	_calm(t)
	# ---- 王座间：女王的八音盒
	GameState.set_flag(PalaceThrone.BOSS_FLAG, false)
	GameState.pending_spawn = "from_ante"
	await t.main.change_level(Floors.scene("floor_06_palace_throne"))
	await t._advance_until(func(): return t._level_id() == "floor_06_palace_throne" and not Cutscene.is_playing() and not Dialogue.is_active(), 60.0)
	var th := _room(t, "PalaceThrone") as PalaceThrone
	verify(t, "王座间：八音盒自动放到 R 键上", GameState.hotkey_item("use_special") == "queen_music_box")
	var used := GameState.inventory.use("queen_music_box", GameState.player)
	verify(t, "按 R 打开八音盒：画像发呆、露出破绽（不消耗）", th.box_t > 0.0 and th.vulnerable() and GameState.inventory.has("queen_music_box") and not used)
	# 颜料池被释放以后，泼颜料的循环不会去 cast 已释放的对象
	var pool := th.spawn_pool(GameState.player.global_position + Vector2(200, 0))
	await t.get_tree().process_frame
	pool.free()
	th._tick_paint(0.05)
	verify(t, "颜料池释放以后照常运行（不 cast 已释放的对象）", th.pools.all(func(x): return is_instance_valid(x)))
	th.use_music_box()
	verify(t, "每场只能用 %d 次" % PalaceThrone.BOX_USES, th.box_used == PalaceThrone.BOX_USES and not th.use_music_box())
	GameState.set_flag(PalaceThrone.BOSS_FLAG)
	_calm(t)


## 追加事件（第三批，跨图）：发条钥匙 / 休息室、巡夜队、冷藏库、宝箱怪的逃亡、镜子迷宫与失窃的小画像、人偶舞会
static func _extra_events_c(t: Node) -> void:
	for f in [PalaceRoom.FRIEND_FLAG, PalaceRoom.PATROL_FLAG, "cg_seen_theater:servants_massage", PalaceKitchen.COLD_FLAG, PalaceKitchen.COLD_IN_FLAG,
			PalaceKitchen.CAKE_FLAG, "cg_seen_theater:kitchen_icecream", PalaceRoom.MIMIC_FLED, PalaceRoom.MIMIC_DONE, PalaceWardrobe.PORTRAIT_FLAG,
			PalaceThrone.PORTRAIT_BACK, PalaceAnte.BALL_BELL, PalaceAnte.BALL_TILES, PalaceAnte.BALL_DONE, "cg_seen_theater:ante_ball_fail"]:
		GameState.flags.erase(f)
	# ---- 回廊：女仆长的发条钥匙 → 休息室的按摩椅（CG）
	await _goto(t, "floor_06_palace_servants")
	var sv := _room(t, "PalaceServants") as PalaceServants
	verify(t, "回廊：女仆长休息室的门锁着", sv != null and is_instance_valid(sv._lounge_door))
	if sv == null:
		return
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	verify(t, "上发条的调查点挂在女仆长本人身上（跟着她走）", is_instance_valid(sv.head_maid) and is_instance_valid(sv.wind_spot)
		and sv.wind_spot.get_parent() == sv.head_maid)
	verify(t, "没有发条钥匙：上不了弦", not sv.wind_maid())
	GameState.give_item(ItemDB.get_item("maid_key"), 1)
	verify(t, "钟楼一层宝箱里的「女仆长的发条钥匙」：给她上弦 → 友好、休息室开门", sv.wind_maid() and GameState.has_flag(PalaceRoom.FRIEND_FLAG)
		and not GameState.inventory.has("maid_key"))
	await t.get_tree().process_frame
	verify(t, "休息室的门开了", not is_instance_valid(sv._lounge_door))
	var cc0 := sv.caught_count
	sv.caught()
	verify(t, "女仆长友好以后：回廊的人偶不再抓人", sv.caught_count == cc0)
	await t._talk("floor_06/servants_lounge_chair", "", [0])
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:servants_massage") and not CG.is_busy() and not Dialogue.is_active(), 150.0)
	verify(t, "休息室的人偶按摩椅：小剧场（CG）", GameState.has_flag("cg_seen_theater:servants_massage"))
	_calm(t)
	# ---- 巡夜队：回廊被抓过一次 → 厨房多一个巡夜人偶；女仆长友好以后撤掉
	GameState.flags.erase(PalaceRoom.FRIEND_FLAG)
	GameState.set_flag(PalaceRoom.PATROL_FLAG)
	await _goto(t, "floor_06_palace_kitchen")
	var kr := _room(t, "PalaceKitchen") as PalaceKitchen
	await t.get_tree().process_frame
	verify(t, "回廊被抓过：厨房多了巡夜人偶", kr.patrols.size() == 1)
	var p := GameState.player as PlayableCharacter
	var np := kr.patrols[0] as PalaceRoom.NightPatrol
	p.global_position = kr.world(kr.cells("ice_cake")[0])
	np.catch(p)
	verify(t, "被巡夜人偶抓到：挠一阵、送回入口", p.global_position.distance_to(kr.world(kr.cells("start")[0])) < 24.0)
	GameState.set_flag(PalaceRoom.FRIEND_FLAG)
	np.tick(0.05)
	await t.get_tree().process_frame
	verify(t, "女仆长友好以后：巡夜人偶撤掉", not is_instance_valid(np))
	_calm(t)
	# ---- 冷藏库
	verify(t, "冰滑道尽头的门冻住了", is_instance_valid(kr._cold_door))
	kr.melt_door()
	await t.get_tree().process_frame
	verify(t, "粉色公主的火融开冻住的门", GameState.has_flag(PalaceKitchen.COLD_FLAG) and not is_instance_valid(kr._cold_door))
	kr.enter_cold()
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:kitchen_icecream") and not CG.is_busy() and not Dialogue.is_active(), 150.0)
	await t.get_tree().process_frame
	verify(t, "第一次进冷藏库：冰糕精灵的小剧场 → 放出 %d 只冰糕精灵" % kr.ice_sprites.size(), GameState.has_flag("cg_seen_theater:kitchen_icecream") and kr.ice_sprites.size() == 3)
	for m in kr.ice_sprites:
		if is_instance_valid(m):
			(m as Node).queue_free()
	_calm(t)
	await t._talk("floor_06/kitchen_ice_cake", "", [0])
	verify(t, "冰块里的生日蛋糕：融开 → 卡片「给两个小不点的第一个生日」", GameState.has_flag(PalaceKitchen.CAKE_FLAG))
	# ---- 宝箱怪的逃亡：冷藏库 → 图书馆 → 衣帽间
	GameState.set_flag(PalaceRoom.MIMIC_FLED)
	GameState.vars[PalaceRoom.MIMIC_STAGE] = 0
	for i in 3:
		var fid: String = PalaceRoom.MIMIC_MAPS[i]
		if i > 0:
			await _goto(t, fid)
		var room := _room(t, ["PalaceKitchen", "PalaceLibrary", "PalaceWardrobe"][i]) as PalaceRoom
		_calm(t)
		p = GameState.player as PlayableCharacter
		room.mimic_catch()
		verify(t, "宝箱怪躲在%s：打开 → 被咬住" % ["冷藏库", "图书馆", "衣帽间"][i], p.status.is_grabbed())
		for k in 6:
			p.status.struggle()
		await t.get_tree().process_frame
		await t.get_tree().process_frame
		verify(t, "挣开：它又跑了（第 %d 次）" % (i + 1), int(GameState.vars.get(PalaceRoom.MIMIC_STAGE, 0)) == i + 1)
		await t._advance_until(func(): return not Dialogue.is_active() and not Dialogue.runner.is_running(), 30.0)
	verify(t, "三次都抓到：宝箱怪吐出金币和一张地图", GameState.has_flag(PalaceRoom.MIMIC_DONE))
	# ---- 衣帽间：镜子迷宫（必经之路）、失窃的小画像
	var wr := _room(t, "PalaceWardrobe") as PalaceWardrobe
	var lvn := t.get_tree().get_first_node_in_group("main").get("level") as Node
	var mc := wr.cells("mirror_wall")[0]
	verify(t, "衣帽间的镜子迷宫：%d 块镜面墙板、镜墙走不过去" % wr.mirrors.size(), wr.mirrors.size() > 40 and not GridPath.walkable(lvn, Vector2i(28, 10)))
	var path := GridPath.find(lvn, wr.world(wr.cells("start")[0]), wr.world(wr.cells("trap_wardrobe")[0]), 20000)
	verify(t, "从门口到东边要穿过整个迷宫（路长 %d 格）" % path.size(), path.size() > 90)
	_calm(t)
	await t._talk("floor_06/wardrobe_fake_mirror", "", [0])
	verify(t, "迷宫里那面奇怪的镜子：其实是失窃的小画像", GameState.has_flag(PalaceWardrobe.PORTRAIT_FLAG) and GameState.inventory.has("lost_portrait"))
	_calm(t)
	# ---- 王座间：挂回去，只剩三幅小画像醒来
	GameState.set_flag(PalaceThrone.BOSS_FLAG, false)
	GameState.pending_spawn = "from_ante"
	await t.main.change_level(Floors.scene("floor_06_palace_throne"))
	await t._advance_until(func(): return t._level_id() == "floor_06_palace_throne" and not Cutscene.is_playing() and not Dialogue.is_active(), 60.0)
	var th := _room(t, "PalaceThrone") as PalaceThrone
	var sp3 := th.small[3] as PalaceThrone.SmallPortrait
	sp3.revive()
	verify(t, "带着小画像进王座间：挂回空画框，那一幅一直睡着（第二层只剩三幅）", GameState.has_flag(PalaceThrone.PORTRAIT_BACK) and not GameState.inventory.has("lost_portrait")
		and sp3.calm and not sp3.alive())
	GameState.set_flag(PalaceThrone.BOSS_FLAG)
	_calm(t)
	# ---- 人偶舞会
	await _goto(t, "floor_06_palace_ante")
	var an := _room(t, "PalaceAnte") as PalaceAnte
	for g in an.guards:
		(g as PalaceAnte.ArmorGuard).push_down()
		(g as PalaceAnte.ArmorGuard)._t = -9999.0
	GameState.set_flag(PalaceAnte.VAULT_FLAG)
	for i in PalaceAnte.LULLABY_SEQ:
		an.step_tile(i)
	verify(t, "只踩了地砖的舞步：还缺铜钟和吊铃，舞会不开", GameState.has_flag(PalaceAnte.BALL_TILES) and not an.ball_on)
	GameState.set_flag(PalaceAnte.BALL_BELL)
	GameState.set_flag(PalaceAnte.LULLABY)
	an.try_ball()
	await _wait_ball(t, an)
	verify(t, "三处都演奏过摇篮曲：前厅开舞会（第一支舞 %d 个人偶）" % an.dolls_alive(), an.ball_on and an.dolls_alive() == PalaceAnte.BALL_WAVES[0])
	var p2 := GameState.player as PlayableCharacter
	_calm(t)
	var q := (1 if (p2.global_position - an._ball_center()).x >= 0.0 else 0) + (2 if (p2.global_position - an._ball_center()).y >= 0.0 else 0)
	p2.global_position = an._ball_center() + Vector2(-30 if q % 2 == 0 else 30, -30 if q < 2 else 30)
	var bl := p2.laugh.value
	an.beat_q = q
	an.beat_sweep()
	verify(t, "拍子落下：站在红色扇区里被羽毛扫（%.0f → %.0f）" % [bl, p2.laugh.value], p2.laugh.value > bl)
	var mint0 := GameState.inventory.count("mint")
	for w in PalaceAnte.BALL_WAVES.size():
		_calm(t)
		for d in an.dolls:
			if is_instance_valid(d) and (d as Monster).is_alive():
				(d as Monster).health.damage(99)
		for k in 6:
			_calm(t)   # 人偶挠得太凶会让两个人笑倒（= 舞会输了），测试里每帧清一下
			await t.get_tree().process_frame
	await t._wait(0.2)
	verify(t, "三支舞都跳完（打倒人偶）：舞会结束、薄荷糖 ×3（薄荷糖 %d → %d）" % [mint0, GameState.inventory.count("mint")], GameState.has_flag(PalaceAnte.BALL_DONE) and GameState.inventory.count("mint") >= mini(mint0 + 3, ItemDB.get_item("mint").max_stack))
	# 输的那条路：再开一场，倒下 → 小剧场（CG）
	GameState.flags.erase(PalaceAnte.BALL_DONE)
	_calm(t)
	an.start_ball()
	await _wait_ball(t, an)
	an.on_defeat("test")
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:ante_ball_fail") and not CG.is_busy() and not Dialogue.is_active() and not an._defeat_busy, 150.0)
	verify(t, "舞会里倒下：小剧场（CG），舞会停下", GameState.has_flag("cg_seen_theater:ante_ball_fail") and not an.ball_on)
	GameState.set_flag(PalaceAnte.BALL_DONE)
	_calm(t)


static func _wait_ball(t: Node, an: PalaceAnte) -> void:
	await t._advance_until(func():
		_calm(t)
		return an.ball_wave == 0 and not Cutscene.is_playing(), 60.0)


## 密道入口没走过之前不显示标志 / 黄字；反省篇的可交互点近处浮出交互键
static func _exit_hints(t: Node) -> void:
	GameState.flags.erase(LevelExit.passage_flag("floor_06_palace_ante", "floor_06_palace_tunnels"))
	var sec: Node = null
	for nd in t.get_tree().root.find_children("*", "Area2D", true, false):
		if nd is LevelExit and (nd as LevelExit)._dst_id() == "floor_06_palace_tunnels":
			sec = nd
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	var lbl: Node = sec.get_node_or_null("MarkerLabel") if sec else null
	verify(t, "前厅画后面的密道口：没走过 → 不显示标志和黄字", sec != null and lbl != null and not (lbl as CanvasItem).visible
		and not (sec.get_node("Marker") as CanvasItem).visible)
	GameState.set_flag(LevelExit.passage_flag("floor_06_palace_tunnels", "floor_06_palace_ante"))
	await t.get_tree().process_frame
	verify(t, "从密道那边走过一次：标志和黄字出现", lbl != null and (lbl as CanvasItem).visible)
	var hint: InteractHint = null
	for nd in t.get_tree().root.find_children("*", "Node2D", true, false):
		if nd is InteractHint and is_instance_valid((nd as InteractHint).target) and (nd as InteractHint).target.enabled \
				and (nd as InteractHint).target.is_visible_in_tree() and not (nd as InteractHint).target.get_parent() is PlayableCharacter:
			hint = nd
			break
	var p := GameState.player as PlayableCharacter
	if hint == null:
		verify(t, "前厅里有交互键提示", false)
		return
	var back := p.global_position
	p.global_position = hint.target.global_position + Vector2(0, 60)
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	verify(t, "走到 5 格以内：头顶浮出交互键", hint.visible)
	p.global_position = hint.target.global_position + Vector2(0, 300)
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	verify(t, "走远了：交互键提示消失", not hint.visible)
	p.global_position = back


## 第四章（下）：王座前厅 → 钟楼 → 隧道与密室 → 王座间 Boss
static func _palace_c(t: Node) -> void:
	GameState.vars.erase(PalaceTunnels.REAL_VAR)
	# ---- 钟楼（五层，一层一张图）
	GameState.pending_spawn = "from_ante"
	await t.main.change_level(Floors.scene("floor_06_palace_clock_1"))
	await t._advance_until(func(): return t._level_id() == "floor_06_palace_clock_1" and not Cutscene.is_playing() and t.seen_cuts.has("palace_clock_in"), 60.0)
	var cr := _room(t, "PalaceClock") as PalaceClock
	await t.get_tree().process_frame
	verify(t, "钟楼一层·齿轮间：两人同行", cr != null and Duo.active and cr.floor_no == 1)
	if cr == null:
		return
	var cp := GameState.player as PlayableCharacter
	var mate := Duo.partner_of(cp)
	mate.global_position = Vector2(-9999, -9999)
	# 发条挠痒虫：齿轮缝里爬出来一批；发条转完自己停下
	var nb := cr.release_beetles(0)
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	verify(t, "一层·齿轮缝里爬出发条挠痒虫（%d 只）" % nb, nb >= 3 and cr.beetles.filter(func(b): return is_instance_valid(b) and (b as Node).is_inside_tree()).size() == nb)
	var bt := cr.beetles[0] as ClockBeetle
	bt.wind_left = 0.01
	await t._wait(0.3)
	verify(t, "发条转完：虫子自己翻倒停下", is_instance_valid(bt) and bt.stopped())
	_quiet_beetles(cr)
	cr.t = PalaceClock.GEAR_CYCLE * 0.8
	cp.global_position = Cutscene.cell_to_world(cr.cells("gear_gaps")[0])
	cr._tick_gear(cp, 0.05)
	verify(t, "齿轮合上时站在缝里：卡住脚踝", cp.status.is_rooted())
	cp.status.clear_root()
	mate.global_position = Cutscene.cell_to_world(cr.cells("brake")[0])
	verify(t, "搭档站上刹车：齿轮停了（缝不会合上）", cr.braked() and not cr.gear_closed())
	verify(t, "AI 搭档的目标：刹车（另一个人还没过齿轮）", (cr.ai_hooks() as BattleAIHooks).objective_for(mate) == Cutscene.cell_to_world(cr.cells("brake")[0]))
	cp.global_position = Cutscene.cell_to_world(cr.cells("up")[0])
	await t._advance_until(func(): return t._level_id() == "floor_06_palace_clock_2" and not Cutscene.is_playing(), 30.0)
	verify(t, "一层北边的楼梯：上到二层（%s）" % t._level_id(), t._level_id() == "floor_06_palace_clock_2")
	cr = _room(t, "PalaceClock") as PalaceClock
	await t.get_tree().process_frame
	cp = GameState.player as PlayableCharacter
	cr.t = 0.0
	cp.global_position = Vector2(cr.pend_x(), Cutscene.cell_to_world(cr.cells("pendulum")[0]).y)
	var cl0 := cp.laugh.value
	for i in 10:
		cr._tick_pendulum(cp, 0.1)
	verify(t, "二层·钟摆的羽毛扫到桥上的人（%.0f → %.0f）" % [cl0, cp.laugh.value], cp.laugh.value > cl0)
	await t._talk("floor_06/clock_chest_2", "", [0])
	verify(t, "二层的小宝箱：守钟人的怀表", GameState.inventory.has("equip_clock_watch"))
	cp.global_position = Cutscene.cell_to_world(cr.cells("up")[0])
	await t._advance_until(func(): return t._level_id() == "floor_06_palace_clock_3" and not Cutscene.is_playing(), 30.0)
	cr = _room(t, "PalaceClock") as PalaceClock
	await t.get_tree().process_frame
	verify(t, "三层也有发条挠痒虫的齿轮缝（%d 处）" % cr.cells("beetle_nests").size(), cr.cells("beetle_nests").size() == 3)
	_quiet_beetles(cr)
	cp = GameState.player as PlayableCharacter
	var wt := 0.0
	while cr.wind_dir(0) == 0.0 and wt < 10.0:
		cr.t += 0.5
		wt += 0.5
	cp.global_position = Cutscene.cell_to_world(cr.cells("bellows")[0]) + Vector2(4, 0)
	var wx := cp.global_position.x
	cr._tick_wind(cp, 0.2)
	verify(t, "三层·风箱吹着走（%.1f → %.1f）" % [wx, cp.global_position.x], not is_equal_approx(cp.global_position.x, wx))
	cp.global_position = Cutscene.cell_to_world(cr.cells("ladder")[0])
	await t._wait(0.5)
	verify(t, "梯子还没放下来：上不去四层", t._level_id() == "floor_06_palace_clock_3")
	var gear_spots := cr.get_children().filter(func(n): return n is PrisonOddities.Spot and n.dialogue == "floor_06/clock_axle" \
		and (n as Node2D).global_position.distance_to(Cutscene.cell_to_world(cr.cells("gear_seat")[0])) < 4.0)
	verify(t, "三层·大齿轮本身也能按 E（以前只有转轴能点）", gear_spots.size() == 1)
	cp.global_position = Cutscene.cell_to_world(cr.cells("axle")[0]) + Vector2(0, 12)
	await t._talk("floor_06/clock_axle", "", [0])
	await t._advance_until(func(): return GameState.has_flag(PalaceClock.LADDER_FLAG) and not CG.is_busy() and not Dialogue.is_active(), 150.0)
	verify(t, "挂在齿轮上（CG）：梯子放下来", GameState.has_flag("cg_seen_theater:clock_gear_ride") and GameState.has_flag(PalaceClock.LADDER_FLAG))
	(GameState.player as Node2D).global_position = Cutscene.cell_to_world(cr.cells("ladder")[0])
	await t._advance_until(func(): return t._level_id() == "floor_06_palace_clock_4" and not Cutscene.is_playing(), 30.0)
	verify(t, "爬梯子上到四层·回廊（%s）" % t._level_id(), t._level_id() == "floor_06_palace_clock_4")
	cr = _room(t, "PalaceClock") as PalaceClock
	await t.get_tree().process_frame
	cp = GameState.player as PlayableCharacter
	mate = Duo.partner_of(cp)
	cp.global_position = Cutscene.cell_to_world(Vector2i(40, 35))
	mate.global_position = cp.global_position + Vector2(10, 0)
	cr._tick_chase(0.05)
	await t._advance_until(func(): return t.seen_cuts.has("clock_keeper_wake") and not Cutscene.is_playing(), 30.0)
	verify(t, "离开梯子口：守钟人偶醒了、开始追", cr.chase_on and t.seen_cuts.has("clock_keeper_wake"))
	cr._wait = 0.0
	cr.keeper_s = cr.progress(cp.global_position)
	cr._tick_chase(0.01)
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:clock_caught") and not CG.is_busy() and not cr._defeat_busy, 150.0)
	verify(t, "被守钟人偶追上：小剧场 → 回检查点、重新追（%d 次）" % cr.caught_count, cr.caught_count == 1 and cr.keeper_s == 0.0)
	cr._wait = 0.0
	cp.global_position = cr.path_at(cr.gate_s(0) + 40.0)
	mate.global_position = cp.global_position
	cr._tick_chase(0.01)
	verify(t, "跑过闸门：闸门落下挡住人偶", cr.gates_closed.has(0))
	cp.global_position = cr.path_at(cr.path_len() - 5.0)
	mate.global_position = cp.global_position
	cr._tick_chase(0.01)
	verify(t, "跑到上钟顶的楼梯口：甩掉守钟人偶", GameState.has_flag(PalaceClock.KEEPER_FLAG) and not cr.chase_on)
	# 大钟面：时针「三」、分针「九」（训练场日志 + 婴儿房刻痕）→ 暗格
	for f in [PalaceClock.CLOCKFACE_FLAG, "palace_sheet_1", PalaceRoom.badge_flag("clockface")]:
		GameState.flags.erase(f)
	await t._talk("floor_06/clock_face", "", [0, 0])
	verify(t, "四层·大钟面拨错：弹出羽毛，暗格没开（钟面有 1~12 共 %d 个选项）" % t.last_options.size(),
		not GameState.has_flag(PalaceClock.CLOCKFACE_FLAG) and t.last_options.size() == 12)
	await t._talk("floor_06/clock_face", "", [2, 8])
	verify(t, "大钟面拨到三点四十五分：暗格开了 → 乐谱片① + 笑脸徽记", GameState.has_flag(PalaceClock.CLOCKFACE_FLAG)
		and GameState.has_flag("palace_sheet_1") and GameState.has_flag(PalaceRoom.badge_flag("clockface")))
	cp.global_position = Cutscene.cell_to_world(cr.cells("up")[0])
	await t._advance_until(func(): return t._level_id() == "floor_06_palace_clock_5" and not Cutscene.is_playing(), 30.0)
	verify(t, "楼梯上到钟顶（%s）" % t._level_id(), t._level_id() == "floor_06_palace_clock_5")
	# 从钟顶下来：追逐已经结束，人偶不再追
	GameState.pending_spawn = "from_above"
	await t.main.change_level(Floors.scene("floor_06_palace_clock_4"))
	await t._advance_until(func(): return t._level_id() == "floor_06_palace_clock_4" and not Cutscene.is_playing(), 30.0)
	var cr4 := _room(t, "PalaceClock") as PalaceClock
	(GameState.player as Node2D).global_position = Cutscene.cell_to_world(cr4.cells("start")[0]) + Vector2(0, -80)
	await t._wait(0.5)
	verify(t, "上过钟顶再回四层：守钟人偶不再追", not cr4.chase_on)
	GameState.pending_spawn = "from_below"
	await t.main.change_level(Floors.scene("floor_06_palace_clock_5"))
	await t._advance_until(func(): return t._level_id() == "floor_06_palace_clock_5" and not Cutscene.is_playing(), 30.0)
	await t.get_tree().process_frame
	await t._talk("floor_06/clock_rope", "", [0])
	await t._advance_until(func(): return GameState.has_flag(PalaceClock.BELLS_FLAG) and not Cutscene.is_playing() and not Dialogue.is_active(), 90.0)
	verify(t, "两个人一起拉钟绳：十三下（背景大图）→ 王座间的封印松了", GameState.has_flag(PalaceClock.BELLS_FLAG) and t.seen_cuts.has("clock_bells"))
	# ---- 隧道与密室
	GameState.pending_spawn = "from_ante"
	await t.main.change_level(Floors.scene("floor_06_palace_tunnels"))
	await t._advance_until(func(): return t._level_id() == "floor_06_palace_tunnels" and not Cutscene.is_playing(), 60.0)
	var tu := _room(t, "PalaceTunnels") as PalaceTunnels
	await t.get_tree().process_frame
	verify(t, "隧道：%d 张蛛网、收路费的栅栏挡着" % (tu.webs_alive() if tu else 0), tu != null and tu.webs_alive() == 4 and not tu.toll_paid())
	if tu == null:
		return
	var tlv := t.get_tree().get_first_node_in_group("main").get("level") as Node
	var gx := tu.cells("toll")[0].x
	var open_rows: Array = []
	for y in 60:
		if GridPath.walkable(tlv, Vector2i(gx, y)):
			open_rows.append(y)
	verify(t, "从前厅进来：出生点离栅栏够远，不会一进门就被拦（%.0f > %.0f）" % [GameState.player.global_position.distance_to(tu.toll_pos()), PalaceTunnels.TOLL_R],
		GameState.player.global_position.distance_to(tu.toll_pos()) > PalaceTunnels.TOLL_R and not Dialogue.is_active())
	verify(t, "收路费的栅栏在必经之路上：x=%d 这一列只有栅栏挡着的 %s 能走（南边的环路绕不过去）" % [gx, open_rows],
		open_rows == [28, 29, 30] and is_instance_valid(tu._toll_body))
	var up := GameState.player as PlayableCharacter
	var umate := Duo.partner_of(up)
	var pinkc: PlayableCharacter = up if up.character_id == "pink" else umate
	var w0 := tu.webs[1] as PalaceTunnels.WebView
	var other := umate if pinkc == up else up
	other.global_position = w0.position
	tu.web_stuck[other] = 0.0
	tu._process(0.05)
	verify(t, "碰到羽毛蛛网：粘住", other.status.is_rooted())
	other.status.clear_root()
	pinkc.global_position = w0.position + Vector2(16, 0)
	pinkc._set_state(PlayableCharacter.State.ATTACK)
	tu._process(0.05)
	pinkc._set_state(PlayableCharacter.State.IDLE)
	verify(t, "粉色公主攻击蛛网：烧掉（剩 %d 张）" % tu.webs_alive(), tu.webs_alive() == 3)
	await t._talk("floor_06/tunnel_toll", "", [2])
	await t._advance_until(func(): return tu.toll_paid() and not CG.is_busy() and not Dialogue.is_active(), 150.0)
	verify(t, "没钱付路费：用痒付（CG）→ 栅栏拆了", tu.toll_paid() and GameState.has_flag("cg_seen_theater:tunnel_toll"))
	up.global_position = Cutscene.cell_to_world(tu.cells("to_library")[0]) + Vector2(0, 20)
	tu._process(0.05)
	verify(t, "走到图书馆那边的密道口：那边的入口打开了（抄近路）", GameState.has_flag("palace_secret_library"))
	var real := tu.real_chest()
	var fake := 1 if real != 1 else 2
	var mint0 := GameState.inventory.count("mint")
	await t._talk("floor_06/tunnel_chest_%d" % fake, "", [0])
	verify(t, "打开宝箱怪：咬住脚踝（定身）", tu.mimic_bites == 1 and (GameState.player as PlayableCharacter).status.is_rooted())
	(GameState.player as PlayableCharacter).status.clear_root()
	await t._talk("floor_06/tunnel_chest_%d" % real, "", [0])
	verify(t, "真的宝箱：薄荷糖 +2", GameState.inventory.count("mint") == mint0 + 2)
	await t._talk("floor_06/tunnel_quilt", "", [0])
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:tunnel_quilt") and not CG.is_busy() and not Dialogue.is_active(), 150.0)
	verify(t, "女王寝室：羽毛被子把两个人卷起来（CG）", GameState.has_flag("cg_seen_theater:tunnel_quilt"))
	await t._talk("floor_06/tunnel_cradle", "", [0])
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:tunnel_cradle") and not CG.is_busy() and not Dialogue.is_active(), 150.0)
	await t._talk("floor_06/tunnel_mobile", "")
	verify(t, "婴儿房：摇篮小手的小剧场、旋转吊铃的摇篮曲", GameState.has_flag("cg_seen_theater:tunnel_cradle") and GameState.has_flag("palace_lullaby_heard"))
	# ---- 王座间
	GameState.pending_spawn = "from_ante"
	await t.main.change_level(Floors.scene("floor_06_palace_throne"))
	await t._advance_until(func(): return t._level_id() == "floor_06_palace_throne" and not Cutscene.is_playing() and t.seen_cuts.has("palace_throne_in"), 60.0)
	var th := _room(t, "PalaceThrone") as PalaceThrone
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	verify(t, "王座间：大画像、四幅小画像", th != null and th.small.size() == 4)
	if th == null:
		return
	var bp := GameState.player as PlayableCharacter
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	verify(t, "王座间：顶上有 Boss 血条（%s，%.0f%%）" % [th.boss_name(), th.boss_ratio() * 100.0],
		th._bar_on and th.boss_name().contains("第一层") and is_equal_approx(th.boss_ratio(), 1.0))
	var px0 := th.portrait_pos()
	th._slide_dir = 1.0
	th._tick_move(1.0)
	var px1 := th.portrait_pos()
	verify(t, "第一层：大画像沿北墙滑动（x %.0f → %.0f，y 不变），破绽跟着走（在画像正下方）" % [px0.x, px1.x],
		px1.x > px0.x and is_equal_approx(px1.y, px0.y) and is_equal_approx(th.weak_point().x, px1.x) and th.weak_point().y > px1.y + 40.0)
	await t.get_tree().process_frame
	var hk := th.ai_hooks()
	verify(t, "AI 搭档：优先打破绽标记（跟着画像走），不再傻站在固定点", hk.priority_target() == th._weak and hk.objective_for(bp) == null
		and th._weak.position.distance_to(th.weak_point()) < 1.0)
	var im := th.spawn_imp(bp.global_position + Vector2(8, 0))
	await t.get_tree().process_frame
	im._rise = 0.0
	im._cool = 0.0
	var il0 := bp.laugh.value
	im.step(0.05)
	verify(t, "颜料小人：从颜料里冒出来，追到人就挥小刷子挠腰（%.0f → %.0f）" % [il0, bp.laugh.value], bp.laugh.value > il0)
	verify(t, "AI 搭档也会去打离得近的颜料小人", hk.nearest_enemy(bp, 150.0) == im)
	bp._set_state(PlayableCharacter.State.ATTACK)
	th._hit_cool.clear()
	th._tick_hits(0.05)
	bp._set_state(PlayableCharacter.State.IDLE)
	verify(t, "颜料小人一下就打掉（碎成一滩颜料）", im.is_queued_for_deletion())
	var far := Duo.partner_of(bp)
	if far:
		far.global_position = th.weak_point() + Vector2(0, 150)
		var sh := th.stretch(far)
		await t.get_tree().process_frame
		verify(t, "伸长的手：先出预警线（AI 会躲）", sh.phase == "warn" and sh.is_in_group("danger"))
		far.global_position = sh.position   # （测试：搭档离玩家太远会被拉回身边，这里放回原位）
		var g0 := far.global_position.distance_to(th.weak_point())
		for k in 40:
			if far.status.is_grabbed_by(sh):
				break
			sh._process(0.05)
		verify(t, "然后手顺着地面伸过去：抓住远处的人", far.status.is_grabbed_by(sh) and sh.phase == "drag")
		for k in 10:
			sh._process(0.1)
		verify(t, "抓住以后拖回破绽前挠（离破绽 %.0f → %.0f）" % [g0, far.global_position.distance_to(th.weak_point())],
			far.global_position.distance_to(th.weak_point()) < g0 - 30.0)
		far.status.release()
		sh._process(0.05)
		verify(t, "挣开了就松手、缩回去", sh.phase == "back")
		sh._end()
	var pool := th.spawn_pool(bp.global_position)
	pool.t = PalaceThrone.POOL_WARN + 0.1
	th._tick_paint(0.05)
	verify(t, "颜料坑：先预警再变成颜料，踩进去脚底沾颜料（画笔追着刷）", th.painted.has(bp) and pool.is_in_group("danger"))
	th.hit(5)
	th.on_defeat("both_down")
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:throne_fail_paint") and not CG.is_busy() and not th._defeat_busy, 150.0)
	verify(t, "第一层两个都倒下：被涂成画（CG）→ 回入口、这一层回满（%d）" % th.hp, th.hp == PalaceThrone.LAYER_HP[0])
	verify(t, "战败小剧场按层不同（第二层茶会 / 第三层变强画框 / 画像小手）", (func():
		th.layer = 1
		var a := th.defeat_theater()
		th.layer = 2
		th.empowered = true
		var b := th.defeat_theater()
		th.empowered = false
		var c := th.defeat_theater()
		th.layer = 0
		return [a, b, c] == ["throne_fail_tea", "throne_fail_frame", "throne_fail"]).call())
	th.hit(PalaceThrone.LAYER_HP[0])
	await t._advance_until(func(): return th.layer == 1 and t.seen_cuts.has("throne_layer_1") and not Cutscene.is_playing(), 60.0)
	verify(t, "第一层画布破了：胡话 → 第二层（小画像醒了，大画像没有破绽）", th.layer == 1 and not th.vulnerable() and th.small.all(func(s): return (s as PalaceThrone.SmallPortrait).alive()))
	verify(t, "第二层：Boss 血条换成「第二层画布」", th.boss_name().contains("第二层") and is_equal_approx(th.boss_ratio(), 1.0))
	var fp0 := th.portrait_pos()
	for k in 10:
		th._tick_move(0.3)
	verify(t, "第二层：大画像离开墙面、飘起来慢慢追人（%.0f,%.0f → %.0f,%.0f），破绽在它脚下" % [fp0.x, fp0.y, th.portrait_pos().x, th.portrait_pos().y],
		th.portrait_pos().distance_to(fp0) > 20.0 and th._portrait.hover_to > 0.0 and th.weak_point().distance_to(th.portrait_pos()) < 20.0)
	var s0 := th.small[0] as PalaceThrone.SmallPortrait
	for k in 10:
		s0._process(0.2)
	verify(t, "小画像醒来：从墙上飞下来追人（离墙 %.0f）" % s0.position.distance_to(s0.home), s0.position.distance_to(s0.home) > 10.0)
	s0.sleep()
	for k in 40:
		s0._process(0.2)
	verify(t, "小画像被打掉：飞回墙上睡觉", s0.position.distance_to(s0.home) < 2.0)
	s0.revive()
	for s in th.small:
		for k in PalaceThrone.SMALL_HP:
			(s as PalaceThrone.SmallPortrait).hurt()
	bp.global_position = (th.small[0] as Node2D).position
	th.vuln_t = 0.0
	th._hit_cool.clear()
	if th.small.all(func(x): return not (x as PalaceThrone.SmallPortrait).alive()):
		th.vuln_t = PalaceThrone.VULN_TIME
	verify(t, "小画像全打掉：大画像露出破绽", th.vulnerable())
	th.hit(PalaceThrone.LAYER_HP[1])
	await t._advance_until(func(): return th.layer == 2 and t.seen_cuts.has("throne_layer_2") and not Cutscene.is_playing(), 60.0)
	await t._advance_until(func(): return th.inside != null, 10.0)
	var inner := th.inside
	var mid := Cutscene.cell_to_world(th.cells("arena")[0])
	for k in 20:
		th._tick_move(0.3)
	verify(t, "第三层：大画像飘到场地中央转圈（离中心 %.0f）" % th.portrait_pos().distance_to(mid), th.portrait_pos().distance_to(mid) <= PalaceThrone.ORBIT_R + 6.0)
	await t.get_tree().process_frame
	verify(t, "被拉进画里：画面加上水彩滤镜", is_instance_valid(th._water) == (GameState.player == inner))
	verify(t, "第三层：被拉进画里（在画里的世界）", inner != null and inner.global_position.distance_to(Cutscene.cell_to_world(th.cells("paint_start")[0])) < 30.0)
	if inner == null:
		return
	inner.laugh.set_value(inner.laugh.max_value)
	th._process(0.05)
	await t._advance_until(func(): return th.empowered and not CG.is_busy() and not Dialogue.is_active(), 150.0)
	verify(t, "画里没逃出来：被困在画里（CG）→ 画框变强、换外面的人操控", th.empowered and GameState.has_flag("cg_seen_theater:throne_painting_trapped") and GameState.player != inner)
	th.hit(PalaceThrone.FRAME_HP)
	await t._advance_until(func(): return Cutscene.chapter_screen.visible and not Cutscene.is_playing(), 120.0)
	verify(t, "打破变强的画框：她出来 → 两人各释放一次烧穿画布 → 另半枚徽章 →「%s」" % Cutscene.chapter_title.text,
		GameState.has_flag(PalaceThrone.BOSS_FLAG) and t.seen_cuts.has("throne_finale") and t.seen_cuts.has("palace_end") and Cutscene.chapter_title.text.contains("旧王宫"))
	verify(t, "徽记台换过发饰 + 王座间通关：先看女王的回忆（背景大图）", t.seen_cuts.has("palace_queen_memory") and GameState.has_flag(PalaceRoom.MEMORY_FLAG))
	Cutscene.chapter_screen.hide()
	Cutscene.chapter_next = ""
	# 画里自己逃出来（另一条路）：重新进王座间，直接到第三层
	GameState.set_flag(PalaceThrone.BOSS_FLAG, false)
	GameState.set_flag("cg_seen_theater:throne_escape", false)
	GameState.pending_spawn = "from_ante"
	await t.main.change_level(Floors.scene("floor_06_palace_throne"))
	await t._advance_until(func(): return t._level_id() == "floor_06_palace_throne" and not Cutscene.is_playing(), 60.0)
	var th2 := _room(t, "PalaceThrone") as PalaceThrone
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	th2.layer = 2
	th2.pull()
	var esc := th2.inside
	verify(t, "（重来）被拉进画里", esc != null)
	if esc:
		var b0 := th2.brushes[0] as PalaceThrone.Brush
		b0.position = esc.global_position
		b0._cool = 0.0
		var el0 := esc.laugh.value
		b0.step(0.05)
		verify(t, "画里的画笔碰到人：闷笑涨、被弹开", esc.laugh.value > el0)
		esc.global_position = Cutscene.cell_to_world(th2.cells("paint_exit")[0])
		th2._process(0.05)
		await t._advance_until(func(): return Cutscene.chapter_screen.visible and not Cutscene.is_playing(), 120.0)
		verify(t, "在画里跑到画框出口：逃出画的小剧场 → 两人各释放一次 → 胜利", GameState.has_flag("cg_seen_theater:throne_escape") and GameState.has_flag(PalaceThrone.BOSS_FLAG))
	Cutscene.chapter_screen.hide()
	Cutscene.chapter_next = ""


static func _room(t: Node, cls: String) -> Node:
	for nd in t.get_tree().root.find_children("*", "", true, false):
		if nd.get_script() and str(nd.get_script().get_global_name()) == cls:
			return nd
	return null




## 第四轮：道具提示、前厅搭档闲逛 + 提示、选项页滚动
static func _round4(t: Node) -> void:
	_calm(t)
	await _goto(t, "floor_06_palace_ante")
	var an := _room(t, "PalaceAnte") as PalaceAnte
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	var lead := GameState.player as PlayableCharacter
	var mate := Duo.partner_of(lead)
	verify(t, "前厅：搭档不跟随、自己闲逛（roam），还能走过去说话", mate != null and mate.roam and mate.partner_talk == PalaceAnte.HINT_FILE)
	if mate == null:
		return
	var wt: Variant = an.ai_hooks().objective_for(mate)
	var mid := an.world(an._tile_origin + Vector2i(1, 1))
	verify(t, "闲逛点（%s）不在地砖上、走过去的路不穿过地砖" % str(wt), wt is Vector2 and (wt as Vector2).distance_to(mid) > 40.0
		and Geometry2D.get_closest_point_to_segment(mid, mate.global_position, wt).distance_to(mid) >= PalaceAnte.TILE_CLEAR - 0.1)
	var tp0 := an.tile_progress
	mate.global_position = mid
	an._process(0.05)
	verify(t, "搭档路过地砖：不算踩（只认玩家操控的那个）", an.tile_progress == tp0 and not an._last_cell.has(mate.get_instance_id()))
	mate.global_position = an.world(PalaceAnte.WANDER[0])
	var ks := an.hint_keys()
	verify(t, "搭档的提示按进度挑（现在：%s）" % str(ks), not ks.is_empty() and (ks as Array).all(func(k): return PalaceAnte.HINT_FILE != "" and str(k) != ""))
	GameState.vars["ante_hint"] = str(ks[0])
	var said := []
	var cb := func(f: String, n: String): said.append(n)
	Dialogue.runner.node_entered.connect(cb)
	await t._talk(PalaceAnte.HINT_FILE, "")
	Dialogue.runner.node_entered.disconnect(cb)
	verify(t, "和搭档说话：说一句「%s」的提示（%s）" % [ks[0], str(said)], said.size() == 1 and str(said[0]).begins_with(str(ks[0])))
	# 道具提示：拿到笑脸徽记（之前没提示过）→ 等对话空下来弹一小段
	GameState.set_flag(PalaceRoom.item_hint_flag("smile_badge"), false)
	var hs := []
	var cb2 := func(f: String, n: String): hs.append(f + ":" + n)
	Dialogue.runner.node_entered.connect(cb2)
	await t._advance_until(func(): return hs.has(PalaceRoom.ITEM_HINT_FILE + ":smile_badge") and not Dialogue.runner.is_running(), 10.0)
	Dialogue.runner.node_entered.disconnect(cb2)
	verify(t, "拿到跨图道具（笑脸徽记）：弹出一小段提示说用处，只弹一次", hs.has(PalaceRoom.ITEM_HINT_FILE + ":smile_badge")
		and GameState.has_flag(PalaceRoom.item_hint_flag("smile_badge")) and not PalaceRoom.pending_item_hints().has("smile_badge"))
	# 选项页：12 个选项 → 只显示 6 个，选到下面会滚动，每次打开从最上面开始
	var cm := Dialogue.runner.choice_menu
	var opts := []
	for i in 12:
		opts.append("选项 %d" % (i + 1))
	cm.ask(opts, "滚动测试")
	await t.get_tree().process_frame
	var shown0 := cm.box.get_children().filter(func(c): return c is Label and (c as Label).text.contains("选项")).size()
	cm.selected = 9
	cm._refresh()
	await t.get_tree().process_frame
	var top9 := cm.top
	cm.choose(0)
	cm.ask(opts, "")
	await t.get_tree().process_frame
	verify(t, "选项太多：一次只显示 %d 个，选到第 10 个滚到 top=%d，重新打开从最上面开始（top=%d）" % [shown0, top9, cm.top],
		shown0 == ChoiceMenu.MAX_SHOWN and top9 == 4 and cm.top == 0)
	cm.choose(0)
	await t.get_tree().process_frame


## 第四轮·后花园：暗门（石像告诉你）、秋千、天使喷泉的水路、凉亭宝箱、花园小店主和小水壶、花丛里的小精灵
static func _garden(t: Node) -> void:
	_calm(t)
	for k in PalaceRoom.ITEM_HINTS:   # 前面有测试重置过标记：道具提示照样先当作提示过
		GameState.set_flag(PalaceRoom.item_hint_flag(k))
	for f in [PalaceGarden.FLOW_FLAG, PalaceGarden.GAZEBO_FLAG, PalaceGarden.KEEPER_ASKED, PalaceGarden.KEEPER_DONE, "palace_can_taken",
			"cg_seen_theater:garden_swing", "cg_seen_theater:garden_petals", "intro_done_palace_garden_in"]:
		GameState.set_flag(f, false)
	if GameState.inventory.has("watering_can"):
		GameState.inventory.remove("watering_can", 1)
	await _goto(t, "floor_06_palace_ante")
	var an := _room(t, "PalaceAnte") as PalaceAnte
	var lvn := t.get_tree().get_first_node_in_group("main").get("level") as Node
	var gex: LevelExit = null
	for e in lvn.find_children("*", "", true, false):
		if e is LevelExit and str((e as LevelExit).target_level).contains("palace_garden"):
			gex = e
	verify(t, "前厅东北角有通往后花园的暗门（secret，要石像的线索）", gex != null and gex.secret and gex.unlock_flag == PalaceGarden.GARDEN_CLUE)
	verify(t, "石像三问全对以后：知道了后花园的门（%s）" % PalaceGarden.GARDEN_CLUE, GameState.has_flag(PalaceGarden.GARDEN_CLUE))
	GameState.pending_spawn = "from_ante"
	await t.main.change_level(Floors.scene(PalaceGarden.MAP))
	await t._advance_until(func(): return (t._level_id() == PalaceGarden.MAP and GameState.has_flag("intro_done_palace_garden_in")
		and not Cutscene.is_playing() and not Dialogue.is_active()), 60.0)
	var gd := _room(t, "PalaceGarden") as PalaceGarden
	await t.get_tree().process_frame
	verify(t, "后花园：秋千、三尊小天使、凉亭、花园小店主、小精灵（%d 只）" % t.get_tree().get_nodes_in_group("enemy").size(),
		gd != null and gd.dirs.size() == 3 and t.get_tree().get_nodes_in_group("enemy").size() >= 3)
	if gd == null:
		return
	_clear_enemies(t)
	verify(t, "喷泉一开始是干的、凉亭宝箱打不开", not gd.flowing() and not gd.open_gazebo())
	# 秋千
	await t._talk("floor_06/garden_swing", "", [0])
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:garden_swing") and not CG.is_busy() and not Dialogue.is_active(), 120.0)
	verify(t, "双人秋千：一个坐一个推，藤蔓挠脚心（小剧场）", GameState.has_flag("cg_seen_theater:garden_swing"))
	# 转错：被水喷脚底
	var p := GameState.player as PlayableCharacter
	var c0 := gd.cells("cherubs")[0]
	p.global_position = gd.world(c0) + Vector2(0, 16)
	p.laugh.clear()
	var wrong_once := false
	var guard := 0
	while not gd.flowing() and guard < 20:
		guard += 1
		for i in gd.dirs.size():
			if int(gd.dirs[i]) != gd._right_dir(gd.cells("cherubs")[i]):
				p.global_position = gd.world(gd.cells("cherubs")[i]) + Vector2(0, 16)
				var l0 := p.laugh.value
				gd.turn(i)
				p.status.clear_root()
				if int(gd.dirs[i]) != gd._right_dir(gd.cells("cherubs")[i]) and p.laugh.value > l0:
					wrong_once = true
				break
	verify(t, "转到错误方向：水柱喷到脚底", wrong_once)
	verify(t, "三尊小天使都对准喷泉：水路接通（转了 %d 下）" % guard, gd.flowing())
	await t._talk("floor_06/garden_gazebo", "")
	await t._advance_until(func(): return not Dialogue.is_active() and not Cutscene.is_playing(), 10.0)
	verify(t, "凉亭的宝箱：水车转起来，开了", GameState.has_flag(PalaceGarden.GAZEBO_FLAG))
	# 花园小店主 → 厨房的小水壶 → 浇花
	await t._talk("floor_06/garden_keeper", "")
	verify(t, "花园小店主：想浇花，水壶在厨房", GameState.has_flag(PalaceGarden.KEEPER_ASKED) and not GameState.has_flag(PalaceGarden.KEEPER_DONE))
	await _goto(t, "floor_06_palace_kitchen")
	await t._talk("floor_06/kitchen_watering_can", "")
	verify(t, "厨房水槽边：拿到小水壶", GameState.inventory.has("watering_can"))
	GameState.pending_spawn = "from_ante"
	await t.main.change_level(Floors.scene(PalaceGarden.MAP))
	await t._advance_until(func(): return t._level_id() == PalaceGarden.MAP and not Cutscene.is_playing() and not Dialogue.is_active(), 60.0)
	_clear_enemies(t)
	await t._talk("floor_06/garden_keeper", "")
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:garden_petals") and not CG.is_busy() and not Dialogue.is_active(), 120.0)
	verify(t, "带着水壶回去浇花：花瓣谢礼（小剧场）→ 线索", GameState.has_flag(PalaceGarden.KEEPER_DONE) and GameState.has_flag("cg_seen_theater:garden_petals")
		and not GameState.inventory.has("watering_can"))


static func _clear_enemies(t: Node) -> void:
	for e in t.get_tree().get_nodes_in_group("enemy"):
		if e is Monster and (e as Monster).is_alive():
			(e as Monster).health.damage(999)
	_calm(t)

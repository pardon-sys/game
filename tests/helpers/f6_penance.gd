extends RefCounted
## 反省篇第一章（--penance-only）：骑士篇尾声接医务帐篷 → 吵架 → 反省牢房（六件道具的小剧场 → 墙缝里的挠脚鼠）
## → 换上鼠鼠装、钻进墙缝 → 章末画面 → 鼠鼠装脱下还原；鼠鼠装的效果（攻击 ×0.8、乱窜暴击涨魔力疲倦、鼠味引怪）。
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
	verify(t, "答应挠脚鼠：换上鼠鼠装（%s）→ 钻墙缝 → 章末「第一章　反省牢房　完」（%s）" % [wore["v"], Cutscene.chapter_title.text],
		wore["v"] and t.seen_cuts.has("penance_crawl") and Cutscene.chapter_title.text.contains("反省牢房") and Cutscene.chapter_next == "floor_06_after_house")
	verify(t, "章末以后：鼠鼠装脱下、原来的装备还回来（第二章还没做）", GameState.has_flag(PenanceCell.DONE_FLAG) and not PenanceCell.wearing_mouse()
		and Equipment.worn("pink").get("sole", "") == "equip_dance_shoes")
	Cutscene.chapter_screen.hide()
	Cutscene.chapter_next = ""

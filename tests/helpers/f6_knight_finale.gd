extends RefCounted
## 骑士篇 E~G 专项：第二天早上和营地楼梯口的队员说话 → 诅咒失控 → 镇中追逃（信标、盔甲追、栅栏、冻住、被抱住轻挠和挣脱、抓三次失败）→ Boss「痒铠骑士」
## （冻住才打得动、护腿跺完卡住、笑面打不动、符文圈共鸣净化）→ 尾声（半枚徽章、「骑士篇 完」）。
static var checks := 0


static func verify(t: Node, label: String, ok: bool) -> void:
	checks += 1
	t.check(label, ok)


static func task(t: Node, id: String) -> Node:
	return t._node("Task_" + id)


static func run(t: Node) -> void:
	checks = 0
	for f in ["after_started", "penance_book", "f6_opening_done", AfterFestival.FINALE_DONE, "blue_tickle_pants"]:
		GameState.set_flag(f)
	GameState.vars[TaskArmorChase.LIT_KEY] = 0
	GameState.vars[TaskArmorChase.CAUGHT_KEY] = 0
	GameState.vars[TaskKnightBoss.PHASE_KEY] = 0
	GameState.vars[TaskKnightBoss.CAUGHT_KEY] = 0
	verify(t, "骑士篇后半的步骤：%s" % [KnightStory.STEPS.map(func(s): return s["id"]).slice(7)],
		KnightStory.STEPS.map(func(s): return s["id"]).slice(7) == ["report", "chase", "boss"])
	KnightStory.jump("report")
	GameState.pending_spawn = "from_house"
	await t.main.change_level(Floors.scene(AfterStory.TOWN))
	await t._wait(0.8)
	var gc := t._node("after_k_guard_camp") as Node2D
	verify(t, "第二天早上：白天的小镇（%s），营地楼梯口的队员头上冒「！」" % t._level_id(), t._level_id() == KnightStory.KDAY
		and gc != null and gc.get_node_or_null("ErrandMark") != null and not t.seen_cuts.has("knight_erupt"))
	await t._talk("floor_06/after_k_guard_camp", "")
	await t._advance_until(func(): return task(t, "chase") != null and bool(task(t, "chase").started) and not Cutscene.is_playing() and not GameState.in_dialogue, 60.0)
	var ch := task(t, "chase") as TaskArmorChase
	verify(t, "和楼梯口的队员说话 → 诅咒失控 → 盔甲冲出营地，追逃开始", ch != null and t.seen_cuts.has("knight_erupt") and t.seen_cuts.has("knight_chase_open"))
	if ch == null:
		return
	verify(t, "追逃在骑士篇专用的空小镇上（%s），一个镇民都没有" % t._level_id(), t._level_id() == KnightStory.KCHASE
		and t.main.level.find_children("*", "Resident", true, false).is_empty())
	ch.ai_enabled = false
	var pink := ch.pink
	verify(t, "开局：两人在楼梯口附近，盔甲先在楼梯口挣扎一会儿", ch.armor.stun_left > 0.0
		and pink.global_position.distance_to(Cutscene.cell_to_world(TaskArmorChase.PINK_START)) < 8.0)
	ch.armor.stun_left = 0.0
	var d0 := ch.armor.global_position.distance_to(pink.global_position)
	for i in 10:
		await t.get_tree().physics_frame
	verify(t, "盔甲朝她追过来（%.0f → %.0f）" % [d0, ch.armor.global_position.distance_to(pink.global_position)],
		ch.armor.global_position.distance_to(pink.global_position) < d0)
	ch.armor.sweep_now()
	verify(t, "铁手横扫：先亮预警线（danger 组）", ch.armor.warn_left > 0.0 and not t.get_tree().get_nodes_in_group("danger").is_empty())
	# 被抱住：轻挠、疲倦涨得快
	ch.safe_left = 0.0
	pink.laugh.set_value(0.0)
	pink.fatigue.set_value(0.0)
	ch.grab()
	for i in 20:
		ch.advance(0.05)
	verify(t, "被盔甲抱住：挠得很轻（闷笑 %.1f），疲倦涨得快（%.1f）" % [pink.laugh.value, pink.fatigue.value],
		ch.grabbing and pink.fatigue.value > pink.laugh.value and TaskArmorChase.caught() == 1)
	for i in TaskArmorChase.MASH:
		ch.mash()
	verify(t, "连按 J：挣开，马上能动（定身解开了）", not ch.grabbing and not pink.status.is_rooted())
	verify(t, "没被操控的蓝色公主由 AI 控制（%s）" % ch.blue.controller, ch.blue.controller is KnightAI)
	# AI 蓝色公主：盔甲追着粉色公主、她在旁边 → 冻住
	ch.ai_enabled = true
	ch.armor.stun_left = 0.0
	ch.armor.freeze_left = 0.0
	ch.freeze_cool = 0.0
	ch.armor.global_position = ch.pink.global_position + Vector2(40, 0)
	ch.blue.global_position = ch.armor.global_position + Vector2(-20, 6)
	ch.ai_plan(ch.blue)
	verify(t, "AI 蓝色公主：盔甲靠近粉色公主 → 冷却好了就冻住它", ch.armor.freeze_left > 0.0 and ch.freeze_cool > 0.0)
	ch.armor.freeze_left = 0.0
	ch.freeze_cool = 0.0
	ch.blue.global_position = ch.armor.global_position + Vector2(90, 40)
	var plan_b := ch.ai_plan(ch.blue)
	verify(t, "AI 蓝色公主：离得远 → 冲过去拦", plan_b.has("to") and bool(plan_b.get("dash", false)))
	# 换成蓝色公主：粉色公主由 AI 控制，背着盔甲跑
	GameState.switch_control(ch.blue)
	await t._wait(0.1)
	verify(t, "按 C 换成蓝色公主：粉色公主由 AI 控制", ch.pink.controller is KnightAI and ch.blue.controller is PlayerInputController)
	ch.armor.global_position = ch.pink.global_position + Vector2(30, 0)
	var plan_p := ch.ai_plan(ch.pink)
	verify(t, "AI 粉色公主：盔甲靠近 → 往反方向跑", plan_p.has("to") and (plan_p["to"] as Vector2).x < ch.pink.global_position.x)
	GameState.switch_control(ch.pink)
	await t._wait(0.1)
	ch.ai_enabled = false
	ch.freeze_cool = 0.0
	ch.armor.freeze_left = 0.0
	# 蓝色公主冻住
	GameState.switch_control(ch.blue)
	await t._wait(0.2)
	ch.armor.global_position = ch.blue.global_position + Vector2(20, 0)
	verify(t, "蓝色公主 J：冻住盔甲（有冷却）", ch.freeze() and ch.armor.freeze_left > 0.0 and not ch.freeze())
	GameState.switch_control(pink)
	await t._wait(0.2)
	# 栅栏
	var g := ch.gates[0] as TaskArmorChase.Gate
	ch.armor.global_position = g.global_position + Vector2(10, 0)
	pink.global_position = g.global_position + Vector2(-120, 0)
	ch.advance(0.05)
	verify(t, "镇民关上栅栏挡住盔甲", g.closed_left > 0.0 and g.collision_layer == 1)
	# 信标
	ch.light(0)
	verify(t, "点亮第一座信标：盔甲被光晃了一下", TaskArmorChase.lit() == 1 and (ch.beacons[0] as TaskArmorChase.Beacon).lit and ch.armor.stun_left > 0.0)
	# 抓三次失败
	GameState.vars[TaskArmorChase.CAUGHT_KEY] = 2
	ch.safe_left = 0.0
	ch.grab()
	await t._advance_until(func(): return GameState.has_flag("cg_seen_theater:knight_fail_chase") and task(t, "chase") != null and bool(task(t, "chase").started) and not CG.is_busy(), 60.0)
	ch = task(t, "chase") as TaskArmorChase
	verify(t, "被抓三次：失败小剧场 → 重来（点亮的信标还亮着）", GameState.has_flag("cg_seen_theater:knight_fail_chase") and ch != null
		and TaskArmorChase.lit() == 1 and TaskArmorChase.caught() == 0)
	if ch == null:
		return
	verify(t, "重来以后粉色公主马上能动（没有残留的抱住定身）", not ch.pink.status.is_rooted())
	ch.light(1)
	ch.light(2)
	ch.armor.paused = true
	ch.pink.global_position = Cutscene.cell_to_world(TaskArmorChase.PLAZA)
	ch.advance(0.05)
	await t._advance_until(func(): return task(t, "boss") != null and bool(task(t, "boss").started) and not Cutscene.is_playing() and not GameState.in_dialogue, 60.0)
	var b := task(t, "boss") as TaskKnightBoss
	verify(t, "三座信标亮了、引到广场 → Boss「痒铠骑士」开始（铁手套两只、场上 %d 个人）" % (b.victims.size() if b else 0), b != null
		and t.seen_cuts.has("knight_boss_open") and b.phase == 0 and b.parts.size() == 2 and b.victims.size() >= 5)
	if b == null:
		return
	pink = b.pink
	b.curse_t = 999.0
	for v in b.victims:
		v.cursed = false
	verify(t, "Boss 战：没被操控的蓝色公主由 AI 控制；C 键能换人", b.blue.controller is KnightAI
		and InputMap.action_get_events("switch_character").any(func(e): return e is InputEventKey and e.physical_keycode == KEY_C))
	var a0: TaskKnightBoss.BossPart = b.parts[0]
	b.freeze_cool = 0.0
	b.blue.global_position = a0.global_position + Vector2(0, 20)
	b.ai_plan(b.blue)
	verify(t, "AI 蓝色公主：走到没冻住的部件旁边 → 冻住", a0.freeze_left > 0.0)
	var hk := (b.blue.controller as KnightAI).hooks
	verify(t, "冻住的部件成了 AI 的优先目标", hk != null and hk.priority_target() == a0)
	a0.freeze_left = 0.0
	b.freeze_cool = 0.0
	GameState.switch_control(b.blue)
	await t._wait(0.1)
	var plan_bp := b.ai_plan(b.pink)
	verify(t, "换成蓝色公主：AI 粉色公主贴近本体（让出招变慢）", b.pink.controller is KnightAI and plan_bp.has("to")
		and (plan_bp["to"] as Vector2).distance_to(b._body.global_position) < TaskKnightBoss.SOFT_R)
	b.grab(b.pink)
	await t._advance_until(func(): return b.grabbed == null, 3.0)
	verify(t, "AI 粉色公主被抓：自己连按挣开（%d 下）" % b.mashes, b.grabbed == null and b.mashes >= TaskKnightBoss.MASH)
	b.ai_enabled = false
	GameState.vars[TaskKnightBoss.CAUGHT_KEY] = 0
	GameState.switch_control(b.pink)
	await t._wait(0.1)
	b.attack_t = 999.0
	a0.hp = TaskKnightBoss.PART_HP
	a0.freeze_left = 0.0
	b.freeze_cool = 0.0
	# ---- 救人
	var vic: KnightBossFx.Victim = b.curse_victim(b.victims[0])
	verify(t, "手印贴上了被挠倒的队员", vic.cursed)
	pink.global_position = vic.global_position + Vector2(8, 0)
	b.freeze_cool = 3.0
	Input.action_press("interact")
	for i in 30:
		b.advance(0.05)
	Input.action_release("interact")
	verify(t, "走到身边按住 E 一秒：救下来 → 冻结冷却马上好、队员替她挡一次（%s）" % [vic.cursed], not vic.cursed and b.freeze_cool == 0.0 and b.shield == 1)
	b.grab(pink)
	verify(t, "下一次扑抓：被救的队员冲上来挡掉了", b.grabbed == null and b.shield == 0)
	var vic2: KnightBossFx.Victim = b.curse_victim(b.victims[1])
	vic2.cursed_t = TaskKnightBoss.ENRAGE_AFTER + 1.0
	b.advance(0.05)
	verify(t, "被手印贴着超过 %d 秒没人管：诅咒变强（出招变快）" % int(TaskKnightBoss.ENRAGE_AFTER), b.enraged)
	b.blue.global_position = vic2.global_position + Vector2(10, 0)
	b.freeze_part(b.blue)
	verify(t, "蓝色公主冻一下也能救人 → 不再变强", not vic2.cursed and not b.enraged)
	b.shield = 0
	# ---- 阶段一：铁手套的新招
	b.flick(pink)
	var bolts: Array = b.fx.filter(func(n): return n is KnightBossFx.Bolt)
	verify(t, "弹指：三发扇形", bolts.size() == 3)
	pink.laugh.set_value(0.0)
	pink.global_position = bolts[1].global_position + bolts[1].vel.normalized() * 6.0
	b.advance(0.02)
	verify(t, "弹指打中：小挠一下（闷笑 %.1f）" % pink.laugh.value, pink.laugh.value > 0.0)
	b.net(pink)
	var cells: Array = b.fx.filter(func(n): return n is KnightBossFx.NetCell)
	verify(t, "十指痒网：脚下 3×3 的预警格（%d）" % cells.size(), cells.size() == 9 and cells.all(func(c): return c.is_in_group("danger")))
	pink.laugh.set_value(0.0)
	await t._wait(1.4)
	verify(t, "格子里冒出指头：站在里面会被挠（闷笑 %.1f）" % pink.laugh.value, pink.laugh.value > 0.0)
	# 抓人：粉色轻、蓝色狠
	b.grab(b.blue)
	var bl0 := b.blue.laugh.value
	for i in 10:
		b.advance(0.05)
	var blue_gain := b.blue.laugh.value - bl0
	for i in TaskKnightBoss.MASH:
		b.mash()
	b.grab(pink)
	var pl0 := pink.laugh.value
	for i in 10:
		b.advance(0.05)
	var pink_gain := pink.laugh.value - pl0
	for i in TaskKnightBoss.MASH:
		b.mash()
	verify(t, "铁手套抓住蓝色公主狠挠（+%.1f），抓住粉色公主很轻（+%.1f）" % [blue_gain, pink_gain], blue_gain > pink_gain * 2.0)
	GameState.vars[TaskKnightBoss.CAUGHT_KEY] = 0
	# ---- 反击：冻住打碎 → 破绽 → 挠骑士 → 清醒
	var p0: TaskKnightBoss.BossPart = b.parts[0]
	verify(t, "没冻住的部件打不动", not b.hit_part(p0) and p0.hp == TaskKnightBoss.PART_HP)
	GameState.switch_control(b.blue)
	await t._wait(0.2)
	b.blue.global_position = p0.global_position + Vector2(10, 0)
	b.freeze_cool = 0.0
	verify(t, "蓝色公主 J：冻住身边的部件", b.freeze_part(b.blue) and p0.freeze_left > 0.0)
	for i in TaskKnightBoss.PART_HP:
		b.hit_part(p0)
	verify(t, "冻住以后打三下：左铁手套碎了 → 露出破绽（手腕）", p0.broken and b.weak_left > 0.0 and is_instance_valid(b.weak_spot)
		and b.weak_spot.spot == "手腕")
	verify(t, "破绽成了 AI 的优先目标", hk.priority_target() == b.weak_spot)
	for i in 4:
		b.tickle_knight()
	verify(t, "打破绽 = 挠骑士：骑士的笑满了 → 清醒（所有部件不冻也打得动）", b.lucid_left > 0.0 and b.weak_left <= 0.0)
	var p1: TaskKnightBoss.BossPart = b.parts[1]
	for i in TaskKnightBoss.PART_HP:
		b.hit_part(p1)
	await t._advance_until(func(): return b.phase == 1 and not b.transitioning, 30.0)
	verify(t, "两只铁手套都碎了 → 换阶段的过场（演示新招、提示玩法）→ 阶段二：护腿", b.phase == 1 and t.seen_cuts.has("knight_boss_p1") and b.parts.size() == 2)
	GameState.switch_control(pink)
	await t._wait(0.2)
	b.attack_t = 999.0
	# ---- 阶段二：护腿
	b.stomp()
	pink.global_position = b._body.global_position + Vector2(40, 0)
	pink.laugh.set_value(0.0)
	for i in 30:
		b.advance(0.05)
	verify(t, "跺地：痒波碰到她（闷笑 %.0f），跺完卡住露出膝盖窝" % pink.laugh.value, pink.laugh.value > 0.0 and b.weak_left > 0.0)
	b.stuck_left = 0.0
	b._close_weak()
	pink.global_position = b._body.global_position + Vector2(0, 80)
	b.blue.global_position = b._body.global_position + Vector2(-100, 0)
	b.charge(b.blue)
	verify(t, "冲撞：先亮预警线", str(b.warn.get("kind", "")) == "charge")
	var body0: Vector2 = b._body.global_position
	for i in 40:
		b.advance(0.05)
		if b.stuck_left > 0.0:
			break
	verify(t, "冲过去（%.0f 像素）→ 撞完卡住，护腿不冻也打得动" % b._body.global_position.distance_to(body0),
		b._body.global_position.distance_to(body0) > 20.0 and b.stuck_left > 0.0 and b.parts.all(func(x): return b._soft(x)))
	if b.grabbed:
		b._release_grab()
	b.sand(pink)
	var dust: Array = b.fx.filter(func(n): return n is KnightBossFx.Dust)
	pink.global_position = dust[0].global_position
	pink.laugh.set_value(0.0)
	for i in 10:
		b.advance(0.05)
	verify(t, "踢沙：三团痒尘，站在里面闷笑慢慢涨（%.1f）" % pink.laugh.value, dust.size() == 3 and pink.laugh.value > 0.0)
	b.stuck_left = 2.0
	for part in b.parts.duplicate():
		for i in TaskKnightBoss.PART_HP:
			b.hit_part(part)
	await t._advance_until(func(): return b.phase == 2 and not b.transitioning, 30.0)
	verify(t, "护腿碎了 → 过场 → 阶段三：胸甲", b.phase == 2 and t.seen_cuts.has("knight_boss_p2") and b.parts.all(func(x): return x.id.begins_with("plate")))
	b.attack_t = 999.0
	# ---- 阶段三：胸甲
	b.throw_gear(pink)
	var gb: Array = b.fx.filter(func(n): return n is KnightBossFx.Bolt and n.icon != null)
	verify(t, "诅咒穿戴：甩出一件痒痒装备（带装备图标）", gb.size() == 1)
	pink.global_position = gb[0].global_position + gb[0].vel.normalized() * 6.0
	b.advance(0.02)
	verify(t, "甩中了：穿到她身上（%s）" % [pink.get_meta(&"knight_gear").item_id if pink.has_meta(&"knight_gear") else ""], pink.has_meta(&"knight_gear"))
	pink.laugh.set_value(0.0)
	for i in 10:
		b.advance(0.05)
	verify(t, "穿着的时候一直挠（闷笑 %.1f）" % pink.laugh.value, pink.laugh.value > 0.0)
	for i in TaskKnightBoss.GEAR_TEARS:
		b.tear_gear(pink)
	verify(t, "自己连按 J：挣掉了", not pink.has_meta(&"knight_gear"))
	b.wear_gear(pink, "equip_t_thigh_ring")
	b.ai_enabled = true
	b.blue.global_position = pink.global_position + Vector2(8, 0)
	for i in 30:
		b.advance(0.05)
		if not pink.has_meta(&"knight_gear"):
			break
	b.ai_enabled = false
	verify(t, "搭档站在身边（按住 E）：扯下来了（距离 %.0f，进度 %.2f，操控 %s）" % [b.blue.global_position.distance_to(pink.global_position),
		pink.get_meta(&"knight_gear").pull if pink.has_meta(&"knight_gear") else 1.0, GameState.player.name], not pink.has_meta(&"knight_gear"))
	pink.global_position = b._body.global_position + Vector2(70, 0)
	b.blue.global_position = b._body.global_position + Vector2(-200, 0)
	var dm0: float = pink.global_position.distance_to(b._body.global_position)
	b.magnet()
	for i in 10:
		b.advance(0.05)
	verify(t, "护心磁吸：把她往中间吸（%.0f → %.0f）" % [dm0, pink.global_position.distance_to(b._body.global_position)],
		pink.global_position.distance_to(b._body.global_position) < dm0 - 10.0)
	b.magnet_left = 0.0
	b.shards()
	verify(t, "甲片飞散：六片", b.fx.filter(func(n): return n is KnightBossFx.Shard).size() == TaskKnightBoss.SHARDS)
	GameState.vars[TaskKnightBoss.CAUGHT_KEY] = 0
	if b.grabbed:
		b._release_grab()
	for part in b.parts.duplicate():
		part.freeze_left = 4.0
		for i in TaskKnightBoss.PART_HP:
			b.hit_part(part)
	await t._advance_until(func(): return b.phase == 3 and not b.transitioning, 30.0)
	verify(t, "胸甲碎了 → 过场 → 阶段四：笑面", b.phase == 3 and t.seen_cuts.has("knight_boss_p3"))
	b.attack_t = 999.0
	# ---- 阶段四：笑面
	verify(t, "笑面打不动", not b.hit_part(b.parts[0]))
	b.mirrors()
	verify(t, "镜面笑脸：三张", b.fx.filter(func(n): return n is KnightBossFx.Mirror).size() == TaskKnightBoss.MIRRORS)
	b.name_call()
	verify(t, "呼唤骑士之名：冲击波 + 露出脖子", b.fx.any(func(n): return n is KnightBossFx.Ring) and b.weak_left > 0.0 and b.weak_spot.spot == "脖子")
	for i in 4:
		b.tickle_knight()
	b.advance(0.05)
	verify(t, "挠满骑士的笑：笑面撑不住 → 符文圈马上亮起来", b.resonance)
	pink.global_position = Cutscene.cell_to_world(TaskKnightBoss.RUNES[0])
	b.blue.global_position = Cutscene.cell_to_world(TaskKnightBoss.RUNES[1])
	pink.laugh.set_value(pink.laugh.max_value * 0.5)
	b.blue.laugh.set_value(b.blue.laugh.max_value * 0.5)
	verify(t, "两人都站进符文圈", b.in_runes())
	b.meter.charge = 0.98
	b.advance(0.5)
	await t._advance_until(func(): return Cutscene.chapter_screen.visible and not Cutscene.is_playing(), 90.0)
	verify(t, "共鸣充满 → 光柱净化笑面 → 尾声（半枚徽章）→「骑士篇 完」", t.seen_cuts.has("knight_epilogue") and Cutscene.chapter_title.text.contains("骑士篇"))
	Cutscene.continue_chapter()
	await t._advance_until(func(): return t._level_id() == AfterStory.HOUSE and not Cutscene.chapter_screen.visible, 20.0)
	verify(t, "按 E 回小屋；骑士篇这一段结束（%s）" % KnightStory.objective(AfterStory.HOUSE).get("text", ""),
		t._level_id() == AfterStory.HOUSE and KnightStory.step().is_empty())

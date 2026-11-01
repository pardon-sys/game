extends RefCounted
## 骑士篇 E~G 专项：第二天早上和营地楼梯口的队员说话 → 诅咒失控 → 镇中追逃（栅栏是支线「夜里的栅栏」装的、队长替她挡一次）（信标、盔甲追、栅栏、冻住、被抱住轻挠和挣脱、抓三次失败）→ Boss「痒铠骑士」
## （冻住才打得动、护腿跺完卡住、笑面打不动、符文圈共鸣净化）→ 尾声（半枚徽章、「骑士篇 完」）。
static var checks := 0


static func verify(t: Node, label: String, ok: bool) -> void:
	checks += 1
	t.check(label, ok)


static func task(t: Node, id: String) -> Node:
	return t._node("Task_" + id)


static func run(t: Node) -> void:
	checks = 0
	for f in ["after_started", "penance_book", "f6_opening_done", AfterFestival.FINALE_DONE, "blue_tickle_pants", "kq_fence_done"]:
		GameState.set_flag(f)
	for q in ["shoes", "samples", "spear"]:
		GameState.set_flag("kq_%s_done" % q, false)
	GameState.vars[TaskArmorChase.LIT_KEY] = 0
	GameState.vars[TaskArmorChase.CAUGHT_KEY] = 0
	GameState.vars[TaskKnightBoss.PHASE_KEY] = 0
	GameState.vars[TaskKnightBoss.CAUGHT_KEY] = 0
	# 机制介绍过场：老的用例里关掉（下面专门测一次）
	TaskKnightBoss.intros = false
	verify(t, "骑士篇后半的步骤：%s" % [KnightStory.STEPS.map(func(s): return s["id"]).slice(7)],
		KnightStory.STEPS.map(func(s): return s["id"]).slice(7) == ["report", "chase", "boss", "boss_fog"])
	KnightStory.jump("report")
	GameState.pending_spawn = "from_house"
	await t.main.change_level(Floors.scene(AfterStory.TOWN))
	await t._wait(0.8)
	var gc := t._node("after_k_captain") as Node2D
	verify(t, "第二天早上：白天的小镇（%s），地牢入口的保卫队队长头上冒「！」" % t._level_id(), t._level_id() == KnightStory.KDAY
		and gc != null and gc.get_node_or_null("ErrandMark") != null and not t.seen_cuts.has("knight_erupt"))
	await t._talk("floor_06/after_k_captain", "")
	await t._advance_until(func(): return task(t, "chase") != null and bool(task(t, "chase").started) and not Cutscene.is_playing() and not GameState.in_dialogue, 60.0)
	var ch := task(t, "chase") as TaskArmorChase
	verify(t, "和保卫队队长说话 → 诅咒失控 → 盔甲冲出营地，追逃开始", ch != null and t.seen_cuts.has("knight_erupt") and t.seen_cuts.has("knight_chase_open"))
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
	verify(t, "做过支线「夜里的栅栏」：三道栅栏（%d）；镇民关上栅栏挡住盔甲" % ch.gates.size(), ch.gates.size() == 3 and g.closed_left > 0.0 and g.collision_layer == 1)
	# 队长替她挡一次（支线「队长的旧剑术」）
	ch.captain_block = 1
	ch.safe_left = 0.0
	var c0 := TaskArmorChase.caught()
	ch.grab()
	verify(t, "做过支线「队长的旧剑术」：队长替她挡下一次抱住", not ch.grabbing and TaskArmorChase.caught() == c0 and ch.captain_block == 0)
	ch.safe_left = 0.0
	# 冲刺无敌的时候抓不住
	ch.armor.stun_left = 0.0
	ch.armor.freeze_left = 0.0
	ch.armor.paused = false
	pink.dash(Vector2.RIGHT)
	ch.armor.global_position = pink.global_position
	await t.get_tree().physics_frame
	verify(t, "冲刺无敌的时候盔甲抓不住", not ch.grabbing)
	await t._wait(0.5)
	# 信标
	ch.light(0)
	verify(t, "点亮第一座信标：盔甲被光晃了一下", TaskArmorChase.lit() == 1 and (ch.beacons[0] as TaskArmorChase.Beacon).lit and ch.armor.stun_left > 0.0)
	# 四座信标分在镇上各处、彼此隔得远；目标提示指向下一座
	var far := true
	for i in TaskArmorChase.BEACONS.size():
		for j in i:
			far = far and Vector2(TaskArmorChase.BEACONS[i]).distance_to(Vector2(TaskArmorChase.BEACONS[j])) >= 18.0
	verify(t, "四座信标、彼此至少隔 18 格", TaskArmorChase.BEACONS.size() == 4 and far)
	var mk := t._node("Objective") as ObjectiveMarker
	await t._wait(0.2)
	var obj := KnightStory.objective(KnightStory.KCHASE)
	verify(t, "目标提示指向第二座信标（%s）" % [obj.get("cell")], obj.get("cell", []) == [TaskArmorChase.BEACONS[1].x, TaskArmorChase.BEACONS[1].y] and mk != null)
	# 扔陷阱：落点先有影子，落地变成地牢里的陷阱；第一次扔这一种，粉色公主吐槽；到时间收走
	var said: Array = []
	var on_said := func(text: String, _t2: float): said.append(text)
	GameState.princess_reacted.connect(on_said)
	ch.armor.stun_left = 0.0
	ch.throw_left = 999.0
	var th := ch.throw_trap("snare", pink.global_position + Vector2(48, 0))
	verify(t, "盔甲扔出绳套：落点先亮影子", th != null and is_instance_valid(th))
	await t._wait(TaskArmorChase.THROW_FLY + 0.3)
	var landed: Array = ch.traps.filter(func(x): return str(x.get("kind", "")) == "snare")
	verify(t, "落地变成倒吊绳套（SnareTrap）", landed.size() == 1 and landed[0]["node"] is SnareTrap)
	verify(t, "第一次扔绳套：粉色公主吐槽（%s）" % [said], said.any(func(x): return str(x).contains("绳套")))
	said.clear()
	ch.throw_trap("snare", pink.global_position + Vector2(-48, 0))
	await t._wait(TaskArmorChase.THROW_FLY + 0.3)
	verify(t, "再扔一样的：不再吐槽", not said.any(func(x): return str(x).contains("绳套")))
	GameState.princess_reacted.disconnect(on_said)
	for kind in TaskArmorChase.THROWS:
		if kind != "snare":
			ch.land(kind, pink.global_position + Vector2(0, 120))
	verify(t, "八种陷阱都落得下来（%d 个）" % ch.traps.size(), ch.traps.filter(func(x): return x.has("kind")).size() == 9)
	for x in ch.traps:
		x["left"] = 0.0
	pink.global_position += Vector2(0, -60)
	ch._trap_tick(0.1)
	await t._wait(0.1)
	verify(t, "到时间：地上的陷阱收走（还剩 %d）" % ch.traps.size(), ch.traps.is_empty())
	# 扔得更勤、更多、会预判
	verify(t, "扔陷阱的间隔：开局 %.1f 秒 → 全亮 %.1f 秒" % [TaskArmorChase.THROW_EVERY, TaskArmorChase.THROW_FAST],
		is_equal_approx(ch.throw_interval(), lerpf(TaskArmorChase.THROW_EVERY, TaskArmorChase.THROW_FAST, float(TaskArmorChase.lit()) / 4.0)) and TaskArmorChase.THROW_FAST < TaskArmorChase.THROW_EVERY)
	pink.velocity = Vector2(80, 0)
	var aims: Array = ch.aim_points()
	verify(t, "预判：落点在她前进方向的前面（%.0f 像素）" % (aims[0].x - pink.global_position.x), aims[0].x > pink.global_position.x + 40.0)
	GameState.vars[TaskArmorChase.LIT_KEY] = 3
	verify(t, "亮了 3 座：一次扔 3 个（第二个拦在去下一座信标的路上）", ch.aim_points().size() == 3)
	GameState.vars[TaskArmorChase.LIT_KEY] = 1
	pink.velocity = Vector2.ZERO
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
	for i in range(1, TaskArmorChase.BEACONS.size()):
		ch.light(i)
	verify(t, "四座都亮了：目标提示指回广场", KnightStory.objective(KnightStory.KCHASE).get("cell", []) == [TaskArmorChase.PLAZA.x, TaskArmorChase.PLAZA.y])
	ch.armor.paused = true
	ch.pink.global_position = Cutscene.cell_to_world(TaskArmorChase.PLAZA)
	ch.advance(0.05)
	await t._advance_until(func(): return Cutscene.current == "story_knight_boss" and Cutscene.is_playing() and Cutscene.backdrop.is_shown(), 40.0)
	verify(t, "Boss 开场演完：背景大图过场「背靠背」（整屏大图 %s）" % Cutscene.backdrop.current, t.seen_cuts.has("knight_boss_open")
		and Cutscene.current == "story_knight_boss" and Cutscene.backdrop.current == "knight_boss")
	await t._advance_until(func(): return task(t, "boss") != null and bool(task(t, "boss").started) and not Cutscene.is_playing() and not GameState.in_dialogue, 60.0)
	verify(t, "大图过场演完收起；剧情回顾里「背靠背」解锁了", not Cutscene.backdrop.is_shown()
		and Backpack.gallery_entries().any(func(e): return e["kind"] == "story" and e["id"] == "story_knight_boss" and e["name"] == "背靠背" and GameState.has_flag(str(e["flag"]))))
	var b := task(t, "boss") as TaskKnightBoss
	verify(t, "四座信标亮了、引到广场 → Boss「痒铠骑士」开始（铁手套两只、场上 %d 个人）" % (b.victims.size() if b else 0), b != null
		and t.seen_cuts.has("knight_boss_open") and b.phase == 0 and b.parts.size() == 2 and b.victims.size() >= 5)
	if b == null:
		return
	pink = b.pink
	b.curse_t = 999.0
	# 老的用例不要自动爆发 / 盯镇民（下面专门测）
	KnightCurse.auto = false
	b.curse.end(true)
	b.curse._end_hunt()
	for v in b.victims:
		v.cursed = false
	verify(t, "Boss 战：没被操控的蓝色公主由 AI 控制；C 键能换人", b.blue.controller is KnightAI
		and InputMap.action_get_events("switch_character").any(func(e): return e is InputEventKey and e.physical_keycode == KEY_C))
	verify(t, "屏幕上方有盔甲耐久条（满的：%.2f）" % b.durability(), is_instance_valid(b._hud) and is_equal_approx(b.durability(), 1.0))
	verify(t, "广场上有 %d 个木箱（另有工匠打的木桩）" % b.crates.size(), b.crates.filter(func(c): return not c.stake).size() == TaskKnightBoss.CRATES.size())
	# ---- 这一轮的修正：Boss 战里不瞬移、右上角显示另一位、挠痒同时涨疲倦（暴击更多）
	verify(t, "Boss 战里两位公主都不跟随瞬移（follow 关掉）", not pink.follow and not b.blue.follow)
	verify(t, "右上角状态面板显示另一位公主（%s）" % (b.partner_panel.partner().display_name() if b.partner_panel and b.partner_panel.partner() else "无"),
		is_instance_valid(b.partner_panel) and b.partner_panel.partner() == (b.blue if GameState.player == pink else pink))
	KnightTickle.no_crit = true
	pink.laugh.set_value(0.0)
	pink.fatigue.clear()
	b._hit(pink, 0.1, "sole")
	var l1 := pink.laugh.value
	var f1 := pink.fatigue.value
	verify(t, "技能命中走普通挠痒流程：闷笑涨（%.1f）、魔力疲倦一起涨（%.1f）" % [l1, f1], l1 > 0.0 and f1 > 0.0)
	pink.laugh.set_value(0.0)
	pink.fatigue.clear()
	pink.forced_specials = 1
	b._hit(pink, 0.1, "sole")
	verify(t, "暴击：闷笑和疲倦都更多（%.1f / %.1f）" % [pink.laugh.value, pink.fatigue.value], pink.laugh.value > l1 * 1.5 and pink.fatigue.value > f1 * 2.5)
	pink.laugh.set_value(0.0)
	pink.fatigue.clear()
	KnightTickle.no_crit = false
	# ---- 盔甲会走（先清掉侧跳 / 预警 / 卡住，不然这几秒可能正在干别的）
	b.ai_enabled = false
	b.attack_t = 999.0
	b._clear_warn()
	b.stuck_left = 0.0
	b._side_left = 0.0
	b._side_t = 99.0
	b.body_mode = "walk"
	pink.global_position = b._body.global_position + Vector2(120, 0)
	var d_walk: float = b._body.global_position.distance_to(pink.global_position)
	for i in 20:
		b.advance(0.05)
	verify(t, "盔甲朝她走过来（%.0f → %.0f），不站在原地（抓着 %s 姿态 %s 卡住 %.1f 冲 %.1f 跳 %.1f 磁 %.1f 预警 %s 爆发 %s 转阶段 %s）" % [d_walk, b._body.global_position.distance_to(pink.global_position),
		b.grabbed != null, b.body_mode, b.stuck_left, b.charge_left, b.leap_left, b.magnet_left, b.warn.get("kind", ""), b.curse.surge if is_instance_valid(b.curse) else "", b.transitioning],
		b._body.global_position.distance_to(pink.global_position) < d_walk - 10.0)
	# ---- 出招前站定发光
	b.attack_t = 0.0
	b.advance(0.01)
	verify(t, "出招前站定发光（%s）—— 攻击的空当" % b.body_mode, b.body_mode == "windup" and b.pending_skill != "")
	var body_w: Vector2 = b._body.global_position
	b.advance(0.1)
	verify(t, "站定的时候不动", b._body.global_position.distance_to(body_w) < 0.5)
	b._clear_field()
	b.body_mode = "walk"
	b.attack_t = 999.0
	if b.grabbed:
		b._release_grab()
	b.curse_t = 999.0
	for v in b.victims:
		v.cursed = false
	verify(t, "Boss 战：没被操控的蓝色公主由 AI 控制；C 键能换人", b.blue.controller is KnightAI
		and InputMap.action_get_events("switch_character").any(func(e): return e is InputEventKey and e.physical_keycode == KEY_C))
	b.ai_enabled = true
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
	# ---- 镇民：乱跑、救人、说话
	var runner: KnightBossFx.Victim = b.victims.filter(func(v): return v.kind == "runner")[0]
	var r0: Vector2 = runner.global_position
	await t._advance_until(func(): return runner.global_position.distance_to(r0) > 2.0, 5.0)
	verify(t, "镇民在掩体之间跑（不沿固定的圈；活动范围大一点：%d 处掩体）" % runner.covers.size(), runner.global_position.distance_to(r0) > 2.0
		and runner.covers.size() == TaskKnightBoss.COVERS.size() + TaskKnightBoss.FAR_COVERS.size())
	runner.state = "hide"
	runner.global_position = b._body.global_position + Vector2(20, 0)
	await t._wait(0.1)
	verify(t, "盔甲靠近：躲着的镇民逃开（%s）" % runner.state, runner.state == "flee")
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
	verify(t, "化简：没有狂暴（被贴久了也不变强）", not b.enraged)
	b.blue.global_position = vic2.global_position + Vector2(10, 0)
	b.freeze_part(b.blue)
	verify(t, "蓝色公主冻一下也能救人", not vic2.cursed)
	var c_before := b.victims.filter(func(x): return is_instance_valid(x) and x.cursed).size()
	for i in 30:
		b._tick_victims(1.0)
	verify(t, "化简：平时不再随机给镇民贴手印", b.victims.filter(func(x): return is_instance_valid(x) and x.cursed).size() == c_before)
	for v in b.victims:
		v.talk_cool = 0.0
		v.helped = false
		v.cursed = false
	var granny: KnightBossFx.Victim = b.victims.filter(func(v): return v.who == "granny")[0]
	pink.laugh.set_value(pink.laugh.max_value * 0.5)
	var lg0 := pink.laugh.value
	verify(t, "化简：和镇民说话只喊一句提示，没有薄荷糖（%s）" % b.talk_to(granny, pink), pink.laugh.value == lg0)
	var guard: KnightBossFx.Victim = b.victims.filter(func(v): return v.who == "guard" and v.kind == "guard")[0]
	b.shield = 0
	verify(t, "化简：队员也不替你挡（%s）" % b.talk_to(guard, pink), b.shield == 0)
	b.shield = 0
	# ---- 冲刺无敌、完美闪避（蓝色公主站远一点，扑抓不会落到她身上）
	b.blue.global_position = pink.global_position + Vector2(-150, 0)
	pink.laugh.set_value(0.0)
	b._warn_grab(pink)
	b.warn["left"] = 0.01
	pink.dash(Vector2.RIGHT)
	b.advance(0.02)
	verify(t, "冲刺无敌：扑抓抓不到", b.grabbed == null)
	await t._wait(0.6)
	GameState.set_flag("kq_spear_done")
	b._close_weak()
	b.blue.global_position = pink.global_position + Vector2(-150, 0)
	b._warn_grab(pink)
	b.warn["left"] = 0.01
	b.warn["at"] = pink.global_position
	pink.dash(Vector2.UP)
	b.advance(0.02)
	verify(t, "学过队长的旧剑术：快打中才冲刺 = 完美闪避，骑士露出破绽", b.grabbed == null and b.weak_left > 0.0)
	GameState.set_flag("kq_spear_done", false)
	b._close_weak()
	await t._wait(0.6)
	# ---- 阶段一：铁手套
	b.flick(pink)
	var bolts: Array = b.fx.filter(func(n): return n is KnightBossFx.Bolt)
	verify(t, "弹指：三发扇形", bolts.size() == 3)
	pink.laugh.set_value(0.0)
	pink.global_position = bolts[1].global_position + bolts[1].vel.normalized() * 6.0
	b.advance(0.02)
	verify(t, "弹指打中：小挠一下（闷笑 %.1f）" % pink.laugh.value, pink.laugh.value > 0.0)
	b.net(pink)
	var cells: Array = b.fx.filter(func(n): return n is KnightBossFx.NetCell)
	verify(t, "十指痒网：脚下 3×3 的预警格（%d），第一次用预警加倍" % cells.size(), cells.size() == 9 and cells.all(func(c): return c.is_in_group("danger"))
		and cells[0].warn >= TaskKnightBoss.GRAB_WARN * TaskKnightBoss.FIRST_SLOW - 0.01)
	pink.laugh.set_value(0.0)
	await t._wait(2.4)
	verify(t, "格子里冒出指头：站在里面会被挠（闷笑 %.1f）" % pink.laugh.value, pink.laugh.value > 0.0)
	b._clear_field()
	KnightTickle.no_crit = true
	KnightTickle.reset()
	b.grab(b.blue)
	var bl0 := b.blue.laugh.value
	for i in 10:
		b.advance(0.05)
	var blue_gain := b.blue.laugh.value - bl0
	for i in TaskKnightBoss.MASH:
		b.mash()
	b.grab(pink)
	pink.fatigue.clear()   # 前面攒满了会在这里触发魔力释放、疲倦归零
	var pl0 := pink.laugh.value
	var pf0 := pink.fatigue.value
	for i in 10:
		b.advance(0.05)
	var pink_gain := pink.laugh.value - pl0
	var pink_fat := pink.fatigue.value - pf0
	for i in TaskKnightBoss.MASH:
		b.mash()
	KnightTickle.no_crit = false
	verify(t, "粉色公主被抱住：闷笑慢、魔力疲倦涨得快（0.5 秒疲倦 +%.1f，原来手写约 +25）" % pink_fat, pink_fat > pink_gain * 2.0 and pink_fat < 60.0)
	verify(t, "铁手套抓住蓝色公主狠挠（+%.1f），抓住粉色公主很轻（+%.1f）" % [blue_gain, pink_gain], blue_gain > pink_gain * 2.0)
	GameState.vars[TaskKnightBoss.CAUGHT_KEY] = 0
	# ---- 诅咒爆发的种类轮换 + 每种第一次出现演介绍过场
	var kinds := {}
	var last := ""
	var no_repeat := true
	for i in 12:
		b.curse.start()
		kinds[b.curse.surge] = true
		if b.curse.surge == last:
			no_repeat = false
		last = b.curse.surge
		b.curse.end(true)
	verify(t, "前三个阶段的爆发在三种里轮换、不连着重复（%s）" % [kinds.keys()], kinds.size() == 3 and kinds.has("hands") and kinds.has("veins") and kinds.has("heart") and no_repeat)
	GameState.set_flag("knight_intro_seen_surge_heart", false)
	TaskKnightBoss.intros = true
	b.curse.start("heart")
	verify(t, "第一次「诅咒核心」：演介绍过场（%s），战斗暂停" % Cutscene.current, Cutscene.is_playing() and Cutscene.current == "knight_intro_surge_heart")
	await t._advance_until(func(): return not Cutscene.is_playing() and not GameState.in_dialogue, 20.0)
	b.curse.end(true)
	b.curse.start("heart")
	verify(t, "第二次：不再演", not Cutscene.is_playing())
	b.curse.end(true)
	TaskKnightBoss.intros = false
	# ---- 诅咒爆发「手印风暴」：打不动、靠近闷笑狂涨、吸到笑声回耐久；三个被贴的镇民都救下来才破
	GameState.switch_control(pink)
	await t._wait(0.2)
	b.attack_t = 999.0
	var cu := b.curse
	for v in b.victims:
		v.cursed = false
	var pa: TaskKnightBoss.BossPart = b.parts[0]
	pa.hp = TaskKnightBoss.PART_HP - 2
	cu.start("hands")
	verify(t, "诅咒爆发（铁手套）：手印风暴，三个镇民被贴上（%d）" % cu.surge_victims.size(), cu.surge == "hands" and cu.surge_victims.size() == 3
		and cu.surge_victims.all(func(v): return v.cursed))
	pa.freeze_left = 4.0
	verify(t, "爆发中：冻住了也打不动", not b.hit_part(pa) and pa.hp == TaskKnightBoss.PART_HP - 2)
	pa.freeze_left = 0.0
	pink.laugh.set_value(0.0)
	pink.global_position = b._body.global_position + Vector2(0, 30)
	for i in 20:
		cu.tick(0.1)
	verify(t, "站在诅咒圈里：闷笑狂涨（%.0f%%），笑声被吸走 → 部件回耐久（%d）" % [pink.laugh.ratio() * 100.0, pa.hp],
		pink.laugh.ratio() > 0.3 and pa.hp > TaskKnightBoss.PART_HP - 2)
	pink.laugh.set_value(0.0)
	for v in cu.surge_victims.duplicate():
		b.rescue(v)
	cu.tick(0.05)
	verify(t, "三个人都救下来：诅咒散了，骑士露出破绽", cu.surge == "" and b.weak_left > 0.0)
	b._close_weak()
	# ---- 化简：盔甲不再自己盯着镇民走；爆发中 AI 不打打不动的部件、去救被贴的人
	verify(t, "化简：盔甲不会自己盯着镇民走（hunt 关掉）", not KnightCurse.hunt_auto)
	cu.start("hands")
	b.ai_enabled = true
	var hkp := b.soft_target()
	var surge_plan := b._ai_move(b.blue)
	verify(t, "手印风暴里：AI 不去打部件（%s），蓝色公主去扒被贴的镇民" % [hkp], hkp == null and (surge_plan.get("hold", false) or surge_plan.has("to")))
	for v in cu.surge_victims.duplicate():
		b.rescue(v)
	cu.tick(0.05)
	b._close_weak()
	b.ai_enabled = false
	pa.hp = TaskKnightBoss.PART_HP
	pink.laugh.set_value(0.0)
	# ---- 反击：冻住打碎 → 破绽 → 挠骑士 → 清醒
	var p0: TaskKnightBoss.BossPart = b.parts[0]
	p0.freeze_left = 0.0
	b.lucid_left = 0.0
	verify(t, "没冻住的部件打不动", not b.hit_part(p0) and p0.hp == TaskKnightBoss.PART_HP)
	GameState.switch_control(b.blue)
	await t._wait(0.2)
	b.blue.global_position = p0.global_position + Vector2(10, 0)
	b.freeze_cool = 0.0
	verify(t, "蓝色公主 J：冻住身边的部件", b.freeze_part(b.blue) and p0.freeze_left > 0.0)
	# 减伤：蓝色公主（非粉色）打一下只算三分之一，三下才掉 1 点；粉色公主一下 1 点
	var hp_before := p0.hp
	b.hit_part(p0, false, b.blue)
	b.hit_part(p0, false, b.blue)
	var after_two := p0.hp
	b.hit_part(p0, false, b.blue)
	verify(t, "非粉色公主打部件只算三分之一：两下不掉（%d）、三下掉 1（%d → %d）" % [after_two, hp_before, p0.hp], after_two == hp_before and p0.hp == hp_before - 1)
	b.hit_part(p0, false, pink)
	verify(t, "粉色公主打一下就掉 1 点（%d）" % p0.hp, p0.hp == hp_before - 2)
	p0.hp = TaskKnightBoss.PART_HP
	p0.chip = 0.0
	p0.freeze_left = 4.0
	var dur0 := b.durability()
	for i in TaskKnightBoss.PART_HP:
		b.hit_part(p0)
	verify(t, "冻住以后打满耐久：左铁手套碎了 → 露出破绽（手腕）、耐久条掉了一段（%.2f → %.2f）" % [dur0, b.durability()], p0.broken and b.weak_left > 0.0
		and is_instance_valid(b.weak_spot) and b.weak_spot.spot == "手腕" and b.durability() < dur0 - 0.05)
	verify(t, "破绽成了 AI 的优先目标", hk.priority_target() == b.weak_spot)
	var p1hp: int = b.parts[1].hp
	for i in 4:
		b.tickle_knight()
	verify(t, "打破绽 = 挠骑士：骑士笑出声 → 直接震碎一截部件（%d → %d，不再有「清醒」）" % [p1hp, b.parts[1].hp],
		b.parts[1].hp <= p1hp - TaskKnightBoss.WEAK_BREAK and b.weak_left <= 0.0)
	var p1: TaskKnightBoss.BossPart = b.parts[1]
	for i in TaskKnightBoss.PART_HP:
		b.hit_part(p1)
	verify(t, "两只铁手套都碎了：场内演出（踉跄，不进过场）", b.transitioning and b.body_mode == "stagger" and not Cutscene.is_playing())
	await t._advance_until(func(): return b.phase == 1 and not b.transitioning, 10.0)
	verify(t, "→ 阶段二：护腿（没黑屏、没有过场）", b.phase == 1 and b.parts.size() == 2 and not t.seen_cuts.has("knight_boss_p1"))
	GameState.switch_control(pink)
	await t._wait(0.2)
	b.attack_t = 999.0
	# ---- 诅咒爆发「痒波地脉」：笑着引它冲撞，撞断三根木桩
	cu.start("veins")
	verify(t, "诅咒爆发（护腿）：地脉 %d 道、镇民搬来 %d 根木桩" % [cu.veins.size(), cu.stakes.size()], cu.surge == "veins"
		and cu.stakes.size() == 3 and cu.veins.size() == KnightCurse.VEINS and cu.stakes.all(func(x): return b.crates.has(x)))
	b._body.global_position = b._home
	var st0: KnightBossFx.Crate = cu.stakes[0]
	st0.global_position = b._body.global_position + Vector2(0, 40)
	pink.global_position = b._body.global_position + Vector2(0, 90)
	cu._lure_cool = 0.0
	KnightLaugh.force_hold = true
	for i in 3:
		cu.tick(0.15)
	KnightLaugh.force_hold = false
	verify(t, "靠近按住 Y 笑：盔甲朝她冲撞（%s；卡住 %.1f 跳 %.1f 冲 %.1f 冷却 %.1f 操控粉色 %s 对话 %s）" % [b.warn.get("kind", ""), b.stuck_left, b.leap_left,
		b.charge_left, cu._lure_cool, GameState.player == pink, GameState.in_dialogue], str(b.warn.get("kind", "")) == "charge")
	if str(b.warn.get("kind", "")) == "charge":
		b.warn["left"] = 0.0
		b._tick_warn(0.01)
	pink.global_position += Vector2(60, 0)
	# 冲撞路线上不能有别人 / 别的木箱（AI 蓝色公主偶尔走到路上会先被抓住）
	b.blue.global_position = b._home + Vector2(-140, -60)
	for c in b.crates:
		if is_instance_valid(c) and c != st0 and absf(c.global_position.x - b._body.global_position.x) < 30.0:
			c.global_position += Vector2(80, 0)
	for i in 30:
		b._tick_charge(0.05)
		if b.stuck_left > 0.0:
			break
	cu.tick(0.05)
	verify(t, "躲开：它撞断了一根木桩、卡住（%d / 3；抓着 %s）" % [cu.stake_hits, b.grabbed.display_name() if b.grabbed else "没人"], cu.stake_hits == 1 and b.stuck_left > 0.0)
	b.stuck_left = 0.0
	for st in cu.stakes:
		if is_instance_valid(st):
			st.smash()
	cu.tick(0.05)
	verify(t, "三根都撞断：地脉碎了", cu.surge == "" and cu.stakes.is_empty() and cu.veins.is_empty())
	b._close_weak()
	# 引怪修好：骑士忙的时候按 Y 不浪费，空下来立刻斜着冲向粉色公主
	b._body.global_position = b._home
	b.stuck_left = 0.0
	b.charge_left = 0.0
	b._clear_warn()
	cu.start("veins")
	b.stuck_left = 1.5
	pink.global_position = b._body.global_position + Vector2(50, 60)
	cu._lure_cool = 0.0
	cu.lure()
	verify(t, "骑士卡住的时候按 Y：先记着（不浪费），还没冲", cu.lure_pending and str(b.warn.get("kind", "")) != "charge")
	b.stuck_left = 0.0
	cu.tick(0.05)
	verify(t, "空下来立刻转向冲她，方向直接对着她（%.2f, %.2f）" % [b.charge_dir.x, b.charge_dir.y], str(b.warn.get("kind", "")) == "charge"
		and not cu.lure_pending and absf(b.charge_dir.x) > 0.1 and absf(b.charge_dir.y) > 0.1)
	verify(t, "地脉爆发时骑士盯着粉色公主走", b._focus() == pink)
	b._clear_warn()
	cu.end(true)
	b._close_weak()
	b._body.global_position = b._home
	b.charge_left = 0.0
	# ---- 阶段二：护腿
	b.stomp()
	pink.global_position = b._body.global_position + Vector2(40, 0)
	pink.laugh.set_value(0.0)
	for i in 30:
		b.advance(0.05)
	verify(t, "跺地：痒波碰到她（闷笑 %.0f），跺完卡住露出膝盖窝" % pink.laugh.value, pink.laugh.value > 0.0 and b.weak_left > 0.0)
	# ---- 召出来的小手：15 秒自己散、蓝色公主的冰晶结界冻住
	var hs: Array = b.hands.filter(func(h): return is_instance_valid(h) and h.state != "gone")
	verify(t, "跺地召出小手（%d 只），都有寿命" % hs.size(), hs.size() == TaskKnightBoss.SUMMON and hs.all(func(h): return h.life > 0.0))
	var h0: CurseHand = hs[0]
	IceBarrier.cast_with(b.blue, 200.0, 3.0, 3, h0.global_position)
	verify(t, "冰晶结界（L）：范围里的小手冻住", h0.state == "frozen")
	for c in [pink, b.blue]:
		c.remove_buff("frost_guard")
	h0.life = 0.05
	await t._wait(0.3)
	verify(t, "到时间：小手自己散了", not is_instance_valid(h0) or h0.state == "gone")
	b.stomp()
	b.stuck_left = 0.0
	var left_before := b.hands.filter(func(h): return is_instance_valid(h) and h.state != "gone").size()
	b._clear_field()
	await t._wait(0.5)
	verify(t, "换阶段清场：小手一只不剩（之前 %d 只）" % left_before, left_before > 0 and b.hands.is_empty() or b.hands.all(func(h): return not is_instance_valid(h) or h.state == "gone"))
	b.wave_left = 0.0
	b.stuck_left = 0.0
	b._close_weak()
	pink.global_position = b._body.global_position + Vector2(0, 80)
	b.leap(pink)
	verify(t, "跳起来砸地：她脚下亮影子", is_instance_valid(b._shadow) and b._shadow.global_position.distance_to(pink.global_position) < 2.0)
	var land: Vector2 = b.leap_to
	pink.global_position = land + Vector2(TaskKnightBoss.LEAP_R + 20.0, 0)
	pink.laugh.set_value(0.0)
	for i in 50:
		b.advance(0.05)
		if b.leap_left <= 0.0:
			break
	verify(t, "盔甲飞过去落在影子上；走出影子就没被砸到（闷笑 %.1f），落地卡住" % pink.laugh.value,
		b._body.global_position.distance_to(land) < 2.0 and pink.laugh.value == 0.0 and b.stuck_left > 0.0)
	b.stuck_left = 0.0
	# 冲撞撞木箱
	var cr: KnightBossFx.Crate = b.crates[0]
	b._body.global_position = cr.global_position + Vector2(60, 0)
	b.blue.global_position = cr.global_position + Vector2(-20, 0)
	pink.global_position = b._body.global_position + Vector2(0, 80)
	b.charge(b.blue)
	verify(t, "冲撞：先亮预警线", str(b.warn.get("kind", "")) == "charge")
	var body0: Vector2 = b._body.global_position
	for i in 40:
		b.advance(0.05)
		if b.stuck_left > 0.0:
			break
	verify(t, "冲过去（%.0f 像素）撞碎木箱 → 卡住，护腿不冻也打得动" % b._body.global_position.distance_to(body0),
		b._body.global_position.distance_to(body0) > 20.0 and b.stuck_left > 0.0 and not b.crates.has(cr) and b.parts.all(func(x): return b._soft(x)))
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
	await t._advance_until(func(): return b.phase == 2 and not b.transitioning, 10.0)
	verify(t, "护腿碎了 → 阶段三：胸甲（场内换阶段）", b.phase == 2 and b.parts.all(func(x): return x.id.begins_with("plate")))
	# ---- 诅咒爆发「护心诅咒」：蓝色公主三秒内冻住两颗心核
	cu.start("heart")
	verify(t, "诅咒爆发（胸甲）：两颗心核绕着胸口转", cu.surge == "heart" and cu.cores.size() == 2)
	GameState.switch_control(b.blue)
	await t._wait(0.2)
	b.blue.global_position = cu.core_pos(cu.cores[0])
	b.freeze_part(b.blue)
	cu.tick(0.05)
	verify(t, "冻住一颗：还不够", float(cu.cores[0]["frozen"]) > 0.0 and cu.surge == "heart")
	b.blue.global_position = cu.core_pos(cu.cores[1])
	b.freeze_part(b.blue)
	cu.tick(0.05)
	verify(t, "三秒内两颗都冻住：护心诅咒碎了", cu.surge == "")
	b._close_weak()
	GameState.switch_control(pink)
	await t._wait(0.2)
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
	verify(t, "化简：搭档站在身边也扯不下来（只能自己连按挣掉）", pink.has_meta(&"knight_gear"))
	b._take_gear(pink)
	pink.global_position = b._body.global_position + Vector2(70, 0)
	b.blue.global_position = b._body.global_position + Vector2(-200, 0)
	var dm0: float = pink.global_position.distance_to(b._body.global_position)
	b.magnet()
	for i in 10:
		b.advance(0.05)
	verify(t, "护心磁吸：把她往中间吸（%.0f → %.0f）" % [dm0, pink.global_position.distance_to(b._body.global_position)],
		pink.global_position.distance_to(b._body.global_position) < dm0 - 10.0)
	verify(t, "护心磁吸比走路慢（%.0f < %.0f）：往外走就走得掉" % [TaskKnightBoss.MAGNET_PULL, pink.move_speed], TaskKnightBoss.MAGNET_PULL < pink.move_speed)
	b.magnet_left = 0.0
	b.shards()
	verify(t, "甲片飞散：六片", b.fx.filter(func(n): return n is KnightBossFx.Shard).size() == TaskKnightBoss.SHARDS)
	GameState.vars[TaskKnightBoss.CAUGHT_KEY] = 0
	if b.grabbed:
		b._release_grab()
	# 做过两个支线：最后阶段两个帮手
	GameState.set_flag("kq_shoes_done")
	GameState.set_flag("kq_samples_done")
	for part in b.parts.duplicate():
		part.freeze_left = 4.0
		for i in TaskKnightBoss.PART_HP:
			b.hit_part(part)
	# 胸甲碎了：笑雾涌起 → 换到「笑雾之中」（广场的倒影，等距），同一个 Boss 从第 3 阶段接着打
	KnightDispel.quiet = true
	var in_fog := func() -> bool: return t._level_id() == KnightStory.KFOG and task(t, "boss_fog") != null and bool(task(t, "boss_fog").started) and not Cutscene.is_playing() and not GameState.in_dialogue
	await t._advance_until(in_fog, 90.0)
	verify(t, "胸甲碎了 → 笑雾涌起（knight_fog_rise）→ 换到笑雾之中（%s，等距 %s）" % [t._level_id(), str(t.main.level.get("style"))],
		t.seen_cuts.has("knight_fog_rise") and t.seen_cuts.has("knight_fog_open") and t._level_id() == KnightStory.KFOG and str(t.main.level.get("style")) == "iso")
	b = task(t, "boss_fog") as TaskKnightBoss
	pink = b.pink
	cu = b.curse
	TaskKnightBoss.skip_cutscenes = true
	verify(t, "雾里：阶段四（笑面），四盏灯笼暗着（%d）、骑士浮在半空、外圈黑雾、配乐 knight_fog（%s）" % [b.lanterns.size(), Audio.music_id],
		b.phase == 3 and b.lanterns.size() == 4 and b.lanterns.all(func(l): return not l.lit) and b.floating and is_instance_valid(b.fog_ring)
		and Audio.music_id == "knight_fog")
	# 外圈黑雾：慢慢收紧，圈外痒；点亮一盏往外推
	var fr := b.fog_ring
	var fog_r0 := fr.radius
	fr.tick(2.0)
	verify(t, "黑雾慢慢收紧（%.0f → %.0f）" % [fog_r0, fr.radius], fr.radius < fog_r0)
	pink.global_position = fr.global_position + Vector2(fr.radius + 30.0, 0)
	pink.laugh.set_value(0.0)
	fr._tick = 0.0
	fr.tick(0.05)
	verify(t, "站在黑雾里：闷笑涨（%.0f%%）、挂上「黑雾缠身」" % (pink.laugh.ratio() * 100.0), pink.laugh.value > 0.0 and pink.has_buff("fog_tickle"))
	# 亮着的灯笼光里：不受黑雾侵蚀
	var safe_l: KnightBossFx.Lantern = b.lanterns[0]
	b._light(safe_l, 1.0)
	fr.radius = KnightFogRing.R_MIN
	pink.global_position = safe_l.global_position
	pink.laugh.set_value(0.0)
	pink.remove_buff("fog_tickle")
	fr._tick = 0.0
	fr.tick(0.05)
	verify(t, "亮着的灯笼光里：黑雾侵蚀不到（%.0f%%）" % (pink.laugh.ratio() * 100.0), pink.laugh.value == 0.0 and not pink.has_buff("fog_tickle"))
	safe_l.lit = false
	safe_l.progress = 0.0
	fr.radius = KnightFogRing.R0
	pink.global_position = fr.global_position
	pink.laugh.set_value(0.0)
	verify(t, "做过的三个支线（骑士救公主、手印样本、夜里的栅栏）：帮手跑到他那盏灯笼下（%d）" % b.helpers.size(), b.helpers.size() == 3)
	b.attack_t = 999.0
	b._clear_field()
	# ---- 阶段四：笑面 + 全镇的笑声
	verify(t, "笑面打不动", not b.hit_part(b.parts[0]))
	b.mirrors()
	verify(t, "镜面笑脸：三张", b.fx.filter(func(n): return n is KnightBossFx.Mirror).size() == TaskKnightBoss.MIRRORS)
	var mm: KnightBossFx.Mirror = b.fx.filter(func(n): return n is KnightBossFx.Mirror)[0]
	mm._process(3.0)
	verify(t, "镜面笑脸只绕着盔甲转，不追人（离盔甲 %.0f）" % mm.global_position.distance_to(b._body.global_position),
		mm.global_position.distance_to(b._body.global_position) <= KnightBossFx.Mirror.ORBIT_MAX + 16.0)
	b._clear_field()
	b.name_call()
	verify(t, "呼唤骑士之名：先蓄力，标出 %d 个缺口" % TaskKnightBoss.RING_GAPS, str(b.warn.get("kind", "")) == "name" and (b.warn["gaps"] as Array).size() == TaskKnightBoss.RING_GAPS)
	var gap: float = b.warn["gaps"][0]
	pink.global_position = b._body.global_position + Vector2.from_angle(gap) * 60.0
	b.blue.global_position = b._body.global_position + Vector2.from_angle(gap + PI / TaskKnightBoss.RING_GAPS) * 60.0
	pink.laugh.set_value(0.0)
	b.blue.laugh.set_value(0.0)
	b.ai_enabled = false
	# 冲击波自己按真实时间往外扩：等它扩完
	await t._advance_until(func(): return b.warn.is_empty() and not b.fx.any(func(n): return is_instance_valid(n) and n is KnightBossFx.Ring), 4.0)
	verify(t, "冲击波：站在缺口的方向上没事（%.1f），别的方向被扫到（%.1f）；喊完露出脖子" % [pink.laugh.value, b.blue.laugh.value],
		pink.laugh.value == 0.0 and b.blue.laugh.value > 0.0 and b.weak_spot != null and b.weak_spot.spot == "脖子")
	# 灯笼
	var l0: KnightBossFx.Lantern = b.lanterns[2]
	pink.global_position = l0.global_position
	KnightLaugh.reset()
	KnightLaugh.force_hold = true
	for i in 20:
		b.advance(0.05)
	KnightLaugh.force_hold = false
	verify(t, "站在灯笼旁按住 Y 笑：灯笼一点点亮起来（%.2f）" % l0.progress, l0.progress > 0.05)
	var hl: KnightBossFx.Lantern = b.lanterns[0]
	await t._advance_until(func(): return b._helper_at(0), 6.0)
	var hp0: float = hl.progress
	b.advance(1.0)
	verify(t, "帮手（小汤姆和小莉莉）在那盏灯笼下：自己也慢慢亮（%.2f → %.2f）" % [hp0, hl.progress], hl.progress > hp0)
	# ---- 笑面「吸笑」：站在亮着的灯笼光里才安全
	var lit0: KnightBossFx.Lantern = b.lanterns[0]
	b._light(lit0, 1.0)
	cu.start()
	verify(t, "笑面吸笑开始", cu.surge == "drain")
	var dark: KnightBossFx.Lantern = b.lanterns[2]
	dark.progress = 0.5
	pink.global_position = dark.global_position + Vector2(0, 40)
	pink.laugh.set_value(0.0)
	for i in 5:
		cu.tick(0.2)
	verify(t, "光外面：闷笑被吸着涨（%.0f%%）、没亮的灯笼暗下去（%.2f）" % [pink.laugh.ratio() * 100.0, dark.progress], pink.laugh.ratio() > 0.05 and dark.progress < 0.5)
	pink.global_position = lit0.global_position
	pink.laugh.set_value(0.0)
	for i in 3:
		cu.tick(0.2)
	verify(t, "亮着的灯笼光里：不受影响", pink.laugh.value == 0.0)
	for i in 30:
		cu.tick(0.2)
	verify(t, "吸笑过去了", cu.surge == "")
	var hl0 := CurseHand.new()
	b.get_parent().add_child(hl0)
	hl0.global_position = lit0.global_position + Vector2(8, 0)
	b.hands.append(hl0)
	b._tick_hands()
	verify(t, "小手爬进亮着的灯笼光里：化掉", hl0.state == "gone")
	# 化简：没有触手；亮着的灯笼光圈里闷笑慢慢下降
	verify(t, "化简：笑面不再伸触手", b.tentacles.is_empty())
	GameState.switch_control(pink)
	await t._wait(0.2)
	pink.global_position = lit0.global_position + Vector2(6, 0)
	pink.laugh.set_value(pink.laugh.max_value * 0.6)
	var lc0 := pink.laugh.value
	b._tick_lantern_calm(1.0)
	verify(t, "站在亮着的灯笼光里：闷笑慢慢下降（%.0f → %.0f）" % [lc0, pink.laugh.value], pink.laugh.value < lc0)
	pink.laugh.set_value(0.0)
	GameState.switch_control(pink)
	await t._wait(0.2)
	b.weak_left = 2.0
	if not is_instance_valid(b.weak_spot):
		b.open_weak(Vector2(0, -26))
	var lp: Array = b.lanterns.map(func(l): return l.progress)
	for i in 4:
		b.tickle_knight()
	verify(t, "挠满骑士的笑：每盏没亮的灯笼都亮一截", b.lanterns.all(func(l): return l.lit or l.progress >= float(lp[b.lanterns.find(l)]) + TaskKnightBoss.LUCID_LANTERN - 0.01))
	verify(t, "耐久条：笑面那一段还满着（%.2f）" % b.durability(), b.durability() > 0.1)
	TaskKnightBoss.skip_cutscenes = false
	for l in b.lanterns:
		l.progress = 0.99
	pink.global_position = b.lanterns[1].global_position
	KnightLaugh.force_hold = true
	for l in b.lanterns:
		b._light(l, 0.02)
	KnightLaugh.force_hold = false
	b.advance(0.05)
	verify(t, "雾里四盏都亮了：骑士落地、外圈黑雾停住、开始驱散（玩家操控蓝色公主）", is_instance_valid(b.dispel) and not b.floating
		and b.fog_ring.frozen and GameState.player == b.blue and bool(GameState.vars.get(TaskKnightBoss.DISPEL_KEY, false)))
	var dsp := b.dispel
	verify(t, "驱散里黑雾小手刷得更勤（每 %.1f 秒，后半段 %.1f 秒）" % [KnightDispel.HAND_EVERY, KnightDispel.HAND_EVERY_LATE], KnightDispel.HAND_EVERY <= 1.3 and KnightDispel.HAND_EVERY_LATE <= 0.9)
	var mon := dsp.spawn_monster("rat")
	verify(t, "雾里钻出现有的怪（%s）" % [mon.name if mon else "无"], mon != null and dsp.monsters.has(mon))
	dsp._clear_monsters()
	# 粉色公主站在骑士身边吟唱：读条涨
	pink.global_position = b.body_pos() + Vector2(0, 20)
	pink.laugh.set_value(0.0)
	dsp.interrupt_left = 0.0
	var dp0 := dsp.progress
	dsp.tick(1.0)
	verify(t, "粉色公主在骑士身边吟唱：读条涨（%.2f → %.2f）" % [dp0, dsp.progress], dsp.channeling and dsp.progress > dp0)
	# 黑气小手碰到她：打断、读条倒退、闷笑涨
	dsp.progress = 0.5
	var fh0 := dsp.spawn_hand()
	fh0.global_position = pink.global_position
	dsp.tick(0.05)
	verify(t, "黑气小手碰到粉色公主：打断，读条 −15%%（%.2f）、闷笑涨（%.0f%%）" % [dsp.progress, pink.laugh.ratio() * 100.0],
		absf(dsp.progress - 0.35) < 0.02 and dsp.interrupt_left > 0.0 and pink.laugh.value > 0.0 and not dsp.hands.has(fh0))
	# 蓝色公主 J：冻碎身边的小手
	var fh1 := dsp.spawn_hand()
	fh1.global_position = b.blue.global_position + Vector2(6, 0)
	b.freeze_cool = 0.0
	verify(t, "蓝色公主 J：冻碎身边的黑气小手", b.freeze_part(b.blue) and not dsp.hands.has(fh1))
	# 闷笑第一次满：魔力释放（小手震散、闷笑回落、之后更敏感）
	dsp.spawn_hand()
	pink.laugh.set_value(pink.laugh.max_value * 0.99)
	dsp.tick(0.05)
	verify(t, "粉色公主闷笑第一次满：魔力释放（小手全散、闷笑 %.0f%%、更敏感 %.1f 秒）" % [pink.laugh.ratio() * 100.0, dsp.sensitive_left],
		dsp.bursts == 1 and dsp.hands.is_empty() and pink.laugh.ratio() < 0.5 and dsp.sensitive_left > 0.0)
	verify(t, "驱散阶段失败挑「笑雾之中」的小剧场", TaskKnightBoss.fail_theater() == "knight_fail_fog")
	# 第二次满：失败 → 小剧场 → 从驱散重来（灯笼直接亮着）
	pink.laugh.set_value(pink.laugh.max_value * 0.99)
	dsp.tick(0.05)
	var old_b := b
	var retried := func() -> bool: return task(t, "boss_fog") != null and task(t, "boss_fog") != old_b and is_instance_valid((task(t, "boss_fog") as TaskKnightBoss).dispel) and not Cutscene.is_playing() and not CG.is_busy()
	await t._advance_until(retried, 60.0)
	var b3 := task(t, "boss_fog") as TaskKnightBoss
	verify(t, "第二次满：驱散失败 → 小剧场 knight_fail_fog → 重来直接从驱散开始（灯笼都亮着）", b3 != null and b3 != b
		and is_instance_valid(b3.dispel) and b3.lanterns.all(func(l): return l.lit))
	b = b3
	pink = b.pink
	# 读满：驱散成功 → 净化
	TaskKnightBoss.skip_cutscenes = false
	var d3 := b.dispel
	pink.global_position = b.body_pos() + Vector2(0, 20)
	pink.laugh.set_value(0.0)
	d3.interrupt_left = 0.0
	d3.progress = 0.99
	d3.tick(1.0)
	verify(t, "读条满：黑雾散了 → 净化（光柱汇到盔甲上）", d3.done and b.finale)
	KnightCurse.auto = true
	# 战败小剧场：追逃 1 个 + Boss 4 个；不写「第几幕」标题（第七轮）；两位公主都被挠（粉色脚心、蓝色大腿和屁股），有魔力释放的舒服
	var ids := ["knight_fail_chase", "knight_fail_boss", "knight_fail_boss_2", "knight_fail_boss_3", "knight_fail_fog"]
	var shape_ok := true
	for id in ids:
		var thd: Dictionary = {}
		if CG.has_theater(id):
			thd = JSON.parse_string(FileAccess.get_file_as_string(CG.theater_index()[id]))
		var steps: Array = thd.get("steps", [])
		var acts := steps.filter(func(st): return st is Dictionary and str(st.get("text", "")).begins_with("—— 第")).size()
		var blue_hit := steps.any(func(st): return st is Dictionary and (st.get("actions", []) as Array).any(func(x): return str(x.get("who", "")) == "blue" and str(x.get("zone", "")) in ["thigh", "butt"]))
		var burst := steps.any(func(st): return st is Dictionary and str(st.get("act", "")) == "burst")
		var comfy := steps.any(func(st): return st is Dictionary and str(st.get("text", "")).contains("舒服"))
		if acts != 0 or not blue_hit or not burst or not comfy:
			shape_ok = false
			print("  小剧场 %s：%d 幕 蓝色被挠 %s 释放 %s 舒服 %s" % [id, acts, blue_hit, burst, comfy])
	verify(t, "战败小剧场都没有「第几幕」标题、两位公主都被挠、有魔力释放的舒服", shape_ok and ids.all(func(i): return CG.has_theater(i)))
	GameState.vars[TaskKnightBoss.DISPEL_KEY] = false
	var fmap := []
	for ph in 4:
		GameState.vars[TaskKnightBoss.PHASE_KEY] = ph
		fmap.append(TaskKnightBoss.fail_theater())
	GameState.vars[TaskKnightBoss.PHASE_KEY] = 3
	verify(t, "Boss 失败按阶段挑小剧场（%s）" % [fmap], fmap == ["knight_fail_boss", "knight_fail_boss", "knight_fail_boss_2", "knight_fail_boss_3"])
	await t._advance_until(func(): return Cutscene.chapter_screen.visible and not Cutscene.is_playing(), 90.0)
	verify(t, "手帕 → 净化（knight_purify）→ 尾声（半枚徽章）→「骑士篇 完」", t.seen_cuts.has("knight_purify") and t.seen_cuts.has("knight_epilogue")
		and Cutscene.chapter_title.text.contains("骑士篇"))
	Cutscene.continue_chapter()
	await t._advance_until(func(): return t._level_id() == AfterStory.HOUSE and not Cutscene.chapter_screen.visible, 20.0)
	verify(t, "按 E 回小屋；骑士篇这一段结束（%s）" % KnightStory.objective(AfterStory.HOUSE).get("text", ""),
		t._level_id() == AfterStory.HOUSE and KnightStory.step().is_empty())
	for q in ["shoes", "samples", "spear"]:
		GameState.set_flag("kq_%s_done" % q, false)
	# ---------------------------------------------------------------- 六个支线都做过：最后一战的帮手都在场上
	for q in ["shoes", "samples", "spear", "fence", "host", "blue"]:
		GameState.set_flag("kq_%s_done" % q)
	GameState.vars[TaskKnightBoss.PHASE_KEY] = 0
	GameState.vars[TaskKnightBoss.CAUGHT_KEY] = 0
	KnightCurse.auto = false
	KnightStory.jump("boss")
	GameState.pending_spawn = "from_prison"
	await t.main.change_level(Floors.scene(KnightStory.KCHASE))
	await t._advance_until(func(): return task(t, "boss") != null and bool(task(t, "boss").started) and not Cutscene.is_playing() and not GameState.in_dialogue, 60.0)
	var b2 := task(t, "boss") as TaskKnightBoss
	verify(t, "再打一次 Boss（六个支线都做过）", b2 != null)
	if b2 == null:
		KnightCurse.auto = true
		return
	var fh := b2.field_helpers
	verify(t, "帮手都在场上：小孩们、奶奶、队长、工匠、派对主人、旧石灯笼（%s）" % [fh.field.keys()], fh.field.has("tom") and fh.field.has("lily")
		and fh.field.has("granny") and fh.field.has("captain") and fh.field.has("engineer") and is_instance_valid(fh.host) and is_instance_valid(fh.old_lantern))
	verify(t, "派对主人用 KnightAI（和蓝色公主一样的 AI），按 C 换不到她", fh.host.controller is KnightAI and not fh.host.switchable)
	verify(t, "做过旧剑术：开场就有一次挡", b2.shield >= 1)
	var stakes := b2.crates.filter(func(c): return is_instance_valid(c) and c.stake)
	verify(t, "工匠在场上打好了 %d 根木桩" % stakes.size(), stakes.size() == KnightHelpers.STAKES_PER_PHASE)
	var pk := b2.pink
	pk.laugh.set_value(pk.laugh.max_value * 0.8)
	fh.granny_mint_cool = 0.0
	fh.tick(0.05)
	verify(t, "闷笑过七成：奶奶扔来薄荷糖（%.0f%%）" % (pk.laugh.ratio() * 100.0), pk.laugh.ratio() < 0.7 and fh.granny_mint_cool > 0.0)
	b2.stomp()
	b2.stuck_left = 0.0
	b2.wave_left = 0.0
	fh.music()
	verify(t, "派对主人放八音盒：全场的小手都停住了", b2.hands.all(func(h): return not is_instance_valid(h) or h.state == "frozen"))
	var hm: CurseHand = b2.hands[0]
	hm.global_position = fh.old_lantern.global_position + Vector2(6, 0)
	b2._tick_hands()
	verify(t, "旧石灯笼（第五盏灯）一开场就亮着：小手爬进光里化掉", hm.state == "gone")
	verify(t, "做过点灯笼的小姑娘：蓝色公主的冻结范围大一圈（%.0f）" % b2.freeze_reach(), b2.freeze_reach() > TaskKnightBoss.FREEZE_R)
	verify(t, "队长不再跟着粉色公主，而是跟着盔甲上去打", (fh.field["captain"] as Node2D).get("follow") == b2._body)
	# 最后阶段（笑雾之中从第 3 阶段接着打）开场：灯笼下已有帮手，场上不再摆第二个队长
	var ph_save := b2.phase
	b2.phase = TaskKnightBoss.PHASES - 1
	var fh2 := KnightHelpers.new()
	fh2.task = b2
	b2.add_child(fh2)
	fh2.setup()
	verify(t, "最后阶段开场：场上不再摆队长 / 小孩 / 奶奶 / 工匠（只留灯笼下的那一个）", not fh2.field.has("captain") and not fh2.field.has("tom") and not fh2.field.has("granny"))
	fh2.cleanup()
	fh2.queue_free()
	b2.phase = ph_save
	var vk: KnightBossFx.Victim = b2.victims[0]
	b2.curse_victim(vk)
	(fh.field["tom"] as Node2D).global_position = vk.global_position
	b2._tick_victims(0.3)
	verify(t, "小孩们跑去帮着扒手印（%.2f）" % vk.rescue, vk.rescue > 0.0 or not vk.cursed)
	var pc: TaskKnightBoss.BossPart = b2.parts[0]
	pc.freeze_left = 4.0
	(fh.field["captain"] as Node2D).global_position = pc.global_position + Vector2(10, 0)
	var chp := pc.hp
	for k in 3:   # 队长和别的非粉色公主一样只算三分之一：三下掉 1 点
		fh._cap_hit = 0.0
		fh.tick(0.05)
	verify(t, "冻住的部件：队长也上去打了一下（%d → %d）" % [chp, pc.hp], pc.hp == chp - 1)
	# ---- 派对主人：攻击目标、自己挣扎、彩带打部件、放庆典光环、笑倒不算失败、C 切不到
	var ho := fh.host
	verify(t, "派对主人带 no_switch（测试模式的 F2 也切不到）、AI 有放魔法", ho.has_meta(&"no_switch") and (ho.controller as KnightAI).behaviours.has("magic"))
	verify(t, "派对主人也是骑士的攻击目标", b2._players().has(ho))
	if b2.grabbed:
		b2._release_grab()
	var caught0 := TaskKnightBoss.caught()
	b2.shield = 0
	fh.captain_cool = 99.0
	b2.grab(ho)
	verify(t, "骑士抱住派对主人：不算公主被抓（%d → %d）" % [caught0, TaskKnightBoss.caught()], b2.grabbed == ho and TaskKnightBoss.caught() == caught0)
	for i in 80:
		b2.advance(0.05)
		if not b2.grabbed:
			break
	verify(t, "派对主人被抱住：自己连按挣开", b2.grabbed == null)
	var pr: TaskKnightBoss.BossPart = b2.parts.filter(func(x): return is_instance_valid(x) and not x.broken)[0]
	pr.freeze_left = 4.0
	var rhp := pr.hp
	# 刚被抱住挠过：闷笑清零、状态复位（失控时出不了手）
	ho.laugh.set_value(0.0)
	if ho.status:
		ho.status.clear()
	# 部件一冻住她的 AI 就去放庆典光环（吟唱中出不了彩带）：这一项先停掉她的放魔法
	var hai := ho.controller as KnightAI
	hai.behaviours.erase("magic")
	ho._end_channel()
	ho._set_state(PlayableCharacter.State.IDLE)
	ho.set("_ribbon_wait", 0.0)
	if is_instance_valid(b2.curse):
		b2.curse.end(true)
	await t._wait(0.1)
	pr.freeze_left = 4.0
	ho.global_position = pr.global_position + Vector2(-30, 0)
	ho.facing = Vector2.RIGHT
	ho.attack()
	for i in 20:
		await t.get_tree().physics_frame
		if pr.hp < rhp or pr.chip > 0.0:
			break
	hai.behaviours.insert(2, "magic")
	verify(t, "派对主人的彩带打中冻住的部件（%d → %d；诅咒无敌 %s、软 %s、能出手 %s、状态 %s、彩带 %d）" % [rhp, pr.hp, b2.curse.invulnerable() if is_instance_valid(b2.curse) else false,
		b2._soft(pr), ho.can_act(), ho.state, t.get_tree().get_nodes_in_group("festival_ribbon").size()], pr.hp < rhp or pr.chip > 0.0)
	FestivalAura.cast(ho, 200.0, 2.0)
	KnightTickle.no_crit = true
	pk.laugh.set_value(0.0)
	KnightTickle.hit(pk, 0.1, b2._body, "")
	var in_aura := pk.laugh.value
	for a in t.get_tree().get_nodes_in_group("festival_aura"):
		a.queue_free()
	await t.get_tree().process_frame
	pk.laugh.set_value(0.0)
	KnightTickle.hit(pk, 0.1, b2._body, "")
	verify(t, "骑士站在庆典光环里挠人更狠（%.1f > %.1f）" % [in_aura, pk.laugh.value], in_aura > pk.laugh.value * 1.2)
	pk.laugh.set_value(0.0)
	KnightTickle.no_crit = false
	pr.freeze_left = 4.0
	verify(t, "部件冻住时 AI 有放魔法的目标（庆典光环）", b2._ai_hooks.magic_target(ho) != null)
	ho.health.damage(ho.health.hp)
	await t._wait(0.2)
	verify(t, "派对主人笑倒：坐地缓一会儿（不放 CG、Boss 战没结束）", not ho.is_alive() and not b2._emitted and not CG.is_busy())
	await t._wait(KnightHelpers.HOST_DOWN + 0.5)
	verify(t, "缓过来了：派对主人重新站起来", ho.is_alive() and ho.laugh.value == 0.0)
	KnightCurse.auto = true
	for q in ["shoes", "samples", "spear", "host", "blue"]:
		GameState.set_flag("kq_%s_done" % q, false)

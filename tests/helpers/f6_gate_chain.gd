extends RefCounted
## 城门穿链专项：走真实接取／舞台／退出／换图／存读档入口，不运行七天全流程。
static var checks := 0

static func verify(t: Node, label: String, ok: bool) -> void:
	checks += 1
	t.check(label, ok)

static func find_show(t: Node) -> GateChainShow:
	return t._show(GateChainShow) as GateChainShow

static func solve_node(t: Node, show: GateChainShow) -> void:
	await t._advance_until(func(): return not is_instance_valid(show) or not show.busy, 3.0)
	if not is_instance_valid(show) or show._done: return
	for i in 30:
		if absf(show.aim - show.target()) <= GateChainShow.AIM_STEP * 0.55: break
		show.press("RIGHT" if show.aim < show.target() else "LEFT")
	var desired := (float(show.phase_info()["force"][0]) + float(show.phase_info()["force"][1])) * 0.5
	for i in 25:
		if absf(show.force - desired) <= GateChainShow.FORCE_STEP * 0.55: break
		show.press("J" if show.force < desired else "K")
	show.press("E")
	await t.get_tree().process_frame

static func start(t: Node) -> GateChainShow:
	await t._talk("floor_06/after_engineer", "errand_gate_chain", [0])
	t._go(Cells.to_world([31,38]))
	await t._advance_until(func(): return find_show(t) != null, 3.0)
	return find_show(t)

static func run(t: Node) -> void:
	checks = 0
	GateChainShow.quiet = true
	GateChainShow.fixed_seed = 61604
	for f in ["after_started", "penance_book", "f6_opening_done"]: GameState.set_flag(f)
	for k in ["open", "active", "done"]: GameState.set_flag("errand_gate_chain_" + k, false)
	GameState.vars.erase(GateChainShow.SAVE_STEP)
	GameState.vars["penance_hours"] = 50
	GameState.vars["penance_punish"] = []
	DayClock.set_time(3,DayClock.AFTERNOON)
	verify(t,"第3天尚未开放",not AfterErrands.is_open("gate_chain"))
	DayClock.set_time(4,DayClock.NIGHT)
	verify(t,"夜里不开放",not AfterErrands.is_open("gate_chain"))
	DayClock.set_time(4,DayClock.AFTERNOON)
	GameState.set_flag("after_done_d4_morning")
	verify(t,"第4天白天开放，旧档无进度从零开始",AfterErrands.is_open("gate_chain") and GateChainShow.saved_step()==0)
	var tx := GateChainShow.text()
	verify(t,"12节点，三阶段为3＋6＋3",tx["nodes"].size()==12 and tx["phases"].map(func(p):return p["steps"])==[3.0,6.0,3.0])
	verify(t,"12节点改为非阻塞动作描述",tx["nodes"].all(func(n):return n.has("caption") and not n.has("lines")))
	verify(t,"挠痒事件都针对脚底，每阶段两种道具",tx["feedback"].all(func(e):return e["zone"]=="sole") and tx["phases"].all(func(p):return p["tools"].size()==2))
	var dev: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/skip_points_more.json"))
	var points: Array = dev["skip_points"].filter(func(p):return str(p["name"]).begins_with("七日赎罪"))
	verify(t,"所有赎罪跳关点重置新进度与标记",points.all(func(p):return p["vars"].get(GateChainShow.SAVE_STEP,-1)==0 and "!errand_gate_chain_done" in p["flags"]))
	await t.main.change_level(Floors.scene(AfterStory.TOWN))
	await t._wait(0.2)
	var entry := Dialogue.runner.entry_of("floor_06/after_engineer")
	verify(t,"工匠同时有梯子委托时新委托仍可见",entry=="errand_gate_chain" and GameState.has_flag("errand_ladder_open"))
	var original_laugh := 9.0
	var original_fatigue := 15.0
	GameState.player.laugh.set_value(original_laugh)
	GameState.player.fatigue.set_value(original_fatigue)
	var g := await start(t)
	verify(t,"真实对话接取并走到目标开演",g!=null and AfterErrands.active()=="gate_chain")
	if g==null: return
	verify(t,"舞台只有粉色和工匠，地图输入被锁住（演员%s，锁%d，对话%s）" % [g.actors.keys(),GameState.dialogue_holds,GameState.in_dialogue],g.actors.size()==2 and g.actors.has("princess") and g.actors.has("worker") and GameState.dialogue_holds==1 and GameState.in_dialogue)
	original_laugh = g._start_laugh
	original_fatigue = g._start_fatigue
	verify(t,"新委托接下后其他委托互斥",not GameState.has_flag("errand_ladder_open"))
	var a := g.aim
	var f := g.force
	var l := GameState.player.laugh.value
	g.apply_interference()
	verify(t,"真实干扰同时改变对准／力度／闷笑",g.aim!=a and g.force>f and GameState.player.laugh.value>l)
	var first_laugh := GameState.player.laugh.value
	await t._wait(12.4)
	verify(t,"实际操作时间内反复干扰，不推进也发生两次加强",g.interference.strong_count >= 2 and g.completed == 0 and GameState.player.laugh.value > first_laugh and not Dialogue.is_active())
	await t._advance_until(func(): return g.fx_root.get_child_count() > 0 and not g._floating.is_empty(), 2.0)
	verify(t,"持续特效和公主飘字存在且不锁输入",g.fx_root.get_child_count() > 0 and not g._floating.is_empty() and not g.busy)
	verify(t,"描写使用原反应方框，右侧操作说明不重叠",g._action_caption==Dialogue.reaction_text and not g._action_caption.text.is_empty() and g.hint_label.position.x>=Dialogue.reaction_panel.position.x+Dialogue.reaction_panel.size.x)
	var clock := g.elapsed
	g.busy = true
	var laugh_paused := GameState.player.laugh.value
	await t._wait(0.1)
	g._tick(1.0)
	g.press("J")
	verify(t,"对白中计时与输入冻结",g.elapsed==clock and g.force>f)
	verify(t,"对白中模拟闷笑不被世界组件自然衰减",not GameState.player.laugh.is_processing() and GameState.player.laugh.value==laugh_paused)
	g.busy = false
	var force_before := g.force
	GameState.in_cutscene = true
	g._tick(1.0)
	g.press("J")
	verify(t,"外部演出期间计时和输入冻结",g.elapsed==clock and g.force==force_before)
	GameState.in_cutscene = false
	t.get_tree().paused = true
	g._tick(1.0)
	g.press("J")
	verify(t,"暂停中计时和输入冻结",g.elapsed==clock and g.force==force_before)
	t.get_tree().paused = false
	var blocks := g.dialogue_blocks
	g.aim = 1.0
	g.force = 0.0
	var errs := g.errors
	g.press("E")
	verify(t,"错误位置不会推进且记录当前节点失误",g.completed==0 and g.errors==errs+1 and GateChainShow.saved_step()==0)
	g.aim = g.target()
	g.force = 1.0
	errs = g.errors
	g.press("E")
	verify(t,"位置正确但力度错误也不能通过",g.completed==0 and g.errors==errs+1)
	verify(t,"穿链阶段的道具是清灰刷 / 羽毛掸（%s）" % g.active_tool,g.active_tool in ["brush","feather"])
	g.interference._strong_left = 3.0
	verify(t,"不在预告时缩脚没有效果",not g.tuck() and not g.tucked)
	g.interference._strong_left = 0.3
	verify(t,"预告亮着时按S缩脚",g.tuck() and g.tucked)
	g.aim = 0.0
	GameState.player.laugh.set_value(0.0)
	g.apply_interference()
	var expect: float = g.laugh_max() * GateChainShow.STRONG_LAUGH * GateChainShow.TUCK_LAUGH_SCALE
	verify(t,"缩脚：这一下闷笑减半、链头往反方向偏（%.2f / %.2f）" % [GameState.player.laugh.value,expect],is_equal_approx(GameState.player.laugh.value,expect) and g.aim * float(g.node_info()["push"]) < 0 and not g.tucked)
	g.interference._strong_left = 3.0
	g.aim = 0.0
	g.force = 0.0
	var clock_before_nodes := g.interference.elapsed
	await solve_node(t,g)
	await solve_node(t,g)
	verify(t,"普通节点和失误均无剧情，跨节点保留干扰时钟",g.dialogue_blocks == blocks and not Dialogue.is_active() and g.interference.elapsed >= clock_before_nodes and g.interference.strong_count >= 2)
	verify(t,"通过实际按键完成两步并逐步保存",g.completed==2 and GateChainShow.saved_step()==2)
	var good := g.completed
	var prior_helpless := GameState.has_flag("was_helpless")
	var prior_recover := GameState.has_flag("seen_laugh_recover")
	GameState.player.laugh.set_value(GameState.player.laugh.max_value)
	g.mistake("full")
	verify(t,"闷笑满只退当前节点、不记补罚",g.completed==good and GateChainShow.saved_step()==good and GameState.player.laugh.ratio()<0.5 and PenanceBook.punishments().is_empty())
	verify(t,"模拟闷笑不消耗世界教学标记",GameState.has_flag("was_helpless")==prior_helpless and GameState.has_flag("seen_laugh_recover")==prior_recover)
	await t._advance_until(func():return not g.busy,3.0)
	var th: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/theater/after/after_fail_gate_chain.json"))
	verify(t,"失败小剧场：墙完整 / 碎一半 / 全碎三个演员，魔力释放三次以上",th["cast"].has("wall") and th["cast"].has("wall_half") and th["cast"].has("wall_broken")
		and th["steps"].filter(func(st):return st is Dictionary and str(st.get("act",""))=="burst").size()>=3 and CG.data.get("trap_actors",{}).has("rubble_full"))
	g.errors = GateChainShow.FAIL_ERRORS
	g.mistake()
	await t._advance_until(func():return not g.busy,3.0)
	verify(t,"失误超过 4 次：墙塌了（失败小剧场）→ 失误清零、扣好的节点保留、接着做",g.collapses==1 and g.errors==0 and g.completed==good and not g.busy)
	g.quit()
	await t._advance_until(func():return find_show(t)==null,2.0)
	verify(t,"Esc暂存退出不结算奖励",AfterErrands.active()=="" and not AfterErrands.is_done("gate_chain") and GateChainShow.saved_step()==2 and PenanceBook.hours()==50)
	verify(t,"退出释放锁并恢复原闷笑疲倦（锁%d，对话%s，文本%s，runner%s，CG%s，闷笑%.3f/%.3f，疲倦%.3f/%.3f）" % [GameState.dialogue_holds,GameState.in_dialogue,Dialogue.is_active(),Dialogue.runner.is_running(),GameState.in_cutscene,GameState.player.laugh.value,original_laugh,GameState.player.fatigue.value,original_fatigue],GameState.dialogue_holds==0 and not GameState.in_dialogue and is_equal_approx(GameState.player.laugh.value,original_laugh) and is_equal_approx(GameState.player.fatigue.value,original_fatigue))
	verify(t,"退出归还临时教学隔离及闷笑组件时钟",not GameState.player.has_meta("suppress_laugh_tutorials") and GameState.player.laugh.is_processing())
	t._go(Cells.to_world([30,35]))
	var old_dir := SaveSystem.dir
	SaveSystem.dir = "/private/tmp/f6-gate-chain-test-saves/"
	verify(t,"使用隔离测试目录写真实存档",SaveSystem.save(1,"gate-chain-test") and int(SaveSystem.read(1)["vars"][GateChainShow.SAVE_STEP])==2)
	g = await start(t)
	verify(t,"重新接取直接恢复第3步",g!=null and g.completed==2 and g.phase==0)
	if g==null: return
	# 在真实台词排队期间读档，检查旧演出不吞新场景的输入或结算。
	GateChainShow.quiet = false
	g.dialogue_quiet = false
	g._lines(tx["intro"])
	await t.get_tree().process_frame
	verify(t,"测试已进入来源专属对白",Dialogue.is_active() and Dialogue._id==g._line_id)
	verify(t,"真实读档成功",await SaveSystem.load_slot(1))
	await t._wait(0.2)
	verify(t,"读档取消旧对白／舞台且保留存档节点",find_show(t)==null and not Dialogue.is_active() and GameState.dialogue_holds==0 and GateChainShow.saved_step()==2 and not AfterErrands.is_done("gate_chain"))
	GateChainShow.quiet = true
	g = await start(t)
	if g==null:
		verify(t,"读档后可重接",false)
		return
	await solve_node(t,g)
	verify(t,"穿链三步后进入入轮",g.phase==1 and g.completed==3)
	await solve_node(t,g)
	var stored := g.completed
	var clean_laugh := g._start_laugh
	var clean_fatigue := g._start_fatigue
	var incoming_values := []
	var capture := func(p):
		if p.character_id == "pink": incoming_values.append([p.laugh.value,p.fatigue.value])
	GameState.player_registered.connect(capture)
	await t.main.change_level(Floors.scene(AfterStory.TOWN))
	GameState.player_registered.disconnect(capture)
	await t._wait(0.2)
	verify(t,"换图取消root演出但保持已接委托与进度",find_show(t)==null and AfterErrands.is_active("gate_chain") and GateChainShow.saved_step()==stored and GameState.dialogue_holds==0)
	verify(t,"换图不会携带小游戏的临时闷笑疲倦（注册值%s，预期%.3f/%.3f）" % [incoming_values,clean_laugh,clean_fatigue],incoming_values.size()==1 and is_equal_approx(float(incoming_values[0][0]),clean_laugh) and is_equal_approx(float(incoming_values[0][1]),clean_fatigue))
	t._go(Cells.to_world([31,38]))
	await t._advance_until(func():return find_show(t)!=null,3.0)
	g = find_show(t)
	verify(t,"原委托回目标后接着入轮",g!=null and g.completed==stored and g.phase==1)
	if g==null: return
	g.add_fatigue(g.fatigue_max())
	g._process(0.01)
	verify(t,"疲倦释放也只重置当前节点",g.completed==stored and GameState.player.fatigue.value==0 and not g.busy)
	verify(t,"魔力释放：舒服的演出（停一下）、之后几秒格外敏感",g.releases==1 and g.recovery_left>0 and g.sensitive_left>0)
	GameState.player.laugh.set_value(0.0)
	g.work_laugh(10.0)
	verify(t,"释放后敏感：挠痒加倍",is_equal_approx(GameState.player.laugh.value,10.0 * ErrandWorkStage.SENSITIVE_MULT))
	GameState.player.laugh.set_value(0.0)
	while g.completed<9: await solve_node(t,g)
	verify(t,"入轮六步后进入试拉，道具换成手指 / 齿轮刷（%s）" % g.active_tool,g.phase==2 and g.completed==9 and g.active_tool in ["finger","gear"])
	var final_bands: Array = g.phase_info()["force"]
	verify(t,"三个阶段使用不同力度与更精确的位置",final_bands==[0.45,0.65] and float(g.phase_info()["tolerance"])<float(tx["phases"][0]["tolerance"]))
	var ending_blocks := g.dialogue_blocks
	var final_blocks := []
	g.finished.connect(func(): final_blocks.append(g.dialogue_blocks))
	while is_instance_valid(g) and g.completed<12: await solve_node(t,g)
	verify(t,"试拉普通节点不播剧情，结尾只播一次",final_blocks == [ending_blocks + 1])
	await t._advance_until(func():return AfterErrands.is_done("gate_chain"),3.0)
	await t.get_tree().process_frame
	verify(t,"十二步结束后委托完成并只减3工时",AfterErrands.is_done("gate_chain") and AfterErrands.active()=="" and PenanceBook.hours()==47 and GateChainShow.saved_step()==12)
	AfterErrands.complete("gate_chain")
	verify(t,"重复完成回调不重复发奖励",PenanceBook.hours()==47)
	verify(t,"完成后释放输入、无残留舞台且梯子委托仍可接",find_show(t)==null and GameState.dialogue_holds==0 and not GameState.in_dialogue and GameState.has_flag("errand_ladder_open"))
	# 通用show入口被修补，附带验证既有梯子演出的来源退出清理，不跑整项梯子。
	LadderShow.quiet = true
	await t._talk("floor_06/after_engineer","errand_ladder",[0])
	t._go(Cells.to_world([24,10]))
	await t._advance_until(func():return t._show(LadderShow)!=null,3.0)
	verify(t,"旧梯子委托仍经通用入口开演",t._show(LadderShow)!=null)
	await t.main.change_level(Floors.scene(AfterStory.TOWN))
	await t._wait(0.2)
	verify(t,"旧show来源离开也不留下root演出或输入锁",t._show(LadderShow)==null and GameState.dialogue_holds==0)
	LadderShow.quiet = false
	SaveSystem.delete(1)
	SaveSystem.dir = old_dir
	GateChainShow.quiet = false
	GateChainShow.fixed_seed = -1
	print("城门穿链针对性断言：%d" % checks)

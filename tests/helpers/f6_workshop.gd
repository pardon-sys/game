extends RefCounted
## 棚布／筛叶专项：真实接取、实际模拟、按键、续做、来源取消与一次性结算。
static var checks := 0

static func verify(t: Node, label: String, ok: bool) -> void:
	checks += 1
	t.check(label, ok)

static func show(t: Node, id: String) -> ErrandWorkStage:
	return t._show(CanopyShow if id=="canopy" else SiftingShow) as ErrandWorkStage

static func start(t: Node, id: String) -> ErrandWorkStage:
	var npc := "after_merchant" if id=="canopy" else "after_pharm"
	await t._talk("floor_06/"+npc,"errand_"+id,[0])
	t._go(Cells.to_world(AfterErrands.info(id)["target"]))
	await t._advance_until(func():return show(t,id)!=null,3.0)
	return show(t,id)

static func solve_canopy(t: Node, s: CanopyShow) -> void:
	s.set_process(false)
	var before := s.completed
	for i in 300:
		if not is_instance_valid(s) or s.completed!=before: break
		if s.phase < 2:
			var goal := s.guide()
			for j in 35:
				var diff := goal-s.cursor
				if diff.length()<=3: break
				s.press(("D" if diff.x>0 else "A") if absf(diff.x)>absf(diff.y) else ("S" if diff.y>0 else "W"))
		else:
			if s.tension>0.55:s.press("A")
			elif s.tension<0.45:s.press("D")
		s.hold_tool(true)
		s.simulate(0.05)
		if i%15==0:await t.get_tree().process_frame
	await t.get_tree().process_frame

static func next_beat(t: Node, s: SiftingShow) -> void:
	var phase := s.phase
	var target := (floorf(s.beat_clock/SiftingShow.BEAT)+1)*SiftingShow.BEAT
	while is_instance_valid(s) and s.phase==phase and s.beat_clock<target-0.00001:
		s.simulate(minf(0.1,target-s.beat_clock))
	if is_instance_valid(s) and s.phase==phase:s.press("J")
	await t.get_tree().process_frame

static func run(t: Node) -> void:
	checks=0
	CanopyShow.quiet=true
	SiftingShow.quiet=true
	CanopyShow.fixed_seed=621
	SiftingShow.fixed_seed=622
	for id in AfterErrands.ids():
		GameState.set_flag("errand_"+str(id)+"_active",false)
	for id in ["canopy","sifting"]:
		GameState.set_flag("errand_"+id+"_done",false)
		GameState.vars.erase("errand_"+id+"_step")
	for flag in ["after_started","penance_book","after_done_d4_morning"]:GameState.set_flag(flag)
	GameState.vars["penance_hours"]=50
	DayClock.set_time(3,DayClock.AFTERNOON)
	verify(t,"两个新委托第3天未开放",not AfterErrands.is_open("canopy") and not AfterErrands.is_open("sifting"))
	DayClock.set_time(4,DayClock.AFTERNOON)
	await t.main.change_level(Floors.scene(AfterStory.TOWN))
	await t._wait(0.2)
	verify(t,"第4天白天开放且旧档从零开始",AfterErrands.is_open("canopy") and AfterErrands.is_open("sifting") and CanopyShow.saved_step()==0)
	var s = await start(t,"canopy")
	verify(t,"真实商贩接取到坏摊棚开演",s!=null and AfterErrands.active()=="canopy")
	if s==null:return
	s.set_process(false)
	verify(t,"棚布舞台只有粉色和商贩",s.actors.size()==2)
	s.hold_tool(true)
	s.cursor=Vector2(55,5)
	s.simulate(0.2)
	verify(t,"挂角必须对准，不能原地按住J跳过",s.completed==0 and s.progress==0)
	await solve_canopy(t,s)
	verify(t,"通过实际方向键挂角并逐段保存",s.completed==1 and CanopyShow.saved_step()==1)
	var clock = s.elapsed
	GameState.in_cutscene=true
	s.simulate(1)
	verify(t,"新委托外部过场冻结干扰和劳动",s.elapsed==clock)
	GameState.in_cutscene=false
	s.quit()
	await t._advance_until(func():return show(t,"canopy")==null,2)
	verify(t,"棚布退出保留挂角且不发奖励",CanopyShow.saved_step()==1 and PenanceBook.hours()==50 and GameState.dialogue_holds==0)
	t._go(Cells.to_world([13,29]))
	var old_save_dir:=SaveSystem.dir
	SaveSystem.dir="/private/tmp/f6-workshop-test-saves/"
	verify(t,"棚布进度写入真实隔离存档",SaveSystem.save(1,"workshop") and int(SaveSystem.read(1)["vars"]["errand_canopy_step"])==1)
	s=await start(t,"canopy")
	verify(t,"棚布重接从第二角开始",s!=null and s.completed==1)
	if s==null:return
	s.dialogue_quiet=false
	s._lines(s.work_text()["resume"])
	await t.get_tree().process_frame
	verify(t,"新任务对白期间可以读档",Dialogue.is_active() and await SaveSystem.load_slot(1))
	await t._wait(0.2)
	verify(t,"读档取消新任务旧舞台且保留挂角进度",show(t,"canopy")==null and CanopyShow.saved_step()==1 and not Dialogue.is_active() and GameState.dialogue_holds==0)
	s=await start(t,"canopy")
	if s==null:return
	while s.completed<3:await solve_canopy(t,s)
	verify(t,"挂角完成只播一次转场进入描线",s.phase==1 and s.dialogue_blocks==2)
	s.hold_tool(false)
	var p = s.progress
	s.simulate(0.2)
	verify(t,"收针时描线不推进",s.progress==p)
	s.hold_tool(true)
	s.cursor=Vector2(56,8)
	s.simulate(0.2)
	verify(t,"偏线停止有效缝合",s.progress==p)
	while s.completed<7:await solve_canopy(t,s)
	verify(t,"四道破口补好后进入张紧",s.phase==2 and s.dialogue_blocks==3)
	s.tension=1
	s.hold_tool(true)
	s.simulate(0.2)
	verify(t,"张力超出绿区不算验收",s.progress==0)
	var blocks:=[]
	s.finished.connect(func():blocks.append(s.dialogue_blocks))
	while is_instance_valid(s) and s.completed<10:await solve_canopy(t,s)
	await t._advance_until(func():return AfterErrands.is_done("canopy"),3)
	verify(t,"棚布四处主剧情，减3工时一次",blocks==[4] and PenanceBook.hours()==47 and AfterErrands.is_done("canopy"))
	AfterErrands.complete("canopy")
	verify(t,"棚布重复结算不重复减工时",PenanceBook.hours()==47)
	t._go(Cells.to_world([16,13]))
	s=await start(t,"sifting")
	verify(t,"药剂师对话接取后在门外开演",s!=null and AfterErrands.active()=="sifting")
	if s==null:return
	s.set_process(false)
	s.press("J")
	verify(t,"乱按J不算节拍",s.collected==0)
	while s.phase==0:await next_beat(t,s)
	verify(t,"十二拍进入风选",s.completed==1 and s.phase==1)
	# 错篮子的叶回盘，不重做已完成的筛松。
	for i in 17:s.simulate(0.1)
	s.wind=1
	await next_beat(t,s)
	for i in 16:s.simulate(0.1)
	verify(t,"风向错误落错篮不计数、不重做前段",s.completed==1 and s.collected==0)
	for i in 80:
		if s.phase!=1:break
		var desired:=float(s.sent%3-1)
		for j in 10:
			if absf(s.wind-desired)<0.13:break
			s.press("D" if s.wind<desired else "A")
		await next_beat(t,s)
	verify(t,"正确调风并跟拍可收齐24片进入装袋",s.phase==2 and s.completed==2 and s.leaves.is_empty())
	s.hold_tool(true)
	for i in 10:s.simulate(0.1)
	s.hold_tool(false)
	verify(t,"袋量不足只重装当前袋",s.completed==2 and s.progress==0)
	var incoming:=[]
	var capture:=func(player):
		if player.character_id=="pink":incoming.append([player.laugh.value,player.fatigue.value])
	var old_laugh = s._start_laugh
	var old_fatigue = s._start_fatigue
	GameState.player_registered.connect(capture)
	await t.main.change_level(Floors.scene(AfterStory.TOWN))
	GameState.player_registered.disconnect(capture)
	await t._wait(0.2)
	verify(t,"换图清理新舞台、保留已接及进度",show(t,"sifting")==null and SiftingShow.saved_step()==2 and AfterErrands.is_active("sifting") and GameState.dialogue_holds==0)
	verify(t,"换图归还临时数值",incoming.size()==1 and is_equal_approx(incoming[0][0],old_laugh) and is_equal_approx(incoming[0][1],old_fatigue))
	t._go(Cells.to_world([17,12]))
	await t._advance_until(func():return show(t,"sifting")!=null,3)
	s=show(t,"sifting")
	if s==null:return
	s.set_process(false)
	var final_blocks:=[]
	s.finished.connect(func():final_blocks.append(s.dialogue_blocks))
	for bag in 3:
		s.hold_tool(true)
		for i in 40:s.simulate(0.1)
		s.hold_tool(false)
		await t.get_tree().process_frame
	await t._advance_until(func():return AfterErrands.is_done("sifting"),3)
	verify(t,"装齐三袋完成且只减3工时",AfterErrands.is_done("sifting") and PenanceBook.hours()==44 and SiftingShow.saved_step()==5)
	verify(t,"重进后仅开场和收尾，逐袋不播剧情",final_blocks==[2])
	verify(t,"新任务结束无残留舞台、输入锁和角色临时状态",show(t,"sifting")==null and GameState.dialogue_holds==0 and not GameState.player.has_meta("suppress_laugh_tutorials"))
	for id in ["gate_chain","shearing"]:
		var data:=GateChainShow.text() if id=="gate_chain" else ShearingShow.text()
		var events: Array = data["feedback"] + data.get("licks", [])
		verify(t,id+"分阶段分工具的挠痒事件至少12组（%d）"%events.size(),events.size()>=12 and events.all(func(e):return e["react"].size()==3))
	CanopyShow.quiet=false
	SiftingShow.quiet=false
	SaveSystem.delete(1)
	SaveSystem.dir=old_save_dir
	print("新弥补任务针对性断言：%d" % checks)

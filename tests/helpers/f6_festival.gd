extends RefCounted
## 祭典专项：使用真实接取与结算入口，只用press／simulate替代人工计时。
static var checks := 0
static func verify(t: Node, label: String, ok: bool) -> void:
	checks += 1
	t.check(label, ok)

static func show(t: Node, id: String) -> ErrandWorkStage:
	return t._show(LampCalibrationShow if id == "lamp_calibration" else AnnouncerShow) as ErrandWorkStage

static func start(t: Node, id: String) -> ErrandWorkStage:
	if id == "lamp_calibration":
		await t._talk("floor_06/after_bonfire_host", "", [0])
		t._go(Cutscene.cell_to_world(AfterErrands.info(id)["target"]))
	else:
		await t._talk("floor_06/after_bonfire_host", "", [1, 1])
	await t._advance_until(func(): return show(t,id) != null, 3)
	return show(t,id)

static func solve(t: Node, s) -> void:
	s.set_process(false)
	var before = s.completed
	for i in 300:
		if not is_instance_valid(s) or s.completed != before: break
		if s is LampCalibrationShow:
			for axis in (1 if s.phase == 0 else 2):
				for step in 40:
					var diff: float = s.target_lamps[axis] - s.lamps[axis]
					if absf(diff) < 0.02: break
					s.press(("D" if diff > 0 else "A") if axis == 0 else ("S" if diff > 0 else "W"))
			if s.phase == 2 and s.mask_index != s.target_mask: s.press("E")
		else:
			s.press(str(s.cards.find(AnnouncerShow.PROGRAMS[s.completed])+1))
			if s.marker() >= AnnouncerShow.BEAT_LOW and s.marker() <= AnnouncerShow.BEAT_HIGH: s.press("J")
		if is_instance_valid(s) and s.completed == before: s.simulate(0.05)
		if i%20 == 0: await t.get_tree().process_frame
	await t.get_tree().process_frame

static func run(t: Node) -> void:
	checks = 0
	LampCalibrationShow.quiet = true
	AnnouncerShow.quiet = true
	LampCalibrationShow.fixed_seed = 901
	AnnouncerShow.fixed_seed = 902
	for id in AfterErrands.ids(): GameState.set_flag("errand_"+str(id)+"_active", false)
	for flag in ["after_started","penance_book","after_done_d4_morning"]: GameState.set_flag(flag)
	GameState.vars["penance_hours"] = 50
	GameState.vars[LampCalibrationShow.SAVE_KEY] = 0
	GameState.vars["penance_punish"] = []
	GameState.vars["penance_settled"] = 0
	GameState.set_flag("errand_lamp_calibration_done", false)
	GameState.set_flag("errand_dance_done", false)
	GameState.set_flag("errand_massage_done", false)
	DayClock.set_time(4,DayClock.AFTERNOON)
	verify(t,"灯轮和报幕都要求原舞会排练",not AfterErrands.is_open("lamp_calibration") and not AfterPenance.available("announcer"))
	GameState.set_flag("errand_dance_done")
	DayClock.set_time(3,DayClock.AFTERNOON)
	verify(t,"两项祭典任务第3天未开放",not AfterErrands.is_open("lamp_calibration") and not AfterPenance.available("announcer"))
	DayClock.set_time(4,DayClock.NIGHT)
	verify(t,"两项新增练习不抢夜间剧情",not AfterErrands.is_open("lamp_calibration") and not AfterPenance.available("announcer"))
	DayClock.set_time(4,DayClock.AFTERNOON)
	await t.main.change_level(Floors.scene(AfterStory.TOWN))
	await t._wait(0.2)
	verify(t,"满足前置后第4天开放灯轮，旧档进度为零",AfterErrands.is_open("lamp_calibration") and LampCalibrationShow.saved_step()==0)
	AfterPenance.run("announcer")
	await t.get_tree().process_frame
	verify(t,"没有待抵记录不能启动补罚",not AfterPenance.running and show(t,"announcer")==null)
	var s = await start(t,"lamp_calibration")
	verify(t,"真实对话接取并到篝火开演灯轮",s!=null and AfterErrands.active()=="lamp_calibration")
	if s==null:return
	s.set_process(false)
	verify(t,"灯轮演员只有粉色和派对主人",s.actors.size()==2 and s.actors["worker"].sprite.texture.resource_path.replace("_hd.png", ".png").ends_with("bonfire_host.png"))
	s.lamps.x = 1.0 if s.target_lamps.x<0.5 else 0.0
	s.simulate(0.2)
	verify(t,"不对准不能直接计稳定时间",s.progress==0 and s.completed==0)
	var laugh = s.player.laugh.value
	var pos = s.lamps
	for i in 16:s.simulate(0.1)
	verify(t,"游玩中持续增长闷笑、漂移及原反应框反馈",s.player.laugh.value>laugh and s.lamps!=pos and s._caption_owned!="" and s._action_caption==Dialogue.reaction_text)
	s.interference._strong_left = 5.0
	s.player.laugh.set_value(0.0)
	s.lamps = Vector2(0.05, 0.05)
	s.simulate(0.2)
	var shallow: float = s.player.laugh.value
	s.interference._strong_left = 5.0
	s.player.laugh.set_value(0.0)
	s.lamps = Vector2(0.95, 0.95)
	s.simulate(0.2)
	verify(t,"踏板踩得越深，滚轮毛刷越痒（%.3f > %.3f）"%[s.player.laugh.value,shallow],s.player.laugh.value>shallow)
	verify(t,"单灯阶段的道具是羽毛 / 彩带流苏（%s）"%s.active_tool,s.active_tool in ["feather","tassel"])
	s.player.laugh.set_value(0.0)
	s.lamps = Vector2(0.5, 0.5)
	var elapsed = s.elapsed
	var lamps = s.lamps
	t.get_tree().paused=true
	s.press("D")
	s.simulate(0.2)
	t.get_tree().paused=false
	verify(t,"暂停冻结时间和输入",s.elapsed==elapsed and s.lamps==lamps)
	GameState.in_cutscene=true
	s.simulate(0.2)
	s.press("D")
	GameState.in_cutscene=false
	verify(t,"外部过场冻结时间和输入",s.elapsed==elapsed and s.lamps==lamps)
	await solve(t,s)
	verify(t,"按键可校准第一项并保存，普通节点不播剧情",s.completed==1 and LampCalibrationShow.saved_step()==1 and s.dialogue_blocks==1)
	verify(t,"普通节点保留连续干扰时钟",s.elapsed>elapsed)
	s.quit()
	await t._advance_until(func(): return show(t,"lamp_calibration")==null,2)
	verify(t,"退出不奖励，保留灯轮进度并还锁",PenanceBook.hours()==50 and LampCalibrationShow.saved_step()==1 and GameState.dialogue_holds==0)
	t._go(Cutscene.cell_to_world([42,28]))
	var save_dir := SaveSystem.dir
	SaveSystem.dir="/private/tmp/f6-festival-saves/"
	verify(t,"实际隔离存档保存已校准项",SaveSystem.save(1,"festival") and int(SaveSystem.read(1)["vars"][LampCalibrationShow.SAVE_KEY])==1)
	s=await start(t,"lamp_calibration")
	if s==null:return
	verify(t,"灯轮重接从剩余项继续",s.completed==1)
	s.set_process(false)
	s.dialogue_quiet=false
	s._lines(s.work_text()["resume"])
	await t.get_tree().process_frame
	elapsed=s.elapsed
	s.simulate(0.2)
	verify(t,"对白中不推进计时",Dialogue.is_active() and s.elapsed==elapsed)
	verify(t,"对白中真实读档成功",await SaveSystem.load_slot(1))
	await t._wait(0.2)
	verify(t,"读档释放旧舞台与对白",show(t,"lamp_calibration")==null and not Dialogue.is_active() and GameState.dialogue_holds==0)
	s=await start(t,"lamp_calibration")
	if s==null:return
	for i in 3:await solve(t,s)
	verify(t,"四个单灯后只演一次阶段转换",s.completed==4 and s.phase==1 and s.dialogue_blocks==2)
	s.lamps.x=s.target_lamps.x
	s.lamps.y=1.0 if s.target_lamps.y<0.5 else 0.0
	s.simulate(0.1)
	verify(t,"双灯必须同时对准",s.progress==0 and s.completed==4)
	for i in 4:await solve(t,s)
	verify(t,"八项后进入图案验收",s.completed==8 and s.phase==2)
	s.lamps=s.target_lamps
	s.mask_index=(s.target_mask+1)%3
	s.simulate(0.2)
	verify(t,"图案错误不积累稳定时间",s.progress==0)
	var penalties := PenanceBook.punishments().size()
	s.add_laugh(s.laugh_max())
	s.simulate(0.1)
	verify(t,"笑满仅恢复当前项、不记录额外惩罚",s.recovery_left>0 and s.completed==8 and PenanceBook.punishments().size()==penalties and not CG.is_busy())
	for i in 16:s.simulate(0.1)
	s.add_fatigue(s.fatigue_max())
	s.simulate(0.1)
	verify(t,"疲倦满：魔力释放（停一下、不退进度、之后敏感）",s.recovery_left>0 and s.player.fatigue.value==0 and s.releases>=1 and s.sensitive_left>0 and s.completed==8)
	var blocks:=[]
	s.finished.connect(func():blocks.append(s.dialogue_blocks))
	for i in 4:await solve(t,s)
	await t._advance_until(func():return AfterErrands.is_done("lamp_calibration"),3)
	verify(t,"十二项完成、只四段主剧情、减3工时",AfterErrands.is_done("lamp_calibration") and PenanceBook.hours()==47 and blocks==[4])
	AfterErrands.complete("lamp_calibration")
	verify(t,"委托不可重复领取工时",PenanceBook.hours()==47)
	PenanceBook.punish("专项第一条")
	PenanceBook.punish("专项第二条")
	AfterPenance.refresh()
	verify(t,"有待抵记录开放报幕选项，旧两项分发保留",GameState.has_flag("penalty_announcer_open") and AfterPenance.SHOWS.size()==3 and AfterPenance.available("dance") and AfterPenance.available("model"))
	s=await start(t,"announcer")
	verify(t,"从原补罚菜单选报幕",s!=null and AfterPenance.running)
	if s==null:return
	s.set_process(false)
	var key_event := InputEventKey.new()
	key_event.keycode=KEY_2
	key_event.pressed=true
	s._input(key_event)
	verify(t,"真实数字键路由可选第二张卡",s.selected==s.cards[1])
	s.selected=(AnnouncerShow.PROGRAMS[0]+1)%3
	var cards = s.cards.duplicate()
	s.press("J")
	verify(t,"错卡仅散开重排当前项",s.completed==0 and s.scatter_left>0 and s.cards!=cards and s.selected==-1)
	for i in 10:s.simulate(0.1)
	s.selected=AnnouncerShow.PROGRAMS[0]
	for i in 60:
		if s.marker()>0.7:break
		s.simulate(0.05)
	s.press("J")
	verify(t,"选对但不合拍仍不能通过",s.completed==0 and s.scatter_left>0)
	await solve(t,s)
	verify(t,"正确卡片与节拍同时满足可过关",s.completed==1)
	# 笑场：闷笑高时鸣铃，有一半机会声音笑破、这一项重报
	for attempt in 12:
		if s.cracks > 0 or s.completed >= 4:
			break
		s.scatter_left = 0.0
		s.recovery_left = 0.0
		for i in 80:
			if s.marker() >= AnnouncerShow.BEAT_LOW and s.marker() <= AnnouncerShow.BEAT_HIGH:
				break
			s.simulate(0.05)
		s.scatter_left = 0.0
		s.recovery_left = 0.0
		s.selected = AnnouncerShow.PROGRAMS[s.completed]
		s.player.laugh.set_value(s.laugh_max() * 0.9)
		s.ring()
	verify(t,"闷笑高时鸣铃会笑场（%d 次）"%s.cracks,s.cracks>0)
	s.player.laugh.set_value(s.laugh_max() * 0.5)
	s.breath_cd = 0.0
	verify(t,"K 深呼吸：闷笑降一截，有冷却",s.breath() and is_equal_approx(s.player.laugh.value,s.laugh_max()*(0.5-AnnouncerShow.BREATH_DROP)) and not s.breath())
	s.player.laugh.set_value(0.0)
	s.quit()
	await t._advance_until(func():return not AfterPenance.running,2)
	verify(t,"报幕退出不抵记录也不扣工时",AfterPenance.settled()==0 and PenanceBook.hours()==47 and GameState.dialogue_holds==0)
	s=await start(t,"announcer")
	if s==null:return
	verify(t,"报幕重进从第一节目开始",s.completed==0)
	for i in 4:await solve(t,s)
	verify(t,"报幕四节目后换成手指钻趾缝",s.phase==1 and s.active_tool=="finger")
	s.set_process(false)
	for i in 120:
		if s.offset_left>0:break
		s.simulate(0.05)
	verify(t,"第二轮有实际短时偏拍",s.offset_left>0)
	for i in 4:await solve(t,s)
	verify(t,"最后轮进入交替联排",s.phase==2)
	var tools_seen:={}
	for i in 240:
		s.simulate(0.05)
		tools_seen[s.active_tool]=true
	verify(t,"第三轮掰脚趾 / 刮脚心交替",tools_seen.has("toes") and tools_seen.has("scrape"))
	blocks=[]
	s.finished.connect(func():blocks.append(s.dialogue_blocks))
	for i in 4:await solve(t,s)
	await t._advance_until(func():return not AfterPenance.running,3)
	verify(t,"完成报幕抵一笔减3工时，四段主剧情",AfterPenance.settled()==1 and PenanceBook.hours()==44 and blocks==[4])
	s=await start(t,"announcer")
	verify(t,"仍有待抵记录可再次选择报幕",s!=null)
	if s==null:return
	await t.main.change_level(Floors.scene(AfterStory.TOWN))
	await t._wait(0.2)
	verify(t,"换图取消报幕且禁止迟到结算",show(t,"announcer")==null and not AfterPenance.running and AfterPenance.settled()==1 and PenanceBook.hours()==44 and GameState.dialogue_holds==0)
	verify(t,"恢复世界角色数值处理与教程保护",GameState.player.laugh.is_processing() and not GameState.player.has_meta("suppress_laugh_tutorials"))
	for id in ["lamp_calibration","announcer"]:
		var data:=LampCalibrationShow.data() if id=="lamp_calibration" else AnnouncerShow.data()
		for phase in 3:
			verify(t,id+"阶段%d至少三组完整反应"%phase,data["feedback"].filter(func(e):return int(e["phase"])==phase and e["react"].size()==3).size()>=3)
	SaveSystem.delete(1)
	SaveSystem.dir=save_dir
	LampCalibrationShow.quiet=false
	AnnouncerShow.quiet=false
	print("祭典专项断言：%d"%checks)

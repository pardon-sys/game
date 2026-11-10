extends RefCounted
## 七日赎罪本批专项，复用区域夹具，不运行七天完整流程。输入通过press／auto_picks直接调用。
static var checks := 0

static func verify(t: Node, label: String, ok: bool) -> void:
	checks += 1
	t.check(label, ok)

static func run(t: Node) -> void:
	checks = 0
	GameState.set_flag("after_started")
	GameState.set_flag("penance_book")
	DayClock.set_time(3, DayClock.MORNING)
	await t.main.change_level(Floors.scene(AfterStory.TOWN))
	await t.get_tree().create_timer(0.2).timeout
	await lantern(t)
	await exam(t)
	await routine(t)
	await charts(t)
	print("日常优化针对性断言：%d" % checks)

static func lantern(t: Node) -> void:
	var show := LanternShow.new()
	t.add_child(show)
	show.player = GameState.player
	show._build_ui()
	show.set_process(false)
	show.rng.seed = 20261020
	for count in 5:
		var losses := {}
		var valid := true
		for i in 16:
			show.lit = count
			show._punish("fatigue")
			losses[count-show.lit] = true
			valid = valid and show.lit>=0 and count-show.lit==mini(1,count)
		verify(t,"灯笼%d盏：16次释放每次只碎一盏" % count, valid)
	# 第九轮：Esc 能退出笑声灯笼
	show.playing = true
	show.busy = false
	show.quit()
	verify(t, "笑声灯笼：Esc 退出小游戏（委托算中断，之后能重新开始）", show.quitting)
	show.quitting = false
	# 第九轮：「痒痒装备回收」失败后留在身上的临时装备（羽毛脚镣 no_dash）进七日赎罪的图时卸掉——K 能闪避
	Equipment.force("pink", "equip_t_feather_shackles", 9999.0)
	var had := Equipment.has_special("pink", "no_dash")
	GameState.set_flag(AfterStory.TASK_FLAG, false)
	AfterStory._strip_stale_task_gear()
	verify(t, "残留的羽毛脚镣被卸掉（之前 %s）→ K 能闪避" % str(had), had and not Equipment.has_special("pink", "no_dash"))
	show.lit = show.lanterns().size()
	show._punish("fatigue")
	verify(t,"全部点亮优先完成，不倒扣",show._done and show.lit==show.lanterns().size())
	show.queue_free()
	await t.get_tree().process_frame

static func exam(t: Node) -> void:
	var blue := t.main.level.find_child("AfterBlue",true,false) as BluePrincess
	var show := DrillExamShow.new()
	t.add_child(show)
	show.player = blue
	show._build_ui()
	show._build_extra()
	show.set_process(false)
	DrillShow.quiet = true
	show._begin()
	show.playing = true
	var spots: Array = show.lesson().get("spots",[])
	verify(t,"考核与第一课完整共用六部位",spots.size()==6 and spots==DrillShow.text()["lessons"]["ice"]["spots"])
	for spot in spots:
		var id := str(spot["id"])
		show.press(str(spot["key"]))
		var face := show.face
		var laugh := blue.laugh.value
		var blocked := show.blocked
		show._strike(id,"pink")
		verify(t,"考核%s按键实际冻住并挡下攻击" % spot["key"],show.frozen.has(id) and show.face==face and blue.laugh.value==laugh and show.blocked==blocked+1)
	show.press("Q")
	verify(t,"重复冻结增加寒冷",show.cold==IceSitShow.FREEZE_COLD)
	show.gap_t = 999
	show._tick(6.1)
	verify(t,"六秒后冻结实际解除",show.frozen.is_empty())
	show.press("A")
	show.sensitive_t = 10
	show._tick(3.1)
	verify(t,"敏感期冻结加速融化",not show.frozen.has("lthigh"))
	show.press("J")
	show._strike("rthigh","pink")
	verify(t,"J防守仍有效",show.blocks==1 and not show.guard)
	await show.burst()
	verify(t,"U千手解放仍有效",show.bursts==1 and show.pushed_t>0 and show.backlash_t>0)
	show.queue_free()
	DrillShow.quiet = false
	GameState.in_dialogue = false
	await t.get_tree().process_frame

static func routine(t: Node) -> void:
	var r := AfterBlueRoutine.current
	var blue := r.blue
	var homes: Array[Vector2] = []
	for slot in 3:
		DayClock.set_time(3,slot)
		r.sync(true)
		homes.append(blue.global_position)
		verify(t,"时段%d默认闲逛且可对话" % slot,not blue.follow and blue.controller is WanderController and blue.get_node("Talk").enabled)
	verify(t,"早午晚三个不同地点",homes[0]!=homes[1] and homes[1]!=homes[2] and homes[0]!=homes[2])
	var wc := blue.controller as WanderController
	for i in 10:
		wc._pick_target()
		verify(t,"日程路线留在限定范围%d" % i,wc.path.all(func(p): return wc._in_area(wc._cell(p))))
	verify(t,"没赢过不能直接邀请",not r.invite())
	AfterPlay.quiet = true
	AfterPlay.auto_qte = false
	var pick := AfterPlay.SPOTS.find(AfterPlay.weak_spot())
	AfterPlay.auto_picks = [pick,pick,pick]
	verify(t,"真实玩闹失败不会解锁",not await AfterPlay.run() and not r.invite())
	AfterPlay.auto_qte = true
	AfterPlay.auto_picks = [pick]
	var bond := int(GameState.vars.get("blue_bond",0))
	verify(t,"失败后当天可重试获胜",await AfterPlay.run() and AfterPlay.won_today())
	verify(t,"胜利只增加一次关系值",int(GameState.vars.get("blue_bond",0))==bond+1)
	verify(t,"获胜后可邀请并切为同行",r.invite() and blue.follow and blue.controller is CompanionController)
	verify(t,"同行只保留搭档交互口",not blue.get_node("Talk").enabled and blue._partner_area.enabled)
	var at := blue.global_position
	r.dismiss()
	verify(t,"结束同行恢复闲逛且不传送",not blue.follow and blue.controller is WanderController and blue.global_position==at)
	verify(t,"当天可再次邀请",r.invite())
	await AfterPlay.run()
	verify(t,"当天再次交互不重复增加关系",int(GameState.vars.get("blue_bond",0))==bond+1)
	var saved := GameState.vars.duplicate(true)
	GameState.vars = saved.duplicate(true)
	await t.main.change_level(Floors.scene(AfterStory.TOWN))
	await t.get_tree().create_timer(0.2).timeout
	r = AfterBlueRoutine.current
	blue = r.blue
	r.sync(true)
	verify(t,"保存状态并重进地图恢复当天同行",AfterPlay.won_today() and AfterBlueRoutine.invited_today() and blue.follow)
	DayClock.set_time(4,DayClock.MORNING)
	r.sync(true)
	verify(t,"次日资格失效并恢复闲逛",not AfterPlay.won_today() and not r.invite() and not blue.follow)
	AfterStory._mute_partner(true)
	GameState.set_flag(AfterStory.TASK_FLAG)
	r.sync(true)
	verify(t,"任务无需赢挑战仍按原来同行并静音",blue.follow and blue.partner_talk=="" and not blue._partner_area.enabled)
	AfterStory._mute_partner(false)
	GameState.set_flag(AfterStory.TASK_FLAG,false)
	r.sync(true)
	verify(t,"任务结束恢复自由日程",not blue.follow and blue.controller is WanderController)
	DayClock.set_time(2,DayClock.MORNING)
	r.sync(true)
	verify(t,"第二天示众前仍离场",not blue.visible)
	DayClock.mark_done(2,DayClock.MORNING)
	r.sync(true)
	verify(t,"示众结束后回归",blue.visible)
	DayClock.set_time(5,DayClock.AFTERNOON)
	GameState.vars.erase("after_play_win_day")
	GameState.vars.erase("after_play_bond_day")
	GameState.vars["after_play_day"] = 5
	bond = int(GameState.vars.get("blue_bond",0))
	AfterPlay.settle(true)
	verify(t,"旧存档可新获资格但不补发当天关系",AfterPlay.won_today() and int(GameState.vars.get("blue_bond",0))==bond)
	AfterPlay.auto_picks.clear()
	AfterPlay.auto_qte = null
	AfterPlay.quiet = false

static func charts(t: Node) -> void:
	var chart := TailorChart.new()
	t.add_child(chart)
	for part in ["armpit","waist","sole"]:
		var info: Dictionary = TaskTailor.part(part)
		chart.set_state(part,info["points"],{0:"strong",1:"weak",2:"none"},[0],[2])
		verify(t,"裁缝%s图像与四个编号就绪" % part,chart._texture!=null and chart._points.size()==4 and chart.marks==[0] and chart.sewn==[2])
	var menu := Dialogue.runner.choice_menu
	var result := []
	(func(): result.append(await menu.ask(["1 左肩缝：明显","2 左腋窝：轻微","3 右腋窝：没感觉","4 右肩缝：未试过","再试一遍","喝口茶","就缝这些"],"标出漏风点",Rect2(304,12,168,164)))).call()
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	chart.position = Vector2(120,12)
	verify(t,"插画与选项分栏不重叠",not chart.get_global_rect().intersects(menu.panel.get_global_rect()))
	menu.choose(0)
	await t.get_tree().process_frame
	verify(t,"选项正确返回并释放输入锁",result==[0] and GameState.dialogue_holds==0)
	chart.queue_free()

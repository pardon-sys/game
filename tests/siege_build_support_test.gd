extends SiegeFixture
## 仅建塔支援和冲车专项；真实地图／基座／建造／存档，不运行Boss、波次或音频回归。

func until(cond: Callable, timeout := 8.0) -> void:
	var left := timeout
	while not cond.call() and left > 0:
		await get_tree().process_frame
		left -= get_process_delta_time()

func pad_at(at: Vector2) -> BuildPad:
	var p := BuildPad.new()
	d.entities().add_child(p)
	p.global_position = at
	return p

func _ready() -> void:
	await _boot()
	d.wave = 1
	d.state = "prep"
	check("编制为5名冰吟诵学徒与1名冰筑工匠", d.soldiers.filter(func(s): return s.role=="mage").size()==5 and d.soldiers.filter(func(s): return s.role=="builder").size()==1)
	var s: SiegeSoldier = d.soldiers.filter(func(unit): return unit.role=="builder")[0]
	s.retreating = false
	s.visible = true
	s.builder.cooldown = 0.0
	s.set_physics_process(true)
	check("工匠与学徒建造效率分别1和0.5", s.build_rate()==1.0 and d.soldiers.filter(func(unit):return unit.role=="mage")[0].build_rate()==0.5)
	d.crystals = 100
	check("准备阶段不自动下单", not s.builder.start_order() and d.crystals==100)
	d.state = "fight"
	d.crystals = 39
	check("不足以付款后保留30时不下单", not s.builder.start_order() and d.crystals==39)
	var pad := pad_at(Vector2(500,d.wall_foot_y()+100))
	s.global_position = pad.helper_spot(0)
	d.crystals = 40
	check("优先空基座，付费后恰好保留30", s.builder.start_order() and d.crystals==30 and s.builder.order.get_ref()==pad)
	check("订单重复申请不会重复扣款", not pad.request("icicle",false,30,false) and not s.builder.start_order() and d.crystals==30)
	await until(func(): return is_instance_valid(pad.tower))
	check("实际AI走到基座并独立完成建造", is_instance_valid(pad.tower) and pad.pending.is_empty())
	await get_tree().process_frame
	check("成塔完成后进入30秒冷却并写入塔存档", s.builder.cooldown>29 and (GameState.vars.get("siege_towers",[]) as Array).any(func(t):return t["x"]==pad.global_position.x))
	var before := s.builder.cooldown
	GameState.in_cutscene = true
	s.builder.tick(5)
	check("剧情暂停不消耗自动建塔冷却", s.builder.cooldown==before)
	GameState.in_cutscene = false
	d.wave = 12
	d.crystals = 1000
	s.builder.cooldown = 0
	# 已有6塔仍允许继续，不设自动建塔数量限制。
	for i in 6:
		var extra := pad_at(Vector2(700+i*40,d.wall_foot_y()+200))
		extra._build("icicle",1)
	var second := pad_at(Vector2(500,d.wall_foot_y()+180))
	s.global_position = second.helper_spot(0)
	check("已有六座以上塔仍能自动下单", s.builder.start_order() and s.builder.order.get_ref()==second)
	check("自动选塔覆盖已解锁池并优先较少塔种", second.pending["kind"]!="icicle" and IceTower.unlocked(second.pending["kind"]))
	s._mage(0.01)
	s._retreat()
	check("工匠撤退释放协助席位，保留已付款订单", not second.reserved.has(s) and not second.helpers.has(s) and not second.pending.is_empty())
	var mages: Array = d.soldiers.filter(func(unit): return unit.role=="mage")
	for i in 2:
		mages[i].retreating = false
		mages[i].visible = true
		mages[i].set_physics_process(true)
		mages[i].global_position = second.helper_spot(i)
		mages[i]._job = second
		mages[i]._mage(0.01)
	await until(func(): return is_instance_valid(second.tower))
	check("两名学徒接续并完成工匠留下的订单", is_instance_valid(second.tower))
	var p3 := pad_at(Vector2(1200,d.wall_foot_y()+220))
	check("测试订单可创建",p3.request("icicle",false,30,false))
	for i in 2:
		mages[i].global_position = p3.helper_spot(i)
		mages[i]._job = p3
		mages[i]._mage(0.01)
	check("每基座最多两名协作者",p3.reserved.size()==2 and p3.reserve(mages[2])==-1)
	p3.set_process(false)
	var progress_before := p3.progress
	GameState.in_dialogue = true
	p3._process(0.5)
	check("对话中冰光进度冻结", p3.progress==progress_before)
	GameState.in_dialogue = false
	mages[0].global_position += Vector2(100,0)
	p3._beam_tick(0.5)
	check("位移离开工位立即停止该学徒贡献",is_equal_approx(p3.progress-progress_before,0.25) and not p3.helpers.has(mages[0]))
	mages[1].set_physics_process(false)
	p3._beam_tick(0.5)
	check("冻结或停止物理的学徒释放席位", not p3.reserved.has(mages[1]))
	p3.queue_free()
	await get_tree().process_frame
	mages[0]._mage(0.01)
	check("基座释放后旧学徒引用可安全清理", not is_instance_valid(mages[0]._job))
	await cart_checks()
	print("BUILD SUPPORT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func cart_checks() -> void:
	d.bench_soldiers(true)
	var pad := pad_at(Vector2(1450,d.wall_foot_y()+110))
	pad._build("icicle",1)
	var tower := pad.tower
	var maximum := tower.health.max_hp
	var cart := d.spawn("cart","",tower.global_position+Vector2(0,24)) as SiegeCart
	cart.set_physics_process(false)
	cart._phase = "charge"
	check("冲车每次扣最大生命25%",cart._touch_tower(Vector2.UP) and tower.health.hp==maximum-ceili(maximum*0.25))
	var hp := tower.health.hp
	for i in 10: cart._touch_tower(Vector2.UP)
	check("重叠不逐帧伤害，撞击后晕住",tower.health.hp==hp and cart._phase=="dazed")
	cart.siege_wander(null,SiegeCart.SMASH_DAZE+0.01)
	cart.siege_wander(null,SiegeCart.REAIM+0.01)
	check("撞晕结束重新预警再冲", cart._phase=="warn2")
	cart.siege_wander(null,0.61)
	check("重新预警后可再撞同塔",cart._touch_tower(Vector2.UP) and tower.health.hp==maximum-2*ceili(maximum*0.25))
	for i in 2:
		cart._phase = "charge"
		cart._touch_tower(Vector2.UP)
	check("四次冲锋摧毁满血塔且保留基座", tower.health.hp==0 and is_instance_valid(pad) and pad.tower==null)
	await get_tree().process_frame
	pad._build("decoy",1)
	cart._phase="charge"
	check("诱饵冰雕不走普通扣血分支",not cart._touch_tower(Vector2.UP))
	pad.tower.queue_free()
	pad.tower = null
	pad._build("icicle",1)
	var boss := fortress()
	cart.configure_fortress(boss.mechanisms,Vector2(1450,d.wall_foot_y()),false)
	var before := pad.tower.health.hp
	cart._fortress_tick(0.01)
	check("Boss召唤车同样扣塔25%并进入撞晕",pad.tower.health.hp==before-ceili(pad.tower.health.max_hp*0.25) and cart._phase=="dazed")

extends SiegeFixture
## 派对主人专项：原角色档案／地图入口、回旋弹、Buff与三角色兼容；不运行整套楼层测试。
var host: BonfireHost

func _ready() -> void:
	await _boot()
	host = load("res://scenes/actors/playable/bonfire_host.tscn").instantiate()
	d.entities().add_child(host)
	host.global_position = Vector2(1000,d.wall_foot_y()+180)
	host.set_physics_process(false)
	check("角色继承Princess且默认ALLY、相机不抢占",host is Princess and host.faction==Faction.Type.ALLY and not host.camera.enabled and GameState.player==d.pink)
	check("原WanderController提供NPC行为",host.controller is WanderController)
	Characters.scope("bonfire_host")
	check("独立角色档案路径",Characters.path("reactions.json",ReactionDB.PATH).contains("characters/bonfire_host"))
	check("反应使用派对主人的主持语气",str(ReactionDB.data()["lines"]).contains("报幕"))
	check("腋下腰侧1.4且其它1.0",is_equal_approx(TickleZones.info("armpit")["sensitivity"],1.4) and is_equal_approx(TickleZones.info("waist")["sensitivity"],1.4) and is_equal_approx(TickleZones.info("sole")["sensitivity"],1.0))
	check("魔法与通用CG档案独立",ReactionDB.magic("burst").size()>0 and CG.death_cg_for("rat","bonfire_host")=="host_rest" and CG.cgs("bonfire_host").size()==1)
	Characters.unscope()
	check("原角色档案没有被新档案替换",Characters.current()=="pink" and Characters.path("stats.json","","blue").contains("characters/blue"))
	for visual in GameState.VISUALS:
		check("立绘和头像存在："+visual,Dialogue.portrait_for(visual,"bonfire_host")!=null and Dialogue.head_for(visual,"bonfire_host")!=null)
	var actor := CGActor.make_npc("host","bonfire_host",Dialogue.npcs["bonfire_host"])
	add_child(actor)
	check("NPC舞台默认普通待机，角色身份固定",actor.visual=="normal" and actor.animator!=null and actor.reaction_key=="bonfire_host")
	actor.set_pose("chant","channel")
	actor.animator.update(0.1,"down",false,GameState.VISUALS.find("chant"))
	check("舞台使用自己魔法图，不回退粉蓝贴图",actor.sprite.texture.resource_path.ends_with("bonfire_host_magic.png"))
	actor.queue_free()
	Dialogue.line_character="bonfire_host"
	check("派对主人说话身份按原人物表识别",Dialogue.hero_npc()=="bonfire_host" and Dialogue.hero_speaker()==host.display_name())
	Dialogue.line_character=""
	for who in ["pink","blue"]:
		var old_actor:=CGActor.make_princess("old",who)
		add_child(old_actor)
		old_actor.set_pose("chant","channel")
		old_actor.animator.update(0.1,"down",false,GameState.VISUALS.find("chant"))
		check("原角色魔法图不被替换："+who, old_actor.sprite.texture.resource_path.ends_with("princess_blue_magic.png" if who=="blue" else "princess_magic.png"))
		old_actor.queue_free()
	await ribbon_checks()
	await aura_checks()
	await map_checks()
	print("\n==== 派对主人%s (%d 项失败，%d 项检查) ====" % ["全部通过" if failures==0 else "有失败",failures,checks])
	get_tree().quit(1 if failures else 0)

func ribbon_checks() -> void:
	for i in 3:
		host._set_state(PlayableCharacter.State.IDLE)
		host._ribbon_wait=0
		host.attack()
	check("最多两枚回旋，第三次不生成",get_tree().get_nodes_in_group("festival_ribbon").size()==2)
	var ribbon: FestivalRibbon = get_tree().get_nodes_in_group("festival_ribbon")[0]
	ribbon.set_physics_process(false)
	var at := host.global_position+Vector2(40,0)
	var rat := d.spawn("rat","",at)
	rat.set_physics_process(false)
	rat.health.max_hp=100
	rat.health.fill()
	rat.hurt_invuln_time=0
	rat._attack_invuln=0
	ribbon._sweep(at-Vector2(15,0),at+Vector2(15,0),host)
	ribbon._sweep(at-Vector2(15,0),at+Vector2(15,0),host)
	check("去程重叠只扣一次2血",rat.health.hp==98)
	ribbon._turn()
	ribbon._sweep(at+Vector2(15,0),at-Vector2(15,0),host)
	ribbon._sweep(at+Vector2(15,0),at-Vector2(15,0),host)
	check("回程另扣一次，总计4血",rat.health.hp==96)
	GameState.in_dialogue=true
	var age := ribbon._age
	ribbon._physics_process(1.0)
	check("对白期间弹体时间冻结",ribbon._age==age)
	GameState.in_dialogue=false
	ribbon.global_position=host.global_position+Vector2(0,-8)
	ribbon._physics_process(0.01)
	check("返回到身边回收",ribbon.is_queued_for_deletion())
	for n in get_tree().get_nodes_in_group("festival_ribbon"): n.queue_free()
	await get_tree().process_frame
	host._set_state(PlayableCharacter.State.IDLE)
	host._ribbon_wait=0
	host.attack()
	check("回收释放投掷名额",get_tree().get_nodes_in_group("festival_ribbon").size()==1)
	var r: FestivalRibbon=get_tree().get_nodes_in_group("festival_ribbon")[0]
	r.set_physics_process(false)
	var wall:=StaticBody2D.new()
	var cs:=CollisionShape2D.new()
	var shape:=RectangleShape2D.new()
	shape.size=Vector2(8,70);cs.shape=shape;wall.add_child(cs)
	d.entities().add_child(wall)
	wall.global_position=host.global_position+Vector2(30,-8)
	await get_tree().physics_frame
	r.direction=Vector2.RIGHT
	r._physics_process(0.2)
	check("去程扫掠墙体后折返，无穿墙",r.returning and r.global_position.x<wall.global_position.x)
	r._age=FestivalRibbon.LIFE
	r._physics_process(0.01)
	check("寿命结束清理",r.is_queued_for_deletion())
	wall.queue_free();rat.queue_free()
	await get_tree().process_frame
	var barrel: Node2D=load("res://scenes/objects/barrel.tscn").instantiate()
	d.entities().add_child(barrel)
	barrel.global_position=host.global_position+Vector2(30,0)
	var thrown:=FestivalRibbon.launch(host,Vector2.RIGHT)
	thrown.set_physics_process(false)
	await get_tree().physics_frame
	thrown._physics_process(0.2)
	check("远程普攻保留打碎中立木桶的规则",barrel.is_queued_for_deletion())
	thrown.queue_free()
	await get_tree().process_frame

func aura_checks() -> void:
	var at:=host.global_position
	d.blue.global_position=at+Vector2(20,0)
	d.blue.set_physics_process(false)
	var soldier: SiegeSoldier=d.soldiers[0]
	soldier.retreating=false
	soldier.visible=true
	soldier.set_physics_process(false)
	soldier.global_position=at+Vector2(0,20)
	var snow:=Snowman.new()
	d.entities().add_child(snow)
	snow.global_position=at+Vector2(-20,0)
	snow.set_physics_process(false)
	var rat:=d.spawn("rat","",at+Vector2(30,0))
	rat.set_physics_process(false)
	var boss:=fortress()
	boss.global_position=at+Vector2(90,90)
	var tower1:=tower(at+Vector2(40,20))
	var enemy_tower:=_tower9("resonance",at+Vector2(10,20))
	host.cast_magic(1)
	var aura:=host._festival.get_ref() as FestivalAura
	aura.set_process(false)
	check("实际一档施法为64范围4秒",aura.radius==64 and aura.time_left==4)
	check("自己、公主、士兵和召唤物获得友方Buff",[host,d.blue,soldier,snow].all(func(a):return a.has_buff(FestivalAura.ALLY_BUFF)))
	check("普通怪物与Boss获得风险Buff",rat.has_buff(FestivalAura.ENEMY_BUFF) and boss.has_buff(FestivalAura.ENEMY_BUFF))
	check("友塔与敌塔均被排除",not tower1.has_buff(FestivalAura.ALLY_BUFF) and not enemy_tower.has_buff(FestivalAura.ENEMY_BUFF))
	check("友方移速和全伤害倍率",is_equal_approx(host.stat_mul("speed"),1.2) and is_equal_approx(host.stat_mul("damage_dealt"),1.4))
	check("普通攻击和士兵／召唤物都由HitData统一增伤",[host,soldier,snow].all(func(a):return HitData.make_attack(a,10).damage==14))
	var h:=HitData.make_attack(host,10)
	check("复制HitData不重复放大",h.copy().damage==14 and h.damage==14)
	var tickle:=rat.make_tickle(host,10)
	check("敌人挠痒只放大一次35%",is_equal_approx(tickle.tickle,13.5))
	rat.global_position=at+Vector2(40,0)
	rat.health.max_hp=100;rat.health.fill();rat._attack_invuln=0
	StarBurst.cast_with(host,{"radius":48.0,"damage":10,"knockback":0.0,"stun":0.0},1,"magic_1",false)
	check("伤害魔法实际命中14血",rat.health.hp==86)
	aura.scan();aura.scan()
	check("反复维护Buff不叠层",host.buff_stacks(FestivalAura.ALLY_BUFF)==1)
	GameState.in_cutscene=true
	aura._process(1.0)
	var left:float=host.buffs[FestivalAura.ALLY_BUFF].time_left
	host.tick_timers(1.0)
	check("过场冻结光环和所赋Buff",aura.time_left==4 and host.buffs[FestivalAura.ALLY_BUFF].time_left==left)
	GameState.in_cutscene=false
	host.global_position+=Vector2(150,0)
	aura._process(0.01)
	check("光环跟随施法者",aura.global_position==host.global_position)
	d.blue.tick_timers(0.31)
	check("离圈后短时Buff自然消失",not d.blue.has_buff(FestivalAura.ALLY_BUFF))
	host.cast_magic(3)
	check("三档刷新为112范围8秒",aura.radius==112 and aura.time_left==8)
	host.cast_fatigue_burst()
	check("疲倦释放不缩短更长已有光环",aura.time_left==8)
	aura.queue_free()
	await get_tree().process_frame
	check("结束清除自己和敌人的光环状态",not host.has_buff(FestivalAura.ALLY_BUFF) and not rat.has_buff(FestivalAura.ENEMY_BUFF))
	host.cast_fatigue_burst()
	aura=host._festival.get_ref() as FestivalAura
	aura.set_process(false)
	check("单独疲倦释放为最大范围4秒",aura.radius==112 and aura.time_left==4)
	aura.queue_free();snow.queue_free()
	await get_tree().process_frame
	host.cast_magic(1)
	aura=host._festival.get_ref() as FestivalAura
	host._dead=true
	aura._process(0.01)
	check("施法者倒下结束光环",aura.is_queued_for_deletion())
	host._dead=false
	await get_tree().process_frame

func map_checks() -> void:
	for f in ["f6_opening_done","f6w_arrived","after_started","penance_book","after_done_d4_morning","after_done_d4_afternoon"]:GameState.set_flag(f)
	DayClock.set_time(3,DayClock.AFTERNOON)
	host.cast_magic(1)
	var aura_ref:=host._festival
	host._set_state(PlayableCharacter.State.IDLE)
	host._ribbon_wait=0
	host.attack()
	var old_ribbons:=get_tree().get_nodes_in_group("festival_ribbon").size()
	await main.change_level(Floors.scene("floor_06_upper"))
	await _wait(0.2)
	check("换图清理仍在运行的光环与回旋",old_ribbons>0 and not is_instance_valid(aura_ref.get_ref()) and get_tree().get_nodes_in_group("festival_ribbon").is_empty())
	var all:Array=[]
	for n in main.level.find_children("*","PlayableCharacter",true,false):
		if n.visible:all.append(n)
	check("普通小镇包含真实第三角色",all.any(func(c):return c is BonfireHost))
	var dev_was: Variant = DevConfig.override
	DevConfig.override=true
	var seen:=[]
	for i in 3:
		main.switch_character()
		seen.append(GameState.player.character_id)
	check("测试模式F2能循环三个角色",seen.has("pink") and seen.has("blue") and seen.has("bonfire_host"))
	DevConfig.override=false
	for c in all:
		if c.character_id=="pink":GameState.switch_control(c)
	var normal:=[]
	for i in 3:
		main.switch_character()
		normal.append(GameState.player.character_id)
	check("正常模式换人不会换到派对主人",not normal.has("bonfire_host") and normal.has("blue"))
	DevConfig.override=dev_was
	await main.change_level(Floors.scene("floor_06_war"))
	await _wait(0.2)
	var war_party: BonfireHost
	for n in main.level.find_children("*","BonfireHost",true,false): war_party=n
	check("战时角色不被原双人导演强制跟随",is_instance_valid(war_party) and not war_party.follow and war_party.controller is WanderController)
	var before: Node = GameState.player
	var event:=InputEventAction.new()
	event.action="switch_character";event.pressed=true
	main._unhandled_input(event)
	check("业务no_switch沿用原输入限制",bool(main.level.get("no_switch")) and GameState.player==before)
	await main.change_level(Floors.scene("floor_06_after"))
	await _wait(0.5)
	check("换图恢复业务主角",GameState.player.character_id=="pink")
	var towns: Array = main.level.find_children("*","AfterTown",true,false)
	var town:AfterTown=towns[0] if not towns.is_empty() else null
	check("战后导演只把蓝色识别为AfterBlue",town!=null and town.blue is BluePrincess)
	var party:BonfireHost=town.residents.get("after_bonfire_host") if town else null
	check("战后日程登记真实派对角色",is_instance_valid(party))
	if is_instance_valid(party):
		AfterTown.place(party,{"at":[46,24],"wander":1,"dir":"left","dialogue":"after_bonfire_host"})
		check("原日程入口配置位置与闲逛",party.controller is WanderController and party.global_position.distance_to(Cutscene.cell_to_world([46,24]))<1 and party.dialogue=="floor_06/after_bonfire_host")
		AfterTown.place(party,{"hidden":true})
		check("隐藏日程关闭交互",not party.visible and not party.get_node("Talk").enabled)
		AfterTown.place(party,{"hidden":false})
		check("日程恢复可见和交互",party.visible and party.get_node("Talk").enabled)

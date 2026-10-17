extends SiegeFixture
## 第 12 波（最终波）狂欢攻城堡垒的回归：车身几何、增援配额、六个机关、船员协作、美术 / CG、胜利流程。
func _ready() -> void:
	fixture_wave = 12
	await _boot()
	d.set_process(false)
	d.features.set_process(false)
	if "--effects-drops-only" in OS.get_cmdline_user_args():
		await _effects_and_drops()
		await _transport()
		await _cannon()
		print("FORTRESS EFFECTS / DROPS: %d checks, %d failures" % [checks,failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--resonance-types-only" in OS.get_cmdline_user_args():
		await _resonance_types()
		print("FORTRESS RESONANCE TYPES: %d checks, %d failures" % [checks,failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--wind-motion-only" in OS.get_cmdline_user_args():
		await _wind_motion()
		print("FORTRESS WIND / MOTION: %d checks, %d failures" % [checks,failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--freed-targets-only" in OS.get_cmdline_user_args():
		await _freed_targets_v2()
		print("FORTRESS V2 FREED TARGETS: %d checks, %d failures" % [checks,failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--round10-only" in OS.get_cmdline_user_args():
		await _round10()
		print("FORTRESS ROUND10: %d checks, %d failures" % [checks,failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--cars-only" in OS.get_cmdline_user_args():
		await _cars()
		print("FORTRESS V2 CARS: %d checks, %d failures" % [checks,failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--capacity-only" in OS.get_cmdline_user_args():
		await _capacity()
		print("FORTRESS V2 CAPACITY: %d checks, %d failures" % [checks,failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--geometry-only" in OS.get_cmdline_user_args():
		await _geometry()
		print("FORTRESS V2 GEOMETRY: %d checks, %d failures" % [checks,failures])
		get_tree().quit(1 if failures else 0)
		return
	await _geometry()
	await _capacity()
	await _guidance()
	await _arms()
	await _transport()
	await _cranes()
	await _cars()
	await _cannon()
	await _pairs_and_pause()
	await _round10()
	await _resonance_types()
	await _effects_and_drops()
	await _coops()
	await _art_and_cg()
	await _ending_v2()
	await _wait(1.5) # Let the normal victory fanfare finish before process teardown.
	print("FORTRESS V2: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)


func _wind_motion() -> void:
	await _reset()
	var h := _bubble_at(Vector2(700,600))
	var f := d.features
	f.gust_left = 1.6
	f.gust_dir = Vector2.LEFT
	f._gust_tick(0.5)
	check("left gust moves actual bubble, not hazard root",h._bubbles[0]["pos"].x == 645 and h.global_position.x == 700)
	h._from_left = true
	h._active(0.5)
	check("opposing gust overcomes natural bubble drift",h._bubbles[0]["pos"].x < 700)
	f.gust_dir = Vector2.RIGHT
	f.gust_left = 0.1
	var x: float = h._bubbles[0]["pos"].x
	f._gust_tick(1.0)
	check("right gust applies only its remaining duration",is_equal_approx(h._bubbles[0]["pos"].x-x,11))
	var at: Vector2 = h._bubbles[0]["pos"]
	f.gust_left = 1
	GameState.in_dialogue = true
	f._gust_tick(0.5)
	check("dialogue freezes wind clock and bubble",h._bubbles[0]["pos"]==at and f.gust_left==1)
	GameState.in_dialogue = false
	GameState.in_cutscene = true
	f._gust_tick(0.5)
	check("cutscene also freezes wind",h._bubbles[0]["pos"]==at and f.gust_left==1)
	GameState.in_cutscene = false
	h.warned = false
	h.blow(Vector2(100,0))
	check("warning bubbles do not move before activation",h._bubbles[0]["pos"]==at)
	h.queue_free()
	await get_tree().process_frame
	# Real capture path, then wind against an actual blocking tower.
	d.pink.global_position = Vector2(500,650)
	h = _bubble_at(d.pink.global_position)
	h._active(0)
	check("bubble captures only free player",h._bubbles[0]["held"]==d.pink and not d.pink.is_physics_processing())
	var before := d.pink.global_position
	h.blow(Vector2(25,0))
	check("gust carries passenger and bubble together",d.pink.global_position==before+Vector2(25,0) and h._bubbles[0]["pos"]==d.pink.global_position-Vector2(0,4))
	var obstacle := tower(Vector2(580,650))
	await get_tree().physics_frame
	await get_tree().physics_frame
	h.blow(Vector2(140,0))
	check("carried player cannot blow through tower",d.pink.global_position.x<580 and not d.pink.test_move(d.pink.global_transform,Vector2.ZERO))
	h.queue_free()
	await get_tree().process_frame
	check("deleting occupied bubble restores player",d.pink.is_physics_processing() and not d.pink.get_meta("siege_bubbled",false) and not d.pink.has_meta("siege_bubble_owner"))
	obstacle.queue_free()
	d.pink.global_position = Vector2(500,d.wall_foot_y()+30)
	h = _bubble_at(d.pink.global_position)
	h._active(0)
	before = d.pink.global_position
	h.blow(Vector2(0,-100))
	check("occupied bubble cannot cross wall",d.pink.global_position.y>before.y-90 and not d.pink.test_move(d.pink.global_transform,Vector2.ZERO))
	h._active(HazardBubbles.HOLD+0.1)
	check("normal pop restores player after wind",h._bubbles[0]["pop"] and d.pink.is_physics_processing() and not d.pink.has_meta("siege_bubble_owner"))
	h.queue_free()
	d.pink.global_position = Vector2(160,800)
	var m := d.spawn("rat","",Vector2(700,650))
	h = _bubble_at(m.global_position)
	h._active(0)
	check("ordinary soldier can still board bubble",h._bubbles[0]["mob"]==m and not m.is_physics_processing())
	before = m.global_position
	h.blow(Vector2(-30,0))
	check("gust carries transported soldier",m.global_position==before+Vector2(-30,0))
	h._end()
	check("ending bubble releases soldier immediately",m.is_physics_processing() and not m.has_meta("siege_bubble_owner"))
	h = _bubble_at(Vector2(900,650))
	m = d.spawn("rat","",Vector2(900,650))
	h._active(0)
	check("freed-passenger fixture starts with real capture",h._bubbles[0]["mob"]==m)
	m.queue_free()
	await get_tree().process_frame
	h.blow(Vector2(10,0))
	h._active(0.1)
	check("freed passenger does not cause invalid instance assignment",h._bubbles[0]["pop"] and h._bubbles[0]["mob"]==null)
	h.queue_free()
	await _reset()
	# The giant edge is in range even though its center is far away.
	var b := fortress()
	var original := b.global_position
	b.set_physics_process(true)
	h = _bubble_at(b.global_position+Vector2(-CarnivalFortress.HALF.x,0))
	h._active(0)
	check("bubble cannot transport giant from its hull edge",h._bubbles[0]["mob"]==null and b.is_physics_processing() and b.global_position==original)
	f.gust_left = 1
	f.gust_dir = Vector2.LEFT
	f._gust_tick(0.5)
	check("gust cannot shove fortress hull sideways",b.global_position==original)
	b.set_physics_process(false)
	h.queue_free()
	for phase in 2:
		b.expanded = phase==1
		b.expand_left = 0
		b.global_position = Vector2(880,900)
		b.recoil = Vector2.ZERO
		b.add_buff("siege_carnival",10)
		var y := b.global_position.y
		step(b,0.5)
		check("phase %d slow march ignores carnival speed" % phase,absf(b.global_position.y-(y-(2 if phase else 4)))<0.02)
		for i in 10: b.apply_knockback(b.global_position+Vector2(0,20),200)
		y = b.global_position.y
		step(b,0.5)
		check("phase %d rear hits cannot cause forward rush" % phase,absf(b.global_position.y-(y-(2 if phase else 4)))<0.02)
		b.apply_knockback(b.global_position-Vector2(0,20),400)
		y = b.global_position.y
		step(b,0.2)
		check("phase %d front hit really knocks hull back" % phase,b.global_position.y>y+20)
		b.recoil = Vector2.ZERO
		b.apply_knockback(b.global_position-Vector2(20,0),100)
		var old_x := b.global_position.x
		step(b,0.1)
		check("phase %d side knockback remains possible" % phase,b.global_position.x>old_x)
		b.recoil = Vector2(0,-1000)
		y = b.global_position.y
		step(b,0.1)
		check("phase %d external recoil cannot bypass forward cap" % phase,b.global_position.y>=y-(0.4 if phase else 0.8)-0.02)
	await _reset()
func _geometry() -> void:
	await _reset()
	var b:=fortress()
	check("giant world footprint 1176 x 400",b.footprint().size==Vector2(1176,400))
	check("both sides retain 292px",is_equal_approx(b.footprint().position.x,292) and is_equal_approx(d.map_size().x-b.footprint().end.x,292))
	d.pink.global_position=b.global_position+Vector2(-612,0)
	await get_tree().physics_frame
	check("giant hull really blocks player collision",d.pink.test_move(d.pink.global_transform,Vector2(50,0)))
	d.pink.global_position=Vector2(b.global_position.x,b.footprint().position.y-12)
	var next:=b.global_position+Vector2(0,-4)
	check("advancing hull pushes a nearby free actor outside",b._push_clear(next) and not b.footprint(next).grow(10).has_point(d.pink.global_position))
	var original:=b.global_position
	b.global_position=Vector2(880,d.wall_foot_y()+236)
	d.pink.global_position=Vector2(880,d.wall_foot_y()+18)
	var pinned:=d.pink.global_position
	check("wall pin stops hull without teleporting actor through it",not b._push_clear(Vector2(880,d.wall_foot_y()+200)) and d.pink.global_position==pinned)
	b.global_position=original
	d.pink.global_position=Vector2(160,800)
	await get_tree().physics_frame
	var at:=b.global_position+Vector2(-650,0)
	check("edge distance rather than center",is_equal_approx(FortressRules.distance(b,at),62))
	check("spatial query finds distant center giant from edge",d.enemies_near(at,70).has(b))
	b.receive_hit(HitData.make_attack(d.pink,10))
	var hp:=b.health.hp
	check("same swing cannot double count hull",not b.receive_hit(HitData.make_attack(d.pink,10)) and b.health.hp==hp)
	b._attack_invuln=0
	b.receive_hit(HitData.make_attack(d.pink,8,0,true))
	check("tower damage still 25 percent",b.health.hp==hp-2)
	check("area damage inside hull uses occupied geometry",d.enemies_near(b.global_position+Vector2(200,0),8).has(b))
	d.pink.global_position=b.global_position+Vector2(-620,0)
	b._attack_invuln=0
	hp=b.health.hp
	StarBurst.cast_with(d.pink,{"radius":42.0,"damage":2,"knockback":0.0,"stun":0.0},1,"magic_1",false)
	check("player burst can damage a far-center hull edge",b.health.hp==hp-2)
	var y:=b.global_position.y
	step(b,0.5)
	check("normal speed eight px per sec",absf(b.global_position.y-(y-4))<0.02)
	var expand_hp:=int(FortressRules.data()["expand_hp"])
	b.health.set_hp(expand_hp)
	step(b,1.6)
	check("one expansion with no healing",b.expanded and b.phase_count==1 and b.health.hp==expand_hp)
	b.apply_knockback(b.global_position-Vector2(0,20),100)
	check("expanded hull can be knocked back",b.recoil.length()>0)
	var first:=tower(b.global_position+Vector2(-500,0))
	var second:=tower(b.global_position+Vector2(500,0))
	var spared:=tower(b.global_position+Vector2(0,0))
	var a:=first.health.hp;var c:=second.health.hp;var e:=spared.health.hp
	b._crush(0.5)
	check("separate tracks crush only contacted towers",first.health.hp<a and second.health.hp<c and spared.health.hp==e)
	d.cam.set_zoom_level(0.30,true)
	check("final battle camera permits 0.30",is_equal_approx(d.cam.zoom,0.30))
func _capacity() -> void:
	await _reset()
	var b:=fortress()
	var r:=d.reinforcements
	check("boss replaces finite opening queue",r.active and d._queue.is_empty())
	check("rate starts ten per second",r.rate()==10)
	for i in 5:
		r.elapsed=i*45
		check("reinforcement tier %d" % i,is_equal_approx(r.rate(),10+i*5))
	GameState.in_dialogue=true
	var t:=r.elapsed
	r.tick(10)
	check("reinforcement clock freezes in dialogue",r.elapsed==t)
	GameState.in_dialogue=false
	r.elapsed=0
	var ticket:=r.reserve(799)
	check("all in-flight slots share 800 cap",r.remaining(ticket)==799 and r.capacity()==1)
	check("formation skips when only partial capacity remains",d.teamwork.spawn_formation("cart_escort",Vector2(50,1000)).is_empty() and r.capacity()==1)
	var m:=d.spawn("rat","",Vector2(50,1000))
	check("last unreserved slot may spawn",m!=null and r.capacity()==0)
	check("other sources cannot exceed cap",d.spawn("rat")==null)
	var offspring:Monster=load("res://scenes/actors/monsters/split_slime.tscn").instantiate()
	d.entities().add_child(offspring)
	check("generic scene offspring cannot bypass final cap",offspring.is_queued_for_deletion())
	r.tick(2)
	check("full arena discards backlog",r.credit<1 and r.spawned==0)
	r.consume(ticket)
	check("reservation conversion creates one slot",r.capacity()==1)
	r.release(ticket)
	check("cancelled transport releases all remaining slots",r.reserved==0)
	var accepted_child:Monster=load("res://scenes/actors/monsters/split_slime.tscn").instantiate()
	d.entities().add_child(accepted_child)
	check("generic child factory is registered when capacity exists",d.monsters.has(accepted_child))
	accepted_child.queue_free()
	await get_tree().process_frame
	check("deferred child setup tolerates deleted instance",not is_instance_valid(accepted_child))
	var own:=b.reserve_crew(100)
	check("boss crew cap follows fortress.json (%d)" % b.max_crew,own==b.max_crew and b.reserve_crew(2)==0)
	b.reserved_crew=0
	for n in d.monsters:
		if is_instance_valid(n) and n!=b: n.queue_free()
	await get_tree().process_frame
	r.tick(0.1)
	check("after capacity frees natural spawning resumes",r.spawned==1)
func _guidance() -> void:
	await _reset()
	var b:=fortress()
	var c:=d.pink
	c.global_position=Vector2(100,500)
	var shot:=FortressOrdnance.missile(Vector2(100,700),c)
	var angle:float=shot["angle"]
	c.global_position=Vector2(300,700)
	FortressOrdnance.tick_missile(b.mechanisms,shot,0.1)
	check("guided missile has turn inertia",absf(angle_difference(angle,shot["angle"]))<=PI*0.05+0.001)
	shot["t"]=2.05
	FortressOrdnance.tick_missile(b.mechanisms,shot,0.1)
	angle=shot["angle"]
	c.global_position=Vector2(0,100)
	shot["t"]=2.65
	FortressOrdnance.tick_missile(b.mechanisms,shot,0.1)
	check("locked dash cannot turn after target moves",is_equal_approx(angle,shot["angle"]) and shot["state"]=="dash")
	b.mechanisms.start("missiles")
	step(b,6)
	check("missile job ends and cooldown starts after finish",b.mechanisms.jobs.is_empty() and b.mechanisms.cds["missiles"]>0)
func _arms() -> void:
	await _reset()
	var b:=fortress()
	d.pink.global_position=b.shoulder(-1)+Vector2(-120,0)
	d.blue.global_position=Vector2(1600,500)
	check("hand skill starts with a ground target",b.mechanisms.start("hands"))
	step(b,2.55)
	var job:Dictionary=b.mechanisms.jobs[0]
	var arm:Dictionary=job["arms"][0]
	var pos:Vector2=arm["p"]
	d.pink.global_position=pos+Vector2(-40,0)
	step(b,0.3)
	check("open palm stops tracking before closure",arm["phase"]=="lock" and arm["p"]==pos)
	d.pink.global_position=pos
	step(b,0.4)
	check("real contact captures after warning",d.pink.status.is_grabbed() and arm["phase"]=="drag")
	check("other mother attacks cannot chain a held target",not b.strike_tools(d.pink,22,"sole","missiles"))
	b.mechanisms.cancel_all()
	check("cancelled hand restores control",not d.pink.status.is_grabbed())
	check("cancel retains short mother protection",b.protected(d.pink))
func _transport() -> void:
	await _reset()
	var b:=fortress()
	check("dual front rockets reserve actual crew",b.mechanisms.start("rockets") and b.reserved_crew==12 and d.reinforcements.reserved==12)
	var job:Dictionary=b.mechanisms.jobs[0]
	check("ground and wall batches differ in timing",job["shots"][0]["launch"]==0 and job["shots"][3]["launch"]==1.6)
	step(b,0.9)
	var point:Vector2=job["shots"][0]["at"]
	d.pink.global_position+=Vector2(0,-150)
	step(b,0.5)
	check("landing point stays fixed after locking",job["shots"][0]["at"]==point)
	step(b,2.5)
	check("landing converts reservations exactly once",b.reserved_crew==0 and d.reinforcements.reserved==0 and b.crew.size()==12)
	check("natural aircraft can relay real landed crew",b.crew.any(func(r): return r.get_ref().get_meta("rocket_landed",false)))
func _cranes() -> void:
	await _reset()
	var b:=fortress()
	b.expanded=true
	var first:=tower(b.global_position+Vector2(-650,-80))
	var second:=tower(b.global_position+Vector2(650,-80))
	var original:=first.global_position
	check("expanded cranes select different towers",b.mechanisms.start("crane") and b.mechanisms.jobs[0]["lifts"].size()==2)
	var job:Dictionary=b.mechanisms.jobs[0]
	step(b,2.85)
	var cable:=b.mechanisms.live_target(job,0)
	cable.receive_hit(HitData.make_attack(d.pink,6))
	check("cut one cable returns only its tower",first.global_position==original and not first.has_meta("fortress_lift") and second.has_meta("fortress_lift"))
	job["objects"][1].queue_free()
	await get_tree().process_frame
	step(b,0.1)
	check("freed cable safely returns remaining tower",not second.has_meta("fortress_lift"))
	b.mechanisms.cancel_all()
	b.mechanisms.cds["crane"]=0
	b.mechanisms.start("crane")
	step(b,8.8)
	check("failed dual lift stores only one extra shell",b.empowered and not SiegeTools.alive(first) and not SiegeTools.alive(second))
func _cars() -> void:
	await _reset()
	var b:=fortress()
	b.mechanisms.start("convoy")
	var job:Dictionary=b.mechanisms.jobs[0]
	check("convoy has three independent launch times",job["cars"][0]["launch"]==1.4 and job["cars"][4]["launch"]==3.2 and job["cars"][7]["launch"]==5.0)
	step(b,1.5)
	check("only first batch launches initially",b.carts.size()==4)
	step(b,4)
	check("all ten cars and tickets reconcile",b.carts.size()==10 and d.reinforcements.reserved==0)
	var car:SiegeCart=b.carts[0].get_ref()
	check("fortress tuning does not change ordinary cart constants",car._fortress_speed==190 and SiegeCart.TOP_SPEED==150)
	var decoy:=tower(Vector2(100,600),"decoy")
	var redirected:=d.spawn("cart","",decoy.global_position) as SiegeCart
	redirected.configure_fortress(b.mechanisms,decoy.global_position,false)
	redirected.set_physics_process(false)
	var wall_before:=d.wall_hp
	var decoy_before:=decoy.health.hp
	redirected._fortress_tick(0.01)
	check("fortress car hitting a decoy does not damage wall",d.wall_hp==wall_before)
	check("decoy absorbs actual vehicle impact",decoy.health.hp<decoy_before)
	var wall_car:=d.spawn("cart","",Vector2(100,d.wall_foot_y()+18)) as SiegeCart
	wall_car.configure_fortress(b.mechanisms,wall_car.global_position,false)
	wall_car.set_physics_process(false)
	wall_car._fortress_tick(0.01)
	check("fortress wall impact uses configured damage",is_equal_approx(wall_before-d.wall_hp,80))
func _cannon() -> void:
	await _reset()
	var b:=fortress()
	b.mechanisms.start("cannon")
	var job:Dictionary=b.mechanisms.jobs[0]
	var core:=b.mechanisms.live_target(job,0)
	var hp:=b.health.hp
	core.receive_hit(HitData.make_attack(d.pink,3))
	b.mechanisms.live_target(job,1).receive_hit(HitData.make_attack(d.blue,3))
	check("both core faces share six point interrupt",b.health.hp==hp-294 and b.mechanisms.jobs.is_empty())
	b.mechanisms.cds["cannon"]=0
	b.empowered=true
	b.mechanisms.start("cannon")
	job=b.mechanisms.jobs[0]
	check("stolen tower grants fourth shot once",job["count"]==4 and not b.empowered)
	step(b,4.1)
	check("core closes before firing phase",b.mechanisms.live_target(job,0)==null and job["shots"].size()==4)
	step(b,0.1)
	var first:Dictionary=job["shots"][0]
	var at:Vector2=first["at"]
	d.pink.global_position+=Vector2(100,-100)
	step(b,0.3)
	check("shell lock stays fixed before launch",first["locked"] and first["at"]==at)
	step(b,6)
	check("four independent shots complete",job["shots"].all(func(s): return s["done"]) and b.mechanisms.jobs.is_empty())
func _pairs_and_pause() -> void:
	await _reset()
	var b:=fortress()
	b.expanded=true
	b.mechanisms.start("hands")
	var before:float=b.mechanisms.jobs[0]["t"]
	GameState.in_dialogue=true
	b.mechanisms.tick(20)
	check("all mechanism clocks pause",b.mechanisms.jobs[0]["t"]==before)
	GameState.in_dialogue=false
	check("five designed pair identities",FortressMechanisms.PAIRS==[["hands","missiles"],["convoy","rockets"],["crane","cannon"],["tornado_launcher","magnet"],["portal_drop","fireworks"]])
	check("clear side corridors pass safety graph",b.mechanisms.safe_pair("missiles"))
func _effect_count(kind: String) -> int:
	return get_tree().get_nodes_in_group("fortress_skill_fx").filter(func(n): return not n.is_queued_for_deletion() and n.kind==kind).size()

func _effects_and_drops() -> void:
	await _reset()
	var item := ItemData.new()
	item.id = "siege_drop_expiry_test"
	item.max_stack = 99
	var drop := WorldItem.spawn(d.entities(),Vector2(700,600),item,1,false)
	drop.set_process(false)
	check("battle drop starts twenty-second lifetime",is_equal_approx(drop._siege_life_left,20))
	drop._process(19.9)
	check("drop remains available just before deadline",not drop.is_queued_for_deletion())
	GameState.in_dialogue = true
	drop._process(10)
	check("dialogue freezes drop expiry",not drop.is_queued_for_deletion() and is_equal_approx(drop._siege_life_left,0.1))
	GameState.in_dialogue = false
	GameState.in_cutscene = true
	drop._process(10)
	check("cutscene freezes drop expiry",not drop.is_queued_for_deletion() and is_equal_approx(drop._siege_life_left,0.1))
	GameState.in_cutscene = false
	drop._process(0.11)
	check("twenty-second expiry queues actual removal",drop.is_queued_for_deletion())
	await get_tree().process_frame
	check("expired drop really leaves scene",not is_instance_valid(drop))
	drop = WorldItem.spawn(d.entities(),Vector2(700,600),item,1,false)
	var remaining := drop._siege_life_left
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	check("pause menu freezes real drop process",drop._siege_life_left==remaining)
	get_tree().paused = false
	drop.queue_free()
	drop = WorldItem.spawn(d.entities(),Vector2(700,600),item,1,false)
	drop.set_process(false)
	var have := GameState.inventory.count(item.id)
	drop._on_body_entered(d.pink)
	check("unexpired drops retain ordinary pickup",drop.is_queued_for_deletion() and GameState.inventory.count(item.id)==have+1)
	var outside := Node2D.new()
	add_child(outside)
	var permanent := WorldItem.spawn(outside,Vector2(0,0),item,1,false)
	permanent.set_process(false)
	permanent._process(100)
	check("other map drops have no battle expiry",permanent._siege_life_left<0 and not permanent.is_queued_for_deletion())
	outside.queue_free()
	var drops: Array[WorldItem] = []
	for i in 100:
		var n := WorldItem.spawn(d.entities(),Vector2(900,600),item,1,false)
		n.set_process(false)
		n._process(20)
		drops.append(n)
	await get_tree().process_frame
	check("one hundred expired drops release all nodes",drops.all(func(n): return not is_instance_valid(n)))
	GameState.inventory.remove(item.id,1)
	var b := fortress()
	b.mechanisms.start("rockets")
	step(b,2.1)
	var job: Dictionary = b.mechanisms.jobs[0]
	check("first transport landings each create explosion",_effect_count("rockets")==3 and b.crew.size()==6)
	var count := _effect_count("rockets")
	b.mechanisms._rockets(job)
	check("completed landing callbacks cannot duplicate burst",_effect_count("rockets")==count and b.crew.size()==6)
	check("launch events have separate plume",_effect_count("launch")==6)
	var effect := b.mechanisms.burst(Vector2(700,600),48,"rockets")
	effect.set_process(false)
	GameState.in_dialogue = true
	effect._process(0.4)
	check("battle effects freeze in dialogue",effect.elapsed==0)
	GameState.in_dialogue = false
	effect._process(0.2)
	check("explosion animates across frames",effect.elapsed>0 and not effect.is_queued_for_deletion())
	effect._process(2)
	check("effect deletes itself after animation",effect.is_queued_for_deletion())
	await _reset()
	check("battle clear removes all effect nodes",get_tree().get_nodes_in_group("fortress_skill_fx").is_empty())

func _resonance_types() -> void:
	await _reset()
	var b := fortress()
	var co := b.mechanisms.coop
	var car := d.spawn("cart","",b.global_position+Vector2(-650,0)) as SiegeCart
	car.configure_fortress(b.mechanisms,Vector2(100,d.wall_foot_y()+20),false)
	var ladder := LivingLadder.new()
	ladder.position = Vector2(500,d.wall_foot_y())
	for i in 3:
		ladder.geckos.append(d.spawn("gecko","",ladder.position+Vector2(i*8,20)))
	d.entities().add_child(ladder)
	ladder.set_physics_process(false)
	check("fixture has live ladder in shared enemy tower group",ladder.is_alive() and ladder.is_in_group("siege_enemy_tower"))
	check("ladder alone is not a resonance source",not co.start("resonance") and co.jobs.is_empty())
	var other := Node2D.new()
	d.entities().add_child(other)
	other.add_to_group("siege_enemy_tower")
	check("generic group member without kind is skipped",not co.start("resonance"))
	var signal_tower := EnemyTower.new()
	signal_tower.kind = "airdrop"
	d.entities().add_child(signal_tower)
	signal_tower.global_position = car.global_position+Vector2(0,-40)
	signal_tower.set_physics_process(false)
	check("other real tower kinds are skipped",not co.start("resonance"))
	signal_tower.kind = "resonance"
	signal_tower.global_position = Vector2(-1000,300)
	check("far resonance tower remains out of range",not co.start("resonance"))
	signal_tower.global_position = car.global_position+Vector2(0,-40)
	check("mixed group still finds real resonance tower",co.start("resonance"))
	check("selected source is tower rather than ladder",co.jobs.size()==1 and co.jobs[0]["members"][0]==signal_tower)
	co.tick(0.3)
	check("valid tower still speeds convoy",is_equal_approx(car.convoy_speed(),1.35))
	check("ladder stays targetable and unclaimed",ladder.is_in_group("siege_enemy_tower") and not ladder.has_meta("fortress_coop"))
	signal_tower.queue_free()
	co.tick(0.1)
	check("queued source immediately cancels job and speed",co.jobs.is_empty() and is_equal_approx(car.convoy_speed(),1.0) and not car.has_meta("fortress_speed_source"))
	check("queued tower cannot start another command",not co.start("resonance"))
	await get_tree().process_frame
	check("freed tower and remaining ladder are safe",not co.start("resonance") and co.jobs.is_empty())
	other.queue_free()
	await _reset()

func _coops() -> void:
	await _reset()
	var b:=fortress()
	var co:=b.mechanisms.coop
	check("all six monster synergies retained",co.CDS.size()==6)
	for i in 2: d.spawn("goblin_engineer","",b.global_position+Vector2(-620 if i==0 else 620,0)).set_physics_process(false)
	check("engineers cannot heal outside cannon charge",not co.start("repair"))
	for n in d.monsters:
		if is_instance_valid(n) and n!=b: n.queue_free()
	await get_tree().process_frame
	var car:=d.spawn("cart","",b.global_position+Vector2(-650,0)) as SiegeCart
	car.configure_fortress(b.mechanisms,Vector2(100,d.wall_foot_y()+20),false)
	for i in 2: d.spawn("shield_crab","",car.global_position+Vector2(-20+i*40,-20))
	check("shield convoy finds natural members",co.start("escort"))
	co.tick(0.3)
	check("shield guards attach to the actual car",car.get_meta("escorts",[]).size()==2)
	co.cancel_all()
	check("guard cancellation restores prior formation",car.get_meta("escorts",[]).is_empty())
	var slime:=d.spawn("warm_slime","",car.global_position+Vector2(-30,0))
	check("warm slime joins a real fortress car",co.start("warm"))
	co.tick(0.3)
	car.stun(3)
	co.tick(0.1)
	check("frozen cooperation member restores owned physics",not slime.has_meta("fortress_coop") and slime.is_physics_processing())
	car._stun_left=0
	car.state=Monster.State.WANDER
	var signal_tower:=EnemyTower.new()
	signal_tower.kind="resonance"
	d.entities().add_child(signal_tower)
	signal_tower.global_position=car.global_position+Vector2(0,-40)
	signal_tower.set_physics_process(false)
	check("resonance binds source to moving cars",co.start("resonance"))
	co.tick(0.3)
	check("convoy speed comes from live source",is_equal_approx(car.convoy_speed(),1.35))
	signal_tower.queue_free()
	await get_tree().process_frame
	co.tick(0.1)
	check("removed command tower cancels speed immediately",is_equal_approx(car.convoy_speed(),1.0))
	d.spawn("bat_swarm","",car.global_position+Vector2(0,-50))
	b.reserve_crew(1)
	var crew:=b.land_crew(car.global_position+Vector2(10,0),1)
	check("bats relay existing rocket crew",co.start("airlift"))
	co.tick(0.3)
	co.tick(1.4)
	check("airlift moves one soldier without duplicating",crew.size()==1 and crew[0].get_meta("airlifted",false) and b.crew.size()==1)
	co.cancel_all()
	for i in 2: d.spawn("goblin_engineer","",b.global_position+Vector2(-620 if i==0 else 620,14))
	b.health.set_hp(3500)
	b.mechanisms.start("cannon")
	check("engineers join a real cannon charge",co.start("repair"))
	for i in 20: co.tick(0.16)
	check("continuous three second repair heals at most 84",b.healed_total>0 and b.healed_total<=84)
	co.cancel_all()
	b.mechanisms.cancel_all()
	b.mechanisms.cds["hands"]=0
	d.pink.global_position=b.shoulder(-1)+Vector2(-150,0)
	d.spawn("hook","",d.pink.global_position+Vector2(-90,0))
	b.mechanisms.start("hands")
	step(b,1.05)
	check("hook pairs with visible hunting hand",co.start("hook"))
	co.tick(0.3)
	check("hook does not grab during aiming",not d.pink.is_force_moving())
	for i in 50: co.tick(0.02)
	check("visible hook contact owns collision movement",d.pink.get_meta("siege_puppet_move",false) and d.pink.is_force_moving() and d.pink.is_physics_processing())
	co.cancel_all()
	b.mechanisms.cancel_all()
	check("cooperation cancellation leaves no member claims",co.jobs.is_empty() and not d.pink.status.is_grabbed())
	b.healed_total=0
	b.health.set_hp(3500)
	for i in 10: b.heal_from_engineers(84)
	check("shared engineer healing cannot exceed 336",b.healed_total==336 and b.health.hp==3836)
func _art_and_cg() -> void:
	var meta:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/siege/fortress_v2.json"))
	check("generated sprite metadata matches giant footprint",Vector2(meta["body"][0],meta["body"][1])==Vector2(1176,400))
	for who in ["pink","blue"]:
		var path := "res://data/siege_cgs.json" if who=="pink" else "res://data/characters/blue/siege_cgs.json"
		var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		var entry:Dictionary=data["cgs"]["death_siege_carnival_fortress"]
		check("new CG registered for "+who,data["death"]["carnival_fortress"]=="death_siege_carnival_fortress" and entry["steps"].size()>=10)
		check("new giant CG texture for "+who,data["actors"]["carnival_fortress"]["sprite"]["texture"].ends_with("fortress_v2_hull.png"))
		var text := JSON.stringify(entry)
		check("retired puzzle instructions absent from "+who,"方向杆" not in text and "蓝阀" not in text and "回收磁场" not in text)

func _ending_v2() -> void:
	await _reset()
	var b:=fortress()
	var t:=tower(b.global_position+Vector2(-650,0))
	var at:=t.global_position
	b.mechanisms.start("crane")
	step(b,3)
	b.health.damage(99999)
	check("death immediately locks victory and ends endless stream",d.victory_locked and not d.reinforcements.active and d.reinforcements.reserved==0)
	check("death returns suspended original tower",t.global_position==at and not t.has_meta("fortress_lift"))
	check("no spawn permitted after victory",d.spawn("rat")==null)
	await _wait(1.7)
	check("victory needs no remaining enemy clearance",d.state=="won")

func _freed_targets_v2() -> void:
	await _reset()
	var b:=fortress()
	b.expanded=true
	var t:=tower(b.global_position+Vector2(-650,-80))
	tower(b.global_position+Vector2(650,-80))
	b.mechanisms.start("crane")
	var job:Dictionary=b.mechanisms.jobs[0]
	job["objects"][0].queue_free()
	check("queued references are skipped before conversion",b.mechanisms.live_target(job,0)==null)
	await get_tree().process_frame
	check("fixture contains a truly freed reference",not is_instance_valid(job["objects"][0]))
	step(b,2)
	check("freed slot preserves independent surviving cable",b.mechanisms.live_target(job,0)==null and b.mechanisms.live_target(job,1)!=null)
	check("deleted cable safely returns original tower",not t.has_meta("fortress_lift"))
	b.mechanisms.cancel_all()
	check("cancel after freed target clears remaining jobs",b.mechanisms.jobs.is_empty())


## 第十轮加强：血量 / 节奏数据、登场车队和车头舱门、五个新机关、护盾柱减伤、超载三机关、最终波固定攻城大队。
func _round10() -> void:
	var data := FortressRules.data()
	await _reset()
	var b:=fortress()
	var m:=b.mechanisms as FortressSkills
	check("round10 fortress uses FortressSkills with data hp %d" % b.health.max_hp, m != null and b.health.max_hp==int(data["hp"]) and int(data["hp"])==6000)
	check("round10 default pace speeds skill timelines", is_equal_approx(FortressSkills.new().pace, 1.0/float(data["warn_mult"])) and float(data["warn_mult"])<1.0)
	check("round10 hands reach / speed tuned", float(data["hand_reach"])>=1.5 and float(data["hand_speed"])>=1.4)
	# 登场车队
	b._introduced=false
	b.set_physics_process(true)
	step(b,0.05)
	var intro:=b.carts.filter(func(r): return SiegeTools.alive(r.get_ref()) and r.get_ref().has_meta("fortress_hatch")).size()
	check("round10 intro lines up %d carts in front" % intro, intro==int(data["intro_carts"]))
	# 车头舱门
	var before:=b.carts.size()
	check("round10 hatch releases a cart row", m.start("hatch") and b.carts.size()-before==int(data["hatch_count"]))
	await _reset()
	b=fortress()
	m=b.mechanisms as FortressSkills
	# 龙卷发射器
	var hz0:=get_tree().get_nodes_in_group("siege_hazard").filter(func(h): return h is HazardTornado).size()
	check("round10 tornado launcher starts", m.start("tornado_launcher"))
	var tornadoes:=get_tree().get_nodes_in_group("siege_hazard").filter(func(h): return h is HazardTornado)
	var crew:=d.monsters.filter(func(x): return SiegeTools.alive(x) and x.has_meta("fortress_crew")).size()
	check("round10 launches %d chasing tornadoes carrying crew (%d)" % [tornadoes.size()-hz0, crew],
		tornadoes.size()-hz0==int(data["tornado_count"]) and tornadoes.all(func(t): return t.chase) and crew>=int(data["tornado_count"]))
	m.cancel_all()
	await _reset()
	b=fortress()
	m=b.mechanisms as FortressSkills
	# 传送门空降：船员落在入口，被送上城墙
	check("round10 portal drop starts", m.start("portal_drop"))
	var portal:HazardPortalPair=(m.jobs[0]["portal"] as WeakRef).get_ref()
	check("round10 portal exits on the wall top", portal!=null and portal.exit.y<d.wall_foot_y())
	for i in 240:
		portal._process(1.0/60)
		step(b,1.0/60)
	var up:=d.monsters.filter(func(x): return SiegeTools.alive(x) and x.has_meta("fortress_crew") and x.get_meta("siege_on_wall",false)).size()
	check("round10 crew poured through the portal onto the wall (%d)" % up, up>0)
	m.cancel_all()
	await _reset()
	b=fortress()
	m=b.mechanisms as FortressSkills
	# 烟花弹幕
	d.pink.global_position=b.global_position+Vector2(0,-b.footprint().size.y/2-200)
	check("round10 fireworks start", m.start("fireworks"))
	var job:Dictionary=m.jobs[0]
	step(b,float(job["life"])+0.2)
	var landed:=(job["shells"] as Array).filter(func(sh): return sh["done"]).size()
	check("round10 all firework shells landed (%d/%d)" % [landed, (job["shells"] as Array).size()], landed==(job["shells"] as Array).size() and landed>=int(data["firework_waves"])*int(data["firework_shells"]))
	m.cancel_all()
	await _reset()
	b=fortress()
	m=b.mechanisms as FortressSkills
	# 磁吸车头：粉色公主被往车头拉
	var front:=m._magnet_point()
	d.pink.global_position=front+Vector2(0,-180)
	d.pink.set_physics_process(true)
	var dist0:=d.pink.global_position.distance_to(front)
	check("round10 magnet starts", m.start("magnet"))
	for i in 60:
		step(b,1.0/60)
		await get_tree().physics_frame
	check("round10 magnet pulls pink toward the hull (%.0f -> %.0f)" % [dist0, d.pink.global_position.distance_to(front)], d.pink.global_position.distance_to(front)<dist0-8.0)
	m.cancel_all()
	await _reset()
	b=fortress()
	m=b.mechanisms as FortressSkills
	# 护盾柱：立着时母车受伤 ×0.2，柱子全倒恢复
	check("round10 shield pillars rise", m.start("shields") and m.shield_up() and is_equal_approx(m.damage_mult(), float(data["shield_reduction"])))
	b._attack_invuln=0
	b._full_invuln=0
	var hp:=b.health.hp
	b.receive_hit(HitData.make_attack(d.pink,10,0.0))
	var shielded:=hp-b.health.hp
	var sjob:Dictionary=m.jobs.filter(func(j): return j["kind"]=="shields")[0]
	for i in sjob["objects"].size():
		var pillar:=FortressJobs.live_target(sjob,i)
		if pillar:
			m.target_hit(pillar,999)
	b._attack_invuln=0
	b._full_invuln=0
	hp=b.health.hp
	b.receive_hit(HitData.make_attack(d.pink,10,0.0))
	check("round10 pillars cut damage to %d, broken pillars restore %d" % [shielded, hp-b.health.hp], shielded>0 and shielded<=3 and not m.shield_up() and hp-b.health.hp>=shielded*3)
	await _reset()
	b=fortress()
	m=b.mechanisms as FortressSkills
	# 超载：剩 30% 血 → 每轮三个、增援最高档
	b.expanded=true
	b.expand_left=0
	b.health.set_hp(int(b.health.max_hp*float(data["overdrive_ratio"]))-1)
	step(b,0.1)
	check("round10 overdrive at 30% hp maxes reinforcements", b.overdrive and d.reinforcements.tier()>=4)
	check("round10 overdrive allows three skills at once", m.start("missiles") and m.start("magnet") and m.start("fireworks") and m.main_jobs().size()==3)
	m.cancel_all()
	# 最终波固定开着攻城大队
	d.features.begin([])
	check("round10 final wave always runs the corps", d.features.is_on("corps") and d.features.is_on("carnival"))
	d.features.end()

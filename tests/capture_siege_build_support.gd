extends SiegeFixture
## 建塔协作与25%撞击的定向截图，不执行战斗全流程。
const OUT := "res://tools/.cache/shots/siege_build_support/"

func _ready()->void:
	await _boot()
	for i in 80:
		if not Dialogue.is_active(): break
		Dialogue.advance()
		Dialogue.advance()
		await get_tree().process_frame
	GameState.in_dialogue = GameState.dialogue_holds>0
	d.wave=12
	d.crystals=100
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	d.cam.set_process(false)
	var cam:=GameState.player.camera
	cam.top_level=true
	cam.position_smoothing_enabled=false
	cam.zoom=Vector2(0.6,0.6)
	cam.global_position=Vector2(800,d.wall_foot_y()+100)
	cam.reset_smoothing()
	var pads:Array[BuildPad]=[]
	for i in 3:
		var p:=BuildPad.new()
		d.entities().add_child(p)
		p.global_position=Vector2(560+i*240,d.wall_foot_y()+95)
		pads.append(p)
		if i<2:p.request("icicle",false,0,false)
	var mages:=d.soldiers.filter(func(s):return s.role=="mage")
	for i in 5:
		var s:SiegeSoldier=mages[i]
		s.retreating=false
		s.visible=true
		s.global_position=pads[i/2].helper_spot(i%2)
		s._job=pads[i/2]
	var builder:SiegeSoldier=d.soldiers.filter(func(s):return s.role=="builder")[0]
	builder.retreating=false
	builder.visible=true
	builder.global_position=pads[2].helper_spot(1)
	builder.builder.cooldown=0
	builder.builder.start_order()
	await _wait(1.0)
	await shot("builders_beams")
	await _wait(3.5)
	await shot("completed_towers")
	d.bench_soldiers(true)
	var tower:=pads[1].tower
	if not is_instance_valid(tower):
		get_tree().quit(1)
		return
	var cart:=d.spawn("cart","",tower.global_position+Vector2(0,24)) as SiegeCart
	cart.set_physics_process(false)
	cart._phase="charge"
	cart._touch_tower(Vector2.UP)
	SpeechBubble.say(cart,str(tower.health.hp)+" / "+str(tower.health.max_hp),50,2)
	await _wait(0.1)
	await shot("cart_quarter_hit")
	get_tree().quit()

func shot(label:String)->void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+label+".png"))
	print("SHOT ",label)

extends SiegeFixture
## 派对主人定向截图：实际NPC对话、三人比例、技能、旧小游戏及通用CG。
const OUT := "res://tools/.cache/shots/bonfire_host/"
var host: BonfireHost

func shot(label:String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+label+".png"))
	print("截图：",label)

func flush() -> void:
	Dialogue.runner.end_conversation()
	for i in 30:
		if not Dialogue.is_active():break
		Dialogue._finish_typing()
		Dialogue.advance()
		await get_tree().process_frame
	GameState.in_dialogue=false
	await get_tree().process_frame

func _ready() -> void:
	await _boot()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await flush()
	await _wait(11.0) # 等夹具开场的限时规则提示自行退场，避免盖住角色验收。
	host=load("res://scenes/actors/playable/bonfire_host.tscn").instantiate()
	d.entities().add_child(host)
	host.global_position=Vector2(864,d.wall_foot_y()+160)
	GameState.switch_control(host)
	host.camera.zoom=Vector2(3,3)
	d.cam.set_process(false)
	d.cam.set_physics_process(false)
	host.camera.position_smoothing_enabled=false
	host.camera.top_level=true
	host.camera.global_position=host.global_position
	host.set_physics_process(false)
	d.pink.global_position=host.global_position+Vector2(-40,0)
	d.blue.global_position=host.global_position+Vector2(40,0)
	for c in [d.pink,d.blue]:c.set_physics_process(false)
	if "--portraits-only" in OS.get_cmdline_user_args():
		await portraits_only()
		get_tree().quit()
		return
	await _wait(0.2)
	await shot("three_characters")
	host.camera.zoom=Vector2(1.4,1.4)
	host.cast_magic(3)
	for offset in [Vector2(-70,30),Vector2(70,30)]:
		var m:=d.spawn("shield_crab","",host.global_position+offset)
		m.set_physics_process(false)
	await _wait(0.3)
	await shot("festival_aura")
	host._set_state(PlayableCharacter.State.IDLE)
	host.facing=Vector2.RIGHT
	host.attack()
	host.animator.play("attack")
	host.animator.update(0.12,"side",false,0)
	await _wait(0.15)
	await shot("ribbon_outbound")
	await _wait(0.55)
	await shot("ribbon_return")
	for f in ["f6_opening_done","f6w_arrived","after_started","penance_book","after_done_d4_morning","after_done_d4_afternoon"]:GameState.set_flag(f)
	DayClock.set_time(3,DayClock.AFTERNOON)
	await main.change_level(Floors.scene("floor_06_upper"))
	await flush()
	for n in main.level.find_children("*","BonfireHost",true,false):host=n
	GameState.player.global_position=host.global_position+Vector2(-35,0)
	host.call_deferred("talk",GameState.player)
	await _wait(0.2)
	Dialogue._finish_typing()
	await shot("town_dialogue")
	await flush()
	await main.change_level(Floors.scene("floor_06_after"))
	await _wait(0.3)
	await flush()
	DanceShow.quiet=true
	var dance:=DanceShow.new()
	add_child(dance)
	dance.call_deferred("play")
	await _wait(0.4)
	await shot("dance_stage")
	dance._done=true
	await _wait(0.4)
	dance.queue_free()
	await flush()
	MassageShow.quiet=true
	var massage:=MassageShow.new()
	add_child(massage)
	massage.call_deferred("play")
	await _wait(0.4)
	await shot("massage_stage")
	massage._done=true
	# 按摩的for moves须正常经过当前段才结束，截图后释放整个舞台，进程内不保存任务。
	massage.queue_free()
	await flush()
	for n in main.level.find_children("*","BonfireHost",true,false):host=n
	AfterTown.place(host,{"hidden":false})
	GameState.switch_control(host)
	CG.call_deferred("play","host_rest","",false,"bonfire_host")
	await _wait(1.0)
	Dialogue._finish_typing()
	await shot("host_generic_cg")
	get_tree().quit()

## 资源修订只拍战损立绘与对应施法，不重复小游戏／CG流程。
func portraits_only() -> void:
	for visual in ["damaged","damaged_giggle","damaged_chant","damaged_giggle_chant","damaged_burst","damaged_giggle_burst"]:
		Dialogue.set_portrait_override(Dialogue.portrait_for(visual,"bonfire_host"))
		var anim := "channel" if visual.ends_with("chant") else "cast" if visual.ends_with("burst") else "idle"
		host.animator.play(anim)
		host.animator.progress = 0.8
		host.animator.update(0.25,"down",false,GameState.VISUALS.find(visual))
		await _wait(0.1)
		await shot("portrait_"+visual)

extends "res://tests/f6_after_test.gd"
## 新弥补任务定向视觉验收；描线、节奏／风选、原方框与收尾。
const SPEC := preload("res://tests/helpers/f6_workshop.gd")
const OUT := "res://tools/.cache/shots/f6_workshop/"

func _ready() -> void:
	DevConfig.override=false
	ComboTracker.play_scenes=false
	TutorialBoard.enabled=false
	main=load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1)
	_finish()
	for flag in ["f6_opening_done","f8_done","f8_returned","magic_unlocked","siege_won","after_started","penance_book","after_done_d4_morning"]:GameState.set_flag(flag)
	DayClock.set_time(4,DayClock.AFTERNOON)
	GameState.vars["penance_hours"]=50
	for id in ["canopy","sifting"]:GameState.vars["errand_"+id+"_step"]=0
	await main.change_level(Floors.scene(AfterStory.TOWN))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	CanopyShow.quiet=true
	SiftingShow.quiet=true
	var s:=await SPEC.start(self,"canopy")
	if s==null:
		get_tree().quit(1)
		return
	s.set_process(false)
	s.cursor=s.guide()
	s.hold_tool(true)
	s.simulate(0.2)
	await pose(s,"canopy_mount")
	while s.completed<3:await SPEC.solve_canopy(self,s)
	for i in 15:
		s.cursor=s.guide()
		s.hold_tool(true)
		s.simulate(0.1)
	await pose(s,"canopy_stitch")
	while s.completed<7:await SPEC.solve_canopy(self,s)
	s.hold_tool(true)
	s.simulate(0.2)
	await pose(s,"canopy_tension")
	while s.completed<9:await SPEC.solve_canopy(self,s)
	s.dialogue_quiet=false
	await SPEC.solve_canopy(self,s)
	Dialogue._finish_typing()
	await shot("canopy_ending")
	await _advance_until(func():return AfterErrands.is_done("canopy"),5)
	_go(Cutscene.cell_to_world([16,13]))
	s=await SPEC.start(self,"sifting")
	if s==null:
		get_tree().quit(1)
		return
	s.set_process(false)
	await SPEC.next_beat(self,s)
	await pose(s,"sifting_rhythm")
	while s.phase==0:await SPEC.next_beat(self,s)
	for i in 5:
		s.wind=float(s.sent%3-1)
		await SPEC.next_beat(self,s)
	await pose(s,"sifting_wind")
	for i in 50:
		if s.phase!=1:break
		s.wind=float(s.sent%3-1)
		await SPEC.next_beat(self,s)
	s.hold_tool(true)
	for i in 38:s.simulate(0.1)
	await pose(s,"sifting_bag")
	s.hold_tool(false)
	for bag in 2:
		if bag==1:s.dialogue_quiet=false
		s.hold_tool(true)
		for i in 40:s.simulate(0.1)
		s.hold_tool(false)
		await get_tree().process_frame
	Dialogue._finish_typing()
	await shot("sifting_ending")
	await _advance_until(func():return AfterErrands.is_done("sifting"),5)
	await shot("completed")
	get_tree().quit()

func pose(s:ErrandWorkStage,label:String)->void:
	s.clear_feedback()
	s.work_reaction(s.work_text(),s.phase,"brush","worker")
	await _wait(0.35)
	await shot(label)

func shot(label:String)->void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+label+".png"))
	print("SHOT ",label)

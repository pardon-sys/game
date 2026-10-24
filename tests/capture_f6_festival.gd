extends "res://tests/f6_after_test.gd"
## 仅本批两项玩法三个阶段、结束与新主人对白立绘的截图。
const SPEC := preload("res://tests/helpers/f6_festival.gd")
const OUT := "res://doc/festival_tasks_verification/"
func _ready() -> void:
	DevConfig.override=false
	ComboTracker.play_scenes=false
	TutorialBoard.enabled=false
	main=load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1)
	_finish()
	for flag in ["f6_opening_done","f8_done","f8_returned","magic_unlocked","siege_won","after_started","penance_book","after_done_d4_morning","errand_dance_done"]:GameState.set_flag(flag)
	DayClock.set_time(4,DayClock.AFTERNOON)
	GameState.vars["penance_hours"]=50
	GameState.vars[LampCalibrationShow.SAVE_KEY]=0
	GameState.vars["penance_settled"]=0
	GameState.vars["penance_punish"]=[]
	await main.change_level(Floors.scene(AfterStory.TOWN))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	LampCalibrationShow.quiet=true
	AnnouncerShow.quiet=true
	LampCalibrationShow.fixed_seed=901
	AnnouncerShow.fixed_seed=902
	var s:=await SPEC.start(self,"lamp_calibration")
	if s==null:
		get_tree().quit(1)
		return
	s.set_process(false)
	for phase in 3:
		await pose(s,"lamp_phase_%d"%phase)
		for i in 4:
			if phase==2 and i==3:s.dialogue_quiet=false
			await SPEC.solve(self,s)
	Dialogue._finish_typing()
	await shot("lamp_ending")
	await _advance_until(func():return AfterErrands.is_done("lamp_calibration"),5)
	PenanceBook.punish("截图待抵记录")
	AfterPenance.refresh()
	s=await SPEC.start(self,"announcer")
	if s==null:
		get_tree().quit(1)
		return
	s.set_process(false)
	for phase in 3:
		await pose(s,"announcer_phase_%d"%phase)
		for i in 4:await SPEC.solve(self,s)
	await _advance_until(func():return not AfterPenance.running,3)
	await shot("completed")
	for state in ["normal","helpless_2"]:
		Dialogue.start_lines([{"speaker":"篝火派对的主人","npc":"bonfire_host","emotion":state,"text":"十二组校准完成，灯轮先收好，等庆功宴再挂起来。"}],"festival_portrait_check")
		Dialogue._finish_typing()
		await _wait(0.3)
		await shot("host_"+state)
		Dialogue._end()
	get_tree().quit()

func pose(s:ErrandWorkStage,label:String)->void:
	s.simulate(0.2)
	s.clear_feedback()
	s.work_reaction(s.work_text(),s.phase,s.active_tool,"worker")
	await _wait(0.35)
	await shot(label)

func shot(label:String)->void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+label+".png"))
	print("SHOT ",label)

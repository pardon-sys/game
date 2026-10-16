extends "res://tests/fortress_v2_test.gd"
const OUT := "res://doc/siege_wave12_v2_images/"
var _capture_index := []
func _ready() -> void:
	await _boot()
	d.set_process(false)
	d.features.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for key in SiegeIntel.data(): GameState.set_flag("siege_intel_"+key)
	for key in ["hint_tickled","hint_first_special","hint_grabbed","hint_overflow","hint_helpless"]: GameState.set_flag(key)
	if "--effects-only" in OS.get_cmdline_user_args():
		await effects_only()
		get_tree().quit()
		return
	if "--hud-only" in OS.get_cmdline_user_args():
		await hud_only()
		get_tree().quit()
		return
	if "--art-only" in OS.get_cmdline_user_args():
		await art_only()
		get_tree().quit()
		return
	var b:=fortress()
	camera(Vector2(880,950),0.30)
	await shot("01_normal")
	camera(Vector2(880,640),0.205)
	await shot("02_overview")
	b.health.set_hp(1400)
	step(b,1.6)
	camera(Vector2(880,950),0.30)
	await shot("03_expanded")
	for key in FortressMechanisms.CD:
		await _reset()
		b=fortress()
		b.expanded=true
		d.pink.global_position=Vector2(230,880)
		d.blue.global_position=Vector2(1450,720)
		camera(Vector2(880,900),0.30)
		if key=="crane":
			tower(b.global_position+Vector2(-650,-100))
			tower(b.global_position+Vector2(650,-100))
		b.mechanisms.start(key)
		match key:
			"missiles": step(b,1.4)
			"hands": step(b,2.6)
			"rockets": step(b,1.0); camera(Vector2(880,640),0.205)
			"crane": step(b,3.2)
			"convoy": step(b,3.0); camera(Vector2(880,650),0.24)
			"cannon": step(b,3.3)
		await shot("skill_"+key)
		if key in ["hands","crane"]:
			camera(Vector2(330,900),0.65)
			await shot(key+"_detail")
		if key=="cannon":
			step(b,1.0)
			await shot("cannon_flight")
			step(b,3.4)
			await shot("cannon_third")
	for pair in FortressMechanisms.PAIRS:
		await _reset()
		b=fortress()
		b.expanded=true
		d.pink.global_position=Vector2(210,900)
		d.blue.global_position=Vector2(1510,700)
		camera(Vector2(880,850),0.30)
		if pair[0]=="crane":
			tower(b.global_position+Vector2(-650,-80))
			tower(b.global_position+Vector2(650,-80))
		b.mechanisms.start(pair[0])
		step(b,0.8)
		if b.mechanisms.safe_pair(pair[1]): b.mechanisms.start(pair[1])
		step(b,1.8)
		await shot("pair_"+pair[0]+"_"+pair[1])
	await _reset()
	b=fortress()
	d.pink.global_position=b.shoulder(-1)+Vector2(-150,0)
	var hook:=d.spawn("hook","",d.pink.global_position+Vector2(-90,0))
	b.mechanisms.start("hands")
	step(b,1.05)
	b.mechanisms.coop.start("hook")
	b.mechanisms.coop.tick(0.61)
	camera(d.pink.global_position+Vector2(90,-20),0.70)
	await shot("hook_flight")
	hook.queue_free()
	b.mechanisms.cancel_all()
	for who in ["pink","blue"]:
		await _reset()
		GameState.switch_control(d.pink if who=="pink" else d.blue)
		GameState.set_flag("cg_seen_death_siege_carnival_fortress")
		CG.play("death_siege_carnival_fortress","carnival_fortress",false,who)
		for i in 100:
			if CG._playing: break
			await get_tree().process_frame
		await _wait(1.0)
		for i in 100:
			if CG.step_index>=6 or not CG._playing: break
			if Dialogue.is_active(): Dialogue.advance()
			await _wait(0.15)
		await _wait(0.8)
		await shot("cg_"+who)
		CG.cancel_source("carnival_fortress")
		for i in 100:
			if not CG.is_busy(): break
			await get_tree().process_frame
	await _stress()
	await _reset()
	b=fortress()
	camera(Vector2(880,950),0.30)
	b.health.damage(99999)
	await _wait(0.2)
	await shot("victory_destruction")
	await _wait(1.5)
	await shot("victory")
	var manifest:=FileAccess.open(OUT+"index.json",FileAccess.WRITE)
	manifest.store_string(JSON.stringify(_capture_index,"\t"))
	manifest.close()
	print("FORTRESS V2 VISUAL COMPLETE: ",_capture_index.size()," screenshots")
	await _wait(1.5)
	get_tree().quit()
func camera(at: Vector2, zoom: float) -> void:
	d.cam.set_process(false)
	var cam:=GameState.player.camera
	cam.top_level=true
	cam.position_smoothing_enabled=false
	cam.limit_left=-100000
	cam.limit_right=100000
	cam.limit_top=-100000
	cam.limit_bottom=100000
	cam.zoom=Vector2(zoom,zoom)
	cam.global_position=at
	cam.reset_smoothing()

func hold_effects() -> void:
	for effect in get_tree().get_nodes_in_group("fortress_skill_fx"):
		effect.set_process(false)
		effect.elapsed=0.28 if effect.kind=="launch" else 0.18
		effect.queue_redraw()

func effects_only() -> void:
	await _reset()
	var b := fortress()
	d.pink.global_position=Vector2(230,880)
	d.blue.global_position=Vector2(1450,720)
	camera(Vector2(880,850),0.30)
	b.mechanisms.start("rockets")
	step(b,1.2)
	hold_effects()
	await shot("fx_rocket_flight")
	step(b,0.9)
	hold_effects()
	await shot("fx_rocket_landing")
	# 侧翼近景：落地的实际爆炸节点保持在动画中段，便于检查像素构图。
	var landing := get_tree().get_nodes_in_group("fortress_skill_fx").filter(func(e): return e.kind=="rockets")
	if not landing.is_empty(): camera(landing[0].global_position,0.9)
	await shot("fx_rocket_landing_detail")
	await _reset()
	b=fortress()
	d.pink.global_position=Vector2(230,780)
	d.blue.global_position=Vector2(1450,720)
	camera(Vector2(880,850),0.30)
	b.mechanisms.start("cannon")
	step(b,4.3)
	hold_effects()
	await shot("fx_cannon_flight")
	step(b,0.6)
	hold_effects()
	camera(Vector2(230,780),0.9)
	await shot("fx_cannon_impact_detail")
	var out := FileAccess.open(OUT+"effects_index.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(_capture_index,"\t"))
	out.close()
	print("FORTRESS EFFECTS VISUAL COMPLETE: ",_capture_index.size()," screenshots")
func drain() -> void:
	for i in 100:
		if not Dialogue.is_active(): break
		Dialogue.advance()
		await _wait(0.01)
	for hud in get_tree().root.find_children("*","CanvasLayer",true,false):
		if hud.get("center_hint")!=null: hud.center_hint.hide()
		if hud.get("toast_label")!=null:
			hud.toast_label.hide()
			for old in hud._toast_old:
				if is_instance_valid(old): old.hide()
func shot(label: String) -> void:
	if not label.begins_with("cg_"):
		await drain()
		GameState.princess_reacted.emit("",0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+label+".png"))
	if not _capture_index.has(label+".png"): _capture_index.append(label+".png")
	print("SHOT ",label)
func _stress() -> void:
	await _reset()
	var b:=fortress()
	b.expanded=true
	var pool:=FinalReinforcements.COMMON+FinalReinforcements.SUPPORT+FinalReinforcements.HEAVY
	for i in 800:
		var at:=Vector2(40+(i%50)*33,450+int(i/50)*22)
		if b.footprint().grow(30).has_point(at): at.x=50 if i%2==0 else 1710
		d.spawn(pool[i%pool.size()],"",at)
	for c in [d.pink,d.blue]: c.set_invulnerable(100)
	b.mechanisms.start("hands")
	b.mechanisms.start("missiles")
	camera(Vector2(880,640),0.205)
	await drain()
	var started:=Time.get_ticks_usec()
	for i in 120:
		b._tick(1.0/60)
		await get_tree().process_frame
	var ms:float=(Time.get_ticks_usec()-started)/120.0/1000
	print("FORTRESS V2 RENDER: %.2f ms/frame; alive %d, reserved %d; 800 initial mixed mobs + hull + two skills" % [ms,d.reinforcements.alive_count(),d.reinforcements.reserved])
	await shot("stress_800")
	d.reinforcements.elapsed=180
	await shot("reinforcements_max")

func art_only() -> void:
	if FileAccess.file_exists(OUT+"index.json"):
		_capture_index=JSON.parse_string(FileAccess.get_file_as_string(OUT+"index.json"))
	var b:=fortress()
	GameState.boss_changed.emit(b)
	camera(Vector2(880,950),0.30)
	await shot("01_normal")
	b.expanded=true
	await shot("03_expanded")
	d.pink.global_position=Vector2(230,880)
	d.blue.global_position=Vector2(1450,720)
	b.mechanisms.start("hands")
	step(b,2.6)
	camera(Vector2(330,900),0.65)
	await shot("hands_detail")
	step(b,0.9)
	await shot("hands_grabbed_detail")
	b.mechanisms.cancel_all()
	for who in ["pink","blue"]:
		await _reset()
		GameState.switch_control(d.pink if who=="pink" else d.blue)
		GameState.set_flag("cg_seen_death_siege_carnival_fortress")
		CG.play("death_siege_carnival_fortress","carnival_fortress",false,who)
		for i in 100:
			if CG._playing: break
			await get_tree().process_frame
		await _wait(1)
		for i in 100:
			if CG.step_index>=6 or not CG._playing: break
			if Dialogue.is_active(): Dialogue.advance()
			await _wait(0.15)
		await _wait(0.8)
		await shot("cg_"+who)
		CG.cancel_source("carnival_fortress")
		for i in 100:
			if not CG.is_busy(): break
			await get_tree().process_frame
	var manifest:=FileAccess.open(OUT+"index.json",FileAccess.WRITE)
	manifest.store_string(JSON.stringify(_capture_index,"\t"))
	manifest.close()
	print("FORTRESS V2 ART REVIEW COMPLETE")

func hud_only() -> void:
	if FileAccess.file_exists(OUT+"index.json"):
		_capture_index=JSON.parse_string(FileAccess.get_file_as_string(OUT+"index.json"))
	var b:=fortress()
	GameState.boss_changed.emit(b)
	d.reinforcements.elapsed=180
	d.reinforcements.tick(0.2)
	camera(Vector2(880,900),0.30)
	await shot("reinforcements_max")
	b.expanded=true
	tower(b.global_position+Vector2(-650,-80))
	tower(b.global_position+Vector2(650,-80))
	b.mechanisms.start("crane")
	step(b,3.2)
	var job:Dictionary=b.mechanisms.jobs[0]
	var cable:=b.mechanisms.live_target(job,1)
	cable.receive_hit(HitData.make_attack(d.pink,6))
	camera(Vector2(880,850),0.30)
	await shot("dual_crane_rescue")
	b.mechanisms.cancel_all()
	b.empowered=true
	b.mechanisms.start("cannon")
	step(b,2.6)
	await shot("cannon_four_charge")
	var manifest:=FileAccess.open(OUT+"index.json",FileAccess.WRITE)
	manifest.store_string(JSON.stringify(_capture_index,"\t"))
	manifest.close()
	print("FORTRESS V2 HUD AND RESCUE REVIEW COMPLETE")

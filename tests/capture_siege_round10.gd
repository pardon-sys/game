extends SiegeFixture
## 真正渲染的截图（第十轮）：攻城大队、拆塔投石车、陷阱和怪物的配合、狂欢要塞的新机关 / 护盾柱 / 超载。
## 输出到 tools/.cache/shots/siege_round10/。

const OUT := "res://tools/.cache/shots/siege_round10/"


func _ready() -> void:
	fixture_wave = 12
	await _boot()
	d.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var mid := Vector2(d.map_size().x / 2.0, d.wall_foot_y() + 260.0)
	# 攻城大队
	await _reset()
	d.features.set_process(true)
	d.features.begin(["corps"])
	d.features.corps()
	_camera(Vector2(mid.x, d.map_size().y - 120.0), 0.45)
	await _wait(1.0)
	await _shot("corps_warning")
	await _wait(1.6)
	await _shot("corps_charge")
	d.features.end()
	d.features.set_process(false)
	# 拆塔投石车：砸冰塔
	await _reset()
	var tw := tower(mid + Vector2(-60, -40), "frost")
	tower(mid + Vector2(-20, -30), "icicle")
	var cat := _tower9("catapult", mid + Vector2(-60, 200))
	d.pink.global_position = mid + Vector2(200, 120)
	_camera(mid + Vector2(-40, 80), 0.6)
	cat._catapult()
	await _wait(0.7)
	await _shot("catapult_shadow")
	await _wait(0.7)
	await _shot("catapult_hit")
	# 陷阱配合：龙卷风卷怪、抓娃娃机投怪、传送门怪潮、流沙伏兵
	for kind in ["tornado", "claw", "portal_pair", "quicksand"]:
		await _reset()
		d.pink.global_position = mid + Vector2(-260, 160)
		d.blue.global_position = Vector2(mid.x, d.wall_top_y() + 4)
		for i in 6:
			var m := d.spawn("slime", "", mid + Vector2(randf_range(-12, 12), randf_range(-10, 10)))
			if m:
				m.mind = null
		var hz := d.spawn_hazard(kind, mid)
		if kind == "claw":
			(hz as HazardClaw)._cool["pink"] = 99.0
			(hz as HazardClaw)._cool["blue"] = 99.0
		_camera(mid + Vector2(-60, -40), 0.9)
		await _wait(3.4 if kind != "portal_pair" else 5.2)
		await _shot("hazard_coop_%s" % kind)
	# 狂欢要塞：新机关
	for key in ["tornado_launcher", "portal_drop", "fireworks", "magnet", "shields"]:
		await _reset()
		var b := fortress()
		var m2 := b.mechanisms as FortressSkills
		m2.pace = 1.0 / float(FortressRules.data()["warn_mult"])
		d.pink.global_position = b.global_position + Vector2(-120, -b.footprint().size.y / 2.0 - 160.0)
		d.pink.set_physics_process(true)
		m2.start(key)
		_camera(b.global_position + Vector2(0, -300 if key == "magnet" else -420), 0.45 if key != "magnet" else 0.7)
		for i in 90:
			step(b, 1.0 / 60)
			await get_tree().process_frame
		await _shot("fortress_%s" % key)
		m2.cancel_all()
	# 超载
	await _reset()
	var b2 := fortress()
	b2.expanded = true
	b2.expand_left = 0
	b2.health.set_hp(int(b2.health.max_hp * float(FortressRules.data()["overdrive_ratio"])) - 1)
	_camera(b2.global_position + Vector2(0, -420), 0.45)
	step(b2, 0.1)
	await _wait(0.4)
	await _shot("fortress_overdrive")
	print("SIEGE ROUND10 capture complete")
	get_tree().quit()


func _camera(at: Vector2, zoom: float) -> void:
	d.cam.set_process(false)
	var cam := GameState.player.camera
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.limit_left = -100000
	cam.limit_right = 100000
	cam.limit_top = -100000
	cam.limit_bottom = 100000
	cam.zoom = Vector2(zoom, zoom)
	cam.global_position = at
	cam.reset_smoothing()


func _shot(label: String) -> void:
	for _i in 100:
		if not Dialogue.is_active():
			break
		Dialogue.advance()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + label + ".png"))
	print("shot ", label)

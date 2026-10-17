extends SiegeFixture
## 攻防战性能剖析（打印用，不是回归测试）：场上 1000 只打不死的怪 + 30 座冰塔、城墙打不破，
## 用满负荷计时（SiegeFixture.saturated_frame_ms）看每帧开销，以及屏幕外降级（LOD）省了多少。
## 用法：godot --headless --path . res://tests/siege_perf_profile.tscn

const COUNT := 1000
const KEYS := ["slime", "rat", "caterpillar", "squirrel", "fairy", "bat", "spider", "crab", "ghost", "hedgehog"]


func _ready() -> void:
	await _boot()
	# 开着窗口跑时关掉垂直同步，不然帧时间被锁在刷新率上
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	d.state = "fight"
	d._queue = [{"t": 99999.0, "monster": "slime", "from": "bottom"}]
	d.teamwork.enabled = true
	d.wall_max = 1e12
	d.wall_hp = 1e12
	for i in 30:
		tower(Vector2(200 + (i % 10) * 160, d.wall_foot_y() + 80 + (i / 10) * 70), ["icicle", "frost", "mortar"][i % 3])
	for i in COUNT:
		var m := d.spawn(KEYS[i % KEYS.size()], ["bottom", "left", "right", "hole"][i % 4])
		if m and m.health:
			m.health.max_hp = 999999
			m.health.hp = 999999
	await _wait(1.5)
	await _cost("刚出来")
	await _wait(10.0)
	await _cost("挤到墙下")
	d.lod_enabled = false
	d._clamp_monsters()
	await _cost("挤到墙下、关掉远处降级")
	d.lod_enabled = true
	d._clamp_monsters()
	await _cost("挤到墙下、开回远处降级")
	# 最坏情况：镜头对着怪最多的地方
	var crowd: Variant = d.densest(160.0, d.pink.global_position, 99999.0)
	if crowd is Vector2:
		d.pink.global_position = (crowd as Vector2) + Vector2(0, 60)
		await _wait(1.0)
		d._clamp_monsters()
		await _cost("镜头对着怪堆")
	print("SIEGE PERF PROFILE done")
	get_tree().quit()


func _cost(label: String) -> void:
	var ms := await SiegeFixture.saturated_frame_ms(get_tree(), 2.0)
	var far := d.monsters.filter(func(m): return is_instance_valid(m) and m.lod_far).size()
	print("PERF %-20s 每帧 %.2f ms   场上 %d 只（屏幕外降级 %d）" % [label, ms, d.monsters.size(), far])

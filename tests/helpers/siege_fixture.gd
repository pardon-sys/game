class_name SiegeFixture
extends Node
## 攻防战 Boss / 机关测试的共用夹具（第 6 / 9 / 12 波的测试和截图都直接继承它，不再一层继承一层）：
##   _boot()   读进攻防战地图，关掉小剧场 / 教程 / 随机暴击，士兵下场、配合技停用
##   _reset()  清场、两位公主复位（满血、清状态、AI 停住），按 fixture_wave 把波次和站位摆好（9：魔偶师用的站位 / 移动标记；12：要塞）
##   check()   打印 PASS / FAIL 并计数；_wait()
##   生成工具：_bear() 风暴熊、_puppet() 魔偶师、_tower9() 敌塔、fortress() 要塞、tower() 冰塔、step() 推进要塞、_bubble_at() 泡泡潮

## _reset 摆到第几波（6 / 9 / 12）
var fixture_wave := 6
var main: Node
var d: SiegeDirector
var failures := 0
var checks := 0


class PlainDamageTower extends IceTower:
	func _dmg(base: int) -> int:
		return base


func _boot() -> void:
	seed(606)
	DevConfig.override = false
	ComboTracker.play_scenes = false
	TutorialBoard.enabled = false
	SiegeIntel.auto_controls = false
	TownBuffShow.enabled = false
	Monster.random_specials = false
	HUD.slow_motion = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(0.5)
	for flag in ["magic_unlocked", "intro_blue_magic", "f8_done", "f8_slept", "f8_returned", "f6w_arrived", "intro_done_siege_intro", "siege_intro_seen", "seen_fatigue_burst", "seen_laugh_recover"]:
		GameState.set_flag(flag)
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	await main.change_level(Floors.scene("floor_06_siege"))
	await _wait(0.5)
	d = SiegeDirector.current
	if d == null:
		get_tree().quit(1)
		return
	d.quiet_spawn = true
	d.bench_soldiers(true)
	d.teamwork.enabled = false
	await _reset()


func check(title: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", title])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _reset() -> void:
	if fixture_wave == 12 and is_instance_valid(d):
		d.victory_locked = false
	d.state = "prep"
	d.clear_field()
	d.features.end()
	d.teamwork._cd.clear()
	for tower in get_tree().get_nodes_in_group("siege_tower"):
		tower.queue_free()
	await get_tree().process_frame
	for c in [d.pink, d.blue]:
		var downed: Node = c.get_node_or_null("Downed")
		if downed:
			downed.queue_free()
		if not c.is_alive() or c.state == PlayableCharacter.State.DEAD:
			c.revive()
			c._set_state(PlayableCharacter.State.IDLE)
		c.set_controller(CharacterController.new())
		c.health.max_hp = 1000
		c.health.fill()
		c.status.release(true)
		c.status.clear_root()
		c.laugh.set_value(0.0)
		c.fatigue.clear()
		c.fatigue_bursting = false
		c._set_state(PlayableCharacter.State.IDLE)
		c.set_invulnerable(0.0)
		c._full_invuln = 0.0
		c._attack_invuln = 0.0
		c.clear_buffs()
		c.set_meta("siege_cd", {})
		c.global_position = Vector2(d.gate_pos.x + (0 if c == d.pink else 50), 880)
	d.wave = 6
	d.state = "fight"
	d._queue = [{"t": 99999.0, "monster": "slime", "from": "bottom"}]
	d._hazards.clear()
	d.wall_hp = d.wall_max
	for wall in d.walls:
		wall.shield_left = 0.0
	Engine.time_scale = 1.0
	# Downed 是延后删除的节点，夹具返回前确保复活状态已经完全清理。
	await get_tree().process_frame
	if fixture_wave == 9:
		_reset_wave9()
	elif fixture_wave == 12:
		_reset_wave12()


func _reset_wave9() -> void:
	d.wave = 9
	d.pink.global_position = Vector2(864, 930)
	d.blue.global_position = Vector2(920, d.wall_top_y() + 4)
	for c in [d.pink, d.blue]:
		c.set_physics_process(true)
		c.set_meta("siege_puppet_move", false)
		c.set_meta("siege_falling", false)
		c.set_meta("siege_climbing", false)
		c.set_meta("siege_dragged", false)
		c.set_meta("siege_dragger", null)


func _reset_wave12() -> void:
	d.wave = 12
	GameState.in_dialogue = false
	GameState.in_cutscene = false
	for c in [d.pink, d.blue]:
		c.global_position = Vector2(160 if c == d.pink else 1600, 800)
		c.end_forced_move()


# ------------------------------------------------------------------ 生成工具
func _bear(at := Vector2(864, 900)) -> GaleBear:
	var bear := d.spawn("gale_bear", "", at) as GaleBear
	bear.set_physics_process(false)
	bear._intro_done = true
	bear._intro_left = 0.0
	return bear


func _puppet(at := Vector2(864, 960)) -> PuppetMaster:
	var p := d.spawn("puppet_master", "", at) as PuppetMaster
	p.set_physics_process(false)
	p._intro_done = true
	return p


func _tower9(kind: String, at := Vector2(900, 920)) -> EnemyTower:
	var t := EnemyTower.new()
	t.kind = kind
	t.position = at
	d.entities().add_child(t)
	t._t = 999
	return t


func fortress() -> CarnivalFortress:
	var b:=d.spawn("carnival_fortress") as CarnivalFortress
	b.set_physics_process(false)
	b._introduced=true
	b.mechanisms.autonomous=false
	b.mechanisms.coop.enabled=false
	# 机关的单项测试按原来的时间线（第十轮的 1 / warn_mult 加快另测）
	b.mechanisms.pace=1.0
	return b
func tower(at: Vector2, kind := "icicle") -> IceTower:
	var pad:=BuildPad.new()
	d.entities().add_child(pad)
	pad.global_position=at
	pad._build(kind,1,true)
	pad.tower.set_physics_process(false)
	return pad.tower
func step(b: CarnivalFortress, seconds: float) -> void:
	for i in int(ceil(seconds*60)):
		b.tick_timers(1.0/60)
		b._tick(1.0/60)

func _bubble_at(at: Vector2) -> HazardBubbles:
	var h := HazardBubbles.new()
	h.position = at
	d.entities().add_child(h)
	h.set_process(false)
	h.warned = true
	h._warn_left = 0
	h._bubbles = [{"pos":at,"held":null,"mob":null,"left":0.0,"pop":false}]
	return h

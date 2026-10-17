class_name SiegeDevTools
extends RefCounted
## Esc 的攻防战测试命令；只在 DevConfig 开启、稳定的准备 / 战斗阶段执行。
## 复用导演清场 / 复位 / 波次初始化，以及 BuildPad 的真实 IceTower 构造与存档。

const BATCH := 30
const SPACING := 64.0


static func available(d: SiegeDirector) -> bool:
	return DevConfig.enabled() and is_instance_valid(d) and d == SiegeDirector.current \
		and d.state in ["prep", "fight"] and not d._busy and not SiegeTools.paused()


static func jump_wave(d: SiegeDirector, wave: int) -> bool:
	if not available(d) or wave < 1 or wave > d.data.get("waves", []).size():
		return false
	d._busy = true
	d._set_state("prep")
	d.features.end()
	if d.aim and d.aim.active:
		d.aim.close()
	# 未完成的友塔工程保留，但中断旧冰光与学徒认领，解开操控锁。
	for n in d.get_tree().get_nodes_in_group("siege_pad"):
		var pad := n as BuildPad
		pad._stop_blue()
		pad.helpers.clear()
		pad.reserved.clear()
		pad._clear_lines()
	d.clear_field()
	# 固定地基留着供新波次使用，旧塔 / 工兵认领 / 建造进度全部清掉。
	for n in d.get_tree().get_nodes_in_group("siege_enemy_site"):
		var site := n as EnemySite
		if site.temporary:
			site.queue_free()
		else:
			site.tower = null
			site.builders.clear()
			site.progress = 0.0
			site.build_progress = 0.0
			site._claim = 0
			site._claim_t = 0.0
			site._frozen_t = 0.0
	d.teamwork._cd.clear()
	d._grid.clear()
	d._grid_frame = -1
	d._help.clear()
	d._fight_t = 0.0
	d._total_this_wave = 0
	d.next_left = -1.0
	d._boss_gate_told = false
	# 等 queue_free 完成，旧 Boss / 敌塔的退出回调才不会碰到新波次。
	await d.get_tree().process_frame
	if not is_instance_valid(d) or d != SiegeDirector.current:
		return false
	d.reset_after_fail()
	for c: PlayableCharacter in [d.pink, d.blue]:
		if is_instance_valid(c):
			c.status.clear()
			c.end_forced_move()
			c.remove_buff("lifted")
			c._update_lift(0.0)
			c._set_state(PlayableCharacter.State.IDLE)
			c.velocity = Vector2.ZERO
	await d.get_tree().process_frame
	if not is_instance_valid(d) or d != SiegeDirector.current:
		return false
	d.wave = wave
	await d.town.grant_missing_for_wave(wave)
	d._begin_prep()
	d._busy = false
	GameState.notify("测试：已跳到第 %d 波准备阶段（已补齐镇民增益，保留友塔和冰晶）" % wave)
	return true


static func deploy_towers(d: SiegeDirector, count := BATCH) -> int:
	if not available(d) or count <= 0:
		return 0
	var kinds := IceTower.kinds().filter(func(k): return IceTower.unlocked(str(k)))
	if kinds.is_empty():
		return 0
	var made := 0
	var last: BuildPad
	var ms := d.map_size()
	var center := snappedf(clampf(d.gate_pos.x, SiegeDirector.BUILD_MARGIN, ms.x - SiegeDirector.BUILD_MARGIN), 4.0)
	var rows := int(ceilf(ms.y / SPACING))
	var columns := int(ceilf(ms.x / SPACING))
	# 墙下开始一行行布置；每行从城门向两侧扩展，跳过已有塔 / 敌地基 / 实体墙 / 公主。
	for row in rows:
		for col in columns * 2:
			var step := int((col + 1) / 2)
			var x := center + step * SPACING * (1.0 if col % 2 == 1 else -1.0)
			var at := Vector2(x, snappedf(d.wall_foot_y() + 64.0 + row * SPACING, 4.0))
			if d.build_blocked(at) != "" or not _free_spot(d, at):
				continue
			var pad := BuildPad.new()
			d.entities().add_child(pad)
			pad.global_position = at
			pad.set_meta("siege_dev_tower", true)
			pad._build(str(kinds[made % kinds.size()]), 1, true)
			last = pad
			made += 1
			if made >= clampi(count, 1, 100):
				break
		if made >= clampi(count, 1, 100):
			break
	if is_instance_valid(last):
		last._save()
	GameState.notify("测试：免费部署 %d 座 1 级友塔（本波已解锁类型）" % made)
	return made


static func _free_spot(d: SiegeDirector, at: Vector2) -> bool:
	for c: PlayableCharacter in [d.pink, d.blue]:
		if is_instance_valid(c) and c.global_position.distance_to(at) < 24.0:
			return false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 8)  # IceTower 的原始实体底座
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, at + Vector2(0, -6))
	query.collision_mask = 1
	return d.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## 每次点击免费升一级；正常塔 / 测试塔共用真实升级与全场保存，待完成工程不取消。
static func upgrade_towers(d: SiegeDirector) -> int:
	if not available(d):
		return 0
	var count := 0
	var last: BuildPad
	for n in d.get_tree().get_nodes_in_group("siege_pad"):
		var pad := n as BuildPad
		if not is_instance_valid(pad) or pad.is_queued_for_deletion() or not SiegeTools.alive(pad.tower) or pad.tower.level >= IceTower.MAX_LEVEL:
			continue
		pad.tower.upgrade()
		last = pad
		count += 1
	if is_instance_valid(last):
		last._save()
	GameState.notify("测试：%d 座友塔免费提升一级（最高 3 级）" % count)
	return count


static func clear_test_towers(d: SiegeDirector) -> int:
	if not available(d):
		return 0
	var removed := 0
	for n in d.get_tree().get_nodes_in_group("siege_pad"):
		var pad := n as BuildPad
		if not pad.get_meta("siege_dev_tower", false) or pad.is_queued_for_deletion():
			continue
		if is_instance_valid(pad.tower):
			pad.tower.queue_free()
		pad.queue_free()
		removed += 1
	# _save 会排除 queue_free 中的塔，保留正常建造的塔。
	for n in d.get_tree().get_nodes_in_group("siege_pad"):
		(n as BuildPad)._save()
		break
	GameState.notify("测试：清除 %d 座测试友塔" % removed)
	return removed

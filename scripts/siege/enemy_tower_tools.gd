class_name EnemyTowerTools
extends RefCounted
## 新塔只增加效果分支，建造、受击、拆除与发射时钟仍归 EnemyTower。

static func attack(tower: EnemyTower) -> void:
	match tower.kind:
		"airdrop": _airdrop(tower)
		"brush_battery":
			for c in ([tower.cooperation_target()] if not tower.cooperation.is_empty() else [tower.pink(), tower.blue()]):
				if not SiegeTools.alive(c) or c.global_position.distance_to(tower.global_position) > float(tower.p("range", 700)):
					continue
				for i in 3:
					var shot := BrushShell.new()
					shot.source = weakref(tower)
					shot.actor = weakref(c)
					shot.at = c.global_position
					shot.delay = i * 0.18
					shot.key = SiegeTools.picture(c, i)
					shot.power = tower.power
					shot.command = tower.cooperation.duplicate()
					tower.get_parent().add_child(shot)
					tower.register_tools(shot)
		"resonance":
			for c in [tower.pink(), tower.blue()]:
				if SiegeTools.alive(c) and c.global_position.distance_to(tower.global_position) <= float(tower.p("range", 300)):
					SiegeTools.strike(tower, c, 4.0, int(tower._anim * 3), "pulse")
			SiegeFx.ring(tower.get_parent(), tower.global_position, float(tower.p("range", 300)), SiegeTools.COLOR, 0.6)
			Fx.burst(tower.get_parent(), tower.global_position + Vector2(0, -28), "note", 10, 60.0, 0.8, Vector2(0, -20), SiegeTools.COLOR)


static func pending(tower: EnemyTower = null) -> int:
	var count := 0
	var d := SiegeDirector.current
	if d == null:
		return 0
	for n in d.get_tree().get_nodes_in_group("siege_airdrop_pending"):
		if not n.is_queued_for_deletion() and (tower == null or n.source.get_ref() == tower):
			count += 1
	for m in d.monsters:
		if SiegeTools.alive(m) and m.has_meta("airdrop_site") and (tower == null or m.get_meta("airdrop_site") == tower.get_instance_id()):
			count += 1
	return count


static func _airdrop(tower: EnemyTower) -> void:
	var d := tower.director
	if d == null:
		return
	for i in 4:
		if pending(tower) >= 16 or pending() >= 48:
			break
		var c: PlayableCharacter = d.pink if i < 2 else d.blue
		if not SiegeTools.alive(c):
			c = d.blue if i < 2 else d.pink
		if not SiegeTools.alive(c):
			continue
		var drop := Drop.new()
		drop.source = weakref(tower)
		drop.key = ["vine", "hug_bear", "ghost", "thigh_spider"][i]
		drop.wall = d.is_on_wall(c)
		drop.at = (tower.cooperation["at"] if tower.cooperation.has("at") and c == tower.cooperation_target() else c.global_position) + Vector2((i % 2 * 2 - 1) * 24, 0)
		drop.command = tower.cooperation.duplicate()
		drop.position = tower.global_position + Vector2(0, -34)
		tower.get_parent().add_child(drop)
		tower.register_tools(drop)


class Drop extends Node2D:
	var command := {}
	var source: WeakRef
	var key := "vine"
	var at := Vector2.ZERO
	var wall := false
	var flight: Tween
	func _ready() -> void:
		add_to_group("siege_temp")
		add_to_group("siege_airdrop_pending")
		z_index = 30
		var s := Sprite2D.new()
		s.texture = IceTower.TEX
		s.region_enabled = true
		s.region_rect = IceTower.region("tool_capsule")
		add_child(s)
		SiegeFx.warn(get_parent(), at, "shadow", 26.0, 0.6, SiegeTools.COLOR, 0.0, 1.2, true)
		flight = TeamworkEffects._arc(self, at, 0.6, 120.0, _land)
	func _process(_delta: float) -> void:
		if is_queued_for_deletion():
			return
		if not EnemyTower.cooperation_valid(command) or not SiegeTools.valid_source(source.get_ref()) or SiegeDirector.current == null or SiegeDirector.current.state != "fight":
			_end()
			return
		if SiegeTools.paused():
			flight.pause()
		elif flight.is_valid() and not flight.is_running():
			flight.play()
	func _land() -> void:
		var t := source.get_ref() as EnemyTower
		var d := SiegeDirector.current
		if not EnemyTower.cooperation_valid(command) or not SiegeTools.valid_source(t) or d == null or d.state != "fight":
			_end()
			return
		var segment := d.segment_at(at.x)
		if wall and (segment == null or not segment.climbable()):
			wall = false
			at.y = d.wall_foot_y() + 30.0
		at = d.clamp_in_map(at, 24, wall)
		var m := d.spawn(key, "", at)
		if m:
			m.set_meta("airdrop_site", t.get_instance_id())
			if wall:
				TeamworkEffects.put_on_wall(m, at)
		Fx.burst(get_parent(), at, "dust", 10, 45.0, 0.5, Vector2(0, 30), SiegeTools.COLOR)
		queue_free()
	func _end() -> void:
		if flight and flight.is_valid():
			flight.kill()
		queue_free()
	func _exit_tree() -> void:
		if flight and flight.is_valid():
			flight.kill()


class BrushShell extends Node2D:
	var command := {}
	var source: WeakRef
	var actor: WeakRef
	var at := Vector2.ZERO
	var delay := 0.0
	var t := 0.0
	var key := "tool_roller"
	var power := 1.0
	var fired := false
	var landed := false
	var from := Vector2.ZERO
	func _ready() -> void:
		add_to_group("siege_temp")
		z_index = 24
		var s := source.get_ref() as Node2D
		from = s.global_position + Vector2(0, -30)
		global_position = from
	func _process(delta: float) -> void:
		var tower := source.get_ref() as EnemyTower
		if not EnemyTower.cooperation_valid(command) or not SiegeTools.valid_source(tower) or SiegeDirector.current == null or SiegeDirector.current.state != "fight":
			queue_free()
			return
		if SiegeTools.paused():
			return
		t += delta
		if t < delay:
			return
		if not fired:
			fired = true
			SiegeFx.warn(get_parent(), at, "circle", 28.0, 0.35, SiegeTools.COLOR, 0.0, 1.2, true)
		var f := clampf((t - delay) / 0.35, 0, 1)
		global_position = from.lerp(at, f) + Vector2(0, -sin(f * PI) * 70.0)
		queue_redraw()
		if f >= 1.0 and not landed:
			landed = true
			var c := actor.get_ref() as PlayableCharacter
			if SiegeTools.alive(c) and c.global_position.distance_to(at) < 28.0:
				var job := SiegeTools.sequence(tower, c, 4, 3.0, "battery")
				job.guard = command.get("owner")
				job.power = power
				job.root_on_start = 0.8
				tower.register_tools(job)
			SiegeTools.visual(get_parent(), at, key, 0.25)
			queue_free()
	func _draw() -> void:
		if fired:
			draw_texture_rect_region(IceTower.TEX, Rect2(-10, -10, 20, 20), IceTower.region(key))


static func bell_at(tower: EnemyTower) -> bool:
	for bell in tower.get_tree().get_nodes_in_group("siege_enemy_tower"):
		if bell != tower and bell is EnemyTower and bell.kind == "resonance" and SiegeTools.alive(bell) and bell.global_position.distance_to(tower.global_position) <= float(bell.p("range", 300)):
			return true
	return false


static func aura(tower: EnemyTower) -> void:
	for m in tower.director.enemies_near(tower.global_position, float(tower.p("range", 300))):
		if m is SiegeBoss:
			continue
		m.add_buff("siege_resonant", 0.6)
		tower.track_boost(m)
	for c in [tower.pink(), tower.blue()]:
		if not SiegeTools.alive(c):
			continue
		var fx := EquipFx.of(c)
		if fx and c.global_position.distance_to(tower.global_position) <= float(tower.p("range", 300)):
			fx.add_mod("siege_resonance", 1.3, 1.15, 0.6)
			tower.track_boost(c)


static func clear_aura(tower: EnemyTower) -> void:
	for ref in tower._boosted:
		var c := ref.get_ref() as Actor
		if not is_instance_valid(c):
			continue
		var other := false
		for bell in tower.get_tree().get_nodes_in_group("siege_enemy_tower"):
			if bell != tower and bell is EnemyTower and bell.kind == "resonance" and SiegeTools.alive(bell) and bell.global_position.distance_to(c.global_position) <= float(bell.p("range", 300)):
				other = true
		if not other:
			c.remove_buff("siege_resonant")
			var fx := EquipFx.of(c) if c is PlayableCharacter else null
			if fx:
				fx.remove_mod("siege_resonance")
	tower._boosted.clear()

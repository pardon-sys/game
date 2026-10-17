class_name FortressFinale
extends RefCounted
## 狂欢要塞被打倒后的胜利演出（SiegeDirector.final_boss_defeated 调用）：锁住胜利、取消排队的笑倒 CG，
## 场上的怪变成撤退的剪影（最多 24 个）后清场，车身残骸崩塌淡出，演完调用导演的 _win。


static func play(d: SiegeDirector, boss: CarnivalFortress) -> void:
	if d.victory_locked or d.state != "fight":
		return
	d.victory_locked = true
	CG.cancel_pending_deaths()
	d._set_state("victory")
	d._busy = true
	var at := boss.global_position
	# 只保留有上限的撤退剪影；真实敌人和伤害回调立即清掉。
	var retreat_count := 0
	for monster in d.monsters:
		if (
			monster == boss
			or not is_instance_valid(monster)
			or monster.sprite == null
			or not d.on_screen(monster.global_position)
			or retreat_count >= 24
		):
			continue
		var shade := Sprite2D.new()
		shade.texture = monster.sprite.texture
		shade.region_enabled = monster.sprite.region_enabled
		shade.region_rect = monster.sprite.region_rect
		shade.hframes = monster.sprite.hframes
		shade.vframes = monster.sprite.vframes
		shade.frame = monster.sprite.frame
		shade.offset = monster.sprite.offset
		shade.scale = monster.sprite.scale
		shade.position = monster.global_position
		d.entities().add_child(shade)
		var retreat := shade.create_tween().set_parallel()
		retreat.tween_property(shade, "position", shade.position + Vector2(0, 120), 1.2)
		retreat.tween_property(shade, "modulate:a", 0.0, 1.2)
		retreat.chain().tween_callback(shade.queue_free)
		retreat_count += 1
	d.clear_field()
	for c in [d.pink, d.blue]:
		if not is_instance_valid(c):
			continue
		c.end_forced_move()
		c.set_physics_process(true)
		c.remove_buff("lifted")
		c._update_lift(0.0)
	var wreck := Sprite2D.new()
	wreck.texture = load("res://assets/generated/siege/fortress_v2_hull.png")
	wreck.position = at
	d.entities().add_child(wreck)
	SiegeFx.big_title(d, "狂欢堡垒已击破！", Color(1, 0.85, 0.4), "残兵撤退，小镇守住了！")
	SiegeFx.impact(d.entities(), at, 220, true, Color(1, 0.7, 0.3))
	Audio.play("wall_crash", 0.0)
	var epoch := d.battle_generation
	var tw := wreck.create_tween()
	tw.tween_property(wreck, "modulate", Color(0.25, 0.2, 0.3, 0), 1.5)
	tw.tween_callback(
		func():
			wreck.queue_free()
			if d.state == "victory" and epoch == d.battle_generation:
				d._win()
	)

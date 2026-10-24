extends SiegeFixture
## 只验证共鸣／陨石对盾蟹和拆塔史莱姆的实际伤害，以及相邻免疫规则。

func _ready() -> void:
	await _boot()
	var at := Vector2(720, d.wall_foot_y() + 200)
	var crab := d.spawn("shield_crab", "", at) as ShieldCrab
	var slime := d.spawn("warm_slime", "", at + Vector2(30, 0)) as WarmSlime
	var targets: Array[SiegeMonster] = [crab, slime]
	for m in targets:
		m.mind = null
		m.set_physics_process(false)
		m.health.max_hp = 100
		m.health.fill()
		m.set_invulnerable(0.0)
		m._attack_invuln = 0.0
	await get_tree().physics_frame
	var resonance := damage_tower("resonance", at + Vector2(0, -60))
	resonance._t = 0.0
	resonance._resonance()
	for m in targets:
		check("实际共鸣连跳对%s造成全额伤害" % m.get_class(), 100-m.health.hp == int(resonance.p("damage", 2)))
	resonance.queue_free()
	await get_tree().process_frame
	for m in targets:
		m.health.fill()
		m.set_invulnerable(0.0)
		m._attack_invuln = 0.0
	var meteor := damage_tower("meteor", at + Vector2(0, -60))
	meteor._t = 0.0
	meteor._meteor(0.01)
	await _wait(1.2)
	for m in targets:
		check("实际陨石落地对%s造成全额伤害" % m.get_class(), 100-m.health.hp == int(meteor.p("damage", 4)))
		m.set_invulnerable(0.0)
		m._attack_invuln = 0.0
		var before := m.health.hp
		check("%s仍免疫普通塔攻击" % m.get_class(), not m.receive_hit(HitData.make_attack(meteor, 8, 0.0, true)) and m.health.hp == before)
		check("%s仍免疫蓝色普通攻击" % m.get_class(), not m.receive_hit(HitData.make_attack(d.blue, 8, 0.0)))
	crab.set_invulnerable(0.0)
	crab._attack_invuln = 0.0
	d.pink.global_position = crab.global_position + Vector2(0, -30)
	check("盾蟹仍挡粉色正面攻击", not crab.receive_hit(HitData.make_attack(d.pink, 8, 0.0)))
	d.pink.global_position = crab.global_position + Vector2(0, 30)
	var hp := crab.health.hp
	check("盾蟹背后仍承受粉色全额攻击", crab.receive_hit(HitData.make_attack(d.pink, 8, 0.0)) and hp-crab.health.hp == 8)
	slime.stun(3.0)
	slime.add_buff("siege_chill", 3.0)
	check("暖炉史莱姆仍免疫冻结和减速", not slime.is_stunned() and not slime.buffs.has("siege_chill"))
	print("SPECIAL TOWER DAMAGE: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func damage_tower(kind: String, at: Vector2) -> IceTower:
	var t := PlainDamageTower.new()
	t.kind = kind
	d.entities().add_child(t)
	t.global_position = at
	t.set_physics_process(false)
	return t

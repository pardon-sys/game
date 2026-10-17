class_name FortressSkills
extends FortressMechanisms
## 狂欢要塞第十轮新增的机关（数值在 data/siege/fortress.json，名字 / 公告在 bosses.json；原六个机关在 FortressMechanisms）：
##   tornado_launcher 龙卷发射器：车头射出 tornado_count 道追着粉色公主的龙卷风，每道先卷着 tornado_crew 只船员（龙卷风会把怪甩上墙）
##   portal_drop      传送门空降：车头前和城墙顶之间开一对传送门，船员成群穿门上墙；蓝色公主的法术能冰封门
##   fireworks        烟花弹幕：firework_waves 波彩色烟花落点（最后一波追着公主），炸开是羽毛 / 小怪 / 泡泡潮 / 弹弹蘑菇 / 黏网
##   magnet           磁吸车头：把 magnet_radius 以内的粉色公主和小怪往车头拉，贴到车头的被一排转刷挠；往反方向跑 / 冲刺能挣开
##   shields（auto）  护盾发生柱：剩 shield_at 的血各立一次 shield_count 根柱子，柱子没倒完母车受伤 ×shield_reduction（公主打柱子）
##   hatch（auto）    车头舱门：每 cd 秒从车头前沿放 hatch_count 辆攻城车冲墙；要塞登场时先排 intro_carts 辆（release_carts）
## auto 机关不进成对轮换、不占同时机关数（FortressJobs.is_auto）。

const FIREWORK_KINDS := ["feather", "crew", "bubbles", "mushrooms", "feather"]
const FIREWORK_R := 46.0
const MAGNET_HIT_R := 60.0
const PILLAR_COLOR := Color(0.45, 0.95, 1.0)

var _shield_wave := 0


static func rules() -> Dictionary:
	return FortressRules.data()


func tick(delta: float) -> void:
	super(delta)
	if not autonomous or not valid() or SiegeTools.paused() or boss.is_stunned() or boss.expand_left > 0:
		return
	if float(cds.get("hatch", 0.0)) <= 0.0:
		start("hatch")
	var ratio := float(boss.health.hp) / maxf(1.0, float(boss.health.max_hp))
	var at: Array = rules()["shield_at"]
	while _shield_wave < at.size() and ratio <= float(at[_shield_wave]):
		_shield_wave += 1
		if not jobs.any(func(j): return j["kind"] == "shields"):
			cds["shields"] = 0.0
			start("shields")


## 护盾柱立着（还有没倒的）。
func shield_up() -> bool:
	return jobs.any(func(j): return j["kind"] == "shields" and not j["ended"] and int(j.get("pillars_left", 0)) > 0)


## 母车受到的伤害倍率（护盾柱立着时 shield_reduction）。
func damage_mult() -> float:
	return float(rules()["shield_reduction"]) if shield_up() else 1.0


## 车头前沿（朝城墙那一边）放 n 辆攻城车；离城墙太近就从车身两侧放。返回放出来的车。
func release_carts(n: int, ticket := -1) -> Array[SiegeCart]:
	var made: Array[SiegeCart] = []
	var fp := boss.footprint()
	var d := boss.director
	var front_y := fp.position.y - 26.0
	var sides := front_y < d.wall_foot_y() + 60.0
	for i in n:
		var pos: Vector2
		if sides:
			var side := -1.0 if i % 2 == 0 else 1.0
			pos = Vector2(boss.global_position.x + side * (fp.size.x / 2.0 + 40.0 + (i / 2) * 26.0), fp.position.y + 40.0)
		else:
			pos = Vector2(lerpf(fp.position.x + 60.0, fp.end.x - 60.0, (i + 0.5) / n), front_y)
		pos = d.clamp_in_map(pos)
		pos.y = maxf(pos.y, d.wall_foot_y() + 50.0)
		var cart := d.spawn("cart", "", pos, ticket) as SiegeCart
		if cart == null:
			continue
		cart.set_meta("fortress_hatch", true)
		boss.carts.append(weakref(cart))
		made.append(cart)
	if not made.is_empty():
		Audio.play("siege_horn", -4.0, 0.05, 0.7)
	return made


func _begin(job: Dictionary) -> bool:
	var r := rules()
	match job["kind"]:
		"hatch":
			boss.carts = boss.carts.filter(func(ref): return SiegeTools.alive(ref.get_ref()))
			var count := _reserve(job, mini(int(r["hatch_count"]), boss.max_carts - boss.carts.size()))
			if count <= 0:
				return false
			job["cars"] = release_carts(count, job["ticket"])
			GameState.hint(boss.notice("hatch"))
			return not job["cars"].is_empty()
		"tornado_launcher":
			var n := int(r["tornado_count"])
			var crew := _reserve(job, n * int(r["tornado_crew"]), true)
			job["tornadoes"] = []
			var fp := boss.footprint()
			for i in n:
				var pos := Vector2(lerpf(fp.position.x + 120.0, fp.end.x - 120.0, (i + 0.5) / n), fp.position.y - 40.0)
				pos = boss.director.clamp_in_map(pos)
				pos.y = maxf(pos.y, boss.director.wall_foot_y() + 60.0)
				var t := boss.director.spawn_hazard("tornado", pos) as HazardTornado
				if t == null:
					continue
				t.chase = true
				t.speed_mult = 1.8
				t.tint = Color(1.0, 0.6, 0.3, 0.6)
				boss.register_field(t)
				job["tornadoes"].append(weakref(t))
				var per := crew / n + (1 if i < crew % n else 0)
				if per > 0:
					# 船员落在龙卷风脚下，一生效就被卷进去
					boss.land_crew(pos, per, false, job["ticket"], ["rat", "slime", "squirrel"])
			return not job["tornadoes"].is_empty()
		"portal_drop":
			var blue := boss.director.blue
			var wx := blue.global_position.x if SiegeTools.alive(blue) and boss.director.is_on_wall(blue) else boss.global_position.x
			var portal := HazardPortalPair.new()
			portal.exit_override = Vector2(clampf(wx + randf_range(-60, 60), 120.0, boss.director.map_size().x - 120.0), boss.director.wall_top_y() + 4.0)
			var front := boss.director.clamp_in_map(Vector2(boss.global_position.x + randf_range(-200, 200), boss.footprint().position.y - 50.0))
			front.y = maxf(front.y, boss.director.wall_foot_y() + 80.0)
			boss.director.entities().add_child(portal)
			portal.global_position = front
			portal.life = float(FortressRules.skill("portal_drop")["life"])
			boss.register_field(portal)
			job["portal"] = weakref(portal)
			job["crew_left"] = _reserve(job, int(r["portal_crew"]), true)
			job["next_crew"] = HazardPortalPair.WARN + 0.2
			GameState.hint(boss.notice("portal"))
			return true
		"fireworks":
			job["shells"] = []
			var waves := int(r["firework_waves"])
			var per := int(r["firework_shells"])
			var crew_shells := 0
			for w in waves:
				for k in per:
					var kind: String = FIREWORK_KINDS[(w * per + k) % FIREWORK_KINDS.size()]
					if kind == "crew":
						crew_shells += 1
					job["shells"].append({"wave": w, "kind": kind, "land": 1.6 + w * 1.8 + k * 0.08, "at": Vector2.INF, "warned": false, "done": false})
			# 最后一波追着公主：每个公主脚下一颗黏网弹
			for c: PlayableCharacter in people():
				if not boss.director.is_on_wall(c):
					job["shells"].append({"wave": waves - 1, "kind": "net", "land": 1.6 + (waves - 1) * 1.8 + 0.4, "at": Vector2.INF, "target": weakref(c), "warned": false, "done": false})
			job["crew_ticket_left"] = _reserve(job, crew_shells * 3, true)
			job["life"] = 1.6 + waves * 1.8 + 1.0
			return true
		"magnet":
			if not people().any(func(c): return not boss.director.is_on_wall(c)):
				return false
			job["pulled"] = {}
			GameState.hint(boss.notice("magnet"))
			return true
		"shields":
			job["pillars_left"] = 0
			var n := int(r["shield_count"])
			var fp := boss.footprint()
			for i in n:
				var x := lerpf(fp.position.x - 80.0, fp.end.x + 80.0, (i + 0.5) / n)
				var pos := boss.director.clamp_in_map(Vector2(x, fp.position.y - 140.0 - (i % 2) * 70.0))
				pos.y = maxf(pos.y, boss.director.wall_foot_y() + 70.0)
				var pillar := make_target("pillar", pos, job, int(r["shield_hp"]), i)
				pillar.color = PILLAR_COLOR
				pillar.label = "护盾柱 %d" % int(r["shield_hp"])
				job["pillars_left"] += 1
			SiegeFx.big_title(boss, FortressRules.skill("shields")["name"], PILLAR_COLOR, boss.notice("shield_up"))
			return true
	return super(job)


func _update(job: Dictionary, delta: float) -> void:
	match job["kind"]:
		"hatch":
			pass
		"tornado_launcher":
			if job["tornadoes"].all(func(ref): return not is_instance_valid(ref.get_ref())):
				finish(job)
		"portal_drop":
			_portal_drop(job)
		"fireworks":
			_fireworks(job)
		"magnet":
			_magnet(job, delta)
		"shields":
			pass
		_:
			super(job, delta)


func _portal_drop(job: Dictionary) -> void:
	var portal := (job["portal"] as WeakRef).get_ref() as HazardPortalPair
	if portal == null or not portal.is_processing():
		finish(job)
		return
	if int(job["crew_left"]) <= 0 or job["t"] < float(job["next_crew"]):
		return
	job["next_crew"] = job["t"] + 0.5
	var n := mini(2, int(job["crew_left"]))
	job["crew_left"] -= n
	# 船员在入口那扇门上落地，马上被传送到城墙顶
	boss.land_crew(portal.global_position, n, false, job["ticket"], ["rat", "slime", "gecko"])


func _fireworks(job: Dictionary) -> void:
	var d := boss.director
	for shell in job["shells"]:
		if shell["done"]:
			continue
		var warn_at := float(shell["land"]) - 1.0
		if not shell["warned"] and job["t"] >= warn_at:
			shell["warned"] = true
			var target: Variant = shell.get("target")
			var c: Variant = target.get_ref() if target is WeakRef else null
			var at: Vector2
			if SiegeTools.alive(c):
				at = (c as Node2D).global_position
			else:
				var ms := d.map_size()
				at = Vector2(randf_range(80.0, ms.x - 80.0), randf_range(d.wall_foot_y() + 80.0, boss.footprint().position.y - 30.0))
				# 后几波往公主身边落
				if int(shell["wave"]) > 0 and SiegeTools.alive(d.pink) and randf() < 0.5:
					at = d.pink.global_position + Vector2.from_angle(randf() * TAU) * randf_range(20.0, 90.0)
			shell["at"] = d.clamp_in_map(at)
			SiegeFx.warn(boss.get_parent(), shell["at"], "circle", FIREWORK_R, 1.0, Color.from_hsv(randf(), 0.6, 1.0), 0.0, 1.2, true)
		if shell["warned"] and job["t"] >= float(shell["land"]):
			shell["done"] = true
			_firework_burst(job, shell)


func _firework_burst(job: Dictionary, shell: Dictionary) -> void:
	var d := boss.director
	var at: Vector2 = shell["at"]
	SiegeFx.impact(boss.get_parent(), at, FIREWORK_R, false, Color.from_hsv(randf(), 0.55, 1.0))
	Fx.burst(boss.get_parent(), at + Vector2(0, -10), "spark", 16, 70.0, 0.6, Vector2(0, 30), Color.from_hsv(randf(), 0.5, 1.0))
	Audio.play("pop", -3.0, 0.15, 0.9)
	match str(shell["kind"]):
		"feather":
			Fx.burst(boss.get_parent(), at + Vector2(0, -12), "feather", 12, 60.0, 0.8, Vector2(0, 30))
			explode(at, FIREWORK_R, 12.0, "fireworks")
		"crew":
			var n := mini(3, int(job["crew_ticket_left"]))
			job["crew_ticket_left"] -= n
			if n > 0:
				boss.land_crew(at, n, false, job["ticket"], ["rat", "slime", "imp"])
			explode(at, FIREWORK_R * 0.6, 6.0, "fireworks")
		"bubbles":
			boss.register_field(d.spawn_hazard("bubbles", at))
		"mushrooms":
			var m := d.spawn_hazard("mushrooms", at)
			if m:
				m.life = 6.0
				boss.register_field(m)
		"net":
			boss.register_field(d.spawn_hazard("sticky_net", at))


func _magnet_point() -> Vector2:
	return Vector2(boss.global_position.x, boss.footprint().position.y - 8.0)


func _magnet(job: Dictionary, delta: float) -> void:
	var r := rules()
	var front := _magnet_point()
	var radius := float(r["magnet_radius"])
	var pull := float(r["magnet_pull"])
	for c: PlayableCharacter in people():
		if boss.director.is_on_wall(c) or not SiegeTools.can_move(boss, c):
			continue
		var dist := c.global_position.distance_to(front)
		if dist > radius:
			continue
		# 冲刺时挣开（拉力只在走路 / 站着时有效）；往反方向跑跑得比拉力快
		if c.state != PlayableCharacter.State.DASH:
			c.add_push(c.global_position.direction_to(front) * pull * (1.3 - dist / radius))
			job["pulled"][c.get_instance_id()] = true
		if dist < MAGNET_HIT_R:
			strike(c, 6.0, "magnet", job)
	for m in boss.director.enemies_near(front, radius):
		if SiegeTools.displaceable(m) and not m.has_meta("fortress_crew"):
			m.add_push(m.global_position.direction_to(front) * pull * 0.8)
	if randf() < delta * 10.0:
		var from := front + Vector2.from_angle(randf_range(PI * 1.1, PI * 1.9)) * radius * randf_range(0.4, 1.0)
		Fx.burst(boss.get_parent(), from, "spark", 1, 10.0, 0.4, from.direction_to(front) * 160.0, Color(0.7, 0.85, 1.0))


func target_hit(target: FortressTarget, amount: int) -> void:
	if target.kind != "pillar":
		super(target, amount)
		return
	var job := target.job
	if job.get("ended", false):
		return
	target.hp -= amount
	target.label = "护盾柱 %d" % maxi(0, target.hp)
	if target.hp > 0:
		return
	burst(target.global_position, 40, "recoil")
	target.close()
	job["pillars_left"] = int(job["pillars_left"]) - 1
	if int(job["pillars_left"]) <= 0:
		GameState.hint(boss.notice("shield_down"))
		finish(job)


func _draw() -> void:
	super()
	for job in jobs:
		match job["kind"]:
			"magnet":
				var front := to_local(_magnet_point())
				var radius := float(rules()["magnet_radius"])
				var pulse := fmod(clock * 2.0, 1.0)
				draw_arc(front, radius * (1.0 - pulse), PI, TAU, 40, Color(0.6, 0.85, 1.0, 0.35 + pulse * 0.4), 3.0)
				for i in 7:
					var x := lerpf(-120.0, 120.0, i / 6.0)
					var spin := sin(clock * 20.0 + i) * 4.0
					draw_rect(Rect2(front + Vector2(x - 6, -4 + spin), Vector2(12, 8)), Color(1, 0.75, 0.85))
			"shields":
				for i in job["objects"].size():
					var pillar := live_target(job, i)
					if pillar:
						var a := to_local(pillar.global_position + Vector2(0, -20))
						var b := to_local(boss.global_position + Vector2(0, -120))
						draw_line(a, b, Color(PILLAR_COLOR, 0.35 + sin(clock * 8.0 + i) * 0.15), 3.0)
				if shield_up():
					draw_arc(to_local(boss.global_position), boss.footprint().size.x * 0.52, 0, TAU, 64, Color(PILLAR_COLOR, 0.35), 4.0)

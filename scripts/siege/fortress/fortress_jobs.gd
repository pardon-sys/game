class_name FortressJobs
extends Node2D
## 狂欢要塞的机关（数据在 data/siege/fortress.json，名字在 bosses.json）：按战斗时间计时，展开后两两成对调度（pairs），
## 超载后每轮三个；auto 机关（护盾柱、车头舱门）不进轮换、由 FortressSkills 按条件放。机关时间线按 1 / warn_mult 加快。
##   missiles 猎笑巡航弹（追着人飞、闪光后爆开）、hands 伸缩追猎巨手（抓住往回拖）、rockets 双线火箭运兵（地面 / 墙顶分批落兵）、
##   crane 双钩劫塔（吊走冰塔，打断吊索 FortressTarget 救回来）、convoy 三批交叉车阵、cannon 三连锁定重炮（蓄力时打核心能取消）。
## 每个机关是一个 job（字典），目标、抓取、增援预约和被吊的冰塔都走同一条取消路径（finish / cancel_all）。
## 这一层是调度和共用工具：冷却、成对调度（_schedule / start）、增援预约、命中 / 爆炸、能打的机关（FortressTarget）、
## 收尾和取消、成对机关的安全检查（safe_pair）、预警和飞行贴图的小工具。六个机关本身在子类 FortressMechanisms（_begin / _update）。
static var CD: Dictionary:
	get:
		var result := {}
		for key in FortressRules.data()["skills"]:
			result[key] = FortressRules.skill(key)["cd"]
		return result
static var NAMES: Dictionary:
	get:
		var result := {}
		for key in FortressRules.data()["skills"]:
			result[key] = FortressRules.skill(key)["name"]
		return result
## 展开后的成对调度（fortress.json 的 pairs）；超载时每轮再从下一对里多拉一个，三个一起放
static var PAIRS: Array:
	get:
		return FortressRules.data()["pairs"]
var boss: CarnivalFortress
var cds := {}
var jobs: Array[Dictionary] = []
var targets: Array[FortressTarget] = []
var used: Array[String] = []
var autonomous := true
var sequence := 0
var pair_index := 0
var rest := 2.0
## 成对 / 超载时排队等着放的机关：[{key, delay}]
var pending: Array[Dictionary] = []
var generation := 0
var next_serial := 0
var coop: FortressCooperation
var ground: Node2D
var clock := 0.0
var _textures := {}
var last_safety := {}
## 机关整条时间线（预警、飞行、回收）的快慢：默认 1 / warn_mult（第十轮加快）；测试可以设回 1
var pace := 1.0 / float(FortressRules.data().get("warn_mult", 1.0))
## 每个公主站着不动了几秒（索敌用）
var still := {}
var _last_pos := {}


func _ready() -> void:
	material = FortressFx.ink()
	ground = Node2D.new()
	ground.material = FortressFx.ink()
	ground.add_to_group("siege_temp")
	boss.get_parent().add_child.call_deferred(ground)
	ground.draw.connect(_draw_ground)
	for key in CD:
		cds[key] = 0.0
	for key in ["hand", "hand_closed", "missile", "pod", "shell"]:
		_textures[key] = load("res://assets/generated/siege/fortress_v2_%s.png" % key)
	coop = FortressCooperation.new()
	coop.manager = self
	add_child(coop)
	z_index = 16


## 索敌分数（越小越优先）：距离减去站着不动的秒数 × 120。
func target_score(c: PlayableCharacter, from: Vector2) -> float:
	return c.global_position.distance_to(from) - float(still.get(c.get_instance_id(), 0.0)) * 120.0


func _track_still(delta: float) -> void:
	for c: PlayableCharacter in people():
		var id := c.get_instance_id()
		var last: Vector2 = _last_pos.get(id, c.global_position)
		still[id] = float(still.get(id, 0.0)) + delta if last.distance_to(c.global_position) < 3.0 * maxf(delta * 60.0, 1.0) else 0.0
		_last_pos[id] = c.global_position


func valid() -> bool:
	return SiegeTools.alive(boss) and not boss.ending and is_instance_valid(boss.director) and boss.director.state == "fight"


func people() -> Array:
	return [boss.director.pink, boss.director.blue].filter(func(c): return SiegeTools.alive(c)) if valid() else []


func nearby(key: String, count: int) -> Array:
	return boss.director.enemies_near(boss.global_position, 850).filter(func(m): return MonsterTeamwork.key_of(m) == key and SiegeTools.valid_source(m) and m.is_physics_processing() and not m.get_meta("team_transfer", false) and not m.has_meta("fortress_coop") and float(m.get_meta("team_busy", 0.0)) <= Time.get_ticks_msec() / 1000.0).slice(0, count)


## auto 机关（护盾柱、车头舱门）不进轮换、不占同时机关数，由子类按条件放。
static func is_auto(key: String) -> bool:
	return bool(FortressRules.skill(key).get("auto", false))


## 正在放的轮换机关（不含 auto）。
func main_jobs() -> Array[Dictionary]:
	return jobs.filter(func(j): return not is_auto(j["kind"]))


func tick(delta: float) -> void:
	if not valid() or SiegeTools.paused():
		return
	clock += delta
	_track_still(delta)
	for key in cds:
		cds[key] = maxf(0, float(cds[key]) - delta)
	for job in jobs.duplicate():
		if job["ended"]:
			continue
		job["t"] += delta * pace
		_update(job, delta * pace)
		if not job["ended"] and job["t"] >= job["life"]:
			finish(job)
	coop.tick(delta)
	if autonomous and not boss.is_stunned():
		_schedule(delta)
	if boss.director.on_screen(boss.global_position, 900):
		queue_redraw()
		if is_instance_valid(ground):
			ground.queue_redraw()


func _schedule(delta: float) -> void:
	if not pending.is_empty():
		for item in pending.duplicate():
			item["delay"] -= delta
			if item["delay"] <= 0:
				if main_jobs().is_empty() or safe_pair(item["key"]):
					start(item["key"])
					pending.erase(item)
				else:
					item["delay"] = 0.25
		return
	if not main_jobs().is_empty():
		return
	rest = maxf(0, rest - delta)
	if rest > 0:
		return
	if boss.expanded:
		var pairs := PAIRS
		var pair: Array = pairs[pair_index % pairs.size()]
		var delay := float(FortressRules.data()["pair_delays"][pair_index % pairs.size()])
		start(pair[0])
		pending = [{"key": pair[1], "delay": delay}]
		if boss.overdrive:
			var third: String = pairs[(pair_index + 1) % pairs.size()][0]
			pending.append({"key": third, "delay": delay + 0.8})
			GameState.hint(boss.notice("triple") % [NAMES[pair[0]], NAMES[pair[1]], NAMES[third]])
		else:
			GameState.hint(boss.notice("pair") % [NAMES[pair[0]], NAMES[pair[1]]])
		pair_index = (pair_index + 1) % pairs.size()
	else:
		var keys := CD.keys().filter(func(k): return not is_auto(k))
		for i in keys.size():
			var key: String = keys[sequence % keys.size()]
			sequence += 1
			if start(key):
				break
		rest = 2.0


func start(key: String) -> bool:
	if not valid() or not CD.has(key) or float(cds[key]) > 0 or jobs.any(func(j): return j["kind"] == key):
		return false
	if not is_auto(key) and main_jobs().size() >= (3 if boss.overdrive else (2 if boss.expanded else 1)):
		return false
	var job := {"kind": key, "t": 0.0, "life": float(FortressRules.skill(key)["life"]), "id": next_serial, "generation": generation, "objects": [], "ended": false, "next_hit": {}, "damage": 0, "ticket": -1, "reserved": 0}
	next_serial += 1
	if not _begin(job):
		_release_reserve(job)
		cds[key] = float(CD[key])
		return false
	jobs.append(job)
	used.append(key)
	boss.skill = key
	SpeechBubble.say(boss, NAMES[key], 120, 1.2)
	return true


func _reserve(job: Dictionary, count: int, crew := false) -> int:
	var wanted := boss.reserve_crew(count) if crew else count
	job["ticket"] = boss.director.reinforcements.reserve(wanted)
	var got := boss.director.reinforcements.remaining(job["ticket"])
	if crew:
		boss.reserved_crew -= wanted - got
		job["reserved"] = got
	return got


## 子类（FortressMechanisms）实现：开始一个机关，返回是否开得成。
func _begin(_job: Dictionary) -> bool:
	return false


## 子类实现：机关每帧的推进。
func _update(_job: Dictionary, _delta: float) -> void:
	pass


## 子类实现：双钩劫塔的吊索被打断 / 收尾时把吊起的冰塔放回去。
func _return_lift(_lift: Dictionary, _cable: FortressTarget) -> void:
	pass


## 子类实现：伸缩巨手松开（fling = 甩出去）。
func _release_arm(_arm: Dictionary, _fling: bool) -> void:
	pass


## 子类实现：地面那一层（ground 节点）的绘制。
func _draw_ground() -> void:
	pass


func strike(c: PlayableCharacter, amount: float, variant: String, job: Dictionary) -> bool:
	var id := c.get_instance_id()
	if clock < float(job["next_hit"].get(id, -INF)):
		return false
	var accepted := SiegeTools.strike(boss, c, amount, int(clock * 4), variant)
	if accepted:
		job["next_hit"][id] = clock + 0.8
	return accepted


func explode(at: Vector2, radius: float, amount: float, variant: String, push := 0.0) -> void:
	if not valid():
		return
	for c in people():
		if c.global_position.distance_to(at) <= radius and SiegeTools.strike(boss, c, amount, int(clock * 4), variant):
			if push > 0 and SiegeTools.can_move(boss, c):
				c.force_move(at.direction_to(c.global_position) * (push / 0.6), 0.6, "slide")
	burst(at, radius, variant)


func burst(at: Vector2, radius: float, kind: String) -> Node2D:
	return FortressFx.play(boss.get_parent(), at, radius, kind)


func make_target(kind: String, at: Vector2, job: Dictionary, hp := 6, index := 0) -> FortressTarget:
	var target := FortressTarget.new()
	target.manager = self
	target.kind = kind
	target.job = job
	target.hp = hp
	target.index = index
	target.label = "攻击核心 6" if kind == "core" else "救塔：吊索 6"
	target.position = at
	boss.get_parent().add_child(target)
	targets.append(target)
	job["objects"].append(target)
	return target


static func live_target(job: Dictionary, index: int) -> FortressTarget:
	var objects: Array = job.get("objects", [])
	if index < 0 or index >= objects.size():
		return null
	var raw: Variant = objects[index]
	if not is_instance_valid(raw):
		return null
	var target := raw as FortressTarget
	return target if target != null and not target.closed and not target.is_queued_for_deletion() else null


func target_hit(target: FortressTarget, amount: int) -> void:
	var job := target.job
	if job.get("ended", false):
		return
	if target.kind == "core" and job["t"] < 4:
		job["progress"] += amount
		for i in job["objects"].size():
			var core := live_target(job, i)
			if core:
				core.label = "核心 %d/6" % mini(6, job["progress"])
		if job["progress"] >= 6:
			finish(job, true)
			boss.mechanism_damage(294)
			if valid():
				boss.recoil += Vector2.DOWN * 320
				boss._stun_left = maxf(boss._stun_left, 3)
				burst(boss.global_position + Vector2(0, -190), 110, "recoil")
				SiegeFx.big_title(boss, boss.notice("recoil_title") % 294, boss.GOLD, boss.notice("recoil_sub"))
	elif target.kind == "cable":
		target.hp -= amount
		if target.hp <= 0:
			_return_lift(job["lifts"][target.index], target)


func target_broken(target: FortressTarget) -> void:
	target_hit(target, 6)


func _release_reserve(job: Dictionary) -> void:
	boss.reserved_crew = maxi(0, boss.reserved_crew - int(job.get("reserved", 0)))
	job["reserved"] = 0
	boss.director.reinforcements.release(int(job.get("ticket", -1)))


func finish(job: Dictionary, _cancelled := false) -> void:
	if job.get("ended", false):
		return
	job["ended"] = true
	if job.has("lifts"):
		for i in job["lifts"].size():
			_return_lift(job["lifts"][i], live_target(job, i))
	if job.has("arms"):
		for arm in job["arms"]:
			_release_arm(arm, false)
	for i in job["objects"].size():
		var target := live_target(job, i)
		if target:
			target.close()
	_release_reserve(job)
	jobs.erase(job)
	cds[job["kind"]] = float(CD[job["kind"]]) * (float(FortressRules.data().get("overdrive_cd", 1.0)) if boss.overdrive else 1.0)
	if main_jobs().is_empty():
		rest = 4.0 if boss.expanded else 2.0
		boss.skill = ""
	targets = targets.filter(func(t): return is_instance_valid(t) and not t.closed)


func cancel_all(_preserve := false) -> void:
	generation += 1
	pending.clear()
	for job in jobs.duplicate():
		finish(job, true)
	for target in targets:
		if is_instance_valid(target):
			target.close()
	targets.clear()
	if coop:
		coop.cancel_all()


func _exit_tree() -> void:
	cancel_all()
	if is_instance_valid(ground):
		ground.queue_free()


func active_grab_zone() -> Variant:
	for job in jobs:
		if job["kind"] != "hands":
			continue
		for arm in job["arms"]:
			if arm["phase"] == "hunt":
				return {"job": job, "arm": arm, "at": arm["p"]}
	return null


## 成对机关的安全检查（保守）：留出 96 像素宽的通道，算上已经锁定的落点、车身和真的冰塔；
## 第二个机关延后放的话，只有第一个还有效时才重试。
func safe_pair(candidate: String) -> bool:
	var hazards: Array = []
	for job in jobs:
		if job["kind"] == "hands":
			for arm in job["arms"]:
				if arm["phase"] in ["hunt", "lock"]:
					hazards.append({"p": arm["p"], "r": 60.0})
		elif job["kind"] == "convoy":
			for car in job["cars"]:
				if not car["done"] and car["launch"] - job["t"] < 2.0:
					hazards.append({"a": car["from"], "b": car["to"], "r": 24.0})
	if candidate == "rockets":
		for c in people():
			if not boss.director.is_on_wall(c):
				hazards.append({"p": boss.safe_exterior(c.global_position + Vector2(90, 35)), "r": 48.0})
	elif candidate == "cannon":
		for c in people():
			hazards.append({"p": c.global_position, "r": 88.0 if boss.expanded else 72.0})
	var towers := get_tree().get_nodes_in_group("siege_tower").filter(func(t): return SiegeTools.alive(t) and not t.has_meta("fortress_lift"))
	var top := boss.director.wall_foot_y() + 48
	var size := boss.director.map_size()
	var blocked := {}
	var cols := int(size.x / 64)
	var rows := int((size.y - top) / 64)
	for y in rows:
		for x in cols:
			var p := Vector2(x * 64 + 32, top + y * 64 + 32)
			var solid := boss.footprint().grow(48).has_point(p) or p.x < 48 or p.x > size.x - 48 or p.y > size.y - 48
			if not solid:
				for tower in towers:
					if tower.global_position.distance_to(p) < 60:
						solid = true
						break
			if not solid:
				for h in hazards:
					var nearest: Vector2 = h["p"] if h.has("p") else Geometry2D.get_closest_point_to_segment(p, h["a"], h["b"])
					if p.distance_to(nearest) < h["r"] + 48:
						solid = true
						break
			blocked[Vector2i(x, y)] = solid
	for c in people():
		if boss.director.is_on_wall(c):
			continue
		var origin := Vector2i(int(c.global_position.x / 64), int((c.global_position.y - top) / 64))
		var queue: Array[Vector2i] = []
		var visited := {}
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var cell := origin + Vector2i(dx, dy)
				if not bool(blocked.get(cell, true)) and c.global_position.distance_to(Vector2(cell.x * 64 + 32, top + cell.y * 64 + 32)) <= 144:
					queue.append(cell)
					visited[cell] = true
		var head := 0
		var escaped := false
		while head < queue.size():
			var cell := queue[head]
			head += 1
			var p := Vector2(cell.x * 64 + 32, top + cell.y * 64 + 32)
			if (p.x < 200 or p.x > size.x - 200 or p.y < boss.footprint().position.y - 96) and queue.size() >= 3:
				escaped = true
				break
			for off in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next: Vector2i = cell + off
				if not visited.has(next) and not bool(blocked.get(next, true)):
					visited[next] = true
					queue.append(next)
		if not escaped:
			last_safety = {"safe": false, "candidate": candidate, "character": c.character_id}
			return false
	last_safety = {"safe": true, "candidate": candidate}
	return true


func _warning(at: Vector2, radius: float, label: String, col: Color) -> void:
	var p := to_local(at)
	draw_circle(p, radius, Color(col, 0.12))
	draw_arc(p, radius, 0, TAU, 40, col, 2)
	draw_line(p - Vector2(12, 0), p + Vector2(12, 0), col, 2)
	draw_line(p - Vector2(0, 12), p + Vector2(0, 12), col, 2)
	draw_string_outline(ThemeDB.fallback_font, p + Vector2(-24, -radius - 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color.BLACK)
	draw_string(ThemeDB.fallback_font, p + Vector2(-24, -radius - 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


func _sprite(key: String, at: Vector2, angle := 0.0, scale := 1.0) -> void:
	var tex: Texture2D = _textures[key]
	draw_set_transform(to_local(at), angle, Vector2.ONE * scale)
	draw_texture(tex, -tex.get_size() / 2)
	draw_set_transform(Vector2.ZERO)


func _flight(shot: Dictionary, t: float, key: String, duration: float, height: float) -> void:
	var f := clampf(t / duration, 0, 1)
	var p: Vector2 = (shot["from"] as Vector2).lerp(shot["at"], f) + Vector2(0, -sin(f * PI) * height)
	var tangent: Vector2 = ((shot["at"] as Vector2) - shot["from"]) + Vector2(0, -cos(f * PI) * PI * height)
	_exhaust(p, tangent.normalized(), t, key == "shell")
	_sprite(key, p, tangent.angle() + PI / 2)


func _exhaust(at: Vector2, heading: Vector2, time: float, heavy := false) -> void:
	var tail := to_local(at - heading * 16)
	var back := -heading
	var across := heading.orthogonal()
	var length := (34.0 if heavy else 26.0) + sin(time * 45) * 7
	draw_colored_polygon(PackedVector2Array([tail + across * 8, tail + back * length, tail - across * 8]), Color(1, 0.45, 0.15, 0.85))
	draw_colored_polygon(PackedVector2Array([tail + across * 4, tail + back * length * 0.65, tail - across * 4]), Color(1, 0.95, 0.6))
	for i in 4:
		var p := (tail + back * (length + i * 10) + across * sin(time * 18 + i) * 4).round()
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(0.75, 0.68, 0.9, 0.5 - i * 0.1))

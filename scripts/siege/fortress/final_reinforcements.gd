class_name FinalReinforcements
extends RefCounted
## 最终波（狂欢要塞）的增援配额：所有出怪来源（波次表、要塞机关、成套生成、分裂出来的小怪）共用一个上限，
## 包括还在路上的预约（reserve → consume / release）。要塞活着时增援按时间档位越来越快（fortress.json 的 base_rate / multipliers）。
var director: SiegeDirector
var active := false
var elapsed := 0.0
var credit := 0.0
var reserved := 0
var spawned := 0
var _serial := 0
var _tickets: Dictionary = {}
const COMMON := ["slime", "rat", "squirrel", "gecko"]
const SUPPORT := ["shield_crab", "hook", "goblin_engineer", "bat_swarm", "warm_slime"]
const HEAVY := ["cart", "octopus", "troll", "hug_bear"]


func start(d: SiegeDirector) -> void:
	director = d
	active = true
	elapsed = 0.0
	credit = 0.0
	reserved = 0
	_tickets.clear()
	# The opening queue is replaced, not repeated alongside the endless stream.
	d._queue.clear()


func stop() -> void:
	active = false
	credit = 0.0
	reserved = 0
	_tickets.clear()


func tier() -> int:
	return mini(4, int(elapsed / float(FortressRules.data()["tier_seconds"])))


func multiplier() -> float:
	return float(FortressRules.data()["multipliers"][tier()])


func rate() -> float:
	return float(FortressRules.data()["base_rate"]) * multiplier()


func alive_count() -> int:
	if not is_instance_valid(director):
		return 0
	return director.monsters.filter(func(m): return SiegeTools.alive(m) and not m is CarnivalFortress).size()


func capacity() -> int:
	return maxi(0, int(FortressRules.data()["alive_cap"]) - alive_count() - reserved)


func reserve(count: int) -> int:
	if not active or count <= 0:
		return -1
	var got := mini(count, capacity())
	if got <= 0:
		return -1
	_serial += 1
	_tickets[_serial] = got
	reserved += got
	return _serial


func remaining(ticket: int) -> int:
	return int(_tickets.get(ticket, 0))


func release(ticket: int) -> void:
	reserved -= remaining(ticket)
	_tickets.erase(ticket)


func consume(ticket: int) -> bool:
	if not active or remaining(ticket) <= 0:
		return false
	_tickets[ticket] -= 1
	reserved -= 1
	if _tickets[ticket] == 0:
		_tickets.erase(ticket)
	return true


func entry_point(index: int) -> Vector2:
	var ms := director.map_size()
	var side := index % 3
	var p := Vector2(28 if side == 0 else ms.x - 28, randf_range(director.wall_foot_y() + 60, ms.y - 40))
	if side == 2:
		p = Vector2(randf_range(30, ms.x - 30), ms.y - 24)
	for b in director.get_tree().get_nodes_in_group("fortress"):
		if b.footprint().grow(24).has_point(p):
			p.x = 36 if index % 2 == 0 else ms.x - 36
	return p


func tick(delta: float) -> void:
	if not active or director.victory_locked or director.state != "fight" or SiegeTools.paused():
		return
	elapsed += delta
	credit += rate() * delta
	# Drop overdue whole slots; never burst a paused/capped backlog into the arena.
	var count := mini(int(credit), 8)
	credit = fmod(credit, 1.0)
	for i in count:
		if capacity() <= 0:
			break
		var roll := randf()
		var common := 0.6 - tier() * 0.05
		var heavy := 0.1 + tier() * 0.025
		var pool: Array = COMMON if roll < common else (HEAVY if roll > 1.0 - heavy else SUPPORT)
		var m := director.spawn(str(pool.pick_random()), "", entry_point(spawned))
		if m:
			spawned += 1


## 最终波里不经过 SiegeDirector.spawn 生出来的怪（分裂史莱姆生的小史莱姆……）：占配额，没配额 / 已经胜利就直接收掉；
## 占上了就登记成导演的怪、下一帧补上攻防战的设置（_configure_child）。
func track_child(node: Node) -> void:
	if director == null or not director.is_final_fortress() or not node is Monster or node.get_meta("siege_director_spawn", false):
		return
	if director.victory_locked:
		node.queue_free()
		return
	if not active:
		return
	var ticket := reserve(1)
	if ticket < 0:
		node.queue_free()
		return
	consume(ticket)
	node.set_meta("siege_director_spawn", true)
	director.monsters.append(node)
	node.died.connect(director._on_monster_died)
	director._grid_frame = -1
	_configure_child.call_deferred(node)


func _configure_child(node: Variant) -> void:
	if not SiegeTools.alive(node) or director.victory_locked:
		return
	director._as_minion(node)
	node.add_buff("siege_rapid", 99999)
	node.mind = SiegeMind.new(director)
	node.collision_mask = 1 if node.collision_mask != 0 else 0

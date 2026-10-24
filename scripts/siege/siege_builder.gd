class_name SiegeBuilder
extends RefCounted
## 冰筑工匠的自主订单：全部已解锁塔种、无数量上限；付费后保留30冰晶，完成后冷却30秒。
## 只在战斗有效时间选址；原基座优先，塔种按数量少／新解锁／原表序排列。
## 单订单保留弱引用，撤退不取消付费进度；tick/start_order/reset供专项测试。

const RESERVE := 30
const COOLDOWN := 30.0
const RETRY := 1.0
const GRID := 40.0
const SEARCH_DEPTH := 280.0
var owner: WeakRef
var order: WeakRef
var cooldown := 0.0
var retry_left := 0.0

func _init(soldier: SiegeSoldier) -> void:
	owner = weakref(soldier)

func reset() -> void:
	order = null
	cooldown = COOLDOWN
	retry_left = 0.0

func tick(delta: float) -> void:
	var s := owner.get_ref() as SiegeSoldier
	if not is_instance_valid(s): return
	var d := s.director as SiegeDirector
	if d == null or d.state != "fight" or SiegeTools.paused() or not s.can_build():
		s._leave_build()
		s.velocity = Vector2.ZERO
		return
	if order:
		var pad := order.get_ref() as BuildPad
		if is_instance_valid(pad) and not pad.is_queued_for_deletion() and not pad.pending.is_empty():
			s._job = pad
			s._mage(delta)
			return
		order = null
		s._leave_build()
		cooldown = COOLDOWN
	cooldown = maxf(0.0, cooldown - delta)
	retry_left -= delta
	if cooldown <= 0.0 and retry_left <= 0.0:
		retry_left = RETRY
		if start_order(): return
	s._wander(delta, 24.0)

func choose_kind(d: SiegeDirector) -> String:
	var kinds: Array = IceTower.kinds().filter(func(k): return IceTower.unlocked(k) and int(IceTower.info(k).get("cost", 10)) + RESERVE <= d.crystals)
	var counts := {}
	for k in kinds: counts[k] = 0
	for n in d.get_tree().get_nodes_in_group("siege_pad"):
		if not n is BuildPad or n.is_queued_for_deletion(): continue
		var k := str(n.pending.get("kind", ""))
		if is_instance_valid(n.tower): k = n.tower.kind
		if counts.has(k): counts[k] += 1
	kinds.sort_custom(func(a, b):
		if counts[a] != counts[b]: return counts[a] < counts[b]
		if IceTower.unlock_wave(a) != IceTower.unlock_wave(b): return IceTower.unlock_wave(a) > IceTower.unlock_wave(b)
		return IceTower.kinds().find(a) < IceTower.kinds().find(b))
	return str(kinds[0]) if not kinds.is_empty() else ""

func start_order() -> bool:
	var s := owner.get_ref() as SiegeSoldier
	if not is_instance_valid(s) or not s.can_build() or order or cooldown > 0.0: return false
	var d := s.director as SiegeDirector
	if d == null or d.state != "fight" or SiegeTools.paused(): return false
	var kind := choose_kind(d)
	if kind == "": return false
	var empty: Array = d.get_tree().get_nodes_in_group("siege_pad").filter(func(p): return p is BuildPad and not p.is_queued_for_deletion() and not is_instance_valid(p.tower) and p.pending.is_empty())
	empty.sort_custom(func(a, b): return a.global_position.distance_squared_to(s.global_position) < b.global_position.distance_squared_to(s.global_position))
	var pad: BuildPad
	var fresh := false
	if not empty.is_empty():
		pad = empty[0]
	else:
		var at: Variant = find_position(d, s.global_position)
		if not at is Vector2: return false
		pad = BuildPad.new()
		d.entities().add_child(pad)
		pad.global_position = at
		fresh = true
	if not pad.request(kind, false, RESERVE, false):
		if fresh: pad.discard_if_empty()
		return false
	order = weakref(pad)
	s._job = pad
	d.intel.discover("soldier_builder")
	return true

func find_position(d: SiegeDirector, from: Vector2) -> Variant:
	var positions: Array[Vector2] = []
	var size := d.map_size()
	for y in range(int(d.wall_foot_y() + d.BUILD_FROM_WALL + 8), mini(int(size.y - d.BUILD_MARGIN), int(d.wall_foot_y() + SEARCH_DEPTH)), int(GRID)):
		for x in range(int(d.BUILD_MARGIN + 8), int(size.x - d.BUILD_MARGIN), int(GRID)):
			var p := Vector2(x, y).snapped(Vector2(4, 4))
			if d.build_blocked(p) != "": continue
			var query := PhysicsPointQueryParameters2D.new()
			query.position = p
			query.collision_mask = 1
			if not d.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty(): continue
			positions.append(p)
	positions.sort_custom(func(a, b):
		var wa := d.segment_at(a.x)
		var wb := d.segment_at(b.x)
		var damage_a: float = wa.taken if wa else 0.0
		var damage_b: float = wb.taken if wb else 0.0
		if not is_equal_approx(damage_a, damage_b): return damage_a > damage_b
		return a.distance_squared_to(from) < b.distance_squared_to(from))
	return positions[0] if not positions.is_empty() else null

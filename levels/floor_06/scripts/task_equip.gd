class_name TaskEquip
extends Node2D
## 弥补任务「痒痒装备回收」（第 2 天下午，战后小镇）的玩法节点（AfterStory 摆进来，await finished）：
##   攻防战时散落在镇上的 ITEMS 件临时痒痒装备在地上发光（ItemSpot）。走过去就被强制穿上（Equipment.force，不会自己掉）：
##   穿着的会定时发作（EquipFx）；同一个部位再捡一件 → 旧的那件掉在脚下（要再捡）；所以一趟最多带 脚 / 大腿 / 屁股 各一件。
##   走到补给站（DEPOT，市场监督那里）全部卸下，记件数。全部送到 = 做完。
##   路上的小孩（AfterKid）：闷笑超过 40%、装备正在发作被看见、或者戴着铃铛脚链 / 痒痒印记臀贴 → 跑过来按身上穿着的装备配合着挠（EquipKids 的文本）。
##   降闷笑：长椅上歇着（站在长椅旁不动，每秒 −BENCH_RATE）、井边洗把脸（一次 −WELL_CUT，每口井冷却 WELL_COOL 秒）、被挠时按 J 挣扎。
##   闷笑到 FAIL_AT = 笑倒 → failed 信号（AfterStory 播失败小剧场，装备散回原位重来）。
## 状态存在 vars：task_equip_left（还在地上的 [id, x, y]）、task_equip_done（送到几件）。

signal finished(ok: bool)

## 没做完就被删掉了（换图 / 读档 / 测试跳关）：AfterStory 收拾残局，走回触发点能重新开始
var aborted := false
var _emitted := false

const ITEMS := [["equip_t_feather_socks", 6, 13], ["equip_t_toe_brush", 52, 13], ["equip_t_bell_anklet", 20, 30],
	["equip_t_feather_shackles", 56, 31], ["equip_t_thigh_ring", 36, 15], ["equip_t_thigh_strap", 10, 34],
	["equip_t_pinch_pad", 47, 34], ["equip_t_mark_patch", 26, 15]]
const DEPOT := [13, 24]
const DEPOT_R := 1.6
const BENCHES := [[40, 21], [48, 21], [40, 27], [48, 27]]
const WELLS := [[30, 18]]
const KIDS := [[22, 22], [36, 30], [50, 18], [14, 30]]
const PICK_R := 12.0
const FAIL_AT := 0.9
const BENCH_RATE := 0.08
const WELL_CUT := 0.3
const WELL_COOL := 20.0
const KID_LURE := 0.4

var spots: Array[Node2D] = []
var kids: Array[AfterKid] = []
var _well_cool := {}
var _bench_t := 0.0
## 装备刚发作过（小孩看得见她在扭）
var _flare_t := 0.0
var _done := false
var who := "pink"


func _ready() -> void:
	if not GameState.vars.has("task_equip_left"):
		reset_items()
	_spawn_spots()
	var fx := GameState.player.get_node_or_null("EquipFx") if is_instance_valid(GameState.player) else null
	if fx and fx.has_signal("flared"):
		fx.flared.connect(_on_flared)
	for c in KIDS:
		var k := AfterKid.spawn(get_parent(), Cells.to_world(c), 2.5)
		k.lure = _lure
		k.pick_zone = func(_k) -> String: return EquipKids.zone_for(worn())
		k.caption = func(_k, _z: String) -> String: return EquipKids.caption(worn())
		k.chase_words = EquipKids.chase_words()
		k.tickle_words = EquipKids.tickle_words()
		var rp: Variant = EquipKids.data().get("react", {})
		if rp is Dictionary and not (rp as Dictionary).is_empty():
			k.react_pool = rp
		k.on_catch = func(kid: AfterKid): SpeechBubble.say(kid, ["嘿嘿，好玩！", "下次还要！", "姐姐笑了～"].pick_random(), 26.0, 1.0)
		kids.append(k)


func _exit_tree() -> void:
	# 换图 / 读档 / 测试跳关 / 失败以后：身上的临时装备一起卸掉（重新开始时从头捡；以前失败后不卸，羽毛脚镣会让 K 一直闪避不了）
	for id in TaskEquip.worn():
		Equipment.release("pink", str(id))
	for n in spots:
		if is_instance_valid(n):
			n.queue_free()
	for k in kids:
		if is_instance_valid(k):
			k.queue_free()


static func reset_items() -> void:
	GameState.vars["task_equip_left"] = ITEMS.duplicate(true)
	GameState.vars["task_equip_done"] = 0
	Equipment.release("pink")


static func done_count() -> int:
	return int(GameState.vars.get("task_equip_done", 0))


static func status_text() -> String:
	return "已送回 %d / %d 件　身上 %d 件" % [done_count(), ITEMS.size(), worn().size()]


static func worn() -> Array:
	return Equipment.forced_items("pink").filter(func(id): return str(id).begins_with("equip_t_"))


func _on_flared(_id: String, _zone: String) -> void:
	_flare_t = 2.0


func _lure() -> bool:
	var p := GameState.player
	if not is_instance_valid(p) or p.laugh == null:
		return false
	if p.laugh.ratio() >= KID_LURE or _flare_t > 0.0:
		return true
	return worn().has("equip_t_bell_anklet") or worn().has("equip_t_mark_patch")


func _spawn_spots() -> void:
	for n in spots:
		if is_instance_valid(n):
			n.queue_free()
	spots.clear()
	for it in GameState.vars.get("task_equip_left", []):
		var s := Node2D.new()
		s.set_script(preload("res://levels/floor_06/scripts/item_spot.gd"))
		s.set("item_id", str(it[0]))
		get_parent().add_child(s)
		s.global_position = Cells.to_world([it[1], it[2]])
		spots.append(s)


func _process(delta: float) -> void:
	if _done or GameState.in_dialogue or GameState.in_cutscene:
		return
	var p := GameState.player
	if not is_instance_valid(p) or p.laugh == null:
		return
	_flare_t = maxf(0.0, _flare_t - delta)
	# 捡
	for s in spots.duplicate():
		if is_instance_valid(s) and s.global_position.distance_to(p.global_position) <= PICK_R:
			_pick(s)
	# 送到补给站
	if p.global_position.distance_to(Cells.to_world(DEPOT)) <= DEPOT_R * 16.0 and not worn().is_empty():
		_deliver()
	# 长椅 / 井
	var on_bench := false
	for b in BENCHES:
		if p.global_position.distance_to(Cells.to_world(b)) < 16.0 and p.velocity.length() < 5.0:
			on_bench = true
	_bench_t = _bench_t + delta if on_bench else 0.0
	if _bench_t > 0.5:
		p.laugh.reduce_ratio(BENCH_RATE * delta)
		if randf() < delta * 0.8:
			SpeechBubble.say(p, ["呼……歇一会儿……", "腿……腿还在抖……"].pick_random(), 30.0, 1.0)
	for i in WELLS.size():
		_well_cool[i] = maxf(0.0, float(_well_cool.get(i, 0.0)) - delta)
		if float(_well_cool[i]) <= 0.0 and p.global_position.distance_to(Cells.to_world(WELLS[i])) < 20.0:
			_well_cool[i] = WELL_COOL
			p.laugh.reduce_ratio(WELL_CUT)
			Audio.play("water_release", -8.0)
			SpeechBubble.say(p, "呼——冷水洗把脸，清醒多了！", 30.0, 1.4)
	# J 挣扎：被小孩挠的时候挠的时间缩短
	if Input.is_action_just_pressed("attack"):
		for k in kids:
			if is_instance_valid(k) and k.mode == AfterKid.Mode.TICKLE:
				k._mode_t -= 0.4
				p.laugh.reduce_ratio(0.02)
	if p.laugh.ratio() >= FAIL_AT:
		_done = true
		_emit(false)


func _pick(s: Node2D) -> void:
	var id := str(s.get("item_id"))
	var it := ItemDB.get_item(id) as EquipData
	if it == null:
		return
	# 同部位的旧装备掉在脚下
	for old in worn():
		var oi := ItemDB.get_item(str(old)) as EquipData
		if oi and not oi.slots.filter(func(z): return z in it.slots).is_empty():
			Equipment.release("pink", str(old))
			_drop(str(old), GameState.player.global_position + Vector2(10, 6))
	Equipment.force("pink", id, 99999.0)
	var left: Array = GameState.vars.get("task_equip_left", [])
	for i in left.size():
		if str(left[i][0]) == id:
			left.remove_at(i)
			break
	GameState.vars["task_equip_left"] = left
	spots.erase(s)
	s.queue_free()
	Audio.play("cloth", -4.0)
	GameState.notify("捡起了「%s」——自己穿上了！" % it.display_name, 2.0)
	SpeechBubble.say(GameState.player, EquipKids.wear_line(id), 30.0, 1.6)


func _drop(id: String, at: Vector2) -> void:
	var cell := [floori(at.x / 16.0), floori((at.y - 12.0) / 16.0)]
	var left: Array = GameState.vars.get("task_equip_left", [])
	left.append([id, cell[0], cell[1]])
	GameState.vars["task_equip_left"] = left
	var s := Node2D.new()
	s.set_script(preload("res://levels/floor_06/scripts/item_spot.gd"))
	s.set("item_id", id)
	get_parent().add_child(s)
	s.global_position = Cells.to_world(cell)
	spots.append(s)
	GameState.notify("同一个部位穿不下两件：「%s」掉在地上了" % (ItemDB.get_item(id) as EquipData).display_name, 2.0)


func _deliver() -> void:
	var n := worn().size()
	Equipment.release("pink")
	GameState.vars["task_equip_done"] = done_count() + n
	Audio.play("chest", -4.0)
	GameState.notify("送回补给站 %d 件（%d / %d）" % [n, done_count(), ITEMS.size()], 2.0)
	if done_count() >= ITEMS.size():
		_done = true
		_emit(true)


func _emit(ok: bool) -> void:
	if _emitted:
		return
	_emitted = true
	finished.emit(ok)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and not _emitted:
		aborted = true
		_emit(false)

class_name PalaceRoom
extends Node2D
## 反省篇第四章·旧王宫各张图导演的公共部分（PalaceBath / PalaceServants / PalaceKitchen 继承）：
##   两人同行（Duo：按 C 换人、AI 搭档；倒地搭档按住 E 扶起；两个都倒下 → on_defeat → 小剧场 palace_down → 回检查点）；
##   检查点（map_id() 那张图的 checkpoints 标记，没有就用进图的位置）；跳关进来补穿鼠鼠装（penance_mouse_dev，挠脚鼠还没在厨房告别时）；
##   短台词 data/after/palace.json（data()）；等距：要单独投影的画面节点挂在 Entities（导演的父节点）下面（add_view）。

const PALACE_DATA := "res://data/after/palace.json"

var lv: Node
var pink: PlayableCharacter
var blue: PlayableCharacter
var checkpoint := Vector2.ZERO
var _tick := {}
var _defeat_busy := false
static var _data := {}


func map_id() -> String:
	return ""


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PALACE_DATA))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func say_random(who: Node2D, key: String) -> void:
	var lines: Array = data().get(key, [])
	if not lines.is_empty() and is_instance_valid(who):
		SpeechBubble.say(who, str(lines.pick_random()), 28.0, 1.6)


## 笑脸徽记（第四章追加事件）：每个来源（src）只给一枚；集齐 BADGES_ALL 枚到王座前厅的徽记台换女王的羽毛发饰
const BADGE_SOURCES := ["rat_king", "clockface", "vault", "statue", "scrub", "shade", "lost"]
const BADGES_ALL := 7


static func badge_flag(src: String) -> String:
	return "badge_" + src


static func badges() -> int:
	return BADGE_SOURCES.filter(func(s): return GameState.has_flag(badge_flag(s))).size()


static func give_badge(src: String) -> bool:
	if GameState.has_flag(badge_flag(src)):
		return false
	GameState.set_flag(badge_flag(src))
	var it := ItemDB.get_item("smile_badge")
	if it:
		GameState.give_item(it, 1)
	Audio.play("chime", -3.0, 0.0, 1.3)
	GameState.notify("得到一枚笑脸徽记（%d / %d）" % [badges(), BADGES_ALL])
	return true


## 笑声乐谱（三片：1 钟面暗格 / 2 送餐 / 3 浴场镜子）；王座前厅的笑声地砖要三片都有
static func sheets() -> int:
	return [1, 2, 3].filter(func(i): return GameState.has_flag("palace_sheet_%d" % i)).size()


static func give_sheet(i: int) -> bool:
	if GameState.has_flag("palace_sheet_%d" % i):
		return false
	GameState.set_flag("palace_sheet_%d" % i)
	var it := ItemDB.get_item("music_sheet")
	if it:
		GameState.give_item(it, 1)
	GameState.notify("得到一片笑声乐谱（%d / 3）" % sheets())
	return true


static func cell_pos(c: Vector2i) -> Vector2:
	return Vector2(c.x * 16.0 + 8.0, c.y * 16.0 + 8.0)


func _ready() -> void:
	lv = get_parent()
	while lv and lv.get_node_or_null("Floor") == null and lv.get_parent():
		lv = lv.get_parent()
	if GameState.has_flag("penance_mouse_dev") and not GameState.has_flag(PalaceKitchen.FAREWELL_FLAG) and not PenanceCell.wearing_mouse():
		PenanceCell.wear_mouse()
	_start_duo.call_deferred()
	_add_lost.call_deferred()
	_add_patrol.call_deferred()
	_add_mimic.call_deferred()
	if map_id() in [TRAY_FROM, TRAY_TO]:
		var tc := TrayCarry.new()
		tc.room = self
		add_view(tc)


# ------------------------------------------------------------------ 失物招领（隧道的小鬼丢的五样东西，散在五张图里）
const LOST_ITEMS := {
	"floor_06_palace_library": ["quill", 2], "floor_06_palace_servants": ["bell", 3], "floor_06_palace_wardrobe": ["sock", 4],
	"floor_06_palace_kitchen": ["cheese", 5], "floor_06_palace_clock_2": ["spring", 6]}
const LOST_NAMES := {"quill": "羽毛笔", "bell": "小铃铛", "sock": "一只袜子", "cheese": "一块奶酪", "spring": "钟发条"}
const EVENTS2 := "res://assets/generated/palace_events2.png"


static func lost_flag(key: String) -> String:
	return "palace_lost_" + key


static func lost_found() -> int:
	return LOST_NAMES.keys().filter(func(k): return GameState.has_flag(lost_flag(k))).size()


## 和隧道的小鬼说过「失物招领」以后，五张图里的失物才出现（ASKED_FLAG）
const LOST_ASKED := "palace_lost_asked"


func _add_lost() -> void:
	if not LOST_ITEMS.has(map_id()) or cells("lost").is_empty():
		return
	var key := str(LOST_ITEMS[map_id()][0])
	var sp := PrisonOddities.Spot.new()
	sp.dialogue = "floor_06/lost_" + key
	sp.done_flag = lost_flag(key)
	add_child(sp)
	sp.global_position = world(cells("lost")[0])
	var v := Events2View.new()
	v.frame = int(LOST_ITEMS[map_id()][1])
	v.hide_flag = lost_flag(key)
	v.position = world(cells("lost")[0])
	add_view(v)
	gate(sp, [LOST_ASKED])
	v.need = [LOST_ASKED]


# ------------------------------------------------------------------ 人偶巡夜队（回廊被抓过一次以后：厨房 / 浴场 / 图书馆各多一个巡夜人偶）
const PATROL_FLAG := "palace_night_patrol"
const FRIEND_FLAG := "palace_headmaid_friend"   # 给女仆长上过发条：巡夜队撤掉、回廊不再抓人
var patrols: Array = []


func _add_patrol() -> void:
	var cs := cells("patrol")
	if cs.size() < 2 or not GameState.has_flag(PATROL_FLAG) or GameState.has_flag(FRIEND_FLAG):
		return
	var n := NightPatrol.new()
	n.room = self
	n.a = world(cs[0])
	n.b = world(cs[1])
	add_view(n)
	patrols.append(n)


func tick_patrols(delta: float) -> void:
	for n in patrols:
		if is_instance_valid(n):
			(n as NightPatrol).tick(delta)


## 巡夜人偶：在 a、b 之间来回走，前面一个扇形（VIEW_R、VIEW_HALF）；看到人就追（CHASE_SPEED，最多 CHASE_MAX 秒），
## 追上了挠一阵、把两个人送回这张图的入口；女仆长变友好以后（FRIEND_FLAG）自己走掉
class NightPatrol extends Node2D:
	const SHEET := "res://assets/generated/npcs/doll_maid.png"
	const SPEED := 26.0
	const CHASE_SPEED := 58.0
	const CHASE_MAX := 3.0
	const VIEW_R := 80.0
	const VIEW_HALF := 0.55
	const CATCH_R := 12.0
	var room: PalaceRoom
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var to_b := true
	var state := "walk"
	var target: PlayableCharacter
	var facing := Vector2.RIGHT
	var caught_count := 0
	var _t := 0.0
	var _cool := 0.0
	var _anim := 0.0
	var _spr: Sprite2D

	func _ready() -> void:
		z_index = 1
		position = a
		if ResourceLoader.exists(SHEET):
			_spr = Sprite2D.new()
			_spr.texture = load(SHEET)
			_spr.hframes = 4
			_spr.vframes = 4
			_spr.offset = Vector2(0, -15)
			_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(_spr)

	func sees(pc: PlayableCharacter) -> bool:
		if Downed.is_downed(pc):
			return false
		var to := pc.global_position - position
		return to.length() <= VIEW_R and to.length() > 0.1 and facing.dot(to.normalized()) >= cos(VIEW_HALF)

	func tick(delta: float) -> void:
		_t += delta
		_cool = maxf(0.0, _cool - delta)
		if GameState.has_flag(PalaceRoom.FRIEND_FLAG):
			queue_free()
			return
		match state:
			"walk":
				var goal := b if to_b else a
				_move(goal, SPEED, delta)
				if position.distance_to(goal) < 2.0:
					to_b = not to_b
				if _cool <= 0.0:
					for m in room.members():
						if sees(m as PlayableCharacter):
							state = "chase"
							target = m
							_t = 0.0
							SpeechBubble.say(self, "……巡夜中。……站住。", 34.0, 1.2)
							break
			"chase":
				if not is_instance_valid(target) or _t > CHASE_MAX:
					state = "walk"
					_cool = 3.0
				else:
					_move(target.global_position, CHASE_SPEED, delta)
					if position.distance_to(target.global_position) <= CATCH_R:
						catch(target)
		queue_redraw()

	func _move(goal: Vector2, speed: float, delta: float) -> void:
		var d := goal - position
		position = position.move_toward(goal, speed * delta)
		if d.length() > 0.5:
			facing = d.normalized()
			_anim += delta * 6.0
		if _spr:
			var sd := IsoView.screen_dir(facing)
			var row := (1 if sd.x < 0 else 2) if absf(sd.x) > absf(sd.y) else (0 if sd.y > 0 else 3)
			_spr.frame = row * 4 + int(_anim) % 4

	## 追上了：挠一阵，送回入口
	func catch(pc: PlayableCharacter) -> void:
		caught_count += 1
		state = "walk"
		_cool = 5.0
		Audio.play("grab", -4.0)
		for k in 4:
			var h := HitData.make_tickle(self, 2.5)
			h.zone = ["armpit", "waist", "sole"].pick_random()
			pc.receive_hit(h)
		PalaceRoom.say_random(pc, "patrol_caught")
		GameState.notify("被巡夜人偶抓到了——送回了门口")
		room.reset_to(room.world(room.cells("start")[0]))

	func _draw() -> void:
		if state == "walk":
			var pts := PackedVector2Array([Vector2.ZERO])
			for k in 9:
				var an := facing.angle() - VIEW_HALF + VIEW_HALF * 2.0 * k / 8.0
				pts.append(IsoView.offset(Vector2(cos(an), sin(an)) * VIEW_R))
			draw_colored_polygon(pts, Color(1.0, 0.85, 0.5, 0.1))
		if _spr == null:
			draw_rect(Rect2(-5, -24, 10, 18), Color(0.2, 0.2, 0.4))


# ------------------------------------------------------------------ 宝箱怪的逃亡（隧道里被咬过一次以后，它依次躲到 厨房冷藏库 → 图书馆 → 衣帽间）
const MIMIC_FLED := "palace_mimic_fled"
const MIMIC_DONE := "palace_mimic_done"
const MIMIC_MAPS := ["floor_06_palace_kitchen", "floor_06_palace_library", "floor_06_palace_wardrobe"]
const MIMIC_STAGE := "palace_mimic_stage"


static func mimic_here(fid: String) -> bool:
	return GameState.has_flag(MIMIC_FLED) and not GameState.has_flag(MIMIC_DONE) \
		and int(GameState.vars.get(MIMIC_STAGE, 0)) == MIMIC_MAPS.find(fid)


func _add_mimic() -> void:
	if cells("mimic_hide").is_empty() or not MIMIC_MAPS.has(map_id()):
		return
	var v := MimicHide.new()
	v.room = self
	v.position = world(cells("mimic_hide")[0])
	add_view(v)
	var sp := PrisonOddities.Spot.new()
	sp.dialogue = "floor_06/mimic_hide"
	add_child(sp)
	sp.global_position = world(cells("mimic_hide")[0])
	v.spot = sp


## 抓住宝箱怪（打开伪装的宝箱）：被咬住挠脚心，连按挣开；它又逃去下一个地方，三次都抓到就吐出宝物
func mimic_catch() -> void:
	for n in get_parent().get_children():
		if n is MimicHide and (n as MimicHide).room == self:
			(n as MimicHide).bite(GameState.player as PlayableCharacter)


func mimic_escaped() -> void:
	var st := int(GameState.vars.get(MIMIC_STAGE, 0)) + 1
	GameState.vars[MIMIC_STAGE] = st
	if st >= MIMIC_MAPS.size():
		GameState.set_flag(MIMIC_DONE)
		GameState.give_item(ItemDB.get_item("coin"), 60)
		Dialogue.talk("floor_06/mimic_done")
	else:
		GameState.notify("宝箱怪「咔嗒咔嗒」地跑掉了……好像躲到%s去了" % ["厨房", "图书馆", "衣帽间"][st])


## 伪装成宝箱的宝箱怪（地牢宝箱图，盖子一起一伏地「呼吸」）
class MimicHide extends Node2D:
	const TEX := "res://assets/third_party/kenney_tiny_dungeon/tilemap_packed.png"
	const PRESSES := 6
	var room: PalaceRoom
	var spot: Node2D
	var holding: PlayableCharacter
	var _tick := 0.0
	var _t := 0.0
	var _s: Sprite2D

	func _ready() -> void:
		z_index = 1
		_s = Sprite2D.new()
		_s.texture = load(TEX)
		_s.region_enabled = true
		_s.region_rect = Rect2(80, 112, 16, 16)
		_s.offset = Vector2(0, -7)
		_s.scale = Vector2(1.25, 1.25)
		_s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_s)

	func here() -> bool:
		return room != null and PalaceRoom.mimic_here(room.map_id())

	func bite(pc: PlayableCharacter) -> void:
		if pc == null or holding or not here():
			return
		if not pc.status.grab(self, 4.0, PRESSES):
			return
		holding = pc
		_tick = 0.1
		Audio.play("gate", -6.0, 0.0, 1.8)
		PalaceRoom.say_random(pc, "mimic")

	func _process(delta: float) -> void:
		_t += delta
		var on := here()
		visible = on or holding != null
		if is_instance_valid(spot):
			spot.visible = on and holding == null
			for c in spot.get_children():
				if c is Interactable:
					(c as Interactable).enabled = on and holding == null
		_s.region_rect = Rect2(96, 112, 16, 16) if holding else Rect2(80, 112, 16, 16)
		_s.scale = Vector2(1.25, 1.25 + (sin(_t * 2.5) * 0.06 if on else 0.0))
		if holding:
			if not holding.status.is_grabbed_by(self):
				holding = null
				room.mimic_escaped()
				return
			_tick -= delta
			if _tick <= 0.0:
				_tick = 0.35
				var h := HitData.make_tickle(self, 2.5)
				h.zone = "sole"
				holding.receive_hit(h)


# ------------------------------------------------------------------ 按进度出现
## node 只有在 need 里的剧情标记都有了才显示、才能交互（每帧对一次，标记一有就出现）
func gate(node: Node, need: Array) -> Gate:
	var g := Gate.new()
	g.target = node
	g.need = need
	add_child(g)
	g.apply()
	return g


class Gate extends Node:
	var target: Node
	var need: Array = []
	var _last := -1

	func open() -> bool:
		return need.all(func(f): return GameState.has_flag(str(f)))

	func apply() -> void:
		if not is_instance_valid(target):
			return
		var on := open()
		if int(on) == _last:
			return
		_last = int(on)
		if target is CanvasItem:
			(target as CanvasItem).visible = on
		for c in target.find_children("*", "Interactable", true, false):
			(c as Interactable).enabled = on
		if target is Interactable:
			(target as Interactable).enabled = on

	func _process(_d: float) -> void:
		apply()


## palace_events2.png 的一帧（0 海绵 / 1 点心托盘 / 2 羽毛笔 / 3 小铃铛 / 4 袜子 / 5 奶酪 / 6 钟发条 / 7 夹着衣架书签的书）；hide_flag 有了就不画
class Events2View extends Node2D:
	var frame := 0
	var hide_flag := ""
	## 这些剧情标记都有了才显示（按进度出现）
	var need: Array = []
	var scale_k := 0.6
	## 不用 palace_events2 的帧、直接用一张小图（物品图标之类）
	var tex := ""
	var _s: Sprite2D

	func _ready() -> void:
		if tex != "" and ResourceLoader.exists(tex):
			_s = Sprite2D.new()
			_s.texture = load(tex)
			_s.offset = Vector2(0, -10)
			_s.scale = Vector2.ONE * scale_k
			_s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(_s)
		elif ResourceLoader.exists(PalaceRoom.EVENTS2):
			_s = Sprite2D.new()
			_s.texture = load(PalaceRoom.EVENTS2)
			_s.hframes = 8
			_s.frame = frame
			_s.offset = Vector2(0, -14)
			_s.scale = Vector2.ONE * scale_k
			_s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(_s)

	func _process(_d: float) -> void:
		visible = (hide_flag == "" or not GameState.has_flag(hide_flag)) and need.all(func(f): return GameState.has_flag(str(f)))
		if _s:
			_s.position.y = sin(Time.get_ticks_msec() / 300.0) * 1.5
		else:
			queue_redraw()

	func _draw() -> void:
		if _s == null:
			draw_circle(Vector2(0, -6), 4.0, Color(1.0, 0.85, 0.5))


# ------------------------------------------------------------------ 事件点的图（补素材）
const PROPS3 := "res://assets/generated/palace_props3.png"   # 0 骑士石像 / 1 粉摇篮 / 2 蓝摇篮 / 3 旋转吊铃 / 4 水槽 / 5 糕点台
const CHEF := "res://assets/generated/npcs/pastry_chef.png"
const PROPS4 := "res://assets/generated/palace_props4.png"   # 0 人偶按摩椅 / 1 冻住的门 / 2 冰块里的蛋糕 / 3 生日蛋糕 / 4 空的小画框 / 5 镜面墙板   # 糕点师人偶：0 1 站着晃 / 2 端蛋糕 / 3 举打蛋器


## 一张图集里的一帧（或几帧循环）；anim 为空就是静止的
class SheetView extends Node2D:
	var tex := ""
	var hframes := 1
	var frame := 0
	var anim: Array = []
	var fps := 3.0
	var lift := 0.0
	var scale_k := 1.0
	var _s: Sprite2D
	var _t := 0.0

	func _ready() -> void:
		if not ResourceLoader.exists(tex):
			return
		_s = Sprite2D.new()
		_s.texture = load(tex)
		_s.hframes = hframes
		_s.frame = frame
		_s.scale = Vector2.ONE * scale_k
		_s.offset = Vector2(0, -float(_s.texture.get_height()) * 0.5 + 2.0 - lift)
		_s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_s)

	func _process(d: float) -> void:
		if _s and not anim.is_empty():
			_t += d
			_s.frame = int(anim[int(_t * fps) % anim.size()])


func sheet_view(tex: String, hf: int, frame: int, c: Vector2i, anim: Array = [], scale_k := 1.0, nudge := Vector2.ZERO) -> SheetView:
	var v := SheetView.new()
	v.tex = tex
	v.hframes = hf
	v.frame = frame
	v.anim = anim
	v.scale_k = scale_k
	v.position = world(c) + nudge
	add_view(v)
	return v


# ------------------------------------------------------------------ 送餐潜行（厨房 → 仆人回廊）
## 端着点心（TRAY_FLAG）：头顶一个托盘、不能冲刺（meta no_dash）；被女仆发现 → 试吃惩罚、点心没了
const TRAY_FLAG := "palace_tray_carry"
const TRAY_FROM := "floor_06_palace_kitchen"
const TRAY_TO := "floor_06_palace_servants"


static func carrying_tray() -> bool:
	return GameState.has_flag(TRAY_FLAG)


static func set_tray(on: bool) -> void:
	GameState.set_flag(TRAY_FLAG, on)


class TrayCarry extends Node2D:
	var room: PalaceRoom
	var _s: Sprite2D

	func _ready() -> void:
		z_index = 5
		if ResourceLoader.exists(PalaceRoom.EVENTS2):
			_s = Sprite2D.new()
			_s.texture = load(PalaceRoom.EVENTS2)
			_s.hframes = 8
			_s.frame = 1
			_s.offset = Vector2(0, -42)
			_s.scale = Vector2(0.55, 0.55)
			_s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(_s)

	func _process(_d: float) -> void:
		var on := PalaceRoom.carrying_tray()
		visible = on
		for m in room.members() if room else []:
			if on:
				(m as Node).set_meta(&"no_dash", true)
			elif (m as Node).has_meta(&"no_dash"):
				(m as Node).remove_meta(&"no_dash")
		var p := GameState.player as Node2D
		if on and is_instance_valid(p):
			global_position = p.global_position
		queue_redraw()

	func _draw() -> void:
		if _s == null and visible:
			draw_rect(Rect2(-8, -40, 16, 3), Color(0.85, 0.85, 0.9))
			draw_circle(Vector2(0, -43), 3.0, Color(1.0, 0.8, 0.85))


# ------------------------------------------------------------------ 女王的回忆（徽记台换过发饰 + 王座间通关以后，一次）
const MEMORY_FLAG := "palace_queen_memory"


static func memory_ready() -> bool:
	return GameState.has_flag("palace_badges_done") and GameState.has_flag("palace_boss_done") and not GameState.has_flag(MEMORY_FLAG)


static func try_memory() -> bool:
	if not memory_ready():
		return false
	GameState.set_flag(MEMORY_FLAG)
	await Cutscene.play("palace_queen_memory")
	return true


func _start_duo() -> void:
	pink = GameState.player as PlayableCharacter
	for n in get_tree().get_nodes_in_group("player_chars"):
		if n is PlayableCharacter and (n as PlayableCharacter).character_id == "blue":
			blue = n
	if is_instance_valid(pink):
		checkpoint = pink.global_position
	if is_instance_valid(pink) and is_instance_valid(blue):
		Duo.start([pink, blue], self, ai_hooks())


func ai_hooks() -> BattleAIHooks:
	return BattleAIHooks.new()


func _exit_tree() -> void:
	if Duo.active and Duo.director == self:
		Duo.stop()


func members() -> Array:
	return [pink, blue].filter(func(c): return is_instance_valid(c))


func busy() -> bool:
	return GameState.in_dialogue or GameState.in_cutscene or CG.is_busy() or Dialogue.is_active()


func add_view(n: Node2D) -> void:
	get_parent().add_child.call_deferred(n)


func cells(key: String) -> Array[Vector2i]:
	return QuestMaps.cells(map_id(), key)


func world(c: Vector2i) -> Vector2:
	return Cutscene.cell_to_world(c)


func tickle(pc: PlayableCharacter, key: String, every: float, amount: float, zone: String, delta: float, src: Node = null) -> void:
	var k := str(pc.get_instance_id()) + key
	_tick[k] = float(_tick.get(k, 0.0)) - delta
	if float(_tick[k]) <= 0.0:
		_tick[k] = every
		var h := HitData.make_tickle(src if src else self, amount)
		h.zone = zone
		pc.receive_hit(h)


func update_checkpoints(r := 16.0) -> void:
	for c in cells("checkpoints"):
		for m in members():
			if (m as Node2D).global_position.distance_to(world(c)) <= r:
				checkpoint = world(c)


## 走到某处自动演一次的小剧场（标记点 key，theater_id）
func auto_theater(key: String, theater_id: String, r := 16.0) -> bool:
	if GameState.has_flag("cg_seen_theater:" + theater_id):
		return false
	for c in cells(key):
		for m in members():
			if (m as Node2D).global_position.distance_to(world(c)) <= r:
				CG.play_theater(theater_id)
				return true
	return false


## 两个都倒下：小剧场 → 都扶起来、回检查点
func on_defeat(_reason: String) -> void:
	if _defeat_busy:
		return
	_defeat_busy = true
	await CG.play_theater(defeat_theater())
	reset_to(checkpoint)
	_defeat_busy = false


func defeat_theater() -> String:
	return "palace_down"


func reset_to(at: Vector2) -> void:
	for c in members():
		var pc := c as PlayableCharacter
		if Downed.is_downed(pc):
			(pc.get_node("Downed") as Downed).revive_now()
		pc.status.clear_root()
		pc.laugh.set_value(0.0)
		pc.global_position = at + (Vector2(10, 0) if pc.character_id == "blue" else Vector2.ZERO)
	var p := GameState.player
	if is_instance_valid(p) and p.get("camera"):
		p.camera.reset_smoothing()

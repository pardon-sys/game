class_name PenanceCell
extends Node2D
## 反省篇第一章·反省牢房（floor_06_penance_cell；地图 [legend] 的 penancecell；台词和小剧场在 tools/build/penance_text/）：
##   六件道具（SPOTS）：摆一个陷阱演员（CGActor.make_trap，地图上画在地板之上）+ 一个按 E 的调查点 → 对话 floor_06/penance_<id>
##   （没玩过：放小剧场 penance_<id>；玩过：一句短台词）。玩过 = 剧情标记 cg_seen_theater:penance_<id>。
##   六件都玩过（ALL_FLAG）：东北角的墙缝里探出挠脚鼠（wall_crack 演员换成有老鼠的那一帧），调查墙缝 → 对话 floor_06/penance_rat
##   （按以前在地牢放没放过它分两种开场；没玩完六件时只有吱吱声）。答应它 → 对话 set.call = penance_rat_outfit
##   （DialogueBox → crawl()：强制换上鼠鼠装 → 过场 penance_crawl（钻进墙缝 → 章末画面 → 按 E 进第二章·鼠洞）；鼠鼠装一直穿着，章末也不脱）。
## 鼠鼠装：wear_mouse / take_off_mouse（原来的裤子 / 鞋子记在 vars.PREV_VAR，脱下时还回去）。
## 测试：spots、crack_open、spot(id)、all_done()、wear_mouse()、take_off_mouse()。

const SPOTS := {
	"stocks": {"cell": Vector2i(4, 4), "key": "stocks"},
	"doll": {"cell": Vector2i(7, 3), "key": "plush_doll"},
	"bed": {"cell": Vector2i(13, 3), "key": "penance_bed"},
	"tub": {"cell": Vector2i(15, 8), "key": "sitz_bath"},
	"cat": {"cell": Vector2i(12, 10), "key": "cat_guard"},
	"chest": {"cell": Vector2i(4, 9), "key": "trophy_chest"},
}
const CRACK_CELL := Vector2i(17, 2)
const ALL_FLAG := "penance_all_done"
const DONE_FLAG := "penance_ch1_done"
const PREV_VAR := "penance_prev_equip"
const SHORTS := "equip_mouse_shorts"
const SHOES := "equip_mouse_paw_shoes"

var spots := {}
var actors := {}
var crack: CGActor
var crack_spot: Node2D
var crack_open := false


func _ready() -> void:
	PalaceRoom.ensure_pants()
	for id in SPOTS:
		var info: Dictionary = SPOTS[id]
		var key := str(info["key"])
		var a := CGActor.make_trap("penance_" + id, key, CG.data.get("trap_actors", {}).get(key, {}))
		# CG 舞台用的陷阱演员有的 z = -1（压在人物下面）：放到地图上会被地板盖住，调回地板之上
		a.z_index = maxi(a.z_index, 1)
		add_child(a)
		a.global_position = Cutscene.cell_to_world(info["cell"])
		actors[id] = a
		spots[id] = _make_spot("floor_06/penance_" + id, info["cell"] + Vector2i(0, 1))
	crack = CGActor.make_trap("penance_crack", "wall_crack", CG.data.get("trap_actors", {}).get("wall_crack", {}))
	crack.z_index = 1
	add_child(crack)
	crack.global_position = Cutscene.cell_to_world(CRACK_CELL)
	crack_spot = _make_spot("floor_06/penance_rat", CRACK_CELL + Vector2i(-1, 1))
	_refresh()


func _make_spot(dialogue: String, cell: Vector2i) -> Node2D:
	var sp := PrisonOddities.Spot.new()
	sp.dialogue = dialogue
	add_child(sp)
	sp.global_position = Cutscene.cell_to_world(cell)
	return sp


func spot(id: String) -> Node2D:
	return crack_spot if id == "rat" else spots.get(id)


static func done(id: String) -> bool:
	return GameState.has_flag("cg_seen_theater:penance_" + id)


static func all_done() -> bool:
	return SPOTS.keys().all(func(id): return done(str(id)))


func _process(_delta: float) -> void:
	_refresh()


## 六件都玩过：墙缝里探出挠脚鼠（只换一次）
func _refresh() -> void:
	var open := all_done()
	if open and not GameState.has_flag(ALL_FLAG):
		GameState.set_flag(ALL_FLAG)
	if open == crack_open:
		return
	crack_open = open
	# 陷阱演员每帧按 trap_info 的 idle 帧画：换一份 idle = 有老鼠的那一帧（别改到 CG.data 里共用的那份）
	var info: Dictionary = crack.trap_info.duplicate()
	info["idle"] = [1] if open else [0]
	crack.trap_info = info
	if open and is_inside_tree() and not GameState.in_cutscene:
		Audio.play("pop", -6.0, 0.0, 1.6)
		SpeechBubble.say(crack, "吱吱？", 20.0, 1.6)


# ------------------------------------------------------------------ 鼠鼠装
## 强制换上鼠鼠短裤 + 鼠爪鞋（诅咒；原来占着这些部位的装备记下来，脱下时还回去）
static func wear_mouse(who := "pink") -> void:
	if not Equipment.unlocked():
		GameState.set_flag(Equipment.UNLOCK_FLAG)
	var mine: Dictionary = GameState.equipment.get(who, {})
	var prev := {}
	for id in [SHORTS, SHOES]:
		var it := ItemDB.get_item(id) as EquipData
		for z in it.slots:
			var cur := str(mine.get(z, ""))
			if cur != "" and cur != SHORTS and cur != SHOES:
				prev[z] = cur
	GameState.vars[PREV_VAR] = prev
	for id in [SHORTS, SHOES]:
		if not GameState.inventory.has(id):
			GameState.inventory.add(ItemDB.get_item(id))
		var it := ItemDB.get_item(id) as EquipData
		for z in it.slots:
			var cur := str(mine.get(z, ""))
			if cur != "" and cur != id:
				Equipment._remove(mine, cur)
		for z in it.slots:
			mine[z] = id
	GameState.equipment[who] = mine
	GameState.set_flag("wearing_%s_%s" % [who, SHORTS])
	GameState.set_flag("wearing_%s_%s" % [who, SHOES])
	Equipment._notify(who)


## 脱下鼠鼠装、把原来的装备穿回去
static func take_off_mouse(who := "pink") -> void:
	var mine: Dictionary = GameState.equipment.get(who, {})
	for id in [SHORTS, SHOES]:
		Equipment._remove(mine, id)
		GameState.set_flag("wearing_%s_%s" % [who, id], false)
	var prev: Dictionary = GameState.vars.get(PREV_VAR, {})
	for z in prev:
		mine[z] = str(prev[z])
	GameState.vars.erase(PREV_VAR)
	GameState.equipment[who] = mine
	Equipment._notify(who)


static func wearing_mouse(who := "pink") -> bool:
	var w := Equipment.worn(who)
	return w.values().has(SHORTS) and w.values().has(SHOES)


## 答应挠脚鼠：换上鼠鼠装 → 钻墙缝的过场（结尾是章末画面，按 E 进鼠洞）。鼠鼠装不脱（到第三章出了水道才脱，take_off_mouse）
static func crawl() -> void:
	wear_mouse()
	GameState.set_flag(DONE_FLAG)
	Cutscene.play("penance_crawl")

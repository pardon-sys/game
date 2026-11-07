class_name PrisonOddities
extends Node2D
## 夜探地牢的牢房里那些奇怪的东西（TaskSneak 开始时摆上；台词和小剧场在 tools/build/knight_text/prison.py）：
##   挠痒鼠（第一间牢房）、被没收的痒痒手套（第二间牢房的墙上）：它们关在牢房里，调查那间牢房的铁门（按 E）就触发——
##     牢门自己的「门锁着」调查关掉，换成这里的调查点（不然按 E 总是先碰到门）；坏掉的审讯椅（审问室）：按 E 调查（对话 floor_06/after_prison_*）；
##   马凳（审问室角落）：走到旁边（SADDLE_R 以内）自动触发小剧场 prison_saddle（只一次）。
##   挠痒鼠没放出来会尖叫把守卫引来（对话 set.call = prison_alarm → alarm()）。
## 测试：spots、saddle_done、alarm()、spot(id)。

const SPOTS := {
	"rat": {"actor": Vector2i(14, 3), "talk": Vector2i(14, 4), "dialogue": "floor_06/after_prison_rat", "kind": "monster", "key": "rat"},
	"glove": {"actor": Vector2i(20, 2), "talk": Vector2i(20, 4), "dialogue": "floor_06/after_prison_glove", "kind": "monster", "key": "glove"},
	"chair": {"actor": Vector2i(18, 12), "talk": Vector2i(18, 12), "dialogue": "floor_06/after_prison_chair", "kind": "", "key": ""},
}
const SADDLE_AT := Vector2i(16, 13)
const SADDLE_R := 14.0
const ALARM_R := 220.0

var spots := {}
var saddle: Node2D
var saddle_done := false


func _ready() -> void:
	for id in SPOTS:
		var info: Dictionary = SPOTS[id]
		var actor_cell: Vector2i = info["actor"]
		if str(info["kind"]) == "monster":
			var a := CGActor.make_monster("prison_" + id, str(info["key"]), CG.data.get("actors", {}).get(str(info["key"]), {}))
			a.z_index = maxi(a.z_index, 1)
			add_child(a)
			a.global_position = Cutscene.cell_to_world(actor_cell)
		# 关在牢房里的：牢门自己的调查（门锁着）关掉，调查牢门就触发它们
		_mute_gate(info["talk"])
		var sp := Spot.new()
		sp.dialogue = str(info["dialogue"])
		add_child(sp)
		sp.global_position = Cutscene.cell_to_world(info["talk"])
		spots[id] = sp
	saddle = CGActor.make_trap("prison_saddle", "saddle_bench", CG.data.get("trap_actors", {}).get("saddle_bench", {}))
	# CG 舞台用的陷阱演员 z = -1（舞台上压在人物下面）：放到地图上会被地板盖住，调回地板之上
	saddle.z_index = 1
	add_child(saddle)
	saddle.global_position = Cutscene.cell_to_world(SADDLE_AT)
	saddle_done = GameState.has_flag("cg_seen_theater:prison_saddle")


## 那一格的牢门：关掉它自己的「门锁着」调查
func _mute_gate(cell: Vector2i) -> void:
	var lv := get_parent()
	while lv and lv.get_node_or_null("Entities") == null and lv.get_parent():
		lv = lv.get_parent()
	if lv == null:
		return
	var at := Cutscene.cell_to_world(cell)
	for g in lv.find_children("*", "", true, false):
		if g.get_script() and str(g.get_script().resource_path).ends_with("gate.gd") and (g as Node2D).global_position.distance_to(at) <= 10.0:
			var it := g.get_node_or_null("Interactable") as Interactable
			if it:
				it.enabled = false


func spot(id: String) -> Node2D:
	return spots.get(id)


func _process(_delta: float) -> void:
	if saddle_done or GameState.in_dialogue or GameState.in_cutscene or CG.is_busy():
		return
	var p := GameState.player
	if is_instance_valid(p) and p.global_position.distance_to(saddle.global_position) <= SADDLE_R:
		saddle_done = true
		CG.play_theater("prison_saddle")


## 挠痒鼠尖叫：附近的守卫都过来查看
static func alarm() -> int:
	var d := StealthDirector.current
	var p := GameState.player
	if d == null or not is_instance_valid(p):
		return 0
	return d.noise(p.global_position, ALARM_R)


## 按 E 说话 / 调查的点
class Spot extends Node2D:
	var dialogue := ""
	## 有这个剧情标记以后头顶不再冒「！」（InteractHint；做过的事件）
	var done_flag := ""
	## 提示（E /「！」）离地多高（东西高的话往上挪）
	var prompt_y := -22.0

	func _ready() -> void:
		var area := Interactable.new()
		area.prompt_offset = Vector2(0, prompt_y)
		var shape := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 12.0
		shape.shape = c
		area.add_child(shape)
		add_child(area)

	func on_interact(_player: Node) -> void:
		if not Dialogue.is_active():
			Dialogue.talk(dialogue)

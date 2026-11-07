class_name LevelExit
extends Area2D
## 关卡出口 / 楼梯：公主走进来时（可先播放一段对话）切换到 target_level。
## target_level 为 "next" 时按 data/floors.json 进入当前楼层的下一层。
## spawn：到了新地图站在同名的到达点（SpawnPoint）上（第六层小镇的楼梯用）；down：楼梯的样子（往下 / 往上）。
## locked：封住的出口（只播 dialogue，不走）。
## lock_flag：有这个剧情标记时锁住（比如夜里小屋的门）；unlock_flag：有这个标记才打开（比如拿到钥匙）。
## 锁住时播 locked_dialogue（没写就播 dialogue）；打开时播 dialogue（可以不写）。

@export var target_level := ""
@export var dialogue := ""
@export var size := Vector2(16, 16)
@export var spawn := ""
@export var down := true:
	set(v):
		down = v
		var look := get_node_or_null("Look")
		if look:
			look.set("kind", "stairs_down" if v else "stairs_up")
@export var locked := false
@export var lock_flag := ""
@export var unlock_flag := ""
@export var locked_dialogue := ""
## 反省篇的地图（牢房 / 鼠洞 / 水道 / 旧王宫）：出口上自动摆一个显眼的标记（exit_markers.png：往上的楼梯 / 往下的楼梯 / 门 / 墙洞 / 梯子）
## + 头顶一行「→ 目的地」（锁着时加「（锁着）」），见 _add_marker。
const MARKERS := "res://assets/generated/exit_markers.png"
const MARKER_MAPS := ["floor_06_penance", "floor_06_rat_tunnel", "floor_06_waterway", "floor_06_palace"]
## 密道：通往这些地图的出口（画后面 / 衣柜里……）没走过之前不显示标志和黄字，只看得到那幅画；走过一次（哪个方向都算）才显示
const SECRET_MAPS := ["floor_06_palace_tunnels"]
## 打开后第一次走进来播的对话（比如「用钥匙……打开了！」），只播一次。
@export var open_dialogue := ""

var _used := false
var _retry := 0.0
## 上次走进来时没处理（正在对话 / main 正忙），人还在里面就再试
var _pending := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := RectangleShape2D.new()
	shape.size = size
	$Shape.shape = shape
	body_entered.connect(_on_body_entered)
	_add_marker.call_deferred()


func _floor_id() -> String:
	var n: Node = self
	while n:
		var v: Variant = n.get("floor_id")
		if v != null and str(v) != "":
			return str(v)
		n = n.get_parent()
	return ""


## 出口长什么样：0 往上的楼梯 / 1 往下的楼梯 / 2 门 / 3 墙洞 / 4 梯子
static func marker_kind(src: String, dst: String) -> int:
	if src.begins_with("floor_06_palace_clock_") and dst.begins_with("floor_06_palace_clock_"):
		var a := int(src.get_slice("_", 4))
		var b := int(dst.get_slice("_", 4))
		if (a == 3 and b == 4) or (a == 4 and b == 3):
			return 4
		return 0 if b > a else 1
	if src.begins_with("floor_06_palace_clock_1") and dst == "floor_06_palace_ante":
		return 1
	if dst == "floor_06_palace_clock_1":
		return 0
	if dst.contains("tunnels") or src.contains("tunnels") or dst.contains("rat_tunnel") or dst.contains("waterway") or src.contains("rat_tunnel"):
		return 3
	return 2


## 目的地的地图 id（构建好的出口存的是 res://levels/<id>/floor.tscn）
func _dst_id() -> String:
	var d := target_level
	if d.begins_with("res://"):
		d = d.get_base_dir().get_file()
	return d


static func passage_flag(a: String, b: String) -> String:
	var p := [a, b]
	p.sort()
	return "passage_seen_%s_%s" % p


## 这个出口是不是还没被发现的密道入口（不显示标志）
func secret_hidden() -> bool:
	var dst := _dst_id()
	if not SECRET_MAPS.has(dst) or SECRET_MAPS.has(_floor_id()):
		return false
	return not GameState.has_flag(passage_flag(_floor_id(), dst))


func _add_marker() -> void:
	var src := _floor_id()
	if not MARKER_MAPS.any(func(p): return src.begins_with(p)):
		return
	var dst_id := target_level
	if dst_id == "" or dst_id == "next":
		return
	dst_id = _dst_id()
	if ResourceLoader.exists(MARKERS):
		var spr := Sprite2D.new()
		spr.name = "Marker"
		spr.texture = load(MARKERS)
		spr.hframes = 5
		spr.frame = marker_kind(src, dst_id)
		spr.offset = Vector2(0, -20)
		add_child(spr)
	var tag := Label.new()
	tag.name = "MarkerLabel"
	var nm := Floors.display_name(dst_id).replace("旧王宫·", "")
	tag.text = "→ " + nm + ("（锁着）" if is_locked_now() else "")
	tag.add_theme_font_size_override("font_size", 8)
	tag.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6) if not is_locked_now() else Color(0.75, 0.7, 0.75))
	tag.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.15))
	tag.add_theme_constant_override("outline_size", 3)
	tag.position = Vector2(-tag.get_minimum_size().x * 0.5, -46)
	tag.z_index = 30
	add_child(tag)
	_marker_lock = is_locked_now()
	_marker_hidden = not secret_hidden()   # 让 _process 第一帧就刷新显隐


var _marker_lock := false
var _marker_hidden := false


func _process(_d: float) -> void:
	var tag := get_node_or_null("MarkerLabel") as Label
	if tag and _marker_hidden != secret_hidden():
		_marker_hidden = secret_hidden()
		tag.visible = not _marker_hidden
		var mk := get_node_or_null("Marker") as Node2D
		if mk:
			mk.visible = not _marker_hidden
	if tag and _marker_lock != is_locked_now():
		_marker_lock = is_locked_now()
		tag.text = tag.text.replace("（锁着）", "") + ("（锁着）" if _marker_lock else "")
		tag.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6) if not _marker_lock else Color(0.75, 0.7, 0.75))


## 走进来那一刻正好有对话 / 换图被拒（main 正忙）时，人还站在出口里：空下来以后再试一次（以前会一直卡在出口上走不了）
func _physics_process(delta: float) -> void:
	if _used or not _pending:
		return
	_retry -= delta
	if _retry > 0.0:
		return
	_retry = 0.3
	if Dialogue.is_active() or GameState.in_dialogue or GameState.in_cutscene:
		return
	_pending = false
	for b in get_overlapping_bodies():
		if b.is_in_group("player"):
			_on_body_entered(b)
			return


func _on_body_entered(body: Node) -> void:
	if _used or not body.is_in_group("player"):
		return
	if Dialogue.is_active():
		_pending = true
		return
	_used = true
	var is_locked := is_locked_now()
	var say := locked_dialogue if is_locked and locked_dialogue != "" else dialogue
	if not is_locked and open_dialogue != "" and not GameState.has_flag("opened_" + open_dialogue):
		GameState.set_flag("opened_" + open_dialogue)
		say = open_dialogue
	if say != "":
		Dialogue.start(say)
		await Dialogue.finished
	if is_locked:
		await get_tree().create_timer(1.0).timeout
		_used = false
		return
	GameState.pending_spawn = spawn
	if SECRET_MAPS.has(_dst_id()) or SECRET_MAPS.has(_floor_id()):
		GameState.set_flag(passage_flag(_floor_id(), _dst_id()))
	var path := resolve_target()
	var main := get_tree().get_first_node_in_group("main")
	if main and path != "":
		if bool(main.get("_busy")):
			# 正在换别的图：这次不算，等一会儿再试
			await get_tree().create_timer(0.5).timeout
			_used = false
			_pending = true
			return
		main.change_level(path)


## 现在是不是锁着（locked、lock_flag、unlock_flag 一起判断）。
func is_locked_now() -> bool:
	if locked:
		return true
	if lock_flag != "" and GameState.has_flag(lock_flag):
		return true
	return unlock_flag != "" and not GameState.has_flag(unlock_flag)


func resolve_target() -> String:
	if target_level != "next":
		return target_level
	var next := Floors.next_of(str(owner.get("floor_id")) if owner else "")
	return Floors.scene(next) if next != "" else ""

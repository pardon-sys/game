extends Node2D
## 小镇道具（房屋、摊位、篝火、帐篷、哨塔、栅栏、训练假人、路灯……）：图集 assets/generated/town_props.png，
## 每种道具的区域、碰撞、发光、动画在 town_props.json（tools/art/gen_town_art.py 生成）。
## 构建器图例：X = prop type=<道具> [action=…]
##   action = heal          交互：恢复满生命、闷笑清零（篝火）
##   action = shop:<商店>    交互：打开商店（data/shop/<商店>.json）
##   action = training      交互：保卫队训练（TrainingDB，小游戏以后接）
##   action = talk:<文件>[#节点]  交互：人物对话（data/dialogues/<文件>.json，可以指定从哪个节点开始——房间里的家具共用一个文件）
##   action = hide          交互：躲进去 / 出来（潜入模式的木箱、矿车，见 StealthDirector）
##   action = read:<对话 id> 交互：读一段普通对话（像石碑）
##   show_flag = 标记      有这个剧情标记才出现；hidden_flag = 标记：有就不出现（庆功宴摊位通关以后的装扮）

## 等距楼层里道具碰撞盒的最大边长（像素）
const ISO_BODY_MAX := 14.0
const SHEET := preload("res://assets/generated/town_props.png")
const META_PATH := "res://assets/generated/town_props.json"

static var _meta := {}

@export var kind := "crate"
@export var action := ""
@export var show_flag := ""
@export var hidden_flag := ""

var sprite: Sprite2D
## 着火的道具（篝火、火堆、路灯）：在 torch 组里，幽灵进了光照范围就现形（TickleGhost 读 lit）
var lit := false
var _anim_t := 0.0
var _frames: Array = []


static func meta() -> Dictionary:
	if _meta.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
		_meta = parsed if parsed is Dictionary else {}
	return _meta


func _ready() -> void:
	var info: Dictionary = meta().get(kind, {})
	if info.is_empty():
		push_warning("没有这种道具: " + kind)
		return
	add_to_group("prop")
	if kind.begins_with("bonfire") or info.get("fire", false) or kind.begins_with("fire") or kind.begins_with("lamp"):
		lit = true
		add_to_group("torch")
	var r: Array = info["region"]
	sprite = Sprite2D.new()
	sprite.texture = SHEET
	sprite.region_enabled = true
	sprite.region_rect = Rect2(r[0], r[1], r[2], r[3])
	sprite.offset = Vector2(0, -float(r[3]) / 2.0)
	if info.get("floor", false):
		sprite.offset = Vector2(0, -8)
		# 地面上的东西（楼梯、木地板、地毯）挪到不参与 y 排序的地面层，不会盖住走在上面的人
		var floor_layer := get_parent().get_parent().get_node_or_null("FloorObjects") if get_parent() and get_parent().name == "Entities" else null
		if floor_layer:
			_move_to.call_deferred(floor_layer, info.get("under", false))
	# lift：挂在墙上的东西（窗户、画）往上抬，看起来贴在上面那面墙上；
	# 节点本身挪到墙那一格之上（y 排序排在墙上火把之前 = 火把画在它前面），精灵和交互范围反向补回
	var lift := float(info.get("lift", 0))
	sprite.offset.y -= lift
	var sort_shift := 0.0
	if lift > 0.0 and not IsoView.enabled:
		sort_shift = lift + 10.0
		position.y -= sort_shift
		sprite.offset.y += sort_shift
	add_child(sprite)
	if info.has("anim"):
		var r2: Array = meta()[str(info["anim"])]["region"]
		_frames = [Rect2(r[0], r[1], r[2], r[3]), Rect2(r2[0], r2[1], r2[2], r2[3])]
	if info.has("body"):
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		var b: Array = info["body"]
		rect.size = Vector2(float(b[0]), float(b[1]))
		# 等距楼层：碰撞在逻辑格子里、贴图是直立的，宽的碰撞盒投影出去会伸到贴图外面（像空气墙）——收窄到格子中间
		if IsoView.enabled:
			rect.size.x = minf(rect.size.x, ISO_BODY_MAX)
			rect.size.y = minf(rect.size.y, ISO_BODY_MAX)
		shape.shape = rect
		shape.position = Vector2(0, float(info.get("body_y", -3)))
		body.add_child(shape)
		add_child(body)
	if info.has("light"):
		var l: Array = info["light"]
		var light := PointLight2D.new()
		light.texture = preload("res://assets/lights/light_soft.tres")
		light.color = Color(float(l[0]), float(l[1]), float(l[2]))
		var fire := kind.begins_with("bonfire")
		light.energy = 0.8 if fire else (0.6 if info.get("fire", false) else 0.4)
		light.texture_scale = 1.3 if fire else (0.8 if info.get("fire", false) else 0.55)
		light.position = Vector2(0, -float(r[3]) * 0.6)
		add_child(light)
	if kind.begins_with("bonfire") or info.get("fire", false):
		Fx.emitter(self, "ember", 8, 1.0, {"offset": Vector2(0, -10), "dir": Vector2.UP, "spread": 25.0,
				"speed": [12.0, 26.0], "gravity": Vector2(0, -10), "color": Color(1, 0.7, 0.4), "z": 3})
	# smoke：烧过的房子还在冒烟
	if info.get("smoke", false):
		Fx.emitter(self, "dust", 6, 2.2, {"offset": Vector2(8, -float(r[3]) * 0.7), "dir": Vector2.UP, "spread": 15.0,
				"speed": [6.0, 12.0], "gravity": Vector2(2, -4), "color": Color(0.35, 0.32, 0.36, 0.7), "z": 3})
	if action != "":
		var it := Interactable.new()
		it.name = "Interactable"
		it.prompt_offset = Vector2(0, -float(r[3]) - 4.0 + sort_shift)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(maxf(float(r[2]), 18.0), 20)
		shape.shape = rect
		shape.position = Vector2(0, -6 + sort_shift)
		it.add_child(shape)
		add_child(it)
	if show_flag != "" or hidden_flag != "":
		_refresh_visibility()
		GameState.flag_changed.connect(func(_f: String): _refresh_visibility())


## 看不见的时候碰撞也关掉（PROCESS_MODE_DISABLED 会把碰撞体移出物理）
func _refresh_visibility() -> void:
	var show := (show_flag == "" or GameState.has_flag(show_flag)) and (hidden_flag == "" or not GameState.has_flag(hidden_flag))
	visible = show
	process_mode = Node.PROCESS_MODE_INHERIT if show else Node.PROCESS_MODE_DISABLED


## 被撞碎（攻防战的攻城车 / 巨魔将军冲锋）：只有沙袋、路障、碎石、木箱这类小东西会碎。
func smash() -> void:
	if not (kind.begins_with("sandbag") or kind.begins_with("barricade") or kind.begins_with("rubble") or kind.begins_with("crate")
			or kind.begins_with("barrel") or kind.begins_with("stump")):
		return
	Fx.burst(get_parent(), global_position + Vector2(0, -6), "wood", 10, 60.0, 0.6, Vector2(0, 120), Color(0.8, 0.6, 0.4))
	Fx.burst(get_parent(), global_position + Vector2(0, -4), "dust", 8, 40.0, 0.5, Vector2(0, 20))
	queue_free()


## under：铺在最底下（木地板），其它地面上的东西（地毯、楼梯、陷阱）画在它上面。
func _move_to(layer: Node, under := false) -> void:
	var gp := global_position
	get_parent().remove_child(self)
	layer.add_child(self)
	if under:
		layer.move_child(self, 0)
	global_position = gp


func _process(delta: float) -> void:
	if _frames.is_empty():
		return
	_anim_t += delta
	sprite.region_rect = _frames[int(_anim_t * 6.0) % _frames.size()]


func on_interact(player: Node) -> void:
	var parts := action.split(":", true, 1)
	match parts[0]:
		"heal":
			Town.rest(player)
		"shop":
			Town.open_shop(parts[1] if parts.size() > 1 else "market")
		"training":
			Town.open_training()
		"talk":
			var tk := parts[1].split("#", true, 1)
			Dialogue.talk(tk[0], tk[1] if tk.size() > 1 else "")
		"hide":
			StealthDirector.toggle_hide(player, self)
		"read":
			Audio.play("book", -4.0)
			Dialogue.start(parts[1])

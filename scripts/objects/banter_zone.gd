class_name BanterZone
extends Area2D
## 边走边聊（可复用）：操控的人走进区域 → 两个公主头顶轮流冒气泡说一段话，不打断走路，只触发一次（剧情标记 banter_<id>）。
## 台词在本层对话文件夹的 banter.json：{"<id>": [{"who": "pink" / "blue", "text": "…", "pants_text": "…"（可选）,
##   "pants_only": true（可选：只在有千手痒痒裤时说）}, …]}。
##   有千手痒痒裤（剧情标记 blue_tickle_pants）时，蓝色公主那句换成 pants_text（夹着「哈哈」）；pants_only 的句子才会出现。
## 一句停留 LINE_MIN 秒起、按字数加长。说的人不在场（没跟着）就跳过那一句。
## 图例：X = banter id=<段> w=<格> h=<格>

signal started(id: String)
signal finished(id: String)

const LINE_MIN := 2.4
const PER_CHAR := 0.11
const HEIGHT := 36.0

@export var id := ""
@export var size := Vector2(16, 16)

var playing := false
## 正在说第几句（测试用）
var line_index := -1


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	shape.shape = r
	add_child(shape)
	body_entered.connect(_on_body)


func flag() -> String:
	return "banter_" + id


func _on_body(b: Node) -> void:
	if playing or b != GameState.player or GameState.has_flag(flag()):
		return
	play()


static func lines_for(banter_id: String, floor_id: String) -> Array:
	var path := Floors.dialogue_dir(floor_id) + "banter.json"
	if not FileAccess.file_exists(path):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (data as Dictionary).get(banter_id, []) if data is Dictionary else []


func _level() -> Node:
	var n := get_parent()
	while n and not n.has_node("Walls"):
		n = n.get_parent()
	return n


func speaker(who: String) -> Node2D:
	var lv := _level()
	if lv == null:
		return null
	for n in lv.find_children("*", "PlayableCharacter", true, false):
		if str(n.get("character_id")) == who and (n as Node2D).visible:
			return n
	return null


func play() -> void:
	playing = true
	GameState.set_flag(flag())
	started.emit(id)
	var lv := _level()
	var pants := GameState.has_flag("blue_tickle_pants")
	var lines := lines_for(id, str(lv.get("floor_id")) if lv else "")
	for i in lines.size():
		var ln: Dictionary = lines[i]
		if bool(ln.get("pants_only", false)) and not pants:
			continue
		var text := str(ln.get("pants_text", ln.get("text", ""))) if pants and ln.has("pants_text") else str(ln.get("text", ""))
		var who := speaker(str(ln.get("who", "pink")))
		if who == null or text == "":
			continue
		line_index = i
		var dur := maxf(LINE_MIN, 1.0 + text.length() * PER_CHAR)
		SpeechBubble.say(who, text, HEIGHT, dur)
		# 过场 / 对话时停下来等
		var t := 0.0
		while t < dur:
			await get_tree().process_frame
			if not is_inside_tree():
				return
			if not (GameState.in_dialogue or GameState.in_cutscene):
				t += get_process_delta_time()
	playing = false
	line_index = -1
	finished.emit(id)

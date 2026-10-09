class_name MemoryShard
extends Node2D
## 回忆碎片（第八层夜迷宫，6 片）：地上一点发光的小东西，走近就捡起来——屏幕泛白，闪回一句她小时候的记忆（她的独白，不点明）。
## 捡过的记在剧情标记 f8m_mem_<id>；collected() = 已捡的片数。收齐 6 片：出口前多一段小剧场 f8_maze_memory。
## 图例：X = memshard id=<1~6>

const TOTAL := 6
## 每片是什么、闪回的独白
const SHARDS := {
	1: {"name": "半截蜡笔", "lines": ["……蜡笔。……紫色的。", "……那时候，画了好多只手。……它说，画得很像。"]},
	2: {"name": "半个雪花发夹", "lines": ["……发夹。……另一半，在我头上。", "……弄丢的时候，是谁找了一整晚。……"]},
	3: {"name": "八音盒的发条", "lines": ["……发条。……原来掉在这里。", "……每天晚上，拧一下，才肯睡。……有人陪着拧。"]},
	4: {"name": "小裙子的蝴蝶结", "lines": ["……蝴蝶结。……被挠到滚来滚去的时候，扯掉的。", "……笑到哭……也没人停。……我也没叫它停。"]},
	5: {"name": "旧茶匙", "lines": ["……茶匙。……两个人的茶，总是我先喝完。", "……「再来一杯」。……它的手，总是比我快。"]},
	6: {"name": "折起来的画", "lines": ["……一张画。……我，和好多只手。……大家都在笑。", "……那时候……说好了，要一直在一起的。"]},
}
const LIGHT_TEX := preload("res://assets/lights/light_soft.tres")

@export var id := 1

var _t := 0.0
var _taken := false


static func collected() -> int:
	var n := 0
	for i in range(1, TOTAL + 1):
		if GameState.has_flag("f8m_mem_%d" % i):
			n += 1
	return n


func _ready() -> void:
	add_to_group("memory_shard")
	if GameState.has_flag("f8m_mem_%d" % id):
		queue_free()
		return
	var l := PointLight2D.new()
	l.texture = LIGHT_TEX
	l.texture_scale = 0.4
	l.energy = 0.8
	l.color = Color(1.0, 0.92, 0.7)
	l.height = 12.0
	l.position = Vector2(0, -6)
	add_child(l)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	var p := GameState.player as Node2D
	if _taken or not is_instance_valid(p) or GameState.in_dialogue or CG.is_busy() or Cutscene.is_playing():
		return
	if p.global_position.distance_to(global_position) < 12.0:
		take()


func take() -> void:
	if _taken:
		return
	_taken = true
	GameState.set_flag("f8m_mem_%d" % id)
	Audio.play("music_box", -10.0, 0.0, 1.0)
	ScreenFx.flash(Color(1, 0.97, 0.9), 0.8)
	var info: Dictionary = SHARDS.get(id, {"name": "碎片", "lines": ["……"]})
	var lines: Array = [{"speaker": "", "text": "（捡到了「%s」。回忆 %d / %d）" % [info["name"], collected(), TOTAL]}]
	for t in info["lines"]:
		lines.append({"speaker": "蓝色的公主", "emotion": "sad", "text": t})
	Dialogue.start_lines(lines, "f8m_mem_%d" % id)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


func _draw() -> void:
	var y := -6.0 + sin(_t * 2.5) * 1.5
	draw_circle(Vector2(0, y), 5.0, Color(1.0, 0.9, 0.6, 0.25 + 0.1 * sin(_t * 3.0)))
	draw_colored_polygon(PackedVector2Array([Vector2(0, y - 4), Vector2(3, y), Vector2(0, y + 4), Vector2(-3, y)]), Color(1.0, 0.95, 0.8))
	draw_circle(Vector2(0, 2), 3.0, Color(0, 0, 0, 0.25))

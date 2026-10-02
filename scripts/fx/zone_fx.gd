class_name ZoneFx
extends Sprite2D
## 部位专属挠痒特效：assets/generated/zone_fx.png（16x16 × 6 帧，每行一个部位；行号是部位表的 fx 字段）。
##   ZoneFx.play(部位, parent, pos, scale_k, weak)   播放一次后自动删除；weak = 挠到被束缚露出的部位（弱点）时放大 1.5 倍、变亮
##   ZoneFx.body_point(actor, 部位)                公主小人身上这个部位的位置（部位表的 body，x 随机左右翻转）
## 叠在来源命中特效（HitFx）之上：Actor.receive_hit 在公主身上播一份，PortraitFx 在立绘的部位位置播一份。
## 新增部位只要在 tools/art/gen_zone_art.py 的 ZONE_FX 里画一行、在部位表里写 fx 行号和 body。

const SHEET := preload("res://assets/generated/zone_fx.png")
const FPS := 14.0
const ROWS := 8
const WEAK_SCALE := 1.5
const WEAK_COLOR := Color(1.6, 1.3, 1.5)

## 测试 / 性能需要时可以关掉。
static var enabled := true

var zone := ""
var weak := false
var _t := 0.0


static func row_of(z: String) -> int:
	var info := TickleZones.info(z)
	return int(info.get("fx", -1)) if info.has("fx") else -1


static func play(z: String, parent: Node, pos: Vector2, scale_k := 1.0, is_weak := false) -> ZoneFx:
	var row := row_of(z)
	if not enabled or row < 0 or row >= ROWS or parent == null or not parent.is_inside_tree():
		return null
	var s := ZoneFx.new()
	s.texture = SHEET
	s.hframes = 6
	s.vframes = ROWS
	s.frame_coords = Vector2i(0, row)
	s.zone = z
	s.weak = is_weak
	s.scale = Vector2.ONE * scale_k * (WEAK_SCALE if is_weak else 1.0)
	if is_weak:
		s.modulate = WEAK_COLOR
	s.z_index = 13
	parent.add_child(s)
	s.global_position = pos.round()
	return s


static func body_point(actor: Node2D, z: String) -> Vector2:
	var b: Variant = TickleZones.info(z).get("body", [0, -12])
	var off := Vector2(float(b[0]), float(b[1])) if b is Array and b.size() == 2 else Vector2(0, -12)
	if randf() < 0.5:
		off.x = -off.x
	return actor.global_position + off


func _process(delta: float) -> void:
	_t += delta
	var f := int(_t * FPS)
	if f >= hframes:
		queue_free()
		return
	frame_coords = Vector2i(f, frame_coords.y)

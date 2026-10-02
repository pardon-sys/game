class_name HitFx
extends Sprite2D
## 命中特效：assets/generated/hit_fx.png（24x24 × 6 帧，每行一种）。部位专属特效另见 ZoneFx。
##   HitFx.play(kind, parent, pos)   播放一次后自动删除
##   HitFx.kind_of(source)           按挠痒 / 攻击来源选特效：怪物看 MonsterStats.hit_fx，陷阱看 Trap.hit_fx，
##                                   投射物看发射者；组合技、余痒这类没有来源键的不播
## Actor.receive_hit 在挠痒 / 攻击生效后统一调用；暴击时额外叠一个 crit。

const SHEET := preload("res://assets/generated/hit_fx.png")
const KINDS := ["feather", "hand", "goo", "sting", "bubble", "brush", "pinch", "slash", "crit", "curse", "suck", "crawl"]
const FPS := 16.0

## 测试 / 性能需要时可以关掉。
static var enabled := true

var _t := 0.0


static func play(kind: String, parent: Node, pos: Vector2, flip := false) -> HitFx:
	var row := KINDS.find(kind)
	if not enabled or row < 0 or parent == null or not parent.is_inside_tree():
		return null
	var s := HitFx.new()
	s.texture = SHEET
	s.hframes = 6
	s.vframes = KINDS.size()
	s.frame_coords = Vector2i(0, row)
	s.flip_h = flip
	s.z_index = 12
	parent.add_child(s)
	s.global_position = pos.round()
	return s


static func kind_of(source: Variant) -> String:
	if source == null or not is_instance_valid(source):
		return ""
	if source is Monster:
		var st: MonsterStats = (source as Monster).stats
		return st.hit_fx if st else ""
	if source is Projectile:
		return kind_of((source as Projectile).shooter)
	var k: Variant = source.get("hit_fx")
	return str(k) if k is String else ""


func _process(delta: float) -> void:
	_t += delta
	var f := int(_t * FPS)
	if f >= hframes:
		queue_free()
		return
	frame_coords = Vector2i(f, frame_coords.y)

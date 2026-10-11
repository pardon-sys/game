class_name SiegeArt
extends RefCounted
## 攻防战的静态物件图集（tools/art/gen_siege_art.py 生成）：assets/generated/siege/props.png + props.json（名字 -> 区域）。

const TEX := preload("res://assets/generated/siege/props.png")
const META := "res://assets/generated/siege/props.json"

static var _meta := {}


static func region(key: String) -> Rect2:
	if _meta.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(META))
		_meta = parsed if parsed is Dictionary else {}
	var r: Variant = _meta.get(key, [0, 0, 1, 1])
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


## 用图集里的一格做一个 Sprite2D（底边对齐节点原点）。
static func sprite(key: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = TEX
	s.region_enabled = true
	s.region_rect = region(key)
	s.offset = Vector2(0, -s.region_rect.size.y / 2.0)
	return s

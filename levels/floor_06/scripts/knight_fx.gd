class_name KnightFx
extends Sprite2D
## 骑士篇的特效动画（图是 codex 生成、tools/art/import_knight_fx.py 像素化切好的一排帧：assets/generated/fx/<名字>.png，每帧正方形，FRAMES 帧横排）。
##   KnightFx.play(父节点, 名字, 位置, {选项})：播一遍就自己收走；loop = true 一直循环（调用方负责收走 / stop()）。
##   选项：size（显示的边长，像素，默认按原图）、rot（弧度）、fps、loop、color（modulate）、z、flip、squash（y 方向压扁，地上的环）。
## 名字：spear_thrust / spear_sweep / spear_impact（训练室）、curse_burst / shockwave / dust_land / part_break / laugh_drain / tentacle /
##   lantern_pillar / purify（Boss）、throw_trail / beacon_light / trap_land（追逃）。图不存在时什么都不画（返回 null）。

const DIR := "res://assets/generated/fx/"
const FRAMES := 6

var loop := false
var fps := 14.0
var _t := 0.0


static func has(fx_name: String) -> bool:
	return ResourceLoader.exists(DIR + fx_name + ".png")


static func play(parent: Node, fx_name: String, at: Vector2, opts := {}) -> KnightFx:
	if not is_instance_valid(parent) or not has(fx_name):
		return null
	var fx := KnightFx.new()
	fx.texture = load(DIR + fx_name + ".png")
	fx.hframes = FRAMES
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.loop = bool(opts.get("loop", false))
	fx.fps = float(opts.get("fps", 14.0))
	var cell := float(fx.texture.get_width()) / FRAMES
	var k := float(opts.get("size", cell)) / cell
	fx.scale = Vector2(k, k * float(opts.get("squash", 1.0)))
	fx.rotation = float(opts.get("rot", 0.0))
	fx.flip_h = bool(opts.get("flip", false))
	fx.modulate = opts.get("color", Color.WHITE)
	fx.z_index = int(opts.get("z", 3))
	parent.add_child(fx)
	fx.global_position = at
	return fx


func _process(delta: float) -> void:
	_t += delta
	var f := int(_t * fps)
	if f >= FRAMES and not loop:
		queue_free()
		return
	frame = f % FRAMES


func stop() -> void:
	queue_free()

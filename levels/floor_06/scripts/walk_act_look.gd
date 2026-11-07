class_name WalkActLook
extends Node2D
## Boss / 大怪的外观：一张 4×4 走路图（下 / 左 / 右 / 上 各 4 帧）+ 一条动作条（探头、挥刷、晕……）。
## walk(方向, delta) 按屏幕方向选行、走一步换一帧；idle() 停在当前方向的第一帧；act(i) 显示动作条的第 i 帧。
## 图没生成出来时什么都不画（调用方自己有简笔画兜底）。

var walk_tex := ""
var act_tex := ""
var act_frames := 3
var lift := 0.0   # 图往上抬多少（脚底对齐节点位置）
var _walk: Sprite2D
var _act: Sprite2D
var _row := 0
var _t := 0.0


func ready_ok() -> bool:
	return _walk != null


func _ready() -> void:
	if ResourceLoader.exists(walk_tex):
		_walk = _make(walk_tex, 4, 4)
	if ResourceLoader.exists(act_tex):
		_act = _make(act_tex, act_frames, 1)
		_act.visible = false


func _make(path: String, hf: int, vf: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.hframes = hf
	s.vframes = vf
	var fh := float(s.texture.get_height()) / vf
	s.offset = Vector2(0, -fh * 0.5 + 1.0 - lift)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(s)
	return s


func walk(dir: Vector2, delta: float) -> void:
	if _walk == null:
		return
	_show_walk()
	if dir.length() > 0.01:
		var sd := IsoView.screen_dir(dir)
		_row = (1 if sd.x < 0 else 2) if absf(sd.x) > absf(sd.y) else (0 if sd.y > 0 else 3)
		_t += delta * 7.0
	_walk.frame = _row * 4 + int(_t) % 4


func idle() -> void:
	if _walk == null:
		return
	_show_walk()
	_walk.frame = _row * 4


func act(i: int) -> void:
	if _act == null:
		idle()
		return
	_act.visible = true
	if _walk:
		_walk.visible = false
	_act.frame = clampi(i, 0, act_frames - 1)


func bob(dy: float) -> void:
	position.y = dy


func _show_walk() -> void:
	_walk.visible = true
	if _act:
		_act.visible = false

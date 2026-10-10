class_name LaughRadius
extends Node2D
## 笑声半径（第八层夜迷宫）：她憋笑 / 失控时身上有一圈笑声的波纹，半径内的紫手被吸引过来（MazeHand.attracts）。
## 半径按闷笑阶段：平静 0、憋笑 RADII[0]、失控一 RADII[1]、失控二 RADII[2]；boost(倍数, 秒) 临时放大（组合技）、
## burst(半径) 一下子放出一大圈（笑声收集瓶打开）。

const RADII := [60.0, 100.0, 140.0]

var host: PlayableCharacter
var _boost := 1.0
var _boost_left := 0.0
var _burst := 0.0
var _burst_left := 0.0
var _t := 0.0
var _shown := 0.0


static func attach(c: PlayableCharacter) -> LaughRadius:
	var old := c.get_node_or_null("LaughRadius") as LaughRadius
	if old:
		return old
	var r := LaughRadius.new()
	r.name = "LaughRadius"
	r.host = c
	c.add_child(r)
	return r


func _ready() -> void:
	host = get_parent() as PlayableCharacter
	z_index = -1


func base_radius() -> float:
	if host == null or host.laugh == null:
		return 0.0
	var lm := host.laugh
	if lm.value >= lm.helpless_stage2_threshold:
		return RADII[2]
	if lm.is_helpless():
		return RADII[1]
	if lm.value >= lm.giggle_threshold:
		return RADII[0]
	return 0.0


## 现在的笑声半径（0 = 没在笑）。
func radius() -> float:
	var r := base_radius() * _boost
	if _burst_left > 0.0:
		r = maxf(r, _burst)
	return r


func boost(mult: float, sec: float) -> void:
	_boost = maxf(_boost, mult)
	_boost_left = maxf(_boost_left, sec)


func burst(r: float, sec := 1.5) -> void:
	_burst = r
	_burst_left = sec


func _process(delta: float) -> void:
	_t += delta
	if _boost_left > 0.0:
		_boost_left -= delta
		if _boost_left <= 0.0:
			_boost = 1.0
	_burst_left = maxf(0.0, _burst_left - delta)
	_shown = move_toward(_shown, radius(), 160.0 * delta)
	queue_redraw()


func _draw() -> void:
	if _shown < 2.0:
		return
	# 一圈圈往外扩的波纹（地面上的圆：等距楼层压成椭圆）
	draw_set_transform(Vector2(0, -6), 0.0, IsoView.ground_scale())
	for i in 3:
		var k := fmod(_t * 0.8 + i / 3.0, 1.0)
		var r := _shown * k
		draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(1.0, 0.6, 0.9, 0.35 * (1.0 - k)), 1.5)
	draw_arc(Vector2.ZERO, _shown, 0, TAU, 64, Color(1.0, 0.55, 0.85, 0.18), 1.0)
	draw_set_transform(Vector2.ZERO)

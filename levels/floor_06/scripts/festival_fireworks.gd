class_name FestivalFireworks
extends Node2D
## 庆功宴的烟花（AfterFestival.run_finale 摆在广场上空，过场放完收走）：每隔 EVERY 秒升起一发，飞 RISE 秒后在高处炸开成一圈火星，
## 火星带重力往下落、慢慢变暗；颜色在 COLORS 里轮换。纯 _draw，不用额外素材；不受夜里的光照影响（UNSHADED），每次炸开带一圈光晕。

const EVERY := 0.55
const RISE := 0.7
const SPARKS := 28
const LIFE := 1.4
const GRAVITY := 40.0
const COLORS := [Color("ff8fc8"), Color("ffd27a"), Color("8fc6ff"), Color("b6f0a0"), Color("d6a8ff")]

## 铺多开：升起和炸开的范围、火星飞多远都乘它（镜头拉远时调大；炸开的高度最多乘 1.3，不然炸到画面外面）
var spread := 1.0

var _t := 0.0
var _count := 0
var _rockets: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 60
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_rng.randomize()


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = EVERY
		_count += 1
		_rockets.append({"from": Vector2(_rng.randf_range(-90, 90), 120) * spread, "to": Vector2(_rng.randf_range(-110, 110) * spread, _rng.randf_range(-90, -40) * minf(spread, 1.3)),
			"age": 0.0, "col": COLORS[_count % COLORS.size()]})
	for r in _rockets.duplicate():
		r["age"] += delta
		if r["age"] >= RISE:
			_rockets.erase(r)
			for i in SPARKS:
				var dir := Vector2.from_angle(i * TAU / SPARKS + _rng.randf_range(-0.1, 0.1))
				_sparks.append({"pos": r["to"], "vel": dir * _rng.randf_range(50, 95) * sqrt(spread), "age": 0.0, "col": r["col"]})
			_flashes.append({"pos": r["to"], "age": 0.0, "col": r["col"]})
	for f in _flashes.duplicate():
		f["age"] += delta
		if f["age"] >= 0.35:
			_flashes.erase(f)
	for s in _sparks.duplicate():
		s["age"] += delta
		s["vel"] += Vector2(0, GRAVITY * delta)
		s["pos"] += s["vel"] * delta
		if s["age"] >= LIFE:
			_sparks.erase(s)
	queue_redraw()


func _draw() -> void:
	for r in _rockets:
		var k: float = r["age"] / RISE
		var p: Vector2 = (r["from"] as Vector2).lerp(r["to"], k)
		draw_line(p, p + ((r["from"] as Vector2) - (r["to"] as Vector2)).normalized() * 8.0, Color(1, 0.95, 0.8, 0.8), 1.5)
		draw_circle(p, 1.5, Color.WHITE)
	for f in _flashes:
		var k := 1.0 - float(f["age"]) / 0.35
		draw_circle(f["pos"], 26.0 * (1.2 - k), Color(f["col"], 0.35 * k))
		draw_circle(f["pos"], 6.0, Color(1, 1, 1, 0.8 * k))
	for s in _sparks:
		var a := 1.0 - float(s["age"]) / LIFE
		var col: Color = s["col"]
		draw_circle(s["pos"], 2.4, Color(col, a))
		draw_line(s["pos"], (s["pos"] as Vector2) - (s["vel"] as Vector2) * 0.08, Color(col, a * 0.7), 1.5)

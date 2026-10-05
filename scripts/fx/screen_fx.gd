class_name ScreenFx
extends CanvasLayer
## 全屏特效（可复用，盖在游戏画面上、HUD 下面）：
##   ScreenFx.flash(颜色, 秒)                   一闪（白闪 / 红闪）
##   var d := ScreenFx.darken(不透明度, 渐入秒)   全屏压暗，d.fade_out(秒) 收起
##   var v := ScreenFx.vignette(颜色, 强度, 脉动)  四周暗角（脉动 = 像心跳一样一明一暗），v.set_strength(x) / v.fade_out(秒)
## 千手痒痒魔的大招（压暗 + 红色暗角）、阶段三的持续红色脉动暗角、俯冲撞墙的白闪都用它。

const LAYER := 8
const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.9, 0.1, 0.2, 1.0);
uniform float strength = 0.6;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d * vec2(1.25, 1.0));
	float a = smoothstep(0.32, 0.78, r) * strength;
	COLOR = vec4(tint.rgb, a);
}
"""

var rect: ColorRect
var kind := "flash"
var pulse := false
var base_strength := 0.6
var _t := 0.0
var _mat: ShaderMaterial


static func _make(k: String) -> ScreenFx:
	var s := ScreenFx.new()
	s.kind = k
	(Engine.get_main_loop() as SceneTree).root.add_child(s)
	return s


static func flash(col := Color.WHITE, time := 0.3) -> ScreenFx:
	var s := _make("flash")
	s.rect.color = Color(col, 0.85)
	var tw := s.create_tween()
	tw.tween_property(s.rect, "color:a", 0.0, time)
	tw.tween_callback(s.queue_free)
	return s


static func darken(alpha := 0.55, time := 0.4) -> ScreenFx:
	var s := _make("darken")
	s.rect.color = Color(0.02, 0.0, 0.05, 0.0)
	s.create_tween().tween_property(s.rect, "color:a", alpha, time)
	return s


static func vignette(col := Color(0.9, 0.1, 0.2), strength := 0.6, pulsing := false) -> ScreenFx:
	var s := _make("vignette")
	s.pulse = pulsing
	s.base_strength = strength
	s._mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER
	s._mat.shader = sh
	s._mat.set_shader_parameter("tint", col)
	s._mat.set_shader_parameter("strength", 0.0)
	s.rect.material = s._mat
	s.rect.color = Color.WHITE
	s.create_tween().tween_method(func(v: float): s._mat.set_shader_parameter("strength", v), 0.0, strength, 0.5)
	return s


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


func set_strength(v: float) -> void:
	base_strength = v
	if _mat:
		_mat.set_shader_parameter("strength", v)


func fade_out(time := 0.4) -> void:
	pulse = false
	var tw := create_tween()
	if _mat:
		tw.tween_method(func(v: float): _mat.set_shader_parameter("strength", v), float(_mat.get_shader_parameter("strength")), 0.0, time)
	else:
		tw.tween_property(rect, "color:a", 0.0, time)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	if pulse and _mat:
		# 心跳：一下重一下轻
		var beat := pow(maxf(0.0, sin(_t * 5.0)), 6.0) + 0.5 * pow(maxf(0.0, sin(_t * 5.0 - 0.9)), 6.0)
		_mat.set_shader_parameter("strength", base_strength * (0.65 + 0.35 * beat))
	var cg := get_node_or_null("/root/CG")
	visible = not (cg != null and cg.is_playing())

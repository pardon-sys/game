class_name ThroneFx
extends RefCounted
## 王座间 Boss 战的特效（图：assets/generated/paint_fx.png，6 帧：粉颜料飞溅 / 蓝颜料飞溅 / 画布碎片 / 金色笔触 / 金色星光 / 颜料手）。
## 都是一次性的节点，挂到房间的父节点（Entities，等距地图里各自投影）上，演完自己删掉。
## splash(颜料飞溅 + 粒子)、shards(破层时画布碎片四散)、gold(破绽的金色笔触 + 星光)、flash(全屏闪白)、Watercolor(画里世界的水彩滤镜)。

const TEX := "res://assets/generated/paint_fx.png"
const FRAMES := 6


static func _sprite(frame: int) -> Sprite2D:
	var s := Sprite2D.new()
	if ResourceLoader.exists(TEX):
		s.texture = load(TEX)
		s.hframes = FRAMES
		s.frame = frame
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s


## 颜料飞溅：一团颜料「啪」地炸开（放大、淡出）+ 颜料滴粒子
static func splash(host: Node, pos: Vector2, blue := false, scale_k := 1.0) -> void:
	if host == null:
		return
	var n := Node2D.new()
	n.position = pos
	n.z_index = 3
	var s := _sprite(1 if blue else 0)
	s.offset = Vector2(0, -10)
	s.scale = Vector2.ONE * 0.3 * scale_k
	n.add_child(s)
	host.add_child(n)
	var tw := n.create_tween()
	tw.tween_property(s, "scale", Vector2.ONE * 0.9 * scale_k, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, 0.45)
	tw.tween_callback(n.queue_free)
	Fx.burst(host, pos + Vector2(0, -8), "drop", 10, 60.0 * scale_k, 0.5, Vector2(0, 30), Color(0.6, 0.8, 1.0) if blue else Color(1.0, 0.6, 0.8))


## 画布碎片：破一层的时候，一圈碎片往外飞、往下掉、转着淡出
static func shards(host: Node, pos: Vector2, count := 10) -> void:
	if host == null:
		return
	for i in count:
		var n := Node2D.new()
		n.position = pos + Vector2(randf_range(-20, 20), randf_range(-50, -10))
		n.z_index = 5
		var s := _sprite(2)
		s.scale = Vector2.ONE * randf_range(0.25, 0.45)
		n.add_child(s)
		host.add_child(n)
		var dir := Vector2.from_angle(randf() * TAU) * randf_range(40, 90)
		var tw := n.create_tween().set_parallel()
		tw.tween_property(n, "position", n.position + dir + Vector2(0, 40), 0.9).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "rotation", randf_range(-6, 6), 0.9)
		tw.tween_property(s, "modulate:a", 0.0, 0.9).set_delay(0.3)
		tw.chain().tween_callback(n.queue_free)
	Fx.burst(host, pos + Vector2(0, -30), "chip", 18, 90.0, 0.7, Vector2(0, 60), Color(0.95, 0.9, 0.75))


## 金色笔触 + 星光（打到破绽、八音盒、破层）
static func gold(host: Node, pos: Vector2) -> void:
	if host == null:
		return
	for f in [3, 4]:
		var n := Node2D.new()
		n.position = pos
		n.z_index = 6
		var s := _sprite(f)
		s.offset = Vector2(0, -16)
		s.scale = Vector2.ONE * 0.4
		s.rotation = randf_range(-0.5, 0.5) if f == 3 else 0.0
		n.add_child(s)
		host.add_child(n)
		var tw := n.create_tween()
		tw.tween_property(s, "scale", Vector2.ONE * (0.8 if f == 3 else 0.6), 0.15)
		tw.tween_property(s, "modulate:a", 0.0, 0.35)
		tw.tween_callback(n.queue_free)
	Fx.burst(host, pos + Vector2(0, -16), "spark", 8, 50.0, 0.5, Vector2.ZERO, Color(1.0, 0.85, 0.4))


## 全屏闪一下（白 / 粉）
static func flash(tree: SceneTree, col := Color(1, 1, 1, 0.7), time := 0.35) -> void:
	if tree == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 30
	var r := ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(r)
	tree.root.add_child(layer)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.0, time)
	tw.tween_callback(layer.queue_free)


## 画里世界的水彩滤镜：纸纹 + 颜色变柔 + 四角暗一点（被拉进画里时打开）
class Watercolor extends CanvasLayer:
	const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i), b = hash(i + vec2(1, 0)), c = hash(i + vec2(0, 1)), d = hash(i + vec2(1, 1));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}
void fragment() {
	vec2 uv = SCREEN_UV + (vec2(noise(UV * 40.0 + TIME * 0.2), noise(UV * 40.0 - TIME * 0.2)) - 0.5) * 0.006 * strength;
	vec3 col = texture(screen_tex, uv).rgb;
	// 纸纹：大小两层噪声；颜色往暖色画纸靠、稍微褪色
	float paper = noise(UV * 220.0) * 0.10 + noise(UV * 30.0) * 0.08;
	vec3 soft = mix(col, vec3(dot(col, vec3(0.3, 0.59, 0.11))), 0.25);
	soft = soft * vec3(1.05, 0.97, 0.92) + vec3(0.10, 0.06, 0.08);
	soft *= 1.0 - paper;
	// 四周一圈粉紫色的「颜料边」：越靠边越浓，边缘带一点笔刷的毛边
	float d = distance(UV, vec2(0.5));
	float edge = smoothstep(0.38, 0.72, d + (noise(UV * 18.0) - 0.5) * 0.08);
	soft = mix(soft, vec3(0.55, 0.32, 0.5), edge * 0.55);
	COLOR = vec4(mix(col, soft, strength), 1.0);
}
"""
	var rect: ColorRect

	func _ready() -> void:
		layer = 8
		rect = ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		var mat := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = SHADER
		mat.shader = sh
		rect.material = mat
		add_child(rect)

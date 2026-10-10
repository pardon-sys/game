class_name PerspectiveView
extends CanvasLayer
## 透视倾斜（可复用；2.5D 楼层由 scripts/level.gd 自动挂上）：世界画面像放在桌上斜着看——远处小、近处大。
##   在世界之上、UI 之下（层 LAYER）放一块全屏 ColorRect，shaders/perspective_tilt.gdshader 读屏幕贴图做投影变换。
##   tilt_deg：倾斜角（默认 40°）。画面底边只取中间 near_width() 宽的一段放大到全宽，顶边保持全宽。
##   镜头往上抬（camera_lift()）：主角显示在画面中下方，前方（上方）看得更远。
##   人物「立着」：透视会把地面纵向压扁，人物不该被压扁——upright_factor() 算出主角那一行的纵向补偿，交给 LitSprite.upright。
##   source_uv(画面上的点) / output_uv(原画面的点)：两边换算（测试、把世界坐标换成屏幕位置用）。

const SHADER := preload("res://shaders/perspective_tilt.gdshader")
const LAYER := 5
## 主角在原画面里的纵向位置（0 = 顶、1 = 底）：0.75 → 透视后大约在画面 64% 的高度
const PLAYER_ROW := 0.75

@export var tilt_deg := 40.0

var rect: ColorRect
var mat: ShaderMaterial


static func of(host: Node) -> PerspectiveView:
	return host.get_node_or_null("PerspectiveView") as PerspectiveView if host else null


static func attach(host: Node, tilt := 40.0) -> PerspectiveView:
	var pv := of(host)
	if pv:
		return pv
	pv = PerspectiveView.new()
	pv.name = "PerspectiveView"
	pv.tilt_deg = tilt
	host.add_child(pv)
	return pv


func _ready() -> void:
	layer = LAYER
	rect = ColorRect.new()
	rect.name = "Warp"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	rect.material = mat
	add_child(rect)
	refresh()


## 底边取多宽（40° → 0.6；0° → 1 = 不倾斜）。
func near_width() -> float:
	return clampf(1.0 - tilt_deg / 100.0, 0.3, 1.0)


func refresh() -> void:
	var m := homography()
	mat.set_shader_parameter("h_col0", m.x)
	mat.set_shader_parameter("h_col1", m.y)
	mat.set_shader_parameter("h_col2", m.z)


## 输出 UV → 原画面 UV 的投影变换（单位正方形 → 梯形：顶边 0..1、底边居中 near_width 宽）。
func homography() -> Basis:
	var b := near_width()
	var h := (1.0 - b) / b
	var k := (0.5 - b / 2.0) / b
	# x = (u + k·v) / (h·v + 1)，y = (v / b) / (h·v + 1)
	return Basis(Vector3(1.0, 0.0, 0.0), Vector3(k, 1.0 / b, h), Vector3(0.0, 0.0, 1.0))


func source_uv(out_uv: Vector2) -> Vector2:
	var p := homography() * Vector3(out_uv.x, out_uv.y, 1.0)
	return Vector2(p.x, p.y) / p.z


func output_uv(src_uv: Vector2) -> Vector2:
	var p := homography().inverse() * Vector3(src_uv.x, src_uv.y, 1.0)
	return Vector2(p.x, p.y) / p.z


## 原画面第 src_row 行的人物要纵向拉多少倍才「立着」（横向放大 ÷ 纵向放大）。
func upright_factor(src_row := PLAYER_ROW) -> float:
	var v := output_uv(Vector2(0.5, src_row)).y
	var dv := 0.001
	var sy := (dv) / (source_uv(Vector2(0.5, v + dv)).y - source_uv(Vector2(0.5, v)).y)
	var b := near_width()
	var sx := 1.0 / (1.0 - (1.0 - b) * src_row)
	return sx / sy


## 镜头往上抬多少（世界像素）：让主角落在原画面的 PLAYER_ROW 行。
func camera_lift(view_height: float) -> float:
	return (PLAYER_ROW - 0.5) * view_height

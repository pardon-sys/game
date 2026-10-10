class_name IsoTheme
extends Resource
## 等距主题（可复用；IsoTerrain 用）：一套地面 / 墙 / 门 / 活墙的外观。由 tools/art/gen_iso_theme.py 画图并写出 assets/iso_themes/<名>.tres。
##   floor：32x16 菱形图块，列 = j*floor_period + i（格子坐标对 floor_period 取余），行 = 视角 k（四个视角各一套，转了也没有接缝）
##   decals：64x32 地面装饰，行 = 第几种，列 = 视角 k
##   walls：32x(16+wall_height) 方块墙，wall_variants 种并排；gate：栅栏门块（0 铁、1 紫）；living：活墙 3 帧（起伏 2 帧 + 预警）
##   living_crack：活墙沉下后的裂纹（32x16 菱形，2 帧：平常 / 预警）
##   *_normal：对应的法线贴图（x 右、y 下、z 朝外）

const DIR := "res://assets/iso_themes/"

@export var theme_name := ""
@export var floor: Texture2D
@export var floor_normal: Texture2D
@export var decals: Texture2D
@export var walls: Texture2D
@export var walls_normal: Texture2D
@export var gate: Texture2D
@export var gate_normal: Texture2D
@export var living: Texture2D
@export var living_normal: Texture2D
@export var living_crack: Texture2D
@export var floor_period := 4
@export var decal_count := 4
@export var wall_variants := 4
## 墙的正面高度（像素；方块图高 = 16 + wall_height）
@export var wall_height := 24
## 挡住主角的前景墙淡到多少
@export var fade_alpha := 0.35
## 光在地上是椭圆：纵向压多少
@export var light_squash := 0.5


static func named(theme: String) -> IsoTheme:
	var path := DIR + (theme if theme != "" else "blue_stone") + ".tres"
	if not ResourceLoader.exists(path):
		path = DIR + "blue_stone.tres"
	return load(path) as IsoTheme


## 节点所在关卡的主题（往上找有 iso_theme 属性的关卡根；子节点 _ready 时 IsoView 可能还没挂上，用这个）。
static func for_node(n: Node) -> IsoTheme:
	var c := n
	while c:
		var t = c.get("iso_theme")
		if t != null:
			return named(str(t))
		c = c.get_parent()
	return named("")


## 把 sprite 打扮成一个方块（墙 / 门 / 活墙同一套画法）：region 取第 frame 块，方块底座的中心在 sprite 的位置上。
## 方块要画在格子中心：根节点不在格子中心时（门的根在格子底边），再用 IsoView.anchor(sprite, 逻辑偏移) 挪过去。
func dress_cube(sprite: Sprite2D, tex: Texture2D, normal: Texture2D, frame := 0) -> void:
	var size := cube_size()
	sprite.texture = lit(tex, normal)
	sprite.hframes = 1
	sprite.vframes = 1
	sprite.region_enabled = true
	sprite.region_rect = Rect2(frame * size.x, 0, size.x, size.y)
	sprite.centered = false
	sprite.offset = -Vector2(16, 8 + wall_height)
	sprite.scale = Vector2.ONE


## 带法线的贴图（2D 光照用）。
static func lit(diffuse: Texture2D, normal: Texture2D) -> Texture2D:
	if normal == null:
		return diffuse
	var ct := CanvasTexture.new()
	ct.diffuse_texture = diffuse
	ct.normal_texture = normal
	ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return ct


func cube_size() -> Vector2i:
	return Vector2i(32, 16 + wall_height)

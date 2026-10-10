class_name LitSprite
extends RefCounted
## 2.5D 楼层（[level] style = 2.5d）里人物 / 怪物的光照（可复用）：给 Sprite2D 换上 shaders/lit_sprite.gdshader 的材质
## （实时算法线 + 高光，保留受击闪色），这样 2D 灯光照在身上有受光面、背光面和高光反光。贴图换成别的图集也照常生效。
##   LitSprite.apply(节点)        给这个节点和它下面的所有 Sprite2D 套上（已经套过的跳过）
## 2.5D 楼层的关卡（scripts/level.gd）进场时对所有角色调 apply_actors，之后新进来的角色在 node_added 里再套。

const SHADER := preload("res://shaders/lit_sprite.gdshader")
## 透视倾斜时人物纵向拉回来的倍数（PerspectiveView 挂上时设置；1 = 不拉）
static var upright := 1.0


static func apply(root: Node) -> void:
	for s in [root] + root.find_children("*", "Sprite2D", true, false):
		var sp := s as Sprite2D
		if sp == null or sp.has_meta("lit"):
			continue
		var old := sp.material as ShaderMaterial
		# 只换默认材质和受击闪色材质（别的特效材质不动）
		if sp.material != null and not (old and old.shader and old.shader.resource_path.ends_with("flash.gdshader")):
			continue
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		if old:
			mat.set_shader_parameter("flash", old.get_shader_parameter("flash"))
			mat.set_shader_parameter("flash_color", old.get_shader_parameter("flash_color"))
		mat.set_shader_parameter("upright", upright)
		mat.set_shader_parameter("feet_y", sp.get_rect().end.y)
		sp.material = mat
		sp.set_meta("lit", true)


static func apply_actors(level: Node) -> void:
	for n in level.find_children("*", "", true, false):
		if n is Actor:
			apply(n)

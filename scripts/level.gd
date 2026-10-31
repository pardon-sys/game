extends Node2D
## 楼层根节点：载入本层对话、设置相机边界、播放开场对话。

## 楼层 id（levels/<floor_id>/），由构建器写入。
@export var floor_id := ""
@export var intro_dialogue := "intro"
## 开场过场动画（data/cutscenes/<楼层组>/<id>.json）；写了就代替开场对话。
@export var intro_cutscene := ""
## 夜晚的环境光（a = 0 表示这张地图没有昼夜之分）；剧情标记 night 打开时换上，关掉时换回白天的。
@export var night_ambient := Color(0, 0, 0, 0)
## 这一关不能切换操控的角色（[level] 段 no_switch = true；第八层的小房间）
@export var no_switch := false
## 同行的人（[level] 段 party = 人物 id,…）：除了跟着走的同行者，这些可操作角色也能在背包状态页看、能换过去（见 scripts/core/party.gd）
@export var party := PackedStringArray()
## 画面风格（[level] 段 style）：""（默认）/ "2.5d"（法线贴图图块 + 人物实时光照 + 跟着角色的冷光 + 透视倾斜）/
##   "iso"（同样的光照，画面换成等距 45° + 方块墙 + Z / X 转镜头：scripts/iso/ 的 IsoView + IsoTerrain；第八层的夜迷宫）
@export var style := ""
## 等距楼层的外观主题（assets/iso_themes/<名>.tres）和能不能转镜头
@export var iso_theme := ""
@export var iso_rotate := true
## 2.5D 楼层：冷光从满到空的秒数（0 = 不消耗）
@export var light_drain := 0.0

var _day_ambient := Color.WHITE

@onready var walls: TileMapLayer = $Walls


func _enter_tree() -> void:
	# 子节点 _ready 之前就要知道：门、活墙之类在等距楼层换等距贴图
	IsoView.enabled = style == "iso"


func _ready() -> void:
	if GameState.has_flag("blue_is_hero"):
		_swap_hero()
	Dialogue.load_floor(floor_id)
	if floor_id != "":
		Audio.play_music(Audio.music_for_floor(floor_id))
	var dark := get_node_or_null("Darkness") as CanvasModulate
	if dark:
		_day_ambient = dark.color
	_apply_time_of_day()
	GameState.flag_changed.connect(_on_flag_changed)
	var player := get_tree().get_first_node_in_group("player") as PlayableCharacter
	# 从楼梯过来：站到同名的到达点上
	if player and GameState.pending_spawn != "":
		for sp in get_tree().get_nodes_in_group("spawn_point"):
			if str(sp.get("id")) == GameState.pending_spawn and is_ancestor_of(sp):
				player.global_position = (sp as Node2D).global_position
				GameState.set_checkpoint(player.global_position)
				break
		GameState.pending_spawn = ""
	if player:
		apply_camera_limits(player)
	if style == "2.5d" or style == "iso":
		_setup_25d()
	Dialogue.finished.connect(_on_dialogue_finished)
	if GameState.pending_load > 0:
		return  # 马上要读档换关卡：不播开场
	if intro_cutscene != "":
		var cflag := "intro_done_" + intro_cutscene
		if not GameState.has_flag(cflag):
			GameState.set_flag(cflag)
			await get_tree().create_timer(0.6).timeout
			Cutscene.play(intro_cutscene)
		return
	var flag := "intro_done_" + intro_dialogue
	if intro_dialogue != "" and not GameState.has_flag(flag):
		GameState.set_flag(flag)
		await get_tree().create_timer(0.8).timeout
		Dialogue.start(intro_dialogue)


## 相机边界 = 地图范围（关卡载入时；中途换了主角时也调它）。
func apply_camera_limits(player: PlayableCharacter) -> void:
	if player == null or player.camera == null:
		return
	var rect := walls.get_used_rect()
	var ts := walls.tile_set.tile_size
	var cam := player.camera
	# 透视倾斜：画面底部只看得到中间一段，镜头贴着地图边时主角会跑出画面——边界往外放宽一个画面
	if style == "iso":
		# 等距：画面由 IsoView 按投影后的位置放镜头，逻辑上的边界不适用
		cam.limit_left = -10000000
		cam.limit_top = -10000000
		cam.limit_right = 10000000
		cam.limit_bottom = 10000000
		cam.reset_smoothing()
		return
	var margin := Vector2.ZERO
	if style == "2.5d":
		margin = get_viewport().get_visible_rect().size / cam.zoom
	cam.limit_left = int(rect.position.x * ts.x - margin.x)
	cam.limit_top = int(rect.position.y * ts.y - margin.y)
	cam.limit_right = int(rect.end.x * ts.x + margin.x)
	cam.limit_bottom = int(rect.end.y * ts.y + margin.y)
	cam.reset_smoothing()


## 蓝色公主当主角（剧情标记 blue_is_hero）：把关卡里的粉色公主换成玩家操控的蓝色公主（同一个位置）。
## 关卡里本来就有的蓝色公主（小镇里溜达的那个）这时不出现（BluePrincess.hide_flags）。
func _swap_hero() -> void:
	for n in get_tree().get_nodes_in_group("player"):
		if n is Princess and n.character_id == "pink" and is_ancestor_of(n):
			var pink := n as Princess
			var blue: BluePrincess = load("res://scenes/actors/playable/blue_princess.tscn").instantiate()
			blue.hero = true
			blue.name = "BlueHero"
			pink.remove_from_group("player")
			pink.get_parent().add_child(blue)
			blue.global_position = pink.global_position
			pink.queue_free()
			return


func _on_flag_changed(f: String) -> void:
	if f == "night":
		_apply_time_of_day()


## 昼夜：有 night_ambient 的地图在剧情标记 night 时变暗。
func _apply_time_of_day() -> void:
	var dark := get_node_or_null("Darkness") as CanvasModulate
	if dark == null or night_ambient.a <= 0.0:
		return
	var target := night_ambient if GameState.has_flag("night") else _day_ambient
	if is_inside_tree() and dark.color != target:
		create_tween().tween_property(dark, "color", target, 1.2)
	else:
		dark.color = target


func _on_dialogue_finished(id: String) -> void:
	match id:
		"ending":
			GameState.set_flag("chapter1_clear")
		"ending_2":
			GameState.set_flag("chapter2_clear")
		"ending_3":
			GameState.set_flag("chapter3_clear")
		"ending_4":
			GameState.set_flag("chapter4_clear")
			GameState.emote("happy", 3.0)
			GameState.notify("第四章通关！楼梯继续往下……")
		"ending_5":
			GameState.set_flag("chapter5_clear")


# ------------------------------------------------------------------ 2.5D 楼层
func _setup_25d() -> void:
	if style == "iso":
		# 等距：显示层 + 地形（人物不用纵向补偿）
		var view := IsoView.attach(self, iso_rotate)
		IsoTerrain.attach(view, IsoTheme.named(iso_theme))
		LitSprite.upright = 1.0
	else:
		# 透视倾斜：先算好人物的纵向补偿，再给人物套光照材质
		var pv := PerspectiveView.attach(self)
		LitSprite.upright = pv.upright_factor()
	LitSprite.apply_actors(self)
	get_tree().node_added.connect(_on_node_added_25d)
	_attach_carry_light(GameState.player)
	GameState.player_registered.connect(_attach_carry_light)


func _on_node_added_25d(n: Node) -> void:
	if n is Actor and is_ancestor_of(n):
		LitSprite.apply.call_deferred(n)


## 冷光跟着当前操控的角色（换人时移过去，冷光值一起带过去）。
func _attach_carry_light(p: Node) -> void:
	if not (p is Node2D) or not is_ancestor_of(p):
		return
	var keep := 1.0
	for l in find_children("CarryLight", "", true, false):
		if l.get_parent() != p:
			keep = (l as CarryLight).level
			l.queue_free()
	var cl := CarryLight.attach(p as Node2D, light_drain)
	cl.level = keep if cl.level >= 1.0 else cl.level
	_lift_camera(p)


## 透视倾斜时镜头往上抬：主角显示在画面中下方（PerspectiveView.camera_lift）。
const CAMERA_BASE := Vector2(0, -12)


func _lift_camera(p: Node) -> void:
	var pv := PerspectiveView.of(self)
	var cam: Camera2D = p.get("camera") if p else null
	if pv == null or cam == null:
		return
	cam.position = CAMERA_BASE - Vector2(0, pv.camera_lift(get_viewport().get_visible_rect().size.y / cam.zoom.y))
	cam.reset_smoothing()


func _exit_tree() -> void:
	if style == "2.5d" or style == "iso":
		LitSprite.upright = 1.0
	if style == "iso":
		IsoView.enabled = false


func carry_light() -> CarryLight:
	var p := GameState.player
	return p.get_node_or_null("CarryLight") as CarryLight if is_instance_valid(p) else null

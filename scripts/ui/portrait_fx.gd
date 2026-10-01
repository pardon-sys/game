class_name PortraitFx
extends Control
## 常驻立绘（左下角）的被挠反馈，挂在 Dialogue 下（Dialogue.portrait_fx）：
##   抖动        Dialogue.shake_portrait，幅度按闷笑阶段：平静 1、憋笑 2、失控 1 3、失控 2 4 像素；暴击再 +2
##   来源贴片    按挠痒来源（HitFx.kind_of）在立绘的脚心 / 腰侧 / 腋下 / 脖子随机位置播放命中特效（放大 2 倍）
##   粉色闪光    被挠瞬间立绘泛粉；立绘下面的粉色光晕随闷笑比例变浓（0% 不显示，100% 时 0.55）
##   「哈哈」飘字 失控后被挠时旁边冒出「哈哈」「嘻嘻」小字往上飘
##   暴击爆闪    暴击时金色星环（放大 3 倍）+ 白闪；组合技触发时爆开粉色心形（三来源更多）
## 笑倒 CG 播放中、立绘被 CG 接管（横版大框）时不处理。

const ANCHORS := [Vector2(0.36, 0.93), Vector2(0.62, 0.93), Vector2(0.3, 0.56), Vector2(0.7, 0.56),
	Vector2(0.27, 0.42), Vector2(0.73, 0.42), Vector2(0.5, 0.3)]
const HAHA := ["哈哈", "哈哈哈", "嘻嘻", "哈哈~", "~"]
const SHAKE_BY_STAGE := {"calm": 1.0, "giggle": 2.0, "helpless_1": 3.0, "helpless_2": 4.0}
const MAX_STICKERS := 3
const STICKER_GAP := 0.15
const GLOW_MAX := 0.55

var portrait: TextureRect
var glow: TextureRect
var _stickers: Array[Node] = []
var _since_sticker := INF
var _since_haha := INF
var _glow_target := 0.0
var _flash_tween: Tween


func setup(p: TextureRect) -> void:
	portrait = p
	name = "PortraitFx"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	glow = TextureRect.new()
	glow.name = "PortraitGlow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.45, 0.7, 1.0))
	grad.set_color(1, Color(1.0, 0.45, 0.7, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.75)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	glow.texture = tex
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.modulate.a = 0.0
	var host := portrait.get_parent()
	host.add_child(glow)
	host.move_child(glow, portrait.get_index())  # 画在立绘下面


func active() -> bool:
	return portrait != null and portrait.visible and not GameState.in_cutscene and not Dialogue.is_portrait_wide()


## 被挠痒：抖动、闪光、来源贴片、飘字、暴击爆闪。
func on_tickled(hit: HitData, laugh: LaughMeter) -> void:
	if not active():
		return
	var stage := laugh.stage() if laugh else "calm"
	var strength := float(SHAKE_BY_STAGE.get(stage, 1.0)) + (2.0 if hit.special else 0.0)
	Dialogue.shake_portrait(strength, 0.24 if hit.special else 0.18)
	_flash(Color(2.0, 2.0, 2.0) if hit.special else Color(1.35, 0.85, 1.1), 0.08 if hit.special else 0.12)
	var kind := HitFx.kind_of(hit.source)
	if kind != "" and _since_sticker >= STICKER_GAP:
		_since_sticker = 0.0
		_sticker(kind, _anchor_point(), 2.0)
	if hit.special:
		_sticker("crit", portrait_rect().get_center(), 3.0)
	if stage.begins_with("helpless"):
		var gap := 0.22 if stage == "helpless_2" else 0.35
		if _since_haha >= gap:
			_since_haha = 0.0
			_haha(stage == "helpless_2")


## 组合技：立绘周围爆开粉色心形。
func on_combo(triple: bool) -> void:
	if not active():
		return
	var r := portrait_rect()
	Fx.burst(self, r.get_center() + Vector2(0, -10), "heart", 18 if triple else 10, 70.0 if triple else 50.0, 0.8,
			Vector2(0, -30), Color(1, 0.75, 0.88))
	_flash(Color(1.5, 0.9, 1.25), 0.2)


func clear() -> void:
	for s in _stickers:
		if is_instance_valid(s):
			s.queue_free()
	_stickers.clear()
	for c in get_children():
		c.queue_free()
	_glow_target = 0.0
	if glow:
		glow.modulate.a = 0.0
	if portrait:
		portrait.self_modulate = Color.WHITE


func sticker_count() -> int:
	_stickers = _stickers.filter(func(s): return is_instance_valid(s))
	return _stickers.size()


func portrait_rect() -> Rect2:
	return Rect2(portrait.position, portrait.size)


func _process(delta: float) -> void:
	_since_sticker += delta
	_since_haha += delta
	if portrait == null:
		return
	var p := GameState.player
	_glow_target = 0.0
	if active() and is_instance_valid(p) and p.laugh and p.is_alive():
		_glow_target = clampf(p.laugh.ratio(), 0.0, 1.0) * GLOW_MAX
	glow.modulate.a = move_toward(glow.modulate.a, _glow_target, delta * 0.8)
	glow.visible = glow.modulate.a > 0.01
	var r := portrait_rect()
	glow.position = r.position + Vector2(-8, r.size.y * 0.25)
	glow.size = Vector2(r.size.x + 16, r.size.y * 0.8)


func _anchor_point() -> Vector2:
	var r := portrait_rect()
	var a: Vector2 = ANCHORS.pick_random()
	return r.position + r.size * a + Vector2(randf_range(-4, 4), randf_range(-4, 4))


func _sticker(kind: String, pos: Vector2, scale_k: float) -> void:
	if sticker_count() >= MAX_STICKERS and kind != "crit":
		return
	var s := HitFx.play(kind, self, pos)
	if s:
		s.scale = Vector2.ONE * scale_k
		s.z_index = 2
		_stickers.append(s)


func _flash(col: Color, time: float) -> void:
	if _flash_tween:
		_flash_tween.kill()
	portrait.self_modulate = col
	_flash_tween = create_tween()
	_flash_tween.tween_property(portrait, "self_modulate", Color.WHITE, time)


func _haha(big: bool) -> void:
	var l := Label.new()
	l.text = HAHA.pick_random()
	l.add_theme_color_override("font_color", Color(1, 0.6, 0.8))
	l.add_theme_color_override("font_outline_color", Color(0.35, 0.06, 0.22))
	l.add_theme_constant_override("outline_size", 4)
	if big:
		l.add_theme_font_size_override("font_size", 16)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := portrait_rect()
	l.position = Vector2(r.position.x + randf_range(r.size.x * 0.45, r.size.x * 0.95), r.position.y + randf_range(r.size.y * 0.15, r.size.y * 0.55))
	l.rotation = randf_range(-0.2, 0.2)
	add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 22.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:x", l.position.x + randf_range(-6, 6), 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


## 正在飘的「哈哈」数量（测试用）。
func haha_count() -> int:
	return get_children().filter(func(c): return c is Label).size()

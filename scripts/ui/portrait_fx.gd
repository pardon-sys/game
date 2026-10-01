class_name PortraitFx
extends Control
## 立绘（左下角常驻立绘 / CG 里的立绘和横版 CG 图）的被挠反馈，挂在 Dialogue 下（Dialogue.portrait_fx）：
##   抖动        Dialogue.shake_portrait，幅度按阶段：平静 1、憋笑 2、失控 1 3、失控 2 4 像素；暴击 / 高潮再加
##   来源贴片    按挠痒来源的命中特效（hit_fx）在立绘的脚心 / 腰侧 / 腋下 / 脖子随机位置播放（放大 2 倍）
##   粉色闪光    被挠瞬间立绘泛粉；立绘下面的粉色光晕随闷笑比例（CG 里按幕）变浓
##   飘字        失控后被挠时旁边冒出小字往上飘：文字在 data/princess_reactions.json 的 portrait_words
##               （全局默认，各来源可以单独配置，ReactionDB.portrait_words）
##   暴击爆闪    暴击时金色星环（放大 3 倍）+ 白闪；组合技触发时爆开粉色心形（三来源更多）
## 游戏中：Dialogue 把公主的 tickled / 组合技转给 on_tickled / on_combo（笑倒 CG 播放中不处理）。
## CG 中：CGPlayer 调 begin_cg / set_cg_level / cg_tickle / cg_crit / on_combo / end_cg。强度按幕递进（cg_level 1–4），
##   横版 CG 图上用轻量版：抖动、泛粉、沿大框两边飘字、大框底部光晕，不放来源贴片（不挡画面）。

const ANCHORS := [Vector2(0.36, 0.93), Vector2(0.62, 0.93), Vector2(0.3, 0.56), Vector2(0.7, 0.56),
	Vector2(0.27, 0.42), Vector2(0.73, 0.42), Vector2(0.5, 0.3)]
## data 里一个字都没配置时的兜底。
const HAHA := ["哈哈", "哈哈哈", "嘻嘻", "哈哈~", "~"]
const SHAKE_BY_STAGE := {"calm": 1.0, "giggle": 2.0, "helpless_1": 3.0, "helpless_2": 4.0}
## CG 每一级强度的光晕透明度（0 级 = 没开始）。
const CG_GLOW := [0.0, 0.25, 0.4, 0.55, 0.6]
const MAX_STICKERS := 3
const STICKER_GAP := 0.15
const GLOW_MAX := 0.55
## 横版 CG 图上光晕的透明度系数（大图不透明，光晕盖在图上要淡一些）。
const WIDE_GLOW_K := 0.4
## 两次泛粉闪光的最短间隔（连续挠的时候不要一直泛粉）。
const FLASH_GAP := 0.3
## CG 里挠得很密，飘字间隔放大这么多倍。
const CG_HAHA_K := 1.8

var portrait: TextureRect
## 立绘下面的光晕（普通立绘）。
var glow: TextureRect
## 盖在横版 CG 图底部的光晕（横版图不透明，光晕要画在图上面）。
var glow_top: TextureRect
## CG 模式：由 CGPlayer 控制强度，横版图也处理。
var cg_mode := false
var cg_level := 0
var _stickers: Array[Node] = []
var _since_sticker := INF
var _since_haha := INF
var _since_flash := INF
var _glow_target := 0.0
var _flash_tween: Tween


func setup(p: TextureRect) -> void:
	portrait = p
	name = "PortraitFx"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	glow = _glow_rect("PortraitGlow", Vector2(0.5, 0.75), Vector2(0.5, 0.0))
	var host := portrait.get_parent()
	host.add_child(glow)
	host.move_child(glow, portrait.get_index())  # 画在立绘下面
	glow_top = _glow_rect("PortraitGlowTop", Vector2(0.5, 1.0), Vector2(0.5, 0.0))
	add_child(glow_top)


func _glow_rect(n: String, from: Vector2, to: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.name = n
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.45, 0.7, 1.0))
	grad.set_color(1, Color(1.0, 0.45, 0.7, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = from
	tex.fill_to = to
	tex.width = 64
	tex.height = 64
	r.texture = tex
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.modulate.a = 0.0
	return r


## 是否处理（游戏中：不在 CG、不是横版大框；CG 模式：立绘可见就处理）。
func active() -> bool:
	if portrait == null or not portrait.visible:
		return false
	if cg_mode:
		return true
	return not GameState.in_cutscene and not Dialogue.is_portrait_wide()


func is_wide() -> bool:
	return Dialogue.is_portrait_wide()


# ------------------------------------------------------------------ 游戏中
## 被挠痒：抖动、闪光、来源贴片、飘字、暴击爆闪。
func on_tickled(hit: HitData, laugh: LaughMeter) -> void:
	if cg_mode or not active():
		return
	var stage := laugh.stage() if laugh else "calm"
	_tickle_core(ReactionDB.key_of(hit.source), HitFx.kind_of(hit.source), stage, hit.special, 0.0)


## 组合技（以及 CG 里组合演出的高潮）：立绘周围爆开粉色心形。
func on_combo(triple: bool) -> void:
	if not active():
		return
	var r := portrait_rect()
	var at := r.get_center() + Vector2(0, -10) if not is_wide() else Vector2(r.get_center().x, r.end.y - 20)
	Fx.burst(self, at, "heart", 18 if triple else 10, 70.0 if triple else 50.0, 0.8, Vector2(0, -30), Color(1, 0.75, 0.88))
	_flash(Color(1.5, 0.9, 1.25), 0.2)


# ------------------------------------------------------------------ CG 中
func begin_cg() -> void:
	clear()
	cg_mode = true
	cg_level = 0


func end_cg() -> void:
	cg_mode = false
	cg_level = 0
	clear()


## CG 强度（按幕递进）：1 = 失控 1，2 = 失控 2，3 / 4 = 第三 / 四幕或组合演出高潮。
func set_cg_level(level: int) -> void:
	cg_level = clampi(level, 0, CG_GLOW.size() - 1)


func cg_stage() -> String:
	return "helpless_1" if cg_level <= 1 else "helpless_2"


## CG 的挠痒：key = 挠痒来源键（飘字用它的 portrait_words），kind = 命中特效种类（空 = 不放贴片）。
func cg_tickle(key: String, kind: String) -> void:
	if not cg_mode or not active():
		return
	_tickle_core(key, kind, cg_stage(), false, 1.0 if cg_level >= 3 else 0.0)


## 切幕：金色星环 + 白闪（横版图上星环放在大框右上角，不挡画面中心）。
func cg_crit() -> void:
	if not cg_mode or not active():
		return
	var r := portrait_rect()
	var at := r.get_center() if not is_wide() else r.position + Vector2(r.size.x - 26, 26)
	_sticker("crit", at, 3.0, true)
	_flash(Color(2.0, 2.0, 2.0), 0.1)
	Dialogue.shake_portrait(5.0, 0.3)


# ------------------------------------------------------------------ 共用
func _tickle_core(key: String, kind: String, stage: String, special: bool, extra_shake: float) -> void:
	var strength := float(SHAKE_BY_STAGE.get(stage, 1.0)) + (2.0 if special else 0.0) + extra_shake
	Dialogue.shake_portrait(strength, 0.24 if special else 0.18)
	if special:
		_flash(Color(2.0, 2.0, 2.0), 0.08)
	elif _since_flash >= FLASH_GAP:
		# 横版 CG 图只轻轻泛一下，不把整张画染粉
		_flash(Color(1.1, 0.96, 1.04) if is_wide() else Color(1.35, 0.85, 1.1), 0.1 if is_wide() else 0.12)
	if kind != "" and not is_wide() and _since_sticker >= STICKER_GAP:
		_since_sticker = 0.0
		_sticker(kind, _anchor_point(), 2.0)
	if special:
		_sticker("crit", portrait_rect().get_center(), 3.0, true)
	if stage.begins_with("helpless"):
		var gap := (0.22 if stage == "helpless_2" else 0.35) * (CG_HAHA_K if cg_mode else 1.0)
		if _since_haha >= gap:
			_since_haha = 0.0
			_haha(stage == "helpless_2", key, stage)


func clear() -> void:
	for s in _stickers:
		if is_instance_valid(s):
			s.queue_free()
	_stickers.clear()
	for c in get_children():
		if c != glow_top:
			c.queue_free()
	_glow_target = 0.0
	if glow:
		glow.modulate.a = 0.0
	if glow_top:
		glow_top.modulate.a = 0.0
	if portrait:
		portrait.self_modulate = Color.WHITE


## 来源贴片数量（不含暴击星环；测试用）。
func sticker_count() -> int:
	_stickers = _stickers.filter(func(s): return is_instance_valid(s))
	var crit_row := HitFx.KINDS.find("crit")
	return _stickers.filter(func(s): return (s as HitFx).frame_coords.y != crit_row).size()


## 暴击星环数量（测试用）。
func crit_count() -> int:
	_stickers = _stickers.filter(func(s): return is_instance_valid(s))
	return _stickers.size() - sticker_count()


func portrait_rect() -> Rect2:
	return Rect2(portrait.position, portrait.size)


func _process(delta: float) -> void:
	_since_sticker += delta
	_since_haha += delta
	_since_flash += delta
	if portrait == null:
		return
	_glow_target = 0.0
	if cg_mode:
		_glow_target = CG_GLOW[cg_level] if active() else 0.0
	else:
		var p := GameState.player
		if active() and is_instance_valid(p) and p.laugh and p.is_alive():
			_glow_target = clampf(p.laugh.ratio(), 0.0, 1.0) * GLOW_MAX
	var wide := is_wide()
	var shown := glow_top if wide else glow
	var hidden := glow if wide else glow_top
	shown.modulate.a = move_toward(shown.modulate.a, _glow_target * (WIDE_GLOW_K if wide else 1.0), delta * 0.8)
	hidden.modulate.a = move_toward(hidden.modulate.a, 0.0, delta * 2.0)
	glow.visible = glow.modulate.a > 0.01
	glow_top.visible = glow_top.modulate.a > 0.01
	var r := portrait_rect()
	glow.position = r.position + Vector2(-8, r.size.y * 0.25)
	glow.size = Vector2(r.size.x + 16, r.size.y * 0.8)
	glow_top.position = Vector2(r.position.x, r.end.y - r.size.y * 0.45)
	glow_top.size = Vector2(r.size.x, r.size.y * 0.45)


## 当前在显示的光晕透明度（测试用）。
func glow_alpha() -> float:
	return maxf(glow.modulate.a, glow_top.modulate.a)


func _anchor_point() -> Vector2:
	var r := portrait_rect()
	var a: Vector2 = ANCHORS.pick_random()
	return r.position + r.size * a + Vector2(randf_range(-4, 4), randf_range(-4, 4))


func _sticker(kind: String, pos: Vector2, scale_k: float, force := false) -> void:
	if not force and sticker_count() >= MAX_STICKERS:
		return
	var s := HitFx.play(kind, self, pos)
	if s:
		s.scale = Vector2.ONE * scale_k
		s.z_index = 2
		_stickers.append(s)


func _flash(col: Color, time: float) -> void:
	_since_flash = 0.0
	if _flash_tween:
		_flash_tween.kill()
	portrait.self_modulate = col
	_flash_tween = create_tween()
	_flash_tween.tween_property(portrait, "self_modulate", Color.WHITE, time)


func _haha(big: bool, key := "", stage := "helpless_1") -> void:
	var words := ReactionDB.portrait_words(key, stage)
	var l := Label.new()
	l.text = str(words.pick_random()) if not words.is_empty() else HAHA.pick_random()
	l.add_theme_color_override("font_color", Color(1, 0.6, 0.8))
	l.add_theme_color_override("font_outline_color", Color(0.35, 0.06, 0.22))
	l.add_theme_constant_override("outline_size", 4)
	if big:
		l.add_theme_font_size_override("font_size", 16)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := portrait_rect()
	add_child(l)
	var w := l.get_minimum_size().x
	if is_wide():
		# 横版 CG 图：沿大框左右两边飘（整段字留在框内），不挡画面中心
		var left := randf() < 0.5
		l.position = Vector2(r.position.x + randf_range(4, 14) if left else r.end.x - w - randf_range(6, 16),
				r.position.y + randf_range(r.size.y * 0.3, r.size.y * 0.85))
	else:
		l.position = Vector2(r.position.x + randf_range(r.size.x * 0.45, r.size.x * 0.95),
				r.position.y + randf_range(r.size.y * 0.15, r.size.y * 0.55))
	l.rotation = randf_range(-0.2, 0.2)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 22.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:x", l.position.x + randf_range(-6, 6), 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


## 正在飘的小字数量（测试用）。
func haha_count() -> int:
	return get_children().filter(func(c): return c is Label).size()


## 正在飘的小字（测试用）。
func haha_texts() -> Array:
	return get_children().filter(func(c): return c is Label).map(func(c): return (c as Label).text)

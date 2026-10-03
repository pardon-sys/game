class_name PortraitFx
extends Control
## 立绘（左下角常驻立绘 / CG 里的立绘和横版 CG 图）的被挠反馈，挂在 Dialogue 下（Dialogue.portrait_fx）：
##   抖动        Dialogue.shake_portrait，幅度按阶段：平静 1、憋笑 2、失控 1 3、失控 2 4 像素；暴击 / 高潮再加
##   来源贴片    按挠痒来源的命中特效（hit_fx）在立绘的脚心 / 腰侧 / 腋下 / 脖子随机位置播放（放大 2 倍）
##   部位特效    挠到某个部位时，在立绘那个部位的位置（部位表 anchor）播部位专属特效 ZoneFx（放大 2 倍，弱点再放大变亮）
##   粉色闪光    被挠瞬间立绘泛粉（连续挠时限频）
##   飘字        失控后被挠时旁边冒出小字往上飘：文字在 data/princess_reactions.json 的 portrait_words
##               （全局默认，各来源可以单独配置，ReactionDB.portrait_words）
##   暴击爆闪    暴击时金色星环（放大 3 倍）+ 白闪；组合技触发时爆开粉色心形（三来源更多）
##   粉色光晕    shaders/portrait_glow.gdshader：普通立绘沿人物轮廓向外发光，横版 CG 图在大框内侧四周晕光；
##               强度游戏中按闷笑（憋笑起亮、失控 2 最亮），CG 中按幕；失控时轻轻呼吸
## 游戏中：Dialogue 把公主的 tickled / 组合技转给 on_tickled / on_combo（笑倒 CG 播放中不处理）。
## CG 中：CGPlayer 调 begin_cg / set_cg_level / cg_tickle / cg_crit / on_combo / end_cg。强度按幕递进（cg_level 1–4），
##   横版 CG 图上用轻量版：抖动、轻泛粉、沿大框两边飘字；来源贴片放在图的四周（不挡画面中心）。

const ANCHORS := [Vector2(0.36, 0.93), Vector2(0.62, 0.93), Vector2(0.3, 0.56), Vector2(0.7, 0.56),
	Vector2(0.27, 0.42), Vector2(0.73, 0.42), Vector2(0.5, 0.3)]
## data 里一个字都没配置时的兜底。
const HAHA := ["哈哈", "哈哈哈", "嘻嘻", "哈哈~", "~"]
const SHAKE_BY_STAGE := {"calm": 1.0, "giggle": 2.0, "helpless_1": 3.0, "helpless_2": 4.0}
## CG 强度的最高级。
const CG_MAX_LEVEL := 4
const MAX_STICKERS := 3
const STICKER_GAP := 0.15
## 两次泛粉闪光的最短间隔（连续挠的时候不要一直泛粉）。
const FLASH_GAP := 0.3
## CG 里挠得很密，飘字间隔放大这么多倍。
const CG_HAHA_K := 1.8
const GLOW_SHADER := preload("res://shaders/portrait_glow.gdshader")
## CG 各级的光晕强度（下标 = cg_level）。
const CG_GLOW := [0.0, 0.35, 0.6, 0.85, 1.0]
## 失控时光晕的呼吸幅度。
const GLOW_PULSE := 0.3
## 横版 CG 图上的贴片离中心至少这么远（占宽 / 高的比例）。
const WIDE_STICKER_MARGIN := 0.3

var portrait: TextureRect
## CG 模式：由 CGPlayer 控制强度，横版图也处理。
var cg_mode := false
var cg_level := 0
var _stickers: Array[Node] = []
var _zone_stickers: Array[Node] = []
var _since_sticker := INF
var _since_haha := INF
var _since_flash := INF
var _flash_tween: Tween
var _glow: ShaderMaterial
## 当前光晕强度（平滑跟随目标值）。
var glow_strength := 0.0


func setup(p: TextureRect) -> void:
	portrait = p
	name = "PortraitFx"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow = ShaderMaterial.new()
	_glow.shader = GLOW_SHADER
	portrait.material = _glow


## 是否处理（游戏中：不在 CG、不是横版大框；CG 模式：立绘可见就处理）。
func active() -> bool:
	if portrait == null or not portrait.visible:
		return false
	if cg_mode:
		return true
	return (not GameState.in_cutscene or Cutscene.is_playing()) and not Dialogue.is_portrait_wide()


func is_wide() -> bool:
	return Dialogue.is_portrait_wide()


# ------------------------------------------------------------------ 游戏中
## 被挠痒：抖动、闪光、来源贴片、飘字、暴击爆闪。
func on_tickled(hit: HitData, laugh: LaughMeter) -> void:
	if cg_mode or not active():
		return
	var stage := laugh.stage() if laugh else "calm"
	_tickle_core(ReactionDB.key_of(hit.source), HitFx.kind_of(hit.source), stage, hit.special, 0.0, hit.zone, hit.weak)


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
	cg_level = clampi(level, 0, CG_MAX_LEVEL)


func cg_stage() -> String:
	return "helpless_1" if cg_level <= 1 else "helpless_2"


## CG 的挠痒：key = 挠痒来源键（飘字用它的 portrait_words），kind = 命中特效种类（空 = 不放贴片）。
func cg_tickle(key: String, kind: String, zone := "") -> void:
	if not cg_mode or not active():
		return
	_tickle_core(key, kind, cg_stage(), false, 1.0 if cg_level >= 3 else 0.0, zone, zone != "")


## 地图内过场里挠到某个部位（Cutscene 的 tickle zone=…）：立绘抖动 + 部位特效 + 部位飘字。
func cutscene_tickle(kind: String, zone: String) -> void:
	if cg_mode or not active():
		return
	var p := GameState.player as PlayableCharacter
	var stage := p.laugh.stage() if p and p.laugh else "giggle"
	_tickle_core("", kind, stage, false, 0.0, zone, true)


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
func _tickle_core(key: String, kind: String, stage: String, special: bool, extra_shake: float, zone := "", weak := false) -> void:
	var strength := float(SHAKE_BY_STAGE.get(stage, 1.0)) + (2.0 if special else 0.0) + extra_shake
	Dialogue.shake_portrait(strength, 0.24 if special else 0.18)
	if special:
		_flash(Color(2.0, 2.0, 2.0), 0.08)
	elif _since_flash >= FLASH_GAP:
		# 横版 CG 图只轻轻泛一下，不把整张画染粉
		_flash(Color(1.1, 0.96, 1.04) if is_wide() else Color(1.35, 0.85, 1.1), 0.1 if is_wide() else 0.12)
	if kind != "" and _since_sticker >= STICKER_GAP:
		_since_sticker = 0.0
		if is_wide():
			_sticker(kind, _wide_point(), 2.5)
		else:
			_sticker(kind, _anchor_point(zone), 2.0)
	if zone != "" and not is_wide():
		_zone_sticker(zone, weak)
	if special:
		_sticker("crit", portrait_rect().get_center(), 3.0, true)
	if stage.begins_with("helpless"):
		var gap := (0.22 if stage == "helpless_2" else 0.35) * (CG_HAHA_K if cg_mode else 1.0)
		if _since_haha >= gap:
			_since_haha = 0.0
			_haha(stage == "helpless_2", key, stage, zone)


func clear() -> void:
	for s in _stickers:
		if is_instance_valid(s):
			s.queue_free()
	_stickers.clear()
	_zone_stickers.clear()
	for c in get_children():
		c.queue_free()
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
	_update_glow(delta)


## 光晕目标强度：CG 中按幕；游戏中按闷笑（憋笑以下 0，憋笑起 0.25，到失控 2 时 1）。
func glow_target() -> float:
	if not active():
		return 0.0
	if cg_mode:
		return CG_GLOW[clampi(cg_level, 0, CG_MAX_LEVEL)]
	var p := GameState.player
	if not is_instance_valid(p) or p.laugh == null:
		return 0.0
	var lm: LaughMeter = p.laugh
	if lm.value <= lm.giggle_threshold:
		return 0.0
	var t := (lm.value - lm.giggle_threshold) / maxf(lm.helpless_stage2_threshold - lm.giggle_threshold, 0.001)
	return lerpf(0.25, 1.0, clampf(t, 0.0, 1.0))


## 是否在呼吸（失控 / CG 中）。
func glow_pulsing() -> bool:
	if cg_mode:
		return cg_level >= 1
	var p := GameState.player
	return is_instance_valid(p) and p.laugh != null and p.laugh.stage().begins_with("helpless")


func _update_glow(delta: float) -> void:
	glow_strength = move_toward(glow_strength, glow_target(), delta * 2.0)
	_glow.set_shader_parameter("strength", glow_strength)
	_glow.set_shader_parameter("pulse", GLOW_PULSE if glow_pulsing() else 0.0)
	_glow.set_shader_parameter("mode", 1 if is_wide() else 0)
	_glow.set_shader_parameter("region", glow_region(portrait.texture))


## 立绘在贴图里的 UV 范围（图集里的一格；普通贴图为整张）。
static func glow_region(tex: Texture2D) -> Vector4:
	if tex is AtlasTexture and (tex as AtlasTexture).atlas:
		var at := tex as AtlasTexture
		var size := at.atlas.get_size()
		var r := at.region
		return Vector4(r.position.x / size.x, r.position.y / size.y, r.end.x / size.x, r.end.y / size.y)
	return Vector4(0, 0, 1, 1)


## 光晕材质（测试用）。
func glow_material() -> ShaderMaterial:
	return _glow


## 立绘上的贴片位置：有部位时用部位的 anchor（princess_ticklish.json），否则随机一个锚点。
func _anchor_point(zone := "") -> Vector2:
	var r := portrait_rect()
	var za: Variant = TickleZones.anchor(zone) if zone != "" else null
	var a: Vector2 = za if za is Vector2 else ANCHORS.pick_random()
	return r.position + r.size * a + Vector2(randf_range(-4, 4), randf_range(-4, 4))


## 横版 CG 图上的贴片位置：图的四周一圈（离中心至少 WIDE_STICKER_MARGIN），不挡画面中心。
func _wide_point() -> Vector2:
	var r := portrait_rect()
	var n := Vector2(randf_range(-0.42, 0.42), randf_range(-0.4, 0.4))
	if absf(n.x) < WIDE_STICKER_MARGIN and absf(n.y) < WIDE_STICKER_MARGIN:
		if randf() < 0.5:
			n.x = signf(n.x if n.x != 0.0 else 1.0) * randf_range(WIDE_STICKER_MARGIN, 0.42)
		else:
			n.y = signf(n.y if n.y != 0.0 else 1.0) * randf_range(WIDE_STICKER_MARGIN, 0.4)
	return r.get_center() + r.size * n


## 正在播放的来源贴片位置（测试用）。
func sticker_positions() -> Array:
	var crit_row := HitFx.KINDS.find("crit")
	var out := []
	for s in _stickers:
		if is_instance_valid(s) and (s as HitFx).frame_coords.y != crit_row:
			out.append((s as HitFx).global_position)
	return out


func _sticker(kind: String, pos: Vector2, scale_k: float, force := false) -> void:
	if not force and sticker_count() >= MAX_STICKERS:
		return
	var s := HitFx.play(kind, self, pos)
	if s:
		s.scale = Vector2.ONE * scale_k
		s.z_index = 2
		_stickers.append(s)


## 部位专属特效贴在立绘的部位位置（同一时间最多 MAX_STICKERS 个）。
func _zone_sticker(zone: String, weak: bool) -> void:
	_zone_stickers = _zone_stickers.filter(func(s): return is_instance_valid(s))
	if _zone_stickers.size() >= MAX_STICKERS:
		return
	var s := ZoneFx.play(zone, self, _anchor_point(zone), 2.0, weak)
	if s:
		s.z_index = 3
		_zone_stickers.append(s)


## 正在播放的部位特效（测试用）。
func zone_stickers() -> Array:
	_zone_stickers = _zone_stickers.filter(func(s): return is_instance_valid(s))
	return _zone_stickers.duplicate()


func _flash(col: Color, time: float) -> void:
	_since_flash = 0.0
	if _flash_tween:
		_flash_tween.kill()
	portrait.self_modulate = col
	_flash_tween = create_tween()
	_flash_tween.tween_property(portrait, "self_modulate", Color.WHITE, time)


func _haha(big: bool, key := "", stage := "helpless_1", zone := "") -> void:
	var words := ReactionDB.portrait_words(key, stage, zone)
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

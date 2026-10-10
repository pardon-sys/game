class_name HoldLaugh
extends Node2D
## 憋笑键（可复用组件，节点名 "HoldLaugh"，挂在可操作角色下；按住 hold_laugh = 空格）：
##   按住时：笑声半径（LaughRadius）收起来——手和怪听不到她；闷笑涨幅 ×GAIN_MULT，少涨的部分记成「憋住的笑」；
##           走得慢（状态 holding_laugh：移动 ×0.7）；脸憋红，头上冒「嗯——」。
##   憋气条（breath，0~1）：满条约 HOLD_TIME 秒；身上每多一只手（HandCover）耗得快 HAND_DRAIN，已经在憋笑阶段耗得快一倍。
##           松开 REGEN_DELAY 秒后开始回，REGEN_TIME 秒回满。
##   自己松开：憋住的笑放出 RELEASE_SOFT，笑声圈小亮一下。
##   憋到底：「噗——」憋不住（蓝色公主憋不住的笑 blue_crack），放出 RELEASE_FAIL + FAIL_EXTRA，笑声圈爆到 FAIL_RADIUS，定住 FAIL_ROOT 秒。
##   对话、过场、小剧场、QTE、被抓住 / 束缚、笑到失控时不能憋（正在憋就算自己松开）。
## 信号：started、released(是否憋爆)。HUD：冷光条下面一条细细的憋气条（只在憋 / 回气时显示）。

signal started
signal released(burst: bool)

const GAIN_MULT := 0.5
const HOLD_TIME := 4.0
const HAND_DRAIN := 0.08
const REGEN_DELAY := 0.5
const REGEN_TIME := 3.0
const RELEASE_SOFT := 0.3
const RELEASE_FAIL := 0.7
const FAIL_EXTRA := 10.0
const FAIL_RADIUS := 240.0
const FAIL_ROOT := 1.0
const LINES := [
	"……噗——！哈、哈哈哈……憋、憋不住了……！",
	"……唔……噗哈……哈哈哈哈……！",
	"……不、不行……噗……哈哈哈……",
	"……噗嗤……哈哈……刚、刚才的不算……！",
]

var host: PlayableCharacter
var breath := 1.0
var held := 0.0
var holding := false
## 测试用：当成一直按着
var force_hold := false
var _since_release := 99.0
var _t := 0.0
var _hud: CanvasLayer
var _bar_bg: ColorRect
var _bar: ColorRect


static func of(c: Node) -> HoldLaugh:
	return c.get_node_or_null("HoldLaugh") as HoldLaugh if c else null


static func attach(c: PlayableCharacter) -> HoldLaugh:
	var h := of(c)
	if h:
		return h
	h = HoldLaugh.new()
	h.name = "HoldLaugh"
	c.add_child(h)
	return h


func _ready() -> void:
	host = get_parent() as PlayableCharacter
	z_index = 5
	if host and host.laugh:
		host.laugh.suppressed.connect(func(a: float): held += a)
	_hud = CanvasLayer.new()
	_hud.layer = 9
	add_child(_hud)
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.3, 0.2, 0.1, 0.6)
	_bar_bg.position = Vector2(8, 104)
	_bar_bg.size = Vector2(60, 3)
	_hud.add_child(_bar_bg)
	_bar = ColorRect.new()
	_bar.color = Color(1, 0.85, 0.35)
	_bar.size = Vector2(60, 3)
	_bar_bg.add_child(_bar)
	var lb := Label.new()
	lb.text = "憋气"
	lb.position = Vector2(63, -5)
	lb.add_theme_font_size_override("font_size", 8)
	lb.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_bar_bg.add_child(lb)


func _exit_tree() -> void:
	_set_holding(false)


func radius_node() -> LaughRadius:
	return host.get_node_or_null("LaughRadius") as LaughRadius if host else null


func can_hold() -> bool:
	if host == null or not host.is_alive() or GameState.in_dialogue or GameState.in_cutscene:
		return false
	if CG.is_busy() or Cutscene.is_playing() or KeySequenceQTE.is_running():
		return false
	if host.status and (host.status.is_grabbed() or host.status.is_rooted() or host.status.is_hobbled()):
		return false
	return host.laugh != null and not host.laugh.is_helpless() and breath > 0.0


func wants_hold() -> bool:
	return force_hold or Input.is_action_pressed("hold_laugh")


## 现在每秒耗多少憋气（0~1 / 秒）。
func drain_rate() -> float:
	var hands := HandCover.of(host).total() if HandCover.of(host) else 0
	var k := (1.0 + HAND_DRAIN * hands) * (2.0 if host.laugh and host.laugh.is_giggling() else 1.0)
	return k / HOLD_TIME


func _process(delta: float) -> void:
	_t += delta
	if host == null:
		return
	if holding:
		if not wants_hold() or not can_hold():
			_release(false)
		else:
			breath = maxf(0.0, breath - drain_rate() * delta)
			host.add_buff("holding_laugh", 0.3)
			if breath <= 0.0:
				_release(true)
	elif wants_hold() and can_hold() and _since_release > 0.15:
		_set_holding(true)
		started.emit()
	if not holding:
		_since_release += delta
		if _since_release >= REGEN_DELAY:
			breath = minf(1.0, breath + delta / REGEN_TIME)
	_update_view()


func _set_holding(on: bool) -> void:
	holding = on
	if host and host.laugh:
		host.laugh.gain_mult = GAIN_MULT if on else 1.0
	var r := radius_node()
	if r:
		r.muted = on
	if host:
		if on:
			host.add_buff("holding_laugh", 0.3)
		elif host.has_buff("holding_laugh"):
			host.remove_buff("holding_laugh")
		if host.sprite:
			host.sprite.self_modulate = Color(1, 0.86, 0.86) if on else Color.WHITE


## 松开（burst = 憋到底憋不住）。
func _release(burst: bool) -> void:
	_set_holding(false)
	_since_release = 0.0
	var out := held * (RELEASE_FAIL if burst else RELEASE_SOFT)
	held = 0.0
	var r := radius_node()
	if burst:
		out += FAIL_EXTRA
		if r:
			r.burst(FAIL_RADIUS, 2.0)
		if host.status:
			host.status.apply_root(FAIL_ROOT)
		host.shake(0.4)
		Audio.play_crack()
		GameState.princess_reacted.emit(LINES.pick_random(), 2.6)
	elif out > 0.5 and r:
		r.burst(LaughRadius.RADII[0] * 0.6, 1.0)
		Audio.play("puff", -12.0, 0.1, 1.3)
	if out > 0.0 and host.laugh:
		host.laugh.add(out)
	released.emit(burst)


func _update_view() -> void:
	var show := holding or breath < 1.0
	_hud.visible = show and not CG.is_busy()
	_bar.size.x = 60.0 * breath
	_bar.color = Color(1, 0.35, 0.3) if breath < 0.3 and int(_t * 8.0) % 2 == 0 else Color(1, 0.85, 0.35)
	queue_redraw()


func _draw() -> void:
	if not holding:
		return
	# 头上的「嗯——」：越憋越抖
	var shake := (1.0 - breath) * 1.5
	var p := Vector2(randf_range(-shake, shake), -34 + randf_range(-shake, shake) * 0.5)
	draw_string_outline(ThemeDB.fallback_font, p + Vector2(-10, 0), "嗯——", HORIZONTAL_ALIGNMENT_CENTER, 20, 8, 2,
		Color(0.25, 0.05, 0.1))
	draw_string(ThemeDB.fallback_font, p + Vector2(-10, 0), "嗯——", HORIZONTAL_ALIGNMENT_CENTER, 20, 8, Color(1, 0.75, 0.8))

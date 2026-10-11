class_name SpellAim
extends CanvasLayer
## 攻防战：玩家操控蓝色公主时的「瞄准施法」（SiegeDirector 创建；PlayableCharacter.magic_override 把 L 键转到这里）。
##   按 L 打开：地上出现准星（默认放在射程里怪最密的地方），蓝色公主站着不动；
##   方向键 / 鼠标移动准星，Q / R 换法术（冰锥雨 / 冰晶结界 / 清凉雪花 / 冰墙加固），L / E / 鼠标左键放出，Esc 取消。
##   准星外圈是法术范围，蓝色公主周围的虚线圈是射程；射程外 / 冷却中准星变红。

const MOVE_SPEED := 220.0

var director: Node
var caster: PlayableCharacter
var spell := "ice_rain"
var point := Vector2.ZERO
var active := false
var reticle: Reticle
var _label: Label
var _opened_t := 0


class Reticle extends Node2D:
	var aim: SpellAim

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if aim == null or not aim.active or aim.caster == null:
			return
		var ok := aim.can_cast()
		var col := Color(0.7, 0.92, 1.0) if ok else Color(1, 0.4, 0.45)
		var c := aim.caster.global_position - global_position
		draw_arc(c, SiegeSpells.RANGE, 0.0, TAU, 96, Color(0.7, 0.9, 1.0, 0.25), 1.0)
		var p := aim.point - global_position
		var r := SiegeSpells.radius(aim.spell) if aim.spell != "reinforce" else 20.0
		draw_circle(p, r, Color(col.r, col.g, col.b, 0.15))
		draw_arc(p, r, 0.0, TAU, 40, col, 1.5)
		draw_line(p + Vector2(-5, 0), p + Vector2(5, 0), col, 1.0)
		draw_line(p + Vector2(0, -5), p + Vector2(0, 5), col, 1.0)
		if aim.spell == "reinforce" and aim.director:
			var w: SiegeWall = aim.director.segment_at(aim.point.x)
			if w:
				draw_rect(Rect2(Vector2(w.left_x(), w.top_y()) - global_position, Vector2(w.width_px(), w.foot_y() - w.top_y())), Color(col.r, col.g, col.b, 0.25))


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_label = Label.new()
	_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.06, 0.1, 0.2))
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_font_size_override("font_size", 9)
	_label.position = Vector2(120, 232)
	_label.hide()
	add_child(_label)


func open(c: PlayableCharacter) -> void:
	if active:
		return
	caster = c
	active = true
	_opened_t = Engine.get_process_frames()
	if reticle == null or not is_instance_valid(reticle):
		reticle = Reticle.new()
		reticle.aim = self
		reticle.z_index = 40
		c.get_parent().add_child(reticle)
	var p: Variant = director.densest(30.0, c.global_position, SiegeSpells.RANGE) if director else null
	point = p if p is Vector2 else c.global_position + Vector2(0, 90)
	PlayerInputController.movement_locked = true
	PlayerInputController.actions_locked = true
	_label.show()
	_refresh_label()


func close() -> void:
	active = false
	PlayerInputController.movement_locked = false
	PlayerInputController.actions_locked = false
	_label.hide()


func can_cast() -> bool:
	return caster != null and SiegeSpells.ready(caster, spell) and (spell == "reinforce" or SiegeSpells.in_range(caster, point))


func cycle(dir: int) -> void:
	var i := SiegeSpells.ORDER.find(spell)
	spell = SiegeSpells.ORDER[posmod(i + dir, SiegeSpells.ORDER.size())]
	_refresh_label()


## 放出当前法术（成功就收起准星）。
func fire() -> bool:
	if caster == null:
		return false
	if not can_cast():
		Audio.play("locked", -8.0)
		return false
	var ok := SiegeSpells.cast(caster, spell, point)
	if ok:
		close()
	return ok


func _refresh_label() -> void:
	var cd := SiegeSpells.cooldown_left(caster, spell) if caster else 0.0
	_label.text = "【%s】%s　Q / R 换法术　L / E / 左键 放出　Esc 取消" % [SiegeSpells.spell_name(spell),
		("冷却 %.1f 秒" % cd) if cd > 0.0 else ("射程外" if spell != "reinforce" and caster and not SiegeSpells.in_range(caster, point) else "可以放")]


func _process(delta: float) -> void:
	if not active:
		return
	if caster == null or not is_instance_valid(caster) or GameState.player != caster or not caster.is_alive() or Downed.is_downed(caster):
		close()
		return
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	point += v * MOVE_SPEED * delta
	if director:
		var ms: Vector2 = director.map_size()
		point = point.clamp(Vector2.ZERO, ms)
	_refresh_label()


func _unhandled_input(event: InputEvent) -> void:
	if not active or Engine.get_process_frames() == _opened_t:
		return
	if event is InputEventMouseMotion and reticle:
		point = reticle.get_global_mouse_position()
		return
	if not event.is_pressed() or event.is_echo():
		return
	var handled := true
	if event.is_action("pause") or event.is_action("ui_cancel"):
		close()
	elif event.is_action("use_item"):
		cycle(-1)
	elif event.is_action("use_special"):
		cycle(1)
	elif event.is_action("magic") or event.is_action("interact") or (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		if event is InputEventMouseButton and reticle:
			point = reticle.get_global_mouse_position()
		fire()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()

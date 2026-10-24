class_name BonfireHost
extends Princess
## 派对主人：沿用 Princess 的移动、表情、闷笑与施法；默认在原位置闲逛，F2 可调试操控。
## 专属数据由 gen_bonfire_host_character.py 生成到 data/characters/bonfire_host/。
## 普攻为双枚彩带回旋；魔法为敌我均受影响的跟随光环。没有独立存档变量。

const RIBBON_INTERVAL := 0.6
const MAX_RIBBONS := 2
@export var dialogue := "floor_06/bonfire_host"
@export var show_flag := ""
@export var hide_flags: Array[String] = []
@export var ai := true
@export var wander := 1.0
@export var dir := "down"
var talking := false
var _ribbon_wait := 0.0
var _ribbons: Array[WeakRef] = []
var _festival: WeakRef
var _host_home := Vector2.ZERO


func _setup() -> void:
	character_id = "bonfire_host"
	portrait_set = "bonfire_host"
	_host_home = global_position
	facing = Trap.dir_vector(dir)
	set_controller(WanderController.new() if ai else ScriptedController.new())
	super()
	# 普攻不扫描近战 Hitbox；保留节点的 hit_landed 信号供原 ComboTracker 使用。
	hitbox = null
	if camera:
		camera.enabled = false
	var it := get_node_or_null("Talk") as Interactable
	if it:
		it.interacted.connect(talk)
	if controller is WanderController:
		controller.configure_area(_host_home, ceili(wander))
	GameState.flag_changed.connect(func(_flag: String): _refresh_visibility())
	_refresh_visibility()


func display_name() -> String:
	return str(Dialogue.npcs.get("bonfire_host", {}).get("name", ""))


func make_ai_controller() -> CharacterController:
	# 她不自动加入两位公主的双人队伍，切回 NPC 后仍在原活动区。
	if not ai:
		return ScriptedController.new()
	var wc := WanderController.new()
	wc.configure_area(_host_home, ceili(wander))
	return wc


func _tick(delta: float) -> void:
	if not GameState.in_dialogue and not GameState.in_cutscene and not CG.is_busy():
		_ribbon_wait = maxf(0.0, _ribbon_wait-delta)
	super(delta)


func attack() -> void:
	_ribbons = _ribbons.filter(func(w): return is_instance_valid(w.get_ref()))
	if not can_act() or _ribbon_wait > 0.0 or _ribbons.size() >= MAX_RIBBONS:
		return
	_ribbon_wait = RIBBON_INTERVAL
	_set_state(State.ATTACK)
	var ribbon := FestivalRibbon.launch(self, facing)
	_ribbons.append(weakref(ribbon))
	Audio.play("swing", -4.0)


func cast_magic(tier: int) -> void:
	var p := FestivalAura.params(tier)
	_open_festival(p["radius"], p["duration"])


func cast_fatigue_burst() -> void:
	_open_festival(FestivalAura.params(3)["radius"], 4.0)


func _open_festival(radius: float, duration: float) -> void:
	var aura: FestivalAura = _festival.get_ref() if _festival else null
	if is_instance_valid(aura):
		aura.refresh(radius, duration)
	else:
		_festival = weakref(FestivalAura.cast(self, radius, duration))


func fatigue_burst_visual() -> String:
	return "damaged_giggle_burst"

## 原镇民日程入口转交给既有 WanderController，不复制 Resident 的行走实现。


func place_schedule(info: Dictionary) -> void:
	show_flag = "after_never" if bool(info.get("hidden", false)) else ""
	if info.has("at"):
		global_position = Cutscene.cell_to_world(info["at"])
		_host_home = global_position
		velocity = Vector2.ZERO
	if info.has("dir"):
		facing = Trap.dir_vector(str(info["dir"]))
	if info.has("wander"):
		wander = float(info["wander"])
	if info.has("dialogue"):
		dialogue = "floor_06/" + str(info["dialogue"])
	if controller is WanderController:
		controller.configure_area(_host_home, ceili(wander))
	_refresh_visibility()


func _refresh_visibility() -> void:
	visible = (show_flag == "" or GameState.has_flag(show_flag)) and not hide_flags.any(func(f): return GameState.has_flag(f))
	process_mode = Node.PROCESS_MODE_INHERIT if visible else Node.PROCESS_MODE_DISABLED
	var it := get_node_or_null("Talk") as Interactable
	if it:
		it.enabled = visible and ai and dialogue != "" and not is_controlled()


func talk(player: Node) -> void:
	if talking or dialogue == "" or is_controlled() or Dialogue.runner.is_running():
		return
	talking = true
	var wc := controller as WanderController
	if wc:
		wc.paused = true
		wc.path.clear()
	if player is Node2D:
		facing = global_position.direction_to(player.global_position)
	await Dialogue.talk(dialogue)
	talking = false
	if is_instance_valid(wc):
		wc.paused = false
	_refresh_visibility()


func _exit_tree() -> void:
	for w in _ribbons:
		var r: Variant = w.get_ref()
		if is_instance_valid(r):
			r.queue_free()
	var aura: Variant = _festival.get_ref() if _festival else null
	if is_instance_valid(aura):
		aura.queue_free()

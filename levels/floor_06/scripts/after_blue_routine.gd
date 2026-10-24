class_name AfterBlueRoutine
extends Node
## 战后小镇自由活动日程：仅管理AfterBlue，不管理其他地图或任务演员。
## 存档：after_blue_follow_day=主动同行的日期；after_play_win_day=挑战获胜日期。
## 优先级：剧情／任务接管 > 第二天示众前离场 > 当日主动同行 > 时段闲逛。
## 测试：sync()、invite()、dismiss()；日程读DayClock的数据，不在脚本内写地点文案。

const PARTNER := "floor_06/after_partner"
const FOLLOW_DAY := "after_blue_follow_day"
const NEVER := "after_never"
static var current: AfterBlueRoutine
var blue: BluePrincess
var _state := ""
var _slot := ""


func _ready() -> void:
	current = self


func _exit_tree() -> void:
	if current == self: current = null


func _process(_delta: float) -> void:
	sync()


static func invited_today() -> bool:
	return AfterPlay.won_today() and int(GameState.vars.get(FOLLOW_DAY, 0)) == DayClock.day()


static func change_follow_later(on: bool) -> void:
	var owner := current
	await TrainingDB.wait_dialogue_free()
	if not is_instance_valid(owner) or current != owner: return
	if on: current.invite()
	else: current.dismiss()


func _task_active() -> bool:
	return GameState.has_flag(AfterStory.TASK_FLAG) or AfterErrands.active() != ""


func invite() -> bool:
	if not is_instance_valid(blue) or not AfterPlay.won_today() or _task_active() or AfterStory.running or AfterTown.blue_away(): return false
	GameState.vars[FOLLOW_DAY] = DayClock.day()
	sync(true)
	return true


func dismiss() -> void:
	GameState.vars[FOLLOW_DAY] = 0
	sync(true)


## 任务启动在静音搭档前调用，避免一帧延迟使新交互口漏出。
func force_task_follow() -> void:
	if is_instance_valid(blue) and not blue.is_controlled():
		blue.start_following(PARTNER)
		_state = "task"


func sync(force := false) -> void:
	if not is_instance_valid(blue) or blue.is_controlled(): return
	if GameState.has_flag("after_blue_can_follow") != AfterPlay.won_today(): GameState.set_flag("after_blue_can_follow", AfterPlay.won_today())
	if GameState.has_flag("after_blue_following") != invited_today(): GameState.set_flag("after_blue_following", invited_today())
	if GameState.in_cutscene or Cutscene.is_playing() or CG.is_busy(): return
	if not force and (GameState.in_dialogue or DayClock.passing or AfterPlay.running): return
	if not force and AfterStory.running and not _task_active(): return
	if _task_active():
		if _state != "task": force_task_follow()
		return
	var slot_key := "%d:%d" % [DayClock.day(), DayClock.slot()]
	if AfterTown.blue_away():
		if _state != "away":
			blue.ai = true
			blue.show_flag = NEVER
			blue._refresh_visibility()
			_state = "away"
		return
	var state := "follow:" + slot_key if invited_today() else "roam:" + slot_key
	if not force and state == _state: return
	blue.show_flag = ""
	blue.hide_flags.clear()
	blue._refresh_visibility()
	if invited_today():
		blue.start_following(PARTNER)
	else:
		var spec := DayClock.npc("after_blue")
		var home := Cutscene.cell_to_world(spec.get("at", [12, 14]))
		# 时段切换在时钟黑幕内换位，结束同行则沿路走回。
		if _slot != slot_key or _state == "away": blue.global_position = home
		blue.velocity = Vector2.ZERO
		blue.facing = Trap.dir_vector(str(spec.get("dir", "down")))
		blue.start_wandering(PARTNER, home, int(spec.get("wander", 2)))
	_slot = slot_key
	_state = state

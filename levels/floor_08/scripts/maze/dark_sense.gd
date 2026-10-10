class_name DarkSense
extends Node
## 黑暗里更怕痒（第八层夜迷宫；导演自带一个）：
##   冷光低于 DARK_LEVEL，或者被遮眼蝠蒙住眼（状态 blinded）→ 她看不清，猜不到下一下落在哪里：
##   状态 dark_sensitive（挠痒 ×1.2；蒙眼的 blinded 自己再 ×1.3），冷光圈缩小，屏幕四周更暗。
##   每段第一次进入：屏幕中间黄字 + 她念叨一句（maze_lines.json 的 dark）；整个迷宫第一次还有一段小剧场 f8_maze_dark_first。

signal entered

const DARK_LEVEL := 0.3
const HINT := "……看不清……身体变得更敏感了……"

var director: MazeDirector
var dark := false
var _fx: ScreenFx
var _told := false
var _mode := ""


func _process(_delta: float) -> void:
	if director == null or not is_instance_valid(director.blue):
		return
	var blue := director.blue
	var cl := director.carry_light()
	var blind := blue.has_buff("blinded")
	var now := blind or (cl != null and cl.level < DARK_LEVEL)
	if now and not (GameState.in_dialogue or CG.is_busy() or Cutscene.is_playing()):
		blue.add_buff("dark_sensitive", 0.5)
	var mode := "blind" if blind else ("dark" if now else "")
	if mode == _mode:
		return
	_mode = mode
	dark = now
	if cl:
		cl.squeeze = 0.45 if blind else (0.75 if now else 1.0)
	if is_instance_valid(_fx):
		_fx.fade_out(0.3)
		_fx = null
	if now:
		_fx = ScreenFx.vignette(Color(0.0, 0.0, 0.04), 0.95 if blind else 0.55, false)
		_enter()


func _enter() -> void:
	entered.emit()
	if _told:
		return
	_told = true
	GameState.hint(HINT)
	GameState.princess_reacted.emit(MazeLines.pick("dark"), 2.8)
	if not GameState.has_flag("f8m_dark_first"):
		GameState.set_flag("f8m_dark_first")
		CG.play_theater("f8_maze_dark_first")


func _exit_tree() -> void:
	if is_instance_valid(_fx):
		_fx.fade_out(0.2)

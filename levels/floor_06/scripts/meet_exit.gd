class_name MeetExit
extends Node2D
## 反省篇第三章·开场（floor_06_waterway_exit；地图 legend meetexit；台词 tools/build/penance_text/meet.py）：
##   进图依次放：过场 meet_in（蓝色公主提着鞋在出口等）→ 小剧场 meet_pants（互相调侃裤子：千手痒痒裤挠蓝色公主、挠脚鼠不甘示弱挠粉色公主）
##   → 过场 meet_out（章末「第三章　汇合」待续）。做过一次就记 DONE_FLAG，不再放。鼠鼠装一直穿着。
const DONE_FLAG := "meet_exit_done"
var running := false


func _ready() -> void:
	if not GameState.has_flag(DONE_FLAG):
		run.call_deferred()


func run() -> void:
	if running:
		return
	running = true
	await get_tree().create_timer(0.3).timeout
	await Cutscene.play("meet_in")
	while Cutscene.is_playing():
		await get_tree().process_frame
	await CG.play_theater("meet_pants")
	GameState.set_flag(DONE_FLAG)
	Cutscene.play("meet_out")

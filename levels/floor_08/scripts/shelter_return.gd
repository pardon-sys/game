class_name ShelterReturn
extends Node2D
## 第八层的小房间：蓝色公主走出夜迷宫之后（剧情标记 f8_maze_done）回到这里。
##   第一次（还没有 f8_returned）：放回小屋的过场 f8_shelter_return（迷宫里身上超过 8 只手过 → _pants 那一版：
##   她发现腿上缠着千手痒痒裤）。过场一开始粉色公主冰封着躺在床上、闭着眼，床尾一群小怪在挠她露出来的脚心。
##   之后：粉色公主操控（小房间本来就不能切换），蓝色公主跟着她（BluePrincess.start_following）；门（unlock_flag = f8_returned）
##   通往新的第七层 floor_07_return。
## 图例：X = f8shelter

signal returned

const FLAG := "f8_returned"


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if GameState.has_flag(FLAG):
		_after()
	elif GameState.has_flag("f8_maze_done"):
		await play()


static func cutscene_id() -> String:
	return "f8_shelter_return_pants" if GameState.has_flag("f8m_ms_total_8") else "f8_shelter_return"


func blue() -> BluePrincess:
	var lv := get_parent()
	while lv and not lv.has_node("Walls"):
		lv = lv.get_parent()
	if lv == null:
		return null
	for n in lv.find_children("*", "BluePrincess", true, false):
		if n != GameState.player:
			return n as BluePrincess
	return null


func play() -> void:
	await Cutscene.play(cutscene_id())
	GameState.set_flag(FLAG)
	_after()
	returned.emit()


func _after() -> void:
	var b := blue()
	if b:
		b.start_following()

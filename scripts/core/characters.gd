class_name Characters
extends RefCounted
## 可操作角色的数据档案：粉色公主（pink）用 data/ 下原来的文件；别的角色（蓝色公主 blue）的文件放在 data/characters/<角色>/，
## 同名文件存在就用它，没有就回退到粉色公主的。按「当前操控的角色」（GameState.player 的 character_id）选。
##   reactions.json（受挠台词，ReactionDB）、fatigue.json（疲倦爆发台词）、ticklish.json（部位表，TickleZones）、
##   cgs.json / nest_cgs.json / combo_scenes.json（笑倒 CG、巢穴 CG、组合演出，CG）
## 蓝色公主的这些文件由 tools/build/gen_blue_character.py 从粉色公主的数据转换生成。

const DIR := "res://data/characters/%s/"

## 两个可操作角色同场时（第八层），每个角色处理自己的受挠 / 反应时临时把「当前角色」换成自己（scope / unscope 成对用）。
static var _scope: Array[String] = []


static func scope(id: String) -> void:
	_scope.append(id)


static func unscope() -> void:
	if not _scope.is_empty():
		_scope.pop_back()


static func current() -> String:
	if not _scope.is_empty() and _scope[-1] != "":
		return _scope[-1]
	var p := GameState.player
	if is_instance_valid(p) and p.get("character_id") != null:
		return str(p.get("character_id"))
	return "pink"


## 某个角色的某个数据文件：角色文件夹里有就用它，否则用 default_path。
static func path(file: String, default_path: String, who := "") -> String:
	var c := who if who != "" else current()
	if c == "" or c == "pink":
		return default_path
	var p := DIR % c + file
	return p if FileAccess.file_exists(p) else default_path


static func load_json(file: String, default_path: String, who := "") -> Dictionary:
	var p := path(file, default_path, who)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null
	return parsed if parsed is Dictionary else {}

class_name AfterNight
extends RefCounted
## 七日赎罪晚上的弥补任务的台词：data/after/night.json（gen_floor06_after.py 从 after_text/night.py 生成）。
##   sweep 羽毛大扫除（TaskSweep）/ mice 逃跑的痒痒鼠（MouseShow）/ tag 挠痒捉人（TaskTag）/ lantern 笑声灯笼（LanternShow）。

const PATH := "res://data/after/night.json"

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = parsed if parsed is Dictionary else {}
	return _data


## 反应字（三档）
static func react(lr: float) -> String:
	var r: Dictionary = data().get("react", {})
	var pool: Array = r.get("light" if lr < 0.35 else ("mid" if lr < 0.7 else "heavy"), ["……"])
	return str(pool.pick_random())

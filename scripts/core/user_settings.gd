class_name UserSettings
extends RefCounted
## 玩家的显示设置（P 键菜单 SettingsMenu 改），存在玩家数据目录的 settings.cfg 的 [display] 段（和 Audio 的 [audio] 音量同一个文件：先读再改，不覆盖别的段）。
##   art_style：角色画风 "hd"（精细像素：粉色 / 蓝色公主、派对主人用 *_hd.png，codex 直接画的 64 格像素风，默认）/ "pixel"（原来的 32 格像素图）。
##     SpriteSheetAnimator 每帧比对 revision，变了就重新选贴图；缺 *_hd.png 时照旧用像素图。
##   show_portrait：显示常驻立绘（游戏中左下角的角色立绘；关掉后只在对话 / CG / 小剧场里出现）。
## 测试：set_value 之后 revision +1；reset_cache() 让下次重新读文件。

const SECTION := "display"
const DEFAULTS := {"art_style": "hd", "show_portrait": true}

## 每改一次 +1（SpriteSheetAnimator / Dialogue 比对它来刷新）
static var revision := 0
static var _cache := {}


static func path() -> String:
	return DevConfig.data_root() + "settings.cfg"


static func _load() -> void:
	if not _cache.is_empty():
		return
	var cfg := ConfigFile.new()
	var ok := cfg.load(path()) == OK
	for k in DEFAULTS:
		_cache[k] = cfg.get_value(SECTION, k, DEFAULTS[k]) if ok else DEFAULTS[k]


static func get_value(key: String) -> Variant:
	_load()
	return _cache.get(key, DEFAULTS.get(key))


static func set_value(key: String, value: Variant) -> void:
	_load()
	_cache[key] = value
	revision += 1
	var cfg := ConfigFile.new()
	cfg.load(path())
	cfg.set_value(SECTION, key, value)
	cfg.save(path())


static func hd() -> bool:
	return str(get_value("art_style")) == "hd"


static func show_portrait() -> bool:
	return bool(get_value("show_portrait"))


static func reset_cache() -> void:
	_cache.clear()
	revision += 1


## 精细像素图集的路径：xxx.png → xxx_hd.png（存在才返回，否则原路径）
static func styled_path(p: String) -> String:
	if not hd() or p == "" or p.ends_with("_hd.png"):
		return p
	var cand := p.get_basename() + "_hd." + p.get_extension()
	return cand if ResourceLoader.exists(cand) else p

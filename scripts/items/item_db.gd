class_name ItemDB
extends RefCounted
## 物品注册表：id -> 物品数据资源。新增物品在 PATHS 加一行即可。

const PATHS := {
	"heart": "res://data/items/heart.tres",
	"coin": "res://data/items/coin.tres",
	"key_bronze": "res://data/items/key_bronze.tres",
	"key_gold": "res://data/items/key_gold.tres",
	"mint": "res://data/items/mint.tres",
	"clear_dew": "res://data/items/clear_dew.tres",
	"star_candy": "res://data/items/star_candy.tres",
	"backpack": "res://data/items/backpack.tres",
	"mystery_key": "res://data/items/mystery_key.tres",
}

static var _cache := {}


static func get_item(id: String) -> ItemData:
	if not _cache.has(id):
		if not PATHS.has(id):
			push_error("未知物品 id: " + id)
			return null
		_cache[id] = load(PATHS[id])
	return _cache[id]


static func all_ids() -> Array:
	return PATHS.keys()

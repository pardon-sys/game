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
	"thousand_pants": "res://data/items/thousand_pants.tres",
	# 装备（tools/build/gen_equipment.py）
	"equip_armpit_pad": "res://data/items/equip_armpit_pad.tres",
	"equip_scarf": "res://data/items/equip_scarf.tres",
	"equip_wool_socks": "res://data/items/equip_wool_socks.tres",
	"equip_dance_shoes": "res://data/items/equip_dance_shoes.tres",
	"equip_waist_sash": "res://data/items/equip_waist_sash.tres",
	"equip_mint_sachet": "res://data/items/equip_mint_sachet.tres",
	"equip_chest_guard": "res://data/items/equip_chest_guard.tres",
	"equip_training_wraps": "res://data/items/equip_training_wraps.tres",
	"equip_padded_shorts": "res://data/items/equip_padded_shorts.tres",
	"equip_party_bow": "res://data/items/equip_party_bow.tres",
	"equip_feather_anklet": "res://data/items/equip_feather_anklet.tres",
	"equip_ice_hairpin": "res://data/items/equip_ice_hairpin.tres",
	"equip_t_feather_socks": "res://data/items/equip_t_feather_socks.tres",
	"equip_t_toe_brush": "res://data/items/equip_t_toe_brush.tres",
	"equip_t_fluff_bra": "res://data/items/equip_t_fluff_bra.tres",
	"equip_t_thigh_ring": "res://data/items/equip_t_thigh_ring.tres",
	"equip_t_pinch_pad": "res://data/items/equip_t_pinch_pad.tres",
	"equip_t_knead_tights": "res://data/items/equip_t_knead_tights.tres",
	"equip_t_feather_shackles": "res://data/items/equip_t_feather_shackles.tres",
	"equip_t_thigh_strap": "res://data/items/equip_t_thigh_strap.tres",
	"equip_t_bell_anklet": "res://data/items/equip_t_bell_anklet.tres",
	"equip_t_mark_patch": "res://data/items/equip_t_mark_patch.tres",
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

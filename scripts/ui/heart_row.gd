class_name HeartRow
extends RefCounted
## 心形血量的一排（可复用：HUD、双人模式的搭档面板）：最多 MAX_SLOTS 格，1 颗心 = 2 点生命。
## 超过 5 颗心时，第 6~10 颗不往右加格，而是在第 1~5 格上盖一层金色（满 / 半 / 只剩金色轮廓 = 这颗金心没血了）。
## 图：assets/generated/hud.png（红满、红半、红空、金满、金半、金空；tools/art/gen_misc.py 生成）。
##   HeartRow.update(容器, hp, max_hp, 图标大小)

const HUD_TEX := preload("res://assets/generated/hud.png")
const MAX_SLOTS := 5

static var _tex: Array[AtlasTexture] = []


static func tex(i: int) -> AtlasTexture:
	if _tex.is_empty():
		for k in 6:
			var at := AtlasTexture.new()
			at.atlas = HUD_TEX
			at.region = Rect2(k * 16, 0, 16, 16)
			_tex.append(at)
	return _tex[i]


## 一格的状态：第 heart 颗心（0 起）在当前血量下是满 / 半 / 空（0 / 1 / 2）。
static func state(hp: int, heart: int) -> int:
	var v := hp - heart * 2
	return 0 if v >= 2 else (1 if v == 1 else 2)


## box 里每格是一个 TextureRect（红心），金色那层是它的子节点 "Gold"。
static func update(box: Container, hp: int, max_hp: int, size := 16.0) -> void:
	var count := int(ceil(max_hp / 2.0))
	var slots := mini(count, MAX_SLOTS)
	while box.get_child_count() < slots:
		var r := TextureRect.new()
		r.custom_minimum_size = Vector2(size, size)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var g := TextureRect.new()
		g.name = "Gold"
		g.set_anchors_preset(Control.PRESET_FULL_RECT)
		g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(g)
		box.add_child(r)
	for i in box.get_child_count():
		var r := box.get_child(i) as TextureRect
		r.visible = i < slots
		r.texture = tex(state(hp, i))
		var g := r.get_node("Gold") as TextureRect
		# 第 i + 5 颗心存在（上限超过 5 颗）：盖一层金色
		var gold_heart := i + MAX_SLOTS
		g.visible = gold_heart < count
		if g.visible:
			g.texture = tex(3 + state(hp, gold_heart))

class_name PitTrap
extends RestraintTrap
## 落穴洞：地上的洞，踩中一屁股坐进去卡住、两条腿翘在外面（屁股 ×1.5、脚心 ×1.3）。
## 洞里住着 content 那种怪物，从下面挠（挠痒同时算「落穴洞」和那种怪物的来源，可以凑组合）：
##   rat 挠脚鼠 / squirrel 刷尾松鼠 / slime 史莱姆 / tentacle 小触手。洞里的怪物不出来，打不到。

const SHEET := preload("res://assets/generated/pit.png")
const CONTENT := {
	"rat": {"row": 0, "fx": "hand", "extra": "rat", "pitch": 1.6},
	"squirrel": {"row": 1, "fx": "brush", "extra": "squirrel", "pitch": 1.4},
	"slime": {"row": 2, "fx": "goo", "extra": "slime", "pitch": 1.2},
	"tentacle": {"row": 3, "fx": "sting", "extra": "tentacle", "pitch": 0.9},
}

@export var content := "rat"


func _restraint_setup() -> void:
	var c: Dictionary = CONTENT.get(content, CONTENT["rat"])
	hit_fx = str(c["fx"])
	tickle_pitch = float(c["pitch"])
	if sprite:
		sprite.texture = SHEET
		sprite.hframes = 2
		sprite.vframes = 4
		sprite.frame_coords = Vector2i(0, int(c["row"]))


func extra_combo_keys() -> Array:
	return [CONTENT.get(content, CONTENT["rat"])["extra"]]


func _on_restrain(_a: Actor) -> void:
	Audio.play("puddle", -2.0, 0.05, 0.8)


func _while_held(_delta: float) -> void:
	if sprite:
		sprite.z_index = 3 if int(_t * 4.0) % 2 == 0 else 0

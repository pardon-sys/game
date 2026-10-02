class_name SupineTrap
extends RestraintTrap
## 仰卧刑床：踩上去被放倒仰躺在台子上，两条皮带扣住，肚子整个朝上（肚子 ×1.5）；台上的羽毛自己轻轻挠。
## 旁边常装着肚脐羽毛钻（逗弄器 content=drill，同 group_name）。


func _on_restrain(_a: Actor) -> void:
	Audio.play("stocks", -3.0, 0.08, 0.9)

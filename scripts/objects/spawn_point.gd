class_name SpawnPoint
extends Marker2D
## 到达点：从别的地图的楼梯（LevelExit.spawn）过来时，公主站在同名的到达点上。图例：X = spawn id=<名字>

@export var id := ""


func _ready() -> void:
	add_to_group("spawn_point")

"""定向更新建塔友军情报；不重生成波次、地图、Boss或其他攻防战数据。"""
import json
from pathlib import Path
from siege_text.build_support import intel

root = Path(__file__).resolve().parents[2]
path = root / "data/siege/intel.json"
data = json.loads(path.read_text())
data.update(intel())
path.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n")
print("更新建塔友军情报2项")

extends TaskShow
## 第 6 天晚上 镇长「笑声灯笼」（广场）：LanternShow。


static func status_text() -> String:
	return "↑↓ 调刷子的强度，让闷笑停在灯笼要的范围里"


func make_show() -> Node:
	return LanternShow.new()

extends TaskShow
## 第 3 天晚上 药剂师奶奶「逃跑的痒痒鼠」（药剂师工房）：MouseShow。


static func status_text() -> String:
	return "Q W E / A S D 拍对地方抓小鼠"


func make_show() -> Node:
	return MouseShow.new()

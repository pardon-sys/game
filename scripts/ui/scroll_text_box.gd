class_name ScrollTextBox
extends ScrollContainer
## 可复用的滚动文字面板：固定大小，只竖向滚动；文字自动换行、不超出边框，内容比面板高时出现像素风滚动条（鼠标滚轮可滚）。
## 用在训练菜单的说明 / 列表、背包状态页和物品 / 被动说明、训练小游戏的面板上。
##   var box := ScrollTextBox.make(Rect2(位置, 大小))；parent.add_child(box)
##   clear()、add_line(文字, 颜色)、add_row(图标控件, 文字, 颜色)、add_control(控件)、set_text(文字, 颜色)
##   scroll_by(方向)（键盘一次一行）、scroll_to_top()、ensure_visible(控件)
## style_scrollbar(滚动条)：统一的像素风滚动条样式（对话框、暂停菜单也用它）。

const LINE_STEP := 14.0
const BAR_W := 4.0

var box: VBoxContainer
var font_size := 0
var separation := 2


static func make(rect: Rect2, sep := 2, size_px := 0) -> ScrollTextBox:
	var s := ScrollTextBox.new()
	s.separation = sep
	s.font_size = size_px
	s.position = rect.position
	s.size = rect.size
	s.custom_minimum_size = rect.size
	return s


static func style_scrollbar(bar: ScrollBar, width := BAR_W) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.2, 0.13, 0.2, 0.85)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.95, 0.72, 0.8)
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", grab)
	bar.add_theme_stylebox_override("grabber_pressed", grab)
	bar.custom_minimum_size.x = width


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(box)


func _ready() -> void:
	box.add_theme_constant_override("separation", separation)
	style_scrollbar(get_v_scroll_bar())


## 文字可用的宽度（给滚动条留位置）。
func text_width() -> float:
	return maxf(size.x - BAR_W - 3.0, 8.0)


func clear() -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	scroll_vertical = 0


func _make_label(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.custom_minimum_size.x = text_width()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func add_line(text: String, col := Color(0.95, 0.92, 0.98)) -> Label:
	var l := _make_label(text, col)
	box.add_child(l)
	return l


## 一行：左边一个小控件（图标），右边自动换行的文字。
func add_row(icon: Control, text: String, col := Color(0.95, 0.92, 0.98)) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var l := _make_label(text, col)
	l.custom_minimum_size.x = maxf(text_width() - icon.custom_minimum_size.x - 4.0, 8.0)
	row.add_child(l)
	box.add_child(row)
	return row


func add_control(c: Control) -> Control:
	box.add_child(c)
	return c


## 整个面板只显示一段文字（说明）。
func set_text(text: String, col := Color(0.95, 0.92, 0.98)) -> Label:
	clear()
	return add_line(text, col)


func line_count() -> int:
	return box.get_child_count()


## 内容比面板高（需要滚动）。
func is_scrollable() -> bool:
	return box.get_combined_minimum_size().y > size.y + 0.5


func scroll_by(dir: int) -> void:
	scroll_vertical = int(clampf(scroll_vertical + dir * LINE_STEP, 0.0, maxf(box.get_combined_minimum_size().y - size.y, 0.0)))


func scroll_to_top() -> void:
	scroll_vertical = 0

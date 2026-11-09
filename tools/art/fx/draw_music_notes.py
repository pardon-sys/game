"""摇篮曲音符：3 帧 16x16（八分音符 / 双八分音符 / 高音谱号）。笔画白色（游戏里按帧着色）、外面一圈深色描边。"""
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
W = 16
img = Image.new("L", (W * 3, W), 0)
d = ImageDraw.Draw(img)
# 0 八分音符
d.ellipse([1, 9, 8, 14], fill=255); d.line([7, 11, 7, 2], fill=255, width=2); d.line([7, 2, 12, 6], fill=255, width=2)
# 1 双八分
o = W
d.ellipse([o + 0, 10, o + 6, 14], fill=255); d.ellipse([o + 8, 9, o + 14, 13], fill=255)
d.line([o + 5, 12, o + 5, 2], fill=255, width=2); d.line([o + 13, 11, o + 13, 1], fill=255, width=2)
d.polygon([(o + 5, 1), (o + 14, 0), (o + 14, 3), (o + 5, 4)], fill=255)
# 2 高音谱号（简化）
o = W * 2
d.arc([o + 3, 6, o + 12, 14], 20, 340, fill=255, width=2)
d.line([o + 8, 14, o + 8, 1], fill=255, width=2)
d.arc([o + 6, 0, o + 12, 6], 180, 60, fill=255, width=2)
d.ellipse([o + 5, 12, o + 9, 15], fill=255)
a = np.asarray(img) > 100
edge = ndimage.binary_dilation(a, iterations=1) & ~a
rgba = np.zeros((W, W * 3, 4), np.uint8)
rgba[a] = (255, 255, 255, 255)
rgba[edge] = (70, 40, 80, 255)
Image.fromarray(rgba, "RGBA").save("/Users/zxcvbzzy1/Desktop/项目/project_godot/project-1/assets/generated/music_notes.png")
print("music_notes.png")

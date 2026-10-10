"""第八层夜迷宫第五轮的像素图（输出到 assets/generated/）：
  princess_sleep.png          32x32   粉色公主睡着的样子：朝下待机帧（普通表情）把眼睛画成闭着的「‿」
  item_thousand_pants.png     16x16   关键道具「千手痒痒裤」：紫色紧身短裤 + 两只小手
用法：python tools/art/gen_maze5_art.py
"""
from PIL import Image, ImageDraw

from palette import OUT, add_outline

LID = (90, 30, 60, 255)
LASH = (60, 20, 45, 255)


def princess_sleep():
    sheet = Image.open(OUT / "princess.png").convert("RGBA")
    f = sheet.crop((0, 0, 32, 32))
    skin = f.getpixel((15, 16))
    for (x0, x1) in ((12, 14), (18, 20)):
        for y in range(14, 17):
            for x in range(x0, x1 + 1):
                f.putpixel((x, y), skin)
        # 「‿」：两端高、中间低
        f.putpixel((x0, 15), LID)
        f.putpixel((x0 + 1, 16), LID)
        f.putpixel((x1, 15), LID)
    return f


def thousand_pants():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cloth = (150, 80, 200, 255)
    cloth_d = (105, 50, 150, 255)
    cloth_l = (210, 160, 250, 255)
    d.rectangle((3, 4, 12, 7), fill=cloth)                   # 腰
    d.polygon([(3, 7), (6, 7), (6, 12), (3, 12)], fill=cloth)     # 左腿
    d.polygon([(9, 7), (12, 7), (12, 12), (9, 12)], fill=cloth)   # 右腿
    d.line((7, 7, 8, 7), fill=cloth_d)
    d.line((3, 4, 12, 4), fill=cloth_l)
    for x in (4, 10):                                         # 布上的小手印
        d.point((x, 9), fill=cloth_l)
        d.point((x + 1, 9), fill=cloth_l)
        d.point((x, 10), fill=cloth_l)
    for x, y in ((1, 2), (14, 2)):                            # 两只伸出来的小手
        d.rectangle((x - 1, y, x, y + 2), fill=(235, 200, 255, 255))
        d.point((x + (1 if x < 8 else -2), y + 3), fill=(235, 200, 255, 255))
    return add_outline(img)


def main():
    princess_sleep().save(OUT / "princess_sleep.png")
    thousand_pants().save(OUT / "item_thousand_pants.png")
    print("第五轮像素图：princess_sleep, item_thousand_pants")


if __name__ == "__main__":
    main()

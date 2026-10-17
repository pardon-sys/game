"""Normalize the approved imagegen source and draw deterministic matching pixel parts.
Python: test_for_master. Original generated source is retained without modification.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageEnhance
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/generated/siege'
im=Image.open(ROOT/'tools/art/src/fortress_playful_source.png').convert('RGBA')
im=im.crop(im.getbbox()).resize((588,200),Image.Resampling.NEAREST)
a=im.getchannel('A').point(lambda value: 255 if value>=128 else 0);im=im.convert('RGB').quantize(colors=32).convert('RGBA');im.putalpha(a)
im=im.resize((1176,400),Image.Resampling.NEAREST)
im.save(OUT/'fortress_v2_hull.png')
for name,size in [('hand',(80,72)),('hand_closed',(80,72)),('missile',(24,48)),('pod',(32,44)),('shell',(32,48)),('deck',(260,60))]:
 p=Image.new('RGBA',(size[0]//2,size[1]//2));d=ImageDraw.Draw(p);w,h=p.size
 d.rounded_rectangle((1,1,w-2,h-2),radius=3,fill='#8061a5',outline='#302544',width=2)
 d.rectangle((3,3,w-4,h-4),outline='#ffd56a',width=2)
 if name in ('hand','hand_closed'):
  d.rectangle((0,0,w,h),fill=(0,0,0,0))
  if name=='hand':
   for x,y in [(8,5),(14,1),(20,0),(26,4)]:d.rounded_rectangle((x,y,x+6,22),radius=3,fill='#ffedb3',outline='#53366f',width=2)
   d.rounded_rectangle((2,15,13,29),radius=4,fill='#ffedb3',outline='#53366f',width=2)
   d.rounded_rectangle((8,14,33,31),radius=5,fill='#ffedb3',outline='#53366f',width=2)
   d.arc((15,18,27,28),0,180,fill='#e5ad52',width=2)
  else:
   d.rounded_rectangle((7,6,34,31),radius=8,fill='#ffedb3',outline='#53366f',width=2)
   for x in (13,20,27):d.line((x,8,x,16),fill='#e5ad52',width=2)
   d.rounded_rectangle((4,16,17,26),radius=4,fill='#f3d78f',outline='#53366f',width=2)
  d.rectangle((11,29,31,35),fill='#56c4cf',outline='#53366f',width=2)
  d.line((13,31,29,31),fill='#ffd56a',width=2)
 elif name=='deck':
  for x in range(8,w-8,16):d.rectangle((x,5,x+8,h-6),fill='#ac83cf',outline='#ffda7d')
 else:
  d.polygon([(w//2,0),(w-3,8),(w-3,h-6),(3,h-6),(3,8)],fill='#f06e54' if name=='missile' else '#9e78ce',outline='#e8be6a')
  d.rectangle((w//2-2,7,w//2+2,12),fill='#84f3f0')
  d.rectangle((w//2-2,h-5,w//2+2,h-1),fill='#ffe99e')
 p.resize(size,Image.Resampling.NEAREST).save(OUT/f'fortress_v2_{name}.png')
(OUT/'fortress_v2.json').write_text(json.dumps({'body':[1176,400],'source':'tools/art/src/fortress_playful_source.png','pixel_scale':2,'palette_colors':32,'style':'playful dungeon toy fortress','anchors':{'shoulders':[[-520,-70],[520,-70]],'cranes':[[-360,-130],[360,-130]],'core':[[-600,-170],[600,-170]],'cannon':[0,-190]}},indent=2)+'\n')
print('fortress v2: generated hull + six deterministic pixel parts')

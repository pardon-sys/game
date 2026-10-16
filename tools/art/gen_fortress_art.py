"""Deterministic layered 2px siege fortress pixel assets; test_for_master / Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw
import json
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/generated/siege'
OUT.mkdir(parents=True,exist_ok=True)
P={'ink':'#221d35','dark':'#39344e','iron':'#56546e','light':'#85859a','gold':'#e7b34e','shine':'#ffe1a0','copper':'#b46c42','red':'#c5565d','cyan':'#66c9c6','purple':'#82649e'}
layers={}
def layer(name):
 im=Image.new('RGBA',(96,80)); layers[name]=im; return ImageDraw.Draw(im)
def box(d,xy,c,outline='ink',width=1): d.rectangle(xy,fill=P.get(c,c),outline=P.get(outline,outline),width=width)
def rivets(d,x0,y0,x1,y1,step=7):
 for x in range(x0,x1,step): d.rectangle((x,y0,x+1,y0+1),fill=P['shine']);d.rectangle((x,y1,x+1,y1+1),fill=P['copper'])
d=layer('tracks')
for x in (17,67):
 box(d,(x,19,x+12,76),'dark');box(d,(x+2,21,x+10,74),'iron')
 for y in range(23,74,5):
  box(d,(x, y,x+12,y+2),'light');d.line((x+2,y,x+8,y),fill=P['shine'])
 for y in (28,44,60): d.ellipse((x+3,y,x+9,y+8),fill=P['dark'],outline=P['ink'])
d=layer('platform')
box(d,(0,32,95,62),'dark');box(d,(2,34,93,59),'purple');rivets(d,4,35,92,58)
for x in (5,77):
 box(d,(x,39,x+13,54),'gold');box(d,(x+2,41,x+11,52),'iron')
 for y in range(43,51,3):d.line((x+3,y,x+10,y),fill=P['ink'])
d=layer('hull')
box(d,(28,14,67,73),'dark');box(d,(30,16,65,71),'copper');box(d,(32,19,63,63),'iron');rivets(d,33,20,63,62)
box(d,(35,25,60,45),'dark');box(d,(37,27,58,43),'purple')
# Carnival mask with visor eyes and brass grille.
for x in (40,52):box(d,(x,31,x+4,34),'cyan');d.point((x+1,31),fill='white')
box(d,(40,39,55,42),'gold')
for x in range(42,55,3):d.line((x,39,x,42),fill=P['ink'])
box(d,(37,49,58,60),'ink')
for x in range(39,58,4):box(d,(x,51,x+1,58),'gold')
d.ellipse((41,64,54,74),fill=P['dark'],outline=P['gold']);d.line((48,70,51,66),fill=P['red'],width=2)
for x in (31,61):
 box(d,(x,6,x+4,21),'copper');box(d,(x-1,5,x+5,8),'gold');box(d,(x,3,x+4,4),'dark')
d=layer('plow')
d.polygon([(19,17),(28,10),(67,10),(77,17),(69,26),(27,26)],fill=P['ink'])
d.polygon([(22,17),(29,12),(66,12),(74,17),(67,23),(29,23)],fill=P['copper'])
for x in range(27,69,8):d.polygon([(x,13),(x+3,13),(x+6,22),(x+3,22)],fill=P['gold'])
d.line((24,17,72,17),fill=P['shine'])
d=layer('rockets')
for x in (19,66):
 box(d,(x,30,x+10,49),'dark')
 for j in (0,5):
  box(d,(x+j,30,x+j+4,43),'red');d.polygon([(x+j,30),(x+j+2,25),(x+j+4,30)],fill=P['shine']);box(d,(x+j,39,x+j+4,42),'gold')
d=layer('crane')
box(d,(60,49,65,68),'gold');box(d,(61,7,65,51),'copper');box(d,(47,6,65,10),'gold')
d.line((48,10,48,19),fill=P['light']);d.arc((45,16,51,23),0,210,fill=P['gold'],width=2)
for y in range(14,48,7):d.line((61,y,65,y+4),fill=P['ink'])
d=layer('arms')
for side in (-1,1):
 x=48+side*27
 d.ellipse((x-4,48,x+4,56),fill=P['gold'],outline=P['ink'])
 box(d,(x-3,53,x+3,63),'copper')
 d.ellipse((x-6,61,x+6,70),fill=P['purple'],outline=P['gold'])
 for k in range(3):box(d,(x-5+k*4,67,x-3+k*4,73),'shine')
for name,im in layers.items(): im.resize((192,160),Image.Resampling.NEAREST).save(OUT/f'fortress_{name}.png')
for state in ('normal','expanded','cast','hit','overload','damaged','destroyed'):
 im=Image.new('RGBA',(96,80))
 for key,pic in layers.items():
  if key=='platform' and state=='normal':continue
  im.alpha_composite(pic)
 draw=ImageDraw.Draw(im)
 if state in ('cast','overload'):draw.ellipse((39,48,57,62),outline=P['cyan'] if state=='cast' else P['shine'],width=2)
 if state in ('damaged','destroyed'):
  for x,y in [(36,20),(54,44),(32,59)]:draw.line((x,y,x+4,y+5,x+1,y+9),fill=P['ink'],width=2)
 if state=='destroyed':draw.polygon([(20,72),(43,47),(65,72),(53,57),(78,77)],fill=P['red']);draw.polygon([(33,73),(45,57),(60,75)],fill=P['gold'])
 if state=='hit':
  white=Image.new('RGBA',im.size,(255,240,220,150));white.putalpha(im.getchannel('A').point(lambda a:int(a*.55)));im=Image.alpha_composite(im,white)
 im.resize((192,160),Image.Resampling.NEAREST).save(OUT/f'fortress_{state}.png')
(OUT/'fortress.json').write_text(json.dumps({'canvas':[192,160],'body':[128,160],'expanded':[192,160],'layers':list(layers),'pixel_scale':2},indent=2)+'\n')
print('fortress: 7 layers, 7 states, 192x160, deterministic')

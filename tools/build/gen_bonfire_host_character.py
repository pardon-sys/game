"""派对主人角色档案。沿gen_blue_character.py流程生成独立目录，不执行蓝色生成器。
基础反应、通用演出与装备资料；不添加专属长篇剧情。仅更新本角色、两个Buff和人物表对应项。
"""
from pathlib import Path
import copy
import json

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'data/characters/bonfire_host'
NAME = '篝火派对的主人'
ROLE = 'bonfire_host'
LINES = {
 'calm': ['别急，派对才刚开始呢！', '哎呀，这一下可不在节目单上。', '等我把灯提稳，马上就好。', '想打乱主持人的节奏？我看见你啦。'],
 'giggle': ['噗……等一下，我还在报幕呢！', '呵呵，灯笼都跟着晃了，先让我站稳！', '别、别趁我举灯的时候捣乱呀。', '大家先看彩带，别看我……噗！'],
 'helpless_1': ['哈哈，节目顺序……让我重新排一下！', '哈、哈哈！我还没说开场词呢！', '灯、灯先放稳，哈哈……别碰腋下啦！', '哈哈哈！腰边一碰，我就记不住下一拍了！'],
 'helpless_2': ['哈哈哈哈！主持人申请中场休息！', '哈、哈哈哈！好啦，我先认输，灯笼别掉！', '哈哈哈哈，谁来替我报幕呀！', '等、等等……哈哈哈！节奏全乱啦！'],
 'grabbed': ['哎，主持人可不能一直站在这里呀！', '先放开手，我的彩带还没收好呢！'],
 'special': ['呀！哈哈哈——这可真是突然加演！', '噗哈哈！腋下别闹，灯要晃掉啦！'],
}
WORDS = {'helpless_1':['还在报幕呢！','灯先提稳','噗、哈哈'], 'helpless_2':['申请休息！','节奏全乱啦','哈哈哈哈']}
MAGIC = {'channel':['灯火聚起来，彩带跟上！','大家站稳，热闹的要来啦！'], 'interrupted':['哎呀，节拍断了。再来！'],
 'fizzle':['灯花还没攒够呢。'], 'burst':['派对开场！大家一起跑起来！'], 'burst_full':['灯火全亮！可别让对面先追上来哦！'],
 'exposed_hint':['举灯时要留神身边的敌人。']}


def read(path): return json.loads((ROOT/path).read_text())
def write(path, data):
 path.parent.mkdir(parents=True, exist_ok=True)
 path.write_text(json.dumps(data, ensure_ascii=False, indent='\t')+'\n')
def line(text, emotion='normal'): return {'speaker':NAME,'text':text,'emotion':emotion}

def main():
 OUT.mkdir(parents=True, exist_ok=True)
 pink = read('data/princess_reactions.json')
 sources = {}
 for key, source in pink.get('sources',{}).items():
  if not isinstance(source,dict): continue
  item = {'name':source.get('name',key), **copy.deepcopy(LINES)}
  item['first_encounter'] = []
  item['portrait_words'] = WORDS
  if isinstance(source.get('lines_by_content'),dict):
   item['lines_by_content'] = {variant:copy.deepcopy(LINES) for variant in source['lines_by_content']}
  sources[key] = item
 # 保留全部已注册攻防战来源的名字和变体键，内容统一走本角色的通用反应。
 siege = read('data/characters/blue/reactions.json')
 for key, source in siege.get('sources',{}).items():
  if key not in sources and isinstance(source,dict):
   sources[key]={'name':source.get('name',key),**copy.deepcopy(LINES),'first_encounter':[], 'portrait_words':WORDS}
 write(OUT/'reactions.json', {'_说明':'gen_bonfire_host_character.py生成；仅基础角色反应，不复制公主专属剧情。',
  'display_seconds':2.4,'cooldown_seconds':2.0,'lines':LINES,'hints':pink.get('hints',{}),'portrait_words':WORDS,'sources':sources,'magic':MAGIC,'combos':{}})
 tk=read('data/actors/princess_ticklish.json')
 tk['_说明']='派对主人：腋下、腰侧1.4；其他1.0。阶段、连续命中等字段沿用既有结构。'
 for key, info in tk['zones'].items():
  info['sensitivity']=1.4 if key in ('armpit','waist') else 1.0
  info['words']=WORDS
 write(OUT/'ticklish.json',tk)
 write(OUT/'stats.json',{'_说明':'沿用公主场景基准；只覆盖本角色魔法冷却。','speed_mult':1.0,'magic_cooldown':12.0})
 write(OUT/'fatigue.json',{'_说明':'派对主人通用疲倦反馈。','burst':['哎呀，灯火自己开场啦！','散开一点，这圈热闹连对面也会赶上！'],
  'after':['呼，先把灯提稳，再接下一段。','刚才笑得乱了拍子，让我缓一缓。'],
  'first':[line('灯花攒得太满了，先给大家让个位置！','surprise'),line('呼……这下连对面都跑快了，可要留神。','shy')],
  'warning':['灯火快满了，别挤在敌人旁边！','该找个宽敞的位置了。']})
 common={'got_bronze_key':'铜钥匙收好了，看看前面哪扇门需要它。','got_gold_key':'金钥匙！下一段路有着落啦。','locked_bronze':'这扇门要铜钥匙。','locked_gold':'这扇门要金钥匙。',
  'gate_closed':'门还关着，先找找机关吧。','laugh_recover':'呼……主持人回来啦！下一段重新起拍。','respawn':'灯火还在，重整一下再来！'}
 write(OUT/'dialogues.json',{'_说明':'派对主人通用对话。',**{k:[line(v)] for k,v in common.items()}})
 # 装备只保留现有效果的数值与通用反馈，不复制蓝色的永久裤子情节。
 equip=read('data/equip_reactions.json')
 def rewrite(value):
  if isinstance(value,list):
   if value and all(isinstance(x,str) for x in value): return value
   return [rewrite(x) for x in value]
  if not isinstance(value,dict): return value
  out={}
  for k,v in value.items():
   if k=='words': out[k]=['先让我提稳灯。','噗，别打乱节拍！'] if isinstance(v,list) else {'calm':['先让我提稳灯。'],'giggle':['噗，别打乱节拍！'],'helpless':['哈哈，申请休息！']}
   elif k in ('lines','caption','captions'): out[k]=[] if isinstance(v,list) else ''
   else: out[k]=rewrite(v)
  return out
 equip=rewrite(equip);equip['_说明']='派对主人装备通用反馈，保持原装备数据格式。'
 equip.pop('thousand_pants',None)
 write(OUT/'equip_reactions.json',equip)
 cg={'name':'主持人的中场休息','cast':{'princess':{'kind':'princess','at':[0,8],'visual':'helpless_1','anim':'helpless','dir':'down'}},
  'steps':[{'actions':[{'do':'fade_in','time':0.3}],'wait':0.3},
   {'portrait':'defeat_1',**line('哈、哈哈……等一下，我还没把这段报完呢！','giggle')},
   {'portrait':'defeat_2',**line('哈哈哈！好啦，中场休息！灯笼先放稳……','helpless_2'),'actions':[{'do':'pose','who':'princess','visual':'helpless_2','anim':'helpless'}]},
   {'portrait':'wake',**line('呼，笑得全乱拍了。下一次，我要把节奏拿回来。','shy'),'actions':[{'do':'pose','who':'princess','visual':'sad','anim':'idle'}]},
   {'actions':[{'do':'fade_out','time':0.3}],'wait':0.3}]}
 write(OUT/'cgs.json',{'_说明':'只提供本角色通用笑倒；专属长篇来源演出未制作。','portraits':{'defeat_1':{'file':'','placeholder':'helpless_1'},'defeat_2':{'file':'','placeholder':'helpless_2'},'wake':{'file':'','placeholder':'sad'},'fatigue_burst':{'file':'','placeholder':'damaged_giggle_burst'}},
  'actors':{},'trap_actors':{},'death':{'default':'host_rest','by_source':{}},'cgs':{'host_rest':cg}})
 write(OUT/'nest_cgs.json',{'_说明':'未新增专属巢穴演出，走本角色通用笑倒。','portraits':{},'nest':{},'cgs':{}})
 for key in ('combo_scenes','equip_scenes','siege_scenes'):
  write(OUT/(key+'.json'),{'_说明':'预留既有格式；本批不增加专属长篇演出，不回退读取其他角色。','scenes':{}})
 write(OUT/'siege_cgs.json',{'_说明':'来源默认使用本角色通用笑倒。','actors':{},'death':{},'portraits':{},'cgs':{}})
 # 不创建或复制blue专属maze_lines；目前没有派对主人的迷宫业务入口。
 npcs=read('data/actors/npcs.json')
 npcs['npcs'][ROLE].update(sprite='res://assets/generated/bonfire_host.png',portrait_set=ROLE,princess_sheet=True,
  scene='res://scenes/actors/playable/bonfire_host.tscn',profile={'age':'成年','personality':'热情从容的主持人，受扰后努力圆场，忍笑到手忙脚乱。','weak':'腋下与腰侧'})
 write(ROOT/'data/actors/npcs.json',npcs)
 buffs=read('data/buffs.json');buffs['stat_kinds']['damage_dealt']='mul'
 # 只追加图标序号，原图标与已有状态保持原值。
 from PIL import Image
 icons=Image.open(ROOT/'assets/generated/buff_icons.png')
 base=icons.width//12
 assigned=[v.get('icon',0) for k,v in buffs['buffs'].items() if k in ('festival_ally','festival_enemy')]
 start=min(assigned) if assigned else base
 for k,idx,name,mods,desc in (
  ('festival_ally',start,'祭典鼓舞',{'speed':1.2,'damage_dealt':1.4},'移速+20%，普通攻击及伤害魔法+40%。'),
  ('festival_enemy',start+1,'祭典狂热',{'speed':1.2,'tickle_power':1.35},'移速+20%，挠痒强度+35%。')):
  buffs['buffs'][k]={'name':name,'icon':idx,'debuff':False,'duration':0.3,'max_stacks':1,'modifiers':mods,'desc':desc}
 write(ROOT/'data/buffs.json',buffs)
 for fid in ('floor_06_upper','floor_06_war','floor_06_after'):
  path=ROOT/'levels'/fid/'map.txt'
  path.write_text(path.read_text().replace('npc id=bonfire_host ', 'bonfire_host '))
 print('派对主人基础档案、人物注册与两个Buff已定向生成')

if __name__=='__main__': main()

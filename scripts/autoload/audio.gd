extends Node
## 简单音效播放器：Audio.play("chest")。

const DIR := "res://assets/third_party/kenney_rpg_audio/"
const SOUNDS := {
	"step": ["footstep00.ogg", "footstep02.ogg", "footstep04.ogg", "footstep06.ogg"],
	"swing": ["knifeSlice.ogg", "knifeSlice2.ogg"],
	"hit": ["chop.ogg"],
	"hurt": ["cloth1.ogg"],
	"dash": ["drawKnife1.ogg"],
	"door": ["doorOpen_1.ogg"],
	"door_close": ["doorClose_2.ogg"],
	"gate": ["creak1.ogg"],
	"unlock": ["metalLatch.ogg"],
	"locked": ["metalClick.ogg"],
	"lever": ["beltHandle1.ogg"],
	"chest": ["creak1.ogg"],
	"coin": ["handleCoins.ogg"],
	"pickup": ["handleSmallLeather.ogg"],
	"book": ["bookFlip2.ogg"],
	"break": ["metalPot1.ogg"],
	"drop": ["dropLeather.ogg"],
	"torch": ["drawKnife1.ogg"],
	"cloth": ["cloth1.ogg"],
	# 由 tools/art/gen_sfx.py 合成
	"tickle": ["res://assets/generated/sfx/tickle_1.wav", "res://assets/generated/sfx/tickle_2.wav",
		"res://assets/generated/sfx/tickle_3.wav", "res://assets/generated/sfx/tickle_4.wav"],
	"web": ["res://assets/generated/sfx/web.wav"],
	"puff": ["res://assets/generated/sfx/puff.wav"],
	"swish": ["res://assets/generated/sfx/swish.wav"],
	"grab": ["res://assets/generated/sfx/grab.wav"],
	"chant": ["res://assets/generated/sfx/chant.wav"],
	"star_burst": ["res://assets/generated/sfx/star_burst.wav"],
	"water_release": ["res://assets/generated/sfx/water_release.wav"],
	"fizzle": ["res://assets/generated/sfx/fizzle.wav"],
	"pinch": ["res://assets/generated/sfx/pinch.wav"],
	"vine": ["res://assets/generated/sfx/vine.wav"],
	"wind": ["res://assets/generated/sfx/wind.wav"],
	"conveyor": ["res://assets/generated/sfx/conveyor.wav"],
	"chomp": ["res://assets/generated/sfx/chomp.wav"],
	"chime": ["res://assets/generated/sfx/chime.wav"],
	"music_box": ["res://assets/generated/sfx/music_box.wav"],
	"pop": ["res://assets/generated/sfx/pop.wav"],
	"combo": ["res://assets/generated/sfx/combo.wav"],
	"tickle_special": ["res://assets/generated/sfx/tickle_special.wav"],
	"puddle": ["res://assets/generated/sfx/puddle.wav"],
	"bubble": ["res://assets/generated/sfx/bubble.wav"],
	"bubble_pop": ["res://assets/generated/sfx/bubble_pop.wav"],
	"roll": ["res://assets/generated/sfx/roll.wav"],
	"stocks": ["res://assets/generated/sfx/stocks.wav"],
	"totem": ["res://assets/generated/sfx/totem.wav"],
	"rune": ["res://assets/generated/sfx/rune.wav"],
	# CC0: cicifyre (giggle), moxobna (continuous laugh); see each License.txt.
	"giggle": ["res://assets/third_party/cicifyre_voice/giggle.wav"],
	"laugh": ["res://assets/third_party/cicifyre_voice/laugh.wav"],
	# 蓝色公主专属的笑声（用户提供：assets/generated/blue_princess/轻笑.mp3、大笑.mp3）
	"blue_giggle": ["res://assets/audio/voice/blue/giggle.mp3"],
	"blue_laugh": ["res://assets/audio/voice/blue/laugh.mp3"],
	# 蓝色公主笑出声（憋爆、魔法失败、过场）：只用她的两种笑声——短的是轻笑，长的是大笑（不循环）
	"blue_crack": ["res://assets/audio/voice/blue/giggle.mp3"],
	"blue_crack_long": ["res://assets/audio/voice/blue/laugh.mp3"],
	# 第八层夜迷宫第五轮（tools/art/gen_sfx.py）
	"hand_grab": ["res://assets/generated/sfx/hand_grab.wav"],
	"heartbeat": ["res://assets/generated/sfx/heartbeat.wav"],
	"rumble": ["res://assets/generated/sfx/rumble.wav"],
	"brush_spin": ["res://assets/generated/sfx/brush_spin.wav"],
	"bat_flap": ["res://assets/generated/sfx/bat_flap.wav"],
	"ice_crack": ["res://assets/generated/sfx/ice_crack.wav"],
	# 小镇攻防战
	"siege_horn": ["res://assets/generated/sfx/siege_horn.wav"],
	"cart_rumble": ["res://assets/generated/sfx/cart_rumble.wav"],
	"wall_crash": ["res://assets/generated/sfx/wall_crash.wav"],
	"hook_throw": ["res://assets/generated/sfx/hook_throw.wav"],
	"tower_build": ["res://assets/generated/sfx/tower_build.wav"],
	"icicle": ["res://assets/generated/sfx/icicle.wav"],
	"win_fanfare": ["res://assets/generated/sfx/win_fanfare.wav"],
	"lose_fanfare": ["res://assets/generated/sfx/lose_fanfare.wav"],
	"bell_jingle": ["res://assets/generated/sfx/bell_jingle.wav"],
	"chase_drums": ["res://assets/generated/sfx/chase_drums.wav"],
}
## 循环播放的声音（用 loop_stream 取流，挂到自己的播放器上）。
const LOOPED := ["laugh", "blue_laugh", "chant", "wind", "conveyor", "chase_drums"]
const POOL_SIZE := 10

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _voice: AudioStreamPlayer
var _voice_state := ""
## 蓝色公主笑出声（blue_crack = 轻笑 / blue_crack_long = 大笑）单独一个播放器：换关卡也不断（过场之间的笑声衔接），可以淡出
var _crack: AudioStreamPlayer
var _crack_tw: Tween
## 别处的笑声播放器（小剧场舞台的 voice / voice2）：同一时间只放一段笑声——她笑出声（blue_crack）时它们先停住（register_laugh_player）
var _laugh_players: Array[AudioStreamPlayer] = []

# ------------------------------------------------------------------ 背景音乐
## 配乐（tools/audio/gen_music.py 用 ElevenLabs 生成，2 分钟可循环）：地牢层 dungeon、地下小镇 town、攻防战 siege。
## 关卡载入时按 data/floors.json 的 music 切换（play_music）；CG / 过场 / 对话剧场时压低（DUCK_DB）。
## 循环：.wav.import 里 edit/loop_begin = 循环起点（前奏只放一次，之后在正文里循环），文件结尾已经和循环起点之前的一拍交叉淡化好。
## 换曲：旧曲淡出（fade 的一半），淡到 MUSIC_OVERLAP 时新曲从头淡入——只在两边都很轻的时候短暂重叠，不会两首叠着放、也不会中间空一段。
## 淡入淡出补的是线性振幅 _fade[i]（0~1，正弦缓入缓出），每帧在 _update_music 里和目标音量、压低量合成 volume_db。
## 音乐音量 music_volume（0~1）存在玩家数据目录的 settings.cfg（暂停菜单调）。
const MUSIC := {
	"dungeon": "res://assets/audio/music/dungeon_loop.wav",
	"town": "res://assets/audio/music/town_loop.wav",
	"boss": "res://assets/audio/music/boss_loop.wav",
	"boss3": "res://assets/audio/music/boss3_loop.wav",
	"night_room": "res://assets/audio/music/night_room_loop.wav",
	"night_maze": "res://assets/audio/music/night_maze_loop.wav",
	"siege": "res://assets/audio/music/siege_loop.wav",
	"minigame": "res://assets/audio/music/minigame_loop.wav",
	"knight_boss": "res://assets/audio/music/knight_boss_loop.wav",
	# 骑士 Boss 最后阶段「笑雾之中」：原曲 + 宿命感、诡异、迷惑
	"knight_fog": "res://assets/audio/music/knight_fog_loop.wav",
	# 反省篇第四章：被遗弃的旧王宫（荒凉、破旧、往日的华丽）/ 王座间 Boss「封笑的女王画像」
	"old_palace": "res://assets/audio/music/old_palace_loop.wav",
	"palace_boss": "res://assets/audio/music/palace_boss_loop.wav",
	"palace_memory": "res://assets/audio/music/palace_memory_loop.wav",
}
const MUSIC_DB := -6.0
const SFX_BUS := &"SFX"
const DUCK_DB := -6.0
const MUSIC_FADE := 1.2
## 旧曲淡出到这个比例（剩下的振幅）时新曲开始淡入
const MUSIC_OVERLAP := 0.3
var music_volume := 0.7
var sfx_volume := 1.0
var music_id := ""
var _music: Array[AudioStreamPlayer] = []
var _music_cur := 0
var _duck := 0.0
## 两个播放器各自的淡入淡出振幅（0~1）
var _fade: Array[float] = [0.0, 0.0]


static func settings_path() -> String:
	return DevConfig.data_root() + "settings.cfg"


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_save_volume("music_volume", music_volume)


## 音效、机关循环声和人物声音统一经过 SFX 总线，保留各播放器自己的音量与淡出。
func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_sfx_volume()
	_save_volume("sfx_volume", sfx_volume)


func _apply_sfx_volume() -> void:
	var bus := AudioServer.get_bus_index(SFX_BUS)
	AudioServer.set_bus_mute(bus, sfx_volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(sfx_volume, 0.001)))


func _save_volume(key: String, value: float) -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path())
	cfg.set_value("audio", key, value)
	cfg.save(settings_path())


## 播放 id 的配乐（循环）；id 为空就淡出停掉。已经在放同一首时什么都不做。
## 换曲时两个播放器交替用。每个播放器同时只留一个淡入 / 淡出补间：
## 连着换两次曲（读档：先放地牢曲、马上换 Boss 曲）时，旧的淡出补间不能在新曲开始后把播放器停掉。
var _music_tw: Array[Tween] = [null, null]


func _music_tween(i: int) -> Tween:
	if _music_tw[i] and _music_tw[i].is_valid():
		_music_tw[i].kill()
	_music_tw[i] = _music[i].create_tween()
	_music_tw[i].set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return _music_tw[i]


## tween_method 的回调：bind 的参数排在补间值后面
func _set_fade(v: float, i: int) -> void:
	_fade[i] = v


## 配乐音高（攻防战狂欢节 1.06，换波 / 离开时回到 1）。
func set_music_pitch(pitch: float) -> void:
	for m in _music:
		m.pitch_scale = pitch


func play_music(id: String, fade := MUSIC_FADE) -> void:
	var tw_cur := _music_tw[_music_cur]
	if id == music_id and (id == "" or _music[_music_cur].playing or (tw_cur != null and tw_cur.is_running())):
		return
	music_id = id
	var cur := _music_cur
	var old := _music[cur]
	var wait := 0.0
	# 上一首还在等着开播（连着换了两次曲）：取消它，不然过一会儿它又自己放起来
	if not old.playing and tw_cur != null and tw_cur.is_valid():
		tw_cur.kill()
	if old.playing:
		var out_time := fade * 0.5 * _fade[cur]
		# 正弦缓出：振幅降到 MUSIC_OVERLAP 大约用掉淡出时间的 (1 - MUSIC_OVERLAP) 左右
		wait = out_time * (1.0 - MUSIC_OVERLAP)
		var tw := _music_tween(cur)
		tw.tween_method(_set_fade.bind(cur), _fade[cur], 0.0, out_time)
		tw.tween_callback(old.stop)
	if id == "" or not MUSIC.has(id) or not ResourceLoader.exists(MUSIC[id]):
		return
	var s := load(MUSIC[id]) as AudioStream
	# 配乐 WAV 用无损导入（.import 的 compress/mode=0，QOA 有损压缩会给高频多的曲子添沙沙声），导入设置里就设成向前循环（edit/loop_mode=2）
	if s is AudioStreamWAV and (s as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
		push_warning("配乐 %s 没有在导入设置里开循环" % id)
	elif s is AudioStreamOggVorbis or s is AudioStreamMP3:
		s = s.duplicate()
		s.set("loop", true)
	_music_cur = 1 - cur
	var i := _music_cur
	var p := _music[i]
	var tw := _music_tween(i)
	p.stream = s
	_fade[i] = 0.0
	p.volume_db = -80.0
	if wait > 0.0:
		p.stop()
		tw.tween_interval(wait)
		tw.tween_callback(p.play)
	else:
		p.play()
	tw.tween_method(_set_fade.bind(i), 0.0, 1.0, maxf(fade - wait, 0.05))


## 停掉配乐（淡出），music_id 清空——之后 play_music 同一首也会重新放。
func stop_music() -> void:
	play_music("")


## 楼层的配乐（floors.json 的 music；没写的地牢层默认 dungeon）。
static func music_for_floor(floor_id: String) -> String:
	return str(Floors.info(floor_id).get("music", "dungeon"))


func _music_target_db() -> float:
	if music_volume <= 0.001:
		return -80.0
	return MUSIC_DB + linear_to_db(music_volume) + _duck


func _music_ducked() -> bool:
	var cg := get_node_or_null("/root/CG")
	var cs := get_node_or_null("/root/Cutscene")
	return (cg != null and cg.is_playing()) or (cs != null and cs.is_playing())


## 每帧：目标音量（音乐音量 + 压低）× 淡入淡出振幅 → volume_db（两个播放器都算，淡出中的旧曲也跟着压低）。
func _update_music(delta: float) -> void:
	_duck = move_toward(_duck, DUCK_DB if _music_ducked() else 0.0, 24.0 * delta)
	var base := _music_target_db()
	for i in _music.size():
		var p := _music[i]
		if p.playing:
			p.volume_db = -80.0 if _fade[i] <= 0.001 or base <= -79.0 else base + linear_to_db(_fade[i])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in SOUNDS:
		var list: Array[AudioStream] = []
		for f in SOUNDS[key]:
			var path: String = f if f.begins_with("res://") else DIR + f
			var s := load(path) as AudioStream
			if s:
				if key in LOOPED and s is AudioStreamWAV:
					var loop := s.duplicate() as AudioStreamWAV
					loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
					loop.loop_begin = 0
					loop.loop_end = int(round(loop.get_length() * loop.mix_rate))
					s = loop
				elif key in LOOPED and s is AudioStreamMP3:
					var mloop := s.duplicate() as AudioStreamMP3
					mloop.loop = true
					s = mloop
				list.append(s)
		_streams[key] = list
	_voice = AudioStreamPlayer.new()
	_voice.bus = SFX_BUS
	add_child(_voice)
	_crack = AudioStreamPlayer.new()
	_crack.bus = SFX_BUS
	_crack.name = "Crack"
	add_child(_crack)
	for i in 2:
		var mp := AudioStreamPlayer.new()
		mp.name = "Music%d" % i
		add_child(mp)
		_music.append(mp)
	var cfg := ConfigFile.new()
	if cfg.load(settings_path()) == OK:
		music_volume = clampf(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
		sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	_apply_sfx_volume()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_players.append(p)


func play(sound: String, volume_db := 0.0, pitch_jitter := 0.08, pitch := 1.0) -> void:
	if sound in ["giggle", "laugh"]:
		play_voice(sound)
		return
	if sound in ["blue_crack", "blue_crack_long"]:
		play_crack(sound == "blue_crack_long", volume_db)
		return
	var list: Array = _streams.get(sound, [])
	if list.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = list.pick_random()
	p.volume_db = volume_db
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
	p.play()


## 蓝色公主笑出声：long = 大笑，否则轻笑。正在放时会换成新的一段。
func play_crack(long := false, volume_db := -4.0) -> void:
	var clips: Array = _streams.get("blue_crack_long" if long else "blue_crack", [])
	if clips.is_empty():
		return
	if _crack_tw:
		_crack_tw.kill()
	_crack.stream = clips.pick_random()
	_crack.volume_db = volume_db
	_crack.play()


func crack_playing() -> bool:
	return _crack.playing


## 登记一个会放笑声的播放器：她笑出声（blue_crack）时它暂停，放完接着放（同一时间只有一段笑声）。
func register_laugh_player(p: AudioStreamPlayer) -> void:
	p.bus = SFX_BUS
	if not _laugh_players.has(p):
		_laugh_players.append(p)


func _duck_laughs() -> void:
	var cracking := _crack.playing
	if is_instance_valid(_voice):
		_voice.stream_paused = cracking
	_laugh_players = _laugh_players.filter(func(p): return is_instance_valid(p))
	for p in _laugh_players:
		p.stream_paused = cracking


## 笑出声的那一段慢慢淡掉（time 秒）。
func fade_crack(time := 1.0) -> void:
	if not _crack.playing:
		return
	if _crack_tw:
		_crack_tw.kill()
	_crack_tw = create_tween()
	_crack_tw.tween_property(_crack, "volume_db", -40.0, time)
	_crack_tw.tween_callback(_crack.stop)


## 笑声按当前操控的角色选：蓝色公主有自己的 blue_giggle / blue_laugh。
func voice_key(sound: String, who := "") -> String:
	who = who if who != "" else Characters.current()
	if sound in ["giggle", "laugh"] and who == "blue" and not _streams.get("blue_" + sound, []).is_empty():
		return "blue_" + sound
	return sound


## 取一个循环声音的流（吟唱、风扇、传送带），由调用者用自己的 AudioStreamPlayer(2D) 播放。
func loop_stream(sound: String, who := "") -> AudioStream:
	var list: Array = _streams.get(voice_key(sound, who), [])
	return list[0] if not list.is_empty() else null


func set_voice_state(sound: String) -> void:
	if sound != _voice_state:
		stop_voice()
		_voice_state = sound
	if sound == "laugh":
		play_voice("laugh")


func stop_voice() -> void:
	if is_instance_valid(_voice):
		_voice.stop()


func play_voice(sound: String) -> void:
	if get_tree().paused or sound != _voice_state or _voice.playing or _crack.playing:
		return
	var clips: Array = _streams.get(voice_key(sound), [])
	if clips.is_empty():
		return
	_voice.stream = clips.pick_random()
	_voice.volume_db = -8.0
	_voice.pitch_scale = 1.0
	_voice.play()


func _process(_delta: float) -> void:
	_update_music(_delta)
	_duck_laughs()
	if get_tree().paused or not is_instance_valid(GameState.player) or not GameState.player.is_alive():
		stop_voice()
	elif _voice_state == "laugh":
		# Resume after pause without waiting for a one-shot laugh timer.
		play_voice("laugh")

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
}
## 循环播放的声音（用 loop_stream 取流，挂到自己的播放器上）。
const LOOPED := ["laugh", "blue_laugh", "chant", "wind", "conveyor"]
const POOL_SIZE := 10

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _voice: AudioStreamPlayer
var _voice_state := ""

# ------------------------------------------------------------------ 背景音乐
## 配乐（tools/audio/gen_music.py 用 ElevenLabs 生成，2 分钟首尾相连）：地牢层 dungeon、地下小镇 town。
## 关卡载入时按 data/floors.json 的 music 切换（play_music），换曲时淡入淡出；CG / 过场 / 对话剧场时压低（DUCK_DB）。
## 音乐音量 music_volume（0~1）存在玩家数据目录的 settings.cfg（暂停菜单调）。
const MUSIC := {
	"dungeon": "res://assets/audio/music/dungeon_loop.wav",
	"town": "res://assets/audio/music/town_loop.wav",
	"boss": "res://assets/audio/music/boss_loop.wav",
	"boss3": "res://assets/audio/music/boss3_loop.wav",
}
const MUSIC_DB := -12.0
const DUCK_DB := -6.0
const MUSIC_FADE := 1.2
var music_volume := 0.7
var music_id := ""
var _music: Array[AudioStreamPlayer] = []
var _music_cur := 0
var _duck := 0.0


static func settings_path() -> String:
	return DevConfig.data_root() + "settings.cfg"


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	var cfg := ConfigFile.new()
	cfg.load(settings_path())
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.save(settings_path())


## 播放 id 的配乐（循环）；id 为空就淡出停掉。已经在放同一首时什么都不做。
## 换曲时两个播放器交替用。每个播放器同时只留一个淡入 / 淡出补间：
## 连着换两次曲（读档：先放地牢曲、马上换 Boss 曲）时，旧的淡出补间不能在新曲开始后把播放器停掉。
var _music_tw: Array[Tween] = [null, null]


func _music_tween(i: int) -> Tween:
	if _music_tw[i] and _music_tw[i].is_valid():
		_music_tw[i].kill()
	_music_tw[i] = _music[i].create_tween()
	return _music_tw[i]


func play_music(id: String, fade := MUSIC_FADE) -> void:
	if id == music_id and (id == "" or _music[_music_cur].playing):
		return
	music_id = id
	var old := _music[_music_cur]
	if old.playing:
		var tw := _music_tween(_music_cur)
		tw.tween_property(old, "volume_db", -60.0, fade)
		tw.tween_callback(old.stop)
	if id == "" or not MUSIC.has(id) or not ResourceLoader.exists(MUSIC[id]):
		return
	var s := load(MUSIC[id]) as AudioStream
	if s is AudioStreamWAV:
		s = (s as AudioStreamWAV).duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(round(s.get_length() * s.mix_rate))
	elif s is AudioStreamOggVorbis or s is AudioStreamMP3:
		s = s.duplicate()
		s.set("loop", true)
	_music_cur = 1 - _music_cur
	var p := _music[_music_cur]
	var tw := _music_tween(_music_cur)
	p.stream = s
	p.volume_db = -60.0
	p.play()
	tw.tween_property(p, "volume_db", _music_target_db(), fade)


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


func _update_music(delta: float) -> void:
	_duck = move_toward(_duck, DUCK_DB if _music_ducked() else 0.0, 24.0 * delta)
	var p := _music[_music_cur]
	# 淡入的补间结束后才接手音量（不和补间抢）
	if p.playing and absf(p.volume_db - _music_target_db()) < 6.0:
		p.volume_db = _music_target_db()


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
	add_child(_voice)
	for i in 2:
		var mp := AudioStreamPlayer.new()
		mp.name = "Music%d" % i
		add_child(mp)
		_music.append(mp)
	var cfg := ConfigFile.new()
	if cfg.load(settings_path()) == OK:
		music_volume = float(cfg.get_value("audio", "music_volume", music_volume))
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(sound: String, volume_db := 0.0, pitch_jitter := 0.08, pitch := 1.0) -> void:
	if sound in ["giggle", "laugh"]:
		play_voice(sound)
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


## 笑声按当前操控的角色选：蓝色公主有自己的 blue_giggle / blue_laugh。
func voice_key(sound: String) -> String:
	if sound in ["giggle", "laugh"] and Characters.current() == "blue" and not _streams.get("blue_" + sound, []).is_empty():
		return "blue_" + sound
	return sound


## 取一个循环声音的流（吟唱、风扇、传送带），由调用者用自己的 AudioStreamPlayer(2D) 播放。
func loop_stream(sound: String) -> AudioStream:
	var list: Array = _streams.get(voice_key(sound), [])
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
	if get_tree().paused or sound != _voice_state or _voice.playing:
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
	if get_tree().paused or not is_instance_valid(GameState.player) or not GameState.player.is_alive():
		stop_voice()
	elif _voice_state == "laugh":
		# Resume after pause without waiting for a one-shot laugh timer.
		play_voice("laugh")

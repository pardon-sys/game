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
}
## 循环播放的声音（用 loop_stream 取流，挂到自己的播放器上）。
const LOOPED := ["laugh", "chant", "wind", "conveyor"]
const POOL_SIZE := 10

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _voice: AudioStreamPlayer
var _voice_state := ""


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
				list.append(s)
		_streams[key] = list
	_voice = AudioStreamPlayer.new()
	add_child(_voice)
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


## 取一个循环声音的流（吟唱、风扇、传送带），由调用者用自己的 AudioStreamPlayer(2D) 播放。
func loop_stream(sound: String) -> AudioStream:
	var list: Array = _streams.get(sound, [])
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
	var clips: Array = _streams.get(sound, [])
	if clips.is_empty():
		return
	_voice.stream = clips.pick_random()
	_voice.volume_db = -8.0
	_voice.pitch_scale = 1.0
	_voice.play()


func _process(_delta: float) -> void:
	if get_tree().paused or not is_instance_valid(GameState.player) or not GameState.player.is_alive():
		stop_voice()
	elif _voice_state == "laugh":
		# Resume after pause without waiting for a one-shot laugh timer.
		play_voice("laugh")

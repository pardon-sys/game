"""用 ElevenLabs 的音乐生成接口生成游戏配乐（2 分钟，首尾相连可循环），存成 assets/audio/music/<id>_loop.wav。

API key 从项目根目录的 .env 读（ELEVENLABS=...，.env 不进版本库）；只把下面的提示词发给 ElevenLabs，不发送任何项目文件。
接口：POST https://api.elevenlabs.io/v1/music/stream（prompt、music_length_ms、force_instrumental），output_format=pcm_44100（16 位立体声交错 PCM）。
首尾相连：生成的曲子结尾常有淡出 / 静音，所以先找循环点 T（find_loop_end：在淡出之前、节奏和和声都和开头最像的半句边界），
把 T 之后 CROSSFADE 秒和开头交叉淡化（等功率），T 之后的尾声丢掉——循环播放时无缝接回开头。
原始音频存在 tools/.cache/music/（不进版本库）。
用法：python tools/audio/gen_music.py [dungeon] [town] [boss] [boss3] [night_room] [night_maze] [siege] [minigame] [knight_boss]（不写就全部生成；已经生成过的跳过，加 --force 重新生成，
  加 --reloop 用缓存的原始音频重新切循环）
"""
import json
import os
import struct
import sys
import time
import wave
from pathlib import Path

import numpy as np
import requests

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/audio/music"
CACHE = ROOT / "tools/.cache/music"
RATE = 44100
CHANNELS = 2
LENGTH_MS = 140000   # 多要 20 秒：结尾的淡出尾声会被切掉，循环部分约 2 分钟
## 循环点在拍子上对齐了：短短交叉淡化一下就好（太长的话两段不一样的音乐叠在一起，会听成杂音）
CROSSFADE = 0.3

TRACKS = {
    "knight_boss": ("Instrumental video game boss battle music for a cute pixel-art game: two princesses fight a cursed suit of knight armor "
                    "possessed by glowing purple tickling hands, in a lantern-lit underground town plaza. The knight trapped inside is a loyal, "
                    "tragic figure, so the piece is heroic and urgent but carries a sorrowful, noble undertone. 140 BPM, minor key. Driving "
                    "staccato strings and marching snare, heavy low brass for the armor's stomps, a solemn horn melody like an old royal anthem "
                    "played in a sad minor mode, harpsichord ostinato, sparkling celesta and bell accents for the magic, a few playful pizzicato "
                    "flourishes so it never becomes truly grim. Builds tension, loops seamlessly, steady energy, no fade-in or fade-out."),
    "minigame": ("Instrumental video game background music for silly, playful little minigames in a cute pixel-art game about ticklish "
                 "princesses: light-hearted, bouncy and comedic, childlike and mischievous. 128 BPM, major key. Plucky pizzicato strings, "
                 "a bright glockenspiel and xylophone melody, a bouncy tuba / bassoon bass line, kazoo-like playful accents, woodblock and "
                 "light shaker percussion, occasional cartoon slide whistles and cheeky little pauses. Cheerful, giggly, a bit goofy, never "
                 "scary; loops seamlessly, steady energy, no fade-in or fade-out."),
    "night_maze": ("Instrumental video game background music for exploring a dark, living labyrinth at night, alone. A quiet princess walks "
                   "through moonlit stone corridors while invisible many-handed things wander in the darkness. Mood: mysterious, cold, "
                   "tense but restrained, with a thread of melancholy and longing, same melancholic minor key as a soft night lullaby. "
                   "A low, slow heartbeat-like pulse in the contrabass and soft timpani; sustained cold strings and airy pads; sparse, "
                   "distant fragments of an antique music box melody that drift in and out like memories; occasional glassy celesta "
                   "and harp glints like moonlight on stone. No drums kit, no fast rhythm. Around 70 BPM, sparse and atmospheric. "
                   "Seamless loop, consistent dynamics from start to end, no fade-out ending."),
    "night_room": ("Instrumental video game background music for a quiet, melancholic night scene: two princesses rest in a small, dusty, "
                   "long-abandoned bedroom hidden deep inside a dungeon tower, a room full of faded memories that one of them will not talk about. "
                   "Mood: wistful nostalgia and quiet sorrow, tender but heavy-hearted, like remembering someone you lost long ago; not playful, "
                   "not cute, not bouncy. Lead: slow, expressive solo cello and violin with long sustained legato lines in a minor key; warm "
                   "felt piano chords underneath; a distant, slightly detuned antique music box appears only occasionally and softly in the "
                   "background, like an echo of the past. No drums, no percussion, no pizzicato. Slow tempo around 60 BPM, sparse and intimate, "
                   "with breathing space between phrases. Seamless loop, consistent dynamics from start to end, no fade-out ending."),

    "dungeon": ("Instrumental video game background music for a cute pixel-art dungeon full of mischievous tickle traps. "
                "Mood: childlike and playful, sly and cunning, with an undercurrent of danger, and the clockwork feel of dungeon "
                "machinery. Music box and xylophone carry a bouncy, sneaky melody; pizzicato strings and a plucked upright bass "
                "tiptoe underneath; percussion made of ticking clocks, gear clicks, ratchets and wooden knocks; occasional low "
                "dissonant cello swells and a creeping chromatic line for danger. Moderate tempo around 100 BPM, minor key with "
                "playful major-key twists. No vocals. Loop-friendly: steady energy throughout, and end on the same chord and groove "
                "the piece begins with so it can loop seamlessly."),
    "town": ("Instrumental video game background music for a cozy underground town lit by lanterns, where a lost princess finds "
             "warmth and kind people. Mood: warm, safe, gently curious with a hint of mystery. Accordion and soft harp lead a "
             "friendly folk melody, light hand percussion and soft acoustic guitar strumming, a little glockenspiel sparkle, "
             "subtle low drone for the cave atmosphere. Relaxed tempo around 90 BPM, major key. No vocals. Loop-friendly: steady "
             "energy, end on the same chord and groove the piece begins with so it can loop seamlessly."),
    "boss": ("Instrumental video game boss battle music for a cute pixel-art game: two princesses fight a giant, many-handed tickle "
             "monster that was once someone dear. Mood: childlike and playful yet sly and cunning, dangerous, with a deep sense of fate "
             "and sorrow. A music box melody turned minor and urgent, driving pizzicato and staccato strings, dissonant low cello and "
             "contrabass, ticking clockwork and gear percussion with heavy taiko hits, wordless choir-like pads swelling with a fateful, "
             "bittersweet motif. Tempo around 110 BPM, minor key. No vocals or lyrics. Loop-friendly: steady high energy throughout, end "
             "on the same chord and groove the piece begins with so it can loop seamlessly."),
    "siege": ("Instrumental video game battle music for a cute pixel-art tower-defense siege: two princesses defend an underground "
              "town wall against waves of mischievous tickle monsters. Mood: childlike and playful, but grand, epic and martial, with "
              "constant tension. Bright xylophone, glockenspiel and piccolo flute carry a bouncy, cheeky march melody; a full "
              "orchestra answers with grand heroic brass fanfares, French horns and trombones; snare drum marching rolls, timpani and "
              "big war drums drive the rhythm; fast tense staccato string ostinatos underneath keep the pressure on, with occasional "
              "rising string swells for danger. Tempo around 128 BPM, major key with dramatic minor turns. No vocals or lyrics. "
              "Loop-friendly: constant high energy, no intro and no fade-out, end on the same chord and groove it begins with so it can "
              "loop seamlessly."),
    "boss3": ("Instrumental video game final-phase boss battle music, continuing the same piece as the previous boss theme: same tempo "
              "of 110 BPM, same minor key, same instruments (music box, pizzicato and staccato strings, low cello and contrabass, "
              "clockwork and gear percussion, taiko, wordless choir pads). Two princesses face a giant many-handed tickle monster that "
              "was once someone dear, now in its desperate final form. Mood: childlike motifs twisted into something extremely "
              "dangerous, fierce and intense battle energy, overwhelming sense of fate and sorrow. Faster rhythmic drive with double-time "
              "percussion and driving string ostinatos, the music box melody played higher and more frantic, the choir swelling in "
              "fateful bittersweet chords, heavy low brass-like stabs. No vocals or lyrics. Loop-friendly: constant high intensity, end on "
              "the same chord and groove it begins with so it can loop seamlessly."),
}


def api_key() -> str:
    env = ROOT / ".env"
    for line in env.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("ELEVENLABS") and "=" in line:
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    if os.environ.get("ELEVENLABS"):
        return os.environ["ELEVENLABS"]
    raise SystemExit("没有找到 ELEVENLABS（.env 或环境变量）")


def compose(prompt: str) -> bytes:
    """流式接口（/v1/music/stream）：边生成边传回，长时间生成时连接不会被代理当成空闲掐断；失败重试 3 次。"""
    body = json.dumps({"prompt": prompt, "music_length_ms": LENGTH_MS, "force_instrumental": True})
    last = None
    for attempt in range(3):
        try:
            with requests.post("https://api.elevenlabs.io/v1/music/stream", params={"output_format": "pcm_44100"},
                               headers={"xi-api-key": api_key(), "Content-Type": "application/json"},
                               data=body, timeout=(30, 300), stream=True) as r:
                if r.status_code != 200:
                    # 只打印状态码和服务端的错误说明，不打印请求头
                    raise SystemExit("ElevenLabs 返回 %d：%s" % (r.status_code, r.text[:400]))
                chunks = []
                for c in r.iter_content(chunk_size=65536):
                    if c:
                        chunks.append(c)
                data = b"".join(chunks)
                if len(data) < RATE * 2 * CHANNELS * 10:
                    raise RuntimeError("音频太短（%d 字节）" % len(data))
                return data
        except (requests.exceptions.RequestException, RuntimeError) as e:
            last = e
            print("  第 %d 次失败：%s，重试……" % (attempt + 1, type(e).__name__), flush=True)
            time.sleep(5)
    raise SystemExit("生成失败：%s" % type(last).__name__)


HOP = 441   # 10 毫秒一格的音量包络


def envelope(mono: np.ndarray) -> np.ndarray:
    k = len(mono) // HOP
    return np.sqrt((mono[:k * HOP].reshape(k, HOP) ** 2).mean(1))


def _spectrum(x: np.ndarray) -> np.ndarray:
    """一小段的对数频谱（4 kHz 以下，归一化）：比较两段的和声像不像。"""
    m = x.mean(1)
    f = np.log1p(np.abs(np.fft.rfft(m * np.hanning(len(m))))[:int(4000 * len(m) / RATE)])
    f = f - f.mean()
    return f / (np.linalg.norm(f) + 1e-9)


def find_loop_end(x: np.ndarray) -> int:
    """循环点：先从起音包络的自相关估出拍长（60~170 BPM），在尾声（音量掉到中位数六成以下的最后一段）之前、
    曲子 55% 以后的每个半句（8 拍）边界上打分，取最好的那个：
      节奏：循环点之后 WINDOW 秒的起音和开头的起音像不像（在 ±80 毫秒内微调对齐）；
      和声：循环点之后 1 秒和开头 1 秒的频谱像不像（循环时这一段会和开头交叉淡化，不像就会听成两首曲子叠在一起的杂音）。
    循环点前 3 秒里有停顿的不要（循环时不要出现一段空白）。"""
    mono = x.mean(1)
    env = envelope(mono)
    sec = 100   # 每秒 100 格
    loud = np.array([env[i:i + sec].mean() for i in range(0, len(env) - sec, sec)])
    med = float(np.median(loud))
    last_full = len(loud)
    while last_full > 0 and loud[last_full - 1] < med * 0.6:
        last_full -= 1
    window = 4 * sec
    end_limit = min(last_full * sec, len(env) - window - 1)
    onset = np.maximum(0.0, np.diff(env, prepend=env[0]))
    on = onset - onset.mean()
    m = min(len(on), 60 * sec)
    ac = np.correlate(on[:m], on[:m], "full")[m - 1:]
    lo, hi = int(sec * 60 / 170), int(sec * 60 / 60)
    beat = lo + int(np.argmax(ac[lo:hi]))
    l8 = np.arange(beat * 8 - 6, beat * 8 + 7)
    beat = l8[int(np.argmax(ac[l8]))] / 8.0        # 8 拍的自相关峰值求更准的拍长
    half = beat * 8
    ref = onset[:window]
    ref = (ref - ref.mean()) / (ref.std() + 1e-9)
    head = _spectrum(x[:RATE])
    quiet = med * 0.1
    best = (-1e9, 0, 0.0, 0.0)
    for k in range(int(np.ceil(len(env) * 0.55 / half)), int(np.floor(end_limit / half)) + 1):
        t0 = int(k * half)
        if min(env[t0 - 3 * sec + i:t0 - 3 * sec + i + 25].mean() for i in range(0, 3 * sec - 25, 5)) < quiet:
            continue
        rhythm, at = -1e9, t0
        for t in range(t0 - 8, t0 + 9):
            seg = onset[t:t + window]
            if len(seg) < window:
                continue
            seg = (seg - seg.mean()) / (seg.std() + 1e-9)
            c = float((seg * ref).mean())
            if c > rhythm:
                rhythm, at = c, t
        harmony = float((_spectrum(x[at * HOP:at * HOP + RATE]) * head).sum())
        score = rhythm + 1.5 * harmony
        if score > best[0]:
            best = (score, at, rhythm, harmony)
    _score, best_t, rhythm, harmony = best
    print("  %.1f BPM，循环点 %.2f 秒（尾声从 %.1f 秒开始），节奏吻合度 %.2f，和声相似 %.2f"
          % (6000.0 / beat, best_t / sec, end_limit / sec, rhythm, harmony))
    return best_t * HOP


def make_loop(pcm: bytes) -> np.ndarray:
    x = np.frombuffer(pcm[:len(pcm) // (2 * CHANNELS) * 2 * CHANNELS], dtype="<i2").astype(np.float32) / 32768.0
    x = x.reshape(-1, CHANNELS)
    n = int(CROSSFADE * RATE)
    if len(x) < n * 4:
        return x
    x = x[:find_loop_end(x) + n]       # T 之后 CROSSFADE 秒和开头重叠；再往后的尾声丢掉
    head, body, tail = x[:n], x[n:-n], x[-n:]
    t = np.linspace(0.0, np.pi / 2.0, n, dtype=np.float32)[:, None]
    mixed = tail * np.cos(t) + head * np.sin(t)      # 结尾淡出、开头淡入（等功率）
    # 循环：mixed 接在开头位置，后面是正文；正文的最后一个样本自然接回 mixed 的开头（= 原结尾）
    out = np.concatenate([mixed, body])
    peak = float(np.max(np.abs(out))) or 1.0
    return out * min(1.0, 0.95 / peak)


def save_wav(path: Path, x: np.ndarray) -> None:
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2").tobytes()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(CHANNELS)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm)


def main():
    want = [a for a in sys.argv[1:] if not a.startswith("--")] or list(TRACKS)
    force = "--force" in sys.argv
    # --reloop：用缓存的原始音频重新找循环点、重新切（不调接口）
    reloop = "--reloop" in sys.argv
    OUT.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    log = []
    for tid in want:
        out = OUT / ("%s_loop.wav" % tid)
        raw = CACHE / ("%s_raw.pcm" % tid)
        if out.exists() and not force and not reloop:
            print("跳过（已经有了）：", out.name)
            continue
        t0 = time.time()
        if raw.exists() and not force:
            pcm = raw.read_bytes()
        else:
            print("生成中：%s ……" % tid, flush=True)
            pcm = compose(TRACKS[tid][0] if isinstance(TRACKS[tid], tuple) else TRACKS[tid])
            raw.write_bytes(pcm)
        loop = make_loop(pcm)
        save_wav(out, loop)
        print("%s：原始 %.1f 秒 → 循环 %.1f 秒（用时 %.0f 秒）" % (tid, len(pcm) / 2 / CHANNELS / RATE, len(loop) / RATE, time.time() - t0))
        log.append((tid, len(loop) / RATE))
    return log


if __name__ == "__main__":
    main()

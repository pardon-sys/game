"""合成像素游戏音效（输出 assets/generated/sfx/*.wav，22050Hz 16bit 单声道）。

  tickle_1..4  挠痒："啵叽"果冻声（音高下滑 + 果冻颤动 + 湿润噪声），4 种变体
  web          吐丝："嘶"的短噪声
  puff         喷粉：柔和的"噗"
  swish        刷子扫过："唰"
  grab         抓住：低沉的"咚"+ 一下果冻声
  chant        吟唱：柔和的和弦嗡鸣（循环播放，按蓄力档位升调）
  star_burst   星光爆发：上扬的闪光 + 铃声
  fizzle       魔法落空 / 被打断：下滑的"噗嘶"
  pinch        钳钳蟹夹脚："咔嚓"
  vine         藤蔓缠绕：沙沙声
  wind         羽毛风扇：呼呼风声（循环）
  conveyor     传送带：咔嗒咔嗒（循环）
  chomp        宝箱怪合上嘴："啪嗒"
  chime        小精灵铃声
  pop          史莱姆分裂："啵"
  combo        组合技提示音：两声上扬

用法：python tools/art/gen_sfx.py
在游戏里通过 Audio.play("tickle", 音量, 抖动, 音高) 播放，怪物用不同音高区分（巨魔低沉、蝙蝠尖细）。
"""
import wave

import numpy as np

from palette import ROOT

RATE = 22050
OUT = ROOT / "assets/generated/sfx"
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(dur * RATE)) / RATE


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def env(t, attack, decay):
    e = np.minimum(t / attack, 1.0) * np.exp(-np.maximum(t - attack, 0) / decay)
    return e


def jelly(dur=0.24, f0=380.0, f1=160.0, wobble=24.0, wet=0.28, delay=0.0):
    """一声果冻"啵叽"：指数音高下滑 + 颤动 + 湿润噪声。"""
    t = t_axis(dur)
    freq = f1 + (f0 - f1) * np.exp(-t / (dur * 0.35))
    freq = freq * (1 + 0.06 * np.sin(2 * np.pi * wobble * t))  # 颤动
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    tone = np.sin(phase) + 0.35 * np.sin(2 * phase) + 0.12 * np.sin(3 * phase)
    am = 0.75 + 0.25 * np.sin(2 * np.pi * wobble * 0.9 * t)  # 果冻晃动的振幅
    noise = lowpass(rng.standard_normal(len(t)), 1400) * env(t, 0.004, 0.035)
    sig = (tone * am * env(t, 0.008, dur * 0.35) + wet * 3.0 * noise)
    if delay:
        sig = np.concatenate([np.zeros(int(delay * RATE)), sig])
    return sig


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def save(name, sig, gain=0.8):
    sig = sig / (np.abs(sig).max() + 1e-9) * gain
    fade = min(len(sig), int(0.01 * RATE))
    sig[-fade:] *= np.linspace(1, 0, fade)
    pcm = (sig * 32767).astype("<i2")
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def main():
    save("tickle_1", jelly())
    save("tickle_2", mix(jelly(0.18, 420, 200), jelly(0.16, 330, 170, delay=0.09) * 0.6))  # 两下"啵叽啵叽"
    save("tickle_3", jelly(0.2, 520, 260, wobble=30, wet=0.22))                           # 更高更弹
    t = t_axis(0.26)
    chirp = np.sin(2 * np.pi * np.cumsum(180 + 260 * (t / 0.26) ** 2) / RATE) * env(t, 0.1, 0.05) * 0.4
    save("tickle_4", mix(jelly(0.22, 400, 170, wobble=20), chirp))                         # 结尾上扬

    t = t_axis(0.2)
    save("web", highpass(rng.standard_normal(len(t)), 2500) * env(t, 0.01, 0.06), 0.5)
    t = t_axis(0.4)
    save("puff", lowpass(rng.standard_normal(len(t)), 700) * env(t, 0.05, 0.12), 0.6)
    t = t_axis(0.3)
    sweep = rng.standard_normal(len(t))
    swish = highpass(lowpass(sweep, 3000), 600) * np.sin(np.pi * t / 0.3) ** 2
    save("swish", swish, 0.5)
    t = t_axis(0.3)
    thump = np.sin(2 * np.pi * np.cumsum(90 * np.exp(-t / 0.2) + 40) / RATE) * env(t, 0.005, 0.08)
    save("grab", mix(thump, jelly(0.22, 300, 130, delay=0.05) * 0.5))
    gen_expansion_sfx()
    print("音效已生成：", sorted(p.name for p in OUT.glob("*.wav")))


def tone(freqs, dur, attack=0.01, decay=0.2):
    t = t_axis(dur)
    sig = sum(np.sin(2 * np.pi * f * t) for f in freqs)
    return sig * env(t, attack, decay)


def seamless(sig, xfade=0.05):
    """把首尾交叉淡化，便于循环播放。"""
    n = int(xfade * RATE)
    head, body = sig[:n], sig[n:].copy()
    body[-n:] = body[-n:] * np.linspace(1, 0, n) + head * np.linspace(0, 1, n)
    return body


def save_loop(name, sig, gain=0.8):
    sig = sig / (np.abs(sig).max() + 1e-9) * gain
    pcm = (sig * 32767).astype("<i2")
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def gen_expansion_sfx():
    # 吟唱：C 大三和弦 + 轻微颤音，1.2 秒循环
    t = t_axis(1.25)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5 * t)
    chant = sum(np.sin(2 * np.pi * np.cumsum(f * vib) / RATE) * a for f, a in ((261.6, 1), (329.6, 0.7), (392, 0.6), (523.2, 0.3)))
    chant *= 0.8 + 0.2 * np.sin(2 * np.pi * 0.8 * t)
    save_loop("chant", seamless(chant), 0.45)
    # 星光爆发
    t = t_axis(0.7)
    rise = np.sin(2 * np.pi * np.cumsum(600 + 1400 * (1 - np.exp(-t / 0.08))) / RATE) * env(t, 0.005, 0.12)
    bells = mix(tone([1318, 1976], 0.7, 0.003, 0.25), np.concatenate([np.zeros(int(0.08 * RATE)), tone([1568, 2349], 0.6, 0.003, 0.22)]))
    boom = lowpass(rng.standard_normal(len(t)), 900) * env(t, 0.003, 0.09)
    save("star_burst", mix(rise * 0.6, bells * 0.5, boom * 0.8))
    # 落空
    t = t_axis(0.35)
    fz = np.sin(2 * np.pi * np.cumsum(700 * np.exp(-t / 0.12) + 120) / RATE) * env(t, 0.005, 0.1)
    save("fizzle", mix(fz, highpass(rng.standard_normal(len(t)), 2000) * env(t, 0.01, 0.08) * 0.4), 0.55)
    # 夹钳
    t = t_axis(0.18)
    click = highpass(rng.standard_normal(len(t)), 3000) * env(t, 0.001, 0.015)
    save("pinch", mix(click, np.concatenate([np.zeros(int(0.05 * RATE)), click[: int(0.1 * RATE)] * 0.7]), jelly(0.16, 520, 300) * 0.35), 0.7)
    # 藤蔓沙沙
    t = t_axis(0.5)
    rustle = highpass(lowpass(rng.standard_normal(len(t)), 5000), 1200) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 9 * t))) * env(t, 0.05, 0.2)
    save("vine", rustle, 0.5)
    # 风（循环）
    t = t_axis(1.6)
    wind = lowpass(rng.standard_normal(len(t)), 500) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.7 * t))
    save_loop("wind", seamless(wind, 0.2), 0.4)
    # 传送带（循环）：规律的咔嗒 + 低鸣
    t = t_axis(1.2)
    belt = np.zeros(len(t))
    for k in range(8):
        i = int(k * 0.15 * RATE)
        c = highpass(rng.standard_normal(int(0.03 * RATE)), 1500) * np.exp(-np.arange(int(0.03 * RATE)) / (0.006 * RATE))
        belt[i:i + len(c)] += c
    belt += np.sin(2 * np.pi * 70 * t) * 0.15
    save_loop("conveyor", belt, 0.4)
    # 宝箱怪合嘴
    t = t_axis(0.25)
    chomp = mix(np.sin(2 * np.pi * np.cumsum(160 * np.exp(-t / 0.05) + 60) / RATE) * env(t, 0.002, 0.06),
                highpass(rng.standard_normal(len(t)), 1800) * env(t, 0.001, 0.02) * 0.6)
    save("chomp", chomp, 0.8)
    # 精灵铃声
    save("chime", mix(tone([2093, 3136], 0.5, 0.002, 0.12), np.concatenate([np.zeros(int(0.06 * RATE)), tone([2637], 0.4, 0.002, 0.1)])), 0.4)
    # 分裂"啵"
    save("pop", mix(jelly(0.14, 700, 300, wobble=40, wet=0.1), jelly(0.14, 600, 280, wobble=36, wet=0.1, delay=0.07)), 0.6)
    # 组合技提示
    save("combo", mix(tone([784, 1175], 0.3, 0.003, 0.08), np.concatenate([np.zeros(int(0.1 * RATE)), tone([1047, 1568], 0.4, 0.003, 0.14)])), 0.6)


if __name__ == "__main__":
    main()

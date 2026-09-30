"""合成像素游戏音效（输出 assets/generated/sfx/*.wav，22050Hz 16bit 单声道）。

  tickle_1..4  挠痒："啵叽"果冻声（音高下滑 + 果冻颤动 + 湿润噪声），4 种变体
  web          吐丝："嘶"的短噪声
  puff         喷粉：柔和的"噗"
  swish        刷子扫过："唰"
  grab         抓住：低沉的"咚"+ 一下果冻声

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
    print("音效已生成：", sorted(p.name for p in OUT.glob("*.wav")))


if __name__ == "__main__":
    main()

"""Extract CC0 cicifyre laughter from the original ZIP; no speech clips are used.
Usage: python tools/art/import_voice.py tools/.cache/audio/bright.zip
Source and license: assets/third_party/cicifyre_voice/License.txt
"""
import sys
import struct
import wave
import zipfile
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/third_party/cicifyre_voice'


def convert(blob, output):
    pos = 12
    data = None
    while pos + 8 <= len(blob):
        tag = blob[pos:pos+4]
        size = struct.unpack_from('<I', blob, pos+4)[0]
        chunk = blob[pos+8:pos+8+size]
        if tag == b'fmt ':
            fmt, channels, rate, _, _, bits = struct.unpack_from('<HHIIHH', chunk)
        elif tag == b'data':
            data = chunk
        pos += 8 + size + size % 2
    assert fmt == 3 and bits == 32 and data is not None, 'Expected source float32 WAV'
    samples = np.frombuffer(data, dtype='<f4').reshape(-1, channels).mean(axis=1)
    active = np.flatnonzero(np.abs(samples) > 0.015)
    assert len(active), 'Silent source'
    start = max(0, active[0] - int(rate * 0.08))
    end = min(len(samples), active[-1] + int(rate * 0.12))
    samples = samples[start:end].copy()
    samples *= (10 ** (-3 / 20)) / np.max(np.abs(samples))
    fade = min(int(rate * 0.01), len(samples)//2)
    samples[:fade] *= np.linspace(0, 1, fade)
    samples[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(str(output), 'wb') as w:
        w.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        w.writeframes((samples * 32767).astype('<i2').tobytes())
    print(output.name, round(len(samples)/rate, 3), 'seconds')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(sys.argv[1]) as archive:
        for source, target in [('02-laughter.wav', 'giggle.wav'), ('03-laughter.wav', 'laugh.wav')]:
            convert(archive.read('Free Voice Clips Pack - Bright Female/' + source), OUT / target)


if __name__ == '__main__':
    main()

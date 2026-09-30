"""Build a continuous CC0 laugh loop from moxobna's public HQ preview.
Decode first: afconvert -f WAVE -d LEI16 source.mp3 source.wav
Usage: python tools/art/build_laugh_loop.py source.wav
Provenance: assets/third_party/moxobna_voice/License.txt
"""
import sys
import wave
from pathlib import Path
import numpy as np

OUT = Path(__file__).resolve().parents[2] / 'assets/third_party/moxobna_voice/laugh_loop.wav'


def main():
    with wave.open(sys.argv[1]) as w:
        rate = w.getframerate()
        assert w.getsampwidth() == 2
        pcm = np.frombuffer(w.readframes(w.getnframes()), dtype='<i2')
        audio = pcm.reshape(-1, w.getnchannels()).mean(1) / 32768.0
    audio = audio[round(52.3 * rate):round(60.3 * rate)]
    hop = round(rate * .02)
    energy = np.array([np.sqrt(np.mean(audio[i:i+hop]**2)) for i in range(0,len(audio),hop)])
    # Preserve syllables and short breaths; remove long pauses between bouts.
    voiced = np.convolve((energy > .006).astype(int), np.ones(7,dtype=int), 'same') > 0
    edges = np.diff(np.r_[False, voiced, False].astype(int))
    runs = list(zip(np.flatnonzero(edges == 1), np.flatnonzero(edges == -1)))
    parts = [audio[a*hop:min(b*hop,len(audio))] for a,b in runs if (b-a)*hop > .12*rate]
    cross = round(rate*.04)
    joined = parts[0]
    for part in parts[1:]:
        n = min(cross,len(joined)//2,len(part)//2)
        f = np.linspace(0,1,n)
        joined = np.r_[joined[:-n],joined[-n:]*(1-f)+part[:n]*f,part[n:]]
    # Circular overlap-add: no silent padding or discontinuity at the wrap.
    f = np.linspace(0,1,cross)
    joined = np.r_[joined[cross:-cross],joined[-cross:]*(1-f)+joined[:cross]*f]
    joined *= 10**(-3/20) / np.max(np.abs(joined))
    OUT.parent.mkdir(parents=True,exist_ok=True)
    with wave.open(str(OUT),'wb') as w:
        w.setparams((1,2,rate,0,'NONE','not compressed'))
        w.writeframes((joined*32767).astype('<i2').tobytes())
    print('Loop seconds:',round(len(joined)/rate,3),'joined bouts:',len(parts))
    print('Boundary step:',round(abs(float(joined[-1]-joined[0])),6))


if __name__ == '__main__':
    main()

"""배경음악을 끊김 없이 이어지는 반복용 ogg로 만든다 (고닷 11단계, 사용자 요청: 소리가 비는 구간 없이 쭉 이어지게).
원곡(Bgm_Monume.mp3)의 잔잔한 앞부분 0~16.5초(드럼 "딩"이 16.75초에 들어오기 전)만 쓴다.
끝 1.5초를 처음 1.5초와 크로스페이드(맞물려 섞기)해서 "끝 → 처음"이 같은 소리로 이어지게 하고, 길이 15초의 반복 조각을 만든다.
고닷에서는 이 파일을 loop=true 로 틈 없이 반복 재생(sound.gd). 예전처럼 반복할 때 소리를 줄였다 키우지 않는다.
사용: python tools/make_bgm_loop.py  (ffmpeg 필요)"""
import os, subprocess, sys
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "fish game", "Assets", "Audio", "Bgm_Monume.mp3")
DST = os.path.join(ROOT, "godot", "assets", "audio", "bgm_loop.ogg")
RATE = 44100
USE = 16.5      # 쓰는 앞부분(초)
FADE = 1.5      # 이음새 크로스페이드(초)
LOOP = USE - FADE   # 반복 조각 길이 = 15.0초

raw = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", SRC, "-t", str(USE), "-f", "f32le", "-ac", "2", "-ar", str(RATE), "-"],
                     check=True, capture_output=True).stdout
s = np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()
n_use, n_fade = int(USE * RATE), int(FADE * RATE)
assert len(s) >= n_use - 2, "원곡이 16.5초보다 짧아요"
s = s[:n_use]
n_loop = n_use - n_fade
t = np.linspace(0.0, np.pi / 2.0, n_fade, dtype=np.float32)[:, None]
fade_out, fade_in = np.cos(t), np.sin(t)               # 소리 크기가 일정하게 들리는 크로스페이드(등전력)
seam = s[n_loop:n_use] * fade_out + s[:n_fade] * fade_in    # 조각 끝 = (원래 끝 → 서서히) + (원래 처음 ← 서서히)
loop = np.concatenate([s[n_fade:n_loop], seam], axis=0)     # 가운데 + 이음새 = 15초
os.makedirs(os.path.dirname(DST), exist_ok=True)
p = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "f32le", "-ac", "2", "-ar", str(RATE), "-i", "-", "-c:a", "libvorbis", "-q:a", "4", DST],
                   input=loop.astype(np.float32).tobytes(), check=True)
print("ok", DST, "%.2f초" % (len(loop) / RATE), os.path.getsize(DST), "바이트")

"""고닷 포팅 밑작업(docs/GODOT_PORT.md): 유니티 프로젝트의 에셋을 godot/assets/ 로 모은다. 원본은 건드리지 않고 복사만 한다.

실행(저장소 루트 fishing-game/ 에서):
  python tools/export_assets_for_godot.py --dry-run   # 무엇을 복사할지 목록만 보기
  python tools/export_assets_for_godot.py             # 실제로 복사 (약 6MB)
- 모델: FBX는 그대로 복사(고닷이 FBX를 바로 읽음). 블렌더 원본 작업 파일은 blender/ 에 있음.
- BGM: 원곡은 131초지만 게임은 앞 16.5초만 반복하므로 ffmpeg로 16.5초만 잘라 ogg로 저장(약 0.2MB). ffmpeg가 없으면 원곡을 복사하고 알려 줌.
- 글꼴: 주아(OFL). 라이선스 문구 파일도 같이 복사.
- 효과음: 파일이 아니라 코드(SfxSynth.cs)가 만드는 소리라서 여기서 복사하지 않음. 이미 godot/assets/audio/sfx/ 에 WAV로 뽑아 둠(유니티에서 GodotExport.DumpSfx).
"""
import os, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.path.join(ROOT, "fish game", "Assets")
OUT = os.path.join(ROOT, "godot", "assets")
DRY = "--dry-run" in sys.argv


def copy(src, dst_rel):
    dst = os.path.join(OUT, dst_rel)
    print(("[dry] " if DRY else "") + "copy", os.path.relpath(src, ROOT), "->", os.path.relpath(dst, ROOT))
    if DRY:
        return
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)


def copy_tree(sub, dst_sub, exts):
    base = os.path.join(A, sub)
    n = 0
    for dp, _, files in os.walk(base):
        for f in sorted(files):
            if f.lower().endswith(exts):
                rel = os.path.relpath(os.path.join(dp, f), base)
                copy(os.path.join(dp, f), os.path.join(dst_sub, rel))
                n += 1
    return n


n_models = copy_tree("Models", "models", (".fbx",))                  # 섬, 오두막, 부두, 배, NPC, 소품(Props/)
n_models += copy_tree(os.path.join("Resources", "Models"), "models/extra", (".fbx",))   # 낚싯대, 집 장식, 갈매기·병·보트
n_fish = copy_tree("Fish", "fish", (".png",))                        # 도감 물고기 그림 16장(Fish_01~16)

font = os.path.join(A, "Resources", "Fonts")
for f in ("Jua-Regular.ttf", "OFL_Jua.txt"):
    copy(os.path.join(font, f), os.path.join("fonts", f))

bgm = os.path.join(A, "Audio", "Bgm_Monume.mp3")
dst = os.path.join(OUT, "audio", "bgm_loop.ogg")
print(("[dry] " if DRY else "") + "trim 16.5s", os.path.relpath(bgm, ROOT), "->", os.path.relpath(dst, ROOT))
if not DRY:
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    try:
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", bgm, "-t", "16.5", "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
    except (OSError, subprocess.CalledProcessError) as e:
        print("ffmpeg로 자르지 못해 원곡을 복사합니다(고닷에서 앞 16.5초만 반복하게 따로 처리 필요):", e)
        copy(bgm, os.path.join("audio", "Bgm_Monume.mp3"))

print("done:", n_models, "models,", n_fish, "fish images", "(dry run)" if DRY else "")

"""유니티 재질(.mat)의 색·반짝임을 godot/data/materials.json 으로 뽑는다 (고닷 포팅 2단계, docs/GODOT_PORT.md).
실행: python tools/extract_materials.py   (저장소 루트 fishing-game/ 에서)
고닷에서는 FBX 안의 재질 이름(Mat_Grass 등)과 같은 이름으로 찾아서 색을 덮어쓴다.
"""
import glob, json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MATS = os.path.join(ROOT, "fish game", "Assets", "Materials")
OUT = os.path.join(ROOT, "godot", "data", "materials.json")


def color(block, key):
    m = re.search(r"- %s: \{r: ([-\d.e]+), g: ([-\d.e]+), b: ([-\d.e]+), a: ([-\d.e]+)\}" % key, block)
    return [float(m.group(i)) for i in range(1, 5)] if m else None


def number(block, key):
    m = re.search(r"- %s: ([-\d.e]+)" % key, block)
    return float(m.group(1)) if m else None


out = {}
for f in sorted(glob.glob(os.path.join(MATS, "*.mat"))):
    s = open(f, encoding="utf-8").read()
    name = re.search(r"m_Name: (\S+)", s).group(1)
    shader = re.search(r"m_Shader: \{fileID: (-?\d+), guid: (\w+)", s)
    base = color(s, "_BaseColor") or color(s, "_Color")
    emis = color(s, "_EmissionColor")
    out[name] = {
        "base_color": base,
        "smoothness": number(s, "_Smoothness"),
        "metallic": number(s, "_Metallic"),
        "emission": emis if emis and any(emis[:3]) else None,
        "surface": number(s, "_Surface"),          # 0 불투명, 1 투명
        "alpha_clip": number(s, "_AlphaClip"),
        "cull": number(s, "_Cull"),                # 2 = 앞면만(기본), 0 = 양면
        "shader_guid": shader.group(2) if shader else None,
        "file": os.path.basename(f),
    }
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
    json.dump(out, fh, ensure_ascii=False, indent=1)
    fh.write("\n")
print("wrote", OUT, len(out), "materials")

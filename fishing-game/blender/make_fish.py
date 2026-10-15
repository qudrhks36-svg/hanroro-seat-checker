import bpy, bmesh, math, sys, os

OUT = os.environ.get("FISH_OUT", r"C:\Users\qudrh\AppData\Local\Temp\claude\shots\fish")
os.makedirs(OUT, exist_ok=True)
_mats = {}

def mat(c):
    key = tuple(round(v, 3) for v in c)
    if key in _mats: return _mats[key]
    m = bpy.data.materials.new("m%d" % len(_mats))
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1)
    b.inputs["Roughness"].default_value = 0.85
    _mats[key] = m
    return m

def finish(o, c):
    o.data.materials.clear(); o.data.materials.append(mat(c))
    for p in o.data.polygons: p.use_smooth = False
    return o

def sphere(loc, sc, c, sub=2, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=1, location=loc, rotation=rot)
    o = bpy.context.active_object; o.scale = sc
    return finish(o, c)

def cone(loc, rot, r, depth, c, verts=5, r2=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot)
    return finish(bpy.context.active_object, c)

def tail(tip, theta_deg, r, depth, c, flat=0.22):
    t = math.radians(theta_deg); d = (math.sin(t), 0, math.cos(t))
    o = cone((tip[0] - d[0] * depth / 2, tip[1], tip[2] - d[2] * depth / 2), (0, t, 0), r, depth, c, 4)
    o.scale.y = flat
    return o

def eye(loc, s=0.16):
    sphere(loc, (s, s * 0.7, s), (1, 1, 1), 1)
    sphere((loc[0] + s * 0.25, loc[1] - s * 0.55, loc[2]), (s * 0.55, s * 0.35, s * 0.55), (0.07, 0.07, 0.12), 1)

def clear():
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete()

def setup(center_z, scale, cx=0.0):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"; sc.cycles.samples = 32; sc.cycles.device = "CPU"
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = 512
    sc.render.image_settings.file_format = "PNG"; sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.85, 0.88, 0.95, 1); bg.inputs[1].default_value = 0.42
    bpy.ops.object.light_add(type="SUN", location=(-4, -6, 7), rotation=(math.radians(50), 0, math.radians(-25)))
    bpy.context.active_object.data.energy = 2.4
    bpy.ops.object.camera_add(location=(cx, -12, center_z), rotation=(math.radians(90), 0, 0))
    cam = bpy.context.active_object; cam.data.type = "ORTHO"; cam.data.ortho_scale = scale
    sc.camera = cam

def render(name):
    bpy.context.scene.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)

# ---------- 9 해마 ----------
def seahorse():
    clear(); setup(0.45, 3.9)
    body = (0.98, 0.5, 0.12); belly = (1.0, 0.8, 0.42); fin = (1.0, 0.45, 0.35)
    pts = [((0.45, 0, 1.55), 0.42), ((0.28, 0, 1.2), 0.34), ((0.2, 0, 0.82), 0.5), ((0.22, 0, 0.3), 0.46),
           ((0.1, 0, -0.15), 0.36), ((-0.2, 0, -0.52), 0.3), ((-0.58, 0, -0.62), 0.25), ((-0.8, 0, -0.35), 0.2), ((-0.68, 0, -0.08), 0.15)]
    for i, (p, r) in enumerate(pts):
        sphere(p, (r * (1.25 if i == 0 else 1.0), r * 0.85, r * (1.15 if i == 0 else 1.0)), belly if 2 <= i <= 3 else body, 2)
    cone((1.0, 0, 1.42), (0, math.radians(90), 0), 0.18, 0.85, (1.0, 0.55, 0.15), 6, 0.08)   # 주둥이
    tail((0.0, 0.0, 0.8), -90, 0.45, 0.55, fin)        # 등지느러미
    for z in (1.85, 1.7):
        cone((0.35, 0, z), (0, 0, 0), 0.12, 0.3, fin, 4)                      # 머리 장식
    sphere((0.55, -0.34, 1.35), (0.16, 0.06, 0.12), (1.0, 0.6, 0.65), 1)    # 볼
    eye((0.55, -0.3, 1.62), 0.16)
    render("Fish_09_Seahorse.png")

# ---------- 10 해파리 ----------
def jelly():
    clear(); setup(-0.35, 3.3)
    dome = (0.95, 0.5, 0.78); rim = (0.75, 0.3, 0.65); tent = (1.0, 0.6, 0.85)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1, location=(0, 0, 0.0))
    o = bpy.context.active_object; o.scale = (1.0, 1.0, 0.8)
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.02], context="VERTS")
    bm.to_mesh(o.data); bm.free(); finish(o, dome)
    cone((0, 0, 0.0), (0, 0, 0), 1.08, 0.18, rim, 10, 1.08)
    for i, x in enumerate((-0.7, -0.35, 0.0, 0.35, 0.7)):
        L = 1.0 + 0.5 * ((i % 2) == 0)
        cone((x, 0.0, -0.1 - L / 2), (math.radians(180), 0, 0), 0.17, L, tent, 5, 0.05)
    for x in (-0.5, 0.5):
        cone((x, 0.25, -0.1 - 0.45), (math.radians(180), 0, 0), 0.13, 0.9, rim, 4, 0.04)
    eye((-0.32, -0.86, 0.36), 0.14); eye((0.32, -0.86, 0.36), 0.14)
    sphere((0, -0.95, 0.2), (0.1, 0.05, 0.05), (1.0, 0.5, 0.6), 1)
    render("Fish_10_Jelly.png")

# ---------- 11 달빛고기 ----------
def moonfish():
    clear(); setup(0.0, 5.0, -0.5)
    body = (0.74, 0.84, 1.0); crater = (0.55, 0.68, 0.92); fin = (1.0, 0.88, 0.5)   # 푸른 은빛 몸 + 노란 초승달 꼬리(복어와 구별)
    sphere((0.1, 0, 0), (1.25, 0.45, 0.9), body, 3)
    for (x, z, s) in ((-0.1, 0.35, 0.22), (0.3, -0.3, 0.17), (-0.45, -0.25, 0.14)):
        sphere((x, -0.46, z), (s, 0.05, s), crater, 1)
    tail((-1.0, 0, 0.1), 115, 0.45, 1.3, fin)    # 초승달 꼬리 위
    tail((-1.0, 0, -0.1), 65, 0.45, 1.3, fin)    # 초승달 꼬리 아래
    cone((0.0, 0, 1.15), (0, 0, 0), 0.3, 0.55, fin, 4)
    cone((0.1, 0, -1.0), (math.radians(180), 0, 0), 0.25, 0.45, fin, 4)             # 배지느러미
    sphere((0.75, -0.2, 0.62), (0.2, 0.05, 0.2), (1, 1, 1), 1)                       # 이마 별빛
    cone((0.75, -0.25, 0.62), (math.radians(90), 0, 0), 0.08, 0.5, (1, 1, 0.85), 4)
    sphere((0.78, -0.42, -0.18), (0.16, 0.06, 0.12), (1.0, 0.65, 0.7), 1)
    eye((0.92, -0.38, 0.12), 0.17)
    render("Fish_11_Moonfish.png")

# ---------- 12 무지개고기 ----------
def rainbow():
    clear(); setup(0.0, 5.0, -0.5)
    cols = [(0.95, 0.25, 0.3), (1.0, 0.55, 0.2), (1.0, 0.85, 0.25), (0.45, 0.8, 0.4), (0.3, 0.7, 0.95), (0.4, 0.4, 0.85), (0.7, 0.4, 0.85)]
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1, location=(0.1, 0, 0))
    o = bpy.context.active_object; o.scale = (1.35, 0.5, 0.82)
    o.data.materials.clear()
    for c in cols: o.data.materials.append(mat(c))
    for p in o.data.polygons:
        z = sum(o.data.vertices[i].co.z for i in p.vertices) / len(p.vertices)   # 로컬 좌표 -1..1
        p.material_index = min(6, max(0, int((1 - (z + 1) / 2) * 7)))
        p.use_smooth = False
    tc = (1.0, 0.5, 0.75)
    tail((-1.2, 0, 0.05), 115, 0.5, 1.4, tc)
    tail((-1.2, 0, -0.05), 65, 0.5, 1.4, tc)
    cone((0.0, 0, 0.85), (0, 0, 0), 0.32, 0.5, (0.7, 0.4, 0.85), 4)
    cone((0.1, 0, -0.85), (math.radians(180), 0, 0), 0.26, 0.4, (0.95, 0.25, 0.3), 4)
    sphere((0.85, -0.42, -0.15), (0.16, 0.06, 0.12), (1.0, 0.65, 0.75), 1)
    eye((1.0, -0.4, 0.18), 0.17)
    render("Fish_12_Rainbow.png")


def two_tone(o, top, bottom, split=0.0):
    """위쪽(z > split)은 top, 아래는 bottom 색으로 면을 나눠 칠한다(로컬 z 기준)."""
    o.data.materials.clear(); o.data.materials.append(mat(top)); o.data.materials.append(mat(bottom))
    for p in o.data.polygons:
        z = sum(o.data.vertices[i].co.z for i in p.vertices) / len(p.vertices)
        p.material_index = 0 if z > split else 1
        p.use_smooth = False

def tail_fin(tip, theta_deg, r, depth, c, flat=0.2):
    t = math.radians(theta_deg); d = (math.sin(t), 0, math.cos(t))
    o = cone((tip[0] - d[0] * depth / 2, tip[1], tip[2] - d[2] * depth / 2), (0, t, 0), r, depth, c, 4)
    o.scale.y = flat
    return o

def cone(loc, rot, r, depth, c, verts=5, r2=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot)
    return finish(bpy.context.active_object, c)

# ---------- 13 참치 ----------
def tuna():
    clear(); setup(0.0, 5.2, -0.3)
    blue = (0.1, 0.22, 0.44); silver = (0.8, 0.86, 0.93); yellow = (1.0, 0.85, 0.3)
    o = sphere((0.0, 0, 0), (1.5, 0.5, 0.58), blue, 3); two_tone(o, blue, silver, -0.1)
    tail_fin((-1.35, 0, 0.1), 115, 0.55, 1.2, blue); tail_fin((-1.35, 0, -0.1), 65, 0.55, 1.2, blue)
    fin_up(-0.1, 0.55, 0.38, 0.75, blue)                                   # 등지느러미(몸에서 위로 솟음)
    for i, x in enumerate((-0.6, -0.85, -1.1)):                              # 등 뒤 작은 노란 지느러미들
        cone((x, 0, 0.42 - i * 0.03), (0, 0, 0), 0.07, 0.18, yellow, 4)
    tail_fin((0.45, 0, -0.5), 0, 0.22, 0.5, silver, 0.15)
    tail_fin((0.3, -0.4, -0.15), -75, 0.2, 0.55, silver, 0.2)                # 가슴지느러미
    sphere((1.0, -0.38, 0.12), (0.19, 0.06, 0.19), (1, 1, 1), 1)
    sphere((1.05, -0.43, 0.12), (0.1, 0.04, 0.1), (0.08, 0.08, 0.12), 1)
    sphere((1.2, -0.3, -0.12), (0.12, 0.05, 0.08), (1.0, 0.65, 0.7), 1)
    render("Fish_13_Tuna.png")

# ---------- 14 청새치 ----------
def marlin():
    clear(); setup(0.1, 6.2, 0.2)
    blue = (0.08, 0.2, 0.5); silver = (0.85, 0.9, 0.96); sail = (0.2, 0.4, 0.8)
    o = sphere((0.0, 0, 0), (1.5, 0.38, 0.5), blue, 3); two_tone(o, blue, silver, -0.1)
    cone((2.15, 0, 0.05), (0, math.radians(90), 0), 0.12, 1.5, (0.2, 0.22, 0.3), 6, 0.0)   # 긴 주둥이
    sphere((1.2, -0.3, 0.12), (0.15, 0.05, 0.15), (1, 1, 1), 1)
    sphere((1.25, -0.34, 0.12), (0.085, 0.04, 0.085), (0.08, 0.08, 0.12), 1)
    fin_up(0.1, 0.47, 0.95, 0.75, sail)                                    # 커다란 돛 모양 등지느러미
    tail_fin((-1.45, 0, 0.1), 118, 0.5, 1.3, blue); tail_fin((-1.45, 0, -0.1), 62, 0.5, 1.3, blue)
    tail_fin((0.4, 0, -0.5), 0, 0.22, 0.5, silver, 0.15)
    tail_fin((0.5, -0.33, -0.15), -75, 0.18, 0.55, silver, 0.2)
    for i, x in enumerate((-0.3, 0.1, 0.5, 0.9)):                            # 옆구리 줄무늬
        box_(x, -0.3, 0.05, 0.12, 0.03, 0.7, (0.5, 0.65, 0.95))
    render("Fish_14_Marlin.png")

def fin_up(x, z_top, r, depth, c, flat=0.12):
    """몸 위(z_top)에서 위로 솟는 납작한 삼각 지느러미(아래쪽이 넓어 몸에 붙음)."""
    o = cone((x, 0, z_top + depth / 2 - 0.08), (0, 0, 0), r, depth + 0.08, c, 4)
    o.scale.y = flat
    return o

def box_(x, y, z, sx, sy, sz, rgb):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z))
    o = bpy.context.active_object; o.scale = (sx, sy, sz)
    return finish(o, rgb)

# ---------- 15 초롱아귀 ----------
def angler():
    clear(); setup(0.35, 4.6, 0.2)
    body = (0.42, 0.28, 0.55); dark = (0.28, 0.18, 0.4); glow = (1.0, 0.95, 0.45)
    sphere((0.0, 0, 0), (1.05, 0.7, 0.85), body, 3)
    sphere((0.35, -0.3, -0.35), (0.7, 0.42, 0.3), dark, 2)                  # 아래턱(벌린 큰 입)
    for i in range(6):                                                         # 뾰족한 이빨
        x = 0.4 + i * 0.12
        cone((x, -0.28, -0.06), (math.radians(180), 0, 0), 0.04, 0.16, (1.0, 0.98, 0.9), 4)
        cone((x - 0.03, -0.28, -0.3), (0, 0, 0), 0.04, 0.16, (1.0, 0.98, 0.9), 4)
    st = cone((0.8, 0, 1.08), (0, math.radians(50), 0), 0.05, 0.78, dark, 4, 0.02)      # 머리 위에서 앞으로 휘는 낚싯대 줄기(끝 = 등불 자리)
    sphere((1.12, 0, 1.38), (0.2, 0.2, 0.2), glow, 2)                         # 반짝이는 등불
    sphere((1.12, 0, 1.38), (0.3, 0.3, 0.3), (1.0, 0.98, 0.7), 1)
    sphere((0.7, -0.5, 0.25), (0.26, 0.1, 0.26), (1, 1, 1), 1)
    sphere((0.78, -0.58, 0.25), (0.14, 0.06, 0.14), (0.08, 0.08, 0.12), 1)
    tail_fin((-1.0, 0, 0.0), 90, 0.45, 0.8, dark)
    tail_fin((-0.1, 0, 0.8), 0, 0.3, 0.45, dark, 0.15)
    render("Fish_15_Angler.png")

# ---------- 16 별고래 ----------
def whale():
    clear(); setup(0.1, 5.2, 0.0)
    blue = (0.5, 0.7, 1.0); belly = (0.95, 0.97, 1.0); gold = (1.0, 0.88, 0.35)
    o = sphere((0.0, 0, 0), (1.25, 0.75, 0.8), blue, 3); two_tone(o, blue, belly, -0.15)
    sphere((-1.25, 0, 0.2), (0.7, 0.4, 0.4), blue, 2)                         # 꼬리 쪽
    tail_fin((-1.7, 0, 0.35), 120, 0.55, 0.9, blue, 0.18); tail_fin((-1.7, 0, 0.25), 60, 0.55, 0.9, blue, 0.18)   # 위로 솟은 꼬리지느러미
    tail_fin((0.2, -0.65, -0.25), -60, 0.28, 0.8, blue, 0.2)                  # 가슴지느러미
    sphere((1.0, -0.62, 0.15), (0.2, 0.06, 0.2), (1, 1, 1), 1); sphere((1.08, -0.68, 0.15), (0.11, 0.05, 0.11), (0.08, 0.08, 0.14), 1)
    sphere((1.1, -0.55, -0.2), (0.17, 0.06, 0.12), (1.0, 0.65, 0.75), 1)
    for (x, z, s) in ((-0.4, 0.75, 0.16), (0.2, 0.8, 0.2), (0.7, 0.62, 0.13), (-0.95, 0.5, 0.12)):    # 등의 금빛 별
        sphere((x, -0.05, z), (s, 0.04, s), gold, 1)
        cone((x, -0.05, z + s * 1.1), (0, 0, 0), 0.04, 0.12, gold, 4)
        cone((x, -0.05, z - s * 1.1), (math.radians(180), 0, 0), 0.04, 0.12, gold, 4)
    cone((0.9, 0, 0.78), (0, 0, 0), 0.08, 0.35, (0.75, 0.9, 1.0), 5)         # 숨구멍 물줄기
    render("Fish_16_StarWhale.png")

which = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["seahorse", "jelly", "moonfish", "rainbow", "tuna", "marlin", "angler", "whale"]
for w in which:
    {"seahorse": seahorse, "jelly": jelly, "moonfish": moonfish, "rainbow": rainbow, "tuna": tuna, "marlin": marlin, "angler": angler, "whale": whale}[w]()
print("FISH DONE")

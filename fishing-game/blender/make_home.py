# 집 장식 모델(화분·파라솔·풍경·모닥불 돌·해먹·굴뚝·깃발·등불)을 만들어 FBX로 내보낸다 (GDD 9번 "블렌더 모델 교체 ②").
# 실행: blender.exe -b --factory-startup -P blender/make_home.py
# 약속: 재질 이름 "C_RRGGBB"(색 16진수) -> 게임(HomeDecor)이 이름에서 색을 읽는다. 원점 = 놓이는 자리(바닥 가운데 / 걸리는 점).
#       움직이는 부분은 이름으로 분리: Home_Hammock의 "Hammock", Home_Flag의 "FlagCloth" (원점 = 흔들리는 축).
# 좌표: 블렌더(x,y,z) -> 유니티(x, z, -y). 즉 블렌더 -Y = 유니티 앞(+Z), 블렌더 Z = 위.
import bpy, math, os

OUT = os.environ.get("HOME_OUT", r"C:\Users\qudrh\fishing-game-repo\fishing-game\fish game\Assets\Resources\Models")
os.makedirs(OUT, exist_ok=True)
_mats = {}
R90 = math.radians(90)

def mat(rgb):
    h = "C_%02X%02X%02X" % tuple(int(round(max(0, min(1, v)) * 255)) for v in rgb)
    if h in _mats: return _mats[h]
    m = bpy.data.materials.new(h); m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1); b.inputs["Roughness"].default_value = 0.85
    _mats[h] = m
    return m

def fin(o, rgb, name):
    o.name = name; o.data.materials.clear(); o.data.materials.append(mat(rgb))
    for p in o.data.polygons: p.use_smooth = False
    return o

def cyl(x, y, z, r, h, rgb, name, verts=8, r2=None, rot=(0, 0, 0)):
    """z 방향(위)으로 선 원기둥/원뿔대. (x,y,z) = 가운데."""
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=(r if r2 is None else r2), depth=h, location=(x, y, z), rotation=rot)
    return fin(bpy.context.active_object, rgb, name)

def ball(x, y, z, sx, sy, sz, rgb, name, sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=1, location=(x, y, z))
    o = bpy.context.active_object; o.scale = (sx, sy, sz)
    return fin(o, rgb, name)

def box(x, y, z, sx, sy, sz, rgb, name, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z), rotation=rot)
    o = bpy.context.active_object; o.scale = (sx, sy, sz)
    return fin(o, rgb, name)

def clear():
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete()

def export(name):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)    # 크기·회전은 모양에 굽고, 위치(=원점)만 남겨서 유니티에서 원점 기준으로 흔들 수 있게
    path = os.path.join(OUT, name + ".fbx")
    bpy.ops.export_scene.fbx(filepath=path, axis_forward="-Z", axis_up="Y", bake_space_transform=True, apply_scale_options="FBX_SCALE_ALL",
                             object_types={"MESH"}, mesh_smooth_type="FACE", use_selection=True)
    print("HOME", name, path)

def flower(x, y, z_base, h, petal, center, lean=0.0):
    g = (0.36, 0.68, 0.33)
    st = cyl(x, y, z_base + h / 2, 0.016, h, g, "Stem", 5)
    st.rotation_euler = (lean, 0, 0)
    cz = z_base + h
    for i in range(5):
        a = i / 5 * math.pi * 2
        ball(x + math.cos(a) * 0.075, y + math.sin(a) * 0.075 - lean * 0.0, cz, 0.065, 0.065, 0.03, petal, "Petal")
    ball(x, y, cz + 0.012, 0.05, 0.05, 0.04, center, "Center")

def pot():
    clear()
    cyl(0, 0, 0.19, 0.2, 0.38, (0.8, 0.45, 0.3), "Pot", 8, 0.27)
    cyl(0, 0, 0.39, 0.3, 0.07, (0.72, 0.38, 0.25), "Rim", 8)
    ball(0, 0, 0.42, 0.26, 0.26, 0.07, (0.3, 0.2, 0.14), "Soil", 1)
    flower(-0.1, 0.02, 0.43, 0.38, (1.0, 0.55, 0.7), (1.0, 0.85, 0.3))
    flower(0.1, -0.03, 0.43, 0.52, (1.0, 0.95, 0.9), (1.0, 0.8, 0.25))
    flower(0.0, 0.11, 0.43, 0.3, (1.0, 0.8, 0.3), (0.9, 0.5, 0.2))
    for a in (0, 2.2, 4.1):
        o = ball(math.cos(a) * 0.15, math.sin(a) * 0.15, 0.5, 0.14, 0.05, 0.03, (0.4, 0.72, 0.36), "Leaf")
        o.rotation_euler = (0, 0.5, a)
    export("Home_Pot")

def parasol():
    clear()
    cyl(0, 0, 0.95, 0.04, 1.9, (0.75, 0.6, 0.4), "Pole", 6)
    # 줄무늬 지붕: 옆면이 빨강/크림 번갈아
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=1.3, radius2=0.06, depth=0.55, location=(0, 0, 1.95))
    c = bpy.context.active_object; c.name = "Canopy"
    c.data.materials.clear(); c.data.materials.append(mat((0.96, 0.38, 0.35))); c.data.materials.append(mat((1.0, 0.95, 0.85)))
    k = 0
    for p in c.data.polygons:
        p.use_smooth = False
        if len(p.vertices) >= 8: p.material_index = 1        # 위·아래 뚜껑
        else: p.material_index = k % 2; k += 1               # 옆면 8장을 빨강/크림 번갈아
    ball(0, 0, 2.27, 0.07, 0.07, 0.07, (1.0, 0.85, 0.4), "Finial")
    cyl(0.9, -0.7, 0.16, 0.22, 0.32, (0.7, 0.5, 0.32), "Stool", 8)
    cyl(0.9, -0.7, 0.33, 0.22, 0.02, (0.85, 0.68, 0.45), "StoolTop", 8)
    box(-0.8, 0.8, 0.02, 0.9, 0.55, 0.03, (0.35, 0.72, 0.85), "Towel", (0, 0, 0.5))   # 해변 수건
    export("Home_Parasol")

def chime():
    clear()                                                     # 원점 = 처마에 거는 점
    ball(0, 0, 0, 0.04, 0.04, 0.04, (1.0, 0.84, 0.4), "Hook")
    cyl(0, 0, -0.25, 0.012, 0.5, (0.55, 0.38, 0.25), "String", 4)
    cyl(0, 0, -0.52, 0.19, 0.045, (0.55, 0.38, 0.25), "TopPlate", 8)
    lens = (0.34, 0.46, 0.28, 0.4, 0.32)
    for i, L in enumerate(lens):
        a = i / 5 * math.pi * 2
        cyl(math.cos(a) * 0.14, math.sin(a) * 0.14, -0.55 - L / 2, 0.026, L, (1.0, 0.84, 0.4), "Tube%d" % i, 6)
    cyl(0, 0, -0.78, 0.008, 0.36, (0.55, 0.38, 0.25), "Clapper", 4)
    cyl(0, 0, -0.98, 0.07, 0.03, (0.55, 0.38, 0.25), "ClapperDisc", 6)
    box(0, 0, -1.12, 0.02, 0.1, 0.16, (0.9, 0.55, 0.45), "Sail")           # 바람을 받는 작은 판
    export("Home_Chime")

def fire():
    clear()                                                     # 원점 = 바닥 가운데
    cyl(0, 0, 0.01, 0.5, 0.02, (0.42, 0.38, 0.36), "Ash", 10)
    for i in range(8):
        a = i / 8 * math.pi * 2
        o = ball(math.cos(a) * 0.55, math.sin(a) * 0.55, 0.1, 0.13, 0.12, 0.1, (0.55, 0.55, 0.58) if i % 2 else (0.48, 0.48, 0.52), "Stone%d" % i)
        o.rotation_euler = (0.3, 0.2, a)
    for i in range(3):
        o = cyl(0, 0, 0.2, 0.065, 0.95, (0.45, 0.3, 0.2), "Log%d" % i, 6, rot=(0, R90 * 0.92, i * 2.1))
        cyl(0, 0, 0.2, 0.066, 0.12, (0.15, 0.1, 0.08), "Char%d" % i, 6, rot=(0, R90 * 0.92, i * 2.1)).location.x += 0.0
    export("Home_Fire")

def hammock():
    clear()                                                     # 원점 = 땅 가운데. 기둥은 y=±1.5
    for y in (-1.5, 1.5):
        cyl(0, y, 0.85, 0.07, 1.7, (0.5, 0.36, 0.24), "Post", 6)
        ball(0, y, 1.72, 0.1, 0.1, 0.1, (0.4, 0.28, 0.18), "PostCap")
    # 천: 가운데가 처진 띠. 별도 오브젝트(원점 = 흔들리는 축, 높이 1.35)
    parts = []
    n = 9
    for i in range(n):
        u = i / (n - 1) * 2 - 1
        y, z = u * 1.25, 1.35 - 0.55 * (1 - u * u)
        c = box(0, y, z, 0.75, 0.4, 0.05, (0.35, 0.72, 0.72) if i % 2 == 0 else (0.98, 0.9, 0.7), "Cloth%d" % i, (math.atan(1.1 * u) * 0.8, 0, 0))
        parts.append(c)
    for y in (-1.5, 1.5):                                       # 기둥과 천 끝을 잇는 줄
        r = cyl(0, y * 0.97, 1.5, 0.014, 0.4, (0.9, 0.85, 0.7), "Rope", 4)
        parts.append(r)
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts: p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    h = bpy.context.active_object; h.name = "Hammock"
    h.data.materials.clear(); h.data.materials.append(mat((0.35, 0.72, 0.72))); h.data.materials.append(mat((0.98, 0.9, 0.7)))   # 재질 정리: 다시 이름 지정이 필요한 면은 아래에서
    # 면마다 원래 재질을 잃었으니 위치로 다시 칠함(줄무늬 = y 위치로 번갈아)
    for p in h.data.polygons:
        yc = sum(h.data.vertices[v].co.y for v in p.vertices) / len(p.vertices)
        seg = int(round((yc / 1.25 + 1) / 2 * (n - 1)))
        p.material_index = 0 if seg % 2 == 0 else 1
        p.use_smooth = False
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    # 원점을 흔들리는 축(높이 1.35)으로 옮김
    bpy.context.scene.cursor.location = (0, 0, 1.35)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    export("Home_Hammock")

def chimney():
    clear()                                                     # 원점 = 굴뚝 바닥 가운데
    cyl(0, 0, 0.55, 0.36, 1.1, (0.62, 0.4, 0.34), "Stack", 8, 0.34)
    for z in (0.3, 0.7):
        cyl(0, 0, z, 0.38, 0.05, (0.5, 0.33, 0.28), "Band", 8)
    cyl(0, 0, 1.12, 0.44, 0.1, (0.4, 0.28, 0.24), "Cap", 8)
    cyl(0, 0, 1.18, 0.26, 0.03, (0.12, 0.1, 0.1), "Soot", 8)
    export("Home_Chimney")

def flag():
    clear()                                                     # 원점 = 깃대 바닥
    cyl(0, 0, 0.9, 0.035, 1.8, (0.55, 0.4, 0.28), "Pole", 6)
    ball(0, 0, 1.82, 0.06, 0.06, 0.06, (1.0, 0.85, 0.4), "Ball")
    c = box(0, 0, 1.55, 0.9, 0.03, 0.5, (0.95, 0.35, 0.35), "FlagCloth")                 # 깃발 천(원점 = 깃대 위치)
    for v in c.data.vertices: v.co.x += 0.5                                                  # 천 메시가 깃대 오른쪽으로 뻗도록
    ball(0.6, 0.0, 1.55, 0.1, 0.035, 0.1, (1.0, 0.95, 0.9), "Emblem")                       # 하얀 무늬
    export("Home_Flag")

def lantern():
    clear()                                                     # 원점 = 등불 가운데. 벽은 블렌더 -Y 쪽(유니티 +Z)
    cyl(0, 0, 0, 0.12, 0.3, (1.0, 0.85, 0.4), "Glass", 6)
    cyl(0, 0, 0.19, 0.15, 0.05, (0.34, 0.22, 0.13), "TopCap", 6)
    cyl(0, 0, -0.19, 0.15, 0.05, (0.34, 0.22, 0.13), "BottomCap", 6)
    ball(0, 0, 0.25, 0.04, 0.04, 0.04, (0.34, 0.22, 0.13), "Knob")
    box(0, -0.1, 0.32, 0.05, 0.28, 0.05, (0.34, 0.22, 0.13), "Arm")                       # 벽에서 나온 팔
    box(0, -0.24, 0.1, 0.07, 0.04, 0.5, (0.34, 0.22, 0.13), "WallPlate")                    # 벽에 붙는 판
    export("Home_Lantern")

for f in (pot, parasol, chime, fire, hammock, chimney, flag, lantern):
    f()
print("HOME DONE")

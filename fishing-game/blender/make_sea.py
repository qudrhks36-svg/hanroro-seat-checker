# 이벤트 모델(갈매기·병)을 만들어 FBX로 내보낸다 (GDD 9번 "블렌더 모델 교체 ③").
# 실행: blender.exe -b --factory-startup -P blender/make_sea.py
# 약속: 재질 이름 "C_RRGGBB" -> 게임(SeaEvents)이 색을 읽는다. 블렌더 +X = 앞(갈매기가 날아가는 쪽). 블렌더 -Y = 유니티 +Z (유니티 왼쪽 날개).
#       갈매기: "WingL"(블렌더 -Y쪽)·"WingR"(+Y쪽) 날개는 어깨가 원점이라 X축으로 돌리면 퍼덕임. 병: "Gem"(원점 = 반짝이 가운데) 따로.
import bpy, math, os

OUT = os.environ.get("SEA_OUT", r"C:\Users\qudrh\fishing-game-repo\fishing-game\fish game\Assets\Resources\Models")
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

def ball(x, y, z, sx, sy, sz, rgb, name, sub=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=1, location=(x, y, z))
    o = bpy.context.active_object; o.scale = (sx, sy, sz)
    return fin(o, rgb, name)

def box(x, y, z, sx, sy, sz, rgb, name, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z), rotation=rot)
    o = bpy.context.active_object; o.scale = (sx, sy, sz)
    return fin(o, rgb, name)

def cone(x, y, z, r1, r2, depth, rgb, name, rot, verts=6):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=(x, y, z), rotation=rot)
    return fin(bpy.context.active_object, rgb, name)

def clear():
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete()

def export(name):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    path = os.path.join(OUT, name + ".fbx")
    bpy.ops.export_scene.fbx(filepath=path, axis_forward="-Z", axis_up="Y", bake_space_transform=True, apply_scale_options="FBX_SCALE_ALL",
                             object_types={"MESH"}, mesh_smooth_type="FACE", use_selection=True)
    print("SEA", name, path)

def join(parts, name, origin):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts: p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.active_object; o.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.context.scene.cursor.location = origin
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return o

def gull():
    clear()
    white = (0.97, 0.97, 0.98); gray = (0.55, 0.6, 0.68); dark = (0.3, 0.33, 0.4); orange = (1.0, 0.7, 0.2)
    ball(0, 0, 0, 0.45, 0.2, 0.2, white, "Body")
    ball(0.1, 0, -0.08, 0.3, 0.15, 0.1, (0.9, 0.9, 0.93), "Belly", 1)
    ball(0.5, 0, 0.1, 0.16, 0.14, 0.14, white, "Head")
    cone(0.74, 0, 0.08, 0.05, 0.015, 0.26, orange, "Beak", (0, R90, 0))
    box(0.72, 0, 0.03, 0.1, 0.03, 0.012, (0.9, 0.3, 0.25), "BeakSpot")
    for s in (-1, 1): ball(0.57, s * 0.11, 0.15, 0.03, 0.03, 0.03, (0.08, 0.08, 0.1), "Eye", 1)
    box(-0.52, 0, 0.03, 0.3, 0.17, 0.035, white, "Tail", (0, -0.12, 0))
    box(-0.66, 0, 0.0, 0.1, 0.17, 0.036, dark, "TailTip", (0, -0.12, 0))
    for name, s in (("WingL", -1), ("WingR", 1)):
        parts = [box(0.0, s * 0.43, 0.08, 0.42, 0.56, 0.03, white, "WingIn"),
                 box(-0.04, s * 0.72, 0.085, 0.34, 0.3, 0.03, gray, "WingMid"),
                 box(-0.08, s * 0.95, 0.09, 0.26, 0.2, 0.03, dark, "WingTip")]
        join(parts, name, (0.05, s * 0.15, 0.08))
    export("Sea_Gull")

def bottle():
    clear()                                                    # 원점 = 땅 닿는 점 가운데, 병은 X 방향으로 누움
    glass = (0.55, 0.85, 0.8); cream = (1.0, 0.95, 0.8); cork = (0.7, 0.5, 0.3); rope = (0.6, 0.45, 0.28)
    z0 = 0.13
    cone(0.0, 0, z0, 0.13, 0.13, 0.5, glass, "Body", (0, R90, 0), 8)
    ball(-0.25, 0, z0, 0.04, 0.13, 0.13, glass, "Bottom", 1)
    cone(0.36, 0, z0, 0.13, 0.055, 0.22, glass, "Shoulder", (0, R90, 0), 8)
    cone(0.52, 0, z0, 0.055, 0.055, 0.1, glass, "Neck", (0, R90, 0), 8)
    cone(0.585, 0, z0, 0.07, 0.07, 0.04, glass, "Lip", (0, R90, 0), 8)
    cone(0.63, 0, z0, 0.045, 0.04, 0.08, cork, "Cork", (0, R90, 0), 6)
    cone(0.0, 0, z0, 0.137, 0.137, 0.16, cream, "Label", (0, R90, 0), 8)
    cone(0.5, 0, z0, 0.065, 0.065, 0.025, rope, "Rope", (0, R90, 0), 6)
    cone(-0.05, 0, z0, 0.075, 0.075, 0.3, cream, "Scroll", (0, R90, 0), 6)                          # 안에 든 쪽지(유리 속 대신 살짝 튀어나와 보이게)
    ball(0, 0, 0.55, 0.07, 0.07, 0.1, (1.0, 0.85, 0.25), "Gem", 1)                                    # 위에 떠서 도는 노란 반짝이
    export("Sea_Bottle")

gull()
bottle()
print("SEA DONE")

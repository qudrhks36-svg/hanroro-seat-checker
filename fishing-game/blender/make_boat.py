# 작은 나무 배 모델(부두에 매어 둔 배 / 먼 바다의 배)을 FBX로 내보낸다 (GDD 9번 "먼 바다 낚시터").
# 실행: blender.exe -b --factory-startup -P blender/make_boat.py
# 약속: 재질 이름 "C_RRGGBB"; 원점 = 배 바닥 가운데(수면 높이); 배는 블렌더 +X 방향(뱃머리)으로 뻗음. "Lantern" 오브젝트(원점 = 등불 가운데)는 밤에 빛남.
import bpy, math, os

OUT = os.environ.get("BOAT_OUT", r"C:\Users\qudrh\fishing-game-repo\fishing-game\fish game\Assets\Resources\Models")
os.makedirs(OUT, exist_ok=True)
_mats = {}
R = math.radians

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

def box(x, y, z, sx, sy, sz, rgb, name, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z), rotation=rot)
    o = bpy.context.active_object; o.scale = (sx, sy, sz)
    return fin(o, rgb, name)

def cyl(x, y, z, r, h, rgb, name, rot=(0, 0, 0), verts=6):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=(x, y, z), rotation=rot)
    return fin(bpy.context.active_object, rgb, name)

def ball(x, y, z, r, rgb, name, sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=(x, y, z))
    return fin(bpy.context.active_object, rgb, name)

bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete()
wood = (0.62, 0.42, 0.26); trim = (0.45, 0.3, 0.2); white = (0.96, 0.92, 0.82); red = (0.85, 0.3, 0.28)
L = 2.6
box(0, 0, 0.16, L, 0.9, 0.1, trim, "Bottom")                                       # 바닥판
for s in (-1, 1):                                                                   # 양쪽 옆판(바깥으로 기울어짐)
    box(0, s * 0.52, 0.42, L, 0.08, 0.5, wood, "Side", (R(s * -18), 0, 0))
    box(0, s * 0.585, 0.64, L, 0.1, 0.07, trim, "Rail")                             # 테두리 나무
    box(0, s * 0.56, 0.5, L, 0.09, 0.07, white, "Stripe", (R(s * -18), 0, 0))       # 흰 줄
bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.62, radius2=0.04, depth=0.95, location=(L / 2 + 0.38, 0, 0.42), rotation=(0, R(90), R(45)))   # 뾰족한 뱃머리
bow = bpy.context.active_object; bow.scale = (1.0, 1.0, 0.55); fin(bow, wood, "Bow")
box(-L / 2 - 0.05, 0, 0.42, 0.1, 0.95, 0.5, wood, "Stern")                          # 뒷판
box(-0.4, 0, 0.4, 0.3, 1.0, 0.07, trim, "Bench1"); box(0.55, 0, 0.4, 0.3, 0.95, 0.07, trim, "Bench2")      # 앉는 판 두 개
for s in (-1, 1):                                                                   # 노 두 자루(옆에 걸쳐 둠)
    cyl(0.05, s * 0.95, 0.62, 0.03, 1.7, (0.8, 0.65, 0.45), "Oar", (R(s * 62), 0, 0), 5)
    box(0.05, s * 1.65, 0.38, 0.1, 0.38, 0.03, white, "Blade", (R(s * 62), 0, 0))
cyl(L / 2 + 0.05, 0, 0.9, 0.035, 0.75, (0.5, 0.35, 0.22), "LampPost", (0, 0, 0), 6)    # 뱃머리 등불대
ball(L / 2 + 0.05, 0, 1.3, 0.14, (1.0, 0.88, 0.45), "Lantern", 1)                        # 등불(원점 = 등불 가운데)
cyl(L / 2 + 0.05, 0, 1.44, 0.1, 0.05, (0.34, 0.22, 0.13), "LampCap", (0, 0, 0), 6)
box(0, 0, 0.5, 0.5, 0.35, 0.28, red, "Bucket")                                       # 낚시 통(빨강)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
path = os.path.join(OUT, "Sea_Rowboat.fbx")
bpy.ops.export_scene.fbx(filepath=path, axis_forward="-Z", axis_up="Y", bake_space_transform=True, apply_scale_options="FBX_SCALE_ALL",
                         object_types={"MESH"}, mesh_smooth_type="FACE", use_selection=True)
print("BOAT", path)

# 둥근 오두막 (고닷 10단계, 사용자 선택 "지붕과 벽 모양을 새로 만든다"): fishing_island.blend 의 Cabin_Model 에서 문·계단·창문은 그대로 두고,
# 벽은 모서리가 크게 둥근 상자로, 지붕은 처마가 넓게 나온 둥근 돔(타원체 윗부분)으로 새로 만든다. 재질 이름은 그대로(Mat_Wall·Mat_Roof).
# 크기·위치는 원래와 같게(벽 6x5x3.5, 문은 앞(-y)쪽, 창문은 좌우 벽) 맞춰서 충돌·꾸미기 자리가 어긋나지 않게 한다.
# 실행(창 없이): blender.exe -b blender/fishing_island.blend --python blender/make_cabin.py -- <내보낼 폴더>   → <폴더>/Cabin.fbx
# blend 파일은 저장하지 않는다. 내보내기 설정은 make_*.py 와 같음.

import bpy, bmesh, math, os, sys

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(os.path.dirname(bpy.data.filepath), "round_out")
os.makedirs(OUT, exist_ok=True)

WALL_W, WALL_D, WALL_H = 6.0, 5.0, 3.5          # 원래 벽 상자
WALL_ROUND = 0.32                                # 벽 모서리 둥글기
DOME_R = (3.9, 3.4, 2.35)                        # 지붕 돔 반지름(x, y, 높이) — 벽보다 0.9m 나오는 처마, 꼭대기 z = 3.5 + 2.35


def select_only(objs, active):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


def smooth(o, angle=60):
    select_only([o], o)
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle), keep_sharp_edges=False)
    except Exception:
        bpy.ops.object.shade_smooth()


def apply_mod(o, m):
    select_only([o], o)
    bpy.ops.object.modifier_apply(modifier=m.name)


src = bpy.data.objects["Cabin_Model"]
work = src.copy()
work.data = src.data.copy()
bpy.context.collection.objects.link(work)

# 1) 문·계단(Mat_WoodDark)·창문(Mat_Window)만 남기고 모서리를 살짝 깎는다
select_only([work], work)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.separate(type="MATERIAL")
bpy.ops.object.mode_set(mode="OBJECT")
keep = []
for o in list(bpy.context.selected_objects):
    mats = [m.name for m in o.data.materials if m]
    used = {p.material_index for p in o.data.polygons}
    name = o.data.materials[min(used)].name
    if name in ("Mat_Wall", "Mat_Roof"):
        bpy.data.objects.remove(o, do_unlink=True)
        continue
    b = o.modifiers.new("Round", "BEVEL")
    b.width = 0.04 if name == "Mat_WoodDark" else 0.03
    b.segments = 2
    b.limit_method = "ANGLE"
    b.angle_limit = math.radians(25)
    apply_mod(o, b)
    smooth(o, 40)
    keep.append(o)

# 2) 벽: 모서리가 크게 둥근 상자
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, WALL_H / 2))
walls = bpy.context.active_object
walls.scale = (WALL_W, WALL_D, WALL_H)
select_only([walls], walls)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
b = walls.modifiers.new("Round", "BEVEL")
b.width = WALL_ROUND
b.segments = 6
b.limit_method = "NONE"
apply_mod(walls, b)
walls.data.materials.append(bpy.data.materials["Mat_Wall"])
smooth(walls, 60)

# 3) 지붕: 타원체 윗부분(둥근 돔), 바닥은 막는다
bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=20, radius=1.0, location=(0, 0, WALL_H))
dome = bpy.context.active_object
dome.scale = DOME_R
select_only([dome], dome)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bm = bmesh.new()
bm.from_mesh(dome.data)
geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, 0), plane_no=(0, 0, 1), clear_inner=True)
boundary = [e for e in bm.edges if e.is_boundary]
bmesh.ops.holes_fill(bm, edges=boundary, sides=0)
bm.to_mesh(dome.data)
bm.free()
dome.data.materials.append(bpy.data.materials["Mat_Roof"])
smooth(dome, 80)

parts = keep + [walls, dome]
select_only(parts, parts[0])
bpy.ops.object.join()
joined = bpy.context.view_layer.objects.active
src.data.name = "Cabin_Model_orig"
src.name = "Cabin_Model_orig"
joined.name = "Cabin_Model"
joined.data.name = "Cabin_Model"
select_only([joined], joined)
path = os.path.join(OUT, "Cabin.fbx")
bpy.ops.export_scene.fbx(filepath=path, axis_forward="-Z", axis_up="Y", bake_space_transform=True, apply_scale_options="FBX_SCALE_ALL",
                         object_types={"MESH"}, mesh_smooth_type="FACE", use_selection=True)
d = joined.dimensions
print("CABIN verts", len(joined.data.vertices), "dim", round(d.x, 2), round(d.y, 2), round(d.z, 2), "->", path)

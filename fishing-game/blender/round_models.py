# 모델 둥글게 (고닷 10단계 시험, 사용자 요청 "레고같은 각진 느낌을 둥글게"): fishing_island.blend 의 야자수·오두막·부두·배를 재질별로 나눠
# 모서리를 깎거나(Bevel) 부드럽게 다듬고(Subdivision) 면을 부드럽게 이은(shade smooth by angle) 뒤 FBX로 내보낸다.
# 실행(창 없이): blender.exe -b blender/fishing_island.blend --python blender/round_models.py -- <내보낼 폴더>
# blend 파일은 저장하지 않는다(원본 그대로). 내보내기 설정은 make_*.py 와 같음(-Z 앞, Y 위, 변환 구움).

import bpy, math, os, sys

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(os.path.dirname(bpy.data.filepath), "round_out")
os.makedirs(OUT, exist_ok=True)

# 오브젝트 → (FBX 파일 이름, {재질 이름: ("bevel", 너비, 조각 수) | ("subsurf", 단계) | None})
PLAN = {
    "Palm_Model":   ("Palm.fbx",  {"Mat_Trunk": ("subsurf", 2), "Mat_Leaf": ("subsurf", 1), "Mat_WoodDark": ("subsurf", 1)}),
    "Cabin_Model":  ("Cabin.fbx", {"Mat_Wall": ("bevel", 0.14, 3), "Mat_Roof": ("bevel", 0.09, 3), "Mat_WoodDark": ("bevel", 0.04, 2), "Mat_Window": ("bevel", 0.03, 2)}),
    "Pier_Model":   ("Pier.fbx",  {"Mat_Wood": ("bevel", 0.05, 2), "Mat_WoodDark": ("bevel", 0.05, 2)}),
    "Boat_Model":   ("Boat.fbx",  {"Mat_Boat": ("subsurf", 1), "Mat_Wood": ("bevel", 0.04, 2), "Mat_WoodDark": ("bevel", 0.04, 2), "Mat_Wall": None}),
}
SMOOTH_ANGLE = math.radians(40)


def select_only(objs, active):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


def part_material(o):
    mats = [m.name if m else "" for m in o.data.materials]
    used = {p.material_index for p in o.data.polygons}
    return mats[min(used)] if used else ""


def apply_rule(o, rule):
    if rule is None:
        return
    if rule[0] == "bevel":
        m = o.modifiers.new("Round", "BEVEL")
        m.offset_type = "WIDTH"
        m.width = rule[1]
        m.segments = rule[2]
        m.limit_method = "ANGLE"
        m.angle_limit = math.radians(25)   # 상자 모서리뿐 아니라 6~8각 기둥 모서리도 깎음(각 45도 안팎이라 25도 기준)
        m.profile = 0.6
        m.use_clamp_overlap = True
    else:
        m = o.modifiers.new("Round", "SUBSURF")
        m.levels = rule[1]
        m.render_levels = rule[1]
        m.subdivision_type = "CATMULL_CLARK"
    select_only([o], o)
    bpy.ops.object.modifier_apply(modifier=m.name)


def smooth(o):
    select_only([o], o)
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=SMOOTH_ANGLE, keep_sharp_edges=False)
    except Exception:
        bpy.ops.object.shade_smooth()


for name, (fbx, rules) in PLAN.items():
    src = bpy.data.objects[name]
    work = src.copy()
    work.data = src.data.copy()
    bpy.context.collection.objects.link(work)
    select_only([work], work)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="MATERIAL")
    bpy.ops.object.mode_set(mode="OBJECT")
    parts = [o for o in bpy.context.selected_objects]
    before = sum(len(o.data.vertices) for o in parts)
    for o in parts:
        mat = part_material(o)
        apply_rule(o, rules.get(mat))
        smooth(o)
    after = sum(len(o.data.vertices) for o in parts)
    select_only(parts, parts[0])
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    src.data.name = name + "_orig"
    src.name = name + "_orig"   # 이름이 겹치면 ".001"이 붙으니 원본 이름을 비켜 둔다(FBX 안의 이름을 그대로 유지)
    joined.name = name
    joined.data.name = name
    select_only([joined], joined)
    path = os.path.join(OUT, fbx)
    bpy.ops.export_scene.fbx(filepath=path, axis_forward="-Z", axis_up="Y", bake_space_transform=True, apply_scale_options="FBX_SCALE_ALL",
                             object_types={"MESH"}, mesh_smooth_type="FACE", use_selection=True)
    d = joined.dimensions
    print("ROUND", name, "verts", before, "->", len(joined.data.vertices), "dim", round(d.x, 2), round(d.y, 2), round(d.z, 2), "->", path)
    bpy.data.objects.remove(joined, do_unlink=True)

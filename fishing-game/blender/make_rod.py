# 낚싯대 모델 3단계(0 기본 / 1 튼튼 / 2 반짝)를 만들어 FBX로 내보낸다 (GDD 9번 "블렌더 모델 교체").
# 실행: blender.exe -b --factory-startup -P blender/make_rod.py
# 약속: 재질 이름은 "C_RRGGBB"(색 16진수) -> 게임(RodLook)이 이름에서 색을 읽어 재질을 만든다.
#       낚싯대는 블렌더 -Y 방향(= 유니티 앞 +Z)으로 뻗고, 원점 = 손잡이 끝. 끝 구슬 오브젝트 이름 "Orb"(원점 = 낚싯대 끝).
import bpy, math, os

OUT = os.environ.get("ROD_OUT", r"C:\Users\qudrh\fishing-game-repo\fishing-game\fish game\Assets\Resources\Models")
os.makedirs(OUT, exist_ok=True)
_mats = {}

def mat(rgb):
    h = "C_%02X%02X%02X" % tuple(int(round(max(0, min(1, v)) * 255)) for v in rgb)
    if h in _mats: return _mats[h]
    m = bpy.data.materials.new(h); m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1); b.inputs["Roughness"].default_value = 0.85
    _mats[h] = m
    return m

def done(o, rgb, name):
    o.name = name; o.data.materials.clear(); o.data.materials.append(mat(rgb))
    for p in o.data.polygons: p.use_smooth = False
    return o

def seg(y0, y1, r0, r1, rgb, name, verts=6):
    """y0(손잡이 쪽)에서 y1(끝 쪽, 더 작은 y)까지 r0->r1로 가늘어지는 토막. y0 > y1."""
    L = y0 - y1
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r0, radius2=r1, depth=L, location=(0, (y0 + y1) / 2, 0), rotation=(math.radians(90), 0, 0))
    return done(bpy.context.active_object, rgb, name)

def ring(y, z_off, r, rgb, name):
    """낚싯줄 고리: 막대 아래쪽(-Z)에 매달린 작은 고리(막대 축과 나란한 면)."""
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=r * 0.28, major_segments=8, minor_segments=4, location=(0, y, z_off), rotation=(0, math.radians(90), 0))
    return done(bpy.context.active_object, rgb, name)

def reel(y, rgb_body, rgb_spool, name):
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.062, depth=0.05, location=(0.045, y, -0.075), rotation=(0, math.radians(90), 0))
    done(bpy.context.active_object, rgb_body, name + "_Body")
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.04, depth=0.075, location=(0.045, y, -0.075), rotation=(0, math.radians(90), 0))
    done(bpy.context.active_object, rgb_spool, name + "_Spool")
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0.085, y, -0.075)); c = bpy.context.active_object
    c.scale = (0.018, 0.012, 0.075); done(c, rgb_body, name + "_Crank")                                   # 손잡이 막대
    bpy.ops.mesh.primitive_uv_sphere_add(segments=6, ring_count=4, radius=0.022, location=(0.1, y, -0.12)); done(bpy.context.active_object, rgb_spool, name + "_Knob")

def orb(y, d, rgb):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=d / 2, location=(0, y, 0))
    return done(bpy.context.active_object, rgb, "Orb")

def clear():
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete()

def build(level):
    clear()
    L = (1.4, 1.61, 1.82)[level]
    wood = [(0.54, 0.35, 0.21), (0.86, 0.64, 0.38), (1.0, 0.82, 0.3)][level]
    handle = [(0.82, 0.68, 0.45), (0.42, 0.28, 0.18), (0.3, 0.75, 0.75)][level]
    metal = [(0.3, 0.31, 0.34), (0.78, 0.8, 0.84), (1.0, 0.85, 0.4)][level]
    wrap = [(0.3, 0.2, 0.12), (0.88, 0.28, 0.28), (0.98, 0.95, 0.9)][level]
    spool = [(0.75, 0.77, 0.8), (0.95, 0.96, 0.98), (0.3, 0.75, 0.75)][level]

    seg(0.0, -0.34, 0.034, 0.03, handle, "Handle", 8)                       # 손잡이(굵게)
    seg(-0.34, -0.38, 0.036, 0.036, metal, "Ferrule", 8)                    # 손잡이와 대 사이 마디
    seg(-0.38, -L * 0.62, 0.026, 0.017, wood, "Rod_A")                       # 아래 토막
    seg(-L * 0.62, -L, 0.017, 0.007, wood, "Rod_B")                          # 끝 토막(더 가늘게)
    reel(-0.2, metal, spool, "Reel")
    for i, f in enumerate((0.45, 0.62, 0.78, 0.92)):                          # 줄 고리 + 감은 실(색 띠)
        y = -L * f
        ring(y, -0.03 + 0.012 * f, 0.026 - 0.012 * f, metal, "Guide%d" % i)
        seg(y + 0.035, y - 0.035, 0.019 - 0.01 * f, 0.019 - 0.01 * f, wrap, "Wrap%d" % i, 6)
    if level >= 1:
        orb(-L, (0.05, 0.05, 0.07)[level], (1.0, 0.9, 0.45))               # 끝 구슬(원점 = 끝)
    bpy.ops.object.select_all(action="SELECT")
    path = os.path.join(OUT, "Rod_%d.fbx" % level)
    bpy.ops.export_scene.fbx(filepath=path, axis_forward="-Z", axis_up="Y", bake_space_transform=True, apply_scale_options="FBX_SCALE_ALL",
                             object_types={"MESH"}, mesh_smooth_type="FACE", use_selection=True)
    print("ROD", level, path)

for lv in range(3):
    build(lv)
print("ROD DONE")

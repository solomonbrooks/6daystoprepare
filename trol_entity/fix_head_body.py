"""Make the body match the head's colour and fuse the head onto the neck."""
import os, shutil
import bpy, bmesh, numpy as np

D = "/home/user/6daystoprepare/trol_entity"
SMOOTH_ITERS = int(os.environ.get("SMOOTH_ITERS", "0"))
if not os.path.exists(D + "/original/trol_entity.blend"):
    os.makedirs(D + "/original", exist_ok=True)
    for f in ("trol_entity.blend", "trol_entity.fbx", "trol_entity_0.png"):
        shutil.copy(f"{D}/{f}", f"{D}/original/{f}")
bpy.ops.wm.open_mainfile(filepath=D + "/original/trol_entity.blend")

obj = bpy.data.objects["trol_entity"]
arm = bpy.data.objects["Armature"]
img = obj.data.materials[0].node_tree.nodes["Image Texture"].image
W, H = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)

# ---------- 1. colour: scale body texels so the neck matches the head ----------
bm = bmesh.new(); bm.from_mesh(obj.data); uvl = bm.loops.layers.uv.active
def neck_mean(is_head, zlo, zhi, extra=lambda c: True):
    s = []
    for f in bm.faces:
        for l in f.loops:
            u, v = l[uvl].uv
            if (u < 0.5) == is_head and zlo < l.vert.co.z < zhi and extra(l.vert.co):
                p = px[min(int(v * H), H - 1), min(int(u * W), W - 1)]
                if p[3] > 0.5 and p[:3].max() > 0.005:
                    s.append(p[:3])
    return np.array(s).mean(0)
head_c = neck_mean(True, 3.6, 3.95, lambda c: c.y > -0.15)   # skin behind/around the neck, not the face
body_c = neck_mean(False, 3.3, 3.7)
gain = head_c / body_c
print("head", head_c, "body", body_c, "gain", gain)
bm.free()

body_region = np.zeros((H, W), bool); body_region[H // 2:, W // 2:] = True
sel = body_region & (px[..., 3] > 0)
px[..., :3][sel] = np.clip(px[..., :3][sel] * gain, 0, 1)
img.pixels.foreach_set(px.ravel())
img.filepath_raw = D + "/trol_entity_0.png"; img.file_format = "PNG"
img.save()

# ---------- 2. geometry: split head/body, boolean-union, smooth the joint ----------
bpy.context.view_layer.objects.active = obj
obj.modifiers.clear()
# Snapshot skin weights by position: the boolean does not carry the head's weights across.
from mathutils.kdtree import KDTree
orig_w = [[(g.group, g.weight) for g in v.groups] for v in obj.data.vertices]
kd = KDTree(len(obj.data.vertices))
for v in obj.data.vertices: kd.insert(v.co.copy(), v.index)
kd.balance()
head = obj.copy(); head.data = obj.data.copy(); bpy.context.scene.collection.objects.link(head)

def keep(o, want_head):
    bm = bmesh.new(); bm.from_mesh(o.data); uvl = bm.loops.layers.uv.active
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    kill = [f for f in bm.faces
            if (sum(l[uvl].uv.x for l in f.loops) / len(f.loops) < 0.5) != want_head]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    # close the open neck tube / tiny holes so the boolean sees solid volumes
    bmesh.ops.holes_fill(bm, edges=bm.edges[:], sides=0)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    print("part head" if want_head else "part body", len(bm.faces), "boundary", sum(1 for e in bm.edges if e.is_boundary))
    bm.to_mesh(o.data); bm.free()
keep(obj, False)
keep(head, True)

for o in bpy.context.selected_objects: o.select_set(False)
obj.select_set(True); bpy.context.view_layer.objects.active = obj
b = obj.modifiers.new("Union", "BOOLEAN")
b.operation = "UNION"; b.solver = "EXACT"; b.object = head
b.use_hole_tolerant = False
b.material_mode = "TRANSFER"
bpy.ops.object.modifier_apply(modifier=b.name)
bpy.data.objects.remove(head)

# Smooth a couple of rings around the head/neck junction to soften the crease.
bm = bmesh.new(); bm.from_mesh(obj.data); uvl = bm.loops.layers.uv.active
def nb(): return sum(1 for e in bm.edges if e.is_boundary)
print("boundary after union", nb())
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
print("boundary after weld", nb())
def is_head_face(f): return sum(l[uvl].uv.x for l in f.loops) / len(f.loops) < 0.5
seam = {v for v in bm.verts
        if len({is_head_face(f) for f in v.link_faces}) == 2 and 3.4 < v.co.z < 4.1}
ring = set(seam)
for _ in range(2):
    ring |= {e.other_vert(v) for v in list(ring) for e in v.link_edges}
print("seam verts", len(seam), "smoothed", len(ring))
for _ in range(SMOOTH_ITERS):
    bmesh.ops.smooth_vert(bm, verts=list(ring), factor=0.5,
                          use_axis_x=True, use_axis_y=True, use_axis_z=True)
bm.to_mesh(obj.data); bm.free()

# Restore skin weights from the nearest original vertex (exact match except at the new junction).
groups = obj.vertex_groups
for gr in groups: gr.remove(range(len(obj.data.vertices)))
far = 0
for v in obj.data.vertices:
    _, i, d = kd.find(v.co)
    far += d > 1e-4
    for gi, w in orig_w[i]:
        groups[gi].add([v.index], w, "REPLACE")
print("weights restored; verts not at an original position:", far)

for p in obj.data.polygons: p.use_smooth = True
mod = obj.modifiers.new("Armature", "ARMATURE"); mod.object = arm

bpy.ops.wm.save_as_mainfile(filepath=D + "/trol_entity.blend")
bpy.ops.export_scene.fbx(
    filepath=D + "/trol_entity.fbx", object_types={"ARMATURE", "MESH"},
    add_leaf_bones=False, use_armature_deform_only=False,
    path_mode="COPY", embed_textures=True, bake_anim=False)
print("verts", len(obj.data.vertices), "faces", len(obj.data.polygons))

"""Alternate head: deeper V grin + darker, rougher skin, inspired by the
unused head left in the body model's texture. Writes trol_entity_althead.*"""
import os, math
import bpy, numpy as np
from mathutils import Vector, noise

D = "/home/user/6daystoprepare/trol_entity"
DEPTH = float(os.environ.get("DEPTH", "0.14"))     # how far the jaw centre drops
bpy.ops.wm.open_mainfile(filepath=D + "/trol_entity.blend")
obj = bpy.data.objects["trol_entity"]; me = obj.data
vg = obj.vertex_groups

# ---------- 1. geometry: deepen the V of the grin ----------
jaw = vg["Jaw"].index
uv = me.uv_layers.active.data
head_v = set()
for p in me.polygons:
    if sum(uv[i].uv.x for i in p.loop_indices) / p.loop_total < 0.5:
        head_v.update(p.vertices)
moved = 0
for v in me.vertices:
    if v.index not in head_v: continue
    w = next((g.weight for g in v.groups if g.group == jaw), 0.0)
    if w <= 0: continue
    centre = max(0.0, 1 - abs(v.co.x) / 0.36) ** 1.3        # 1 in the middle, 0 at mouth corners
    front = min(1.0, max(0.0, (-v.co.y - 0.02) / 0.2))     # front of the face only, not the neck
    low = min(1.0, max(0.0, (v.co.z - 3.62) / 0.15))        # leave the very bottom of the chin near the neck
    d = DEPTH * w * centre * front * (0.35 + 0.65 * low)
    if d > 1e-5:
        v.co.z -= d
        v.co.y -= d * 0.25                                  # jut slightly forward as it drops
        moved += 1
me.update()
print("jaw verts moved", moved)

# ---------- 2. texture: darker, wrinkled skin computed in 3D (seamless across UV cuts) ----------
img = me.materials[0].node_tree.nodes["Image Texture"].image
W, H = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
pos = np.full((H, W, 3), np.nan, np.float32)
co = np.array([v.co for v in me.vertices], np.float32)
for p in me.polygons:
    li = list(p.loop_indices)
    t = np.array([[uv[i].uv.x * W, uv[i].uv.y * H] for i in li])
    if t[:, 0].mean() >= W / 2: continue
    P3 = co[[me.loops[i].vertex_index for i in li]]
    x0, y0 = np.floor(t.min(0)).astype(int) - 2; x1, y1 = np.ceil(t.max(0)).astype(int) + 2
    xs, ys = np.meshgrid(np.arange(max(x0, 0), min(x1, W)), np.arange(max(y0, 0), min(y1, H)))
    q = np.stack([xs + 0.5, ys + 0.5], -1)
    a, b, c = t[0], t[1], t[2]
    den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
    if abs(den) < 1e-12: continue
    l1 = ((b[1] - c[1]) * (q[..., 0] - c[0]) + (c[0] - b[0]) * (q[..., 1] - c[1])) / den
    l2 = ((c[1] - a[1]) * (q[..., 0] - c[0]) + (a[0] - c[0]) * (q[..., 1] - c[1])) / den
    l3 = 1 - l1 - l2
    e = -0.08                                               # small bleed past the edge to cover seams
    ins = (l1 >= e) & (l2 >= e) & (l3 >= e)
    pos[ys[ins], xs[ins]] = (l1[ins, None] * P3[0] + l2[ins, None] * P3[1] + l3[ins, None] * P3[2])
mask = ~np.isnan(pos[..., 0])
P = pos[mask]
print("head texels", len(P))

def fbm(p, oct, base):
    return noise.fractal(Vector(p) * base, 0.6, 2.1, oct, noise_basis="PERLIN_NEW")
def ridge(p):
    return noise.ridged_multi_fractal(Vector((p[0] * 9, p[1] * 9, p[2] * 4.5)), 0.9, 2.0, 4, 1.0, 2.0, noise_basis="PERLIN_NEW")
n_fine = np.array([fbm(p, 4, 38) for p in P], np.float32)
n_wr = np.array([ridge(p) for p in P], np.float32)
n_fine = (n_fine - n_fine.mean()) / (n_fine.std() + 1e-6)
n_wr = (n_wr - n_wr.mean()) / (n_wr.std() + 1e-6)

rgb = px[..., :3][mask]
lum = rgb.mean(1)
sat = rgb.max(1) - rgb.min(1)
skin = np.clip(1 - np.maximum((lum - 0.5) / 0.15, (sat - 0.08) / 0.08), 0, 1)   # spare teeth, gums, eye whites
z = P[:, 2]
neck_keep = np.clip((z - 3.85) / 0.35, 0, 1)                # no change where the head meets the neck
darken = 1 - 0.28 * neck_keep
detail = 1 + (0.10 * n_fine - 0.16 * np.clip(n_wr, 0, None) + 0.05 * np.clip(-n_wr, 0, None)) * (0.4 + 0.6 * neck_keep)
k = (skin * 1.0)[:, None]
new = rgb * (1 - k) + np.clip(rgb * darken[:, None] * detail[:, None], 0, 1) * k
new = new * np.array([1.0, 0.985, 0.97], np.float32)        # a touch warmer/browner, like the leftover pieces
px[..., :3][mask] = new
alt = bpy.data.images.new("trol_entity_althead_0.png", W, H, alpha=True)
alt.pixels.foreach_set(px.ravel())
alt.filepath_raw = D + "/trol_entity_althead_0.png"; alt.file_format = "PNG"; alt.save()
alt.filepath = D + "/trol_entity_althead_0.png"; alt.reload()
mat = me.materials[0].copy(); mat.name = "trol_entity_althead"
mat.node_tree.nodes["Image Texture"].image = alt
me.materials[0] = mat

bpy.ops.wm.save_as_mainfile(filepath=D + "/trol_entity_althead.blend")
bpy.ops.export_scene.fbx(
    filepath=D + "/trol_entity_althead.fbx", object_types={"ARMATURE", "MESH"},
    add_leaf_bones=False, use_armature_deform_only=False,
    path_mode="COPY", embed_textures=True, bake_anim=False)
print("done")

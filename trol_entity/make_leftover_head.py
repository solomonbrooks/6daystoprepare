"""Re-texture the troll head with the *leftover* head texture from the body model.

The unused head pieces are cut out of the original texture, cleaned (neighbouring
pieces masked off, gaps filled), and laid out in the empty bottom half of the
texture. The troll head's faces are sorted into skull / face / lips / teeth /
mouth / eyes and each group is projected onto its piece. Eyes keep the troll's.
Writes trol_entity_lefthead.*"""
import math
import bpy, numpy as np

D = "/home/user/6daystoprepare/trol_entity"
ORIG_TEX = D + "/original/trol_entity_0.png"

bpy.ops.wm.open_mainfile(filepath=D + "/trol_entity.blend")
obj = bpy.data.objects["trol_entity"]; me = obj.data
img = me.materials[0].node_tree.nodes["Image Texture"].image
W, H = img.size
cur = np.array(img.pixels[:], np.float32).reshape(H, W, 4)          # bottom-up rows
src_img = bpy.data.images.load(ORIG_TEX)
src = np.array(src_img.pixels[:], np.float32).reshape(H, W, 4)

# ---------- mask of texels the original mesh never used ----------
uvl = me.uv_layers.active.data
def raster_used(mesh):
    used = np.zeros((H, W), bool)
    uvd = mesh.uv_layers.active.data
    for p in mesh.polygons:
        t = np.array([[uvd[i].uv.x * W, uvd[i].uv.y * H] for i in p.loop_indices])
        x0, y0 = np.floor(t.min(0)).astype(int) - 1; x1, y1 = np.ceil(t.max(0)).astype(int) + 2
        xs, ys = np.meshgrid(np.arange(max(x0, 0), min(x1, W)), np.arange(max(y0, 0), min(y1, H)))
        q = np.stack([xs + 0.5, ys + 0.5], -1); a, b, c = t[:3]
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-12: continue
        l1 = ((b[1] - c[1]) * (q[..., 0] - c[0]) + (c[0] - b[0]) * (q[..., 1] - c[1])) / den
        l2 = ((c[1] - a[1]) * (q[..., 0] - c[0]) + (a[0] - c[0]) * (q[..., 1] - c[1])) / den
        ins = (l1 >= -0.05) & (l2 >= -0.05) & (1 - l1 - l2 >= -0.05)
        used[ys[ins], xs[ins]] = True
    for _ in range(2):
        used = used | np.roll(used, 1, 0) | np.roll(used, -1, 0) | np.roll(used, 1, 1) | np.roll(used, -1, 1)
    return used
leftover = (src[..., 3] > 0.5) & ~raster_used(me)

# ---------- cut + clean pieces (rects given top-down, like an image editor) ----------
def piece(x0, y0, x1, y1):
    r0, r1 = H - y1, H - y0                                         # to bottom-up rows
    c = src[r0:r1, x0:x1, :3].copy(); m = leftover[r0:r1, x0:x1].copy()
    print('  leftover px in rect', m.sum())
    if m.sum() < 500: m = src[r0:r1, x0:x1, 3] > 0.5     # piece is (partly) used by the body; take it anyway
    # keep only the largest leftover blob in the rect, drop slivers of neighbours
    lab = np.zeros(m.shape, np.int32); n = 0; sizes = {}
    for y, x in zip(*np.nonzero(m)):
        if lab[y, x]: continue
        n += 1; st = [(y, x)]; lab[y, x] = n; k = 0
        while st:
            yy, xx = st.pop(); k += 1
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                a, b = yy + dy, xx + dx
                if 0 <= a < m.shape[0] and 0 <= b < m.shape[1] and m[a, b] and not lab[a, b]:
                    lab[a, b] = n; st.append((a, b))
        sizes[n] = k
    m = lab == max(sizes, key=sizes.get)
    for _ in range(2):                                             # pull edge 2px in: AA fringe
        m = m & np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1)
    # fill outside the piece by repeated neighbour averaging (nearest-colour extension)
    known = m.copy(); c[~known] = 0
    while not known.all():
        acc = np.zeros_like(c); cnt = np.zeros(m.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            kk = np.roll(np.roll(known, dy, 0), dx, 1); cc = np.roll(np.roll(c, dy, 0), dx, 1)
            acc += cc * kk[..., None]; cnt += kk
        new = (~known) & (cnt > 0)
        c[new] = acc[new] / cnt[new, None]; known |= new
    return c

def resize(c, w, h):
    ys = (np.arange(h) + 0.5) * c.shape[0] / h - 0.5; xs = (np.arange(w) + 0.5) * c.shape[1] / w - 0.5
    y0 = np.clip(np.floor(ys).astype(int), 0, c.shape[0] - 1); y1 = np.clip(y0 + 1, 0, c.shape[0] - 1)
    x0 = np.clip(np.floor(xs).astype(int), 0, c.shape[1] - 1); x1 = np.clip(x0 + 1, 0, c.shape[1] - 1)
    fy = np.clip(ys - y0, 0, 1)[:, None, None]; fx = np.clip(xs - x0, 0, 1)[None, :, None]
    return (c[y0][:, x0] * (1 - fy) * (1 - fx) + c[y0][:, x1] * (1 - fy) * fx +
            c[y1][:, x0] * fy * (1 - fx) + c[y1][:, x1] * fy * fx)

def mirror_tile(c, w, h):
    t = np.concatenate([c, c[:, ::-1]], 1); t = np.concatenate([t, t[::-1]], 0)
    reps = (math.ceil(h / t.shape[0]), math.ceil(w / t.shape[1]))
    return np.tile(t, (reps[0], reps[1], 1))[:h, :w]

P = {
    "face": piece(1405, 215, 1555, 365),
    "skin_a": piece(1405, 105, 1515, 220),
    "skin_b": src[H - 200:H - 112, 1824:1908, :3].copy(),      # plain interior of the grey skin panel
    "mouth": piece(1405, 355, 1560, 505),
    "lip": piece(1620, 100, 1745, 270),
    "teeth": piece(1630, 45, 1705, 115),
}
for k, v in P.items(): print("piece", k, v.shape)

# ---------- atlas in the empty bottom half: cells (x0, y0, w, h) in bottom-up pixels ----------
CELLS = {"skin": (0, 0, 1000, 1000), "face": (1000, 500, 500, 500), "mouth": (1000, 0, 500, 500),
         "lip": (1500, 500, 250, 500), "teeth": (1750, 500, 250, 500), "skin2": (1500, 0, 500, 500)}
out = cur.copy()
def put(cell, pix):
    x0, y0, w, h = CELLS[cell]; out[y0:y0 + h, x0:x0 + w, :3] = pix; out[y0:y0 + h, x0:x0 + w, 3] = 1
put("skin", mirror_tile(P["skin_b"], 1000, 1000))
put("skin2", mirror_tile(P["skin_a"], 500, 500))
put("face", resize(P["face"], 500, 500))
put("mouth", resize(P["mouth"], 500, 500))
put("lip", resize(P["lip"], 250, 500))
put("teeth", mirror_tile(resize(P["teeth"], 125, 250), 250, 500))

# ---------- classify head faces ----------
def tex_at(u, v):
    return cur[min(int(v * H), H - 1), min(int(u * W), W - 1), :3]
co = np.array([v.co for v in me.vertices])
cls = {}
eye_l = np.array([-0.15, -0.33, 4.43]); eye_r = np.array([0.16, -0.33, 4.43])
for p in me.polygons:
    us = [uvl[i].uv for i in p.loop_indices]
    cu = sum(u.x for u in us) / len(us); cv = sum(u.y for u in us) / len(us)
    if cu >= 0.5: continue                                         # body
    c = np.array(p.center); col = tex_at(cu, cv); lum = col.mean(); sat = col.max() - col.min()
    if min(np.linalg.norm(c - eye_l), np.linalg.norm(c - eye_r)) < 0.09: cls[p.index] = "eye"
    elif lum > 0.55 and sat < 0.12: cls[p.index] = "teeth"
    elif sat > 0.07 and col[0] > col[2]: cls[p.index] = "lip"
    elif lum < 0.07 and c[1] < 0.1 and c[2] > 3.7: cls[p.index] = "mouth"
    elif p.normal.y < -0.6 and 3.85 < c[2] < 4.78 and abs(c[0]) < 0.48: cls[p.index] = "face"
    else: cls[p.index] = "skin"
import collections; print(collections.Counter(cls.values()))

# eye centres: refine from the darkest front-facing upper-face faces
dark = [np.array(p.center) for p in me.polygons if cls.get(p.index) and p.center.z > 4.3
        and p.center.y < -0.2 and tex_at(*(sum((uvl[i].uv for i in p.loop_indices), uvl[p.loop_indices[0]].uv * 0) / p.loop_total)).mean() < 0.12]
print("dark upper-face faces", len(dark))

# ---------- project UVs ----------
def fit(vals, cell, axes, margin=0.06):
    x0, y0, w, h = CELLS[cell]
    a = np.array([v[axes[0]] for v in vals]); b = np.array([v[axes[1]] for v in vals])
    amin, amax, bmin, bmax = a.min(), a.max(), b.min(), b.max()
    def f(pa, pb):
        fa = margin + (1 - 2 * margin) * (pa - amin) / (amax - amin + 1e-9)
        fb = margin + (1 - 2 * margin) * (pb - bmin) / (bmax - bmin + 1e-9)
        return ((x0 + fa * w) / W, (y0 + fb * h) / H)
    return f
groups = collections.defaultdict(list)
for fi, k in cls.items(): groups[k].append(fi)
head_c = np.array([0.0, 0.05, 4.25])
for k, faces in groups.items():
    if k == "eye": continue
    loops = [li for fi in faces for li in me.polygons[fi].loop_indices]
    pts = [co[me.loops[li].vertex_index] for li in loops]
    if k == "skin":
        # cylindrical around the head's vertical axis; seam at the back; 2 wraps for texel density
        def cyl(pp):
            ang = math.atan2(pp[0] - head_c[0], -(pp[1] - head_c[1]))      # 0 at the front
            return ((ang / math.pi + 1) * 0.5, pp[2])
        vals = [cyl(pp) for pp in pts]
        f = fit(vals, "skin", (0, 1), 0.0)
        for li, (a, b) in zip(loops, vals): uvl[li].uv = f(a, b)
    else:
        f = fit(pts, k, (0, 2))                                            # planar front projection (x, z)
        for li, pp in zip(loops, pts): uvl[li].uv = f(pp[0], pp[2])

# ---------- save ----------
alt = bpy.data.images.new("trol_entity_lefthead_0.png", W, H, alpha=True)
alt.pixels.foreach_set(out.ravel())
alt.filepath_raw = D + "/trol_entity_lefthead_0.png"; alt.file_format = "PNG"; alt.save()
alt.filepath = D + "/trol_entity_lefthead_0.png"; alt.reload()
mat = me.materials[0].copy(); mat.name = "trol_entity_lefthead"
mat.node_tree.nodes["Image Texture"].image = alt
me.materials[0] = mat
bpy.ops.wm.save_as_mainfile(filepath=D + "/trol_entity_lefthead.blend")
bpy.ops.export_scene.fbx(
    filepath=D + "/trol_entity_lefthead.fbx", object_types={"ARMATURE", "MESH"},
    add_leaf_bones=False, use_armature_deform_only=False,
    path_mode="COPY", embed_textures=True, bake_anim=False)
print("done")

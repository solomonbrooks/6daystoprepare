import json, struct, sys
import bpy
from mathutils import Matrix, Vector

UP = "/root/.claude/uploads/3b088e51-4a87-57d6-8f3c-45f0a0a3aa3c/"
BIN = UP + "fc7fdb58-trol_entity.bin"
META = UP + "8a4ba1b6-trol_entity.json"
TEX = "/tmp/claude-0/-home-user-6daystoprepare/3b088e51-4a87-57d6-8f3c-45f0a0a3aa3c/images/1.webp"
OUT_DIR = sys.argv[sys.argv.index("--") + 1]

meta = json.load(open(META))
b = open(BIN, "rb").read()

# --- parse TDS2 (big-endian) ---
assert b[:4] == b"TDS2"
nv, ni, nj, ninf = struct.unpack(">4I", b[4:20])
o = 20
verts = [struct.unpack_from(">8f", b, o + i * 32) for i in range(nv)]
o += nv * 32
offs = struct.unpack_from(">%dI" % (nv + 1), b, o)
o += (nv + 1) * 4
infl = [struct.unpack_from(">fI", b, o + i * 8) for i in range(ninf)]
o += ninf * 8
idx = struct.unpack_from(">%dI" % ni, b, o)
o += ni * 4
assert o == len(b), (o, len(b))

# Source is Y-up; Blender is Z-up.
Y2Z = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
def cv(x, y, z):
    return (x, -z, y)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# --- mesh ---
me = bpy.data.meshes.new("trol_entity")
me.from_pydata([cv(*v[0:3]) for v in verts], [],
               [tuple(idx[i:i + 3]) for i in range(0, ni, 3)])
uvl = me.uv_layers.new(name="UVMap")
loop_vi = [0] * len(me.loops)
me.loops.foreach_get("vertex_index", loop_vi)
uvs = []
for vi in loop_vi:
    u, v = verts[vi][6:8]
    uvs += (u, 1.0 - v)
uvl.data.foreach_set("uv", uvs)
me.normals_split_custom_set_from_vertices([cv(*v[3:6]) for v in verts])
me.validate(clean_customdata=False)
me.update()

# --- material ---
mat = bpy.data.materials.new("trol_entity")
mat.use_backface_culling = False
nt = mat.node_tree
bsdf = nt.nodes.get("Principled BSDF")
img = bpy.data.images.load(TEX)
print("tex size", tuple(img.size)); _ = img.pixels[0]
img.name = "trol_entity_0.png"
img.file_format = "PNG"
img.filepath_raw = OUT_DIR + "/trol_entity_0.png"
img.save()
img.filepath = OUT_DIR + "/trol_entity_0.png"
img.reload()
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = img
nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.9
me.materials.append(mat)

mesh_obj = bpy.data.objects.new("trol_entity", me)
scene.collection.objects.link(mesh_obj)

# --- armature from inverse bind matrices ---
nodes = meta["nodes"]
def colmajor(m):
    return Matrix([[m[c * 4 + r] for c in range(4)] for r in range(4)])

bind = [Y2Z @ colmajor(m).inverted() for m in meta["inverseBindMatrices"]]
joints = meta["joints"]
names = [nodes[j]["name"] for j in joints]
parent = [nodes[j]["parent"] for j in joints]
children = {i: [k for k, p in enumerate(parent) if p == i] for i in range(nj)}

arm = bpy.data.armatures.new("Armature")
arm_obj = bpy.data.objects.new("Armature", arm)
scene.collection.objects.link(arm_obj)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.mode_set(mode="EDIT")
heads = [m.to_translation() for m in bind]
lengths = []
for i in range(nj):
    d = [(heads[c] - heads[i]).length for c in children[i]]
    d = [x for x in d if x > 1e-4]
    lengths.append(min(d) if d else None)
ebs = []
for i in range(nj):
    eb = arm.edit_bones.new(names[i])
    L = lengths[i] or (lengths[parent[i]] * 0.5 if parent[i] >= 0 and lengths[parent[i]] else 0.05)
    L = max(L, 0.01)
    rot = bind[i].to_3x3().normalized()
    eb.head = heads[i]
    eb.tail = heads[i] + rot.col[1] * L
    eb.align_roll(rot.col[2])
    ebs.append(eb)
for i in range(nj):
    if parent[i] >= 0:
        ebs[i].parent = ebs[parent[i]]
bpy.ops.object.mode_set(mode="OBJECT")

# --- skin weights ---
groups = [mesh_obj.vertex_groups.new(name=n) for n in names]
for vi in range(nv):
    for k in range(offs[vi], offs[vi + 1]):
        w, j = infl[k]
        if w > 0:
            groups[j].add([vi], w, "ADD")
mesh_obj.parent = arm_obj
mod = mesh_obj.modifiers.new("Armature", "ARMATURE")
mod.object = arm_obj

bpy.ops.wm.save_as_mainfile(filepath=OUT_DIR + "/trol_entity.blend")
bpy.ops.export_scene.fbx(
    filepath=OUT_DIR + "/trol_entity.fbx",
    object_types={"ARMATURE", "MESH"},
    add_leaf_bones=False,
    use_armature_deform_only=False,
    path_mode="COPY",
    embed_textures=True,
    bake_anim=False,
)
print("OK", nv, ni // 3, nj, ninf)

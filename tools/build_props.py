"""
Genera la rueda y los props de stage en Blender (headless).
Correr:  blender --background --python tools/build_props.py

Exporta a assets/props/: wheel.glb, pine.glb, tree.glb, rock.glb, cactus.glb
"""
import bpy
import os
import math
import random

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "props")
os.makedirs(OUT_DIR, exist_ok=True)
random.seed(7)


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def mat(name, color, rough=0.7, metal=0.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    return m


def export(name):
    bpy.ops.object.select_all(action="SELECT")
    out = os.path.join(OUT_DIR, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=out, use_selection=True, export_apply=True)
    print("EXPORTED %s" % out)


# ── RUEDA: neumático + llanta de 5 rayos ─────────────────────────────────────
# Eje de giro a lo largo de X (como las ruedas del juego).

def build_wheel():
    clear()
    tire_mat = mat("Tire", (0.08, 0.08, 0.09), rough=0.9)
    rim_mat = mat("Rim", (0.75, 0.75, 0.78), rough=0.3, metal=0.8)

    # Neumático: toro achatado → cilindro con bisel
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.28, depth=0.22,
                                        rotation=(0, math.pi / 2, 0))
    tire = bpy.context.active_object
    tire.name = "Tire"
    tire.data.materials.append(tire_mat)
    bev = tire.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.04
    bev.segments = 2

    # Llanta: disco
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.17, depth=0.24,
                                        rotation=(0, math.pi / 2, 0))
    rim = bpy.context.active_object
    rim.name = "Rim"
    rim.data.materials.append(rim_mat)
    rim.parent = tire

    # 5 rayos
    for i in range(5):
        a = i * math.tau / 5
        bpy.ops.mesh.primitive_cube_add(size=1)
        spoke = bpy.context.active_object
        spoke.scale = (0.13, 0.035, 0.11)
        spoke.location = (0, math.cos(a) * 0.1, math.sin(a) * 0.1)
        spoke.rotation_euler = (a, 0, 0)
        bpy.ops.object.transform_apply(scale=True)
        spoke.data.materials.append(rim_mat)
        spoke.parent = tire

    export("wheel")


# ── PINO: tronco + 3 conos con leve irregularidad ────────────────────────────

def build_pine():
    clear()
    trunk_mat = mat("Trunk", (0.3, 0.2, 0.12), rough=0.9)
    leaf_mat = mat("Leaf", (0.13, 0.42, 0.17), rough=0.8)

    bpy.ops.mesh.primitive_cylinder_add(vertices=7, radius=0.16, depth=2.4, location=(0, 0, 1.2))
    trunk = bpy.context.active_object
    trunk.name = "Trunk"
    trunk.data.materials.append(trunk_mat)

    for i in range(3):
        r = 1.6 - i * 0.45
        h = 1.8
        z = 2.2 + i * 1.25
        bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=r, depth=h, location=(0.06 * i, -0.04 * i, z))
        cone = bpy.context.active_object
        cone.name = "Leaf%d" % i
        cone.rotation_euler = (math.radians(random.uniform(-4, 4)), math.radians(random.uniform(-4, 4)), 0)
        cone.data.materials.append(leaf_mat)
        cone.parent = trunk

    export("pine")


# ── ÁRBOL REDONDO: tronco + esfera ico facetada ──────────────────────────────

def build_tree():
    clear()
    trunk_mat = mat("Trunk", (0.32, 0.21, 0.12), rough=0.9)
    leaf_mat = mat("LeafRound", (0.22, 0.5, 0.18), rough=0.8)

    bpy.ops.mesh.primitive_cylinder_add(vertices=7, radius=0.18, depth=1.8, location=(0, 0, 0.9))
    trunk = bpy.context.active_object
    trunk.name = "Trunk"
    trunk.data.materials.append(trunk_mat)

    for (dx, dy, dz, s) in [(0, 0, 2.6, 1.4), (0.7, 0.3, 2.2, 0.9), (-0.6, -0.2, 2.3, 0.8)]:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=s, location=(dx, dy, dz))
        ball = bpy.context.active_object
        ball.data.materials.append(leaf_mat)
        ball.parent = trunk

    export("tree")


# ── ROCA: icoesfera deformada ────────────────────────────────────────────────

def build_rock():
    clear()
    rock_mat = mat("Rock", (0.45, 0.42, 0.38), rough=0.95)

    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0)
    rock = bpy.context.active_object
    rock.name = "Rock"
    # Deformar vértices para que no sea esfera perfecta
    for v in rock.data.vertices:
        v.co *= 1.0 + random.uniform(-0.25, 0.25)
        v.co.z *= 0.65  # achatada
    rock.data.materials.append(rock_mat)
    export("rock")


# ── CACTUS: tronco + brazos con bisel ────────────────────────────────────────

def build_cactus():
    clear()
    cactus_mat = mat("Cactus", (0.25, 0.52, 0.28), rough=0.7)

    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.28, depth=2.8, location=(0, 0, 1.4))
    trunk = bpy.context.active_object
    trunk.name = "Cactus"
    trunk.data.materials.append(cactus_mat)
    bev = trunk.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.08
    bev.segments = 2

    for side, h in [(-1, 1.5), (1, 1.9)]:
        # Brazo horizontal
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.15, depth=0.5,
                                            rotation=(0, math.pi / 2, 0),
                                            location=(side * 0.45, 0, h))
        arm_h = bpy.context.active_object
        arm_h.data.materials.append(cactus_mat)
        arm_h.parent = trunk
        # Brazo vertical
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.15, depth=0.8,
                                            location=(side * 0.68, 0, h + 0.35))
        arm_v = bpy.context.active_object
        arm_v.data.materials.append(cactus_mat)
        arm_v.parent = trunk

    export("cactus")


build_wheel()
build_pine()
build_tree()
build_rock()
build_cactus()
print("ALL_PROPS_DONE")

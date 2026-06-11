"""
Genera los 6 modelos de auto low-poly del juego con Blender (headless).
Correr:  blender --background --python tools/build_cars.py

Cada auto se construye desde su silueta lateral (perfil 2D de puntos z,y),
extruida a lo ancho con "tumblehome" (el techo más angosto que la base),
más bisel en los bordes para que la luz los marque. Exporta .glb a assets/cars/.

Materiales por nombre (Godot los identifica para pintar):
  Paint  → carrocería (recoloreable por jugador)
  Glass  → vidrios oscuros
  LightF → faros (emisivo cálido)
  LightR → luces traseras (emisivo rojo)
  Dark   → detalles oscuros (parrilla, asiento, llantas)
"""
import bpy
import bmesh
import os
import math

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "cars")
os.makedirs(OUT_DIR, exist_ok=True)


# ── Materiales ────────────────────────────────────────────────────────────────

def make_materials():
    mats = {}

    def mat(name, color, emission=None, rough=0.6, metal=0.0):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        if emission:
            bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
            bsdf.inputs["Emission Strength"].default_value = 2.0
        mats[name] = m
        return m

    mat("Paint", (0.8, 0.2, 0.2), rough=0.35, metal=0.15)
    mat("Glass", (0.06, 0.08, 0.1), rough=0.15, metal=0.3)
    mat("LightF", (1.0, 0.95, 0.7), emission=(1.0, 0.9, 0.6))
    mat("LightR", (0.7, 0.05, 0.05), emission=(1.0, 0.1, 0.1))
    mat("Dark", (0.1, 0.1, 0.11), rough=0.8)
    return mats


# ── Construcción del cuerpo desde perfil lateral ──────────────────────────────

def build_body(name, profile, width, mats, glass_range=None, tumblehome=0.82, bevel=0.05):
    """
    profile: lista de (z, y) — silueta lateral, sentido horario desde el frente bajo.
    glass_range: (y_min,) — caras por encima de esta altura llevan material Glass.
    tumblehome: factor de angostamiento del techo.
    """
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)

    bm = bmesh.new()
    half = width / 2.0

    # Dos anillos de vértices (izquierda y derecha), angostando arriba
    y_min = min(p[1] for p in profile)
    y_max = max(p[1] for p in profile)

    def x_at(y):
        t = (y - y_min) / max(y_max - y_min, 0.001)
        return half * (1.0 - (1.0 - tumblehome) * t)

    left = [bm.verts.new((-x_at(y), y, z)) for z, y in profile]
    right = [bm.verts.new((x_at(y), y, z)) for z, y in profile]

    n = len(profile)
    # Caras laterales
    bm.faces.new(left)
    bm.faces.new(list(reversed(right)))
    # Caras del contorno (panel por segmento del perfil)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([left[i], left[j], right[j], right[i]])

    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()

    # Materiales: Paint en todo; Glass en caras altas si corresponde
    mesh.materials.append(mats["Paint"])
    mesh.materials.append(mats["Glass"])
    if glass_range is not None:
        for poly in mesh.polygons:
            cy = sum(mesh.vertices[v].co.y for v in poly.vertices) / len(poly.vertices)
            # Solo caras del contorno superior (no las laterales completas)
            if cy > glass_range and abs(poly.normal.x) < 0.6:
                poly.material_index = 1

    # Bisel para que la luz marque los bordes
    bev = obj.modifiers.new("Bevel", "BEVEL")
    bev.width = bevel
    bev.segments = 2
    bev.limit_method = "ANGLE"
    bev.angle_limit = math.radians(40)

    return obj


def add_box(name, size, loc, mat, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    obj.data.materials.append(mat)
    if parent:
        obj.parent = parent
    return obj


def add_lights(parent, mats, front_z, rear_z, y=0.42, half_x=0.5):
    for sx in (-half_x, half_x):
        add_box("HL", (0.26, 0.12, 0.06), (sx, y, front_z), mats["LightF"], parent)
        add_box("TL", (0.3, 0.1, 0.06), (sx, y, rear_z), mats["LightR"], parent)


def add_wheel_arches(parent, mats, positions, radius=0.36, width=0.28):
    """Guardabarros simples sobre cada rueda."""
    for (x, z) in positions:
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8, radius=radius, depth=width,
            location=(x, 0.35, z), rotation=(0, math.pi / 2, 0))
        arch = bpy.context.active_object
        arch.name = "Arch"
        arch.data.materials.append(mats["Dark"])
        arch.parent = parent


# ── Los 6 autos ───────────────────────────────────────────────────────────────
# Perfiles: (z, y) con z negativo = frente. Sentido: piso frente → capot →
# parabrisas → techo → luneta → cola → piso atrás.

CARS = {
    "car_0_rally_hatch": {
        "profile": [(-1.62, 0.18), (-1.66, 0.52), (-0.86, 0.62), (-0.42, 1.02),
                    (0.78, 1.04), (1.34, 0.72), (1.6, 0.66), (1.62, 0.18)],
        "width": 1.62, "glass_above": 0.66,
        "spoiler": {"size": (1.5, 0.07, 0.38), "loc": (0, 1.06, 1.5)},
        "lights": (-1.64, 1.6, 0.45),
    },
    "car_1_muscle": {
        "profile": [(-1.95, 0.16), (-1.98, 0.5), (-0.55, 0.58), (-0.1, 0.95),
                    (0.95, 0.97), (1.5, 0.62), (1.92, 0.58), (1.95, 0.16)],
        "width": 1.74, "glass_above": 0.62,
        "spoiler": {"size": (1.74, 0.09, 0.3), "loc": (0, 0.72, 1.88)},
        "extra": [("Scoop", (0.5, 0.12, 0.6), (0, 0.66, -1.0), "Dark")],
        "lights": (-1.97, 1.94, 0.4),
    },
    "car_2_buggy": {
        "profile": [(-1.45, 0.2), (-1.48, 0.55), (-0.5, 0.62), (0.9, 0.62),
                    (1.42, 0.55), (1.45, 0.2)],
        "width": 1.55, "glass_above": None,
        "rollbar": True,
        "lights": (-1.47, 1.44, 0.45),
    },
    "car_3_classic": {
        "profile": [(-1.72, 0.2), (-1.76, 0.6), (-0.95, 0.68), (-0.5, 1.15),
                    (0.55, 1.18), (1.05, 0.72), (1.72, 0.66), (1.75, 0.2)],
        "width": 1.68, "glass_above": 0.72,
        "extra": [("BumperF", (1.74, 0.12, 0.14), (0, 0.26, -1.8), "Dark"),
                  ("BumperR", (1.74, 0.12, 0.14), (0, 0.26, 1.8), "Dark")],
        "lights": (-1.78, 1.78, 0.52),
    },
    "car_4_van": {
        "profile": [(-1.78, 0.2), (-1.82, 0.7), (-1.3, 0.78), (-1.05, 1.5),
                    (1.55, 1.52), (1.78, 0.85), (1.8, 0.2)],
        "width": 1.74, "glass_above": 0.95,
        "lights": (-1.8, 1.78, 0.5),
    },
    "car_5_wedge": {
        "profile": [(-1.85, 0.14), (-1.9, 0.3), (-0.3, 0.58), (0.55, 0.74),
                    (1.3, 0.72), (1.82, 0.55), (1.85, 0.14)],
        "width": 1.85, "glass_above": 0.6, "tumblehome": 0.72,
        "spoiler": {"size": (1.85, 0.06, 0.42), "loc": (0, 0.85, 1.72)},
        "lights": (-1.87, 1.84, 0.32),
    },
}

ARCH_POSITIONS = [(-0.78, -1.2), (0.78, -1.2), (-0.78, 1.2), (0.78, 1.2)]


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def build_car(name, spec):
    clear_scene()
    mats = make_materials()  # Recrear: clear_scene purga materiales sin uso

    body = build_body(
        name + "_body", spec["profile"], spec["width"], mats,
        glass_range=spec.get("glass_above"),
        tumblehome=spec.get("tumblehome", 0.82),
    )

    if "spoiler" in spec:
        sp = spec["spoiler"]
        add_box("Spoiler", sp["size"], sp["loc"], mats["Paint"], body)
        # Soportes
        w = sp["size"][0] * 0.36
        add_box("StrutL", (0.07, 0.22, 0.07), (-w, sp["loc"][1] - 0.14, sp["loc"][2]), mats["Dark"], body)
        add_box("StrutR", (0.07, 0.22, 0.07), (w, sp["loc"][1] - 0.14, sp["loc"][2]), mats["Dark"], body)

    if spec.get("rollbar"):
        add_box("RollL", (0.09, 0.7, 0.09), (-0.55, 0.95, 0.35), mats["Dark"], body)
        add_box("RollR", (0.09, 0.7, 0.09), (0.55, 0.95, 0.35), mats["Dark"], body)
        add_box("RollTop", (1.2, 0.09, 0.09), (0, 1.32, 0.35), mats["Dark"], body)
        add_box("Seat", (0.85, 0.4, 0.5), (0, 0.78, 0.45), mats["Dark"], body)
        add_box("Windshield", (1.2, 0.35, 0.06), (0, 0.85, -0.75), mats["Glass"], body)

    for extra in spec.get("extra", []):
        ename, esize, eloc, emat = extra
        add_box(ename, esize, eloc, mats[emat], body)

    fz, rz, ly = spec["lights"]
    add_lights(body, mats, fz, rz, ly)
    add_wheel_arches(body, mats, ARCH_POSITIONS)

    # Corregir convención de ejes (script Y-up → Blender Z-up)
    body.rotation_euler = (math.radians(90), 0, 0)

    # Seleccionar todo y exportar
    bpy.ops.object.select_all(action="SELECT")
    out = os.path.join(OUT_DIR, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=out, use_selection=True, export_apply=True)
    print("EXPORTED %s" % out)


def main():
    for name, spec in CARS.items():
        build_car(name, spec)
    print("ALL_CARS_DONE")


main()

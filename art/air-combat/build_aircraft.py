"""Build the air-combat redesign models: fighters, bombers, rotorcraft and mobile
anti-air for all three factions, plus their roster icons.

Rebuild faction GLBs with art/<faction>/build_aircraft.py. This shared builder
also generates the complete editable catalogue and icons when run directly.
"""
import json
import math
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
import weathering  # noqa: E402
import trim_sheet  # noqa: E402
import modeling  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/air-combat"
BUILD_FACTION = globals().get("BUILD_FACTION")
OUTPUT = {
    "bastion": (ROOT / "assets/models/bastion/air-v1", ROOT / "assets/ui/bastion"),
    "helix": (ROOT / "assets/models/helix/v1", ROOT / "assets/ui/helix"),
    "frontier": (ROOT / "assets/models/frontier/v1", ROOT / "assets/ui/frontier"),
}
for models, icons in OUTPUT.values():
    models.mkdir(parents=True, exist_ok=True)
    icons.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
bpy.context.preferences.filepaths.save_version = 0


def mat(name, color, metallic=.25, roughness=.5, emission=0, emission_color=None):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Emission Color"].default_value = (*(emission_color or color), 1)
    bsdf.inputs["Emission Strength"].default_value = emission
    return m


PALETTES = {
    "bastion": {
        "armor": mat("Bastion_Armor", (.072, .084, .074), .22, .48),
        "panel": mat("Bastion_Panels", (.155, .172, .150), .28, .44),
        "dark": mat("Bastion_Mechanisms", (.025, .031, .033), .58, .42),
        "steel": mat("Bastion_Steel", (.30, .34, .35), .78, .30),
        "nozzle": mat("Bastion_TitaniumNozzle", (.14, .135, .145), .88, .26),
        "team": mat("TeamColor_Bastion", (.68, .31, .02), .20, .44),
        "rubber": mat("Bastion_Rubber", (.016, .021, .023), 0, .86),
        "canopy": mat("Bastion_CanopyGlass", (.035, .072, .095), .55, .09, .04, (.12, .38, .48)),
        "glass": mat("Bastion_Optics", (.12, .58, .72), .25, .20, .65),
        "burn": mat("Bastion_Afterburner", (.95, .48, .12), .10, .15, 2.2),
        "mark": mat("Bastion_Markings", (.78, .77, .64), .10, .52),
    },
    "helix": {
        "armor": mat("Helix_Ceramic", (.70, .72, .67), .18, .36),
        "panel": mat("Helix_Secondary", (.36, .42, .42), .28, .42),
        "dark": mat("Helix_Graphite", (.024, .038, .045), .64, .34),
        "steel": mat("Helix_Titanium", (.24, .30, .33), .80, .28),
        "nozzle": mat("Helix_Nozzle", (.09, .12, .14), .86, .24),
        "team": mat("TeamColor_Helix", (.015, .24, .27), .26, .40),
        "rubber": mat("Helix_Rubber", (.012, .019, .021), 0, .88),
        "canopy": mat("Helix_CanopyGlass", (.022, .085, .125), .68, .07, .08, (.08, .55, .68)),
        "glass": mat("Helix_Optics", (.04, .70, .82), .25, .18, 1.5),
        "burn": mat("Helix_PlasmaCore", (.06, .82, .95), .10, .15, 2.4),
        "mark": mat("Helix_Warning", (.92, .24, .03), .12, .48),
    },
    "frontier": {
        "armor": mat("Frontier_Ceramic", (.24, .29, .17), .16, .52),
        "panel": mat("Frontier_Secondary", (.46, .38, .25), .24, .54),
        "dark": mat("Frontier_Graphite", (.028, .036, .038), .60, .44),
        "steel": mat("Frontier_Titanium", (.26, .30, .31), .76, .36),
        "nozzle": mat("Frontier_Exhaust", (.13, .11, .095), .82, .34),
        "team": mat("TeamColor_Frontier", (.72, .22, .055), .22, .46),
        "rubber": mat("Frontier_Rubber", (.014, .020, .021), 0, .88),
        "canopy": mat("Frontier_CanopyGlass", (.06, .08, .055), .46, .11, .03, (.25, .36, .22)),
        "glass": mat("Frontier_Optics", (.62, .80, .56), .25, .20, 1.1),
        "burn": mat("Frontier_Afterburner", (.96, .38, .08), .10, .18, 2.0),
        "mark": mat("Frontier_Canvas", (.70, .65, .48), 0, .86),
    },
}
P = PALETTES["bastion"]
assets = []
current = None
root = None


def begin(faction, name):
    global current, root, P
    P = PALETTES[faction]
    current = bpy.data.collections.new(faction + "_" + name)
    scene.collection.children.link(current)
    root = bpy.data.objects.new(name, None)
    current.objects.link(root)
    root["faction"] = faction
    root["forward"] = "-Z in Godot"
    assets.append((faction, name, current, root))
    return root


def attach(obj, name, material, parent=None, bevel=0, smooth=True, sharp_angle=35.0):
    return modeling.finalize_part(
        obj, current.name + "_" + name, current, material, parent or root,
        bevel=bevel, bevel_segments=2 if bevel >= .035 else 1,
        smooth=smooth, sharp_angle=sharp_angle,
    )


def box(name, xyz, size, material=None, parent=None, bevel=.025, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rot:
        obj.rotation_euler = rot
    return attach(obj, name, material or P["armor"], parent, bevel)


def cyl(name, xyz, radius, depth, material=None, parent=None, axis="Z", vertices=20):
    vertices = max(vertices, 18 if radius >= .12 else 12)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=xyz)
    obj = bpy.context.object
    if axis == "Y":
        obj.rotation_euler.x = math.pi / 2
    if axis == "X":
        obj.rotation_euler.y = math.pi / 2
    return attach(obj, name, material or P["dark"], parent, bevel=0, smooth=True, sharp_angle=35.0)


def rod(name, a, b, radius, material=None, parent=None, vertices=12):
    delta = Vector(b) - Vector(a)
    obj = cyl(name, (Vector(a) + Vector(b)) / 2, radius, delta.length, material or P["steel"], parent, vertices=vertices)
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    return obj


def shape(name, vertices, faces, material=None, parent=None, bevel=.015, smooth=True):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new(name, data)
    current.objects.link(obj)
    return attach(obj, name, material or P["armor"], parent, bevel, smooth=smooth)


def loft(name, rings, material=None, parent=None, bevel=0.0, sharp_angle=38.0):
    return modeling.loft_rings(
        current.name + "_" + name, rings, current, material or P["armor"], parent or root,
        closed_caps=True, bevel=bevel, bevel_segments=2 if bevel >= .04 else 1,
        smooth=True, sharp_angle=sharp_angle,
    )


def lathe(name, prof, origin, axis_dir, material=None, parent=None, segments=24, sharp_angle=36.0):
    return modeling.lathe_profile(
        current.name + "_" + name, prof, origin, axis_dir, segments,
        current, material or P["armor"], parent or root, smooth=True, sharp_angle=sharp_angle,
    )


def wedge(name, x, y, z, width, length, height, material=None, parent=None, taper=(.8, .7)):
    return loft(name, [
        modeling.rounded_rect_ring(width, length, min(width, length) * .14, x, y, z, 2),
        modeling.rounded_rect_ring(width * ((1 + taper[0]) * .5), length * .9, min(width, length) * .12, x, y - length * .04, z + height * .55, 2),
        modeling.rounded_rect_ring(width * taper[0], length * taper[1], min(width, length) * .10, x, y - length * .08, z + height, 2),
    ], material, parent, bevel=.02)


def pivot(name, xyz, parent=None, rot=None):
    obj = bpy.data.objects.new(current.name + "_" + name, None)
    current.objects.link(obj)
    obj.location = xyz
    if rot:
        obj.rotation_euler = rot
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = parent or root
    obj.matrix_world = world
    return obj


# --- Aerospace hard-surface primitives -------------------------------------------

def chine_ring(y, zc, w_top, w_chine, w_bot, h_top, h_bot, z_chine=0.0, cx=0.0):
    """12-point symmetric aerospace chined fuselage cross-section on the XZ plane at axial Y."""
    wt = max(w_top, 0.008)
    wc = max(w_chine, 0.010)
    wb = max(w_bot, 0.008)
    ht = max(h_top, 0.008)
    hb = max(h_bot, 0.008)
    zc_off = zc + z_chine
    # Counter-clockwise around +Y looking forward: top-center -> starboard -> belly -> port
    pts = [
        (0.0, zc + ht),
        (wt * 0.58, zc + ht * 0.90),
        (wt, zc + ht * 0.56),
        (wc, zc_off),
        (wb, zc - hb * 0.62),
        (wb * 0.52, zc - hb),
        (0.0, zc - hb),
        (-wb * 0.52, zc - hb),
        (-wb, zc - hb * 0.62),
        (-wc, zc_off),
        (-wt, zc + ht * 0.56),
        (-wt * 0.58, zc + ht * 0.90),
    ]
    return [(cx + x, y, z) for x, z in pts]


def chined_fuselage(name, stations, mat_override=None, parent=None, sharp_angle=34.0, cx=0.0):
    """Loft a chined fuselage from (y, zc, w_top, w_chine, w_bot, h_top, h_bot, z_chine) tuples."""
    rings = [chine_ring(*st, cx=cx) for st in stations]
    return loft(name, rings, mat_override or P["armor"], parent, bevel=0.0, sharp_angle=sharp_angle)


def canopy_assembly(name, stations, arch_indices=(1, 2), glass_mat=None, frame_mat=None, parent=None):
    """Sculpted dark reflective teardrop/faceted canopy with recessed structural frame arches."""
    gmat = glass_mat or P["canopy"]
    fmat = frame_mat or P["dark"]
    rings = []
    for y, z_base, w, h in stations:
        w = max(w, 0.01)
        h = max(h, 0.01)
        pts = [
            (0.0, z_base + h),
            (w * 0.55, z_base + h * 0.86),
            (w * 0.94, z_base + h * 0.44),
            (w, z_base),
            (w * 0.60, z_base - 0.04),
            (-w * 0.60, z_base - 0.04),
            (-w, z_base),
            (-w * 0.94, z_base + h * 0.44),
            (-w * 0.55, z_base + h * 0.86),
        ]
        rings.append([(x, y, z) for x, z in pts])
    loft(name + "_Glass", rings, gmat, parent, bevel=0.0, sharp_angle=44.0)

    # Lower sill frame hugging the fuselage seam
    sill_rings = []
    for y, z_base, w, _h in stations:
        w = max(w, 0.015) + 0.025
        sill_rings.append([
            (w, z_base + 0.03),
            (w + 0.02, z_base - 0.04),
            (-w - 0.02, z_base - 0.04),
            (-w, z_base + 0.03),
        ])
    # Wrap structural bow arches at key stations for authentic fighter/gunship cockpit silhouette
    for idx in arch_indices:
        if 0 < idx < len(stations) - 1:
            y, z_base, w, h = stations[idx]
            w_o, h_o = w + 0.026, h + 0.026
            band_a, band_b = [], []
            for dy in (-0.036, 0.036):
                target = band_a if dy < 0 else band_b
                for t in range(9):
                    ang = math.pi * (t / 8.0)
                    target.append((math.cos(ang) * w_o, y + dy, z_base + math.sin(ang) * h_o))
                for t in range(8, -1, -1):
                    ang = math.pi * (t / 8.0)
                    target.append((math.cos(ang) * (w - 0.01), y + dy, z_base + math.sin(ang) * (h - 0.01)))
            loft(f"{name}_Bow{idx}", [band_a, band_b], fmat, parent, bevel=0.0, sharp_angle=32.0)


def airfoil_fin(name, root_x, tip_x, root_y_lead, root_y_trail, tip_y_lead, tip_y_trail,
                root_z, tip_z, t_root=0.09, t_tip=0.04, mat_override=None, parent=None):
    """True symmetric airfoil vertical or canted tail stabilizer (replaces flat triangular slabs)."""
    # 6-point symmetric supersonic diamond-camber airfoil cross-section
    prof = [
        (0.0, 0.0),      # leading edge
        (0.28, 0.50),    # upper-right shoulder
        (0.68, 0.42),    # aft-right shoulder
        (1.0, 0.0),      # trailing edge
        (0.68, -0.42),   # aft-left shoulder
        (0.28, -0.50),   # upper-left shoulder
    ]
    def make_ring(cx, y_le, y_te, z, thick):
        return [(cx + fx * thick, y_le + (y_te - y_le) * fy, z) for fy, fx in prof]
    mid_x = (root_x + tip_x) * 0.5
    mid_le = (root_y_lead + tip_y_lead) * 0.5
    mid_te = (root_y_trail + tip_y_trail) * 0.5
    mid_z = (root_z + tip_z) * 0.5
    mid_t = (t_root + t_tip) * 0.5
    rings = [
        make_ring(root_x, root_y_lead, root_y_trail, root_z, t_root),
        make_ring(mid_x, mid_le, mid_te, mid_z, mid_t),
        make_ring(tip_x, tip_y_lead, tip_y_trail, tip_z, t_tip),
    ]
    return loft(name, rings, mat_override or P["armor"], parent, bevel=0.0, sharp_angle=35.0)


def wing_stripe(name, x0, y0, x1, y1, chord0, chord1, z0, z1, mat_override=None, parent=None):
    """Flush swept team-color insignia band following a wing's exact sweep and taper."""
    thick = 0.018
    r0 = [
        (x0, y0 + chord0 * 0.5, z0),
        (x0, y0 - chord0 * 0.5, z0),
        (x0, y0 - chord0 * 0.5, z0 + thick),
        (x0, y0 + chord0 * 0.5, z0 + thick),
    ]
    r1 = [
        (x1, y1 + chord1 * 0.5, z1),
        (x1, y1 - chord1 * 0.5, z1),
        (x1, y1 - chord1 * 0.5, z1 + thick),
        (x1, y1 + chord1 * 0.5, z1 + thick),
    ]
    return loft(name, [r0, r1], mat_override or P["team"], parent, bevel=0.0, sharp_angle=30.0)


def jet_nozzle(name, center, r_base, r_exit, length, parent=None, burn_mat=None):
    """Convergent-divergent metallic afterburner nozzle with stepped petals and glowing core."""
    cx, cy, cz = center
    # Outer metallic shrouded petal housing
    lathe(name + "_Shroud", [
        (r_base * 0.96, 0.0),
        (r_base * 1.02, -length * 0.18),
        (r_base * 0.94, -length * 0.52),
        (r_exit * 1.06, -length * 0.58),
        (r_exit, -length),
        (r_exit * 0.80, -length),
        (r_exit * 0.72, -length * 0.35),
        (0.0, -length * 0.25),
    ], (cx, cy, cz), (0, 1, 0), P["nozzle"], parent, segments=20, sharp_angle=34.0)
    # Recessed luminous afterburner core disc
    cyl(name + "_Core", (cx, cy - length * 0.84, cz), r_exit * 0.68, 0.05,
        burn_mat or P["burn"], parent, axis="Y", vertices=18)


def caret_intake(name, side, y_front, y_back, x_in, x_out, z_bot, z_top, mat_override=None, parent=None):
    """Sculpted angled supersonic intake nacelle with dark recessed throat."""
    # Swept forward lip for authentic jet caret profile
    lip_lead = 0.24
    r_front = [
        (side * x_in, y_front + lip_lead, z_top),
        (side * x_out, y_front, z_top - 0.04),
        (side * (x_out - 0.04), y_front - 0.10, z_bot),
        (side * x_in, y_front + 0.06, z_bot),
    ]
    r_mid = [
        (side * x_in, (y_front + y_back) * 0.5, z_top + 0.02),
        (side * (x_out + 0.03), (y_front + y_back) * 0.5, z_top - 0.03),
        (side * (x_out - 0.02), (y_front + y_back) * 0.5, z_bot),
        (side * x_in, (y_front + y_back) * 0.5, z_bot),
    ]
    r_back = [
        (side * x_in, y_back, z_top - 0.02),
        (side * (x_out - 0.06), y_back, z_top - 0.06),
        (side * (x_out - 0.10), y_back, z_bot + 0.04),
        (side * x_in, y_back, z_bot + 0.04),
    ]
    if side < 0:
        r_front, r_mid, r_back = list(reversed(r_front)), list(reversed(r_mid)), list(reversed(r_back))
    loft(name + "_Duct", [r_front, r_mid, r_back], mat_override or P["panel"], parent, bevel=0.012)
    # Dark intake cavity face
    xc = side * ((x_in + x_out) * 0.5)
    zc = (z_bot + z_top) * 0.5
    box(name + "_Throat", (xc, y_front + 0.02, zc), (abs(x_out - x_in) * 0.78, 0.08, (z_top - z_bot) * 0.74),
        P["dark"], parent, bevel=0.008)


def finned_missile(name, x, y, z, length=1.05, radius=0.065, parent=None):
    """Realistic air-to-air / AGM missile with ogive seeker, warhead band, and cruciform fins."""
    cyl(name + "_Body", (x, y, z), radius, length, P["mark"], parent, axis="Y", vertices=12)
    lathe(name + "_Seeker", [
        (radius, 0.0), (radius * 0.84, 0.09), (radius * 0.42, 0.18), (0.0, 0.24),
    ], (x, y + length * 0.5, z), (0, 1, 0), P["dark"], parent, segments=12)
    cyl(name + "_Band", (x, y + length * 0.24, z), radius * 1.05, 0.09, P["team"], parent, axis="Y", vertices=12)
    # Cruciform tail fins & forward control canards
    for ang_deg in (45, 135):
        rad = math.radians(ang_deg)
        box(f"{name}_TailFin_{ang_deg}", (x, y - length * 0.36, z), (radius * 3.8, 0.16, 0.018),
            P["dark"], parent, bevel=0.0, rot=(0, rad, 0))
        box(f"{name}_Canard_{ang_deg}", (x, y + length * 0.28, z), (radius * 2.5, 0.10, 0.014),
            P["dark"], parent, bevel=0.0, rot=(0, rad, 0))


def pylon_and_missiles(name, x, y, z_wing, count=1, length=1.05, radius=0.065, parent=None):
    """Aerodynamic underwing weapons pylon carrying one or two finned missiles."""
    box(name + "_Pylon", (x, y + 0.05, z_wing - 0.13), (0.075, 0.68, 0.24), P["dark"], parent, bevel=0.01)
    if count == 2:
        box(name + "_Rack", (x, y + 0.05, z_wing - 0.24), (0.34, 0.42, 0.045), P["steel"], parent, bevel=0.008)
    for idx in range(count):
        dx = (idx - (count - 1) * 0.5) * radius * 3.4
        finned_missile(f"{name}_M{idx}", x + dx, y, z_wing - 0.28 - radius, length, radius, parent)


def gear(points, height=.5):
    for x, y in points:
        rod("GearStrut", (x, y, .18), (x, y, height), .042, P["steel"], vertices=10)
        rod("GearBrace", (x, y - .18, height * .85), (x, y, .26), .024, P["dark"], vertices=8)
        modeling.detailed_wheel(
            current.name + f"_GearWheel_{x:.2f}_{y:.2f}", (x, y, .15),
            .15, .10, 1 if x >= 0 else -1, current, P["rubber"], P["steel"], P["steel"], root, segments=16, lug_count=0,
        )


def rotor(name, xyz, radius, blades, parent=None, axis="Z"):
    hub = pivot(name, xyz, parent)
    modeling.pitched_rotor(current.name + "_Fan_" + name, xyz, radius, blades, current, P["steel"], P["dark"], hub, axis=axis)
    return hub


def tracks(width=2.0, length=2.8):
    for side in (-1, 1):
        x = side * width / 2
        loft("TrackBelt", [
            modeling.rounded_rect_ring(.50, length, .20, x, 0, .06, 2),
            modeling.rounded_rect_ring(.52, length * 1.02, .22, x, 0, .42, 2),
            modeling.rounded_rect_ring(.50, length, .20, x, 0, .78, 2),
        ], P["rubber"], bevel=0)
        for i in range(5):
            y = -length * .37 + i * length * .185
            cyl("Wheel", (x + side * .26, y, .43), .25, .06, P["panel"], axis="X", vertices=18)
        box("Fender", (x, 0, .89), (.65, length, .13), bevel=.03)


def wheels(width=2.1, positions=(-1.0, .2, 1.1), radius=.42):
    for side in (-1, 1):
        for y in positions:
            modeling.detailed_wheel(
                current.name + f"_Wheel_{side}_{y:.2f}", (side * width / 2, y, radius),
                radius, .34, side, current, P["rubber"], P["steel"], P["team"], root, segments=20, lug_count=10,
            )


# --- Bastion ---------------------------------------------------------------------

def bastion_fighter():
    """Heavy twin-engine air-superiority strike jet (F-15EX / F-22 / F/A-18 lineage)."""
    begin("bastion", "Fighter")
    # Chined stealth-industrial fuselage with nose radome, broad engine bay, and dorsal spine
    chined_fuselage("Fuselage", [
        (-2.55, .64, .46, .58, .50, .24, .22, .00),
        (-1.45, .66, .56, .74, .60, .30, .24, .01),
        (0.10, .66, .52, .78, .58, .32, .24, .02),
        (1.35, .64, .38, .58, .44, .30, .22, .02),
        (2.35, .61, .24, .36, .28, .22, .16, .01),
        (3.25, .58, .10, .14, .11, .10, .09, .00),
        (3.75, .56, .012, .015, .012, .012, .012, .00),
    ])
    # Dark radar nosecone cap + pitot needle
    lathe("Radome", [
        (.15, 3.18), (.10, 3.45), (.04, 3.68), (0.0, 3.82),
    ], (0, 0, .57), (0, 1, 0), P["dark"], segments=18)
    rod("Pitot", (0, 3.78, .56), (0, 4.02, .56), .012, P["steel"], vertices=8)
    # Sculpted dorsal avionics spine tapering into aft deck
    chined_fuselage("Spine", [
        (-2.35, .86, .16, .24, .28, .10, .04, .00),
        (-0.80, .92, .22, .32, .38, .15, .06, .00),
        (0.65, .92, .24, .32, .36, .16, .06, .00),
    ], P["panel"])
    # Framed bubble teardrop fighter canopy
    canopy_assembly("Canopy", [
        (0.55, .92, .25, .14),
        (1.05, .93, .29, .26),
        (1.62, .88, .26, .23),
        (2.12, .79, .18, .13),
        (2.42, .72, .07, .04),
    ], arch_indices=(1, 2, 3))
    # Twin engine nacelles, caret intakes, swept wings, LERX strakes, twin canted tails
    for side in (-1, 1):
        # Leading-Edge Root Extension (LERX) strake flowing from intake into wing
        modeling.airfoil_wing(
            current.name + f"_LERX_{side}", (side * .38, 1.05), (side * .88, .48),
            1.65, .95, .64, .62, .14, .10, current, P["armor"], root, bevel=.01,
        )
        # Main swept trapezoidal delta-hybrid wing
        modeling.airfoil_wing(
            current.name + f"_Wing_{side}", (side * .64, -.02), (side * 2.75, -1.25),
            1.88, .52, .60, .55, .15, .055, current, P["panel"], root, bevel=.012,
        )
        # Flush swept team-color chevron band on outer wing
        wing_stripe(f"WingTeam_{side}", side * 1.65, -.64, side * 2.42, -1.08, .38, .24, .65, .60)
        # Wingtip missile rail + Sidewinder
        box(f"TipRail_{side}", (side * 2.77, -1.22, .55), (.06, .78, .07), P["dark"], bevel=.008)
        finned_missile(f"TipAAM_{side}", side * 2.83, -1.10, .55, .86, .048)
        # Flap track fairings under wing
        for fx, fy in ((1.22, -.88), (1.92, -1.16)):
            lathe(f"FlapFairing_{side}_{fx:.1f}", [
                (.02, -.24), (.045, -.10), (.045, .14), (.015, .22),
            ], (side * fx, fy, .49), (0, 1, 0), P["dark"], segments=10)
        # Underwing ordnance pylon + twin missiles
        pylon_and_missiles(f"Pylon_{side}", side * 1.48, -.68, .54, count=2, length=1.02, radius=.058)
        # Caret supersonic air intake with dark throat
        caret_intake(f"Intake_{side}", side, .96, -.45, .44, .82, .45, .79)
        # Twin canted airfoil vertical tail fins
        airfoil_fin(
            f"TailFin_{side}", side * .46, side * .74,
            -1.42, -2.52, -2.18, -2.68, .82, 1.88, .09, .042, P["armor"],
        )
        # Flush team flash near top of vertical stabilizer
        box(f"FinMark_{side}", (side * .67, -2.36, 1.56), (.07, .32, .12), P["team"], bevel=.006,
            rot=(0, side * math.radians(-14), 0))
        # Swept all-moving horizontal tailplanes
        modeling.airfoil_wing(
            current.name + f"_Stabilizer_{side}", (side * .56, -2.18), (side * 1.58, -2.66),
            .78, .30, .62, .59, .085, .04, current, P["panel"], root, bevel=.008,
        )
        # Twin convergent-divergent titanium afterburner nozzles
        jet_nozzle(f"Nozzle_{side}", (side * .30, -2.50, .63), .24, .19, .46)
    # Recessed rotary cannon port + chin FLIR targeting pod
    cyl("CannonShroud", (.38, 1.75, .74), .065, .45, P["dark"], axis="Y", vertices=12)
    cyl("CannonBarrel", (.38, 2.04, .74), .038, .30, P["steel"], axis="Y", vertices=12)
    modeling.sensor_pod(current.name + "_ChinFLIR", (0, 2.58, .40), .62, (0, 1, 0), current, P["dark"], P["glass"], P["steel"], root)
    gear([(0, 2.05), (-.82, -.65), (.82, -.65)], .44)
    pivot("Muzzle", (0, 3.85, .56))


def bastion_bomber():
    """Heavy armored 4-turboprop tactical gunship-bomber (preserves RotorA/B/C/D)."""
    begin("bastion", "Bomber")
    # Heavy muscular chined armored fuselage with stepped flight deck & tailcone
    chined_fuselage("Fuselage", [
        (-3.55, .82, .22, .30, .24, .22, .18, .02),
        (-2.35, .84, .46, .58, .50, .38, .34, .02),
        (-0.80, .86, .60, .74, .66, .48, .44, .00),
        (1.30, .86, .62, .76, .68, .48, .44, .00),
        (2.45, .82, .52, .64, .56, .44, .38, -.02),
        (3.35, .74, .34, .44, .38, .28, .26, -.02),
        (3.92, .70, .14, .18, .15, .14, .12, .00),
        (4.15, .69, .02, .025, .02, .02, .02, .00),
    ])
    # Nose weather/ground-mapping radome cap
    lathe("NoseRadome", [
        (.24, 3.65), (.18, 3.92), (.08, 4.10), (0.0, 4.20),
    ], (0, 0, .69), (0, 1, 0), P["dark"], segments=18)
    # Armored stepped flight deck cockpit with dark multi-pane glazing & heavy mullions
    canopy_assembly("Cockpit", [
        (1.65, 1.24, .44, .18),
        (2.35, 1.22, .47, .24),
        (2.98, 1.06, .38, .19),
        (3.26, .95, .24, .08),
    ], arch_indices=(1, 2))
    # Heavy center wing-root fairing & dorsal ECM radome
    chined_fuselage("WingFairing", [
        (-1.10, 1.28, .48, .64, .70, .18, .08, .00),
        (0.20, 1.30, .54, .72, .76, .20, .08, .00),
        (1.35, 1.28, .44, .58, .64, .16, .08, .00),
    ], P["panel"])
    cyl("DorsalRadome", (0, -.55, 1.54), .34, .12, P["panel"], vertices=20)
    cyl("RadomeRing", (0, -.55, 1.55), .36, .04, P["dark"], vertices=20)
    # Flush dorsal fuselage command stripe
    box("TeamStripe", (0, -1.75, 1.26), (.68, .46, .025), P["team"], bevel=.008)
    # Recessed armored bomb bay with twin bay doors
    box("BombBayFrame", (0, .05, .41), (.96, 2.25, .08), P["dark"], bevel=.015)
    for side in (-1, 1):
        box(f"BayDoor_{side}", (side * .25, .05, .38), (.42, 2.08, .04), P["panel"], bevel=.008)
        # Main landing gear sponsons along lower fuselage flanks
        chined_fuselage(f"GearSponson_{side}", [
            (-0.95, .48, .12, .22, .20, .16, .14, .00),
            (0.05, .48, .16, .28, .26, .20, .16, .00),
            (0.95, .48, .10, .18, .16, .14, .12, .00),
        ], P["panel"], cx=side * .68)
        # High-mounted heavy tapered airfoil wings
        modeling.airfoil_wing(
            current.name + f"_Wing_{side}", (side * .58, .30), (side * 4.15, -.18),
            1.82, .66, 1.26, 1.14, .22, .085, current, P["panel"], root, bevel=.012,
        )
        # Subtle swept wingtip team-color band
        wing_stripe(f"WingTeam_{side}", side * 3.15, -.05, side * 3.82, -.14, .52, .38, 1.26, 1.22)
        # Wingtip ECM pods
        lathe(f"TipPod_{side}", [
            (0.0, -.42), (.085, -.30), (.09, .28), (0.0, .42),
        ], (side * 4.18, -.18, 1.14), (0, 1, 0), P["dark"], segments=12)
        # Twin underslung sculpted turboprop nacelles + radiator scoops + 4-blade rotors
        for x, y_nac in ((1.42, .42), (2.68, .28)):
            lathe(f"Nacelle_{side}_{x:.1f}", [
                (.14, -.92), (.26, -.62), (.31, .15), (.30, .68), (.22, .86), (.12, .92),
            ], (side * x, y_nac, 1.02), (0, 1, 0), P["armor"], segments=18)
            # Chin oil-cooler scoop + dark exhaust pipe
            box(f"Scoop_{side}_{x:.1f}", (side * x, y_nac + .55, .74), (.22, .42, .14), P["dark"], bevel=.012)
            cyl(f"Exhaust_{side}_{x:.1f}", (side * x, y_nac - .88, 1.04), .12, .22, P["nozzle"], axis="Y", vertices=14)
            letter = ("A" if x < 2 else "B") if side < 0 else ("C" if x < 2 else "D")
            rotor("Rotor" + letter, (side * x, y_nac + .96, 1.02), .68, 4, axis="Y")
        # Heavy airfoil horizontal tailplane + tall twin airfoil H-tail vertical fins
        modeling.airfoil_wing(
            current.name + f"_Stabilizer_{side}", (side * .36, -3.12), (side * 2.02, -3.38),
            .84, .48, 1.06, 1.08, .11, .065, current, P["panel"], root, bevel=.008,
        )
        airfoil_fin(
            f"TailFin_{side}", side * 1.98, side * 1.98,
            -2.74, -3.62, -3.02, -3.72, .84, 2.22, .11, .055, P["armor"],
        )
        box(f"FinBand_{side}", (side * 1.98, -3.32, 1.94), (.09, .48, .14), P["team"], bevel=.006)
    # Nose chin FLIR turret + rear tail defense gun turret
    modeling.sensor_pod(current.name + "_ChinFLIR", (0, 3.15, .44), .70, (0, 1, 0), current, P["dark"], P["glass"], P["steel"], root)
    cyl("TailTurret", (0, -3.62, .80), .20, .28, P["dark"], axis="Y", vertices=14)
    for sx in (-.06, .06):
        cyl(f"TailGun_{sx:.2f}", (sx, -3.88, .80), .028, .46, P["steel"], axis="Y", vertices=10)
    gear([(0, 2.85), (-.98, -.15), (.98, -.15)], .42)
    pivot("Muzzle", (0, .05, .34))


def bastion_helicopter():
    """Heavy armored tandem attack gunship (AH-64D Apache lineage; preserves RotorM & RotorT)."""
    begin("bastion", "Helicopter")
    # Faceted armored narrow tandem gunship fuselage
    chined_fuselage("Pod", [
        (-1.55, .94, .22, .32, .26, .28, .22, .00),
        (-0.45, .90, .42, .56, .48, .40, .38, .00),
        (0.75, .84, .44, .58, .50, .38, .36, .00),
        (1.68, .72, .32, .42, .36, .28, .26, .00),
        (2.18, .64, .18, .24, .20, .18, .16, .00),
    ])
    # Armored side EFAB avionics cheek bays
    for side in (-1, 1):
        chined_fuselage(f"CheekBay_{side}", [
            (-0.55, .72, .14, .20, .18, .22, .18, .00),
            (0.55, .70, .15, .22, .18, .22, .18, .00),
            (1.38, .66, .10, .14, .12, .16, .14, .00),
        ], P["panel"], cx=side * .54)
    # Tandem armored stepped gunship canopy with thick structural framing
    canopy_assembly("Canopy", [
        (0.05, 1.24, .32, .14),
        (0.58, 1.26, .34, .28),
        (1.16, 1.18, .32, .26),
        (1.68, 1.00, .25, .18),
        (1.98, .88, .14, .06),
    ], arch_indices=(1, 2, 3))
    # Twin side-mounted armored turboshaft engine nacelles + IR-suppressor exhaust shrouds
    box("TransmissionDeck", (0, -.22, 1.44), (.74, 1.48, .38), P["panel"], bevel=.04)
    for side in (-1, 1):
        lathe(f"Turboshaft_{side}", [
            (.14, -.82), (.24, -.55), (.25, .48), (.20, .72), (.13, .76),
        ], (side * .52, -.30, 1.32), (0, 1, 0), P["armor"], segments=16)
        cyl(f"TurbineIntake_{side}", (side * .52, .48, 1.32), .16, .08, P["dark"], axis="Y", vertices=14)
        # Black Hole IR suppressor side-vented exhaust fairing
        box(f"IRSuppressor_{side}", (side * .64, -.92, 1.34), (.22, .44, .26), P["nozzle"], bevel=.025)
    # Detailed main rotor mast, swashplate, 4-blade pitched main rotor & mast-mounted fire-control radar
    cyl("MastBase", (0, .02, 1.72), .16, .22, P["dark"], vertices=16)
    cyl("Swashplate", (0, .02, 1.88), .22, .06, P["steel"], vertices=16)
    cyl("MastShaft", (0, .02, 1.98), .085, .32, P["steel"], vertices=16)
    rotor("RotorM", (0, .02, 2.08), 2.55, 4)
    # Longbow-style mast-mounted radar dome above hub
    lathe("MastRadar", [
        (0.0, 2.18), (.24, 2.22), (.30, 2.30), (.24, 2.38), (0.0, 2.41),
    ], (0, .02, 0), (0, 0, 1), P["panel"], segments=18)
    # Tapered hexagonal armored tail boom (replaces thin cylinder rod)
    chined_fuselage("TailBoom", [
        (-3.28, 1.24, .09, .13, .10, .14, .12, .00),
        (-2.25, 1.12, .15, .20, .16, .20, .18, .00),
        (-1.25, 1.00, .24, .32, .26, .28, .24, .00),
    ], P["armor"])
    box("TeamStripe", (0, -1.92, 1.30), (.26, .58, .025), P["team"], bevel=.006)
    # Swept airfoil vertical tail fin + low horizontal stabilator + 4-blade tail rotor
    airfoil_fin("TailFin", 0.0, 0.0, -2.72, -3.45, -3.12, -3.65, 1.08, 2.18, .12, .055, P["armor"])
    modeling.airfoil_wing(
        current.name + "_TailStabL", (-.08, -3.18), (-.82, -3.28),
        .38, .26, 1.20, 1.20, .07, .045, current, P["panel"], root, bevel=.008,
    )
    modeling.airfoil_wing(
        current.name + "_TailStabR", (.08, -3.18), (.82, -3.28),
        .38, .26, 1.20, 1.20, .07, .045, current, P["panel"], root, bevel=.008,
    )
    cyl("TailGearbox", (.12, -3.32, 1.54), .11, .20, P["dark"], axis="X", vertices=14)
    rotor("RotorT", (.24, -3.32, 1.54), .54, 4, axis="X")
    # Armored stub wings with rocket pods + Hellfire missile racks + armored skids
    for side in (-1, 1):
        modeling.airfoil_wing(
            current.name + f"_StubWing_{side}", (side * .48, .05), (side * 1.62, -.16),
            .68, .44, .82, .74, .13, .08, current, P["panel"], root, bevel=.01,
        )
        wing_stripe(f"StubTeam_{side}", side * .75, -.02, side * 1.42, -.14, .28, .22, .88, .82)
        # Inner 19-tube rocket pod with dark recessed face
        cyl(f"RocketPod_{side}", (side * 1.02, -.05, .56), .18, .92, P["dark"], axis="Y", vertices=16)
        cyl(f"PodBand_{side}", (side * 1.02, .22, .56), .19, .10, P["team"], axis="Y", vertices=16)
        cyl(f"PodFace_{side}", (side * 1.02, .42, .56), .15, .04, P["steel"], axis="Y", vertices=14)
        # Outer twin-rail Hellfire AGM pylon
        pylon_and_missiles(f"AGM_{side}", side * 1.48, -.10, .72, count=2, length=.88, radius=.052)
        # Heavy braced armored landing skids
        rod(f"Skid_{side}", (side * .64, -.95, .08), (side * .64, 1.28, .08), .048, P["steel"], vertices=12)
        rod(f"SkidTip_{side}", (side * .64, 1.28, .08), (side * .64, 1.48, .22), .042, P["steel"], vertices=10)
        rod(f"SkidStrutF_{side}", (side * .64, .65, .08), (side * .42, .65, .54), .038, P["dark"], vertices=10)
        rod(f"SkidStrutA_{side}", (side * .64, -.52, .08), (side * .42, -.52, .56), .038, P["dark"], vertices=10)
    # Articulated under-chin 30mm chain gun turret + nose TADS/PNVS sensor turret
    cyl("ChinTurret", (0, 1.48, .38), .20, .24, P["dark"], vertices=16)
    box("GunReceiver", (0, 1.62, .32), (.18, .44, .16), P["panel"], bevel=.015)
    cyl("ChinGun", (0, 2.08, .31), .042, .66, P["steel"], axis="Y", vertices=12)
    modeling.sensor_pod(current.name + "_NoseTADS", (0, 2.24, .64), .76, (0, 1, 0), current, P["dark"], P["glass"], P["steel"], root)
    pivot("Muzzle", (0, 2.45, .31))


def bastion_flak():
    begin("bastion", "AntiAirVehicle")
    tracks(2.0, 3.0)
    wedge("Hull", 0, 0, .55, 1.75, 3.05, .55)
    box("TeamPlate", (0, -1.1, 1.12), (1.0, .35, .03), P["team"], bevel=.01)
    turret = pivot("TurretPivot", (0, -.1, 1.1))
    wedge("Turret", 0, -.1, 1.1, 1.25, 1.45, .6, P["panel"], turret)
    barrel = pivot("BarrelPivot", (0, .2, 1.45), turret, (math.radians(35), 0, 0))
    for side in (-1, 1):
        lathe("Autocannon", [
            (.09, .30), (.09, .75), (.065, .78), (.065, 1.72),
        ], (side * .28, 0, 1.45), (0, 1, 0), P["dark"], barrel, segments=16)
        cyl("MuzzleBrake", (side * .28, 1.78, 1.45), .09, .18, P["steel"], barrel, "Y", 16)
        box("AmmoDrum", (side * .62, -.1, 1.4), (.24, .7, .4), P["armor"], turret, .04)
    pivot("Muzzle", (0, 1.9, 1.45), barrel)
    rod("RadarMast", (0, -.75, 1.65), (0, -.75, 2.25), .05, P["steel"], turret, vertices=12)
    radar = pivot("SensorPivot", (0, -.75, 2.3), turret)
    box("RadarDish", (0, -.75, 2.35), (.9, .08, .45), P["panel"], radar, .025)
    modeling.sensor_pod(current.name + "_FCS", (.36, .45, 1.62), .75, (0, 1, 0), current, P["dark"], P["glass"], P["steel"], turret)
    for side in (-1, 1):
        modeling.era_tile_rack(current.name + f"_HullERA_{side}", (side * .92, -.95, .85), (side * .92, .95, .85), (side, 0, .2), 4, (.36, .06, .22), current, P["panel"], P["dark"], root)


# --- Helix -----------------------------------------------------------------------

def helix_fighter():
    """Next-gen forward-swept stealth aerospace interceptor (Su-47 Berkut / ADF-01 lineage)."""
    begin("helix", "TalonInterceptor")
    # Razor-chined stealth aerospace fuselage with flat belly and sharp aerodynamic strakes
    chined_fuselage("Fuselage", [
        (-2.75, .56, .38, .56, .46, .18, .15, .00),
        (-1.40, .58, .46, .72, .56, .24, .18, .01),
        (0.25, .58, .42, .68, .50, .26, .18, .02),
        (1.65, .56, .30, .48, .36, .22, .15, .02),
        (2.85, .54, .14, .24, .16, .12, .10, .01),
        (3.68, .53, .012, .018, .012, .012, .012, .00),
    ], P["armor"])
    # Graphite nose sensor probe & stealth radar tip
    lathe("SensorTip", [
        (.14, 3.10), (.08, 3.48), (0.0, 3.84),
    ], (0, 0, .53), (0, 1, 0), P["dark"], segments=16)
    # Sleek dorsal graphite spine & flush energy core conduit
    chined_fuselage("DorsalSpine", [
        (-2.55, .74, .14, .24, .30, .10, .04, .00),
        (-0.55, .80, .18, .30, .36, .13, .05, .00),
        (0.70, .80, .20, .30, .34, .12, .05, .00),
    ], P["panel"])
    box("SpineConduit", (0, -.85, .93), (.07, 1.85, .022), P["glass"], bevel=.006)
    # Flush polarized dark-iridium stealth canopy with sleek frame arches
    canopy_assembly("Canopy", [
        (0.60, .79, .22, .12),
        (1.15, .80, .25, .22),
        (1.78, .75, .21, .18),
        (2.35, .67, .12, .08),
    ], arch_indices=(1, 2))
    for side in (-1, 1):
        # Forward-swept blended wing-body strake + razor-clean forward-swept main wing
        modeling.airfoil_wing(
            current.name + f"_WingRoot_{side}", (side * .48, -.82), (side * 1.12, -.45),
            1.42, 1.02, .56, .56, .13, .10, current, P["panel"], root, bevel=.01,
        )
        modeling.airfoil_wing(
            current.name + f"_Wing_{side}", (side * .92, -.52), (side * 2.75, .78),
            1.02, .38, .56, .58, .10, .048, current, P["armor"], root, bevel=.01,
        )
        # Flush recessed cyan flux inlay along wing mid-chord (integrated into wing, not floating)
        wing_stripe(f"FluxChannel_{side}", side * .98, -.46, side * 2.52, .64, .10, .055, .61, .60, P["glass"])
        wing_stripe(f"WingTeam_{side}", side * 1.55, -.05, side * 2.38, .54, .34, .22, .62, .61, P["team"])
        # Forward swept stealth control canards
        modeling.airfoil_wing(
            current.name + f"_Canard_{side}", (side * .40, 1.62), (side * 1.24, 1.26),
            .56, .20, .58, .58, .07, .035, current, P["panel"], root, bevel=.008,
        )
        # Diverterless supersonic stealth side intakes
        caret_intake(f"DSI_{side}", side, .82, -.55, .36, .66, .42, .68, P["dark"])
        # Sharply canted stealth airfoil V-tails
        airfoil_fin(
            f"TailFin_{side}", side * .34, side * .92,
            -1.45, -2.62, -2.02, -2.80, .70, 1.66, .085, .038, P["panel"],
        )
        box(f"TailMark_{side}", (side * .72, -2.28, 1.32), (.05, .34, .10), P["team"], bevel=.006,
            rot=(0, side * math.radians(-30), 0))
        # Conformal underwing pulse-interceptor missile
        pylon_and_missiles(f"Pylon_{side}", side * 1.34, -.12, .51, count=1, length=.98, radius=.055)
        # Twin stealth 2D thrust-vectoring plasma nozzles
        box(f"VectorHousing_{side}", (side * .28, -2.72, .56), (.34, .46, .24), P["nozzle"], bevel=.02)
        box(f"PlasmaSlit_{side}", (side * .28, -2.96, .56), (.24, .05, .11), P["burn"], bevel=.006)
    gear([(0, 1.95), (-.68, -.78), (.68, -.78)], .42)
    pivot("Muzzle", (0, 3.80, .53))


def helix_bomber():
    """Stealth Blended-Wing-Body flying-wing plasma bomber (B-2 / B-21 Raider lineage)."""
    begin("helix", "ShrikeBomber")
    # TRUE multi-station airfoil Blended Wing Body (BWB) from centerline to swept wingtips
    # Each station is (x, y_le, y_te, z_mid, thick) — genuine cambered stealth flying wing!
    bwb_prof = [
        (0.00, 0.00),
        (0.14, 0.36),
        (0.34, 0.54),
        (0.62, 0.40),
        (0.86, 0.16),
        (1.00, 0.01),
        (1.00, -0.02),
        (0.70, -0.22),
        (0.32, -0.34),
        (0.12, -0.24),
    ]
    def bwb_ring(x, y_le, y_te, z_mid, thick):
        chord = y_le - y_te
        return [(x, y_le - fy * chord, z_mid + fz * thick) for fy, fz in bwb_prof]

    # Symmetric sawtooth B-2 planform across 11 spanwise stations (-4.35 to +4.35)
    half_stations = [
        (0.00, 2.75, -1.78, .72, .72),
        (0.68, 2.15, -1.32, .72, .58),
        (1.38, 1.48, -1.62, .71, .44),
        (2.32, 0.60, -1.18, .70, .30),
        (3.48, -0.48, -1.82, .68, .18),
        (4.32, -1.26, -2.02, .67, .09),
    ]
    full_stations = [(-x, le, te, zm, th) for x, le, te, zm, th in reversed(half_stations[1:])] + half_stations
    loft("BlendedWingBody", [bwb_ring(*st) for st in full_stations], P["armor"], bevel=0.0, sharp_angle=36.0)

    # Sculpted dorsal stealth fairing & recessed 4-pane B-2 brow cockpit
    chined_fuselage("DorsalHump", [
        (-1.45, .96, .26, .48, .66, .16, .06, .00),
        (0.35, 1.00, .42, .68, .86, .24, .06, .00),
        (1.75, .96, .34, .54, .68, .20, .06, .00),
        (2.42, .84, .12, .22, .30, .08, .04, .00),
    ], P["panel"])
    canopy_assembly("Cockpit", [
        (1.18, 1.12, .38, .14),
        (1.65, 1.10, .42, .18),
        (2.12, .98, .32, .12),
        (2.34, .88, .16, .04),
    ], arch_indices=(1, 2))

    # Recessed stealth serrated S-duct intakes, shielded plasma exhaust troughs, and wing markings
    for side in (-1, 1):
        # Dorsal S-duct stealth engine intake pod
        chined_fuselage(f"SDuct_{side}", [
            (-1.25, .92, .16, .24, .28, .16, .06, .00),
            (0.25, .96, .22, .32, .36, .22, .06, .00),
            (1.18, .92, .20, .28, .32, .18, .06, .00),
        ], P["panel"], cx=side * .88)
        box(f"IntakeLip_{side}", (side * .88, 1.20, 1.00), (.36, .12, .18), P["dark"], bevel=.012)
        # Shielded upper exhaust trough + recessed cyan plasma thrust slit
        box(f"ExhaustTrough_{side}", (side * .88, -1.24, .94), (.38, .44, .14), P["nozzle"], bevel=.012)
        box(f"PlasmaSlit_{side}", (side * .88, -1.46, .95), (.28, .06, .07), P["burn"], bevel=.005)
        # Integrated subtle flux ribs & swept team-color insignia along outer wing
        wing_stripe(f"FluxRib_{side}", side * 1.48, .55, side * 3.85, -1.16, .12, .07, .89, .73, P["glass"])
        wing_stripe(f"WingTeam_{side}", side * 2.25, -.18, side * 3.45, -1.04, .56, .34, .86, .76, P["team"])
        # Stealth split-drag rudder tip accents
        box(f"TipRudder_{side}", (side * 3.92, -1.66, .71), (.52, .24, .04), P["dark"], bevel=.006,
            rot=(0, 0, side * math.radians(-42)))
    # Flush belly plasma-bomb bay with serrated doors
    box("BombBay", (0, .18, .48), (1.15, 1.85, .06), P["dark"], bevel=.012)
    for side in (-1, 1):
        box(f"BayDoor_{side}", (side * .29, .18, .46), (.50, 1.72, .03), P["panel"], bevel=.006)
    gear([(0, 1.72), (-1.18, -.52), (1.18, -.52)], .52)
    pivot("Muzzle", (0, .18, .46))


def helix_helicopter():
    """Sleek next-gen stealth VTOL tiltrotor gunship (V-280 Valor lineage; preserves RotorLeft & RotorRight)."""
    begin("helix", "WraithTiltrotor")
    # Faceted stealth chined gunship hull
    chined_fuselage("Body", [
        (-2.25, .84, .18, .26, .20, .20, .16, .00),
        (-1.15, .82, .42, .56, .48, .34, .28, .00),
        (0.35, .82, .52, .68, .58, .38, .32, .00),
        (1.48, .76, .38, .52, .42, .32, .24, .00),
        (2.35, .68, .18, .26, .20, .16, .14, .00),
        (2.68, .66, .04, .06, .04, .04, .04, .00),
    ], P["armor"])
    # Flush dark-iridium tandem stealth visor canopy
    canopy_assembly("Canopy", [
        (0.45, 1.12, .34, .16),
        (1.08, 1.12, .36, .24),
        (1.75, 1.00, .28, .18),
        (2.15, .86, .16, .07),
    ], arch_indices=(1, 2))
    # Dorsal drive-shaft fairing & optical mast
    chined_fuselage("SpineFairing", [
        (-1.35, 1.14, .18, .28, .34, .14, .05, .00),
        (0.15, 1.18, .26, .38, .44, .18, .06, .00),
        (0.85, 1.14, .20, .30, .36, .12, .05, .00),
    ], P["panel"])
    # High-mounted slightly swept gull/tapered tiltrotor wing
    for side in (-1, 1):
        modeling.airfoil_wing(
            current.name + f"_Wing_{side}", (side * .38, .04), (side * 2.28, -.10),
            .84, .56, 1.18, 1.24, .15, .10, current, P["panel"], root, bevel=.012,
        )
        wing_stripe(f"WingTeam_{side}", side * 1.15, -.02, side * 1.88, -.08, .36, .28, 1.28, 1.30, P["team"])
        # Sculpted aerodynamic wingtip tilt-rotor engine pod + intake scoop + plasma stabilizer ring
        lathe(f"Nacelle_{side}", [
            (.14, -.64), (.28, -.44), (.34, .05), (.32, .48), (.22, .68), (.12, .74),
        ], (side * 2.34, -.08, 1.24), (0, 0, 1), P["armor"], segments=20)
        box(f"NacelleIntake_{side}", (side * 2.34, .22, 1.14), (.26, .32, .42), P["dark"], bevel=.015)
        cyl(f"NacelleExhaust_{side}", (side * 2.34, -.08, .58), .19, .10, P["nozzle"], vertices=18)
        cyl(f"NacelleGlow_{side}", (side * 2.34, -.08, .54), .13, .04, P["burn"], vertices=16)
        rotor("RotorLeft" if side < 0 else "RotorRight", (side * 2.34, -.08, 2.02), 1.62, 4)
        # Conformal side weapons sponson + plasma rocket pod
        chined_fuselage(f"Sponson_{side}", [
            (-0.55, .64, .14, .22, .18, .16, .14, .00),
            (0.45, .64, .16, .24, .20, .18, .14, .00),
            (1.10, .64, .10, .14, .12, .12, .10, .00),
        ], P["panel"], cx=side * .64)
        cyl(f"RocketPod_{side}", (side * .92, .12, .62), .15, .86, P["dark"], axis="Y", vertices=16)
        cyl(f"PodRing_{side}", (side * .92, .40, .62), .16, .07, P["glass"], axis="Y", vertices=16)
        # Twin sharply canted airfoil V-tail stabilizers
        airfoil_fin(
            f"TailFin_{side}", side * .22, side * .78,
            -1.45, -2.28, -1.92, -2.45, .94, 1.72, .085, .04, P["panel"],
        )
        # Retractable landing skids / pads
        rod(f"Skid_{side}", (side * .56, -.78, .12), (side * .56, 1.05, .12), .038, P["steel"], vertices=10)
        rod(f"SkidLegF_{side}", (side * .56, .58, .12), (side * .40, .58, .52), .030, P["dark"], vertices=8)
        rod(f"SkidLegA_{side}", (side * .56, -.45, .12), (side * .40, -.45, .54), .030, P["dark"], vertices=8)
    # Nose electro-optical gimbal + recessed twin chin pulse cannon
    modeling.sensor_pod(current.name + "_NoseOptic", (0, 2.48, .58), .66, (0, 1, 0), current, P["dark"], P["glass"], P["steel"], root)
    cyl("ChinMount", (0, 1.65, .42), .16, .18, P["dark"], vertices=14)
    cyl("ChinGun", (0, 2.08, .38), .045, .62, P["steel"], axis="Y", vertices=12)
    pivot("Muzzle", (0, 2.42, .38))


def helix_aa():
    begin("helix", "HaloSkimmer")
    loft("Hull", [
        modeling.rounded_rect_ring(1.85, 3.05, .34, 0, 0, .30, 3),
        modeling.rounded_rect_ring(1.94, 3.16, .36, 0, 0, .56, 3),
        modeling.rounded_rect_ring(1.52, 2.65, .28, 0, -.06, .86, 3),
    ], P["armor"], bevel=.025)
    for side in (-1, 1):
        box("SkirtGlow", (side * .9, 0, .3), (.08, 2.6, .06), P["glass"], bevel=.01)
        box("Sponson", (side * 1.0, -.2, .45), (.35, 2.0, .35), P["panel"], bevel=.05)
    box("TeamPlate", (0, -1.15, .87), (.9, .3, .03), P["team"], bevel=.01)
    modeling.sensor_pod(current.name + "_BowOptic", (0, 1.56, .66), .75, (0, 1, 0), current, P["dark"], P["glass"], P["steel"], root)
    turret = pivot("TurretPivot", (0, -.15, .85))
    wedge("Mount", 0, -.15, .85, 1.0, 1.1, .35, P["panel"], turret)
    barrel = pivot("BarrelPivot", (0, 0, 1.25), turret, (math.radians(40), 0, 0))
    for side in (-1, 1):
        box("Launcher", (side * .42, .1, 1.3), (.42, 1.15, .55), P["armor"], barrel, .05)
        for row in range(2):
            for col in range(2):
                cyl("Cell", (side * .42 + (col - .5) * .18, .69, 1.18 + row * .24), .065, .04, P["glass"], barrel, "Y", 14)
    pivot("Muzzle", (0, .8, 1.3), barrel)
    halo = pivot("SensorPivot", (0, -.75, 1.75), turret)
    bpy.ops.mesh.primitive_torus_add(major_segments=32, minor_segments=8, location=(0, -.75, 1.75),
                                     major_radius=.45, minor_radius=.04)
    attach(bpy.context.object, "HaloRing", P["glass"], halo, smooth=True, sharp_angle=50.0)
    rod("HaloMast", (0, -.75, 1.2), (0, -.75, 1.72), .04, P["steel"], turret, vertices=12)


# --- Frontier --------------------------------------------------------------------

def frontier_fighter():
    """Rugged light close-support / bush interceptor (F-5 / Su-25 / A-10 industrial lineage)."""
    begin("frontier", "HornetFighter")
    # Muscular riveted-industrial chined fuselage with nose gun cheeks & heavy aft turbine housing
    chined_fuselage("Fuselage", [
        (-2.38, .70, .34, .42, .36, .28, .24, .00),
        (-1.15, .72, .46, .58, .50, .34, .30, .00),
        (0.45, .72, .48, .60, .52, .36, .30, .00),
        (1.65, .70, .38, .48, .40, .30, .24, .00),
        (2.48, .68, .22, .28, .24, .18, .16, .00),
        (3.12, .67, .06, .08, .06, .06, .06, .00),
    ], P["armor"])
    # Dark steel nosecone + probe
    lathe("Radome", [
        (.20, 2.58), (.14, 2.90), (.05, 3.16), (0.0, 3.24),
    ], (0, 0, .67), (0, 1, 0), P["dark"], segments=16)
    rod("NoseProbe", (0, 3.20, .67), (0, 3.44, .67), .012, P["steel"], vertices=8)
    # Rugged dorsal spine with cooling louvers
    chined_fuselage("Spine", [
        (-2.15, .98, .18, .26, .32, .12, .05, .00),
        (-0.45, 1.04, .24, .32, .38, .16, .06, .00),
        (0.65, 1.04, .24, .32, .36, .14, .05, .00),
    ], P["panel"])
    # Heavy framed bubble cockpit with armored roll-bar bow
    canopy_assembly("Canopy", [
        (0.48, 1.02, .28, .14),
        (1.02, 1.04, .30, .25),
        (1.58, .98, .25, .20),
        (1.98, .88, .15, .09),
    ], arch_indices=(1, 2))
    # Heavy rear jet turbine afterburner nozzle + heat-shield collar
    jet_nozzle("Exhaust", (0, -2.35, .70), .31, .24, .48)
    # Tall rugged swept vertical airfoil tail fin with rudder accent + ventral stability fin
    airfoil_fin("TailFin", 0.0, 0.0, -1.25, -2.36, -1.98, -2.52, .96, 2.12, .11, .048, P["armor"])
    box("FinStripe", (0, -2.20, 1.82), (.085, .44, .14), P["team"], bevel=.006)
    airfoil_fin("VentralFin", 0.0, 0.0, -1.55, -2.28, -1.92, -2.36, .46, .24, .06, .03, P["panel"])
    for side in (-1, 1):
        # Shoulder-mounted D-shaped air intakes with heavy steel intake lips
        caret_intake(f"Intake_{side}", side, .78, -.72, .42, .74, .54, .92, P["panel"])
        # Rugged swept trapezoid airfoil wings with bolted field-repair plates
        modeling.airfoil_wing(
            current.name + f"_Wing_{side}", (side * .50, -.12), (side * 2.48, -.78),
            1.48, .58, .64, .62, .15, .075, current, P["armor"], root, bevel=.012,
        )
        # Bolted field-patch plate & flush wing team band
        wing_stripe(f"FieldPatch_{side}", side * .92, -.28, side * 1.56, -.50, .48, .40, .71, .69, P["panel"])
        wing_stripe(f"WingTeam_{side}", side * 1.72, -.54, side * 2.26, -.72, .38, .30, .69, .67, P["team"])
        # Streamlined wingtip fuel tanks with stabilizer fins
        lathe(f"WingTank_{side}", [
            (0.0, -.74), (.12, -.56), (.14, .46), (.09, .66), (0.0, .76),
        ], (side * 2.52, -.78, .60), (0, 1, 0), P["panel"], segments=16)
        box(f"TankFin_{side}", (side * 2.66, -1.22, .60), (.16, .20, .02), P["dark"], bevel=.004)
        # Underwing ordnance pylon + finned rocket/missile
        pylon_and_missiles(f"Pylon_{side}", side * 1.38, -.48, .58, count=2, length=.88, radius=.052)
        # Swept low-mounted horizontal airfoil stabilizers
        modeling.airfoil_wing(
            current.name + f"_Stab_{side}", (side * .34, -2.06), (side * 1.34, -2.42),
            .62, .28, .68, .66, .08, .042, current, P["armor"], root, bevel=.008,
        )
        # Twin cheek-mounted 25mm autocannons with flash suppressors
        cyl(f"GunHousing_{side}", (side * .38, 1.72, .56), .07, .55, P["panel"], axis="Y", vertices=12)
        cyl(f"Gun_{side}", (side * .38, 2.22, .56), .036, .62, P["steel"], axis="Y", vertices=12)
    gear([(0, 1.72), (-.78, -.55), (.78, -.55)], .44)
    pivot("Muzzle", (0, 3.25, .67))


def frontier_bomber():
    """Heavy rugged twin-boom ordnance hauler (OV-10 Bronco / P-38 / C-119 lineage; preserves RotorLeft & RotorRight)."""
    begin("frontier", "BuzzardBomber")
    # Sculpted central armored crew pod / fuselage nacelle
    chined_fuselage("Pod", [
        (-1.42, .88, .32, .42, .36, .34, .30, .00),
        (-0.25, .92, .52, .66, .58, .44, .42, .00),
        (1.35, .92, .54, .68, .60, .44, .42, .00),
        (2.35, .88, .44, .56, .48, .38, .34, .00),
        (2.96, .84, .26, .34, .28, .24, .22, .00),
        (3.22, .82, .06, .08, .06, .06, .06, .00),
    ], P["armor"])
    # Armored multi-pane greenhouse cockpit nose with structural mullions
    canopy_assembly("Greenhouse", [
        (1.30, 1.24, .44, .18),
        (1.98, 1.24, .46, .24),
        (2.58, 1.12, .38, .20),
        (2.98, .96, .24, .10),
    ], arch_indices=(1, 2))
    # Nose bombardier glazing & roof comms mast
    box("NoseWindow", (0, 3.06, .82), (.42, .22, .28), P["canopy"], bevel=.02)
    rod("RadioMast", (0, .45, 1.36), (0, .28, 1.82), .028, P["steel"], vertices=8)
    # Heavy underbelly external ordnance rack carrying 4 finned iron bombs
    box("BombCradle", (0, .55, .44), (.92, 1.85, .14), P["dark"], bevel=.02)
    for sx in (-.26, .26):
        for by in (.02, .98):
            lathe(f"Bomb_{sx:.1f}_{by:.1f}", [
                (0.0, -.36), (.07, -.30), (.115, -.14), (.12, .16), (.08, .30), (0.0, .38),
            ], (sx, by, .27), (0, 1, 0), P["dark"], segments=14)
            cyl(f"BombBand_{sx:.1f}_{by:.1f}", (sx, by + .18, .27), .124, .06, P["mark"], axis="Y", vertices=14)
            box(f"BombFins_{sx:.1f}_{by:.1f}", (sx, by - .30, .27), (.24, .14, .24), P["steel"], bevel=.004)
    # High-mounted broad cambered airfoil wing with bolted repair plates & twin engine booms
    for side in (-1, 1):
        modeling.airfoil_wing(
            current.name + f"_Wing_{side}", (side * .50, .18), (side * 4.10, .06),
            1.38, .76, 1.28, 1.24, .22, .11, current, P["armor"], root, bevel=.012,
        )
        wing_stripe(f"FieldPatch_{side}", side * 2.15, .12, side * 2.85, .10, .62, .54, 1.38, 1.36, P["panel"])
        wing_stripe(f"WingTeam_{side}", side * 3.12, .10, side * 3.82, .08, .54, .44, 1.36, 1.34, P["team"])
        # Heavy radial/turboprop engine nacelle with cooling cowling & exhaust stacks
        lathe(f"Engine_{side}", [
            (.20, -.86), (.34, -.55), (.38, .28), (.36, .74), (.28, .92), (.18, .98),
        ], (side * 1.56, .26, 1.12), (0, 1, 0), P["panel"], segments=18)
        cyl(f"CowlingRing_{side}", (side * 1.56, .92, 1.12), .31, .14, P["dark"], axis="Y", vertices=18)
        box(f"OilCooler_{side}", (side * 1.56, .52, .76), (.26, .48, .18), P["dark"], bevel=.015)
        # 3-blade heavy pitched propeller in front of nacelle (tractor configuration)
        rotor("RotorLeft" if side < 0 else "RotorRight", (side * 1.56, 1.28, 1.12), .82, 3, axis="Y")
        # Full-bodied tapered lofted twin tail boom (replaces thin cylinder stick!)
        chined_fuselage(f"TailBoom_{side}", [
            (-3.38, 1.20, .12, .16, .13, .18, .14, .00),
            (-1.95, 1.16, .18, .24, .20, .24, .20, .00),
            (-0.62, 1.12, .26, .34, .28, .30, .26, .00),
        ], P["armor"], cx=side * 1.56)
        # Tall swept airfoil vertical tail fin + rudder
        airfoil_fin(
            f"TailFin_{side}", side * 1.56, side * 1.56,
            -2.62, -3.55, -2.95, -3.68, .96, 2.26, .12, .055, P["panel"],
        )
        box(f"FinMark_{side}", (side * 1.56, -3.28, 1.98), (.095, .44, .14), P["team"], bevel=.006)
    # High-mounted airfoil horizontal stabilizer bridging the twin tail fins
    modeling.airfoil_wing(
        current.name + "_HighStabL", (0, -3.28), (-1.58, -3.28),
        .68, .64, 1.88, 1.88, .10, .09, current, P["armor"], root, bevel=.01,
    )
    modeling.airfoil_wing(
        current.name + "_HighStabR", (0, -3.28), (1.58, -3.28),
        .68, .64, 1.88, 1.88, .10, .09, current, P["armor"], root, bevel=.01,
    )
    gear([(0, 2.22), (-1.56, .20), (1.56, .20)], .66)
    pivot("Muzzle", (0, .55, .24))


def frontier_aa():
    begin("frontier", "RipsawTruck")
    wheels(2.0, (-1.15, .05, 1.15), .4)
    box("Chassis", (0, 0, .62), (1.8, 3.4, .28), P["dark"], bevel=.035)
    wedge("Cab", 0, 1.25, .76, 1.75, 1.0, .85, P["armor"], taper=(.9, .75))
    box("Windshield", (0, 1.72, 1.32), (1.4, .05, .38), P["canopy"], bevel=.01)
    box("Flatbed", (0, -.55, .82), (1.85, 2.1, .14), P["panel"], bevel=.025)
    for side in (-1, 1):
        box("Sideboard", (side * .9, -.55, 1.0), (.06, 2.1, .32), P["armor"], bevel=.015)
    box("TeamPlate", (0, 1.25, 1.62), (.9, .45, .03), P["team"], bevel=.01)
    modeling.sensor_pod(current.name + "_CabOptics", (.42, 1.55, 1.66), .70, (0, 1, 0), current, P["dark"], P["glass"], P["steel"], root)
    modeling.era_tile_rack(current.name + "_GrillArmor", (-.58, 1.80, .86), (.58, 1.80, .86), (0, 1, 0), 3, (.32, .06, .22), current, P["panel"], P["dark"], root)
    turret = pivot("TurretPivot", (0, -.65, 1.0))
    cyl("Ring", (0, -.65, 1.05), .55, .12, P["steel"], turret, vertices=24)
    box("GunShield", (0, -.3, 1.4), (.9, .08, .55), P["armor"], turret, .035)
    barrel = pivot("BarrelPivot", (0, -.55, 1.35), turret, (math.radians(30), 0, 0))
    for side in (-1, 1):
        lathe("Autocannon", [
            (.08, -.35), (.08, .15), (.06, .18), (.06, 1.05),
        ], (side * .18, 0, 1.35), (0, 1, 0), P["dark"], barrel, segments=16)
    box("Receiver", (0, -.55, 1.35), (.55, .6, .32), P["steel"], barrel, .035)
    pivot("Muzzle", (0, 1.1, 1.35), barrel)
    pivot("DamageSocket", (.65, 1.35, 1.3))
    for rank in (1, 2):
        group = pivot(f"ScrapRank{rank}", (0, 0, 1.0))
        y = -.6 if rank == 1 else 1.1
        for side in (-1, 1):
            box(f"SalvagePlate{rank}", (side * .97, y, 1.05), (.08, .7, .36),
                P["panel"] if rank == 1 else P["steel"], group, .025)
        if rank == 2:
            box("SalvageBumper", (0, 1.8, .92), (1.3, .1, .3), P["panel"], group, .025)


bastion_fighter()
bastion_bomber()
bastion_helicopter()
bastion_flak()
helix_fighter()
helix_bomber()
helix_helicopter()
helix_aa()
frontier_fighter()
frontier_bomber()
frontier_aa()

manifest = []
for faction, name, collection, asset_root in assets:
    if BUILD_FACTION is not None and faction != BUILD_FACTION:
        continue
    if "--damage-only" in sys.argv and name not in {"RipsawTruck", "HaloSkimmer", "AntiAirVehicle"}:
        continue
    if name in {"HaloSkimmer", "AntiAirVehicle"}:
        socket = bpy.data.objects.new(name + "_DamageSocket", None)
        collection.objects.link(socket)
        socket.parent = asset_root
        socket.location = (.45, -.6, 1.0)
    bpy.context.view_layer.update()
    for part in collection.objects:
        trim_sheet.prepare(part)
    deps = bpy.context.evaluated_depsgraph_get()
    copies = {}
    for obj in collection.objects:
        clone = bpy.data.objects.new(
            "export_" + obj.name,
            bpy.data.meshes.new_from_object(obj.evaluated_get(deps), depsgraph=deps) if obj.type == "MESH" else None,
        )
        scene.collection.objects.link(clone)
        clone.matrix_world = obj.matrix_world.copy()
        copies[obj] = clone
    for obj, clone in copies.items():
        if obj.parent in copies:
            matrix = clone.matrix_world.copy()
            clone.parent = copies[obj.parent]
            clone.matrix_world = matrix
    groups = {}
    for obj in copies.values():
        if obj.type == "MESH":
            groups.setdefault(obj.parent, []).append(obj)
    for parent, objects in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        joined = bpy.context.object
        modifier = joined.modifiers.new("Triangulate", "TRIANGULATE")
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        bm = bmesh.new()
        bm.from_mesh(joined.data)
        degen = [f for f in bm.faces if f.calc_area() < 1e-10]
        if degen:
            bmesh.ops.delete(bm, geom=degen, context="FACES_ONLY")
            bm.to_mesh(joined.data)
        bm.free()
    live = [obj for obj in scene.collection.objects if obj.name.startswith("export_")]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in live:
        obj.select_set(True)
    triangles = sum(len(obj.data.polygons) for obj in live if obj.type == "MESH")
    weathering.bake(live)
    models, _icons = OUTPUT[faction]
    bpy.ops.export_scene.gltf(
        filepath=str(models / (name + ".glb")), export_format="GLB", use_selection=True,
        export_animations=False, export_yup=True, export_cameras=False, export_lights=False,
        export_vertex_color="ACTIVE",
    )
    for obj in live:
        bpy.data.objects.remove(obj, do_unlink=True)
    manifest.append({"faction": faction, "name": name, "triangles": triangles})
    collection.hide_render = True


def render_catalogue():
    world = bpy.data.worlds.new("Studio")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (.22, .27, .34, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = .45
    for light_name, loc, power, color in (("Key", (4, 6, 11), 1800, (1, .88, .72)),
                                          ("Fill", (-6, 1, 6), 1500, (.7, .83, 1)),
                                          ("Rim", (3, -6, 8), 2100, (1, .92, .78))):
        data = bpy.data.lights.new(light_name, "AREA")
        data.energy = power
        data.shape = "DISK"
        data.size = 7
        data.color = color
        obj = bpy.data.objects.new(light_name, data)
        scene.collection.objects.link(obj)
        obj.location = loc
        obj.rotation_euler = (Vector((0, 0, 1)) - obj.location).to_track_quat("-Z", "Y").to_euler()
    camera_data = bpy.data.cameras.new("Camera")
    camera = bpy.data.objects.new("Camera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera_data.type = "ORTHO"
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 16
    scene.cycles.use_denoising = True
    scene.render.resolution_percentage = 100
    scene.render.resolution_x = 256
    scene.render.resolution_y = 256
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "AgX"
    for faction, name, collection, asset_root in assets:
        collection.hide_render = False
        points = [obj.matrix_world @ Vector(p) for obj in collection.objects if obj.type == "MESH" for p in obj.bound_box]
        lo = Vector([min(p[i] for p in points) for i in range(3)])
        hi = Vector([max(p[i] for p in points) for i in range(3)])
        center = (lo + hi) / 2
        camera.location = center + Vector((9, 12, 10))
        camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
        camera_data.ortho_scale = max(hi - lo) * 1.45
        _models, icons = OUTPUT[faction]
        scene.render.filepath = str(icons / (name + ".png"))
        bpy.ops.render.render(write_still=True)
        collection.hide_render = True

    for index, (faction, name, collection, asset_root) in enumerate(assets):
        collection.hide_render = False
        asset_root.location = Vector(((index % 4 - 1.5) * 10, (index // 4 - 1) * 10, 0))
    camera.location = (30, 38, 40)
    camera.rotation_euler = (Vector((0, 0, 0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.ortho_scale = 46
    scene.render.film_transparent = False
    scene.render.resolution_x = 1800
    scene.render.resolution_y = 1400
    scene.cycles.samples = 32
    SOURCE.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(SOURCE / "aircraft-catalogue.png")
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "aircraft.blend"))
    bpy.ops.render.render(write_still=True)
    (SOURCE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("Air-combat assets complete:", len(manifest))


if BUILD_FACTION is None:
    render_catalogue()
else:
    print(f"Air-combat models complete: {BUILD_FACTION}, {len(manifest)} assets")

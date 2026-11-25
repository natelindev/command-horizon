"""Shared hard-surface procedural modeling utilities for Blender 5.x.

Provides smooth-by-angle shading with sharp-edge preservation, multi-segment
chamfers/bevels, contoured lofts, revolved lathe profiles, swept pipes/cables,
ducted fans, detailed off-road/armored wheels, and recessed panel details.
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector


def _ensure_collection(obj, collection):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)


def apply_smoothing(obj, angle_deg=36.0):
    """Enable smooth shading across faces while marking edges above angle_deg sharp."""
    if obj.type != "MESH" or not obj.data.polygons:
        return obj
    mesh = obj.data
    for poly in mesh.polygons:
        poly.use_smooth = True
    bm = bmesh.new()
    bm.from_mesh(mesh)
    threshold = math.radians(angle_deg)
    for edge in bm.edges:
        if len(edge.link_faces) == 2:
            edge.smooth = edge.calc_face_angle(0.0) <= threshold
        else:
            edge.smooth = False
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    return obj


def finalize_part(
    obj,
    name,
    collection,
    material,
    parent,
    bevel=0.0,
    bevel_segments=2,
    smooth=True,
    sharp_angle=36.0,
):
    """Assign collection, material, multi-segment bevel, smooth normals, and parent."""
    obj.name = name
    _ensure_collection(obj, collection)
    if material and material.name not in [m.name for m in obj.data.materials if m]:
        obj.data.materials.append(material)
    if smooth:
        apply_smoothing(obj, sharp_angle)
    if bevel > 0.0:
        mod = obj.modifiers.new("EdgeBevel", "BEVEL")
        mod.width = bevel
        mod.segments = bevel_segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(30.0)
        mod.harden_normals = False
    if smooth or bevel > 0.0:
        wn = obj.modifiers.new("WeightedNormals", "WEIGHTED_NORMAL")
        wn.keep_sharp = True
        wn.weight = 60
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = world
    return obj


def new_mesh_object(name, bm, collection, material, parent, bevel=0.0, bevel_segments=2, smooth=True, sharp_angle=36.0):
    """Convert a BMesh into an attached Blender object with clean outward normals."""
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    return finalize_part(obj, name, collection, material, parent, bevel, bevel_segments, smooth, sharp_angle)


def rounded_rect_ring(width, length, cut=0.14, cx=0.0, cy=0.0, z=0.0, corner_steps=2):
    """Return a 3D ring for a chamfered/rounded rectangular footprint at height z."""
    hw, hl = width * 0.5, length * 0.5
    c = min(cut, hw * 0.45, hl * 0.45)
    if c <= 1e-4:
        pts = [(-hw, -hl), (hw, -hl), (hw, hl), (-hw, hl)]
    elif corner_steps <= 1:
        pts = [
            (-hw + c, -hl), (hw - c, -hl),
            (hw, -hl + c), (hw, hl - c),
            (hw - c, hl), (-hw + c, hl),
            (-hw, hl - c), (-hw, -hl + c),
        ]
    else:
        pts = []
        corners = [
            (hw - c, -hl + c, -math.pi * 0.5, 0.0),
            (hw - c, hl - c, 0.0, math.pi * 0.5),
            (-hw + c, hl - c, math.pi * 0.5, math.pi),
            (-hw + c, -hl + c, math.pi, math.pi * 1.5),
        ]
        for ox, oy, a0, a1 in corners:
            for k in range(corner_steps + 1):
                a = a0 + (a1 - a0) * (k / corner_steps)
                pts.append((ox + math.cos(a) * c, oy + math.sin(a) * c))
    return [(cx + x, cy + y, z) for x, y in pts]


def ellipse_ring(rx, ry, cx=0.0, cy=0.0, z=0.0, segments=20, flatten_bottom=0.0):
    """Return a 3D ring on XY plane, optionally flattened below."""
    pts = []
    for i in range(segments):
        a = i * math.tau / segments
        x = math.cos(a) * rx
        y = math.sin(a) * ry
        if flatten_bottom > 0.0 and y < -ry * (1.0 - flatten_bottom):
            y = -ry * (1.0 - flatten_bottom)
        pts.append((cx + x, cy + y, z))
    return pts


def loft_rings(name, rings, collection, material, parent, closed_caps=True, bevel=0.0, bevel_segments=2, smooth=True, sharp_angle=38.0):
    """Build a multi-station lofted hull/body from a list of equal-length 3D vertex rings."""
    n = len(rings[0])
    bm = bmesh.new()
    grid = [[bm.verts.new(p) for p in ring] for ring in rings]
    for r in range(len(grid) - 1):
        for i in range(n):
            j = (i + 1) % n
            v0, v1, v2, v3 = grid[r][i], grid[r][j], grid[r + 1][j], grid[r + 1][i]
            if (v0.co - v1.co).length > 1e-6 or (v3.co - v2.co).length > 1e-6:
                bm.faces.new((v0, v1, v2, v3))
    if closed_caps:
        for end_ring, rev in ((grid[0], True), (grid[-1], False)):
            if len({(round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4)) for v in end_ring}) >= 3:
                bm.faces.new(list(reversed(end_ring)) if rev else end_ring)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    return new_mesh_object(name, bm, collection, material, parent, bevel, bevel_segments, smooth, sharp_angle)


def lathe_profile(name, profile_rz, axis_origin, axis_dir, segments, collection, material, parent, bevel=0.0, smooth=True, sharp_angle=38.0):
    """Revolve a list of (radius, axial_offset) pairs around axis_dir from axis_origin."""
    origin = Vector(axis_origin)
    axis = Vector(axis_dir).normalized()
    helper = Vector((1, 0, 0)) if abs(axis.z) > 0.9 else Vector((0, 0, 1))
    u = helper.cross(axis).normalized()
    v = axis.cross(u).normalized()

    bm = bmesh.new()
    rings = []
    cap_start = None
    cap_end = None
    for idx, (r, h) in enumerate(profile_rz):
        center = origin + axis * h
        if r <= 1e-5:
            vert = bm.verts.new(center)
            if idx == 0:
                cap_start = vert
            elif idx == len(profile_rz) - 1:
                cap_end = vert
            continue
        ring = []
        for s in range(segments):
            a = s * math.tau / segments
            pt = center + (u * math.cos(a) + v * math.sin(a)) * r
            ring.append(bm.verts.new(pt))
        rings.append(ring)

    for k in range(len(rings) - 1):
        for s in range(segments):
            ns = (s + 1) % segments
            bm.faces.new((rings[k][s], rings[k][ns], rings[k + 1][ns], rings[k + 1][s]))

    if rings:
        if cap_start is not None:
            for s in range(segments):
                ns = (s + 1) % segments
                bm.faces.new((cap_start, rings[0][ns], rings[0][s]))
        elif profile_rz[0][0] > 1e-5:
            bm.faces.new(list(reversed(rings[0])))

        if cap_end is not None:
            for s in range(segments):
                ns = (s + 1) % segments
                bm.faces.new((rings[-1][s], rings[-1][ns], cap_end))
        elif profile_rz[-1][0] > 1e-5:
            bm.faces.new(rings[-1])

    return new_mesh_object(name, bm, collection, material, parent, bevel, 2, smooth, sharp_angle)


def sweep_tube(name, points, radius, segments, collection, material, parent, cap_ends=True, smooth=True):
    """Sweep a circular cross-section along a 3D polyline with mitered frames."""
    pts = [Vector(p) for p in points]
    if len(pts) < 2:
        return None
    bm = bmesh.new()
    rings = []
    prev_u = None
    for idx, p in enumerate(pts):
        if idx == 0:
            tangent = (pts[1] - pts[0]).normalized()
        elif idx == len(pts) - 1:
            tangent = (pts[-1] - pts[-2]).normalized()
        else:
            t1 = (pts[idx] - pts[idx - 1]).normalized()
            t2 = (pts[idx + 1] - pts[idx]).normalized()
            tangent = (t1 + t2)
            tangent = tangent.normalized() if tangent.length > 1e-5 else t2
        if prev_u is None:
            helper = Vector((1, 0, 0)) if abs(tangent.z) > 0.9 else Vector((0, 0, 1))
            u = helper.cross(tangent).normalized()
        else:
            u = (prev_u - tangent * prev_u.dot(tangent))
            if u.length < 1e-5:
                helper = Vector((1, 0, 0)) if abs(tangent.z) > 0.9 else Vector((0, 0, 1))
                u = helper.cross(tangent).normalized()
            else:
                u.normalize()
        prev_u = u
        v = tangent.cross(u).normalized()
        r = radius[idx] if isinstance(radius, (list, tuple)) else radius
        ring = [
            bm.verts.new(p + (u * math.cos(a) + v * math.sin(a)) * r)
            for a in (s * math.tau / segments for s in range(segments))
        ]
        rings.append(ring)

    for k in range(len(rings) - 1):
        for s in range(segments):
            ns = (s + 1) % segments
            bm.faces.new((rings[k][s], rings[k][ns], rings[k + 1][ns], rings[k + 1][s]))
    if cap_ends:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    return new_mesh_object(name, bm, collection, material, parent, 0.0, 1, smooth, 40.0)


def airfoil_wing(name, root_xy, tip_xy, root_chord, tip_chord, root_z, tip_z, thickness_root, thickness_tip, collection, material, parent, bevel=0.015):
    """Build a multi-section cambered/tapered aircraft wing between root and tip."""
    # Stations along chord: leading edge -> upper mid -> upper aft -> trailing edge -> lower aft -> lower mid
    profile = [
        (0.50, 0.00),
        (0.32, 0.48),
        (-0.08, 0.52),
        (-0.50, 0.04),
        (-0.50, -0.04),
        (-0.08, -0.34),
        (0.32, -0.34),
    ]
    rings = []
    for cx, cy, z, chord, thick in (
        (root_xy[0], root_xy[1], root_z, root_chord, thickness_root),
        (tip_xy[0], tip_xy[1], tip_z, tip_chord, thickness_tip),
    ):
        ring = [(cx, cy + fy * chord, z + fz * thick) for fy, fz in profile]
        rings.append(ring)
    return loft_rings(name, rings, collection, material, parent, closed_caps=True, bevel=bevel, bevel_segments=2, smooth=True, sharp_angle=38.0)


def detailed_wheel(name, center, radius, width, side, collection, rubber_mat, rim_mat, hub_mat, parent, segments=20, lug_count=14):
    """Create a chamfered tire with beveled dish rim, hub cap, and tread lugs."""
    cx, cy, cz = center
    hw = width * 0.5
    # Revolved tire profile with rounded shoulder and concave rim seat
    tire_prof = [
        (radius * 0.62, -hw * 0.85),
        (radius * 0.86, -hw),
        (radius * 0.99, -hw * 0.82),
        (radius, -hw * 0.55),
        (radius, hw * 0.55),
        (radius * 0.99, hw * 0.82),
        (radius * 0.86, hw),
        (radius * 0.62, hw * 0.85),
    ]
    lathe_profile(name + "_Tire", tire_prof, (cx, cy, cz), (1, 0, 0), segments, collection, rubber_mat, parent, smooth=True, sharp_angle=42.0)

    # Dish rim facing outward
    s = 1.0 if side >= 0 else -1.0
    rim_prof = [
        (0.0, s * hw * 0.35),
        (radius * 0.42, s * hw * 0.40),
        (radius * 0.55, s * hw * 0.88),
        (radius * 0.65, s * hw * 0.92),
        (radius * 0.65, -s * hw * 0.75),
        (0.0, -s * hw * 0.75),
    ]
    lathe_profile(name + "_Rim", rim_prof, (cx, cy, cz), (1, 0, 0), segments, collection, rim_mat, parent, smooth=True, sharp_angle=35.0)

    hub_prof = [
        (0.0, s * hw * 0.42),
        (radius * 0.25, s * hw * 0.42),
        (radius * 0.27, s * hw * 0.98),
        (radius * 0.16, s * hw * 1.12),
        (0.0, s * hw * 1.12),
    ]
    lathe_profile(name + "_Hub", hub_prof, (cx, cy, cz), (1, 0, 0), 12, collection, hub_mat, parent, smooth=True, sharp_angle=35.0)

    # Individual tread blocks merged into one mesh for crisp silhouette without extra objects
    bm = bmesh.new()
    for i in range(lug_count):
        a = i * math.tau / lug_count
        ny, nz = math.sin(a), math.cos(a)
        rot = Matrix.Rotation(-a, 4, "X")
        mat_xform = Matrix.Translation((cx, cy + ny * (radius + 0.01), cz + nz * (radius + 0.01))) @ rot
        res = bmesh.ops.create_cube(bm, size=1.0)
        for v in res["verts"]:
            v.co = mat_xform @ Vector((v.co.x * (width * 0.94), v.co.y * (radius * 0.24), v.co.z * 0.045))
    new_mesh_object(name + "_Treads", bm, collection, rubber_mat, parent, bevel=0.0, smooth=False)


def ducted_shroud(name, center, radius, height, wall, collection, armor_mat, dark_mat, steel_mat, parent, segments=28):
    """Build a hollow beveled ducted-fan shroud with intake lip and stator struts."""
    cx, cy, cz = center
    r_out = radius
    r_in = radius - wall
    hh = height * 0.5
    prof = [
        (r_in, -hh),
        (r_out - wall * 0.25, -hh),
        (r_out, -hh * 0.72),
        (r_out, hh * 0.72),
        (r_out - wall * 0.20, hh),
        (r_in + wall * 0.12, hh),
        (r_in, hh * 0.72),
        (r_in, -hh * 0.72),
    ]
    lathe_profile(name + "_Shroud", prof, (cx, cy, cz), (0, 0, 1), segments, collection, armor_mat, parent, smooth=True, sharp_angle=38.0)

    # Inner dark throat lip and 3 stator struts
    lip_prof = [
        (r_in - 0.015, hh * 0.4),
        (r_in + 0.02, hh * 0.4),
        (r_in + 0.02, hh * 0.78),
        (r_in - 0.015, hh * 0.78),
    ]
    lathe_profile(name + "_Lip", lip_prof, (cx, cy, cz), (0, 0, 1), segments, collection, steel_mat, parent, smooth=True, sharp_angle=38.0)

    for k in range(3):
        a = k * math.tau / 3.0 + math.pi / 6.0
        p0 = (cx + math.cos(a) * (r_in * 0.15), cy + math.sin(a) * (r_in * 0.15), cz - hh * 0.35)
        p1 = (cx + math.cos(a) * r_in, cy + math.sin(a) * r_in, cz - hh * 0.35)
        sweep_tube(f"{name}_Strut{k}", [p0, p1], wall * 0.26, 8, collection, dark_mat, parent, cap_ends=True)


def pitched_rotor(name, center, radius, blades, collection, hub_mat, blade_mat, parent, axis="Z"):
    """Build a pitched multi-blade rotor with tapered root and spinner cone inside parent pivot."""
    cx, cy, cz = center
    rot_axis = Matrix.Identity(4)
    if axis == "X":
        rot_axis = Matrix.Rotation(math.pi * 0.5, 4, "Y")
    elif axis == "Y":
        rot_axis = Matrix.Rotation(math.pi * 0.5, 4, "X")

    # Spinner hub
    hub_r = max(0.065, radius * 0.11)
    hub_prof = [
        (0.0, -hub_r * 0.6),
        (hub_r, -hub_r * 0.5),
        (hub_r * 1.05, 0.0),
        (hub_r * 0.75, hub_r * 0.55),
        (0.0, hub_r * 0.85),
    ]
    axis_vec = (1, 0, 0) if axis == "X" else (0, 1, 0) if axis == "Y" else (0, 0, 1)
    lathe_profile(name + "_Spinner", hub_prof, center, axis_vec, 16, collection, hub_mat, parent, smooth=True, sharp_angle=40.0)

    # Tapered pitched blades in one combined mesh
    bm = bmesh.new()
    blade_w = max(0.055, radius * 0.12)
    pitch = Matrix.Rotation(math.radians(14), 4, "X")
    for b in range(blades):
        ang = b * math.tau / blades
        spin = Matrix.Rotation(ang, 4, "Z")
        xform = Matrix.Translation(center) @ rot_axis @ spin @ pitch
        stations = [
            (hub_r * 0.7, blade_w * 0.36, 0.022),
            (radius * 0.32, blade_w * 0.55, 0.018),
            (radius * 0.92, blade_w * 0.44, 0.012),
            (radius, blade_w * 0.24, 0.008),
        ]
        rings = []
        for rx, wy, tz in stations:
            pts = [
                Vector((rx, -wy, -tz)),
                Vector((rx, wy, -tz)),
                Vector((rx, wy * 0.85, tz)),
                Vector((rx, -wy * 0.85, tz)),
            ]
            rings.append([bm.verts.new(xform @ p) for p in pts])
        for k in range(len(rings) - 1):
            for i in range(4):
                j = (i + 1) % 4
                bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    new_mesh_object(name + "_Blades", bm, collection, blade_mat, parent, bevel=0.0, smooth=True, sharp_angle=42.0)


def recessed_viewport(name, center, width, height, depth, facing, collection, housing_mat, glass_mat, parent):
    """Build an armored sensor/viewport hood with a genuinely recessed optic lens."""
    cx, cy, cz = center
    fx, fy, fz = Vector(facing).normalized()
    forward = Vector((fx, fy, fz))
    up = Vector((0, 0, 1)) if abs(forward.z) < 0.9 else Vector((0, 1, 0))
    right = forward.cross(up).normalized()
    up = right.cross(forward).normalized()

    hw, hh = width * 0.5, height * 0.5
    frame_t = max(0.03, min(width, height) * 0.18)
    outer = [(-hw - frame_t, -hh - frame_t), (hw + frame_t, -hh - frame_t),
             (hw + frame_t, hh + frame_t), (-hw - frame_t, hh + frame_t)]
    inner = [(-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)]

    bm = bmesh.new()
    # Back block + beveled front frame around recessed pocket
    back = [bm.verts.new(Vector(center) - forward * (depth * 0.6) + right * u + up * v) for u, v in outer]
    front_out = [bm.verts.new(Vector(center) + forward * (depth * 0.4) + right * (u * 0.94) + up * (v * 0.94)) for u, v in outer]
    front_in = [bm.verts.new(Vector(center) + forward * (depth * 0.4) + right * u + up * v) for u, v in inner]
    pocket = [bm.verts.new(Vector(center) + forward * (depth * 0.12) + right * u + up * v) for u, v in inner]

    bm.faces.new(list(reversed(back)))
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((back[i], back[j], front_out[j], front_out[i]))
        bm.faces.new((front_out[i], front_out[j], front_in[j], front_in[i]))
        bm.faces.new((front_in[i], front_in[j], pocket[j], pocket[i]))
    bm.faces.new(pocket)
    new_mesh_object(name + "_Housing", bm, collection, housing_mat, parent, bevel=0.012, bevel_segments=1, smooth=True, sharp_angle=35.0)

    # Recessed lens sitting inside the pocket
    bm_g = bmesh.new()
    g0 = [bm_g.verts.new(Vector(center) + forward * (depth * 0.13) + right * (u * 0.96) + up * (v * 0.96)) for u, v in inner]
    g1 = [bm_g.verts.new(Vector(center) + forward * (depth * 0.25) + right * (u * 0.90) + up * (v * 0.90)) for u, v in inner]
    for i in range(4):
        j = (i + 1) % 4
        bm_g.faces.new((g0[i], g0[j], g1[j], g1[i]))
    bm_g.faces.new(g1)
    new_mesh_object(name + "_Optic", bm_g, collection, glass_mat, parent, bevel=0.0, smooth=True, sharp_angle=35.0)


def louver_grille(name, center, width, length, count, collection, frame_mat, slat_mat, parent):
    """Build a framed engine/cooling grille with angled louver slats inside a recess."""
    cx, cy, cz = center
    hw, hl = width * 0.5, length * 0.5
    rim = 0.045
    bm = bmesh.new()
    outer = [(-hw, -hl), (hw, -hl), (hw, hl), (-hw, hl)]
    inner = [(-hw + rim, -hl + rim), (hw - rim, -hl + rim), (hw - rim, hl - rim), (-hw + rim, hl - rim)]
    bot = [bm.verts.new((cx + x, cy + y, cz - 0.02)) for x, y in outer]
    top_out = [bm.verts.new((cx + x, cy + y, cz + 0.035)) for x, y in outer]
    top_in = [bm.verts.new((cx + x, cy + y, cz + 0.035)) for x, y in inner]
    well = [bm.verts.new((cx + x, cy + y, cz - 0.005)) for x, y in inner]
    bm.faces.new(list(reversed(bot)))
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((bot[i], bot[j], top_out[j], top_out[i]))
        bm.faces.new((top_out[i], top_out[j], top_in[j], top_in[i]))
        bm.faces.new((top_in[i], top_in[j], well[j], well[i]))
    bm.faces.new(well)
    new_mesh_object(name + "_Frame", bm, collection, frame_mat, parent, bevel=0.0, smooth=False)

    bm_s = bmesh.new()
    slat_w = width - rim * 2.2
    slat_l = (length - rim * 2.2) / max(1, count * 1.45)
    for k in range(count):
        sy = cy - (length * 0.5 - rim * 1.6) + (k + 0.5) * ((length - rim * 3.2) / count)
        rot = Matrix.Rotation(math.radians(22), 4, "X")
        xf = Matrix.Translation((cx, sy, cz + 0.018)) @ rot
        res = bmesh.ops.create_cube(bm_s, size=1.0)
        for v in res["verts"]:
            v.co = xf @ Vector((v.co.x * slat_w, v.co.y * slat_l, v.co.z * 0.024))
    new_mesh_object(name + "_Slats", bm_s, collection, slat_mat, parent, bevel=0.0, smooth=False)


def era_tile_rack(name, start, end, outward, count, tile_size, collection, tile_mat, rail_mat, parent):
    """Build a bracketed row of beveled composite/reactive armor tiles."""
    p0, p1 = Vector(start), Vector(end)
    span = p1 - p0
    dir_v = span.normalized()
    n_v = Vector(outward).normalized()
    up_v = n_v.cross(dir_v).normalized()
    basis = Matrix((dir_v, n_v, up_v)).transposed().to_4x4()

    tw, td, th = tile_size
    bm_rail = bmesh.new()
    res = bmesh.ops.create_cube(bm_rail, size=1.0)
    rail_xf = Matrix.Translation((p0 + p1) * 0.5 - n_v * (td * 0.35)) @ basis
    for v in res["verts"]:
        v.co = rail_xf @ Vector((v.co.x * (span.length + tw * 0.4), v.co.y * (td * 0.35), v.co.z * (th * 0.35)))
    new_mesh_object(name + "_Rail", bm_rail, collection, rail_mat, parent, bevel=0.0, smooth=False)

    bm_tiles = bmesh.new()
    for i in range(count):
        t = (i + 0.5) / count
        pos = p0.lerp(p1, t)
        xf = Matrix.Translation(pos) @ basis
        r = bmesh.ops.create_cube(bm_tiles, size=1.0)
        for v in r["verts"]:
            v.co = xf @ Vector((v.co.x * tw, v.co.y * td, v.co.z * th))
    new_mesh_object(name + "_Tiles", bm_tiles, collection, tile_mat, parent, bevel=0.012, bevel_segments=1, smooth=True, sharp_angle=35.0)


def cupola_hatch(name, center, radius, height, collection, body_mat, dark_mat, glass_mat, parent):
    """Build a beveled commander/access cupola with lid hinge and periscope blocks."""
    cx, cy, cz = center
    ring_prof = [
        (radius * 0.98, 0.0),
        (radius, height * 0.55),
        (radius * 0.92, height * 0.72),
        (radius * 0.78, height * 0.72),
        (radius * 0.76, height * 0.92),
        (0.0, height),
    ]
    lathe_profile(name + "_Cupola", ring_prof, (cx, cy, cz), (0, 0, 1), 12, collection, body_mat, parent, smooth=True, sharp_angle=36.0)
    bm_p = bmesh.new()
    for i in range(4):
        a = i * math.tau / 4.0 + math.pi * 0.25
        xf = Matrix.Translation((cx + math.cos(a) * radius * 0.78, cy + math.sin(a) * radius * 0.78, cz + height * 0.58)) @ Matrix.Rotation(a, 4, "Z")
        r = bmesh.ops.create_cube(bm_p, size=1.0)
        for v in r["verts"]:
            v.co = xf @ Vector((v.co.x * (radius * 0.26), v.co.y * (radius * 0.38), v.co.z * (height * 0.32)))
    new_mesh_object(name + "_Periscopes", bm_p, collection, glass_mat, parent, bevel=0.0, smooth=False)


def smoke_dischargers(name, origin, side, collection, tube_mat, bracket_mat, parent):
    """Build a triple-tube angled smoke discharger pod."""
    ox, oy, oz = origin
    bm_b = bmesh.new()
    res = bmesh.ops.create_cube(bm_b, size=1.0)
    for v in res["verts"]:
        v.co = Vector((ox + v.co.x * 0.14, oy + v.co.y * 0.30, oz + v.co.z * 0.14))
    new_mesh_object(name + "_Bracket", bm_b, collection, bracket_mat, parent, bevel=0.0, smooth=False)

    bm_t = bmesh.new()
    for k, dy in enumerate((-0.09, 0.0, 0.09)):
        pitch = Matrix.Rotation(math.radians(24), 4, "X")
        yaw = Matrix.Rotation(side * math.radians(-18 - k * 8), 4, "Z")
        xf = Matrix.Translation((ox + side * 0.05, oy + dy, oz + 0.09)) @ yaw @ pitch
        r = bmesh.ops.create_cone(bm_t, cap_ends=True, cap_tris=False, segments=8, radius1=0.038, radius2=0.042, depth=0.26)
        for v in r["verts"]:
            v.co = xf @ Vector((v.co.x, v.co.z, v.co.y))
    new_mesh_object(name + "_Tubes", bm_t, collection, tube_mat, parent, bevel=0.0, smooth=True, sharp_angle=45.0)


def sensor_pod(name, center, scale, facing, collection, housing_mat, lens_mat, steel_mat, parent):
    """Build an armored dual-optics FLIR / laser rangefinder head."""
    fwd = Vector(facing).normalized()
    up = Vector((0, 0, 1)) if abs(fwd.z) < 0.9 else Vector((0, 1, 0))
    right = fwd.cross(up).normalized()
    up = right.cross(fwd).normalized()
    basis = Matrix((right, fwd, up)).transposed().to_4x4()
    c = Vector(center)

    bm = bmesh.new()
    res = bmesh.ops.create_cube(bm, size=1.0)
    xf = Matrix.Translation(c) @ basis
    for v in res["verts"]:
        v.co = xf @ Vector((v.co.x * 0.34 * scale, v.co.y * 0.28 * scale, v.co.z * 0.22 * scale))
    new_mesh_object(name + "_Pod", bm, collection, housing_mat, parent, bevel=0.015 * scale, bevel_segments=1, smooth=True, sharp_angle=35.0)

    bm_l = bmesh.new()
    for sx in (-0.085, 0.085):
        r = bmesh.ops.create_cone(bm_l, cap_ends=True, cap_tris=False, segments=10, radius1=0.055 * scale, radius2=0.055 * scale, depth=0.05 * scale)
        lxf = Matrix.Translation(c + fwd * (0.145 * scale) + right * (sx * scale)) @ basis
        for v in r["verts"]:
            v.co = lxf @ Vector((v.co.x, v.co.z, v.co.y))
    new_mesh_object(name + "_Optics", bm_l, collection, lens_mat, parent, bevel=0.0, smooth=True, sharp_angle=40.0)


def hvac_fan_unit(name, center, width, length, height, collection, casing_mat, dark_mat, steel_mat, parent):
    """Build a recessed industrial rooftop cooling fan housing with rotor blades."""
    cx, cy, cz = center
    bm = bmesh.new()
    res = bmesh.ops.create_cube(bm, size=1.0)
    for v in res["verts"]:
        v.co = Vector((cx + v.co.x * width, cy + v.co.y * length, cz + v.co.z * height))
    new_mesh_object(name + "_Box", bm, collection, casing_mat, parent, bevel=0.025, bevel_segments=1, smooth=True, sharp_angle=35.0)

    r_fan = min(width, length) * 0.36
    prof = [
        (r_fan * 0.85, 0.0),
        (r_fan * 1.06, 0.0),
        (r_fan * 1.06, height * 0.14),
        (r_fan * 0.88, height * 0.16),
        (r_fan * 0.85, height * 0.02),
    ]
    lathe_profile(name + "_Shroud", prof, (cx, cy, cz + height * 0.5), (0, 0, 1), 16, collection, dark_mat, parent, smooth=True, sharp_angle=35.0)
    pitched_rotor(name + "_Fan", (cx, cy, cz + height * 0.55), r_fan * 0.78, 4, collection, steel_mat, steel_mat, parent, axis="Z")


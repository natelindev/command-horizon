"""Bake per-corner ambient occlusion and an edge-wear mask into vertex colors.

Call `bake(objects)` on the joined export meshes of one asset, before glTF
export with `export_vertex_color="ACTIVE"`. RGB holds occlusion (1 is open sky,
darker in crevices, under overhangs and where parts meet the ground) and alpha
holds 1 - wear, where wear marks narrow convex bevel faces. Both default to 1
on meshes without vertex colors, which therefore stay unweathered. Godot
multiplies the occlusion into imported and team-color albedo; the armor shaders
also use the wear mask.

Results are deterministic: ray directions are fixed and the scene is static.
"""

import math
import random

import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ATTRIBUTE = "Weathering"
RAYS = 40
# Faces narrower than this (metres) on a convex edge are treated as worn bevels.
BEVEL_WIDTH = 0.09
CONVEX_ANGLE = 0.2
# Darkest stored occlusion; fully blocked corners stay readable as dark paint.
FLOOR = 0.35
CONTRAST = 1.8
# Corner samples move this share toward the face center, capped in metres.
INSET = 0.3
INSET_LIMIT = 0.2
# Faces wider than SPAN_PANEL metres shade evenly; below SPAN_DETAIL per corner.
SPAN_DETAIL = 0.25
SPAN_PANEL = 0.8


def _hemisphere(count, seed=7):
    """Stratified cosine-weighted directions around +Z."""
    rng = random.Random(seed)
    directions = []
    for index in range(count):
        u = (index + rng.random()) / count
        phi = 2.0 * math.pi * rng.random()
        radius = math.sqrt(u)
        directions.append(
            Vector((radius * math.cos(phi), radius * math.sin(phi), math.sqrt(1.0 - u)))
        )
    return directions


def _frame(normal):
    helper = Vector((1, 0, 0)) if abs(normal.z) > 0.9 else Vector((0, 0, 1))
    tangent = helper.cross(normal).normalized()
    return tangent, normal.cross(tangent)


def _openness(tree, point, normal, bias, reach, directions):
    """Share of the hemisphere around `normal` that reaches open sky."""
    origin = point + normal * bias
    tangent, bitangent = _frame(normal)
    blocked = 0.0
    for d in directions:
        hit = tree.ray_cast(origin, tangent * d.x + bitangent * d.y + normal * d.z, reach)
        if hit[0] is not None:
            blocked += 1.0 - hit[3] / reach
    return 1.0 - blocked / len(directions)


def _worn_faces(obj):
    """Indices of narrow, elongated faces that sit on a convex edge."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(obj.matrix_world)
    bm.faces.ensure_lookup_table()
    worn = set()
    for face in bm.faces:
        edges = [edge.calc_length() for edge in face.edges]
        longest = max(edges)
        if longest <= 0.0:
            continue
        width = 2.0 * face.calc_area() / longest if len(face.verts) == 3 else min(edges)
        if width >= BEVEL_WIDTH or longest < width * 2.0:
            continue
        for edge in face.edges:
            if len(edge.link_faces) == 2 and edge.calc_face_angle_signed(0.0) > CONVEX_ANGLE:
                worn.add(face.index)
                break
    bm.free()
    return worn


def bake(objects):
    meshes = [obj for obj in objects if obj.type == "MESH" and obj.data.polygons]
    if not meshes:
        return
    points = []
    polygons = []
    for obj in meshes:
        offset = len(points)
        points.extend(obj.matrix_world @ vertex.co for vertex in obj.data.vertices)
        polygons.extend([offset + index for index in poly.vertices] for poly in obj.data.polygons)
    low = Vector([min(point[axis] for point in points) for axis in range(3)])
    high = Vector([max(point[axis] for point in points) for axis in range(3)])
    size = max(high - low)
    reach = min(max(size * 0.35, 0.35), 2.5)
    # The battlefield plane occludes undersides and grounds every asset.
    margin = size * 4.0 + reach
    offset = len(points)
    points.extend(
        [
            Vector((low.x - margin, low.y - margin, 0.0)),
            Vector((high.x + margin, low.y - margin, 0.0)),
            Vector((high.x + margin, high.y + margin, 0.0)),
            Vector((low.x - margin, high.y + margin, 0.0)),
        ]
    )
    polygons.append([offset, offset + 1, offset + 2, offset + 3])
    tree = BVHTree.FromPolygons(points, polygons, epsilon=0.0)
    directions = _hemisphere(RAYS)
    bias = max(size * 0.0015, 0.002)
    for obj in meshes:
        mesh = obj.data
        matrix = obj.matrix_world
        normal_matrix = matrix.to_3x3().inverted().transposed()
        worn = _worn_faces(obj)
        for existing in list(mesh.color_attributes):
            mesh.color_attributes.remove(existing)
        attribute = mesh.color_attributes.new(ATTRIBUTE, "BYTE_COLOR", "CORNER")
        mesh.color_attributes.active_color = attribute
        mesh.color_attributes.render_color_index = 0
        corner_normals = mesh.corner_normals
        edge_faces = {}
        for poly in mesh.polygons:
            for key in poly.edge_keys:
                edge_faces.setdefault(key, []).append(poly)
        cache = {}
        for poly in mesh.polygons:
            wear = 1.0 if poly.index in worn else 0.0
            center = matrix @ poly.center
            # Triangulation splits quads along their longest edge; both halves sample
            # that edge's midpoint (the quad center) so they shade identically.
            longest = max(
                poly.edge_keys,
                key=lambda key: (mesh.vertices[key[0]].co - mesh.vertices[key[1]].co).length,
            )
            partners = [
                other
                for other in edge_faces[longest]
                if other != poly and other.normal.dot(poly.normal) > 0.999
            ]
            if len(poly.vertices) == 3 and partners:
                a, b = (mesh.vertices[index].co for index in longest)
                middle_point = matrix @ ((a + b) * 0.5)
            else:
                middle_point = center
            # Large faces take their center's occlusion: a few corners interpolated
            # across metres would otherwise smear one dark corner as a diagonal ramp.
            corners = [matrix @ mesh.vertices[index].co for index in poly.vertices]
            span = max((a - b).length for a in corners for b in corners)
            uniform = min(max((span - SPAN_DETAIL) / (SPAN_PANEL - SPAN_DETAIL), 0.0), 1.0)
            face_normal = (normal_matrix @ poly.normal).normalized()
            middle = 1.0
            if uniform > 0.0:
                middle = _openness(tree, middle_point, face_normal, bias, reach, directions)
                if middle < 0.6:
                    middle = max(
                        middle,
                        _openness(tree, middle_point, -face_normal, bias, reach, directions),
                    )
            for corner in poly.loop_indices:
                vertex = mesh.loops[corner].vertex_index
                normal = (normal_matrix @ corner_normals[corner].vector).normalized()
                key = (poly.index, vertex)
                if key not in cache:
                    # Sample slightly inside the face: low-poly faces interpolate a
                    # few corners across metres, so an edge rail touching one corner
                    # must not darken the whole panel.
                    point = matrix @ mesh.vertices[vertex].co
                    inward = center - point
                    if inward.length > 0.0:
                        point += inward.normalized() * min(inward.length * INSET, INSET_LIMIT)
                    openness = _openness(tree, point, normal, bias, reach, directions)
                    # Single-sided sheets (roofs, canopies) render double-sided and may
                    # face inward; their visible side is whichever one is open.
                    if openness < 0.6:
                        openness = max(
                            openness, _openness(tree, point, -normal, bias, reach, directions)
                        )
                    openness += (middle - openness) * uniform
                    # The curve keeps open panels bright while crevices read from a distance.
                    exposure = openness**CONTRAST
                    cache[key] = FLOOR + (1.0 - FLOOR) * exposure
                occlusion = cache[key]
                attribute.data[corner].color = (occlusion, occlusion, occlusion, 1.0 - wear)

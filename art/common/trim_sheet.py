"""Assign a second UV set to mechanical parts before rigid meshes are joined.

UV0 and imported textures are untouched. UV1 is the runtime trim atlas; (0, 0)
means no trim (bevels, tiny parts, glass, team markings and cloth). Four strips
share one atlas across factions; the runtime material keeps each paint color.
"""
from mathutils import Vector

PROTECTED = ("teamcolor", "marking", "optic", "glass", "window", "emission", "canvas",
             "concrete", "foundation", "rock", "ore", "silicon", "rubber", "warning")
PAINT = ("armor", "panel", "ceramic", "secondary", "steel", "titanium", "mechanism", "cast", "olive")


def prepare(obj):
    if obj.type != "MESH":
        return
    mesh = obj.data
    if not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    # Match names before joining primitives with different source UV layer names.
    mesh.uv_layers[0].name = "UVMap"
    uv = mesh.uv_layers.get("TrimUV") or mesh.uv_layers.new(name="TrimUV")
    mesh.uv_layers.active_index = 0
    mesh.uv_layers[0].active_render = True
    for loop in uv.data:
        loop.uv = (0, 1)  # glTF converts Blender V to 1-V.
    # Imported meshes may already be triangulated. Connected coplanar faces
    # share one chart so a diagonal never becomes a spurious panel seam.
    edge_faces = {}
    for face in mesh.polygons:
        for edge in face.edge_keys:
            edge_faces.setdefault(edge, []).append(face.index)
    charts = {}
    for first in mesh.polygons:
        if first.index in charts:
            continue
        members = []
        pending = [first.index]
        seen = {first.index}
        while pending:
            face = mesh.polygons[pending.pop()]
            members.append(face)
            for edge in face.edge_keys:
                for index in edge_faces[edge]:
                    neighbor = mesh.polygons[index]
                    if index not in seen and neighbor.material_index == first.material_index and neighbor.normal.dot(first.normal) > .99999:
                        seen.add(index)
                        pending.append(index)
        for face in members:
            charts[face.index] = members
    for face in mesh.polygons:
        if face.material_index >= len(mesh.materials):
            continue
        material = mesh.materials[face.material_index]
        if material is None:
            continue
        label = material.name.lower()
        if any(word in label for word in PROTECTED) or not any(word in label for word in PAINT):
            continue
        # A stable orthonormal face basis retains plate proportion, even on wedges.
        n = face.normal.normalized()
        helper = Vector((0, 0, 1)) if abs(n.z) < .9 else Vector((0, 1, 0))
        tangent = helper.cross(n).normalized()
        bitangent = n.cross(tangent)
        points = [mesh.vertices[mesh.loops[i].vertex_index].co for i in face.loop_indices]
        projected = [(p.dot(tangent), p.dot(bitangent)) for p in points]
        chart = charts[face.index]
        all_points = [mesh.vertices[i].co for member in chart for i in member.vertices]
        chart_points = [(p.dot(tangent), p.dot(bitangent)) for p in all_points]
        low = [min(p[i] for p in chart_points) for i in range(2)]
        span = [max(p[i] for p in chart_points)-low[i] for i in range(2)]
        # Keep narrow chamfers and tiny fasteners smooth. Their actual geometry
        # and baked wear define the edge; a panel stamped there would shimmer.
        if min(span) < .14 or sum(member.area for member in chart) < .035:
            continue
        name = obj.name.lower()
        band = 1 if "vent" in name or "grille" in name else 2 if "strap" in name or "rail" in name else 3 if "tread" in name or "track" in name else 0
        columns = max(1, min(4, round(span[0] / max(span[1], .3)))) if band == 0 else 4
        col_offset = (len(chart) + int(round((low[0] + low[1]) * 10.0))) % 4 if (band == 0 and columns == 1) else 0
        for index, point in zip(face.loop_indices, projected):
            u = (point[0]-low[0])/span[0]
            v = (point[1]-low[1])/span[1]
            # Choose a single complete plate and inset by 4 px to avoid bleeding.
            # Broad parts repeat across the four plates in the horizontal strip.
            u_coord = col_offset * .25 + .002 + u * (.246 if columns == 1 else (columns * .25 - .004))
            uv.data[index].uv = (u_coord, 1-(band*.25+.002+v*.246))

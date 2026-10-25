"""Bounded leaf-card clusters for procedural scenery.

Cards remain inside the original ellipsoid, preserving gameplay envelopes.
Their custom normals follow the canopy volume rather than each flat quad.
Runtime ObjectMaterials recognizes the material suffix and supplies shared
cutouts; Blender exports keep the palette and conventional UV coordinates.
"""
import math

import bpy
from mathutils import Vector

_materials = {}


def card_material(original, kind):
    key = (original.name, kind)
    if key not in _materials:
        material = original.copy()
        material.name = original.name + " [cards:" + kind + "]"
        material.use_backface_culling = False
        _materials[key] = material
    return _materials[key]


def cluster(name, center, size, material, rng, kind="leaves", count=32):
    verts, faces, normals = [], [], []
    for index in range(count):
        # Golden-angle distribution with seeded jitter makes the canopy read
        # from above and the side without a camera-facing billboard.
        z = 1 - 2*(index+.5)/count
        phi = index*2.399963 + rng.uniform(-.3, .3)
        radial = Vector((math.sqrt(1-z*z)*math.cos(phi), math.sqrt(1-z*z)*math.sin(phi), z))
        helper = Vector((0, 0, 1)) if abs(z) < .9 else Vector((0, 1, 0))
        tangent = radial.cross(helper).normalized()
        bitangent = radial.cross(tangent).normalized()
        r = rng.uniform(.35, .70)
        half = rng.uniform(.34, .48)
        start = len(verts)
        for u, v in [(-1,-1), (1,-1), (1,1), (-1,1)]:
            point = radial*r + (tangent*u + bitangent*v)*half
            if point.length > .99:
                point.normalize()
                point *= .99
            verts.append(tuple(point[i]*size[i] for i in range(3)))
            normal = Vector((point.x/max(size[0], .01), point.y/max(size[1], .01), point.z/max(size[2], .01))).normalized()
            normals.append(normal)
        faces.append(tuple(start+i for i in range(4)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    uv = mesh.uv_layers.new(name="UVMap")
    for face in mesh.polygons:
        face.use_smooth = True
        for loop, value in zip(face.loop_indices, [(0,0),(1,0),(1,1),(0,1)]):
            uv.data[loop].uv = value
    mesh.normals_split_custom_set([normals[loop.vertex_index] for loop in mesh.loops])
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = center
    mesh.materials.append(card_material(material, kind))
    return obj

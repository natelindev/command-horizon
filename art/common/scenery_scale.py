"""Compress authored architecture vertically without changing map footprints.

Apply in world space so roofs, snow, windows and parented details share the same
ground datum. Trees, navigable bridges and terrain tiers deliberately keep their
authored dimensions. Targets are peak heights above that datum, in metres.
"""
from mathutils import Matrix
import bpy


def fit_height(collection, target):
    bpy.context.view_layer.update()
    objects = list(collection.objects)
    peak = max((obj.matrix_world @ vertex.co).z
               for obj in objects if obj.type == "MESH"
               for vertex in obj.data.vertices)
    factor = min(1.0, target / max(peak, .001))
    compression = Matrix.Diagonal((1.0, 1.0, factor, 1.0))
    # These are static props. Bake world coordinates into each mesh, avoiding
    # both TRS shear loss and inflated transformed AABBs on diagonal augers.
    transforms = {obj: compression @ obj.matrix_world for obj in objects if obj.type == "MESH"}
    for obj in objects:
        if obj.type == "MESH":
            if obj.data.users > 1:
                obj.data = obj.data.copy()
            obj.data.transform(transforms[obj])
            obj.parent = None
            obj.matrix_world = Matrix.Identity(4)
    bpy.context.view_layer.update()
    return factor

# Industrial Crossroads surroundings

Original editable perimeter scenery for the 128 × 104 m district. The [builder](build_industrial_surroundings.py) produces [IndustrialSurroundingsKit.blend](IndustrialSurroundingsKit.blend), five exported GLBs and the [measured bounds manifest](industrial-surroundings-manifest.json). All materials and named component meshes remain editable. No downloaded assets or generated bitmap textures are used.

The rail maintenance shed and two freight wagons establish the north siding; water utilities and the substation occupy the south service court. A second maintenance shed and seventeen birch/scrub groups frame the sides. These 23 placements, rail track and raised exterior ground are scenic and have no collision/navigation input. Each model stays outside the battlefield. Flattened foundations and zero-height, upward-normal terrain edges preserve the transition to playable ground.

The district ground shader has opt-in wear and yard paving. Industrial Crossroads enables it on its private ground material; Broken Foundry keeps the original default. A separate surface shader adds mottling and vertical wear to concrete, brick, wall panels and roofs in this map. Materials retain metallic values. Gameplay constants, existing landmark collision/air envelopes and map overview data remain unchanged.

Rebuild with Blender:

```sh
blender --background --python art/environment/build_industrial_surroundings.py
```

See [verification and comparison captures](../../docs/playtests/2026-10-04/INDUSTRIAL_SURROUNDINGS.md) for actual gameplay/rendering evidence and acceptance limits.

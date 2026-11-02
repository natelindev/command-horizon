# Engine modernization

Implement the valid opportunities from the engine review without launching Godot.
Preserve navigation authority, selection semantics, fog occlusion, independent
audio positioning, save formats and existing native crowd batching. Performance
improvements remain hypotheses until the deferred measurements are completed.

## Stage 1 — Navigation and commands

- Reuse path-query parameters/results with unused metadata disabled.
- Replace full-map construction rebakes with bounded tile baking, while publishing
  one combined region for existing projection, connectivity and native consumers.
- Coalesce changes, include clearance around tile boundaries, retain old topology
  until all affected tiles are ready, and handle destruction during pending work.

## Stage 2 — Selection and simulation

- Use a physics frustum as a conservative selection broadphase, retaining exact
  projected sample checks and all ownership/visibility/worker rules.
- Add useful types to projectile and spatial-index hot paths; retain meaningful
  nullable unit attributes and native interfaces.

## Stage 3 — Presentation

- Generate fog textures through a rendering-device compute backend where supported,
  preserving terrain reveal triangles, exploration and a viewport fallback.
- Add terrain-aware cosmetic GPU particle collisions and optional local volumetric
  mist, respecting graphics settings and renderer capabilities.
- Keep spatial combat voice budgeting and the existing synchronized music stems;
  neither warrants the proposed blanket replacement. Preserve native pose batching.

## Stage 4 — Static review and future verification

- Review formatting, resource references, shader interfaces and diffs without
  invoking Godot or launching the game.
- Record regression commands and required visual/performance comparisons below.
  Do not describe unexecuted tests or anticipated speedups as verified.

## Future verification

All Godot execution, including headless tests, is deferred at the user's request.
None of the checks below has been executed. Import the new compute shader with
the project's Godot build before running them. Static parsing does not establish
Godot type checking, shader compilation, correct gameplay or a performance gain.

### 1. Import, compile and headless regressions

After permission to run Godot is given, start with:

```sh
godot --headless --editor --path . --import
godot --headless --path . --script tests/headless/EngineModernizationRegression.gd
godot --headless --path . --script tests/headless/ArealSelectionRegression.gd
godot --headless --path . --script tests/headless/TerrainNavRegression.gd
godot --headless --path . --script tests/headless/NavigationProjectionRegression.gd
godot --headless --path . --script tests/headless/NavigationConnectivityRegression.gd
godot --headless --path . --script tests/headless/ProjectileSystemRegression.gd
godot --headless --path . --script tests/headless/TerrainSightRegression.gd
godot --headless --path . --script tests/headless/StrategicPolishRegression.gd
godot --headless --path . --script tests/headless/NeutralPolishRegression.gd
godot --headless --path . --script tests/headless/SaveRestoreRegression.gd
```

- The new engine regression compares reusable queries against `map_get_path`,
  retains old results across subsequent calls, checks GPU buffer layouts,
  exercises unequal seam segments, crosses a tiled map, and constructs, moves
  and removes an obstacle while asserting bounded rebake counts.
- The selection regression now also compares physics candidates with the screen
  scan using live Area3D roots. Extend the workload to 500+ units, dense overlapping
  colliders, edge samples, threaded physics, pause, rapid teleports and camera
  rotation. Confirm no selection/highlight/release latency changed.
- Run the existing native crowd, nearest-surface and movement regressions with
  their documented native flags, plus formation, factory egress, harvesting,
  destructible-barrier and hover regressions. Cover all maps, especially ramps,
  bridges, narrow crossings, shoreline approaches and buildings crossing seams.
- Exercise multiple construction/destruction events during an in-flight batch,
  destruction of the match before completion, and immediate loading of another
  match. Old worker completions must never publish into the new match.
- Run economic AI, salvage, garrison/evacuation, neutral-building egress,
  battlefield-event, commander landing and field-engineering regressions, since
  their route searches now share the match's query owner.
- Run projectile visual/physics, suppression, faction asymmetry, save round-trip,
  unit-state and native battlefield-index regressions for typed hot paths. Nullable
  health/damage/range fields and the current snapshot version remain intact.

### 2. Rendered fog, saves and graphics review

Run without `--headless`, once execution is authorized:

```sh
godot --path . --script tests/rendered/FogComputeRegression.gd
godot --path . --script tests/headless/SaveRestoreRegression.gd
godot --path . --script tests/rendered/CombatAudioPreview.gd
godot --path . --script tests/rendered/TerrainLayersPreview.gd
```

- `FogComputeRegression.gd` checks actual GPU output: circle visibility, occluded
  terrain triangles, remembered exploration after units leave, full reveal without
  modifying history, nonmultiple dispatch dimensions and restored exploration.
- Compare live fog and minimap output with `--viewport-fog` on flat/elevated maps,
  all factions, grounded/airborne aircraft, garrisons, relay capture, sight bonuses,
  pause, campaign reveals and multiplayer full reveal. The compute filter is a
  small tent filter; visually review its boundaries against the viewport blur.
- Verify exploration PNG save/load/save parity with both backends, including a
  restore while the compute backend is initializing. Review backend failure and
  Compatibility renderer fallback, repeated matches and RD resource teardown.
- Review High/Low environment settings in English and Chinese, all weather states,
  day/night and reduced flashes. High + atmospheric fog enables up to three local
  mist volumes in Forward+; High + ground detail enables particle collisions on RD
  renderers. Low retains existing effects. Check tactical silhouettes and fog
  secrecy, and ensure transient lighting has no volumetric ghost trails.
- Review sparks/debris on slopes, elevated ground, changing buildings and bridges.
  A heightfield has one surface per XZ location and cannot represent overhangs;
  gameplay projectile sweeps remain authoritative. Check paused particle behavior
  and that the heightfield refreshes on topology changes, not on every camera move.
- Check synchronized music, independent combat stereo positions, priority/duplicate
  voice handling and faction damage audio remain correct; their architecture was
  retained.

### 3. Performance measurements

- Reproduce the ordinary and heavy 2v2 benchmarks documented in
  `tools/performance/README.md` on identical hardware, engine/export build,
  resolution, visibility and graphics settings. Include native 4K and every phase.
- Measure command latency and CPU time for mass orders, marquee dragging and
  economic planning; compare default selection with `--screen-selection`.
- Measure construction/destruction worker time, foreground publication cost and
  synchronization latency on flat/elevated maps. Inspect `last_baked_tiles` on
  ground and hover bakers. Tiles limit raster baking; publishing the stitched
  single region still synchronizes the complete published mesh.
- Compare fog CPU packing, GPU time, allocations and frame p95 against
  `--viewport-fog`. Stationary vision skips compute submissions. Check sustained
  moving armies, expensive occlusion outlines and save-time readbacks separately.
- Measure High environment GPU cost separately from navigation/CPU improvements.
  No 10x, 2–3x, sub-millisecond or zero-dropped-audio claim is established here.

## Decisions retained from the review

- Obstacles remain baking inputs and avoidance constraints; no runtime carving
  substitute was introduced. Gameplay high-ground classification remains intact.
- A single stitched navigation region preserves existing native/projection and
  connectivity contracts. Worker concurrency is bounded to two jobs per baker.
- The GPU fog texture binds directly to existing world/minimap materials; a full
  screen compositor pass is unnecessary for this architecture. CPU gameplay sight
  and terrain reveal outlines remain authoritative. Saves keep their current format.
- Keep independently positioned, bounded combat voices; a single polyphonic
  spatial origin cannot replace them. Synchronized music stems already exist.
- Keep native crowd pose batching. Skeleton modifiers do not make GDScript IK
  execute in C++. SDFGI/SSIL and additional attractor/sub-emitter effects remain
  optional feature ideas without a demonstrated problem to fix in this review.

## Agent progress

- Initial source and engine-documentation review complete. Working tree was clean.
- Stages 1–3 implemented, including all production path-query call sites, tiled
  ground/hover baking, selection broadphase, typed projectile helpers, compute fog,
  save/minimap integration, and optional High environment visuals.
- Added two regression scripts and expanded existing selection/fog assertions;
  they are authored but unexecuted.
- Static-only review: GDScript files formatted; literal script/shader paths resolve;
  `git diff --check` passed. GDScript lint reports existing diagnostics in modified
  files; comparison against HEAD found no new diagnostic messages. These checks
  do not invoke Godot.
- Runtime, rendered, save compatibility, engine type/shader compilation and
  performance verification remain future work above. No Godot process was launched.

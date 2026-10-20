# Visible battlefield environment effects

## Stage 1 — Liquid surfaces

Make water motion readable at battle zoom with flowing wave normals, moving crests
and shoreline foam. Make lava visibly circulate beneath cooled plates. Use the
match clock so animation pauses and restores with the battle. Provide a cheap
static fallback without changing terrain, navigation or saved state.

## Stage 2 — Weather and controls

Add visible drifting clouds/shadows, biome dust and low mist using one bounded
screen pass instead of volumetric ray marching. Expose independent liquid,
cloud and dust switches alongside the existing fog control. Add a low/high
quality setting and bounded lava embers. Preserve settings preview/save/cancel
and English/Chinese localization.

## Stage 3 — Verification

Test settings persistence, pause/clock behavior, biome/weather transitions,
effect budgets and fallback controls. Render water, lava, cloud, dust and fog
in real matches; compare on/off frame times and review captures.

## Water architecture research

The user's follow-up asked about a hybrid fluid system. The implemented work is
an authored-current / analytical-wave layer, not a pressure or water-volume
solver. The recommended extension is an obstacle-aware baked flow field plus a
small, optional camera-local heightfield simulation for ford wakes, impact
ripples and foam transport. Keep the authored level authoritative for navigation;
only introduce volume-conserving gameplay water if flooding becomes a mechanic.

Primary references:

- [Valve: Water Flow in Left 4 Dead 2 / Portal 2](https://cdn.akamai.steamstatic.com/apps/valve/2010/siggraph2010_vlachos_waterflow.pdf): authored velocity fields, phased normal/colour advection and artifact control.
- [Rare: The Technical Art of Sea of Thieves](https://history.siggraph.org/wp-content/uploads/2022/09/2018-Talks-Ang_The-Technical-Art-of-Sea-of-Thieves.pdf): FFT ocean, localized GPU shallow-water details and camera-centred foam.
- [Epic: Water Body Actors](https://dev.epicgames.com/documentation/en-us/unreal-engine/water-body-actors-in-unreal-engine): spline-driven river velocities written to flow maps.

## Stage 4 — Hybrid interactive water

Implement the approved extension using a baked 256×256 current/depth/wetness
atlas for authored water. Deflect currents around the same solid footprints
used by terrain and movement; clamp normal flow near banks. Blend two advection
phases to limit texture distortion.

High detail adds a 128×128 GPU height/velocity/foam simulation spanning 64 metres
around the camera. Use a fixed 30 Hz step with at most two updates per frame,
32 impulses per update, 64 sampled units at 10 Hz and 64 shared splash particles.
Reflect waves at dry cells, advect disturbances/foam, damp the patch edge, and
reproject existing state when the camera moves. Clear transient state on large
camera/time jumps. Keep Low, disabled effects and unsupported rendering devices
on the analytical layer. Never read GPU state back during gameplay.

Use the main RenderingDevice and Texture2DRD as documented by
[Godot's compute-texture example](https://github.com/godotengine/godot-demo-projects/tree/master/compute/texture),
with resource creation, dispatch and disposal on the render thread.

This is a linear shallow-water ripple model over an authored current, not a
volume-conserving river simulation. Water levels and navigation do not change.
Legacy hand-built coastal/river scenes retain their analytical surfaces; the
hybrid field applies to the authored battlefield system.

## Agent progress

- Stages 1–2 implemented. Rivers use distance-along-channel coordinates and an
  indexed wave mesh: current, foam and ripples travel downstream around bends.
  Connected fords share the river surface with lower waves and a raised shallow
  surface, avoiding rectangular water over the dry approaches. Canals carry
  explicit centreline paths; pools and harbours have slower currents.
- Lava has circulating crust, emissive seams and a map-wide limit of 48 embers
  on Low / 96 on High. The weather uses one depth-aware rendering pass for
  cloud wisps, shadows, biome dust/ash and mist. Tactical fog draws afterward.
- Graphics settings expose liquid, cloud and dust switches, the existing fog
  switch, and Low/High detail (Low by default). English and Chinese translated.
- Water-flow regression passes on every authored map, including bend direction,
  ford continuity, mesh size and current speed. Environment-effects and Settings
  regressions pass. Terrain navigation, picking, rebaking and save/restore pass.
- Stage 3 complete: seven rendered scenes (authored harbour, legacy coast,
  river, lava, dust, mist and clouds) passed with effects off/low/high, plus
  motion frames and English/Chinese graphics dialogs. The flow clip is at
  `art/environment-effects/river-flow.mp4`; measurements are in the adjacent
  `performance.json`.
- At 1440×900 on Apple M1 Pro / Metal Forward+, the largest measured increase
  in median frame time was under 1 ms. These are paused-scene render samples,
  not a guarantee for active battles or other GPUs. The test harness reports
  shutdown resource warnings (registry/music resources and renderer shader
  caches); all behavioral assertions and render-error checks passed.

- Stage 4 implemented: static obstacle-aware flow fields and two-phase advection;
  High detail adds bounded GPU ripples, transported foam, ford wakes and impact
  splashes. Low/off release compute resources; headless/Compatibility use the
  analytical fallback. Hidden units and unseen impacts cannot inject wakes.
- Hybrid headless tests cover bank/obstacle deflection, wet/dry masks, ford depth
  and height, finite values and stability bounds on representative maps. Three
  map fields bake in approximately 0.27 seconds total on this machine.
- Rendered integration checks pass for real combat impacts, moving ford units,
  hidden/airborne unit suppression, pause, wave decay, camera scrolling, bounded
  catch-up and repeated quality switching/resource disposal. Captures and the
  active-solver timing report are in `art/environment-effects/`.
- Final verification also passed wave propagation beyond the input footprint,
  dry-cell confinement, the OpenGL Compatibility fallback, water-flow, combat
  effects, settings, and terrain navigation/rebake/save-round-trip regressions.
  Lint and whitespace checks pass. Existing engine shutdown resource warnings
  remain; there were no new shader, dispatch, or behavioral errors.
- Final active-solver sample (M1 Pro, Metal, 120 frames per tier) measured Low
  12.584 ms median / 25.949 ms p95 and High 12.507 ms median / 26.738 ms p95.
  Median cost was within measurement noise; the p95 increase was 0.789 ms.
  This isolates the active water solver in a paused battle, not a full combat
  benchmark or a performance guarantee for other devices. The review clip is
  `art/environment-effects/hybrid-water.mp4` and the ford still is
  `art/environment-effects/hybrid-ford-wake.png`.

# Battle performance optimization

## Stage 1 — Establish a baseline

Inspect simulation and rendering hot paths. Run reproducible battle and maximum-population benchmarks with rendering enabled, recording frame time, GPU time and simulation throughput.

## Stage 2 — Remove measured bottlenecks

Optimize unnecessary CPU work and rendering overhead while preserving gameplay, visibility and visual quality. Add focused regression coverage for changed behavior.

## Stage 3 — Verify and report

Repeat the same benchmarks, run relevant gameplay regressions and formatting checks, and document measurements with hardware and remaining limitations.

## Stage 4 — Retire obsolete menu controls

Remove program-specific menu controls and stale chip/program descriptions. Verify current behavior controls, tactical guidance, research and English/Chinese HUD layouts.

## Stage 5 — Make soldier locomotion independent of frame rate

Reproduce render/physics cadence differences, inspect the Windows export configuration, and add regression coverage for walking/running at different frame rates. Distinguish local reproduction from Windows-only verification.

## Stage 6 — Standardize starting resource access

Inspect all playable map spawn layouts, apply one shared starting-field distance rule, and verify geometry, reachability and save compatibility.

## Stage 7 — Improve large-battle frame pacing

Rebaseline the current rendered stress workload, profile the remaining hot paths,
and remove redundant work without changing unit counts, combat rules, or visual
quality. Repeat rendered measurements and focused gameplay regressions, recording
frame-time tails as well as averages and any remaining hardware limits.

## Stage 8 — Balance nearby worker assignments

Spread harvesters across reachable deposits of the ordered resource type within
the selected field. Account for existing reservations and travel cost, preserve
cargo and queued orders, and verify four-worker assignments, depletion, pause,
save restoration and real deliveries across factions.

## Agent progress

- Stages 7–8 complete: repeated rendered stress measurements improve movement
  from 25.34 to 23.19–23.20 ms and combat from 32.03 to 28.62–28.74 ms. Combat
  frames over 33 ms fall from 33.7% to 6.3–6.6%; maximum-population performance
  remains below 60 FPS on M1 Pro. See SMOOTHNESS.md and the accompanying raw rows.
- Four-worker distribution, pause/save/load, unreachable deposits, cargo
  accounting, navigation, combat and animation pass 14 targeted headless
  regressions. Six rendered worker cases pass across all factions/resource types;
  worker and shared-scenery captures reviewed. Formatting, lint and diff checks pass.
- Log review also found and fixed an existing resource-site exception in legacy
  spectator matches; ownership and facility regressions now pass without script errors.
- Stage 7 started: preserving ongoing garrison/refinery/cargo edits; collecting a
  fresh full-resolution, real-time 200-unit baseline before changes.
- Fresh baseline: 25.34 ms movement / 32.03 ms combat at 1920×1080. Shared scenery
  meshes remove about 900 initial draw calls; typed hot paths and tighter spatial
  searches are under regression review.
- Stage 8 added at the user's request. Existing harvest logic caps deposits at
  two workers but fills the nearest node first and scans the full army repeatedly.

- Initial repository inspection complete; existing scale benchmarks exercise 200 mobile units and 80 structures. Earlier verification concentrated on headless simulation, leaving rendered performance unverified.
- Baseline rendering and CPU profiling complete; per-unit Lua snapshot preparation dominates the original stress workload.
- User approved replacing programmable unit logic with Attack, Defensive, Follow, Guard and Hold Fire. Battle editors, factory program activation and AI specialist loops have been removed from normal play.
- Added separate fine/coarse spatial queries, typed contact math and cached navigation trait lookup.
- Added stance persistence (snapshot v14), legacy script conversion without VM creation, and a three-faction behavior regression.
- Tested 30 Hz simulation with interpolation; the 60 Hz simple-behavior experiment is recorded for comparison.
- Functional and rendered HUD verification complete across all three factions.
- Final design implemented: five battle controls, no battle Lua activation, no factory/AI program loops, compatibility-only native mission controllers.
- Kept 30 Hz with interpolation after combat, navigation, orders and animation checks; fixed gait sampling between simulation ticks and added stance persistence.
- Three-faction headless and rendered behavior checks pass. English/Chinese HUD captures, Chinese text audit and locale switching pass.
- Final rendered stress repeats complete at 39.4 FPS moving / 31.1–31.2 FPS in combat, with all 200 units moving and zero VMs. Warm 70-unit combat averages 83.3 FPS.
- Performance report, raw measurement rows and a 22-script verification index recorded. Release smoke checks, navigation/combat/animation checks, formatting/lint and repository cleanup complete.
- Remaining limits: RTX 4090/Windows and release-export performance are unverified; the maximum-population M1 Pro case remains below 60 FPS. Existing Godot shutdown resource warnings remain.

- Follow-up complete: removed obsolete menu controls and chip/program instructions; behavior, tactical guidance, technology and English/Chinese HUD reviews pass.
- Reproduced 70 frame-cadence animation failures; fixed stride restart and tiny-travel thresholds. Five infantry roles across three factions pass 30–1,000 FPS sampling, and three-faction rendered contact sheets were reviewed. Windows native execution remains unverified.
- Standardized all three current skirmish home fields to 18 m. Nine faction/map combinations deliver materials and electronics for both players; advanced-start geometry and saved-position/stock preservation pass.
- Follow-up results and remaining limits are recorded in FOLLOW_UP.md and follow-up-verification.json.

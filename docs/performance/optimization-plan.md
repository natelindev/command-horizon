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

## Agent progress

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

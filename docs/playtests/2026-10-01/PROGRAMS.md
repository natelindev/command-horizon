# Basic unit programs — implementation and verification

Date: 2026-10-01. Godot 4.6, macOS M1 Pro. This is the first playable part of roadmap Stage 2, with built-in behavior presets and a reusable parameter library. It does not yet execute Lua.

## Playing the slice

Choose an **Advanced** skirmish start to try programs immediately. Both starter tanks include chips. In Standard, finish a vehicle producer and faction lab. Robots, scouts, strike aircraft and long-range armor have hardware included; conventional tanks need a retrofit.

Select compatible units. Choose **Hold position**, **Guard area**, **Escort ally** or **Patrol route**. Assign a point, friendly unit or two waypoints using the panel. Choose a safe point if automatic retreat is desired. Set target priority and retreat/return thresholds, then **Apply & run**. A missing assignment holds the unit and explains what is needed. Repair robots use their assignment as a bounded service area; scouts patrol/follow without receiving a weapon.

Right-click orders, attack-move and Stop enter **Manual** immediately. They never auto-resume the preset. **Resume** re-evaluates the saved assignment. Parameters and assignments can be edited during tactical pause; no simulation time advances. Selection shows state, exact saved version when applicable, a reason, and readiness across the selection. Hover the reason for its last 16 changes. A dashed neutral boundary marks the representative guard sector; safe points and patrol routes are also shown. The boundary renders beneath HUD controls.

**Fit chip · 4 E** prompts for a completed friendly HQ or repair depot. A tank travels there and installs for five simulation seconds, slowed to 35% by insufficient power. Orders cancel and refund the full fee; destruction loses it. A missing service or five seconds without travel progress cancels and refunds. Factories can queue fitted tanks for +4 E / +5 seconds; that choice is pinned on each job, and cancellation refunds its recorded cost. Chip production waits for a replacement lab if the lab is lost. Previously unlocked technology and installed chips continue operating.

**Save version** stores an immutable parameter version in `user://program-library.json`. A loaded version is a draft until Apply. Saving an update appends a version; editing a loaded draft marks it custom. Per-map points/units are not saved with the library. The library has a schema, a 1 MiB input cap and a 128-version bound. Invalid values, corrupt JSON and failed writes preserve the existing file. No network/account is required.

## Verification

| Scenario | Evidence |
|---|---|
| Hardware and technology | `ProgramRegression.gd`: infantry excluded, robot hardware cannot bypass unlock, unfinished lab rejected, factory+completed lab unlock, lab loss preserves technology |
| Retrofit lifecycle | Exact one-time fee; duplicate/installed purchase rejected; cancellation/full refund; pause; low-power 35% speed; five-second completion; destruction loses fee; provider destruction cancels/refunds |
| Factory jobs | Fitted tank costs +4 E / +5 s; full cancellation refund; production holds without lab; final spawned tank has chip |
| Authority | Program does not interrupt a direct move or auto-resume on completion; Stop holds; explicit Resume starts again; paused Apply remains pending |
| Local tactics | Guard fires at legal visible targets, drops targets outside sector, rejects obstructed/hidden targets; weakest/armor priorities; retreat 30%/return 80% hysteresis; no invented safe point |
| Recovery/support | Five-second no-progress state holds without repeated attempts, including a changing destination; explicit retry works; destroyed escort waits; scout patrol moves; repair preset heals eligible ally |
| Library | Reloaded versions retain separate parameters; invalid hysteresis/NaN rejected; corrupt library cannot be overwritten |
| UI | `ProgramPreview.gd`: actual advanced Helix roster, aircraft picking/escort/paused selection, factory fitting toggle and pinned hardware job, panel Save/Load, map-click assignment without losing selection, paused Apply, human terrain order override, Resume; screenshots and layout bounds checked at 1440×900 and 1280×720 |
| Existing gameplay | Combat, navigation, both-faction skirmish, motion and legacy Bastion regression suites pass |

Review screenshots: [Running program](../../../art/skirmish/program-running.png), [manual override at 720p](../../../art/skirmish/program-720p.png), [paused assignment](../../../art/skirmish/program-paused.png), [factory chip option](../../../art/skirmish/program-factory.png).

The active-program stress scenario uses 200 chipped mobile units, 80 structures and 32 resource nodes, across both factions, at 1920×1080. Units retain inflated test HP to keep the full workload alive; the test is not a balance match. Run `tests/headless/ScaleBenchmark.gd` with `-- --programs` to activate presets. All 200 moved; 116 fired; peak sampled live projectiles/tracers were 27/25.

The initial implementation averaged 64.62 ms advancing / 68.29 ms combat because each program queried perception across all enemies. Spatial candidate culling inside the shared battlefield perception service reduced this to **19.52 / 24.47 ms**, with p95 **31.47 / 45.71 ms**. Preset evaluations are staggered across frames. Results use fixed 60 Hz simulation with VSync disabled and reflect workload throughput on one machine, not stable 60 FPS. The old conventional benchmark uses a different roster/behavior mix, so it is not a controlled overhead comparison. Lua instruction budgets and 300 simultaneous transient effects are not covered by this run.

Format/lint and editor import are checked. Existing runtime navigation GPU-readback warnings and shutdown ObjectDB/resource/RID diagnostics remain; these are not treated as release-ready verification. No new GDScript runtime errors were observed in the passing scenarios.

## Remaining Stage 2 work

- Coordination research, explicit program squads and faction coordination abilities.
- Shift-order queues and opt-in auto-resume; current direct orders always stay Manual after completion.
- Specialist standoff/strike-return/fire-support presets and exact factory program-version pins. The current factory option pins hardware only.
- Lua dependency, sandbox, bounded API/budgets and failure containment; then visual-to-Lua rules and arena validation.
- Reuse acceptance on authored map 2, novice usability and Standard-start chip timing. The parameter library round-trip is tested; full cross-map campaign/save-game state is not.

The broader goal still includes campaign, additional faction/map depth, save/load, LLM drafts and presentation/performance work. These remain in the roadmap rather than being redefined as complete by this slice.

# Rendered continuation — 2026-10-16

The user authorized real game launches and rendering after the headless phase, then requested removal of sparse legacy map choices and fuller campaign interiors. This record supplements the [headless evidence](../headless-continuation/README.md).

## Implemented and verified

- Fixed production tile prices extending outside two-line buttons. The original containment regression failed 34 cases; the corrected sizing passes across factions and locales.
- Fixed black opening briefings by initializing player sight before the cinematic pause. Nested alert layers are now hidden during the briefing and restored on skip.
- Fixed campaign faction panels retaining the previous faction's textures.
- Removed duplicate objective notices; the objective remains in the mission panel.
- New skirmishes offer only the expanded Desert Frontier, Alpine Relay and Coastal Foundry maps. Existing path and numeric preferences migrate to appropriate replacements. Legacy scenes remain available for loading existing saves.
- Added biome-specific buildings, courtyards, groves and moving residents throughout campaign interiors. Solid buildings use matching navigation and sight footprints and aircraft clearance. Shared meshes batch repeated scenery. Bases, resources, objectives and convoy routes retain clear space.
- Removed diagonal route strips across the urban street grids. Compact tutorial and relay maps use smaller scenery placements.
- Captured garrison buildings retain ownership when the last occupant leaves or dies. Enemy infantry can recapture an empty building through the contextual command; occupied enemy buildings still resist entry. Empty owned buildings retain their owner-colored garrison label. Version 13 snapshots persist ownership, with version 11/12 migration checks. Destruction still evacuates occupants and clears ownership.

## Rendered coverage

| Fixture | Coverage |
| --- | --- |
| HUD console | 60 faction/layout/production/alert/pause states |
| Menus | 28 captures: English/Chinese, 100%/150%, three factions |
| Campaigns | 16 openings in both languages, battle views and environment views (64 captures) |
| Campaign story | Mouse skip, keyboard result scrolling, long English/Chinese debriefs |
| Construction | 12 captures across three factions |
| Map balance | 10 map overviews and battle views; includes retained legacy save/test scenes |
| Unit animation | 45 role/faction sheets, plus six real-time infantry/tank sheets |
| Neutral ownership | Occupied, vacant-owned and vacant-recaptured building views |

Representative captures:

- [Vacant captured building](../../../../art/neutral-ownership/vacant-owned.png)
- [Enemy recapture](../../../../art/neutral-ownership/vacant-recaptured.png)
- [Quiet Streets interior](../../../../art/hero-campaigns/helix_quiet_streets-environment.png)
- [Supply Line interior](../../../../art/hero-campaigns/supply_line-environment.png)
- [First Orders interior](../../../../art/hero-campaigns/first_orders-environment.png)
- [Drainage interior](../../../../art/hero-campaigns/frontier_drainage-environment.png)
- [Production tile layout](../../../../art/hud-console/bastion-720p-factory.png)
- [Helix campaign menu at 150%](../../../../art/polish-menus/Campaign-en-1.5-1.png)

Capture fixtures force a draw before reading the viewport. The initial construction capture stalled when normal window drawing stopped; corrected captures pass. Animation captures also wait a process frame after pose/caption changes to avoid recording the previous pose.

## Performance

Apple M1 Pro, Godot 4.6, Metal Forward+, default visual settings, VSync disabled, uncapped real-time measurement (no fixed-FPS acceleration). These are editor/debug runtime measurements, not release performance guarantees. The skirmish measurements precede the campaign-only interior additions.

| Scenario | Pixels | Mean frame | P95 frame | Mean FPS |
| --- | --- | ---: | ---: | ---: |
| Base, 30 units | 2304 × 1296 | 9.51 ms | 12.83 ms | 105.2 |
| Midfield combat, 70 units | 2304 × 1296 | 13.71 ms | 16.84 ms | 73.0 |
| Maximum movement, 200 mobile + 80 structures + 200 Lua VMs | 1920 × 1080 | 142.72 ms | 209.84 ms | 7.0 |
| Maximum combat, same population | 1920 × 1080 | 212.06 ms | 243.61 ms | 4.7 |

The final battle benchmark verifies 240 actual rendered frames and advancing simulation in each scenario. An earlier run with a stationary simulation clock was rejected; its FPS is not used here. The maximum-load run verifies 94/76 rendered frames, all 200 units moving and travelling, 103 firing, and all Lua VMs remaining functional. Ten simulated seconds take 13.42/16.12 wall seconds.

Halving only 3D resolution improves maximum-load movement/combat to 130.29/197.25 ms (12.51/14.99 wall seconds per ten simulated seconds). This modest change indicates substantial CPU/simulation pressure; it does not isolate all GPU costs. The viewport GPU timing API returned zero throughout, so GPU time is **unavailable**, not zero-cost rendering. Maximum-load performance remains below a smooth real-time target.

## Verification notes

All eleven new campaign operations complete in normal combat with harvesting, paid replacements, hero abilities and objective travel after the interior additions. Supply Line, First Orders, Split Signal and Broken Foundry also pass their full mission regressions. The new interior regression checks resource access, distribution, sight/aircraft clearance and deterministic moving-resident poses across all current campaigns and the retained Air Corridor mission.

The first Command Horizon playthrough exposed stalled replacement infantry near the armored guard. Widened reinforcement corridors restore victory; a reserved forward construction pocket also passes the original environment regression. Final checks pass in 172.5 seconds (combat) and 45.5 seconds (environment).

The persistent-ownership regression failed six assertions before the fix and now passes. It covers departure, vacant time, friendly re-entry, enemy recapture, defended-building rejection, last-occupant death, save/load and legacy version 11/12 migration. Neutral-world destruction/combat, all-faction facility vacancy/income/recapture, save snapshots and production activity checks also pass.

Some Godot test exits still report ObjectDB/resource/RID cleanup warnings. Passing rows mean no script/parse errors and successful scenario assertions; they do not imply clean shutdown stderr.

## Remaining acceptance limits

- Maximum-population rendered performance remains poor; further CPU profiling and optimization are needed for smooth play at that extreme.
- GPU timestamp data is unavailable on this setup.
- Subjective voice listening, art-direction and balance acceptance remain human review items.
- Native packaged main-menu rendering was observed on Apple Silicon. Automated clicking failed with `noWindowsAvailable` after discovery and exact-path rebinding; manual launch-to-battle interaction is unverified. Scripted rendered interactions pass. Included x86_64 libraries do not establish Intel or other-platform runtime acceptance.

## Final verification

Final campaign captures pass (64 images, 53.5 seconds). Three ownership captures also pass. Source formatting (373 files), lint and whitespace checks pass. All 14 isolated packaged-resource checks pass, including persistent ownership, neutral combat, facilities, saves, campaign interiors, dialogue, hero restoration, Lua and HUD production. The rebuilt native release starts on Metal and exits successfully after 120 frames. Deep signature verification passes for the bundle and both native architectures.

Existing options and all three autosaves match their pre-launch hashes. A later skirmish faction preference change was left intact because its timestamp falls after the interrupted native test; no user saves were overwritten.

- [Packaged check results](package-final-check.txt)
- [Ownership reproduction before the fix](capture-before-details.txt) and [final regression results](capture-final-checks.txt)
- [Final campaign route/construction checks](horizon-final-checks.txt)
- [Battle frame measurements](battle-frame-verified.txt), [maximum-load measurements](scale-frame.txt), and [half-resolution diagnostic](scale-half-resolution.txt)
- [Native startup log](native-final-startup.txt) and [signature verification](signature-final.txt)
- [macOS release ZIP](../../../../build/Open%20RTS-rendered-verified.zip) (141,401,276 bytes)

Release SHA-256: `732d7b68c5f71cda099c41492f306bd05f54c0ecb3a489bbc8b9ad0e0ea38bd2`.

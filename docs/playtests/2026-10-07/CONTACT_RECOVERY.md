# Contact recovery without losing the HQ escape

The harvesting failure discovered during the construction experiment is fixed. Ground recovery admits a direction with at least the existing two-centimetre contact margin of free travel, then prefers navigation clearance and uses free travel to break ties. A fully blocked side no longer excludes a backward escape. A partially clear side can still use ordinary avoidance and tangential sliding instead of repeatedly backing away from the work site.

Only `source/match/units/traits/Movement.gd` changes in shipping code. The existing `.02` collision allowance is factored into `GROUND_CONTACT_MARGIN` and reused for recovery eligibility; its collision value is unchanged. Work-face selection, contact range, movement speed, order authority, arrival rules and save fields retain their preceding behavior.

## Isolated cause

The retained October 4 engineer has three materials and is trying to finish collecting at a crowded deposit. The prior HQ-traffic change ranked the longest straight body-free ray first. In this case that selected a backward diagonal, after which the engineer returned to the same blocked approach and repeated the cycle. The [before trace](contact-recovery/before-trace.json) records no collection over twenty simulation seconds.

An isolated project initially copied current shipping sources and changed only Movement.gd to its pre-HQ ranking. That control collects at 6.1 seconds and passes the original contact suite. The trace shows why reverting blindly would be insufficient: the contact site has a sideways ray with roughly three centimetres of initial body-free travel and two metres of navigation clearance, while the retained Industrial HQ pinch has zero free travel in every forward/side direction. The old ranking could select those completely blocked HQ sides. The final ranking distinguishes a usable short slide from a fully blocked side, preserving both behaviors.

The same isolated project was then configured with the preceding, faulty Movement.gd for the final negative control. All other shipping sources match the final worktree. It fails **15 assertions**: twelve captured collection completions and three post-load collection completions. No script or parse errors occur. Source copies and fingerprints retain both baseline configurations.

## Actual work and restoration

[ContactRecoveryRegression](contact-recovery/final-regression.log) runs the unchanged captured functional checks twelve times. Every replay collects at **6.1 seconds**, consumes exactly one unit of finite resource stock and finishes with four materials. Each moves about 2.099 metres by four seconds; no timing or excursion bound was weakened. Maximum observed single-frame movement is approximately 0.064001 metres, within the original speed check, and minimum sampled body clearance is approximately -0.000014 metres, within the existing collision tolerance.

Separate disk round trips begin after 75, 150 and 240 physics frames. Paused position, cargo and destination remain unchanged; real collection subsequently completes within the original ten-second post-load bound. The existing manual replacement check still cancels gathering and reaches the replacement Move goal. All three factions also complete crowded HQ delivery and power-plant construction, preserve finite cargo, refuse fully occupied work faces and cancel when the target disappears. First work begins in approximately 2.48–3.32 seconds in these fresh cases.

The new expanded regression reuses the existing behavioral assertions. The original test now has a configurable checkpoint frame count, and intermediate unconditional `PASS` messages say `CHECKED`; only its final failure count establishes success.

## Shared checks and rendered review

Nine relevant headless suites have accepted passing runs:

- ContactRecoveryRegression
- HQTrafficRegression and HQTrafficFactionsRegression
- AttackArrivalProgressRegression
- HarvestTrafficRegression
- CrowdBoundaryRegression
- GuardArrivalRegression
- FrontierCrowdRegression
- CargoReturnRegression

The HQ headless runs use the final ranking before the equivalent `.02` constant extraction. They retain real escape, collection/delivery, an intermediate disk load, speed/body/navigation bounds and fresh traffic completion for all factions. The rendered HQ run uses the final file: both branches escape, reach their destination, collect and deliver actual cargo. Their observed delivery times are approximately 40.27 and 41.48 seconds; these are replay observations, not timing guarantees under combat.

Both rendered scenarios pass. All **ten 1280×720 captures at 150% UI scale** were inspected: three contact stages and seven HQ stages including reload. The contact panel shows cargo increasing from three to four. The HQ scenes show the engineers separating and completing their retained orders. Layouts remain readable with the existing scrollable selection panel. These scripts select units and resume the game programmatically; this is rendered simulation/authority verification, not a claim of new native mouse/keyboard testing.

Formatting and lint pass. Known runtime navigation-readback warnings and shutdown resource/RID/shader diagnostics remain. Two guessed test names were rejected by file-existence guards and never executed; the actual boundary, arrival and cargo suites above were run instead. Full classifications are in [run-results](contact-recovery/run-results.json).

## Rejected approaches and limits

Six work-action experiments were tested and discarded: retaining best approach progress, rejecting obstructed paths, reassessing after escape, sampling a wider contact band, introducing a single waypoint, and a bounded local waypoint search. None passed the complete original contact checks. One restored actual collection in fresh replays but still failed the four-second movement checks and post-load collection. Their sources and failed logs remain available. MovingToUnit.gd is byte-identical to its pre-turn source; no experimental work-route code ships.

This closes the captured harvesting regression while retaining the verified HQ and arrival cases. It does not establish general congestion freedom or improved match balance. No new full-match outcome claim is made. The previously retained 33-second stationary episode, programmed goals obstructed by later friendly construction, Industrial home defense and paid progression remain follow-up work. Broader content, novice and platform acceptance are still open, and performance remains deferred.

## Reproduction

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/ContactRecoveryRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/HQTrafficRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/ContactApproachPreview.gd -- --captures=res://tmp/new-contact
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/HQTrafficPreview.gd -- --captures=res://tmp/new-hq
```

Use fresh capture names to preserve evidence. The report folder retains comparison data, raw traces/logs, source snapshots, fingerprints and SHA256SUMS. The overall gameplay goal remains active.

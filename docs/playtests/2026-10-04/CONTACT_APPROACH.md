# Static-target contact recovery — 4 October 2026

The captured Alpine engineer can now approach another reachable work face when neighboring units block its original route. Resource quantities, work range, movement speed, avoidance and manual-order authority stay intact. This addresses the demonstrated resource/building approach failure; the earlier uncaptured Desert engineer and Alpine AI tank delays remain unresolved.

## Captured cause and original failure

The [coordination archive](ai-coordination-stall.json) saves `unit-0` at `(17.255119, 0, 33.506615)`, targeting `resource-2` with three carried materials. Its center distance is 1.823149 m, just 0.023149 m beyond the existing 1.8 m work range. Nearby engineers are stationary because their HQ is gone. Navigation has a path, but local avoidance almost cancels both the requested approach velocity and its existing recovery sidestep.

The [crowded diagnostic](contact-stall-probe.log) needs roughly six seconds to creep into range, then completes the one-second collection interval. The [isolated diagnostic](contact-stall-isolated.log), removing other mobile units, reaches contact promptly. The missing HQ explains the subsequent waiting state, not the preceding slow contact approach. [Diagnostic source](contact-stall-probe.gd.txt) is retained.

The [original regression](contact-approach-before.gd.txt) produces [three real failures](contact-approach-before.log): maximum excursion by four seconds is only 0.0029–0.0051 m. It eventually collects after 7.08–7.87 seconds. The original full match recorded a 16.5-second stationary episode before this archive; replay does not reproduce that full duration, so these figures are not a controlled 16.5-to-5.8-second comparison.

A [temporary alternate-work-face probe](contact-detour-probe.log) establishes actual collection after changing the approach. A [temporary alternating-sidestep probe](contact-alternating-probe.log) moves farther but still fails to collect within twelve seconds. Movement distance alone therefore does not establish successful recovery. Both probe sources are retained: [work-face probe](contact-detour-probe.gd.txt), [sidestep probe](contact-alternating-probe.gd.txt).

## Production behavior

`MovingToUnit` retains ordinary movement until a terrain unit approaching a navigation obstacle travels less than 0.2 m over a two-second observation interval. It then samples 32 points around the target, projects them onto the current navigation map, and selects the shortest reachable path ending within the existing contact range. Candidates must be clear of owned or currently observed mobile units and meaningfully different from the current destination. If no candidate qualifies, the existing order stays in place.

The selected destination uses ordinary movement and avoidance. No priority, footprint, speed, global sidestep or harvesting-slot rule changes. The adherence-margin calculation is extracted into a shared helper without changing its formula. This applies to resource collection, HQ delivery and construction through their existing `MovingToUnit` actions. It introduces no new saved fields: the chosen destination already belongs to the action archive; the local progress observation restarts after loading.

## Targeted and rendered verification

The [final regression](contact-approach-regression.log) checks:

- Three exact archive replays: roughly 1.374 m excursion by four seconds, real collection at 5.783 seconds, one material removed from finite stock and one added to cargo.
- Maximum per-frame movement of about 0.0517 m remains within normal speed; minimum neighboring-footprint clearance is approximately −0.000014 m, within the 0.08 m numerical tolerance.
- A real disk save during the detour retains paused position, cargo and chosen destination; collection resumes after loading.
- A new manual move replaces the detour and retains the three carried materials.
- Both factions deliver exactly four electronics to a crowded HQ and complete construction at a crowded power plant. First work begins in 2.48–2.77 seconds, inside the existing contact range.
- Six engineers occupying all work faces cause no overlapping destination or repeated movement command. Removing the target cancels the action.

An earlier expanded fixture incorrectly called a campaign-only spawn helper on a skirmish. Its [script-error log](contact-approach-fixture-error.log) is retained and excluded despite the engine returning zero. The corrected [intermediate run](contact-approach-intermediate.log) and final run contain no script errors. Assertions and log inspection, not exit status alone, determine acceptance.

The [normal-clock rendered replay](contact-approach-render.log) passes at 1280×720 with 150% interface scale. All three captures were reviewed: [before](../../../art/skirmish/contact-approach-before.png), [detour](../../../art/skirmish/contact-approach-detour.png), [collected](../../../art/skirmish/contact-approach-collected.png). The selected engineer remains visible among the field crowd, cargo increases from three to four, and the HUD correctly changes to “No drop-off” because the archived HQ is absent. No native-input or new-control verification is claimed.

## Shared checks and complete matches

All [twelve shared suite results](contact-approach-shared.json) pass with zero script errors: resource navigation and field limits, archived crowd boundaries, two-faction Desert traffic, base access, queued/manual orders, unit motion, restoration edges and combat, global AI coordination, raided-field resumption and support. Each log is retained as `contact-approach-verified-<suite>.log`. Existing finite stock, harvest quotas, bounded contact ranges, normal movement, construction access and archive contracts remain checked.

The [eight final trial records](contact-approach-matches.json) cover both factions, Desert/Alpine and Standard ground/Advanced mixed reference policies at Standard difficulty and seed 4110. [Process results](contact-approach-match-exits.json) retain **seven completed matches and one unresolved thirty-minute limit**; the latter correctly exits 1. This cohort is not an all-passing complete-match acceptance gate.

| Human faction | Map | Start / policy | Result | Time | Longest stationary travel, human / AI |
| --- | --- | --- | --- | --- | --- |
| Bastion | Desert | Standard ground | Defeat | 7:14.4 | 1.5 / 1.5 s |
| Bastion | Desert | Advanced mixed | Defeat | 6:47.7 | 5.5 / 2.0 s |
| Bastion | Alpine | Standard ground | Victory | 8:02.1 | 7.0 / 1.5 s |
| Bastion | Alpine | Advanced mixed | Unresolved at 30:00 | 30:00.7 | 2.5 / 1.5 s |
| Helix | Desert | Standard ground | Victory | 10:57.1 | 3.5 / 2.0 s |
| Helix | Desert | Advanced mixed | Defeat | 5:27.2 | 4.5 / 3.0 s |
| Helix | Alpine | Standard ground | Victory | 8:39.4 | 3.5 / 1.5 s |
| Helix | Alpine | Advanced mixed | Defeat | 5:51.8 | 2.0 / 4.0 s |

Raw logs: [0](contact-approach-match-0.log), [1](contact-approach-match-1.log), [2](contact-approach-match-2.log), [3](contact-approach-match-3.log), [4](contact-approach-match-4.log), [5](contact-approach-match-5.log), [6](contact-approach-match-6.log), [7](contact-approach-match-7.log).

No trial triggers the fifteen-second stationary-travel archive. Actual task/order checks record zero violations across **9,961 half-second samples**. The completed results are three human-policy victories and four defeats, lasting 5:27.2–10:57.1. Reusing a seed does not eliminate navigation/combat scheduling variability; these results do not isolate the change's effect on wins or directly compare the earlier sixteen-second episode with case 7.

The unresolved Bastion Alpine Advanced trial retains both economies and active combat at thirty minutes, with twenty AI waves and 29 individual human-unit withdrawals. The policy records one transition into assault; that count does not measure every subsequent individual recommitment. Final human forces include twelve tanks and seven walkers, with substantial harvesting and damage recorded throughout. Its longest stationary travel is 2.5 seconds for the human and 1.5 seconds for the AI, so the available evidence does not support a repeated long movement stall. The policy's recovery/recommitment behavior and broader pacing are the next investigation; its causal explanation is not yet established.

The [final audit](contact-approach-audit.json) confirms all nineteen recorded sources are unchanged through the cohort. All eight logs are free of script errors; the sole match assertion is the unresolved case 3. The twelve shared suites and targeted/rendered checks pass independently. Overall match pacing and release acceptance remain open.

## Reproduction and limits

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/ContactApproachRegression.gd
godot --path . --script tests/rendered/ContactApproachPreview.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/ResourceNavigationRegression.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/CrowdBoundaryRegression.gd
```

The [source manifest](contact-approach-source-sha256.json) records the production change and relevant movement, persistence, policy, metrics and verification sources before the final cohort. The [editor import](contact-approach-editor.log), [format check](contact-approach-format.log) and [lint](contact-approach-lint.log) pass. The existing navigation-bake and shutdown RID/resource warnings remain. Performance optimization is deferred.

This does not establish universal deadlock freedom, a solution to sealed navigation islands, or the cause of the two earlier uncaptured movement episodes. The broad gameplay goal remains active: ordinary pacing, sustained contested mixed-force play, novice/content acceptance and release gates still need work.

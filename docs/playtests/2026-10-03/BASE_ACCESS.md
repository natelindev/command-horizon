# AI base access — 2026-10-03

AI construction now keeps passages between static footprints wide enough for ground navigation. The innermost candidate ring grows from 6 to 7 metres, and sites must leave 2.4 metres between building/resource footprints: twice the 0.9 m navigation erosion plus a 0.3 m cell allowance on each side. The existing collision and navigable-footprint checks still apply. This changes AI siting; it does not relocate buildings already recorded in saves or change player placement rules.

## Reproduced cause

The earlier [548-second trace](crowd-empty-path-trace.log) had no save. Six additional same-seed Desert matches did not reproduce it. A [six-seed sweep, 4106–4111](base-access-before-matches.json) then found a 180-second empty-path worker stall (and a separate 25-second intact-path crowd stall). A focused seed-4110 run captured [the actual battle](skirmish-empty-path-battle.json), with the worker near the original trace location, at `(109.686, 0, 65.25195)`, again trying to reach electronics at `(108.5, 0, 51)`.

The [live diagnostic](base-access-live-capture.log) records active physics processing, navigation synchronization and 30 avoidance callbacks in the last half-second. A fresh server route ends roughly 15 cm away instead of reaching the resource. The agent has reached the edge of a tiny disconnected navigation island. This evidence rules out a frozen movement component in this recurrence.

An [isolated replay](base-access-isolated.log), with commanders disabled and other mobile units removed, remains within 1 cm of its initial position for 40 seconds. Removing the AA turret at `(107.7039, 0, 64.45673)` opens the route. Rebuilding through the old AI site selector chooses that same position and traps the engineer again. The [before regression](base-access-before.log) fails both route reachability and actual electronics delivery.

With the new selector, the replacement turret goes to `(106.1732, 0, 60.7612)`. The path stays connected, and the engineer delivers 4 E within 30 seconds. Its maximum sampled step is 0.053337 m at 60 Hz, within its 3.2 m/s speed bound. The test includes a real disk save/load halfway through: paused position, cargo and harvest order survive exactly. See the [regression log](base-access-regression.log).

The fixture deliberately replaces the closing turret to test the placement decision. Loading the original closed base does not automatically dismantle or move its buildings. The uncaptured earlier 548-second occurrence cannot be replayed exactly; the new captured recurrence establishes and fixes this construction failure class.

## Verification

- `BaseAccessRegression`: retained failing layout, the closing obstacle, corrected AI site selection, reachable resource, actual delivery, bounded movement and paused midpoint disk restoration.
- `FrontierAIRegression`: both factions build eight structures and launch four attacks within six simulated minutes, with actual harvesting/production.
- `IndustrialAIRegression` and `CoastalAIRegression`: both factions build, produce, launch attacks and damage the opposing HQ.
- `SkirmishSupportRegression` and `Skirmish`: repair support plus setup, four faction pairings, paid production/construction, anti-air, pause, results/restart and legacy-map AI economies.
- `CrowdBoundaryRegression`: the earlier saved intact-path failure still passes three replays; both factions deliver 24 M / 12 E through opposing traffic and a midpoint archive.
- `BaseAccessPreview`: normal-clock Metal rendering at 1280×720, the same archived/rebuilt layout and real midpoint save/load; 4 E delivered with the same movement bound.

[Closed layout](../../../art/skirmish/base-closed.png) · [New turret site and harvesting engineer](../../../art/skirmish/base-open.png). These are spatial diagnostics with full visibility and the main HUD hidden, not ordinary-fog or native-input acceptance.

## Complete-match follow-up

[All eight records](base-access-after-matches.json) use seed 4110, Normal AI and the same paid reference commander as the [earlier matrix](SKIRMISH_MATRIX.md). All reach an outcome. Maximum stationary travel is 6 seconds for the human side and 4 seconds for the AI; no 15-second capture is triggered. These are one run per combination, not evidence that every layout is free of navigation problems.

| Human faction | Map | Start | Result | Duration | Longest stationary travel, human / AI |
|---|---|---|---|---|---|
| Bastion | DesertFrontier | Standard | Victory | 7:50.7 | 2.5 / 1.5 s |
| Bastion | DesertFrontier | Advanced | Defeat | 8:07.5 | 1.5 / 1.5 s |
| Bastion | AlpineRelay | Standard | Victory | 8:13.2 | 1.5 / 1.5 s |
| Bastion | AlpineRelay | Advanced | Defeat | 7:49.3 | 1.5 / 3.0 s |
| Helix | DesertFrontier | Standard | Victory | 8:57.4 | 1.5 / 3.0 s |
| Helix | DesertFrontier | Advanced | Defeat | 5:59.9 | 2.0 / 4.0 s |
| Helix | AlpineRelay | Standard | Victory | 9:10.3 | 6.0 / 1.5 s |
| Helix | AlpineRelay | Advanced | Defeat | 6:02.5 | 3.5 / 1.5 s |

The four Standard victories and four Advanced defeats remain outcomes of a limited fixed policy. All eight matches end in about 6–9 minutes, below the intended 20–30-minute pacing. Broader strategy, contested expansion, novice testing and content acceptance remain open. Performance optimization stays deferred.

## Reproduction and evidence

[Source fingerprints](base-access-build.json). Run from the repository root with Godot 4.6:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script tests/headless/BaseAccessRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script tests/headless/BaseAccessMatches.gd -- --repeats=1 --output=res://tmp/base-access-matches.json
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/BaseAccessPreview.gd
```

Retained shared logs: [Desert](base-access-FrontierAIRegression.log), [Industrial](base-access-IndustrialAIRegression.log), [Coastal](base-access-CoastalAIRegression.log), [support](base-access-SkirmishSupportRegression.log), [skirmish lifecycle](base-access-Skirmish.log), [crowd/archive](base-access-CrowdBoundaryRegression.log), [rendered](base-access-rendered.log). Existing headless renderer/resource shutdown warnings remain; the checks report no gameplay script errors.

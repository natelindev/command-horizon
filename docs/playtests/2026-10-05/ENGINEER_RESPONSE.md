# Engineer raid response — completed 2026-10-06

The battle plan now changes its existing engineer shortcut to **Engineers at risk** when owned engineers face a visible, compatible threat nearby or have taken enemy weapon damage in the last six simulation seconds. It selects and focuses those engineers, including busy gatherers, builders and workers with queued orders. The main defender recommendation remains available. Selection preserves current orders; evacuation still requires the player's explicit Move command.

When danger clears, the shortcut returns to **Idle engineers**. Engineers with waiting manual orders are now excluded from that idle count. The button recomputes its targets when clicked, and its tooltip/accessibility description explains that selection keeps current orders.

## Evidence behind the change

The retained screened-air references lost 21 Frontier engineers against Helix and 17 Helix engineers against Frontier. Both lost the match and never purchased reference-side research. These observations motivate better raid-response controls; they do not establish a research-timer defect or a faction-stat imbalance. The original records and extracted casualty timelines are identified in [prior-raid-observations.json](engineer-response/prior-raid-observations.json).

The original panel's idle shortcut was disabled when all engineers were gathering, even beside an observed raider. The minimal all-faction fixture records nine expected assertions before the change—disabled shortcut, missing danger label and missing threatened-worker selection for each faction—and zero afterward. See [baseline](engineer-response/minimal-before.log), [passing result](engineer-response/minimal-after.log) and retained original sources/minimal test.

Expanded verification also exposed a separate classification defect: a paused engineer with a waiting Move could have no active action and therefore be counted as idle. The corrected-cargo [probe](engineer-response/fixture-probe.log) records six failing idle/fallback assertions across three factions. `SkirmishPlan.idle_workers` now excludes waiting manual orders.

## Implementation and boundaries

- [SkirmishTactics.gd](../../../source/match/SkirmishTactics.gd) filters living owned engineers using current observed contacts and the existing defense reach rule: a compatible weapon within its range plus the 8 m approach margin. Recent incoming damage identifies only the owned worker; it does not expose an unseen attacker's identity or location.
- [SkirmishPlan.gd](../../../source/match/SkirmishPlan.gd) exposes the endangered-worker selection and corrects queued-worker idle classification.
- [SkirmishPlanPanel.gd](../../../source/match/hud/SkirmishPlanPanel.gd) reuses the existing shortcut, preserving the panel's layout and ordinary selection flow.

“At risk” indicates nearby danger, not a guarantee of a clear enemy firing line or a safe retreat route. The player chooses the destination. Unit statistics, prices, harvesting, combat, AI policies and research timing are unchanged.

## Verification

[EngineerResponseRegression.gd](../../../tests/headless/EngineerResponseRegression.gd) passes Bastion, Helix and Frontier in [expanded-corrected.log](engineer-response/expanded-corrected.log), exit 0 with zero failures and zero script errors. It covers:

- Busy gatherer/builder selection, current defender guidance, selection-only authority, cargo and queued-order preservation.
- Click-time revalidation after a raider leaves, safe idle fallback, and exclusion of queued workers from idle selection.
- Hidden contacts despite stale visibility flags, actual incoming-hit context, expiry of old damage, harmless scouts, AA-only weapons and visible strike aircraft.
- Paused disk save/reload, selection after reload, arming/cancelling Move, explicitly replacing a waiting order, actual movement after resume and unchanged cargo/funds.

The first expanded fixture assigned 3 M + 2 E, exceeding the existing four-unit cargo capacity. Archive validation correctly rejected it. The corrected fixture uses 3 M + 1 E; no cargo or archive rules were changed. The first source/log and subsequent diagnostic probe are retained separately from the accepted result.

BattlePlanRegression, AirDefenseAdviceRegression, EconomySupplyRegression and DirectOrdersRegression also exit 0 with zero failures and zero script errors. Their logs remain in the evidence directory. Formatting, lint, whitespace, report links and [source/artifact hashes](engineer-response/engineer-response-evidence.json) are verified. Existing navigation-readback and headless renderer/ObjectDB cleanup diagnostics remain in those logs.

## Native input and visual review

[EngineerResponsePreview.gd](../../../tests/rendered/EngineerResponsePreview.gd) uses controlled Advanced-start raid fixtures at 1280×720 and 150% UI scale. Options are temporarily applied in memory and restored; autosaves are disabled. Native clicks select the endangered engineer for each faction, M opens a destination choice and Escape cancels without changing the gathering order or cargo.

- [Bastion selection](engineer-response/native-final-bastion-selected.png)
- [Helix selection](engineer-response/native-final-helix-selected.png)
- [Frontier selection](engineer-response/native-final-frontier-selected.png)
- [Explicit paused retreat order](engineer-response/native-final-frontier-retreat-queued.png)
- [Retreat after resume, with 3 M / 1 E retained](engineer-response/native-final-frontier-retreated.png)

For Frontier, a second M and a world click issue Move, then native Space resumes the match. The engineer travels toward the chosen destination and keeps its cargo. Other actors are frozen during that final movement interval, so this is input/movement verification, not a contested survival test. The final native process exits 0 with zero failures and zero script errors in [native-final.log](engineer-response/native-final.log).

The new shortcut fits inside the existing panel without overlapping the minimap or unit controls. The first native fixture teleported actors while paused without refreshing fog, leaving their world geometry obscured; that test-owned process was stopped, the fixture refresh was corrected, and the entire native flow was rerun. `native.log`, `native-bastion-raid.png` and the first preview source are not accepted final evidence.

Correction, 2026-10-06: the original review mistakenly described Helix construction names/prices as clipped. Full-resolution reinspection and an all-faction rendered geometry audit show those labels fit. No production layout change was needed. See [the roster layout audit](../2026-10-06/ROSTER_LAYOUT.md), which preserves the original report revision and the follow-up evidence. The earlier evidence manifest describes the original report revision.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/EngineerResponseRegression.gd

tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/EngineerResponsePreview.gd -- --captures=res://tmp/engineer-response/native
```

Use a fresh capture prefix in an existing directory. The native runner requires the indicated clicks/keys and has a five-minute wall deadline. This stage does not claim the earlier full-match defeats are resolved. Strategy, pacing, novice comprehension, final environments and platform acceptance remain open; performance stays deferred and the overall goal remains active.

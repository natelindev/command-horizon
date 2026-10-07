# Roster information and mixed-force readiness — 4 October 2026

Players can now inspect a unit's role before they can afford or unlock it. Production and construction cards retain the name, faction-specific description, total price and current blockers together. Missing materials/electronics are shown separately from the purchase price. The same text populates the engine's accessibility description.

The hover card separates its title, role and purchase facts, wraps to a bounded width and stays inside the game window at 1280×720 / 150%. Role text explains ground/air targeting, infantry/armor tradeoffs, Lancer switching, Prism deployment, scouting, repairs and service buildings. Helix buildings no longer claim to be a generic lighter, faster specialist.

Production time includes the selected basic chip and current power factor, and explicitly excludes existing queue wait. For example, a fitted tank takes 25 seconds at full power and displays 72 seconds at 35% power (rounded up from 71.43). Construction time describes one engineer after reaching the site. Research cost and time are stated at full power. Queue, population, structure, research and prerequisite limits continue to prevent unavailable purchases. Costs, unit statistics, combat rules and AI difficulty are unchanged.

## Original problem and verification

The [original focused regression](roster-info-before.log) records 31 failures: lost identity/role on locked cards, lost role on unaffordable cards, fourteen generic Helix descriptions, absent resource gaps/times and unclear queue-cap information. Its [exact fixture](roster-info-before-test.gd.txt) and original [catalog](roster-info-before-FactionCatalog.gd.txt) / [menu](roster-info-before-UnitMenus.gd.txt) are retained.

The final regression exercises both factions, real paid fitted production and refund, current low-power times, lab loss/conventional fallback, full queues, actual population/structure limits, and a paused disk round trip with a paid fitted job. Repeated inspection does not spend funds, advance the simulation or change engineer orders. The rendered workflow uses actual Godot window events to hover disabled cards, buy with Enter, cancel with the mouse and review both factions' five states.

[Eight final suites](roster-info-final-shared.json) pass: the focused roster check plus skirmish roster/production/AI, programs, economic recovery, supply, battle-plan selection, subtitle layout and campaign controls. [Final delivery checks](roster-info-delivery.json) also pass editor import, the rendered workflow, formatting, lint and whitespace. All ten final 720p captures were visually reviewed; the final hover run required no retries. The [final audit](roster-info-final-audit.json) records logs, captures and source hashes.

Initial fixture failures are retained separately: [preloading the faction catalog](roster-info-fixture-preload.log) before autoload setup broke the test launch; the [first low-power fixture](roster-info-fixture-power.log) still had enough HQ supply; a [broad node search](roster-info-fixture-queue.log) found the simulation queue instead of its UI. The [first corrected rendered run](roster-info-hover-initial.log) missed three hover popups. Explicitly leaving and re-entering the card, with a bounded retry and pointer/focus diagnostics, produced a passing run. These are not passing product evidence. Existing runtime navigation-bake and shutdown resource warnings remain.

## Mixed-force investigation

The previous authored-guard trials had eight ground combatants before contact, below the reference commander's nine-unit assault threshold. The new probe records paid production, unaffordable choices, and affordable choices withheld only by a pending aircraft budget. It preserves the original commands and game rules. A second policy delays air investment until its own deployed/queued ground count reaches nine; this is a controlled reference-policy variation, not a shipping balance change.

In the fresh Helix/Desert original trial, a 22 M / 14 E fitted tank was affordable but withheld for 83 half-second decision samples, from 78.23 to 119.23 seconds, while reserving 28 M / 24 E for a strike aircraft. The policy then bought one aircraft. Delaying air investment added a tank and reached nine ground units before contact, but the army still waited for an observed home attack and was subsequently defeated. The two outcomes were 4:27.0 and 4:32.0. The first important building loss was the lab in each trial; the records retain subsequent casualties and worker allocation.

The comparison demonstrates a real spending/readiness tradeoff. It does not establish that the aircraft reservation caused defeat, that a specific army composition is balanced, or that a one-unit threshold solves the strategy. Asynchronous navigation/combat still vary despite a shared seed. Sustained mixed-force play, ordinary pacing and the earlier uncaptured long loss remain open; no unit prices were tuned to make a reference commander win.

[Four complete Desert trials](mixed-readiness-matches.json) retain [terminal exits](mixed-readiness-exits.json). All use Advanced starts, Normal AI and seed 4110. Ground counts below are sampled at 2:00.7, before observed home pressure.

| Faction | Allocation policy | Ground combatants | Affordable tank withheld | Result | First assault |
| --- | --- | ---: | ---: | --- | --- |
| Bastion | Original aircraft reserve | 8 | 59.0 s across 118 samples | Defeat, 4:38.7 | None |
| Bastion | Ground count before air | 10 | 0 s | Defeat, 4:40.9 | None |
| Helix | Original aircraft reserve | 8 | 41.5 s across 83 samples | Defeat, 4:27.0 | None |
| Helix | Ground count before air | 9 | 0 s | Defeat, 4:32.0 | None |

The four trials record 2,197 AI coordination samples with no task/order violations and no stationary-travel episode above two seconds. No fifteen-second movement archive was triggered. The counterfactual reaches the numerical army gate in both factions, but the reference policy still waits for a home attack; it does not launch an operation before losses close the gate again. Better operation choice, defense coverage and resource allocation remain investigation work.

The [probe source](mixed-readiness-MixedReadinessMatches.gd.txt) extends the retained [authored guard wrapper](authored-guard-AuthoredGuardMatches.gd.txt) and its existing recovery/defense chain. Output includes full match results, production decisions, loss timelines, readiness, recovery, economy and coordination samples.

## Captures

| State | Bastion | Helix |
| --- | --- | --- |
| Unaffordable fitted armor | [Capture](../../../art/skirmish/roster-info-bastion-shortage.png) | [Capture](../../../art/skirmish/roster-info-helix-shortage.png) |
| Research-locked heavy unit | [Capture](../../../art/skirmish/roster-info-bastion-available.png) | [Capture](../../../art/skirmish/roster-info-helix-available.png) |
| Low-power production time | [Capture](../../../art/skirmish/roster-info-bastion-low-power.png) | [Capture](../../../art/skirmish/roster-info-helix-low-power.png) |
| Missing lab and research | [Capture](../../../art/skirmish/roster-info-bastion-missing-lab.png) | [Capture](../../../art/skirmish/roster-info-helix-missing-lab.png) |
| Construction purpose and time | [Capture](../../../art/skirmish/roster-info-bastion-construction.png) | [Capture](../../../art/skirmish/roster-info-helix-construction.png) |

## Reproduction and limits

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/RosterInfoRegression.gd
godot --path . --script tests/rendered/RosterInfoPreview.gd
godot --headless --path . --fixed-fps 60 --script tmp/MixedReadinessMatches.gd -- --case=5 --repeats=1 --output=res://tmp/mixed-original.json
godot --headless --path . --fixed-fps 60 --script tmp/MixedReadinessMatches.gd -- --case=5 --repeats=1 --ground-first --output=res://tmp/mixed-ground.json
```

The local engine is Godot 4.6. Temporary match wrappers are retained as text beside this report for reconstruction. Rendered tests use synthetic window events; physical-device, screen-reader, cross-platform and novice acceptance remain separate. Broader gameplay/content/mixing/release work remains active. Performance optimization stays deferred.

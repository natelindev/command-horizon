# First-contact defense audit — 2026-10-06

No defensive change is accepted as a general improvement. The retained Helix opening exposes weak conventional positioning and an unfavorable initial force, but three tested responses do not establish a reliable solution. Shipping unit statistics, service rules, map geometry, AI and player guidance are unchanged. New commander behaviors remain explicitly invoked test experiments; existing harness defaults retain their previous behavior.

## Earned fight

The source is `conventional-recovery/earned-6-case6-11-worker_withdrawal.json`, at 143.75 simulation seconds from the previous Helix→Frontier defeat. Helix has six full-health infantry and one full-health tank: 172 combined HP. The incoming Frontier force has six infantry and two tanks: 250 combined HP. Several defenders are behind the forward soldiers and outside legal firing range when those soldiers first take fire. This is not evidence that idle defense should pursue enemies automatically: conventional units intentionally require commander orders.

`EarnedOpeningProbe.gd` restores this exact archive and runs the existing reference defense loop every half second for 120 simulation seconds. It samples all mobile combatants once per second, including position, HP, action, movement, nearby observed enemies and legal firing opportunities. Strategic player processes are disabled; existing unit actions, navigation, production jobs, construction and service processing remain live. The defense loop starts with fresh reference-policy bookkeeping, rather than reconstructing its historical last-order time. Economy, production decisions, authored-program management and worker protection are not replayed. This is a controlled earned-state probe, not a replay of the complete paid match.

| Probe | Human combatants / HP at 30 s | Human combatants at 60 s | Enemy combatants at 60 s | Human firing-opportunity samples, first 30 s |
| --- | --- | ---: | ---: | ---: |
| Previous anchor and command behavior | 2 / 10.0 | 1 | 1 | 39 |
| Respond to nearby visible attackers | 2 / 24.4 | 0 | 2 | 65 |
| Hold beside completed Barracks | 3 / 27.7 | 0 | 4 | 28 |

The responsive experiment uses ordinary AttackMove to a currently observed compatible armed target within the existing home-defense threat set. It preserves available firing actions, throttles reorders, and excludes active programs and recovery actions. Its increased firing opportunities do not translate to surviving the wave. Moving the defensive anchor beside Barracks also fails. Neither is promoted to a default or shipping behavior. `HomeDefensePolicy.gd` exists only to reproduce the responsive experiment. Counts cover live combatants at each sample, not damage events, shots fired or continuous measurements. Navigation timing can vary across runs; these are observations, not deterministic balance comparisons.

## Paid two-tank opening

The previous commander begins its lab after one tank and stops pre-lab tank production at one. `ScreenedOpeningMatches.gd` instead targets two tanks before committing to the lab, then retains the existing screened-air production, combined research, engineer safety/reassignment and conventional recovery policies. Readiness latches after two tanks exist, so a later casualty does not revoke the lab decision. All units, buildings and research are paid through existing game APIs. No resources, health or units are granted.

Default-preserving hooks in `SkirmishLoop.gd` and `PaidProgressionMatches.gd` isolate this alternative from earlier reference runs. A separate default-false hook in `SkirmishDefensePolicy.gd` permits the earned responsive probe without changing the ordinary commander. The previous recovery regression still returns all four earned wounded infantry to the assault with zero failures.

All observations use Standard start, Normal shipping AI and Coastal Foundry:

| Reference → AI | Seed | Result / seconds | Two tanks ready | Basic unlock | Ground defense program | First assault | Collected M / E |
| --- | ---: | --- | ---: | ---: | ---: | ---: | --- |
| Frontier → Helix | 4110 | Victory / 450.0 | 104.7 | 158.2 | — | 256.2 | 497 / 137 |
| Frontier → Helix | 4111 | Defeat / 922.4 | 104.7 | 155.3 | 180.3 | — | 465 / 183 |
| Helix → Frontier | 4110 | Defeat / 353.8 | 105.7 | 151.7 | — | — | 304 / 80 |
| Helix → Frontier | 4111 | Defeat / 648.4 | 106.2 | 157.3 | 182.8 | — | 544 / 80 |

`first_program` measures the reference ground-defense setup, not every possible program. In particular, Frontier seed 4110 executes its programmed air raid at 356.2 s despite having no recorded ground-defense program. Do not interpret that empty metric as proof that no automation ran.

Both match processes exit zero, each with two completed records and zero unresolved checks. Across the four matches there are 462 conventional-treatment and 8147 engineer-authority checks, and 4750 AI coordination samples with no violations. The longest sampled stationary travel interval is four seconds; no fifteen-second stall archive triggers. One win and three losses is the same outcome count as the previous four observations, with materially different durations. It does not prove improvement or equivalence: the observations are few and asynchronous navigation prevents deterministic pairing.

## Native inspection

`DefensiveOpeningPreview.gd` restores the first-contact archive of the first match in each pairing, verifies frozen time/health/funds while paused, then accepts native Space input. The enemy AI and existing actors continue for 35 simulation seconds; the external reference commander is not reconstructed. Two of the original eight Helix defenders and four of the original eight Frontier defenders survive these separate continuations. These counts characterize the native continuations only, not the ongoing paid commander trials.

Four 1280×720 images at 150% interface scale show the initial healthy forces and the resulting casualties/damage. The program panel correctly shows conventional armor requiring an explicit chip retrofit after unlock. Native restoration/input checks pass with zero failures. The captions and logs retain this limitation rather than presenting the scenes as improved defenses.

## Evidence, reproduction and next decision

Evidence is in `defensive-opening/`: original/proposed trace JSON, four complete paid records, earned snapshots, native images/logs, before-source copies, `summary.json`, `validation.json` and `SHA256SUMS`. Accepted logs have no script/parse errors. Existing navigation-readback warnings and renderer/ObjectDB cleanup diagnostics remain; these are recorded separately from test assertions and match outcomes.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/EarnedOpeningProbe.gd -- --output=res://tmp/opening.json
# Alternative probes add --responsive or --service-line.
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/ScreenedOpeningMatches.gd -- --case=6 --repeats=2 --research=combined --strategy=screened-air --output=res://tmp/opening-matches.json --archive=res://tmp/opening-stall.json --archive-prefix=res://tmp/opening-earned
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/DefensiveOpeningPreview.gd -- --captures=res://tmp/opening-native
```

Case 2 is the reciprocal Frontier→Helix pairing. Use fresh output paths. The native harness reads the retained first-contact archives and requires two Space inputs.

The next useful test is explicit paid retrofit of surviving conventional armor after unlock, with observed-pressure decisions and preserved combat/recovery authority. The current reference commander relies largely on newly produced fitted units to activate its ground programs; simply buying more conventional armor does not exercise that transition reliably. This is a test-policy gap to investigate, not justification for automatic player retrofits, free chips, stronger faction stats or a promised winning strategy. Defensive strategy, wider match consistency and broader gameplay acceptance remain open. Performance optimization remains deferred.

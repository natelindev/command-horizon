# Protected AI expansion — 2026-10-04

The old commander immediately assigned an idle engineer to the nearest remaining resource node after home depletion. No military role was reserved for that new field. The [before-fix run](ai-expansion-before.log) reproduces both problems for Bastion and Helix: four failed expectations, with the worker departing and zero guards assigned.

## Behavior

The commander now evaluates deposits from a completed friendly HQ, avoiding currently observed enemies that can attack an engineer. It rejects threatened nodes and observed danger along the straight approach corridor. The corridor filter is conservative strategic screening; ordinary navigation still determines the actual route. It does not guarantee that every detour is safe, or reveal enemies behind fog.

A resource destination beyond the HQ's thirty-metre home area needs a healthy ground combat unit within ten metres before an idle engineer receives the harvest order. One expansion at a time receives up to two ground guards, chosen by proximity and requiring at least half health. Their staging point is five metres toward the HQ from the field, with small formation offsets. Active gathering assignments retain the guard through return trips. Immediate economic defense takes priority; remaining infantry can capture relays and remaining soldiers can launch the existing scheduled waves. Guards are excluded from those duties while allocated to the field. If no suitable guard is available, the remote assignment waits.

A harvesting engineer near a currently observed legal attacker withdraws toward its completed HQ when it is more than eight metres from that HQ and the HQ is outside the same danger margin. It retains carried material/electronics and delivers that cargo before receiving another field assignment. Pure cargo deliveries have no resource-field destination and cannot accidentally send guards to world origin. Builders retain their construction orders. Hidden attackers, unarmed scouts and air-only weapons do not trigger this ground-worker response.

The planning state is derived from owned units, their normal actions and current observation; no new save schema or persistent hidden enemy reference is added. Production prices, harvesting rates, six-worker target, existing worker-type allocation, wave intervals and combat stats are unchanged. This is protection for expansion and retreat, not adaptive resource allocation or an overall army-coordination solution.

## Actual behavior and archives

The [main regression](ai-expansion-regression.log) passes four real travel/harvest scenarios. Each removes the home electronics node, leaves the engineer waiting, sends guards through ordinary navigation, then permits harvesting only after a guard reaches the field. Exactly four electronics leave the finite deposit and reach the HQ. The engineer has no injected cargo in these expansion scenarios.

| AI faction | Map | Engineer admitted after | First delivery after |
| --- | --- | ---: | ---: |
| Bastion | Desert Frontier | 11.48 s | 45.93 s |
| Bastion | Alpine Relay | 9.98 s | 44.28 s |
| Helix | Desert Frontier | 9.98 s | 40.77 s |
| Helix | Alpine Relay | 8.48 s | 38.80 s |

These are simulated durations in an isolated Advanced-start fixture; opposing starting units are stationary. A midpoint real disk save/load preserves the waiting engineer, guard positions/orders and paused clock. After delivery, additional staged reserves allow a genuine scheduled attack wave while the field guard stays assigned. No travel speed or destination teleport is used to make the expansion pass.

Separate staged threat contracts verify hidden/revealed enemies, legal attack domains, endangered-node rejection, economic-defense precedence and critically damaged guard exclusion. A carrying engineer withdraws, survives a paused disk archive and delivers all three staged electronics after Resume (6.38 / 6.45 seconds in the headless run). The threat contract positions units to isolate the decision; its cargo is explicitly staged, not earned income. An initial fixture put the attacker seven metres from the engineer, beyond its five-metre sight range, so the supposed visible threat was correctly hidden. Moving the attacker to a nearby clear approach corrected the fixture; no observation rule was weakened.

The [actual raid extension](ai-expansion-raids.log) then attacks each established field with a live infantry raider using attack-move. The existing guard defeats the raider, all engineers survive, and a further four electronics are delivered from finite stock:

| AI faction / map | Raider defeated after | Further income after |
| --- | ---: | ---: |
| Bastion / Desert | 1.48 s | 32.92 s |
| Bastion / Alpine | 1.37 s | 60.88 s |
| Helix / Desert | 2.58 s | 39.07 s |
| Helix / Alpine | 1.50 s | 30.40 s |

This proves one small ground raid and continued harvesting in those fixtures. Large assaults, simultaneous contested expansions and air raids require the wider defense planner and remain broader strategy acceptance.

## Shared and rendered checks

All nine shared runs pass: [SkirmishDefenseRegression](ai-expansion-SkirmishDefenseRegression.log), [SkirmishCompositionRegression](ai-expansion-SkirmishCompositionRegression.log), [SkirmishSupportRegression](ai-expansion-SkirmishSupportRegression.log), [SkirmishOffenseRegression](ai-expansion-SkirmishOffenseRegression.log), [ResourceFieldRegression](ai-expansion-ResourceFieldRegression.log), [SaveRestoreEdges](ai-expansion-SaveRestoreEdges.log), [FrontierAIRegression](ai-expansion-FrontierAIRegression.log), [IndustrialAIRegression](ai-expansion-IndustrialAIRegression.log), [CoastalAIRegression](ai-expansion-CoastalAIRegression.log). These retain observed defense/counter-production, repaired support, archived offensive departures, harvesting boundaries, ordinary save restoration and three-map AI behavior. The [editor import](ai-expansion-editor.log), format and lint checks also pass. Successful logs have no script errors; existing runtime navigation-bake and shutdown shader/RID/ObjectDB warnings remain.

The [final rendered run](ai-expansion-rendered.log) passes the full four-case regression and both retreat archives at normal simulation speed, 1280×720 and 150% interface scale. A staged human scout reveals the actual field guard after its successful resource return; selection uses the existing API and no native-input claim is made. The review fixture applies normal gold/red team colors instead of its inherited blue/blue defaults. All four final images were inspected: [Bastion Desert](../../../art/skirmish/ai-expansion-bastion-DesertFrontier.png), [Bastion Alpine](../../../art/skirmish/ai-expansion-bastion-AlpineRelay.png), [Helix Desert](../../../art/skirmish/ai-expansion-helix-DesertFrontier.png), [Helix Alpine](../../../art/skirmish/ai-expansion-helix-AlpineRelay.png). Guards remain at the field; the scout staging does not change their orders or positions.

## Complete matches

All [eight complete records](ai-expansion-matches.json) use Normal difficulty, seed 4110 and unchanged Standard-ground / Advanced-mixed reference policies. All finish: five human wins and three losses (Standard 4/4 wins; Advanced mixed 1/4 wins).

| Human faction | Map | Policy/start | Result | Duration | Longest AI stationary travel |
| --- | --- | --- | --- | ---: | ---: |
| Bastion | DesertFrontier | Ground / Standard | [Victory](ai-expansion-ground-0.log) | 9:00.2 | 2.0 s |
| Bastion | DesertFrontier | Mixed / Advanced | [Victory](ai-expansion-mixed-1.log) | 13:55.8 | 1.5 s |
| Bastion | AlpineRelay | Ground / Standard | [Victory](ai-expansion-ground-2.log) | 7:37.0 | 1.5 s |
| Bastion | AlpineRelay | Mixed / Advanced | [Defeat](ai-expansion-mixed-3.log) | 8:24.6 | 3.5 s |
| Helix | DesertFrontier | Ground / Standard | [Victory](ai-expansion-ground-4.log) | 9:22.3 | 3.0 s |
| Helix | DesertFrontier | Mixed / Advanced | [Defeat](ai-expansion-mixed-5.log) | 4:51.3 | 2.0 s |
| Helix | AlpineRelay | Ground / Standard | [Victory](ai-expansion-ground-6.log) | 8:10.6 | 1.0 s |
| Helix | AlpineRelay | Mixed / Advanced | [Defeat](ai-expansion-mixed-7.log) | 8:44.7 | 1.5 s |

The longest sampled stationary-travel episode is 3.5 seconds for the AI and 5.5 seconds for the human policy; none reaches the fifteen-second diagnostic threshold. The mixed-force trials still vary by map/faction, and durations of 4:51.3–13:55.8 remain below the ordinary 20–30-minute pacing hypothesis. These are compatibility and strategy observations, not a controlled balance comparison: identical seeds do not eliminate asynchronous navigation/combat variation. The targeted fixtures establish the expansion behavior; these full-match records do not independently tag every guard allocation.

## Remaining work and reproduction

Adaptive worker ratios and reservations for competing armor/air production remain open. This planner protects one remote field and uses a thirty-metre home-area heuristic. It does not compute globally safe routes, guarantee a forward-HQ strategy or share one global task budget with defense/relays/offense. Larger raids, novice acceptance and the ordinary 20–30-minute pacing target remain unproven. Performance optimization stays deferred.

Run with Godot 4.6 from the repository root:

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishExpansionRegression.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishExpansionRaid.gd
godot --path . --rendering-method mobile --script tests/rendered/SkirmishExpansionPreview.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishMixedPolicy.gd -- --case=1 --repeats=1 --output=res://tmp/expansion-match.json
```

The tests restore autosave preferences; the rendered runner also restores the original display settings. Temporary disk archives use process-specific paths and are removed after restoration. [Source fingerprints](ai-expansion-build.json) identify the reviewed implementation and test/policy scripts.

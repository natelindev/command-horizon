# Observed-threat skirmish defense — 2026-10-04

The skirmish opponent now responds to observed armed threats near its engineers and buildings between scheduled attack waves. Previously, a visible tank approaching an engineer could receive no response until the next whole-army timer. The [original reproduction](ai-defense-before.log) fails for both factions: neither of the two available defenders receives an interception order, and the raider takes no damage.

## Commander behavior

The new planner reads current allied observation and owned assets. An enemy is a defense candidate only if its weapon can target a nearby owned engineer/building and it is within weapon range plus six metres. Smaller distance margins and recent fire on the threatened asset raise priority. Hidden contacts and unarmed scouts do not recall defenders.

Nearby threats of the same ground/air domain form a cluster within eight metres. Story, Standard and Veteran can plan responses to one, two and three supported clusters per decision. Each cluster requests two suitable responders per visible contact, capped at six. Candidates are ranked by travel time with a capped engagement-time estimate. A cluster with no eligible responder does not consume a coordination slot: the [additional failure reproduction](ai-defense-unsupported-before.log) shows why that matters when an unanswerable air raid precedes a ground raid.

Ground-only tanks are excluded from air defense. A Helix Lancer can prepare Interception while approaching a known air raid, using its normal two-second switch and firing lock. Existing matching movement orders and active attack-move shots are retained instead of being restarted every decision. New defense and scheduled assault orders use the shared manual-order path.

Defenders are excluded from relay assignment and the next offensive wave. Other troops can still capture relays or attack. Visible economy threats are excluded from offensive target selection, so the remaining army does not simply pile onto the same raid. Loss of observation leaves an issued order at its last observed point; unseen enemy movement supplies no new destination. Defense does not consume the scheduled wave timer or spend resources.

The plan is derived from observation on each existing AI decision tick. This adds a defense-group budget, not persistent strategic squads or a global group cap across defense, relays and attacks. Previously issued orders continue until completed or replaced. Strategic expansion, counter-building/production and broader difficulty coordination remain later work. HP, damage, prices, unit speeds, difficulty reaction delays and wave intervals are unchanged.

## Verification

The final [headless regression](ai-defense-regression.log) passes for both defending factions. It covers:

- Actual ground interception and damage between attack waves; unchanged defense orders retain their action object.
- Hidden raids, lost-contact movement, unarmed scouts and unchanged resources.
- Ground/air eligibility, Lancer mode preparation and actual air interception after restoration.
- Tactical pause and a real disk archive during movement and a partial weapon switch, preserving position, remaining switch time, order and scheduled-wave age.
- One/two/three supported response groups, distinct responder allocation, the six-responder planning cap and an unsupported high-priority raid leaving capacity for an answerable raid.
- Separate offensive orders and infantry relay duties while other troops defend the economy.

The staged raiders are held stationary to isolate response selection, movement and damage; these are mechanics checks, not contested-fight balance results. A wave-target assertion was corrected to accept the visible enemy barracks as a valid offensive objective, alongside the enemy starting base.

Shared [Desert AI economy](ai-defense-FrontierAIRegression.log), [Industrial economy/combat](ai-defense-IndustrialAIRegression.log), [Coastal economy/combat](ai-defense-CoastalAIRegression.log), [repair support](ai-defense-SkirmishSupportRegression.log), [weapon modes](ai-defense-WeaponModeRegression.log) and [save/load](ai-defense-SaveRestoreRegression.log) checks pass. The Desert run builds eight structures and launches four waves per faction, producing eight Bastion/eleven Helix units. Existing save/action formats are reused; no schema migration is needed.

Editor import, changed-file formatting/lint and whitespace checks pass. Existing navigation/rendering and shutdown-resource warnings remain. Retained successful runs contain no gameplay script errors.

## Complete-match evidence

The [initial cohort](ai-defense-initial-matches.json) completes seven victories and one defeat. It predates the final supported-slot correction. The [final cohort](ai-defense-final-matches.json), on the fingerprinted source, completes eight victories. Both use Normal AI and seed 4110. Standard uses the existing early-commitment reference commander; Advanced uses the retained Guard/repair/regroup policy.

| Human / map | Start | Initial cohort | Final cohort | Final AI attack waves | Final outer cargo return |
|---|---|---|---|---|---|
| Bastion / Desert | Standard | L · 7:25.5 | W · 9:40.8 | 5 | 6:36.7 |
| Bastion / Desert | Advanced | W · 7:37.7 | W · 6:27.4 | 3 | — |
| Bastion / Alpine | Standard | W · 8:20.1 | W · 9:14.6 | 5 | 6:41.7 |
| Bastion / Alpine | Advanced | W · 6:48.1 | W · 9:17.4 | 3 | 7:03.2 |
| Helix / Desert | Standard | W · 8:49.5 | W · 10:35.7 | 4 | 6:58.7 |
| Helix / Desert | Advanced | W · 6:43.7 | W · 5:45.5 | 2 | — |
| Helix / Alpine | Standard | W · 10:13.3 | W · 8:56.6 | 4 | 6:37.2 |
| Helix / Alpine | Advanced | W · 10:31.0 | W · 11:03.2 | 6 | 6:30.2 |

All sixteen matches reach an ordinary result. The final range is 5:45.5–11:03.2, still below the 20–30-minute pacing hypothesis. The initial cohort's longest stationary trip is 10.5 seconds; the final maxima are 4.5 seconds for the human side and 2.5 for AI. Neither cohort reaches the probe's 15-second diagnostic threshold.

The two samples vary despite the shared seed because crowd avoidance, asynchronous navigation and subsequent combat are not deterministic. The earlier defeat remains in the record; these outcomes do not establish faction balance, optimal AI play or novice success. The matrix commanders field ground combat forces, so complete mixed-air strategies remain unproven; air countering is verified in the retained scenarios above. Performance work stays deferred.

## Rendered review

The final [normal-clock Metal run](ai-defense-rendered.log) repeats both-faction scenarios at 1280×720 and 150% interface scale with ordinary fog. The selected human raider shows actual damage from the defending units; the Helix air response visibly uses the AA stance. It also repeats pause/archive and simultaneous-objective checks. Selection is driven by the game selection API, not physical-device input.

- [Helix ground response](../../../art/skirmish/ai-defense-helix-ground-response.png) · [Helix air interception](../../../art/skirmish/ai-defense-helix-air-response.png)
- [Bastion ground response](../../../art/skirmish/ai-defense-bastion-ground-response.png) · [Bastion air interception](../../../art/skirmish/ai-defense-bastion-air-response.png)

## Reproduction

[Source fingerprints](ai-defense-build.json). Run from the repository root with Godot 4.6:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script tests/headless/SkirmishDefenseRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/SkirmishDefensePreview.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script tests/headless/SkirmishDefensePolicy.gd -- --case=5 --repeats=1 --output=res://tmp/defense-advanced.json
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script tests/headless/BaseAccessMatches.gd -- --case=4 --repeats=1 --output=res://tmp/defense-standard.json
```

Cases 0/1 are Bastion/Desert, 2/3 Bastion/Alpine, 4/5 Helix/Desert, 6/7 Helix/Alpine; even IDs use Standard starts, odd IDs Advanced. Ordinary victories and defeats are both valid recorded outcomes.

# Skirmish gameplay loop — 2026-10-02

Development priority is now the playable economy → base → chip/program → army → assault → result loop. Further performance optimization is deferred under the user's explicit direction.

## Delivered

Ordinary skirmishes have a collapsible Battle plan panel, with context-sensitive next actions and own-unit selection shortcuts. Standard starts begin with gathering and an early infantry screen, then factory/lab construction, chip production, a built-in Guard program, reinforcement and an assault. Nine combat units is a soft recommendation, never a production/order gate. Advanced starts skip buildings already present. Missing HQ/workers, low power and unfinished construction produce recovery guidance. Manual override retains configured-program recognition. Campaign missions keep their authored objectives.

The buttons select engineers, the relevant producer, a chip unit, idle engineers or the army and move the camera. They do not spend resources or issue orders. Selecting through the guide cancels an unfinished placement/assignment UI. The guide hides while choosing a map assignment/attack destination, stays usable while tactically paused, and uses current own-state after loading without adding authoritative save fields.

Repeated opening playthroughs exposed a collection bug: passive crowd movement paused a worker's harvest timer, potentially indefinitely while still in range. Harvesting now continues while contact is valid; leaving range stops it. Tactical pause still freezes collection. Old archives with a crowd-paused collection timer resume under the corrected rule after the player resumes the battle. Rates, capacity, costs and resource amounts are unchanged.

## Actual playthrough

Both factions used Standard starts on Desert Frontier against the opposing faction's live Easy AI. The test commander used ordinary harvesting, validated paid building placement, production queues, fitted chips, a shipped Guard preset and direct attack-move orders. No resources/units were injected, no HP/damage multipliers were changed, and enemy construction/production/attacks remained enabled.

The reference opening spreads gatherers among material piles, adds engineers, builds barracks/factory/lab, protects the resource approach with infantry, then gathers a tank-supported force. Earlier passive/congested openings lost; the guide reflects the need for protection and continued income. These are viable scripted examples, not proof of novice pacing or a winning strategy against every opponent.

| Latest complete run | Bastion | Helix |
| --- | --- | --- |
| Result | Victory | Victory |
| Match duration | 8:36 | 8:40 |
| Lab completed | 2:34 | 2:30 |
| First fitted tank / program | about 3:00 | about 2:56 |
| First full assault | 6:00 | 6:20 |
| Harvested M / E | 472 / 108 | 544 / 132 |
| Enemy attack waves | 2 | 1 |
| Surviving combat units | 9 | 11 |

[Playthrough events](skirmish-loop.json) preserve initial unsuccessful attempts and later outcomes. Headless fixed-step playback is used to exercise rules, not to measure frame rate. The lifecycle test requires paid progression, programming, direct-order takeover, enemy pressure and a valid result; it does not require an unbeatable test commander.

## Verification

- `HarvestContinuity.gd` reproduces the old crowd-pause failure, then passes range, cargo, tactical-pause and legacy paused-timer restoration checks.
- `SkirmishLoop.gd` plays both factions from Standard start through actual outcomes.
- `SkirmishLoopPreview.gd` passes native 720p engineer/army selection, world harvesting input, keyboard collapse, pause, chip selection, real Guard area/safe-point/Apply controls and manual override. Both faction layouts were reviewed.
- Shared navigation/harvesting and both-faction save restoration suites pass. Changed scripts pass format/lint and whitespace checks. Existing navigation-bake and shutdown-only resource warnings remain.

Review: [Bastion opening](../../../art/skirmish/loop-bastion-economy-720p.png), [Helix programs](../../../art/skirmish/loop-helix-programs-720p.png), [program running and reinforcement](../../../art/skirmish/loop-bastion-reinforce-720p.png).

Follow-up: the specified resource-field assignment/work-slot/depletion behavior is now implemented; see [Resource fields](RESOURCE_FIELDS.md) for updated full-match outcomes. Next gameplay work is economic recovery/expansion guidance and the missing conventional campaign opening. Remaining balance, novice testing, campaign/faction breadth and release performance gates stay open.

# Air Corridor — 2026-10-03

Operation 04 is playable from **Campaign → Air Corridor**. Clear two anti-air batteries with ground troops, position an escort beyond the quarry, and launch evacuation flights individually. Two safe flights permit completion; saving the third records optional support for operation 05. Performance optimization remains deferred.

## Delivered loop

The 144×104 industrial quarry has a continuous spoil wall, solid freight containers and two ground bypasses. Aircraft cross the center directly. The starting Bastion base supports harvesting, construction, production, shipped programs and aircraft service. Its army includes chipped tanks, infantry, walkers, repair robots, strike aircraft and a scout. The unarmed Rescue VTOL has 150 HP and no programming or production role; normal Stop, movement and queued orders remain available. **Continue flight** explicitly restores its exit order after a diversion or repair stop.

Both batteries must be destroyed before launch. Only one flight can be airborne, and launch requires a free population slot, including paid reservations. Arrival within five metres of the exit extracts the craft. Two losses defeat the mission. Losing the HQ starts the shared 60-second rebuild deadline. No script automatically launches a replacement or the next flight.

| Difficulty | Infantry per battery | Tanks per battery | Lancers per response | Aircraft per response |
| --- | --- | --- | --- | --- |
| Story | 2 | 1 | 1 | 1 |
| Standard | 3 | 1 | 2 | 1 |
| Veteran | 4 | 1 | 3 | 2 |

Each launch warns one finite response ten seconds ahead. Ground Lancers use Interception and approach from the southeast; Wraith aircraft enter from the northeast. A live player unit within twelve metres of an entry denies that wing permanently. Initial defenses also include one finite Wraith patrol unless Split Signal's network badge was earned. Ground troops counter the Lancers; walkers protect against aircraft. The current map dressing and four-nacelle VTOL are procedural prototypes, not final environment or Blender vehicle art.

## Campaign and archives

Operations 01–04 are directly selectable. Completion schema 4 preserves schemas 1–3 and their badges. Saving all three flights records a fixed +20-electronics reward for Broken Foundry; Broken Foundry now consumes that reward, and its regression verifies the 100-electronics fresh start. See [Broken Foundry](BROKEN_FOUNDRY.md).

Gameplay-v5 snapshots retain both battery references, three flight records, response timers/resolution and the HQ recovery countdown. Active flights restore paused with their existing orders. Validation rejects duplicate active craft, invalid timers, incompatible roles/owners, premature launches and already-finished states. Initial patrol orders use the ordinary unit-order archive. Start, battery-clearance, launch and extraction checkpoints use the shared rotating campaign saves.

## Verification

- `AirCorridorRegression.gd`: different ground/air path lengths and actual traversal; battery launch gates; paused launch/movement; real JSON write/read/restore with identical mission state; resumed response timing and no replay; hangar healing; rejection of ground-robot aircraft repair; one-loss tolerance/two-loss defeat; occupied response-entry denial; population limit; HQ deadline; Story/Veteran defender and response budgets; legacy completion migration and fresh-game network reward.
- The same suite completes Standard through ordinary movement, attack-move, combat and extraction, using shipped strike-return and service-area presets. That playthrough does not edit enemy HP, remove enemies or force victory. Final fixed-step result: both batteries cleared at **37.75 / 53.75 seconds**, all three flights safe, victory at **219.03 simulated seconds**.
- `AirCorridorPlaythrough.gd` repeats that commander with native Metal rendering at 1280×720 and normal simulation time. Batteries clear at **42.80 / 58.35 seconds**; all three flights escape at **133.38 / 178.38 / 223.15 seconds**. Result: **zero failures**. These are simulation durations, not wall-time or performance measurements.
- A separate unescorted exposure fixture removes the static batteries and keeps the player's mobile force away from the route. Its flight extracts with a recorded minimum **38/150 HP**. This verifies actual enemy air pressure, but does not establish that an escort is mandatory or that difficulty is balanced.
- `AirCorridorPreview.gd`: native 720p mouse/Space entry and briefing; initial automatic checkpoint; independent ground/air selection; paused launch; manual archive/dialog/load; Resume with actual movement; transport selection without programming/coordination controls; Stop and Continue; two-flight Finish choice; replay and Campaign return. Final result: **zero failures**. The UI result fixture moves flights to the exit and clears batteries directly; combat victory is established separately above. The overview reveals fog only for layout review.
- Shared First Orders, Split Signal, Supply Line and both-faction archive-edge regressions pass. Supply Line's rendered controls also pass after adapting shared campaign selection and HUD layout.
- Editor import and whitespace checks pass. A final formatter/linter pass could not run: `gdtoolkit` is not installed or cached, and the package download failed because the configured network tunnel refused the connection. Existing runtime navigation-bake warnings and shutdown resource/RID leak diagnostics remain; this is not a warning-free runtime or release-performance acceptance claim.

An earlier rules run failed a stale expectation that the network reward adds electronics. The implemented reward removes the initial patrol, consistent with Split Signal's design. The final regression checks the absent patrol and unchanged 80 starting electronics, and passes. No extra starting resources were added to satisfy the old assertion.

Reviewed screens: [briefing](../../../art/skirmish/air-corridor-briefing-720p.png), [flight controls](../../../art/skirmish/air-corridor-flight-720p.png), [live escort](../../../art/skirmish/air-corridor-live-escort-720p.png), [archive](../../../art/skirmish/air-corridor-archive-720p.png), [overview](../../../art/skirmish/air-corridor-overview-720p.png), [live result](../../../art/skirmish/air-corridor-live-result-720p.png).

## Remaining acceptance

The practiced commander finishes in about four minutes. Novice pacing, route readability under fog, complete Story/Veteran playthroughs, final art/audio and broader balance remain open. Bastion's mobile AA lesson is available; a player-controlled Helix mode-choice lesson is not part of this mission. Operations 05–06, the third faction, remaining maps and release acceptance remain unfinished.

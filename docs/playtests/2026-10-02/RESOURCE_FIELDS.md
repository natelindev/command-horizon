# Resource-field economy — 2026-10-02

This stage completes bounded resource assignment, two-slot gathering and player-visible recovery states. Performance optimization remains deferred. The user removed the former weekly Codex 10%-remaining stop condition during this work.

## Implemented behavior

- A resource order fixes both type and origin. Eligible replacements are positive, same-type deposits within 10 metres of the originally clicked node. The boundary never follows a replacement node or the HQ. Authored separate field IDs are not required by this implementation.
- Every deposit has two reservations across all players while workers approach or collect. Returning, cancellation and death release reservations. Extra workers wait where they are and retry every 0.5 simulation seconds. Ordinary approach navigation handles contact positions; dedicated docking pads are not implemented.
- A new resource order returns existing cargo before starting the new assignment. Exhaustion returns even a single remaining resource, then waits for another field. A final resource cannot be collected twice when two timers fire together.
- Loss of the HQ during a return stops the trip and preserves cargo. Another completed friendly HQ requires an explicit order. Delivery advances queued orders; terminal waits also yield to orders queued later. Tactical pause freezes gathering and reservation retries.
- Engineer selection shows cargo and approach/collect/return/slot/depletion/HQ status. Group selection shows gathering, waiting and other engineer counts. Depleted and missing-HQ workers appear in Idle engineers, and emit a terminal notice. AI commanders explicitly reassign their own terminal workers.
- Snapshot version 5 records type, fixed origin, wait reason and retry time. Waiting actions need no live target or child. Active actions reconstruct reservations. Versions 1–4 infer an assignment only from a surviving resource reference; a return without one requests assignment after delivery. Invalid kinds, wait states and mismatched resource types are rejected.

## Verification

`ResourceFieldRegression.gd` passes for both factions: three workers/two slots, actual collection, pause, cancellation/death release, fixed field/type and local replacement, prevention of radius chaining, last-resource accounting, partial-cargo delivery, new-type orders with old cargo, missing-HQ recovery, Shift handoffs, v5 active/targetless archive reconstruction, v4 migration and malformed-state rejection. Fixtures use real navigation/collection/return actions, controlled resource quantities and actual scene reconstruction.

`ResourceFieldPreview.gd` passes native 1280×720 checks for both factions: group and individual status, depletion feedback, panel bounds, Idle-engineer selection and actual world right-click reassignment. Reviewed screenshots: [Bastion depleted field](../../../art/skirmish/fields-bastion-depleted-720p.png), [Helix group economy](../../../art/skirmish/fields-helix-group-720p.png), [Bastion slot wait](../../../art/skirmish/fields-bastion-wait-720p.png).

Relevant shared checks pass: HarvestContinuity, OrdersRegression, NavigationRegression, SaveRestoreEdges, WeaponModeRegression, PreparationRegression and SignatureRegression. The missing-resource archive fixture now removes the actual reserved deposit, which can differ from the clicked field anchor. Editor import, changed-script format/lint and whitespace checks pass. Existing navigation-bake and shutdown-only RID/resource warnings remain; this work does not resolve those warnings.

## Paid Standard-start matches

Both factions ran Desert Frontier against the opposing live Easy AI. The scripted commander pays for every building/unit/chip and uses ordinary construction, production, Guard and attack-move controls. No injected resources, units or stat changes are used. Fixed-step playback checks game rules, not frame delivery.

The initial reference defense covered the approach but left gatherers exposed: Bastion lost at 10:23 before launching its assault; Helix won at 7:59. The updated commander explicitly handles terminal engineer assignments and stations its infantry/Guard at the resource field. No production balance or AI handicap was changed to obtain the subsequent result.

| Updated field defense | Bastion | Helix |
| --- | --- | --- |
| Result | Victory | Victory |
| Duration | 15:46 | 9:26 |
| Lab completed | 2:49 | 2:45 |
| First fitted tank / program | 3:31 | 3:11 |
| First full assault | 13:05 | 6:35 |
| Harvested materials / electronics | 691 / 152 | 477 / 164 |
| Enemy attack waves | 2 | 3 |
| Surviving combat units | 14 | 7 |

[Events from both attempts](resource-field-matches.json) retain the failed opening and the later successful runs. These are scripted examples, not novice acceptance or an assertion of equal faction pacing. The lifecycle test requires paid progression, programming, manual takeover, live enemy pressure and a valid outcome.

## Remaining gameplay work

Improve full-match economic recovery and expansion guidance, playtest faction pacing with human players, and implement the missing conventional campaign opening. Field placement/contact readability and dedicated docking positions can receive further polish after the underlying loop; broader content, audio and release performance remain open.

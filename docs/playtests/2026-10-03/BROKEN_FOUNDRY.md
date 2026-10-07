# Broken Foundry — 2026-10-03

Operation 05 is playable from **Campaign → Broken Foundry**. Destroy two production nodes, capture the foundry with infantry, and secure it for 30 cumulative uncontested seconds. The operation exercises urban sightlines, protected repair support, finite production and bounded pursuit. Performance optimization remains deferred.

## Delivered loop

The 160×116 industrial district has north, central and south streets separated by opaque warehouse blocks. Furnace blocks frame an accessible control yard. These structures block ground navigation and line of sight/fire; the existing public-objective camera locators and minimap markers identify both production yards and the foundry. The environment uses procedural prototype geometry and the established faction models.

The Bastion force starts with an HQ, barracks, vehicle factory, lab, depot, three generators, two engineers, a scout, six chipped tanks, two railgun tanks, two repair robots and twelve infantry. Its base supports paid replacements, harvesting, building and ordinary program authoring. Starting funds are 160 materials and 80 electronics; the Air Corridor all-flight reward adds 20 electronics once when starting a fresh mission. Programs and direct orders remain explicit player choices.

| Difficulty | Infantry per production node | Infantry at foundry | Chipped skimmers per batch | Final response |
| --- | --- | --- | --- | --- |
| Story | 3 | 4 | 1 | 3 units |
| Standard | 4 | 6 | 2 | 5 units |
| Veteran | 5 | 8 | 3 | 7 units |

Each node also has one skimmer and one Mender. Two Prism artillery units and a repair depot defend the foundry. Their weapons, preparation, visibility and repair rules use the normal combat systems. Local Guard and Fire support assignments bound enemy pursuit; the Prism positions and firing sectors cover valid infantry positions beside the control mast.

Crossing the district's west threshold starts the alarm. Ten seconds later each surviving node queues its first batch; the next two batches start at 45-second intervals. Jobs pay the ordinary Helix cost, chip surcharge and production duration from a finite 600-material/300-electronics budget. There are no harvesters or resource refills. Destroying a node removes its pending jobs and future batches; completed units remain. Each node has at most three batches.

Both nodes must be disabled before capture can progress. One or more infantry within three metres capture in ten seconds, without a stacking speed bonus. Enemy ground combatants contest. After capture, friendly infantry must remain for 30 cumulative uncontested seconds; ownership alone does not advance this timer. Leaving, contest or recapture pauses secured time without erasing it. Disabling both nodes also announces one east response ten seconds ahead; a live friendly unit within twelve metres of its entry denies it permanently. A lost HQ must be rebuilt within 60 seconds. Victory requires foundry control, not elimination of every enemy.

## Campaign and archives

Five operations are directly selectable. Shorter selector labels retain a single row at 720p, including every existing briefing. Campaign-progress schema 5 reads schemas 1–4 and preserves their completion and badges. Foundry completion records the alternate-approach flag for Command Horizon. The finale and its alternate route remain unimplemented.

Gameplay-v5 archives preserve node references, disabled states, batch counts/countdowns, district alarm, control ownership/candidate/progress/contest, secured time, final response and HQ recovery. Ordinary production serialization retains exact paid jobs, remaining time and fitted chips. Restored factory output receives the same Guard assignment. Start, disabled-node and friendly control-capture checkpoints use the shared rotating archive.

## Verification

- `BrokenFoundryRegression.gd`: real warehouse bypass traversal and obstructed/open sightlines; actual artillery damage to a valid control-yard position with other enemy shooters disabled; Guard engagement and bounded return; actual mobile repair with non-stacking channels; alarm and paid production; factory destruction before completion; all six Standard skimmers from the surviving node; no output beyond three batches; fitted chips and active Guard programs on restored output.
- Archive cases include a real file write/read/restore with partially elapsed paid queues, exact resaved production and mission state, pause, destruction after loading, partially elapsed capture, retained secured time and resolved-response continuity. Malformed duplicate nodes, excessive budgets and capture before production shutdown are rejected. Additional cases cover capture gating, ground contest, empty owned-yard suspension, denied/repeated final responses, HQ defeat, Story/Veteran production/response budgets, schema-1–4 completion migration and actual fresh-game Air Corridor funds.
- The Standard commander uses ordinary movement/attack-move and shipped Service area presets, reserves two infantry, then buys four replacement infantry for 24 materials before capture. It does not edit enemy HP, delete enemies, add funds or force the objective in that playthrough. The final full suite, including owned-control archive restoration, disables nodes at **30.75 / 76.75 simulated seconds** and wins at **161.40 seconds**, with 14 mobile units surviving. Result: **zero failures**. The preceding combat-coverage run also wins at 158.40 seconds.
- `BrokenFoundryPlaythrough.gd`: native Metal rendering at 1280×720 with normal simulation time. The same paid commander disables nodes at **30.73 / 72.78 seconds** and wins at **157.48 seconds**, with 13 mobile units surviving. Both Prism defenders are destroyed in this run. Result: **zero failures**. These are simulation durations, not frame-rate or wall-time performance measurements.
- `BrokenFoundryPreview.gd`: native mouse/Space selection of all five briefings, start, automatic checkpoint, independent infantry/repair selection, objective locator, actual paid production, tactical pause, manual archive/dialog/load, unchanged production timer followed by Resume, result, replay and Campaign return. It verifies objective/minimap separation with a two-line production notice. Final result: **zero failures**. The result fixture moves enemy troops away and assigns almost-complete capture state; it checks result controls, while the separate commander establishes real combat victory. The overview reveals fog only for layout review.
- Shared Air Corridor, First Orders and both-faction archive-edge regressions pass. Final Godot editor import and whitespace checks pass. The formatter/linter tool is unavailable locally, and its package download fails because the configured network tunnel refuses the connection. Existing navigation-bake and shutdown resource/RID diagnostics remain.

Review corrected two gameplay/UI issues: the initial two-row mission selector clipped a longer briefing at 720p, and the artillery's original default sector did not cover the capture yard. The selector now uses short labels in one row; the artillery has a wider bounded sector and closer defensive positions. A dedicated real-shot regression covers the latter. An early production test also assumed chipless timing; it now allows the ordinary fitted-chip duration before counting completed jobs.

An earlier all-army rush stalled after disabling both nodes, still unfinished at 308.75 seconds with 11 mobile survivors. Other rush runs won, so this was not treated as proof of a navigation defect or a reason to weaken defenders. The retained commander instead protects capturers with a reserve and paid replacements. Its successful route is evidence of playability, not novice or all-difficulty balance.

Reviewed screens: [briefing](../../../art/skirmish/foundry-briefing-720p.png), [support controls](../../../art/skirmish/foundry-support-720p.png), [node combat](../../../art/skirmish/foundry-node-1-720p.png), [archive](../../../art/skirmish/foundry-archive-720p.png), [overview](../../../art/skirmish/foundry-overview-720p.png), [live victory](../../../art/skirmish/foundry-live-result-720p.png).

## Remaining acceptance

The practiced route takes under three minutes. Human onboarding, novice pacing, full Story/Veteran combat runs, final industrial art/audio and wider balance remain open. Command Horizon, the third skirmish faction, remaining map contracts and release acceptance are still unfinished. The finale reward is stored, but its route cannot be exercised until that operation exists.

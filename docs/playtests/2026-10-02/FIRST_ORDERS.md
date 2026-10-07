# First Orders campaign slice

Verified 2026-10-02 with Godot 4.6 on macOS arm64. The first playable operation is available through **CAMPAIGN → Start First Orders**. This is operation 2 of the planned six-operation campaign; operation 1 and operations 3–6 remain in development. Full game-state save/load and optional LLM drafting are subsequent stages.

## Delivered behavior

- A dedicated 80 × 64 training map, Bastion force against Helix relay guards, initial economy, lab construction, program assignment and relay defense. Find engineer/repair robot/infantry selects a real unit; normal build/program controls perform the actions. Tactical pause and direct orders retain authority.
- Built-in Service area on the starting repair robot satisfies the lesson. No source editing, native Lua interpreter or provider request occurs on this path. Conventional tanks can alternatively fit a chip and run a retreat-capable area program. The learning phases have no timed reinforcement attacks.
- Infantry capture within 3 m over ten simulation seconds; numbers do not accelerate capture. Enemy ground combatants contest. Workers and aircraft do not capture or contest. Ownership persists and grants 9 m local sight subject to obstruction; recapture removes that sight. A public map/screen marker discloses the objective location without revealing enemy contacts. Relay scenery has a navigation footprint and is excluded from unit contact snapshots.
- Sixty uncontested seconds of player ownership wins. Contest pauses that timer; enemy recapture resets it. Three objective-directed responses use fixed 3/4/5-unit Story/Standard/Veteran budgets, with unchanged health and damage. Warnings precede scheduled arrivals by ten seconds. A player presence within 12 m of the eastern entry defers arrival until clear. The maximum authored enemy budget is 17 units including the two guards, below the 100-unit cap.
- Losing HQ starts a 60-second completed-rebuild window; losing HQ and all mobile forces is immediate defeat. Results pause simulation and stop reinforcement progression. Replay recreates the mission, and Campaign returns to the briefing without leaving the tree paused.
- Saving, loading and applying a changed preset retreat threshold earns an optional cosmetic badge. Exact loaded preset identity survives Apply; changing parameters clears the saved identity. Victory and badge flags persist in a validated 4 KiB maximum JSON file via flushed temporary write/rename. Replay does not erase earned badges, and corrupt files are retained. This file does not contain the running battle.

## Verification

| Check | Evidence |
| --- | --- |
| Full preset-only victory | `CampaignRegression.gd` pays for a lab, has an engineer actually construct it, assigns the shipped repair preset and orders infantry/tanks to the relay. Standard completes with all three response waves exercised. The finished clock and arrivals remain frozen. |
| Objective boundaries | Two infantry do not accelerate capture; enemy armor contests; pause freezes capture; local relay sight works within range and fails outside it; relay is excluded from weapon/Lua contacts; enemy infantry recaptures; workers/aircraft cannot capture; contest pauses mission hold and recapture resets it. |
| Response/defeat/progress | Warning precedes arrival; a defended entry blocks spawning. Incomplete HQ does not reset the timer, completed replacement does, and another HQ loss eventually defeats. Pause freezes the grace window. Completion/badge replay and corrupt-file preservation pass. |
| Real UI flow | `CampaignPreview.gd` uses viewport clicks for menu/loading, engineer selection, actual lab placement, program assignment/Apply, version saving, result replay and Campaign return. Parameter selection and saved-version loading also exercise the panel API. No automatic gameplay completion is claimed by this UI test: its result screens use explicit victory/defeat fixtures, while the headless run covers real victory. |
| 720p presentation | Briefing, lesson/program controls, minimap, public fog marker and both result screens inspected. Lesson does not overlap selection/program UI or minimap. Screenshots linked below. |
| Shared regressions | Existing `ProgramRegression.gd`, `CombatRegression.gd`, `LuaProgramRegression.gd` and `Skirmish.gd` pass, including all four faction matchups and both AI economies. `ProgramPreview.gd` passes saved-record identity and edit invalidation, assignment/manual authority and 720p/900p layouts. `SkirmishPreview.gd` passes ordinary setup, production/construction, paused attack move, results and return in an isolated run. |
| Static checks | Changed GDScript format/lint, Godot editor import and `git diff --check` pass. |

Verification exposed two UI issues and one library issue: the initial lesson panel overlapped the right-side unit controls, the public objective was visually lost under fog, and applying a loaded preset discarded its version record. They are corrected and covered. Initial harness corrections allowed worker travel in addition to the 40-second lab construction duration, used a clear sight line for the positive vision test, and clicked the actual assignment button/site rather than an overlapping menu.

The first concurrent rendered skirmish run stopped progressing after its result screenshot without reporting a script error. A live process sample and native window inspection did not establish the cause. The owned test process was stopped, a stage-reporting 120-simulation-second watchdog was added, and an isolated rerun passed. This is a recorded harness/runtime limitation, not a claimed gameplay fix.

Final passing runs have no failed assertions or GDScript errors. Existing navigation mesh GPU-readback warnings and shutdown-only shader/RID/ObjectDB/resource warnings remain in some Godot runs. There was no new 200-unit performance measurement, export validation or novice usability session. Story/Veteran budgets are implemented, but the complete combat playthrough uses Standard. The compact training map does not establish the campaign's 15–35 minute pacing or strategic-map acceptance gates.

## Review images

- [Briefing](../../../art/skirmish/campaign-briefing-720p.png)
- [Initial objective and economy HUD](../../../art/skirmish/first-orders-start-720p.png)
- [Preset/version lesson beside unit controls](../../../art/skirmish/first-orders-program-720p.png)
- [Public relay marker under fog](../../../art/skirmish/first-orders-relay-720p.png)
- [Victory UI fixture](../../../art/skirmish/first-orders-victory-720p.png)
- [Defeat UI fixture](../../../art/skirmish/first-orders-defeat-720p.png)

## Next stage

Implement full game-state save/load with embedded program versions, stable entity references, remaining simulation durations, production/research, manual orders and campaign objectives. Continue the broader faction/map, LLM and performance roadmap. Latest weekly quota check: 63% used / 37% remaining; stop threshold remains 10% remaining.

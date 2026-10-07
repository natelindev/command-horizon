# Supply Line — 2026-10-02

Operation 01 is now playable from **Campaign → Supply Line**. This stage fills the conventional-control opening before First Orders introduces programmable units. Performance optimization remains deferred.

## Delivered loop

Scout and clear a checkpoint with the escort, advance the trucks, defend the stop, repair, then explicitly order the next leg. Three trucks cross South crossing, Ridge depot and Extraction; each needs 12 cumulative stationary, uncontested seconds at each checkpoint. Leaving its seven-metre area resets clearance. Enemy ground units within ten metres pause clearance. Two extracted trucks win; two losses defeat the mission.

The fixed starting force has three unarmed 180-HP trucks, four tanks, twelve infantry and two repair robots. Trucks use existing mechanical repair rules, with no harvesting, building or chip capability. Advance/Hold affects trucks only; Select trucks/escorts and ordinary right-click/Shift orders preserve direct control. Route buttons focus public checkpoints. The HUD shows health, next checkpoint, clearance and active field-force count. Arrived trucks with a remaining movement order show **Hold to clear**, because entry alone does not make the truck stationary; it omits irrelevant economy and locked programming/coordination panels.

The 192×128 corridor has three connected road legs, checkpoint pads and four navigation/sight-blocking outcrops. The current truck is a procedural six-wheel armored vehicle. Map dressing and vehicle geometry are gameplay prototypes, not final Blender art.

| Difficulty | Initial infantry per checkpoint | Tanks at checkpoints 2 and 3 | Infantry per response |
| --- | --- | --- | --- |
| Story | 3 | 1 each | 2 |
| Standard | 4 | 1 each | 3 |
| Veteran | 5 | 1 each | 4 |

Each checkpoint announces one response ten seconds after first truck arrival. A player unit within twelve metres of the entry permanently denies it; otherwise the finite response attacks that checkpoint. There is no continuing enemy income or replacement army.

## Campaign and archives

Operations 01–03 remain directly selectable. Completion grants a fixed +20 starting materials to fresh First Orders games (100 instead of 80), without stacking on replay or modifying loaded battle funds. Completion schema 3 reads schemas 1–3 and preserves existing badges.

Gameplay snapshot version 5 now recognizes Supply Line and mission-only human trucks. It preserves all three truck references, legs, partial clearance, extraction/loss, response countdowns and resolved flags. Duplicate/untracked truck references, incompatible owners/roles, invalid timers and already-finished convoy states are rejected. The normal archive and rotating start/checkpoint saves are available; loaded games remain paused.

## Verification

- `SupplyLineRegression.gd`: real manual repair order and HP recovery; paused movement/clock; actual JSON archive write/read/restore while clearance and an announced response are partially elapsed; identical resaved mission state; single-truck menu without engineer build options; checkpoint stop hint and actual Hold → completed clearance; malformed references/timers; contested clearance; denied reinforcement entry; one-loss tolerance/two-loss defeat; Story/Veteran defender and response budgets; actual First Orders reward; schema-1/schema-2 completion migration preserving badges.
- The same suite completes Standard through actual movement, attack-move, weapons, damage, repair and extraction. Its commander clears checkpoints before bringing the convoy forward and explicitly orders Hold once the arriving trucks are inside the pad; it does not remove enemies, edit HP/resources or force victory in that playthrough. The final fixed-step run wins at **238.25 simulated seconds**, with two trucks extracted and the third still alive. Earlier fixed-step runs extracted all three at 228.25 and 229.75 seconds. A normal-clock run with explicit Hold also reaches victory at **231.90 seconds**. This establishes a viable conventional route, not novice usability or difficulty balance.
- `SupplyLinePreview.gd`: native Metal rendering at 1280×720; real mouse/Space input for three-operation selection and start; initial automatic checkpoint; independent truck/escort selection; pause and queued advance; manual save/dialog/load; Resume followed by actual movement; Hold; three camera locators; result/replay and Campaign return. Final run: zero failures. Panel bounds clear the minimap and unit controls.
- The UI result screenshot uses a controlled two-extraction fixture; full combat victory is established separately above. The overview temporarily reveals fog for layout inspection only. Native test clicks dispatch press/release together to avoid unrelated native pointer movement cancelling a synthetic press between frames; buttons still receive ordinary GUI events.
- `CampaignPreview.gd` also passes the shared First Orders entry/build/program/assignment/version-reuse/result flow. Its construction wait now uses simulation time instead of a rendering-frame count, preventing high frame rates from ending the wait before the 40-second build completes.
- Shared First Orders, Split Signal and archive-edge headless regressions passed during integration. Changed-script formatting/lint and whitespace checks pass. Existing navigation-bake and shutdown resource/RID warnings remain; this stage does not claim a warning-free runtime or release performance acceptance.

Reviewed screens: [briefing](../../../art/skirmish/supply-line-briefing-720p.png), [convoy controls](../../../art/skirmish/supply-line-convoy-720p.png), [checkpoint stop hint](../../../art/skirmish/supply-line-checkpoint-720p.png), [archive](../../../art/skirmish/supply-line-archive-720p.png), [route overview](../../../art/skirmish/supply-line-overview-720p.png), [result](../../../art/skirmish/supply-line-result-720p.png).

## Remaining acceptance

An earlier normal-clock run with a commander that only issued Advance timed out at 370.40 simulated seconds without victory; the missing completion reward then caused three dependent assertions to fail. This remains recorded rather than counted as a passing playthrough. An Advance-only repeat did win at 259.00 simulated seconds, so the first timeout does not by itself establish a navigation defect. The revised commander uses the existing explicit Hold control inside checkpoint areas, and the HUD now explains that requirement. No global navigation or unit balance change was made for this observation. The repeat and the 231.90-second run also failed an unrelated repair assertion because the inherited wait helper counted render frames rather than physics ticks. A separate checkpoint-clearance fixture exposed the same mismatch. The Supply Line headless suite now waits on physics ticks, and repair additionally waits for actual HP recovery with a bounded 15-second simulation deadline. A separate normal-clock run of the final rules/archive fixture passes with zero failures after these corrections. These test corrections do not change simulation rules.

The original 10–15 minute novice target is not verified: the practiced scripted route currently takes about four simulated minutes. Human onboarding, route readability under fog, difficulty tuning, final art/audio, campaign operations 04–06, the third faction and remaining map settings are still open. No artificial travel delay was added merely to match a duration target.

# Classic RTS technology and conventional opening — 2026-10-04

## Delivered behavior

The command lab now offers Coordination plus six unit technologies: two weapon tiers, two armor tiers, Field service and a faction doctrine. Global **Tech** provides the same controls without selecting a lab and preserves access to paid refunds after lab destruction. See [design section 93](../../GAME_DESIGN.md#93-classic-rts-technology-and-conventional-opening) for the exact costs, effects and prerequisites. Research has one shared paid slot, full-power durations, 35% low-power speed, lab-loss suspension and single-use cancellation refunds. Completed effects apply to existing and future eligible units; armor retains current health percentage.

Bastion doctrine strengthens Anchor's incoming-damage reduction from 15% to 25%. Helix doctrine changes the first Precision shot's preparation reduction from 20% to 50%. Coordination still unlocks these abilities and long-range armor; all activation, setup, cooldown and interruption requirements continue to apply. Unit selection details and roster tooltips expose researched effects. The AI uses identical research payment and prerequisites, protecting construction and urgent production reserves and requiring a healthy field army before unit upgrades.

Snapshot version 7 preserves completed technologies, exact paid cost and active remaining time. Strict validation rejects unknown/duplicate IDs, impossible prerequisites, incorrect refunds, invalid timers and concurrent Coordination. Restoration applies research before unit construction without stacking stats or replaying payments. Versions 1–6 remain readable with no invented unit upgrades.

Opening advice now recommends one conventional tank before an unpaid lab. Once basic programming unlocks, a surviving conventional vehicle can be selected for a paid retrofit at HQ or a depot. Existing paid queues and installations suppress duplicate purchase advice. The player retains order and spending authority. Emergency worker/HQ recovery includes a route to reclaim paid technology funds even after the lab is lost.

## Verification

`TechnologyRegression` exercises both factions through actual paid/timed research, real weapon hits, current/new unit stats, preserved health percentage, service healing, ordinary/upgraded signatures, Coordination exclusion, ownership/prerequisites, low power, pause, destroyed labs, paused disk restoration, malformed data and a genuine pre-upgrade legacy restore. The missing-feature baseline fails; `technology-verified-2.log` has zero failures and no script errors. Earlier implementation/fixture failures remain in the directory for diagnosis.

`TechnologyAIRegression` verifies no research with an insufficient army, protected construction reserves, exact payment, single-queue behavior, actual timed completion, benefits and subsequent armor choice. Both factions pass in `technology-ai.log`. It is a controlled policy test, not proof of optimized full-match research timing.

`OpeningArmorRegression` verifies both-faction costs, funds advice, paid conventional production, cancel/refund, paused disk queues, actual manual movement, lab handoff, paid retrofit, cancellation/refund, installation resumption and a running guard program. The former guidance failed 26 assertions; the final shared run passes.

`TechnologyPreview` runs the native renderer at 1280×720 and 150% interface scale. Actual mouse/keyboard input covers selected labs, the global Tech button, purchase/cancel, Escape pause restoration, scrollbar End/Home navigation and emergency refund access with no engineers or lab. Completed upgrades appear on selected units. All checks pass in `technology-ui-keyboard.log`. The first rendering revealed subtitles above the overlay; overlays now use their own canvas above subtitles. The corrected screenshots were visually reviewed.

`OpeningArmorPreview` exercises actual advice selection without issuing orders or advancing a paused match, visible faction costs, paid queue/funding/lab/retrofit/install/program states and separation from minimap/unit controls. Both factions pass at 720p/150% in `opening-armor-ui.log`; representative screenshots were visually inspected. The production and retrofit operations in this preview use the normal game APIs, while advice selection uses injected native mouse events.

Accepted verification is indexed in `technology-accepted-checks.json` (28 run records, including repeated shared suites). Shared coverage includes presets, signatures, combat, specialists, Coordination, economy supply/recovery, battle-plan selection, snapshots, restored actions/combat, weapon modes, resource-field legacy migration, ambient legacy migration, AI budgets/composition/offense/recovery/support, subtitle layout and save slots. No script or assertion errors are accepted. Editor import, focused lint/format checks and whitespace checks pass.

The original Coordination suite assumed a healthy reserve must receive a repair escort. That conflicts with the current support policy. Damaging the target before settling also made its Hold preset actively repair, correctly preventing an idle-order takeover. The corrected fixture introduces damage after the preset settles, verifies the assignment and waits another 40 frames to confirm it persists. The existing support runtime remains unchanged by this investigation. Legacy-fixture builders now remove the new technology field when constructing older snapshot versions.

Godot continues to report navigation-mesh readback and shutdown renderer/resource/ObjectDB warnings. These are retained and are not new script failures. Physical input devices, other platforms, novice usability and release performance have not been accepted.

## Complete-match observations

All trials use real harvesting, paid production and Normal AI. Two Desert trials with the original allocation policy ended in defeats before the first fitted program: Bastion at 423.5 seconds and Helix at 356.4. These are retained as `technology-match-{0,4}.json` and are not direct comparisons with the previous Coastal ground-first policy.

The matching Coastal ground-first/proactive reference policy produced the following single trial per faction:

| Faction | Result / seconds | Lab / first program | Contact / assault | Harvest M / E | AI coordination samples / violations |
|---|---|---|---|---|---|
| Bastion | Victory / 755.4 | 142.2 / 166.7 | 146.2 / 541.2 | 657 / 267 | 1511 / 0 |
| Helix | Victory / 991.6 | 144.2 / 168.7 | 150.2 / 555.2 | 772 / 302 | 1983 / 0 |

The preceding lab-first Coastal pair was a Bastion victory at 913.9 seconds and a Helix defeat at 394.6. The new results show viable contested openings; two samples with additional research enabled do not isolate a causal balance improvement. The reference commander purchases later fitted units, while the explicit surviving-vehicle retrofit is verified separately by the dedicated regression. Full-match metrics do not establish how often the AI buys each classic upgrade; payment/effect evidence comes from the dedicated technology tests. The largest sampled stationary-travel episode in these Coastal runs was six seconds. Broader pacing, strategy, repeated-match balance and the earlier intermittent harvesting deadline remain open.

## Evidence

- `technology-accepted-checks.json`: accepted test logs, with earlier failed runs retained separately.
- `technology-coastal-{2,6}.json` and logs: complete comparable map/policy trials.
- `technology-match-{0,4}.json` and logs: separate Desert policy observations.
- `art/skirmish/technology-*.png`: both-faction research, prerequisite, active, completed, selected-unit and lost-lab views.
- `art/skirmish/opening-armor-*.png`: both-faction conventional-to-programmable progression.
- `technology-source.json`: final source hashes for this feature and verification.

No commits, publication or persistent agent-instruction changes were made. The broader gameplay/content goal remains active; performance optimization remains deferred.

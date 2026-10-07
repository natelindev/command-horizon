# Corner recovery and arrival timing

Ground units can escape the retained Coastal building corner while keeping their original order. Recovery considers navigable side routes, commits for at most two seconds or two metres, and returns to the same destination. Navigation-constrained steps stop or slide at nearby ground-unit contact; the two-centimetre contact allowance remains below the regression's eight-centimetre maximum overlap tolerance. Aircraft keep their previous steering.

Near an occupied friendly endpoint, movement retains short yielding instead of repeatedly taking a long outward detour. Plain Move still requires its original final-path-segment, proximity and no-progress checks before finishing; harvesting and construction retain their actual contact checks. Enemy occupancy does not complete an order.

Archive restoration now waits for every mobile and obstacle to initialize, the final terrain bake to finish, and the region and map to publish it. Positions, simulation time, recovery time and program no-progress clocks stay frozen while loading. Existing archives retain their format and assignments. The distinction between a completed bake and a synchronized navigation region follows [Godot's navigation API](https://docs.godotengine.org/en/4.6/classes/class_navigationserver3d.html#class-navigationserver3d-method-region-get-iteration-id).

Program decisions now resolve arrival, valid formation contact and combat before declaring an unchanged trip blocked. A trip that still cannot progress uses the same five-second timeout. This prevents an already-arrived guard from being blocked on its arrival decision; it does not reset the old trip's clock to manufacture progress.

## Reproduction and rejected approaches

The original [Coastal archive](guard-travel-after-3-0.json), entity `unit-13`, starts with 4.1167 seconds already accumulated on its no-progress timer. Nearby repair, infantry and working engineers remain active in the replay. The [old movement under the final regression](corner-recovery-accepted-contract-before.log) produces 13 failures: all three original captures and the mid-recovery disk replay block without reaching the formation, and one also exceeds the mobile-clearance limit. The old movement and plain-Move sources are retained beside the report.

The first [publication probe](corner-navigation-publication-before.log) returned from loading while the lab interior was still navigable. Waiting only for a bake and mobile initialization was insufficient. A later [rendered attempt](corner-recovery-ranked-preview.log) also caught an obstacle-registration race; explicit obstacle readiness and region publication are part of the accepted implementation.

Clamping at contact without sliding kept one guard pinned. Unrestricted long detours regressed harvesting and crowded barracks arrival. Ranking backward escape rays ahead of available side routes also delayed a contact approach. Limiting collision checks to steps changed by projection still allowed overlap of about 0.12 m. These diagnostic runs remain in the `corner-*` logs; the shipping implementation uses side-route preference, short yielding near occupied endpoints and contact sliding for all ground steps. The experimental five-centimetre allowance was not adopted.

The shared guard regression exposed a second failure. In [the trace](corner-arrival-trace.log), a nearby guard was already at a valid formation neighbor but timed out before evaluating arrival, preventing the adjacent guard from joining. [The corrected trace](corner-arrival-priority-trace.log) resolves that formation without extending its timer. A separate six-case probe covers both factions with preset, Lua and visual-rule guards: [before](corner-recovery-timed-arrival-verified-before.log) has twelve failed assertions; [after](corner-recovery-timed-arrival-verified-after.log) has none. Those timing cases are now included in `GuardArrivalRegression.gd`.

## Accepted checks

All **31 headless suites pass**, with no script errors in their logs. The [execution ledger](corner-recovery-accepted-checks.json) covers terrain/contact/air movement, both maps, occupied-center and blocked guards, crowded arrivals, resource access, combat/orders, three archive suites, AI recovery/coordination, presets and authored programs. [Lint](corner-recovery-accepted-lint.log), [format](corner-recovery-accepted-format.log), [editor import](corner-recovery-accepted-import.log) and the tracked diff whitespace check also pass.

The [headless corner run](corner-recovery-accepted-check-CornerRecoveryRegression.log) records these first valid arrivals; each scenario continues for twenty seconds:

| Scenario | First valid arrival | Maximum displacement from start |
| --- | ---: | ---: |
| Original capture 0 | 4.75 s | 2.98 m |
| Original capture 1 | 4.53 s | 2.92 m |
| Original capture 2 | 5.18 s | 4.68 m |
| Mid-recovery disk reload | 4.85 s | 1.58 m |
| Fresh Bastion | 4.97 s | 2.05 m |
| Fresh Helix | 6.57 s | 2.22 m |

Maximum observed frame displacement is 0.052001 m; worst mobile clearance is -0.0200 m and minimum static clearance is positive. All six end Running and settled in this headless run. The [guard suite](corner-recovery-accepted-check-GuardArrivalRegression.log) also passes all six added real-tick arrival-at-timeout cases.

The corner regression requires actual displacement and an observed valid formation arrival. It then keeps the original live traffic running for the full twenty-second observation and checks speed, unit/building clearance, assignment, repair continuity and the final Running state. Traffic can push an arrived guard into another approach, so the test does not equate movement at an arbitrary final instant with failure to arrive. Fresh setups remove other mobile traffic and still require a settled final formation. A one-time endpoint check that merely accepts the starting corner cannot pass the old-runtime comparison.

Disk coverage saves during active recovery, reads the real file, restores it, holds the battle paused for sixty frames and checks unchanged position, time and saved no-progress clock before resuming. Manual Move and Stop replace the detour normally. Both-faction fresh corner fixtures keep the same buildings, nearby infantry and repair assignment.

The [normal-clock rendered run](corner-recovery-accepted-rendered.log) passes at 1280×720 with a 150% interface. All nine captures were reviewed: the original corner, formation arrival and subsequent traffic, the same sequence after disk restoration, and fresh Bastion/Helix arrival and final formation. Arrival status reads “Watching assigned area”; later traffic can correctly show “Returning to guard point.” Tactical-pause ownership and the paused clock remain consistent. These are programmatic gameplay/visual checks, not a physical-device input acceptance claim.

| Captured corner | Valid formation arrival | Fresh Bastion | Fresh Helix |
| --- | --- | --- | --- |
| [Before](../../../art/skirmish/corner-recovery-before.png) | [After recovery](../../../art/skirmish/corner-recovery-original-arrival.png) | [Arrival](../../../art/skirmish/corner-recovery-fresh-bastion-arrival.png) | [Arrival](../../../art/skirmish/corner-recovery-fresh-helix-arrival.png) |

## Complete matches and limits

The initial four source-fingerprinted Advanced-start matches cover both factions on Industrial Crossroads and Coastal Foundry against Normal AI. They finish with one victory and three defeats at 5:22.3–19:02.2. Their longest sampled stationary-travel episodes are at most 2.5 seconds, with no AI coordination violations. These runs precede the arrival-decision ordering correction and are retained as pilot evidence.

The final four matches use the accepted six-file runtime change and finish with two victories/two defeats. All 3,566 coordination samples have zero violations, and no guard pre-block capture triggers. Results are from the reference commander's side; stationary columns are longest sampled episodes in seconds.

| Faction / map | Outcome | Time | Commander stationary | AI stationary |
| --- | --- | ---: | ---: | ---: |
| [Bastion / Industrial](corner-recovery-final-match-0.json) | Victory | 4:17.0 | 2.5 | 2.5 |
| [Bastion / Coastal](corner-recovery-final-match-1.json) | Victory | 14:04.4 | 2.5 | 8.5 |
| [Helix / Industrial](corner-recovery-final-match-2.json) | Defeat | 5:53.7 | 2.5 | 15.5 |
| [Helix / Coastal](corner-recovery-final-match-3.json) | Defeat | 5:28.0 | 2.0 | 1.5 |

**Remaining movement defect:** the Industrial match saves [AI tank `unit-42`](corner-recovery-final-match-2-stall.json) beside its Command Lab and several settled allies at simulation time 185.73. Its plain Move requests `(107, 0, 49)`; the path terminates at the reachable boundary `(106.2, 0.6, 49.8)`. In the [thirty-second replay](corner-recovery-final-stall-replay.log), with AI decisions disabled and other units retained, it remains Moving and displaces only 0.001 m. This is a reproduced unresolved blockage, not a successful congestion check. The [isolated replay](corner-recovery-final-stall-isolated.log), removing every other mobile unit while preserving the buildings, moves 0.359 m and finishes the order before the five-second sample. This narrows the next investigation to nearby mobile traffic and crowded endpoint completion; it does not identify which neighbor or rule is responsible. The full match eventually ends; that does not prove this unit completed its order. The 8.5-second Coastal delay has no saved capture below the fifteen-second archive threshold. Neither outcome counts nor the pilot comparison establish a causal balance improvement.

The [artifact audit](corner-recovery-accepted-audit.json) verifies 388 current source hashes, retains 26 runtime/test/commander snapshots, and records the checks, match results and image hashes. The [source comparison](corner-recovery-accepted-source.json), [check runner](run_corner_recovery_accepted_checks.py.txt) and [match runner](run_corner_recovery_final_matches.py.txt) identify the tested implementation and command lines. Full matches use the established responsive reference commander and uniquely named stall archives; they are not human or novice playtests. Godot 4.6's existing navigation-geometry readback and exit-time shader/resource warnings remain visible in the logs.

This pass addresses the retained corner, restoration readiness and arrival-timeout defects. It does not establish universal congestion freedom, faction balance, intended match pacing or novice success. Broader gameplay/content, physical-device/platform and release acceptance remain open. Performance optimization remains deferred.

## Reproduce

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/CornerRecoveryRegression.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/GuardArrivalRegression.gd
godot --path . --script tests/rendered/CornerRecoveryPreview.gd
```

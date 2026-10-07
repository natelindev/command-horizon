# Split Signal capture-unit recovery — 2026-10-07

Split Signal now offers **Find infantry** beside a relay that needs a capture unit. It selects and centers the nearest idle infantry first, preserving the selected unit’s orders and the battle's pause state. If only busy infantry survive, they remain findable without cancelling their work. With no infantry, the shortcut becomes **Find barracks** and opens the existing selection/production controls. With neither infantry nor a completed barracks, it is disabled and explains that a barracks is needed. The existing View locator remains available.

## What the saved battle showed

The preceding relay-feedback pass exposed timing-sensitive Veteran recovery branches. This pass added bounded order/action/weapon-timer/contact samples and saves the actual unfinished end state. The instrumented headless branch remains at 117.45 / 120 uplink seconds after another 180.50 seconds of simulation. The northern relay is enemy-owned, with friendly armor present and 5.75 seconds of partial recapture retained.

The end-state archive contains a living 22-HP infantry unit at `(25.3042, 0, 33.9126)`, near the home base. From simulation time 310.90 to 448.90, every sampled position is identical, its manual queue is empty, and its action is WaitingForTargets. Friendly tanks and a repair robot are already near the northern relay. The audit supports a capture-order problem in the reference commander; this case does not justify changing weapon or navigation rules.

The ten-second audit cadence does not capture the precise earlier target-loss event; the causal mechanism is verified separately below. The reference helper replaced an advance with a targeted attack and did not queue a return to the capture objective. Target disappearance can therefore leave approaching infantry holding short of the relay. The revised test-only helper explicitly queues an ordinary attack-move to the relevant relay after its attack. A controlled regression removes the observed target while the infantry is still en route: the old helper fails to capture within 40 seconds, while the revised queue completes the capture in 14 seconds. The first version of this fixture accidentally blocked the observer's line of sight with the relay and failed both branches; those two runs are rejected, and the corrected observer placement establishes the intended contact before target removal.

This is an explicit reference-commander decision. Shipping units continue obeying ordinary manual order replacement and queue semantics; the new HUD shortcut issues no movement, attack or production order.

## Earned recovery and controls

The exact newly captured stalled world restores with unchanged positions/HP and a frozen clock. Find infantry selects its sole idle infantry. View centers the northern relay, and an explicit move completes the uplink in **12.85 seconds headless** and **12.80 seconds with normal-clock rendering**. No extra unit, resource or health is granted, and the shortcut spends nothing.

The rendered flow uses real viewport mouse and Enter activation, then a right-click on the capture ground. While paused, the order remains accepted/queued; it starts when the battle resumes. The initial headless fixture incorrectly expected an active movement destination before resume; that assertion is corrected to accept the paused pending order. The original HUD fails a separate missing-shortcut check.

Additional controlled checks cover idle-versus-busy preference, preserved queued orders, last-infantry loss, barracks selection without automatic production, missing-barracks disable/help and hidden recovery actions after mission completion. All controls and rows fit at 1280×720 with 150% interface scaling and remain above the minimap. Five reviewed captures show [found infantry](split-recovery-audit/ui-found.png), [explicit queued move](split-recovery-audit/ui-ordered.png), [earned victory](split-recovery-audit/ui-victory.png), [barracks fallback](split-recovery-audit/ui-barracks.png) and [missing barracks](split-recovery-audit/ui-no-barracks.png).

## Complete branch evidence

| Branch from the earlier Veteran contested archive | Result | Additional simulation time |
| --- | --- | ---: |
| Original helper, instrumented headless | Unfinished; idle infantry short of relay | 180.50 s |
| Original helper, normal-clock | Victory | 54.55 s |
| Queued follow-through, instrumented headless | Victory | 22.53 s |
| Queued follow-through, normal-clock | Victory | 26.22 s |

These branches retain the existing paid recovery force: four infantry, two tanks and a repair robot, costing 88 materials / 20 electronics. They do not establish a causal win-rate or timing improvement: the original normal-clock branch already wins, and scheduling variation remains. The controlled target-loss regression establishes the specific queue behavior; the earned idle-infantry archive establishes the usefulness of the player shortcut.

Seven final captures were visually reviewed, including the normal-clock continuation’s loaded and victorious states. All fifteen script processes are classified in `run-index.json`, including observed failures and rejected fixtures. The six changed/new scripts pass format and lint checks. Shipping source hashes show only `SplitSignalHUD.gd` changed during this pass.

The shared Split Signal suite passes objective/archive/finite-response/optional-route/progress checks and a 136.53-second full reference victory. Shared order and relay-feedback regressions pass. No balance values, capture rules, map geometry, archive schema or enemy behavior change.

## Reproduction and limits

Run Godot with `--headless --fixed-fps 60 --script tests/headless/SplitCaptureShortcut.gd` for exact stalled-world recovery and controlled shortcut edges. `SplitFollowthroughRegression.gd` covers target disappearance and actual subsequent relay capture. `tests/playtest/SplitRecoveryAudit.gd` accepts `--archive=...`, a fresh `--evidence=res://...` prefix, and `--reinforce`; the rendered shortcut fixture accepts a fresh evidence prefix and refuses screenshot overwrites. Keep the retained original archives unchanged.

Source snapshots, exact archives, timelines, classified runs and SHA256 evidence are retained in [the evidence folder](split-recovery-audit/). Known navigation readback and shutdown resource/ObjectDB/RID diagnostics remain. Novice comprehension, repeated strategy/difficulty/reward balance, broader product/environment/platform acceptance and deferred performance remain open. The overall development goal stays active.

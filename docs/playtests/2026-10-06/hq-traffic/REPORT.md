# Industrial HQ engineer traffic — 2026-10-06

Ground recovery now ranks the distance actually free of neighboring bodies before terrain clearance. A backward escape remains eligible when the side routes are navigable but occupied. The retained Industrial engineers can separate and resume their original orders; navigation projection, speed limits, physical contact clipping, destination ownership and arrival rules remain unchanged.

The shipping edit is confined to two comparisons and their explanation in `Movement.gd`. It does not alter unit sizes, avoidance settings, map geometry, health, resources or combat.

## Reproduction and cause

The [416.7-second earned archive](relay-commitment/final6-earned-case6-10-infantry_ready.json) contains a wounded engineer executing Move and an electronics harvester wedged between HQ and the barracks. Their earlier full-match observation lasted approximately 272 seconds. The [original Move replay](hq-traffic/before-unit-8.log) remains stationary until the engineer dies; the [original harvesting replay](hq-traffic/before-unit-15.log) records zero displacement throughout thirty seconds. Removing other mobile units lets the [same Move finish within five seconds](hq-traffic/before-unit-8-isolated.log), distinguishing mobile congestion from an unreachable destination.

The recovery diagnostic finds a side ray with 2.0 m of navigable terrain but **0.0 m of usable travel** before contact. The original selector prefers that ray and skips backward candidates. The backward ray offers approximately 1.1 m for the wounded engineer and 1.5 m for the harvester. The corrected selector evaluates that usable space first and retains terrain clearance as its tie-breaker. The existing two-second recovery commitment and physical constraints then govern movement.

## Focused verification

The finalized fixture against an isolated copy of the original movement code produces [six assertion failures](hq-traffic/original-final-traffic.log). None of its three repetitions escapes the pinch; one repetition retains both engineers motionless for the full minute. The baseline copy uses the same project sources/tests with only `Movement.gd` replaced by the retained before version, leaving the active project untouched.

[Final headless traffic checks](hq-traffic/final-traffic.log) preserve all saved actors, health, orders and cargo. They disable further player/AI decisions but leave existing unit actions and combat running. No units, resources or healing are granted. Results:

| Repetition | Escape beyond 2 m | Completed Move | First pickup | Actual electronics delivery |
| --- | ---: | ---: | ---: | ---: |
| Original archive 0 | 3.18 s | 6.92 s | 20.23 s | 38.37 s |
| Disk reload during recovery | 0.77 s | 6.63 s | 21.45 s | 39.57 s |
| Original archive 2 | 5.12 s | Died after escape | 22.87 s | 40.97 s |

Reload-row times begin after the intermediate reload, 1.2 simulation seconds after the original archive. It preserves exact paused positions, destinations and clock. The wounded engineer begins at 1 HP. The traffic contract requires escape within ten seconds, completion within fifteen seconds if it survives, and the other engineer's actual collection/delivery. Death before escaping still fails. This distinguishes clearing the traffic defect from guaranteeing survival under fire. Earlier checks that required universal survival failed in one headless repetition and one rendered repetition; those observations remain, and no combat protection was added to make them pass.

All observed steps remain within the normal 3.84 m/s speed at 60 Hz; minimum mobile clearance is approximately −0.020002 m, within the existing two-centimetre contact tolerance. Maximum planar navmesh offset is below 0.078 m, including the original slightly off-mesh archived position. [Fresh Bastion, Helix and Frontier fixtures](hq-traffic/factions-regression.log) also complete both opposing engineer orders through the recreated HQ corridor while respecting body and terrain bounds.

## Shared checks and limits

Fourteen headless suites have passing final runs: the two HQ traffic suites above, plus [CornerRecovery](hq-traffic/CornerRecoveryRegression.log), [CrowdBoundary](hq-traffic/CrowdBoundaryRegression.log), [HarvestTraffic](hq-traffic/HarvestTrafficRegression.log), [EndpointTail](hq-traffic/EndpointTailRegression.log), [CrowdedDestination](hq-traffic/fixed-enemy-regression.log), [FrontierCrowd](hq-traffic/FrontierCrowdRegression.log), [GuardEndpoint](hq-traffic/GuardEndpointRegression.log), [AttackCrowdedArrival](hq-traffic/repeated-attack-arrival.log), [AttackMoveArrival](hq-traffic/AttackMoveArrivalRegression.log), [AirArrival](hq-traffic/AirArrivalRegression.log), [SaveRestoreEdges](hq-traffic/SaveRestoreEdges.log) and [EconomyRecovery](hq-traffic/EconomyRecoveryRegression.log). The FrontierCrowd suite exercises the Desert Frontier map with Bastion/Helix; the separate fresh HQ fixture covers the Frontier faction.

The older enemy-occupancy fixture disabled the blocker's action but left its passive avoidance running. [Tracing](hq-traffic/enemy-arrival-signals.log) shows the blocker drifting about 0.4 m and a real `movement_finished` event at the projected navigation endpoint. The test now keeps that blocker stationary and explicitly verifies its position, preserving the intended enemy-exclusion check. No shipping arrival rule changed.

One initial [AttackCrowdedArrival run](hq-traffic/AttackCrowdedArrivalRegression.log) misses its six-second bound in its first repetition, generating two assertions; the other repetitions and queue/combat cases pass. A subsequent complete run passes, as does the original-code control. The intermittent timing miss is retained as an unresolved limitation, not declared fixed or silently discarded. General crowd/arrival acceptance therefore remains open.

Seven final [rendered captures](hq-traffic/final-render.log) cover before, ten seconds and delivery for two live replays, plus the intermediate disk reload. Both rendered engineers complete their Moves (12.15 / 7.28 seconds), with deliveries at 39.07 / 38.45 seconds. [Before](hq-traffic/final-render-archive-0-before.png), [after delivery](hq-traffic/final-render-archive-0-after.png), and [mid-recovery reload](hq-traffic/final-render-archive-1-reloaded.png) are representative. All seven framebuffers are verified as 1280×720 at 150% interface scale; paused selection/camera review preserves funds and orders. Selection is programmatic, not native or injected GUI input. The first rendered run is retained as rejected evidence: it included the casualty noted above and restoration reset its window to 1920×1080. Final review establishes the window size after each load.

All passing final runs exit zero without script/parse errors. Formatting and lint pass. Existing navigation-readback and shutdown resource/RID diagnostics remain.

## Full-match follow-through

Two new paid Standard/Normal cautious-relay trials use seed 4110 and the same research/production/repair policies as the preceding audit:

| Match | Result / time | First program | Longest sampled stationary travel, own / AI | Forces lost |
| --- | --- | --- | --- | ---: |
| Frontier → Bastion, Alpine | Defeat / 812.4 s | 495.2 s | 3.0 / 2.0 s | 24 |
| Helix → Frontier, Industrial | Defeat / 277.8 s | None | 1.5 / 0.5 s | 8 |

[Alpine record](hq-traffic/match0.json) and [Industrial record](hq-traffic/match6.json) reach actual outcomes, exit zero, and have no script/parse errors or AI coordination violations across 2,181 samples. No fifteen-second stationary episode triggers the requested archive capture. These runs support bounded traffic improvement, not stronger survival or balance: both lose, neither launches the main assault, and Industrial loses before program activation. Earlier seeded trials varied substantially, so a causal win-rate claim is not supported.

Home defense, paid strategic progression, late recovery/production deadlock, the intermittent arrival bound, novice/content/platform acceptance and broader congestion remain open. Performance stays deferred. Source snapshots, classified run results and [artifact hashes](hq-traffic/SHA256.json) accompany this report.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/HQTrafficRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/HQTrafficFactionsRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/HQTrafficPreview.gd -- --captures=docs/playtests/2026-10-06/hq-traffic/review-new
```

Use a fresh capture prefix to preserve prior evidence.

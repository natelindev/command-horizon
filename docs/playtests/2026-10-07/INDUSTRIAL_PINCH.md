# Industrial HQ boundary contact recovery

The retained engineer/infantry jam near the Industrial HQ has a movement fix. When an active ground recovery step is displaced by navigation projection and then clipped to less than one millimetre of actual movement, it can try its committed direction through the same navigation, speed and swept body-contact checks. The alternative is used only if it permits more movement. Short yielding at an occupied endpoint is excluded; ordinary destination arrival retains its existing behavior.

Only `source/match/units/traits/Movement.gd` changes in shipping code. Actual resulting velocity continues to be reported to avoidance. No order, resource, collision-margin, movement-speed or save-format rule changes.

## Cause and original failure

The October 6 construction control logged an engineer and infantry stationary near `(10.95, 52.38)` and `(11.88, 52.22)` for thirty seconds; its longest sampled episode was 33 seconds. This is separate from the later blocked-program assignments. The earned `construction-safety/control6-earned-case6-10-worker_withdrawal.json` archive at **139.733 seconds** captures both units during the jam.

The engineer already chooses a backward recovery direction with 1.5 metres of navigation/body clearance. Local avoidance changes that direction. Projection back onto the navigation boundary then points into the adjacent infantry, and the body clip removes the resulting step. Both units remain pinned despite having legal destinations. Replaying the save on the preceding shipping code reproduces the failure with player decision loops disabled and existing work, movement, combat and paid queues still live.

An isolated project matches all 288 preceding shipping scripts exactly. The new regression fails **25 assertions** there: escape, infantry arrival, collection and delivery in six replay/checkpoint branches, plus a manually replaced Move order. No script or parse errors occur. Final-code replay keeps the same earned units, geometry, orders and deadlines.

## Verification

The regression runs three direct replays and three disk continuations saved after 1, 12 and 36 physics frames. Paused position, destination, action, cargo and simulation time survive restoration. The engineer must escape within five seconds, collect within ten and deliver within twenty; the infantry must reach its original guard point within five. A separate explicit Move replaces harvesting and reaches its new destination without collecting cargo.

In the final six-branch headless run, escape takes approximately **0.55–0.67 seconds**, infantry arrival **1.63–2.17 seconds**, collection **4.62–5.70 seconds**, and cargo delivery **10.27–11.35 seconds** from the earned checkpoint. These are observed replay timings, not general guarantees. Maximum measured movement is approximately 1.000024 times the nominal per-frame speed allowance, within the existing numerical tolerance; minimum mobile clearance is about -0.01486 m and maximum navigation offset about 0.00434 m.

Collection is checked at real resource contact and must consume finite deposit stock. Delivery is checked at HQ contact and must increase funds by the returned cargo. Each frame is checked against movement speed, nearby mobile-body clearance and the navigation boundary. Eight headless suites have accepted passing final runs: IndustrialPinchRegression, ContactRecoveryRegression, HQTrafficRegression, HQTrafficFactionsRegression, CrowdBoundaryRegression, FrontierCrowdRegression, GuardArrivalRegression and CargoReturnRegression. The twelve older captured contact replays still collect at 6.1 seconds; the older HQ branches still deliver cargo.

**Shared verification is not fully green.** AttackArrivalProgressRegression has passing and failing runs. A focused twenty-replay audit of `late-89136-3.json` misses the six-second arrival deadline in **2/20 preceding-code replays and 5/20 current-code replays** (four and ten assertions respectively). This establishes a pre-existing intermittent failure, not an unchanged failure rate or a general arrival fix. Instrumentation also records a failed replay without the new fallback firing during that replay. Earlier single passing suites were insufficient to close this case.

HarvestTrafficRegression has one full-suite manual-replacement deadline miss on current code. Its preceding-code full suite passes. Twelve isolated manual-replacement replays pass on each code version; this does not explain or dismiss the retained full-suite miss. Its cause remains follow-up work. No fixture deadline or behavioral assertion was relaxed.

The rendered scenario uses 1280×720 at 150% UI scale, with normal visibility and programmatic selection/pause. Both rendered branches pass, and all **seven final captures** were inspected. They show the initial pinch, escape, delivery and intermediate disk reload. Seven superseded captures from the intermediate implementation are also retained and were reviewed. This verifies rendered simulation and selection authority, not new native mouse/keyboard interaction.

Formatting and lint pass for the changed shipping file and five new regression/audit/preview scripts. Known runtime navigation-readback warnings and shutdown resource/ObjectDB/RID/shader diagnostics remain. Final passing runs have no script or parse errors.

## Paid match limits

Two complete paid Standard/Normal Industrial trials use the same Helix-versus-Frontier reference, seed 4110, combined research, screened-air production, two opening tanks, early depot and cautious relay policy. The isolated preceding-code control loses at **288.8 seconds**; the final implementation loses at **671.8 seconds**. Neither reaches its first program or main assault. Longest sampled stationary travel is **3.0 / 0.5 seconds** by side in the control and **3.5 / 2.5 seconds** in the final trial, with zero coordination violations across 578 and 1,344 samples.

The match outcomes do not establish a stronger opening, and the control itself does not recreate the older 33-second jam. The earned-state replay isolates that defect. Longer survival in one changed trajectory is not balance acceptance. A completed intermediate-version trial also loses at 676.0 seconds with no program/assault; it remains separate from final-code acceptance.

## Rejected and superseded approaches

The first version allowed the fallback whenever a recovery step was body-blocked. It made the older contact fixture collect early, invalidating its expected detour/checkpoint assumptions (thirteen assertions and three script errors), and caused one older HQ disk continuation to miss collection/delivery (two assertions). That version is rejected and retained as `experiment-unrestricted-Movement.gd`.

The second version required displacement by the navigation boundary. It preserved the contact and HQ suites, but a later occupied-arrival run failed four assertions in two of fourteen archived infantry replays. The first preceding-source arrival control passed, but the focused repeats above later reproduced the miss on preceding code too. The earlier causal attribution to the fallback is therefore unproven. This intermediate source and its paid match remain recorded. The final change explicitly excludes occupied-endpoint yielding, preserves the original pinch fix, and retains the unresolved arrival failures rather than claiming the added guard solves them.

## Limits and reproduction

This repairs a captured physical contact failure. The reproduced occupied-arrival timing defect and retained harvesting replacement miss are the next movement acceptance work. A stronger full-match opening, general congestion freedom, broader content, novice and platform acceptance remain unproven. Performance remains deferred; the overall gameplay goal stays active.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/IndustrialPinchRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/IndustrialPinchPreview.gd -- --captures=res://tmp/new-industrial-pinch
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/CautiousRelayMatches.gd -- --case=6 --repeats=1 --research=combined --strategy=screened-air --output=res://tmp/new-industrial-match.json --archive=res://tmp/new-industrial-stationary.json --archive-prefix=res://tmp/new-industrial-earned
```

Use fresh output paths. Raw logs, rejected/final sources, earned archives, classified run results, source fingerprints and a SHA256 manifest are retained in [industrial-pinch](industrial-pinch/).

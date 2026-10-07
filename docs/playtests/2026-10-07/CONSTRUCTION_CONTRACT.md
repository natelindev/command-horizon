# Construction rate and cancellation contract

Skirmish construction now follows the core design: one engineer supplies progress to each site, and cancellation returns the unused fraction of its cost. Previously four engineers built four times as fast, while a nearly finished foundation still refunded its entire price.

A site's active builder is derived from live, in-range construction orders in player child order. Other engineers retain their orders and take over when an earlier builder stops, dies or leaves range. No persistent ownership claim or save field is introduced. Construction spark effects remain unchanged. The shared `Structure.construct()` API remains usable for setup and scripted progress; rate enforcement belongs to ordinary engineer construction actions.

Cancellation rounds the unused fraction down independently for materials and electronics. The selection panel displays the current refund, with a matching accessible explanation. Completed, destroyed and already-cancelled structures cannot issue refunds. Destruction continues to return nothing. Non-skirmish legacy construction retains additive worker speed and full cancellation refunds.

## Verification

The final runner against the exact preceding 288-script shipping baseline fails eighteen expected assertions: excessive crew speed, accelerated handoffs and partial-construction full refunds in each faction. It has no script or parse errors. The first narrower reproduction also fails eighteen assertions; both logs and their test sources are retained.

The final construction regression passes for Bastion, Helix and Frontier:

- Ordinary placement charges 80 M / 20 E for the HQ. Four engineers make exactly 10/45 progress in ten simulation seconds.
- A real disk save/load preserves paused progress, simulation time and defeat countdown, then resumes construction.
- Stopping the first engineer and killing the next each preserve the one-engineer rate. The stopped engineer is not reassigned.
- The HQ completes before the sixty-second defeat deadline and resets that deadline. Completed-building cancellation is rejected.
- Paid cancellation cases at 0%, 25%, 50% and 99% return 80/20, 60/15, 40/10 and 0/0, respectively. Same-frame duplicate cancellation does not refund twice. Destruction gives no refund.
- Legacy metadata fixtures preserve additive construction and full refunds.

These are controlled fixtures: funds and worker positions are supplied, and refund progress is injected. They verify actual paid placement and ordinary construction actions, not an earned-economy opening or successful Industrial match recovery.

The rendered Helix run passes four engine-injected Cancel button clicks and the same construction/save/handoff checks. All seven 1280×720 captures at 150% UI scale were inspected: crew, restored, completed and four refund states. Buttons and amounts fit the selection panel, the selected foundation remains visible, and completion restores the normal HQ menu. Native OS input is not claimed.

Formatting and lint pass. Eight final headless suites pass: ConstructionContractRegression, HQCountdownRegression, EconomyRecoveryRegression, OrdersRegression, BattleDebriefRegression, ContactRecoveryRegression, Skirmish and BastionDemo. Results and logs are retained in `construction-contract/`. Existing runtime navigation-readback warnings and shutdown resource/ObjectDB/RID diagnostics remain; accepted runs contain no script or parse errors.

## Evidence and reproduction

`construction-contract/` retains before/final source snapshots, the initial reproduction and intermediate checks, final negative and positive runs, rendered captures, source fingerprints and a SHA-256 manifest. The shared batch originally requested `EconomyRecovery`, which is not a file; `EconomyRecoveryRegression` was then run successfully under its correct name. The missing-name entry is retained as a launch omission, not a test pass.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/ConstructionContractRegression.gd
```

Use `tests/rendered/ConstructionContractPreview.gd` without `--headless` and pass a new `-- --captures=res://tmp/construction-review` prefix for visual review.

This closes the documented construction-rate/refund deviation. Earned-state HQ rebuilding and the reference economy's reconstruction priorities, sustained Industrial defense/progression, broader content/novice/platform acceptance and congestion remain open. Performance remains deferred.

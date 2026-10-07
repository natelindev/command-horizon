# Closed-panel attack feedback — 2026-10-06

The existing battle-alert button now shows **Base under attack** while an own-building attack alert is active, or **Units under attack** for other own-unit fire. Base damage takes priority over unit damage, including newer unit hits. Players can see incoming danger without opening the history. New/active counts remain in the tooltip and accessibility description; the normal count label returns after attack alerts expire.

This uses the existing human-only damage events and eight-second simulation-time alert window. Reading or clearing history does not hide an active attack. Tactical pause preserves the warning. Clicking still opens the existing history; Show still locates/selects the affected units without issuing orders. No flashing, extra panel, popup, map reveal or combat/balance change was added.

## Evidence

The finalized regression against the original panel produces [22 failures](attack-feedback/original-final-fixture.log) for missing unit/base labels, priority, read-state persistence and count context. The new panel passes the same cases for Bastion, Helix and Frontier. Tests apply real weapon damage through the unit damage API, distinguish enemy damage and generic HP changes, and cover pause, renewed fire, expiry fallback, read/clear, settings/result blocking, funds and order authority.

An untouched [earned Industrial withdrawal archive](relay-contest/earned6-case6-10-worker_withdrawal.json) resumes with live enemy AI and existing orders. An actual building hit occurs 0.45 simulation seconds after restoration and updates the button. The replay supplies no units, resources, damage injections or reference-commander decisions. This verifies the feedback in the losing match's real home-defense state; it does not establish improved player survival or resolve the strategy failure.

Accepted headless checks:

- [AttackFeedbackRegression](attack-feedback/final-AttackFeedbackRegression.log): all three factions plus live earned-state damage, zero failures.
- [BattleAlertsRegression](attack-feedback/verified-live-worker-alerts.log): grouping, losses, ownership, pause, inspection, actual cargo delivery, paid queue/power recovery, bounded history and save/load, zero failures.
- [AirDefenseAdviceRegression](attack-feedback/final-AirDefenseAdviceRegression.log) and [GroundDefenseAdviceRegression](attack-feedback/final-GroundDefenseAdviceRegression.log): zero failures.

The [rendered regression](attack-feedback/final-render.log) verifies mouse opening and keyboard Show, paused-clock/order preservation, text width and viewport bounds. Six final 1280×720 / 150% captures cover units, base, resolved state and earned Industrial fire, including the open histories. [Earned closed button](attack-feedback/final-earned-industrial.png) and [earned history](attack-feedback/final-earned-industrial-history.png) show the changed player-facing behavior. These use engine GUI input, not physical native input.

All accepted runs exit zero without script/parse errors. Existing navigation-readback and shutdown resource/RID diagnostics remain. Formatting and GDScript lint pass.

## Fixture corrections and scope

The first modal assertion expected the button's local visible flag to clear during Settings. Settings freezes the scene beneath its modal, so the corrected check tests the actual contract: alert interaction is unavailable and cannot open history or move the camera. The existing shipping modal behavior was sufficient.

The shared alert regression initially reports ten failures under both the original and changed panels. Its combat fixture freezes every unit subtree, leaving idle engineers unable to yield at HQ's unloading face. Two couriers circle with their final cargo; the early return then prevents later power fixtures from being established. A diagnostic continuation that restores normal engineer processing delivers both cargo units within five seconds. The economy phase now keeps all engineers' normal avoidance active and checks that the depleted couriers, specifically, do not also generate idle alerts. The complete suite passes with final-field return at 19.0/22.0 seconds. No shipping harvesting change was needed. Diagnostic scripts/logs and the before fixture are retained. An intermediate nested-lambda formatting parse failure is retained as rejected evidence; the final fixture uses a simple loop.

The only shipping edit is the alert-button presentation in `BattleAlertsPanel.gd`. Broader strategy, novice, content and platform acceptance remain open; performance remains deferred. Source copies, accepted-result metadata and [artifact hashes](attack-feedback/SHA256.json) accompany this report.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/AttackFeedbackRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/AttackFeedbackPreview.gd -- --captures=docs/playtests/2026-10-06/attack-feedback/review-new
```

Use a fresh capture prefix to preserve earlier evidence.

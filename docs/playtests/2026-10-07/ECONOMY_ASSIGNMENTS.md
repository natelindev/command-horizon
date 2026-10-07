# Visible gathering assignments and queued-income guidance

The resource bar now shows an engineer count beside materials and electronics. Each count is a selection shortcut: players can inspect the workers assigned to that resource without changing cargo or orders. Supply guidance uses the same accounting, so an already-queued gathering transfer no longer produces a false missing-income prompt.

## Behavior

A worker counts once: by its next queued job, or by its current gathering assignment when no job is queued. An immediate valid resource-gathering order counts toward its destination; a later gathering order behind another pending job does not. Cargo delivery to HQ is not a resource-field assignment. Invalid, dying or freed targets, dead engineers and depleted/stranded assignments are excluded. Engineers travelling, returning cargo or waiting for a work slot remain assigned. The tooltips explain that queued next jobs count.

This makes an uneven allocation visible even when both streams still have workers. The existing supply recommendation remains conservative: working streams do not trigger automatic redistribution advice. Selection does not reassign workers, spend money or accelerate deliveries. The resource shortcuts reuse the battle-plan selection path, including command-mode cancellation and modal/ownership checks. They are hidden on foreign or campaign/legacy bars without the human skirmish battle plan. Empty allocations are disabled and callbacks revalidate their current membership.

Only `EconomySupply.gd` and `ResourcesBar.gd` change among the preceding 288 shipping scripts, with a new read-only `EconomyAssignments.gd` helper. No harvesting, order execution, production costs or archive schema changes are made.

## Verification

All three factions exercise ordinary materials collection, a loaded return with an explicit queued electronics job, selection of the expected group, exact paused disk restoration, subsequent electronics delivery and paid fitted armor completion. Current actions, queues, cargo, bank and simulation time are unchanged by selection. The fixture uses an Advanced start and sets the electronics bank to zero to isolate the missing-income prompt; it is not a fully earned Standard opening. Each original 4 M cargo is delivered once. Actual electronics deliveries accumulate to 12 / 16 / 8 E for Bastion / Helix / Frontier, enough for the normal faction-specific fitted cost, and the purchased unit completes with its chip.

The assignment contracts cover both transfer directions, next-versus-later queued jobs, HQ drop-off, queued target destruction, work-slot waits versus depletion, engineer death, empty selection, foreign bars and modal ownership. The shared supply suite preserves raid/recent-damage priority over depletion and ordinary one-worker streams; the shared orders suite retains queue, manual override, fog/target loss and harvest handoffs.

The preceding shipping Supply/ResourcesBar files fail twelve assertions in the retained counterfactual run: false missing-electronics guidance before/after load and absent controls, in each faction. Its grouped message “Archive lost planned allocation” fails because restored guidance ignores the queue; actual archive data and resource delivery remain intact. The final fixture uses a clearer diagnostic. Additional final checks cover an empty callback after death and the reciprocal electronics-to-materials queue. The counterfactual process exits 1 and the current source is restored before final verification.

## Rendered review

The accepted Metal-rendered run at **1280×720, 150% interface scale** uses two engine-injected mouse activations and one focused Enter activation. All three captures were inspected: material group selection, queued electronics selection with visible keyboard focus, and restored selection with the empty materials shortcut disabled. The resource row fits above the command panel and clear of Alerts, with no added HUD height or colored decorative borders. Cargo and the pending order remain visible in the unit panel.

Reviewed captures: [materials group](economy-assignments/verified-preview-helix-queued-1.png), [queued electronics with keyboard focus](economy-assignments/verified-preview-helix-queued-2.png), [restored assignment](economy-assignments/verified-preview-helix-restored-2.png).

The first rendered fixture incorrectly called a Control rectangle method on the alerts CanvasLayer. It emitted three script errors despite exit 0 and is rejected. The second corrected that target but produced three 1920×1080 images instead of the required 720p frames; it exits 1 and is retained separately. Applying the viewport size after scene setup/restoration fixes that fixture. The final rendered run reports zero failures. Rendered verification stops after paused archive/selection checks; the full income/production checks run headless.

## Evidence and limits

The evidence directory retains classified logs, earlier fixture sources, the original shipping files, final sources/fingerprints, screenshots and a SHA-256 inventory. Initial, intermediate and final runs are distinguished in `run-index.json`; `analyze.py` verifies their expected outcomes, image dimensions and exact shipping-change scope. Existing navigation-readback warnings and shutdown ObjectDB/resource/shader/RID diagnostics remain. Format and lint pass.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/EconomyAssignmentsRegression.gd
```

The opponent strategic loop is disabled in these controlled fixtures. This improves human economy visibility and preserves explicit orders; it does not establish contested survival, broad balance or novice acceptance. Those gates, final environment/platform acceptance and deferred performance remain open. The overall goal remains active.

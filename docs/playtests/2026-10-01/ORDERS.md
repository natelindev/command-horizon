# Manual command queues

## Delivery

Shift orders append up to 16 waiting operations per unit. Ordinary orders replace the queue; Stop clears it. Programs yield immediately, with explicit Resume or optional queue-end auto-resume controlling the return to automation. Paused commands stay pending. All mobile roles can queue manual orders, including conventional infantry and workers.

Action nodes are instantiated at execution time, preventing stale construction signal connections and retaining no queued Node instances. Targets use weak references and are revalidated before execution. Hidden enemy targets resolve only to the position recorded at enqueue time. Repair releases its queue on full health; gathering yields after delivery; following continues until target loss or player intervention. Five seconds without move progress produces a blocked explanation, with Skip available. Idle controllers disable processing.

Selection UI includes state/count, Skip, Clear waiting and an optional auto-resume preference. A representative numbered route shows active solid and pending dashed segments below other HUD layers. Existing program editing and factory inheritance still work.

## Evidence

- `OrdersRegression.gd` passes for Bastion and Helix: actual Shift terrain signals, paused queues, route execution, ground/air/conventional units, cap, replace/Stop, default manual completion, opt-in resume, explicit Resume cancellation, dead targets, hidden target position, full-health repair, follow/skip, single-load harvesting delivery, attack/attack-move/construction handoffs and blocked movement/Skip.
- `OrdersPreview.gd` passes actual paused Shift attack-move input, multi-unit append, auto-resume selection checkbox, Clear waiting preserving current actions, Stop not auto-resuming, and 1280×720 combat/worker panel bounds. Rendered screenshots inspected.
- Existing `ProgramRegression.gd`, `CoordinationRegression.gd`, `NavigationRegression.gd`, `Skirmish.gd` and rendered `ProgramPreview.gd` pass. These cover direct/program authority, factory rally precedence, chip/research workflows, harvesting/navigation, all faction pairings, production and AI.
- GDScript format/lint and whitespace checks pass for changed scripts.

The existing headless navigation GPU-readback warning and shutdown resource/RID diagnostics remain. No passing scenario is used to claim complete squad automation, Lua, campaign, save/load or stable 60 FPS. This pass does not remeasure the 200-unit benchmark. Explicit squads/shared state/target claims and remaining roadmap stages are still pending.

## Review

- [Paused order queue](../../../art/skirmish/orders-paused-720p.png)
- [Active route](../../../art/skirmish/orders-active-720p.png)
- [Worker controls](../../../art/skirmish/orders-worker-720p.png)

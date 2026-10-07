# Guard endpoint arrival — 2026-10-06

A saved Alpine guard could finish navigation just outside Guard's one-metre arrival threshold, repeatedly request the same completed trip, and report Blocked after five seconds. The shared Guard action now accepts a tightly bounded, clear completed endpoint and remembers a stationary hold across archive reloads.

## Reproduction and change

The earned [stall archive](regional-recovery/stall0.json) contains Frontier tank `unit-11` at `(16.80818, 0, 26.79615)` guarding `(17.5, 0, 26)`, beside a factory. Navigation ends at approximately `(17.1, 0.6, 26.4)`. The tank is about 1.05 m from its assignment and 0.49 m from that final path point. Its path tolerance is 0.5 m. Navigation reports finished while the old Guard check rejects arrival. Removing all other mobile units preserves this failure, isolating it from traffic pressure.

`PresetAction.gd` now requires the current action destination and navigation target to match the assignment, completed navigation, an endpoint within one metre of the assignment, and the tank within the lesser of its path tolerance or 0.5 m of that endpoint. The unit must remain inside its assigned radius, on the ground, and connected to the clear assignment by an unobstructed line. A settled hold remains valid only beside its recorded position; existing saved progress position supplies that record, without an archive-format change. Formation, ordinary movement and the five-second no-progress safeguard remain in place.

## Verification

Running the finalized endpoint fixture against the [original implementation](guard-endpoint/original-verified-fixture.log) produces six assertions across all three controlled forms: each becomes Blocked and fails to settle. The fixed implementation passes the same fixture. Source copies, logs and captures are indexed by [SHA256.json](guard-endpoint/SHA256.json).

- `GuardEndpointRegression`: the unchanged earned archive stays Blocked while paused, accepts explicit Resume and remains Running through twelve seconds with live AI. It may continue moving under traffic; this does not certify long-term crowd stability.
- Three controlled Frontier cases preserve the earned map/buildings while removing mobile traffic. Preset, Lua and visual forms settle at the original position, retain their assigned area, remain settled after a real disk save/reload, attack a nearby enemy, and yield to a manual movement order.
- Bounds reject unrelated action/navigation targets, insufficient path tolerance, displaced holds, too-small guard areas and structure centers.
- `GuardArrivalRegression`: seven earlier earned guard captures, Bastion/Helix formations in all three authoring forms, late arrival at the timeout boundary, archives, combat, manual movement and enemy/moving/air/obstruction bounds pass.
- `BlockedAssignmentRegression`, `AuthoredGuardRegression`, and `GuardAreaRegression` pass. All five accepted headless suites exit zero without script or parse errors.
- `GuardEndpointPreview` passes with seven 1280×720 / 150% captures: earned live state, and each controlled form before/after restoration. These are rendered harness checks; no physical native-input claim is made.

Accepted logs: [endpoint](guard-endpoint/final-GuardEndpointRegression.log), [formation](guard-endpoint/verified-GuardArrivalRegression.log), [blocked assignments](guard-endpoint/final-BlockedAssignmentRegression.log), [authored guard](guard-endpoint/final-AuthoredGuardRegression.log), [guard area](guard-endpoint/final-GuardAreaRegression.log), [rendered](guard-endpoint/render.log). [Restored Lua guard](guard-endpoint/render-frontier-lua-restored.png) shows Running / Watching assigned area. Existing navigation-readback and shutdown resource/RID diagnostics remain.

## Retained investigation history

Exploratory faction-swapped archives had inconsistent faction/HP data; a fresh-map replacement did not preserve the endpoint. Those failed fixture logs are retained but are not accepted evidence. Final endpoint coverage uses the authentic Frontier archive; the existing shared suite supplies Bastion/Helix coverage. An initial shared test found stale arrival reuse after displacement and led to the stationary-position check. A later run exposed an older test race: it sampled an enemy's health after guards could already kill it. Sampling initial health before simulation fixes that fixture without weakening its damage/death assertion. The interrupted cascading-error log is retained compressed; its corrected rerun passes.

The separate [control-rendering correction](CONTROL_RENDERING.md) disproves the earlier clipping diagnosis. No shipping layout or balance adjustment follows from this slice. Broader strategy, novice/content/platform acceptance remain open; performance work stays deferred.

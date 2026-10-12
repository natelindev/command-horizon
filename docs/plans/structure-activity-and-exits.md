# Structure activity and production departures

## Stage 1: Visible structure activity
Show construction, production, research, blocked/low-power, and idle states on structures. Animate appropriate machinery, working lights and construction scaffolds without moving building foundations.

## Stage 2: Production departures
Use the final part of each existing paid production job for a visible departure: infantry run from a doorway, ground units drive from the assembly bay, and aircraft lift from the pad. Spawn the controllable unit at the departure endpoint, then preserve factory programs and rally orders. Keep exits clear and retain paid jobs when an exit is blocked. Restore departures from queue progress and the saved exit endpoint.

## Stage 3: Verification
Verify all factions and producer types, research and construction transitions, queue cancellation, low power, pause, blocked exits, completion counts, factory programs/rally handoff, and save/restore. Render active structures and record infantry/vehicle/aircraft departures.

## Agent progress
- Inspection complete: construction has a partial-build shader, but completed structures lack a shared activity presentation. Production currently creates units at arbitrary radial positions. Research is player-wide and continues at any surviving completed lab.
- Implementation approach: departures use the final portion of the existing production timer, with a cosmetic model inside the producer until handoff. This preserves paid jobs, population reservations, existing production durations, and save compatibility.
- User refinement: remove all floating progress labels and bars; activity is communicated by the structure’s lights, sensors, machinery, scaffolding, and doors.
- Stages 1–3 complete. Every faction’s structures now share construction scaffolding and working lights; labs animate their authored SensorPivot/RadarPivot, factories move their assembly head, and production doors slide open for departures. There are no floating activity labels or progress bars.
- Ground and air departures retain paid queue reservations until the visible model hands off at the same position to the live unit. Blocked exits wait, cancellation refunds once, and low power slows the animation with production.
- Save version 12 retains the chosen exit endpoint, including blocked mid-departure saves; versions 1–11 remain readable. Paused restoration reconstructs the model and open doors before play resumes.
- Verification complete: 13 regression suites passed, focused GDScript lint passed, Godot editor import succeeded, and all three factions were visually reviewed. Preview and detailed evidence are in `docs/playtests/2026-10-11/structure-activity/`.

- Lighting refinement: removed the repeated flashing row and the bright tool-tip cube. Small shaded fixtures now mount on door lintels, assembly carriages, sensor supports, pad surfaces, and scaffold rails; warm illumination fades on/off and remains steady while working. The all-faction activity regression now checks steady brightness and gradual shutdown.

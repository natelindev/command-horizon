# Premium battle controls and frame pacing

## Stage 1 — Audit and complete existing Stage 5 work
Verify prepaid research queues, bilingual commander roster, and loading/restore shader prewarm integration. Repair any gaps exposed by focused regressions.

## Stage 2 — Camera and command feedback
Add frame-independent pan acceleration/damping, middle-button map grabbing, Alt + middle-button rotation, and terrain-following formation/facing feedback with safe cancellation.

## Stage 3 — Four-player query and minimap pacing
Measure and optimize the existing spatial grids, cover ownership/topology/movement correctness, and distribute minimap marker updates across frames. Measure four-owner queries against the requested 0.5 ms target.

## Stage 4 — Combat presentation and verification
Add bounded muzzle lights, directional armor ricochets, and terrain-projected command rings. Verify accessibility/pause/visibility, rendered presentation, gameplay regressions, formatting, and measured limits.

## Agent progress

- Repository audit: clean working tree. Research queues, roster localization, combat prewarm and fine/coarse spatial grids already exist; verify and extend these paths.

- Stage 1: prepaid queue, research tiles/economy/feedback, commander elimination and localization regressions pass. Rendered prewarm exposed idle-window draw waits and phased minimap initialization after restore; explicit preparation draws and a full initial marker sync fix both. Full loading/restore/cancellation and process-mode preservation now pass.
- Stage 2: exact exponential pan integration, MMB ground grabbing, Alt + MMB orbit/reset, focus/modal/teleport cancellation, terrain ribbons/facing slots and accepted-order rings implemented. Camera cadence and battle feedback regressions pass; six ramp/armor captures pass across all factions.
- Stage 3: shared owner-independent body grids and live ownership filtering implemented. Native release: 200 dispersed local queries improve from 1.269 ms median / 1.355 ms p95 to 0.426–0.431 ms / 0.452–0.461 ms; grid rebuild costs 0.294–0.295 ms separately. Dense queries remain above 0.5 ms (0.783 ms median), and the full four-player sample remains below 60 FPS on M1 Pro. No Windows timing claim is made.
- Stage 4: pooled unshadowed muzzle lights, reflected armor spark fans and accessibility cleanup implemented. All 20 final focused headless suites pass, as do six bilingual research cases, the three-faction bilingual commander matrix and six formation/armor captures. Formatting/lint and the test PCK export pass. Evidence and explicit performance limits are recorded in `docs/playtests/2026-10-24/premium-battle/README.md`.

- Delivery complete for the requested controls, feedback and integration changes. The dispersed release query batch meets 0.5 ms; dense queries, end-to-end four-player 60 FPS and native Windows timing remain open acceptance limits. Existing intermittent crowd-navigation and shutdown warnings are documented, with final current navigation runs passing.

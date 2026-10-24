# Release v0.17.0

## Stage 1 — Prepare and push
Commit all pending battle controls, feedback, research/commander verification, shader prewarm, localization, regression tests and evidence. Update desktop version metadata to 0.17.0. Verify formatting, lint and whitespace, then push main without rewriting history.

## Stage 2 — Verify native packages
Dispatch the existing release workflow from main. Require native Linux, Windows and macOS startup and every packaged regression to pass. Resolve any failures before publication.

## Stage 3 — Publish and verify
Download the verified packages, check archive integrity and embedded version metadata, and generate SHA-256 checksums. Publish v0.17.0 at the verified commit with notes and all desktop packages. Verify remote tag, asset digests and main. Cancel the redundant tag build to preserve the verified archives.

## Agent progress

- Preparing release 0.17.0. Focused implementation checks already pass; detailed measurements and limits are in docs/playtests/2026-10-24/premium-battle/README.md. Dense-query and rendered Windows performance acceptance remain open; native headless CI is not a rendered performance test.

- Stage 1 complete: all pending changes committed as f30c9004 and pushed to main. Local formatting/lint/whitespace and GitHub static checks pass. Native verification run 40086867951 is testing 78 packaged suites on each desktop platform before publication.
- Initial Windows verification exited with access violation 0xC0000005 after InfantryDeathGroundRegression reported all 72 scenarios passing. The same suite passes locally on macOS. Publication is held; awaiting remaining platform results and a fresh Windows rerun before deciding whether a code correction is required.
- Initial macOS verification reached MixedArmyMovementRegression, then one Worker stalled during retreat through allies (19/20 arrivals). This intermittent behavior was already reproduced on the original implementation during the earlier audit. Added failure-only state/archive capture; reproducing locally before choosing a correction.
- Initial Linux executable startup and all 78 packaged suites passed; upload failed because GitHub Actions artifact storage quota was exhausted. The fresh diagnostic matrix (40088121317 at 252ea14f) could not start any job: GitHub reports an Actions budget is preventing further use. Asked the user to enable the allowance or choose a source-only release; no spending settings or existing artifacts were changed.
- Exported mixed-army trial 6 reproduced the worker stall and captured its complete format-19 snapshot. A focused layout from that archive fails before the correction and passes after rebuilding the navigation path at the end of a ground-recovery detour. No movement speed, collision or arrival tolerance was widened. Broader verification is running; native Windows exit-crash reproduction remains blocked by Actions allowance.
- Ground-recovery correction verified: all nine follow-up source checks pass, including original-layout negative/positive controls, navigation, mixed armies, vehicle motion, contact, save restoration and map passages. The exported pack passes the focused crowd check and six consecutive mixed-army runs. Formatting and lint pass for all 406 source scripts. Preparing a draft while native final-platform verification remains blocked by GitHub Actions allowance/storage.
- All source and evidence pushed in e98a0aaa. Created the v0.17.0 draft at that exact verified local-source commit: https://github.com/natelindev/copperfin/releases/tag/untagged-f14ecb461048a09b0dc5. It has no desktop assets and is not published. Even the latest static-check run (40089128986) was blocked before starting by the Actions budget. Final evidence is in docs/campaign/release-v0.17.0.json. Publication awaits restored allowance or the user's source-only choice; no Windows crash fix or complete native matrix is claimed.

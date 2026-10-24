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

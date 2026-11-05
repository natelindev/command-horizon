# CI repair and main publication

## Stage 1: Preserve and synchronize
Commit the completed campaign, voice and HUD fixes and incorporate remote main.

## Stage 2: Repair checks
Reproduce formatting/lint failures and the clean release import. Fix their causes without weakening checks. Retain release failure evidence in GitHub Actions.

## Stage 3: Verify and publish
Run relevant local checks, push main, and verify the new GitHub runs.

## Agent progress
- Campaign changes committed and rebased onto the newer remote main commit.
- Static CI fails formatting; release CI fails clean import with missing detailed logs.
- Formatting and lint now pass for all 518 source scripts. Existing runtime-load and guard-clause conventions have documented local lint exceptions.
- Reproduced the custom-font startup failure on a clean import; the staged bootstrap and restored-settings import both pass with strict diagnostics.
- All 24 release-runner unit tests pass, including bootstrap failure/restoration tests.
- Release workflows retain failure logs and support explicit headless manual verification.
- Main pushed; GitHub static checks passed: https://github.com/natelindev/copperfin/actions/runs/42058112118
- The first remote release verification exposed missing generated translations in addition to the startup font. Bootstrap coverage now includes both settings; 25 release-runner tests pass.
- The fully uncached font/translation import now passes both strict passes. Serializing the bootstrap avoids a reproduced native crash in parallel CSV generation.
- The updated static workflow is green: https://github.com/natelindev/copperfin/actions/runs/42059136865
- Cross-platform headless release verification is running: https://github.com/natelindev/copperfin/actions/runs/42059143382
- Windows verification reached native combat tests and exposed an inherited fixture signature mismatch. The fixture now accepts the parent's optional map argument while keeping its terrain-test default.
- Native combat comparisons then reproduced bypassed power-grid and harvester eligibility. Native firing now applies the shared eligibility rules; both query modes pass 7,299 comparisons each using a freshly built native library.
- All 140 packaged regression scripts compile locally. The 25 release-runner unit tests and changed-file formatting/lint checks pass.
- The user has authorized full graphical release verification, both remotely and locally.
- The macOS packaged sweep completed all 162 checks and exposed repeated shutdown leaks plus stale portrait/mist expectations and a hover test sampling before the first resumed physics step. Corrected portrait, volumetric/fallback mist, and completed-step hover checks pass locally.
- The actual OpenGL resource-lifetime check passes with all six temporary scene instances freed.
- Focused clean-runner shutdown diagnostics are running on an isolated diagnostic branch. Release job/step budgets now leave time to finish the complete platform sweep and retain evidence.
- Audio shutdown now waits for started playback references to drain, bounded for unavailable devices. Repeated packaged macOS startup/roster runs and the explicit shutdown regression pass on GitHub.
- Linux three-player failures were caused by ENet dropping clients during roughly eleven seconds of synchronous battlefield initialization. Bounded loading timeouts and an initial-frame readiness handshake restore ordinary match timeouts after setup; the focused Linux 2v2/dedicated checks pass.
- Network fixtures now synchronize pause acknowledgement and replica readiness rather than relying on short timing windows; the runner caps idle peer frame rates. All 20 local multiplayer/replay checks pass, including a deliberately stalled loading client.
- Recorded five-body and seven-body crowd deadlocks are permanent regressions. Recovery continues around blocked path corners, and a zero avoidance result cannot cancel a collision-constrained escape. Both script and rebuilt native backends pass the complete mixed-army suite, captured failures, and existing crowd collision/speed checks.
- Infantry firing-priority verification now samples completed frames and distinguishes approaching units from settled shooters; all three factions pass.
- Full Linux graphical verification exposed the runner's absent ALSA device. Xvfb checks explicitly select silent audio while still requiring actual OpenGL; all 26 release-runner tests pass.
- The full local static checks pass for all 518 source scripts. Five network-runner tests pass; a one-second subprocess startup test was rerun successfully after concurrent runtime checks completed.
- Main commit f8d14671 contains the verified fixes. The next release is v0.17.1; application/export/native metadata is aligned while preserving the older v0.17.0 draft and tag. Full release qualification runs on the versioned commit.

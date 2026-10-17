# Release 0.13.1

## Stage 1 — Prepare all local changes

Include the entire non-ignored working tree: battlefield expansion, four-player
skirmishes, garrison/refinery feedback, worker cargo, performance, distribution,
regressions and review artifacts. Update release versions and changelog, run
static checks and verify the exported macOS package with the expanded smoke suite.

## Stage 2 — Commit and push

Commit all local changes, push main without rewriting history, and require the
repository static checks to pass on the release commit.

## Stage 3 — Build, publish and verify

Tag the verified fix as v0.13.1. Monitor native Linux, macOS and Windows builds
and packaged regressions, publish focused release notes, then download and verify
all published packages and their checksums. Record final release evidence.

## Agent progress

- User explicitly authorized committing all local changes and creating a release.
- Confirmed main and origin/main match at f60bca94 and v0.12.0 is the latest release.
- Selected v0.13.0 for thirteen additional battlefields and four-player skirmishes.
- All 377 shipping GDScript files pass formatting and lint. Existing map, HUD,
  garrison, cargo and performance verification records reviewed.
- Updated app/package versions and changelog. Added packaged release checks for
  worker distribution, cargo, field capacity, garrison exits, facilities, map
  connectivity/save compatibility and opening economy.
- Local macOS release export, packaged startup, and all fourteen packaged
  regressions pass without script errors. Verified 0.13.0 bundle metadata,
  Intel/Apple Silicon executable slices and the ad-hoc signature.
- Committed every local change as 07bdff6d and pushed main. Static CI passed.
- The v0.13.0 candidate passed macOS CI, but the new larger-map restore checks
  failed on Linux/Windows: 300 accelerated frames could expire before asynchronous
  navigation completed. Publication was correctly skipped.
- Replaced the frame-count timeout with a ten-second wall-time deadline, retained
  terrain/agent readiness checks, and added a deterministic delayed-sync regression.
  Preparing v0.13.1 while retaining the unpublished v0.13.0 tag unchanged.
- The delayed-sync regression fails against the candidate's original code and
  passes with the fix. The fresh 0.13.1 macOS export/startup and seven focused
  packaged checks pass, including larger-map restore, worker/cargo, ownership
  and both campaign suites. Bundle metadata/signature and changed-script lint pass.
- Committed the navigation fix and regression as 1008c682, pushed main, and
  passed static CI. Tagged the fix as v0.13.1 without changing v0.13.0.
- Release workflow 39006377541 passed on native Linux, macOS and Windows runners:
  packaged startup and all fifteen packaged regression checks passed per platform.
- Published v0.13.1 as the latest release with all three desktop packages and
  focused release notes. Downloaded each archive, checked its integrity and
  SHA-256 digest against GitHub, and uploaded SHA256SUMS.txt.
- Recorded platform results, archive digests and remaining verification limits in
  docs/campaign/release-v0.13.1.json. Release preparation and publication are complete.

# Release 0.13.0

## Stage 1 — Prepare all local changes

Include the entire non-ignored working tree: battlefield expansion, four-player
skirmishes, garrison/refinery feedback, worker cargo, performance, distribution,
regressions and review artifacts. Update release versions and changelog, run
static checks and verify the exported macOS package with the expanded smoke suite.

## Stage 2 — Commit and push

Commit all local changes, push main without rewriting history, and require the
repository static checks to pass on the release commit.

## Stage 3 — Build, publish and verify

Tag the verified commit as v0.13.0. Monitor native Linux, macOS and Windows builds
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

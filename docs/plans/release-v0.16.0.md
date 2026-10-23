# Release v0.16.0

## Stage 1 — Prepare
Inspect the changes since v0.15.1, correct static-check failures, update desktop
versions and changelog, and include the new gameplay regressions in packaging.

## Stage 2 — Verify and push
Run formatting, lint, launcher tests, and focused Godot regressions. Commit all
release changes and push main and the new release tag.

## Stage 3 — Publish
Monitor native Linux, Windows, and macOS exports and packaged regressions. Verify
the published assets and update the release with focused notes.

## Agent progress
- The user authorized committing and pushing everything local and creating a release.
- The working tree was clean at daf22d79; main already matched origin/main.
- v0.15.1 was the latest release. Selected v0.16.0 for the infantry/walker and
  air-combat updates. Existing CI failures were seven lint issues in the new
  infantry code; corrected declaration order and long chained assignments.
- Updated application/package versions, changelog, and release packaging to run
  twelve additional regression suites (57 total).
- Formatting and lint pass for all 396 source scripts; all five macOS launcher
  tests pass. Godot 4.7.2 imports the project without script errors. Focused
  infantry, animation, terrain, and AA-priority regressions pass. Research and
  combat regressions are running before the release tag is pushed.

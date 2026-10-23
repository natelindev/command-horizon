# Release v0.16.1

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
- All eleven focused local Godot suites pass, including research, weapon modes,
  research tiles, and combat. Release preparation is committed as 6aef5819 and
  pushed to main; GitHub static checks pass. Tag v0.16.0 is pushed and native
  packaging is running in GitHub Actions run 39934344216.
- v0.16.0 macOS packaging caught an existing nondeterministic spacing assertion:
  one Helix soldier at 5.949 m failed the 6 m cutoff while all eight fired. Five
  local repeats showed runner-dependent spacing. The test now requires at least
  six soldiers beyond 6 m and every soldier beyond 5.5 m. An isolated exported
  PCK passes; disabling stationary-shooter priority reproduces the old 5.0–5.45 m
  collapse and is rejected by the revised spacing checks. No gameplay change.
- Selected v0.16.1 for publication, retaining the failed v0.16.0 candidate tag.

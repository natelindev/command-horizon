# Release v0.16.2

## Stage 1 — Prepare
Inspect the changes since v0.15.1, correct static-check failures, update desktop
versions and changelog, and include the new gameplay regressions in packaging.

## Stage 2 — Verify and push
Run formatting, lint, launcher tests, and focused Godot regressions. Commit all
release changes and push main for a native verification build.

## Stage 3 — Publish
Monitor native Linux, Windows, and macOS exports and packaged regressions.
After all pass, publish those verified artifacts as v0.16.2 and verify the
published archives, package version, and checksums.

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
- The earlier candidate Linux run later exposed intermittent Railspire ramp
  deadlocks. Reproduced locally on the third repeated run, affecting both
  overpass approaches. Widened both ramps to 12 m; all eight repeated runs then
  passed. Added three passage trials for Railspire in the packaged regression.
  TerrainLayersPreview ran without headless mode and reported zero failures.
- Stopped v0.16.1 publication while investigating the crossing bug. Selected
  v0.16.2 and will verify a main-branch dispatch build before creating its tag.
- The full map-passage suite passes with three traffic trials per Railspire ramp.
  The standard terrain preview and a focused ramp view both pass without
  headless mode; inspected both widened approaches. Formatting, lint, and diff
  whitespace checks pass. Preparing the verified-build dispatch from main.
- The first v0.16.2 dispatch caught a stale baked Railspire map-picker preview
  after the ramp edit. Regenerated it with tools/ui/bake_map_previews.gd and
  verified all sixteen cached previews against freshly generated terrain.
  Retained only the changed Railspire artifact; stopped the superseded build.
- Further Linux validation still failed the passage check. Instrumented local
  failures showed all six tanks had crossed and completed their orders; later
  crowd avoidance displaced arrivals, so the test incorrectly demanded all six
  remain near their goals simultaneously. Record each crossing independently
  while retaining the time and detour bounds. Restored the original ramp widths
  and baked preview to keep the release focused on the verified test correction.
- The corrected test passes eight runs on the original ramp layout, three
  trials per approach. A frozen first tank is correctly rejected with only
  five crossings recorded. Full passage and all-sixteen-preview regressions
  pass; final rendered ramp review passes. The previous native macOS and
  Windows jobs completed all 57 suites; Linux's false simultaneous-arrival
  assertion is the remaining correction for the new verification build.

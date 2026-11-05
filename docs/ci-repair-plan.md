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
- Main push and GitHub verification pending.

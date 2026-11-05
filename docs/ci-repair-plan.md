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
- A publishable release requires graphical checks; remote graphical verification is awaiting clarification of the earlier headless-only instruction. Headless release retries remain authorized.

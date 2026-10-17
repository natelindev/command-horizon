# Release 0.12.0

## Stage 1 — Prepare

Review the completed performance/gameplay/UI changes, update package versions and
changelog, and verify formatting/lint plus the desktop release smoke tests.

## Stage 2 — Push main

Commit the reviewed changes, synchronize with origin, push main without rewriting
history, and wait for the repository static checks.

## Stage 3 — Build and publish

Tag the verified main commit as v0.12.0. Monitor the native Windows/macOS/Linux
release jobs and packaged smoke tests. Resolve failures before publishing complete
packages, then publish focused release notes and verify uploaded assets.

## Agent progress

- Confirmed local main matches origin/main at 31aadfca before the release changes.
- Confirmed v0.11.0 is the latest published release. Chose v0.12.0 for the gameplay
  redesign and performance work.
- Existing tag workflow builds/tests all three desktop platforms and publishes only
  after every platform passes. GitHub CLI authentication is available through Keychain.
- Local macOS export starts successfully and passes all seven packaged release
  regressions. Bundle versions are 0.12.0; formatting/lint checks pass. An outdated
  behavior-test assertion for the removed Battle plan panel was corrected before
  the successful packaged run.
- Pushed the release implementation to main as ff9c391b. GitHub static checks pass.
- Tagged v0.12.0. All three native desktop CI jobs and seven packaged checks per
  platform pass; publication completed successfully.
- Downloaded all three published packages, verified archive integrity and SHA-256
  digests, and attached SHA256SUMS.txt. Published focused release notes and confirmed
  v0.12.0 is the latest release. Details are in release-v0.12.0.json.

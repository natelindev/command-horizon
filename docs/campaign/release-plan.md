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

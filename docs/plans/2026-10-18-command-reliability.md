# Command reliability fixes

## Stage 1 — Reproduce and isolate

Reproduce Defensive combat save rejection, garrison Hold Fire violations, and
stationary-leader Follow recovery. Trace player input, manual order replacement,
worker assignments, and navigation to isolate ignored mining/build/move commands.

## Stage 2 — Implement and protect

Make focused fixes and add regression scenarios covering actual command execution,
replacement, pause, and save/load where applicable. Preserve queued-order semantics
and explicit attack authority.

## Stage 3 — Verify

Run the new regressions and relevant existing behavior, selection, direct-order,
construction, harvesting, navigation, and garrison tests. Exercise rendered input
flows where practical. Record results and any remaining limitations.

## Agent progress

- Initial review reproduced all three reported code defects with headless probes.
- Reproduced another command defect: a production exit sidestep retained control
  after an explicit replacement Move. The worker moved away from its new goal
  (distance increased from 8 m to 11.08 m in one simulated second).
- Reproduced the main input conflict: the command card handled camera keys as
  hidden grid shortcuts. Pressing W immediately erased an accepted Move order;
  E also issued Hold, and Q/A/D could arm unwanted commands. Removed those
  aliases and made badges use the existing configurable M/F/T bindings.
- Repaired Reverse to submit a backwards move through the manual queue rather
  than assigning a Dictionary to `Unit.action`. Repaired double control-group
  recall to pass an iterable unit list to camera centering.
- Fixed Defensive save validation, stationary-leader Follow recovery, and automatic
  garrison targeting under Hold Fire. Explicit garrison attacks remain available.
- Replacement/Stop commands now cancel exit clearance, and production does not
  redirect units actively travelling under manual orders. Idle clearance and
  queued-order semantics are retained.
- Added `BehaviorReliabilityRegression.gd` and `CommandReliabilityRegression.gd`.
  Both pass headlessly, including all three factions and actual mouse dispatch
  for mining, construction, paused replacement, queued movement, and Stop.
- Existing behavior, direct-order, navigation, contact-approach, exit-clearance,
  and Industrial Crossroads garrison combat/exit regressions pass. Changed files
  pass formatting and lint checks.
- Worker distribution/delivery and selection batching pass. Extended command
  coverage verifies camera keys leave Gather/Build/Move intact, remapped keys and
  badges agree, and Reverse/Stop work. Key binding tests now verify double group
  recall; fixed the older UI test's unnamed Selection fixture.
- Reviewed generated Bastion, Helix, and Frontier HUD captures: M/F/T badges are
  readable, and Stop/Hold/Reverse no longer advertise conflicting camera keys.
- Final rendered command tests pass for all three factions, including camera
  shortcuts during mining/building/movement, remapping, Reverse, and Stop.
  `HudConsolePreview.gd` completed all faction captures in English and Chinese
  with zero failures. Godot import, changed-file formatting/lint, and whitespace
  checks pass.
- Verification is targeted rather than the entire historical test suite. Godot
  still emits shutdown resource/instance leak warnings also seen in baseline
  runs; no gameplay script errors remain in the verified scenarios.
- All three stages are complete; no release build or commit was requested.

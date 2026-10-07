# Preserve replacement rally orders

Changing a producer's rally from target A to target B previously kept the target-loss listener attached to A. Depleting A erased B's order and attempted to disconnect a nonexistent signal; destroying B left a freed reference and the marker at B's former position. The actual pre-fix all-faction reproduction fails nine assertions, with three disconnect errors.

`RallyPoint.gd` now disconnects the previous target before connecting its replacement. Repeating the same target is a no-op. Losing the current target clears the reference, resets the marker to its producer and respects selection visibility. Reset uses local zero, which also works during scene teardown. Reapplying a null target leaves a saved explicit point unchanged. This is the sole shipping-script change from the preceding guard-response baseline; no archive schema change is needed.

## Gameplay verification

Five final headless suites pass: RallyRetargetRegression, CoordinationRegression, LuaAuthoringRegression, SaveRestoreRegression and SaveRestoreEdges. The shared suites cover factory program pins, exact queued Lua versions, rally/manual authority and archive compatibility. Formatting and lint pass.

The new regression covers Bastion, Helix and Frontier on Standard-start Industrial Crossroads:

- Retarget HQ from one friendly engineer to another, repeat the assignment, resume to verify marker tracking, then destroy the current target. It clears the reference and resets the selected marker.
- Issue an explicit point rally, destroy the formerly assigned engineer, save to disk and reload. The exact accepted destination and paused clock survive; deselection hides the marker.
- Retarget HQ from a nearby material deposit to electronics, then deplete the old material deposit. The electronics assignment survives.
- Spend ordinary starting funds on one engineer, advance the normal production timer by one second, save to disk and reload while paused. Funds, remaining production time and rally target identity are unchanged.
- Resume without replacing any orders. Exactly one engineer is trained and delivers four electronics, with no material delivery, in 22.02 / 21.37 / 21.62 simulation seconds after the saved point. Depleting the restored current target clears the rally normally.

Production, travel, collection and return use ordinary rules and unmodified starting funds. Target deaths/depletion are deliberately injected, and strategic controllers are disabled. These checks establish order reliability and actual delivery, not contested economy or balance acceptance.

## Rendered input

The final Helix rendered run passes six engine-injected right-clicks at 1280×720 and 150% UI scale: friendly-target replacement/repetition, point rally and material-to-electronics replacement. Five captures were inspected: target loss, restored point, replacement resource, restored production and completed delivery. Panels remain readable and within the viewport; the paid queue resumes and electronics increase from 12 to 16. The rendered engineer returns its first load 23.43 simulation seconds after the saved point. HQ selection and production submission are fixture-driven; this is not a physical-device or novice trial.

## Evidence and retained development failures

`rally-retarget/run-index.json` classifies twelve Godot runs. Historical control uses the actual preceding RallyPoint source in an isolated project, with matching shipping hashes apart from the final one-file correction. That control fails the same nine acceptance assertions; it skips paid delivery once the replacement rally has already been lost.

The first reproduction's `== null` check did not distinguish a freed Godot object from a cleared reference, and its paused marker had not yet followed the unit. Its six failures supplied partial evidence only. The strengthened reproduction checks the Variant type and allows normal marker tracking before loss.

The first implementation passed its then-current gameplay assertions but emitted six out-of-tree transform errors during teardown. It also reset a saved point on redundant null assignment, caught during source review. Both issues were corrected before the shared suites and explicit point archive test. Its source/logs are retained; its zero exit code is not final acceptance.

The first rendered test compared an ideal world coordinate with the slightly rounded raycast result, reporting two false point-preservation failures despite successful input and delivery. The corrected runner checks click proximity, captures the actual accepted destination, and then requires exact preservation through death and disk reload. Both rendered sets remain in the evidence directory.

Final accepted runs have no script/parse errors, signal-disconnect errors or out-of-tree transform errors. Existing navigation mesh readback warnings and shutdown ObjectDB/resource/shader/RID diagnostics remain. Source snapshots, logs, images, the 288-script fingerprint and SHA-256 inventory accompany this report.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/RallyRetargetRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/RallyRetargetPreview.gd -- --captures=/tmp/rally-review
```

Use a fresh capture prefix to preserve earlier evidence. Sustained Industrial home defense, protected income through later raids, broader environment/novice/platform acceptance and deferred performance remain open. The overall goal stays active.

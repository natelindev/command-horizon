# Preserve service-building retreat assignments

Safe-point input again accepts a completed friendly facility that can service the selected ground unit. The preceding assignment-footprint change incorrectly rejected every owned building, including this explicitly supported recovery destination. That was a regression in input validation; existing healing and program execution still supported the assignment when set directly.

Only `SkirmishHUD.gd` changes in shipping code. The safe-point exception uses `RepairService.facility_eligible`, the same ownership, completion, life and role checks used by recovery. An unfinished or unsuitable owned building still rejects the ground safe point. Guard and patrol points retain their footprint restrictions. Air-only point assignments retain their previous freedom to fly above buildings. Mixed selections are still checked before any program mutation, with eligibility evaluated per ground unit.

The invalid-safe-point hint now asks for open ground or a completed repair facility. Assignment itself neither heals nor resumes the program: health, position, funds, clock, anchor and authored source stay unchanged. Explicit Resume starts ordinary retreat, bounded service and program-controlled return. Facility range, rates, capacity, movement, thresholds and save fields are unchanged.

## Reproduction and verification

The corrected pre-fix eligibility runner fails **36 valid service assignments**: four ground roles × three factions × preset/Lua/visual modes. The eighteen aircraft combinations already pass. The new test enters through `arm_program_assignment` and `accept_program_assignment`; older facility-recovery tests assigned `program.safe_point` directly, which is why they did not cover this UI regression.

The final full runner passes **54 actual recovery cases**:

- Bastion, Helix and Frontier.
- Tank, AdvancedTank, CombatRobot, RepairRobot, Drone and Helicopter.
- Built-in preset, authored Lua and visual rules.

Each case starts at 35% health, assigns the matching service through the HUD, explicitly resumes, reaches real healing, passes the 85% recovery threshold and returns within three metres of its original assignment within forty simulation seconds. No case reports Blocked. These fixtures create units/facilities for isolated verification; they are not paid match progression evidence.

Nine Tank cases perform a real disk save/load during partial healing, one per faction/mode. Paused health, position, funds, clock, anchor, safe point, source and program status match exactly. After resuming, each continues healing and returns. Ground guard/patrol points on the service remain rejected, as do retreat points in foundations or the non-healing HQ; rejection preserves authority.

Five final headless suites pass:

- ServiceAssignmentRegression
- AssignmentFootprintRegression
- DirectOrdersRegression
- ProgramRecoveryFeedbackRegression
- PresetRecoveryCrowdRegression

The shared suites retain blocked-point and mixed-selection behavior, manual queues and running-program authority, command controls, missing/mobile support feedback and the two-channel crowded recovery limit.

The final rendered Helix run passes all three authoring modes and **eight engine-injected map clicks**, including guard/patrol rejection, incomplete/unsuitable service rejection and the completed service assignment. All **ten final 1280×720 / 150% UI-scale captures** were inspected. The revised camera framing keeps both the service building and recovering/returning unit visible beside the selection panel. Feedback and status text remain readable. Selection, arming and Resume are programmatic; native OS input is not claimed.

Formatting and lint pass. Accepted runs have no script/parse errors; existing runtime navigation-readback warnings and shutdown ObjectDB/resource/RID diagnostics remain.

## Retained development evidence

The first new SceneTree test referenced the Constants autoload directly, causing dependent scripts to compile before autoload initialization. Godot misleadingly exited zero after extensive script errors. That run is rejected and retained as `early-autoload.log`, with its source. The fixture now resolves Constants through the initialized root at runtime. The corrected original-code run exits one with the expected 36 eligibility failures and no script errors.

The first rendered run passes behavior checks but places the healing unit partly beneath the selection panel. Its source, log and ten captures remain intermediate evidence. The final framing was rerun, and all ten replacement captures were reviewed. No shipping behavior or test deadline changed for that visual adjustment.

Source versions, logs, visual-review metadata, fingerprints and hashes are in `service-assignment/`. Reproduce:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/ServiceAssignmentRegression.gd
```

Add `-- --eligibility-only` to isolate input validation. Use `tests/rendered/ServiceAssignmentPreview.gd` without `--headless`, passing a new `--captures=res://tmp/service-review` prefix, for rendered review.

## Industrial follow-up

The retained ordinary-recovery trial loses HQ at 566.62 seconds. Its 600.7-second sample and final record have 47 M / 3 E, below the current Helix HQ price of 80 M / 20 E; remaining production queues are empty. Surviving engineers and army therefore do not establish an affordable rebuild. The reference opening's base economy also does not currently prioritize HQ reconstruction. This read-only finding does not prove the complete recovery UI or justify a balance change. A funded earned-state reconstruction check remains follow-up work.

The compatibility regression is repaired. Sustained Industrial defense/progression, later construction obstructing existing assignments, broader content/novice/platform acceptance and general congestion remain open. Performance remains deferred.

# Explicit producer rally controls

A selected HQ previously offered **Stop current orders**, which left its rally unchanged. Its panel did not describe the destination. The original all-faction control reproduces both gaps with 24 failed assertions.

Completed producers now display a compact rally status: At producer, Map destination, Materials, Electronics, Salvage or the friendly target's faction-specific name. Their single-selection action is **Clear rally**, disabled when no destination is assigned. Its tooltip explains that paid production and existing unit commands continue, and that right-click sets a new destination. It uses the existing styled button, focus handling and accessibility description; no extra panel or decorative border was added.

Clearing releases the target and resets the point to the producer. It does not cancel jobs, refund resources, stop existing units or alter pinned programs. Mixed-selection Stop and foundation cancellation retain their existing meaning. UnitMenus.gd and RallyPoint.gd are the only shipping-script changes from the preceding rally-retarget baseline.

## Verification

Five final headless suites pass: RallyControlsRegression, RallyRetargetRegression, ConstructionContractRegression, DirectOrdersRegression and CoordinationRegression. Formatting and lint pass. The original reproduction fails 24 expected UI/clearing assertions without script errors; it predates the later all-producer and mixed-selection coverage.

The new regression checks all three factions with ordinary Standard-start funds. A paid engineer remains in the same queue with unchanged remaining time and funds after clearing a resource rally. Another engineer's existing action and pending order are preserved. Point and friendly-unit rallies clear, and the cleared target's later death leaves the producer unchanged. An actual paused disk round trip preserves the empty rally, clock, funds and paid queue. Fifteen simulation seconds after resuming, exactly one new engineer has completed, has no rally action and stays by HQ without delivering resources.

The same control clears destinations on HQ, barracks, vehicle and aircraft producers for each faction. These additional producer structures are controlled fixtures, not paid construction claims. Mixed HQ/engineer selection still stops the engineer while preserving the HQ rally. Shared suites verify foundation refunds, direct orders, target lifetime handling, factory program versions and manual-rally priority.

The Helix rendered run passes two mouse clicks and one focused Enter activation at 1280×720 with 150% interface scale. Seven inspected captures cover resource, point and friendly-target labels, enabled/disabled action, paid queue preservation, paused restoration and the completed idle engineer. Destination text and controls fit the panel, with the standard keyboard focus indicator visible. Assignments, selection and production submission are fixture-driven; this does not claim physical-device or novice testing.

All nine retained Godot runs are classified in `rally-controls/run-index.json`. Final accepted runs have no script/parse errors or new runtime errors. Existing navigation-readback warnings and shutdown ObjectDB/resource/shader/RID diagnostics remain. Earlier positive runs precede the final pending-order assertion; the final headless rerun includes it. Source fingerprints, logs, screenshots and a SHA-256 inventory are retained beside this report.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/RallyControlsRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/RallyControlsPreview.gd -- --captures=/tmp/rally-controls-review
```

Use a fresh capture prefix. Strategic AI is disabled and target death is injected in these fixtures. Sustained Industrial defense, protected income, broader environment/novice/platform acceptance and deferred performance remain open. The overall goal stays active.

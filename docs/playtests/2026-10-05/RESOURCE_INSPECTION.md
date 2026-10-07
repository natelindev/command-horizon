# Resource inspection and wreck readability — 2026-10-05

Pointing at a currently observed material field, electronics field or wreck now shows one readable world card. Deposits show current stock and their two work slots. Wrecks show their faction-specific unit name, remaining materials, expiry and Frontier recovery eligibility. Moving the pointer away closes the card. The same picker now reaches aircraft ownership captions.

Persistent wreck labels have been removed. The new card uses the existing world-overlay typography and background, avoids the HUD, minimap, selection controls and subtitles, and does not receive mouse input. Resource inspection remains available when optional military ownership symbols are disabled. Neutral resources do not receive military markers.

## Original evidence and correction

The prior [earned battle capture](research-feedback/native-final-earned-paused.png) shows very small persistent wreck text beside overlapping unit markers. It contains one currently observed wreck; it is not evidence of multiple simultaneous wrecks. A controlled extension of that same archive creates three nearby tank deaths to compare the original labels and new presentation at identical camera framing:

- [Original three-wreck labels](resource-inspection/before-cluster.png)
- [The same cluster after removing persistent labels](resource-inspection/after-cluster.png)

The cluster is a visual fixture, not a claim that those three deaths occurred in the original complete match. Both rendered processes verify that all three deaths produce wrecks. The all-faction headless test separately verifies that pointing into a three-wreck cluster returns one card for the actual ray target.

The old world picker used collision mask 2, excluding both neutral resources on layer 1 and aircraft on layer 4. The corrected minimal input regression misses all nine targets across Bastion, Helix and Frontier before the change, then passes afterward. See [corrected baseline](resource-inspection/minimal-corrected-before.log), [corrected passing result](resource-inspection/minimal-corrected-after.log) and the retained `ResourceInspectionRegression-minimal-corrected.gd.txt`.

The first attempted baseline was invalid: it passed logical viewport coordinates to an input function that transformed them a second time, and disabled the aircraft's entire process mode, which also removed its collision area. `minimal-before.log`, `minimal-after.log`, `picking-probe.log` and `coordinate-corrected.log` are diagnostic fixture runs, not accepted failure/passing evidence. The maintained fixture uses local input coordinates, keeps collision areas active and pauses the match. The corrected baseline was rerun with the original production sources and restored the updated sources afterward.

## Implementation

- [OwnershipOverlay.gd](../../../source/match/hud/OwnershipOverlay.gd) picks resource, ground-unit and aircraft collision layers, validates current observation and draws a single bounded multiline card. Military captions retain their existing ownership setting.
- [Battlefield.gd](../../../source/match/combat/Battlefield.gd) accepts neutral resource nodes without a `player` property, then uses the same range, blocker and observer-cache validation as other targets.
- [Wreck.gd](../../../source/match/units/non-player/Wreck.gd) retains its model, stock, lifetime and visibility refresh, with the persistent Label3D removed.

The display reads actual resource stock and remaining simulation lifetime. Public map-resource markers do not grant current stock visibility: a hidden resource receives no inspection card. FULL visibility and all-player observer modes use their existing visibility scope. Current observer hints are revalidated when a scout withdraws, including within the same frame.

## Verification

[ResourceInspectionRegression.gd](../../../tests/headless/ResourceInspectionRegression.gd) exits 0 with zero failures and zero script errors in [expanded-final.log](resource-inspection/expanded-final.log). Coverage includes:

- Actual input-event ray picking for materials, electronics and raised aircraft across all three factions; current stock, two work slots, wreck identity/expiry and faction eligibility.
- Current sight, stale visible flags, same-frame scout withdrawal, local versus enemy vision, ALL_PLAYERS and FULL visibility, and HUD input exclusion.
- Optional military symbols leaving resource inspection available; neutral resources excluded from military markers; paused inspection preserving simulation time, funds, unit positions/health, actions, queued orders and selection.
- Immediate card removal when deposits are queued for depletion, actual timed wreck expiry, and paused disk save/reload preserving stock and remaining lifetime.
- Three actual tank deaths producing three finite wrecks without Label3D children, one card at the pointed wreck, real partial salvage updating stock, and exactly four materials eventually delivered to HQ. Other cluster wrecks are explicitly removed before the delivery subtest to isolate conservation.

The earlier `expanded-first.log` passes the smaller suite before all-player observation and real cluster/harvest extensions were added; its exact test source is retained. In the harvesting extension a worker may physically cover a small wreck, so the partial-stock check reads the card's shared line builder while the worker is gathering. Actual world picking is checked separately before the order. An occluding worker remains the correct ray target.

Shared checks all exit 0 without script errors:

| Check | Relevant coverage |
| --- | --- |
| OwnershipRegression | Existing ground/air markers, same-color opponents, hidden contacts, spectator modes and layout. |
| CombatRegression | Ground/allied/elevated observation, opaque structures and terrain, current target loss and legal firing. |
| FrontierGameplayRegression | Actual salvage eligibility, pending-death and partial-cargo restoration, exact delivery, plus faction gameplay. |
| FrontierSalvageEdges | Hidden wrecks, scouting, partial cargo on expiry, excluded unit roles and the bounded wreck pool. |

Logs and [source/artifact hashes](resource-inspection/resource-inspection-evidence.json) are retained in the evidence directory. Formatting, lint and changed-file whitespace checks pass.

## Native review

[ResourceInspectionPreview.gd](../../../tests/rendered/ResourceInspectionPreview.gd) loads the previously earned Frontier [research archive](paid-progression/earned-frontier-verified-10-technology.json). It changes display options only in memory and restores them; autosaves are disabled. At 1280×720 with 150% UI scale, actual native world clicks position the pointer over the saved battle's observed resources:

- [Materials: 155 M, two work slots](resource-inspection/native-materials.png)
- [Electronics: 70 E, two work slots](resource-inspection/native-electronics.png)
- [Scrapper rig wreck: 1 M, 2:46 remaining, recovery instruction](resource-inspection/native-wreck.png)
- [Raised aircraft ownership caption](resource-inspection/native-aircraft.png)

Clicks on the HUD clear each card. Resource inspection preserves paused time, stock, funds and army actions. The aircraft is a declared preview extension, created to verify its raised collision layer; it was not produced in the archived match. Captures were visually inspected and cards fit without overlapping the HUD, minimap or selection controls. The native process exits 0 and prints its inherited runner's `Paid progression native: 0 failures` in [native.log](resource-inspection/native.log).

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/ResourceInspectionRegression.gd

tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/ResourceInspectionPreview.gd -- --archive=res://docs/playtests/2026-10-05/paid-progression/earned-frontier-verified-10-technology.json --captures=res://tmp/resource-inspection/native --interactive
```

Use a new capture prefix in an existing directory. The native runner waits for each indicated pointer action and has a four-minute deadline. `--cluster` instead creates and captures the declared three-death visual extension without interaction.

Existing navigation mesh readback and renderer/ObjectDB cleanup diagnostics remain in the logs. This pass verifies resource readability and gameplay preservation, not novice comprehension, final map quality, faction balance, full-match pacing or platform acceptance. Those remain open; performance optimization stays deferred and the overall development goal remains active.

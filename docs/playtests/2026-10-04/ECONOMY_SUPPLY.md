# Economy guidance under pressure — 2026-10-04

A depleted-field notice previously took precedence over a visible raid, selecting displaced engineers while their economy needed defenders. After vehicle production was unlocked, the guide also continued to programming lessons when no engineer was collecting electronics and reserves could not fund armor. The [before-fix regression](economy-supply-before.log) records sixteen failed expectations across the two factions, including these original scenarios.

## Implemented behavior

HQ loss and engineer replacement keep their urgent recovery paths. Otherwise, currently observed nearby armed enemies or recent damage to owned economic units take precedence over cargo reassignment, depleted fields and work-slot redistribution. When the threat disappears, the guide returns to the outstanding economy task. Hidden enemies do not affect the recommendation.

With a completed vehicle factory, missing material or electronics income is compared with the faction's tank cost. Fit chips adds the actual four-electronics fee. A completed aircraft factory also includes the faction's strike-aircraft cost. For each resource, the largest applicable single-unit cost is a reserve threshold; it is not a prediction of aggregate production demand. A shortage notice appears only when the resource has no assigned gatherers and the other resource has an active assignment. Approaching, collecting, returning and work-slot waiting engineers retain their resource assignment for this purpose. Established depletion and congestion guidance remains responsible for stopped or oversubscribed fields.

The shortcut selects one idle engineer first, then an available gatherer, preferring one with less cargo. Engineers constructing, moving under another action or carrying queued future orders are excluded. The text asks the player to choose a protected deposit and scout/defend new fields before sending workers. Advice and selection do not spend resources, issue orders, relocate units or change harvest rules. Cargo delivery before a new harvest assignment continues through the existing action implementation.

## Verification

The [headless regression](economy-supply-final.log) passes for Bastion and Helix:

- Missing electronics/materials streams, sufficient reserves, faction prices, fitted-chip fees and air-production thresholds.
- Preference for idle engineers and preservation of manual movement, construction and queued orders.
- Depletion plus a visible raid, hidden/withdrawn enemies, recent incoming damage and return to expansion guidance.
- Repeated advisory evaluation without resource or order mutation, and actual paused disk save/restore with unchanged clock and restored advice.
- The recommended engineer is explicitly assigned to electronics, harvests and delivers enough income to pay for a fitted tank. Bastion delivers 12 E in 60.60 simulated seconds; Helix delivers 16 E in 66.23 seconds. The paid tank finishes production with its chip installed in both scenarios. These are isolated home-economy fixtures, not contested expansion trials.

Shared [battle-plan](economy-supply-BattlePlanRegression.log), [economic recovery](economy-supply-EconomyRecoveryRegression.log), [resource-field](economy-supply-ResourceFieldRegression.log) and [weapon preparation](economy-supply-PreparationRegression.log) regressions pass. Existing HQ/refund/worker-replacement flows and field assignment boundaries remain covered. Format/lint checks pass. The editor imports the new scripts and UID files successfully. Retained logs include existing navigation-bake and shutdown resource/RID warnings; successful runs have no script errors.

The [normal-clock rendered regression](economy-supply-rendered.log) also passes at 1280×720 / 150% interface scale. Mouse events through the viewport exercise the actual selection buttons, verify the selected units and unchanged orders/paused clock, and check panel separation from the minimap and unit controls. All four resulting captures were visually reviewed: [Bastion supply](../../../art/skirmish/economy-bastion-supply.png), [Bastion defense](../../../art/skirmish/economy-bastion-defend.png), [Helix supply](../../../art/skirmish/economy-helix-supply.png), [Helix defense](../../../art/skirmish/economy-helix-defend.png). This is engine-input automation, not a novice playtest. The same rendered run completes paid fitted-tank production after income recovery in both factions; electronics delivery takes 64.47 / 72.07 simulated seconds respectively.

The [editor log](economy-supply-editor.log) and [source fingerprints](economy-supply-build.json) retain the checked revision.

## Remaining work

This improves the player's next-step guidance. It does not rebalance prices, production throughput or match pacing, and it does not automatically escort or reassign engineers. Existing income can still be insufficient for sustained mixed-force production. Protected expansion strategy, resource allocation with competing production plans, broader coordination and novice acceptance remain open. No new full-match balance conclusion follows from these focused checks. Performance work remains deferred.

## Reproduction

Run from the repository root using Godot 4.6:

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/EconomySupplyRegression.gd
godot --path . --rendering-method mobile --script tests/rendered/EconomySupplyPreview.gd
```

The rendered test uses normal simulation timing, sets a 1280×720 window and 150% interface scale, then restores the original options. Both runners restore the prior autosave setting. The supply archive uses a process-specific temporary path and is removed after restoration.

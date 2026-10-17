# Garrison combat and refinery feedback

## Stage 1: Reproduce

Exercise real infantry firing from shelters and movement after unloading, including restored matches. Inspect existing occupancy and refinery income feedback.

## Stage 2: Fix and present

Fix combat and exit state, make shelter occupancy legible, and expose the existing small refinery income beside resources and on the refinery.

## Stage 3: Verify

Run focused regressions and related combat, capture, save/load and HUD checks. Render and inspect shelter/refinery feedback and all faction HUD previews.

## Agent progress

- Initial inspection: refineries already pay 2 materials / 1 electronics every 10 seconds, with finite stock; shelters already have a small world label. Existing unloading checks do not assert resumed travel.
- Stage 1 complete: reproduced stuck exits across expanded desert, industrial and coastal maps. Units were placed at the navigation surface height without subtracting their foot offset, leaving their first waypoint unreachable. Explicit attack orders also replaced the shelter action and evacuated the shooter.
- Stage 2 complete: corrected exit elevation and reset movement state; direct legal attacks retain the shelter action, and muzzle effects originate outside the wall. Enlarged and outlined occupancy labels, retained readable ownership tint, and added occupancy to selected-unit orders. Resource readouts now show owned refinery income, while refinery labels and the facilities overview show payout timing, suspension or depletion. Added English/Chinese strings.
- Stage 3 complete: all 80 exit slots across ten shelters pass, as do direct attacks and save/load firing/unloading on all three maps. NeutralWorldRegression, PersistentCaptureRegression, MechanicsRegression, InfantryHeroesRegression, PointOfInterestRegression, SupplyLineRegression and 16 HUD console states pass. Updated stale HUD test assumptions about captions and an optional panel. Changed shipping scripts pass formatting and lint, and the final editor import passes; the older NeutralWorldRegression retains its existing naming/duplicate-load lint warnings. Godot still reports the same shutdown resource leaks seen in the unchanged baseline.
- Rendered review complete: the dedicated garrison/refinery preview passes. The full HUD preview passes for all factions in English and Chinese at 720p/150% or 1080p/100%; the further Helix preview on ExpandedAlpineRelay also passes. Visually inspected shelter occupancy, unloading and refinery payouts, plus all six faction/language income readouts. Captures are under `art/garrison-refinery/` and `art/hud-console/*refinery.png`; historical console captures were preserved.

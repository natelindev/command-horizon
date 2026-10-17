# Menu, soldier animation and starting resources — 2026-10-17

## Menu cleanup

Removed the program-issue shortcut and auto-resume checkbox, including their UI
callbacks. Production queues no longer display redundant program/chip badges.
Research, lab, faction ability and resource tooltips now describe the current game
without directing players to retired chips or squad programs. English and Chinese
captions are updated. Queued-order controls, faction abilities, research and the
five unit behaviors remain available.

## Soldier walk/run investigation

The infantry gait treated every zero-distance rendered frame as a stop. When the
renderer draws multiple frames between physics updates, the next update restarts
the stride from the lead foot. A second fixed distance-per-frame threshold also
classified slow continuous walking as stationary at high frame rates.

A deterministic regression reproduced 70 failures before the fix. It samples a
30 Hz moving body at 30, 60, 144, 240 and 1,000 render frames per second, then tests
slow walking and a real stop for all five infantry roles across all three factions.
The fixed version passes. Motion detection now uses a speed threshold and retains
the stride through a short 60 ms gap between movement samples. Feet still stop
advancing when there is no travel and settle after a genuine stop. The existing
no-skating, planted-foot, shooting, pause and gameplay-invariance checks also pass.
The animation regression is included in desktop release smoke checks. Three-faction
rendered contact sheets were also reviewed locally for starting, cruising, turning
and stopping.

This is a reproduced timing defect that can explain a faster Windows system
behaving differently from a Mac. It is not a verified Windows-only renderer bug.
Windows execution remains unverified on this macOS workspace.

## Starting resource spacing

All three maps in the skirmish picker use a shared opening layout:

- Home field center: **18 m from the starting HQ**.
- The same five material and two electronics pile offsets, rotated/reflected for
  each start. Individual pile distances match across maps and between players.
- Material piles retain 400 units each; electronics piles retain 720 each.
- Expansion fields keep their authored positions and stocks.

The old field-center distances were approximately 26.2 m on Desert Frontier,
24.7 m on Alpine Relay and 18 m on Coastal Foundry. The map preview and runtime
layout use the same policy. Authored campaign/legacy map scenes retain their
layouts. Restoring a battle uses its recorded resource positions and stocks.

`StartingResourceRegression.gd` checks geometry, per-pile distances and actual
materials/electronics delivery for both players, with all three factions on all
three current maps. Advanced-start geometry is checked on all three maps as well.
Every case also round-trips a save and checks that recorded
positions and remaining stock are preserved, including an intentionally changed
archived position.

## Verification

See [follow-up check results](follow-up-verification.json). Rendered HUD review
uses `HudConsolePreview.gd` for all factions in English and Chinese. Existing
Godot shutdown resource warnings remain; script errors are checked separately.

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/BehaviorRegression.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/UnitAnimationRegression.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/StartingResourceRegression.gd
godot --path . --script tests/rendered/HudConsolePreview.gd
```

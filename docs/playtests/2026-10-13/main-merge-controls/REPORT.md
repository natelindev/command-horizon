# Main merge controls verification — 13 October 2026

Review of the automatic merge preserved both the mechanics branch and incoming main controls. The menu keeps all nine maps, the expanded default, stable scene-path preferences with legacy numeric-map compatibility, and the doctrine selector with settings/preferences. One integration defect was identified: drag-heading formations returned raw slots before reachable destination packing. Root corrected that wrapper while retaining the formation geometry API.

The three owned headless suites passed with **0 assertions / exit 0**, with no script errors:

- Tier1ControlsRegression: raw line/wedge geometry, heading-wrapper provisional separation, stance cycling, control-group append/access tracking and idle-worker query.
- Tier3UiRegression: command-card matrix/hotkey captions, tactical range-ring lifecycle and tactical ping dispatch/audio.
- FormationCapRegression: **21 real 100-unit cases** across Bastion, Helix and Frontier. The original nine click cases remain; twelve cases add drag-heading line/wedge orders at both opposite map corners. Every assigned destination is planar, on-mesh, route-reachable and non-overlapping.

Tier1 now uses declared radius/hp properties and a NavigationAgent3D Movement child for its provisional geometry fixture. The full-army regression supplies synchronized units on an actual match map. Neither the raw geometry API nor runtime packing was weakened to accommodate test dummies.

The formation log retains known ObjectDB/resource cleanup warnings at process exit. The Tier1/Tier3 logs contain no such warnings. Formatting, lint and diff checks passed for the two modified tests. Source and log hashes are preserved in [summary.json](summary.json).

The native facility rerun on merged main also passed **0 assertions / exit 0**, in **English and Chinese at 1280 × 720 / 150% interface scale**. All six current screenshots were inspected and retained alongside the raw log. Engine-routed clicks, wheel and keys verified the actual Sites button, scrollable six-card list, neutral recruitment disabled, real infantry capture, paid hiring/cancellation/refund, actual infantry completion, View camera centering, previous pause-state restoration and focused Enter on Back without orders leaking through the modal. No facility UI source fix was needed; the established models and presentation remain unchanged. Physical operating-system input automation is not claimed.

These headless checks establish controls and navigation integration. They do not establish human match balance or physical operating-system input automation. Merge-specific evidence is kept separate from the pre-merge mechanics baseline.

Reproduce:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script res://tests/headless/Tier1ControlsRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script res://tests/headless/Tier3UiRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script res://tests/headless/FormationCapRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --windowed --resolution 1280x720 --script res://tests/rendered/PointOfInterestPreview.gd
```

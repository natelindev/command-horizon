# Resource-field route scope correction

A broader integration sweep exposed one route failure after the HQ work-face
improvement: Frontier's expanded Alpine engineers could not deliver electronics
from the extra field at `(37.5, 0, 114)`. After 120 simulated seconds, the engineer
remained at `(23.71269, 0, 54.76546)` near the starter field, carrying zero. The
complete before-fix trace is retained in `field-approach/`.

A fresh fifth-field-only fixture passed. Verification therefore preserves the
full sequence of all eight fields, including earlier deliveries and cleanup.
Preventively choosing a different resource contact face changed a long route
before any body obstruction required that choice. The correction keeps an
ordinary resource route when it is clear of settled mobile bodies. A frozen or
idle row can still trigger a preventive detour; a worker already moving away
keeps ordinary avoidance. Structures retain their work-face planning. Every
candidate detour checks all current bodies, and actual-contact recovery remains
available. Terrain, resource coordinates, starting rosters and contact bounds
are unchanged.

Final acceptance on this guard:

- All 24 sequential Alpine field cases pass across Bastion, Helix and Frontier.
  The original failing electronics field delivers in 58.0 simulated seconds.
- All 54 HQ map/faction/start/roster fixtures pass, including frozen outbound
  harvesting and both headquarters.
- All six paused mid-waypoint archive roundtrips pass; cargo, balance, destination
  and position remain intact while paused, then exact delivery completes.
- NavigationRegression passes obstacle routing, crowded movement, harvesting,
  construction and factory departure. Formatting, lint and whitespace checks pass.

The initial attempt to restrict prevention to structures alone passed the field
sequence but exposed frozen outbound engineer stalls. The final settled-body
condition covers that physical case while preserving clear field routes.

Run `tests/headless/ExpandedFieldApproachRegression.gd` with the local Godot 4.6
binary and `--headless --fixed-fps 60 --path . --script`. Optional `--bastion`,
`--helix` or `--frontier` arguments select a faction; the default checks all three.
Raw logs, counts and final source hashes are in
[field-approach/summary.json](field-approach/summary.json). Existing engine exit
cleanup warnings remain in the raw logs.

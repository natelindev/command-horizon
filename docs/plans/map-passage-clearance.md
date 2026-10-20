# Map passage clearance

## Stage 1 — Reproduce

Inspect authored crossings and measure their usable width after navigation baking, including neutral structures and resources. Identify blocked or excessively pinched routes.

## Stage 2 — Repair

Adjust the affected map definitions or terrain construction at the source, preserving symmetry and intended terrain barriers. Add regression coverage for usable crossing width and actual unit travel.

## Stage 3 — Verify

Run the passage regression and relevant terrain/navigation checks. Review rendered views of changed terrain and report any remaining verification limitations.

## Agent progress

All three stages are complete.

- Reproduced narrow baked clearances on Four Rivers bridges, Saltwind Basin dikes, Copper Badlands ramp exits, and a Railspire Junction ramp mouth. The final regression reports 14 failures against those original layouts.
- The user's Coastal Foundry screenshot identified the gap west of the foundry hall. Its original approach measured only 5.25–5.5 m in the sampled corridor. Shortened the hall's west end by 6 m, matching the rendered model and solid footprint while keeping the east wall and nearby deposits clear. Both mirrored approaches now meet an 8 m usable-width requirement.
- Widened Four Rivers bridges and their models to 8 m, widened Saltwind dikes to 8 m, moved Copper Badlands machinery into the haul yard, and moved Railspire's ramp entrance clear of the terrace cliff. Bridge decks no longer receive scattered trees, rocks, or shoreline clutter.
- Added `tests/headless/MapPassageRegression.gd`: baked continuous clearance across every ramp and bridge in all 16 selectable maps, both Saltwind dike pairs, both Coastal Foundry approaches, and opposing groups of maximum-radius tanks through the repaired routes. Final run: 0 failures.
- `TerrainNavRegression`, `MapResourceBalanceRegression` on all five affected maps, `MapPreviewRegression`, and `RichTexturesRegression`: 0 failures. Regenerated map previews; only the three changed terrain/road previews differ.
- Reviewed non-headless `AuthoredMapReview` captures and the user's Coastal Foundry angle. The focused `TerrainLayersPreview` run for all five changed maps completed with 0 failures. An earlier unfiltered preview run reached the legacy maps before its timeout; the focused run completed the required review.
- Godot reports shutdown resource-leak warnings in existing harnesses; successful verification commands exit with status 0. Live user-built obstructions and arbitrary army sizes are outside these bounded scenarios.

- Integration with `main`: preserved the Godot 4.7.2 upgrade and gentle-slope placement changes. The combined tree passed `MapPassageRegression` (all 16 maps), `TerrainNavRegression`, and `MapPreviewRegression` on Godot 4.7.2.

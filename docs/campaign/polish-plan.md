# Campaign, map and battle menu polish

## Stage 1 — Restore campaign captions

Keep campaign text visible in briefings and battle dialogue independently of optional
unit radio captions. Check every supported mission, pause, save/load and live locale changes.

## Stage 2 — Explain objectives

Audit capture, hold, convoy and hero requirements. Show current-stage instructions
and a View objective camera control without changing victory conditions.

## Stage 3 — Reuse mature vegetation

Replace flat scrub placeholders with existing mature trees and leafy bushes at
readable world sizes. Keep routes, resources and gameplay collision intact; batch
map scatter and reduce density to offset the larger models.

## Stage 4 — Repair and simplify battle menus

Align a full-width bottom console with the minimap, and give selection portraits the available card height. Make captured mercenary camps
open their paid recruitment controls directly. Remove the skirmish Battle plan panel
and its settings toggle, preserving production and assigned-engineer shortcuts.

## Agent progress

- Campaign dialogue now always displays captions; the optional setting controls
  routine unit speech. All 17 supported story missions pass caption checks.
- Added English/Chinese objective instructions and current-target camera navigation.
  Mission 1 victory, mission 2 convoy rules, all hero operations and dialogue save/load
  checks pass.
- Existing mature tree models and BirchScrub replace flat DryScrub/RoadSage props.
  Scenic scatter stays in multimeshes, with fewer instances and wider road clearance.
- Selection cards now expand portraits and hide empty health labels. Captured camps
  open a focused recruitment menu. Skirmish no longer instantiates Battle plan.
- Selection, camp recruitment/refund/save/load, production queues, vegetation
  sizes and all six current-map routes pass. All 16 current missions pass rendered
  English/Chinese caption checks; all-faction selection previews pass exact
  bottom-band alignment and actual mouse/keyboard tests. Final English/Chinese HUD
  and tactical-pause camp reviews also pass. Archived environment fixture
  limitations are documented in POLISH_VERIFICATION.md.

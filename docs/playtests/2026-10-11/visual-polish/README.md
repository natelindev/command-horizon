# Visual polish verification — 2026-10-11

Implemented all five reported visual issues:

- 15 transparent infantry portraits rendered from actual faction models and class equipment. Both direct launch scripts now import changed/missing Godot resources before starting.
- Buildings assemble from the foundation upward, with a moving luminous assembly edge and an open blueprint above it. Original materials return on completion. Saved progress restores the same visual height, including while paused.
- Research has five illustrated assets, compact cards, and an active-project image and description.
- Desert vegetation uses tree-scale silhouettes. It remains non-colliding and outside gameplay/navigation groups.
- Home, setup, settings and HUD use the shared control theme. Home actions reflect available game features. Setup previews show textured terrain, soft road edges at authored widths, terrain ridges, resources, relays and starting positions. The footer stays available at 150% scale.

## Captures

- [Chinese home](home-zh.png)
- [Desert skirmish setup](map-0.png)
- [Chinese setup at 150%](setup-zh-150.png)
- [Barracks portraits](barracks.png)
- [Active research](research-active.png)
- Construction: [foundation](construction-00.png), [45%](construction-45.png), [complete](construction-100.png)
- [Tree scale](trees.png)

## Verification

All six suites reported zero failures in Godot 4.6:

| Suite | Coverage |
| --- | --- |
| VisualPolishRegression, rendered | All 15 portraits contain visible pixels; Barracks icons; research artwork; all six map previews; English/Chinese; 150% setup footer; construction progress and material restoration |
| ConstructionContractRegression | Three factions; paid construction, crew rate, paused save/restore, matching shader progress, completion and refunds |
| ResearchFeedbackRegression | Three factions; research availability, progress, loss of lab, refunds and completion |
| MenuArtRegression | 100/125/150% menu layout; mouse activation; settings; keyboard Escape |
| LocalizationRegression | Chinese translations, runtime language switching, settings and persistence |
| DesertEnvironmentRegression | Decorative vegetation bounds/collision; exterior bounds; navigation, placement, sight, aircraft, economies and saved movement |

Targeted GDScript lint/format, shader format, shell syntax and diff whitespace checks passed. The rendered visual suite exits cleanly. Some headless suites report Godot resource/ObjectDB cleanup warnings at exit after reporting zero assertion failures; these are retained in the result files.

Reproduce rendered captures:

```sh
godot --headless --editor --path . --import
godot --path . --fixed-fps 60 --script tests/headless/VisualPolishRegression.gd -- --render
```

# Battlefield expansion verification — 2026-10-17

## Content and behavior

- Five new two-player maps and eight new four-player maps; the original three remain in the picker. [Roster](battlefield-expansion-roster.md).
- Two-player maps: 192 × 160, eight resource fields, six facilities. Four-player maps: 224 × 224, twelve resource fields, twelve facilities.
- Every starting field is 18 m from its HQ with five 400-material piles and two 720-electronics piles. Expansion fields have five 600-material piles and two 1,200-electronics piles. Starts, resources and facilities follow the layout's rotational symmetry.
- Four-player games launch one human and three independent AI commanders. Random factions resolve separately. AI chooses surviving rival starts, defeated armies surrender, and victory waits for the last rival. Saved facilities and AI task groups retain all four owners.
- All map scenes use the authored profiles in `source/match/maps/BattlefieldCatalog.gd` and the shared `FrontierBattlefield.gd` builder. Gameplay layout is deterministic; only decorative scatter uses a fixed map seed.

## Passed checks

Run Godot 4.6 from the repository root. Headless checks used `--headless --path . --fixed-fps 60 --script`:

| Check | Result |
| --- | --- |
| `tests/headless/BattlefieldExpansionRegression.gd` | 0 failures across all thirteen maps: menu/preference restoration, all starts, equal stocks and rotated deposit positions, every pair of starting bases connected, every field reachable, four approach directions per facility, water excluded from navigation, aircraft clearance over landmarks, valid snapshots for every map. Four-player save/load, third/fourth AI groups, fourth-owner facilities, cross-owner rejection, elimination persistence, sequential and simultaneous victory, defeat and draw all passed. |
| `tests/headless/BattlefieldOpeningRegression.gd` | 0 failures. Ten advanced starts across Redrock Divide, Sunken Exchange and Frostbound Crown; Bastion, Helix and Frontier workers delivered both resources, factories completed paid tank production, and produced tanks left their bases. |
| `tests/headless/MapRosterRegression.gd` | 0 failures; existing numeric and stable-path preferences still migrate correctly. |
| `tests/headless/SkirmishCoordinationRegression.gd` | 0 failures; both existing factions at every difficulty, task budgets/save restoration, guard recovery and live combat. |
| Godot editor import | Completed without script/compile errors. |
| GDScript lint/format and shader format | Passed for changed implementation and new fixtures. |

Rendered without `--headless`:

- `tests/rendered/BattlefieldExpansionPreview.gd`: top-down and battle views of every new map, plus two-player and four-player setup views. Captures are in `art/new-battlefields/`. The fixture uses full terrain visibility while hiding opponent economy plates for the battle images.
- `tests/rendered/HudConsolePreview.gd`: 0 failures across Bastion, Helix and Frontier, English/Chinese and the fixture's 720p/1080p configurations. Executed against an isolated copy of the current source to retain existing HUD review artifacts. Captures and logs are under `tmp/map-expansion/hud-review/` and `tmp/map-expansion/`.
- Visual review corrected floating, circular pond rims, removed the repeated checker-like water pattern, matched volcanic preview colors, and checked the four-player briefing and map markers.

## Existing limitations

- `SaveSnapshotRegression.gd` stops at line 49 because its custom-Lua fixture expects `UnitProgram.configure_lua()` to create a runtime; the current implementation explicitly rejects custom Lua. This file was not changed by this task.
- `SaveSlotsRegression.gd` passes its quick/manual save and modal/recovery checks but reports `Program checkpoint missing` and `Relay checkpoint did not rotate`. An isolated comparison with this task's Skirmish, AI coordination, snapshot, schema, restore and save-summary changes removed produced the same two failures. These campaign checkpoint failures were not altered here.
- Several Godot runs emit ObjectDB/resource cleanup warnings at process exit; no runtime script errors occurred in the passing map, opening, AI or rendered HUD checks.
- Navigation, opening economy, outcomes and persistence are verified. Extended competitive balance across all faction matchups has not been playtested.

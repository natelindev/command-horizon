# Exported scenario editor verification — 2026-11-02

The main menu now opens a complete in-game **Scenario Editor**. It uses existing environment art and requires no Godot editor installation. Players can create 48–192 m flat maps in desert, temperate or volcanic terrain, set two or four starting positions, and place deposits, capturable Tech Refineries/Data Relays and seven modular scenery pieces.

The editor provides direct palette tools, half-metre placement, selection, coordinate/rotation/resource inspection, removal, bounded 64-step undo/redo, pan/zoom and keyboard shortcuts. Middle-drag pans; the wheel zooms. Left click places or selects, right click removes. Ctrl/Cmd+Z and Ctrl/Cmd+Shift+Z undo/redo; Ctrl/Cmd+S saves; R rotates the placement heading.

Portable `.rtsmap` files live under the game's `user://scenarios/` folder. Files contain bounded JSON data and whitelisted piece identifiers. They cannot load scripts or arbitrary resource paths. Validation checks dimensions, finite positions, stock, map edges and headquarters clearance before editing, loading or playing. Saves replace files atomically.

**Play battlefield** launches a real skirmish with the chosen factions. Navigation, physical resource fields, economic sites and scenery footprints use the normal match systems. Battle snapshots embed the validated document, so loading a battle does not require the original `.rtsmap` file. Older-version battle saves remain unsupported; current archived maps keep their existing schema.

## Verification

| Check | Result |
| --- | --- |
| ScenarioEditorRegression, full native | Explicit native unit-state/crowd bindings, actual 2/4-player maps, every kit, deposits/sites, ground route bake, editing/undo/redo/inspect/removal, file replacement, malformed-data rejection, two captures around restore and unchanged resource IDs/amounts; 0 failures |
| ScenarioEditorPreview, Metal Forward+ | English and Chinese 1280×720 at 150% scale; every visible control fits, literal Chinese palette translation, actual viewport mouse placement, selection and the Play transition with placed geometry; 0 failures |
| Exported release runtime | Real macOS release template with a 217 MiB exported PCK runs ScenarioEditorRegression with native flags; 0 failures |

Reviewed [English and Chinese captures](../../../art/scenario-editor/). Durable [logs](scenario-editor/) retain native, rendered and exported-runtime results. The exported test uses a test-only main-loop bootstrap in a temporary staging project; production starts through the normal main menu.

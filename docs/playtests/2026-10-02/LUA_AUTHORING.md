# Player-facing Lua authoring and exact program versions

Verified 2026-10-02 with Godot 4.6 on macOS arm64. This completes the custom Lua library/editor/factory slice, not visual rules, the battle arena, campaign, save/load, LLM integration or full-product acceptance.

## Player flow

Select a programmable unit and choose **Lua editor**. The match pauses while the editor is open. Start from Hold position, Guard & regroup or Repair area, or load a saved Lua version. The editor provides line numbers, syntax highlighting, a monospace font, role/capability requirements, a sample trace and a compatibility count for the captured selection.

**Check samples** runs eight synthetic snapshots per permitted role in fresh bounded VMs. It never reads the live battlefield or dispatches intents. Samples cover missing/present point assignments, empty/visible contacts, low health and recovery. Results are explicitly labeled as sample checks, not battle simulation or proof that the player's intended behavior is correct. Editing invalidates the displayed trace.

**Save version** initializes a candidate VM and writes a new immutable source record; it changes no unit order. Runtime-only faults can still occur later. **Apply & run** is enabled for a saved, unchanged draft and a compatible, ready selection. Every eligible unit's VM is prepared before any order changes, then the group is committed synchronously. Incompatible units, foreign units and units without ready chips retain their orders. Simulation resumes only when the editor's owned pause is released; an existing tactical pause remains paused.

Closing retains the draft for the current match, including invalid edits. Saved versions persist across matches in the existing local library. The editor belongs to the match rather than the disposable selection panel. The unit panel now exposes Set route alongside area, escort and safe-point assignment controls. Current per-unit map assignments are retained when explicitly applying a program; no assignment coordinates or target handles are stored in its library record.

## Library and factories

Schema 2 stores name-derived stable program ID (names are immutable identities), integer revision, authoring mode, Lua API version, source and source hash, canonical content hash, preset config, allowed roles, capability requirements, an empty reserved parameter schema and test notes. Preset versions have empty source. Parameter-schema editing and visual rule records are not enabled yet.

The reader accepts legacy schema-1 presets and normalizes them in memory without rewriting the file. The next successful save writes schema 2 while retaining earlier versions. Writers re-read before appending so multiple selection/editor instances in the same game do not overwrite each other's versions. Files are replaced through a flushed temporary file and rename. Limits are 128 records, 8 MiB serialized library and 32,768 UTF-8 bytes per Lua source. Corrupt/unsupported/duplicate records preserve the existing file and explain the failure. Canonical numeric hashing survives Godot JSON's integer-to-float conversion. Hashes detect content changes; they are not signatures or authentication.

New factory selections pin ID, revision and content hash. Older name/revision pins remain readable. A queue job captures a deep copy of the full exact record at enqueue time, so later saves, factory changes or library deletion cannot change an existing job. Missing, changed, incompatible or uninitializable programs fall back to Hold with a reason. Rally orders override inherited Lua exactly as they override presets. Native Lua remains optional for built-in gameplay; unavailable runtimes cannot apply custom Lua.

## Verification

- `tests/headless/LuaAuthoringRegression.gd`: schema-1 migration without read-time writes, concurrent editor saves, exact version/source isolation, canonical hash round-trip, tampered source, changed pinned hash, duplicate identities, unsupported API/role/requirements/schema fields, source size, corrupt-file preservation and starter sample checks. Both factions: mixed-role/readiness/ownership preview, failed-initialization group preservation, paused application, independent VMs, manual override, exact queued source despite later versions/deletion, missing/failing source Hold fallback and Lua rally precedence. Passed.
- `tests/rendered/LuaEditorPreview.gd`: mouse and keyboard events through the actual viewport; editor launch, hotkey isolation, sample checking, saving, selection-library refresh, explicit paused Apply, invalid edit preservation, retained drafts, reloading source, custom role-subset preservation, both prior pause states and factory hash pins. Rendered 1280×720 and 1440×900; screenshots visually inspected. Passed.
- `ProgramRegression.gd`, `CoordinationRegression.gd`, `SpecialistRegression.gd`, `LuaProgramRegression.gd`: existing preset persistence, chip gates, factory snapshots, role behavior, Lua action/fault/manual/pause contracts. Passed.
- `tests/rendered/ProgramPreview.gd`: existing preset/library/assignment/manual/production/research UI and 720p layout with the added buttons. Passed.
- Godot editor import, gdformat/gdlint for the changed scripts and `git diff --check`: passed.

The rendered test first exposed a clipped action row and a zero-delay tooltip timer error. A scrollable guide keeps editor actions visible at 720p; the project tooltip delay is now 0.35 seconds, avoiding CodeEdit's invalid zero-duration timer. Input injection uses viewport-local coordinates and a pointer motion before clicks, avoiding inconsistent OS/window coordinate conversion.

Existing navigation GPU-readback warnings remain. Some headless suites retain shutdown-only ObjectDB/resource warnings; one macOS rendered run also emitted an IMK input-method wake-up diagnostic. The final runs contain no GDScript errors or failed gameplay assertions. This slice did not rerun the 200-unit performance workload, native interpreter sanitizer corpus, platform exports, novice usability sessions or other operating systems. Lua starter files are included in export filters, but exported packages remain unverified.

## Review

- [Editor and saved program at 720p](../../../art/skirmish/lua-editor-720p.png)
- [Invalid draft at 720p](../../../art/skirmish/lua-editor-error-720p.png)
- [Editor at 900p](../../../art/skirmish/lua-editor-900p.png)

Next: visual rules compiling into the same versioned Lua record, followed by a genuine battle test arena with expected outcomes, observed intents and trace. Preserve the broader campaign/map/faction/save-load/LLM and performance roadmap.

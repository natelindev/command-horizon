# Game-state save/load implementation contract

Status on 2026-10-03: **capture, reconstruction and player save/load flows implemented and verified for desktop skirmish and all six Bastion operation prototypes.** Campaign completion/badge persistence remains independent. Cross-platform/export and interruption-during-write acceptance remain open.

## Hero campaign extension — 2026-10-16

The catalog now exposes 16 operations across Bastion, Helix and Frontier. Legacy Air
Corridor IDs remain loadable. New operation records preserve the objective stage,
hold progress, bounded response-wave timers/counts, target references, relay states
and the active owned SupplyTruck. Invalid stages, timers, targets and missing active
convoys are rejected before scene replacement.

Hero records preserve the owned hero reference, ability tier and cooldown; restoration
reuses the saved unit instead of spawning a duplicate. Older mission archives without
a hero record receive the mission's hero. Dialogue saves preserve accepted cues,
queued scenes and the exact active line, remaining time and playback position. Old
history-only records and active single-narrator lines remain readable after a cue is
replaced by a multi-speaker scene. A loaded battle remains paused.

Campaign completion is a separate schema-7 file, accepting older schemas 1–6. It
tracks all three faction sequences and retains the old Air Corridor completion and
support reward. Completing the new Cinder Ford also earns the foundry support bonus.

## Delivery stages

1. Bounded typed storage, paused authoritative-state capture, exact embedded programs and Lua checkpoint restoration. Delivered below.
2. Validate the complete gameplay schema and restore a new match transactionally, reconnecting entities, commands and timers without advancing simulation or spending resources. Preserve the current match and source file on preflight failure. Delivered below.
3. Expose quicksave/load, manual slots and three rotating mission-checkpoint autosaves. Delivered, with actual input, slot/error feedback, cancellation, repeated reloads and both battle modes verified below.

## Storage rules

`SaveFile.gd` writes an inert JSON envelope containing format ID, schema 1, a payload string and its SHA-256 checksum. The checksum detects damage; it is not an authenticity/signature mechanism. `SaveValue.gd` tags every value, including lists and records, so player state keys cannot impersonate serializer types. Accepted values are null, booleans, 64-bit integers, finite floats, strings, vectors, colors, arrays and text-keyed records. Interned Godot property keys are normalized to text. No Resource, Node, callable, object loader or arbitrary script path is deserialized.

Integers use canonical decimal strings. Floats/vector/color components use exactly eight IEEE-754 bytes represented as hexadecimal, preserving simulation-duration bits across repeated saves. The initial decimal-JSON implementation demonstrably changed `repair_elapsed` on round trip; the bit-preserving representation fixes that original case. These bytes are read only as a fixed-size number, never as a serialized engine object.

The file limit is 64 MiB, with 750,000 logical values, 32 nesting levels and 2 MiB per string. Lua source/state retain their smaller runtime limits. Bounds allow the measured 200-unit snapshot with large explicit memories and source; they are not an unlimited save guarantee. The reader checks header, version, checksum, types, finite numbers, integer range, duplicate keys and bounds. **This reader returns inert data, not a gameplay-validated scene.** `SnapshotSchema.gd` additionally validates exact snapshot keys, entity/role/map whitelists, ownership, reference domains, limits and compatible program records before constructing nodes.

The outer storage envelope remains schema 1. Gameplay snapshots write version 13 and read versions 1–13. Version 13 adds a validated player `owner` to each neutral-building record, independent of its occupants. Vacant captured buildings retain ownership across loads; invalid player references, hostile occupants and ownership of ruined or uninhabitable structures are rejected. Version 11/12 saves infer ownership from their saved occupants; an empty older building remains neutral because no owner was stored. Versions 9–12 retain battle records, construction durability, neutral combat/garrisons and production departure endpoints. Version 8 adds Frontier faction IDs and a strict resource `wreck` record: an empty dictionary for ordinary deposits, or a whitelisted ground-machine role/original faction with 0–180 s remaining lifetime and material no greater than its finite salvage yield. It rejects non-Frontier harvesting references, excess wreck populations and incompatible ability/charge states. Reconstruction restores wrecks once, with exact remaining material, cargo, timers and maneuver cohorts. The outer envelope is unchanged. Version 7 adds completed technologies and the single active project, exact paid cost and remaining research time. Validation checks known IDs, uniqueness, prerequisites, bounded time, exact prices and exclusion of concurrent Coordination. Armor-adjusted maximum health is validated from faction base stats and completed research. Reconstruction restores technology before creating units, without charging again, stacking upgrades or healing. Versions 1–6 start with no classic unit upgrades. Version 6 adds strictly bounded neutral actor IDs, route distances, stop timers, animation phases and walking poses; authored routes and assets are never loaded from archive data. Versions 1–5 create the default neutral population without archived motion history. Version 5 persists harvesting resource type, fixed field origin, wait reason and retry time. Targetless waiting engineers restore without a child action; active actions reconstruct work-slot reservations. Versions 1–4 infer a field only from a surviving referenced deposit; a cargo-only return without one asks for a new assignment after delivery. Version 2 introduced a strict `weapon_mode` record for Helix CombatRobot units (empty for other roles/factions). It contains current/pending mode and finite nonnegative remaining switch time, at most two seconds; a pending mode must differ from the current mode. Reconstruction applies it before actions/timers and retains the separate weapon reload. Version-1 legacy Lancers start in Precision, and restoration reports that Interception must be selected for air defense.

Version 3 adds Prism's `deployment` record (remaining duration and last stationary position), empty on other roles/factions, and explicit preparation fields in `AttackingWhileInRange`. Active charge time is bounded by its positive total, at most 0.75 seconds, and permitted only for precision weapons; inactive preparation uses -1 with zero total. Deployment is bounded at 1.5 seconds. Exact numeric bits remain preserved by the outer serializer. Charge/deployment visuals are rebuilt while paused, and Stop/mode changes can cancel them without advancing simulation. Older action records and Prism units initialize fresh preparation/deployment under current combat rules; prior reload remains separate.

Version 4 adds explicit per-unit `signature` state (cooldown, cohort ID, kind, sector, setup, anchored flag, window, unused Precision flag and last position) plus player activation cohorts and next ID. It validates role/faction/research/chip compatibility, finite bounded durations/positions, unique owned members (up to six) and cross-references. The controller and unit timers are preserved independently without advancing either on load. Consumed Precision stays consumed; its shortened shot remains in the existing action record. Dead members are omitted. Versions 1–3 reconstruct with empty cohorts and inactive signatures.

Writes serialize first, preserve unreadable/corrupt/newer existing files, then write and flush a temporary sibling, read it back for verification and rename it into place. Failures retain the prior slot. This is not a platform-independent power-loss durability guarantee or concurrent-writer protocol; the player UI will own one writer. No credentials, editor provider configuration, library file paths or in-flight network requests enter the explicit snapshot fields.

Split Signal extends the explicit snapshot-v4 mission whitelist without changing existing fields or old map identities. Its record contains cumulative uplink/optional time, HQ recovery, response start/time/sent/warned counts, optional reward state and exactly three relay records. Mission ID, map path and dimensions must match the campaign catalog. Restoration reconnects all relay owners/candidates and preserves partial capture/contest state. `SplitSignalRegression.gd` verifies a real file round trip, identical resave and continuation of an already-warned response; malformed state is rejected before scene replacement. The unrelated campaign completion file now writes schema 4, reads schemas 1–4 and preserves previously earned results.

Supply Line extends the snapshot-v5 mission whitelist with exactly three truck records (owned entity reference, next leg, partial clearance, extracted flag), three response countdowns and three resolution flags. Mission-only SupplyTruck entities are accepted only for the human Bastion side of this operation. Validation rejects duplicate/untracked truck references, invalid roles/owners, out-of-range timers, inconsistent extracted state and already-finished mission states. Restoration retains active movement and announced responses while paused. The start and cleared checkpoints use the existing rotating autosave slots. Campaign progress schema 3 adds Supply Line completion, with migration from schemas 1 and 2 preserving earlier badges; the fixed First Orders starting-material reward is not re-applied during battle restoration.


Air Corridor extends gameplay-v5 mission records with a bounded HQ recovery timer, exactly two AA-site references/cleared flags and exactly three flight records. Flight status is ready/flying/extracted/lost; only one flying record can reference a human EvacTransport. Response countdowns and one-time resolution survive destruction/extraction. Validation rejects overlapping or untracked transports, wrong roles/owners, launch before clearance, malformed/inconsistent countdowns and already-finished states. The initial Wraith patrol's ordinary queued orders are archived with the unit. Progress schema 4 adds Air Corridor completion and the all-flight support badge while retaining schemas 1–3; loading a battle never reinterprets the current external campaign reward file.


## State inventory

Map identity is part of the compatibility contract. The revised 128×96 Desert Frontier uses `DesertFrontier.tscn` and revision 1. The original `BastionDesert.tscn` still denotes its unchanged 64×64 layout, so old unit/resource coordinates are never transplanted onto the revision. Both remain on the reconstruction whitelist, while only the revision is offered for new Desert skirmishes.

Capture requires a ready, paused, unfinished, two-player skirmish, First Orders or Split Signal match on a supported authored map. The caller owns pausing at a simulation boundary and rendered-frame synchronization. Capture itself does not advance or pause the game. Snapshot-local IDs such as `unit-3` and `resource-2` reconnect references; engine instance IDs are never written. Missing/destroyed references become empty IDs, with unavailable target actions replaced by Hold and feedback.

| Owner | Captured state | Restore obligation |
| --- | --- | --- |
| Match/settings | Map path/revision, seed, faction/controller/settings, simulation clock, unit-production count, repair cadence, visual serial, camera | Reject unsupported map/rules revisions; recreate controllers and map without spawning a second starting army. |
| Players | Funds, latched basic technology, Coordination remaining time/completion, completed unit technologies and paid active research, Command defeat duration, AI decision cadence/wave age/production sequence/enabled flag | Restore paid balances directly; recompute power and population from live entities/queues. |
| Units | Role, owner, transform, HP, construction progress, cargo, cooldown remaining, recent-damage age, cosmetic seed, selection/control groups | Do not heal, charge, reveal hidden units or reset cooldowns as a side effect. |
| Orders/actions | Current/waiting descriptors, target IDs, last-known positions, auto-resume/manual engagement, stall state; whitelist of action trees, child roles, timer remaining/paused/stopped values | Reconnect signals and action ownership without constructor-triggered shots, deposits, refunds or state transitions. |
| Navigation | Destination, velocity and stall/recovery state | Rebuild navigation RIDs/paths; never persist engine navigation objects. Handle unavailable/dead targets. |
| Programs | Exact saved record, unsaved active source/config, chip/install state, assignments, route/escort, mode/reason/pending state, explicit Lua memory and fault state | Use embedded versions, not the external library. Preserve manual authority and fault suspension. |
| Lua contacts | Current handle-to-entity mapping and next handle counter | Remap to new instances while retaining opaque handle identity; missing contacts cannot alias another entity. |
| Production/rally | Exact paid/refundable cost, role, remaining/total time, fitted chip, copied program snapshot, future factory pin and rally destination/target | Recreate queue reservations without payment; preserve exact queued behavior even if the library is removed. |
| Squads | ID/title/policy, next ID, membership, bounded shared state and live fire/repair claims with remaining lifetime | Rebind ownership and weak targets; expire unavailable claims. |
| Projectiles | Cannon/rocket target and remaining flight | Preserve pending damage without replaying launch effects or firing a second shot. Cosmetic trails/wrecks may restart or disappear. |
| Campaign | Lesson phase, hold/rebuild timers, defense/warning/wave progression, optional badge condition, relay ownership/candidate/capture/contest | No repeated rewards/checkpoint waves; restore owned local vision and objective feedback. |
| Alpine / Industrial map objectives | Two relays' ownership, capture candidate, progress and contest flag | Restore exact partial recapture and local vision independently; retain the skirmish win condition. |
| Lancer weapons | Current/pending Precision or Interception mode, remaining switch time | Restore before actions, remain frozen on load, retain firing lock and independent reload. |
| Faction signatures | Per-unit activation/setup/benefit/window/cooldown and player cohort references | Preserve exact paused state, keep regroup cooldowns and drop dead references; legacy snapshots start inactive. |
| Precision / Prism | Shot preparation remaining/total/origin; Prism deployment remaining/position | Rebuild the paused warning, preserve durations, cancel on invalid target/movement and require fresh preparation for legacy records. |
| Fog/knowledge | Rendered accumulated exploration PNG; last-known structure visual identity, transform and optional living reference | Recreate exploration and orphan memories without granting observation of hidden current units. Headless fixtures have explicitly unavailable render history. |

Action/state capture uses explicit fields, not reflection over every node property. An unsupported active action or invalid saved program aborts capture instead of silently dropping it. Ordinary single-player matches and campaign are the supported scope; legacy art demos and other template modes require a separate contract.

## Lua checkpoint semantics

`LuaRuntime.checkpoint()` captures API version, exact source hash, detached explicit state, suspended flag and error. `restore_checkpoint(source, checkpoint)` validates source/API binding and prepares a fresh bounded VM. Compilation or metadata failure leaves the current runtime unchanged. Invalid/deep/oversized/non-data explicit memory is discarded with a warning, while a matching suspended fault remains suspended. Explicit Resume retains its existing meaning: restart from clean memory.

Only the documented explicit state is persistent. Lua closures/globals are reinitialized from the exact source, as stated in the runtime API. The scene restorer handles unavailable native Lua, compilation errors or incompatible saved APIs with a visible suspended-program fallback while preserving the army. Invalid shared squad memory is reset with feedback using the existing bounded state rules.

## Verification

`SignatureRegression.gd` round-trips partial Anchor setup and already-consumed accelerated Precision through real files, checks exact paused state and resumed damage/timing, rejects invalid cohort references/durations/duplicates, validates death cleanup and reconstructs a version-3 archive with inactive abilities. Shared scene-restoration suites pass with snapshot version 4.

`PreparationRegression.gd` round-trips partial Prism deployment and shot preparation through actual archives, verifies exact paused durations and resumes to one hit. It rejects oversized setup/charge, validates earlier snapshot shapes and exercises movement/displacement cancellation. `PreparationPreview.gd` verifies the restored warning and paused Stop through actual 720p input. Shared specialist, mode and scene-restoration tests pass with the new preparation timing.

`WeaponModeRegression.gd` writes/reads a version-2 archive during a Lancer switch and restores exact remaining time, paused state, selected target domain and longer existing reload. Real firing resumes only after both locks permit it. Invalid duration/destination records are rejected. A version-1 fixture reconstructs with the documented Precision default and migration notice; shared scene-restoration suites remain passing.

Alpine Relay adds map-owned objective data to the existing `mission` field: exactly two relays, each with a validated player owner/candidate, bounded capture progress and contest flag. Other skirmish maps retain their empty objective record, and First Orders keeps its existing mission contract. `AlpineRegression.gd` rejects an invalid owner, writes and reads an actual archive, restores exact ownership and partial recapture, and resumes to completion for both factions. The second neutral relay remains independent. Map-specific cold lighting is reconstructed from the map scene rather than serialized.

`tests/headless/SaveSnapshotRegression.gd` exercises a real First Orders match: harvesting produces cargo, a worker constructs a building, Lua evaluates contacts and state, a fitted tank job holds paid costs and an embedded version, orders reference an enemy, a rocket remains in flight, and a destroyed unseen HQ retains its remembered visual identity. Paused capture, exact file round trip and deep-copy independence pass. It also checks nonfinite/object/unknown-tag/duplicate-key/overflow/deep input rejection, future-version/corrupt-file preservation, source-bound checkpoint resume, invalid-state reset, fault suspension and explicit clean Resume.

A second actual match expands to 100 mobile units per side, with 188 tank VMs carrying approximately 31 KiB source and a 2,000-element explicit state each. The snapshot is **18,818,596 bytes** and round-trips without value changes. This verifies storage capacity for that fixture, not live 200-unit combat performance or maximal pathological source/state combinations.

The same test runs with the Metal renderer. Its saved exploration PNG decodes to 160 × 128, and explored base terrain differs from unexplored terrain. Existing `LuaSandboxRegression.gd` and `CombatRegression.gd` pass after shared runtime/knowledge changes. Editor import, changed-file format/lint and diff whitespace checks pass. Existing navigation GPU-readback and shutdown-only shader/RID/ObjectDB/resource warnings remain.

## Scene reconstruction (stage 2 delivered)

`MatchRestore.prepare()` copies and validates inert data before changing the live scene. The schema checks exact records, supported maps/roles/actions, reference domains (player IDs cannot masquerade as targets), ownership, active/reserved population, action state types/child roles/timers, pins and embedded program identity. Exploration dimensions are checked in the PNG header before image decoding. Malformed data retains the live match and its pause state.

`restore()` pauses, releases the old match before constructing the replacement (global groups and signal subscribers must not overlap), restores paid balances/queues and units, rebuilds navigation, then reconnects actions/timers/references. Ordinary action `_ready` side effects are suppressed during restoration: no extra shot, resource deposit, payment or program reactivation. In-flight damage retains its remaining time. Saved manual orders remain in charge; suspended Lua stays in Error until explicitly resumed. A missing nested harvest/build target drops the operation to Hold without discarding cargo; a missing retrofit service cancels installation and refunds its paid 4 E once. The source save is never modified by loading.

A loaded battle remains tactically paused, with the HUD owning that pause so Resume/Space works. Player signals refresh population and power immediately. Current visibility is rebuilt separately from accumulated exploration; remembered live and orphaned structures reconnect without revealing hidden current positions. The rendered campaign test compares every exploration pixel before/after a synchronized paused reload.

Verification caught two user-visible defects: the initial paused loader could not release its pause through the HUD, and its population/power labels stayed at initialization values. Both have regressions. Rendering also caught a 1.6 m relay displacement: paused navigation rebuilding already contained its obstacle footprint, so full position snapping moved it to the edge of its own hole. Restoration now retains authored horizontal obstacle positions and aligns elevation; the relay transform and exploration pixels remain unchanged.

Additional tests:

- `SaveRestoreRegression.gd`: actual campaign disk save → scene reconstruction → real resume, movement/queued authority, harvesting cargo, construction, paid exact-version production, Lua state, retreat hysteresis, squad claims, mission durations, cooldown/damage suppression, pending projectile, malformed input rejection and paused HUD values. Its Metal run uses real mouse input on Resume at 1280 × 720. [Review image](../art/skirmish/save-restored-paused-720p.png).
- `SaveRestoreEdges.gd`: both factions, repeated load/save capture, partially completed paid retrofit, dead gather/service targets, manual control after fallback, suspended faults, invalid-memory recovery, remembered structures and all three skirmish map reloads.
- `SaveRestoreCombat.gd`: an actively firing Helix tank retains its shot count and timer, does no damage while paused and resumes repeating fire on schedule.
- Shared combat, manual orders, basic programs/retrofit, navigation, campaign and skirmish regressions pass. Editor import, changed-code lint/format and whitespace checks pass. Navigation was rerun after the obstacle restoration correction. Existing navigation GPU-readback and shutdown-only shader/RID/ObjectDB/resource warnings remain.

Preflight rejection preserves the current battle; rollback after replacement starts is **not** provided. A bounded navigation synchronization failure returns the new battle paused with an error and keeps the source save intact. The player flow now freezes that incomplete battle and offers another load or Main menu; it cannot resume or save it.

## Player archive and checkpoints (stage 3 delivered)

- Main menu **LOAD BATTLE**, battle menu **Save / Load battle**, and result-screen **Load saved battle** open the same archive. The native controls support keyboard focus, arrow-key slot selection, Enter activation and Escape cancellation. Mouse/input and layouts were verified at 1280 × 720.
- Five manual slots, one quicksave and three campaign checkpoint slots live in `user://saves/`. Slot summaries show the public map/mission name, both factions, simulation time and timestamp labeled UTC. Selection uses a filled background and retains a visible keyboard focus indicator. Checkpoint slots cannot be overwritten manually.
- **F5** saves the current battle to the quicksave slot, replacing a valid prior quicksave. **F9** opens the archive with Quicksave selected. Loading over an active battle and overwriting a manual slot each require a second explicit confirmation; Escape cancels without changing the battle or save. From the main menu, Load selected needs no battle-replacement confirmation.
- The archive owns a modal pause and temporarily disables the current scene's input/processing overrides, including the camera and placement/group controls. Closing restores each prior process mode, keyboard focus and pause ownership. Program editors must be closed before opening the archive. Loaded games retain tactical pause with working Resume.
- File inspection, serialization and reconstruction show progress/feedback. Archive scans yield between slots so the modal can paint its progress. Writes use the existing verified temporary-file replacement. Corrupt, unsupported or gameplay-incompatible slots are visible but cannot be loaded or overwritten; errors retain the source and keep the archive usable.
- First Orders queues automatic checkpoints on operation start, lab completion, valid program assignment and friendly relay capture. Split Signal queues them on operation start and friendly relay capture. A checkpoint waits for navigation readiness and for modal/tactical pauses to end, freezes a simulation boundary, writes the next of three slots, then restores play. No checkpoints run for skirmish or arena scenes. Restoring a checkpoint does not replay the initial checkpoint or completed lesson transitions. Repeated captures can create later checkpoints. Rotation skips damaged/incompatible originals and reports when no writable checkpoint slot remains.
- Main-menu startup enables automatic checkpoints for normal sessions. Test harnesses can leave them off and supply a per-process save directory. Tests using the real campaign menu isolate their automatic files from player saves.

### Verification and measured limits

`SaveSlotsRegression.gd` checks quick/manual capture, world-input isolation, pause/focus restoration, malformed and gameplay-invalid sources, retained files, usable rejection feedback and the four real mission checkpoint triggers/three-slot rotation. It deliberately postpones the real navigation rebake beyond the loader's bounded wait, verifies post-replacement recovery restrictions and source preservation, then retries successfully and separately returns to Main menu before loading again.

`SaveSlotsPreview.gd` drives real buttons/keys at 720p: menu entry, Save, overwrite confirmation/cancel, F5/F9, active-battle load confirmation, Resume, arrow-key selection, corruption feedback and main-menu loading. [Manual save](../art/skirmish/save-manual-720p.png), [load confirmation](../art/skirmish/save-load-confirm-720p.png), [corrupt slot](../art/skirmish/save-corrupt-720p.png), [loaded battle](../art/skirmish/save-loaded-720p.png). Initial visual review found concatenated ItemList newlines; rows now use clear separators with full details below. Rendered skirmish saving also exposed `Vector2` versus `Vector2i` map dimensions in fog validation; the schema normalizes map dimensions and the actual F5/F9 flow passes.

`SaveLoadScale.gd` loads a real 200-mobile, 188-program snapshot (18,818,596 bytes), checks every large explicit memory, then saves the loaded army again. Timings are local M1 Pro headless storage/reconstruction measurements, not combat frame-rate or lower-end-device guarantees. See the current measured timings in the development roadmap. Inspection and serialization remain synchronous within each file; opening many large slots can take several seconds, with progress between slots.

Shared headless campaign, skirmish, orders and restoration regressions pass. The real campaign build/program/reuse/result flow still passes with checkpoint saves enabled. Changed-code formatting/lint, editor import and whitespace checks pass. Existing navigation readback and shutdown-only renderer/ObjectDB/resource warnings remain. Native platform/export acceptance, lower-memory devices and forced interruption during writes remain unverified. Cloud synchronization, arbitrary imported map saves and blanket compatibility beyond the explicitly supported snapshot versions remain outside this contract.


### Broken Foundry campaign state — 2026-10-03

Gameplay-v5 mission records include the district alarm, exactly two production-node references/disabled flags/batch counts/timers, control ownership/candidate/progress/contest, cumulative secured time, final response and HQ recovery countdown. Actual paid jobs, remaining production time and fitted chips use the existing ordinary factory archive; restored outputs regain their mission Guard assignment through the normal production-finished signal. Validation rejects duplicate/wrong-role nodes, production budgets beyond three batches, capture before both nodes are disabled, invalid response timers and completed missions. Campaign-progress schema 5 adds `broken_foundry`, retains schemas 1–4, and preserves earlier badges when any operation is replayed. Command Horizon now consumes this flag on fresh starts; its saved route controls geometry during restoration.

### Command Horizon campaign state — 2026-10-03

The finale's gameplay-v5 record preserves the alternate route, deployed flag/secured time, control ownership/candidate/progress/contest, target HQ reference or destruction, friendly HQ recovery, response start/clock/warning/sent counts and replay challenge. The route is applied before map creation, so campaign rewards earned after saving cannot change a loaded battlefield. The challenge is restored before mission setup; it does not reapply initial resources or troops. Validation rejects inconsistent phases, invalid target ownership/role, response counts beyond four, unsupported challenges and already-finished states.

Disk round trips cover partial capture, owned-but-empty deployment, destroyed enemy HQ before recapture, both route geometries and Lean/Reinforced modifiers. Paused state remains exact. Campaign-progress schema 6 reads schemas 1–5, adds finale and two challenge completion flags, and only reports campaign completion when all six operations are recorded. The original completion badges remain independent and preserved.

These scenarios exposed a shared turret restoration defect: the turret's ordinary order restriction discarded its archived action while reconstruction tried to start the detached timers. Anti-ground and anti-air turrets now accept the internal restoration action and retain the normal order restriction. The regression compares exact action/timer state and resumes actual ground/air damage; the shared active-shooting archive suite also passes. See [Command Horizon verification](playtests/2026-10-03/COMMAND_HORIZON.md).

Horizon environment verification additionally covers an aircraft archived above a solid berm: actual altitude and horizontal position survive a paused disk round-trip, then observation and projectile damage resume. Clearance is derived from the authored map, so no archive-schema change is required. See [environment checks](playtests/2026-10-03/HORIZON_ENVIRONMENT.md).

### Industrial Crossroads and Foundry environment — 2026-10-03

Industrial Crossroads extends the supported map catalog with a 128×104 map and the same exactly-two-relay objective contract as Alpine. Its version-6 neutral record must contain exactly the 14 authored IDs: two cars, eight residents and four foxes. Routes/assets remain catalog-owned. Exact relay owner/partial-recapture and neutral state survive disk reconstruction; both-faction mid-movement saves resume. Industrial and Broken Foundry aircraft also preserve their actual 8 m altitude over the new roofs. Building geometry and clearance profiles are reconstructed from installed scenes, with no additional schema version. Existing snapshot versions 1–5 retain the documented default-neutral migration. See [verification](playtests/2026-10-03/INDUSTRIAL_CROSSROADS.md).

### Resource clearance and navigation lifetime — 2026-10-03

Each restored battle now owns a separate ground navigation map, matching the existing air-map lifetime. The runtime rebuilds resource footprints from their actual avoidance radii. No navigation RID or polygon enters the archive, and the schema stays at version 6. A saved engineer inside a formerly admitted narrow gap retains its exact paused position and four electronics; resuming moves it out and delivers exactly that cargo. Deposit depletion then removes the footprint normally. Both-faction field restoration/version-4 migration, live combat/job/action/cargo restoration and save-slot/checkpoint/failure-recovery checks pass with this lifetime change. See [resource-navigation verification](playtests/2026-10-03/RESOURCE_NAVIGATION.md).


### Coastal Foundry — 2026-10-03

The supported catalog now includes the 128×104 coastal map. Its mission dictionary is empty: victory uses ordinary skirmish HQ/recovery state. Snapshot version 6 requires exactly the 13 authored neutral IDs (two cars, six residents, four gulls, one tug); route heights, geometry and model paths remain trusted map content. Gull wing angles and tug bob/roll derive from the saved phase, so the existing record retains their poses. Older supported archives receive the standard default-neutral migration.

Ground navigation rebuilds from the actual shore polygon and excludes the inlet. The freighter remains at its water position and never snaps to the ground navmesh. Disk round-trips retain moving tank positions, a strike aircraft's 9.3 m crane-clearance position, neutral records and resource counts. Resuming completes ground movement and the aircraft water crossing. Water reads the saved simulation clock immediately while paused, then resumes normal animation; no shader-specific or naval state is added to the archive. See [verification](playtests/2026-10-03/COASTAL_FOUNDRY.md).


### Last Lua guard intent — 2026-10-04

Snapshot version 6 now writes `_guarding_area` in Lua action state. This optional boolean retains the selected guard boundary even when a blocked program cannot reevaluate after loading. The validator rejects non-booleans and unknown action fields; archives without the flag still load and default to false until their next program evaluation. Loading never runs Lua to reconstruct the missing intent. Existing visual-rule metadata can independently identify its guard area. Both-faction paused disk replays and unchanged runtime checkpoints are covered by [blocked-assignment verification](playtests/2026-10-04/BLOCKED_ASSIGNMENTS.md).


## Crowded point-order observation — 2026-10-04

New plain Move records include the elapsed arrival-observation time and its position origin. Restoring the real disk file preserves these values, position, simulation time and queued departure while paused. Older records without either field remain valid and start their observation after resuming. Both fields must be present together; invalid timer values and an active timer without a valid origin are rejected. Contact actions retain their own behavior. See [route-end verification](playtests/2026-10-04/ENDPOINT_TAIL.md).

AttackMove now persists the same bounded occupied-endpoint observation as plain Move. Active firing resets that observation, so combat time cannot count as stalled travel. Earlier AttackMove records without both fields remain valid; partial or invalid observations are rejected. The earned crowded-battle archive, paused disk handoff and native continuation are covered in [crowded AttackMove verification](playtests/2026-10-06/ATTACK_CROWDED_ARRIVAL.md).

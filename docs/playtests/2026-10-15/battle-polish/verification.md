# Battle polish verification — 15 October 2026

## Changes

- Shared, thin translucent attack-range rings for single-unit selection and building placement previews. Group selections suppress attack circles, retaining compact ownership outlines; returning to one selected unit restores its range, including after another selected unit is destroyed. Player-colored ground selection outlines replace overhead ownership dots.
- A production click chooses the eligible selected building with the least remaining work. Mixed building selections expose their combined roster and paid queues; cancellation refunds the correct building's job. Queue display scrolls within the HUD.
- Friendly mobile units yield at obstructed exits while retaining their original destination, orders and program. Production first tries clear alternate exits, then requests a local sidestep, including adjacent allies in packed rows. Enemy and static blockades still matter.
- Cook-off turret debris retains its imported scale. Salvage hulls retain 90% of the source vehicle footprint; civilians, foxes and cars have consistent gameplay scales. Central settlements add neutral buildings, residents and traffic inside the playable area, with legacy-save compatibility.
- Chinese translations cover composed HUD text, map names and symbols, commands, tech requirements, selection, world labels and hover information. Restored 181 previously generated-only translations to the source catalog so rebuilding does not lose them. Literal keyboard key names remain recognizable.
- Faster construction and reinforcement production; resource costs and starting funds are unchanged. Existing paid jobs retain their purchased duration.

## Faction paths and pacing

The existing faction-specific models, weapons, heroes and abilities now have more distinct progression and specialist training times:

| Faction | Progression and mechanic |
| --- | --- |
| Bastion | Repair depots unlock Sentinels; Coordination gates siege armor. Faster assault infantry and heavy armor production complement Anchor sectors. |
| Helix | Flight decks follow operator hubs, without requiring a vehicle factory. Signal labs unlock mode-switching Lancers and Wraiths; Coordination gates deploying Prisms. Faster drones, walkers and aircraft. |
| Frontier | Motor pools unlock Jackals; field workshops unlock Ironbacks without Coordination. Faster workers, tanks and repair units; wreck material is recovered every 0.5 seconds. Maneuver Burst remains available through technology. |

The AI's expansion order follows faction priorities, and UI tooltips expose the actual unlock requirements. Losing a required building suspends the affected paid job; rebuilding it resumes production.

At full power, one barracks and two vehicle factories delivered 12 infantry, 6 tanks and 2 repair units in **60.1 seconds** for each faction, paying the full faction-specific costs. This funded test rallies completed units away; packed exits are verified separately.

A standard-start scripted opening, using real gathering, paid construction, eight workers and rally movement, produced the same 20-unit force as follows:

| Faction | First armor | Complete force |
| --- | ---: | ---: |
| Bastion | 176.5 s | 278.5 s |
| Helix | 151.0 s | 227.0 s |
| Frontier | 146.0 s | 217.0 s |

These are uncontested scripted openings, not competitive balance guarantees. Enemy pressure and player spending choices change the result.

## Performance

Measured after functional fixes and rendered verification, using Godot 4.6, Metal Forward+, Apple M1 Pro, VSync disabled. Each timed rendered run ran alone. The baseline already included the presentation and production fixes.

| 200 mobile units + 80 structures, 1920×1204 | Before mean / p95 | After mean / p95 | Mean reduction |
| --- | ---: | ---: | ---: |
| Movement | 347.33 / 430.66 ms | 109.23 / 150.03 ms | 69% |
| Combat | 369.62 / 399.49 ms | 64.17 / 107.25 ms | 83% |

All 200 units moved and travelled; 159 fired in the final combat run versus 160 in the baseline. Ten simulation seconds now took approximately ten wall-clock seconds, versus 26–28 seconds before. The dense stress scene remains below a smooth frame rate (roughly 9 FPS moving / 16 FPS fighting); this pass does not establish smooth maximum-capacity battles on every machine.

A separate controlled gameplay sample at **1600×900**, 240 measured frames after warmup, averaged **123.9 FPS** around the base and **88.9 FPS** in a midfield fight with 40 added combat units (70 total player units/structures). The corresponding p95 frame times were 11.14 and 15.63 ms. Strategic AI was disabled for this repeatable sample; unit simulation and combat remained active. This is an after-only measurement, not a before/after FPS claim.

Profiling identified repeated minimap circle/polygon GPU allocations, idle structure/production work, and whole-army scans. Changes cache antialiased minimap symbols, update marker positions at 20 Hz, stop empty queues, retain settled idle structure poses, reuse the battlefield spatial index for nearby queries, reject distant visibility candidates early, and skip unchanged stationary navigation projections while respecting navmesh revisions.

Raw results: [baseline stress](../performance/scale-before.log), [final stress](../performance/scale-final.log), [gameplay sample](../performance/gameplay-final.log).

## Verification

All focused regression checks passed. GDScript formatting/lint, translation generation (2,406 keys), Godot import and `git diff --check` also passed. Coverage includes:

- Multi-building queue distribution, mixed producers, full queues, cancellation/refunds, range preview creation/cleanup and player-color selection.
- All-faction wreck/debris and actor scale; real Metal-rendered cook-off verification.
- Workers, infantry, armor and aircraft departing through friendly blockers; packed nine-tank rows, preserved orders, hostile blockades and single charging.
- Faction unlock paths, actual paid orders, prerequisite loss/rebuild, unique weapon modes, and archived queues.
- Full-power reinforcement pacing and resource-funded standard openings.
- All 11 maps' civilian routes, motion, yielding, pause, fog, combat isolation and save/load validation; pre-settlement archives and old mercenary durations.
- Chinese catalog and composed labels; rendered Chinese production, placement and central-settlement screens.
- Combat, repair, construction contracts, program execution, Frontier salvage and abilities, AI production delivery and counter composition, ownership/inspection, crowd boundaries and guard arrival.

Relevant executable fixtures live in `tests/headless/`, `tests/playtest/OpeningPacing.gd`, and `tests/rendered/BattlePolishPreview.gd`. Reproduce a focused headless check with:

```sh
Godot --headless --path . --fixed-fps 60 --script tests/headless/ExitClearanceRegression.gd
```

Reproduce rendered measurements with:

```sh
Godot --path . --disable-vsync --script tests/headless/ScaleBenchmark.gd -- --realtime
Godot --path . --disable-vsync --script tests/rendered/BattleFrameBenchmark.gd
```

Rendered review: [group selection](group-selection-zh.png), [production](balanced-production-zh.png), [central settlement and scale](central-settlement-scale-zh.png), [placement range](placement-range-zh.png).

The Godot test harness still reports existing ObjectDB/resource/RID cleanup leaks at shutdown in several otherwise passing fixtures. Those warnings are retained in benchmark logs; they are separate from assertion or runtime-script failures.

## Group-selection follow-up

Reproduced the overlapping-circle clutter from the supplied screenshot. Verified 18 selected units in a rendered frame without attack-range circles, plus single/mixed selection transitions, deselection, selected-unit deletion and retained placement previews across all three factions. Also corrected a unit-ready subtitle translation found during rendered inspection.

## Chinese UI follow-up

The supplied SOUTH RELAY screenshot exposed a separate screen-space locator that prepended a diamond to an untranslated key. Relay locators now translate the title before decoration, use the bundled Chinese font, and refresh on live language changes, including while paused. Relay overview titles/buttons and Split Signal's campaign markers use translated components too.

The wider audit found translated paragraphs being split into unmatched fragments in multiline tooltips. The adapter now preserves complete lines and known sentence prefixes, then translates the remaining segments without destroying longer matching phrases. The catalog builder retains whitespace-wrapped legacy keys and generates their trimmed equivalents. Added missing setup, command, resource, campaign and 230 distinct voice-caption translations; the complete catalog now contains 2,406 keys.

`tests/headless/ChineseUIRegression.gd` inspects actual assembled labels, menu options and tooltips in the main menu, lore, setup, campaign selector, settings, all three factions' production/technology/relay panels, and all six campaign HUDs. It also checks all 711 voice-caption entries. The final rendered run checked 1,102 distinct UI strings with zero failures. Product/language names, standard MSAA terminology and literal keyboard key labels are allowed; editable player text and hidden developer panels are outside this UI audit.

`LocalizationRegression` and `RelayOverviewRegression` also pass, including real relay capture, camera navigation, save/restore, retained orders and pause behavior. GDScript lint and whitespace checks pass. Rendered review: [south relay locator](relay-marker-zh.png), [relay overview](relay-overview-zh.png). An already-running game needs a restart to load the rebuilt translation catalog.

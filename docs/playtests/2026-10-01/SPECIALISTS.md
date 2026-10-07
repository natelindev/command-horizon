# Specialist unit programs

## Delivered

- Standoff for conventional chipped tanks and long-range armor: back away below 55% of weapon range, settle near 80%, then fire. Desired retreat positions stay inside the assigned area; boundaries do not authorize unlimited kiting.
- Strike & return for aircraft: require area and regroup point, launch one actual projectile, return, wait for the existing weapon cooldown, and re-evaluate targets. Damage retreat retains health hysteresis. No new ammunition/fuel resource.
- Fire support for walkers and long-range armor: occupy the anchor, select only legal targets in weapon/sector range, and do not pursue.
- Named Scout route, Escort & repair and Service area presets expose existing bounded scout/service behavior through role-specific choices.
- All specialist choices use the same manual authority, squad claims, observation, firing, repair and saved-version rules. Factories validate compatibility both when reserving the job and when spawning it; unsupported roles receive Hold with an explanation.
- Preset dropdowns filter by role. Mixed Apply and map assignments touch only compatible members. Incompatible saved drafts disable Apply. Aircraft UI labels its safe point as a regroup point. Mixed-selection guides choose a member with an actual assignment. Factory notices received during assignment are deferred rather than discarded.

## Verification

`SpecialistRegression.gd` passes for Bastion and Helix:

- Valid shipped defaults and library round trip; compatible factory snapshots; incompatible snapshot/Apply rejection preserves existing orders and uses Hold fallback.
- Actual standoff movement, sector bounds, subsequent damage and manual interruption.
- Fire-support arrival, damage and no pursuit of an escaping target.
- Repeated actual one-projectile sorties, regroup before the next launch, cooldown, tactical pause, damage retreat/60%-health hold/full recovery and manual override.
- Missing scout/escort assignments wait; patrol movement and both named repair presets function.

`SpecialistPreview.gd` passes the rendered 1280×720 workflow: filtered roles, mixed tank/air selection, selective area/regroup assignment, saved version, Apply during pause, incompatible saved draft on armor, standoff Apply, and deferred factory notice. Review images were visually inspected.

Existing `CombatRegression.gd`, `ProgramRegression.gd`, `SquadRegression.gd`, `CoordinationRegression.gd`, `Skirmish.gd` and rendered `ProgramPreview.gd` pass. These cover weapon cooldown/visibility/damage, program bounds/authority, squad claims, factory rally/version inheritance, prerequisites, economy, faction pairings and match lifecycle. Formatting, lint and whitespace checks pass.

Some existing headless suites retain navigation GPU-readback warnings and shutdown resource/RID diagnostics. No gameplay assertion or script errors remain in the passing runs.

## Workload

The rendered benchmark uses 200 mobile units, 80 structures and 32 resource deposits, with five specialist behaviors (standoff, strike-return, fire support, scout route and service area) across ten squads. Escort repair is covered by the behavior regressions. Aircraft, scouts and support units use their own assignments; both factions pay no benchmark damage attrition because HP is elevated. It is a workload test, not a balance test. Frame times are fixed-step uncapped throughput on the development M1 Pro at 1920×1080, not a stable-60-FPS guarantee.

The benchmark records both final net displacement and cumulative travel, so a return trip is distinguishable from no movement. Final run: all 200 units travelled more than two metres; 196 also ended more than two metres from their start. 113 weapons fired. Sampled peaks were 80 squad claims, 23 projectiles and 22 tracers.

| Phase | Average frame | p95 frame |
| --- | ---: | ---: |
| Advancing | 19.95 ms | 32.77 ms |
| Combat | 23.85 ms | 34.32 ms |

The travel observer samples all unit positions during the advancing phase. Runs vary with navigation/render scheduling; these results do not establish a performance improvement over previous workloads. Frame spikes, target-hardware coverage and long-match profiling remain open.

## Review and remaining scope

- [Aircraft preset and mixed selection](../../../art/skirmish/specialist-strike-720p.png)
- [Standoff controls](../../../art/skirmish/specialist-standoff-720p.png)
- [200-unit specialist workload](../../../art/skirmish/scale-specialists.png)

These are shipped engine presets. Lua execution, visual compilation, custom sandbox limits, campaign/save-load, faction signatures and optional LLM authoring remain later roadmap work. Saved preset compatibility does not imply arbitrary code execution or full match persistence.

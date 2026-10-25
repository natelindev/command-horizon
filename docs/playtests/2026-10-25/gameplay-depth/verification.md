# Gameplay depth implementation and verification

Date: 2026-10-25. Implements the reviewed decisions in [the gameplay plan](../../../plans/gameplay-depth-and-immersion.md). Costs, damage, radii and cooldowns remain initial playtest tuning. This report records implementation and reproducible checks; it does not claim completed human balance testing.

## Delivered behavior

- Infantry suppression distinguishes confirmed rifle hits from heavy-fire near misses, preserves player orders, excludes heroes, and changes movement/reload/pose with fixed direct-fire protection while pinned. Projectile contribution bookkeeping prevents double buildup. Recovery, terrain occlusion and status survive saves.
- Grenades have simulation-owned flight and impact. Explicitly breaching an occupied hostile civilian building damages its occupants, evicts survivors and applies only a three-second garrison re-entry prohibition. Survivors can immediately move, fire and use abilities. Blocked exits wait for legal space, retaining subsequent orders through save/restore.
- Vehicle damage is cosmetic and faction-specific: Bastion diesel smoke/hull fires, Helix plasma leaks and restrained repulsor motion, Frontier steam/backfire/loose plates. Generated model sockets and two permanent Frontier plate tiers drive presentation. Ordinary combat cannot shake the camera; Skirmish rejects even direct cinematic impulse requests.
- Bastion Barracks and Vehicle Factories gain 8%/16%/24% assembly bonuses after consecutive completed units of the same role. Bonuses exclude departure animation; switching roles, canceling the active job or idling for five seconds resets the streak. Workers instantly deploy paid barricades with a cooldown and can explicitly dismantle their own barriers with `R`. Right-click repairs damaged owned barriers and ignores healthy ones. Barricades block both sides, retain valid access and can be crushed by tanks.
- Helix generators can toggle local shield-recharge Overdrive after Plasma Shields research, using three additional power. Coverage does not stack and suspends under low power. The Kite is an unarmed EW/recon drone whose chaff interrupts missile guidance without deleting missiles.
- Frontier workers and Outriders deploy paid concealed mines. All mobile units can detect them; combat units neither acquire them automatically nor route around them. One successful explicit weapon hit clears a selected mine. Workers of every faction have an explicit area-clearance command. Frontier salvage preserves the existing temporary buffs and adds separate permanent 5%/10% armor and plate tiers.
- Eight authored maps schedule automatic environmental events at 5:00 and 11:00 with 45-second warnings. Any owned mobile ground unit can collect a nearby reward in one interaction. Each occurrence shares a total 10 Materials + 5 Electronics on desert/coastal maps, or 5 Electronics on industrial maps, across all starts; rewards never multiply by player count. Supplies expire after 180 seconds. Linked Alpine terminals accept the first claim for one three-second global enemy-position snapshot, with a 60-second interaction window and no observation, exploration, targeting vision or mine detection. Claims are atomic, blocked landings try authored alternatives then cancel publicly, and reload does not repeat notices or rewards. Events can be disabled; Campaign requires explicit opt-in.
- Commander support provides Bastion barrage, Helix EMP and Frontier two-Outrider airdrop with a repair crate. Barrage/EMP cost 50 Materials + 30 Electronics; airdrop costs 45 Materials + 15 Electronics. Accepted effects retain frozen ownership and targeting, spend atomically, and survive loss of the enabling lab. Airdrops reserve population and are vulnerable to physical AA interception. Targeting uses current vision for offensive powers and explored legal terrain for airdrops.
- Bottom-HUD controls expose these features with tooltips, disabled reasons, Chinese localization, status readouts and minimap markers. `F6` opens Commander support and contextual `Q` targets it; canceling costs nothing and preserves selection/pause. Existing key profiles retain their bindings when the new command is added. Worker Build submenus include field engineering; `R` rotates a barricade preview. Helix generator `E` is a compact support control.
- Skirmish AI uses the same costs, unlocks, visibility and cooldowns for tactical abilities, engineering, commander support and nearby event rewards.

## Persistence

`MatchSnapshot.VERSION` is now **21**. New timers, delayed impacts, EMP states, exploration, mine/engineering actions, reservations, event ledgers, assembly streaks and permanent salvage ranks are captured and validated. Runtime loading still accepts only the current version.

The one-off archive converter is [convert_gameplay_depth_archives.gd](../../../../tools/saves/convert_gameplay_depth_archives.gd). All **811** archived snapshots were converted. The independent [identity audit](logs/ArchiveIdentityAudit.txt) compared **29,764** ordered unit ID/owner/role mappings and **13,040** resource ID/kind mappings against their pre-conversion contents: **zero mismatches**. Obsolete saved Helix dive orders are removed without changing unit/resource identity. Permanent salvage armor initializes only from recorded active salvage stacks.

## Verification

Checks run with Godot 4.7.2. Use `--fixed-fps 60` when reproducing timing-sensitive integration fixtures, as shown below. All **36** headless suites listed here pass; the linked files preserve their actual output.

| Area | Passing checks |
| --- | --- |
| Infantry and weapons | [Suppression](logs/InfantrySuppressionRegression.txt), [breach](logs/GarrisonBreachRegression.txt), [abilities](logs/UnitAbilitiesRegression.txt), [projectile physics](logs/ProjectilePhysicsRegression.txt), [projectile persistence](logs/ProjectileSystemRegression.txt), [grenade presentation](logs/grenade-flight-presentation.txt) |
| Existing capture and garrisons | [Firing/exits across 12 shelters on three maps](logs/GarrisonCombatExitRegression.txt), [authored garrison restore](logs/AuthoredGarrisonRegression.txt), [capture channel/interruption/pause](logs/BuildingCaptureRegression.txt) |
| Faction mechanics and AI | [Bastion assembly](logs/bastion-assembly.txt), [field engineering](logs/field-engineering.txt), [Helix support and scrap expiry](logs/HelixSupportRegression.txt), [tactical AI](logs/gameplay-depth-ai.txt), [Skirmish defense](logs/skirmish-defense.txt) |
| Events and support | [Battlefield events](logs/battlefield-events.txt), [commander powers](logs/CommanderCallInsRegression.txt) |
| HUD and controls | [Operations submenus](logs/OperationsSubmenuRegression.txt), [key bindings](logs/KeyBindingsRegression.txt), [direct orders](logs/DirectOrdersRegression.txt), [HUD production](logs/BattleHudProductionRegression.txt) |
| Presentation | [Vehicle damage visuals](logs/vehicle-damage-visuals.txt), [damage audio](logs/vehicle-damage-audio.txt), [camera feel](logs/camera-feel.txt), [combat effects/audio](logs/combat-juice.txt), [model texture contracts](logs/rich-textures.txt), [unit animation](logs/UnitAnimationRegression.txt) |
| Progression and setup | [Power](logs/PowerBalanceRegression.txt), [technology](logs/TechnologyRegression.txt), [faction tech paths](logs/FactionTechRegression.txt), [match setup](logs/MatchSetupRegression.txt) |
| Persistence | [New gameplay state across three factions](logs/GameplayDepthSaveRegression.txt), [811 archived snapshots and 389 checksums](logs/ArchivedSnapshotRegression.txt), [snapshot scale/corruption](logs/SaveSnapshotRegression.txt), [restore](logs/SaveRestoreRegression.txt), [combat restore](logs/SaveRestoreCombat.txt), [restore edges](logs/SaveRestoreEdges.txt) |

The regression scenarios include blocked breach exits with queued orders across a reload, short-range grenades and suppression blocked by terrain, EMP preserving a turret's current attack/reload state, three AA units physically intercepting the descending carrier, population reservations blocking production at the cap, explored map-edge cells, public event cargo in fog without granting vision, and free target cancellation while preserving selection and pause. UI tests send actual keyboard and mouse events, including right-click cancellation, Commander `F6`/`Q`, generator `E`, and barricade rotation.

Several older fixtures finish successfully but report audio/resource cleanup warnings while the process exits. Those warnings remain in the logs; passing assertions are not a claim of a completely warning-free engine shutdown.

Focused GDScript lint passes for [commander/HUD integration](logs/CommanderHudLint.txt), [infantry and saves](logs/InfantryAndSavesLint.txt), [presentation/events](logs/presentation-events-lint.txt), and [updated garrison fixtures](logs/GarrisonFixtureLint.txt). `git diff --check` also passes.

Non-headless rendering passed the [118-capture HUD matrix](logs/HudConsolePreview.txt) in English and Chinese, with Bastion/Frontier at 720p and 1.5× UI scale and Helix at 1080p; [suppression](logs/InfantrySuppressionPreview.txt) produced three captures; [vehicle damage](logs/vehicle-damage-preview.txt) produced nine; and the prescribed [weathering review](logs/weathering-preview.txt) produced ten. An earlier [50-capture Helix review](logs/HudConsoleHelixFinalPreview.txt) verified localized operating/suspended feedback and dimmed generator cores; the latest full HUD matrix repeats these checks with the revised three-power Overdrive demand and airdrop price. Visual inspection confirms matching power totals, readable suspension feedback and the localized 45/15 price. The [ten-capture commander preview](logs/CommanderSupportPreview.txt) exercises warnings, impact/descent and field support. The [eight-capture map-event preview](logs/battlefield-events-preview.txt) covers desert, industrial, coastal and alpine performances. Visual inspection checks text size, compact controls, minimap header placement, faction damage identity, and world-space warning readability. Final aircraft/carrier silhouettes, detailed supply/repair crates and the radar dish have also been inspected. Each transient transport or supply visual uses one merged mesh.

The legacy authored-garrison and garrison firing/exit fixtures initially inspected neutral capture after only four or six seconds. `Garrisoning.gd` already required a 15-second capture channel in the pre-change code. These fixtures now wait for actual entry, bounded at 20 simulation seconds, and the authored-map probe keeps unrelated AI attacks disabled. The firing/exit fixture first captures with one soldier, then orders the other seven inside and still verifies all eight occupants: this isolates firing and evacuation from approach congestion, which can restart capture under the existing distance rule. These are fixture corrections; gameplay capture duration, group entry behavior and entry rules are unchanged.

### User review fixes and initial balance adjustment

The reported right-click dismantling and large-building barrage misses were reproduced before fixing them. The retained [barricade reproduction](logs/review/FieldEngineeringBeforeFix.txt) has two expected failing assertions; the [barrage reproduction](logs/review/CommanderFootprintBeforeFix.txt) has eight. These files intentionally document the original failures, not the final result.

- A worker's right-click on a healthy owned barricade now leaves its current orders intact. Damaged owned barricades still offer repair. Dismantling requires the explicit `R` command and a target click, retaining its two-second duration and zero refund.
- Barrage candidate lookup includes intersecting building footprints, including rotated elongated structures, and deduplicates targets. Mobile-unit blast reach and ordinary weapon queries are unchanged. Center-based damage falloff retains its 25% floor. Against the default 500-HP headquarters with radius 2.2 m, the centered six-shell pattern now deals **189 damage** (64 + five hits of 25), leaving **311 HP**. Tests cover each outer shell, footprint-edge hits, just-outside misses and duplicate-hit prevention.
- Frontier airdrop now costs **45 Materials + 15 Electronics**; barrage and EMP remain **50 + 30**. The carrier retains **120 HP**, physical AA vulnerability and the two-population reservation. This reduces the resource premium while preserving interception as a meaningful counter.
- Helix Overdrive now adds **3 power demand** per enabled generator. Recharge remains 9 HP/s within 12 m after the existing five-second no-damage delay. This lowers the grid burden without improving shield recovery under sustained attack. Availability checks, payment, AI decisions, HUD prices/tooltips and Chinese localization use the revised values.

After the changes, six relevant suites pass with clean logs: [field engineering](logs/field-engineering.txt), [Helix support](logs/HelixSupportRegression.txt), [tactical AI](logs/gameplay-depth-ai.txt), [operations submenus](logs/OperationsSubmenuRegression.txt), [commander support](logs/CommanderCallInsRegression.txt) and [gameplay save/restore](logs/GameplayDepthSaveRegression.txt). Coverage includes one-resource-short rejection without side effects, exact-price airdrop acceptance, physical AA interception, exact three-power AI eligibility, actual right-click and explicit dismantle input, and saved support effects. The full [118-capture HUD matrix](logs/HudConsolePreview.txt) also passes after these adjustments. [Focused pricing/integration lint](logs/review/CommanderPricingLint.txt) and whitespace checks pass. Save format remains version 21.

These numerical changes are conservative initial defaults approved by the user, not a claim of competitive balance. Representative human matches remain necessary to measure call-in value and Overdrive uptime.

### Dense-army presentation timing

[VehicleDamagePerformance.gd](../../../../tests/rendered/VehicleDamagePerformance.gd) measured 96 stationary tanks, AA vehicles and combat robots per faction on Apple M1 Pro (Metal Forward+). Each phase warmed up for 180 frames and recorded 240 frames with the FPS cap and VSync disabled. The sequence was presentation off → on → off. All units retained 24% HP, position, orders and chassis motion; only particle emission and audio used existing presentation gates. The probe asserts unchanged authoritative state and bounded voice allocation. Raw results are in [vehicle-damage-performance.json](vehicle-damage-performance.json) and the [run log](logs/vehicle-damage-performance.txt).

| Faction | Frame median / p95, off (ms) | Frame median / p95, on (ms) | Godot process median, off → on (ms) | Added draw calls |
| --- | ---: | ---: | ---: | ---: |
| Bastion | 12.12 / 16.10 | 12.21 / 15.81 | 13.77 → 14.35 | 3 |
| Helix | 11.41 / 14.71 | 11.39 / 14.85 | 12.61 → 12.85 | 2 |
| Frontier | 11.88 / 15.81 | 12.01 / 15.87 | 13.57 → 13.69 | 2 |

The second off-phase frame medians were 12.24 ms, 11.48 ms and 12.22 ms respectively. These small differences include run-to-run scheduling variance and are not a universal overhead estimate. All factions sustained at most four damage loops. The shared audio pool allocated four voices for Bastion/Helix and seven for Frontier including occasional backfires, below its 24-voice cap. Shared smoke/fire/spark capacities stayed fixed at 384/256/768 particles; damage presentation adds no per-unit particle emitter.

This probe isolates particle/audio overhead with damage-related chassis motion present in both phases. It does not measure the cost of enabling chassis motion, moving armies, simultaneous weapon effects, AI, long matches or other hardware. The process-time values are Godot monitor samples; frame times use wall-clock intervals between process frames.

Reproduce headless checks from the repository root with the installed Godot binary:

```sh
RTS_GODOT=tmp/tooling/godot-4.7.2/Godot.app/Contents/MacOS/Godot
"$RTS_GODOT" --headless --path . --fixed-fps 60 --script tests/headless/CommanderCallInsRegression.gd
"$RTS_GODOT" --headless --path . --fixed-fps 60 --script tests/headless/GameplayDepthSaveRegression.gd
"$RTS_GODOT" --headless --path . --fixed-fps 60 --script tests/headless/OperationsSubmenuRegression.gd
```

Run visual reviews with a real renderer:

```sh
"$RTS_GODOT" --path . --fixed-fps 60 --script tests/rendered/HudConsolePreview.gd -- --console-only
"$RTS_GODOT" --path . --fixed-fps 60 --script tests/rendered/CommanderSupportPreview.gd
"$RTS_GODOT" --path . --fixed-fps 60 --script tests/rendered/InfantrySuppressionPreview.gd
"$RTS_GODOT" --path . --fixed-fps 60 --script tests/rendered/VehicleDamagePreview.gd
"$RTS_GODOT" --path . --fixed-fps 60 --script tests/rendered/BattlefieldEventsPreview.gd
"$RTS_GODOT" --path . --script tests/rendered/VehicleDamagePerformance.gd
```

Captures are written under `art/hud-console/`, `art/commander-support/`, `art/infantry-suppression/`, `art/vehicle-damage/` and `art/battlefield-events/`. Generated review images are intentionally ignored by Git. Source assets were changed through their authoring scripts.

## Limits

The automated scenarios establish mechanics, input, persistence and presentation contracts. Human evaluation of warning comprehension, fun, matchup balance and long-match pacing remains outstanding. In particular, first-charge/repeat-call-in timing, suppression buildup and permanent salvage protection need representative human matches before claiming competitive balance. No ground texture change or Skirmish super-unit was introduced.

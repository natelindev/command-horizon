# Open RTS

![Open RTS](./media/screenshots/screenshot_1400x650.png "Open RTS")

Open Source real-time strategy game made with Godot 4.

## Game design

The evolving RTS design is recorded in
[the living game design document](docs/GAME_DESIGN.md), including confirmed
decisions, proposed mechanics, and open questions.

Units now use five built-in choices: **Auto-engage, Defensive, Follow, Guard and Hold Fire**. Choose them in the selected unit's Orders panel. Per-unit Lua programs, rule editors, chip fitting and factory program assignment are retired from battles. Guard positions, follow targets, stances and queued direct orders persist in battle saves; legacy scripted orders load as Defensive behavior. See [unit behavior rules](docs/UNIT_BEHAVIORS.md) and [performance measurements](docs/performance/RESULTS.md).

The [core gameplay specification](docs/CORE_GAMEPLAY_SPEC.md) and older playtest reports retain the project's design history. Economy, faction rosters, research, repair, capture, hero campaigns, dialogue and battle archives remain available.

Command Horizon now has a [first environment kit pass](docs/playtests/2026-10-03/HORIZON_ENVIRONMENT.md): industrial landmarks, varied rock cuts, worn roads and verified aircraft clearance. [Industrial Crossroads](docs/playtests/2026-10-03/INDUSTRIAL_CROSSROADS.md) adds a three-street skirmish district and detailed buildings shared with Broken Foundry. [Moving neutral life](docs/playtests/2026-10-03/AMBIENT_LIFE.md) adds civilian traffic, walking residents and wildlife across six maps. [Neutral world interaction](docs/playtests/2026-10-11/neutral-world/README.md) adds eight-person infantry garrisons, explicit neutral targeting, panic reactions, animated destruction and persistent ruins. Right-click a habitable building with infantry to enter; select its occupants and move or choose **Leave building** to exit. Captured buildings keep their owner when emptied, including across saves. Enemy infantry can recapture an empty building; defended buildings must be cleared first. Use **Attack target** (default **T**) to attack a neutral building with infantry. [Expanded infantry and faction heroes](docs/playtests/2026-10-11/infantry-heroes/README.md) adds rifle, anti-armor, sniper and assault infantry, plus one unique hero per player with a persistent gold aura. Train heroes at barracks after building a command lab; alive and queued heroes share the same limit, and fallen heroes can be retrained. [Coastal Foundry](docs/playtests/2026-10-03/COASTAL_FOUNDRY.md) adds a harbor inlet, two ground routes, an air shortcut, cranes, vessels and gulls. Its [coastal environment pass](docs/playtests/2026-10-04/COASTAL_ENVIRONMENT.md) now adds continuous sea/terrain, breakwaters and rocky headlands, port service yards and wind-shaped pines. [Desert Frontier](docs/playtests/2026-10-03/DESERT_ENVIRONMENT.md) now has layered sandstone shelves, canyon surroundings, abandoned extraction/freight landmarks and varied sand/haul-road materials. [Alpine Relay](docs/playtests/2026-10-03/ALPINE_ENVIRONMENT.md) adds glacial shelves, snowy mountain and conifer surroundings, communications stations and connected plowed routes. Final environment work remains in progress.

[Resource navigation and map startup](docs/playtests/2026-10-03/RESOURCE_NAVIGATION.md) now have verified narrow-gap routing, reliable gathering/delivery, and per-battle navigation. The field-access audit covers both factions and all 11 resource-bearing maps. [Crowded Move destinations](docs/playtests/2026-10-04/CROWDED_DESTINATION.md) now settle beside an ally occupying the final reachable point, allowing queued orders and stationary treatment to continue. [Blocked assignments](docs/playtests/2026-10-04/BLOCKED_ASSIGNMENTS.md) identify owned-structure obstructions and retain Lua guard boundaries after loading.

[Air-defense guidance](docs/playtests/2026-10-05/AIR_DEFENSE.md) now selects compatible counters or offers existing anti-air cover, explicit Helix stance controls and real construction guidance when aircraft threaten your economy. [Live research feedback](docs/playtests/2026-10-05/RESEARCH_FEEDBACK.md) shows progress, available choices and lab-loss stalls in the existing command message area. [Resource inspection](docs/playtests/2026-10-05/RESOURCE_INSPECTION.md) shows observed deposit stock and wreck recovery details in one hover card, and aircraft ownership captions now respond to the pointer. The [engineer shortcut](docs/playtests/2026-10-05/ENGINEER_RESPONSE.md) selects endangered workers during raids and preserves their orders until you explicitly move them. Selected engineers can [Return cargo](docs/playtests/2026-10-06/CARGO_RETURN.md) to their nearest completed friendly HQ; hold Shift to queue delivery after a retreat.

[Faction and unit audio](docs/playtests/2026-10-11/audio-enhancement/README.md) now gives
all three factions distinct announcers, character-specific synthetic unit voices,
autonomous machine responses, research/construction/production cues and subtle UI
sounds. A shared priority queue, cooldowns and duplicate suppression keep battle
notifications from overlapping. Speech follows **Voice volume**; machine and UI
sounds follow **Effects volume**.

## Play skirmish

Run `project.godot` in **Godot 4.6** and choose **SKIRMISH**, or double-click [`play-skirmish.command`](play-skirmish.command) on this Mac.

- Play **Bastion**, **Helix**, or **Free Frontier**, against any faction or **Random** (mirror matches supported).
- Choose the expanded **Desert Frontier**, **Alpine Relay**, or **Coastal Foundry**, plus **Easy / Normal / Hard** AI. Sparse legacy maps are retired from new-game selection; old saves remain loadable.
- **Standard:** HQ, four engineers, two infantry, 60 materials / 12 electronics. **Advanced:** established base, tanks and repair support, 120 / 60.
- **Economy:** each resource field has five material piles and two electronics piles. All three current skirmish maps place the home field center 18 m from each starting HQ, with matching individual pile distances. Home piles contain 400 materials / 720 electronics; expansion piles contain 600 / 1,200. Full heaps change into opened bundles, scattered parts, and scraps at 300, 150, and 60 remaining; empty piles disappear. Electronics take 1.5 seconds per item to collect. Repair units, walkers, heavy armor and gunships have lower electronics costs across all factions. HQs supply 8 power and generators supply 12: a full production/technology/defense base needs two generators, with more required as production expands.
- **Battle controls:** direct orders, unit behaviors, production queues and engineer assignment shortcuts. Skirmish keeps the battlefield clear of the former Battle plan advice panel.
- Harvest, construct, produce, repair and fight with all three faction rosters. Each side has a **100 mobile-unit cap**, including queued reinforcements, and a separate **40-structure cap** including foundations.
- **Default keys:** **M + left-click:** move without engaging. **T + enemy click:** attack a visible target. **F + left-click:** attack move. The selection panel has matching buttons; hold **Shift** when choosing the target to queue. **Esc / right-click** cancels targeting. [Direct command verification](docs/playtests/2026-10-04/DIRECT_ORDERS.md). **Space:** tactical pause with orders, construction and production available. **Esc:** controls, resume, restart, setup or main menu.
- **Options / Esc → Settings:** preview master/voice/effects volume, speech subtitles (three text sizes), camera speed, edge scrolling, window mode, pointer confinement and reduced flashes. Save keeps changes; Cancel/Esc restores them. **Controls** remaps 33 battle, camera, queue/selection and control-group actions, with conflict feedback and per-action reset. Displayed battle shortcuts follow your bindings. Tab/Enter navigate controls; Esc cancels capture or closes dialogs. See [controls verification](docs/playtests/2026-10-03/KEY_CONTROLS.md). Subtitles remain readable with audio muted. Urgent warnings take priority over routine voice responses; repeated casualties no longer restart a line for each loss. [Speech verification](docs/playtests/2026-10-03/SPEECH_ACCESSIBILITY.md). Attacks, hits and infantry/vehicle/building destruction have distinct combat sounds, with stereo direction and current-fog filtering. **Test combat sound** previews the Effects setting. [Combat audio verification](docs/playtests/2026-10-03/COMBAT_AUDIO.md).
- **Interface size:** Settings → General → Display offers **100%, 125%, and 150%**, with live preview and Save/Cancel. It scales menus, battle controls and text; subtitle size remains adjustable separately. [Scaling verification](docs/playtests/2026-10-03/INTERFACE_SCALE.md).
- **Alerts:** open the top-right history to inspect incoming fire, grouped losses, idle engineers, depleted fields, stranded cargo, low power and blocked production. **Show** selects affected friendly units and centers the camera; **Go to field** visits the assignment area. Both work while paused. Close with the displayed Menu key; Clear history retains active problems. [Alert verification](docs/playtests/2026-10-03/BATTLE_ALERTS.md).
- **Esc → Save / Load battle:** five manual slots and three campaign checkpoints. **F5:** quicksave. **F9:** review quickload. The main menu also has **LOAD BATTLE**. Loaded battles remain paused until Resume.
- In either editor, **Battle arena** tests the current draft with real units in an isolated desktop window. Choose a role/scenario, run, inspect expected outcomes and traces, then return. The live battle stays paused. Save records matching scenario evidence; Apply remains explicit.
- In **Lua editor → AI assistant**, configure your provider and API key, then Create/Revise/Explain. Review before **Import as unsaved draft**; check, save and apply separately. Provider API charges are separate. Use **Parameters** for supported offline adjustments. Visual-rule drafts can enter this flow through **Copy as Lua**.
- Destroy the enemy HQ and prevent a completed replacement for **60 seconds**. Losing every unit/building also ends the match. Victory, defeat and draw screens support replay and return to setup.

![Skirmish setup](art/skirmish/setup-1280.png)

Helix uses its own models, icons and names: mobile units have 20% less health and 20% faster movement than Bastion counterparts; Prism artillery has longer range and slower movement. Costs and progression are initial tuning. The AI gathers and pays for units, buildings and research, reserving eligible technology costs while prioritizing rebuilding and urgent production. Easy / Normal / Hard skirmish commanders differ in decision speed, attack timing and size, economy, production, research and retreats, without economic or combat bonuses ([difficulty profiles](docs/CORE_GAMEPLAY_SPEC.md#enemy-fairness-and-difficulty)). See [paid progression verification](docs/playtests/2026-10-05/PAID_PROGRESSION.md) and the [reproducible match runner](tests/playtest/README.md).

[Implemented rules and limits](docs/GAME_DESIGN.md#19-playable-two-faction-skirmish--implemented-2026-10-01) · [Helix in battle](art/skirmish/helix-factory.png) · [Verification report](docs/playtests/2026-10-01/SKIRMISH.md)

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/Skirmish.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/NavigationRegression.gd
godot --path . --fixed-fps 60 --script tests/rendered/SkirmishPreview.gd
```

Combat now includes armor/weapon counters, blocked sight and fire, non-stacking repair, infantry/aircraft recovery, recoil, tracers, missile trails, impacts and temporary wrecks. [Watch the combat preview](art/skirmish/combat-preview.mp4) · [Rules and measurements](docs/playtests/2026-10-01/COMBAT.md) · [Development roadmap](docs/DEVELOPMENT_ROADMAP.md).

Both factions now have individual long-idle gestures, gait/hover timing, recoil and death variations. [Watch the idle/combat review](art/skirmish/unit-motion-preview.mp4) · [Motion rules and verification](docs/playtests/2026-10-01/UNIT_MOTION.md).

Choose **Auto-engage**, **Defensive**, **Follow**, **Guard** or **Hold Fire** in the Orders panel. Behaviors require no chip, script or network connection. Follow selects a friendly unit; Guard selects a position. Ordinary move, attack, gathering, construction and repair orders remain available.

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/CombatRegression.gd
godot --path . --script tests/rendered/ScaleFrameBenchmark.gd -- --behaviors --realtime --no-capture
godot --path . --fixed-fps 60 --script tests/rendered/CombatPreview.gd
```

## Hero campaigns

**CAMPAIGN** offers three connected stories about Meridian and Cinder Ford: six Bastion operations led by Marshal Aegis, five Helix operations led by Spectre Nyx, and five Frontier operations led by Pathfinder Rook. Choose a faction, operation and difficulty. Heroes must survive, gain stronger abilities in later acts, and accompany the army to story objectives. The battle HUD provides hero selection, ability activation, convoy orders and dialogue skip controls.

Bastion proceeds through **Supply Line**, **First Orders**, **Split Signal**, **Cinder Ford**, **Broken Foundry** and **Command Horizon**. The original **Air Corridor** evacuation remains loadable from existing saves. Cinder Ford completion supplies the foundry rescue bonus; previously earned Air Corridor support is retained. In Broken Foundry, disable the production nodes and secure the foundry with infantry. In Command Horizon, secure deployment, defeat the command force, then bring Aegis to the Spire controls. Finale victory unlocks Lean and Reinforced replay variants.

Helix's **Quiet Streets**, **The Gate**, **Cinder Ford**, **Pruning** and **Severance**, and Frontier's **Drainage**, **Cinder Ford**, **Salvage**, **Wren** and **The Coalition** combine capture, hold, destruction and escort objectives. Their city, river, drainage and desert theaters include resources, story landmarks, interior buildings, groves and moving residents, with mission routes and construction areas kept clear. English voices use English or Chinese captions; captions default to off and can be enabled in settings. Conversations can be paused, skipped and resumed from a battle save.

The [headless continuation report](docs/playtests/2026-10-16/headless-continuation/README.md) records gameplay, save compatibility, audio and performance verification. Fresh rendered review remains pending.

Choose **CAMPAIGN → First Orders → Start First Orders**. Build a command lab, assign a Guard position, then send infantry and armor to the relay. Hold it for 60 uncontested seconds against three warned Helix responses.

Using Guard and Follow together earns the optional cosmetic doctrine badge. Mission completion, the badge and full battle state persist. **Esc → Save / Load battle** opens the battle archive.

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/CampaignRegression.gd
godot --path . --fixed-fps 60 --script tests/rendered/CampaignPreview.gd
```

## Bastion playable demo

Open `project.godot` in **Godot 4.6**, run the project, and choose **BASTION DEMO**. On this Mac, double-click [`play-bastion.command`](play-bastion.command) to launch directly. A Godot executable is required; the launcher checks the local tool download, cache, application folder, and PATH.

The desert scenario starts with the full faction available for review: **8 mobile unit types, 9 structures, materials/electronics harvesting, power capacity, construction, production, repairs, fog of war, and an AI opponent**. Reinforcements cost resources; the command lab unlocks walkers and railgun tanks. Destroy all enemy units and structures to win. Use **SKIRMISH** for the two-faction mode described above.

![Bastion production in the running Godot demo](art/bastion/demo/gameplay/factory.png)

- **Left-click / drag:** select. **Shift:** add to selection. **Right-click:** move, attack, harvest, repair an ally, or set a factory rally point. **Shift + right-click:** append an order (up to 16 waiting). **Shift + attack-move click:** append an attack-move.
- **Unit behaviors:** Attack, Defensive, Follow, Guard and Hold Fire are available immediately in Orders.
- **Order queue:** numbered routes show active (solid) and waiting (dashed) orders. Skip advances one order; Clear waiting keeps the active order; Stop clears everything.
- **Engineer rover:** select a building in its menu, place it with the left mouse button, and rotate with **R** or by dragging before release. Right-click cancels placement.
- **Production:** select a headquarters, barracks, vehicle factory, or airfield. Click a roster icon to queue; click a queue icon to cancel and refund.
- **Space:** tactical pause in the Bastion demo; select units, give orders, and queue production while paused. **Escape:** match menu.
- **WASD / screen edges:** pan. **Q/E:** rotate. **Mouse wheel:** zoom. **Ctrl+1–9:** assign control groups; **1–9:** recall.

Assets and implementation:

- [Editable Blender faction catalogue](art/bastion/demo/bastion_faction.blend) · [asset overview](art/bastion/demo/faction-catalogue.png) · [construction UI](art/bastion/demo/gameplay/construction.png)
- [Rebuild script](art/bastion/build_faction.py) · [20 GLB exports](assets/models/bastion/demo) · [unit/building icons](assets/ui/bastion) · [verified mesh counts](art/bastion/demo/verification.json)
- [Gameplay specification and prototype limitations](docs/GAME_DESIGN.md#16-bastion-asset-and-gameplay-demo--implemented-2026-10-01)

Rebuild the assets with `blender --background --factory-startup --python-exit-code 1 --python art/bastion/build_faction.py`. The script uses the original tank export in `assets/models/bastion/tank-v1/` and saves editable source, GLBs, icons, and a catalogue render. Validate exports with the same command using `art/bastion/verify_faction.py`.

Verification commands, from the project directory:

```sh
godot --headless --editor --path . --import
godot --headless --path . --script tests/headless/MatchStartup.gd
godot --headless --path . --script tests/headless/BastionDemo.gd
godot --path . --script tests/rendered/BastionPreview.gd
gdformat --check source/
gdlint source/
```

Latest gameplay verification: [repeated skirmishes, repair support and movement completion](docs/playtests/2026-10-03/SKIRMISH_MATRIX.md), followed by [crowded-base movement and archive continuity](docs/playtests/2026-10-03/CROWD_BOUNDARIES.md), [AI construction that preserves base access](docs/playtests/2026-10-03/BASE_ACCESS.md), [tactical guidance and reliable selection](docs/playtests/2026-10-03/BATTLE_PLAN.md), [Guard coverage across its assigned area](docs/playtests/2026-10-03/GUARD_AREA.md), [observed-threat AI defense](docs/playtests/2026-10-04/AI_DEFENSE.md), [observed-composition counter-production](docs/playtests/2026-10-04/AI_COMPOSITION.md), [strategic offensive objectives](docs/playtests/2026-10-04/AI_OFFENSE.md), [protected expansion and cargo-preserving withdrawal](docs/playtests/2026-10-04/AI_EXPANSION.md), [adaptive AI labor and mixed-production budgets](docs/playtests/2026-10-04/AI_ECONOMY.md), [AI recovery and recommitment](docs/playtests/2026-10-04/AI_RECOVERY.md), [intermittent-movement investigation and replay](docs/playtests/2026-10-04/MOVEMENT_DIAGNOSTICS.md), and [global AI task coordination](docs/playtests/2026-10-04/AI_COORDINATION.md).

This is a playable art/gameplay prototype with built-in unit behaviors, three factions, 16 hero campaign operations, and full battle save/load. Native Lua source and historical authoring tools remain in the repository for development history and compatibility, while battle units no longer execute Lua.

## Helix Systems — second faction models

Choose **HELIX MODEL REVIEW** in the main menu to inspect all **8 units and 9 structures**. Use the wheel to zoom, Q/E to turn, Space to pause rotation, and the team-color button to test recoloring. This viewer remains available alongside the playable Helix faction in **SKIRMISH**.

[Unit concept sheet](docs/concept-art/helix/v1/02-helix-unit-designs-v1.png) · [Building concept sheet](docs/concept-art/helix/v1/03-helix-structure-designs-v1.png) · [Faction key art](docs/concept-art/helix/v1/01-helix-key-art-v1.png) · [Exact imagegen prompts](docs/concept-art/helix/v1/prompts.json)

[Editable Blender source](art/helix/v1/helix_faction.blend) · [Model catalogue](art/helix/v1/faction-catalogue.png) · [GLBs](assets/models/helix/v1/) · [Faction design](docs/GAME_DESIGN.md#17-helix-systems--second-faction-design-and-model-set)

Rebuild with `blender --background --factory-startup --python-exit-code 1 --python art/helix/build_faction.py`; validate with `art/helix/verify_faction.py`. Run `godot --path . --script tests/rendered/HelixPreview.gd` to inspect every model through the Godot importer and capture review screenshots.

## Purposes of this project

This game is not going to be a very advanced RTS that would compete with other games of this genre. Instead, it will focus on simplicity and clean design so that it can:
 - showcase Godot 4 capabilities in terms of developing RTS games
 - provide an open-source project template for creating RTS games
 - educate game creators on creating RTS game mechanics

## Features

 - [x] 1 species
 - [x] 2 resources
 - [x] terrain and air units
 - [x] deathmatch mode (human vs AI or AI vs AI)
 - [x] runtime player switching
 - [x] basic fog of war
 - [x] units disappearing in fog of war
 - [x] minimap
 - [x] swarm movement to position
 - [ ] swarm movement to unit
 - [x] simple UI
 - [ ] polished UI
 - [ ] sounds
 - [ ] music
 - [ ] VFX

## Godot compatibility

This project is compatible with Godot `4.6`.

 - support for Godot `4.3` is available in project history before the Godot `4.6` upgrade.
 - support for Godot `4.2` is available on `godot-4.2-support` branch.
 - support for Godot `4.1` is available on `godot-4.1-support` branch.
 - support for Godot `4.0` is available on `godot-4.0-support` branch.

## Screenshots

![Screenshot 1](./media/screenshots/screenshot_2_1920x1080.png "Screenshot 1")

![Screenshot 2](./media/screenshots/screenshot_3_1920x1080.png "Screenshot 2")

![Screenshot 3](./media/screenshots/screenshot_4_1920x1080.png "Screenshot 3")

## Contributing

Everyone is free to fix bugs or perform refactoring just by opening PR. As for features, please refer to existing issue or create one before starting implementation.

## Credits

### Core contributors
 - Pawel Lampe (Lampe Games)

### Contributors

See [contributors](https://github.com/lampe-games/godot-open-rts/graphs/contributors) page.

### Assets
 - 3D Space Kit by [Kenney](https://www.kenney.nl/assets/space-kit)

- Visible heavy-armor defense advice and repeated factory-selection layout verification: [2026-10-06 report](docs/playtests/2026-10-06/GROUND_DEFENSE.md).

- Paid opening infantry guidance, full Standard progression and native reselection follow-up: [2026-10-06 report](docs/playtests/2026-10-06/OPENING_INFANTRY.md).

- Program recovery support, role-specific first assignments and paid healing under enemy pressure: [2026-10-06 report](docs/playtests/2026-10-06/PROGRAM_RECOVERY.md).

- Selected-unit control width, UI-scale transitions and native command cancellation audit: [2026-10-06 report](docs/playtests/2026-10-06/MENU_WIDTH.md).

- Low-health combat/support selection during defense pressure: [2026-10-06 report](docs/playtests/2026-10-06/LOW_HEALTH_SELECTION.md).

- Cross-map paid recovery and progression audit, including unresolved strategy/rendering findings: [2026-10-06 evidence](docs/playtests/2026-10-06/REGIONAL_RECOVERY.md).
- Named skirmish relay overview, camera locators and public fog markers: [2026-10-06 verification](docs/playtests/2026-10-06/RELAY_OVERVIEW.md).
- Own-force battle debrief and persistent production/loss/programming history: [2026-10-06 verification](docs/playtests/2026-10-06/BATTLE_DEBRIEF.md).
- Opening repair-support discovery alongside lab and defense advice: [2026-10-06 verification](docs/playtests/2026-10-06/SUPPORT_DISCOVERY.md).
- Early paid support, conventional armor recovery and chip handoff: [2026-10-06 verification](docs/playtests/2026-10-06/ARMOR_PRESERVATION.md).
- Sustained paid recovery, air-reserve conflict and experimental ground screens: [2026-10-06 audit](docs/playtests/2026-10-06/SUSTAIN_PRESSURE.md).
- Partial recovery-command coverage and faction-specific missing-service feedback: [2026-10-06 report](docs/playtests/2026-10-06/RECOVERY_COVERAGE.md).

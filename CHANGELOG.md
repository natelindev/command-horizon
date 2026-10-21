# Changelog

## [main]

## [0.15.1]

### Verification
 - Material regression checks inspect exported model resources and distinguish runtime texture data from editor-only import settings
 - Desktop packages run 45 regression suites, including object materials, shutdown, battlefield passages, atmosphere and water

All features below are included in 0.15.1. The 0.15.0 candidate was not published
because its packaged material test expected editor-only import settings.

## [0.15.0 — unpublished candidate]

### Air combat redesign
 - Physical projectiles: visible bullets, shells, rockets, guided missiles and bombs follow gravity, thrust and turn limits; rounds can miss, are blocked by terrain and buildings, splash nearby enemies and outlive their shooter
 - Four distinct aircraft from one runway airfield: kamikaze drones, fighters, bombers and attack helicopters
 - Fighters and bombers taxi, take off from the runway, bank to turn, orbit, land on a glide slope and rearm on their stand; parked jets can be destroyed on the ground
 - Rocket infantry fire guided missiles at aircraft, and every faction gains a tank-class anti-air vehicle
 - The airfield is now a rotatable runway with four jet stands and two helipads; helicopters and drones rearm and repair on the helipads
 - Skirmish AI builds anti-air against observed aircraft and uses each aircraft for its role
 - Frontier aircraft are weaker (70% health, 80% damage, no speed bonus); Frontier infantry are tougher and hit harder (110% health, 115% damage)
 - Save format 16 stores rounds in flight and flight state; retained playtest archives were converted

### Added
 - Textured object materials for vegetation, stone, buildings, vehicles and props, with improved lighting and shadows
 - Scalable battlefield clouds, dust, fog and lava effects, plus interactive water with authored currents and local ripples
 - Event-driven HUD motion for production, research, newly available commands and notices, with stable hit targets and reduced-flash support
 - Resource and weapon tooltip icons sized relative to text at every interface scale
 - Directional rocket exhaust and dust, expanding blast flashes, and bounded debris with independent 3D rotation and scale
 - Persistent observed vehicle tracks and blast soot painted onto terrain, including elevated ground; save format 17 stores the bounded mark history
 - Optional rectangular base lights (up to four visible facilities), HDR output detection and calibration with SDR fallback, and English/Chinese settings
 - Sixteen rebuilt skirmish battlefields, each a recognisable real place with its own signature: Redrock Divide, Saltwind Basin, Desert Frontier, Pinebreak Valley, Glacier Narrows, Alpine Relay, Emberworks and Coastal Foundry for two players; Copper Badlands, Shattered Oasis, Four Rivers, Verdant Commons, Frostbound Crown, Railspire Junction, Sunken Exchange and Cinder Ring for four
 - Real elevation on battlefields: raised tiers and sunken gorges, canals and quays joined by ramps, with high ground that blocks sight and fire from below unless spotted
 - Forests that hide units, fords, bridges, flooded quays and lava; capture relays and garrisonable buildings on the maps that use them
 - A new neutral oil refinery model with a working pump
 - Skirmish commanders expand to authored expansion sites and vary their attack routes across each map's crossings
 - Scanned CC0 ground layers (grass, rock, sand, dirt, asphalt, snow, concrete) on every battlefield, backdrop and campaign theater, blended around each map's authored colors, roads and biome features
 - Baked crevice shading, chipped edges and lower-hull dust on all Bastion, Helix and Frontier models, including team trim and construction sites
 - Ground decals: oil stains, skid marks, cracks and repairs along roads, plus tracks, scuffs and debris across open ground; identical after loading a save
 - Ground detail graphics setting to turn scanned ground and decals off for faster rendering

### Changed
 - Upgraded the project, desktop release engine/export templates, Mac launchers and playtest runner to Godot 4.7.2 stable
 - Plain & Simple and Big Arena use a temperate battlefield instead of the legacy flat salmon ground
 - Broken Foundry and Command Horizon enemy posts use the native Guard behavior; posted repair robots service damaged allies within 8 m, and foundry tanks keep their previous assembly time
 - Lab research and Coordination unlock when a vehicle factory and lab have both been completed, as before, without any program terminology
 - Battle debriefs no longer list program milestones. Campaign briefings, the First Orders badge objective, the Frontier Outrider description, difficulty and weapon-mode text no longer mention presets, programs or retrofits
 - Retained playtest archives were converted to snapshot version 15, then 16 with the air combat redesign
 - Command Horizon saves must include their opposition state
 - The skirmish picker offers only the rebuilt battlefields; a saved choice of a retired map opens its successor
 - Larger, richer resource fields: home fields sit beside the HQ, and rich fields hold half again an expansion's stock on exposed ground
 - Bases are farther apart along real paths (about 75–110 seconds for a basic tank), with naturals within 25 seconds

### Removed
 - The Lua script engine: the native `rts_lua` extension, sandbox, Lua runtime and actions, Lua/visual-rule editors, LLM program assistant and the program test arena
 - The programmable-unit system: unit programs and presets, specialist programs, chips and retrofit installation, factory program pins, squads, program panels and badges
 - Battle-save backward compatibility: saves now use the current snapshot version only, and saves from other versions are rejected instead of migrated
 - The Air Corridor operation, which no campaign order reached any more, with its map, HUD, rescue VTOL, voice lines and narration; earlier progress that recorded it still counts toward Cinder Ford
 - The skirmish battle-plan advisor and its hidden settings option, retired from the HUD in 0.12.0
 - Single-narrator campaign lines replaced by recorded dialogue, and remaining old-save handling for heroes, conversations, facility counts and mercenary contracts

### Fixed
 - Wider battlefield passages and approaches keep opposing ground traffic moving
 - High-altitude aircraft can be selected with a drag box
 - Compact research tiles and construction on gentle slopes improve base management
 - Runtime caches and audio are released cleanly when quitting, including during paused battles
 - A restored order whose target no longer exists no longer shows as the unit's current order while paused
 - The skirmish AI now actually hires mercenaries at captured camps; it previously requested a unit camps do not sell
 - `build_catalog.py` reproduces the shipped translation catalog again; strings that existed only in `ui.csv` moved to `art/localization/interface.tsv`
 - Infantry could not capture relays or neutral facilities standing on raised ground
 - Hired mercenaries could not leave a camp standing on raised ground
 - The skirmish AI counts mercenaries already in the field against its army cap
 - Hover cards for resources and units appear again; the full-screen command-feedback layer no longer counts as an occupied HUD panel
 - Campaign district buildings keep clear of the authored resident, fox and car loops
 - Save → load → save keeps action timers identical, including timers that are due on the saved tick
 - Fighters, bombers, anti-air vehicles and camp mercenaries speak instead of staying silent
 - Skirmish commanders fund their army before optional facilities and rebalance workers when their army reaches its cap
 - Ground units finish settling after a teleport or restored elevation instead of becoming stuck above their route
 - Aircraft saves preserve weapon cooldowns, partial rearming and bomb releases; rounds keep flying after their target is destroyed
 - Dragging a jet's move destination preserves the next queued order
 - Hero campaign operations play ambience matching their environment
 - Objectives stay below the resource bars when full visibility shows multiple players
 - Subtitles stay clear of tall resource rosters in eight-player battles
 - Owned navigation maps use the configured edge-matching precision, avoiding false edge collisions during Glacier startup
 - New aircraft and mobile anti-air models include the same baked weathering as the rest of their faction
 - Paid jet orders retain their stands across saves; returning jets respect those reservations and can move to another airfield when theirs is destroyed
 - Fighters and bombers receive stand repairs after returning, and grounded aircraft obey terrain and forest concealment
 - Ground units can approach the runway's actual outline without being stopped by an extra circular avoidance obstacle
 - Glacier's boathouses no longer obstruct two electronics deposits
 - Crowded ground units choose usable escape space instead of repeatedly taking a nearly blocked side step

## [0.14.1]

### Fixed
 - Batch selection changes into one command/build-panel refresh, eliminating repeated control-tree construction when selecting groups
 - Disconnect old selection callbacks and avoid refreshing the panel when an unrelated unit dies
 - Preserve paused selection updates and held-button release safety during deferred refreshes

### Verification
 - Add a packaged regression for selection batching, paused construction commands and selection lifecycle cleanup
 - A local rendered 40-builder selection improved from a 1,383 ms maximum frame to 49 ms; results depend on hardware and workload
 - The exported Windows candidate completed four minutes of scripted gameplay with no frames over 100 ms; targeted headless and all-faction rendered selection checks passed

## [0.13.1]

### Fixed
 - Large-map save restoration now waits for navigation using a wall-time deadline instead of a frame-count limit, fixing Windows/Linux release checks
 - Failed restore fixtures clean up the retained paused match before testing another scenario
 - Packaged releases include a regression for delayed navigation synchronization under accelerated frame delivery

All features below are included in 0.13.1. The 0.13.0 candidate was not published
because its new cross-platform save/load checks caught the synchronization race.

## [0.13.0 — unpublished candidate]

### New features
 - Thirteen new battlefields: five two-player maps and eight four-player maps, with balanced starting fields and capturable facilities
 - Four-player free-for-all skirmishes against three independent AI commanders, including elimination, victory and save/load support
 - Workers spread across nearby reachable resource deposits using travel time and existing assignments
 - Visible carried materials and electronics on workers, with verified Return cargo handling

### Changed
 - Shared scenery geometry and reduced visibility, movement, animation and minimap overhead improve large-battle frame pacing
 - Clearer shelter occupancy and refinery income, payout timing, suspension and depletion feedback
 - Expanded map previews, faction setup, battle briefings and English/Chinese HUD text
 - Desktop release packages now run regressions for worker distribution, cargo accounting, garrisons, facilities and the new battlefields

### Fixed
 - Infantry getting stuck after leaving shelters and explicit attacks unexpectedly evacuating garrisons
 - Legacy spectator matches repeatedly accessing a skirmish-only match state
 - Resource-field reassignment and cargo accounting coverage now supports automatic deposit selection

### Verification and limits
 - Targeted gameplay, navigation, save/load, cargo, combat, animation, map-opening and rendered HUD checks pass on macOS
 - M1 Pro 200-unit combat frame time improves from 32.03 ms to 28.62–28.74 ms, with roughly 80% fewer frames over 33 ms; maximum-population combat remains below 60 FPS
 - Extended four-player competitive balance and Windows/RTX 4090 gameplay performance require hardware playtests
 - Existing campaign checkpoint/custom-Lua test limitations remain documented in docs/plans/battlefield-expansion-verification.md

## [0.12.0]

### Changed
 - Native unit behaviors replace per-unit Lua execution in normal gameplay: Attack, Defensive, Follow, Guard and Hold Fire
 - Faster battlefield contact queries, fewer idle updates, and 30 Hz simulation with interpolated rendering
 - Full-width bottom command console aligned with the minimap, larger unit portraits, and simpler battle menus
 - Removed the skirmish Battle plan panel and its settings toggle
 - Unified starting resource distance and pile layout across the current skirmish maps
 - Reused mature tree and leafy bush models in place of flat scrub props, with batched scatter
 - Snapshot version 14 stores behavior stance and converts older scripted orders to Defensive

### Fixed
 - Soldier walk/run stride resets and sliding caused by rendering faster than simulation updates
 - Missing campaign dialogue captions when optional unit subtitles are disabled
 - Unclear capture/hold, convoy and hero requirements; added current-objective camera navigation
 - Captured mercenary camps now open paid recruitment directly, including during tactical pause
 - Empty health labels and transparent portrait margins shrinking selection avatars
 - Production queue layout after selection changes and oversized coastal tree footprints

### Verification and limits
 - Targeted gameplay, save compatibility, localization, animation and native rendered HUD/campaign checks pass on macOS
 - Initial M1 Pro maximum-population combat benchmark improved from about 5.2 to 31 FPS; 60 FPS at maximum population remains a target
 - Windows/RTX 4090 gameplay performance and subjective animation review require a hardware playtest
 - Archived environment fixtures have stale map/save assumptions; see docs/campaign/POLISH_VERIFICATION.md

## [0.11.0]

### New features
 - Sixteen hero-led campaign operations across Bastion, Helix and Frontier, with persistent abilities and progression
 - 160 English campaign voice recordings, named speakers, portraits and English/Chinese conversations
 - Fuller campaign interiors with biome-specific districts, groves and moving residents
 - Persistent neutral-building ownership: ownership survives evacuation and save/load until enemy infantry recapture an empty building

### Changed
 - New skirmishes use the three expanded maps; legacy preferences migrate and old saves remain loadable
 - Faction HUD, responsive menus, production controls, construction effects and unit animation improvements
 - Revised unit voice casting and robot processing; audited speech and campaign recordings
 - Difficulty-aware AI army limits, improved navigation and lower CPU costs
 - Snapshot version 13 preserves independent neutral-building ownership and reads older archives
 - Release builds include native Lua libraries for each desktop platform and validate exported resources

### Fixed
 - Production costs overflowing two-line buttons
 - Black opening briefings, visible alert layers during conversations, stale faction frames and duplicate objectives
 - Campaign scenery blocking Command Horizon reinforcements or forward construction
 - Worker contact recovery and crowded navigation regressions

### Verification and limits
 - Campaign combat, save compatibility, audio audits, rendered previews and 14 packaged macOS checks pass
 - Maximum-population performance remains below the smooth-play target; human voice/art/balance review remains open

## [0.10.0]

### New features
 - Living World system: animated ambient wildlife, biome atmosphere, dynamic weather, and environmental lighting
 - Interactive neutral world: capturable relays, neutral settlements, and garrisonable structures
 - Expanded infantry roster and unique faction heroes for Bastion, Helix, and Frontier factions
 - Complete Neo-Military Precision HUD overhaul across main menu, skirmish setup, campaign, and match UI
 - Full bilingual localization support (English and Simplified Chinese) including typography, layout, and loading screens
 - Comprehensive audio overhaul: unit voice responses, male faction voices, autonomous machine audio, and licensed music
 - Programmable RTS gameplay, Lua script runtime, and visual program editor
 - Campaign missions with interactive briefings and unit telemetry previews

### Changed
 - Upgraded engine foundation to Godot 4.6
 - Optimized coastal navigation, obstacle avoidance, and combat targeting
 - Improved weapon impact VFX, wreck materials, and debris physics
 - Cleaned up obsolete assets, dead code, and temporary build clutter

## [0.9.1]

### New features
 - Automated multi-platform CI release builds (Linux, macOS, Windows)

### Changed
 - Optimized battlefield targeting and terrain navigation
 - Voice narrator and combat audio lifecycle cleanup

## [0.9.0]

### New features
 - Added 'loading page' translations
 - Added ability to use custom maps
 - Added 2 new maps
 - Added match setup page

### Changed
 - Performed various refactorings
 - Simplified turret's rotation algorithm
 - Removed redundant unit groups
 - Extracted generic `MouseClickAnimation`
 - Improved `assert()` calls
 - Renamed `buildings` to - more generic - `structures`
 - Made `SimpleClairvoyantAI` being able to attach units in runtime

## [0.8.1]

### New features
 - Added resource tooltips
 - Added unit production/construction tooltips
 - Added main menu background
 - Added match loading page
 - Added diagnostic FPS monitor

### Changed
 - Increased units HP by a factor of 2

## [0.8.0]

### New features
 - Added animated logo sequence on startup
 - Added basic main menu with options etc.
 - Added match with hardcoded map and features such as:
   - Settings
   - Isometric 3D camera
   - Fog of war
   - Terrain/Air navigation
   - Units & structures
   - Resources (blue/red crystals)
   - UI (unit selection mechanism)
   - HUD (resource counters, unit management panels)
   - Menu
   - Dynamically created human/AI players
   - Debug utilities (God mode etc.)

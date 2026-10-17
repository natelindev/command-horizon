# Changelog

## [main]

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

# Changelog

## [main]

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

# Godot 4.7 presentation features

## Stage 1 — HUD and readable icons

Use visual-only Control offset transforms for event-driven production, research,
command availability and urgent-alert feedback. Keep keyboard focus and hit targets
stable, respect reduced motion/flashes, and size inline resource/weapon icons in em.

## Stage 2 — Combat and battlefield wear

Add directional exhaust/dust and rotating debris with bounded particle pools.
Accumulate cosmetic tracks, blast marks and destruction soot in a bounded drawable
ground texture, respecting terrain height, visibility, pause and ground-detail
settings. Keep simulation authority and its random stream independent.

## Stage 3 — Optional lighting and HDR

Add a bounded set of faction-colored rectangular lights around visible buildings,
enabled by a high-quality lighting option. Provide HDR capability detection,
brightness calibration, SDR fallback, and normal Settings Save/Cancel behavior.
Localize new controls and help text in English and Simplified Chinese.

## Stage 4 — Verification

Run targeted behavioral, settings, save and rendering regressions. Review all faction
HUDs, terrain layers and a dedicated feature preview without headless mode. Compare
bounded performance workloads with options on/off. Document device limitations.

## Agent progress

All four stages are complete.

- Stages 1–3 implemented. HUD transforms leave layout/hit targets unchanged;
  completion feedback handles factories and captured mercenary camps. Tooltip
  glyphs use em units. Reduced flashes also suppress HUD motion.
- Combat uses directional billboard particles plus 192 independently rotating
  GPU shards. Ground emission heights follow the terrain.
- Wear records at most 2,048 observed marks, rasterizes at most 32 per frame, and
  retires 128 oldest marks when full. A 2,048² drawable texture costs 16 MiB;
  rebuilding temporarily uses a second texture to avoid flashing clean terrain.
  Ground detail and wear settings hide the overlay without erasing saved history.
- Area lights are opt-in, Forward+ only, unshadowed, capped at four visible nearby
  facilities; hidden/destroyed facilities immediately lose their lights.
- HDR is opt-in and requests native HDR output, with engine-managed SDR fallback.
  Peak luminance is adjustable on Windows/macOS; manual paper white is Windows
  only. Settings preview/cancel and persistence include all new options.
- Save format is 17. Converted 810 version-16 repository archives; verified every
  prior field/value and ID is unchanged and all payload hashes are valid. Eight
  pre-existing version-9 flight evidence archives for the retired Air Corridor
  schema remain unchanged and unsupported; no runtime migration was introduced.
- Source checks passed for presentation, settings, production, roster information,
  snapshots, graphics and rich textures. Native HUD captures (all three factions,
  English/Chinese), Glacier Narrows terrain review, and actual combat passed.
  Native HDR activation and cancel rollback succeeded on the Mac HDR display.
- Packaged validation found a mercenary-camp signal/queue mismatch; fixed and
  verified actual hiring across all three factions. All 39 packaged regression
  scenarios passed (the interrupted run's first ten plus the corrected remaining
  twenty-nine). The final localized tooltip update also passed four focused
  packaged UI checks. The Mac release archive has been refreshed.
- Native texture rebuild/eviction checks passed with the 2,048-mark budget, including
  keeping the previous surface visible during rebuilding. Twelve tooltip captures
  cover all factions, English/Chinese, and 125%/150% scaling; no clipping or renderer
  errors. Chinese HDR settings were also reviewed.
- On this M1 Pro, a 1440×900 paused-base sample with VSync disabled measured
  7.50 ms/frame with optional lighting/wear off and 12.37 ms/frame with both on
  (120 frames each). This is one scene, not a large-battle performance guarantee.
- Validation is macOS/Metal plus the headless renderer. Windows/Linux HDR hardware,
  moving between physical SDR/HDR monitors, and absolute luminance calibration
  were not device-tested. Godot handles requested-output fallback automatically.
  Existing shutdown resource/ObjectDB diagnostics remain; the headless fixed-wing
  check also retains its known dummy-renderer null-material diagnostic. Settings
  intentionally exercises a failed write. Native presentation reviews reported no
  runtime rendering errors.

Verification logs and captures are in `tmp/godot-features/`,
`art/presentation-features/`, `art/hud-console/`, `art/terrain-layers/`, and
`art/game-polish/combat/normal/`. The release archive is
`build/release-assets/Command_Horizon_macOS.zip`.

API references: [Godot 4.7 release](https://godotengine.org/releases/4.7/),
[drawable textures](https://docs.godotengine.org/en/4.7/classes/class_drawabletexture2d.html),
[native HDR output](https://docs.godotengine.org/en/4.7/classes/class_displayserver.html).

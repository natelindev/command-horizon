# Battle console kits

Faction HUD textures for the battle console. The console language is shared: asymmetric chamfers, thin luminous edge lines with brighter corner ticks, glass screens with fine grids, and slim keys with a soft light strip. Each faction has its own material and accent:

| Folder | Faction | Material | Accent | Stripe |
| --- | --- | --- | --- | --- |
| `bastion/` | Bastion Directorate | armoured gunmetal, flush bolts, brushed metal | amber | chevrons |
| `helix/` | Helix Systems | graphite-blue glass, hex micro-pattern, no fasteners | cyan | data dashes |
| `frontier/` | Free Frontier Coalition | salvaged warm metal, rivets, diamond plate | orange | hazard bands |

Every bitmap is generated. Do not edit the PNGs by hand.

```sh
python tools/ui/generate_hud_kit.py            # writes assets/ui/hud/**/*.png
```

Requires Pillow and NumPy. Seeds are fixed, so regenerating gives identical files. Profiles (colours, cuts, frame weight, patterns, fasteners) live at the top of the generator.

- The theme follows the human player's faction. `Match._enter_tree` calls `BattleTheme.use_faction`, and `BattleTheme.kit()` loads `assets/ui/hud/<faction>/<name>.png`. It falls back to the shared overlays here: `glow`, `focus` and `bar_segment` are white and tinted with the faction accent.
- Textures are authored at 2x logical resolution. `source/match/hud/HudStyle.gd` draws them at half scale through a nine-slice, so they stay crisp at interface scales 1.25/1.5 and on HiDPI displays. Slice sizes in `BattleTheme.gd` are logical units.
- Selected and active states use fills, insets and glow, never coloured borders. The edge lines are decorative and identical across states. The accent corner brackets (`focus.png`) are reserved for keyboard focus.
- `icons/` holds 24-unit SVG glyphs for system keys and orders, drawn white so the theme's icon colours can tint them.
- Typeface: Barlow Condensed SemiBold/Bold (SIL OFL, `assets/fonts/OFL-BarlowCondensed.txt`) for keys, headings and numerals, falling back to Noto Sans SC for CJK.
- The front-end menus keep their own slate theme in `source/main-menu/ArtTheme.gd`.
- Rendered review: `Godot --path . --script tests/rendered/HudConsolePreview.gd` writes captures for every faction to `art/hud-console/`.

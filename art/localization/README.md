# English and Simplified Chinese

Edit the reviewable `*.tsv` files, then run `python3 art/localization/build_catalog.py` and Godot's editor import. The builder rejects conflicting keys and changed format placeholders. `assets/translations/ui.csv` is the generated native Godot catalog.

The project exposes only `en` and `zh_CN`. New settings follow the OS language; unsupported saved locales fall back to English. The settings dialog previews immediately and restores the previous locale on Cancel. Scene text uses Godot's automatic translation. A bounded-cache translation adapter also handles older HUD strings which are formatted before they reach a Control. This leaves simulation IDs, save data, program source and user names unchanged. Read-only editor diagnostics and custom-drawn hover cards translate explicitly.

Keep `assets/translations/ui.csv.import` at `compress=0`: the adapter needs the source message list, which optimized translation resources do not expose. Do not translate editable code or player-authored program names.

Font: [Noto Sans SC from Google Fonts](https://github.com/google/fonts/tree/main/ofl/notosanssc), bundled with its SIL OFL license in `assets/fonts/`. The original variable font defaults to weight 100. The bundled font is instantiated at weight 450 using fontTools so Chinese and Latin text remain legible in small controls. No runtime system font is required for Chinese UI.

Verification:

- `tests/headless/LocalizationRegression.gd`: fixed and formatted messages, Chinese glyphs, world lore, live read-only diagnostics, save/cancel, persistence and unsupported-locale fallback.
- `tests/rendered/WorldAndLanguagePreview.gd`: English/Chinese menu, world, skirmish and campaign screens; Chinese battle, unit program, technology, visual rules and archive.
- Menu, settings, key binding and unit-menu layout regressions cover existing interactions and 100/125/150% UI sizes.

The PNG files in this directory are actual Godot captures, not mockups. Spoken voice recordings remain their existing English audio; their UI captions are localized.

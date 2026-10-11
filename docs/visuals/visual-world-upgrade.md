# Visual world upgrade

The main menu now uses original river-city artwork, a slate/copper native control theme, slow background motion, staggered action entrances and hover transitions. Skirmish setup, campaign, shared menu backgrounds and settings use the same art direction. Keyboard focus remains visible; menu motion can be disabled.

## Graphics controls

Open **Settings → Graphics**, either from the main menu or the battle menu. Changes preview immediately, including while the match is paused. Save persists them; Cancel/Escape restores the previous values and rendering.

| Control | Behavior / default |
| --- | --- |
| Time of day | Afternoon, golden hour, night or dawn; afternoon initially |
| Day/night cycle | On; one day takes 24 simulation minutes |
| Weather | Changing skies by default; clear, overcast, rain and mist can be fixed |
| Rain particles | On; follows the camera |
| Atmospheric fog | On; separate from tactical fog of war |
| Shadows | On; four cascades with corrected contact bias |
| Ambient occlusion | On under Forward+ |
| Bloom | On; restrained light glow |
| Depth of field | Off initially; optional far blur with camera-relative focus under Forward+ |
| Anti-aliasing | 2× MSAA; Off and 4× also available |
| Living world | On; extra districts, street detail and ambient population |
| Menu animation | On |

The atmosphere follows the archived simulation clock. Changing weather uses deterministic 20-second transitions between fronts. Rendering settings do not change visibility range, damage, navigation or other game rules. The fog-of-war overlay remains black over unexplored ground even when atmospheric fog is enabled.

Implementation uses Godot's [Environment](https://docs.godotengine.org/en/4.6/classes/class_environment.html) and [CameraAttributesPractical](https://docs.godotengine.org/en/4.6/classes/class_cameraattributespractical.html). The UI deliberately gates AO and DOF to the tested Forward+ path. Alternative renderers have not received the same rendered QA.

## World detail

The shared scenery layer adds riverbanks and bridges, residential/shopfront buildings, animated water, distant mountain or mesa models, trees, pedestrians, cars, birds and foxes. Windows and street lighting respond to daylight. Urban terrain and building materials darken and become less rough during rain.

Industrial Crossroads receives two inhabited residential blocks inside existing building obstruction envelopes, sidewalk furniture and extra pedestrians. The original six navigation/sight obstacles remain authoritative, and housing stays below their flight/sight envelope. The coastal expansion sits on the inland side so it does not replace harbor water. Alpine settlements use snow-covered pitched roofs and pines; desert settlements have lower buildings and scrub.

Civilian life is ambient scenery. Most additional large scenery is outside playable bounds; construction areas and combat routes remain available. Existing archived civilian actors retain their save/restore behavior. New cosmetic pedestrians are regenerated with the scenery; they are not additional combat units or a city-economy simulation.

## Verification — Godot 4.6, macOS / Apple M1 Pro

Passed:

- `tests/headless/MenuArtRegression.gd`: all menu actions fit 100%, 125% and 150% interface scales at 720p; mouse activation, graphics checkbox preview and Escape rollback.
- `tests/headless/GraphicsRegression.gd`: shadow defaults, day/night and rain, effect toggles, original and added population toggles, paused preview/cancel, persistence, clock-derived fronts and detached visibility guards.
- `tests/headless/SettingsRegression.gd`: legacy settings, persistence, invalid values, preview/cancel, intentional save failure and battle modal behavior.
- `tests/headless/KeyBindingsRegression.gd`: control capture, remapping, rollback, battle input and quicksave/load for both factions.
- `tests/headless/AmbientLifeRegression.gd`: six maps; routes, walking/yielding, pause, fog, target isolation, exact archives and old-save migration.
- `tests/headless/IndustrialSurroundingsRegression.gd`: both factions; three tank lanes, retreat, aircraft, relay access, sight/placement, home/expansion resources, construction and restoration.
- `tests/headless/MapStartupRegression.gd`: repeated map switching. Also fixed detached observer access found during this check.
- `tests/headless/CombatRegression.gd`: occlusion, hidden-target loss, firing legality, damage/armor, repair and pause.
- `tests/rendered/VisualWorldPreview.gd`: Forward+ captures of menu/settings, effects on/off, afternoon/golden hour/night/rain/mist/DOF, and coastal/alpine/desert scenery. Hidden enemy base pixel check passed.
- `gdformat --check source/`, `gdlint source/`, and `git diff --check`.

Some existing headless harnesses emit resource/ObjectDB shutdown warnings after successful assertions. SettingsRegression intentionally produces a failed-write error to exercise rollback. No rendered runtime/shader errors occurred in the final visual pass. GPU performance across other hardware has not been benchmarked.

## Review files

- [Main menu](../../art/visual-upgrade/menu.png)
- [Graphics settings](../../art/visual-upgrade/graphics-menu.png)
- [Afternoon city](../../art/visual-upgrade/city-afternoon.png)
- [Golden-hour street](../../art/visual-upgrade/street-sunset.png)
- [Night city](../../art/visual-upgrade/city-night.png)
- [Rain](../../art/visual-upgrade/city-rain.png)
- [Mist and optional depth of field](../../art/visual-upgrade/city-mist-dof.png)
- [Alpine](../../art/visual-upgrade/alpinerelay.png)
- [Coastal](../../art/visual-upgrade/coastalfoundry.png)
- [Desert](../../art/visual-upgrade/desertfrontier.png)

The built-in imagegen tool produced [the menu image](../../assets/ui/art/river-city-menu.png). Its exact final prompt is preserved in [the artwork manifest](../../assets/ui/art/README.md). All controls and typography are native Godot UI; the artwork contains no baked-in UI text.

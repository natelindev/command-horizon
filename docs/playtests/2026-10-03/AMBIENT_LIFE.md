# Living-map pass — 2026-10-03

The first moving-neutral pass adds civilian traffic and residents to Command Horizon and Broken Foundry, plus foxes on those maps and Alpine Relay/Desert Frontier. The user requested moving neutral life to make the maps feel inhabited. This implements that first slice; broader environment art, Industrial Crossroads and more regional variety remain open.

Follow-up: [Industrial Crossroads](INDUSTRIAL_CROSSROADS.md) now adds two cars, eight residents and four foxes. The expanded five-map motion/fog/pause/archive regression passes; the original four-map evidence below records the initial slice.

## Delivered behavior

| Map | Cars | Residents | Foxes |
| --- | ---: | ---: | ---: |
| Command Horizon | 2 | 6 | 2 |
| Broken Foundry | 2 | 4 | 2 |
| Alpine Relay | 0 | 0 | 4 |
| Desert Frontier | 0 | 0 | 4 |

Three original, editable Blender models provide a compact jade/ivory resident car, an ochre-coated civilian with a satchel, and a red fox. Residents have articulated arms/legs; foxes have a four-leg gait and tail motion. Rounded authored loops avoid the existing solid landmarks. Residents and foxes pause along their routes. Vehicles stop for ground units and structures ahead, and maintain following clearance from other cars. Pedestrians and foxes also wait for nearby ground traffic to clear.

These actors are environmental scenery: no owner, HP, weapons, selection collider, population cost, resource production, capture contribution, navigation obstacle or vision source. Military commands and navigation keep priority. This is lightweight yielding, not physical crowd simulation: military units can move through a neutral's resting position. Destructible civilians, evacuation objectives, panic/flee behavior, additional animal species, destinations and environmental audio are outside this slice.

Normal fog checks current allied observation and obstruction through `Battlefield`; explored-but-unobserved actors and their shadows disappear. Full-visibility mode reveals all actors. Movement, waits and animation run on simulation time and freeze with tactical pause. A private authored phase avoids consuming the match's random stream.

Gameplay snapshot version 6 includes strictly validated IDs, route distance, remaining pause, animation phase and walking pose. Routes and asset paths come only from the installed catalog. Position and orientation are derived from the saved route distance. Versions 1–5 remain readable; their neutral population starts at the authored defaults because those archives contain no neutral history. The JSON storage envelope remains schema 1.

## Verification

- `AmbientLifeRegression.gd`: all four maps pass route bounds/scenery clearance, actual motion, facing direction, limb-pivot presence, pause, stopping/resumption for ground traffic, car following clearance, current fog visibility and gameplay-group/collider/target isolation. The Horizon test also checks invisibility behind the actual opaque ruin.
- All four maps pass disk round trips preserving exact neutral motion/pose records, resumption, version-5 fallback, and rejection of invalid IDs, duplicate/missing actors, negative/out-of-range travel, non-finite phase, oversized waits and injected fields.
- `WeaponModeRegression.gd`: both-faction weapon behavior and version-1/version-2 archive migrations pass after the schema extension.
- `ResourceFieldRegression.gd`: both-faction field continuity, waiting/recovery and version-4 archives pass.
- `HorizonEnvironmentRegression.gd`: existing economy, placement, aircraft clearance, selection, real fire, tank passages and archives pass with neutrals enabled.
- Godot import, GDScript formatting/lint and `git diff --check` pass. Known navigation-readback and shutdown resource warnings remain; the final runs have no script errors or failed assertions.
- Native Godot review and 720p screenshots show the residents/cars around the Horizon service landmarks, fox silhouettes, Foundry traffic and Alpine wildlife. Initial review caught reversed model facing; the runtime now aligns the imported models' positive-Z forward axis to route travel, with a regression assertion.

The previews reveal the map and freeze military units to inspect neutral motion. They are staged visual checks, not full-match balance evidence. No performance acceptance claim is made; optimization remains deferred by user request.

## Evidence

- [Six-second moving preview](../../../art/skirmish/environment/ambient-life.mp4)
- [Horizon street](../../../art/skirmish/environment/ambient-horizon-street.png)
- [Resident detail](../../../art/skirmish/environment/ambient-resident-walk.png)
- [Foxes](../../../art/skirmish/environment/ambient-fox-trail.png)
- [Foundry traffic](../../../art/skirmish/environment/ambient-foundry-street.png)
- [Alpine wildlife](../../../art/skirmish/environment/ambient-alpine-wildlife.png)

```sh
GODOT=tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless --fixed-fps 60 --path . --script tests/headless/AmbientLifeRegression.gd
"$GODOT" --path . --script tests/rendered/AmbientLifePreview.gd -- --inspect
```

Add `--clip` to the rendered preview to emit 180 PNGs to `/tmp/ambient-frames`; encode at 30 FPS for the six-second clip. The Blender source rebuild command is documented in `art/environment/README.md`.

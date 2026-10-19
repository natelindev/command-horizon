# Built-in unit behaviors — 2026-10-17

This decision replaces the earlier programmable-unit design at the user's request.
Battle units use fixed native game actions instead of per-unit Lua execution or
contact snapshots. No chips, code editor, rule library or factory program is required.

| Choice | Behavior |
| --- | --- |
| Auto-engage | Automatically fire at nearby legal targets. Explicit Attack Move advances the army into combat. |
| Defensive | Return fire and assist nearby allies, with a bounded pursuit around the defended position. |
| Follow | Select a friendly unit. Maintain contact as it moves; stop when it is lost or a new order replaces Follow. |
| Guard | Select a position. Move there and defend without pursuing enemies. |
| Hold Fire | Stop automatic fire immediately. Explicit attack orders retain player authority. |

Direct movement, attack, harvesting, building, repair, service recovery and queued
orders remain available. Stance choices cancel the current order. Guard and Follow
can be issued during tactical pause; the simulation resumes only when unpaused.
Hold Fire allows projectiles already in flight to resolve.

Stances and follow orders persist in snapshot version 14. Versions 1–13 remain
readable, with their previously unrecorded stance defaulting to Auto-engage. Archived
Lua/visual and specialist program actions are replaced with Defensive behavior;
the loader does not compile or execute their source. New production and AI armies
use direct orders. Old script libraries are left on disk. Legacy preset classes
remain for authored mission internals and archive validation, outside the battle UI.

The simulation runs at 30 ticks per second with physics interpolation. Unit roots
interpolate between simulation ticks; local procedural posing remains at display
rate. Spawning, navigation alignment, camera jumps, restored positions and reused
tracers reset interpolation to avoid streaking. No graphics quality option is reduced.

Run `tests/headless/BehaviorRegression.gd` for the three-faction behavior, pause,
follow/save restoration and legacy-script migration checks. Run
`tests/rendered/HudConsolePreview.gd` without `--headless` for faction HUD captures.

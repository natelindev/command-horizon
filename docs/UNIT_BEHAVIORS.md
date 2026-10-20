# Built-in unit behaviors — 2026-10-17

This decision replaces the earlier programmable-unit design at the user's request.
Battle units use fixed native game actions. On 2026-10-20 the Lua runtime, program
presets, chips, squads, rule/code editors and the program arena were removed from
the codebase entirely.

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

Stances and follow orders persist in battle saves (snapshot version 15). Saves from
other versions are rejected; there is no migration. Production and AI armies use
direct orders. Authored campaign posts in Broken Foundry and Command Horizon use the
same Guard behavior; their posted repair robots service damaged allies within 8 m
(`source/match/campaign/CampaignPosts.gd`).

The simulation runs at 30 ticks per second with physics interpolation. Unit roots
interpolate between simulation ticks; local procedural posing remains at display
rate. Spawning, navigation alignment, camera jumps, restored positions and reused
tracers reset interpolation to avoid streaking. No graphics quality option is reduced.

Run `tests/headless/BehaviorRegression.gd` for the three-faction behavior, pause and
follow/save restoration checks. Run
`tests/rendered/HudConsolePreview.gd` without `--headless` for faction HUD captures.

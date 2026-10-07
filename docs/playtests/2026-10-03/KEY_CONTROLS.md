# Remappable keyboard controls

## Delivered behavior

Options and the battle menu's Settings share General and Controls tabs. Controls exposes 31 existing keyboard actions, grouped into Battle, Camera and Groups. Choose a binding, press a physical key or modifier chord, and Save to retain it. Preview updates hints immediately; Cancel restores the complete prior profile. Individual Reset buttons restore a default when it does not collide. Reset defaults uses the existing whole-settings reset.

| Actions | Defaults |
| --- | --- |
| Tactical pause / attack move / battle menu or cancel assignment | Space / F / Escape |
| Building rotation / quicksave / quickload review | R / F5 / F9 |
| Add selection and queue orders, held | Shift |
| Camera pan / rotation | WASD / Q and E |
| Assign / select groups 1–9 | Ctrl+1–9 / 1–9 |

Tab and Enter retain UI navigation/activation. Escape always cancels capture, even with other modifiers held, and closes dialogs independently of the battle-menu binding. Modifier-only capture is supported for the held selection/queue action. Duplicate bindings and reserved navigation, debug and common operating-system shortcuts give feedback without replacing another command. Current bindings remain visible after capture cancellation. Keyboard focus scrolls the list to the active row.

The version-1 profile lives in Options, separate from battle archives. Missing legacy profiles use defaults; malformed, partial, conflicting or unsupported profiles fall back atomically, avoiding mixed defaults that collide with a player's remaining keys. Nested dictionaries are copied for preview/rollback. Changing a binding releases its old InputMap action.

Queue modifiers can accompany attack move, group selection and camera actions. An explicitly bound chord takes precedence: if Shift+F is assigned to pause, holding Shift does not also trigger plain-F attack move. Physical modifier polling handles pressing/releasing Ctrl after a camera key was already held. Battle shortcuts work with a focused HUD button; Tab/Enter still operate those controls. Text fields, settings, save/load and program editors retain input ownership.

## Corrections found during review

- Exact chord matching initially prevented default Shift+F queue entry. Tests now press Shift and F through the real key-event path, then issue two destinations and inspect the retained queue.
- Camera InputMap state retained key-down modifiers after a later Ctrl press. Polling current physical key/modifier state fixes movement and resumption when Ctrl is released.
- Focused HUD buttons consumed Space and arrow shortcuts. Battlefield key handlers now resolve commands before control activation, with modal/text guards.
- Assignment/campaign hints contained fixed Escape/Space labels. Assignment hints now use the live menu binding; campaign briefing refers to Tactical pause.
- Modified Escape did not cancel key capture, and the cancel button left stale instructions. Both are corrected.

## Verification

| Check | Result |
| --- | --- |
| KeyBindingsRegression, both factions | Versioned disk profile, defaults, invalid/reserved/conflicting rejection, nested rollback, live capture, modifier-only hold, modified Escape, per-action reset and old-action release pass. |
| Actual command events | Remapped pause/resume, attack, camera pan/rotation, building rotation, paused group assignment/recall, menu, isolated quicksave and quickload review pass. Old keys become inactive. |
| Chords and queues | Default Shift+F appends two attacks; non-Shift G queue hold and Alt+Ctrl+K work; explicitly assigned Shift+F wins; Ctrl+K does not pan plain K; pressing/releasing Ctrl while K remains down updates camera movement. |
| Focus and text | Space pause and arrow attack/rotation work with focused HUD buttons. Typing a remapped quicksave key enters text, advances no save action and leaves the actual archive bytes unchanged; group/attack chords do not escape text entry. |
| SettingsRegression | Existing volume, camera, display, freeze, save, deep Cancel and deliberate write-failure recovery checks pass. |
| OrdersRegression | Both-faction queue authority, pause, replace/Stop/cap/resume, target/fog loss and harvesting/repair/combat/construction handoffs pass. |
| KeyBindingsPreview | Rendered 1280×720 mouse/key events cover main and battle entry, collision feedback, capture, Save, rollback, group-9 focus scrolling and remapped pause/resume. |
| SettingsPreview | Existing rendered General-tab keyboard/mouse, modal freeze, focus and display flows pass with Controls present. |
| OrdersPreview | Rendered queue/attack input, paused route display, Stop/clear/auto-resume and group/worker 720p layouts pass. |
| SaveSlotsRegression | Quick/manual saves, modal isolation, corrupt retention, load recovery, rotating real checkpoints and resumed jobs/actions/programs/cargo/cooldowns pass. |
| Skirmish and legacy Bastion | Both-faction skirmish roster/construction/AA/pause/restart checks and the legacy roster, production, economy, repair/navigation/combat suite pass. |

Reproduce from the repository root with an installed Godot 4.6 executable:

```sh
godot --headless --fixed-fps 60 --path . --script tests/headless/KeyBindingsRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/SettingsRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/OrdersRegression.gd
godot --path . --script tests/rendered/KeyBindingsPreview.gd
godot --path . --script tests/rendered/SettingsPreview.gd
```

Screenshots: [capture/conflict](../../../art/skirmish/controls-conflict-720p.png), [main settings](../../../art/skirmish/controls-main-720p.png), [group focus](../../../art/skirmish/controls-groups-720p.png), [battle settings](../../../art/skirmish/controls-battle-720p.png), [remapped pause](../../../art/skirmish/controls-battle-paused.png). Preferences are restored after completed fixtures and temporary save files are removed. Final formatting, relevant GDScript lint, editor import and whitespace checks pass.

## Remaining acceptance

The native Godot window was visible, but computer-use clicks failed with a window-discovery error and then an inactive computer-use state after discovery/rebinding and one corrected retry. Native input acceptance therefore remains unverified; rendered tests inject actual Godot input events. Non-US layouts and Windows/Linux operating-system shortcuts also need native acceptance. This adds keyboard remapping for existing commands; mouse/controller remapping, new shortcuts for every command button, scalable HUD and subtitles remain outside this implementation.

Existing navigation-readback and exit-time ObjectDB/resource/renderer warnings remain. The settings suite deliberately attempts an unwritable path to verify recovery. Broader full-match, novice and release acceptance remain open, and performance optimization remains deferred.

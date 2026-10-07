# Campaign controls: stable notices and reliable verification

## Delivered behavior

Campaign View/convoy/flight controls keep their positions when a checkpoint, response or assignment notice appears, changes length or expires. The shared command card reserves two lines for feedback. Longer messages scroll in that space with the wheel or a keyboard-focused scrollbar; new notices and assignments return to the beginning. Assignment instructions still take priority over queued notices. Compact command-card spacing keeps the objective panel clear of the actual minimap on all six campaign maps at 1280×720.

This is a UI change in `SkirmishHUD.gd`; mission rules, orders, balance and save formats are unchanged.

## Observed cause and regression

The [30-click slow trace](campaign-input-slow-trace.log), using tagged synthetic device 77 events, separates two failures:

- Click 14: the East View button moved from y=342 to y=366 between motion and press. The old coordinate selected another row. The native pointer remained outside the window during the failed press.
- Clicks 29–30: device 0 mouse motions arrived between synthetic press and release. Those motions left the button and cancelled activation. These were mixed input streams on a shared desktop.

The [trace source](campaign-input-slow-trace.gd.txt) and [previous HUD source](campaign-input-before-SkirmishHUD.gd.txt) are retained. This explains these captured failures; historical untraced menu misses are not individually attributed.

The deterministic headless regression holds a mouse press while short, two-line, long and expiring notices change. The [old implementation fails four checks](campaign-controls-before.log), including the held click; the [final implementation passes](campaign-controls-CampaignControlsRegression.log). It also checks assignment priority/cancellation, queued feedback, scroll reset and actual arrow-key movement.

The injected click helper now sends motion, press and release in one synchronous gesture and waits afterward. It still uses Godot's event routing and real button callbacks. It does not retry missed clicks or directly emit `pressed`. This prevents unrelated native motion from being interleaved into a synthetic gesture; it does not simulate human press duration. The separate held-click regression covers notice changes during a press.

The [initial uninstrumented full run](campaign-input-full-final-1.log) reached its wall-time deadline. A [subsequent capture trace](campaign-input-capture-trace.log) directly observed `can_draw=false` at the briefing capture, then completed once drawable. The capture helper now checks drawability, requests focus for its own test window once, waits a bounded interval and reports an unavailable capture explicitly. Godot's [Window implementation](https://raw.githubusercontent.com/godotengine/godot/4.6/scene/main/window.cpp) also distinguishes window drawability from input delivery; this is why a capture stall must not be reported as a missed click.

## Verification

- [Four shared suites](campaign-controls-shared.json): CampaignControlsRegression, ProgramRegression, SaveSlotsRegression and KeyBindingsRegression.
- [All six real campaign layouts](campaign-controls-preview-final.log), including real wheel and arrow-key scrolling of long feedback.
- [Thirty injected clicks at 15 FPS](campaign-input-slow-final.log), with [the bounded probe retained](campaign-input-slow-final.gd.txt).
- [Full campaign flow](campaign-input-full-final-2.log): keyboard/mouse mission selection, Start, three View buttons, archive save/load, paused resume, victory display, replay and return to Campaign. A [repeat run](campaign-input-full-final-3.log) records the same gate on the final source.
- GDScript formatting/lint, editor import and whitespace checks. Existing navigation-bake and shutdown resource warnings remain.

| Mission | Objective bottom | Minimap top | Clearance |
| --- | ---: | ---: | ---: |
| Command Horizon | 420 | 441 | 21 px |
| Broken Foundry | 447 | 473 | 26 px |
| Air Corridor | 478 | 497 | 19 px |
| Supply Line | 441 | 449 | 8 px |
| First Orders | 490 | 505 | 15 px |
| Split Signal | 473 | 505 | 32 px |

Reviewed captures: [Horizon](../../../art/skirmish/campaign-controls-command_horizon-720p.png), [Foundry](../../../art/skirmish/campaign-controls-broken_foundry-720p.png), [Air](../../../art/skirmish/campaign-controls-air_corridor-720p.png), [Supply](../../../art/skirmish/campaign-controls-supply_line-720p.png), [Orders](../../../art/skirmish/campaign-controls-first_orders-720p.png), [Signal](../../../art/skirmish/campaign-controls-split_signal-720p.png), [long feedback](../../../art/skirmish/campaign-controls-split-long-notice-720p.png) and [expired feedback](../../../art/skirmish/campaign-controls-split-expired-notice-720p.png).

The [initial layout fixture](campaign-controls-preview-initial.log) compared bounds before the pause label settled and is excluded. The later visual review found Supply Line overlap that a generic y<500 assertion missed; final checks use the real minimap rectangle. Keyboard verification first caught the [default inaccessible scrollbar](campaign-controls-keyboard-before.log), then [zero keyboard movement after focus alone](campaign-controls-keyboard-focus-only.log). The [runtime probe](campaign-controls-scroll-step.log) found `step=0` and `custom_step=-1`; the final scrollbar permits focus and uses a 21-pixel arrow step.

## Scope and reproduction

These are automated Godot event and rendered-layout checks at 720p, not physical-device, all-scale or cross-platform acceptance. General pacing, strategy, novice, content, mixing and release gates remain open; performance remains deferred.

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/CampaignControlsRegression.gd
godot --path . --script tests/rendered/CampaignControlsPreview.gd
godot --path . --script tests/rendered/SplitSignalPreview.gd
```

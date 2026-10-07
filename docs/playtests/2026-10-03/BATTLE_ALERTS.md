# Navigable battle alerts

## Player-facing behavior

Skirmishes and campaign operations now have a top-right **Alerts** control. Its unread count draws attention to new groups; after reading, it shows the number of active conditions. The scrollable history contains simulation timestamps, counts, active/resolved states and inspection controls.

**Show** selects surviving affected friendly units and centers the camera. **Go to field** visits the retained assignment area and selects its affected engineers. An entirely destroyed squad still has a navigable location. Inspection preserves manual orders, program mode and tactical pause; it cancels unfinished placement/targeting gestures. The displayed Menu key (Escape by default) closes the history before opening the battle menu. **Clear history** removes loss/resolved entries and retains active problems.

Rows keep their order while the panel is open, so live events do not move targets under the pointer or steal keyboard focus. New rows append until the next opening, when priority order is applied. An opaque panel avoids text from underlying unit controls showing through; active state uses a fill and words, with the existing visible keyboard focus indicator. The panel fits 720p/900p, leaves the minimap/subtitle gap and campaign lesson controls available, and temporarily covers part of the selection panel while open.

| Alert | Grouping and lifetime |
| --- | --- |
| Incoming fire | Actual accepted hits on human units only; program squad, or a nearby ten-metre area. Buildings have a separate base warning. Resolves after eight simulation seconds without a hit. |
| Losses | Human death notification before tree exit retains position and squad name. Six-second casualty bursts group by squad or area. Count is total casualties; the detail identifies the latest lost role. |
| Idle engineers | Local groups, after six simulation seconds of inactivity. Pending orders and active work are excluded. |
| Depleted field | Materials/electronics assignment anchors, after one second. Separate from generic idle alerts. |
| Stranded cargo | Nearby affected engineers, after one second; asks for an explicit completed friendly HQ assignment. |
| Low power | One player-wide condition, after two seconds; shows actual supply/demand and the existing 35% production speed. |
| Blocked production | Per producer, after two seconds; counts paid jobs and names the missing prerequisite. Uses the same `blocked_reason()` as queue execution. Low power is slowdown, not a prerequisite block. |

The history holds at most 24 entries. Resolved/history entries are removed before active problems; when all entries are active, a new lower/equal-priority alert cannot churn out an existing higher/equal-priority condition. Economy state refreshes twice per presentation second even while tactically paused, so queued-order changes and refunds resolve/update existing alerts. Debounce, expiry and timestamps use the simulation clock and do not advance through pause. Settings/archive scene freezing suspends inspection and processing; results reject new alerts and hide the panel.

Enemy activity never enters this history, even under full visibility. Incoming fire identifies the affected friendly group, not a hidden attacker. Transient history is omitted from saves. Restore starts quietly, then derives current conditions again after Resume and their normal debounce; it does not replay old casualties or reconstruction events.

## Verification

| Check | Evidence |
| --- | --- |
| BattleAlertsRegression, both factions | Four initially idle engineers form one delayed entry, retain its ID/read state, and resolve after paused reassignment. Paused navigation selects them, moves the camera and cancels an armed target gesture without changing their orders or time. Settings blocks navigation. |
| Actual combat | Real damage creates unit/base alerts. Six weapon kills in a named squad create one six-loss record; the destroyed squad retains its name/location and has no invalid selectable members. Enemy casualties are excluded. Generic HP changes do not create incoming-fire alerts. Pause preserves attack age; stopping fire resolves it on simulation time. |
| Actual economy | Two engineers really extract and exhaust an electronics deposit, deliver cargo and form one field alert. A new assignment resolves it without a duplicate generic idle warning. Destroying the real HQ strands cargo; explicit reassignment to a rebuilt HQ delivers the cargo and resolves the condition. |
| Paid production | A paid chip-equipped tank queue stops when the lab is destroyed and reports the named prerequisite. Cancelling a second paid job while paused updates the count without advancing time. Rebuilding the lab resumes the original job. |
| Power | Actual plant loss produces one power warning; a completed replacement resolves it. Immediate tactical pause after structure changes refreshes the resource bar to authoritative totals without advancing simulation. |
| Bounds and archive | Forty separated losses retain unique IDs and stay within the cap. Twenty-six actually damaged squads fill the active cap; repeated lower-priority condition scans leave the retained IDs stable. Clear retains active entries. Actual isolated disk save/read/restore omits history, remains quiet for combat events and derives the saved low-power condition after Resume. Results suppress later alerts. |
| BattleAlertsPreview, normal-clock Metal | Actual Godot mouse/keyboard events exercise opening/read count, Show, scroll-to-field navigation, Clear, Escape/remapped-key hint, unchanged tactical pause, stable rows/focus during a new loss, menus and archive isolation. Both factions pass at 720p; 900p and campaign lesson/result layouts pass. |
| BattleAlertsPause, normal-clock Metal | Thirty real seconds preserve simulation time, a paid HQ worker timer and an incoming-fire alert. Resume advances the queue and resolves stopped fire after the eight-second window. |
| Shared checks | Settings, key bindings, speech, combat audio, resource fields, Coordination/production, save slots/checkpoints/recovery and all four skirmish faction pairings including AI economy/attacks pass. Formatting/lint and whitespace checks pass. |

The resource bar originally refreshed only during unpaused processing. Pausing immediately after structure changes could leave its totals stale indefinitely while an alert showed current numbers. It now performs its read-only half-second refresh during tactical pause. Both headless and rendered checks cover the original loss → immediate pause → displayed-total scenario; the rendered check allows one normal refresh interval.

Gameplay regressions use actual unit/action/queue transitions with isolated deterministic fixtures. The rendered fixture advances its initial simulation age to populate a mixed history and uses programmatically prepared forces; it verifies controls/layout, not full-match difficulty. Mouse fixtures supply motion followed by button press/release before asserting controls; this avoids stale hover state across recreated scenes. The separate thirty-second test uses normal wall-clock scheduling. Test preference/archive files are isolated and restored/removed; rendered autosaves are disabled.

Screenshots: [Bastion history](../../../art/skirmish/alerts-bastion-720p.png), [Helix economy entries](../../../art/skirmish/alerts-economy-helix-720p.png), [campaign](../../../art/skirmish/alerts-campaign-720p.png), [900p](../../../art/skirmish/alerts-900p.png).

Reproduce with Godot 4.6 from the repository root:

```sh
godot --headless --fixed-fps 60 --path . --script tests/headless/BattleAlertsRegression.gd
godot --path . --script tests/rendered/BattleAlertsPreview.gd
godot --path . --script tests/rendered/BattleAlertsPause.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/SettingsRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/KeyBindingsRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/SpeechRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/CombatAudioRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/ResourceFieldRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/CoordinationRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/SaveSlotsRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/Skirmish.gd
```

## Remaining acceptance

Direct macOS input is **not passed**. Native app discovery and screenshots worked; the first click was rejected by the native state-change guard, and the retry after a fresh state returned `noWindowsAvailable`. The interactive `BattleAlertsNative.gd` fixture timed out without its expected navigation/clear flow and also reported a pause-time mismatch. Its source was not established; an independent five-second probe and the thirty-second rendered pause regression did not reproduce it. The native fixture remains available for a fresh manual acceptance session: open Alerts, Show a unit alert, reopen, Clear history, then Escape. No browser or desktop app was restarted to work around the failed input.

General HUD scaling, broader keyboard/screen-reader accessibility, alert pacing in repeated full matches, environmental audio, novice balance and Windows/Linux release acceptance remain open. Performance optimization stays deferred; no frame-rate claim is made. Existing navigation GPU-readback and exit-time ObjectDB/resource/renderer warnings remain; the intentional Settings write-failure test emits its expected save error. Final automated suites have no script errors.

# Command-card refresh and live execution

The command card now retains unchanged button layouts instead of clearing all twelve controls, rebuilding their contents and reconnecting handlers every quarter-second. The presentation key includes the current order-row shape, locale, actual input binding labels and first available controlled ability in each QWER column. Every refresh still replaces selection references and evaluates current eligibility. Ability readiness continues to refresh every 100 ms.

Keyboard focus stays on an unchanged control, and follows the same ability if its assigned column changes. Cooldowns, active toggles, resources, ownership and executable recipients are never cached. Once any current member can execute an ability, further prerequisite queries are unnecessary; every member is still inspected for active toggles and the minimum cooldown.

Stop, Hold and Reverse now share a live recipient filter excluding dead, removed, captured, garrisoned and non-executing entities. This also prevents a legal selection of 100 mobile units plus 40 structures from sending 140 actors through the 128-actor network protocol limit.

## Measured CPU cost

The same native 200-unit fixture measured 40 synchronous samples per function with `CLOCK_THREAD_CPUTIME_ID`. The following case has 100 wounded units and Coordination enabled. These are local caller-thread CPU measurements, **not** an end-to-end frame qualification.

| Path | Before median / p95 | After median / p95 |
| --- | --- | --- |
| Command card | 2.447 / 3.100 ms | 1.137 / 1.284 ms |
| Complete button refresh | 4.383 / 5.493 ms | 2.650 / 3.557 ms |
| Ability readiness, healthy coordinated selection | 0.783 / 0.883 ms | 0.355 / 0.389 ms |

The command-card median fell 53.5%; complete button refresh fell 39.5%. All six wounded/Coordination combinations are retained in [the comparison data](cpu-comparison.json), [before log](cpu-before.log) and [after log](cpu-after.log). The strict 16.6 ms rendered frame requirement remains a separate gate.

## Verification

- [Native](CommandCardRefreshRegression-native.log) and [fallback](CommandCardRefreshRegression-fallback.log) targeted regression: focus retention, one handler per slot, replacement selections, mixed cooldown/readiness/toggle states, live resource funding, ownership/death/garrison changes between refresh and click, ability name/key changes, locale and binding changes, weapon and mobility changes, ability-only/empty layouts, and local recipient revalidation. The native fixture asserts actual native unit-state bindings.
- [Existing native ability regression](UnitAbilitiesRegression-native.log): zero failures across actual ability activation, timers, targeting and command-card behavior.
- [Actual mixed-selection network session](../network-platform/runner-60hz-mixed140/groups-guest.log), [host](../network-platform/runner-60hz-mixed140/groups-host.log), [spectator](../network-platform/runner-60hz-mixed140/groups-spectator.log) and [binary replay](../network-platform/runner-60hz-mixed140/group-replay-verifier.log): zero failures; Stop and Hold each reach the 100 manual-order actors while 40 real structures are selected.

The rendered HUD review covers all three factions in English and Chinese. Representative mixed-selection and worker captures are retained here; [their dimensions and hashes](rendered-captures.json) cover twelve actual images. [The six-case run](HudConsolePreview-six-cases.log) and [the corrected Bastion window repeat](HudConsolePreview-bastion-window-stable.log) pass. The first run's initial Bastion window was larger than requested and is superseded by the exact 1280×720 repeat. The preview now ignores recognized global native flags when parsing faction filters, rejects an empty console review, and stabilizes the requested physical window size before asserting capture dimensions.

Visual inspection found an existing untranslated Smoke Screen label and description. Two TSV entries now provide the Chinese caption and tooltip; the targeted headless regression verifies both after catalog import. Retained rendered images precede that translation correction. Further headed work stopped at the user's headless-only instruction.

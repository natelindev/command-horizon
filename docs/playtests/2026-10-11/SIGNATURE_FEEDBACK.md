# Faction ability feedback — 2026-10-11

## Scope and original failure

Resumed the unfinished work recorded in `docs/REMAINING_WORK.md`. The unchanged panel reproduced all ten retained presentation failures: cooldown replaced Maneuver/Precision/Anchor setup and settled Anchor; mixed selections reported the longest cooldown; missing chips had no actionable instruction. Actual activation and partial-ready checks already passed. The new baseline log is retained in [signature-feedback/baseline.log](signature-feedback/baseline.log.txt); the original state records and unchanged source remain in the 2026-10-07 evidence directory.

## Shipping change

`SignaturePanel.gd` now summarizes ready participants and active effects separately. Anchor distinguishes outside-sector/moving setup, stationary setup and settled protection. Precision distinguishes an unused window from a consumed preparation. Maneuver shows the remaining active duration. Mixed readiness retains both the ready count and active effects.

Inactive selections show the earliest recharge among installed, living selected participants, respecting the greater of each unit's cooldown and its activation cohort's remaining lock. Settled/pending Anchor remains assigned rather than becoming ready when its cooldown reaches zero. A recharge is an opportunity to try the ability again; Helix still needs its legal target, preparation, reload, stationary position and weapon/deployment prerequisites.

The shared button/summary hover help includes cooldown and chip installation status, headquarters installation guidance and short faction-specific lines. Both controls expose accessible names/descriptions; the summary receives pointer hover and wraps within the existing menu. New strings have Simplified Chinese translations. No ability cost, timer, cap, activation implementation, cohort rule, order or archive schema changed.

## Fixture corrections and coverage

The previously unrun archive branch initially produced 16 action mismatches. A follow-up [probe](signature-feedback/frozen-timer-probe.log.txt) isolated all mismatches to a running idle-defense timer with exactly zero time left: restoration deliberately restarts that timer at the existing minimum of 0.000001 s. This one-microsecond normalization is unrelated to the ability UI; it is not an ability-state or order-kind change. The [probe source](signature-feedback/frozen-timer-probe.gd.txt) is retained. The fixture now cancels unrelated unit actions before freezing the controlled scene, preserving exact comparisons for time, players/cohorts, positions, health, current actions, queues and signatures. This is a correction to the diagnostic, not a shipping save change.

Mixed-recharge cases deliberately end the displayed effect while retaining actual independently aged activation cooldowns. Their cosmetic badges are refreshed too. Additional controlled cases cover cohort locks longer than individual cooldowns, installation in progress, outside-sector Anchor, Anchor with zero cooldown, consumed Precision, wrong Helix weapon mode, active/ready mixtures and repeated read-only refreshes. These artificial states isolate presentation; they do not prove paid full-match balance.

The first native pass completed real mouse Frontier activation, Bastion sector selection/cancellation and Tab/Shift+Tab/Enter Helix activation. It retained one hover assertion failure, recorded in [native-first.log](signature-feedback/native-first.log.txt). The preview now moves away between hover targets/locales and allows layout to settle before re-entering, avoiding reuse of an existing tooltip popup. The final native repeat passed with zero failures; its [log](signature-feedback/native.log.txt) is retained. Native pointer activation and sector selection plus Tab/Shift+Tab/Enter were driven through computer use; exhaustive bilingual hover checks use the rendered runner's input events. Screen-reader operation is not established by the accessible-property assertions.

## Verification

- Headless `SignatureFeedbackRegression.gd`: 0 failures, all three factions, actual activation, pause and disk restoration, mixed recharge, partial readiness and additional display cases.
- Native `SignatureFeedbackPreview.gd -- --interactive`: 0 failures, real Frontier mouse activation, Bastion sector selection with observed Escape cancellation and Helix keyboard activation, followed by the complete feedback/archive/hover suite.
- Metal-rendered `SignatureFeedbackPreview.gd`: 0 failures, 1280×720 at 150%, all three factions in English and Simplified Chinese, layout/hover bounds and input-event activation.
- Existing `SignatureRegression.gd`: 0 failures, six-member cap, eligibility/research/chips, damage/preparation rules, manual/program authority, disjoint groups, cooldowns, archives/death/legacy.
- Existing `FrontierGameplayRegression.gd`: 0 failures, actual Maneuver, paid retrofit/factory fitting, salvage/visibility and legacy restoration.
- Existing `LocalizationRegression.gd`: 0 failures.
- Changed GDScript format/lint: passed. Godot editor import and whitespace checks: passed. The deliberately negative zero-idle-timer probe retains 16 exact-equality failures, all the known 0 → 0.000001 s normalization described above; it is not an acceptance gate.

Headless runs still report existing shutdown ObjectDB/resource diagnostics (2–6 resources, depending on suite); the Frontier suite also reports two shutdown DummyShader RIDs. No script exception was observed. Passing gameplay assertions does not establish a clean process-shutdown gate.

## Remaining limits

Screen-reader behavior, other operating systems, additional physical devices/interface scales and subjective final accessibility/art/audio acceptance remain open. These controlled scenes establish feedback and input, not novice comprehension, full-match balance or pacing. Performance work remains deferred. The broader remaining-work document remains authoritative for the next acceptance tasks.

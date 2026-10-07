# Program recovery at service buildings — 4 October 2026

Built-in presets, Lua programs and visual rules now recognize the usable service area when a safe point is inside a matching friendly service building. Ground units previously healed to full health but stayed **Blocked**, because their program kept trying to reach the building’s inaccessible center. The reference match commander also now sends infantry to barracks, rather than a repair depot.

## Reproductions and behavior

Three [instrumented Alpine matches](policy-recovery-diagnostic.json) ended before assault and did not repeat the preceding [thirty-minute outcome](CONTACT_APPROACH.md). Its cause remains unconfirmed. Separate controlled tests established these defects:

- [Four reference-commander failures](policy-recovery-before.log): infantry in both factions never healed or rejoined; tanks did.
- [Sixteen built-in preset failures](preset-recovery-before.log): four ground roles in both factions healed but remained Blocked and never returned.
- [Thirty-two authored-program failures](authored-recovery-before.log): Lua and visual rules suffered the same ground-service deadlock.
- An interim 4.5 m arrival cutoff passed initial crowd runs but [failed a later repetition](program-recovery-verified-PresetRecoveryCrowdRegression.log): a tank receiving repair at 4.65 m remained Blocked at full health. A deterministic [4.75 m boundary test](service-boundary-before.log) then failed for both factions.

The final arrival check shares the repair service’s existing **5 m** constant. A completed, owned, role-compatible building qualifies only when the assigned safe point lies inside its footprint. The program holds within service range; ordinary service still controls slots, healing rate, power and suppression. Built-in presets return at their configured health threshold. Lua and visual rules retain their own conditions, state and return decisions. No program source, point coordinates or distance-condition semantics are rewritten.

Ground points outside the footprint and ordinary anchor/route movement retain exact-point behavior. Enemy, unfinished, wrong-role and removed facilities do not qualify. Manual Stop/replacement, tactical pause and explicit Resume retain authority. Previously saved Blocked programs require Resume. The test commander separately chooses the nearest completed matching owned facility, falling back to HQ if none exists.

## Verification

All [19 final shared suites](program-recovery-final-shared.json) pass without script errors. They cover recovery, programs, visual rules, specialists, squads, Lua integration, arena/combat, manual orders, snapshot/restoration variants, AI recovery/coordination and the captured contact-approach regression.

The [preset suite](program-recovery-final-PresetRecoveryRegression.log) verifies all six programmable mobile roles in both factions, real healing and physical return. It also covers the service boundary, exact ground points, unsuitable/lost providers, manual Stop followed by manual movement, and real disk restoration during partial healing. The [authored suite](program-recovery-final-AuthoredRecoveryRegression.log) covers all six roles × both factions × Lua/visual modes, source preservation, exact paused memory across disk restoration, manual Stop/state freeze, explicit Resume and a deliberately inaccessible ordinary anchor. The [reference-policy suite](program-recovery-final-PolicyRecoveryRegression.log) verifies infantry/tank recovery and recommitment in both factions.

The [final crowded-service suite](program-recovery-final-PresetRecoveryCrowdRegression.log) and [two additional trials](program-recovery-final-crowd.json) all pass: eight wounded tanks per faction share one depot, heal and return within 120 seconds. Aggregate healing remains bounded by two ordinary service channels. The earlier intermittent failure is retained, not replaced by a successful rerun.

## Rendered checks

Both final normal-clock rendered runs pass at 1280×720 and 150% interface scale: [built-in presets](program-recovery-final-preset-render.log) and [Lua/visual rules](program-recovery-final-authored-render.log). All twelve captures were reviewed for visible healing, returned position and readable program status. Fixture selection and direct tactical pause are used; no new native-input verification is claimed.

| Faction | Built-in preset | Lua | Visual rules |
| --- | --- | --- | --- |
| Bastion | [Healing](../../../art/skirmish/preset-recovery-bastion-healing.png) · [Returned](../../../art/skirmish/preset-recovery-bastion-resumed.png) | [Healing](../../../art/skirmish/authored-recovery-bastion-lua-healing.png) · [Returned](../../../art/skirmish/authored-recovery-bastion-lua-resumed.png) | [Healing](../../../art/skirmish/authored-recovery-bastion-visual-healing.png) · [Returned](../../../art/skirmish/authored-recovery-bastion-visual-resumed.png) |
| Helix | [Healing](../../../art/skirmish/preset-recovery-helix-healing.png) · [Returned](../../../art/skirmish/preset-recovery-helix-resumed.png) | [Healing](../../../art/skirmish/authored-recovery-helix-lua-healing.png) · [Returned](../../../art/skirmish/authored-recovery-helix-lua-resumed.png) | [Healing](../../../art/skirmish/authored-recovery-helix-visual-healing.png) · [Returned](../../../art/skirmish/authored-recovery-helix-visual-resumed.png) |

## Complete-match follow-up

The [interim eight-match cohort](preset-recovery-matches.json), before the Lua and service-boundary refinements, completed with five victories and three defeats. A subsequent [authored-program cohort](authored-recovery-matches.json) used invalid records: the fixture changed a script record’s reserved preset configuration. Every apply failed. Those outcomes are excluded from authored-program evidence, and its logs/source remain retained. The [corrected fixture](authored-recovery-final-matches.gd.txt) uses validated record defaults and records an apply failure once per unit.

All [eight final trials](program-recovery-final-matches.json) finished with three victories and five defeats; [process exits](program-recovery-final-match-exits.json) are zero without script errors. Both factions, Desert/Alpine, Standard ground and Advanced mixed starts use Normal AI and seed 4110. Advanced Desert uses converted Lua guard rules; Advanced Alpine uses visual guard rules.

| Faction | Map | Start / program policy | Result | Time | Authored returns / entries |
| --- | --- | --- | --- | --- | --- |
| Bastion | DesertFrontier | Standard / built-in | Victory | 13:35.5 | — |
| Bastion | DesertFrontier | Advanced / lua | Defeat | 4:46.9 | 3 / 6 |
| Bastion | AlpineRelay | Standard / built-in | Victory | 8:31.4 | — |
| Bastion | AlpineRelay | Advanced / visual | Defeat | 5:37.5 | 4 / 9 |
| Helix | DesertFrontier | Standard / built-in | Defeat | 25:42.0 | — |
| Helix | DesertFrontier | Advanced / lua | Defeat | 4:29.9 | 1 / 5 |
| Helix | AlpineRelay | Standard / built-in | Victory | 8:22.9 | — |
| Helix | AlpineRelay | Advanced / visual | Defeat | 4:30.5 | 1 / 5 |

The four authored trials applied programs to 17 units and recorded 25 recovery entries: nine returns and sixteen losses during recovery, with no recorded authored Blocked state. All four were defeats before the reference commander’s first assault. The Helix Standard Desert policy also never launched its assault and lost at 25:42; completion alone does not establish acceptable pacing. Across all eight trials, coordination recorded 9,074 samples without task/order violations. No fifteen-second stationary-travel capture occurred; the longest sampled interval was 9.5 seconds. No unresolved battle archive was needed.

These policies differ from the interim cohort, so the outcome counts are not a controlled balance comparison. The [unresolved-match wrapper](preset-recovery-matches.gd.txt) saves a still-active battle and policy state if needed; its [real disk restoration smoke check](preset-recovery-archive-smoke.log) passes.

## Evidence and limits

The [pre-format manifest](program-recovery-final-source-sha256.json) and [delivery manifest](program-recovery-delivery-source-sha256.json) identify the tested sources. During verification, the formatter wrapped one long comparison in parentheses and line breaks; [exact reconstruction](program-recovery-format-equivalence.json) matches its pre-format hash. The [post-format preset regression](program-recovery-delivery-PresetRecoveryRegression.log), [format check](program-recovery-delivery-format.log), [lint](program-recovery-delivery-lint.log) and [editor import](program-recovery-final-editor.log) pass. No behavior changed during the cohort.

Early [infantry program-fixture](preset-recovery-fixture-error.log), diagnostic [load](policy-recovery-probe-load-error.log)/[path](policy-recovery-probe-path-error.log), invalid authored-record and intermediate crowd failures remain retained and excluded from final passing evidence. The valid diagnostic matches rejected saves after their finished results; no end-state archive is claimed for them. Existing navigation-bake and shutdown resource/RID warnings remain.

Reproduce the focused checks with Godot 4.6:

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/PresetRecoveryRegression.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/AuthoredRecoveryRegression.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/PresetRecoveryCrowdRegression.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/PolicyRecoveryRegression.gd
```

The earlier thirty-minute match, uncaptured movement episodes, broader pacing/balance, novice/content acceptance and release gates remain open. Reaching service does not guarantee survival or eliminate every congested layout. Performance work stays deferred.

# Paid progression playtests

`run_progression.py` runs complete skirmishes and retains JSON observations plus raw Godot logs. It uses the repository's Godot 4.6 executable by default; supply `--godot PATH` elsewhere. No-argument invocation lists the default evidence directory. Output is compact TOON; retained records remain JSON. No hooks or global integrations are installed.

```sh
python3 tests/playtest/run_progression.py
python3 tests/playtest/run_progression.py run --case 0 --research combined --strategy ground-first --output tmp/paid-progression/frontier-bastion.json
python3 tests/playtest/run_progression.py show tmp/paid-progression/frontier-bastion.json
python3 tests/playtest/run_progression.py show tmp/paid-progression/frontier-bastion.json --full
python3 tests/playtest/run_progression.py list --directory docs/playtests/2026-10-05/paid-progression --fields factions,result,seconds
python3 tests/playtest/run_progression.py run --help
```

Each run requires a new output path. The runner preserves existing records/logs, rejects script errors even if Godot exits zero, and reports incomplete or timed-out runs as failures. `--repeats N` runs successive recorded seeds in one artifact; increase the default 1800-second wall bound when appropriate. Each individual match is limited to 30 simulation minutes and must reach a real game result. Defeat is a valid outcome. A fixed random seed does not make Godot navigation, physics and asynchronous setup fully deterministic; retain repeated observations rather than treating one result as balance evidence.

| Case | Reference commander | Shipping AI | Start |
| --- | --- | --- | --- |
| 0 / 1 | Free Frontier | Bastion | Standard / Advanced |
| 2 / 3 | Free Frontier | Helix | Standard / Advanced |
| 4 / 5 | Bastion | Free Frontier | Standard / Advanced |
| 6 / 7 | Helix | Free Frontier | Standard / Advanced |

All cases use Coastal Foundry and Normal AI. The inherited reference scenario records seeds beginning at 4110. Standard starts use the normal HQ, four engineers, two infantry and 60 M / 12 E. No resources, units, upgrades or research time are added after setup.

## Declared reference policies

`--research none` preserves the previous reference commander's production/research behavior: it never orders technology or manually activates signatures. It still uses the current shipping AI, so reproducing the old AI requires the separately retained before sources.

`--research combined` adds paid research once the reference owns a completed lab (with lab research unlocked) and six healthy ground combatants. It requests Coordination, Weapon systems I, Combat armor I, Field service, faction doctrine, Weapon systems II and Combat armor II, in order, while respecting the shared research slot. Future aircraft construction and requested workers, infantry, repair support, scouts and initial wings retain their budgets. Routine armor protects the next unpaid research purchase. Actual research and production payments contribute to the income accounting. Active research is not charged or reserved twice.

The combined policy retains the old commander's producer order (HQ, barracks, airfield, vehicle factory). Its priority numbers distinguish essential requests from optional armor/research; they do not reorder aircraft behind repair support. The shipping AI uses its own sorted production policy. Neither is a claim of optimal strategy.

`--strategy ground-first` delays the airfield and aircraft until twelve ground combatants exist. `--strategy air-first` permits the airfield after the lab. Both retain the same ordinary construction, finite-field harvesting, native Guard posts and recovery orders, proactive assault and observed-target aircraft raids. Combined references activate available faction signatures using owned units and currently observed contacts, preserving unit orders. Full observations may inspect both sides for diagnostics; command decisions do not consume hidden enemy telemetry.

`--strategy screened-air` targets six infantry and requires eight healthy ground combatants before starting the airfield. Once that investment is paid, losses do not disable aircraft production. The first strike aircraft takes precedence over optional research; replacing a lost last wing also precedes the next research project. All construction, production and research still use normal prices and timers. The screen and wing-first budget apply without granting resources or ordering the shipping AI. `army_policy` is the authoritative strategy field in older retained records; newer decisions and samples also record the same policy in `allocation_policy`.

The `reference/` scripts preserve the established commander used in earlier playtests. They were promoted from the identically named `tmp/*.gd` chain, changing only their inheritance/helper paths. The chain ends in maintained headless policies; no `res://tmp/` script dependency remains. The leaf `PaidProgressionMatches.gd` contains the explicit new strategies and research telemetry.

## Native review of earned state

An optional `--archive-prefix PATH` retains the first paid Coordination, paid unit technology and active signature states per case/repetition. It pauses synchronously at a simulation boundary for the normal archive API and immediately restores the previous pause state. Archives use the normal checked save format; they do not alter income or grant upgrades. Use a new prefix for each invocation. Filenames include case, recorded repetition and progression kind.

`PaidProgressionPreview.gd` loads an earned Frontier Weapon systems I archive, checks the research overview and normal-clock timers, and checks signature activation without replacing existing orders. Its `--interactive` mode waits for native clicks/keys (Tech, Escape, Maneuver burst); otherwise it runs rendered input regression events. Captures are 1280×720 at 150% interface scale with normal fog. Supply a new capture prefix.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/PaidProgressionPreview.gd -- --archive=res://tmp/paid-progression/earned-case0-10-technology.json --captures=res://tmp/paid-progression/native --interactive
python3 -m unittest discover -s tests/playtest -p 'test_*.py' -v
```

The Python checks cover empty/invalid input, retained successful records, path quoting, zero-exit script errors, missing records, timeouts and preservation of existing evidence. Gameplay, economy and research regressions remain under `tests/headless/`.

## Native live-research feedback review

`ResearchFeedbackPreview.gd` loads an earned Weapon systems I archive and requires actual mouse/keyboard input: click live research, Escape, M, Escape, click the later stalled status, Cancel & refund, Escape. It checks a two-second normal-clock interval before a controlled lab-loss/refund phase. Capture size, temporary options and archive rules match the paid-progression preview.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/ResearchFeedbackPreview.gd -- --archive=res://docs/playtests/2026-10-05/paid-progression/earned-frontier-verified-10-technology.json --captures=res://tmp/paid-progression/research-feedback --interactive
```

Use a fresh capture prefix in an existing directory. See [research feedback verification](../../docs/playtests/2026-10-05/RESEARCH_FEEDBACK.md) for exact assertions, native captures and retained fixture corrections.

## Experimental engineer withdrawal policy

`EngineerSafetyMatches.gd` extends the paid commander with observed-threat withdrawal, ordinary HQ cargo delivery and guarded resumption of the original field or construction task. Its protected workers are excluded from routine economy reassignment. It accepts the same Godot user arguments as `PaidProgressionMatches.gd`; use it directly, since the Python runner continues to select the established paid commander.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/EngineerSafetyMatches.gd -- --case=2 --repeats=1 --research=combined --strategy=screened-air --output=res://tmp/engineer-protected.json --archive=res://tmp/engineer-stationary.json --archive-prefix=res://tmp/engineer-earned
```

Cases 2 and 6 cover Standard Frontier→Helix and Helix→Frontier. Use new output paths. The optional archive prefix also captures first withdrawal and first recorded delivery. The policy remains experimental: shared retreat destinations and indefinite waits for the original field can suppress income. Do not interpret lower worker losses as successful economy protection.

`EngineerSafetyPolicyRegression.gd` checks all-faction fog, cargo, order stability, actual delivery and renewed income. `EngineerSurvivalPreview.gd` reads the four retained earned archives and requires four native Space inputs; use a fresh `--captures=res://.../prefix`. Its two-second continuations restore existing orders and live enemy AI, without restoring the test reference commander. See [the complete investigation](../../docs/playtests/2026-10-06/ENGINEER_SURVIVAL.md) for failed fixtures, native evidence and strategy limits.

`EngineerReassignmentMatches.gd` selects the next experimental policy: it reserves separated retreat endpoints, avoids friendly unit footprints and tries a safe alternative resource field when original work is unavailable or unsafe. Alternative gathering prefers the original resource channel, then the other one. The selected field must have a clear HQ approach and a reachable currently clear route from the worker. No alternative leaves the worker protected. Run the same arguments with this script; `--archive-prefix` additionally captures the first alternative order per match. The established and original retreat policies remain available.

`EngineerReassignmentRegression.gd` checks all three factions, real cargo delivery and fresh alternate-field income; `--original-policy` deliberately reproduces the earlier spacing and indefinite-wait failures. `EngineerReassignmentPreview.gd` loads a supplied earned archive and an explicit archived worker ID, waits for native Space and observes twenty seconds of normal-clock movement, cargo and delivery with live enemy AI. It does not restore the test reference commander.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/EngineerReassignmentRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/EngineerReassignmentPreview.gd -- --archive=res://docs/playtests/2026-10-06/engineer-reassignment/earned-6-case6-10-worker_alternative.json --unit=unit-4 --captures=res://tmp/reassignment-native
```

See [safe work reassignment](../../docs/playtests/2026-10-06/ENGINEER_REASSIGNMENT.md) for repeated paid-match outcomes, the retained unresolved run and earned collection/delivery observations. This is reference strategy work, not automatic retreat for player-controlled engineers or a shipping balance adjustment.

## Earned crowded AttackMove and infantry recovery

`AttackCrowdedArrivalRegression.gd` replays the earned infantry stall, then checks paused disk observation/queued handoff, distant destinations and active combat. `--capture-only` runs just the three intact-archive arrival checks for comparison with the retained before implementation. `AttackCrowdedArrivalPreview.gd` reads the retained stationary archive, selects its original infantry and requires native Space for six seconds of live continuation. Use a fresh `--captures=res://.../prefix`.

`EarnedInfantryRecoveryProbe.gd` compares sixty seconds of the unresolved army's saved orders with explicit ordinary Barracks recovery. Strategic commanders are disabled while other actors retain processing; it isolates service handoff rather than continuing a complete strategy. See [crowded AttackMove verification](../../docs/playtests/2026-10-06/ATTACK_CROWDED_ARRIVAL.md) for the shipping fix, original failures and remaining reference-policy gap.

## Conventional infantry recovery and recommitment

`ConventionalRecoveryMatches.gd` opts the engineer-reassignment commander into infantry treatment. It starts ordinary safe Barracks recovery below 40% health during operations, or below the normal 80% service-exit threshold while regrouping. Existing service safety, blocked retry and replacement-facility rules remain authoritative. Guard, regroup and assault orders preserve active treatment; healthy infantry return to ordinary combat command. Earlier commander scripts keep their original defaults.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/ConventionalRecoveryMatches.gd -- --case=2 --repeats=2 --research=combined --strategy=screened-air --output=res://tmp/conventional-2.json --archive=res://tmp/conventional-stationary.json --archive-prefix=res://tmp/conventional-earned
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/ConventionalRecoveryRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/ConventionalRecoveryPolicyRegression.gd
```

Use new paths. The earned-army regression runs the actual defense command loop and checks treatment retention and healed return to assault; `--original-policy` deliberately reproduces the prior recovery failure. The separate all-faction policy regression checks thresholds, current observation, blocked-service pause, replacement facilities, stockpiles and release. `ConventionalRecoveryPreview.gd` loads the retained first-treatment archives for Frontier and Helix, requiring two native Space inputs and a fresh `--captures=res://.../prefix`. Each 45-second continuation keeps live enemy AI and existing orders, without reconstructing the reference commander. See [conventional recovery verification](../../docs/playtests/2026-10-06/CONVENTIONAL_RECOVERY.md) for complete outcomes and scope limits.

### Explicit full-health recovery orders (2026-10-06)

`tests/headless/RecoveryOrdersRegression.gd` verifies all-faction player service commands, queue authority, pause, active disk and pending in-memory restoration, live infantry/ground/air healing, handoff, target loss and blocked Skip. It also regresses the restored idle-defense action preventing a pending armed-unit queue from starting. `tests/rendered/RecoveryOrdersPreview.gd -- --captures=<fresh-existing-directory>/recovery` requires native mouse/Enter/Shift+Enter and Space, captures all factions at 1280×720/150%, and checks full healing. These are controlled command fixtures, not paid full-match balance evidence. See `docs/playtests/2026-10-06/RECOVERY_ORDERS.md`.

### First-contact defense experiments (2026-10-06)

`tests/headless/EarnedOpeningProbe.gd` traces the retained Helix first-contact army; `--responsive` tests observed-contact AttackMove response and `--service-line` tests a Barracks-side anchor. Both alternatives lose the controlled fight and are not accepted improvements. `tests/playtest/ScreenedOpeningMatches.gd` explicitly tests two paid tanks before the lab, retaining the other reference policies; the four retained matches yield one victory and three defeats. Existing commander defaults remain unchanged. `tests/rendered/DefensiveOpeningPreview.gd` restores retained paid first-contact states for two native Space continuations. See `docs/playtests/2026-10-06/DEFENSIVE_OPENING.md` for the evidence and reconstruction limits.

## Regional recovery audit

`RegionalRecoveryMatches.gd` retains the experimental armor-preservation strategy while selecting Alpine Relay for cases 0/1/4/5 and Industrial Crossroads for 2/3/6/7. Existing faction/start arguments remain unchanged. It additionally records public relay transitions and the shipping own-force battle record. Use fresh `--output`, `--archive` and `--archive-prefix` paths with the same direct Godot invocation shown above.

Four Standard/Normal observations all end in defeat; three reach the lab and one assaults. `RegionalRecoveryContinuation.gd` and `RegionalRecoveryPreview.gd` replay the two retained Frontier recovery archives with live enemy AI and no reference commander, verifying actual healing. The preview accepts a fresh `--captures` prefix. Its geometry checks pass; a follow-up pixel comparison corrected the initially reported rendering anomaly. See [regional sustained gameplay](../../docs/playtests/2026-10-06/REGIONAL_RECOVERY.md) for exact evidence and limits.

## Optional regional relay expeditions

`RelayContestMatches.gd` adds bounded, observed-contact infantry expeditions to `RegionalRecoveryMatches.gd`. It reserves a home infantry, protects recovery, excludes expedition members from main-assault readiness, and uses ordinary attack-move to one public relay at a time. The established regional policy remains the control. No shipping AI or balance change is implied. `RelayExpeditionRegression.gd` checks all factions/both maps, travelling and partial-capture archives, pause and priority bounds; `RelayContestPreview.gd` reviews the retained earned full-match captures. See [strategy audit and reproduction](../../docs/playtests/2026-10-06/RELAY_CONTEST.md).

`SafeConstructionMatches.gd` is an opt-in cautious-reference variant that skips sites and straight builder approaches exposed to currently observed legal attackers. It uses the ordinary paid placement path and leaves the default reference unchanged. `ConstructionArchiveAudit.gd` compares both choices from an earned state; use a fresh `--output-prefix` and optionally `--archive`. See [construction evidence](../../docs/playtests/2026-10-06/CONSTRUCTION_SAFETY.md), including inconclusive full-match outcomes and the separately discovered contact-approach regression.

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

`--research combined` adds paid research once the reference owns a completed lab, basic programs and six healthy ground combatants. It requests Coordination, Weapon systems I, Combat armor I, Field service, faction doctrine, Weapon systems II and Combat armor II, in order, while respecting the shared research slot. Future aircraft construction and requested workers, infantry, repair support, scouts and initial wings retain their budgets. Routine armor protects the next unpaid research purchase. Actual research and production payments contribute to the income accounting. Active research is not charged or reserved twice.

The combined policy retains the old commander's producer order (HQ, barracks, airfield, vehicle factory). Its priority numbers distinguish essential requests from optional armor/research; they do not reorder aircraft behind repair support. The shipping AI uses its own sorted production policy. Neither is a claim of optimal strategy.

`--strategy ground-first` delays the airfield and aircraft until twelve ground combatants exist. `--strategy air-first` permits the airfield after the lab. Both retain the same ordinary construction, finite-field harvesting, authored guard/recovery programs, proactive assault and observed-target aircraft raids. Combined references activate available faction signatures using owned units and currently observed contacts, preserving unit orders. Full observations may inspect both sides for diagnostics; command decisions do not consume hidden enemy telemetry.

`--strategy screened-air` targets six infantry and requires eight healthy ground combatants before starting the airfield. Once that investment is paid, losses do not disable aircraft production. The first strike aircraft takes precedence over optional research; replacing a lost last wing also precedes the next research project. All construction, fitting, production and research still use normal prices and timers. The screen and wing-first budget apply without granting resources or ordering the shipping AI. `army_policy` is the authoritative strategy field in older retained records; newer decisions and samples also record the same policy in `allocation_policy`.

The `reference/` scripts preserve the established commander used in earlier playtests. They were promoted from the identically named `tmp/*.gd` chain, changing only their inheritance/helper paths. The chain ends in maintained headless policies; no `res://tmp/` script dependency remains. The leaf `PaidProgressionMatches.gd` contains the explicit new strategies and research telemetry.

## Native review of earned state

An optional `--archive-prefix PATH` retains the first paid Coordination, paid unit technology and active signature states per case/repetition. It pauses synchronously at a simulation boundary for the normal archive API and immediately restores the previous pause state. Archives use the normal checked save format; they do not alter income or grant upgrades. Use a new prefix for each invocation. Filenames include case, recorded repetition and progression kind.

`PaidProgressionPreview.gd` loads an earned Frontier Weapon systems I archive, checks the research overview and normal-clock timers, and checks signature activation without replacing the existing program. Its `--interactive` mode waits for native clicks/keys (Tech, Escape, Maneuver burst); otherwise it runs rendered input regression events. Captures are 1280×720 at 150% interface scale with normal fog. Supply a new capture prefix.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/PaidProgressionPreview.gd -- --archive=res://tmp/paid-progression/earned-case0-10-technology.json --captures=res://tmp/paid-progression/native --interactive
python3 -m unittest discover -s tests/playtest -p 'test_*.py' -v
```

The Python checks cover empty/invalid input, retained successful records, path quoting, zero-exit script errors, missing records, timeouts and preservation of existing evidence. Gameplay, economy and research regressions remain under `tests/headless/`.

## Native air-defense guidance review

`AirDefenseAdvicePreview.gd` runs the all-faction defense regression and waits for native clicks on Select engineer (Bastion), Select Lancers and Interception (Helix), then Select air defense (Frontier). It uses a controlled paused fixture, captures at 1280×720 / 150%, checks order/resource/pause authority and restores in-memory options. Supply a new capture prefix in an existing directory; the complete run has a five-minute wall limit.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/AirDefenseAdvicePreview.gd -- --captures=res://tmp/paid-progression/air-defense-native
python3 tests/playtest/run_progression.py run --case 0 --research combined --strategy screened-air --output tmp/paid-progression/screened-frontier-bastion.json
```

See [air-defense verification](../../docs/playtests/2026-10-05/AIR_DEFENSE.md) for the original failure, native captures, accepted and rejected matches, and remaining strategy limits.

## Native live-research feedback review

`ResearchFeedbackPreview.gd` loads an earned Weapon systems I archive and requires actual mouse/keyboard input: click live research, Escape, M, Escape, click the later stalled status, Cancel & refund, Escape. It checks a two-second normal-clock interval before a controlled lab-loss/refund phase. Capture size, temporary options and archive rules match the paid-progression preview.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/ResearchFeedbackPreview.gd -- --archive=res://docs/playtests/2026-10-05/paid-progression/earned-frontier-verified-10-technology.json --captures=res://tmp/paid-progression/research-feedback --interactive
```

Use a fresh capture prefix in an existing directory. See [research feedback verification](../../docs/playtests/2026-10-05/RESEARCH_FEEDBACK.md) for exact assertions, native captures and retained fixture corrections.

## Native engineer response review

`EngineerResponsePreview.gd` uses controlled paused raids for all three factions. Click Engineers at risk, press M and Escape for each faction; for Frontier, press M again, choose the indicated world destination, then resume with Space. The runner verifies selection/order/cargo authority and actual retreat movement. Use a new prefix in an existing directory.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/EngineerResponsePreview.gd -- --captures=res://tmp/engineer-response/native
```

See [engineer response verification](../../docs/playtests/2026-10-05/ENGINEER_RESPONSE.md) for the fixture boundaries, original failures and accepted native evidence.

`RosterLayoutPreview.gd` audits all three factions' construction and production tiles at 720p/150%, including expanded squad controls and paid vehicle queues. It runs automatically and optionally takes a fresh `--captures=res://.../prefix` in an existing directory. See [the layout audit](../../docs/playtests/2026-10-06/ROSTER_LAYOUT.md) for geometry checks, reviewed captures and the correction to the earlier clipping diagnosis.

`CargoReturnPreview.gd` uses controlled loaded-engineer fixtures at 720p/150%. Click Return cargo for Bastion; use Tab/Enter for Helix and Tab/Shift+Enter for Frontier, then Space to resume each delivery. It verifies exact deposits and Frontier's preserved queued retreat. Supply a fresh `--captures=res://.../prefix` in an existing directory. See [cargo delivery verification](../../docs/playtests/2026-10-06/CARGO_RETURN.md) for accepted runs, keyboard corrections and fixture limits.

## Experimental engineer withdrawal policy

`EngineerSafetyMatches.gd` extends the paid commander with observed-threat withdrawal, ordinary HQ cargo delivery and guarded resumption of the original field or construction task. Its protected workers are excluded from routine economy reassignment. It accepts the same Godot user arguments as `PaidProgressionMatches.gd`; use it directly, since the Python runner continues to select the established paid commander.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/EngineerSafetyMatches.gd -- --case=2 --repeats=1 --research=combined --strategy=screened-air --output=res://tmp/engineer-protected.json --archive=res://tmp/engineer-stationary.json --archive-prefix=res://tmp/engineer-earned
```

Cases 2 and 6 cover Standard Frontier→Helix and Helix→Frontier. Use new output paths. The optional archive prefix also captures first withdrawal and first recorded delivery. The policy remains experimental: shared retreat destinations and indefinite waits for the original field can suppress income. Do not interpret lower worker losses as successful economy protection.

`EngineerSafetyPolicyRegression.gd` checks all-faction fog, cargo, order stability, actual delivery and renewed income. `EngineerSurvivalPreview.gd` reads the four retained earned archives and requires four native Space inputs; use a fresh `--captures=res://.../prefix`. Its two-second continuations restore existing orders and live enemy AI, without restoring the test reference commander. See [the complete investigation](../../docs/playtests/2026-10-06/ENGINEER_SURVIVAL.md) for failed fixtures, native evidence and strategy limits.

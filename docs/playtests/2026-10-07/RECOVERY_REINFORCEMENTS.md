# Recovery reinforcements before optional research

The current reference commander now reserves its optional research spending until it has the nine ground combatants required by its own assault gate. This corrects a demonstrated spending conflict; it is not a claim that the commander is a stronger general strategy. Shipping gameplay scripts, costs, units, maps and human order behavior remain unchanged.

## Change

The existing opt-in `ReinforcementFirstMatches` rule is reused through `ReinforcementResearchPolicy.select`. `CautiousRelayMatches` applies it by default, so the current defense/reference family receives the same priority. The old standalone experiment and the new comparison driver override a small hook to retain explicit controls. Coordination remains eligible; active research and already-paid production are untouched. Essential workers/infantry retain their existing purchase priority, and research becomes eligible again when the qualifying ground army reaches nine. Relay expedition membership remains excluded just as it is in the assault gate.

## Saved-state comparison

Both branches restore the unmodified paid Standard/Normal Industrial Helix-versus-Frontier archive retained by the preceding materials investigation at 1800.75 seconds. It has 18 M / 224 E and seven qualifying ground combatants. All assault gates other than army size pass. Exact unit positions/HP, funds, paused time and the running authored guard are checked before continuing; enemy strategic AI remains active.

The recorded recovery phase, phase/pressure timestamps, vehicle sequence and army membership are restored. The prior full-match records contain no active engineer withdrawal, conventional/armor treatment, retrofit or relay expedition at this point. Historical diagnostics and unrecorded test-commander cooldowns restart identically in both branches. The source run used seed 4111; the continuation harness seeds both branches with 4110, and the archive does not retain the prior random stream. This is an exact saved **world** with a reconstructed reference commander, not a bit-identical process resumption.

| Observation after restore | Research-first control | Reinforcement priority |
| --- | ---: | ---: |
| First completed new ground unit | 732 s | 27 s |
| Nine ground combatants / first renewed assault | 891 s | 171 s |
| Victory | 995.85 s | 291.25 s |
| Optional research purchased | Weapons II + armor II: 120 M / 70 E | None before victory |

The priority branch attacks twelve minutes sooner and finishes about eleven minutes forty-five seconds sooner in this saved world. Both branches win. They use the full current command, production, safety, service and combat policies, with ordinary paid jobs and harvest income. Restored runtime program ownership is retained without reapplying the existing guard. Harvest accounting subtracts the actual restored bank rather than the Standard-start 60 M / 12 E.

These are late continuations of a match already thirty minutes old: total finish times are 46:36.6 and 34:52.0. They do not establish the intended twenty-to-thirty-minute ordinary-match pacing. The stronger evidence is removal of the specific budget delay, not a general victory or survival claim.

## Fresh matches

One paid Standard/Normal Industrial seed compares the preceding research-first behavior with the reused priority rule. A separate fresh run exercises the final inherited default through the ordinary entry point. All retain screened-air/combined-research settings and the explicitly enabled home-response/electronics helpers; the material-reversal experiment is not enabled.

| Run | Result | First program | First assault | Harvested M / E |
| --- | --- | ---: | ---: | ---: |
| fresh-control | Defeat · 1609.7 s | 185.73 s | 1034.23 s | 864 / 458 |
| fresh-priority | Defeat · 769.3 s | 194.73 s | — | 312 / 244 |
| final-default | Defeat · 794.2 s | 225.23 s | 308.23 s | 424 / 272 |

All three fresh matches lose. They reach programming within three to five minutes; the final default launches an assault and subsequently regroups, but does not sustain a winning defense. Same-seed trajectories already diverge before research selection, so these runs cannot establish that research priority caused their differing outcomes. The default change is justified by the replicated conflict between a purchase priority and its own readiness requirement, not by a fresh-match win-rate improvement.

All five runs, including the two earned continuations, finish normally with zero unresolved checks and zero AI coordination violations over 8,925 samples. Maximum sampled stationary-travel episodes are at most 3.5 seconds. These are gameplay observations, not performance measurements. The old unresolved source remains retained; finishing a later continuation does not retroactively turn its original thirty-minute pacing result into a pass.

## Verification

All-faction reinforcement tests pass both before and after default integration: exact faction/chip payment, research-first refusal, successful paid replacement, cancellation refund, research re-enabling at nine, expedition exclusion, retained Coordination and paused disk continuity through actual completion. The shared research-economy suite also passes, including real capped-army income and research budgets. Formatting and lint pass. The fresh default process runs the ordinary `SustainedDefenseMatches` entry with no reinforcement flag, verifying the inherited default rather than only the explicit experiment.

Trial source snapshots retain the earlier opt-in dispatch; final snapshots retain the default hook. The last fresh control had already loaded the trial scripts before the hook was integrated. Final all-faction tests and the separate default match use the final dispatch. The selection rule itself is unchanged between the two source sets. Existing navigation-readback warnings and shutdown ObjectDB/resource/RID diagnostics remain.

## Reproduction and remaining work

`recovery-reinforcements/analyze.py` validates terminal outcomes, flags, source snapshots, regression summaries, accounting and the unchanged 288-script shipping fingerprint. Eight Godot processes are classified in `run-index.json`; the two source generations each retain 34 inheritance/policy files. Commands, metrics, progression saves, archived-state preconditions and SHA-256 inventory remain alongside the report.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/EarnedRecoveryReinforcements.gd -- --case=6 --repeats=1 --research=combined --strategy=screened-air --home-response --electronics-handoff --reinforcement-first --output=res://tmp/new-recovery.json
```

Omit `--reinforcement-first` for the explicit research-first comparison driver. Use `RecoveryReinforcementMatches.gd` for fresh paired openings, or ordinary `SustainedDefenseMatches.gd` for the new default without a reinforcement flag. Fresh output names preserve earlier evidence.

This resolves the reference spending conflict, not overall gameplay acceptance. Industrial attrition and field-route protection still need work; other factions/maps, novice play, final environment/platform acceptance and deferred performance remain open. The goal remains active.

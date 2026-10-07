# Research progress and interruption feedback — 2026-10-05

The battle HUD now shows the current research project, its progress and estimated remaining time after Tech closes. Low power adjusts the estimate, and a lost lab produces a visible rebuild instruction. When no project is running, the same control identifies currently affordable research choices. Clicking it opens the existing Tech screen; the player still chooses and pays for each project.

The status uses the command panel's existing reserved message area. Direct-order and program-assignment instructions, load messages and transient notices take priority. The status returns when those messages finish. Coordination completion now uses the same notification flow as unit upgrades. Enemy research does not produce a player notice.

## Change and original failure

The original HUD had a static Tech button but no visible text identifying active research once the overview closed. The minimal real-match regression bought Coordination through its ordinary API, closed Tech and inspected visible HUD controls while paused. It failed once for each faction, exit 1 with three expected failures, in [minimal-before.log](research-feedback/minimal-before.log). Research itself remained correctly paid and paused. The exact minimal test and original HUD, Player and TechnologyResearch sources are retained beside that log.

The same minimal scenario passes after the change. Production changes are limited to:

- [ResearchStatus.gd](../../../source/match/hud/ResearchStatus.gd): a standard button and progress bar, current-power ETA, paused/missing-lab state, affordable choice count and accessible descriptions. Choice eligibility uses existing research prerequisites and prices. Status computation does not buy, cancel or choose research.
- [SkirmishHUD.gd](../../../source/match/hud/SkirmishHUD.gd): places the status beside the existing instruction label inside the reserved scroll area. It yields to active instructions and notices without increasing that area's height.
- [Player.gd](../../../source/match/players/Player.gd): announces the human player's actual Coordination completion through the existing notice method.

The number of available choices is informational, not a purchase sequence or a promise that buying all of them is affordable. The tooltip lists each eligible project's individual price. Research timing, costs, prerequisites, shared-slot behavior, refunds, army orders, AI strategy and battle-plan priorities remain unchanged.

## All-faction regression

[ResearchFeedbackRegression.gd](../../../tests/headless/ResearchFeedbackRegression.gd) passes Bastion, Helix and Frontier with zero failures and zero script errors in [expanded-corrected.log](research-feedback/expanded-corrected.log). It uses real Advanced Desert matches with actors frozen for UI/authority checks and explicit normal-clock resumes for research. Research is paid from the fixture's ordinary starting funds. Power-source construction states and a replacement lab are controlled fixtures, not claims of a naturally played rebuilding sequence.

Coverage includes:

- Four eligible starting choices; exact 20 M / 20 E single-choice boundary; no available-choice prompt without funds; completed and unaffordable branches excluded.
- Paid Coordination visible after closing Tech, unchanged paused state, progress following actual simulation time, and the correct low-power speed of 35%.
- A program assignment retaining its instruction while a notice waits; that notice appearing on cancellation; research returning only after the ordinary notice expires.
- Research stopping when every lab is lost, keeping its payment and progress, surviving an actual disk save/load, and yielding first to the normal loaded-battle notice.
- Opening Tech from the stalled status, exact cancellation refund, no stale project afterward, unfinished labs not enabling research, and completion restoring choices.
- Actual full-power Coordination and Weapon systems I completion within 0.05 s of their declared durations, the human completion notices, and no notice for the enemy's simultaneous Coordination.
- Repeated feedback refreshes preserving pause/time, research state, funds, selection, unit positions/health, active actions and waiting orders.

The first expanded fixture reported 54 cascading assertions. It incorrectly assumed physics-frame signals represented already-processed ticks, forgot that HQ itself supplies 20 power, and expected research to appear before the normal load notice expired. The corrected test measures actual simulation elapsed time, waits for completion within the declared duration, suspends both power sources for the shortage fixture, and respects the load notice. No gameplay code or duration was changed for those corrections. The failed log and original expanded test are retained as `expanded-first.log` and `ResearchFeedbackRegression-expanded-first.gd.txt`.

## Native review from an earned archive

[ResearchFeedbackPreview.gd](../../../tests/rendered/ResearchFeedbackPreview.gd) loads the previously earned Frontier [Weapon systems I archive](paid-progression/earned-frontier-verified-10-technology.json). That project was purchased during a complete match; the preview does not grant the research or its funds. Options are changed only in memory and restored. Autosaves are disabled.

At 1280×720 and 150% interface scale, actual native clicks open the live status and Tech, Escape closes it, M starts a destination choice, and Escape cancels that unissued order. The status yields to the visible Move instruction and returns afterward. Opening/closing the overview and cancelling input preserve paused research, resources, selection and army orders. A two-second normal-clock interval advances the earned project to 32.9833 s remaining.

A subsequent controlled lab removal tests the interruption and refund UI. The status reads “Weapon systems I · rebuild lab”; clicking it opens the stalled project. Actual Cancel & refund returns exactly 30 M / 20 E, from 1 M / 55 E to 31 M / 75 E. Closing Tech leaves the battle paused with no stale timer. This lab removal is a UI fixture extension of the archive, not a combat loss from the original complete match.

The final process exits 0 with zero failures and zero script errors. Its inherited runner prints `Paid progression native: 0 failures` in [native-final.log](research-feedback/native-final.log). The final Escape completed and the test closed its window; the subsequent native observation therefore reported that the app had quit.

- [Earned active research](research-feedback/native-final-earned-paused.png)
- [Progress after normal-clock play](research-feedback/native-final-earned-progress.png)
- [Move instruction taking priority](research-feedback/native-final-move-instructions.png)
- [Lost-lab interruption](research-feedback/native-final-lab-lost.png)
- [Stalled project and refund control](research-feedback/native-final-stalled-overview.png)
- [Exact refund](research-feedback/native-final-refunded.png)
- [Return to the paused battle](research-feedback/native-final-back-to-battle.png)

Captures were visually inspected. The command panel stays within its existing height; neither it nor battle-plan advice overlaps the minimap or selection controls. The first native run passed the input and payment checks but sampled status visibility before the UI processed the Move input frame. Its captured Move prompt was correct. The final test waits two UI frames before inspecting visibility; no production change was made. The first log, source and captures remain retained and are not the accepted final run.

## Shared verification and reproduction

CoordinationRegression, TechnologyRegression, BattlePlanRegression and SubtitleLayoutRegression all exit 0 with zero script errors. Technology covers all three factions; the older Coordination and BattlePlan suites cover Bastion/Helix, supplemented by the new all-faction feedback regression. Logs are in the evidence directory. Formatting, lint, changed-line whitespace and evidence links pass. [Final source and artifact hashes](research-feedback/research-feedback-evidence.json) identify the retained files.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/ResearchFeedbackRegression.gd

tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/ResearchFeedbackPreview.gd -- --archive=res://docs/playtests/2026-10-05/paid-progression/earned-frontier-verified-10-technology.json --captures=res://tmp/paid-progression/research-feedback --interactive
```

Use a new capture prefix in an existing directory. The native review requires the indicated mouse/keyboard input and has a four-minute wall deadline. Headless timing regressions use `--fixed-fps 60`.

Existing navigation-readback and renderer/ObjectDB cleanup warnings remain in engine output. No performance acceptance is claimed. This stage improves research visibility; it does not establish novice comprehension, faction balance, full-match pacing, final environment quality or platform acceptance. Those remain open, and performance optimization stays deferred.

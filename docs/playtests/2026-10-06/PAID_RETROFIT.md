# Paid conventional-armor retrofit — 2026-10-06

The opt-in reference commander now purchases chips for surviving conventional tanks and preserves their installation through defense, assault and regroup orders. Completed installations return to ordinary programmed defense. The original command loop interrupts paid installation in all three factions; the corrected loop passes the same scenario. Shipping installation rules, fees, unit statistics, AI and player controls are unchanged. This is a verified commander transition, not a demonstrated generally winning strategy.

## Conflict and correction

`PaidRetrofitRegression.gd --authority-only` starts an actual paid installation and invokes the existing `SkirmishDefensePolicy` command loop while paused. The old loop treats an installing tank as an unprogrammed defender, replaces `ChipInstalling` with AttackMove and refunds the fee. `before.log` exits one with three expected failures, one per faction.

A default-false `_protected_from_command` hook now lets an explicitly chosen policy retain its installation through all three assignment sites: army-wide assault entry, army-wide regroup and ordinary per-unit defense/attack decisions. Existing reference scripts retain their previous behavior. The new regression uses nine actual units to trigger assault entry, then an injured army to trigger regroup; it checks that the fitting tank keeps the same action throughout. After live installation finishes, the actual commander configures and runs its defense program.

`PaidRetrofitPolicy.gd` is opt-in test policy. It:

- Considers conventional tanks after basic technology unlock, with at least 60% HP, no hit in the preceding five seconds, no waiting manual orders and no active program.
- Withdraws at most one tank at a time, and avoids units currently engaged or within the existing observed-danger margin.
- Chooses a completed owned HQ or RepairDepot that is safe against currently observed threats and has a reachable installation perimeter.
- Uses the shipping `install_at` API, reserving the faction's normal electronics fee and retaining its actual installation time and power scaling.
- Cancels and refunds if observed danger reaches the unit/service, or the service is lost. It records live cancellation/refund and death/lost-fee outcomes separately, and waits ten seconds before retrying that unit.
- Does not start new installations during an assault. An already accepted installation keeps its authority through an army phase change.

The policy's net-fee ledger is added to the reference commander's existing spending totals, including refunds. It records episodes and skip reasons; it does not add stockpiles, units, HP or technology. Policy bookkeeping itself is external to the match archive, while the actual paid installation and program state use the existing save format.

## Verification

`transitions.log` is the final all-faction regression: zero failures. It covers exact faction fees, installation under tactical pause, ordinary commands plus actual assault/regroup transitions, one-unit concurrency, real completion and a Running defense program, unavailable funds, wounded units, pending manual orders, hidden-contact noninterference, cancellation when the contact becomes visible, exactly-once refund, retry cooldown, deleted service, and no refund when the installing unit dies. Earlier successful incremental runs are retained as `regression.log` and `verified.log`.

The shared earned conventional-infantry recovery regression also passes, so the new opt-in protection does not break that previous return-to-assault handoff. Five affected/new scripts pass format and lint checks. Successful logs have no script/parse errors. Existing navigation-readback warnings and renderer/ObjectDB shutdown cleanup diagnostics remain separate from assertions and match results.

## Complete paid observations

`PaidRetrofitMatches.gd` extends the explicitly selected two-tank opening experiment, with screened-air production, combined paid research, engineer reassignment and infantry recovery. All runs use Coastal Foundry, Standard start and Normal shipping AI.

| Reference → AI | Seed | Result / seconds | Basic unlock | First ground-program setup | Installed / refunded episodes | Net retrofit E | Collected M / E |
| --- | ---: | --- | ---: | ---: | --- | ---: | --- |
| Frontier → Helix | 4110 | Victory / 1118.2 | 168.7 | 181.2 | 2 / 1 | 4 | 766 / 296 |
| Frontier → Helix | 4111 | Defeat / 646.2 | 187.8 | 191.8 | 1 / 0 | 2 | 254 / 84 |
| Helix → Frontier | 4110 | Defeat / 342.9 | 181.2 | — | 0 / 0 | 0 | 212 / 72 |
| Helix → Frontier | 4111 | Defeat / 658.8 | 171.3 | 182.3 | 2 / 1 | 8 | 471 / 86 |

The Helix 4110 sample at 180.7 seconds has no surviving tank and technology still locked. Unlock follows at 181.2 seconds; no installation episode is recorded. This is an opening survival/progression failure, not a cancelled or blocked retrofit.

Across the four matches, five installations complete, two threat cancellations refund six electronics, and fourteen electronics remain spent. Summing episode fees minus refunds matches every recorded net total. There are 67 installation-authority checks, 507 conventional-treatment checks and 9616 engineer-authority checks without failure. AI coordination has no violations over 5532 samples. The longest sampled stationary travel interval is five seconds, and no fifteen-second stationary archive triggers. Both match processes exit zero with two complete records each and zero unresolved checks.

The first completed Frontier retrofit takes 4.5 seconds including travel; the first completed Helix retrofit takes 8.5 seconds including travel. Three trials reach the ground-program transition, but the overall one-win/three-loss count does not establish improved strategy or faction balance. Small samples and asynchronous navigation prevent deterministic causal comparison with previous observations. Installation completion also does not guarantee later unit survival.

## Native paid-state and player-control review

`PaidRetrofitPreview.gd` restores `earned-2-case2-10-retrofit_installing.json` from the first paid Frontier match, selects the installing tank and verifies frozen clock, funds and installation time during tactical pause. The archive starts at 176.733 seconds with three fitting seconds remaining and stockpiles of 4 M / 28 E; the chip fee is already paid.

Native Space lets the live actors and enemy AI continue until installation completes. The external reference commander is not reconstructed. With the scene paused again, a real click on **Apply & run** accepts the existing Hold preset without advancing the simulation or charging another fee. A second Space starts the program; the final capture shows **Running**, **1 / 1 compatible & ready**, and the tank at 68/68 HP. Harvesting continues normally while unpaused, so changed stockpiles after installation are not treated as chip charges.

The four installing/installed/ready/running PNGs are exactly 1280×720 at 150% interface scale and were reviewed. The native process exits zero with zero failures. The separate headless command-loop regression supplies the programmed-defense handoff evidence; the native scene verifies the actual player's paid-installation-to-program flow.

## Reproduction and remaining work

Use fresh output/archive paths. Raw logs, earned snapshots, before-source, summary, validation and hashes are in `paid-retrofit/`.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/PaidRetrofitRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/PaidRetrofitMatches.gd -- --case=2 --repeats=2 --research=combined --strategy=screened-air --output=res://tmp/retrofit-matches.json --archive=res://tmp/retrofit-stall.json --archive-prefix=res://tmp/retrofit-earned
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/PaidRetrofitPreview.gd -- --captures=res://tmp/retrofit-native
```

Case 6 is Helix→Frontier. The native preview reads the retained Frontier installation archive and requires Space, Apply & run, then Space.

The early-defeat and sustained-pressure problems remain open. This policy does not justify automatic player retrofits, free chips or stat changes. Next, inspect player-facing early-game advice and counter-production against the retained opening losses, preserving the now-verified manual-to-programmed transition. Broader gameplay acceptance remains active; performance optimization stays deferred.

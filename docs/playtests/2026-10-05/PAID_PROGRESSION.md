# Paid research and army progression — 2026-10-05

The AI now includes eligible unpaid research in its harvesting demand and saves for it before another routine armored unit. This fixes a demonstrated all-materials state at the population cap and gives technology a budget during ordinary production. Construction, replacement engineers, observed counters, repair support and initial aircraft keep their existing precedence. Current prices and unit statistics remain unchanged.

The complete-match reference commander now has explicit paid-research and ground/air strategy choices, with retained records and a reusable runner. Ten Standard/Normal Coastal matches reach actual outcomes. Paid technology, authored programs and faction abilities coexist in several ground-first runs; research is not forced into matches where the army or economy cannot support it. Final balance, novice pacing and the broader game goal remain open. Performance work remains deferred.

## Original failure and production change

The baseline AI's labor demand contained building and unit costs, but no research. In a legal staged base at population 100, those existing demands are zero. Six materials gatherers remain assigned to materials even when Coordination needs electronics. With real finite deposits, movement, work slots, delivery and research timers, the original maintained scenario fails 18 assertions: after 180 seconds all three factions still have 0 E and no Coordination. Assigning an engineer to electronics manually allowed the original research API to work, isolating the policy omission.

The changed policy completes the same zero-resource, six-worker scenario:

| Faction | Coordination purchased | Coordination completed |
| --- | --- | --- |
| Bastion | 64.48 s | 94.50 s |
| Helix | 56.98 s | 87.00 s |
| Free Frontier | 55.48 s | 85.50 s |

`SkirmishAI._research_candidate` returns only an eligible, unpaid ID and canonical cost. A currently completed lab is required even after the basic-program unlock has become permanent. Active Coordination or unit research produces no second reservation. `SkirmishProduction.demand` includes the candidate, and routine priority-6 production protects its cost. The existing healthy-army gate still governs unit upgrades. Full details, before sources, original failure logs and controls are in the [research economy audit](paid-progression/research-economy-review.md).

The older mixed-production regression keeps its original Tank + Helicopter earning threshold and 100-second deadline. It now explicitly checks that the first wing is purchased while routine armor preserves research savings, then earns the additional Coordination price in a separate 60-second phase. Bastion/Helix earn the original budget in 67.42/75.57 seconds and complete the additional purchases in another 33.00/34.50 seconds. Both queues finish; finite-stock/cargo/payment conservation and the final materials handoff pass.

The first attempted test adaptation required another 20 E within the original deadline. Helix reached 52 E against that expanded 54 E requirement, although it exceeded the original 34 E requirement. That failed attempt is retained and explained in the audit. The final test does not weaken the original traffic contract or grant the extra purchase.

## Declared complete-match observation

All runs use ordinary Standard opening resources and units, Normal shipping AI and Coastal Foundry. The reference gathers finite resources, pays for construction, production, fitting and research, uses authored guard/recovery programs, and attacks observed targets. Neither side receives additional resources or free research. Research orders use the ordinary `start_coordination` / technology APIs; signature activation preserves existing orders. Hidden enemy state is recorded for diagnosis but does not drive reference commands.

The old reference commander never requested research. Two pre-fix ground-first baselines, [Bastion → Frontier](paid-progression/baseline-4.json) and [Helix → Frontier](paid-progression/baseline-6.json), ended in reference victories at 881.6/1003.7 seconds; the Frontier AI completed Coordination at 387.93/459.22 seconds, but neither side completed unit technologies. Those baselines show why a reference-policy omission must be separated from the AI funding defect.

The new `combined` reference requests Coordination and subsequent weapon, armor, service and doctrine research once it has a lab, basic programs and six healthy ground combatants. It protects construction and essential unit requests. Ground-first delays air until twelve ground combatants; air-first allows the airfield after the lab. Both retain the original commander's producer order, so its numeric priority labels govern research protection rather than sorting aircraft behind repair support. See the [runner and policy documentation](../../../tests/playtest/README.md).

| Reference → AI | Strategy | Recorded seed | Outcome / duration | Reference Coordination complete | Reference completed upgrades | Reference signature activations |
| --- | --- | --- | --- | --- | --- | --- |
| [frontier → bastion](paid-progression/combined-air-0.json) | air-first | 4110 | Defeat · 311.0 s | — | — | 0 |
| [frontier → helix](paid-progression/combined-air-2.json) | air-first | 4110 | Defeat · 358.5 s | — | — | 0 |
| [bastion → frontier](paid-progression/combined-air-4.json) | air-first | 4110 | Defeat · 338.7 s | — | — | 0 |
| [helix → frontier](paid-progression/combined-air-6.json) | air-first | 4110 | Defeat · 344.1 s | — | — | 0 |
| [frontier → bastion](paid-progression/combined-ground-0-repeated.json) | ground-first | 4110 | Defeat · 1162.7 s | 367.2 s | W1, A1, Service | 28 |
| [frontier → bastion](paid-progression/combined-ground-0-repeated.json) | ground-first | 4111 | Victory · 865.2 s | 183.3 s | W1, A1, Service, Doctrine, W2 | 54 |
| [frontier → bastion](paid-progression/combined-ground-0.json) | ground-first | 4110 | Victory · 824.0 s | 328.2 s | W1, A1, Service, Doctrine, W2 | 54 |
| [frontier → helix](paid-progression/combined-ground-2.json) | ground-first | 4110 | Victory · 885.2 s | 300.8 s | W1, A1, Service | 72 |
| [bastion → frontier](paid-progression/combined-ground-4.json) | ground-first | 4110 | Victory · 714.0 s | 304.2 s | W1, A1, Service, Doctrine | 36 |
| [helix → frontier](paid-progression/combined-ground-6.json) | ground-first | 4110 | Defeat · 551.1 s | — | — | 0 |

W1/W2 mean Weapon systems I/II; A1/A2 mean Combat armor I/II. A dash means the milestone did not occur before the outcome, not a missing measurement. Durations and milestone times are simulated seconds from match start. Signature counts are activation cohorts, not unit counts.

All ten observations exit 0 with zero unresolved gameplay checks and no script errors. Ground-first produced four victories/two defeats across 551.1–1162.7 seconds. The four air-first references lost at 311.0–358.5 seconds without completed research on either side. This specific early-air plan does not sustain its ground defense. It is not evidence that all aircraft strategies are weak or that research should receive free resources.

The repeated Frontier/Bastion ground matchup produced both a victory and a defeat at seed 4110 and a victory at 4111. Godot's asynchronous setup/navigation/physics are not fully deterministic from the recorded random seed, so these observations establish reachable progression and expose variation; they do not establish win rates. The shipping Frontier AI completed Weapon systems I and Combat armor I against the Helix ground reference; Bastion AI also completed Weapon systems I in the longer Frontier loss. Targeted tests separately cover all three factions' eligibility, purchases and bonuses.

The raw records retain funds, units, worker states, lab/army readiness, research transitions, production reserves, fitted purchases, abilities, observed wreck salvage, losses, repair and command coordination. [The compact cohort summary](paid-progression/cohort-summary.json) derives from those retained files. No match was stopped at a convenient technology milestone or changed into a victory.

## Native earned-state review

The [native preview](../../../tests/rendered/PaidProgressionPreview.gd) loaded an ordinary archive captured immediately after the reference paid for Weapon systems I at 545.25 seconds in the repeated Frontier/Bastion match. Coordination and a running authored unit program were already earned. No resources, units or research completion were staged for this review.

At 1280×720, 150% interface scale and ordinary fog, actual native mouse/keyboard input opened Tech, closed it with Escape, and activated Maneuver Burst from selected fitted armor. The checks verify that opening/closing research preserves funds, research time and prior pause; two seconds of normal-clock play advance research by two simulation seconds; activation preserves the running army program and costs no new resources; its six-second window then counts down normally. The selected guard remained stationary, so this UI check does not claim movement-speed coverage. Actual moving combat activations are recorded in the full matches and existing signature tests cover their rules.

The final [native log](paid-progression/native-final.log) reports 0 failures and no script errors. The first review exposed a single-unit notice saying “1 units”; the notice now uses singular/plural agreement, with a second native run and capture confirming it. Technology text and controls fit their scroll containers; the keyboard focus outline remains visible.

- [Earned lab selection](paid-progression/native-final-lab.png)
- [Paused technology overview](paid-progression/native-final-research.png)
- [Final single-unit Maneuver notice and running program](paid-progression/native-final-maneuver.png)
- [Normal-clock cooldown/window](paid-progression/native-final-maneuver-live.png)

The native test window closed after each final click completed its assertions, causing the subsequent accessibility observation to report no window. The process exit, retained captures and final assertion log confirm completion; the click was not repeated.

## Verification and retained setup failures

The following finish with exit 0 and no script errors: `ResearchEconomyRegression`, the two-stage `SkirmishLaborRegression`, `SkirmishBudgetRegression`, `TechnologyAIRegression`, `TechnologyRegression`, `SkirmishCompositionRegression`, `SignatureRegression`, `SkirmishCoordinationRegression` and `SkirmishHandoffRegression`. Coverage includes exact prices, finite-stock conservation, urgent production, shared research slots, lab loss/rebuild, real research completion, paid bonuses, signatures and order/archive continuity. These targeted scenarios stage eligibility/budget boundaries where appropriate; only the income and full-match cases claim earned progression.

The Python runner checks cover invalid/empty input, accepted records, paths with spaces/shell syntax, zero-exit script errors, missing records, timeouts and refusing to overwrite evidence. [Their final log](paid-progression/runner-tests-final.log) passes all three test groups. Changed GDScript formatting/lint and workspace whitespace checks pass.

Exploratory harness errors remain distinguishable from gameplay results. Initial preloads failed before either baseline match could start; their logs are retained separately. The first optional archive run was terminated after discovering that the save API requires a paused simulation boundary; `combined-ground-0-repeat.log` is excluded from the cohort. The corrected capture pauses synchronously and restores the previous pause state. An early signature trigger captured the existence of a signature component before activation; the two `earned-frontier-verified-*-signature.json` files contain zero active signatures and are excluded from ability evidence. Their technology archives are valid and supplied the native review.

The final `earned-final-frontier-helix-case2-10-*` archives include case/repetition in their names, refuse existing paths, and capture the actual requested state: Coordination active at 270.75 seconds, one active Maneuver signature at 301.25 seconds, and paid Weapon systems I at 332.75 seconds. [The archive audit](paid-progression/archive-audit.json) checks stored payload hashes and records these states. The final full match using this capture code ends in victory at 885.2 seconds.

Existing navigation-mesh runtime warnings and renderer/ObjectDB cleanup messages remain in logs; “no script errors” does not mean warning-free shutdown. This work makes no performance claim.

## Remaining acceptance

The observed matches last roughly 5–19 minutes, short of the design's aspirational 20–30-minute ordinary-match pacing. Early-air play, broader tactics/maps/difficulties, repeated faction balance and novice behavior remain to be evaluated. Helix's ground reference lost before funding research; that is retained rather than forced into a technology showcase. Final environment quality, broader accessibility/content/platform acceptance and deferred performance work remain outside this completed funding/progression stage. The overall game-development goal remains active.

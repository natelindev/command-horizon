# Defense advice regression — 2026-10-05

The original advice selected tanks and infantry against an observed aircraft raid even though none of those units could target it. The minimal paused fixture reproduced this for Bastion, Helix and Frontier through both `SkirmishTactics.defense` and `SkirmishPlan.next_step`: each selected `[Infantry, Infantry, Tank, Tank]`, with zero legal anti-air weapons. Adding an owned Helicopter did not remove the irrelevant ground-only units. Repeated selection assertions produce 36 expected failures, exit 1, in `advice-minimal-before.log`; paused authority checks already passed. This is one shared selection defect, not 36 separate gameplay defects. The exact minimal test and original Tactics/Plan/CombatRules sources are retained.

The maintained `tests/headless/AirDefenseAdviceRegression.gd` now passes all three factions, exit 0 with zero failures and zero script errors, in `advice-final-after.log`. Actors are normally spawned in a real Desert Frontier match and frozen for paused advice checks. Observation comes from the actual battlefield system. Prices, attack domains, sight, geometry and research are not altered. Brief controlled resumes exercise actual Helix stance timers and activation of the selected engineer's construction order.

## Checked behavior

- Air-only advice selects only owned mobile units that can target the observed raider. Mixed raids include relevant ground and air defenders. Bastion/Frontier walkers use their real dual-domain weapons.
- Helix Precision Lancers receive explicit Interception guidance. Pending switches are described as unavailable rather than ready fire; completed timed switches become ready. The symmetric ground-only raid selects Interception Lancers for explicit Precision guidance. No advice call changes stance, pending timer or orders.
- An undeployed Helix Prism remains a valid ground responder: deployment delay does not change its target domain. Empty compatible forces select existing ground production; absent producers lead to real Barracks construction guidance.
- Nearby completed anti-air batteries can be selected as cover. Distant and unfinished batteries cannot be advertised as current cover.
- Construction fallback identifies AntiAirTurret or its missing VehicleFactory/Barracks prerequisite with the current faction's names. Exact 1 M / 2 E shortages remain visible. A legal AA foundation is placed through the normal placement handler, its exact cost is checked, and advice recognizes its already-paid status.
- A strong hidden-contact fixture places an owned lone worker 10 m from the raider: inside the economic threat margin, outside the worker's actual sight. The hidden aircraft must not trigger defense. A real recorded hit from that currently unseen source produces generic incoming-fire advice without inventing an aircraft classification.
- An observed unarmed scout, an observed AA-only enemy weapon unable to hit ground economic assets, and an observed aircraft near only a remote combat unit do not trigger economic defense.
- Engineer replacement and HQ recovery retain their earlier priority in Plan during a raid.
- Repeated advice calls preserve pause/clock, resources, unit positions/health, current action objects, waiting manual orders, weapon mode/switch state, production queues and selection.

These are advice and legality fixtures, not complete matches or native-input acceptance. The parent agent owns screened-air matches and native review.

## Foundation fixture correction

The first expanded run, `advice-expanded-after-first.log`, and its retained repeat, `advice-second-before-fixture-correction.log`, each failed three assertions that immediately expected a particular active engineer after placing a foundation while paused. The normal placement flow had correctly queued Construct; it had not activated that action. Existing builder advice could therefore choose another idle engineer. This was a fixture timing assumption, not an air-defense production defect.

The final test first verifies that placement retains the selected engineer's pending Construct order and that advice leaves it dormant during pause. It then explicitly resumes three normal physics frames, pauses again, and checks that advice selects the now-active engineer. No deadline is lengthened, funds granted for this correction, or production behavior changed. The original expanded test source is retained alongside the failed logs.

## Native extension hooks

`_review_air_advice(player, label)` is a no-op in the maintained headless test. Hook labels are `bastion-mobile`, `helix-mobile`, `frontier-mobile`, and the corresponding `-construction` labels, plus `helix-interception`. All run paused with actors disabled. The final Helix hook occurs after headless stance checks, immediately before the Lancer is removed; a native extension can explicitly click Interception without restoring its stance. Explicit native selection may change selection; the pure-query authority check separately verifies that computing advice does not select automatically.

Formatting, lint and whitespace checks pass. Final engine output includes the existing navigation-mesh runtime warning and an ObjectDB cleanup warning, with no script errors. Source and log hashes are recorded in `advice-regression-evidence.json`. The audit agent changed only the new regression and this evidence; the parent agent owns production changes.

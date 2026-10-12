# Main integration verification — 13 October 2026

The completed mechanics/campaign commit `0287047` was merged with the existing
`main` commit `18b4b43`. Both sets of changes are retained; no history is replaced.

The two textual conflicts retain AI program arming alongside paid camp recruitment,
and preserve immediate program Resume authority alongside guarded dummy-unit access.
Review found two semantic overlaps: drag-heading formations needed the same reachable
slot packing as click formations, and automatic counter choice needed to respect
idle Hold fire/Hold position eligibility. Allied assistance cannot move or fire
units that explicitly hold those states. Direct player attacks remain authoritative.

Verification after resolution:

- 25 relevant headless suites pass with no script errors, including new real
  counter/stance integration, programs, orders, combat, recovery, AI budgets/sites,
  coordination, canonical archives, story/boss restore, starting orientation,
  paused HQ waypoints and localization. [Raw logs and summary](main-merge/summary.json).
- Tier 1 and Tier 3 checks pass; all 21 real 100-unit formation cases pass,
  including dragged line/wedge formations at both corners for all factions.
  Fixtures declare their actual properties and navigation synchronization state.
- Campaign briefings/endings and facility controls pass in English and Chinese
  at 1280×720 / 150% in the real renderer. Actual mouse/keyboard input, pause,
  recruitment/refunds and modal isolation remain intact.
  [Controls evidence](main-merge-controls/REPORT.md); campaign log is in `main-merge`.
- Editor import has no script errors; changed GDScript lint/format and diff checks pass.

The [53-suite mechanics report](MECHANICS_COMPLETION.md) and its hashes record
commit `0287047` before this integration; they remain historical evidence.
This merge-specific record describes the combined version. Existing shutdown
ObjectDB/resource diagnostics remain in raw logs; these checks do not claim signed
release/device or universal balance acceptance.

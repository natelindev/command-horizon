# Game mechanics improvement plan

Scope: improve the existing RTS mechanics while preserving the art style, models,
materials, lighting and visual design. The user subsequently expanded scope to larger maps, capturable facilities,
voiced campaign storytelling, functioning enemy bases and boss encounters.
Performance optimization, PvP and naval combat remain outside this work.

## Stage 1 — Movement and command reliability

Reproduce problems with group destination spacing, navigation boundaries, queued
orders and contextual commands. Repair confirmed failures, preserving manual
authority, fog rules, ground/air separation and pause/save continuity.

## Stage 2 — Combat and recovery

Review automatic targeting, counters, army support, retreat, service assignment,
heroes and faction abilities. Improve specific behavior failures rather than
changing combat statistics without match evidence.

## Stage 3 — Economy, progression and AI

Review worker assignments, openings, expansion, production/technology spending,
programmed behavior and AI response. Verify ordinary paid actions and avoid
granting hidden information or free resources.

## Stage 4 — Campaign, pacing and acceptance

Run relevant regressions and representative live simulations. Review campaign
encounters and victory behavior. Retain failures and distinguish scripted
correctness from participant-based balance, pacing and usability acceptance.
Record changed mechanics, evidence and remaining limitations.

## Stage 5 — Larger maps and capturable facilities

Add distinct expanded map paths with more fields and useful infantry-capturable
refineries, camps and repair shops. Integrate economy, paid recruitment, repair,
AI use, minimap/controls and strict archive references without changing art.

## Stage 6 — Campaign storytelling and dynamic opponents

Connect the six missions through skippable animated camera briefings, milestones
and endings. Generate English/Mandarin narration with Hugging Face neural TTS.
Add ordinary paid enemy production and a warned, dodgeable finale commander.

## Stage 7 — Integration and completion

Check bottom-facing bases, live cargo return, paid exits, site controls,
bilingual 720p/150% briefings/results, legacy/new save continuity and packaged
narration. Retain raw failed and passing traces and report bounded acceptance.

## Agent progress

- 2026-10-12: Started mechanics-only review. Working tree initially clean. The
  existing movement/order suites and local Godot 4.6 executable are available.
  Historical losing reference commanders are evidence for investigation, not
  justification for arbitrary faction-stat changes.
- Stage 1: reproduced map-edge slot collapse and coincident-origin overlap;
  group commands now pack reachable destinations. Mixed attack-move now carries
  selected unarmed support using ordinary Move while combatants retain fighting
  advance. Single-unit destinations remain explicit.
- Stage 2: ordinary idle, attack-move and garrison fire now prefer effective
  counters and avoid targets already covered by lethal unresolved allied
  projectiles. Explicit attacks and player-authored program priorities remain
  authoritative. Recovery and cargo delivery select reachable service routes.
  Ownership-loss checks already pass, so no speculative repair change was made.
- Stage 3: reproduced optional lab reservations blocking affordable defensive
  infantry. Visible raids now protect urgent paid production before optional
  construction; peaceful technology savings retain their behavior.
- Verification in progress: new all-faction regression passes. Corrected fixture
  preload order, faction-specific infantry prices and asynchronous test-map
  synchronization before accepting results. Existing direct-order, combat and AI
  budget suites pass. Broader gameplay, archive and campaign checks follow.
- Stage 3 follow-up: Resume now retires the previous action immediately and
  defensive assistance protects a Ready program before its first tick. This
  repairs the independently reproduced Anchor/retreat regression. New presets
  gain Best counter priority; explicit nearest/weakest/armor choices remain valid
  and retain their existing semantics. No unit statistics or costs changed.
- Stage 4: retained original/current campaign failures and the paid reference
  commander's defeat. Fixed stale test power assumptions and a parked Hold unit
  blocking a separate rally fixture. Rendered direct-order input passes at
  1280×720 / 150% scale. Final preset, mission and localization checks are running.
- 2026-10-13: Implementation and bounded verification stages complete. Expanded
  destination search passes 100 mixed armor units at both corners and the center
  for all factions. The final mechanics regression reproduces 18 original failed
  assertions and passes with zero. Canonical Lua/visual envelopes preserve saved
  hashes independently of fresh preset defaults; guard archives pass. Thirty-three
  headless suites and rendered controls pass. Original/current engineer timing,
  Split strategy and Foundry count failures remain retained, along with both paid
  reference defeats. Broad balance/pacing, participant and release acceptance
  remain open; see [the mechanics report](playtests/2026-10-12/MECHANICS.md).

- 2026-10-13 continuation: resumed the three retained failures and standard
  match progression at the user's request. Reproduced repeated builder diversion,
  guards ignoring ranged fire just outside their area, and finite factory output
  crowding its own portal. Construction now waits for a delivery boundary, guards
  can return observed fire without outside pursuit, and Foundry assembly leaves
  the production corridor open. Unstarted departures can reselect a clear route.
- Focused outcomes: the archived engineer delivered within 36.2 seconds; Split
  Signal won after four waves at 137.52 seconds; Foundry released six paid tanks
  and its ordinary playthrough won at 139.92 seconds. The standard reference now
  commits its four-infantry/two-armor opening instead of waiting for nine units
  while refusing further infantry, and reached a paid assault and Bastion victory.
  Final all-faction, archive, campaign and rendered verification is underway.

- 2026-10-13 scope extension: user requested bottom-facing starting buildings;
  all owned starting structures now face +Z, including their production portals.
  Standard/advanced starts for all factions, all six campaigns, actual paid exits
  and preservation of saved orientations pass. Rendered three-faction starts pass.
- Stage 5 — Expanded world: user requested larger maps, more resource fields and
  infantry-capturable refineries, mercenary camps and repair shops. Three expanded
  map paths preserve original archive layouts. Facilities have ten-second capture,
  contested service suspension, finite income, paid recruitment and repair support.
  Save/schema/UI and opponent use are being integrated.
- Stage 6 — Campaign: user authorized parallel agents for voiced storyline and
  animated briefings, paid operating enemy bases and a dodgeable finale boss.
  Cinematics preserve the previous camera/pause state and allow skip. Narration
  is now generated with pinned Hugging Face neural TTS models in both languages,
  replacing initial system speech at the user's request. Only baked audio ships.
- Stage 7 — Integration: archive/schema roundtrips, full mission outcomes, live
  economy around idle starting engineers, rendered facilities/results and voice
  playback are being checked before completion. Preserve all failing traces and
  distinguish genuine gameplay faults from invalid fixture assumptions.

- Final completion, 2026-10-13: all seven stages complete. Fifty-three distinct
  headless suites pass with zero final assertion failures and no script errors;
  bilingual 720p/150% facility, story/result and native control checks pass. The
  full expanded-map matrix passes 72 field returns and paid exits. Clear resource
  paths retain their original goals; actual settled body rows trigger detours.
  All 54 HQ fixtures, 24 sequential Alpine cases and six paused waypoint archives
  pass. Fresh paid references reach Victory for all three factions (412.63,
  541.97 and 386.68 seconds). Earlier failures and obsolete cached/partial runs
  remain explicitly retained. The isolated export pack includes all 52 neural
  voiceovers and narration JSON. No art/style or ordinary combat-stat changes.
  See [completion evidence](playtests/2026-10-13/MECHANICS_COMPLETION.md); broader
  participant, subjective voice, balance, device and release acceptance remains
  separate from completed implementation and bounded verification.

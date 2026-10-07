# Playable game development roadmap

The user authorized sequential implementation of the remaining game design on 2026-10-01. This plan tracks delivery; the core gameplay specification remains the behavior contract. Complete and verify each playable stage before expanding it. Existing art demos remain available.

## Current priority — complete the playable skirmish loop

User steering (2026-10-02): defer performance optimization until later. Prioritize the actual gameplay loop. Existing measurements are retained as future acceptance evidence, not the current work queue.

User steering (2026-10-03): the environment is too simplistic. Keep the present layouts as gameplay blockouts, and schedule a substantial environment pass after the current gameplay checks. Add distinctive regional landmarks, varied terrain/elevation and ground materials, industrial structures and smaller props, lighting/atmosphere and environmental storytelling. Preserve navigable widths, sight/fire rules, objective readability and unit silhouettes; avoid filling the map with repeated decorative obstacles. Final environment quality remains an explicit acceptance gate.

1. Make Standard-start economy → base/army → chip/program unlock → assault/recovery → outcome understandable and actionable for both factions. Preserve direct player control; recommendations do not issue orders or award resources.
2. Exercise a real paid harvesting/building/production/programming/combat progression and fix gameplay blockers found along that route. Add compact, dismissible skirmish guidance and useful own-unit selection shortcuts; authored campaign objectives remain separate.
3. Verify both-faction rules and real 720p player controls, then continue missing gameplay/content. Profiling, stress runs and release frame-rate tuning are deferred unless a specific defect prevents playing this loop.

## Industrial surroundings follow-up — 2026-10-04

1. Capture the existing district, then author editable rail-service, utility and vegetation assets and continuous exterior terrain. Keep all new tall scenery outside the playable rectangle; retain the six landmark envelopes, streets, paired fields and two relay objectives.
2. Add restrained surface wear and review ordinary fog, hidden enemy territory, street-level combat and the wider composition at 720p/900p.
3. Verify imported bounds, terrain seams and navigation isolation, both-faction movement/retreat/economy/capture/archive flows and shared Foundry aircraft clearance. Record exact results and remaining acceptance limits.

## Stage 1 — Combat foundation and scale

Implement shared visibility and direct-fire obstruction checks, armor/weapon profiles, non-stacking repair and two-slot infantry/air service. Explain roles/service in selection UI. Regress hidden targets, obstacles, fractional damage, repair stacking, power and pause. Run existing movement/skirmish tests and measure 200-unit movement/combat. Record actual results and remaining limits.

## Stage 1 follow-up — Combat animation

The user identified primitive battle animation during Stage 1. Deliver faction-colored tracers, cannon recoil, rail streaks, missile smoke trails, hit reactions, impact sparks/fire/dust, walking/air motion and bounded temporary wrecks. Verify the actual rendered battle, tactical pause and the 200-unit workload. This presentation work does not imply final skeletal animation or sound design.

## Stage 1 follow-up — Individual unit motion

The user requested long-idle micro movement for every mobile unit and less synchronized group animation. Implement private per-unit cosmetic profiles, delayed idle breathing/weight shifts/scanning/tool movement, varied gait/hover/recoil/hit reactions and bounded death trajectories. Keep foundations, orders, navigation, damage and weapon cadence authoritative. Verify all 16 faction/mobile combinations, group diversity, long-run transform stability, tactical pause, actual rendered combat and the 200-unit workload. Record the result in the playtest report.

## Stage 2 — First programmable-unit slice

Deliver basic chip progression and retrofit, default Hold/Guard/Escort/Retreat/Target Priority behavior, explicit assignments, manual command authority, readable state/reasons, and a versioned reusable library.

1. Implement and verify built-in presets, hardware/fees, assignment UI, pause/override and local library.
2. Measure 200 active presets and correct perception/intent bottlenecks.
3. Add Coordination progression, queues/squad authority, specialist presets and factory version pins.
4. Validate a Lua dependency and sandbox, then route custom code through the same command authority. Add a bounded Lua runtime only after dependency and sandbox validation. Prove that a failing program cannot block the simulation or override a human order.

## Resource presentation follow-up

1. Replace the similar salvage variants with six distinct silhouettes, coherent materials/electronics colors and manufactured detail. Keep gathering and navigation footprints stable.
2. Add matching resource symbols to the economy HUD and strengthen the persistent power indicator, including healthy, nearly full, full and deficit states.
3. Review rendered gameplay and all six assets, verify power transitions and small-screen layout, and run the harvesting/navigation regression.

## Stage 3 — Authoring and tutorial

Add visual rules compiling to Lua, test arena and trace, custom Lua editing, and the First Orders campaign mission. Complete it without code or a network. Add save/load with embedded program versions and simulation durations.

### Lua runtime implementation stages

1. Pin and review official Lua and Godot C++ sources, build a narrow native extension, and document the permitted API and dependency update procedure.
2. Exercise the real runtime with valid scripts, malformed/hostile scripts, instruction/allocator exhaustion, bounded serialization and independent unit states. Keep the Lua error boundary inside C so a longjmp cannot skip Godot/C++ destructors.
3. Connect bounded snapshots/intents to chip readiness, local observation, explicit assignments and manual authority; regress faults, pause, replacement and clean Resume.
4. Add custom-program library/editor/arena workflows and profile the complete 200-unit loop. Runtime validation alone does not complete authoring or programmable combat.

### Player authoring implementation stages

1. Extend the local library with backward-compatible migration, immutable source/API/hash records, role requirements and exact factory snapshots.
2. Add a paused Lua editor with starter programs, saved-version loading, bounded isolated checks, compatibility preview and explicit atomic application. Preserve manual orders on failed edits and restore the prior pause state on close.
3. Verify migration/corruption handling, both-faction application and factory inheritance, then exercise real UI input and 720p rendering.
4. Follow with visual-rule authoring and a battle test arena/trace. A sample-data check does not establish battlefield behavior.

### Visual authoring implementation stages

1. Define a bounded ordered-rule document, deterministic Lua compiler, named states, retreat/recovery parameters and inferred capability requirements. Preserve schema-1/2 records when adding visual versions.
2. Add rule cards, starter behaviors, priority reordering, generated-code preview and explicit copying to Custom Lua. Reuse the verified pause/library/application flow; keep visual and Lua drafts separate.
3. Test actual compiled behavior, malformed documents, version/compiler integrity, both-faction application/factory/manual authority and the no-code mouse/keyboard flow at 720p. Then implement the separate battlefield arena.

### Battlefield arena implementation stages

1. Add an isolated real-match runner with deterministic scenario events, bounded evaluation/position traces and explicit expected outcomes. Keep the live match paused and preserve drafts/orders across launch, cancellation and faults.
2. Expose scenario/role selection, playback pause/restart, outcome details and return-to-editor feedback for both authoring modes.
3. Regress positive and intentionally failing programs, both factions, manual authority, missing/destroyed targets, blocked navigation and real 720p launch/return flows. Record export/platform limitations.

### First Orders implementation stages

1. Add a campaign entry/briefing and mission settings, an authored relay training map, reusable capture/contest/local-vision rules and mission progression. Preserve ordinary skirmish behavior.
2. Deliver lab/program/relay guidance, bounded objective-directed waves, explicit Command defeat and victory, replay/campaign return and optional saved-threshold reuse badge. Built-in presets alone must complete the mission.
3. Verify actual construction/program/capture flow, contests/recapture/pause/local vision, both result paths, mission progress persistence and real menu/HUD input at 720p. Keep full game-state save/load as the following stage.

### Full game-state save/load implementation stages

1. Define a bounded, versioned, inert save format and capture at a paused simulation boundary. Inventory every authoritative state owner: settings/map, players/research, units/construction/cargo/cooldowns, paid production jobs, orders/actions, exact programs/assignments/runtime/contact handles, squads, objectives, projectiles and explored fog. Verify immutable round trips and corrupt/unsupported data handling before exposing load controls.
2. Restore through a validated scene-loading transaction, rebuilding navigation/observation and stable entity references without charging costs, advancing timers, resuming manual automation or replacing saved programs from the library. Preserve source saves on failure. Regress live movement/combat/harvesting/construction/production, missing targets, Lua state/faults, campaign progression and pause.
3. Add quicksave/load, manual slots and three rotating campaign-checkpoint autosaves, then verify actual menu input, 720p feedback, failed-load recovery and repeated save/load cycles. A completion/badge file alone does not satisfy this stage.

## Stage 4 — Optional LLM assistance

Implement explicit generate/revise requests, configurable provider, platform credential storage, draft validation/testing and explicit Apply. Failures retain the current working program. No real-time dependency on a provider.

### LLM assistance implementation stages

1. Build bounded provider configuration, platform credential storage, explicit context packaging and cancellable one-request adapters. Start with OpenAI Responses and an explicitly selected compatible Chat Completions endpoint; never silently retry/fallback paid requests. Verify exact wire payloads, privacy, timeout/cancel/error mapping and credentials with isolated fixtures.
2. Add Create/Revise/Explain alongside authoring, context disclosure/trace opt-in, visible request limits, separate returned summary/code/parameters and explicit draft import. Preserve drafts/orders on every failure and keep presets/visual tools offline. Generated custom Lua must use the same checks, arena and explicit Save/Apply flow.
3. Verify real UI/input, invalid and delayed provider output, disconnect/cancel/reopen, safe key persistence and both-faction authority. Test one live request only with an available authorized provider credential; record any unavailable live-provider/platform acceptance separately. Keep provider settings/secrets and in-flight responses out of saves/program exports.

## Stage 5 — Faction and map depth

Deliver faction signatures/modes, Desert route revision and Alpine layout, fair AI observation and counterplay. Validate economy, chip timing and traversal time through repeated scenarios. Add the third faction after the two-faction programming loop passes its acceptance tests.

### Faction combat implementation stages

1. Differentiate mobile anti-air: Bastion shared-reload ground/short-range AA profiles; Helix player-selected Precision/Interception with a two-second firing lock. Integrate readable unit badges, mixed-selection controls, target legality for manual/preset/Lua orders, observed-air AI decisions and exact save continuity. Verify both factions, transition/pause/death, reload preservation, range/armor, archived partial switches and actual 720p input.
2. Add visible precision preparation and Prism deployment/cancellation, then explicit Anchor/Precision coordination abilities with bounded participants and cooldowns. Verify control precedence, visibility, saved state and practical readability before accepting tuning.
3. Run equal-budget encounters, retreat/repair counterplay and map-dependent engagement scenarios; revise unclear mechanics and record actual faction values. Continue Desert revision and larger content/performance milestones.

Encounter tuning steps: (a) run actual-unit engagements with explicit material/electronics spending and unspent budget, mirrored battlefield sides, first-hit/first-loss timing and survivors; (b) investigate specialist-role failures with range, deployment and support controls before adjusting catalog values; (c) retain meaningful counterplay, verify affected combat/program/save behavior and record both observations and untested strategic advantages. Budget ceilings do not make differently spent armies equal in value, and probes do not establish PvP balance.

Signature delivery steps: (a) bounded activation cohorts and per-unit state, no movement/program replacement, Anchor's 6 m sector and one-use Precision preparation; (b) selection controls, sector input/cancel, visible state and exact archive continuity; (c) actual damage/timing, regroup/cooldown, pause/retreat/target loss, both-faction rendered input and shared regressions. An activation cohort is independent of persistent named squads: new disjoint groups may activate, but any participant retains its own cooldown when regrouped. Anchor may wait for units to enter its sector; movement after anchoring breaks the benefit and requires a new activation. Precision is consumed by the first eligible preparation, including an already charging shot, and is not refunded by cancellation.

### Desert Frontier revision stages

1. Replace the menu's compact prototype with an independently versioned 128 × 96 desert battlefield: broad central staging ground, north/south flanks, paired home fields and exposed outer electronics. Preserve the original map scene for existing saves and art demos.
2. Integrate preview/catalog, readable terrain routes and bounded low escarpments compatible with current flight height. Verify symmetric resource opportunity, build space, legal sight blockers and both Standard/Advanced starts.
3. Exercise actual multi-unit crossing and retreat on separate routes, both-faction harvesting, archive restoration and 720p menu/gameplay. Record traversal measurements and distinguish these checks from repeated full-match pacing acceptance.

### Alpine Relay implementation stages

1. Author a snow/rock battlefield with two separated wide passes, a longer rear bypass, exposed expansions, paired safe home fields and readable pre-match terrain preview. Measure basic-tank traversal rather than choosing dimensions only by appearance.
2. Integrate optional infantry-captured vision relays, fair AI objective assignments, actual terrain/air paths, building placement and exact objective save/restore. Keep Command destruction as the skirmish win condition.
3. Verify both-faction Standard/Advanced starts, group transit and air shortcuts, harvesting, capture/contest/recapture, archived objective state and actual 720p map selection/gameplay. Desert revision and faction combat signatures remain subsequent work.

## Stage 6 — Campaign and product completion

Build the remaining campaign missions, industrial/coastal maps, accessibility/settings, audio/VFX/presentation and native-platform performance gates. Naval combat, faction variants and PvP remain later decision gates, not dependencies of the initial PvE release.

### Settings and accessibility implementation stages

1. Extend existing persisted options with bounded master/voice volume, camera pan/zoom, edge scrolling and reduced flashes. Keep old screen/mouse preferences readable; apply sound routing and camera/effects behavior in live matches.
2. Add one keyboard-accessible main-menu/battle settings panel with live preview, explicit Save, Cancel rollback, defaults, write-error feedback and voice sample. Freeze all battle/camera inputs while open and preserve prior pause/focus on close.
3. Verify real persistence/corrupt values/write failure, audio bus gain/mute, camera behavior and battle authority; inspect 720p mouse/keyboard flows in both entry points. Key remapping, scalable HUD, broader accessibility and audio production remain later work.

### Split Signal implementation stages

1. Add the third operation's three-relay map, advanced starting force, cumulative two-relay objective, finite warned counterattacks, optional all-relay control and clear battle UI.
2. Expose both available operations through campaign selection, preserve legacy completion, and extend validated archives/checkpoints to retain all relay, timer and response state.
3. Verify real traversal/capture and preset-only victory, contest/recapture/pause/defeat, response entry safety, file restoration, progress migration and actual 720p menu/battle input. Remaining operations and full-campaign pacing stay open.

### Large-battle performance implementation stages — deferred

1. Re-run the current 200-unit, 200-Lua-VM, 80-structure workload with profiling. Preserve behavioral assertions and separate fixed-step throughput from normal-clock frame delivery.
2. Optimize the measured bottleneck without weakening observation, targeting, program limits, movement or presentation requirements. After observation hints, compare isolated cosmetic-update and idle-production ablations and engine process/physics monitors under normal-clock scheduling; diagnostic switches must never be shipping quality reductions. Add regressions for any cache/invalidation or authority changes.
3. Compare the same workload before/after, run relevant gameplay regressions and a normal-clock rendered check, and document hardware, frame distribution, exercised workload and remaining performance limits.

### Resource-field economy implementation stages

1. Preserve resource type and a bounded local field assignment across trips. Add two reservable work slots per deposit, readable waiting states and safe partial-cargo return. Stop for player reassignment after local depletion or loss of a drop-off; do not silently switch type or select a distant field.
2. Integrate engineer status/selection, queued-order handoff and snapshot-version migration, including waiting workers with no live target. Persist assignment and wait reason; reconstruct transient reservations from active actions.
3. Verify actual competing workers, depletion/partial cargo, cancellation/death/pause, HQ loss/recovery, both factions and archive continuity; review native 720p status and continue full-match gameplay acceptance. No performance profiling in this stage.

### Economy recovery and expansion guidance stages

1. Derive recovery advice from own units, funds and paid queues: lost HQ, absent engineers, interrupted delivery, local depletion and overcrowded fields. Keep spending, scouting and reassignment explicit player actions.
2. Make build recommendations respect affordability and existing foundations/jobs; select a suitable available engineer or refundable producer. Explain unrecoverable economy states without offering impossible actions. Preserve pause/save and campaign separation.
3. Verify both factions, actual paid refund → engineer → harvest and HQ rebuild/countdown recovery, paused archive continuity and native 720p selection/refund/reassignment. Document results; keep performance optimization deferred.

### Supply Line campaign opening stages

1. Add a conventional convoy mission, three repairable mission-only trucks, an authored route with defended checkpoints and finite warned responses. Keep convoy movement/hold and escort/repair orders under player control; two extractions win and two truck losses defeat.
2. Integrate Campaign operation 01, objective/route/convoy UI, completion reward for First Orders, validated mission saves and rotating checkpoints. Preserve old progress and save behavior.
3. Verify real traversal/combat/repair and extraction, loss/contestation/pause/restart, difficulty budgets, response entry safety, exact archive continuation and native 720p menus/orders. Record observed pacing separately from the 10–15 minute design target.

### Air Corridor implementation stages

1. Author an industrial-quarry map with genuinely different air and ground routes, two destructible AA sites, a conventional/programmable combined-arms starting force and a mission-only evacuation VTOL. Ground troops clear the sites; players explicitly launch and escort flights while finite warned ground/air responses contest the route.
2. Deliver operation 04 briefing and compact objective/flight/selection UI, pause/restart/results, previous network-badge starting support and optional three-flight electronics support for operation 05. Extend strict mission archives and completion migration; preserve player command authority and ordinary skirmish rosters.
3. Verify actual ground/air traversal, targeting/service, real combat and extraction, launch gates/losses/responses, saved active flights and timers, progress migration, and native 720p controls/layout. Record achieved pacing and unresolved art/balance gates separately; do not resume performance optimization.

### Broken Foundry implementation stages

1. Author an urban industrial map with obstructed sightlines, two destructible production nodes using finite paid queues, exposed repair support and bounded local defenders.
2. Gate infantry capture behind both disabled nodes. Add a finite warned final response, briefing/objective/control UI, previous air-support funds and the finale-route reward. Preserve exact mission state and paid production through archives.
3. Verify real traversal/combat/capture, artillery coverage, production cancellation and budgets, repair/pursuit rules, pause/archive/migration and native 720p controls. Keep novice/difficulty acceptance and final art separate; performance remains deferred.

### Environment richness follow-up

1. Review the playable maps at the normal RTS camera scale. Give each region a clear identity and a small set of authored landmarks, distinguish travel routes from backdrops, and map the existing navigation/sight contracts before replacing blockout geometry.
2. Build a coherent environment kit and apply it to the authored maps: varied ground materials and transitions, more natural terrain/elevation, industrial structures and infrastructure, restrained small props, lighting/atmosphere and signs of use or conflict. Avoid uniform repeated rocks and empty flat expanses. Keep combat silhouettes and objective locations legible.
3. Recheck actual ground/air routes, construction, resource access, sight/fire obstruction and objective approaches after art changes. Review native 720p and larger-camera views, with ordinary fog and active combat. Environment quality is separate from the deferred performance-optimization stage.

## Keyboard control accessibility stages

1. Define a bounded, versioned preference for all battlefield keyboard actions, including camera, selection/queues, groups, pause, attack-move and quicksave/load. Validate conflicting/reserved keys and migrate legacy options to defaults without touching battle archives.
2. Add a keyboard-accessible Controls tab with key capture, explicit collision feedback, per-action/default reset, live preview and existing Save/Cancel rollback. Keep battle input frozen while editing. Update visible command hints and use exact modifier matching.
3. Verify actual remapped commands, group/queue behavior, held-key release, pause/menu/authoring isolation, persistence/corrupt preferences and failed-save recovery. Exercise main-menu and live-battle settings at 720p. Scalable HUD/subtitles and audio remain separate acceptance work.

## Speech accessibility stages

1. Add canonical text for every existing spoken line and a shared human speech channel with bounded priority, repeat suppression and coherent audio/caption lifetimes. Distinguish actual weapon hits from HP initialization, suppress restoration events, and protect battle results.
2. Add persisted subtitle visibility/size controls with preview and rollback, plus a mouse-transparent caption area that fits the 720p battle HUD. Keep speech/captions coherent through tactical pause, editing and scene transitions.
3. Verify both factions, continuous damage, casualty bursts, queue priority, production/selection, fog ownership, restoration, mute, pause, settings failure/rollback and rendered large-text campaign/result/selection layouts. Native input remains a separate pending acceptance gate if computer use is still unavailable.

## Combat sound stages

1. Create original reproducible weapon, impact and destruction cues with measured levels and an audition artifact. Map sounds to weapon family/faction and destruction scale.
2. Route actual combat events through bounded screen-relative spatial playback, current-observation/offscreen guards, a separate Effects volume and protected mix levels. Keep tactical pause, result tails, settings and restoration coherent.
3. Verify real shots/hits/deaths for both factions, stereo positioning and audible bus output, burst saturation, visibility/pause/load isolation, persisted volume/preview rollback, and a rendered combat recording. This is sound delivery work; frame-rate optimization stays deferred.

## Environmental audio stages

1. Completed: seven original reproducible desert/alpine/industrial/coastal and neutral traffic/harbor loops, a finite settings sample and audition artifacts. All eight WAVs reproduce byte-for-byte; loop joins and peak/RMS bounds pass.
2. Completed: match-owned beds, at most four camera-relative currently observed neutral sources, speech/combat ducking, independent persisted Ambience volume and Play/Stop sample. Simulation RNG, tactical/modal pause, mute, paused load and scene cleanup remain intact.
3. Completed for audio verification: both factions/four skirmish maps, all six actual campaign scenes, oversubscribed local audio and sixteen shared suites pass. Normal-clock output/stereo/loop/pause/mute/combat/speech and 720p/150% controls pass. The campaign smoke check repairs Split Signal’s broken Alpine inheritance; mission rules/routes/archives/preset victory pass. Visual review consolidates relay labels and protects HUD layering. Repeated synthetic campaign mouse-input misses remain unresolved despite a passing isolated menu trace; final campaign-input acceptance is not claimed. Subjective mixing and platform/release work remain open; performance stays deferred.

## Navigable battle alert stages

1. Add bounded human-only alert history and stable grouping for actual incoming fire/losses, idle engineers, depleted/stranded harvesters, low power and genuinely blocked paid production. Derive economy conditions from authoritative state, debounce transient inactivity and resolve conditions when recovered. Preserve locations before unit exit and suppress archive reconstruction.
2. Add a compact keyboard-accessible Alerts control and scrollable history with unread counts, clear resolved history and explicit location/unit navigation. Preserve manual/program orders, tactical pause and modal input authority; keep campaign, minimap, captions and selection panels usable at 720p/900p.
3. Verify actual both-faction combat/economy/production transitions, grouping/resolution/bounds, paused navigation, hidden-enemy isolation and save/load reconstruction. Exercise rendered mouse/keyboard, adverse modal flows and campaign layouts. Record remaining full-match/accessibility/release gates; performance stays deferred.

## Interface scaling

1. Completed: bounded, persistent 100/125/150% interface sizes with live preview, defaults and rollback, using the existing 1920×1080 canvas.
2. Completed: settings, battle controls, selection, map targeting, alerts, captions, archives and program editors checked at each scale; arena voice startup and campaign marker layering repaired.
3. Completed for automated rendered scope: reviewed 720p/900p/1080p evidence, ran shared checks and recorded platform/accessibility limits.

## Desert environment follow-up

1. Completed: author an editable sandstone/freight-salvage kit and surrounding dune/canyon terrain using the existing desert concept. Preserve the four shelf footprints/heights, three ground routes, all field access and the original archive map identity.
2. Completed: integrate varied ground materials, worn roads/aprons, authored low ruins and boundary composition with readable lighting. Keep tall scenery outside the playable rectangle and all solid interior decoration inside existing blockers.
3. Completed for automated/rendered scope: verify imported geometry against the gameplay envelopes, both-faction routes/economy/construction/aircraft/archives and ordinary-fog/combat rendering. Review before/after imagery at the actual RTS camera.

## Alpine environment follow-up

1. Completed: build an editable glacial granite, conifer and abandoned communications-station kit from the established alpine setting. Preserve the six ridge envelopes, two passes, outer bypass, fields, capture locations and saved map identity.
2. Completed: compose snowy mountain surroundings, restrained vegetation, distinct station landmarks and connected plowed service routes. Replace the isolated paving blocks and broad repeating snow bands with coherent ground materials; improve relay text contrast on snow.
3. Completed for automated/rendered scope: verify imported bounds, actual ground/air movement, sight/fire, harvesting, construction, relay capture/contest/archive continuity and ordinary-fog combat at 720p and 900p. Review before/after captures and record remaining final-art limits.

## Repeated skirmish acceptance stages

1. Completed: instrument a paid commander across Bastion/Helix, Desert/Alpine and Standard/Advanced starts against Normal AI. Record first contact, chip/program timing, expansion, losses, repair, stalled travel and result. Retain unresolved outcomes and unsuccessful strategies as evidence.
2. Completed: investigate complete-match failures. Fix AI repair target eligibility/assignment, unreachable large-building repair and repeated attack-move arrival at occupied destinations, with actual movement, repair, program, queue and archive regressions. Restore missing facility service details and verify 720p presentation. Distinguish weak commander choices from game bugs; no tuning to force victories.
3. Completed for execution/evidence: all 24 matches reach a result, a normal-clock match completes with reviewed 720p captures, and the report preserves opening losses, short pacing and a reproducible crowd/boundary avoidance failure. The crowded-base follow-up below addresses that retained movement case; novice/balance and performance acceptance remain open. Performance work stays deferred.

## Crowded-base movement stages

1. Completed: the retained archive reproduces an engineer held at a building boundary despite an intact route. The regression retains buildings, neighbors and existing combat, checks normal speed and pause, and separately exercises both-faction opposing harvest traffic and disk restoration.
2. Completed: ground movement reports its actual applied velocity back to avoidance when navigation projection changes the calculated step. Unit radii, speeds, collision footprints, orders and save format are unchanged. Facing and passive-motion signals now follow actual displacement.
3. Completed for the retained failure: original archive and both-faction traffic/archive tests pass, as do shared navigation/army/combat/order/Lua/motion checks and normal-clock 720p rendering. Twelve complete-match follow-ups retain a separate unresolved empty-path stall, not a universal navigation pass. Performance optimization stays deferred.

## Empty-path traffic investigation stages

1. Completed: captured a live empty-path battle near the original location. Active callbacks plus a 15 cm partial route identify a sealed mesh island; isolated archive replay and removing/replacing the closing turret reproduce the cause.
2. Completed: AI building placement preserves two-sided navigation clearance between static footprints and starts its compact placement ring at 7 m. The archive-backed regression fails twice before the change and passes after; the engineer delivers electronics at normal speed across a paused disk reload. Existing closed layouts retain their recorded buildings.
3. Completed: shared AI/support/skirmish and prior crowd/archive regressions pass, as do normal-clock 720p spatial review and eight complete Normal-AI matches. Longest stationary travel is six seconds human / four AI. Fixed-policy Advanced losses and 6–9-minute matches leave strategy/pacing gates open; performance remains deferred.

## Strategy and battle-plan guidance stages

1. Completed: retained two four-match Advanced policy trials at seed 4110. The first revised economy-screen/repair pass wins three and loses one; the earlier early-commitment policy loses all four. Timing remains short, and these exploratory samples do not establish balance.
2. Completed: programming guidance no longer disappears at nine combatants; owned damage and observed threats drive defense/repair/scouting/opposition/rebuilding advice. Production shortcuts choose one usable producer. Rendered testing also exposed and fixed recursive menu rebuilding for mixed production selections.
3. Completed: both-faction state/fog/pause/archive, actual scaled input, mixed-building and world double-click checks pass, alongside economy/support/controls/orders/restoration and opening UI. Final policy repetition is one win/three losses; all twelve pilot/revised trials are retained. Pacing remains short and performance stays deferred.

## Guard-area coverage stages

1. Completed: both-faction reproduction fails before correction: a visible target 11 m away inside a 12 m Guard assignment receives no response.
2. Completed: built-in Guard acquisition covers its full sector from the current position, preserving observation, obstructions, domain, weapon range, manual authority and retreat. Other specialists retain their prior ranges; the tooltip describes the behavior.
3. Completed: both-faction movement/combat, opposite-edge and negative bounds, paused disk restoration, normal-clock scaled rendering and shared program/specialist/squad/order checks pass. Four Advanced follow-up matches all finish in victory; 6–8-minute pacing and balance remain unresolved.

## Observed-threat AI defense stages

1. Completed: both-faction ground-raid reproduction fails before the response planner; a second reproduction exposes unsupported air threats consuming a coordination slot.
2. Completed: observed threats drive suitable ground/air responses; supported defense groups scale by difficulty, preserve matching orders and leave other troops available for waves/relays. New defense/assault orders use the shared manual-order path; existing saves remain compatible.
3. Completed: both-faction visibility, unarmed/unsupported contacts, actual interception, group caps, independent waves/relays, partial-switch archives, scaled rendering and shared AI/support/mode/save checks pass. Sixteen complete trials retain an initial defeat and final eight victories; ordinary pacing and broader strategy remain open.

## Observed-composition production stages

1. Completed: both-faction reproduction of visible air threats not changing production/build priorities and non-vehicle jobs advancing the vehicle roster.
2. Completed: bounded faction-appropriate counters from current observation and owned/queued composition, preserving prerequisites, power, costs and construction reserves.
3. Completed: hidden/unarmed contacts, queued quotas, multiple factories, actual construction/counter interception, pause/archive and rendered checks pass. Fourteen complete outcomes are retained; final eight finish three wins/five losses, with ground-wave/scout diversion and one engineer delay captured for follow-up.

## Strategic offensive objective stages

1. Completed: both captured scout-driven ground-wave diversions fail before the fix; continued slow-exit traces distinguish temporary traffic/repath observations from a disconnected route.
2. Completed: waves prioritize observed enemy economic targets, retain the known enemy-base fallback, and preserve defense/relay allocation and scheduled-wave timing.
3. Completed: both-faction priorities/visibility/ownership/timing, actual archived departures, paused disk restoration, engineer delivery, four additional departure replays, rendered review and shared suites pass. Eight complete trials finish four wins/four losses, without fifteen-second stationary episodes.

## Economy guidance under pressure stages

1. Completed: both factions reproduce depletion masking a visible raid and missing resource income after factory unlock.
2. Completed: immediate defense precedes field reassignment; own-assignment supply advice uses faction armor/aircraft costs and fitted-chip fees, selecting idle or available gatherers.
3. Completed: both-faction paid collection/production, paused archives, shared guidance/recovery checks and normal-clock 720p/150% selection/render review pass. Broader mixed-force throughput and escorted expansion strategies remain subsequent work.

## Protected AI expansion stages

1. Completed: both factions reproduce unguarded remote assignment and missing expansion guards; observed-threat/cargo contracts identify the withdrawal requirements.
2. Completed: a bounded ground guard precedes remote harvesting and stays during cargo trips; observed danger triggers withdrawal to a safe HQ and delivery before reassignment. Existing construction, costs and ordinary action archives remain.
3. Completed: both factions/Desert/Alpine pass actual guard travel, finite-stock return, live infantry raids and resumed income; threat/defense/wave priority, paused archives, nine shared suites, normal-clock 720p/150% review and eight complete matches pass.

## Mixed-force economy stages

1. Completed: reproduced first-wing budget theft and inspected fixed gatherer assignments under one-resource shortages.
2. Completed: prioritize recovery/counters, reserve future mixed-force jobs, account for paid quotas/foundations, and exclude unavailable technology.
3. Completed: derive resource splits from construction/production deficits; queue active handoffs at cargo delivery, preserve retreat/build authority, and share two guards across remote resource approaches.
4. Completed: both-faction finite income, paid mixed completion, queue/archive boundaries, guarded dual-resource returns, strengthened raids, eleven shared suites, six normal-clock rendered captures and eight complete matches pass.

## AI recovery and recommitment stages

1. Completed: original five-role/two-faction reproduction fails ten recovery expectations despite matching facilities.
2. Completed: below-30% military units use reachable safe matching service; established recovery stays protected until 80%, with alternate providers and bounded blocked-travel retry.
3. Completed: both factions pass real travel/healing, renewed combat/support/recon duties, travel/healing/blocked disk archives, provider loss/danger, manual replacement and separate Alpine relay contracts.
4. Completed: fifteen shared suites, four normal-clock 720p/150% captures, recovery-metric contracts, eight complete matches and final evidence audit. Two ordinary-movement stalls remain open; four additional full-match reproductions did not repeat them, and all outcomes are retained.

## Intermittent movement reliability stages

1. Completed diagnostic scope: four more full matches, recorded single-unit approaches and 32 final local crowd/counterflow trials do not reproduce the original delays. Capture now includes nearby agents/avoidance state and exact saved unit ids; explicit replay, real disk restoration and adverse arguments pass. All interim outcomes are retained in [the investigation](playtests/2026-10-04/MOVEMENT_DIAGNOSTICS.md).
2. Completed for the captured Alpine resource approach: an engineer 0.023 m outside work range was receiving almost-zero avoidance velocity amid stationary neighbors. After two seconds without useful progress, static-target approaches can choose another reachable, unoccupied work face. The original three failures now pass actual collection, finite stock, speed and footprint checks; mid-detour disk restoration, manual replacement, both-faction delivery/construction and occupied-target removal pass. Earlier uncaptured delays remain separate open cases.
3. Completed bounded verification: twelve shared crowded/resource/command/archive/AI suites and normal-clock 720p/150% replay pass. [Eight follow-up trials](playtests/2026-10-04/CONTACT_APPROACH.md) retain seven results and one unresolved thirty-minute match; no fifteen-second movement capture or task/order violation occurs. The unresolved match keeps complete-match/pacing acceptance open. Earlier uncaptured episodes remain separate; universal movement reliability is not established.

## Global AI coordination stages

1. Completed: both factions assigned four simultaneous strategic goals at every difficulty; six original budget checks fail.
2. Completed: maintain one shared combat-task roster with stable core membership, observed-threat preemption, bounded ordinary-task rotation, cargo-preserving guard retirement and attached scouting/repair support.
3. Completed: preserve the task roster and scheduling state in battle archives; verify both factions, all difficulties, task release/replacement, recovery authority and actual field returns/capture/combat.
4. Completed: 21 final headless suites, four reviewed rendered captures and eight complete matches pass task/order checks across 7,998 samples. Five human-policy wins/three losses span 4:41.4–13:34.3. A captured 16.5-second human engineer delay and crowded/isolated replays remain an open movement issue; pacing acceptance is not achieved.

## Sustained recovery and pacing investigation stages

1. Completed bounded diagnosis: three instrumented Alpine repetitions do not reproduce the thirty-minute outcome. Controlled tests expose reference infantry-service, preset and Lua/visual recovery failures. A later crowd failure exposes a 4.5 m arrival cutoff inside the actual 5 m healing area; the deterministic boundary test fails in both factions. Preserve all outcomes; the original unresolved match cause remains open.
2. Completed: built-in presets and authored safe-point movement share the existing 5 m service range for matching friendly facilities. Authored state/source/return rules, explicit ground points, unavailable providers, manual authority and partial-healing disk restoration remain intact. All six programmable roles, both factions and three final eight-tank/two-slot trials pass; the reference commander selects role-compatible facilities.
3. Completed bounded verification: 19 shared suites pass; eight final trials finish with three victories and five defeats. Authored programs complete nine recovery returns and lose sixteen recovering units; no authored Blocked state is recorded. The Helix Standard Desert commander defends without assault and loses at 25:42. Broader pacing remains open. Both final normal-clock rendered suites pass; all twelve 720p/150% captures are reviewed.

## Campaign control stability stages

1. Complete: trace button delivery and bounds; reproduce notice-driven movement separately from native pointer interference.
2. Complete: reserve bounded notice space, preserve assignment priority, retain scrollable long messages and clear the actual minimap on all six campaign maps at 720p.
3. Complete: held-click regression, four shared save/program/input suites, thirty slow injected clicks and two full campaign navigation/archive/replay runs pass; native-device/platform acceptance remains separate.

## Campaign scale and subtitle clearance stages

1. Complete: reproduce fixed-width caption overlap across eight mission/scale combinations, plus the oversized Horizon unit panel.
2. Complete: derive captions from live HUD bounds; bound selection-panel height with wheel/keyboard scrolling and focus visibility.
3. Complete: 252 campaign caption checks, 216 skirmish layout combinations, scaled navigation/orders, 720p/900p/1080p captures, the existing interface workflow and eight shared suites pass.

## Authored defense and pacing investigation stages

1. Complete: separate reference-commander assault gates from authored defense; reproduce lost crowded firing and out-of-sector engagement in both starter modes.
2. Complete: share bounded area defense with new Lua/visual guard starters, preserve legacy source and authority, clarify preset drafts and show active guard boundaries.
3. Complete: twenty shared checks and four rendered workflows pass; eighteen captures are reviewed. Five full outcomes and readiness samples are retained without treating policy win rates as balance acceptance.

## Mixed-force readiness investigation stages

1. Complete: four Advanced Desert matches measure withheld affordable tanks and compare a ground-count-before-air policy in both factions. All four end in defeat; larger ground forces still wait for home pressure under the reference commander's assault gates. No cost or difficulty tuning follows from these outcomes.
2. Complete: preserve role information for unaffordable/locked roster choices, replace generic Helix descriptions, and expose total/missing funds, prerequisites and power-aware production time. Resource costs, player authority and fair observation remain intact.
3. Complete: eight suites, real hover/keyboard purchase/mouse refund workflows, ten reviewed 720p captures, import and static checks pass. Paid-job archives and capacity gates hold. Four failed strategies remain retained; mixed-force balance and pacing are unaccepted.

## Mixed-selection control stages

1. Complete: both factions reproduce the missing information. Mixed selection now has compact type counts, stable eight-unit health pages and type/individual/damaged subset selection with the remappable removal modifier.
2. Complete: both factions, all 17 types, 140 selected units, mission vehicles, mouse/Enter/remapping, health updates and actual disk restoration pass. Fixed release fallthrough during filtering and held-button death, including intervening keyboard input; commands, squads, paid jobs, camera and tactical pause are preserved.
3. Complete: nine headless suites and the rendered 720p/150% workflow pass, with seven reviewed captures and import/static checks. Physical-device/screen-reader, balance/novice, content and release acceptance remain open; performance stays deferred.

## Explicit direct-command stages

1. Complete: reproduced missing Move/Attack target controls, added distinct M/T/F targeting and selection-panel buttons, and migrated valid older custom controls without replacing their bindings.
2. Complete: both factions pass command semantics, observation/capability, queue/manual authority, cancellation, placement/modal input, pauses and disk restoration. Actual mouse/keyboard/held-button death workflows cover 720p/150% and campaign layouts.
3. Complete: shared command, controls, selection and campaign checks pass. The shared alert check also exposed a crowded courier; sustained route-progress recovery preserves the existing captured detour and verifies conserved cargo. Evidence, initial failures and acceptance limits are retained in the direct-command report.

## Mixed-force operation stages

1. Complete: separated the prior-home-attack gate, staged routes, early air investment and guard coverage in retained full matches. Corrected the reference commander's idle-action test, which stranded reinforcements and completed waypoint units; actual two-leg advance and recovery regressions pass.
2. Complete: the longer responsive-guard trial captured a seventeen-second infantry blockage at an occupied barracks endpoint. Added bounded plain-Move arrival beside a settled friendly unit, with original six-failure reproduction, enemy/distance guards, conserved movement and queued paused-disk handoff.
3. Complete: twelve shared suites, the normal-clock 720p/150% rendered replay, two full responsive matches and final import/static checks pass. Eighteen study matches are retained across policy/runtime revisions; a separate authored Blocked archive remains a follow-up. Strategy, wider-map/difficulty, novice and release acceptance remain open.

## Blocked assignment clarity stages

1. Complete: replay the retained tank archive and distinguish an inaccessible factory-overlapped assignment from a movement failure.
2. Complete: actionable owned-structure obstruction feedback and saved Lua guard-intent boundaries preserve the existing Blocked/arrival rules.
3. Complete: original capture, both-faction three-mode recovery/authority, disk compatibility, nine shared suites and normal-clock 720p/150% mouse recovery pass. See [blocked assignments](playtests/2026-10-04/BLOCKED_ASSIGNMENTS.md).

## Coastal environment follow-up

1. Complete: captured the current harbor at playable camera scales and preserved shoreline/navigation, two corridors, structures, fields and clearance contracts.
2. Complete: six editable coastal assets, 28 exterior placements, continuous sea/relief, connected port infrastructure, weathered ground and replacement pine stands retain route envelopes.
3. Complete for automated/rendered scope: imported bounds/fog, both-faction two-lane transit/retreat, aircraft, economy, archives and shared suites pass. Ten 720p/900p captures include normal-clock combat and hidden enemy fog. See [coastal environment verification](playtests/2026-10-04/COASTAL_ENVIRONMENT.md).

## Ownership readability stages

1. Reproduce the color-only battlefield/minimap ambiguity with matching faction and player colors. Define consistent own/opponent/resource symbols and clear ownership text without exposing unseen units.
2. Add compact world symbols, matching minimap shapes and a persisted display preference. Keep world markers behind controls and mouse-transparent; inspect all UI scales, selected/damaged units, aircraft and buildings.
3. Verify current fog, death, neutral units, pause, visibility modes and exact archive restoration. Exercise real scaled settings preview/rollback and selection/commands, then run shared HUD, settings, combat and save checks.

## Industrial and Coastal contested-match stages

1. Complete: both factions on Industrial Crossroads and Coastal Foundry with Standard and Advanced starts against Normal AI. Eight initial matches retain paid economy, programs, contact/unlock, expansion, casualties, repair, coordination and stationary travel.
2. Complete for the reproduced commander errors: exact Coastal captures expose an inaccessible HQ-center retreat fallback; the next cohort captures a repair robot later occupying a clear fallback. The reference commander now chooses stable reachable waiting points, recognizes new construction/matching facilities, and explicitly reassigns/resumes occupied blocked retreats. Shipping gameplay rules remain unchanged.
3. Complete for bounded verification: 24 terminal matches across three separately fingerprinted commander revisions, three focused regression suites and four static/import checks. Final outcomes are two wins/six losses, 5:34.7–12:52.2, with no AI coordination violations in 8,448 samples. Guard blockage replays recover after Resume, but their transient causes and a 9.5-second movement delay remain open. These are not three repetitions of an identical final policy or novice/balance acceptance. Performance stays deferred.

## Guard movement diagnosis stages

1. Complete: five instrumented original-runtime Coastal matches, seven pre-block captures, requested/avoidance velocity, valid navigation paths and live-traffic replay identify guards pushing toward an occupied center.
2. Complete for that cause: shared ground guard arrival forms up beside a stationary center ally or settled same-area guard, with original circle, clear neighbor connection, assignment validity and manual authority preserved.
3. Complete for bounded verification: seven captures, both-faction preset/Lua/visual groups, adverse limits, disk archives, seventeen shared suites and twelve normal-clock rendered captures pass. Four full matches finish but retain a different building-corner Blocked guard and three unassigned AI attack-order samples. Next: capture the AI membership violation live and replay the retained corner traffic. General congestion and broader acceptance remain open; performance stays deferred.

## AI task handoff and corner traffic stages

1. Complete for diagnosis so far: six instrumented original-runtime matches do not repeat the older membership failure. A fresh two-faction coordinator fixture instead demonstrates a concrete arrived-regroup handoff defect. The exact Coastal corner archive reproduces three times with live traffic.
2. Complete for the handoff: retire obsolete attack-move at regroup arrival; preserve distant approach, repeated idle/approach orders, active missions, recovery and prepared fire. Corner navigation remains open: directional steering probes fail, while removing the nearby repair robot releases the guard; removing infantry alone does not.
3. Complete for bounded handoff verification: both factions/all three difficulties, disk archives, nine shared suites, two normal-clock rendered reviews and four terminal Coastal Advanced matches. The original match's unassigned orders are not retrospectively explained. Next: collision-aware corner yielding/alternate routing, plus further live membership captures if the condition recurs. Broader acceptance and performance gates remain open; optimization stays deferred.

## Corner recovery stages

1. Complete for diagnosis: the original movement code still blocks in all three exact captures and the mid-recovery disk replay under the final regression. A navigation bake can finish before its building footprints are registered and published; contact-only clipping can also pin units at a boundary.
2. Complete: arrival decisions run before the unchanged trip timeout; bounded terrain-aware sidesteps, side-route preference with local clearance, contact sliding, shared occupied-endpoint yielding, and explicit obstacle/region/map readiness before archive restoration. Saved assignment, position, clock and no-progress timer retain authority.
3. Complete for bounded verification: 31 shared suites, original/fresh corner and disk/authority cases, six arrival-at-timeout cases, nine normal-clock rendered captures and four final full matches pass their specified checks. Next: the captured Industrial AI plain-Move blockage, reproduced for thirty seconds beside its lab. General congestion and broader gameplay acceptance remain open; performance stays deferred.

## Crowded route-end stages

1. Complete: the original tank has only 0.85 m of remaining path, but its tiny intermediate bend prevents the old final-index completion check. The final regression still fails seventeen assertions with the archived old movement code.
2. Complete: bound arrival by actual remaining travel and preserve crowded-arrival observations in new archives. Original/fresh faction, manual queue, paused disk, corrupt/legacy archive and nearby-but-long-detour tests pass; enemy/moving/air/distant/empty endpoints retain movement.
3. Verification recorded: four normal-clock spectator captures, four terminal Advanced matches with 3,451 valid coordination samples, and 32 passing shared suites. One CrowdBoundary archived engineer misses its fifteen-second cargo deadline; instrumented before/after follow-up remains in the report. Keep this intermittent failure, general balance/pacing, content and release acceptance open; performance remains deferred.

## Harvesting delay and Standard pacing stages

1. Investigated: twelve original harvesting replays and sixteen neighbor perturbations did not reproduce the deadline miss. Keep it open. Standard Coastal baselines include a thirty-minute unresolved match and an early defeat; Advanced outcomes do not establish Standard pacing.
2. Implemented: missing-service guidance covers costs, prerequisites, foundations and matching providers; actual healing/archives/manual authority pass. Reference-commander replacements restore electronics assignments and pay for depot construction. Dedicated checks retain the original four/five/six-worker opening and avoid taking electronics workers for construction.
3. Verification recorded: sixteen valid headless suites, both native mouse/keyboard workflows and twenty-four reviewed 720p/150% captures pass. Ten Standard matches across retained commander revisions include the original thirty-minute stall and early defeats; the final pair is a Bastion victory and a Helix loss before assault. General pacing, the intermittent harvesting deadline, novice/content/release gates and deferred performance remain open.

## Conventional opening and retrofit stages

1. Inspect the retained early Helix defeat and preserve the existing guidance/commander before changing them. Verify that ordinary armor is available before the lab and add both-faction regressions for the missing conventional-to-chip path.
2. Make the opening advice cover conventional armor and the paid queue, then make chip guidance select a surviving compatible vehicle for retrofit. Exercise real costs, cancel/refund, production, manual defense, installation and programming without changing combat values or technology rules.
3. Verify shared gameplay/archive checks and normal-clock 720p controls. Compare complete Standard Coastal trials with the retained lab-first policy, recording early defense, chip timing, casualties and outcomes without treating a small sample as balance acceptance. Keep the intermittent harvesting deadline and broader content/novice/release work open; performance remains deferred.

## Classic RTS technology stages — user request 2026-10-04

1. Add paid, timed lab research for two weapon and armor levels, field-service efficiency and faction doctrine improvements. Keep one shared research project active at a time, including Coordination; preserve actual costs, prerequisites, power slowdown, cancellation/refund and lab-loss pause. Completed upgrades affect present/future eligible units and survive lab destruction.
2. Expose clear lab research choices and current unit upgrades. Weapon upgrades increase mobile combat damage; armor preserves health percentage while raising maximum HP; service improves actual healing; faction doctrine strengthens the existing unlocked Anchor/Precision ability. Save/restore all completed and partially paid research with bounded validation and compatibility for older archives. Give the opponent the same paid choices with economy/counter reserves.
3. Verify before/after combat and service, both factions, abilities, queues, ownership, low power, pause, destruction and archives. Exercise native 720p mouse/keyboard research controls and ordinary paid Standard matches. Update the design contract and record remaining balance/content/platform acceptance.

## Arena research fidelity stages — 2026-10-04

1. Reproduce the mismatch between researched battle units and fresh unupgraded arena units. Define a bounded capture of completed research only; preserve the isolated test world, free scenario fixtures and live battle pause/order authority.
2. Carry the captured faction/research setup through editor launch, scenario restarts and returned results. Offer the captured battle setup or an explicit unupgraded baseline, show the chosen benefits, and validate results against the launch setup. Apply upgrades before arena unit creation, without copying live payments or research timers.
3. Verify actual HP/damage/healing and unchanged live state, both factions, baseline switching/restarts, malformed setup/results and native 720p mouse/keyboard launch/return. Run the existing arena/authoring/technology checks and record limitations.

## Free Frontier implementation stages — 2026-10-04

1. Author the proposed third-faction roster as editable Blender models, articulated GLBs and matching icons. Use refurbished wheeled armor, mobile infantry, exposed machinery and modular field structures. Reimport and inspect all seventeen assets; preserve source geometry and document the provisional role/mechanic contract.
2. Integrate faction identity, finite wreck salvage, flexible retrofits and a distinct coordinated mobility ability across combat, economy, research, AI, programming, selection and validated archives. Preserve existing faction behavior and migrate old random-opponent preferences explicitly. Do not expose an incomplete faction in the main menu.
3. Verify paid Standard-start economy, actual combat/counters, salvage depletion and return, manual/program authority, ability/research effects, save/load, all maps and native 720p controls. Record balance/novice limits separately from functional evidence. Performance optimization remains deferred.

## Frontier complete-match follow-up — 2026-10-04

1. Audit the real AI/reference command paths for third-faction omissions, then reproduce stationary Maneuver waste and missing paid conventional chips. Keep costs canonical and existing orders authoritative.
2. Fix targeted AI procurement/movement choices, verify exact spending, lab-loss fallback, movement/retreat observation and unchanged earlier factions. Extend complete-match faction selection without mislabeling evidence.
3. Run Normal Standard paid Frontier matches against both other factions using the established reference policy. Record progression, actual purchases, losses, salvage/ability opportunities and terminal outcomes; do not tune unit statistics merely to make a script win. Retain remaining strategy/novice limits.

## Advanced-base harvesting traffic — 2026-10-05

1. Reproduce the original archived labor scenario and capture stalled engineers, current navigation paths, work reservations and surrounding traffic. Distinguish route geometry, movement recovery and field allocation before selecting a fix.
2. Correct the evidenced gameplay cause while preserving finite resources, cargo delivery, two work slots, collision/navigation boundaries and existing orders. Keep the original scenario and funding deadline as a regression; add focused adverse coverage where needed.
3. Verify the original scenario across factions, shared movement/harvesting/archive behavior and rendered traffic. Document measured income/travel and remaining strategy limits. Performance optimization remains deferred.

## Paid research and army progression — 2026-10-05

1. Inspect current Standard matches after the harvesting correction. Record paid research, army/building readiness, actual income, observed threats and research/production reserves for all relevant factions. Distinguish an AI scheduling defect from a reference commander that never requests technology.
2. Correct evidenced gameplay omissions without changing prices or granting resources. Extend the reference commander to exercise explicitly chosen paid research and faction abilities through ordinary controls, preserving manual tasks, visible information and exact spending. Compare ground-first and earlier-air strategies.
3. Verify any production change with its original failing scenario and shared economy/technology/authority checks. Complete repeated Standard matches with declared policies and native gameplay review; retain outcomes, progression timings, failures and remaining balance/novice limitations. Performance work stays deferred.

## Air defense guidance and screened aircraft opening — 2026-10-05

1. Inspect the early-air defeats and reproduce whether defensive guidance selects units that cannot attack observed raiders. Keep hidden contacts and unrelated scouting separate from threats to the economy.
2. Make air-defense advice actionable through existing selection, stance and construction controls, without issuing orders or revealing hidden enemies. Add an explicit reference opening that establishes a ground screen before buying aircraft; preserve ordinary costs and paid research.
3. Verify counter eligibility, stance/pause/order/fog authority, recovery priority and native selection controls. Complete declared screened-air matches and compare actual aircraft production, raids and outcomes with the retained early-air observations. Record remaining balance/pacing limits.

## Research progress and interruption feedback — 2026-10-05

1. Reproduce the missing live research information after closing Tech, including Coordination and unit upgrades. Check existing notice/assignment ownership and the fixed-size command panel at 720p.
2. Show current research, remaining time, low-power or missing-lab interruption and affordable research choices in the existing HUD message space. Keep assignment instructions and transient notices first; opening Tech remains explicit. Report Coordination completion through the existing notice flow.
3. Verify real paid research, shared-slot/pause/power/lab-loss/cancel/archive behavior for all three factions, then exercise native mouse/keyboard controls and notice priority at 720p/150%. Retain before/after evidence and remaining usability limits.

## Resource inspection and wreck readability — 2026-10-05

1. Reproduce clustered wreck-label clutter and inspect how resource hover picking and observation work. Retain the current battle view before replacing persistent labels.
2. Show one readable world hover card for materials, electronics and wrecks, with stock, work-slot or expiry information and faction eligibility. Preserve current observation, input ownership and tactical UI space; keep neutral resources separate from military markers.
3. Verify actual picking, hidden/current contacts, pause, depletion/expiry, harvesting and archive continuity, plus native inspection at 720p/150% and shared visibility/ownership/salvage checks. Record exact evidence and remaining usability limits.

## Engineer raid response — 2026-10-05

1. Inspect retained early-defeat and stalled-progression records, distinguish observed engineer attrition from unproven balance/timer defects, and reproduce the missing busy-engineer shortcut during a raid.
2. Reuse the existing engineer shortcut for endangered workers while preserving the primary defender advice and explicit player movement. Use current visible legal threats or recent damage to owned workers; retain idle selection when safe and revalidate at click time.
3. Verify all three factions, fog/weapon roles/recent-hit expiry, gathering/construction/cargo/queued orders, paused selection and explicit retreat, archive continuity and native 720p/150% input. Keep full-match pacing/balance conclusions bounded by the actual observations.

## Roster tile layout audit — 2026-10-06

1. Investigate suspected construction-name/cost clipping during native engineer selection. Measure actual roster content against its horizontal viewport across factions and producers.
2. Reinspect full-resolution captures before changing the layout. Only change shipping controls if the suspected defect is demonstrated.
3. Retain all-faction geometry checks and rendered 720p/150% captures, including expanded squad controls and paid production queues. Correct the earlier finding and state the audit's limits if no defect is found.

## Explicit engineer cargo delivery — 2026-10-06

1. Reproduce the missing cargo-delivery control after a manual retreat. Preserve the existing right-click HQ delivery rules and explicit field reassignment.
2. Add a selected-engineer Return cargo button using ordinary queued gather orders to each engineer's nearest completed friendly HQ. Revalidate cargo/HQ/selection on activation, preserve Shift queues and make unavailable reasons readable.
3. Verify all factions, mixed selections, target loss, pause and disk restoration, actual delivery and subsequent gathering, then review native 720p/150% mouse/keyboard controls and shared direct-order/harvesting checks.

## Sustained engineer economy under raids — 2026-10-06

1. Separate the reference commander's exposed-gatherer policy from shipping faction rules. Add an explicit test policy for observed-threat withdrawal, cargo preservation and deliberate work resumption; verify it cannot use hidden contacts or be overwritten by the reference economy loop.
2. Compare complete paid Standard/Normal matches with the established screened-air policy and the new worker policy for the retained Frontier/Helix problem pairings. Preserve original spending, live enemy AI and first-failure movement archives.
3. Inspect outcomes, worker casualties, returned cargo and renewed income. Fix demonstrated shipping blockers if found; keep policy failures, unresolved matches and balance/pacing conclusions distinct. Review meaningful earned state in the native game.

## Safe engineer reassignment under raids — 2026-10-06

1. Reproduce shared retreat endpoints and indefinite unsafe-field waits with controlled, live-neighbor scenarios. Preserve the previous policy and evidence for comparison.
2. Add an experimental reference policy that reserves distinct reachable retreat points and chooses a safe alternative field after delivery when original work remains unsafe. Keep observed-contact authority, ordinary commands and actual income accounting.
3. Run all-faction control/economy regressions and reciprocal complete paid matches; inspect earned alternate-work state. Accept strategy improvements only within the observed scope and retain failed outcomes.

## Crowded attack-move arrival and recovery — 2026-10-06

1. Reproduce the earned infantry AttackMove stall with its settled ally, active neighbors and ordinary geometry. Distinguish the point-order arrival gap from pathfinding, combat and long-route travel.
2. Share bounded occupied-endpoint observation between Move and AttackMove; preserve active combat, queued handoff, pause and exact archive state. Verify the original archive plus shared movement/action/save checks and native continuation.
3. Inspect the unresolved army's conventional-infantry recovery handoff using its earned archive. Keep reference-commander corrections distinct from shipping rules; retain complete-match limitations and next work.

## Conventional recovery through recommitment — 2026-10-06

1. Exercise the reference commander's actual order loop against the earned wounded-infantry archive. Reproduce recovery interruption and preserve the previous policy for comparison.
2. Add explicitly selected conventional treatment that retains safe-service orders until healed, survives guard/assault transitions and releases healthy soldiers back to combat. Reuse shipping service rules; preserve paid economy and programmed-unit authority.
3. Verify earned-state healing/recommitment, repeated Standard paid matches and meaningful native state. Report unresolved outcomes separately from mechanism checks and retain first failures.

## Player recovery orders — 2026-10-06

1. Reproduce the missing explicit service command and preserve the previous sources.
2. Add full-health recovery through ordinary manual queues, with role-appropriate facilities, tactical pause, program override, target-loss handling and compatible archives.
3. Verify all factions and service domains, native controls and layout, queue handoff, blocked paths, save/load and shared regressions.

## Defensive opening under first contact — 2026-10-06

1. Inspect the retained Helix first-contact defeat with earned positions, forces and orders. Measure firing opportunities, command changes and losses before choosing a correction.
2. Correct demonstrated shipping defects or explicitly test a reference commander change, preserving conventional/manual control, observed-contact authority and paid progression.
3. Verify the earned failure, relevant regressions and repeated live paid matches; inspect native earned state and report strategy limits separately from mechanical correctness.

## Paid conventional-armor retrofit — 2026-10-06

1. Exercise actual paid chip installation through the reference command loop; characterize conflicts, refund accounting, safe-service selection and the transition back to programmed defense.
2. Add an explicitly selected retrofit policy using shipping installation rules, observed pressure, one-unit-at-a-time withdrawal and bounded retry; preserve existing reference defaults and player authority.
3. Verify all-faction fees, pause, loss/cancellation, installation protection and program handoff, then repeat paid matches and inspect earned native installation state.

## Visible heavy-armor defense guidance — 2026-10-06

1. Reproduce rifle-only and depleted-army advice against visible heavy armor, retaining the original behavior and fog-of-war boundaries.
2. Add counter-aware guidance with existing defenders, stance choices, static cover, paid production, prerequisites and exact affordability; preserve player authority.
3. Verify all factions, shared air/recovery/opening advice, actual paid completion and native 720p selection/production. Record results and limits.

## Paid opening infantry guidance — 2026-10-06

1. Reproduce repeated infantry-purchase guidance after paid jobs and casualties during Standard opening.
2. Count actual defenders and owned paid infantry, expose exact remaining demand and affordability, and preserve manual authority and emergency priorities.
3. Verify all-faction paid harvesting/construction/infantry/first-tank progression, queue cancellation/loss/restoration and native layout/input where available.

## Program recovery support and first assignments — 2026-10-06

1. Inspect retained first-program states and reproduce programs waiting for health at unserviced safe points.
2. Explain missing role-appropriate support without changing assignments, spending, Lua decisions or recovery thresholds; tailor first-program advice to combat, scout and repair roles.
3. Verify live recovery/return, mobile and facility support, authority and archives across factions; inspect an earned enemy-pressure continuation and native UI.

## Selected-unit control width — 2026-10-06

1. Investigate the apparent clipped command in the earned recovery capture at 720p/150%, inspect actual rendered control bounds, and compare all-faction unit and production selections.
2. Change layout only if a cause is reproduced; retain legible labels, full control access, keyboard focus and manual-order authority.
3. Verify the original state, varied selections, scale changes and actual native command/program input; retain evidence and distinguish headless geometry from rendered layout.

## Low-health discovery under pressure — 2026-10-06

1. Restore the earned unsupported guard with defense advice active and verify whether wounded combat/support units can be selected directly from the battle plan.
2. Add a contextual low-health selection shortcut using the existing recovery threshold, including unarmed support/scouts, while preserving advice priority and manual/program orders.
3. Verify live counts, healing/death changes, empty selection, pause/order authority and all-faction native 720p control access; retain the paid-pressure evidence and broader survival limits.

## Mixed-unit recovery coverage — 2026-10-06

1. Reproduce a wounded mixed selection with only some compatible facilities and inspect the preview before issuing recovery.
2. Show supported/wounded counts and faction-specific missing service requirements without changing nearest-service choice, orders, costs or queue rules.
3. Verify all-faction coverage changes, unsupported/healthy members' authority, native partial activation and shared recovery behavior.

## Sustained recovery investment — 2026-10-06

1. Run the paid two-tank/retrofit reference opening through complete Normal-AI matches, recording wounded units, actual service coverage, foundation progress, funds and worker availability.
2. Distinguish an unavailable investment, unsafe placement, command-authority defect and ineffective strategy from one another; reproduce any actionable defect before changing rules or policy.
3. Verify the resulting paid sustain/assault/outcome path and archive any remaining failure. Keep small-sample outcomes separate from balance acceptance and leave performance deferred.

## Early armor preservation — 2026-10-06

1. Reproduce conventional tank treatment and retrofit-authority gaps using paid service fixtures and retained first-contact evidence.
2. Test an opt-in reference opening with earlier paid depot construction and explicit conventional tank withdrawal; preserve installed programs, pending orders and active chip fitting.
3. Verify real healing/release/retrofit handoffs across factions and complete paid Normal-AI trials before drawing a strategy conclusion.

## Opening repair discovery — 2026-10-06

1. Reproduce missing support access in the earned wounded defense state and pre-program faction openings.
2. Add optional support selection alongside current battle-plan advice, retaining exact cost/foundation feedback and player command authority.
3. Verify all-faction prerequisites, shortages, foundations, stale activation and native 720p mouse/keyboard layout, plus shared recovery and battle-plan checks.

## Battle debrief — 2026-10-06

1. Replace the time/population-only skirmish result with factual own-force production, losses and programming milestones.
2. Persist the record through a versioned save contract, distinguish partial older-save histories, and reject malformed records.
3. Verify real paid production, cancellation, loss ownership, pause/end boundaries, disk restoration and 720p result controls.

## Skirmish relay navigation — 2026-10-06

1. Establish missing named objective access on Alpine Relay and Industrial Crossroads.
2. Add a compact relay overview with public ownership/capture state and camera locators, preserving selection, orders and pause.
3. Verify real capture/contest, save restoration, absent-map/campaign scope and rendered layout/input; record evidence and limitations.

## Regional sustained gameplay — 2026-10-06

1. Run the retained paid armor-preservation strategy on Alpine Relay and Industrial Crossroads against Normal AI, recording public relay transitions and actual progression.
2. Inspect resolved outcomes, casualties and stalled decisions; reproduce and address concrete gameplay defects if found.
3. Verify any changes against the earned scenario and relevant shared suites; retain complete evidence and limitations.

## Restored control rendering — 2026-10-06

1. Reproduce the earned Industrial panel clipping; compare logical geometry, rendered controls and hit areas across scene restoration.
2. Identify the triggering lifecycle/renderer condition and fix the narrow cause without masking overflow.
3. Verify the original sequence, selection/resume/restore and shared layout checks; record images and remaining limits.

## Guard endpoint arrival — 2026-10-06

1. Reproduce the saved Alpine guard at a completed projected navigation endpoint outside the one-metre guard threshold.
2. Accept only bounded, unobstructed completed guard arrivals; preserve the assignment, no-progress safeguard, formation logic and manual authority.
3. Verify earned Frontier preset/Lua/visual endpoint cases, adverse bounds, paused archives, combat and shared Bastion/Helix guard/navigation suites; correct the disproven clipping report.

## Relay-contesting reference strategy — 2026-10-06

1. Trace why the paid reference leaves public relays uncontested, then add a separate bounded infantry expedition policy that reserves a home defender and yields to observed home danger, recovery and assault.
2. Verify actual travel/capture on both regional maps and all factions, ownership/health/phase/observation bounds, and ordinary-order/archive continuity without changing prices, capture rules or shipping AI.
3. Run complete paid regional trials, retain outcomes and earned capture evidence, and distinguish strategy findings from shipping balance acceptance.

## Closed-panel attack feedback — 2026-10-06

1. Reproduce the generic alert-button label during actual incoming fire and inspect the retained Industrial home-defense state.
2. Show an active base/unit attack in the existing alert button, prioritizing base damage while retaining unread/active counts in accessible descriptive text and preserving history/order authority.
3. Verify actual damage, enemy/generic-HP exclusion, read/clear/pause/expiry, all factions, live earned-state replay, and rendered input/layout; run shared alert/UI checks and record limitations.

## Simultaneous HQ recovery feedback — 2026-10-06

1. Reproduce hidden/ambiguous recovery timers when both HQs are lost, including same-faction matches and paused transitions.
2. Present both player-relative countdowns with explicit completed-rebuild wording, keeping the existing outcome rules and compact objective area.
3. Verify timed loss, paid reconstruction, pause/archive continuity, all factions, victory/defeat/draw, campaign isolation and rendered 720p layouts/actions; record exact evidence and remaining limits.

## Relay commitment and home reserve — 2026-10-06

1. Inspect the retained Industrial defeats and isolate expedition decisions that spend the home reserve or ignore newly observed opposition.
2. Add an optional cautious reference policy with an actual nearby reserve, quiet-home interval and live contact reassessment; preserve recovery authority and fair observation.
3. Exercise real capture/recall and adverse cases, then compare complete paid regional matches with the existing expedition policy. Record outcomes without inferring balance or win-rate from single runs.

## Industrial HQ engineer traffic — 2026-10-06

1. Restore the earned 416.7-second Industrial archive and reproduce the two long engineer stalls with original orders; compare controlled removal of neighboring traffic and inspect navigation/contact recovery.
2. Correct the demonstrated cause while preserving physical clearance, navigation boundaries, command authority and save continuity.
3. Verify actual travel and cargo delivery in the retained scenario, focused adversarial and shared movement/economy suites, and rendered 720p evidence. Record remaining traffic and strategic limitations.

## Attack-arrival timing audit — 2026-10-06

1. Reproduce the retained occupied-endpoint timing miss with bounded repeated live replays, tracing arrival progress, neighboring movement and the eventual outcome.
2. Fix a demonstrated arrival/authority defect, or correct the fixture if its bound contradicts legitimate movement; retain missed deadlines and avoid broadening arrival without evidence.
3. Verify the original case, combat and queued-order exclusions, save continuity and relevant shared movement checks; document exact acceptance and remaining limits.

## Independent resource reserves — 2026-10-06

1. Restore the retained late Industrial economy and identify actual unpaid requests, reserves and blocking conditions; separate AI budget behavior from reference-command strategy.
2. Correct demonstrated cross-resource production blocking while preserving paid costs, priority savings and worker recovery; test all factions and live queued completion/save continuity.
3. Verify shared economy/research/composition contracts and paid match follow-through, retain failures, and record bounded acceptance.

## Reinforcement and research pacing — 2026-10-06

1. Audit the retained late reference economy, including real production requests, queues, reserve reasons and attack-readiness requirements; correct incomplete telemetry.
2. Test an optional reinforcement-first research policy against the same paid budgets and saved live state, preserving technology costs, actual production and commander authority.
3. Compare complete paid matches with the existing policy and document whether recovery and assault pacing improve, without promoting an unsupported balance change.

## Economic defense camera focus — 2026-10-06

1. Reproduce defense guidance selecting remote defenders while leaving the threatened economy out of view, including a retained Industrial raid.
2. Focus the existing defender-selection action on a known threatened owned asset, preserving visibility boundaries, selected units, orders and production-selection behavior.
3. Verify all-faction visible/hidden/multiple raids, paused save continuity, related advice and rendered controls; record limits separately from strategic survival.

## Observed-threat construction experiment — 2026-10-06

1. Diagnose Industrial replacement spending from earned archives; distinguish reference site selection from player placement validity.
2. Add an opt-in observed-threat site/approach filter through the ordinary paid placement path. Check hidden contacts, all-faction costs, blocked-site deferral and paused restoration.
3. Compare identical earned-state branches and paid Industrial openings; retain evidence and limitations before choosing whether to promote the policy. Performance remains deferred.

## Harvesting approach recovery regression — 2026-10-07

1. Isolate the captured work-contact failure against one changed movement file and trace recovery choices.
2. Repair local recovery while preserving body clearance, actual resource contact, speed limits and the HQ escape/occupied-arrival improvements.
3. Verify captured and fresh faction scenarios, paused restoration and rendered movement; retain original-failure evidence and update acceptance limits.

## Discover stopped programs — 2026-10-07

1. Trace retained obstruction reports and verify existing explicit reassignment/Resume behavior; preserve that authority model.
2. Add a compact owned-unit program-issue shortcut that remains available with collapsed guidance and does not displace urgent advice or issue orders.
3. Verify real blocked/error states, ownership/lifecycle/pause/modal bounds, earned-state disk continuity and rendered mouse/keyboard discovery/recovery across factions.

## Industrial HQ stationary episode — 2026-10-07

1. Replay the earned 139.733-second archive and identify whether the recorded engineer/infantry jam survives current movement recovery.
2. Isolate any remaining cause and correct it while preserving physical movement, work contact, navigation and order authority.
3. Verify original-state replay, related traffic cases and paused restoration; document any full-match limits.

## Intermittent occupied arrival — 2026-10-07

1. Capture the failing earned-state arrival geometry and identify which settlement condition fails.
2. Correct the arrival or movement logic without false completion across obstacles, during combat, or before real work contact.
3. Repeat the original failures, verify queued/paused restoration and related movement cases, and review rendered behavior.

## Guarded recovery reassignment — 2026-10-07

1. Trace the earned remote-worker decisions and compare reference reassignment with the game AI’s protected expansion contract.
2. Implement an opt-in reference policy requiring an arrived healthy ground guard before remote reassignment, preserving safe local work and normal construction recovery.
3. Verify all-faction gates, real harvesting/cargo/save continuity and complete paid comparisons before drawing progression conclusions.

## HQ departure reliability — 2026-10-07

1. Reproduce the retained departure stall with disabled and normally active idle neighbors, preserving collision and real harvesting.
2. Trace path, avoidance and recovery geometry; repair any demonstrated shipping control failure without relaxing work contact, speed or collision rules.
3. Verify original states, pause/disk continuity, related crowd/work regressions and rendered behavior before accepting the change.

## Clear program assignment points — 2026-10-07

1. Reproduce acceptance of ground assignments inside known friendly footprints, including foundations and mixed ground/air selections.
2. Reject invalid points before changing programs or orders; preserve patrol input, allow air-only assignments and keep signature/service targeting intact.
3. Verify all factions, original-code negatives, real program arrival/combat, paused disk continuation and readable 720p assignment feedback.

## Preserve service-building retreat assignments — 2026-10-07

1. Reproduce the new assignment filter rejecting the documented completed matching service-building recovery flow.
2. Admit those safe points using the existing repair-service eligibility rule, while retaining guard/patrol, unfinished and unsuitable-ground-footprint rejection.
3. Verify UI assignment through actual healing/return for all factions, programmable roles and authoring modes, paused disk continuity, rendered feedback and shared controls.

## Construction economy contract — 2026-10-07

1. Reproduce template multi-worker acceleration and full partial-construction refunds against the current core contract.
2. Enforce one engineer's construction rate with automatic handoff, unused-cost refunds and visible refund amounts; preserve legacy art-demo behavior.
3. Verify all factions, manual/death handoff, real paid HQ reconstruction, cancellation/destruction, pause/disk continuation and rendered controls.

## Recover construction funds — 2026-10-07

1. Reproduce recovery guidance overlooking useful unfinished-building refunds, including currency shortfalls and combined refund sources.
2. Include live unused-construction refunds in recovery advice without cancelling anything automatically or promising an unaffordable rebuild.
3. Verify all-faction advice, paid cancellations through rebuild, save/load, rendered guidance and shared economy checks; distinguish earned resources from controlled failure injection.

## Contested headquarters recovery — 2026-10-07

1. Record HQ damage, affordability and guidance during a fresh complete paid Industrial match under current shipping rules.
2. Exercise an opt-in reference policy that reserves a rebuilding budget under observed HQ danger and explicitly follows paid recovery choices; protect retreat authority and ordinary spending rules.
3. Compare complete matches, validate eligibility/refund/order boundaries and retain earned checkpoints for contested continuation. Promote no strategy or balance change without supporting results.

## Restore electronics after worker retreat — 2026-10-07

1. Reproduce a safe fallback leaving the reference economy with busy materials workers and missing electronics income.
2. Add an explicit opt-in commander handoff at completed delivery, retaining cargo, protected retreat orders and observed-route/remote-guard checks.
3. Verify all-faction actual delivery and paused queue continuity, then compare complete paid Industrial matches. Do not change human automatic resource-type semantics or promote the policy without results.

## Match guard sectors to weapon roles — 2026-10-07

1. Reproduce reference ground guards following a higher-priority aircraft instead of a compatible ground raid.
2. Choose observed compatible defensive contacts per guard, preserving manual/recovery authority and the existing sector-update tolerance.
3. Verify actual firing, all-faction/domain decisions, paused disk continuity, inherited guard behavior and a complete paid Industrial comparison.

## Preserve replaced rally targets — 2026-10-07

1. Reproduce retargeting a producer from one resource or friendly unit to another, followed by loss of either target.
2. Move target-lifetime ownership to the current assignment and preserve explicit point rallies, selection and factory-program authority.
3. Verify all-faction paid production and real resource delivery after retargeting, paused disk continuity, current/previous-target loss and actual 720p input; run shared production/archive checks.

## Make producer rally controls explicit — 2026-10-07

1. Reproduce the selected producer's inert Stop command and absent destination text.
2. Show the current rally destination and provide a producer-only Clear rally action that preserves paid jobs and existing unit commands.
3. Verify resource/point/friendly targets, all-faction paid production, paused archives, shared stop/construction behavior and rendered mouse/keyboard controls.

## Compare sustained Industrial defense policies — 2026-10-07

1. Inspect the earned home-defense/electronics gap and retain current shipping/reference fingerprints.
2. Exercise opt-in conventional response and electronics restoration separately and together against the same default commander, using three complete paid Standard matches per variant.
3. Verify response legality, actual firing and protected recovery; inspect progression, repeated losses, income and earned checkpoints before any policy promotion. Preserve shipping command authority and tuning.

## Reconcile surplus electronics labor — 2026-10-07

1. Reproduce loaded electronics workers retaining an excessive allocation while planned purchases lack materials.
2. Add an opt-in reverse handoff for actual reference purchase demand, preserving the opening electronics quota, cargo, queues and retreat/route authority.
3. Verify all-faction real delivery and exact disk continuity, then compare complete paid matches and retain evidence before considering promotion.

## Reconcile recovery reinforcements and research — 2026-10-07

1. Audit the current unresolved paid archive and reuse the existing research-priority rule.
2. Verify the rule against actual paid production and continue the saved world with live enemy AI and recorded recovery state.
3. Compare complete current-defense openings, classify unresolved outcomes and decide whether promotion is supported. Preserve costs, paid work and command authority.

## Show assigned gathering labor — 2026-10-07

1. Reproduce missing-income guidance that ignores already-queued gathering work.
2. Share read-only assignment accounting between guidance and compact resource-bar selection controls, preserving cargo, commands and ownership.
3. Verify all-faction queued-order/depletion/death/save behavior, real delivery and paid production, then inspect mouse/keyboard controls at 720p and shared economy regressions.

## Command Horizon difficulty follow-through — 2026-10-07

1. Run the existing paid combined-arms finale commander on Story, Standard and Veteran using current shipping rules, recording actual outcomes and retaining unresolved world states; exercise both replay modifiers at Veteran.
2. Investigate any progression, combat or movement failure before changing gameplay; distinguish commander strategy from mission defects and preserve authored difficulty budgets.
3. Verify a demonstrated fix against its original scenario and relevant shared checks, or document the expanded viable-route evidence and remaining difficulty/novice limits.

## Supply Line difficulty follow-through — 2026-10-07

1. Exercise the existing conventional escort route on Story, Standard and Veteran with current shipping rules; retain outcomes and any unfinished world state.
2. Diagnose demonstrated convoy/control/combat failures using actual orders and earned archives, preserving finite opposition and direct player authority.
3. Verify any correction against its original scenario, shared convoy/archive rules and rendered controls; record viable routes separately from novice and repeated difficulty acceptance.

## Supply Line environment pass — 2026-10-07

1. Capture the present convoy route and record its blocker, navigation and archive contracts.
2. Author an editable freight-road kit, continuous worn terrain/checkpoint surfaces, restrained low roadside details and non-playable surroundings. Keep tall interior geometry within the four existing blocker envelopes and preserve all checkpoint/response positions.
3. Verify imported bounds, sight/navigation/road clearance, the earned contested archive and complete difficulty routes; review ordinary-fog combat and 720p/900p environment captures. Record final-art and broader acceptance limits separately.

## Air Corridor difficulty and restoration feedback — 2026-10-07

1. Reproduce misleading loaded-state guidance from the earned convoy archive; preserve restoration warnings and pause authority while correcting the message.
2. Run ordinary combined-arms Air Corridor commanders on Story, Standard and Veteran, retaining complete outcomes and earned states for any recovery issues.
3. Verify demonstrated fixes, shared flight/archive rules and normal-clock controls at 720p/150%; distinguish single-route viability from novice/repeated balance acceptance.

## Air Corridor quarry environment — 2026-10-07

1. Measure the current thirteen obstacle footprints, visual bounds, ground/air routes and crossing altitude; retain baseline rendered views and the earned flight archive.
2. Replace the quarry/containers with editable bounded models, continuous ground/road/helipad materials and exterior quarry infrastructure. Preserve mission positions and ground navigation; provide coherent aircraft clearance where required by measured geometry.
3. Verify imported bounds, ground sight/routes, actual aircraft crossings and saved altitude, earned evacuation recovery, full difficulty routes and ordinary-fog rendered controls. Review 720p/900p compositions and record remaining final-art/platform limits.

## Relay capture feedback — 2026-10-07

1. Reproduce active recapture hidden by contested/owner labels; exercise sole infantry, opposing defenders, vacancy and retained progress through actual relay physics.
2. Share accurate capture presentation between relay markers and Split Signal rows while preserving ownership, contest/scoring rules and archive semantics.
3. Verify pause/disk restoration, relevant campaign contracts, full Split Signal difficulty routes and 720p/150% mouse/keyboard presentation. Record remaining limits.

## Split Signal recovery audit — 2026-10-07

1. Revisit earned contested Veteran saves with normal-clock/headless order, weapon-timer, ownership and production traces; retain unfinished end-state archives.
2. Correct reproducible gameplay or commander defects identified by those traces, preserving ordinary costs, observation and player authority.
3. Verify the original failing state and relevant shared contracts, then report complete-route outcomes and unresolved balance/acceptance limits.

## Split Signal environment — 2026-10-07

1. Record original blocker, navigation and rendered-layout evidence for the three-relay map.
2. Finish the alpine communications setting with continuous terrain, plowed routes, weathered relay aprons, low ground cover and exterior landmarks.
3. Verify footprint/sight/observation/archive contracts, earned recovery and full difficulty routes; inspect gameplay and environment captures and retain unsuccessful outcomes.

## Broken Foundry control feedback and difficulty audit — 2026-10-07

1. Reproduce ambiguous capture/hold presentation and record complete difficulty routes, preserving unfinished earned states.
2. Share active/stalled capture and infantry-presence guidance across objective, HUD and world marker without changing capture or hold rules.
3. Verify pause/disk restoration, actual recovery controls, 720p layout, shared mission/reward contracts and full combat continuations; retain failed outcomes and acceptance limits.

## Broken Foundry sustained production — 2026-10-07

1. Trace all scheduled batches, paid jobs, completions and queue capacity through full uninterrupted production on every difficulty.
2. Fix any lost/partially admitted batch without bypassing shared cost, capacity or prerequisite rules; expose waiting reasons and preserve archive continuity.
3. Verify original failure, blocked/paused/restored and destroyed-node branches, shared production/campaign contracts, actual full missions and native HUD presentation.

## Broken Foundry industrial environment — 2026-10-07

1. Record existing warehouse/furnace envelopes, routes and scene views; adapt the editable industrial surroundings kit to the mission-sized district.
2. Add continuous weathered ground, flush working aprons, exterior rail/utilities landmarks and restrained ground detail while preserving streets, objectives and silhouette readability.
3. Verify boundary seams, imported bounds, navigation/sight/aircraft and archive contracts; play full difficulty routes and inspect native scene/combat captures.

## Command Horizon deployment feedback and north-route audit — 2026-10-07

1. Reproduce advancing/stalled capture, retained securing time and absent deployment guards in current HUD/world/objective presentation.
2. Share accurate deployment status/help without changing capture, scoring or victory requirements; verify actual pause/restore/input and earned recovery.
3. Exercise complete unlocked north-route difficulty/modifier fights, inspect native controls/layout and preserve unsuccessful earned worlds for analysis.

## Command Horizon desert perimeter — 2026-10-07

1. Record both route layouts, landmark bounds and native scene views before changes.
2. Add continuous exterior terrain, desert/service landmarks and restrained ground wear using existing editable assets; preserve the combat geometry.
3. Verify ground/air routes, observation, old/new archives and full combat; inspect native fog, boundary and objective views and retain acceptance limits.

## Frontier wheel motion — 2026-10-07

1. Reproduce static authored wheels during real movement for all five wheeled roles and inspect imported pivots/radii.
2. Drive wheel articulation from signed actual chassis travel and turning, excluding body gestures and discontinuous relocation; preserve gameplay authority.
3. Verify stationary/blocked/reverse/turning/pause/archive behavior, shared faction animation/combat and native moving footage. Record the cosmetic save-phase and broader acceptance limits.

## Faction ability feedback — 2026-10-07

Paused after baseline reproduction; implementation and acceptance remain unfinished. See [remaining work and handoff](REMAINING_WORK.md).

1. Reproduce active-window and mixed-cooldown ambiguity in the actual selection controls.
2. Show active/setup effects, earliest selected recharge and hardware requirements with readable help; retain activation and order authority.
3. Verify real activation, pause/disk restoration, mixed selections, all-faction rules and native 720p mouse/keyboard/hover behavior.

## Agent progress

- Paused at the user's request on 2026-10-07. Latest completed work is Frontier wheel motion. The following ability-feedback pass reproduced ten unresolved display assertions; no shipping fix was made, and its archive/native verification remains unfinished. [Remaining work](REMAINING_WORK.md) records the diagnostic, evidence and broader acceptance gaps. No further implementation or test runs are planned until explicitly resumed; historical active-goal statements below are superseded.

- Completed: Frontier wheel-motion stages 1–3. The corrected original fixture proves static wheels on five moving vehicle roles. All 28 wheels now follow signed chassis travel/turning; WheelPivot names keep imports as ordinary visual nodes, with unchanged GLB geometry and updated editable source. Five-role reverse/turn/blocked/idle/pause/archive checks, all seventeen reimports and shared motion/combat/faction contracts pass. Nineteen classified processes and a 7.5-second native review clip are retained in [wheel evidence](playtests/2026-10-07/FRONTIER_WHEELS.md). Cosmetic wheel phase restarts on load. Overall goal stays active; balance, novice/final art/platform acceptance remain open and performance stays deferred.

- Completed: Command Horizon desert-perimeter stages 1–3. Reused editable desert/industrial scenery, extended continuous terrain and access roads, added flush markings/low cover and weathered service surfaces. Both layouts retain 15/13 blockers and ten route lengths; exterior separation/seams, observation, old/new archives, eight aircraft crossings, resource delivery and shared rules pass. All three south difficulties win; normal-clock northern Veteran wins at 209.33 seconds with explicit retake. Fourteen processes and fourteen reviewed final views are in [perimeter evidence](playtests/2026-10-07/HORIZON_SURROUNDINGS.md). Overall goal stays active; novice/repeated balance, final subjective art and wider product/platform acceptance remain open; performance stays deferred.

- Completed: Command Horizon deployment-feedback/north-route stages 1–3. Shared panel/world status distinguishes retained capture, recapture, contention, securing and missing infantry; owned empty deployment asks for a return after HQ destruction. Corrected original code fails nineteen state/wording checks; exact controlled archives, actual controls, shared nine-budget/route rules and earned recovery pass. All three north difficulties and both Veteran modifiers have victories; initial Lean rejects an optional support purchase, while two traced paid-support replays pass. Native Veteran wins at 200.48 seconds. Twenty-three classified processes and seventeen final reviewed captures are in [deployment evidence](playtests/2026-10-07/HORIZON_CONTROL.md), including rejected initialization/tooltip attempts. Overall goal remains active; novice/repeated balance, final environment/platform acceptance and deferred performance remain open.

- Completed: Broken Foundry industrial-environment stages 1–3. Reused editable rail/utility/birch assets, added continuous weathered ground and flush striped aprons, and weathered existing landmarks. Six exact blocker envelopes and five route lengths remain unchanged; exterior separation/seams, observation, current/previous disk archives and 24 shared aircraft crossings pass. Story/Standard/Veteran routes win; normal-clock Veteran wins at 141.23 seconds. Twelve classified processes and thirteen reviewed final captures are in [environment evidence](playtests/2026-10-07/FOUNDRY_ENVIRONMENT.md). Overall goal stays active; final subjective art, novice/repeated balance and wider product/platform acceptance remain open, with performance deferred.

- Completed: Broken Foundry sustained-production stages 1–3. Original Veteran queues silently lose the ninth unit per node; ready batches now wait for full ordinary paid admission and expose accessible hover reasons. Natural Story/Standard/Veteran production completes 3/6/9 units per node within queue capacity. Controlled constraints, destruction and old/new exact disk continuations pass. Normal-clock early Veteran wins at 145.85 seconds; an all-batches-paid delayed route wins at 320.12 seconds. Twelve classified processes and nine reviewed captures are in [production evidence](playtests/2026-10-07/FOUNDRY_PRODUCTION.md). Overall goal stays active; novice/repeated balance and wider environment/platform acceptance remain open, with performance deferred.

- Completed: Broken Foundry feedback/difficulty stages 1–3. Shared mission/HUD/world status now explains retained capture, recapture, contention and infantry absence using the existing hold predicate. Ten original state/wording assertions fail; current focused restoration/hold checks, shared mission/production/reward and relay suites pass. Ordinary return recovers the controlled paused archive in 30.60 headless / 30.62 rendered seconds. Story/Standard/Veteran routes and a 147.35-second normal-clock Veteran fight win with paid capture replacements. Thirteen classified processes and eleven reviewed 720p/150% captures are retained in [Foundry evidence](playtests/2026-10-07/FOUNDRY_FEEDBACK.md), including interrupted fixtures. Overall goal stays active; novice/repeated balance and wider environment/platform acceptance remain open, with performance deferred.

- Completed: Split Signal environment stages 1–3. Reused the editable alpine kit for mission-sized exterior mountains/communications stations, continuous detailed terrain, plowed roads, flush relay aprons and low ground cover. All three shelf contracts and four route lengths match baseline; exterior separation/seams, observation and shared campaign/archive rules pass. Story/Standard/Veteran routes win, with Standard requiring explicit clearance; normal-clock Veteran wins at 136.67 seconds. The old earned stall recovers via real controls in 12.80 seconds. Fifteen classified processes and fourteen reviewed final captures are in [environment evidence](playtests/2026-10-07/SPLIT_ENVIRONMENT.md). Repeated balance, novice comprehension, final subjective art and broader platform acceptance remain open. Overall goal stays active; performance remains deferred.

- Completed: Split Signal recovery audit stages 1–3. Retained the earned unfinished Veteran state and identified idle infantry short of the capture objective. Find infantry/Find barracks preserves player orders, pause and production authority; exact saved-world recovery wins in 12.85 headless / 12.80 normal-clock seconds. The test commander explicitly queues relay follow-through after clearing a target; corrected old/new target-loss regression demonstrates the missing continuation. Shared campaign, relay feedback and order checks pass; fifteen script processes and seven final 720p/150% captures are classified in [recovery evidence](playtests/2026-10-07/SPLIT_RECOVERY.md). Repeated balance and novice comprehension remain open, alongside broader environment/platform acceptance. Overall goal remains active; performance stays deferred.

- Completed: relay feedback — distinguish advancing recapture, blocked contest, retained vacant progress and missing infantry; share world/mission/overview presentation and contextual uplink guidance. Original code fails five focused assertions; final capture/armor/pause/archive, all-faction relay-overview and campaign contracts pass. Full Story/Veteran stalls yielded earned archives; explicit attacks recover Story, and a paid Veteran continuation wins after 47.78 normal-clock seconds. Earlier recovery failures and timing variation remain recorded; no repeated-balance claim. Nine final 720p/150% captures and 36 classified script runs are in [relay verification](playtests/2026-10-07/RELAY_FEEDBACK.md). Overall goal stays active; novice, wider gameplay/environment/platform acceptance remain open and performance stays deferred.

- Completed: Air Corridor quarry environment — seven editable models, continuous haul roads/pads, exterior quarry infrastructure and aircraft clearance. Original thirteen blocker contracts and four navigation lengths are retained; 39 actual aircraft crossings, new/legacy disk restoration and earned held-flight recovery pass. Story/Standard/Veteran routes win; explicit-response Veteran saves all three flights headless and in a 211.10-second normal-clock 720p/150% run. Nineteen script runs and fifteen reviewed final captures are recorded in [environment evidence](playtests/2026-10-07/AIR_ENVIRONMENT.md). Altitude can affect targeting; novice/repeated balance, final subjective art and wider acceptance remain open. Overall goal stays active; performance remains deferred.

- Completed: Air Corridor difficulty/restoration-feedback stages 1–3. Stopped transports now say Holding and explain Continue; moving/safe states clear the hint. Compact guidance and panel reflow fix demonstrated 720p/150% minimap overlap. Loaded battles now use a state-neutral confirmation with restore warnings retained. Story/Standard baseline routes save three flights; Veteran baseline loses two, while ordinary observed screen attacks/repairs save all three in a fresh headless route. Final normal-clock Veteran controls save all three at 212.10 seconds; the earned held-flight archive resumes to safety in 45.03 / 45.12 seconds headless/rendered. Old-code failures, all twenty-one invocations, shared flight/archive/reward checks, Bastion/Helix restore warnings, nine inspected captures and format/lint are retained in [Air Corridor evidence](playtests/2026-10-07/AIR_DIFFICULTIES.md). The prior turn improved Supply Line's environment; this turn improves evacuation/reload clarity and adds campaign difficulty evidence. Novice/repeated balance, reward combinations, final environments/platform acceptance and deferred performance remain open. Overall goal remains active.

- Completed: Supply Line environment stages 1–3. Six editable freight-road assets, continuous worn road/checkpoint surfaces, low roadside detail, exterior mesas/freight scenery and map-owned lighting replace the blockout. The former four cliff meshes exceeded their movement/sight envelopes; replacement solids now fit the unchanged footprints. Imported bounds, ground-fire/overhead sight, exterior separation, terrain seams and exact baseline navigation lengths pass. The earned contested archive recovers in 3.03 seconds; shared mission/archive/reward checks and Story/Standard/Veteran group routes pass. Normal-clock 720p/150% Veteran mouse/Enter play wins at 226.78 seconds; nine accepted environment/gameplay captures are reviewed. See [Supply environment evidence](playtests/2026-10-07/SUPPLY_ENVIRONMENT.md). The initial JSON float-comparison fixture failure is retained and corrected. This follows convoy feedback with an opening-map art pass; final landscape composition, novice/repeated balance, other campaign environments and platform acceptance remain open. Overall goal stays active; performance remains deferred.

- Completed: Supply Line difficulty follow-through stages 1–3. Six focused Story/Standard/Veteran routes win with individual or group truck stops. A normal-clock Veteran failure exposes 9.8-second clearance held by a surviving enemy while the HUD gives no reason; shipping status now names Contested and preserves moving/cleared states. The earned archive recovers through ordinary escort/repair orders in about three seconds. Final 720p/150% Veteran mouse/Enter playthrough wins at 229.80 seconds with no truck loss; shared convoy/archive/reward checks, focused regression and format/lint pass. See [convoy difficulty evidence](playtests/2026-10-07/SUPPLY_DIFFICULTIES.md). The preceding turn improved finale recovery; this turn improves the conventional opening and expands actual difficulty-route evidence. Novice/repeated balance, remaining campaign combinations, final environments/platform acceptance and deferred performance stay open. Overall goal remains active.

- Completed: Command Horizon difficulty follow-through stages 1–3. Story/Standard normal, Veteran Lean and explicit-recovery Veteran normal/Reinforced reach actual victories. Two original Veteran commanders destroy HQ but lose deployment; earned replay proves ordinary recall/reinforcement can finish. Shipping feedback now names the completed command objective and remaining infantry task, including paused reload and urgent own-HQ priority. Four valid preceding-code assertions fail; final feedback/shared mission rules, actual 720p/150% mouse/Enter recovery and format/lint pass. See [finale difficulty evidence](playtests/2026-10-07/HORIZON_DIFFICULTIES.md). The previous turn delivered gathering controls; this turn adds mission-phase clarity and expands real campaign-route evidence. Novice/repeated/all-combination balance, other campaign difficulty acceptance, broader product/environment/platform gates and deferred performance remain open. Overall goal stays active.

- Delivered and verified 2026-10-07: gathering-assignment stages 1–3 complete. The shipping resource bar now shows selectable material/electronics engineer counts, and supply guidance shares next-job-aware accounting so queued transfers do not trigger false missing-income prompts. Both resource directions, target loss, death, work-slot/depletion distinctions, protected orders and paused archives pass for all three factions; actual loaded cargo returns once and gathered electronics fund completed fitted armor. The preceding shipping files fail twelve assertions. Shared supply/orders tests pass; two mouse activations, one Enter activation and three inspected 720p/150% captures pass. Invalid alerts-layer and 1080p fixtures remain rejected and retained. See [economy assignments](playtests/2026-10-07/ECONOMY_ASSIGNMENTS.md). Two shipping scripts change and one read-only helper is added; harvesting semantics/costs/save schema stay unchanged. These Advanced fixtures disable strategic AI and do not establish contested survival or novice acceptance. Broader gameplay/environment/platform acceptance remains open; goal active, performance deferred.

- Fixed and verified 2026-10-07: recovery-reinforcement stages 1–3 complete for the current reference commander. Optional upgrades now wait for its required nine-ground-unit assault force; Coordination, paid jobs and essential production retain their rules. The new stalled-world continuation with live enemy AI reaches nine/attacks after 171 s instead of 891 s, and wins after 291.25 s instead of 995.85 s. Recorded commander state is reconstructed, with unrecorded histories/RNG restarted; both are already-late matches, not pacing acceptance. All three fresh runs lose, including the final default at 794.2 s; no win-rate improvement is claimed. Five runs resolve with 8,925 violation-free coordination samples, and initial/final all-faction paid/archive checks plus shared research-economy checks pass. See [recovery reinforcements](playtests/2026-10-07/RECOVERY_REINFORCEMENTS.md). All 288 shipping scripts remain unchanged. Next: sustained Industrial field-route/worker survival using the corrected reference budget; broader gameplay, novice/environment/platform acceptance and deferred performance remain open. Goal stays active.

- Verified 2026-10-07: surplus-electronics stages 1–2 and comparative investigation complete; full-match acceptance fails. An opt-in reverse handoff preserves cargo/queues/route safety and the opening electronics floor, with all-faction real delivery and exact earned live-enemy replay (4 E / 4 M versus electronics-only) verified. Four focused suites pass; the disabled-hook control fails six assertions. Four paid trials produce three defeats and one unresolved thirty-minute control; no promotion. See [materials handoff](playtests/2026-10-07/MATERIAL_HANDOFF.md). All 288 shipping scripts and default reference behavior remain unchanged. The unresolved archive exposes the next concrete issue: seven ground combatants cannot pass a nine-unit recovery gate while optional research spends 160 M ahead of replacement tanks. Next: verify recovery reinforcement priority from earned state, retaining essential production and ordinary paid costs. Broader gameplay acceptance remains open; goal active, performance deferred.

- Compared and verified 2026-10-07: sustained-defense stages 1–3 complete as an unpromoted reference experiment. Twelve paid Standard/Normal Industrial Helix-versus-Frontier matches finish with zero unresolved checks and 18,988 violation-free AI coordination samples. Default/response each lose all three; electronics-only/combined each win one of three. All reach programming in three to five minutes; the combined seed-4112 victory takes 28:52 with eight assaults and seven regroups. Three final regression suites pass; parse and invalid-health fixtures remain classified. See [sustained defense](playtests/2026-10-07/SUSTAINED_DEFENSE.md). All 288 shipping scripts and the default reference remain unchanged. Next: reconcile returning/active worker allocations and material demand—the combined loss reaches five electronics/one materials worker with 9 M / 142 E. No general policy promotion; wider gameplay/novice/environment/platform acceptance remains open. Overall goal stays active; performance deferred.

- Delivered and verified 2026-10-07: explicit rally-control stages 1–3 complete. A selected completed producer now names its destination and offers Clear rally, disabled when unassigned. Paid queues, existing unit commands, mixed-selection Stop and foundation cancellation retain their authority. All three factions pass resource/point/friendly clearing, all four producer controls, paused disk continuity and normal paid engineer completion without the cleared order. Five final suites pass; the preceding UI fails 24 assertions. Two engine mouse clicks, one focused Enter activation and seven inspected 720p/150% images pass. See [rally controls](playtests/2026-10-07/RALLY_CONTROLS.md). Only UnitMenus.gd and RallyPoint.gd change; contested progression and broader acceptance remain open. Overall goal stays active; performance deferred.

- Fixed and verified 2026-10-07: rally-retarget stages 1–3 complete. Producer targets now transfer their lifetime listener on replacement; old-target loss cannot erase the new order, current-target loss clears correctly, and saved point destinations survive null restoration. The actual preceding shipping source fails nine all-faction assertions and emits three disconnect errors. Five final headless suites pass, including paid production, exact paused disk continuity and real electronics delivery for all three factions. Six engine-injected right-clicks and five inspected 720p/150% images pass. Initial freed-reference/rounding fixtures and the intermediate teardown/null-restore defects remain classified among twelve runs. See [rally retarget](playtests/2026-10-07/RALLY_RETARGET.md). Only RallyPoint.gd changes among 288 shipping scripts. Target losses are injected and strategic AI disabled; sustained contested progression and broader acceptance remain open. Overall goal stays active; performance deferred.

- Fixed and verified 2026-10-07: guard-sector stages 1–3 complete. Default reference guards now choose observed contacts compatible with their current weapons, preserving manual/recovery authority, safe points and sector tolerance. All-faction authored Lua/visual actual firing and paused disk continuity pass; walker modes and three shared suites pass. Original-selection control fails 24 expected assertions. The complete paid Industrial pair loses at 761.20 / 472.00 s with zero unresolved checks; trajectories diverge before guard programming, so no survival claim follows. Three rejected fixture runs remain classified among eleven retained runs. See [guard response](playtests/2026-10-07/GUARD_RESPONSE.md). All 288 shipping scripts remain unchanged. Next: sustained home/resource-route defense and Industrial progression; geometry, congestion and broader acceptance remain open. Overall goal stays active and performance deferred.

- Verified 2026-10-07: electronics-restoration stages 1–3 complete as an opt-in reference helper. Missing electronics allocations after safe material fallback now have an explicit delivery-boundary handoff option with quota, protected-order, observed-route and remote-guard checks. Five final headless suites pass; the disabled-hook control fails six expected assertions. An exact earned checkpoint with live enemy AI delivers 4 M / 4 E in 28.78 s when its queue is retained, while clearing that queue yields only materials over sixty seconds. The complete final Industrial pair loses at 561.10 / 566.80 s; neither launches an assault, so no strategy promotion. The initial two-electronics-worker opening and the deposit-deletion fixture are retained and classified. See [electronics handoff](playtests/2026-10-07/ELECTRONICS_HANDOFF.md). All 288 shipping scripts and the default reference remain unchanged. Next: protect home/resource routes through subsequent raids and establish sustained Industrial progression. General congestion and broad acceptance remain open; overall goal stays active and performance deferred.

- Audited 2026-10-07: contested HQ recovery stages 1–3 complete as a rejected-for-promotion reference experiment. Current-shipping Industrial control reaches programming/assault and loses at 637.80 s; the opt-in observed-danger reserve/rebuild branch reaches neither and loses at 417.60 s. Both complete with zero harness failures and no replacement HQ purchase. Exact paused checkpoint audits separate blockers: control has 216 M / 10 E plus a 6 M queue refund and two safe workers; experiment has 67 M / 54 E, no refunds and no engineer outside observed danger. No affordable contested rebuild is claimed. All-faction isolated reserve, protected-builder, site/deadline and inherited construction tests pass; all 288 shipping scripts match the previous baseline. See [HQ recovery policy](playtests/2026-10-07/HQ_RECOVERY_POLICY.md). Next: sustained Industrial home defense and protected electronics routes, rather than promoting a reserve strategy that weakens the observed opening. General congestion and broader acceptance remain open. Overall goal stays active; performance remains deferred.

- Fixed and verified 2026-10-07: construction-fund recovery stages 1–3 complete. Battle-plan affordability includes actual unused foundation refunds, and Review foundation selects the useful building without cancelling it or taking engineer authority. All-faction earned-resource progression through paid prerequisite/factory construction, controlled HQ loss, paused disk continuation, explicit refund and HQ rebuilding before defeat passes. Combined queue/research/foundation and last-engineer replacement fixtures pass; previous shipping control fails thirty assertions. See [foundation recovery](playtests/2026-10-07/FOUNDATION_RECOVERY.md). Failed prerequisite/cost fixtures and the insufficient aggregate timer remain classified. The opponent strategic loop is disabled and loss injected in earned tests: contested match recovery and reference-economy priorities remain open, alongside sustained Industrial progression and broader acceptance. Overall goal stays active; performance remains deferred.

- Fixed and verified 2026-10-07: construction economy stages 1–3 complete. Live engineer orders supply one construction rate per site with automatic stop/death handoff; partial cancellation returns unused costs and displays the refund. All-faction paid HQ placement, ordinary completion before defeat, paused disk continuation, paid cancellation, duplicate/completed guards, destruction and legacy rate/refund checks pass. Preceding-code control fails eighteen assertions; eight final headless suites pass. Four engine cancellation clicks and seven inspected 720p/150% captures pass. See [construction contract](playtests/2026-10-07/CONSTRUCTION_CONTRACT.md). These fixtures supply resources and position workers: earned-state HQ reconstruction/reference economy priorities and sustained Industrial progression remain next. Broader acceptance stays open; overall goal stays active and performance remains deferred.

- Corrected and verified 2026-10-07: service assignment stages 1–3 complete. The preceding footprint filter regressed the documented safe-point-on-service flow; HUD input now uses the existing facility eligibility rule for completed compatible ground service, while guard/patrol and incomplete/unsuitable footprints remain rejected. Pre-fix UI eligibility fails 36 valid ground combinations. Final verification passes 54 live recovery cases across all six programmable roles, all three factions and preset/Lua/visual modes; nine exact partial-healing disk checks, five headless suites, eight engine map clicks and ten inspected 720p/150% captures pass. The failed early-autoload fixture and initial obstructed camera framing remain recorded. See [service assignment](playtests/2026-10-07/SERVICE_ASSIGNMENT.md). The retained Industrial loss has insufficient HQ funds and no cancellable production jobs; a funded earned-state rebuild/reference-economy check remains next. Sustained progression, later assignment obstruction and broader acceptance remain open. Overall goal stays active; performance remains deferred.

- Fixed and verified 2026-10-07: clear assignment points stages 1–3 complete. Guard/retreat/patrol input rejects owned living structures and foundations before any program mutation, preserves mixed selections/manual queues/running guards and staged patrol input, and revalidates the first waypoint before commit. Air-only points and signature sectors retain their semantics; only owned footprints inform feedback. Seven final headless suites pass, including all-faction actual arrival/combat and exact paused disk continuity; original shipping control fails 84 assertions. Nineteen engine-injected map clicks and six inspected 720p/150% captures pass. Fixture prerequisite/lifetime/projection errors and weaker intermediate combat evidence remain retained. HQ departure investigation is bounded: disabled neighbors stall all three probes, while active idle neighbors permit real delivery in 30.60 / 26.42 / 28.30 seconds. Conditional movement repair was not justified, so movement stays unchanged. See [assignment footprints](playtests/2026-10-07/ASSIGNMENT_FOOTPRINTS.md). Later construction can still obstruct assignments; sustained Industrial defense/progression, general congestion and broader acceptance remain open. Overall goal stays active; performance remains deferred.

- Audited 2026-10-07: guarded recovery reassignment stages 1–3 complete as an opt-in reference experiment. All 288 shipping scripts match the preceding baseline. All-faction guard gates, real retreat/resumption, harvesting/delivery and exact paused disk continuity pass; original-policy control fails fifteen expected eligibility assertions and completes all actual trips. Shared default reassignment, format and lint pass. One complete paid Industrial pair reaches programming at 280.23 / 294.23 seconds and loses at 626.60 / 472.90 seconds; no strategy promotion. Initial descriptor errors and frozen-army departure stalls remain classified as rejected fixtures, not repaired shipping behavior. See [guarded reassignment](playtests/2026-10-07/GUARDED_REASSIGNMENT.md). Next: sustained Industrial home defense and successful progression; guard-presence gating alone has not improved the opening. General congestion, broader content/novice/platform acceptance and the earlier isolated harvesting replacement observation remain open. Overall goal stays active; performance remains deferred.

- Fixed and verified 2026-10-07: occupied Move/AttackMove arrival stays ready after two seconds without meaningful approach, retaining the prior approach reference through outward yielding and temporary empty-path reconstruction after load. Existing completion bounds and combat/queue authority remain unchanged. A fresh preceding-code geometry probe fails 5/20 times and retains five exact failure archives; final code passes 40/40 source replays and 15/15 captured continuations. The isolated preceding-source window control fails five assertions. Nine final headless suites and two rendered branches pass, including exact ready-state disk restoration; all five 720p/150% captures were inspected. Initial fixture queue-source errors and the genuine intermediate empty-path reset failure remain recorded. See [arrival window](playtests/2026-10-07/ARRIVAL_WINDOW.md). This resolves the reproduced arrival gap from the prior turn. The harvesting replacement suite passes now, but its previous isolated miss remains causally unproven. Next: Industrial home defense/programming access and sustained progression, while retaining that replacement observation and broader content/novice/platform gates. Overall goal stays active; performance remains deferred.

- Fixed and bounded 2026-10-07: the earned 139.733-second Industrial HQ pinch now clears by retrying a stalled navigation-projected recovery step through existing speed/navigation/body constraints, excluding occupied-endpoint yielding. Only Movement.gd changes. Six original-state/disk branches complete collection and delivery; the preceding-source control fails twenty-five assertions. Eight final headless suites and two rendered branches with seven inspected captures pass. Wider checks remain incomplete: focused occupied-arrival repeats fail 2/20 on preceding code and 5/20 on current code, exposing a pre-existing intermittent gap; one full harvesting-suite manual replacement miss remains unexplained, with 12/12 isolated passes on each version. Two paid Industrial trials both lose without programming or an assault (288.8 / 671.8 s), so no stronger strategy is accepted. Superseded sources, failed logs and intermediate outcomes remain classified. See [Industrial pinch](playtests/2026-10-07/INDUSTRIAL_PINCH.md). Next: the now-reproduced arrival timing gap and retained replacement miss before broader movement acceptance, then Industrial defense/progression and content/novice/platform gates. Overall goal stays active; performance remains deferred.

- Implemented and verified 2026-10-07: the battle-plan header exposes owned Blocked/Error programs through a compact Program issues count, including collapsed guidance. Selection reveals status while preserving orders, pause and urgent advice; reassignment and Resume remain explicit. The earned Industrial archive discovers two blocked tanks before/after disk reload. The preceding-source control fails three discovery assertions. Six headless suites, eight rendered mouse/Enter shortcut activations and actual recovery in all three factions pass; eleven 720p/150% captures were inspected. Initial parser, scroll-assumption and obscured-map-click fixture failures are retained and classified. See [program issues](playtests/2026-10-07/PROGRAM_ISSUES.md). Next: the separate 33-second stationary observation and Industrial home-defense/programming access, plus broader content/novice/platform acceptance. Overall goal stays active; performance remains deferred.

- Fixed and verified 2026-10-07: the captured harvesting regression was isolated to ground recovery ranking. Recovery now admits a side with at least the existing 0.02 m contact margin of free travel and then prefers navigation clearance; fully blocked sides still allow the HQ backward escape. Only Movement.gd changes in shipping code. Twelve untouched captured checks collect at 6.1 s, three checkpoint disk continuations pass, and all-faction delivery/construction remain valid. The faulty-code control fails fifteen assertions. Nine relevant headless suites and both rendered scenarios pass, with ten inspected 720p/150% captures. Six unsuccessful work-action alternatives are retained as rejected evidence; MovingToUnit.gd is restored byte-for-byte. See [contact recovery](playtests/2026-10-07/CONTACT_RECOVERY.md). This resolves the prior construction-audit harvesting blocker; it does not establish general crowd or full-match acceptance. Next: retained 33-second stationary/program-goal obstruction observations and Industrial home-defense/programming access, plus broader content/novice/platform acceptance. Overall goal stays active; performance remains deferred.

- Implemented and audited 2026-10-07 (started 2026-10-06): opt-in observed-threat construction reference, with a default-true placement hook preserving existing policy. All-faction exact-price construction, hidden contacts, threatened approaches, all-site deferral and paused disk completion pass; original-hook control fails 21 assertions. Earned funded-state comparison buys four barracks for 80 materials with three losses versus one surviving barracks for 20 over 120 seconds. Two paid Industrial trials both lose (520.3 / 494.4 s), with first programs at 203.2 / 357.2 s and no main assault. No stronger opening or shipping policy change is promoted. Initial unfunded archive comparison showed no benefit and failed post-result save writes; retained as rejected acceptance evidence. Engineer-safety and air-defense suites pass, but ContactApproachRegression fails four work-completion checks on current and preceding shipping code; older pre-HQ-traffic baseline passes. Shipping sources are unchanged this slice. **Next priority: isolate and repair this captured harvesting approach without losing the HQ-traffic/arrival fixes.** Also retain the control's 33-second stationary episode and friendly-building-blocked program goals. See [construction safety](playtests/2026-10-06/CONSTRUCTION_SAFETY.md). Overall goal stays active; performance remains deferred.

- Implemented and verified 2026-10-06: battle-plan defender selection centers the camera on the known threatened owned asset, prioritizing the newest recent hit, while preserving selection, orders, funds, pause and modal ownership. Production/engineer advice keeps its existing focus. Thirty-seven original-code assertions fail; changed code passes fourteen all-faction/earned/disk-reload cases, seven headless suites, fourteen engine mouse/Enter activations and six visually inspected 720p/150% captures. Fog-stale staging, an invalid preview refresh, a layout-timing click miss and a nonexistent shared-test command are retained as rejected evidence; final accepted runs have no script/parse/load errors. See [economic defense focus](playtests/2026-10-06/DEFENSE_FOCUS.md). This makes remote economic danger visible without issuing tactical orders; it does not establish Industrial survival/programming access. Sustained defense, pacing, the retained congestion episode and broader content/novice/platform acceptance remain open. Overall goal stays active; performance remains deferred.

- Implemented and audited 2026-10-06: optional reference policy defers optional upgrades below its existing nine-ground-unit assault requirement while retaining Coordination eligibility. All-faction exact-paid reinforcement, cancellation, protected membership and paused disk delivery pass. In the retained late Industrial budget replay, control buys upgrades and remains at seven ground units for 300 seconds; the variant delivers a new unit at 92 seconds and reaches nine at 156 seconds, then resumes upgrades. Corrected misleading telemetry: the old empty human production list was unmeasured, not proof of no demand; current records include requests, queues, timers and blocking reasons, with null for unknown human construction reserves. Four full paid comparisons produce two Alpine victories (485.5 s control / 1531.2 s variant) and two Industrial defeats (664.6 / 293.1 s), with zero coordination violations across 5,948 samples. The variant is not promoted as a stronger strategy; it is retained as an opt-in experiment. The initial cancellation fixture had script errors despite exit zero and is rejected; corrected policy/telemetry tests pass. See [reinforcement pacing](playtests/2026-10-06/REINFORCEMENT_PACING.md). No shipping-source changes. Next: sustained Industrial home defense and programming access, plus the retained 22.5-second congestion observation and broader content/novice/platform acceptance. Overall goal stays active; performance remains deferred.

- Implemented and verified 2026-10-06: AI production protects reserves only in currencies a purchase consumes, allowing surplus-material infantry while electronics accumulate. The earned Industrial AI state has 72/14 funds, a 45/20 aircraft-factory reserve and a blocked 5/0 infantry request. Original code fails twenty finalized fixture assertions; changed code buys and actually completes the archived infantry after a paused disk reload with electronics unchanged. All-faction construction/counter savings, exact charges/refunds and nine final headless suites pass. Corrected a pre-existing procurement fixture that accidentally reserved unpaid research and leaked failed matches; the corrected fixture also passes original shipping code. Two paid full matches finish (Alpine Victory 749.4 s, Industrial Defeat 610.7 s), with one observed normal surplus-material purchase and zero coordination violations across 2,720 samples. See [independent resource reserves](playtests/2026-10-06/RESOURCE_RESERVES.md). The reference army's separate recovery/production pacing and Industrial home defense remain open, alongside broader content/novice/platform acceptance. Overall goal stays active; performance remains deferred.

- Implemented and verified 2026-10-06: occupied Move/AttackMove arrival measures progress toward the reachable endpoint, preventing sideways crowd recovery from repeatedly restarting the arrival wait. The retained timing miss reproduces in 7/48 original replays (up to 18.17 seconds); the original-code control fails twelve regression assertions. The correction passes fourteen untouched late-state replays and 48/48 fresh replays in about two seconds, twelve headless suites, and four 720p/150% rendered states. Friendly occupancy, short-route bounds, active combat, queued orders and saved observation continuity remain covered. See [attack-arrival progress verification](playtests/2026-10-06/ATTACK_ARRIVAL_PROGRESS.md). This closes the prior retained timing defect, not general crowd or strategic acceptance. Next: home defense, paid progression and late recovery/production deadlock, plus broader content/novice/platform acceptance. Overall goal stays active; performance remains deferred.

- Implemented and verified 2026-10-06: ground recovery ranks actual body-free travel before navmesh clearance, admitting backward escape from the retained Industrial HQ pinch. The original code fails six final-fixture assertions; changed live replays escape and deliver cargo, with exact intermediate disk recovery and fresh all-faction corridor completion. Fourteen headless suites have passing final runs and seven 720p/150% rendered states pass. A 1-HP engineer can still die after escape; an initial six-second attack-arrival miss remains an unresolved timing limitation despite a passing repeat. Corrected an enemy-occupancy fixture whose supposedly stationary blocker could drift. Two paid full matches both lose, with longest sampled stationary travel at most three seconds and zero AI coordination violations across 2,181 samples. See [HQ traffic verification](playtests/2026-10-06/HQ_TRAFFIC.md). Next: home-defense/paid progression and recovery/production deadlock, plus the intermittent arrival bound and broader content/novice/platform acceptance. Overall goal stays active; performance remains deferred.

- Implemented and audited 2026-10-06: optional cautious relay reference keeps two healthy nearby infantry, waits for quiet home conditions, reassesses observed opposition and protects direct withdrawal until arrival or recovery/manual handoff. Six faction/map capture/archive cases, three live withdrawal cases, authority/shared suites and six earned-state 720p/150% captures pass. Four final paid comparisons produce three defeats and one unresolved 30-minute Industrial match; its completion assertion correctly fails. Two Alpine scouts complete protected returns, but no stronger opening is accepted. No AI coordination violations in 9,402 samples. Industrial exposes two approximately 272-second engineer stalls near HQ and a late healthy seven/eight-unit recovery force below the nine-unit assault threshold. See [relay commitment audit](playtests/2026-10-06/RELAY_COMMITMENT.md). Next: reproduce the retained traffic episode and investigate recovery/production deadlock before further strategy promotion. No shipping gameplay change; overall goal stays active and performance deferred.

- Implemented and verified 2026-10-06: independent Your HQ / Enemy HQ recovery deadlines remain visible through simultaneous losses, paused destruction, mirror matches, disk restoration and paid reconstruction. Twenty-four original behavior failures now pass across all three factions; unchanged expiry produces Victory, Defeat and Draw. Five headless suites and five 720p/150% rendered states pass. Removed duplicated deadline/new-build-duration text from paid-foundation advice after the first capture exposed a four-pixel minimap overlap. See [HQ recovery verification](playtests/2026-10-06/HQ_COUNTDOWNS.md). Fixtures grant the exact reconstruction budget and disable AI decisions; full-match comeback viability and broader strategy/novice/content/platform acceptance remain open. Overall goal stays active; performance remains deferred.

- Implemented and verified 2026-10-06: active incoming fire appears directly on the existing alert button, with base damage taking priority, warning persistence after reading, simulation-time expiry and counts in tooltip/accessibility text. Twenty-two original behavior failures now pass across all factions and a live earned Industrial raid. Four headless suites and six final 720p/150% rendered states pass. Corrected the older alert economy fixture's frozen idle engineers and scoped its depleted-worker assertion; the same ten initial failures existed with the old panel, and normal avoidance restores real cargo delivery. See [attack feedback verification](playtests/2026-10-06/ATTACK_FEEDBACK.md). The previous turn added objective-strategy evidence; this turn delivers player-facing danger feedback. Safer objective commitment/home defense and broader strategy/novice/content/platform acceptance remain open; overall goal stays active and performance deferred.

- Implemented and audited 2026-10-06: optional relay expeditions in the paid regional reference, reserving one healthy home infantry and yielding to observed danger/recovery/main operations. Six all-faction/map cases pass actual base-to-relay travel, travel/partial-capture disk restoration, ownership/vision and priority bounds. Four complete current-code trials produce two Alpine victories and two Industrial defeats. Expeditions achieve twelve captures/recaptures (344.0 / 70.5 relay-seconds), but the Alpine run loses more forces and Industrial loses earlier; no stronger opening or shipping balance change is accepted. No coordination violations across 5,764 samples. Two earned archives and six rendered ownership/locator states pass. See [relay-contesting audit](playtests/2026-10-06/RELAY_CONTEST.md). Next: safer objective commitment alongside home economy defense, then broader strategy/novice/content acceptance. Overall goal remains active; performance stays deferred.

- Implemented and verified 2026-10-06: bounded completed-path Guard arrival fixes the earned Alpine false Blocked state. The finalized Frontier preset/Lua/visual fixture reproduces six original failures and passes with exact disk restoration, combat, manual authority and adverse bounds; four shared guard suites and seven rendered 720p/150% states also pass. Stationary hold checks reject displaced arrival reuse. Corrected an older formation-test health-sampling race. The previous clipping diagnosis was mistaken: original and replayed command panels are pixel-identical, and reported-center input works, so no shipping layout change was made. See [guard endpoint verification](playtests/2026-10-06/GUARD_ENDPOINT.md) and [rendering correction](playtests/2026-10-06/CONTROL_RENDERING.md). Broader live crowd/strategy, novice/content/platform acceptance remain open; overall goal stays active and performance deferred.

- Audited and verified 2026-10-06: four paid Standard/Normal armor-preservation trials across Alpine/Industrial and all three factions. All lose (423.4–1378.8 s); three activate programs, one assaults, three conventional armor recoveries and six retrofits complete. No AI coordination violations in 7,692 samples. Two earned Frontier archives heal from 32/68 HP past 80% in 11.1/13.0 s after restoration with live AI and no reference commander. No shipping balance change is supported. A captured guard resumes into its area but later moves under crowd pressure; its cause remains unproven. Rendered review also reveals persistent right-edge clipping despite passing 470-pixel layout bounds, so visual acceptance remains open. See [regional recovery audit](playtests/2026-10-06/REGIONAL_RECOVERY.md). Next: isolate that geometry/render mismatch and the saved near-structure guard, then continue strategy/expansion/relay acceptance. Overall goal remains active; performance stays deferred.

- Implemented and verified 2026-10-06: named skirmish relay overview and public world/minimap locators on Alpine Relay and Industrial Crossroads. Six original all-faction/map access failures now pass through real capture/contest, partial-capture disk reload, camera ground targeting, pause, selection/queue/funds preservation and hidden-enemy isolation. Four shared suites and the rendered input suite pass with 14 final 720p/150% captures. Corrected a campaign fixture's empty assignment selection; shipping assignment logic is unchanged. Physical native input remains limited by computer use selecting Project Manager after rediscovery. See [relay navigation](playtests/2026-10-06/RELAY_OVERVIEW.md). Next: broader cross-map strategy and novice/content acceptance. Overall goal remains active; performance stays deferred.

- Implemented and verified 2026-10-06: factual own-force skirmish debrief with completed production, casualties, built/foundation losses and programming milestones. Snapshot version 9 preserves it; versions 1–8 begin an explicitly partial record that remains partial after resaving. Three original all-faction gaps now pass through paid jobs, cancellation, pause, ownership, actual activation, result freezing, corruption checks and disk continuity. Seven shared gameplay/save suites and six 720p/150% result captures pass. Corrected rendered navigation reaches Skirmish setup; final physical-keyboard repetition remains limited by computer use binding to Godot Project Manager after an earlier timing-fixture failure. See [battle debrief](playtests/2026-10-06/BATTLE_DEBRIEF.md). Next: broader cross-map/faction gameplay and novice/content acceptance. Overall goal remains active; performance stays deferred.

- Implemented and verified 2026-10-06: optional repair-support discovery beside the primary battle-plan action. Four original earned/all-faction failures now pass; costs, funding gaps, paid foundations, prerequisites, duplicate suppression, mobile/completed support and stale selection are covered. Selecting an engineer preserves orders, funds, pause and lab/defense priority. Native mouse/Enter checks pass at 720p/150%; the initial extra row overlapped the minimap, and the final shared action row passes long advice and 95-unit low-health layouts. Shared battle-plan/selection/recovery suites pass. See [opening support discovery](playtests/2026-10-06/SUPPORT_DISCOVERY.md). Next: broader faction/map/content and novice acceptance using the retained paid-match evidence. Overall goal remains active; performance stays deferred.

- Implemented and verified 2026-10-06: opt-in early paid depot and explicit conventional-armor recovery in the reference commander. Three original all-faction failures now pass through paid service construction, real 50→80% healing, phase/queue/program authority, exactly one chip and Running Guard. Shared infantry/retrofit suites and earned infantry return pass. Three complete Standard/Normal trials produce two victories and one defeat; four tanks recover through 101 authority checks, followed by five total paid retrofits. The first Helix trial still loses without an armor-recovery episode, so no general strategy or shipping balance claim is accepted. See [early armor preservation](playtests/2026-10-06/ARMOR_PRESERVATION.md). Next: player-facing timely support discovery and broader faction/map/novice acceptance. Overall goal remains active; performance stays deferred.

- Audited and verified 2026-10-06: seven paid Standard/Normal matches resolve with one Frontier victory and six Helix defeats, with no recorded AI coordination violations. Service traces identify early tank losses and an optional-air reserve holding an affordable ninth ground unit. Two opt-in policy regressions each reproduce six original failures and pass across all factions with paid live production; the final nine-ground variant loses both full trials before program activation, so no stronger opening or shipping change is accepted. See [sustained recovery and spending audit](playtests/2026-10-06/SUSTAIN_PRESSURE.md). Next: conventional armor preservation before chip fitting and support timing. Overall gameplay acceptance remains active; performance stays deferred.

- Implemented and verified 2026-10-06: Recover health previews partial support (for example 3/4) and names missing faction service facilities with affected-unit counts. Eighteen original all-faction feedback assertions now pass; unsupported scouts and healthy members retain their orders on actual partial activation. Native Helix mouse input and 720p/150% labels pass, and shared live-healing/queue/save recovery coverage remains green. See [mixed recovery coverage](playtests/2026-10-06/RECOVERY_COVERAGE.md). Next: return to sustained paid-match and broader gameplay/content acceptance; the recent discovery/feedback improvements do not establish better survival or balance. Overall goal remains active; performance stays deferred.

- Implemented and verified 2026-10-06: a contextual Low health shortcut makes combat/support units below 50% HP directly selectable while emergency defense advice remains active. It includes scouts/repair robots, excludes workers/buildings/enemies/dead units, recomputes healed/dead membership on activation, and keeps existing orders/programs. Four original missing-shortcut assertions now pass. The earned 13.15-HP Helix guard remains unchanged by selection; all-faction mouse/focused-Enter checks pass at 720p/150%, with shared battle-plan and ground-defense suites. See [low-health selection](playtests/2026-10-06/LOW_HEALTH_SELECTION.md). Next: broader opening survival and recovery investment/content acceptance; this access improvement is not evidence of improved win rate. Overall goal remains active; performance stays deferred.

- Verified audit 2026-10-06: the prior recovery capture's apparent Attack move clipping did not reproduce in the exact earned recovery sequence or broader native/headless layout coverage. Added 46-state checks across all factions, six selection roles, three UI scales, scrolling and long remapped shortcuts; both final suites pass. Native mouse activation, focused Enter activation and Escape cancellation retain the guard's action, safe point, funds and paused time. No shipping layout change was made; the single earlier capture discrepancy remains unproven. See [control-width audit](playtests/2026-10-06/MENU_WIDTH.md). Next: return to opening survival/recovery investment and broader gameplay/content acceptance, rather than expanding layout checks without a reproduced defect. Overall goal remains active; performance stays deferred.

- Fixed and verified 2026-10-06: program retreat status identifies missing role-appropriate recovery support, and first-program advice selects Guard, Scout or Service by unit role. The original eighteen all-faction failures now pass, along with real facility/mobile healing, Lua/visual programs, save restoration, manual authority and four shared suites. An earned Helix continuation with Normal enemy AI active remains stranded at 13.15 HP until its existing economy pays 25 M / 10 E for a Service cradle; construction and healing return it to Guard in about 47–48 seconds. Native 720p/150% review verifies the same paid flow after correcting the test harness's pause ownership. See [program recovery verification](playtests/2026-10-06/PROGRAM_RECOVERY.md). Next: broader opening survival and strategy acceptance, including how players discover and fund timely support. Overall goal remains active; performance stays deferred.

- Fixed and verified 2026-10-06: opening infantry guidance counts ready defenders and owned paid jobs, shows exact remaining demand and per-unit cost, and exposes purchase blockers. Twelve original all-faction failures now pass. All three Standard starts pay through normal harvesting/construction/training for four infantry, a conventional tank, lab and chip, reaching Running Guard at 190.95/186.18/167.57 s for Bastion/Helix/Frontier. Partial-training disk restoration, cancellation, split queues, producer loss, population cap and four shared suites pass. Native Bastion Enter/mouse/Space guidance passes at 720p/150%; a refreshed native window also completes the previously blocked manual factory-reselection and subsequent purchase check. See [paid opening verification](playtests/2026-10-06/OPENING_INFANTRY.md). Next: verify that early-game recovery and program setup remain actionable under the retained Normal-AI pressure, with strategy and survival acceptance still open. Overall goal remains active; performance stays deferred.

- Fixed and verified 2026-10-06: visible heavy-armor defense guidance now distinguishes rifle-only armies from existing counters, recognizes paid specialist/air queues, and exposes actual factory cost, fitting, prerequisites and capacity. Original all-faction advice fails nine assertions; final regression passes real paid completion, fog, pause, emergency priority and counter choices. Native mouse/Enter/Space purchases pass for all factions at 720p/150%. Layout review also exposed repeated factory selection collapsing the roster: six original failures now pass after a deferred refit; shared roster/advice checks and rendered blocked states pass. Final manual repeat-click review is limited by CUA returning a gray window after rediscovery; earlier native purchase flows succeeded. See [ground-defense verification](playtests/2026-10-06/GROUND_DEFENSE.md). Next: continue early-game interaction and retained opening-loss acceptance; full-match strategy remains open. Overall goal stays active and performance remains deferred.

- Fixed and verified 2026-10-06: paid conventional-armor retrofit in the opt-in reference commander. The original command loop interrupts fitting in all three factions; installation now survives ordinary orders and actual assault/regroup transitions, then enters a Running defense program. Exact fees, observed pressure, pause, refunds, service loss and death checks pass. Four paid matches complete with five installed and two refunded episodes, 67 installation-authority checks and one victory/three defeats. Native 720p/150% earned installation plus real Apply & run/Space succeeds without another fee. See [paid retrofit verification](playtests/2026-10-06/PAID_RETROFIT.md). Shipping rules and prior reference defaults remain unchanged. Next: inspect player-facing early-game advice and counter-production against the retained opening losses. Broader gameplay acceptance remains active; performance stays deferred.

- Audited 2026-10-06: earned first-contact defense. Observed-contact pursuit increases firing opportunities but loses the controlled opening; a Barracks-side anchor also loses. Four paid two-tank-before-lab observations finish with one Frontier victory and three defeats, so no default strategy, guidance or faction-stat change is accepted. Existing reference defaults and shipping behavior remain unchanged. Native first-contact continuations and shared recovery regression pass; full outcomes, losses, action traces and limits are retained in [defensive opening audit](playtests/2026-10-06/DEFENSIVE_OPENING.md). Next: test explicit paid retrofit of surviving conventional armor after unlock rather than relying only on newly produced fitted units. Wider strategy and gameplay acceptance remain open, and performance stays deferred.

- Completed and verified 2026-10-06: player Recover health command with role-appropriate full healing, Shift/remapped queues, program override/resume, tactical pause, service-loss handoff and blocked Skip. All-faction live infantry/ground/air checks and active/pending archive round trips pass. The pending-queue test exposed and fixed restored idle defense indefinitely holding an armed unit’s queue. Shared cargo/direct/orders/snapshot/restore and AI recovery checks pass, as do native all-faction mouse/keyboard flows at 720p/150%, mixed roster and expanded squads. See [recovery order verification](playtests/2026-10-06/RECOVERY_ORDERS.md). Next: improve weak defensive openings and wider full-match consistency using the retained earned failures. Overall gameplay acceptance remains open and performance stays deferred.

- Verified 2026-10-06: conventional infantry recovery through recommitment. The actual reference loop fails three earned-army checks before; with explicit treatment preservation it crosses the assault gate in 14 s and returns all four wounded infantry to assault by 36.5 s. All-faction threshold, observation, pause, service-loss/replacement and release checks pass. Two native earned continuations heal to full. Four paid Standard/Normal observations finish: Frontier victory/defeat at 1181.7/1061.0 s and Helix defeats at 967.8/434.2 s; no unresolved result or fifteen-second stationary trigger. There are 3181 treatment and 6713 engineer-authority checks without failure. This validates the reference handoff, not general strategy or faction balance. See [conventional recovery verification](playtests/2026-10-06/CONVENTIONAL_RECOVERY.md). Next: improve player-facing recovery usability using the verified service behavior, while retaining weak defensive openings and wider match consistency as open acceptance work. Shipping statistics are unchanged; the broader goal remains active and performance stays deferred.

- Fixed and verified 2026-10-06: crowded AttackMove arrival. The intact earned stall fails six assertions before and passes after sharing Move’s bounded friendly-endpoint observer; active combat resets observation. Paused exact disk state, legacy/corrupt records, queued handoff, distant endpoints, all-faction dynamic-blocker arrivals, shared Move/route-tail/orders/snapshot checks and native 720p/150% continuation pass. Native arrival takes 2.000 s without changing the assigned location. A separate earned-state probe leaves four wounded infantry unchanged under saved orders but heals all four to full with existing Barracks recovery. Next: preserve conventional treatment through the reference commander’s recovery/return-to-combat handoff and re-evaluate complete paid matches. See [crowded AttackMove verification](playtests/2026-10-06/ATTACK_CROWDED_ARRIVAL.md). Broader gameplay acceptance remains open; performance stays deferred and the overall goal remains active.

- Verified mechanism, strategy acceptance open 2026-10-06: spaced engineer retreat and safe alternative work. The original policy reproduces fifteen spacing/idle-income failures across three factions; the revised reference passes all-faction cargo/order/fog and real new-income checks. Native earned Frontier/Helix continuations each deliver four newly gathered materials. Four paid observations yield Frontier victory at 801.0 s and unresolved at 1800.7 s, plus Helix defeats at 343.6/806.6 s. Retained unresolved state exposes wounded conventional infantry holding the recovery health gate; a separate 16-second movement stall persists in intact replay but clears within five seconds in isolation. Next: verify crowded destination handling and the conventional recovery handoff from these archives, then improve the defensive opening without attributing policy failures to faction balance. See [safe work reassignment](playtests/2026-10-06/ENGINEER_REASSIGNMENT.md). Shipping rules are unchanged; broader gameplay acceptance remains open and performance stays deferred.

- Investigated 2026-10-06: sustained engineer economy under raids. Four complete paid Standard/Normal Frontier↔Helix matches and all-faction policy regressions pass their execution/control checks. Established Frontier won at 1193.3 s; protected Frontier lost at 457.6 s. Established/protected Helix lost at 529.1/802.1 s. Retreat reduced observed casualties but prolonged unsafe-field waits starved production; it is not accepted as an improved strategy. Earned withdrawal/delivery archives pass native 720p/150% review. Frozen-neighbor fixture stalls did not reproduce with normal avoidance; shipping movement and balance remain unchanged. Next: spread retreat destinations and evaluate safe alternative work under persistent raids, then repeat complete matches. See [engineer survival investigation](playtests/2026-10-06/ENGINEER_SURVIVAL.md). Broader gameplay acceptance remains open; performance stays deferred and the overall goal remains active.

- Delivered 2026-10-06: explicit Return cargo beside Move for engineers, with queue-key append, focused Enter/Shift+Enter, mixed-selection authority, current HQ/cargo revalidation and unavailable-state explanations. All-faction exact deposits, active disk restoration, queued follow-up and new gathering income pass, along with four shared suites and native 720p/150% mouse/keyboard flows. Corrected two cargo fixtures and the earlier audit's incomplete-airfield/max-icon-width assumptions; no roster tile geometry changed. See [cargo delivery verification](playtests/2026-10-06/CARGO_RETURN.md). Earlier full-match losses and broader strategy/pacing, novice/environment/platform acceptance remain open. Performance stays deferred; the overall goal remains active.

- Completed 2026-10-06: roster layout audit. The earlier clipping diagnosis was mistaken: all three factions' names/prices fit the existing three-column layout. Headless geometry and two rendered runs pass; six expanded-state 720p/150% captures were reviewed, including squad controls, worker cargo and paid queues. Shipping UI is unchanged. See [the audit and correction](playtests/2026-10-06/ROSTER_LAYOUT.md). Broader strategy/pacing, novice/environment/platform acceptance remain open; performance stays deferred and the overall goal remains active.

- Delivered 2026-10-06: contextual engineer raid response. The existing shortcut selects busy endangered engineers using current visible compatible threats or recent own damage, retains primary defender advice, and returns to idle selection when safe. Queued workers no longer appear idle. All-faction fog/role/cargo/order/pause/disk-archive and explicit retreat checks pass, as do shared guidance/direct-order suites and native 720p/150% selection, M/Escape and Frontier Move/resume. See [engineer response verification](playtests/2026-10-05/ENGINEER_RESPONSE.md) for original failures and corrected fixtures. Earlier full-match defeats remain unresolved. The suspected Helix construction-text clipping was subsequently disproved by the roster audit above. Broader pacing/strategy, novice/environment/platform acceptance remain open, with performance deferred.

- Delivered 2026-10-05: resource inspection and wreck readability. One observation-aware hover card shows deposit stock/work slots or wreck identity/materials/expiry/Frontier eligibility; persistent wreck labels are removed and aircraft ownership picking is fixed. Corrected input regression fails all nine resource/aircraft targets before and passes afterward across three factions. Fog, pause, depletion/expiry, disk archive, actual three-death cluster and exact salvage delivery checks pass, along with shared ownership/combat/salvage suites. Native earned-battle inspection passes at 720p/150%; matching three-wreck captures confirm the label-clutter improvement. See [resource inspection verification](playtests/2026-10-05/RESOURCE_INSPECTION.md) for invalid fixture runs, accepted evidence and limitations. Broader strategy, pacing, novice/environment/platform acceptance remain open; performance stays deferred and the overall goal remains active.

- Delivered 2026-10-05: live research progress and interruption feedback in the existing command message area. Active projects show progress/current-power ETA, lab-loss stalls remain visible, and affordable choices open the ordinary Tech screen. Orders and notices retain priority; human Coordination completion now uses the existing notice flow. The original missing-status scenario fails before and passes after for all three factions; paid timing/power/lab-loss/refund/archive/authority and shared research/guidance/subtitle checks pass. Native clicks and M/Escape on an earned research archive pass at 720p/150%, including exact stalled-project refund. See [research feedback verification](playtests/2026-10-05/RESEARCH_FEEDBACK.md) for fixture corrections and scope. Broader strategy, pacing, novice/environment/platform acceptance remain open; performance stays deferred and the overall goal remains active.

- Delivered 2026-10-05: actionable air-defense advice and a screened aircraft reference opening. Advice selects compatible defenders, completed local AA, explicit Helix stances or real construction/prerequisites while preserving fog, orders, pause and spending authority. Original wrong-unit selection fails before and passes after across all three factions; shared guidance/economy/weapon-mode checks and actual native selection/Interception input pass at 720p/150%. Four complete screened-air observations produce strike aircraft in three cases and finish 2 V / 2 D; the prior early-air references produced none. See [air-defense verification](playtests/2026-10-05/AIR_DEFENSE.md), including rejected runs and fixture corrections. Frontier versus Helix still collapses early, and Helix versus Frontier struggles to sustain aircraft/research. Broader strategy, pacing, novice/environment/platform acceptance remain open. Performance stays deferred; the overall goal remains active.

- Delivered 2026-10-05: paid research and army progression. AI harvesting demand now includes eligible unpaid research, and routine armor protects that budget while construction and urgent production retain precedence. The original population-cap deadlock fails before and passes after for all three factions; the labor regression preserves its original earning deadline and separately verifies additional paid research. Shared economy/technology/signature/coordination checks pass. Ten Standard/Normal Coastal matches reach outcomes with explicit ground-first/air-first policies; several ground-first runs complete paid upgrades and use abilities, while all four early-air references lose before research matures. Actual native Tech/Escape/Maneuver input on an earned archive passes at 720p/150%, including program authority, pause and normal-clock research. See [paid progression evidence](playtests/2026-10-05/PAID_PROGRESSION.md) and the reusable match runner. Recorded outcome variation and 5–19-minute matches leave broader strategy/pacing, novice/environment/content/platform acceptance open. Performance stays deferred; the overall goal remains active.

- Delivered 2026-10-05: advanced-base harvesting routes and delivery-boundary handoffs. Ground path simplification removes redundant steering points around the settled repair robot; AI workers queue their next field during a loaded return and switch after actual delivery. The original two-faction labor scenario passes three final repetitions with its funding/rebalance deadlines unchanged. Captured traffic, cadence/archive/manual checks, shared geometry/economy/AI suites and normal-clock rendered review pass. Two older movement fixtures now distinguish simplified paths and active guard re-entry from their respective arrival contracts. See [harvesting verification](playtests/2026-10-05/HARVEST_TRAFFIC.md) for all original failures, discarded candidates and bounded results. Next: repeated paid research/army progression and different Frontier strategies, then broader pacing, novice/content/platform acceptance. Performance stays deferred; the overall goal remains active.

- Delivered 2026-10-05: Frontier AI follow-up — canonical paid tank fitting/lab-loss fallback, observed-contact Maneuver during travel/retreat and cargo-preserving safe home salvage. Targeted original failures now pass, as do shared budget/coordination/signature/archive checks after two invalid test placements were corrected. Six Normal Coastal complete matches reach actual outcomes; Advanced Frontier AI delivers 4 M / 20 M salvage and uses 32 / 31 Maneuver cohorts. See [AI and full-match evidence](playtests/2026-10-05/FRONTIER_AI.md). Single-run outcomes do not establish balance. The unchanged Labor suite still misses its 100-second funding deadline; controlled probes identify advanced-base harvesting traffic. Next: address that original traffic scenario, then repeated paid progression/strategy checks. Overall goal remains active; performance stays deferred.

- Delivered 2026-10-04: Free Frontier gameplay integration and initial functional acceptance (stages 2–3): selectable seventeen-model roster, paid 2 E / 3 s retrofits, finite observed wreck collection/return, Maneuver Burst/Rapid redeployment, AI and program support, version-8 archives and stable-ID preference migration. Four-map Standard economy/travel/restoration, nine faction pairings, all-three-faction paid research and arena authority, actual heavy-cannon/AA hits and native battle-control checks pass. See [Frontier gameplay verification](playtests/2026-10-04/FRONTIER_GAMEPLAY.md) for exact evidence and interface limits. Independent review found and fixed paused-load wreck visibility, with a regression proving observed/hidden world and minimap states before resume. Initial balance is not final competitive/novice acceptance; overall goal remains active and performance stays deferred.

- Delivered 2026-10-04: Free Frontier roster stage 1 — seventeen editable models, articulated GLBs, transparent icons and reviewed Blender/native 720p catalogues. All GLB reimport/topology/bounds/material/pivot/icon and real Godot normalization/articulation checks pass; corrected rotor names, numerical triangle slivers and native review framing. See [Frontier asset verification](playtests/2026-10-04/FRONTIER_ASSETS.md). Stage 2 gameplay/salvage/retrofit/ability/AI/archive integration and stage 3 actual-match acceptance remain unfinished; Frontier is not selectable yet. The preceding arena-research turn and this roster stage both make concrete progress; the overall goal stays active and performance remains deferred.

- Delivered 2026-10-04: research-aware program arena with captured completed upgrades, selectable unupgraded comparison, fresh restart stats and research-labeled returned/saved evidence. The preserved prior arena fails 16 corrected assertions; both-faction real-unit effects/authority, four shared suites and native 720p/150% selection, restart and actual child launch/return pass. Active research, funds and orders stay unchanged in the paused live match. See [arena research verification](playtests/2026-10-04/ARENA_RESEARCH.md). The preceding turn delivered classic RTS research; this turn connects it to trustworthy program testing. Broader gameplay/content acceptance stays open; performance remains deferred.

- Delivered 2026-10-04: paid classic RTS research with weapon/armor tiers, faster field service and stronger faction abilities, shared Coordination queue, strict version-7 archives with older-save support, selected-lab/global Tech controls and same-cost AI research. Both-faction combat/production/healing/ability/adverse/archive and native 720p mouse/keyboard checks pass. See [technology verification](playtests/2026-10-04/TECHNOLOGY.md). Initial research balance and broader gameplay/content/platform acceptance remain open; the overall goal stays active.


- Delivered 2026-10-04: conventional armor before an unpaid lab, then surviving-vehicle retrofit guidance that respects paid queues and installation. Both-faction actual production/manual movement/retrofit/program/archive and native advice-selection checks pass. The comparable Coastal trials finish with Bastion/Helix victories at 755.4/991.6 seconds and no coordination violations across 3,494 samples; two separate Desert trials lose before a first program. These are limited strategy observations, not pacing or balance acceptance. The intermittent harvesting deadline remains open; performance remains deferred.


- Delivered 2026-10-04: actionable matching-service recovery guidance, verified paid construction/healing/archives, and reference-commander electronics replacement plus depot investment. [The report](playtests/2026-10-04/RECOVERY_GUIDANCE.md) retains before failures, sixteen valid shared passes, twenty-four reviewed captures and ten Standard trials. The final Bastion victory and early Helix defeat do not establish pacing; inspect the Helix opening next. The original harvesting deadline remains unreproduced and open. The preceding turn fixed endpoint arrival; this turn improves recovery guidance and corrects test-commander labor. Broader goal stays active; performance remains deferred.

- Delivered 2026-10-04: short-route crowded arrival and preserved archive observation. [The report](playtests/2026-10-04/ENDPOINT_TAIL.md) retains before failures, corrected captured/fresh/queue/adverse checks, four reviewed spectator captures and four complete matches. The shared run is 32/33 passing; the intermittent harvesting deadline remains open rather than being hidden by passing reruns. The preceding turn fixed corner recovery; this turn removes a separate path-index assumption. Broader gameplay goal stays active, including strategy/pacing and content acceptance; performance remains deferred.

- Completed 2026-10-04: Coastal corner recovery, navigation-ready restoration and arrival-before-timeout. [The report](playtests/2026-10-04/CORNER_RECOVERY.md) retains original failing comparisons, 31 shared passes, nine rendered captures and four final matches with 3,566 valid coordination samples. Two wins/two losses do not establish balance or pacing. A different Industrial AI tank remains blocked in plain Move in a retained thirty-second replay; diagnose that next. This turn made runtime changes and completed verification, following the previous handoff fix. Overall goal stays active; performance remains deferred.

- Completed 2026-10-04: AI regroup arrival now retires stale attack-move after task removal. Both-faction before/after probes, all three difficulty budgets, archive/authority checks, nine shared suites and rendered review pass. [The report](playtests/2026-10-04/COORDINATION_HANDOFF.md) retains ten full matches across original/corrected runtime and the still-unexplained older membership observations. The corner blockage now has a reliable three-run replay and controlled neighbor-removal evidence identifying repair-robot interference; intact-scene navigation remains unresolved. The previous turn fixed occupied-center guard arrival; this turn fixes a separate coordinator handoff. Overall goal stays active and performance remains deferred.

- Completed 2026-10-04: occupied-center guard formation arrival and bounded verification. [The report](playtests/2026-10-04/GUARD_ARRIVAL.md) preserves before failures, seven corrected traffic replays, fresh multi-authoring/faction checks, seventeen shared passes and rendered review. Four Coastal Advanced results are one victory/three defeats; one coordination check fails and an opening corner blockage remains captured for follow-up. The previous goal turn supplied regional match evidence; this turn fixes one demonstrated runtime cause without declaring general congestion or balance solved. Overall goal remains active; performance remains deferred.

- Completed 2026-10-04: Industrial/Coastal contested-match study and reference-commander retreat correction. Both-faction original HQ-center captures, later occupied-point reassignment, paused authority, matched service and onward advance pass. All 24 matches finish across three retained revisions; final mixed outcomes, guard blockage and a shorter uncaptured movement delay keep strategy/pacing and congestion acceptance open. See [regional match evidence](playtests/2026-10-04/REGIONAL_MATCHES.md). No shipping combat/economy/map rules changed; performance remains deferred and the broader goal stays active.

- Completed: ownership readability stages 1–3 — own circles/opponent triangles, current-observation hover labels, matching minimap shapes and a persisted world-symbol preference. Original both-faction missing indicators fail before implementation; identical-color/faction, fog/memory/death, aircraft/buildings, pause, options and disk restoration pass. Ten headless suites, the dedicated mouse/keyboard workflow and shared scaled interface/all-six-campaign rendering pass. See [ownership verification](playtests/2026-10-04/OWNERSHIP.md). Physical-device, screen-reader/novice, wider content/balance and release gates remain open; performance stays deferred and overall goal remains active.

- Completed: Industrial Crossroads surroundings stages 1–3 — five editable assets, rail/service/utility yards, 23 exterior placements, birch scrub, continuous terrain and opt-in ground/building wear. Imported bounds, level foundations, seams, navigation isolation, both-faction three-lane 48-tank advance/retreat, economy, construction, relays, aircraft and archives pass. Shared Foundry/AI/ambient/audio/startup/combat restoration and actual 720p/900p fog/combat/pause checks pass. See [Industrial surroundings verification](playtests/2026-10-04/INDUSTRIAL_SURROUNDINGS.md). Final art, broader match balance/novice/platform/release acceptance remain open. Performance remains deferred; overall goal remains active.

- Completed the Coastal Foundry environment follow-up: continuous sea and coastal relief, headlands/breakwaters, freight/maintenance/utilities, wind-shaped pines and weathered working surfaces replace the bare rectangular surround. Six editable assets and 28 exterior placements preserve interior route/clearance contracts. Nine headless suites, normal-clock both-faction combat/fog review and import/static checks pass; all ten final captures were reviewed. See [verification](playtests/2026-10-04/COASTAL_ENVIRONMENT.md). Subjective final art, wider regional polish, broader strategy/novice/platform acceptance, third-faction content and release gates remain open; performance stays deferred and the overall goal stays active. The previous goal turn made verified blocked-assignment/persistence progress; this turn addresses the explicitly requested environment depth.

- Completed blocked-assignment clarity: the retained tank archive is a valid inaccessible point inside a friendly aircraft factory. Added specific reassignment feedback and fixed missing Lua guard boundaries on paused reload. Captured Bastion and fresh Helix built-in/Lua/visual recovery, archive type/compatibility/authority checks, nine shared suites and six reviewed 720p/150% mouse-flow captures pass. See [verification](playtests/2026-10-04/BLOCKED_ASSIGNMENTS.md). Earlier match results remain historical; this pass does not establish broader movement, strategy, novice or release acceptance. Performance stays deferred and the overall goal stays active. The previous goal turn made verified arrival/commander progress; this turn resolves its retained case and improves recovery feedback/persistence.

- Completed crowded point-arrival and reference-commander continuity: a captured seventeen-second infantry blockage now ends beside the occupied friendly endpoint and permits ordinary treatment/queued work. Original six-failure replays, enemy/distance limits, paused disk handoff, twelve shared suites and reviewed 720p/150% treatment captures pass. The reference commander also continues idle reinforcements/waypoints without interrupting fire. Eighteen complete matches separate diagnostic, proactive/staged, allocation and responsive-guard policies; final-runtime Bastion/Helix trials win at 13:04.6 / 6:38.0 with sampled stationary travel at most 2.5 seconds. See [arrival verification](playtests/2026-10-04/CROWDED_DESTINATION.md) and [the operation study](playtests/2026-10-04/MIXED_OPERATIONS.md). One earlier authored Blocked archive remains a separate route/commander follow-up. Broader strategy/pacing, novice/accessibility/platform, remaining content and release gates remain open; performance stays deferred and the overall goal stays active. The previous turn clarified direct commands; this turn fixes an endpoint blockage exposed by longer mixed-force play.

- Completed explicit direct commands: Move [M], Attack target [T] and Attack move [F] buttons/shortcuts, exclusive targeting, queued manual orders and preserved legacy custom controls. Both-faction live semantics, archives, 720p/150% mouse/keyboard/held-death checks and seven reviewed captures pass. Shared verification exposed delayed final cargo near HQ; sustained route-progress recovery preserves valid detours, contact range and cargo conservation. See [direct-command verification](playtests/2026-10-04/DIRECT_ORDERS.md). The previous turn improved mixed selection; this turn clarifies movement versus fighting orders. Strategy/balance, novice/accessibility/platform, remaining content and release gates remain open; performance remains deferred and the overall goal stays active.

- Completed mixed-selection controls: faction type counts, live damaged totals, stable paged health tiles, type/unit/damaged filtering and remappable subset removal. Fixed mouse-release fallthrough both during filtering and when a held tile loses its unit; unrelated keyboard input does not cancel that protection. Nine headless suites, actual 720p/150% mouse/Enter workflows, both 140-unit rosters, mission roles, disk archives and seven reviewed captures pass. See [mixed-selection verification](playtests/2026-10-04/SELECTION_ROSTER.md). Commands, squads, programs, paid production and pause remain intact. The previous turn improved purchase information; this turn improves mixed-force visibility and control. Strategy/balance, novice/accessibility/platform, remaining content and release gates stay open; performance is deferred and the overall goal remains active.

- Completed roster information: locked and unaffordable cards retain faction-specific roles, total/missing resources, prerequisites, chip/power-aware production time and capacity reasons. Wrapped hover cards and matching accessibility descriptions preserve purchase authority. Eight suites, both-faction input workflows, paid-job archives and ten reviewed 720p captures pass. Four new Advanced Desert matches isolate aircraft reservations and ground-count gates; all lose despite a larger counterfactual ground force. See [the roster and readiness report](playtests/2026-10-04/ROSTER_INFORMATION.md). Strategy/pacing, novice/screen-reader/platform, remaining content and release gates stay open; performance remains deferred and the overall goal remains active. The previous turn fixed authored guards; this turn improves unit/spending information and narrows the strategy investigation without changing balance values.

- Completed authored area defense: new Lua and visual guard starters retain legal firing positions, approach observed enemies within the assigned area and return after sector exit. Saved sources, manual authority and retreat hysteresis remain intact. Twenty shared checks, four rendered workflows and eighteen reviewed captures cover both factions, armed roles, archives and actual editor/assignment input. Five complete matches yield four Advanced defeats and one Standard victory; commander readiness gates and sustained mixed-force strategy remain open. See [the authored guard report](playtests/2026-10-04/AUTHORED_GUARD.md). Performance remains deferred; the overall goal stays active. The previous turn fixed scaled HUD clearance; this turn fixes authored defenders crowding their anchor instead of firing.

- Completed scaled HUD clearance: subtitles avoid actual map/command bounds, and oversized unit panels scroll below the top HUD with keyboard focus support. Six campaigns at all three interface sizes, both factions/four skirmish maps, live window resize, the existing interface workflow and eight shared suites pass. [The report](playtests/2026-10-04/CAMPAIGN_SCALE.md) retains both original UI failures and the final evidence. Physical-device/platform and broader accessibility, pacing/strategy, content/mixing and release gates remain open. Performance stays deferred; the overall goal remains active. The previous turn fixed notice-driven mission-button movement; this turn fixes caption overlap and oversized selection controls.

- Completed campaign control stability: notices no longer move mission controls; long feedback supports wheel and keyboard scrolling while assignment priority remains intact. The original held-click failure is reproduced and fixed. All six real campaign layouts clear their actual minimaps at 720p, four final shared suites pass, and slow-click plus two full archive/replay flows pass. Native pointer interference and a nondrawable capture window are distinguished from product layout failures. [The report](playtests/2026-10-04/CAMPAIGN_CONTROLS.md) retains initial failures and final evidence. Physical-device/all-scale/platform, pacing, strategy, novice, content, mixing and release gates remain open; performance is deferred and the overall goal stays active. The previous goal turn delivered environmental audio; this turn fixes the campaign control movement discovered by its input follow-up.

- Completed audio delivery: four regional beds across all core skirmish/campaign maps, observed neutral carts/tugs/gulls, independent Ambience volume/sample and bounded mix/lifecycle behavior. Eight WAVs reproduce exactly; sixteen shared suites and normal-clock real output/720p controls pass. Fixed a reproduced Split Signal map-loading break after Alpine art changes; mission victory/routes/archives pass, and relay titles no longer compete with 3D labels or HUD panels. Some later synthetic campaign mouse clicks still fail intermittently; bounded timing/menu probes do not establish the cause, so that input gate remains open. [The report](playtests/2026-10-04/ENVIRONMENT_AUDIO.md) retains all outcomes. Broader mixing, content, pacing, novice and release acceptance remain open; performance stays deferred and the overall goal remains active.

- Completed this recovery slice: fixed facility-center recovery deadlocks for built-in presets, Lua and visual rules, including the reproduced service-boundary crowd failure, and corrected reference infantry recovery. Nineteen shared suites, three final crowd trials and twelve reviewed 720p/150% captures pass. All eight final matches finish (three wins/five losses), with nine authored recovery returns and no authored Blocked state; 9,074 coordination samples show no task/order violations. A 25:42 defensive loss and all four Advanced authored-policy losses keep pacing/strategy acceptance open. Earlier thirty-minute cause, uncaptured movement episodes, content and release work remain open; performance is deferred. See [the recovery report](playtests/2026-10-04/PRESET_RECOVERY.md).

- Completed: captured static-target contact recovery and bounded verification. The Alpine engineer chooses a reachable free work face and collects within 5.8 seconds in three exact replays. Existing range, speed, footprint, finite stock, manual replacement and mid-detour disk restoration hold; both factions pass crowded delivery/construction and occupied-target handling. Twelve shared suites and three reviewed 720p/150% captures pass. [The report](playtests/2026-10-04/CONTACT_APPROACH.md) retains all eight follow-up trials: three human-policy wins, four losses and one unresolved thirty-minute Alpine match, with no fifteen-second movement capture or task/order violations across 9,961 samples. Completed matches last 5:27.2–10:57.1. Next: investigate the unresolved policy recovery/recommitment and broader ordinary pacing; earlier uncaptured movement episodes, content and release gates remain open. Performance stays deferred and the overall goal remains active. The previous goal turn delivered global AI coordination; this turn corrects the captured contact approach without claiming general deadlock freedom.

- Completed: global AI coordination stages 1–4. Story/Standard/Veteran share one/two/three combat tasks with observed-defense preemption, stable cores, bounded rotation, attached support and protected recovery. Guard retirement preserves cargo, interrupted fields resume actual new-cargo delivery and strategic goal updates preserve prepared fire. Current/legacy disk archives, 21 final suites and four rendered captures pass. [The report](playtests/2026-10-04/AI_COORDINATION.md) retains original failures, interim cohorts and eight final complete matches with zero task/order violations in 7,998 samples. Final pacing is 4:41.4–13:34.3 (five human-policy wins/three losses), below the 20–30-minute hypothesis. A new 16.5-second Alpine human-engineer delay now has an exact archive and bounded crowded/isolated replays; its cause and the two earlier episodes remain open. Next: investigate the captured movement scene, then ordinary pacing and sustained contested mixed-force play, followed by novice/content/release acceptance. Performance stays deferred; the overall goal remains active. The previous goal turn improved movement diagnostics; this turn delivers global coordination and a captured live movement case.

- Completed: bounded intermittent-movement investigation and capture/replay tooling. Four complete matches and 32 final two-faction/two-map crowd trials do not repeat the two recovery-cohort delays. A separate shared-terminal fixture, its archive, an inherited fixture timeout and ownership/destination corrections are all retained in [the report](playtests/2026-10-04/MOVEMENT_DIAGNOSTICS.md). Exact archive-unit selection, nearby-agent/avoidance traces, live disk capture/restore, old and new archive replays and CLI failures pass. Production movement is unchanged; the original two causes remain open. Keep first-failure capture enabled while continuing global AI coordination and ordinary pacing, then novice/content/release gates. Performance stays deferred and the overall goal remains active. The previous goal turn delivered AI recovery; this turn adds diagnostic evidence and a reliable replay route.

- Completed: AI recovery and recommitment stages 1–4. Critically damaged military units use matching safe facilities and keep recovery authority until 80% health, then resume eligible combat/support/recon/relay duties. Both-faction real healing, three disk-archive phases, provider loss/danger/retry, fifteen shared suites and four rendered captures pass. [The report](playtests/2026-10-04/AI_RECOVERY.md) retains eight complete matches with 36 completed recovery episodes, 40 losses and three active episodes, plus four diagnostic matches. Two original long ordinary-movement stalls remain unresolved after negative reproductions; retain live failure archives in subsequent matches. Next: diagnose those intermittent stalls, then broader army coordination and ordinary pacing, followed by novice/content/release gates. Performance stays deferred and the overall goal remains active. The previous goal turn delivered adaptive economy; this turn delivers recovery progress.

- Completed: adaptive AI labor and mixed-production budget stages 1–4. Original first-wing budget failures now pass; priorities preserve worker recovery/counters/support/aircraft, and cargo-boundary handoffs adapt the six-worker economy to current deficits. Both-faction paid tank/aircraft completion, disk restoration, guarded dual-resource income, live raids, eleven shared suites and six normal-clock captures pass. [The report](playtests/2026-10-04/AI_ECONOMY.md) retains all eight final outcomes: three human-policy wins/five losses, 5:20.4–18:37.5, at most three seconds of stationary travel. Next: sustained contested mixed-force strategy, broader coordination and ordinary pacing, followed by novice/content/release gates. Performance stays deferred and the overall goal remains active. The previous goal turn delivered protected expansion; this turn delivers adaptive economy progress.

- Completed: protected AI expansion stages 1–3. A bounded field guard precedes remote harvesting and stays through cargo trips; visible threats cause cargo-preserving withdrawal. Both-faction/two-map actual income, live raids, paused disk restoration, separate defense/wave duties, nine shared suites and normal-clock rendered checks pass. [The report](playtests/2026-10-04/AI_EXPANSION.md) retains eight complete outcomes (five human wins/three losses, 4:51.3–13:55.8). Next: adaptive resource allocation and production reserves for sustained mixed forces, broader coordination and pacing, then novice/content/release gates. Performance stays deferred and the overall goal remains active.

- Completed: economy guidance under pressure stages 1–3. Visible raids/recent economic damage take priority over depleted-field reassignment, and faction-cost-aware advice identifies missing material/electronics income without taking control of engineers. Both-faction actual harvesting, paid fitted-tank completion, paused disk restoration, shared checks and normal-clock 720p/150% controls/rendering pass. [The report](playtests/2026-10-04/ECONOMY_SUPPLY.md) distinguishes these home-economy checks from contested expansion and sustained mixed-force allocation, which remain next. Broader coordination, pacing and novice/content/release gates remain open; performance stays deferred and the overall goal is active.

- Completed: strategic offensive objectives stages 1–3. Ground waves are no longer diverted toward scouts above their own base; observed economic goals and public-base fallback preserve fog and scheduling. Original archive failures, real departures, paused disk restoration, engineer delivery, repeated replays and 720p/150% rendering pass. [The report](playtests/2026-10-04/AI_OFFENSE.md) retains eight complete outcomes (four wins/four losses, 5:17.2–17:30.9), slow-exit diagnostics and the thirty-second bounded departure check. Next: protected expansion, economy allocation for mixed forces and broader strategy/coordination, then novice/content/release gates. Performance stays deferred and the overall goal remains active.

- Completed: observed-composition production stages 1–3. Current armed contacts drive faction-appropriate counters and earlier AA construction, with owned/queued quotas and exact reserves. Both-faction actual paid production/construction/interception, disk restoration, 720p/150% rendering and shared checks pass. [The report](playtests/2026-10-04/AI_COMPOSITION.md) retains fourteen complete trials, including final three wins/five losses at 9:01.9–16:45.3. Next: fix ground offensive waves diverted toward untargetable scouts, replay the retained ground/engineer delay archives, then protected expansion and broader strategy/coordination. Performance remains deferred; the overall goal is active.

- Completed: observed-threat AI defense and supported-group allocation, including ground/air counters, independent offensive/relay duties and no hidden tracking. Both-faction actual interception, pause/archive, normal-clock 720p/150% review and shared checks pass. [The report](playtests/2026-10-04/AI_DEFENSE.md) retains all sixteen full-match outcomes, with final durations 5:45.5–11:03.2. Next: protected expansion, mixed-force/counter-production strategies and broader AI coordination; novice/content/release gates remain open. Performance stays deferred and the overall goal remains active.

- Completed: Guard now responds throughout its assigned area instead of searching only near weapon range. The before/after reproduction, both-faction boundaries/authority/retreat/archive, rendered 720p/150% review and shared checks pass. [The report](playtests/2026-10-03/GUARD_AREA.md) retains four Advanced policy victories with surviving economies and notes timing variability. The matches remain 6–8 minutes; next work is protected expansion, mixed compositions and strategic enemy responses. Broader novice/content/release acceptance remains open; performance is deferred and the overall goal remains active.

- Completed: programming advice survives larger armies; tactical advice now covers economy defense, recovery, scouting, observed opposition and rebuilding. Fixed recursive mixed-producer menus and UI shortcuts misread as world double-clicks. Both factions pass paused/save-load, fog, scaled mouse/keyboard, paid production and shared checks. [The report](playtests/2026-10-03/BATTLE_PLAN.md) retains twelve strategic-policy trials, including the final one-win/three-loss repetition and ongoing short pacing. Next: protected expansion, army composition/counters and strategic AI responses; novice and broader content gates remain open. The previous turn prevented AI construction from closing engineer exits. Performance stays deferred; the overall goal remains active.

- Completed: captured the empty-path recurrence and reproduced a construction-closed navigation island. AI placement now preserves access gaps; the archive-based before/after regression verifies actual delivery, speed bounds and paused disk restoration. Both-faction AI economies, shared support/skirmish/crowd tests, normal-clock 720p spatial review and eight complete matches pass. [The report](playtests/2026-10-03/BASE_ACCESS.md) retains the archive, logs and limitations. Old closed layouts remain unchanged. Next: strategy and pacing beyond the fixed commander, then remaining content/novice acceptance; avoid treating repeated clean matches as a universal navigation guarantee. The previous turn corrected crowd-boundary velocity feedback. Overall goal remains active; performance stays deferred.

- Completed: the archived intact-path crowd failure is corrected by feeding applied velocity back to avoidance after navigation projection. Three archive replays, both-faction traffic/midpoint save-load, shared crowd/resource/combat/order/Lua/motion checks and normal-clock 720p review pass. Twelve follow-up matches complete; one has a separate 548-second empty-path stall, unreproduced in six subsequent Desert diagnostics. [The report](playtests/2026-10-03/CROWD_BOUNDARIES.md) preserves the trace and richer diagnostics for the next occurrence. Next: capture and resolve that remaining no-path state, then broader strategy/pacing/content work. The previous turn delivered repair/arrival fixes, service UI and the 24-match evidence set. Overall goal stays active; performance remains deferred.

- Completed: repeated-skirmish evidence pass — 24/24 full outcomes, 11 Standard wins/1 loss and 12 Advanced losses, plus a normal-clock 9:47.5 rendered victory. Fixed AI support eligibility/target allocation, building-footprint repair reach and occupied attack-move completion; both-faction repair/program/queue/archive and shared combat/order/Lua checks pass. Facility/mobile service details fit 720p. [The report](playtests/2026-10-03/SKIRMISH_MATRIX.md) retains full metrics, strategy/pacing limits and a saved crowd/boundary avoidance failure. Next: fix that reproducible movement case before broader strategy/pacing tuning. The previous turn delivered Alpine environment/readability. Overall goal remains active; third-faction content, environmental audio, novice/release acceptance remain open and performance stays deferred.

- Completed: Alpine Relay environment follow-up with ten editable granite/snow/conifer/station assets, surrounding mountains, coherent plowed routes and clearer relay labels. Both factions pass all six aircraft crossings, three 16-tank advances/retreats, moving and partial-capture archives, geometry/sight/fire, both starting/outer economies and construction. Normal-clock Metal captures pass ordinary fog/hidden bases, active/paused combat, real infantry capture/recapture, enemy tank contest and actual 720p/900p output. Shared combat, formatting/lint and editor import pass. See [alpine environment verification](playtests/2026-10-03/ALPINE_ENVIRONMENT.md). Broader regional composition/audio, third-faction content, novice/full-match balance and release gates remain open. Performance optimization stays deferred; the broader goal stays active. The previous goal turn delivered desert environment and crowded-tank movement work; this turn delivers alpine environment and objective readability.

- Completed: Desert Frontier environment follow-up with ten editable sandstone/freight assets, canyon surroundings, low ruins/scrub, continuous worn ground materials and revised lighting. Imported bounds, seamless boundary geometry/normals, original shelf sight/fire, both-faction actual aircraft, three 16-tank routes, economy, placement and moving archives pass. Repeated retreats exposed waypoint backtracking under crowd avoidance; combined intermediate tolerance and earlier replanning pass four alternating-faction 48-tank runs at the original deadlines, shared 12-tank arrivals and Alpine checks. Reviewed ordinary-fog/hidden-base, active/paused combat and actual 720p/900p captures; other maps retain their fog setting. See [desert environment verification](playtests/2026-10-03/DESERT_ENVIRONMENT.md). Broader environment/novice/full-match/release acceptance remains open. Performance stays deferred; overall goal remains active. The previous turn delivered interface scaling; this turn delivers environment and movement progress.

- Completed: interface sizes 100/125/150% with persisted preview/rollback/defaults, Canvas Items rendering and expanding aspect layout. Both factions pass normal-clock rendered panel, five-job production, minimap/attack-target, alerts, subtitle, Lua/visual-editor, archive and settings input checks; main/setup/campaign/result and exact 720p/900p/1080p captures pass. Arena now shares scaling and stays windowed through a pending fullscreen request; its missing-voice subtitle startup error is fixed and regression-tested. First Orders world labels render behind commands and hide clipped labels. Shared settings, bindings, archives, speech and both-faction arena rules pass; format/lint/whitespace checks are clean. See [interface scaling](playtests/2026-10-03/INTERFACE_SCALE.md). Direct physical-device/cross-platform acceptance, broader accessibility, environmental audio, novice/full-match balance and release work remain open. Performance stays deferred; the overall goal remains active.

- Completed 2026-10-03: navigable battle alert stages 1–3 automated/rendered scope — bounded human history, squad/area casualty grouping, current worker/field/power/paid-queue conditions, debounced/resolved/read states, stable rows and paused unit/location inspection. Both factions pass real economy/combat/production transitions, paused reassignment/refunds and archive reconstruction. Rendered 720p/900p controls/campaign/results and thirty-second normal-clock pause pass. Fixed a power-bar refresh gap exposed by immediate tactical pause. See [alert verification](playtests/2026-10-03/BATTLE_ALERTS.md). Direct native input remains open after a guarded-input/window failure and inconclusive native pause result; independent pause checks pass. Broader gameplay/content/release goal stays active; performance remains deferred.

- Completed 2026-10-03: combat sound stages 1–3 automated/rendered scope — eleven original reproducible weapon/impact/destruction cues, current observation and camera filtering, stereo attenuation, 24-player priority/merge bounds, audible-speech ducking, Effects volume/sample and output limiters. Both factions pass actual attacks/casualties, pause/mute, saturation and damaged-battle disk restoration. Normal-clock Metal captures verify nonzero/stereo output, playback freeze/thaw, live fog loss and bounded peak levels; settings sample input/layout passes. See [combat audio verification](playtests/2026-10-03/COMBAT_AUDIO.md). Subjective listening/final mixing and environmental audio remain open; the broader gameplay/content/release goal stays active and performance optimization stays deferred.

- Completed 2026-10-03: speech accessibility stages 1–3 automated/rendered scope — all 14 existing voice lines, shared priority/repeat/stale-queue delivery, actual-hit warnings, reconstruction suppression, result protection, persisted subtitle visibility/size and sample, and mouse-transparent 720p/900p captions. Both factions pass real combat/casualty/paid-production, mute/pause, options rollback/write failure and damaged-battle disk restoration. Normal-clock rendered speech/input/freeze/layout, shared settings/controls/combat/save-slot/legacy/skirmish suites and read-only review pass. See [speech verification](playtests/2026-10-03/SPEECH_ACCESSIBILITY.md). Direct native/platform input, general HUD scaling, richer audio and navigable alerts remain open. Overall gameplay/content/release goal stays active; performance optimization remains deferred.

- Implemented 2026-10-03: keyboard control accessibility stages 1–2; stage 3 automated/rendered verification passes. Controls covers 31 actions, conflict/reserved-key feedback, physical chords, queue composition, reset, live hints, persistence and deep rollback. Both factions pass remapped commands, paused groups, modifier transitions, focused HUD shortcuts, text isolation and quicksave/load. Rendered Controls/General settings fit 720p. Direct native input remains pending after bounded computer-use recovery failed; scalable HUD/subtitles, broader content and release acceptance remain open. See [controls verification](playtests/2026-10-03/KEY_CONTROLS.md). Performance remains deferred; overall goal stays active.

- Completed 2026-10-03: Coastal Foundry stages 1–3 — selectable 128×104 harbor, quay/inland approaches, land-only ground navigation/construction, aircraft shortcut, paired economy, six editable coastal assets, ground/water treatment and 13 moving neutrals. Both factions pass two 16-tank advances/retreats, home/outer returns, paid construction, all 11 landmark crossings and moving/raised-aircraft archives. Eight paired field checks, six-map ambient/archives, six-minute AI economy/attacks, native selection/Start Battle and rendered 720p/900p review pass. Basic-tank path estimates are 51.1 / 22.5 seconds. See [Coastal verification](playtests/2026-10-03/COASTAL_FOUNDRY.md). All four core map contracts now have playable implementations; broader regional composition, off-map surroundings, audio, contested full-match balance and release acceptance remain open. Performance stays deferred; overall goal remains active.

- Completed 2026-10-03: resource-navigation reliability stages 1–3 — reproduced and fixed the 0.2 m bake / 0.6 m avoidance mismatch, bounded gathering/delivery/building contact to the reachable navmesh boundary, and gave each battle its own ground navigation lifetime after reproducing displaced deposits during map switches. Both-faction narrow/open passage, exact trapped-position/cargo archives, depletion, 68 paired field-return checks on 11 maps, crowded navigation/construction, shared field/save-slot/combat archives and Industrial routes pass. Native 720p movement/collection/full cargo return also pass. See [resource-navigation verification](playtests/2026-10-03/RESOURCE_NAVIGATION.md). Previous goal turn delivered Industrial Crossroads; its updated path estimates are 45.1 / 20.5 seconds. The older-map deposit audit is complete for these access scenarios. Coastal Foundry, wider environments, repeated full-match balance and release acceptance remain open. Performance stays deferred; overall goal remains active.

- Completed 2026-10-03: Industrial Crossroads stages 1–3 — five editable industrial assets, three-street skirmish map, paired fields, two vision relays and 14 moving neutrals; menu/minimap/archive integration; kit reuse and real roof clearance in Broken Foundry. Both factions pass 16-tank advances/retreats, home/outer economy, paid construction, capture and archives; six-minute AI builds/produces/attacks, five-map neutral behavior and every roof's drone/strike-aircraft traversal pass. Fixed a reproduced loaded-engineer trap by widening the new map's deposit gaps; final path estimates are 44.9 / 24.1 seconds. Native selection/Start Battle pass, and Foundry's full suite wins at 157.90 seconds. See [Industrial verification](playtests/2026-10-03/INDUSTRIAL_CROSSROADS.md). Previous goal turn delivered moving neutrals. Coastal Foundry, older-map deposit-spacing audit, broader environment composition and complete-match/novice acceptance remain open. Performance stays deferred; overall goal remains active.

- Completed 2026-10-03: living-map stages 1–3 — original neutral cars, articulated residents and foxes; authored routes on Horizon/Foundry/Alpine/Desert; yielding and car following clearance; current fog/LOS; tactical pause; exact version-6 archives with legacy defaults. Four-map behavior/hostile archive checks, weapon and field migrations, Horizon environment regressions and native/rendered review pass. See [living-map verification](playtests/2026-10-03/AMBIENT_LIFE.md) and its moving preview. Industrial Crossroads layout, broader building-kit rollout, regional life variety and final environment acceptance remain open. Performance optimization remains deferred; overall goal stays active.

- Completed on 2026-10-03: first Command Horizon environment kit pass, with six editable Blender assets, three distinct industrial landmarks, varied cut-rock berms, continuous worn roads, material transitions and revised lighting. Asset bounds, both tank passages, both resource fields, construction, air clearance/selection, sight/fire and archives pass. Standard south/native, north, Lean and Reinforced all reach victory; the Reinforced commander now reacquires sight before direct targeting. Native testing exposed and fixed stale-cursor drag selection, verified again on an aircraft above the berm. See [environment verification](playtests/2026-10-03/HORIZON_ENVIRONMENT.md). This is verified implementation progress, not final environment acceptance: broader terrain composition, boundaries/backdrops, vegetation, environmental audio and the other maps remain open. Performance optimization remains deferred; overall goal stays active.

- Completed on 2026-10-03: Command Horizon stages 1–3 — deployment control and HQ assault, finite warned mixed responses, the real Foundry-reward north passage, six-operation UI, finale/challenge completion and exact phase/route/modifier archives. Standard south/north routes win at 177.60/153.80 simulated seconds; the normal-clock native south run wins at 163.62. Reinforced and Lean also win on Standard at 223.43/293.78; Lean uses paid economy and army rebuilding. Actual capture/contest, all difficulty/modifier budgets, both routes, paused/adverse archives, progress migration and 720p/native challenge controls pass. Fixed shared turret action/timer restoration and a two-line-notice/minimap overlap. See [Command Horizon](playtests/2026-10-03/COMMAND_HORIZON.md). All six mission loops are present. The user's environment feedback is recorded as a substantial later art/layout pass; current maps remain blockouts. Novice/all-difficulty balance, final environments/audio, remaining factions/maps and release acceptance stay open. Performance stays deferred; overall goal remains active. This turn made verified implementation and playtest progress.

- Completed on 2026-10-03: Broken Foundry stages 1–3 — warehouse sightlines and three streets, two destructible nodes with finite paid chipped-unit production, exposed repair support, bounded defenders, gated infantry control, warned final response, campaign funds/reward and exact archives. The final full headless suite wins Standard at 2:41.40; the native normal-clock commander wins at 2:37.48 with paid infantry replacements. Actual artillery coverage, navigation, guard/repair limits, queue cancellation/budgets, partial capture/secured-time restoration, legacy progress and 720p controls pass. See [Broken Foundry](playtests/2026-10-03/BROKEN_FOUNDRY.md). Previous goal turn delivered Air Corridor; operations 01–05 are now playable. Next: Command Horizon and its foundry-reward alternate approach. Novice/all-difficulty balance, final assets, remaining factions/maps and release acceptance remain open. Performance stays deferred; overall goal remains active.

- Completed on 2026-10-03: Air Corridor stages 1–3 — industrial quarry with distinct ground/air routes, two destructible batteries, three explicitly launched evacuation flights, combined-arms/preset play, finite warned responses, transport controls and hangar service, campaign rewards and exact active-flight archives. Standard fixed-step/native normal-clock runs rescue all three at 3:39.03 / 3:43.15; 720p selection, pause, launch, archive, Stop/Continue, Finish, replay and return pass. Shared campaign/archive checks pass. See [Air Corridor](playtests/2026-10-03/AIR_CORRIDOR.md). Previous turn delivered Supply Line; operations 01–04 are now playable. Next gameplay stage: operation 05 Broken Foundry. Novice/all-difficulty balance, final art/audio, remaining content and release acceptance stay open. Performance remains deferred; overall goal remains active.

- Completed Supply Line, the conventional campaign opening: three repairable mission-only trucks, separate convoy/escort commands, three defended checkpoints, finite warned responses, two-extraction victory/two-loss defeat, difficulty budgets, active-force HUD and operation 01 selection. Campaign progress schema 3 retains old badges and gives fresh First Orders games a fixed +20 materials; gameplay-v5 archives/checkpoints retain partial clearance and response state. The final fixed-step Standard combat/extraction test wins at 3:58.25; an explicit-Hold normal-clock route wins at 3:51.90; native 720p selection/pause/advance/save-load/resume/hold/route/replay/return passes. See [Supply Line](playtests/2026-10-02/SUPPLY_LINE.md). Operations 01–03 are now available. Next gameplay stage: operation 04 Air Corridor and its air/ground control lesson; novice pacing, final art/audio, remaining missions/faction/maps stay open. Performance stays deferred; the removed quota stop condition remains removed.

- Completed economic recovery/expansion guidance: affected-engineer selection, field redistribution, paid-job/research refund options, replacement-in-progress recognition, affordability/available-builder selection, HQ foundation/countdown recovery and honest unavailable-budget advice. Real UI testing exposed and fixed paused production-queue cancellation; mouse/Enter refund and reinvestment now pass at 720p, with visible keyboard focus. Both factions pass paid replacement → actual harvest, paid HQ rebuild → countdown reset, pause/archive continuity and shared field/archive/opening UI checks. See [Economic recovery](playtests/2026-10-02/ECONOMY_RECOVERY.md). No resources/orders are granted automatically, no hidden fields are inspected, and no new save fields were added. Next gameplay stage: the missing conventional campaign opening; novice/faction pacing remains open. Performance stays deferred.

- Completed resource-field economy: fixed local/type assignment, two work reservations per deposit, partial-cargo return, terminal depletion/HQ recovery, engineer/group status and idle selection, Shift handoff, AI reassignment and snapshot-v5 migration from v1–4. Both-faction rules and actual 720p controls pass, along with shared orders/navigation/harvesting/archives/weapon-mode/preparation/signature checks. Paid Standard-start matches against live Easy AI finish with victories at 15:46 / 9:26 after the test commander protects the field; the earlier Bastion defeat remains recorded. See [Resource fields](playtests/2026-10-02/RESOURCE_FIELDS.md). Next: economic recovery/expansion guidance and the missing conventional campaign opening; pacing/novice acceptance remain open. Performance stays deferred. The user removed the weekly 10%-remaining quota stop condition. Overall design is still incomplete.

- Delivered under the new gameplay priority: collapsible skirmish Battle plan and own-unit shortcuts, staged economy/defense/factory/lab/chips/program/reinforcement/assault/recovery guidance, in-range crowd-safe gathering and legacy paused-harvest restoration. A reproducer fails before the collection fix and passes afterward. Both factions complete paid Standard-start matches against live Easy AI (latest victories 8:36 / 8:40); native 720p selection/harvesting/Guard assignment/Apply/manual override and shared navigation/archive checks pass. Earlier failed strategies remain recorded. Next: resource-field work slots, type-preserving depletion/reassignment and economic recovery, then missing campaign gameplay. Further optimization remains deferred. Overall goal stays active.

- Current direction: prioritize the complete skirmish gameplay loop under the user’s latest instruction. Stop performance investigation; retain the verified live-distance targeting prefilter and diagnostics. Two normal-clock comparisons show lower movement-frame means (130.01/162.40 → 95.31/87.26 ms), but combat is unchanged within run variation (158.84/163.21 → 165.93/153.18 ms). Combat candidate, both-faction order/Lua/weapon-mode and shooting restoration checks passed. No further performance work is scheduled in this stage.

- Delivered this turn: last-observer hints with live revalidation, bounded weak references and ownership-safe fallback; test-only query profiler/reference and normal-clock scale mode with p99, over-budget frames and simulation/wall time. Fixed-step combat improves 34.83→26.81 ms mean and 55.74→38.32 ms p95; real-time combat improves 223.48→147.89 ms mean but still fails badly, with ~10.1 simulated seconds requiring ~12 wall seconds. Retained all 200 units/VMs, 80 buildings, 32 resources and actual weapons/effects. Shared authority/program/signature/campaign/archive regressions pass, including same-frame observer/target movement, sight-range/ownership/death/construction changes, new occlusion and alternate-spotter fallback. Editor import and changed-code format/lint/whitespace checks pass. Previous turn added Split Signal; this turn reduces a measured cost and corrects the performance evidence. Next: profile normal-clock physics/navigation/cosmetic/render work and address sustained backlog; 300 transient effects, long-run/large-memory/native-platform acceptance and all remaining product scope stay open. Overall goal remains active.

- Delivered this turn: Split Signal, the third authored operation, with a three-relay mountain map, cumulative two-relay victory, advanced starting force, independent program assignments, finite two-wing responses, optional network control, HQ recovery/defeat, compact mission HUD and direct two-operation selection. Progress schema 2 preserves existing completion/badges; archives preserve timers, responses and three relays. Headless objective/archive/default-program victory and native 720p selection/checkpoint/save-load/replay flows pass. Final finite-budget regression passes, and the shared First Orders rendered build/program/reuse/result flow also passes. Verified Standard encounters completed in about 137–141 simulated seconds with four responses and 22–24 surviving mobile units; the separate three-route traversal and actual optional-capture scenario also passes; this is a viable-route check, not novice pacing or all-difficulty balance. Previous turn completed player settings; this turn adds campaign breadth. Supply Line, operations 04–06, third faction, remaining maps, novice/balance/performance/platform acceptance remain open. Overall goal stays active.

- Delivered this turn: shared main/battle settings, bounded persisted audio/camera/display/reduced-flash preferences, Voice bus routing/sample, live preview, atomic Save, Cancel/defaults and write-error recovery. Scene/camera/order input and F5 are isolated; prior pause/focus are restored. Real file, audio, pan/zoom and 720p mouse/keyboard checks pass. Fixed an evidenced macOS native-fullscreen cancellation race with bounded wall-time display synchronization. Final normal-clock rendered verification passes with zero failures, including normal/rapid display rollback, reduced-flash combat and no F5 quicksave file in an isolated test directory. The native test uses a wall-time watchdog so simulation speed cannot cause a false timeout. Shared combat/skirmish/signature/archive checks pass. Previous turn tuned Lancer; this turn adds usable player settings. Platform acceptance, remapping, scalable HUD, broader accessibility/audio and the remaining product scope stay open. Overall goal remains active.

- Delivered this turn: a mirrored actual-unit encounter matrix with separate material/electronics spending, unused budget, first-hit/loss timing and surviving HP. It exposed Lancer's post-charge anti-armor failure; revised Precision to 8 m / 15 base damage with a dedicated 0.3/0.8/2/0.5 armor profile, preserving reload/charge, HP, costs and AA. Current armor/infantry counter tests and 8–15 s basic-duel envelope pass, as do mode, preparation, signature, specialist, Lua, combat, skirmish and archive regressions. Rendered mode controls and actual armor/infantry counter outcomes pass at 720p; both encounter images were reviewed. Before/after JSON is retained; see living design section 40. The previous turn delivered Desert layout; this turn corrects an evidenced unit-role gap. Wider combined-arms balance, signature readability, Prism support, full-match pacing and release gates remain open. Overall goal stays active.

- Delivered this turn: Desert Frontier revision at 128×96 with central staging ground, open north/south flanks, paired home/outer economy, worn routes and low sandstone shelves. New menu map identity preserves old archives/demo geometry. Both factions pass three 16-tank advance/retreat lanes, mid-move disk reload, both starting-side harvesting, outer electronics return and placement; shared Alpine/skirmish/legacy restoration checks pass. Separate popup-viewport input corrects the menu test harness; actual 720p selection/closure passes. Six-minute AI scenarios build, produce and attack. Rendered economy checks also pass; the original full rendered run reports its earlier popup-input assertion, now corrected and verified in the focused menu/visual rerun. Final environment artwork and full-match pacing remain separate acceptance gates. The previous turn delivered signature mechanics; this turn advances map depth. Overall goal remains active; full-match pacing, equal-budget encounters, remaining content and release performance remain open.

- Completed: faction signature mechanics — explicit six-unit Anchor sectors and one-use Precision windows, research/chip/visibility gates, participant/cohort cooldowns, observed-contact AI, selection/sector UI and exact snapshot-v4 restoration with v1–3 support. Actual damage/timing, manual/programmed retreat, regrouping, paused disk restoration, death cleanup and 720p mouse/keyboard/cancel flows pass, as do shared combat, preparation, mode, Coordination, squad, Lua, skirmish and restoration checks. Reviewed both faction screenshots. Perceptibility of the 0.15-second gain and equal-budget encounters remain unaccepted; Desert revision, remaining content and release performance stay open. Overall goal remains active. Weekly quota: 68% used / 32% remaining.

- Completed: precision preparation / Prism deployment portion of faction combat stage 2 — 0.75 s interruptible charge after reload, 1.5 s stationary Prism setup, supports/muzzle warning, immediate paused cancellation, and snapshot-v3 exact restoration with v1/v2 support. Headless actual damage/timing, retarget/movement/occlusion/mode interruption, partial-setup/charge disk round trips and 720p Metal Stop/load flows pass. Shared combat, specialists, weapon modes and both restoration suites pass. The prior goal turn delivered mode differentiation; this turn delivered preparation/deployment. Anchor/Precision group abilities, equal-budget encounter tuning and remaining content/performance gates stay open. Overall goal remains active.

- Completed: faction combat stage 1 — Bastion's short-range AA and ground autocannon share a reload; Helix Lancers have explicit Precision/Interception with a two-second firing lock. Added mode badges, mixed-selection controls/tooltips, observed-contact AI and snapshot-v2 transitions with legacy-v1 reconstruction notice. Verified real damage, range, pause/movement/program authority, non-resetting cooldowns, actual partial-switch disk restoration, hidden-air AI behavior and 720p mouse/Enter/death cleanup. Shared combat, skirmish, Lua and both restoration suites pass. See living design section 36. Precision preparation, Prism setup, group abilities and equal-budget encounters remain next. The previous goal turn delivered Alpine; this turn delivered faction weapon differentiation. Overall goal remains active.

- Completed: Alpine Relay's first playable layout — two passes, outer bypass, aircraft ridge shortcut, paired economy, optional vision relays, AI infantry assignments, map preview/minimap and exact objective archives. Both factions pass Standard harvesting/placement and Advanced 16-tank transit, aircraft crossing and partial-recapture restoration, headless and with Metal rendering at 720p. The original rendered Bastion congestion case passes after moving relays out of the passage center. Menu mouse/keyboard selection and cold-terrain images were reviewed; shared skirmish/campaign restoration and editor import also pass. Path estimates: ground ridge crossing 38 m versus air 24 m; base route 40.8 s at 2.6 m/s. Existing navigation readback and shutdown shader/resource warnings remain. Final environment art, repeated full-match pacing, Desert revision and faction signatures remain open. Overall goal remains active.

- Verified: LLM adverse UI flow — actual local HTTP malformed/refused/incomplete/oversized/rate-limit replies, bounded diagnostic opt-in, pending close/cancel/reopen, retained drafts/reviews and inert hostile Lua followed by bounded explicit validation. No automatic retry or paid provider request. Live-provider/model quality, Windows/Linux native credentials and novice acceptance remain open.

- Completed: LLM assistance stage 2 — Create/Revise/Explain UI, saved connection and scoped masked-key controls, opt-in diagnostics/context preview, inert response review and explicit import. Offline numeric parameters now survive schema-4 library versions, exact factory jobs and battle archives. Real 720p input/local HTTP and both-faction authoring/factory/restoration regressions pass; fixed numeric canonicalization and unsaved connection comparison. See `docs/LUA_RUNTIME.md`. Stage 3 broader delayed/malformed UI and live-provider/platform/novice acceptance remain open; no paid API request. Overall goal remains active.

- Completed: LLM assistance stage 1 — bounded Responses/Chat adapters, explicit context packaging, strict inert draft contract and native/session credentials. Actual loopback transport, cancellation/retry/timeout/redirect/body limits while paused and isolated macOS Keychain round trips pass. Fixed the silent-peer threaded cancellation hang by using Godot's nonblocking HTTP poller. Native rebuild, Lua sandbox and both-faction authoring regressions pass. See `docs/LUA_RUNTIME.md`. No paid call or live-provider acceptance; player-facing Create/Revise/Explain, parameter review/import and real input remain next. Overall goal remains active.

- Completed: save/load stage 3 — player archive in main/battle/result menus, five manual slots, F5/F9, overwrite/load review, modal input and pause/focus restoration, three rotating First Orders checkpoints and retained-source recovery. Real 720p mouse/keyboard flows and campaign checkpoints pass; an injected real navigation wait failure can retry or return to Main menu. Full 200-mobile/188-large-Lua-memory file loads and saves again: 18,818,596 bytes, 887 ms archive inspection, 1,951 ms load, 2,478 ms recapture/write on the local M1 Pro headless run. These are storage/scene timings, not frame-rate guarantees. See `docs/SAVE_LOAD.md`. Previous goal turn delivered reconstruction; this turn adds verified player flows. Overall goal remains active. Weekly quota: 65% used / 35% remaining.

- Completed: save/load stage 2 — validated match reconstruction, action/timer/reference restoration, exact embedded program and paid queue continuity, safe target/fault fallbacks, exploration/knowledge and loaded tactical-pause ownership. Both factions/all skirmish maps, campaign, live firing and actual 720p Resume input pass. Verification fixed relay navigation displacement and stale paused population/power indicators. See `docs/SAVE_LOAD.md`. Stage 3 player slots/quicksave/autosaves/recovery remain unfinished; the overall goal remains active. Latest weekly quota: 64% used / 36% remaining.

- Completed: save/load stage 1 foundation — inert typed format, paused match snapshot, exact embedded programs and runtime checkpoint restoration. Real harvesting/construction/queues/orders/projectiles/knowledge and 200-mobile snapshot round trips pass, including rendered exploration. See `docs/SAVE_LOAD.md`. Previous goal turn delivered verified campaign progress; this turn delivers verified persistence foundations. Scene restoration and player save/load controls remain unfinished. Weekly quota: 63% used / 37% remaining.

- Completed: First Orders stages 1–3 — campaign entry/briefing, authored training map, built-in preset lesson, capture/hold/vision rules, warned finite responses, Command recovery/defeat and completion/badge persistence. Actual Standard victory, 720p input/results/replay and shared regressions pass. See `docs/playtests/2026-10-02/FIRST_ORDERS.md`. This goal turn delivered verified campaign progress; the overall goal remains active.

- Completed: battlefield arena stages 1–3 — seven actual-unit scenarios, expected outcomes, bounded traces, isolated desktop launch/return, pause/restart and exact-draft result notes. Both-faction behavior and 720p launch/editor regressions pass. See `docs/playtests/2026-10-02/BATTLE_ARENA.md`. Previous goal turn made verified visual-authoring progress; this turn delivered the arena.

- Completed: visual authoring stages 1–3 — ordered rule cards, deterministic bounded Lua, optional named states, separate Lua copies, schema-3 graph/source integrity and exact factory versions. Both-faction behavior, actual 720p input and 200-unit execution pass. See `docs/playtests/2026-10-02/VISUAL_RULES.md`. The separate battle arena is delivered below.

- Session cost constraint removed by the user on 2026-10-02: the 10%-remaining weekly Codex stop threshold no longer applies. Continue gameplay development without that quota gate.

- Completed: player authoring stages 1–3 — paused Lua editor, role preview, isolated sample checks, explicit atomic Apply, schema-2 source/API/hash versions with legacy migration and exact factory inheritance. Both-faction headless and real-input 720p/900p checks pass. See `docs/playtests/2026-10-02/LUA_AUTHORING.md`.

- Completed: Lua runtime stages 1–3 — pinned/reviewed native dependencies, bounded C error boundary, Godot data bridge and unit-action integration. Native sanitizer, both-faction authority/fault and 720p diagnostics checks pass. Full 200-unit Lua movement/combat averages 27.93/34.13 ms (p95 44.17/55.68 ms); stable 30 FPS remains open. See `docs/playtests/2026-10-01/LUA_RUNTIME.md`.

- Completed: second resource-art pass with six distinct salvage silhouettes, matching economy symbols and a clearer power meter with near/full/deficit/zero-generation states. Rendered 720p and harvesting/navigation checks pass; all six imported meshes fit their navigation bounds. See `docs/playtests/2026-10-01/RESOURCES_POWER.md`.

- Completed: standoff, strike-return and fire-support presets, named scout/repair defaults and compatibility-aware assignment/library/factory behavior. Both-faction behavior and mixed-role 720p checks pass. The 200-unit specialist workload travelled all 200 units and fired 113 weapons; average advance/combat 19.95/23.85 ms, p95 32.77/34.32 ms. See `docs/playtests/2026-10-01/SPECIALISTS.md`.

- Completed: explicit Coordination squads, bounded shared state, fire/repair claims and management UI. Both-faction membership/authority, loss/pause/fog and mixed-group 720p checks pass. Final 200-unit squad workload: 19.49/25.31 ms average advance/combat, 30.10/47.20 ms p95; all 200 moved, 116 fired, 122 sampled peak claims. See `docs/playtests/2026-10-01/SQUADS.md`.

- Completed: Shift-order queues, manual/program authority, optional queue-end resume and readable routes/status. Verified both factions, pause/input, target loss/fog, harvesting/repair/combat/construction handoffs, cap, replacement, Stop and blocked recovery. Rendered 720p layouts pass. See `docs/playtests/2026-10-01/ORDERS.md`.

- Completed: Coordination research/prerequisites and exact factory program-version pins. Verified costs/refunds, power/pause, destroyed labs, immutable queue snapshots, library fallback, rally authority and AI scout/repair orders.
- Completed: resource art follow-up — six neutral industrial salvage meshes with deterministic variety; persistent demand/capacity power meter, shortage/recovery/zero-supply states and 720p layout. See `docs/playtests/2026-10-01/RESOURCES_POWER.md`.

- Completed: individual motion profiles and long-idle gestures for all 16 mobile/faction combinations; attack/hit/death variation, authority/pause regressions and rendered review. See `docs/playtests/2026-10-01/UNIT_MOTION.md`. Latest 200-unit average movement/combat: 21.37/20.61 ms at 1080p; p95 33.16/38.37 ms.

- Completed: Stage 1 combat rules, current allied observation/obstruction checks, fractional armor counters, strongest-channel repair and two-slot service, non-pursuing idle defense, last-known attack orders and 40-structure cap.
- Completed: combat animation follow-up; actual rendered battle captured in `art/skirmish/combat-preview.mp4`. Effects, projectiles and recoil respect tactical pause.
- Completed: combat/projectile regressions, both-faction skirmish/AI suite, legacy Bastion, movement and rendered menu/production flows. Editor/format/lint checks recorded in the verification report.
- Measured: 200 moving/fighting units, 80 buildings, 32 resource nodes on the M1 Pro. 1080p movement/combat average 20.72/19.98 ms, p95 31.34/37.62 ms. Frame spikes and the later 200-program/300-transient-effects workload remain acceptance work; no stable-60-FPS claim.
- Completed: Stage 2 first slice — basic unlock/retrofit, factory hardware fitting, local presets, manual authority, assignment UI and immutable parameter versions. Headless/rendered regressions pass; 200 active presets average 19.52/24.47 ms advancing/combat after perception culling. See `docs/playtests/2026-10-01/PROGRAMS.md`.
- Next: finish adverse-flow LLM UI acceptance and document live-provider limits, then continue faction/map depth and 200-unit runtime performance. Faction coordination signatures remain in faction differentiation work; Coordination uses existing basic hardware.
- Pending: remaining Stage 2 and Stages 3–6. Custom Lua, visual-rule authoring/library, battle arena and First Orders are delivered; remaining campaign operations, LLM live-provider/novice acceptance, faction/map depth and release acceptance remain open.

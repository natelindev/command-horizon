# Programmable Combat RTS — Living Game Design

2026-10-17 decision: [Attack, Defensive, Follow, Guard and Hold Fire](UNIT_BEHAVIORS.md) replace player-authored unit programs. Economy, combat counters, research and campaign objectives continue; First Orders now teaches Guard. Earlier programming sections below are historical: on 2026-10-20 the Lua runtime, presets, chips, squads, rule/code editors, LLM assistant and program arena were removed from the codebase, together with the unreachable Air Corridor operation (04) and the retired Battle plan advisor.

Status: playable two-faction skirmish, programmable units and six Bastion campaign prototypes, version 0.7  
Last updated: 2026-10-04  
Working title: undecided  
Foundation: the existing Godot Open RTS repository

This document records the design discussion and delivered prototypes. The [core gameplay specification](CORE_GAMEPLAY_SPEC.md) now supplies concrete design defaults and acceptance gates for the next two-faction milestone. The [2026-10-01 playtest review](playtests/2026-10-01/REVIEW.md) records the evidence and its limits. Later implementation sections supersede the earlier planning snapshots: bounded custom Lua, visual authoring, reusable programs, battle archives and all six Bastion mission loops are now present. Final environments, broader faction/map content, novice/balance acceptance and full-release requirements remain unfinished. The latest finale evidence is in section 50.

## 1. Decision status

- **Confirmed:** explicitly requested or accepted by the user.
- **Proposed:** a design recommendation discussed so far, awaiting further refinement or acceptance.
- **Open:** a choice that still needs to be made.
- **Observed:** a finding from inspecting or testing the existing project, not a promise about the finished game.
- **Design default:** the current recommended implementation rule, selected under the user’s request to continue the design and fill gaps. It is not an individually user-confirmed balance value. The version 0.3 core specification supersedes earlier open proposals where explicitly resolved.

Examples, names, numerical tuning, and development phases are provisional unless explicitly marked confirmed. Agreement with a particular recommendation does not automatically approve every earlier proposal.

## 2. Vision and confirmed direction

Build a modern military-inspired RTS with exaggerated technology, inspired by Red Alert and Command & Conquer while establishing its own identity. The central progression is from directly commanding conventional forces to equipping units with programmable chips and directing an army whose tactical behavior the player can customize.

The player remains the commander. Automation should reduce repetitive tactical work while preserving meaningful decisions and direct control.

| Area | Confirmed direction |
| --- | --- |
| Engine and foundation | Develop from the existing Godot RTS template. |
| Initial platforms | Windows and macOS desktop applications, with keyboard and mouse. |
| Visual style | Stylized 3D, readable silhouettes, exaggerated weapons, and strong effects; preserve battlefield readability from an RTS camera. |
| Setting and tone | Modern military inspiration with exaggerated, game-oriented technology preferred over strict realism. |
| Unit families | Soldiers, tanks, robots, drones, and airplanes; battleships/naval combat if practical. |
| Economy | Materials and electronics stockpiles plus power capacity are the accepted prototype baseline, subject to playtesting. |
| Defining feature | Programmable units become available after an early-game threshold. |
| Programming | Lua and a visual programming interface that maps to Lua. |
| Accessibility | Useful default programs for every programmable unit; players need not know how to code. |
| LLM integration | Support generating Lua from natural-language requests so non-programmers can participate. |
| Prototype LLM access | Player-provided API credentials through a provider-adapter architecture. Presets and visual programming remain fully usable without an LLM connection. |
| Reuse | Programs can be saved and reused in later games. |
| Modes | PvE campaign and skirmishes. PvP may be considered later and is not the core focus. |
| Balance | Competitive balance is secondary to enjoyable PvE and expressive strategies. |
| Scale | Approximately 100 controllable units per player as the initial design target, following the discussion of a 100–200 unit scale. |
| Infantry control | Individually selectable soldiers with player-created squads for group orders and programs. Each soldier or vehicle initially counts toward the unit cap. |
| Pause | Single-player campaign and skirmishes support tactical pause for orders and program editing. |
| Automation scope | Bounded automation; the player must retain meaningful control. |
| Factions | At least three factions in the broader game vision, with possible variants. |
| Initial campaign | Start with the heavy mechanized faction, working name Bastion. Target all three factions as playable in skirmish as content expands. |
| Campaign persistence | Fresh armies for most missions; retain technology unlocks, programs, and doctrine presets. Do not require preservation of an entire army between missions. |
| Initial combat scope | Armor classes, weapon roles, terrain obstruction, and repair form the accepted prototype baseline. Evaluate cover, suppression, ammunition, and fuel separately. |
| Maps | Multiple maps with substantially different layouts and tactical demands. |
| Environment quality | Current blockouts are too simplistic; add richer terrain, landmarks, industrial detail and atmosphere in a later environment pass while preserving tactical readability. |

The approximately 100-unit target is per player, not a confirmed cap on all entities in the match. Soldiers remain individual units when grouped into squads; creating a squad does not collapse its members into one population slot. The next slice specifies two sides at 100 mobile units each, a separate 40-structure cap per side, and a 200-mobile-unit load-test scene; these limits are not a completed performance benchmark. See core specification section 10.

The exaggerated technology preference permits railguns and experimental machines; railgun and precision-artillery models are already present. Stealth fields and superweapons are not selected for the next slice.

## 3. Core experience and match progression

**Proposed experience:** the player's role evolves from direct tactical management toward directing and adapting coordinated forces.

| Stage | Main player activity | Army behavior |
| --- | --- | --- |
| Establish | Build an economy, scout, defend, and choose expansions. | Conventional RTS orders with reliable basic behavior. |
| Automate | Unlock chips, assign programs, and organize specialist squads. | Programmed retreat, repair, escort, and target priorities. |
| Coordinate | Direct several operations and respond to changing threats. | Assigned groups execute tactics while the player chooses strategy. |

The original intent is that early forces are relatively unintelligent and depend more on numbers and direct control. The proposed interpretation is to give them competent navigation, basic targeting, and order execution, while reserving adaptive behavior for chips. Poor pathfinding or deliberately unresponsive units should not be the progression mechanic.

A conventional tank requires a manual retreat order. A programmed tank can retreat at a threshold, seek repair, and rejoin its squad. Cheap conventional units should retain late-game roles as defenders, screening forces, and replacements.

### 3.1 Unlock and pacing proposal

- A completed vehicle producer and faction lab unlock basic programmable chips. The lab requires the vehicle producer: Command Lab for Bastion, Signal Lab for Helix.
- Current pacing hypothesis: programming around minutes 3–5 in a 20–30 minute skirmish. This replaces the initial 5–8 minute proposal; the feature should appear earlier. Standard-start measurements must validate it.
- Access primarily depends on economy and construction choices. A difficult contested objective should not be the only route to the defining feature.
- Later objectives can reward advanced capabilities.
- Compatible early vehicles can receive chips at a service depot, making preservation worthwhile.

| Proposed chip tier | Capabilities |
| --- | --- |
| Basic | Local conditions, target priorities, retreat, and repair. |
| Coordination | Squad roles, shared state, and synchronized actions. |
| Advanced | Coordination across groups and more sophisticated sensor processing. |

Progression unlocks understandable capabilities rather than code length. Core specification section 4 defines Basic and Coordination hardware, prices, installation and lab-loss behavior; the Advanced tier is deferred.

## 4. Economy

**Confirmed prototype baseline:** materials and electronics as two stockpiled resources, plus electricity supply/demand capacity. This accepts the recommended model for prototyping; economic tuning and detailed acquisition rules remain provisional.

| Resource | Acquisition | Main uses |
| --- | --- | --- |
| Materials | Engineers harvest deposits; salvage deferred to a later faction experiment. | Buildings, conventional units, and support equipment. |
| Electronics | The same engineers harvest rarer deposits and return cargo to HQ. | Chips, robots, drones, advanced weapons, and research. |
| Power capacity | Construct generators. | Support production, research, and advanced facilities. |

Power is a capacity meter, not a third stockpile. The next-slice default keeps production/research/service activity at 35% during shortage while preserving movement, harvesting, installed programs and weapons. Core specification section 3 defines acquisition, field exhaustion, queue reservations and provisional costs. Repairs consume support capacity and time rather than stockpiles in this slice.

The intended economic tension is between a larger conventional force and investment in a more capable automated army. Chips are equipment purchased using electronics, not a fourth currency.

Installing hardware costs resources. Editing, testing, and reusing a program should have no in-match resource cost. Any external LLM service cost is a separate, unresolved product decision.

## 5. Programming and player accessibility

### 5.1 Authoring paths

**Confirmed:** presets, visual programming, direct Lua, and LLM-assisted Lua generation must serve players with different interests and skill levels.

**Proposed experience:**

1. Select a useful built-in doctrine.
2. Adjust simple parameters.
3. Customize conditions and actions through a visual interface.
4. Ask an LLM to draft or revise behavior.
5. Edit Lua directly when desired.

Players should be able to enjoy the game without writing code. Coding should offer expressive freedom rather than be a prerequisite for basic competence.

### 5.2 Default programs

**Confirmed:** every programmable unit has useful default programs.

**Proposed:** a unit enters play with one sensible active default and a small selection of role-specific alternatives.

| Unit family | Example presets |
| --- | --- |
| Tank | Hold the line, cautious advance, escort. |
| Combat robot | Assault, guard position, protect support units. |
| Repair robot | Maintain assigned squad, defend-and-repair. |
| Recon drone | Scout assigned area, patrol perimeter, follow formation. |
| Attack drone | Strike marked targets, harass within an assigned area. |
| Fighter | Intercept within an assigned zone, escort aircraft. |
| Bomber | Strike an assigned target, return and rearm. |
| Warship, if implemented | Coastal bombardment, escort, hold sea zone. |

These family examples extend beyond the current roster. Infantry and engineers stay conventional in the next slice; a later receiver upgrade would need its own useful presets. Core specification sections 4–5 define eligible units and shipped defaults.

Common parameters should include retreat health, pursuit distance, preferred targets, protected squad, and operating area. A player should often be able to achieve a useful change by adjusting a parameter instead of restructuring a program.

Players can duplicate a built-in preset into their personal library. Proposed versioning makes edits a new version; applying an update to deployed units is explicit so behavior does not change unexpectedly.

Newly produced units should inherit the factory's selected program and parameters. The player can override individuals or apply a doctrine to a squad. Missing or incompatible factory programs fall back to built-in Hold with a notification; missing required anchors enter Waiting for assignment. Core specification section 8 defines version pinning and validation.

### 5.3 Visual editor and Lua relationship

Proposed initial visual representation: ordered conditions and actions, with optional states.

Example tank behavior:

1. Below 30% health, retreat to the assigned repair point.
2. Remain in repair mode until health reaches 80%.
3. Otherwise prioritize visible enemy artillery.
4. If no artillery is available, protect the assigned squad.

Separate retreat and return thresholds avoid repeated switching between advance and retreat.

Visual programs generate Lua. Arbitrary handwritten or LLM-generated Lua is not assumed to convert back into an editable visual graph. The proposed solution is a visual-authoring mode with generated Lua and a separate custom-Lua mode, both using the same gameplay API. Structured LLM edits to visual programs are a possible later extension, not a decided requirement.

### 5.4 Gameplay API and information rules

Proposed rules:

- The engine performs navigation, movement, weapon operation, and action execution. Scripts choose decisions and intent.
- Scripts receive legitimate sensor information and permitted remembered sightings, never unrestricted hidden enemy state.
- A reusable program accepts assignments and parameters instead of depending on a particular map's coordinates or object references.
- Multiple units can share program source while keeping separate runtime memory.
- Squad memory and communication require defined rules before coordination chips are implemented.
- Errors or execution-limit violations suspend that unit’s program and enter Hold, preserving any manual command. Core specification sections 5 and 8 define arbitration, budgets and diagnostics.

### 5.5 Library, testing, and debugging

Proposed requirements:

- A persistent personal program library shared across campaign and skirmish.
- Program versions, parameters, capability requirements, and compatibility checks.
- A small test arena for trying behaviors before deployment.
- Pause and step controls for debugging.
- Human-readable explanations, such as: “Retreating: health 24%, retreat threshold 30%.”
- Inspection of active behavior, relevant conditions, and current assignment.
- Preservation of relevant program/runtime state in match saves.

Hardware and capabilities available in the current match determine whether a saved program can run. Owning a saved program does not bypass the match's technology restrictions.

## 6. LLM-assisted program generation

**Confirmed:** natural-language generation of Lua is part of the intended game, including support for players who cannot code.

### 6.1 Proposed interaction

Example request:

> Make these tanks protect my artillery. Don't chase enemies far away, prioritize enemy tanks, and retreat for repairs below 35% health.

The assistant drafts:

- A plain-language behavior description.
- Editable parameters, explicitly resolving terms such as “far away.”
- Lua source using the supported gameplay API.
- Required assignments, such as the artillery squad to protect.

The player can test the draft and then assign it. Follow-up requests can explain observed behavior or change it, such as keeping at least two tanks with the artillery.

### 6.2 Proposed execution model

- Invoke the LLM when the player requests creation, explanation, or revision.
- Provide the supported API, unit capabilities, and relevant program context.
- Validate generated code and execute it under the same sandbox and budgets as handwritten Lua.
- Run battlefield decisions locally through Lua; do not require an LLM call for each tactical decision.
- Preserve presets, visual editing, and saved scripts when the LLM service is unavailable.
- Treat generated code as a draft. Successful validation and testing do not guarantee that it satisfies every aspect of the player's intent.

### 6.3 Confirmed prototype access and release distinction

- Start with player-provided API credentials and a provider-adapter architecture.
- Presets and visual programming remain fully usable without an LLM connection.
- API-key setup creates friction for non-programmers, so prototype access does not settle the eventual public-release model.
- A managed service is a possible more approachable release option, but is not committed. It requires decisions about operating costs, accounts, and usage allowances.

### 6.4 Open product choices

- Public-release access: player-provided credentials, managed service, local models, or a combination.
- Provider support, service cost, distribution model, and usage limits.
- Provider-specific implementation of the context minimization and disclosure rules now specified in core specification section 8.
- Initial output is custom Lua plus parameters/summary; structured visual-rule generation is deferred.
- The next-slice draft/validate/test/apply and failure workflow is specified in core specification section 8; provider-specific error mappings still need implementation.

## 7. Automation boundaries and direct control

**Confirmed:** automation must leave meaningful control with the player.

**Proposed division of responsibility:**

| Player decides | Programs handle |
| --- | --- |
| Where to attack or defend. | Positioning and target selection within the assignment. |
| Army composition and production. | Using assigned units' capabilities. |
| Expansion and research. | Local reactions to battlefield conditions. |
| Squad membership and objectives. | Escorting, cohesion, retreat, and return. |
| When to commit or withdraw a force. | Consistent execution of the order. |

The initial scripting API should not construct bases, spend resources, choose research, or autonomously manage strategic expansion. Pursuit and autonomous movement can be constrained by assigned operating areas.

Manual orders take priority, including over scripted emergency retreat. The next-slice default holds after a direct command until explicit Resume program; Auto-resume is optional and off by default, and waits for the entire manual queue to complete. Core specification section 5 supplies the command matrix, assignment bounds, blocked-path handling and squad ownership.

### 7.1 Tactical pause

**Confirmed:** campaign and skirmishes support pausing to issue orders and edit programs.

Proposed semantics: inspect units, change assignments, and prepare programs while paused; simulation actions and timers only advance after unpausing. Debug single-stepping deliberately advances a controlled simulation step.

Simulation speed controls and optional pause restrictions for challenge content were proposed but are not yet confirmed. Multiplayer pause rules are outside the initial scope.

## 8. Combat and unit roles

**Confirmed prototype baseline:** armor classes, distinct weapon roles, terrain obstruction, and repair. Cover, suppression, ammunition, and fuel will be evaluated individually rather than all being included initially. Detailed rules and tuning remain provisional.

**Confirmed infantry model:** individually selectable soldiers with player-created squads for group orders and programs. Grouping does not grant chip capabilities to an ineligible unit. Infantry and engineers remain conventional in the next slice; see core specification section 4.

**Confirmed art direction:** stylized 3D with readable silhouettes, exaggerated weapons, and strong effects. Effects must preserve battlefield readability at the RTS camera distance. Bastion and Helix visual directions and model sets are recorded in sections 16–17; their final animation/texture/LOD passes remain.

Proposed combat should be readable and stylized, with enough time to observe programmed behavior and react. Instant destruction of most units would reduce opportunities to understand, appreciate, or improve programs.

| Family | Battlefield role | Example programmable behavior |
| --- | --- | --- |
| Infantry | Capture, urban fighting, inexpensive defense. | Hold cover and withdraw from approaching armor. |
| Tanks | Breakthrough and mobile firepower. | Rotate damaged vehicles behind healthier ones. |
| Robots | Specialist combat and support. | Repair priority assets while staying behind the front. |
| Drones | Reconnaissance, spotting, harassment. | Scout routes and avoid detected anti-air coverage. |
| Aircraft | Interception and concentrated strikes. | Attack after air defenses are suppressed, then rearm. |
| Ships | Coastal control, escort, bombardment. | Screen transports and maintain standoff distance. |

These are broader design examples, not commitments to every subsystem. Core specification section 6 now defines armor/profile multipliers, target domains, visibility and obstruction rules, repair limits and VTOL-style aircraft. Cover bonuses, suppression, ammo/fuel logistics and rearming are deferred from the next slice.

Initial depth should emphasize scouting, positioning, target selection, and repair. Detailed ammunition and fuel logistics can be evaluated later. Exaggerated technology should create distinctive tactical choices without obscuring unit roles.

PvE allows spectacular faction strengths and unusual combinations. Internal balance still matters: several strategies should remain worth using even when competitive symmetry is not a goal.

## 9. Factions and setting

**Confirmed:** at least three factions in the broader vision; possible variants; begin with the heavy mechanized faction's campaign, working name Bastion; exaggerated technology preferred. Conventional infantry and tanks provide the introduction before robots and advanced automation appear.

**Proposed setting:** fictional near-future powers with recognizable modern military silhouettes and substantial creative freedom. Names and fiction below are placeholders.

| Working faction | Combat identity | Automation strengths | Limitations |
| --- | --- | --- | --- |
| Bastion Directorate | Heavy armor, artillery, mechanized infantry. | Coordinated firing, repair rotations, defensive formations. | Slow expansion and expensive losses. |
| Helix Systems | Robots, drones, precision aircraft. | Specialized autonomous units and rapid coordination. | Fragile units and high electronics demand. |
| Free Frontier Coalition | Mobile infantry, refurbished armor, improvised machines. | Flexible retrofits, scouting, ambush, and salvage. | Weaker sustained frontal combat. |

All factions should participate in programming rather than restricting the defining feature to one faction. Variants can initially change selected units, technologies, and economic bonuses while sharing most systems.

The first campaign's heavy mechanized identity is selected. Sections 16–17 record Bastion and Helix visual identities; the core specification now defines their tactical differences and proposed signature abilities. Final names, campaign writing and the third faction's detailed roster remain to be refined.

### Free Frontier gameplay integration — 2026-10-04

The [Frontier roster](../art/frontier/README.md) is now integrated into skirmish selection: seventeen editable models and icons, lower-cost mobile units with 85% base health (revised 2026-10-20: infantry 110%, aircraft 70%), 2 E / 3 s retrofits, finite wreck collection and a distinct Maneuver Burst. Coordination enables a six-unit, six-second +35% movement window with a 25-second cooldown; Rapid redeployment raises it to +50%. Engineers must collect and return 20% of a destroyed ground machine’s material cost before its three-minute wreck expires. Paid economy, combat, program authority, research, exact archives and four-map travel have functional coverage. See [verification and limits](playtests/2026-10-04/FRONTIER_GAMEPLAY.md). Working names and initial balance remain provisional; repeated full-match and novice acceptance remain open.

### 9.1 Concept-art review set

[Bastion concept-art review set 01](concept-art/bastion/v1/README.md) contains faction key art, ground-unit and robotics/air design sheets, and desert, industrial-city, and coastal environment concepts. The six images and exact prompts are saved in the repository. Generated colors, markings, specific equipment shapes, and map details are proposals awaiting user review; the coastal image does not change naval combat's conditional scope.

The user responded positively to this visual direction and requested Blender CLI modeling. The [first Bastion tank model](../art/bastion/tank-v1/README.md) provides an editable Blender scene, articulated GLB, build script, verification, and renders for review. It is a first modeling pass, not a final production asset or a replacement for the current gameplay tank.

## 10. PvE modes and campaign progression

### 10.1 Confirmed scope

- Campaign and standalone skirmishes.
- The heavy mechanized faction's campaign first, working name Bastion.
- Fresh armies for most missions, with persistent technology unlocks, programs, and doctrine presets.
- Three playable skirmish factions as the broader roster is developed, rather than requiring three complete campaigns initially.
- Shared emphasis on accessible programming and meaningful player command.

### 10.2 Proposed campaign structure

A campaign of authored operations, with some branching or optional missions that alter a later battle. Begin mostly linearly and add branches where they create meaningful choices.

Examples:

- Destroy radar to reduce later enemy detection coverage.
- Capture an electronics facility for an additional starting stockpile.
- Disrupt an airbase to reduce enemy air support.
- Rescue a specialist to unlock an optional unit modification.

Optional advantages should not make the main mission unwinnable if skipped.

### 10.3 Progression and persistence

**Confirmed:** fresh armies for most missions; technology unlocks, programs, and doctrine presets persist. Players are not required to preserve a whole army across the campaign. Detailed progression and optional persistence exceptions remain proposed.

| Within a battle | Across the campaign |
| --- | --- |
| Build the base and economy. | Unlock access to units and technologies. |
| Research available battlefield upgrades. | Unlock mission choices. |
| Produce units and install chips. | Save and improve programs. |
| Choose investment in automation. | Retain doctrine presets and loadouts. |

Recurring commanders and occasional persistent special units remain possible additions. They are not yet selected requirements. A fully persistent army is outside the accepted baseline because it introduces loss recovery and snowballing concerns.

Persistent progress should initially emphasize capabilities, mission access, and program mastery rather than large permanent stat bonuses.

### 10.4 Avoid repeating the tutorial phase

Proposed campaign flow:

- Opening missions teach conventional control, followed quickly by chips and useful presets.
- LLM assistance becomes available alongside programming rather than as a late-game unlock.
- Standard base-building missions may require a Command Lab, with saved programs immediately ready when unlocked.
- Advanced missions can start with the lab and chips already available.
- Special missions can begin with a small, fully programmable force.
- Occasional disrupted-command scenarios can challenge doctrines without repeatedly removing the game's central feature.

Standard, Advanced and separate art-review starts are specified in core specification section 2. The Standard start is the pacing experiment; the art demo is not.

### 10.5 Mission and enemy design

Suggested mission families: base assault, convoy escort, survival with counterattacks, evacuation, and simultaneous control of several objectives.

Enemies should pose recognizable tactical problems: artillery behind screening units, raids on resource lines, air attacks on exposed groups, and pressure on multiple fronts. Automation should not eliminate the need to adapt assignments, composition, and strategy.

Core specification section 9 now defines fair observations, difficulty seeds, finite campaign reinforcement budgets and the shared tactical command boundary. The current clairvoyant AI must be replaced before those rules can be tested.

## 11. Map variety and naval scope

**Confirmed:** maps must differ substantially in gameplay, not only scenery.

| Proposed map type | Strategic difference | Programming opportunities |
| --- | --- | --- |
| Open desert | Long sightlines and exposed expansions. | Screening, mobile defense, retreat routes. |
| Dense city | Short engagements and multiple approaches. | Ambushes, infantry support, cautious scouting. |
| Mountain valley | Passes, bottlenecks, separated fronts. | Convoy escort and defensive rotation. |
| Industrial complex | Valuable facilities and tight corridors. | Patrols and capture-and-defend routines. |
| Archipelago | Water separates economies and objectives. | Transport escort and air/naval coordination. |

Recommendation: authored maps and encounters first, so tactical problems can directly inform the programming tools. Procedural generation has not been selected.

Naval combat remains conditional scope. The first coastal map must retain complete ground access and does not require playable ships. It requires water navigation, shoreline rules, ship movement, transports where relevant, and maps that justify those systems. Proposed introduction: limited naval content after ground and air combat is established. A battleship could first be a mission asset before becoming a buildable unit.

## 12. Existing project and feasibility

### 12.1 Observed foundation

Repository inspection found:

- Godot 4.6 project configuration.
- Two generic resources in the player model.
- Ground and air navigation domains.
- Unit production, combat actions, basic fog of war, and a minimap.
- A basic AI opponent, including a clairvoyant intelligence implementation.
- Units using action nodes, providing a potential integration point for commands.

Relevant files: [README](../README.md), [project configuration](../project.godot), [player model](../source/match/players/Player.gd), [unit model](../source/match/units/Unit.gd), [navigation](../source/match/Navigation.gd), and [existing AI intelligence](../source/match/players/simple-clairvoyant-ai/IntelligenceController.gd).

These observations came from source inspection, not performance measurements or full gameplay verification. The current AI's information access should not be inherited as the player-script information model.

### 12.2 Feasibility assessment

The concept is technically achievable in Godot. The template is a useful starting point, but the complete vision is substantial. Major new work includes a safe Lua runtime, behavior authoring and debugging, LLM integration, richer PvE, differentiated factions, and additional content.

The largest product risk is whether authoring and reusing behaviors is satisfying while battlefield decisions remain interesting. The main engineering risks include runtime isolation, script scheduling, navigation and sensing at scale, save compatibility, and clear arbitration between direct commands and automation.

### 12.3 Proposed architecture principles

- Target Windows and macOS desktop applications with keyboard and mouse, as confirmed. Minimum OS versions and target hardware remain open.
- Use the confirmed provider-adapter approach for prototype LLM access; exact providers and adapter interfaces remain to be specified.
- Embed Lua through a suitable integration; GDExtension is a viable route to prototype, not yet a selected dependency.
- Expose a narrow gameplay API without filesystem, network, or unrestricted engine access.
- Limit script execution and memory so faulty scripts cannot indefinitely monopolize the simulation.
- Run tactical decisions at controlled intervals rather than requiring each unit to evaluate complex behavior every rendered frame.
- Bound expensive sensing and path requests as well as Lua instruction execution.
- Route human, AI, and script orders through a shared command layer.
- Define program versioning, parameter serialization, runtime-state persistence, and compatibility behavior.
- Establish aggregate unit and entity benchmarks on specified target hardware before claiming performance support.

Official references consulted during the discussion: [Godot GDExtension documentation](https://docs.godotengine.org/en/stable/engine_details/engine_api/gdextension/index.html) and [Lua 5.4 reference manual](https://www.lua.org/manual/5.4/manual.html). They document extension/embedding mechanisms, including Lua hooks and allocators; they do not by themselves establish a complete sandbox or a finished Godot integration.

### 12.4 Future PvP

PvP is a possible future direction, not an initial core deliverable. The command boundary should preserve architectural options, but networking, authority, synchronization, script execution, and multiplayer pause rules will require deliberate later work. Multiplayer is not assumed to be a simple addition.

## 13. Proposed development sequence

These stages are recommendations for turning the vision into a development specification. They are not a committed schedule or complete release plan.

### Stage 1 — Prove programmable combat

- The selected heavy mechanized faction and a limited enemy roster.
- The accepted materials/electronics economy and power capacity, with tuning validated through playtests.
- The accepted combat baseline: armor classes, weapon roles, terrain obstruction, and repair.
- Infantry, a tank, a scout drone, and a repair robot.
- One mission containing the transition into programmable units.
- Basic chips, useful defaults, a small visual rule editor, and a minimal Lua API.
- Program saving/loading, test arena, and basic diagnostics.
- Tactical pause and understandable direct-order overrides.

Key question: does creating and reusing a behavior feel satisfying and change how the player fights?

### Stage 2 — Validate accessibility and repeatability

- LLM drafting and revision using the established API, player-provided credentials, and the selected provider-adapter approach.
- Validate that non-programmers can customize and diagnose useful behaviors.
- Exercise the program library across different missions and skirmish starts.
- Validate the approximate per-player unit target and determine the aggregate performance budget.

The next milestone places LLM draft assistance after a working preset/editor/runtime contract and alongside the first complete programming mission (core specification Gate D). It remains part of the intended product, with offline presets and visual editing fully supported.

### Stage 3 — Build campaign and faction breadth

- Develop the first faction's campaign.
- Expand toward three playable skirmish factions.
- Add distinct maps, mission types, faction mechanics, and aircraft behaviors.
- Refine progression, program compatibility, and difficulty.

### Stage 4 — Evaluate extensions

- Limited naval combat and battleships if justified by the core game and maps.
- Faction variants and further campaign perspectives.
- More elaborate technology and optional challenge modes.
- PvP only after a separate scope and architecture decision.

## 14. Remaining decisions and validation work

Version 0.3 resolves the earlier shared-rules questions in [Core gameplay specification](CORE_GAMEPLAY_SPEC.md). Economy acquisition, power shortage, chip ownership, manual precedence, squad/state ownership, editor transitions, AI fairness, objectives, initial map contracts and save semantics now have implementation defaults. They must not be confused with delivered features.

Remaining decisions require evidence rather than another unrestricted brainstorming round:

1. Tune Standard-start resource prices, worker travel/saturation, chip timing and combat values after the new start and Helix are playable.
2. Test whether faction signatures are readable and worth using, especially Helix’s first-shot timing window.
3. Select and audit the Lua integration; measure execution/memory/path-query budgets and error isolation.
4. Select prototype LLM adapters after an integration spike; decide managed/BYOK/local public-release access and pricing separately.
5. Validate novice preset/visual-editor usability, parameter clarity and manual-resume behavior.
6. Establish Windows/macOS minimum versions and reference hardware after native build/performance tests.
7. Refine campaign writing, third-faction roster and final naming without expanding the next two-faction milestone.
8. Decide naval, variants and PvP only after the core loop and three-faction product target are supported by tests.

The core specification includes ordered implementation gates and measurable acceptance criteria. [Playtest evidence](playtests/2026-10-01/REVIEW.md) identifies what was actually exercised and what remains an inference or proposed rule.

## 15. Decision log

| Discussion step | Recorded outcome |
| --- | --- |
| Initial vision | Modern combat RTS; two or three resources; early unlock of programmable chips; Lua and visual authoring; reusable programs; PvE priority; at least three factions; drastically different maps; conditional naval combat. |
| Accessibility and modes | Default programs explicitly required for every programmable unit; LLM generation requested; campaign plus skirmishes confirmed; bounded automation emphasized. |
| Scale and pause | Accepted approximately 100 controllable units per player as the starting target and tactical pause for orders/program editing. |
| Campaign and tone | Accepted starting with one faction's campaign; preferred exaggerated game-oriented technology over a grounded treatment. |
| Documentation | Requested that all discussion be recorded in the design document. This draft separates confirmed decisions, proposals, observations, and unresolved questions. |
| Development defaults accepted | Windows and macOS with keyboard/mouse; stylized 3D; heavy mechanized Bastion campaign first; individual infantry with player-created squads and per-soldier/vehicle cap accounting; fresh armies with persistent technology/programs/doctrines; prototype LLM access through player-provided credentials and provider adapters. |
| Prototype baselines accepted | Materials + electronics stockpiles and power capacity; armor classes, weapon roles, terrain obstruction, and repair. Keep tuning provisional and evaluate cover, suppression, ammunition, and fuel separately. Public-release LLM access remains a separate decision. |
| Two-faction design review | Native Bastion interaction test and controlled economy/repair probe; documented that Helix is an asset set, not a playable faction. Version 0.3 selects next-slice rules for starts, chips, manual control, counters, sustain, objectives, maps, AI, authoring and persistence; see core specification and playtest review. |

## 16. Bastion asset and gameplay demo — implemented 2026-10-01

This milestone converts the first faction's approved visual direction into editable 3D models and a playable Godot demonstration. It is an art and baseline gameplay milestone; it does **not** complete the programmable-unit vertical slice described in Stage 1.

### Delivered roster and production

| Producer | Available units | Behavior in this demo |
| --- | --- | --- |
| Headquarters | Engineer rover | Harvest either stockpile resource, return cargo to headquarters, construct buildings. |
| Barracks | Rifle infantry | Individually selectable ground troops with direct attack orders and automatic idle defense. |
| Vehicle factory | Bastion tank, repair robot, combat walker, railgun tank | Armor/support roster. Walkers and railgun tanks require a completed command lab. Repair robots heal nearby allies while idle or follow a player-selected ally to repair. |
| Airfield | Recon drone, VTOL strike aircraft | Drone scouts without weapons; strike aircraft hover, move freely over ground obstacles, and attack ground or air. |

All nine structures can be built by engineers: headquarters, barracks, vehicle factory, airfield, power generator, command lab, repair depot, ground battery, and missile battery. The depot heals nearby friendly ground units. Ground batteries attack terrain units; missile batteries defend against aircraft. The `Helicopter` identifier is retained internally for template compatibility; the displayed asset is the Bastion VTOL strike aircraft.

### Implemented economy and controls

- Materials and electronics are harvested stockpiles. Deposits use new faction-compatible ore/silicon models. Stockpile costs and combat values are provisional and centralized in `source/match/MatchConstants.gd`.
- Headquarters supplies 20 power; each generator supplies 25. Barracks consume 3, vehicle factories 6, airfields 8, labs 5, depots 3, and each defensive battery 2. Only completed structures participate.
- Demand above supply reduces production and depot repair speed to 35%. This prototype does not disable weapons during a power shortage.
- Each mobile unit consumes one of 100 population slots per player, including queued units as reservations. Structures do not consume population. Production also checks producer type, available resources, prerequisites, and queue capacity. Cancellation refunds the full production cost.
- Destroying a lab pauses queued advanced units until a completed lab exists again. Existing advanced units remain usable.
- Direct orders, harvesting, construction, production queues, rally points, selection, control groups, combat, and fog of war use the template's RTS systems with the expanded assets and roster. There is no Lua runtime behind these behaviors yet.
- The **BASTION DEMO** entry adds tactical pause: paused unit selection, move/attack/repair/harvest orders, construction placement, and production queuing. Orders execute when the simulation resumes. Program editing remains unimplemented.
- UI uses rendered asset icons, descriptive names, costs, HP, resource totals, power demand/supply, and population. Screen-space selection, camera control, and minimap calculations accommodate scaled/Retina viewports.

### Scenario and assets

Desert Frontier is a 64 × 64 two-player map with four resource fields and six sandstone outcrops that obstruct ground navigation. The dedicated demo starts with every unit type and building available for review, 120 materials and 70 electronics, two engineers gathering automatically, and a red AI opponent. The player starts at the northwest base; the enemy occupies the southeast. Victory requires eliminating all enemy units and structures. The original two maps remain available for skirmishes, now using the Bastion scenes; those starts retain the template's headquarters/engineer/drone opening.

The opponent still uses the template's explicitly named **Simple Clairvoyant AI**. It builds, gathers, reinforces, and attacks with privileged world information. This is not the final campaign AI or difficulty model. Balance and initial advantage favor asset review and experimentation.

The generated set contains **20 GLBs**: eight mobile units, nine structures, two deposits, and one reusable cliff cluster. All have rendered transparent UI icons. Source and pipeline locations:

- `art/bastion/build_faction.py` — deterministic Blender CLI generation/export/render pipeline; imports the original tank as its armor base.
- `art/bastion/demo/bastion_faction.blend` — editable component-level source and catalogue scene.
- `assets/models/bastion/demo/` — Godot-importable GLBs with named articulation nodes and team-color material slots.
- `assets/ui/bastion/` — generated transparent icons.
- `art/bastion/demo/manifest.json` — export triangle counts and source-space bounds.
- `art/bastion/verify_faction.py` and `art/bastion/demo/verification.json` — independent re-import validation.
- `art/bastion/demo/gameplay/` — actual Godot screenshots of production, construction, and the battlefield.

Mobile assets range from 844 to 12,640 triangles; structures range from 432 to 1,120. Geometry uses solid PBR materials, rigid turret/barrel pivots, simple procedural leg movement, and rotating drone fans. Blender uses meters with Z up; exports use glTF/Godot coordinates, Y up and forward -Z. Scene scaling, collision shapes, health bars, and navigation footprints are configured separately for RTS readability.

### Verification and limits

Verification includes all 20 GLB re-imports, triangle counts, finite mesh coordinates, materials, articulation nodes, icons, Godot imports, all unit-production buttons, stockpile/prerequisite/population gates, low-power production, refunds, construction, repairs, ground/air navigation, combat and target destruction, scaled viewport rendering, tactical pause orders, and the main-menu entry. The original two-map startup/navigation checks are retained. Test sources are in `tests/headless/` and `tests/rendered/`.

This milestone does not yet implement Lua, visual program authoring, reusable program libraries, LLM integration, campaign missions/progression, other factions, naval gameplay, or the planned armor/weapon counter system. Aircraft use hover movement rather than fixed-wing flight. Models have no baked texture atlases, final skeleton animation, damage states, or bespoke LODs. The population limit is enforced, but a target-hardware performance budget for 200 active combatants still needs profiling.

Godot 4.6 verification currently reports a navigation warning about reading terrain mesh geometry during the initial bake and renderer shader/resource cleanup diagnostics at process exit. The tested gameplay and rendering assertions pass; these diagnostics are recorded rather than treated as a clean engine shutdown.

## 17. Helix Systems — second faction design and model set

### Status and design intent

The user requested the second faction's design, ImageGen concept art first, and Blender models afterward. Helix Systems follows the existing precision-robotics faction proposal. The following mechanics are **proposed for playtesting**, not implemented abilities. This milestone delivers the concept art, eight unit models, nine structure models, exports, rendered icons, and a Godot asset-review scene. It does not make Helix a selectable skirmish faction yet.

**Fantasy:** command a small, expensive force that wins through information, timing, and precise concentration of fire. Helix originated as a consortium of industrial robotics and aerospace companies; its expeditionary forces protect remote fabrication and communications infrastructure. Human operators remain important, and players retain command authority over the robots. Helix shares the game's materials/electronics/power economy and the same programming system as the other factions.

**Battlefield identity:** fast repositioning, reconnaissance, fragile specialist machines, strong precision aircraft, electronics-heavy replacement costs, and limited staying power in frontal fights. Bastion holds ground with armor and repairs; Helix identifies an exposed target, commits a coordinated strike, and withdraws before the opponent can concentrate fire. This describes a playstyle, not mandatory automation.

### Visual specification

- Warm ivory armor shells over exposed graphite mechanisms; deep teal team panels, turquoise optics, and small orange caution marks. Team color occupies separate named material slots; optics stay turquoise.
- Split hulls, forked mounts, paired swept fins, slender gun barrels, visible gaps, and articulated joints create recognizable silhouettes without relying on color.
- Early equipment remains recognizably modern: armored humans and wheeled service vehicles. Later units add lift housings, precision walkers, tri-duct reconnaissance drones, and exaggerated rail artillery.
- Buildings use hexagonal pads, separated wings, swept pylons, and open fabrication or maintenance bays. The command hub has twin high fins; the lab has an open tilted sensor ring; power uses three exposed cores.
- The setting shown in key art is an alpine communications/fabrication facility: cool rock, concrete aprons, conifer belts, narrow passes, and elevated sensor sites. This is setting art, not a completed playable map. Aircraft and ground-route asymmetry should be tested before map production.
- Models preserve the concept silhouettes at lower geometric complexity. Fine panel decals, surface wear, final texture baking, and cinematic-level detail are deferred.

### Unit roster and proposed default programs

| Unit / export | Role and player decision | Proposed chip preset |
| --- | --- | --- |
| Vector operator / `VectorOperator` | Inexpensive human rifle infantry. Capture/hold positions in future objective modes and accompany scouts; weak against heavy armor. | **Hold sector:** engage visible threats inside a player-defined radius; never chase beyond it. |
| Mule engineer / `MuleEngineer` | Six-wheel collector and constructor with two tool arms. Build and expansion placement remain direct player orders. | **Assigned harvesting:** work the chosen resource field, return cargo, stop and notify when depleted or threatened. No autonomous expansion. |
| Needle skimmer / `NeedleSkimmer` | Mobile precision armor with a split hull and four lift housings. Strong at firing and repositioning; less durable than Bastion's tank. Hover is a visual/mobility identity, not permission to cross every cliff or water obstacle. | **Standoff fire:** maintain the chosen range against a designated visible target, within a bounded area; direct move orders override it. |
| Lancer walker / `LancerWalker` | Tall four-legged anti-armor specialist. Expensive electronics and exposed mechanisms discourage trading shots. | **Priority armor:** prefer visible armored targets in range and synchronize one volley with the assigned group. |
| Mender robot / `MenderRobot` | Low maintenance walker with two manipulators. Sustain a small task force, but repair cannot compensate for focus fire. | **Bounded escort repair:** follow the assigned unit/group, repair the most damaged nearby ally, retreat to an assigned rally point when threatened. |
| Kite scout / `KiteScout` | Unarmed triangular drone with exactly three ducted fans. Finds routes and identifies targets; fragile and valuable. | **Scout route:** visit player-set waypoints, keep a safe distance from visible air defense, report contacts; no automatic whole-map exploration. |
| Wraith striker / `WraithStriker` | Twin-engine swept-wing strike drone with missile pods. Burst damage and rapid repositioning, vulnerable to dedicated anti-air. | **Strike and return:** attack the selected visible target once, then return to the chosen safe point; do not choose another target without instruction. |
| Prism artillery / `PrismArtillery` | Six-wheel long-range twin-rail accelerator with stabilizers. Deployment and visible targeting cues create counterplay. | **Fire support:** deploy at the ordered position, fire at designated visible targets in a player-set sector, hold when vision is lost. |

These are intended presets for the future Lua/visual editor and LLM authoring system. Version 0.3 scopes Vector infantry and Mule engineers to conventional orders initially; their programmable presets require a later receiver upgrade. They are design requirements, not Lua scripts shipped by this asset milestone. Each future programmable unit must work with a useful preset without requiring code. Advanced presets must use the same bounded public API as player-authored programs.

### Progression and signature mechanics — proposed

1. **Opening:** Nexus HQ, Mule engineers, Vector operators, and generators establish the economy. Units follow direct orders and simple built-in stances.
2. **Early threshold:** complete a Robotics Foundry and Signal Lab. This building-based threshold introduces basic chips, their default programs, and the editor through a short PvE objective. Avoid a kill-count threshold that can stall progression.
3. **Midgame:** expand the specialist roster with Lancers, Menders, scouts, and strike aircraft. Electronics demand makes protecting a second resource field valuable. The player chooses patrol routes, targets, deployment positions, and retreat destinations.
4. **Late game:** Prism artillery and more advanced chip capabilities improve coordination. They add tactical options rather than unlimited strategic automation.

**Shared track:** a Kite or operator can publish a visible target ID to its assigned local group. Shared data includes only legitimately observed information. A last-known position can persist briefly for planning, but cannot authorize shooting into unrevealed space or expose updated hidden positions.

**Precision window:** proposed first signature ability. A player-designated target can receive a short coordination window; up to six assigned chip-equipped units reduce their first-shot preparation time by 20% during a two-second window, followed by an eight-second group cooldown. Bonuses do not stack and do not raise sustained damage indefinitely. The UI should show the target, participants, and remaining window. Exact values require testing alongside the final weapon wind-up system.

**Prism deployment:** proposed 1.5-second setup before firing and a visible charge effect; movement cancels setup. It requires current allied vision and cannot fire through hard line-of-fire blockers. The model includes separate stabilizers and an elevating barrel pivot to support this future implementation.

Manual move, stop, attack, retreat, and ability commands take precedence over scripts. On command completion, the player-selected resume policy decides whether the preset resumes. The next slice does not simulate radio-range or signal loss. Lab destruction blocks new gated production/research but preserves existing chip behavior; any later disruption mechanic must preserve direct control.

### Structures and economy — proposed integration mapping

| Building / export | Intended function |
| --- | --- |
| Nexus HQ / `NexusHQ` | Engineer production, resource drop-off, baseline power and command infrastructure. |
| Operator hub / `OperatorHub` | Train human Vector operators. |
| Robotics foundry / `RoboticsFoundry` | Manufacture Needle, Lancer, Mender, and Prism units; tier prerequisites constrain availability. |
| Flight deck / `FlightDeck` | Build Kite scouts and Wraith strikers; optional future rearm behavior needs a separate decision. |
| Flux generator / `FluxGenerator` | Supply power; three cores provide an unmistakable silhouette. |
| Signal lab / `SignalLab` | Unlock chips, specialist technologies, and the faction's coordination abilities. |
| Service cradle / `ServiceCradle` | Stationary vehicle/robot repair; supplies sustain at the cost of positional commitment. |
| Lance sentry / `LanceSentry` | Precision ground defense with a traversing turret and elevating gun. |
| Skyward array / `SkywardArray` | Dedicated anti-air missiles and radar. |

Use the same two stockpiles and power-capacity UI as Bastion, and keep the 100 mobile-unit-per-player starting limit. Helix should pay more electronics per specialist, have lower armor/HP for similarly priced combat units, and gain reconnaissance or repositioning advantages. The core specification now provides initial economy costs, common power values, combat profile seeds and faction stat relationships. Final HP/ranges/timing still require integration and measurement; the asset viewer has no combat simulation.

Counters should be understandable in PvE: broad-area damage punishes tightly coordinated groups, inexpensive screening troops prevent easy priority shots, air defense denies unescorted Wraith attacks, and flanks exploit Prism setup time. Helix can answer with scouting and deliberate maneuver, not omniscient scripts. A future faction variant could favor aircraft or ground robotics while sharing the same asset and program compatibility rules.

### Saved deliverables and review

Concept art was generated **before modeling** using the built-in `image_gen` tool. All three final PNGs are in `docs/concept-art/helix/v1/`; exact final prompts are in that directory's `prompts.json`. The key art establishes setting and materials, and the two reference sheets define the full unit/structure set. No API fallback was used.

- `art/helix/build_faction.py`: repeatable Blender modeling, export, icon, and render pipeline.
- `art/helix/v1/helix_faction.blend`: editable components with catalogue display transforms. Reset an asset root's translation, rotation, and scale for upright native-metre editing; GLBs already use native dimensions.
- `assets/models/helix/v1/`: 17 GLBs, Y up / forward -Z, with rigid pivots and `TeamColor_Helix` material slots.
- `assets/ui/helix/`: 17 transparent icons rendered from the actual geometry.
- `art/helix/v1/`: individual 768px model renders, the labeled catalogue, manifest, verification report, and actual Godot review screenshots.
- `source/showcase/HelixShowcase.tscn`: interactive model review; available as **HELIX MODEL REVIEW** in the main menu. Choose a roster item, use the mouse wheel to zoom, Q/E to turn, Space to pause rotation, and the team-color button to inspect recoloring. Escape returns to the menu.

The source and GLBs contain independently editable legs, repair arms, wheels, turret/barrel pivots, drone rotors, artillery stabilizers, and sensor assemblies where relevant. These are rigid component hierarchies, not final skeletal rigs or a full animation library. The review scene animates overall rotation and scout rotors; final locomotion, weapons, collisions, navigation footprints, production, faction selection, and signature gameplay require the next integration pass. Battleships remain conditional and are outside this first Helix roster.

### Verification

All 17 exports passed independent re-import in Blender 5.2.1: matching triangle counts, finite vertices, positive face areas, material assignments, team-color slots, required turret/barrel pivots, three scout rotors, and icon availability. Models range from 852 to 5,388 triangles. Results are saved in `art/helix/v1/verification.json`.

Godot 4.6 imported and rendered every model. The rendered verification checks entry through the main-menu button, both rosters, all 17 model instances, team-color switching, and return to the main menu; it saves four actual engine screenshots. The final run exited successfully without logged warnings or errors. Source formatting and lint checks pass. These checks establish asset compatibility and review navigation; they do not establish combat balance or 200-unit performance.

## 18. Playtest-informed design defaults — version 0.3

The user requested continued design work informed by trying the current game. The resulting [core gameplay specification](CORE_GAMEPLAY_SPEC.md) is the next-milestone design reference; the [review and raw measurements](playtests/2026-10-01/REVIEW.md) preserve observations separately from recommendations.

| Gap | Selected design default | Why |
| --- | --- | --- |
| Art demo does not test progression | Separate Standard/Advanced starts; aim for chips in 3–5 minutes. | Expose the defining feature early while preserving an economic choice. |
| Harvester intent and economic pacing | Same workers collect either resource; assigned field/type persists; finite deposits, explicit exhaustion feedback. | Avoid silent resource switching or dangerous unrequested expansion. |
| Chip eligibility and lab loss | Retrofit conventional armor; built-in hardware for advanced machines; infantry/workers conventional initially; existing chips survive lab loss. | Make ownership and recovery understandable. |
| Direct orders versus programs | Manual override wins, including over emergency scripts; Auto-resume off by default. | Preserve player authority and prevent units undoing a deliberate command. |
| Additive repair exceeds individual weapon damage | Strongest channel only, reduced repair under fire, limited service slots. | Encourage rotations and support protection without unbounded healing stacks. |
| Incomplete faction counter coverage | Armor profiles, mobile AA roles, bounded vision and line of fire. | Give both factions answers to air and preserve scouting/terrain value. |
| Similar specialist roles | Bastion commits to ground; Helix scouts and strikes; Prism deploys while railgun tanks stay mobile. | Different decisions using the existing models. |
| Cleanup-heavy victory and flat mission variety | Recoverable HQ defeat for skirmish; six-operation campaign outline with objective wins. | Finish decisive battles and make programming useful beyond base destruction. |
| Map variety not yet functional | Desert routes, Alpine separated fronts, industrial sightlines, coastal ground access. | Vary decisions before adding naval systems. |
| Lua/LLM failure and persistence unspecified | Versioned programs, bounded snapshots, Hold fallback, explicit draft/apply, save embedded program versions. | Keep authored behavior understandable, reusable and recoverable. |

The native test confirmed paused selection/move/production and exposed paused minimap and mixed-group health presentation gaps. The controlled probe delivered 20 M / 12 E in 60 seconds with the two default workers and confirmed additive repair. Helix-versus-Bastion combat, chip authoring, new mission objectives and 200-unit performance have not yet been playtested. This design pass does not implement those systems.

## 19. Playable two-faction skirmish — implemented 2026-10-01

This milestone follows the user's request to prioritize an actual skirmish game with faction and opponent selection. It supersedes the earlier statements that Helix is available only in a model viewer. The larger core specification remains a target; the implemented subset below is authoritative for the current build.

### Setup and match lifecycle

- Dedicated **SKIRMISH** entry with native Godot controls, faction portraits, tactical map preview, remembered setup choices and a Start Battle action.
- One human versus one AI. Human and enemy can independently choose Bastion, Helix or Random. Random resolves once at match creation; replay retains that resolved matchup. Returning to setup and starting a new game rerolls Random.
- Maps: Desert Frontier (64×64, rock formations and contested expansions), Open Plains (50×50, shorter engagements), Great Expanse (100×100, longer travel). Opposing starts use opposite spawn markers. The latter two are existing template maps, not the proposed Alpine/industrial/coastal environments.
- Standard start: completed HQ, four workers, two infantry; 60 M / 12 E. Advanced adds generator, barracks, vehicle factory, lab, repair depot, two tanks and repair robot; 120 M / 60 E.
- Fog of war is enabled; development god mode is disabled for the duration of a skirmish. Player colors are gold and red, independently of faction.
- Victory requires the opponent to have no completed HQ for 60 consecutive simulation seconds, or no surviving units/buildings. Completing an HQ resets the countdown. Simultaneous loss yields a draw. An unfinished replacement does not reset it.
- Result overlay shows outcome, elapsed battle time and surviving army. Replay reconstructs the match; setup/main-menu return clears pause. There is no in-match save/load or multiplayer lobby yet.

### Economy, roster and progression

Both factions use the existing eight mobile roles and nine structures, with faction-specific models, names, icons, team markings and construction ghosts. Stable role identifiers preserve working gathering, navigation, repair and production systems.

The 100-unit limit per side counts mobile units and production reservations; structures are excluded. Materials and electronics are harvested; power is capacity with reduced production under shortage. Workers follow the resource orders the player gives. No automatic player expansion or army management is added.

| Mobile role | Bastion M / E | Helix M / E | Production seconds |
|---|---:|---:|---:|
| Engineer | 6 / 0 | 6 / 0 | 8 |
| Infantry | 6 / 0 | 6 / 0 | 8 |
| Basic tank / Needle skimmer | 24 / 6 | 22 / 10 | 20 |
| Repair robot | 16 / 8 | 14 / 12 | 18 |
| Combat walker | 24 / 16 | 26 / 20 | 24 |
| Railgun tank / Prism artillery | 40 / 24 | 36 / 30 | 32 |
| Scout drone | 8 / 4 | 8 / 6 | 12 |
| Strike aircraft | 32 / 20 | 28 / 24 | 28 |

| Shared structure role | M / E | One-worker build seconds | Required completed structure |
|---|---:|---:|---|
| Headquarters | 80 / 20 | 45 | None |
| Barracks | 20 / 0 | 20 | None |
| Vehicle factory | 45 / 12 | 35 | Barracks |
| Aircraft factory | 45 / 20 | 35 | Vehicle factory |
| Generator | 15 / 0 | 20 | None |
| Command lab | 50 / 30 | 40 | Vehicle factory |
| Repair depot | 25 / 10 | 25 | Vehicle factory |
| Ground turret | 20 / 8 | 20 | Barracks |
| AA turret | 20 / 12 | 20 | Vehicle factory |

Walkers, advanced tanks/artillery and strike aircraft require a completed lab. Losing that prerequisite blocks new orders and pauses affected queued jobs until it is restored. Production cancellation refunds its paid faction price. At this milestone construction retained the template's full cancellation refund and additive worker speed; section 116 later replaces this skirmish deviation with the core contract.

Helix mobile units have 80% of counterpart health and 120% movement speed. Needle/Kite gain two sight units. Prism range is 10 with 90% of baseline movement speed (the Helix speed modifier multiplied by 0.75). Buildings retain shared statistics. Both factions' walkers can engage ground and air in this milestone; the proposed deploy/AA mode switching and coordination signatures are not implemented. Armor classes and weapon profiles were added in section 20.

### Orders and opponent

- Right-click retains move, focus attack, gather, construct, repair and factory rally behavior. F + left-click adds attack move: move toward the ordered destination, stop for compatible enemies in weapon range, continue after losing that engagement. A fresh direct order replaces it.
- Space pauses simulation while selection, camera/minimap, control groups, construction and production UI stay usable. Orders begin on resume. Esc opens a modal menu and preserves a pre-existing tactical pause when closed.
- Weapon cooldowns use simulation time. Retargeting during pause cannot spend wall-clock time to bypass the remaining cooldown. Mixed selection reports unit/damaged counts instead of the first unit's health.
- A new skirmish opponent harvests both resources, maintains six workers, builds production/power/technology/defenses, trains a mixed army, scouts and launches waves. It uses the same costs, prerequisites and caps. No extra health, damage or resource income.
- Easy / Normal / Hard: decision interval 3 / 1.5 / 0.75 seconds; first wave eligible after 180 / 120 / 75 seconds; subsequent minimum interval 100 / 65 / 40 seconds, requiring three combat units. Economy and travel can delay these timings.
- Strategic targets are contacts within its units' sight ranges or the public opposing starting area. Resource locations are map knowledge. This is a first opponent with a fixed build order; occluded observations were added in section 20; learned tactics, adaptive counters and competitive difficulty remain future work.

### Movement reliability follow-up

The user reported units frequently getting stuck during skirmish testing. Reproduction confirmed a tank stranded over nine metres short of a destination behind a factory and incomplete group/factory-exit movement. Static structures and rocks now use a shared circular footprint for navigation baking and local avoidance. Movement submits velocity in metres per second, applies frame time only at integration, advances its path once per physics tick, keeps finite idle targets, preserves orders during initialization, constrains local displacement to the walkable mesh, and uses brief timed sidesteps for crowd deadlocks. Same-target updates no longer continuously restart paths. Navigation mesh resources are isolated per match so an asynchronous bake cannot contaminate a replay. Regression scenarios cover individual and group routes, factory exits, resource traffic, construction access, rocks, and building placement/removal during movement.

### Verification and remaining work

See [skirmish verification](playtests/2026-10-01/SKIRMISH.md) and screenshots under `art/skirmish/`. Automated tests cover faction combinations, prices/refunds, models/team colors, all roster production, construction previews, prerequisites, all map/start combinations, air damage, paused cooldowns, result outcomes and replay. Six-minute economy/attack simulations exercise both AI factions. Rendered and native checks exercise setup and gameplay controls.

This is the conventional RTS foundation for later programmable behavior. Lua/default program libraries, visual programming, LLM authoring, chips, campaign, naval units, save/load and networking are not implemented by this milestone. Section 20 adds bounded repair, sight/fire obstruction, a first 200-unit benchmark and combat animation. Long-match balance and the full program/effects performance workload remain unverified.

## 20. Combat foundation and animation — implemented 2026-10-01

The user authorized sequential implementation of the remaining design, then requested stronger battle animation. The [development roadmap](DEVELOPMENT_ROADMAP.md) records the sequence and [combat verification report](playtests/2026-10-01/COMBAT.md) records evidence.

### Combat authority and sustain

- Shared battlefield queries now serve weapon firing, idle acquisition, attack move, human target validation, enemy AI observations and enemy-unit visibility. Completed buildings and Desert cliffs use opaque cylindrical volumes with height; elevated air sight lines can pass over low obstacles. Friendly spotting reveals a contact but cannot grant a shot through a wall. Foundations remain transparent; removing a building removes its obstruction. Spatial indexing bounds nearby searches; enemy presentation updates over six physics frames, while firing checks current positions.
- Weapons use the six profiles and four armor classes from core specification section 6, including fractional damage. Target domain is checked separately. Walkers use the AA profile against aircraft. Damage and repair remain faction-neutral rules.
- Ordinary idle defense fires within range without chasing. Explicit attack can approach a visible enemy; on loss of contact it visits only the last observed position, then holds, with a five-second no-progress bound. Hidden positions cannot become new movement targets.
- Only the strongest available channel heals a target. Robots: 2.5% maximum HP/second, 3 m, mechanical ground units/completed structures, no self-heal. Depots: two channels, 4%/second, 5 m, mobile mechanical ground units. Infantry recover while stationary at barracks; aircraft recover while stationary at airfields, each with two service slots. Recent enemy damage reduces healing to 25% for three simulation seconds. Building repair follows the 35% low-power factor; robots do not.
- Skirmish placement and AI enforce 40 owned structures including foundations. The existing 100-mobile cap remains separate. Selection shows armor/weapon roles and recovery rules; placement explains the structure cap.

### Battle presentation

Shared effects replace one particle emitter per shot with bounded GPU buffers. Bastion conventional weapons use warm tracers; Helix uses cyan; rail weapons use bright cool streaks. Cannons have short visible travel, missiles have arcing trails and visible target tracking, and rail shots are immediate. Impacts show sparks, brief fire and smoke; vehicles kick back, barrels recoil, and units react to damage. Infantry/walker gait gains body motion; aircraft tilt forward while moving and hover subtly. Moving ground units raise light dust.

Destruction produces an appropriately sized burst and a dark non-colliding model wreck. Infantry topple without a vehicle explosion; airborne wrecks settle to the ground. Wrecks sink away after eight seconds, with a 24-wreck cap. Tracers cap at 96; five GPU buffers total 1,728 cosmetic particles. Saturation drops/reuses cosmetic capacity without changing damage or orders. No effects expose a never-observed shooter; moving tracers update a target only while visible. Tactical pause freezes flight, recoil, particles and wreck settling.

Every mobile unit has an individual cosmetic motion profile. After 4–7.5 seconds of quiet, infantry/walkers breathe and shift weight, vehicles settle and scan, and articulated service tools make small adjustments. Gestures last 3.2 seconds with 6–10-second intervals; independently phased aircraft hover continuously. Body offsets are deliberately small, with larger motion reserved for articulated parts. Gait phase/cadence, rotor phase, three recoil recovery styles and per-shot strength differ across otherwise identical units. Incoming hit direction influences the visual flinch. Infantry collapse in different directions, vehicles settle at different angles, and aircraft bank and accelerate downward; timing and short slide offsets vary. Buildings retain fixed foundations during operation and settle vertically on destruction.

Variation uses private per-unit random streams and simulation time. It never changes weapon cooldowns, damage, orders, collision footprints or navigation positions. New orders reset the idle delay; movement intent suppresses gestures even when a unit is blocked. Active aim overrides scanning, and firing clears idle pose before the muzzle is sampled. Pause freezes the complete motion layer. Wreck lifetime/caps and GPU particle budgets are unchanged. The visual seed is stored on the unit for its lifetime; persistence across future save/load is not yet implemented.

This is a procedural animation/VFX pass using the existing models. Bespoke skeletal reload/death clips, tread animation, sound design, persistent damage meshes, screen shake and final destruction art remain future presentation work. Terrain fog shading still uses broad reveal circles; actual enemy visibility and firing now respect obstructions. Legacy small decorative rocks are not authored sight volumes.

### Verification and scope

The rendered mixed-faction battle exercises more than 100 shots/impacts and nine deaths, checks pause and effect limits, and produces an [eight-second review clip](../art/skirmish/combat-preview.mp4). Gameplay regressions cover blocked fire, allied/elevated vision, fractional counters, ten-healer stacking, service slots, power, repair suppression, projectile flight/pause/target destruction, idle hold and last-known orders. Existing skirmish, AI, production, navigation and rendered UI suites pass.

The load scenario holds 200 mobile units alive with elevated HP, adds 80 structures and 32 resource nodes, and exercises movement and actual weapons/effects. On the development M1 Pro, the final 1920×1080 fixed-step uncapped run averaged 20.72 ms movement / 19.98 ms combat; p95 was 31.34 / 37.62 ms. This is workload throughput, not a stable-framerate or long-match guarantee. The full 200-program/300-transient-effects target, frame spikes and Windows profiling remain open.

## 21. Basic unit programs — implemented 2026-10-01

The first Stage 2 slice makes the defining automation loop playable using shipped presets. Vehicle producer + completed faction lab unlock basic programs for that match. Compatible robots, scouts, strike aircraft and long-range platforms include hardware; conventional tanks can receive a four-electronics/five-second chip retrofit at a chosen HQ/service building or be produced with that hardware surcharge. Advanced starts include chipped starter tanks. Infantry/engineers remain conventional. Installed technology survives lab destruction; fitting/production fees are explicit and cancellations refund the reserved amount.

The selection panel exposes Hold, Guard, Escort and two-waypoint Patrol, a 3–12 m area (6 m default), nearest/lowest-health/heavy-armor priority, and retreat/return thresholds (30%/80% defaults in five-point increments). A retreat requires a player-chosen safe point. Repair robots service damaged allies within their assignment; unarmed scouts use movement presets. Guard targeting stays inside the assigned radius; an out-of-range engagement has at most two metres of additional weapon reach before returning. Programs never choose production, expansions, research or membership.

Direct human orders suspend the preset immediately, including during pause, and remain Manual after completion. Apply & run and Resume activate at the next simulation tick; no implicit auto-resume. Missing/destroyed assignments hold and explain the reason. Five seconds of no movement progress enters Blocked and requires reassignment or explicit retry. Normal idle defense remains available while waiting/blocked. State/reason, recent reason history, version/readiness and representative world-space assignment guides are visible in the UI.

Saved parameter programs are immutable local versions, independent of a match or network. Applying a saved version is explicit; changing its draft does not mutate earlier versions. Current-map locations and entity references are not embedded in library entries. The bounded/versioned JSON library preserves its existing file on failed validation or writes. This is a built-in preset runtime, not Lua execution or a visual-to-Lua compiler.

The headless suite verifies unlocks, retrofit/refund/power/pause, factory hardware, manual authority, visibility/sector limits, target priorities, retreat hysteresis, blocked paths, escort loss, patrol, repair and library validation. The rendered UI flow is checked at 900p and 720p. The 200-active-preset workload moves all 200 units and exercises 116 weapons; final average advance/combat times are 19.52/24.47 ms, with p95 31.47/45.71 ms. See [implementation and verification](playtests/2026-10-01/PROGRAMS.md) for screenshots, hardware and test limits.

Coordination research and factory version pins are delivered in section 22. Squads, queued orders, specialist presets and the Lua sandbox remain Stage 2 work. No campaign, game-state save/load or LLM integration is implied by this milestone.

## 22. Coordination and factory inheritance — implemented 2026-10-01

A completed lab offers Coordination after basic programs unlock: 20 materials + 20 electronics, reserved once, with a 30-second simulation timer. Low power runs research at 35%; tactical pause freezes it. Cancellation refunds the reserved cost once. Losing every completed lab suspends research until a replacement completes; unlocked technology persists. Both factions now need Coordination and a completed lab to produce long-range armor. Advanced starts still require this research. AI researches it while reserving its next planned construction budget.

Vehicle/air factories can select an exact saved program version, defaulting to built-in Hold. Each new queue job captures a validated, independent snapshot; later edits or deleted library files cannot change that queued job. Missing/corrupt versions fall back to Hold with a reason. Produced units receive the snapshot and run when hardware/technology permit. Location-dependent programs wait for explicit map assignments. A factory rally order takes manual authority immediately. Existing units and older jobs do not inherit future dropdown changes. Duplicate library version identities are rejected.

This delivers the research gate. Explicit squads, bounded shared state and target claims are delivered in section 25. Faction coordination abilities remain Stage 2/faction differentiation work; existing basic hardware is sufficient as specified.

## 23. Resource presentation and power readability — implemented 2026-10-01

Resource deposits use neutral industrial salvage, shared by both factions and all maps. Materials have three distinct silhouettes: bundled I-beams/hollow pipes, a broken armored chassis with an exposed turret bearing, and a rolled steel coil with stacked plates. Electronics have three distinct silhouettes: a server cache, a damaged relay with exposed circuitry, and a capacitor pack. Beveled edges, recessed parts, oxidized metal, inventory markings and exposed terminals add manufactured detail. Ochre marks materials; cyan marks recoverable electronics. Position-derived rotation breaks repetition without consuming simulation randomness. All mesh vertices fit inside the existing 0.6 m navigation radius. Existing amounts, harvesting rules and depletion behavior remain authoritative.

The persistent top HUD groups materials, electronics and population with matching stack/chip/shield symbols, alongside a lightning symbol and power usage meter. The label explicitly separates **used / supply**. It shows spare capacity, an amber build-power advisory when reserves reach 10% or less, an exact-capacity instruction, or an orange text-and-color LOW POWER warning with exact deficit and 35% operating speed. Zero supply and zero demand explicitly request a power plant. Near/full capacity alone does not penalize production. Only completed structures contribute power. Production, chip installation, research and depot repair share the low-power factor. Power recovers automatically when demand falls or supply increases. The layout is checked at 1440×900 and 1280×720, including tactical pause and zero-supply states.

See [verification and review images](playtests/2026-10-01/RESOURCES_POWER.md).

## 24. Queued manual orders — implemented 2026-10-01

Shift + right-click appends to a selected unit's manual queue; Shift + the attack-move destination click appends attack-move. Each unit supports one active operation and up to 16 waiting orders, independently of whether it has a chip. Ground and air move orders retain separate crowd spacing. Ordinary orders replace previous orders. Stop clears the queue and keeps the program suspended. Commands can be entered while paused, with execution beginning on simulation ticks after resume.

Programs suspend as soon as a manual order is accepted. Default completion holds position; a selection-level Auto-resume checkbox opts the selected units into resuming their own assigned programs after all orders finish. Explicit Apply/Resume clears pending manual orders. This is individual command authority, not program squad membership or shared state.

Move, attack, attack-move, gather, construct, repair, follow and approach orders use the same queue. Queued repair completes at full health. A harvester with a waiting order delivers its current load before advancing; without a waiting order it keeps harvesting. Follow is persistent until the target is lost, the player skips it or a replacement order arrives. Dead/unavailable targets are skipped. Hidden enemy orders use the enqueue-time last-known position without sampling live hidden coordinates. A blocked move reports after five seconds without progress and remains under player control; Skip advances it rather than silently discarding the maneuver.

The selection panel offers Skip order, Clear waiting (preserves the active operation), queue status and optional auto-resume. One representative numbered route uses a solid active segment and dashed waiting segments, rendered beneath the HUD. This avoids overlapping every route in a large selection. Orders hold weak target references and create action nodes only when activated. Idle queue controllers do not tick.

Verification covers both factions, actual Shift event routing, ground/air/conventional units, pause, cap/replacement/Stop, explicit and optional resume, target death/fog, harvesting, repair, combat and construction handoffs, and blocked-move recovery. Rendered 720p layouts pass for combat selections and worker construction controls. See [order queue verification](playtests/2026-10-01/ORDERS.md).

## 25. Program squads and shared targeting — implemented 2026-10-01

Coordination unlocks explicitly created squads, with one program squad per mobile unit and a 24-member cap. Squad membership is separate from numeric selection groups. The player names, creates, selects, adds/transfers, removes and disbands squads through the selection panel. Transfers validate the entire selection before changing membership. Dead members are removed and empty squads disappear. Buildings/enemy units cannot join. No unit is automatically purchased or enrolled.

Membership and doctrine are separate decisions: creating, joining or disbanding a squad preserves individual orders, queues, programs and assignments. Select the squad to explicitly apply an existing preset to its eligible members. Conventional members remain under manual control; the panel shows the number of program-ready members. A manual order immediately releases that member's shared target claim while leaving other members active.

Three squad targeting policies are available: **Spread fire** (default) favors less-contested targets and penalizes targets whose remaining HP is covered by another member's claimed shot; **Focus fire** prefers a squadmate's eligible target; **Independent** disables sharing. Repair programs spread service across damaged allies under the two sharing policies. These are targeting preferences, not guaranteed simultaneous fire or an overkill-free ballistic predictor. Each member still uses its own visible, legal, in-range/assigned-sector candidates, line-of-fire rules and weapon capabilities. Shared information cannot grant a shot or make a manual unit obey a program.

Claims have a 0.8-second simulation lifetime, refresh during active program evaluation and disappear on manual override, removal, policy change, death or expiry. Pause preserves them. Targeting collects one claim snapshot per decision and reuses it across candidates. Groups do not wait for airborne/ground members or enforce rigid formations; ordinary movement/avoidance and separate ground/air manual spacing remain authoritative.

Each squad also owns up to 8 KiB of JSON-compatible shared state, with bounded keys, arrays, depth and validation work. Only running, chip-ready members can access it. Rejected writes preserve the previous state; reads and writes copy values so external mutation cannot alter stored data. Engine objects and nonfinite numbers are rejected. This is the internal foundation for later custom program APIs; it does not introduce Lua execution or a shared-state editor. Squad state and membership currently last only for the match; game save/load remains pending.

Verification and the 200-unit squad workload are recorded in [squad playtest evidence](playtests/2026-10-01/SQUADS.md).

## 26. Role-specific programs — implemented 2026-10-01

Compatible units now ship with specialist choices alongside the original Hold, Guard, Escort and Patrol defaults:

| Unit role | Specialist | Behavior |
| --- | --- | --- |
| Tank / long-range armor | Standoff armor | Acquire within the assigned area; back away below 55% of weapon range, stop backing near 80%, and fire from a legal position. Reposition destinations stay inside the assigned area. At its edge, hold/fire rather than flee across the map. |
| Strike aircraft | Strike & return | Requires an assigned strike area and a regroup point. Fire one shot, return to regroup, wait for the existing weapon cooldown, then re-evaluate the strike area. No fuel or ammunition resource is introduced. |
| Combat walker / long-range armor | Fire support | Move to the assigned anchor and fire only at legal targets within the sector and weapon range. Do not pursue an escaping target. |
| Scout drone | Scout route | Follow two player-assigned patrol waypoints. Missing routes wait for assignment; normal safe-point retreat rules apply. |
| Repair robot | Escort & repair / Service area | Follow a chosen ally and service eligible targets in its radius, or service the assigned area. Existing strongest-channel/two-slot rules and squad repair claims remain authoritative. |

Health retreat takes priority inside programs, with existing 30%/80% hysteresis; manual commands retain higher authority than all specialist behaviors. Strike aircraft complete regrouping even if the struck target dies or disappears. No preset chooses objectives, spends resources, invents map assignments or acquires hidden targets.

The dropdown lists only presets relevant to the selected roles. Mixed-selection Apply and map assignment affect compatible members only. Other units keep their orders and program assignments. Saved presets retain exact versions in the existing schema; old versions remain valid. Loading an incompatible saved preset shows a disabled Apply state. Factories validate role compatibility at enqueue and spawn: incompatible versions fall back to Hold with a reason. A notice received during map assignment is deferred until the instruction finishes. Assignment guides choose a representative unit with an actual assignment, and strike area/regroup points are linked on the map.

Real combat regressions cover both factions, standoff movement/fire/bounds, support no-pursuit, repeat one-shot sorties, cooldown/pause, emergency retreat/recovery, manual override, named scout/repair defaults, version round trips and factory fallback. The rendered flow checks mixed-role Apply, assignments, saved incompatible drafts and 720p layout. See [specialist verification](playtests/2026-10-01/SPECIALISTS.md).

## 27. Lua runtime and unit actions — implemented foundation 2026-10-01

The game now has a native Lua runtime and a developer integration API for real programmable-unit actions. Every unit has a private VM with 256 KiB of Lua allocations and a 50,000-instruction initialization/evaluation budget. Text source is limited to 32 KiB, explicit unit state to 16 KiB, and snapshots to the nearest 32 currently eligible contacts. Lua receives copied plain data and opaque current-contact handles; no engine objects, files, networking, dynamic modules or debug APIs are available.

Scripts return bounded Hold, assigned-point Move, legal Attack, assigned Escort or eligible Repair intents. Five staggered evaluations per simulation second respect tactical pause. The engine retains chip/technology checks, player assignments, visibility, line of fire, range, weapon cadence, repair eligibility and manual command priority. Invalid edits retain the current program/order. A fault stops the script once, clears its actions and holds with idle defense. The selection panel shows Error/reason and keeps Manual/Resume usable; Resume starts clean. Long diagnostics stay within the panel and retain the full hover trace.

Both-faction gameplay and native sanitizer/bridge tests pass. The full 200-unit Lua workload moved every unit without a VM fault and exercised 99 weapons. After removing duplicate snapshot queries it measured 27.93/34.13 ms mean movement/combat, with 44.17/55.68 ms p95 at 1080p on the development Mac. Stable 30/60 FPS acceptance remains open.

The native build, pinned dependencies, supported API and limitations are in [Lua runtime contract](LUA_RUNTIME.md), with [verification evidence](playtests/2026-10-01/LUA_RUNTIME.md). The built library is present locally; fresh source checkouts build it from the pinned sources. Section 28 adds custom Lua editing/saving and exact-version factory records. Section 29 adds visual rules. Section 30 adds the battle test arena; squad Lua memory remains next-stage work. LLM drafts and campaign/save-load are not implied by this foundation.

## 28. Player-facing Lua authoring — implemented 2026-10-02

Programmable-unit selections now expose a **Lua editor**. It pauses the match, offers Hold/Guard & regroup/Repair starters, syntax highlighting, role and capability requirements, a compatibility count, an isolated sample trace and explicit Save version / Apply & run controls. Closing preserves an unsaved draft for the match and restores the prior pause state. Ordinary presets remain available without opening code.

Saved Lua versions contain stable ID, revision, source/API metadata and hashes, roles, capability requirements and initialization test notes. Legacy presets migrate in memory and are preserved on the next save. Invalid/corrupt libraries are not overwritten. Saving or checking changes no order; group Apply prepares every eligible VM before changing any unit, skips incompatible/unready members and starts on the next simulation tick. Direct orders and factory rally retain priority.

Factories pin the exact version and content hash. Queued jobs embed a deep copy, so later edits or a deleted library cannot change deployed behavior. Missing, changed, incompatible or uninitializable versions produce Hold with a reason. Assignment points, live contact IDs and runtime state are never saved into the library record.

The sample checker exercises eight synthetic snapshots per supported role without reading or commanding the live battlefield. It is explicitly not battle simulation; sections 29–30 add visual rules and a real arena/expected-outcome trace. Parameter-schema editing, import/export UI, program deletion/renaming and LLM generation are not delivered by this slice.

[Authoring verification and review images](playtests/2026-10-02/LUA_AUTHORING.md) record both-faction version/factory/manual/pause checks and actual mouse/keyboard flows at 720p and 900p. Broader performance, campaign, faction/map and save/load acceptance remains on the roadmap.

## 29. Visual rule authoring — implemented 2026-10-02

Programmable-unit selections expose **Visual rules** beside the Lua editor. Five starters cover Hold, Guard & regroup, Scout patrol, Escort and Repair. Players reorder up to twelve condition/action cards, adjust retreat/recovery thresholds and optionally choose named states. The first matching rule with an available target returns one intent; a state transition affects the following tick. Resume resets private program memory. Requirements are derived from actions, and the editor lists required battlefield assignments.

The versioned rule document generates deterministic Lua shown in a read-only tab. It uses the same bounded interpreter, copied observations and manual-order authority as custom Lua. Schema-3 library records retain both graph and generated source; loading verifies their agreement and canonical content hashes. Older preset/Lua records remain readable without read-time rewrites. Future compiler changes require an explicit version/migration policy so saved source remains reproducible.

Editing pauses the match and retains separate visual/Lua drafts. Check samples displays rule/action reasons for synthetic inputs; Save version changes no orders, and Apply explicitly commits compatible prepared VMs. **Copy as Lua** opens a separate unsaved source draft, preserves the original visual version and carries pause ownership across the handoff. Arbitrary Lua cannot be reconstructed as cards. Both modes require the native runtime; built-in presets remain independently usable.

Both-faction behavior and factory/manual authority, graph integrity, repair-area targeting and real-input 720p flows pass. The rendered 200-unit workload evaluated all 200 VMs, moved every unit and exercised 97 weapons, averaging 27.87/34.15 ms movement/combat (p95 44.12/54.97 ms) on the development M1 Pro. Stable 30/60 FPS remains open. Section 30 adds the battle arena. Campaign, save/load and LLM assistance remain separate stages. See [verification and screenshots](playtests/2026-10-02/VISUAL_RULES.md).

## 30. Battlefield program test arena — implemented 2026-10-02

Both program editors now expose **Battle arena** for valid saved or unsaved drafts. An isolated desktop window runs real units, navigation, weapons, repairs, current-contact observation and the same Lua action authority. The original battle remains paused. Players choose a compatible role and one of seven scenarios: retreat/recovery, moving escort, lost enemy contact, missing assignment, manual override, unreachable ground destination or destroyed repair target.

Each scenario states its intended outcome and reports concrete observations with a bounded time/position/HP/intent/reason trace. Pause freezes the test; Restart creates fresh units and memory. Return brings completed results to the editor without applying anything. Results bind to the exact draft, and Save version retains a bounded summary of scenario evidence in test notes. Changed drafts require a new run. Both-faction checks, all-role manual takeover, intentionally wrong/stale/faulting programs and actual child-window launch/return tests pass.

The process boundary isolates existing global match groups/signals. This is currently a desktop implementation; exported packages and other operating systems remain unverified. The arena does not establish economy/chip timing, balance, novice usability or target-hardware performance. See [arena behavior, evidence and limitations](playtests/2026-10-02/BATTLE_ARENA.md). Tutorial, save/load and optional LLM assistance remain next-stage work.

## 31. First Orders campaign slice — implemented 2026-10-02

The main menu now offers **Campaign → First Orders**, the first playable slice of operation 2. A dedicated 80 × 64 training map introduces lab construction, a shipped repair/retreat program, and infantry control of a logistics relay. Bastion starts with conventional tanks, infantry, engineers and one chipped repair robot against Helix guards. No code, Lua runtime or network is required for the preset path. There is no reinforcement timer during the build/program lessons.

Infantry within 3 m capture in ten simulation seconds; more infantry do not accelerate capture. Opposing ground combatants contest, while engineers and aircraft cannot capture or contest. Ownership persists without a garrison and supplies only local 9 m vision subject to terrain obstruction. The public objective marker remains visible through fog without revealing surrounding forces. Relay scenery has a navigation footprint and never becomes a weapon/Lua unit contact.

After the first player capture, hold the relay for 60 uncontested seconds. Contest pauses the hold; enemy recapture resets it. Three finite responses target the disclosed relay, each with at least ten seconds of warning. Story/Standard/Veteran use 3/4/5 units per response with unchanged health/damage. An occupied arrival zone denies reinforcement entry until clear; responses cannot materialize on a player force. Victory stops simulation and further arrivals. Losing the HQ allows 60 seconds for a completed replacement; losing HQ and all mobile forces ends the mission immediately.

A left-side lesson panel identifies the next action and offers Find unit/View relay. It stays clear of selection/program controls and the minimap at 720p. Players retain ordinary selection, orders, construction and tactical pause. Saving a changed retreat threshold, then loading and applying its exact preset version, earns the optional Adaptive doctrine badge. Editing a loaded preset clears its saved-version identity. Completion and the cosmetic badge persist in a bounded, validated, atomically replaced campaign progress file; corrupt files are preserved with a message.

This delivers one compact tutorial operation, not the six-operation campaign or full game-state save/load. Novice usability, campaign pacing, all-difficulty balance and cross-platform exports remain acceptance work. [Verification and review images](playtests/2026-10-02/FIRST_ORDERS.md) cover the real preset-only victory, capture/contest/vision, Command recovery/defeat, progress integrity, menus and 720p controls.

## 32. Game-state persistence — capture and restoration 2026-10-02

The first persistence stage captures an active paused match into bounded, inert, versioned data. It records economy/research, construction/cargo, remaining weapon/production/objective durations, commands/action trees, exact programs and queued versions, explicit Lua memory and contact handles, squads, in-flight damage, explored fog and last-known structures. References use snapshot entity IDs, and numeric bits survive disk round trips. Corrupt or unsupported existing files are preserved.

The Lua checkpoint helper rebuilds the exact source in a fresh bounded VM, restores explicit memory, preserves saved fault suspension and warns when invalid memory must be discarded. Explicit Resume still clears memory. A real 200-mobile fixture with 188 large program states round-tripped an 18.8 MB file; rendered fog history and shared runtime/combat regressions passed.

Validated scene restoration now rebuilds both factions and the campaign with exact paid queues, action timers, manual authority, fault state, squad memory and fog knowledge. Missing targets fall back safely; loaded battles remain paused with working Resume and current population/power indicators. Actual reloads, repeated saves, active firing and a rendered 720p resume flow pass. The player archive now exposes five manual slots, F5 quicksave, F9 quickload review and three rotating campaign checkpoints. It is available from the main menu, battle menu and results. Overwrite/load confirmation, error feedback, input isolation, paused resume and recovery after a navigation failure are verified with real 720p input and backend regressions. A 200-mobile snapshot also loads and saves again with its 188 large program memories intact. See the [state inventory, format, verification and remaining obligations](SAVE_LOAD.md).

## 33. Optional LLM assistance — provider foundation 2026-10-02

The first LLM stage provides configurable OpenAI Responses and explicitly selected Chat-compatible requests, scoped native credentials, bounded context/output and inert draft responses. The default is a pinned small model with strict structured output, an adjustable output limit and timeout. Players bring their own key; persistent storage is opt-in, with session-only operation available. Requests never automatically retry, follow redirects, choose another provider or execute generated Lua. Explain cannot replace source. Code generation remains an optional authoring tool with no live simulation authority.

Local verification covers real HTTP cancellation/retry/timeout/limits, both wire formats, invalid replies, pause ownership and isolated macOS Keychain read/write/update/delete. It found and fixed a threaded-request cancellation hang. No live paid call was made. The player-facing Create/Revise/Explain and parameter review/import controls remain the next stage; existing visual rules and presets work offline. See the [provider contract and verification](LUA_RUNTIME.md#optional-llm-provider-foundation--2026-10-02).

## 34. Player-facing LLM authoring — 2026-10-02

The Lua editor now offers an optional AI assistant with Create/Revise/Explain, provider settings, masked credentials, context disclosure and a separate response review. Import explicitly creates an unsaved draft; existing checks, battle arena, Save and Apply retain authority. Explain is read-only. Offline numeric parameters survive saved versions, factory queue inheritance and battle restoration. Changing a parameter creates a new draft, while freeform changes to its generated declaration detach stale controls. Visual rule cards stay separate and can be copied to Lua.

The 720p mouse/keyboard workflow passes against a local HTTP fixture, including malformed/refused/incomplete/oversized replies, rate limits, diagnostic consent, pending-request cancellation and complete editor reopen. Hostile infinite-loop Lua remains inert until explicitly checked, then fails within the sandbox budget. Parameter changes are verified to alter the Lua decision at the chosen health threshold. Both-faction factory/authority and actual save restoration preserve metadata. The assistant is available for player-configured endpoints; live-provider/model quality, other native credential platforms and novice acceptance remain open. See the [authoring behavior and evidence](LUA_RUNTIME.md#llm-authoring-ui-and-offline-parameters--2026-10-02).

## 35. Alpine Relay skirmish — 2026-10-02

Alpine Relay is a selectable 128×104 snow battlefield for both factions, with Standard and Advanced starts. Two separated ground passes and an outer bypass connect opposed bases; aircraft can cross the low glacial ridges directly. The new layout changes navigation and choices, with its own icy lighting, procedural terrain, menu preview and minimap features. The low ridges preserve the existing aircraft flight plane; tall mountain flight and final environment art remain later work.

Each side has a 600 Materials / 240 Electronics home field and a 900 / 400 expansion. Two staging-area relays grant local vision after infantry capture them for ten seconds. Relays remain optional: Command destruction and the existing rebuild timer decide victory. Their public locations and ownership let AI dispatch up to one available infantry unit per unowned relay without reading hidden enemies. Owner, capture candidate, progress and contest state are preserved in battle archives. Relays sit beside the main passage after rendered group testing exposed congestion around a central installation.

The measured navigable base route takes approximately 40.8 seconds at basic-tank speed; a ridge crossing measures 38 m by ground versus 24 m in the air. These are path estimates, not performance measurements. The initial map is a playable layout pass; Desert revision, faction signatures, further maps and full-match pacing acceptance remain separate work.

`tests/headless/AlpineRegression.gd` passes headless and rendered on Metal: both factions' 16-tank transit and actual aircraft shortcut, Standard-start Materials/Electronics delivery, ridge placement rejection, relay sight/recapture, archived progress and AI assignment. The rendered run also selects the map through mouse/keyboard input at 1280×720. Shared skirmish/campaign restoration, editor import and focused lint pass. Existing navigation-readback and shutdown shader/resource warnings remain. Review: [map selection](../art/skirmish/alpine-menu-720p.png), [north pass](../art/skirmish/alpine-pass-720p.png), [battlefield overview](../art/skirmish/alpine-overview-bastion.png).

## 36. Mobile weapons and Lancer modes — 2026-10-02

The first faction combat stage replaces the two factions' identical dual-domain walker behavior with distinct choices:

| Unit / mode | Legal targets | Range | Base damage / reload | Armor profile |
| --- | --- | --- | --- | --- |
| Bastion combat walker | Ground | 5.5 m | 5 / 0.7 s | Autocannon |
| Bastion combat walker | Air | 4.5 m | Same shared reload | Anti-air |
| Helix Lancer — Precision | Ground only | 6.5 m | 9 / 1.25 s | Precision rail |
| Helix Lancer — Interception | Air only | 5.5 m | 5 / 0.7 s | Anti-air |

Lancers start in Precision. Selecting the other mode starts a two-second period without firing, while movement and programmed behavior continue. The existing reload remains in force; switching cannot accelerate it. Another switch cannot interrupt the pending transition. Tactical pause freezes its duration, and saves preserve the current mode, intended mode and exact remaining time. Previously launched shots finish normally before a standard switch completes. Attacks against targets unsupported by the new mode stop when it commits.

The command panel offers Precision and Interception for eligible selected Lancers, with mode counts and switching feedback. Mixed selections leave other unit roles alone. A compact P / AA badge above each Lancer shows its current mode or pending countdown. Mouse and keyboard controls use ordinary Godot focus; factory tooltips explain the role before production. Programs can select legal targets but cannot change mode. Lua contact eligibility now respects Bastion's shorter AA reach and a Lancer's switching lock.

The skirmish AI chooses Interception when it observes a nearby aircraft, Precision for observed ground contacts, and retains its stance when contacts disappear. It cannot react to an aircraft occluded by a building. This is an opponent-command decision, separate from the player's Lua API.

`WeaponModeRegression.gd` verifies actual damage and shared reload, legal ranges/domains, moving and pausing through a switch, the no-fire interval, exact partial-switch disk restoration, continued reload and resumed firing, invalid saved modes, legacy reconstruction and occluded-air AI behavior. Snapshot version 2 writes weapon state; version 1 remains readable and starts old Lancers in Precision with a visible migration note. `WeaponModePreview.gd` verifies actual 720p clicks and Enter, mixed/single selection, running programs, movement preservation, paused transitions and death cleanup. Shared combat, skirmish, Lua and both restoration suites pass. Review: [mixed selection](../art/skirmish/weapon-switch-mixed-720p.png), [single Lancer](../art/skirmish/weapon-switch-single-720p.png).

These numbers are initial tuning, not equal-budget balance acceptance. Precision preparation, Prism setup/charge, Anchor/Precision group abilities and extended encounter testing remain in the staged plan. Existing navigation-readback and shutdown-only resource warnings remain.

## 37. Precision preparation and Prism deployment — 2026-10-02

Precision fire now has an interruptible 0.75-second charge after the normal reload: Bastion railgun, Helix Prism and Lancer Precision all use it. The first legal shot starts with preparation when its reload is already available. A subsequent shot waits for both reload and fresh preparation; the existing damage and reload values are unchanged. This lowers sustained precision damage compared with the earlier instant-shot prototype. Ordinary cannons, rifles, missiles and Lancer Interception do not gain this delay.

Prism also needs 1.5 seconds stationary to deploy its supports. Deployment is automatic, so players can establish a firing position before a target arrives. It stays deployed while holding; an active move order or physical displacement retracts it and requires fresh setup. Its 10 m range remains 125% of the Bastion railgun's 8 m. The Bastion railgun needs only the charge, preserving the faster relocation role.

Preparation belongs to the current attack and target. Moving, switching target, losing a legal firing lane or changing Lancer mode cancels it. A charged attack cannot be transferred to another target. Reload time is never bypassed by cancel/reissue. Mode switches and Stop update the charge warning even while tactically paused. Normal Hold behavior may subsequently acquire a legal target and start a new charge; Stop is not a permanent cease-fire command.

Muzzle energy grows during preparation, a charge percentage appears above the unit, and Prism supports extend with deployment progress. Selected Prism units report deployment in the command panel. These visuals are reconstructed in paused saves, so a loaded imminent shot remains visible before Resume. Snapshot version 3 stores exact preparation duration/origin and deployment; versions 1 and 2 remain readable with fresh preparation/deployment under the new rules.

`PreparationRegression.gd` passes actual damage, first-shot/reload timing, pause, movement, target changes, a newly completed line-of-fire blocker, Lancer mode interruption and immediate Interception. It saves and restores both partial deployment and partial charge through real files, checks duration/schema rejection and resumes to exactly one hit. Version-1/2 fixtures pass preflight; actual version-2 Prism reconstruction starts fresh setup and completes it after Resume, while `WeaponModeRegression` covers actual version-1 reconstruction. `PreparationPreview.gd` passes Metal rendering and 720p mouse input, including loaded charge visibility, paused Stop, preserved HP until a fresh preparation and panel bounds. Shared combat, specialist programs, mode behavior and both restoration suites pass. Existing navigation-readback and shutdown-only resource warnings remain.

Review: [Prism deploying](../art/skirmish/prism-deploy-720p.png), [paused restored charge](../art/skirmish/prism-charge-restored-720p.png). This delivers preparation/deployment; Anchor formation, Precision window, equal-budget combat tuning and final VFX/performance acceptance remain open.

## 38. Faction coordination signatures — 2026-10-02

Coordination now unlocks explicit faction abilities for up to six ready chipped ground combatants. Bastion's **Anchor sector** button enters a world-point assignment: select a 6 m sector, or cancel with Escape/right click. The nearest eligible selected units keep their current orders; after two seconds stationary inside the sector, they take 15% less weapon damage from every direction. Moving breaks the benefit immediately, including a program's low-health retreat. Re-entering does not automatically reactivate it. The ten-second cooldown begins on activation.

Helix's **Precision window** button works on stationary, deployed, reload-ready precision weapons with a visible legal target. For two seconds, each participant has one 20% faster preparation: 0.75 becomes 0.60 seconds. An already charging shot receives the same 0.15-second reduction without replacing the action. Damage and sustained reload are unchanged; cancelling the shot consumes the opportunity. The eight-second cooldown remains after the window expires.

An activation cohort is independent of named program squads. Both the participant and cohort retain cooldown state, so regrouping cannot reset it; disjoint ready units may activate independently. No ability issues movement, interrupts an existing program or becomes a Lua action. The opponent commander uses these same rules and only observed contacts. The panel reports eligibility/cooldown, world badges report setup/benefit, and neutral dashed outlines show all selected Anchor sectors even alongside a program assignment.

Snapshot version 4 preserves exact per-unit ability state and cohort membership/cooldowns. Paused reconstruction retains partial Anchor setup and already-consumed Precision alongside the accelerated attack; versions 1–3 remain readable and start without abilities. Dead members are omitted safely. The schema rejects invalid durations, duplicate members and missing cohort references.

Verification: `SignatureRegression.gd` passes the six-unit cap, research/chip/ownership gates, real front/rear damage, manual movement and programmed retreat, regroup protection, disjoint activation, exact paused file restoration, single-use charge timing, unchanged damage/reload, cancellation, observed-target eligibility, opponent use, death cleanup and actual version-3 reconstruction. `SignaturePreview.gd` passes 720p Metal mouse/keyboard activation, both cancel paths, preserved running programs, pause/cooldown, expiry and panel bounds. Shared combat, preparation, weapon-mode, Coordination, squad, Lua, skirmish and restoration checks pass. Existing navigation-readback and shutdown resource warnings remain.

Review: [Bastion Anchor](../art/skirmish/signature-bastion-720p.png), [Helix Precision](../art/skirmish/signature-helix-720p.png). This delivers the signature mechanics; readable value of the 0.15-second gain, equal-budget combat tuning, final effects and release performance remain acceptance work.

## 39. Desert Frontier route revision — 2026-10-02

New Desert skirmishes use a 128×96 layout with starts at (18,26) and (110,70). A weathered central freight apron offers room to assemble and change direction; north and south flanks bypass it. Four low sandstone shelves obstruct ground travel and direct ground sight while respecting the current 1.5 m flight plane. Worn route markings connect the approaches. These are navigable choices, not three mandatory narrow choke points.

Home fields are rotationally paired at (14,43) and (114,53), each with 600 materials and 240 electronics. Outer fields at (52,6) and (76,90) each provide 900 materials and 400 electronics, putting more electronics away from starting-base protection. Total stock is 3,000 materials / 1,280 electronics. Both start footprints remain clear for Standard/Advanced bases, and the central apron permits construction.

The new map uses a separate `DesertFrontier.tscn` identity. `BastionDesert.tscn` retains the original 64×64 layout for existing archives, regression fixtures and the art demo. The skirmish menu, preview and minimap show the revision; no old save is silently moved onto new terrain. Match victory remains Command destruction with the existing rebuild grace period.

`FrontierRegression.gd` measures a 36.7-second base route at 2.6 m/s, and a shelf crossing of 38 m by ground versus 34 m by air. For both factions it sends three separate 16-tank groups through all approaches and back, including a real archive/load during the advance. It checks blocked shelf placement, legal staging-ground placement, exact field counts after restore, both starting-side home economies and isolated outer-electronics collection/return. Headless checks pass; Metal rendering confirms the same traversal, retreat and economy cases. `FrontierMenuPreview.gd` verifies mouse opening and keyboard selection/closure at 720p; the popup receives injected input through its own viewport. `FrontierAIRegression.gd` exercises six simulation minutes per opponent: Bastion built seven structures and Helix six, each launched four attacks and produced seven units. These are scenario observations, not a balance claim. Shared Alpine, skirmish and legacy restoration checks pass.

Review: [map selection](../art/skirmish/frontier-menu-720p.png), [overview](../art/skirmish/frontier-overview-bastion.png), [staging ground](../art/skirmish/frontier-staging-helix.png). Environment treatment remains initial procedural art; repeated full-match pacing, equal-budget faction encounters and final environment/audio/performance acceptance remain open. Existing navigation-readback and shutdown-only resource warnings remain.

## 40. First controlled encounter tuning — 2026-10-02

A real-unit encounter probe now measures first damage, first loss, surviving HP, duration and both resource costs across mirrored placements on Desert Frontier. It uses attack-move for approaching armies, explicit fire-support for prepared defenders and escort-repair for support robots. No signatures, reinforcements, production or income operate during the encounter. Twelve scenarios produce 24 observations at fixed 60 Hz. Both currencies remain separate; each comparison reports its budget ceiling and each side's unspent funds. A more expensive composition defeating a cheaper one is not evidence of equal-budget faction balance.

The original Lancer had 52 HP, a 6.5 m range and 9 base rail damage, followed by 1.25 s reload and 0.75 s preparation. Three Lancers costing 78 M / 60 E lost to three Bastion tanks costing 72 M / 18 E, including a prepared fire-support line. Range and damage left the expensive specialist unable to perform its intended anti-armor job after preparation was introduced.

The revised Precision weapon has **8 m range, 15 base damage and a dedicated anti-armor profile**: infantry ×0.3, light machines ×0.8, heavy armor ×2, structures ×0.5. Actual hits are 4.5 / 12 / 30 / 7.5 damage. Reload, charge, 52 HP, mobility, resource cost and Interception remain unchanged. This focuses its role without giving all rail weapons a global buff. Unit descriptions and mode tooltips report the range, heavy-armor hit, charge and infantry weakness.

| Scenario | Original result | Revised result |
| --- | --- | --- |
| Three Lancers vs three Bastion tanks, approaching | Lancers lose both placements | Lancers win at about 5.77 s, each survivor on 16 HP |
| Three prepared Lancers vs three approaching tanks | Lancers lose at 11.3–11.8 s | Lancers win at 10.28–10.32 s; two survive |
| One Lancer vs one tank at 5 m | Lancer dies at 6.33 s; tank has 42.2 HP | Lancer wins at 5.13 s with 7 HP |
| Twelve infantry (72 M / 0 E) vs three Lancers (78 M / 60 E) | Not part of the retained original matrix | Infantry wins both placements at 8.05–8.10 s |
| Bastion/Helix basic tank duel | Bastion wins at about 8.7 s | Unchanged; meets the 8–15 s reaction-time target |

[Original observations](playtests/2026-10-02/encounters-before-lancer-tuning.json) and [current observations](playtests/2026-10-02/encounters.json) retain complete costs, stats and results. The probe now asserts only the basic tank reaction-time envelope and the intended Lancer armor/infantry counter relationships, rather than pinning exact winning HP or all encounter outcomes. Prepared Prism groups still require support against a larger tank line in these scenarios; this pass does not claim their combined-arms acceptance. Repair support changes survivability without reversing every matchup.

Verification: affected weapon-mode, preparation, signatures, specialist programs, Lua, combat, skirmish and restoration regressions pass. The updated weapon tests cover 30 damage to armor, 4.5 to infantry, 12 to light machines and the eight-metre firing boundary. Actual Precision-window archive restoration still accelerates one charge without changing its hit or reload. Rendered mode controls pass at 720p. `EncounterPreview.gd` checks actual rendered armor and infantry counter outcomes; review [armor encounter](../art/skirmish/encounter-lancers_vs_armor.png) and [infantry encounter](../art/skirmish/encounter-infantry_swarm.png). Existing navigation-readback and shutdown resource warnings remain.

This is a first role-correction pass, not PvP balance or complete PvE pacing acceptance. Repeated live matches, wider mixed armies, signature value/readability, terrain-dependent engagements, retreat/repair cycles and Prism support doctrine remain further work.

## 41. Shared player settings — 2026-10-02

Main-menu Options and the battle menu's Settings button now open the same 720p-friendly, keyboard-accessible panel. It offers master and voice volume (0–100%), pan speed (50–200%), zoom speed (50–300%), screen-edge scrolling, pointer confinement, fullscreen/windowed mode and reduced bright combat effects. A voice sample uses the same Voice bus as narrator announcements and unit responses. Master volume affects the whole game; voice volume composes with it rather than replacing it.

Changes preview immediately. **Save & back** writes the existing options resource through a temporary sibling and rename; **Cancel / Escape** restores the prior values. Reset previews defaults without committing them. Write failure keeps the panel open with retry/cancel feedback. Older screen/mouse-only option resources receive defaults for new fields; numeric values are finite and bounded. These preferences remain outside battle archives and program files.

Opening settings freezes the current scene, including children that normally process while paused, and prevents save hotkeys opening another modal. Closing restores every processing mode, the previous pause state and keyboard focus. A running battle returns through its paused battle menu; a tactically paused battle remains paused. Pan and zoom read live preferences. Reduced flashes suppress new flash/spark/fire particles while retaining tracers, charge warnings, damage and orders; this does not disable unit motion or every bright element.

Native fullscreen transitions exposed a macOS race: the system may ignore a second display request while animating the first. The options model now remembers the latest intended display mode and reconciles it at 150 ms intervals for up to five seconds using wall time, including while the battle is paused. Cancel restores the prior display intent, and windowed mode preserves an already-maximized window. This is native display synchronization, not a gameplay timer or background task.

`SettingsRegression.gd` verifies actual isolated file round trips, old-field defaults, invalid numeric values, audio gain/mute, cancel/save and real write failure, both paused/unpaused entry states, scene/camera/order freeze, pan-speed scaling, zoom behavior and both voice routes. `SettingsPreview.gd` verifies real 720p mouse and keyboard input through main and battle entry points, sample playback, focus restoration, saved choices, Esc rollback, blocked W/F/F5/Space inputs, live fullscreen/confinement and rapid cancellation during a native transition. It also confirms actual weapon damage with reduced flashes enabled. The final native run uses the normal clock with a 60 FPS cap and wall-time watchdog; it passes with zero failures. F5 isolation also asserts that no quicksave file is created in a dedicated test directory. Shared combat, skirmish, signature and save-slot/campaign-checkpoint checks pass. Deliberately unwritable settings paths produce an expected engine error in the failure test; existing navigation-readback and shutdown resource warnings remain.

Review: [main-menu settings](../art/skirmish/settings-main-720p.png), [battle settings](../art/skirmish/settings-battle-720p.png). Native display behavior was verified on this Mac; Windows/Linux acceptance, remappable keys, scalable HUD/text, wider accessibility and finished audio production remain open.

## 42. Split Signal campaign operation — 2026-10-02

Operation 03 is now playable from Campaign alongside First Orders. Both operations are directly selectable during development; the missing Supply Line opening is not a prerequisite. Mission selection uses two visible buttons with mouse/keyboard support, independent completion labels and mission-specific difficulty/briefing. Restart, results, battle menus and archive summaries preserve the selected operation.

Split Signal places three public relay objectives on a new 108×88 mountain uplink map. North and South are separated by a central low ridge; the exposed East relay connects their approaches. Roads disclose routes, while low shelves block ground movement and sight without obstructing the existing aircraft altitude. Home and two outer resource fields provide 1,800 Materials and 540 Electronics. Public relay labels and minimap markers disclose objective locations and state, not hidden units. Captured relays retain the shared nine-metre local vision rule.

The player begins with an HQ, two power plants, barracks, vehicle factory, command lab and repair depot; three engineers, six chipped tanks, twelve infantry, two repair robots and one scout drone; 100 M / 40 E. Basic programs are available immediately. Coordination still requires research. Tanks/support can use shipped Guard and Service area programs, while infantry capture and recapture under player orders. There is no mandatory code or online service, no automated army-wide objective selection and no repeated lab tutorial.

Any **two uncontested human-owned relays** advance a 120-second cumulative uplink. Contesting or losing a relay pauses scoring when fewer than two qualify; earned time is never erased. All three uncontested relays add to a separate 20-second cumulative optional objective. Victory records completion and any earned Air Corridor support; replay does not erase it. That reward is reserved for the future operation 04 and does not currently change a playable mission. HQ defeat uses the same 60-second completed-rebuild window, or immediate defeat after losing HQ and all mobile forces.

Six finite Helix responses are scheduled 25/50/75/100/125/150 seconds after the first human capture, each announced ten seconds early. Two wings enter from disclosed northeast/southeast approaches and alternate between the outer pair and East relay. Story/Standard/Veteran send 2/3/4 units per wing (4/6/8 total), with one tank in each wing and otherwise infantry. HP and damage are unchanged. A human unit within twelve metres of an entrance permanently denies that wing of that response; the response is resolved once, with no delayed hidden spawn. Attack orders target public relay positions using ordinary attack-move/observation rules. Initial defenders are two infantry per relay; there is no off-map infinite economy or response production.

The compact objective panel shows uplink progress, each relay's ownership/contest/capture status, response count, optional progress and View buttons. It stays above the minimap and clear of the unit/program panel at 720p, including a two-line notice. Native input checks cover both mission buttons, relay locators, save/load, paused resume, replay and return to Campaign. Operation-start and friendly-capture checkpoints use the existing rotating archive. Exact mission timers, response counts, optional state and all three relay ownership/capture/contest records survive a validated disk reload; malformed relay counts, response counts and inconsistent reward state are rejected. The campaign progress file migrates schema 1 to schema 2 while retaining First Orders completion and doctrine badges; malformed files remain untouched.

Verification includes real infantry capture/contest/recapture, retained score, pause, all difficulty response sizes, denied entrances, finite response exhaustion, optional control, HQ recovery/defeat, exact paused file restoration and scheduled continuation. A Standard encounter wins using shipped armor/support programs and periodic manual infantry recapture orders, with no spawned test reinforcements or HP/damage changes. Verified runs finished in about 137–141 simulated seconds after four responses, with 22–24 surviving mobile units. A separate pressure-isolated scenario sends real infantry along all three routes and earns full-network control through ordinary capture timers before main victory. It is evidence of a viable route, not all-difficulty balance or novice acceptance. Early unattended attempts sometimes lost their relay screens, so the mission deliberately retains player responsibility for capture and recovery. Final art, reward application in operation 04, full-campaign pacing and remaining missions are still open.

Review: [mission selection](../art/skirmish/split-signal-briefing-720p.png), [objective and program UI](../art/skirmish/split-signal-program-720p.png), [revealed map overview](../art/skirmish/split-signal-overview-720p.png), [battle archive](../art/skirmish/split-signal-archive-720p.png). Tests: `SplitSignalRegression.gd`, `SplitSignalPreview.gd`; shared First Orders and archive restoration checks remain part of verification.

## 43. Large-battle observation performance — 2026-10-02

Profiling the 200-unit/200-Lua-VM workload identified repeated searches for an allied observer as a substantial cost. The battlefield now keeps a bounded weak reference to the last successful observer for a player/target pair. Every query rechecks that observer's current ownership, life, construction, range and unobstructed sight. An invalid hint falls back to the normal observer search; failed observations are not cached. Explicit field invalidation clears hints, and the per-player table is capped at 512 entries. These hints are disposable runtime acceleration, not save state. Current sight and direct-fire authority remain separate checks.

In the diagnostic combat run, observer checks fell from 3,456,072 to 365,667 across 600 rendered frames, while inclusive observation-query time fell from about 8.00 s to 1.54 s. The uninstrumented fixed-step comparison improved combat mean/p95 from 34.83/55.74 ms to 26.81/38.32 ms at 1920×1080 on the M1 Pro. All 200 units still moved, all 200 private Lua VMs evaluated without faults, and more than 90 weapons fired. Unit counts, program cadence, visibility rules, HP fixture, animations and effects were retained.

**The performance gate is still failing.** A new normal-clock benchmark exposes the simulation catch-up cost hidden by fixed-step throughput: the reference combat run averaged 223.48 ms per rendered frame (p95 271.29 ms); the optimized run averaged 147.89 ms (p95 179.00 ms). Roughly 10.1 simulated seconds still took about 12.0 wall seconds after optimization. These are intentionally heavy 200-VM/80-building development loads, but they demonstrate that stable 30 FPS and no sustained simulation backlog are not yet achieved. The fixed-step result must not be presented as normal gameplay FPS. Further profiling must separate physics, navigation, cosmetic updates and rendering costs without reducing the supported army/program workload.

`ScaleBenchmark.gd` now supports explicit normal-clock measurement, an isolated reference-query implementation, and a diagnostic timing wrapper. It reports mean/p95/p99, frames above the 30-FPS interval, sample count and simulation/wall duration. [Measurements, commands and verification](playtests/2026-10-02/PERFORMANCE.md) and [raw summary](playtests/2026-10-02/performance-observer-hints.json) retain both favorable and failing results. Broader effects, large Lua memories, long sessions and native-platform performance acceptance remain open.

## 44. Playable skirmish loop first — 2026-10-02

The user explicitly deferred performance optimization and prioritized gameplay. Further profiling is off the current work queue; retained measurements are late-stage acceptance evidence.

Skirmish now has a collapsible, context-sensitive Battle plan: gather both resources, establish infantry defense, build factory/lab, fit chips, configure a default Guard program, reinforce, scout and assault the enemy HQ. Nine combat units is a suggested opening strength, not a restriction. Own-unit shortcuts expose engineers, idle workers, factories, a chip unit and the army without issuing orders or spending resources. Recovery hints cover missing HQ/workers, low power and unfinished construction. Advanced starts skip completed infrastructure; campaigns retain their existing authored guidance. Saved matches recompute guidance from restored own-state.

A gameplay-blocking harvest issue found in the opening is fixed: passive avoidance nudges no longer pause gathering indefinitely while a worker remains in contact. Resource rates/cargo limits are unchanged, out-of-range collection stops, and tactical pause still freezes timers. Old crowd-paused harvest archives normalize that obsolete pause on restoration.

A paid Standard-start playthrough against live Easy AI reached victory for both factions, at about 8:36 Bastion / 8:40 Helix, using normal harvesting/construction/production, factory-fitted tank chips, a built-in Guard preset, infantry protection and manual assault orders. Earlier unattended/congested openings lost; this validates a viable playable route, not balance or novice acceptance. Native 720p selection, harvesting, assignment, Apply, collapse and pause controls pass; collection/legacy-save and shared navigation/archive regressions pass. [Full evidence and review images](playtests/2026-10-02/SKIRMISH_LOOP.md).

The next work stays on gameplay: resource-field assignment/work slots and safe depletion behavior, economic recovery, then the missing conventional campaign opening. Performance work remains deferred.

## Agent progress

- Completed: Broken Foundry's urban map, finite paid factory production, capture/hold loop, bounded defenders, reward integration and exact archives. Actual artillery, repair/pursuit, paid Standard victory, 720p UI and shared archive/campaign checks pass (section 49). Command Horizon and wider product acceptance remain open; performance stays deferred.

- Completed: Air Corridor's ground/air map, explicit evacuation controls, combined-arms/preset loop, finite responses, campaign rewards and active-flight archives. Standard headless/native playthroughs save all three flights; 720p control and shared campaign/archive checks pass (section 48). Operations 05–06 and broader acceptance remain open; performance work stays deferred.

- Completed: contextual skirmish loop guidance, own-unit shortcuts, crowd-safe collection and legacy timer recovery; both-faction paid openings reach real victories and native 720p program flows pass (section 44). Gameplay is now the active priority; optimization is deferred.

- Completed: bounded, live-revalidated observation hints and fixed-step/normal-clock scale measurements. The normal-clock 200-VM workload still fails the frame-rate/backlog gate; further optimization remains required (section 43).

- Completed: Split Signal map, split-control campaign objective, finite warned responses, operation selection, completion migration and exact archive integration (section 42).

- Completed: shared persisted settings with audio/camera/display/effect previews, cancel rollback, native display synchronization and verified main/battle modal behavior (section 41).

- Completed: first controlled encounter matrix and Lancer anti-armor role correction, with retained before/after data and shared behavior regressions (section 40).

- Completed: revised Desert Frontier layout, exposed economy, preview/minimap, compatible map identity and both-faction traversal/economy/archive checks (section 39).

- Completed: both faction coordination signatures, selection/sector UI, observed-contact opponent use, exact snapshot-v4 continuity and headless/rendered verification (section 38).

- Completed: initial inspection of the RTS template and capture of the brainstorming discussion through 2026-10-01.
- Completed: recorded confirmed direction, provisional mechanics, alternative choices, technical considerations, and a proposed staged development sequence.
- Completed: incorporated accepted development defaults into the relevant sections and removed superseded open questions in version 0.2.
- Completed: generated the Bastion faction asset set and integrated the playable Desert Frontier art/gameplay demo described in section 16.
- Completed: designed Helix Systems, generated its concept art before modeling, and produced the second faction's 17-model review set.
- Completed: native Bastion design playtest and controlled economy/repair probe; version 0.3 fills shared gameplay gaps and reconciles earlier open proposals.
- Completed: playable Bastion/Helix skirmish setup, faction integration, economic AI, attack move, tactical pause and complete match lifecycle (section 19).
- Completed: combat/repair rules, shared observed-world queries, structure cap, bounded battle effects and initial 200-unit benchmark (section 20).
- Completed: individual idle/gait/hover/recoil/hit/death variation across both factions; [motion verification and review](playtests/2026-10-01/UNIT_MOTION.md).
- Completed: basic chip progression and fitting, local presets, direct-order authority, assignment UI and reusable parameter versions (section 21).
- Completed: Coordination research and factory version inheritance; six industrial salvage models and persistent power meter.
- Completed: resource-art refinement into six distinct silhouettes, matching economy symbols and explicit power usage/reserve/deficit states; rendered 720p and navigation/harvesting verification (section 23).
- Completed: manual order queues, program authority and optional queue-end resume (section 24).
- Completed: explicit Coordination squads, bounded shared state, fire/repair target claims and 720p management UI (section 25).
- Completed: specialist programs and compatibility-aware assignment/library/factory behavior (section 26).
- Completed: bounded native Lua runtime and developer unit-action integration, with both-faction authority/fault regressions, rendered diagnostics and a 200-unit workload (section 27).
- Completed: player-facing Lua drafts/editor, exact saved source versions and factory inheritance, with isolated sample checks and explicit group Apply (section 28).
- Completed: visual rule authoring, generated Lua, separate source copies and exact graph/source versions (section 29).
- Completed: real battlefield program arena, scenario assertions, bounded traces, isolated launch/return and saved evidence notes (section 30).
- Completed: First Orders campaign entry, preset tutorial, capture/hold mission and completion/badge persistence (section 31).
- Completed: save format, snapshots/checkpoints, validated reconstruction and player archive with quick/manual/rotating campaign saves (section 32).
- Next: optional LLM drafts with explicit validation/testing/Apply; continue faction/map depth, campaign completion and performance work.

- Completed: LLM stage 1 provider/credential/context foundation and local transport verification (section 33). Player-facing assistance and live-provider acceptance remain unfinished.

- Completed: LLM stage 2 player-facing review/import, offline parameters and local 720p input verification (section 34). Live provider/model quality and broader product acceptance remain open.

- Completed: local adverse LLM UI acceptance and Alpine Relay's first playable map layout with both-faction headless/rendered verification (sections 34–35). Overall development continues; Desert revision, faction signatures, remaining campaign/maps and performance acceptance remain open.

- Completed: first faction combat stage — distinct mobile anti-air, manual Lancer modes, readable controls/badges, observed-contact AI and saved transitions (section 36). Preparation/deployment and coordinated abilities remain next; overall goal remains active.

- Completed: precision shot preparation and automatic Prism deployment, visible cancellation, exact archive continuity and 720p verification (section 37). Group abilities and encounter tuning remain next; overall goal remains active.


## 45. Resource-field economy (implemented 2026-10-02)

Engineers now retain a player-selected resource type and a local field anchored within 10 metres of the clicked deposit. Each node has two work slots, reserved while approaching/collecting and released during the return trip. Additional engineers wait rather than silently switching type or travelling to another field. Same-type local replacements retain the original boundary; depletion returns partial cargo and asks for reassignment. A destroyed drop-off stops an active return and preserves cargo until the player chooses a friendly completed HQ or another order.

Selection UI shows cargo, collecting/returning/waiting states and group gathering/waiting counts. Depleted and missing-HQ engineers appear in the idle shortcut, with a terminal notification. Right-click assignment and Shift-order handoff retain player authority. Snapshot version 5 persists assignments/waits and supports versions 1–4. Both factions share these economy rules. Work-slot positioning currently uses ordinary approach navigation, without dedicated authored docking pads.

Verification and full-match outcomes are recorded in [Resource fields](playtests/2026-10-02/RESOURCE_FIELDS.md). Broader economic recovery, novice pacing and the remaining conventional campaign opening are still gameplay work; performance optimization remains deferred.


## 46. Economic recovery and expansion guidance (implemented 2026-10-02)

Ordinary skirmish Battle plan now prioritizes economic interruptions even while some gatherers remain active. Stranded cargo selects the affected engineers for an explicit HQ delivery order. Local depletion selects only displaced engineers and asks the player to scout/protect another field before assigning its resource type. Multiple workers waiting for slots receive redistribution advice. Cargo-only deliveries prompt a new field assignment. Advice reads own units, jobs and funds; it neither discovers hidden resource deposits nor issues orders.

Losing every engineer now distinguishes a paid replacement already in the HQ queue, an affordable new engineer, a useful refundable production queue, cancellable Coordination research and an economy with no available recovery budget. Unit-limit guidance points to a paid queue when one can release a reservation. HQ loss distinguishes an existing paid foundation, affordable rebuilding, refundable work sufficient to cover the rebuild and a budget that cannot be replenished through cargo delivery without an HQ. With no HQ or engineer, the guide offers the remaining army and the recovery deadline instead of an impossible build.

Building recommendations show actual shortages and prefer an available engineer; an engineer already assigned to the required foundation retains priority. HQ rebuilding shows the current countdown and 45-second build duration. The advice does not spend, refund, select targets automatically, extend the defeat clock or grant emergency units. It is derived after loading and adds no archive fields. Authored campaign objectives remain separate.

Native testing exposed that paid queue icons inherited simulation pause and could not accept cancellation. The queue UI now remains interactive while production simulation stays frozen, and its normal keyboard focus indicator is restored. Actual mouse/Enter cancellation and reinvestment in an engineer pass at 720p. [Economic recovery verification](playtests/2026-10-02/ECONOMY_RECOVERY.md) records paid recovery, HQ reconstruction, paused archive continuity and remaining limits.


## 47. Supply Line campaign opening (implemented 2026-10-02)

Operation 01 introduces conventional RTS control before chips. A Bastion force of three unarmed supply trucks, four tanks, twelve infantry and two repair robots crosses a 192×128 desert freight corridor against Helix. Trucks have 180 HP, light-machine armor, speed 1.6 and no harvesting, construction, production or programming capability. Their current six-wheel armored transport geometry is a procedural Godot prototype; final Blender art remains open.

Each truck visits South crossing, Ridge depot and Extraction in order. Within seven metres of its current checkpoint it needs 12 cumulative stationary seconds with no enemy ground unit within ten metres. Movement or contest pauses clearance; leaving the checkpoint resets it. Advance convoy orders only the current leg, while Hold clears truck movement. Arrived trucks with remaining movement orders show “Hold to clear”; a stop is still required even inside the checkpoint area. Escort selection and normal right-click/Shift orders remain independent. The player explicitly brings repair support and decides when to continue. Two extracted trucks win; two losses make success impossible and trigger defeat. This operation has no HQ-loss timer, resources, building or research loop.

Each checkpoint has 3/4/5 infantry on Story/Standard/Veteran; the second and third also have a tank. First truck arrival announces a single response ten seconds ahead: 2/3/4 infantry approach that checkpoint. An entry within twelve metres of a live player unit is permanently denied. All three responses are finite; the enemy receives no ongoing economy or unannounced replacement army. These are initial tuning values, not completed all-difficulty balance.

Campaign now directly exposes operations 01–03. The Supply Line HUD shows truck health, next checkpoint and clearance, convoy advance/hold, independent truck/escort selection and three public route locators. Field-force count replaces irrelevant resource/power panels, and locked programming/coordination controls are hidden. Tactical pause, manual archive, rotating checkpoints, result, replay and Campaign return use the shared flow. Mission state restores without advancing simulation, including partial clearance, active orders and already-announced responses.

Completion records a fixed +20 starting materials for fresh First Orders games (100 instead of 80); it neither stacks on replay nor adds funds when loading a saved battle. Progress schema 3 preserves schemas 1–2 and their existing badges. [Supply Line verification](playtests/2026-10-02/SUPPLY_LINE.md) separates the real Standard combat/extraction run, controlled adverse/archive scenarios and native UI fixtures. The current scripted route takes about four simulated minutes; the original 10–15 minute novice target, final art/audio and operations 04–06 remain open. Performance work stays deferred.


## 48. Air Corridor: air/ground evacuation (implemented 2026-10-03)

Operation 04 takes place in a 144×104 industrial quarry. A continuous spoil wall and solid freight containers create north/south ground bypasses; aircraft can cross the middle directly. Cold concrete, slate spoil, marked aprons and an east flight lane distinguish it from the earlier desert corridor. The map and compact four-nacelle Rescue VTOL use procedural prototype geometry; this is not final environment or Blender vehicle art.

The player starts with an established Bastion HQ, lab, infantry/vehicle/air producers, three generators, a depot, two engineers, six infantry, four chipped tanks, four combat walkers, two repair robots, two strike aircraft and a scout. Starting resources are 140 materials and 80 electronics. Shipped programs and ordinary direct orders are both available. The player clears two real Helix anti-air batteries with ground troops, positions a screen east of the quarry, and explicitly launches one evacuation at a time. The Rescue VTOL is an unarmed 150-HP air unit with no chip or production role; it can be stopped, redirected, serviced at the hangar and explicitly sent onward with Continue flight.

Three flights are available. A launch requires both batteries destroyed, no flight already airborne, and one free mobile-unit slot, including paid queue reservations. Entry within five metres of the marked exit extracts a flight. Two extractions enable Finish operation; the player can instead attempt the third for optional support. Resolving all three with at least two safe finishes automatically. Two flight losses or an unrecovered 60-second HQ loss cause defeat. No timer launches the next flight or replaces losses.

Each launch announces one response ten seconds ahead. The southeast wing brings 1/2/3 Helix Lancers in Interception; the northeast wing brings 1/1/2 Wraith strike aircraft on Story/Standard/Veteran. Both approach the public escort position, with ordinary observation and firing rules. An occupied entry within twelve metres of a live player unit denies that wing permanently. Ground troops counter the Lancers while Bastion walkers cover aircraft. The initial defense has 2/3/4 infantry and one tank per battery, plus one finite Wraith patrol unless the previous network badge was earned. This implements the original reduced-patrol reward from Split Signal; required units and base funds remain available without it.

Campaign directly exposes operations 01–04. Its compact mission HUD provides battery/exit locators, flight status and response countdowns, Launch/Continue/Finish, separate ground/air/transport selection and hangar/escort views. Rescue craft do not expose programming or coordination controls. Campaign completion schema 4 reads schemas 1–4 and retains earlier badges; saving all flights records +20 electronics support for Broken Foundry (implemented in section 49). Gameplay snapshots stay at version 5, with explicit site/flight references, statuses, response timers and HQ recovery. Active flights load paused without launching a replacement or replaying a response.

[Air Corridor verification](playtests/2026-10-03/AIR_CORRIDOR.md) distinguishes real combined-arms/preset playthroughs, an unescorted exposure scenario, controlled loss/archive cases and native UI fixtures. This stage does not establish novice pacing, all-difficulty balance, final assets, controllable Helix campaign mode-choice lessons or release performance. Operations 05–06 and the wider game design remain open.


## 49. Broken Foundry: urban production and capture (implemented 2026-10-03)

Operation 05 occupies a 160×116 industrial district. Four solid warehouse blocks divide north, central and south streets; furnace blocks frame an accessible foundry control yard. Buildings obstruct ground movement and sight/fire. The district uses the editable industrial warehouse/furnace kit, weathered concrete and asphalt, flush loading/control aprons and a continuous exterior rail/utility setting. New tall scenery remains outside playable space; the established blockout supplies the movement and sight envelopes. The player starts with an established Bastion HQ, infantry/vehicle producers, lab, depot, three generators, two engineers, a scout, six chipped tanks, two railgun tanks, two repair robots and twelve infantry. Starting funds are 160 materials and 80 electronics, with a fixed +20 electronics when all Air Corridor flights were saved. Loaded games retain their recorded funds.

Two Helix vehicle factories are actual production nodes. Crossing the district's west threshold starts an alarm and a ten-second warning. Each live node queues three finite batches, beginning ten seconds after entry, with subsequent batches due 45 seconds after the preceding admission. A ready batch waits until ordinary queue capacity, population space, funds and chip prerequisites permit full paid admission; only then does it count against the three-batch budget. Each batch buys 1/2/3 chipped Needle skimmers on Story/Standard/Veteran through the ordinary paid production queue. Their normal production and chip-install time applies. Helix has a fixed 600-material/300-electronics budget and no income or replacements beyond those jobs. Destroying a node cancels its unfinished units and future batches. Surviving produced units remain in the battle and use local Guard assignments.

Each node has 3/4/5 infantry, one skimmer and one Mender. The foundry has 4/6/8 infantry, two stationary Prism artillery units and a repair depot. Their assignments use the same observation, weapon preparation, repair limits and bounded pursuit as player programs. The Prism sectors and positions cover valid infantry positions in the control yard; warehouses and the control mast remain real sight blockers. Both nodes must be disabled before infantry can capture the control mast. Capture takes ten seconds, after which friendly infantry must remain within three metres for 30 cumulative uncontested seconds. Leaving, enemy contest or loss of ownership pauses secured time without clearing it. Recapture is possible; an owned but unoccupied control point does not finish the mission.

Disabling both nodes also warns one east response ten seconds ahead: 3/5/7 mixed ground units by difficulty. A friendly unit within twelve metres of the public entry denies the response permanently. This response is finite and independent of the canceled factory jobs. HQ loss retains the 60-second rebuild deadline. Destroying every enemy is not required for victory.

The mission HUD reports node batches, actual paid queues, timers, capture ownership/contest and secured time. Public objective locators and separate infantry/repair selection support ordinary orders and presets. Campaign's shortened five-operation selectors fit one row at 720p. Campaign-progress schema 5 retains schemas 1–4 and records the foundry completion flag for an alternate finale approach; operation 06 is still unfinished. Gameplay-v5 archives preserve both node references and timers, ordinary jobs and chip fittings, alarm, response, control capture and HQ recovery. Start, disabled-node and friendly control-capture checkpoints use the shared archive system.

[Broken Foundry verification](playtests/2026-10-03/BROKEN_FOUNDRY.md) separates actual paid reinforcement/combat runs from controlled archive/adverse/UI fixtures. The mission establishes a playable urban capture loop; novice pacing, full Story/Veteran balance, final art/audio and the finale remain open. Performance work stays deferred.


## 50. Command Horizon: deployment and command assault (implemented 2026-10-03)

Operation 06 occupies a 184×132 fortified approach. A high berm separates the central deployment yard from the eastern Helix command compound. The southern ground passage is always available; Broken Foundry completion cuts a real northern passage on fresh starts. Aircraft cross the berm directly. This is a gameplay blockout, with procedural roads and repeated cliff geometry. The user has explicitly identified the environment as too simplistic; a later environment stage must add distinctive landmarks, varied terrain/materials, industrial detail, lighting and environmental storytelling without compromising routes, sight rules or unit readability.

The normal Bastion force has four engineers, twelve infantry, eight chipped tanks, four combat walkers, two railgun tanks, two repair robots, two strike aircraft and a scout. An established HQ, three generators, barracks, vehicle factory, lab, depot and aircraft factory support ordinary paid replacements and building. Funds start at 180 materials and 100 electronics; basic programs and Coordination are available. Programs, saved versions, assignments and direct orders remain player choices.

Infantry capture deployment in ten seconds within three metres, then remain for 30 cumulative uncontested seconds to secure it. Enemy ground combatants contest. Absence, contest or lost ownership retains secured time. Victory requires secured deployment, destroyed enemy HQ and current uncontested deployment ownership with friendly infantry present. Early HQ destruction is retained, but does not bypass the deployment objective. Friendly HQ loss retains the 60-second recovery deadline. Clearing every defender is optional.

The forward yard has 4/6/8 infantry on Story/Standard/Veteran, two skimmers and a Mender. The south route has infantry, armor and ground turrets. The HQ has 6/8/10 infantry plus two each of Lancer, Prism, Wraith and Mender, with a nearby depot and northern AA cover. Bounded programs use ordinary observation, damage, preparation and repair rules. Enemy factories do not produce in this mission. First friendly deployment capture starts four finite responses at 20/50/80/110 seconds, each warned ten seconds ahead. The southeast wing brings 2/3/4 ground units; the northeast wing brings 1/1/2 aircraft. Friendly presence within twelve metres denies that entry permanently. No recurring economy or unlimited reserve army is added.

Finale victory unlocks Lean deployment and Reinforced garrison. Lean retains every required unit role and capability but starts with two engineers, eight infantry, four tanks and 80 materials / 40 electronics. Reinforced adds four HQ infantry and one ground unit per response. Difficulty remains separately selectable. Schema-6 campaign progress preserves schemas 1–5 and records finale and challenge victories independently; “campaign complete” requires all six operations. Required counters never depend on optional rewards.

The six-operation briefing, deployment/command/pass locators and separate infantry/armor/air/repair selection fit at 720p. The objective panel distinguishes enemy capture and keeps clear of the minimap during a two-line notice. Gameplay-v5 archives retain the phase, route geometry, challenge, exact capture/secured time, HQ destruction/recovery and response state. A shared turret action-restoration defect found by this mission is fixed and covered by actual post-load firing checks.

[Command Horizon verification](playtests/2026-10-03/COMMAND_HORIZON.md) records real paid Standard victories through both passes, a normal-clock rendered victory, adverse and paused archives, difficulty/modifier budgets, campaign migration and native controls. The practiced Standard route takes roughly three minutes; it does not establish novice pacing or broad balance. All six mission loops are present. Final environments/art/audio, the third faction, remaining map contracts, live-provider/novice acceptance and release/platform requirements stay open; performance optimization remains deferred.


## 51. Command Horizon environment kit and flight clearance — 2026-10-03

The finale now uses an editable six-asset Blender environment kit: ruined service works, a pump station, a substation and three asymmetric rock cuts, with service hardware and rubble inside their established footprints. Continuous road junctions, gravel shoulders, concrete aprons, varied soil and revised lighting improve the fortified industrial setting without changing the ground route layout. Asset geometry is checked against its navigation/sight footprint.

Horizon aircraft now climb over authored landmarks using actual unit height; observation, firing, hit areas, selection and ground markers follow that height. The clear air navigation region retains planar travel speed. Native review also fixed drag rectangles that relied on a stale cursor sample and clarified the deployment label. Both passages, home/forward economy, construction, archives, native selection and Standard/challenge mission playthroughs are verified in the [environment report](playtests/2026-10-03/HORIZON_ENVIRONMENT.md). This first kit pass does not establish final environment quality; wider composition, boundaries, vegetation, audio and other-map integration remain open. Performance work stays deferred.


## 52. Moving neutral life — 2026-10-03

User feedback requests animals, civilians and resident vehicles so the map feels alive. The first implementation puts two civilian cars, six residents and two foxes in Command Horizon; two cars, four residents and two foxes in Broken Foundry; and four foxes each in Alpine Relay and Desert Frontier. Authored rounded routes, short pauses and articulated gait provide visible movement. Ground troops and structures take priority; traffic waits for a clear route and keeps car following distance.

These are noncombat environmental actors with no selection, ownership, HP, population, resource, capture or vision role. Current allied observation and LOS control visibility, including hiding actors again in explored fog. Tactical pause freezes movement and animation. Snapshot version 6 preserves exact route progress, pauses and poses; older archives begin with default neutral activity. The four-map regression, archive compatibility, shared gameplay checks and native review are recorded in [the living-map report](playtests/2026-10-03/AMBIENT_LIFE.md). This is a first pass; more regional varieties, destinations, panic/flee behavior and environmental sound remain future environment work.


## 53. Industrial Crossroads and Foundry building kit — 2026-10-03

Industrial Crossroads is a selectable 128×104 skirmish district with three east–west streets, connecting spines, open junctions, four full-size opaque buildings and two smaller outbuildings. Workshops, cooling infrastructure, offices and a damaged warehouse provide distinct silhouettes and sight breaks. Two optional infantry-captured relays provide local vision; HQ destruction remains the victory condition. Paired home fields contain 600 materials / 240 electronics each, and paired outer fields contain 900 / 400 each. After the resource-navigation correction in section 54, basic-tank navigation estimates are 45.1 seconds between bases and 20.5 seconds to the first expansion. Two cars, eight residents and four foxes bring the shared moving-neutral behavior to a fifth map.

Five editable Blender assets include modeled roofs, seams, vents, glazing, pipework, fans, trusses and service clutter. Broken Foundry uses the same kit, with two furnace blocks, inside its unchanged ground/sight footprints. A continuous ground shader supplies connected roads, markings, curbs and service aprons. Aircraft climb over the authored roofs at their actual unit height, which also survives paused archives.

Both factions pass all three tank approaches and retreats, home/outer cargo return, paid construction, capture/contest, mid-movement archives and six-minute AI production/attacks. Testing caught a zero-clearance gap between deposits; wider spacing and an offset electronics deposit restore actual cargo return on this map. All roofs pass real drone/strike-aircraft crossings; Foundry's full mission suite still reaches victory. Native map selection and Start Battle pass. See [the Industrial report](playtests/2026-10-03/INDUSTRIAL_CROSSROADS.md) for evidence and test limits. Section 54 completes the broader resource-access audit. Section 55 adds Coastal Foundry. Broader terrain/backdrops/vegetation/audio and repeated full-match balance remain open. Performance work stays deferred.


## 54. Resource clearance and battle navigation lifetime — 2026-10-03

The older-map audit reproduced engineers trapped between deposits because resource pathfinding used a smaller footprint than movement avoidance. Both now use the actual 0.6 m resource radius. Tight clusters route traffic around their exterior; sufficiently wide gaps remain passable. Resource gathering, HQ delivery and construction account for the shared navmesh's largest-agent clearance and cell rounding. Contact stays bounded, resource timing/cargo limits remain unchanged, and resources still do not block sight/fire.

Ground navigation now belongs to each match, mirroring the existing air-map lifetime. A scene transition can no longer initialize new units/resources against the previous map's still-synchronized geometry. Authored positions remain intact across small/large map switches. A paused archive retains an engineer's exact formerly trapped position and cargo, then resumes a successful return using the corrected navigation.

Both factions pass narrow/open gaps, tank/worker clearance, harvesting from four sides, bounded interactions, dynamic depletion and archives. All 68 paired material/electronics field-return checks pass across six skirmish maps with both factions and five campaign maps. Shared crowded movement, paid construction, field state, save-slot recovery, live combat restoration, Industrial routes and native 720p cargo return pass. See [the navigation report](playtests/2026-10-03/RESOURCE_NAVIGATION.md). These tests establish resource access and continuity; repeated contested expansion/full-match balance, broader environment content and release acceptance remain open. Performance work stays deferred.


## 55. Coastal Foundry — 2026-10-03

Coastal Foundry completes the first playable set of the four map contracts: a 128×104 harbor with opposite shore bases, a quay route, an inland route behind two opaque foundries and an aircraft shortcut over actual water. The land polygon drives ground navigation and construction legality; shore cranes, beacons and pine clusters have matching solid/sight footprints. The moored freighter supplies sight and air clearance without affecting neighboring land navigation. Maximum aircraft height over the cranes is 9.3 m, retained by paused archives.

Six original editable coastal assets add modeled cranes, beacons, a freighter, tugboat, gulls and coastal pine clusters. Concrete quays, continuous roads, bollards, turf, shoreline foam and subdued water animation establish a different regional setting. Two cars, six residents, four gulls and one tug use the shared neutral behavior. Pause freezes their poses and the water; restoration derives the water pose from the saved simulation clock. Ships remain scenery.

Both factions pass two 16-tank advances/retreats, all-field resource returns, paid construction, 11-landmark aircraft clearance and moving/raised-aircraft archives. Basic-tank route estimates are 51.1 seconds between bases and 22.5 seconds to the western expansion. Six-minute Normal AI runs build economies, produce units and damage the opposing HQ. Native map selection/Start Battle, ordinary starting fog and rendered 720p/900p views pass. See [the Coastal report](playtests/2026-10-03/COASTAL_FOUNDRY.md). These checks establish a playable map; richer regional composition, off-map surroundings, audio, repeated contested balance and release acceptance remain open. Performance work stays deferred.


## 56. Remappable battlefield controls — 2026-10-03

Settings now has General and Controls tabs. Controls edits all 31 existing keyboard actions: pause, attack move, battle menu/cancel assignment, building rotation, quicksave/load, the held selection/queue key, camera pan/rotation, and nine group assignment/recall pairs. Capture supports physical keys and modifier chords, rejects collisions and reserved navigation/system/debug shortcuts, and provides per-action reset. Tab/Enter remain available for UI navigation; Escape cancels capture, including while another modifier is held. Save persists the versioned profile; Cancel restores nested bindings and live hints. Legacy or corrupt profiles receive a complete default profile.

Queue modifiers compose with attack/group shortcuts and camera movement without swallowing an explicitly assigned chord. Camera polling observes modifier presses/releases that occur after the movement key was held. Battlefield shortcuts take priority over focused HUD buttons while text fields, settings, archives and program editors retain their input. Main/battle settings freeze simulation throughout editing. Visible pause, attack, menu, assignment, archive and queue hints follow the current profile.

Both factions pass actual key-event remapping, default Shift+F queues, remapped queue/chord combinations, explicit chord priority, paused groups, building rotation, camera modifier transitions, text isolation and isolated quicksave/load. Rendered Controls and General settings flows fit 720p and pass capture, conflict, Save/Cancel, focus scrolling and battle pause checks. See [controls verification](playtests/2026-10-03/KEY_CONTROLS.md). The native window was visible, but computer-use input failed after bounded recovery, so direct native keyboard/mouse acceptance remains pending. Scalable HUD, subtitles, broader audio/content and full-match/release acceptance remain open; performance work stays deferred.


## 57. Speech subtitles and announcement priority — 2026-10-03

All 14 existing spoken lines have canonical subtitles and a speaker label. Settings → General provides subtitle visibility, Small/Standard/Large text (18/22/26 px) and a combined voice/subtitle sample. Subtitles default on, remain available with either audio bus muted, update immediately during preview and restore on Cancel. The caption area sits between the minimap and the selected-unit/production panel, ignores mouse input and adapts after wrapping and viewport-size changes.

Human announcements and unit acknowledgements share one Voice-bus channel. Urgent base danger, casualties and incoming fire can interrupt routine speech; routine production cannot erase a warning. Repeated events coalesce, with ten-second per-type attack cooldowns and six-second casualty cooldowns. Only accepted playback updates the cooldown, so sustained hits no longer postpone warnings indefinitely. Up to four pending announcements expire after six seconds; stale unit responses are dropped. Caption/read time and audio advance during tactical pause but freeze together when settings or the archive suspends the scene.

Incoming-fire announcements now originate from actual accepted weapon hits. Construction's initial HP assignment and archive reconstruction do not create false warnings. Ownership filtering prevents enemy activity from entering the human channel. Loading starts with no transient speech or subtitle backlog. Skirmish and campaign result panels now trigger the existing victory/defeat line and reject later routine speech; draws clear speech without inventing a spoken result.

Both-faction regressions cover real first/continuous/base damage, six simultaneous losses, paid production, selection/paused orders, all transcript mappings, repeat/priority/stale queues, mute, preference persistence/failure/rollback and actual damaged-battle disk restoration. Rendered normal-clock checks cover keyboard size selection, mouse visibility/sample/Save/Cancel, audio and caption freeze in the archive, right-clicks through captions, large text beside production/group/campaign/result UI, and 720p/900p layouts. Shared controls, settings, combat, save-slot, legacy Bastion and four-pairing skirmish checks pass. See [the speech report](playtests/2026-10-03/SPEECH_ACCESSIBILITY.md). Full HUD scaling, localized/new voice production, environmental/combat sound, navigable alert history, native platform acceptance and broader release work remain open. Performance stays deferred.


## 58. Combat audio cues — 2026-10-03

Actual weapon shots, accepted hits and destruction now produce eleven original procedural cues. Bastion rifle/cannon/autocannon reports contrast with Helix energy discharges and Lancer/rail cracks; missiles use ignition/exhaust. Infantry loss uses an equipment fall, vehicles use chassis destruction and buildings use a longer collapse. The deterministic generator, asset measurements and an isolated audition reel are retained with the project.

Only currently observed sources near the camera produce combat audio. Remembered visuals do not grant audibility, newly unobserved live sources stop, and offscreen cues are culled. Screen-relative stereo and distance attenuation provide direction. Nearby identical bursts merge, a shared 24-player limit bounds overlap, and destruction can replace lower-priority sounds. Audible speech lowers the combat mix by 4 dB; muted speech does not. Effects and Master have output limiters.

Settings adds persisted Effects volume and Test combat sound, with live preview, Save/Cancel, invalid-value fallback and legacy defaults. Combat audio freezes during tactical pause, settings and archives; legitimate destruction tails can finish over a battle result. Loading suppresses reconstruction events and does not replay active sounds from the archive.

Both factions pass actual projectile/hit/death checks, observation/offscreen gates, overload, mute/pause, settings rollback and damaged-battle disk restoration. Normal-clock Metal captures establish nonzero output, correct left/right stereo, actual playback freeze/resume, live fog loss and a bounded 24-destruction-plus-speech mix. The settings sample button and speech layout pass rendered input at 720p/900p. See [the combat audio report](playtests/2026-10-03/COMBAT_AUDIO.md). Subjective speaker/headphone mixing, environmental sound, general HUD scaling, native-platform and broader release acceptance remain open. Performance optimization stays deferred.


## 59. Navigable battle alerts — 2026-10-03

The top-right Alerts control opens a bounded history of incoming fire, losses, idle engineers, depleted materials/electronics fields, stranded cargo, low power and paid production blocked by a missing prerequisite. Combat events group by program squad or nearby location; worker conditions group around their assignment area. Squad titles and positions are recorded before tree exit, so an entirely destroyed squad remains navigable. Enemy casualties and reconstruction events do not enter the human history.

Each entry shows its simulation timestamp, count, active/resolved state and an inspection action. Show selects surviving affected friendly units and centers the camera; Go to field visits the field anchor. Inspection preserves manual/program orders and tactical pause while cancelling an unfinished placement/targeting gesture. Escape/the remapped Menu key closes the panel before opening the battle menu. Clear history retains active problems. New events do not move existing rows under the pointer while the panel is open, and ordinary keyboard focus survives updates.

Idle engineers wait six simulation seconds before an alert; depleted/stranded harvesters wait one, power/blocked queues two. Incoming-fire alerts resolve after eight seconds without hits; losses within six seconds coalesce. Conditions refresh while paused so reassignments and refunds resolve/update the UI, but debounce, expiry and battle timers stay frozen. The 24-entry history removes resolved/history entries before active problems and protects higher-priority active alerts when full. Archives omit transient history and rebuild current conditions after Resume.

Both factions pass real damage, six-unit squad losses, real extraction/depletion/reassignment, stranded cargo delivery after HQ rebuild, paid queue interruption/recovery, paused queue cancellation, power recovery and disk restoration. Rendered mouse/keyboard, stable rows/focus, field navigation, Clear, menus/archive isolation, campaign/result UI and 720p/900p layouts pass. A thirty-second normal-clock pause preserves simulation, production and alert expiry, then all resume correctly. Visual review also found and fixed stale power-bar values when pausing immediately after structure changes; the read-only resource bar now refreshes while paused.

See [alert verification](playtests/2026-10-03/BATTLE_ALERTS.md). Direct macOS input remains unverified after native state/input failures; the failed native harness also reported a pause mismatch that did not reproduce in independent normal-clock checks. General HUD scaling, environmental audio, full-match/novice balance and release acceptance remain open. Performance optimization stays deferred.


## 60. Interface scaling — 2026-10-03

Settings → General → Display now offers 100%, 125% and 150% interface sizes. Text, menus, battle controls, archives and program editors preview together. Save persists the choice; Cancel/Esc restores the previous scale; Reset defaults previews 100%. Subtitle size remains independent. Invalid and legacy settings receive a safe 100% default.

The largest setting retains a 1280×720 logical layout at 16:9. Canvas Items rendering keeps native output resolution; expanding the canvas uses the available space on 16:10 displays. The separate battle arena uses the same scale and explicitly maintains its windowed mode. Its missing-voice subtitle startup error is fixed. First Orders relay labels now render behind the HUD and hide when they would clip at the screen edge.

Both factions pass rendered scale/input checks for selection, five paid production jobs, minimap navigation, attack-move destinations, alerts, subtitles, both program editors, archives and paused settings rollback. Main/setup/campaign screens and 720p/900p/1080p captures are checked, alongside shared settings, controls, archives, speech and arena regressions. See [interface scaling verification](playtests/2026-10-03/INTERFACE_SCALE.md). Direct physical-device and cross-platform acceptance, localization/screen readers, environmental audio, novice balance and broader release work remain open. Performance optimization stays deferred.


## 61. Desert Frontier environment — 2026-10-03

Desert Frontier now reads as an abandoned extraction district: asymmetric sandstone shelves, weighhouse remnants, exposed utility hardware, layered canyon mesas, an extraction tower, freight bays and low sage scrub. Ten original, editable Blender assets replace the interior blockout forms and establish surrounding landmarks. Sand/iron patches, wind ripples, connected haul roads, field branches and a worn freight apron share a continuous ground material. Warm sunlight and cooler ambient fill preserve army silhouettes.

The 128×96 layout, field amounts/positions, three approaches, central build area and archive identity remain intact. All interior solid art fits the existing 5.8 m radius / 1.15 m shelf limits; tall scenery lies outside playable space. Exterior dunes meet the playable plane at matching height and lighting normals. Public scenery fades into the map edge under fog; unexplored interior ground and enemy units retain their visibility rules. Other maps keep their previous fog setting.

Repeated 48-tank advance/archive/retreat checks exposed tanks backtracking toward crowded intermediate waypoints near the outer field. Basic tanks now accept intermediate path points within 0.5 m and recalculate when avoidance displaces them 2 m from the path. Their final destination tolerance remains 0.2 m. The regression retains its original movement deadlines and includes four independent runs, alternating factions.

See [desert environment verification](playtests/2026-10-03/DESERT_ENVIRONMENT.md) for asset bounds, actual flight/sight/fire/economy/archive checks, ordinary-fog combat captures, shared movement checks and remaining acceptance work. This is progress toward the requested environment quality; broader regional polish, environmental sound and repeated complete-match/novice balance remain open. Performance optimization remains deferred.


## 62. Alpine Relay environment — 2026-10-03

Alpine Relay now has fractured granite shelves, snowy mountain crests, conifer groups and abandoned weather/cable stations. Ten original editable Blender models establish the alpine communications setting. Snow, ice, gravel, connected plowed routes and weathered relay aprons replace the previous repeated bands and separate paving blocks. Cool ambient light and restrained warm sunlight retain army contrast.

The six low blockers remain within 6.5 m radius / 1.15 m height; tall mountains, conifers and stations sit entirely outside the 128×104 playable rectangle. Surrounding terrain joins the playable plane at matching height and normals. Map-owned lighting/fog materials expose only public exterior scenery; hidden interior bases remain black. The two passes, rear bypass, field budgets, capture locations and archive identity are retained.

Relay labels use larger text and a strong dark outline for snow contrast. Real infantry capture/recapture and an enemy tank contest are rendered under ordinary fog, with capture progress frozen during tactical pause. Both factions pass six-shelf aircraft crossings, three 16-tank advance/retreat routes, moving and partial-capture disk restoration, both starting/outer economies, placement and shared combat checks. See [alpine environment verification](playtests/2026-10-03/ALPINE_ENVIRONMENT.md) for images, measured geometry and test commands.

Broader regional composition, environmental audio, subjective final art and repeated complete-match/novice balance remain open. Performance optimization remains deferred.


## 63. Complete skirmishes, repair support and occupied destinations — 2026-10-03

A paid reference commander now records complete Normal-AI skirmishes across both factions, Desert Frontier/Alpine Relay and Standard/Advanced starts. The observations include contact, unlock/program timing, actual outer cargo return, per-minute worker allocation and separate M/E army value, casualties, damage, repair and stationary travel. The fixture uses ordinary resources, production, observation and Command defeat. Its fixed policy is a reproducible strategy sample; it does not establish human balance or novice usability.

Match review exposed three shared problems. AI repair robots followed the first soldier even when it was unrepairable infantry; they now prioritize legal wounded machines/completed buildings and assign distinct targets. Large buildings could block robots outside center-based repair reach; the three-metre mobile channel now measures from a completed structure's footprint, consistently across direct orders, built-in programs, Lua and repair allocation. Attack-move could repeatedly retry a point inside a friendly building after navigation had finished; it now completes at the accessible edge and hands off queued orders, including after archive restoration.

Selection details show mobile repair reach and the previously hidden barracks/airfield service slots and radius. Both factions pass actual repair, pause, target replacement, program control, occupied/dynamically occupied movement destinations, queued handoff and disk restoration. Shared combat/order/Lua tests pass. A separate normal-clock Bastion/Desert/Standard match reaches Victory at 9:47.5, with reviewed 720p opening/contact/program/expansion/assault/result captures. See [the repeated-match report](playtests/2026-10-03/SKIRMISH_MATRIX.md) for the final matrix, strategy limitations and source fingerprint.

The retained matrix reaches 24/24 outcomes: 11 Standard wins/1 loss and 12 Advanced losses. An early Standard loss precedes the first programmable unit; Advanced openings commit too early under the fixed policy. All matches finish below 20–30 minutes. Separate tracing retains a real crowded-base archive where an engineer has a valid path but avoidance pushes against the navigation boundary; removing neighboring mobile units restores travel. That reproducible movement failure is the next correction. Five novice players, broader strategic/pacing policies, third faction, environmental audio and release acceptance remain open. Performance optimization stays deferred.


## 64. Ground movement at crowded navigation boundaries — 2026-10-03

A saved full-match engineer could remain pinned near its HQ despite having a valid path to electronics. Avoidance predicted an outward velocity while navigation projection kept the unit on the boundary, so nearby units continued reacting to motion that had not occurred. Ground movement now reports its actual applied velocity when projection or speed limiting changes the avoidance result by more than 0.1 m/s. Facing and passive-motion signals follow actual displacement. Unit spacing, speeds, physical footprints, direct/program orders and save format remain unchanged.

The original archive fails before the correction and passes three restores afterward: the engineer travels over eight metres within ten seconds, gathers within fifteen, respects its speed bound and stays frozen while paused. Both factions deliver materials/electronics through opposing base traffic and a real midpoint archive/load. Shared twelve-tank arrival, six-worker harvesting, resource-gap/access, four 48-tank advance/retreat runs, combat/order/Lua, live-combat restoration and sixteen mobile-role animation checks pass. Normal-clock 720p rendering verifies the archived battle and both-faction traffic with visible engineers, cargo and selection details. See [the crowd-boundary report](playtests/2026-10-03/CROWD_BOUNDARIES.md).

All twelve follow-up matches complete, but one of the initial six includes a different engineer with an empty path for 548 seconds. Six subsequent Desert diagnostics do not reproduce that state. Its trace remains available, and richer path/footprint diagnostics are ready to capture the next occurrence. This pass fixes the retained intact-path failure; it does not establish universal navigation reliability, balance or the intended match pacing. Broader content, novice and release gates remain open; performance optimization stays deferred.


## 65. AI base access and construction-closed navigation — 2026-10-03

A captured full-match engineer stalled at the edge of a tiny navigation island while its movement callbacks continued normally. The AI had placed an AA turret in a collision-free position that closed the last navigable passage between existing buildings. Isolated archive replay retains the failure; removing the turret opens the route, and rebuilding at the old selector's chosen site closes it again.

AI placement now reserves a 2.4 m passage between static building/resource footprints, derived from two-sided navigation erosion and cell allowances. The innermost candidate ring grows from 6 to 7 m; collision and full-footprint navigation checks remain. In the retained regression the AI chooses a different site, the engineer delivers electronics at its normal movement speed, and position/cargo/orders survive a paused midpoint disk reload. Existing saved buildings are not relocated; the corrective regression explicitly rebuilds the closing turret through the new selector.

Both factions pass actual AI economy/production/attacks on Desert, Industrial and Coastal maps, plus shared support, skirmish lifecycle and the earlier crowd/archive scenarios. Normal-clock 720p spatial comparisons show the original and corrected layouts. Eight Normal-AI complete matches, across both factions/maps/start modes, all finish with maximum stationary-travel episodes of six seconds human/four seconds AI. See [AI base-access verification](playtests/2026-10-03/BASE_ACCESS.md) for the archive, before/after failure, detailed results and source fingerprints.

The fixed commander still wins all four Standard starts and loses all four Advanced starts in about 6–9 minutes. Strategy/pacing, novice acceptance, remaining content and release gates stay open; this pass does not establish universal navigation reliability. Performance optimization remains deferred.


## 66. Tactical battle-plan advice and selection reliability — 2026-10-03

Battle-plan guidance no longer skips the first programming step when the army reaches nine combatants. After the economy/technology route, advice reacts to damaged combat/support/scout units, a depleted force, unseen opposition and currently observed contacts. Visible threats near owned economic assets and recent enemy fire on those assets produce defense advice. Economic recovery retains priority; advice only selects owned units and does not issue tactical orders or spend resources.

UI verification exposed two selection faults. Mixed production selections intentionally have no production grid, but the refresh logic rebuilt that empty grid recursively; it now limits that rebuild to single structures. The double-click handler previously inferred intent from every selection signal, so rapid UI army selection could discard distant units. It now consumes the explicit double-click mouse event on world units. The production advice shortcut selects one completed producer with usable job controls.

Both factions pass nine-unit programming, scouting/fog, recovery, defense, visible opposition, rebuilding, pause and disk restoration. Normal-clock 720p/150% mouse and keyboard checks retain all requested selected units, verify paid factory production/refund, and keep the panel clear of the minimap and selection controls. Shared economy, support, controls, orders, restoration and the existing opening UI flow pass. See [battle-plan verification](playtests/2026-10-03/BATTLE_PLAN.md).

Twelve new Advanced policy trials preserve both success and failure. An economy-screen/repair policy wins three of four in its first revised pass but only one of four in the final repetition. Matches remain below the ordinary 20–30-minute pacing hypothesis, with the longest final match at 12:51.6. These observations justify contextual advice and further composition/expansion/AI work; they do not establish balance. No economy or combat values were changed for the trials. Performance optimization remains deferred.


## 67. Guard coverage across the assigned area — 2026-10-03

The built-in Guard area preset previously searched only weapon range plus two metres, so a larger assigned circle could contain visible raiders that the defender ignored. Acquisition now covers the full assignment from the defender's current position. Allied observation, legal target domain, clear line of fire, target priority and sector limits still apply; firing range is unchanged. Leaving targets cause the defender to return to the anchor. Other specialist presets and saved Lua source retain their behavior, and the Guard tooltip describes the area/observation contract.

A before/after reproduction shows both factions stationary and dealing zero damage to an observed enemy 11 m away inside a 12 m area before correction, then moving and firing afterward. Tests cover the opposite edge, hidden/blocked/air targets, leaving targets, manual hold, retreat/recovery and paused disk restoration during approach. Shared program, specialist, squad and order suites pass. Both-faction normal-clock 720p/150% rendered review shows the assigned circle and Ready/Running states. See [Guard-area verification](playtests/2026-10-03/GUARD_AREA.md).

Four Advanced-start policy follow-ups all reach victory with five or six surviving engineers, compared with one win and three losses in the previous final pass. These exploratory samples use the same commander and seed but asynchronous navigation/crowd timing varies; they do not establish balance or novice success. Matches still last only about 6–8 minutes. Protected expansion, army composition, strategic enemy responses, content/novice/release acceptance remain open, and performance stays deferred.


## 68. Observed-threat AI defense — 2026-10-04

Skirmish opponents now respond to currently observed armed threats near engineers and buildings between attack waves. They prioritize proximity/recent damage, cluster nearby ground/air threats and choose suitable responders. Story/Standard/Veteran plan one/two/three supported defense clusters per decision, with two responders per visible contact up to six per cluster. Threats without an eligible counter do not consume a response slot. Helix Lancers prepare their normal Interception mode for air raids; tanks are not sent after aircraft.

Defenders retain matching orders and active attack-move shots, and are excluded from new offensive waves and relay tasks. Other troops can continue those operations. Local threats are excluded from offensive target selection to avoid redirecting the remaining army into the same defense. Lost sight leaves the last observed destination without tracking unseen movement. Defense spends no resources, does not consume the attack-wave timer and uses existing pause/save/action contracts. This is derived planning, not persistent strategic squads or a whole-army group-budget implementation.

Both-faction failure reproductions and final checks cover actual ground/air interception, hidden/unarmed/lost contacts, mode switching, supported-group limits, simultaneous waves/relays and paused disk restoration. Shared three-map AI economy/combat, support, weapon-mode and save/load suites pass. Normal-clock 720p/150% rendering shows actual raider damage and the AA stance. See [observed-threat AI defense verification](playtests/2026-10-04/AI_DEFENSE.md).

Sixteen complete Normal-AI trials preserve the initial seven-win/one-loss cohort and final eight-win cohort. Final matches last 5:45.5–11:03.2, below the 20–30-minute pacing hypothesis. Shared seeds do not make navigation/combat deterministic, and these ground-force reference policies do not prove mixed-air strategy or novice balance. Strategic expansion, composition/counter-production, broader coordination, content/novice/release gates remain open. Performance work stays deferred.


## 69. Observed-composition counter-production — 2026-10-04

Skirmish AI now counts owned units and paid production jobs when deciding its next unit. Current armed air, armor and infantry observations request bounded faction-appropriate counters; Helix can expand its infantry screen, and machinery forces retain repair support. Baseline roster slots respect existing composition, and only successful vehicle production advances the vehicle sequence. Scouted air threats can bring forward the first AA turret after essential economy/production needs. Prerequisites, power, exact costs, chip-fitting costs and construction reserves remain binding.

Both-faction checks cover hidden/unarmed contacts, multiple factories, paid queues/refunds, unfinished technology, exact reserve boundaries, actual engineer construction, and counter completion/interception after a paused disk archive. Normal-clock 720p/150% rendering shows the paid counter through ordinary fog observation. Defense, repair, weapon modes, save/load, air evacuation and Industrial/Coastal AI checks pass. See [composition-production verification](playtests/2026-10-04/AI_COMPOSITION.md).

The new mixed-force reference commander uses a ground defense screen, ordinary reconnaissance and paid strike-return aircraft. An apparent aircraft-arrival fault was traced to repeated test orders and altitude-sensitive telemetry; the production movement code is unchanged, and direct/restored/queued air arrival passes on three maps. The final monitor uses horizontal air distance and rejects missing match records. Initial and diagnostic outcomes remain in the report, with invalid early air-stationary metrics explicitly identified.

Fourteen complete exploratory matches are retained. The final eight all finish: Standard ground policies win three of four, while the mixed-force policy loses all four, at 9:01.9–16:45.3 overall. Each final mixed run brings forward AA construction while armed aircraft are observed. Captured ground-wave/scout diversion produces 37/42.5-second stationary episodes, and a separate engineer approach delay reaches 15.5 seconds. Those archives define the next objective-selection/pathing checks. Balance, protected expansion, broader coordination, content/novice/release gates remain open; performance stays deferred.


## 70. Strategic offensive objectives — 2026-10-04

Two mixed-force archives showed entire ground waves targeting a visible scout above their own HQ. Offensive selection now prioritizes currently observed enemy HQ, production and infrastructure, then exposed engineers, with proximity breaking equal-priority ties. It excludes friendly/dead targets and accounts for ground engagement capability, including a Helix Lancer's ability to change mode. Without a visible economic objective, waves continue toward the public enemy starting position. Attack-move handles nearby combat while the separate defense planner handles raids; scouts and mobile fighters no longer choose the strategic destination.

Existing intervals, minimum wave size, defense/relay allocation, costs, speeds and save formats remain. Both-faction archive failures become correct base-directed orders and actual departures, preserved through a midpoint paused disk reload. The delayed engineer completes materials collection/delivery with normal AI scheduling. Shared defense, composition, support, weapon, restoration and three-map AI checks pass; normal-clock 720p/150% captures show both departing factions. See [offensive-objective verification](playtests/2026-10-04/AI_OFFENSE.md).

A fifteen-second displacement test initially misclassified some slow base exits. Continuous observation records a delayed tank reaching about 42 m by thirty seconds without new orders or position changes; four additional replays pass the final thirty-second bound. Empty path samples during repathing were investigated and the traces retained. No movement workaround was added, and universal navigation reliability is not claimed.

All eight final matches finish, with four wins/four losses and no stationary-travel episode of fifteen seconds or more; the maximum AI episode is two seconds. The mixed-force policy wins Helix/Alpine and loses three other cases. Seed reuse does not remove asynchronous navigation/combat variation, so this does not establish balance. Matches last 5:17.2–17:30.9, below the ordinary pacing hypothesis. Protected expansion, mixed-force resource allocation, broader coordination and novice/content/release gates remain open. Performance remains deferred.


## 71. Supply and expansion guidance under pressure — 2026-10-04

The skirmish battle plan now handles visible economic threats before telling displaced or stranded engineers to change assignments. HQ and engineer-loss recovery retain priority. Hidden opposition does not change advice, and the outstanding expansion task reappears when the observed threat or recent damage expires.

After vehicle production opens, the guide checks whether materials or electronics have no assigned gatherers and reserves are below the faction's tank cost, including fitted chips. A completed air producer also accounts for its strike-aircraft cost. This identifies missing income streams; sustained production demand and optimal worker ratios remain strategic work. The selection shortcut prefers one idle engineer, then a gatherer with less cargo, while preserving construction, manual movement and queued commands. The player still chooses the deposit and protects new fields.

Both factions pass actual collection, paid fitted-tank completion and paused disk restoration, plus shared recovery/field/battle-plan checks. See [supply-guidance verification](playtests/2026-10-04/ECONOMY_SUPPLY.md) for rendered evidence and limits. Contested expansion, wider mixed-force allocation, full-match pacing and novice acceptance remain open.


## 72. Protected AI expansion — 2026-10-04

The commander now sends a bounded ground guard before releasing idle engineers to resource destinations beyond a thirty-metre HQ home area. One field receives up to two healthy ground combatants, retained through cargo returns and excluded from relay/attack-wave duties; immediate economic defense has priority. Resource selection avoids currently observed legal ground threats and their approach corridor. Exposed harvesters withdraw toward a safe HQ, retain their cargo and deliver it before reassignment. Ordinary harvest/move/attack actions reconstruct this behavior after loading without a new save schema.

Both factions pass Desert/Alpine guard travel, finite-stock collection/return and paused archives. Live infantry raids are defeated while engineers survive and income resumes. Threat contracts cover visibility, attack domains, cargo retention, damaged guards and separate offensive waves; nine shared suites and normal-clock 720p/150% rendered checks pass. [The report](playtests/2026-10-04/AI_EXPANSION.md) includes four reviewed captures and eight complete matches (five human wins/three losses, 4:51.3–13:55.8). No fifteen-second stationary-travel episode occurs in that cohort.

This establishes protected single-field expansion, not sustained mixed-force economics. The six-worker target and fixed material/electronics allocation remain. Adaptive worker ratios, competing production reserves, larger/air raids, global squad coordination, ordinary pacing and novice/content/release acceptance remain open. Performance remains deferred.


## 73. Adaptive AI labor and mixed-production budgets — 2026-10-04

The AI now reserves funds for worker recovery, observed counters, infantry, repairs, reconnaissance and strike aircraft before ordinary ground-roster purchases. Paid queued units and planned requests count toward quotas; paid foundations do not reserve their purchase price again. Optional Coordination research protects higher-priority production, and fitted-tank requests account for hardware costs and available prerequisites.

Gatherers derive their resource split from the next construction/production deficits, including one future cycle at a busy factory. Electronics receive twice the collection-time weight. Active workers change resources through a queued order at cargo delivery; already queued changes count toward the split, and at most one active handoff is added per decision. Construction and threatened withdrawal clear stale mining queues. Two remote material/electronics approaches share the existing two-ground-guard allocation; defense keeps priority and remaining units retain wave/relay duties. Costs, mining rates, worker target, combat values and archive format remain unchanged.

Both factions pass original budget failures, actual finite-stock collection, completed paid tank/aircraft production, both directions of resource reallocation and a paused disk archive mid-handoff. Both-resource guarded returns, live field raids, eleven shared suites and six normal-clock 720p/150% captures also pass. See [adaptive economy verification](playtests/2026-10-04/AI_ECONOMY.md).

Eight complete Normal trials yield three human-policy wins and five losses; samples show changing AI worker ratios and four cases with a sampled strike aircraft. No stationary-travel episode exceeds three seconds. Durations span 5:20.4–18:37.5, still below the ordinary 20–30-minute pacing hypothesis. Seed reuse does not remove asynchronous combat/navigation variation. Sustained contested mixed-force strategy, global coordination, pacing, novice/content/release acceptance remain open. Performance remains deferred.


## 74. AI recovery and recommitment

Mobile military units below 30% health now return to reachable, currently safe service facilities: infantry to barracks, aircraft to their air producer and ground machines to repair depots. Recovery remains protected from defense, guard, relay, attack-wave and support reassignment until 80% health. Recovered units become eligible for ordinary duties; healthy reserves retain their existing tasks. Engineers retain economic withdrawal and cargo authority.

Units use ordinary navigation and existing service rules. Unsafe or destroyed providers trigger another compatible provider or a protected hold; five seconds without progress blocks travel and delays retry of the same provider for ten seconds. The planner does not purchase missing services or coordinate a whole-army retreat. Health, healing rates, resource costs and combat rules are unchanged.

Both factions pass actual five-role travel/healing/recommitment, travel/partial-heal/blocked disk archives, threshold and provider-loss contracts, separate Alpine relay checks, fifteen shared suites and four normal-clock 720p/150% captures. The eight-match cohort records 79 recovery episodes, including 36 completed returns and 40 losses during recovery. Aircraft recovery is established by targeted tests, not that cohort. See [recovery verification](playtests/2026-10-04/AI_RECOVERY.md).

The cohort retains two long ordinary-movement episodes (21-second AI tank and 41.5-second human engineer). Four additional full-match reproductions do not repeat them, so their cause remains open. Match durations remain 5:31.3–12:16.4; broader coordination, pacing, novice/content/release acceptance and movement diagnosis remain unfinished. Performance optimization stays deferred.


## 75. Global AI task coordination — 2026-10-04

Story, Standard and Veteran now share one, two and three simultaneous combat tasks across defense, assaults, field protection, relay capture and standalone reconnaissance. Observed raids preempt ordinary tasks. Ordinary tasks keep core members and goals for a ninety-second commitment before eligible waiting work can replace them; completed captures release immediately. A rotating selector prevents indefinite field-guard ownership of Story's sole slot. Assault timing/minimum forces and the shared two-guard limit remain in effect. Surplus assault reinforcements can fill another task slot without taking away the three-member core.

Retiring guards return matching engineers with cargo and wait for their delivery before releasing capacity. Defense or guard loss can preempt that protection. Completed cargo returns become eligible for new expansion demand, allowing interrupted fields to resume. Critical military recovery retains authority; unassigned combatants regroup, scouts follow active tasks and healthy repair escorts follow assigned combatants. Individual repairs and ordinary economic work remain outside the combat-task budget. Snapshots preserve task membership, elapsed commitment, selector and returning engineers while accepting older archives without these fields.

Both factions pass all three difficulty budgets, stable repeated orders, two-raid preemption, fog/recovery authority, actual Story cargo delivery and current/legacy disk restoration. Live Veteran scenarios complete assault travel, both relay captures and support repair. Four normal-clock 720p/150% captures pass. The original over-budget behavior and stale strategic goals during active firing are retained as failing-before evidence. Changed strategic goals now update active engagements without restarting prepared fire. All 21 final suites pass. Eight complete Standard-difficulty matches record no task/order violations across 7,998 samples, with five human-policy wins and three losses in 4:41.4–13:34.3. [The coordination report](playtests/2026-10-04/AI_COORDINATION.md) retains failing-before evidence and interim outcomes.

Sustained contested mixed-force strategy, ordinary pacing, the two earlier intermittent movement delays and novice/content/release acceptance remain open. A new 16.5-second human engineer delay in the final Alpine trial has an exact archive and bounded crowded/isolated replays, with its cause still unresolved. Performance optimization remains deferred.


## 76. Regional environmental audio and campaign continuity — 2026-10-04

Desert wind/sand, alpine gusts/conifers, industrial ventilation and coastal surf now provide distinct environmental beds on all four skirmish regions and six campaign operations. Neutral carts, harbor tugs and gulls supply camera-relative local audio only while currently observed. One bed and at most four local players belong to each match; no hidden military/economy state or simulation RNG drives this cosmetic layer.

Settings adds independent Ambience volume, default 55%, with live preview, a finite Play/Stop sample, Save/Cancel, bounds and legacy defaults. Beds fade in; audible speech/combat lower ambience by 8/4 dB with gradual release. Tactical/modal pause, restoration and results suspend it. Active sound is transient across archives; ordinary neutral actor state remains preserved. Paused loads remain silent until Resume.

All regional scenes and six operations now pass the focused headless check, including real settings files, current fog/camera gates, oversubscribed neutral audio, RNG isolation and real battle disk restoration. Normal-clock rendered capture verifies nonzero output, loop wrap, stereo direction, zero-output mute/pause, real combat/speech mixing and 720p/150% settings input. Original synthesized assets and runtime audition artifacts are retained in [the audio report](playtests/2026-10-04/ENVIRONMENT_AUDIO.md).

This campaign audit also repairs Split Signal’s broken inheritance after the Alpine art changes: model-name and mission-coordinate constants are distinct, and the mission owns its relay aprons. Its rules, traversal, archives and preset victory pass again. Mission locators now replace overlapping 3D relay titles and stay behind interface panels. Broader subjective mixing, native input/platform acceptance, pacing/content and release gates remain open; performance work stays deferred.


## 77. Stable mission controls during live feedback

The command HUD now reserves two lines for transient notices and assignment instructions. Checkpoints, response warnings, long feedback and notice expiry no longer move the mission controls underneath a player's cursor. Long messages remain scrollable with mouse and keyboard; new feedback resets the scroll position, and in-progress assignments retain priority over queued notices. Compact command-card spacing preserves actual minimap clearance across all six campaign maps at 720p.

The old layout fails a held-click regression, while the final layout, four shared suites, a thirty-click slow probe and full campaign archive/replay flows pass. Tracing distinguished live native mouse interference from the reproduced layout movement; synthetic clicks now form one synchronous event gesture. Native-device, all-scale and platform acceptance remain separate. Evidence and retained failures are in the [campaign controls report](playtests/2026-10-04/CAMPAIGN_CONTROLS.md).


## 78. Scaled HUD clearance

Subtitles now use actual minimap and command-panel bounds, including live resize and interface changes. Oversized selection panels scroll below the top HUD while preserving production-queue space, keyboard focus visibility and direct mouse interaction. All six campaigns pass caption/navigation checks at 100/125/150%; both factions pass caption/selection/production checks on all four skirmish maps. The existing interface workflow and eight shared suites pass. See the [scaling report](playtests/2026-10-04/CAMPAIGN_SCALE.md) for original failures, rendered captures and limits. Physical-device, broader accessibility and release acceptance remain open.


## 79. Authored area defense

New Guard & regroup starters use the shared bounded guard behavior: hold a legal firing position, approach observed enemies within the assigned six-metre area, and return after they leave. Lua exposes `guard`; visual rules expose Defend assigned area. Scripts retain retreat/recovery decisions while the engine enforces observation, weapon legality and manual authority. Existing saved sources and legacy visual compilation remain unchanged.

The HUD identifies conventional controls as a Preset draft, shows neutral guard boundaries and explains explicit Resume after assignment. Twenty shared checks and four rendered workflows pass; eighteen captures cover guard engagement, approach, authoring and arena controls. The controlled eight-defender probe now matches built-in guard fire for both factions. See [the authored guard report](playtests/2026-10-04/AUTHORED_GUARD.md) for original failures and verification.

Five full matches finish with four Advanced defeats and one Standard victory. Readiness samples show the reference commander's force-size and home-threat gates delaying assaults; they do not establish faction balance or explain the earlier uncaptured long loss. Sustained mixed-force strategy, ordinary pacing, novice/content/release acceptance and earlier uncaptured movement cases remain open. Performance stays deferred.


## 80. Roster choices before purchase

Production and construction hover cards retain identity and role when locked, unaffordable or at capacity. Total cost and missing resources are separate; production time includes fitted chips and current power, while construction time describes one engineer after travel. Helix roles and buildings now have useful descriptions instead of the generic specialist placeholder. The bounded card separates role text from purchase facts, and the engine accessibility description receives the same information.

Eight final suites, both-faction hover/keyboard purchase/mouse refund workflows, actual paid-job archives and ten reviewed 720p captures pass. Queue, population, structure and technology gates continue to reject unavailable purchases. See [roster information verification](playtests/2026-10-04/ROSTER_INFORMATION.md).

Four new Advanced Desert trials compare the existing aircraft reserve with a ground-count-before-air policy. The reserve withholds otherwise affordable armor for 59.0 / 41.5 sampled seconds in Bastion / Helix. Delaying air investment increases the pre-contact ground count from eight to ten / nine, but all four trials still lose before launching an assault. This narrows the reference-policy investigation; it does not justify changing prices or establish mixed-force balance. Strategy, ordinary pacing, novice/accessibility and broader product gates remain open; performance stays deferred.


## 81. Mixed-selection roster

Mixed selections now show faction-specific type counts, a damaged total and compact health tiles in stable eight-unit pages. Type, individual and damaged-unit controls narrow the selection; holding the configured selection modifier removes that subset. Health updates preserve control identity and order. Keyboard focus, Enter activation and remapped hints are supported.

Selection filtering preserves commands, programs, squads, paid jobs, resources, camera and tactical pause. It consumes the activating event before rebuilding controls; a unit dying under a held mouse button cannot send its later release through to battlefield selection, even if a keyboard event intervenes. Both factions, all 17 types, the 140-unit capacity case, Bastion mission vehicles and real disk restoration pass. Nine headless suites, rendered mouse/keyboard workflows at 720p/150% and seven reviewed captures are recorded in [mixed-selection verification](playtests/2026-10-04/SELECTION_ROSTER.md).

No balance values or archive schema changed. Physical-device, screen-reader and novice acceptance remain open alongside mixed-force strategy, remaining content and release acceptance. Performance optimization remains deferred.


## 82. Explicit direct commands

The selection panel now exposes Move [M], Attack target [T] and Attack move [F] with independent remappable shortcuts, targeting prompts and keyboard activation. Arming preserves current work; choosing a point/enemy commits through the existing manual queue. Invalid/hidden/incompatible targets retain the prompt, right-click/Escape cancels, and the configured queue modifier appends. Engineers keep their work when a mixed selection receives a combat order. Placement, program assignment, modal input, tactical pause and held-button death preserve input authority.

Controls profile version 2 adds the two actions while retaining every valid older custom binding, choosing free chords when defaults conflict. Both factions pass live movement/fire, lost sight, queue, migration and disk-restoration checks. Actual 720p/150% mouse/keyboard workflows, campaign controls and seven reviewed command captures are retained in [the direct command report](playtests/2026-10-04/DIRECT_ORDERS.md).

The shared alert check also exposed a courier circling a crowded HQ: sideways avoidance counted as movement progress. Near contact targets, recovery now checks sustained progress along the route, allowing brief outward detours. The original captured harvest, crowded delivery/construction, conserved final cargo, manual replacement and saved detour remain covered. Physical-device/accessibility, broader strategy/balance, novice/content and release acceptance remain open; performance stays deferred.


## 83. Crowded destinations and reference operation continuity

A longer mixed-force trial captured infantry pushing into an idle ally at the final reachable point beside a barracks. Plain ground Move now accepts the adjacent position after sustained lack of progress, bounded by the two body radii plus 0.2 m. Enemy occupancy, distant paths and other movement domains do not grant arrival; gathering/construction/contact actions retain their own checks. The captured unit now stops and receives ordinary treatment, and queued orders survive paused disk restoration and continue when the route clears. The original three restorations fail six checks; the corrected replays and 720p/150% rendered treatment pass. See [crowded destination verification](playtests/2026-10-04/CROWDED_DESTINATION.md).

The reference playtest commander also left reinforcements and completed waypoint units behind because it expected a null action instead of the ordinary idle-defense action. It now recognizes idle defenders while preserving active fire. Both factions' actual advance/recovery regressions pass. Proactive assaults, staged movement and later air investment alone remain inconsistent; explicitly reassigning programmed defenders toward observed economic threats produces viable recovery and renewed assaults in the retained trials. The [operation study](playtests/2026-10-04/MIXED_OPERATIONS.md) separates diagnostic runs, policy variations and runtime revisions. These are scripted Advanced Desert trials, not faction balance or novice pacing acceptance. Broader strategy, ordinary pacing, remaining content/platform/release gates stay open; performance remains deferred.


## 84. Blocked assignment clarity

The retained blocked tank was guarding a point inside a friendly aircraft factory. The existing five-second failure rule remains correct; stalled ground assignments inside owned structures now ask the player to choose a clear point. Only actual assignment destinations and living friendly footprints inform the message. New battle archives preserve the last Lua guard intent so the selected guard circle survives a blocked, paused reload without evaluating Lua. Older archives remain readable and initialize an absent flag to false until evaluation.

Captured Bastion and fresh Helix guards pass built-in/Lua/visual recovery, paused disk persistence, manual priority and diagnostic bounds. Nine shared suites and normal-clock 720p/150% mouse reassignment pass; all six screenshots were reviewed. See [blocked-assignment verification](playtests/2026-10-04/BLOCKED_ASSIGNMENTS.md). Broader strategy/pacing, content, novice/accessibility/platform and release acceptance remain open. Performance stays deferred.


## 85. Coastal Foundry surroundings and working-port detail

Coastal Foundry now extends into a continuous sea and shaped coastal landscape. Headlands and breakwaters frame the harbor mouth; maintenance, freight and utility sites connect through service paving behind the battlefield. Six editable original models add wind-shaped pine stands, layered rock, wave armor, pumps, containers and pipework. Coastal ground, slabs, aprons and roads receive restrained weathering and wear.

All 28 exterior landmark/grove placements stay outside the playable rectangle; four interior pine stands and service equipment retain existing blocker envelopes. The shoreline, four fields, two ground corridors, 11 flight/sight landmarks and saved map identity remain unchanged. Actual both-faction advances/retreats, aircraft clearance, harvesting, paid construction, moving archives and fog isolation pass. Nine headless suites, normal-clock combat and ten reviewed 720p/900p captures are recorded in [coastal environment verification](playtests/2026-10-04/COASTAL_ENVIRONMENT.md). Final subjective art, wider environment/content work, strategy/pacing, novice/platform and release acceptance remain open. Performance optimization stays deferred.


## 86. Industrial Crossroads surroundings

Industrial Crossroads now includes a rail siding and maintenance yards, a utilities court, birch scrub and exterior embankments. Five original editable assets, 23 placements and weathered ground/building surfaces preserve the existing streets, six landmark envelopes, fields and relays. Both-faction route/economy/capture/archive tests, shared Foundry/AI checks and 720p/900p fog/combat rendering pass. See [Industrial surroundings verification](playtests/2026-10-04/INDUSTRIAL_SURROUNDINGS.md). Final art, wider balance and release acceptance remain open.

## 87. Ownership beyond color

Controlled forces now use a compact circle symbol; opponents use a triangle. Hovering a currently observed unit shows its owner and faction, including during tactical pause. Labels choose open space around the unit and stay behind interface controls. The minimap uses matching shapes and resource diamonds, with a text legend on hover. Neutral scenery receives no military symbol.

Settings → Display can hide world symbols, with preview, Save and Cancel behavior. Minimap shape information remains available. Current observation, visibility modes, death and restoration determine the indicators; no marker is attached to remembered enemy structures or hidden mobile units. Both factions can share identical colors and models without losing ownership cues. See [ownership readability verification](playtests/2026-10-04/OWNERSHIP.md) for rendered evidence and limits. Physical-device, screen-reader and novice accessibility acceptance remain separate; performance optimization stays deferred.


## 88. Industrial and Coastal contested-match evidence

Both factions now have complete Standard/Advanced match observations on Industrial Crossroads and Coastal Foundry against Normal AI. Twenty-four matches across three separately retained commander revisions expose two playtest-policy errors: retreating into an HQ without a matching service facility, and failing to reassign a waiting point later occupied by a repair robot. The reference commander now selects a reachable clear fallback, keeps it stable, reacts to new construction or an available provider, and explicitly resumes a changed blocked retreat. Neither a clear point nor an HQ grants free healing; shipping program, combat, economy and navigation rules are unchanged.

The original captures, paused reassignment, matched service and onward assault regressions pass. The final eight matches produce two wins/six losses at 5:34.7–12:52.2, with zero AI coordination violations across 8,448 samples. Separate captured guard stops recover after Resume but remain unexplained; a 9.5-second movement delay also remains open. See [regional match evidence](playtests/2026-10-04/REGIONAL_MATCHES.md). This is broader match evidence, not balanced factions, identical-policy repetition or novice acceptance. Performance optimization remains deferred.


## 89. Guard arrival beside an occupied center

Ground guards now form up beside stationary defenders at the center, extending through settled guards of the same assignment within the original radius. Clear neighbor connections, valid ground allies and clear center assignments bound this behavior. Combat acquisition remains first; manual orders, movement speed and saved custom scripts retain their contracts. Derived formation membership resets on movement, combat or changed assignment and rebuilds after loading.

Seven original pre-block traffic captures and both-faction eight-tank preset/Lua/visual fixtures pass, including adverse limits, disk restoration, combat and manual departure. Seventeen shared suites and normal-clock rendered review pass. Four further Coastal Advanced matches finish, but retain one building-corner guard blockage and three unassigned AI attack-order observations. See [guard-arrival evidence](playtests/2026-10-04/GUARD_ARRIVAL.md). General navigation, strategy/pacing, novice and release acceptance remain open; performance stays deferred.


## 90. Retired AI task orders

AI regrouping now clears an obsolete attack-move when its defender is already home, including a route temporarily stopped for combat. Previously the task could lose group membership while its route remained active. Both-faction failing probes now pass, and all three difficulty budgets retain valid approach/idle orders, active missions and paused archives. Nine shared suites and normal-clock rendered checks pass.

Six original-runtime repeats did not reproduce the older full-match membership failure; four corrected-runtime trials finish without coordination violations. This does not retrospectively prove that older incident's cause. The retained Coastal corner blockage reproduces with live traffic and releases when its nearby repair robot is removed in a diagnostic, but the intact scene remains unresolved. See [task handoff and corner evidence](playtests/2026-10-04/COORDINATION_HANDOFF.md). Broader acceptance remains open and performance stays deferred.


## 91. Ground corner recovery and arrival decisions

Ground units now choose a navigable side route around a congested corner, commit briefly, and return to their existing assignment. Contact-aware steps can slide around allies without pushing through them. Short yielding remains appropriate near occupied friendly endpoints. Restoring a battle waits for every obstacle and the final navigation region to be ready while saved positions and clocks remain frozen.

Program decisions accept valid arrival or formation contact before applying the existing no-progress timeout. The original three guard captures, disk recovery and fresh faction fixtures pass; all six preset/Lua/visual arrival-at-timeout cases pass. Thirty-one shared suites and nine normal-clock 720p/150% captures pass. Four final Advanced matches finish with two wins/two losses and no coordination violations across 3,566 samples. A separate AI tank remains stuck in plain Move beside an Industrial lab in a thirty-second retained replay, so general congestion remains unresolved. See [corner recovery verification](playtests/2026-10-04/CORNER_RECOVERY.md). Broader strategy/pacing, content, novice/platform and release acceptance stay open; performance optimization remains deferred.


## 92. Crowded arrival along a short remaining route

Plain Move now measures remaining path travel when deciding whether it has arrived beside a settled friendly unit. The same body-spacing and no-progress limits apply across small path bends; a nearby endpoint across a long obstacle detour still requires the full route. New archives preserve the arrival observation so loading does not restart its timer, while older records remain readable.

The retained Industrial AI tank and fresh faction setups now finish their Move, and paused disk queues hand off correctly. Four normal-clock spectator captures and four Advanced matches complete; 3,451 AI coordination samples have no violations and sampled stationary episodes stay at or below 3.5 seconds. Shared verification records 32 passing suites and one intermittent archived harvesting-deadline failure, retained for follow-up. See [route-end verification](playtests/2026-10-04/ENDPOINT_TAIL.md). This resolves the captured tank defect without establishing general congestion, balance, pacing or full release acceptance. Performance work remains deferred.


## 93. Classic RTS technology and conventional opening

A completed vehicle factory and command lab give access to paid unit research. The selected lab and global **Tech** screen share the same single research slot with Coordination. The global screen pauses battle and restores its previous pause state when closed. Low power runs research at 35% speed; losing every completed lab pauses the project. Cancel returns the reserved price once, including after losing the lab. Completed technologies persist and affect existing and newly produced eligible units.

| Research | Materials / electronics | Full-power time | Effect / prerequisite |
|---|---:|---:|---|
| Coordination | 20 / 20 | 30 s | Unlocks long-range armor, squad programs and faction signature abilities |
| Weapon systems I | 30 / 20 | 35 s | +10% damage for infantry, tanks, combat walkers, long-range armor and strike aircraft |
| Weapon systems II | 60 / 40 | 50 s | +20% total damage; requires level I and Coordination |
| Combat armor I | 30 / 15 | 35 s | +10% maximum HP for the same combat roles, retaining current health percentage |
| Combat armor II | 60 / 30 | 50 s | +20% total maximum HP; requires level I and Coordination |
| Field service | 35 / 25 | 40 s | +25% actual healing from repair robots, depots, barracks and airfields |
| Faction doctrine | 45 / 35 | 50 s | Requires Coordination; improves the faction signature below |

Bastion **Fortified Anchor** raises the active sector's incoming-damage reduction from 15% to 25%. Helix **Accelerated Precision** raises the first-shot preparation reduction from 20% to 50%. Existing eligibility, setup, manual activation, cooldowns and interruption rules remain in force. Tech tiers are additive against faction base stats. Service capacity/range and weapon reload remain unchanged. Units show researched benefits in selection details and roster tooltips. The AI buys through the same research API after securing a healthy field army and reserving higher-priority construction/production funds.

Opening advice now introduces an ordinary tank before an unpaid lab, then offers paid chip retrofit for a surviving conventional vehicle. Existing lab foundations, paid tank queues and installations take priority over duplicate purchases. The guidance selects the appropriate unit; the player still pays for production, issues orders and chooses programs. Emergency economy advice can open Tech to reclaim a paid research budget even with no lab or engineers remaining.

Both-faction actual damage, armor, production, healing, ability, pause/power/lab-loss and exact archive checks pass. Native 720p/150% controls and shared gameplay checks are recorded in [technology verification](playtests/2026-10-04/TECHNOLOGY.md). These initial prices and bonuses need broader match and player balancing; this delivery does not establish Standard-start pacing or release acceptance. Performance work remains deferred.


## 94. Research-aware program arena

The program arena now defaults to completed research captured from the live battle and offers an unupgraded baseline for comparison. Fresh fixtures receive the selected weapon, armor and service benefits before simulation starts. Each restart recreates that setup, and returned evidence plus saved program test notes identify it. In-progress research and its payment remain in the paused parent match. The target army remains unupgraded; this is a program-behavior test with a declared setup, not a skirmish balance simulator.

Both-faction real-unit damage, armor, healing, authority, restart and malformed-setup checks pass. Native controls exercise researched and baseline runs, pause/resume and the actual editor/child-process return without changing live funds, pending research or orders. See [arena research verification](playtests/2026-10-04/ARENA_RESEARCH.md). Broader strategy/pacing, novice, content and platform acceptance remain open; performance work stays deferred.


## 95. Free Frontier and paid AI integration

Free Frontier Coalition is playable in skirmish with seventeen authored models, faster but less durable mobile units, conventional chips at 2 E / 3 s, finite observed wreck salvage and a coordinated mobility ability. Maneuver grants up to six eligible chipped ground combatants +35% speed for six seconds; Rapid redeployment increases this to +50%. The 25-second cohort cooldown and current orders remain authoritative. Version-8 archives retain salvage, cargo, paid retrofits and movement windows. See the [initial gameplay rules and verification](playtests/2026-10-04/FRONTIER_GAMEPLAY.md).

Frontier AI now budgets and fits new conventional armor after completing its lab, uses Maneuver during observed-contact travel including retreat/regroup, and schedules nearby safe salvage after delivering existing cargo. A wreck covered by a later building must have a navigable collection face before it can divert an engineer. Paid production, actual delivery, movement authority and adverse cases have targeted before/after evidence; the [AI and complete-match report](playtests/2026-10-05/FRONTIER_AI.md) records outcomes and limitations. The subsequent [harvesting route and handoff stage](playtests/2026-10-05/HARVEST_TRAFFIC.md) resolves the original advanced-base funding scenario and adds delivery-cadence coverage. Numerical balance, repeated strategies and novice acceptance remain open; performance work stays deferred.


## 96. Harvesting routes and reliable resource handoffs

Ground units simplify nearly collinear navigation points with a one-centimetre threshold. Engineers can follow the useful route around settled support units while existing avoidance and physical boundaries govern each step. Actual pickup, HQ delivery, finite field stock, paused archives and manual replacement remain part of harvesting verification.

AI engineers queue a needed resource assignment during their loaded return to HQ. The current trip delivers its cargo before the next job starts, so a fast arrival between AI decisions does not miss the reassignment opportunity. Safe approaches, guarded expansion, one new handoff per decision and manual authority still govern those choices.

Three complete original two-faction labor repetitions pass their funding/rebalance deadlines and paid mixed production. Captured routes, the 1.5-second decision cadence, disk restoration, shared gameplay suites and native rendering have [retained evidence](playtests/2026-10-05/HARVEST_TRAFFIC.md). These are bounded congestion and scheduling checks; repeated army strategies, balance, novice pacing and content/platform acceptance remain open. Performance work stays deferred.


## 97. Live research feedback

The battle command HUD uses its existing message area for active research progress, estimated remaining time at current power, and a rebuild-lab instruction when a paid project is suspended. When idle, it can show the count of individually affordable eligible research choices. Clicking the status opens the existing Tech screen; purchase and cancellation remain explicit. Direct-order/program-assignment instructions and ordinary notices own that area first. Coordination completion now has a human-player notice, matching unit-upgrade completion. Enemy research is not announced.

All-faction paid research, pause/power/lab-loss/refund/archive/notice-priority checks and native 720p/150% review of an earned project pass. See [research feedback verification](playtests/2026-10-05/RESEARCH_FEEDBACK.md). This improves visibility without establishing broader novice, balance or release acceptance; performance work remains deferred.


## 98. Own-force skirmish debrief

Skirmish results now show completed force/engineer production, own losses split into forces, engineers, built structures and unfinished foundations, plus basic-program unlock and first-active-program times. Starting units, cancelled jobs/foundations and enemy events do not count. These facts support reviewing an opening; they do not diagnose a defeat or certify program quality.

Snapshot version 9 preserves the record. Versions 1–8 remain readable, with partial history beginning at the restore time and unknown earlier milestones marked “Not recorded”. Partial history remains partial when resaved. Campaign-specific result summaries retain their mission narratives. See [debrief verification](playtests/2026-10-06/BATTLE_DEBRIEF.md) for live production/loss, persistence, rendering and native-input limits.


## 99. Skirmish relay navigation

Alpine Relay and Industrial Crossroads expose an optional Relays overview beside the battle controls. It explains ten-second infantry capture and persistent local vision, shows named public ownership/progress/contest state, and centers the camera with View North/South Relay. Opening pauses simulation; closing or locating restores the previous pause state while retaining selection, orders and resources. Campaign objective panels remain separate.

Public world labels and minimap squares remain readable in unexplored fog without disclosing nearby enemy units. Labels sit on the capture ground, behind HUD panels, and ignore pointer input. Six all-faction/map scenarios pass actual capture, contest, paused disk restoration, camera targeting, manual authority and fog isolation. Four shared suites and fourteen rendered 720p/150% captures pass; physical native input remains limited by computer use selecting Godot Project Manager. See [relay navigation verification](playtests/2026-10-06/RELAY_OVERVIEW.md). Broader strategy, novice and platform acceptance remain open; performance remains deferred.


## 100. Guard arrival at completed navigation endpoints

Guard can settle beside an assigned point when the completed navigation path ends within one metre of it and the unit is within that endpoint's bounded arrival tolerance (at most 0.5 m). The assigned circle, clear line to the point, matching destination and ground-unit restrictions still apply. A stationary settled guard survives save/load; displacement rechecks arrival. The existing five-second safeguard continues to report genuine stalled travel.

The earned Alpine case, three Frontier authoring forms, Bastion/Helix formations, obstruction/authority bounds, combat, disk restoration and seven rendered captures pass. See [guard endpoint verification](playtests/2026-10-06/GUARD_ENDPOINT.md). This repairs a false Blocked state without establishing broader crowd, strategy or release acceptance. Performance remains deferred.


## 101. Visible incoming-fire feedback

The battle-alert button displays “Base under attack” for active own-building damage, with priority over “Units under attack” for other own-unit fire. New/active counts remain in its tooltip and accessibility description. Reading history keeps the active warning; the existing eight-second simulation-time expiry restores the ordinary count label. Tactical pause preserves the state, and inspection retains normal order authority.

All-faction damage/priority/expiry checks, an earned Industrial raid, shared alert/defense suites and six rendered 720p/150% states pass. See [attack feedback verification](playtests/2026-10-06/ATTACK_FEEDBACK.md). This improves visibility without establishing better strategic outcomes or broader novice/platform acceptance. Performance remains deferred.


## 102. Independent HQ recovery deadlines

Skirmish objectives show both missing HQs' independent deadlines, labeled Your HQ and Enemy HQ even in same-faction matches. Paused destruction immediately shows the full recovery window. A replacement foundation keeps its deadline until the HQ is completed; successful recovery removes only that side's warning. Advice shows the full construction time before purchase and the existing resume-construction instruction after payment.

All three factions pass staggered losses, paused disk restoration, paid reconstruction and actual enemy timeout. Victory, Defeat and Draw remain unchanged. Five headless suites and five 720p/150% rendered states pass, including advice selection and separation from the minimap. See [HQ recovery verification](playtests/2026-10-06/HQ_COUNTDOWNS.md). Controlled fixtures do not establish full-match comeback viability or broader novice/platform acceptance; performance remains deferred.


## 103. Recovery routes through occupied base lanes

Ground movement recovery ranks usable distance before terrain clearance, including a backward escape when neighboring bodies occupy the side routes. Existing navmesh projection, contact clipping, speed limits and arrival rules still apply. This lets the retained opposing engineers separate at the Industrial HQ instead of repeatedly selecting a blocked sidestep.

Live archived traffic clears with actual cargo delivery, paused disk recovery and fresh all-faction corridor completion. Fourteen headless suites have passing final runs and seven rendered 720p/150% states pass; an initial attack-arrival timing miss remains recorded. Two complete paid trials show no long sampled stationary episode but both lose. See [HQ traffic verification](playtests/2026-10-06/HQ_TRAFFIC.md). Clearing a traffic jam does not guarantee survival under fire or establish general crowd, strategic or release acceptance. Performance remains deferred.


## 104. Progress toward an occupied endpoint

Plain Move and AttackMove can settle beside a friendly unit occupying their final reachable point after the existing two-second observation finds less than 0.2 m of progress toward that endpoint. Sideways recovery no longer counts as approach. Completion still requires the existing short route and body-spacing bounds, a settled friendly ground neighbor, and no active AttackMove combat. Queue and paused save restoration preserve their existing behavior.

The retained intermittent case now passes fourteen late-state replays and 48 fresh replays in about two seconds, with twelve headless suites and four 720p/150% rendered states. See [attack-arrival progress verification](playtests/2026-10-06/ATTACK_ARRIVAL_PROGRESS.md). General crowd, strategy and release acceptance remain open; performance stays deferred.


## 105. Independent AI resource savings

Skirmish AI reserves protect each stockpile from purchases that would consume it. A shortage of saved electronics no longer blocks materials-only infantry when sufficient materials remain after construction and higher-priority unit savings. Electronics-consuming purchases still wait for their full protected budget; costs, queue timing, refunds, research priorities and worker recovery retain existing rules.

The earned late Industrial infantry request completes with exact paid/save continuity. All-faction reserve contracts and nine headless suites pass. Two paid matches reach outcomes, including a normal infantry purchase during lab-electronics saving; this does not establish improved balance or solve the separate reference recovery stall. See [resource-reserve verification](playtests/2026-10-06/RESOURCE_RESERVES.md). Broader strategy and release acceptance remain open; performance stays deferred.


## 106. Reinforcement versus optional research evidence

The paid reference commander can reserve optional upgrades while below its own nine-ground-unit assault gate. An opt-in reinforcement-first variant preserves Coordination, defers optional upgrades below that gate, and resumes them once enough eligible combatants exist. In the retained five-minute budget replay, the variant reaches nine units at 156 seconds while the control remains at seven and buys upgrades. All-faction paid production and paused disk continuity pass.

Four complete match comparisons do not establish a stronger strategy: Alpine's variant wins much later with more losses, and both Industrial policies lose before programming. The existing cautious policy remains unchanged. Improved test telemetry now distinguishes real requests, paid/blocked queues and unmeasured reserve fields; an older empty human production list did not prove absent demand. See [reinforcement/research audit](playtests/2026-10-06/REINFORCEMENT_PACING.md). This is reference-policy and diagnostic work, not a shipping balance change; broader gameplay acceptance remains open and performance deferred.


## 107. Show economic danger when selecting defenders

The battle plan's mobile-defender action selects its recommended units and focuses the camera on a threatened owned asset. The newest recent damage event takes precedence; otherwise it uses an asset threatened by a currently observed legal attacker. Unseen fire reveals only the owned victim's location. The six-second damage window, fog rules and urgent recovery precedence remain intact. Production and engineer actions keep their original focus, and selection never replaces unit orders.

Seven headless suites, fourteen injected mouse/Enter interactions and six inspected 720p/150% captures pass, including the earned Industrial raid and paused disk continuity. See [defense-focus verification](playtests/2026-10-06/DEFENSE_FOCUS.md). This is a player-orientation improvement, not an automatic defense policy or evidence that the current Industrial opening survives. Broader acceptance remains open; performance stays deferred.


## 108. Observed-threat construction evidence

An opt-in reference commander skips legal construction sites whose destination or straight builder approach is exposed to currently observed legal attackers. It uses existing engineer danger margins and ordinary placement/payment; hidden contacts cannot affect choices, and all-site deferral spends nothing or changes no orders. The default reference and player placement rules remain unchanged.

All-faction paid construction, threatened approach, hidden-contact, deferral and exact paused disk continuity pass. From one earned funded Industrial state, the filter buys one surviving barracks for 20 materials while the control buys four for 80 and loses three over 120 seconds. Both full paid comparisons still lose, and the filtered run reaches programming later; no stronger strategy is accepted. See [construction audit](playtests/2026-10-06/CONSTRUCTION_SAFETY.md).

Verification also exposes four pre-existing ContactApproachRegression failures on current and preceding shipping code; an older pre-HQ-traffic baseline passes. The shared suite is not fully green. Repair that captured harvesting approach before further movement acceptance; broader gameplay acceptance remains open and performance deferred.


## 109. Preserve usable sideways recovery

Ground recovery distinguishes a completely body-blocked direction from a side with at least the existing two-centimetre contact margin of free travel. Among usable directions it prefers navigation clearance, allowing ordinary avoidance to slide around a neighbor. If the sides are fully blocked, a backward escape remains available. Movement speed, actual work contact, collision tolerances, orders and save state retain their established rules.

This repairs the harvesting regression recorded in section 108: twelve captured replays collect at 6.1 seconds, three paused disk continuations and fresh all-faction delivery/construction pass. The faulty-source control fails fifteen assertions. Nine relevant headless suites and two rendered scenarios with ten inspected captures pass, including the earlier HQ-traffic escape and occupied-arrival cases. See [contact recovery verification](playtests/2026-10-07/CONTACT_RECOVERY.md). General congestion, Industrial progression and broader acceptance remain open; performance stays deferred.


## 110. Discover blocked and failed programs

A compact Program issues count in the battle-plan header selects owned living units with Blocked or Error programs and reveals their program status. It remains visible with collapsed guidance and preserves urgent advice, orders, assignments and pause. Players explicitly reassign and Resume; reviewing the issue never restarts execution. Cleared, foreign, dead and queued units leave the count, and modal/editor/result guards protect selection.

The earned Industrial archive discovers two blocked guards before and after disk restoration. Six headless suites pass, with eight mouse/Enter shortcut activations, actual assignment/Resume recovery for all three factions and eleven inspected 720p/150% captures. See [program-issue verification](playtests/2026-10-07/PROGRAM_ISSUES.md). Full-match progression, the separate stationary observation and broader acceptance remain open; performance stays deferred.


## 111. Escape a clipped navigation-boundary step

During active ground recovery, a navigation-projected avoidance step that leaves less than one millimetre of movement can retry the committed recovery direction through the same speed, navigation and swept body-contact constraints. It uses the alternative only when it moves farther. Occupied-endpoint yielding remains excluded, and actual velocity is still fed back to avoidance.

This clears the retained Industrial engineer/infantry pinch, with collection and delivery in all six replay/disk branches; preceding code fails twenty-five assertions. Eight final headless suites and two rendered branches with seven inspected captures pass. Wider verification is incomplete: twenty focused occupied-arrival replays expose two preceding-code and five current-code deadline misses; a separate full harvesting-suite manual replacement miss remains unexplained despite twelve isolated passes on each version. Both paid Industrial comparisons lose without programming. See [Industrial pinch verification](playtests/2026-10-07/INDUSTRIAL_PINCH.md). General movement, progression and release acceptance remain open; performance stays deferred.


## 112. Keep stalled arrival ready between geometry checks

Move and AttackMove retain an elapsed two-second arrival observation until existing geometry permits completion or at least 0.2 metres of new approach progress starts another wait. Outward crowd displacement no longer becomes fresh progress when a unit returns to its prior position. A temporarily empty navigation path after loading preserves the saved observation but cannot complete arrival. Existing settled-ally, distance, short-route, ground-domain and active-combat restrictions remain unchanged.

The formerly intermittent archive passes forty replays, five captured failures pass fifteen continuations, and nine relevant headless suites pass. The preceding-source window control fails five assertions. Exact ready-state disk restoration and both rendered branches pass, with five inspected captures. See [arrival-window verification](playtests/2026-10-07/ARRIVAL_WINDOW.md). This closes the reproduced sampling/reload defects; the prior isolated harvesting replacement miss is not independently explained by its current passing suite. Industrial progression and broader acceptance remain open; performance stays deferred.


## 113. Guarded recovery reference experiment

An opt-in reference recovery policy requires an owned armed ground guard with at least half health within ten metres before resuming resource work beyond thirty metres from HQ. Existing known-threat checks remain, and safe local work can replace an unguarded distant assignment. Routine economy/expansion orders and continuing escort behavior are outside this hook; shipping code is unchanged.

All-faction eligibility, withdrawal/resumption, real harvesting/delivery and paused disk continuity pass. The original-policy control fails fifteen expected eligibility assertions while completing the same deliveries. One complete paid Industrial pair reaches programming in both runs but loses both; guarded recovery reaches programming later and survives less time, so it remains experimental. Initial descriptor errors and a separate frozen-army fixture stall are retained, with no congestion-fix claim. See [guarded reassignment evidence](playtests/2026-10-07/GUARDED_REASSIGNMENT.md). Sustained progression and broader acceptance remain open; performance stays deferred.


## 114. Reject assignments inside owned buildings

Ground guard, retreat and patrol point input now rejects owned living building/foundation footprints before changing programs or orders. Targeting stays active with a clear instruction. Mixed ground/air groups remain atomic, aircraft alone can target above buildings, and hidden enemy geometry never enters the check. Patrol input preserves a valid first point through a bad second click and revalidates it before committing. Signature sectors and service/escort targeting keep their separate rules. Runtime diagnostics and assignment input share the existing footprint lookup.

All three factions pass rejection/queue/running-program authority, actual clear-point arrival and firing, and exact paused disk continuity. The original-source control fails 84 assertions; seven final headless suites and nineteen engine-injected map clicks pass, with six inspected 720p/150% captures. Separately, the previous departure stall reproduces with disabled neighbors but all three normally active idle armies allow collection/delivery; no movement change is made. See [assignment footprint verification](playtests/2026-10-07/ASSIGNMENT_FOOTPRINTS.md). Later construction can still obstruct an existing point and requires explicit reassignment/Resume. Industrial progression and broader acceptance remain open; performance stays deferred.


## 115. Preserve completed service safe points

The preceding footprint input filter incorrectly rejected the documented safe-point-on-service recovery flow. Safe assignment now admits completed, living, owned facilities matching each selected ground unit through the existing repair eligibility rule. Guard/patrol and unfinished/unsuitable-footprint restrictions remain. Assignment preserves health, resources and source; explicit Resume still owns execution.

The pre-fix UI runner rejects 36 valid ground combinations. Final UI-to-recovery verification passes 54 role/faction/authoring-mode cases, nine partial-healing disk continuations, five headless suites and eight engine map clicks. Ten 720p/150% captures show readable feedback and actual healing/return. An initial autoload-order fixture failure is retained and excluded. See [service assignment verification](playtests/2026-10-07/SERVICE_ASSIGNMENT.md). This corrects section 114's blanket safe-point restriction; broader gameplay acceptance remains open and performance deferred.


## 116. One-engineer construction and unused-cost refunds

Skirmish sites now accept one engineer's progress at a time, with automatic handoff from live in-range orders when the current builder stops, dies or leaves. Cancellation returns the unused cost, rounded down separately for each currency, and the selection button shows that amount. Repeated cancellation and cancellation of completed/dead structures cannot refund resources. Legacy non-skirmish rate/refund behavior remains.

The original-code control fails eighteen assertions; eight final headless suites pass. All three factions pass actual paid HQ placement, ordinary crew construction, stopped/dead builder handoffs, exact paused disk continuation, completion before defeat and paid cancellation/refund checks. The rendered run passes four engine button clicks with seven inspected 720p/150% captures. Fixtures supply funds and positions, so earned-state reconstruction and sustained Industrial recovery remain open. See [construction verification](playtests/2026-10-07/CONSTRUCTION_CONTRACT.md). Performance remains deferred.


## 117. Recover funds from unfinished buildings

Recovery guidance now counts the unused, floor-rounded refund from live foundations alongside paid production and research. When useful, Review foundation selects the named building and shows its current refund; cancellation remains explicit. HQ advice continues to reject a rebuild when either currency is still short. The same source can fund replacement of the final engineer when a completed HQ remains.

All three factions pass ordinary harvesting/delivery to a 120 M / 32 E budget, paid barracks and partial factory construction, injected HQ loss, exact paused disk continuation, explicit factory cancellation and paid HQ reconstruction before defeat. No resource or position injection occurs along this earned path; opponent strategic decisions are disabled and the HQ loss is controlled. Combined production/research/multiple-foundation and engineer-replacement fixtures pass, while the preceding source fails thirty assertions. See [foundation recovery verification](playtests/2026-10-07/FOUNDATION_RECOVERY.md). Sustained recovery against an attacking opponent and broader acceptance remain open; performance stays deferred.


## 118. Contested HQ recovery experiment

An opt-in reference controller protects an HQ budget while all completed headquarters are damaged or visibly threatened, and follows ordinary paid refund/rebuild choices after loss. Protected or visibly endangered engineers are excluded; placement checks observed approach safety and an estimated construction deadline. Default reference behavior and all 288 shipping scripts remain unchanged.

The complete paid Industrial control reaches programming and assault but loses at 637.80 seconds; the experimental run reaches neither and loses at 417.60 seconds. Neither buys a replacement HQ. Earned checkpoint audits show the control lacks electronics despite some statically feasible sites, while the experiment lacks materials and has no engineer outside observed danger. All-faction isolated policy/construction checks and both paused checkpoint audits pass. See [HQ recovery experiment](playtests/2026-10-07/HQ_RECOVERY_POLICY.md). The reserve strategy is not promoted. Stronger home defense and protected electronics income remain necessary; contested rebuilding and broader acceptance are unproven. Performance stays deferred.


## 119. Explicit electronics handoff after fallback

A reference economy can remain on materials indefinitely after its safety policy diverts electronics workers. An opt-in commander helper restores the established one/two-electronics-worker split by queueing a new gather order behind a loaded delivery. It preserves retreat and manual queues and checks observed route safety plus a remote ground guard. Human automatic harvesting, the default reference and all shipping scripts are unchanged.

All-faction collection/delivery, exact paused disk continuity, authority, quotas and remote-threat checks pass. In a retained active-enemy battle checkpoint, preserving the order delivers 4 M / 4 E in 28.78 seconds; clearing it leaves the worker delivering only materials over sixty seconds. The final full pair still loses at 561.10 / 566.80 seconds, without assault, so strategy promotion is unsupported. An intermediate two-electronics-worker opening lasted longer but changed the intended opening and remains separate evidence. See [electronics handoff verification](playtests/2026-10-07/ELECTRONICS_HANDOFF.md). Home defense, sustained income through later raids and broader acceptance remain open; performance stays deferred.


## 120. Weapon-compatible defensive sectors

The default reference commander now directs each running guard toward the highest-priority observed home threat that its current weapons can target. Ground-only tanks no longer follow aircraft while a compatible ground raid remains elsewhere. Air-only pressure leaves those tanks at the ordinary defense point; protected recovery and manual orders retain authority. Shipping gameplay scripts remain unchanged.

All three factions pass mixed-raid approach and actual firing in authored Lua/visual modes, exact paused disk continuity and authority checks. Walker tests cover Helix Precision and its completed Interception switch as well as Bastion/Frontier air targeting. Five final suites pass; the original selection fails 24 assertions. The full Industrial pair still loses at 761.20 / 472.00 seconds, with opening differences before guard programming, so no survival benefit or regression is established. See [guard response verification](playtests/2026-10-07/GUARD_RESPONSE.md). Sustained home defense, safe sector approaches, protected resource income and broader acceptance remain open; performance remains deferred.


## 121. Reliable replacement rally targets

Changing a producer's rally target now releases the old target's lifetime listener and watches the replacement. Depleting the former resource field no longer erases the new destination; losing the current target clears it and returns the selected marker to the producer. Explicit point rallies retain their exact saved position.

All three factions pass actual paid engineer production, paused disk restoration and electronics delivery after material-to-electronics retargeting. Friendly-target loss, repeat assignment and point archives pass. Five final headless suites and six engine-injected right-clicks at 720p/150% pass; the preceding shipping source fails nine assertions. See [rally verification](playtests/2026-10-07/RALLY_RETARGET.md). The fixtures disable strategic AI and inject target loss, so contested economy and broader gameplay acceptance remain open. Performance stays deferred.


## 122. Visible and cancellable producer rallies

Completed producer panels now show their current destination and replace the ineffective single-producer Stop action with Clear rally. It is disabled when no rally is assigned. Clearing preserves paid production, existing unit orders and factory-program settings; mixed-selection Stop and unfinished-building cancellation keep their established behavior.

All three factions pass all four producer controls, target/point clearing, paused disk continuity and actual paid engineer completion after clearing. Five final suites, two rendered mouse clicks, one Enter activation and seven inspected 720p/150% images pass. The preceding UI fails 24 assertions. See [rally controls](playtests/2026-10-07/RALLY_CONTROLS.md). Broader contested progression, novice/environment/platform acceptance and deferred performance remain open.


## 123. Repeated sustained-defense trials

Twelve paid Standard Industrial matches compare the default reference commander, explicit conventional response, electronics restoration and their combination over three seeds each. All finish and reach programming within three to five minutes. Default and response lose all three; electronics-only and combined each win one. The combined victory lasts 28:52 and includes eight assaults, seven regroups and eight authored recovery returns, demonstrating one complete sequence at the intended longer pacing.

The results remain inconsistent and do not justify general policy or balance promotion. A combined loss exposes material starvation alongside five electronics assignments and an electronics stockpile; returning workers and routine assignment decisions need reconciliation beyond a one-way restoration helper. Three focused regression suites pass. See [comparison and evidence](playtests/2026-10-07/SUSTAINED_DEFENSE.md). Shipping scripts and default reference behavior remain unchanged. Broader gameplay acceptance remains open; performance stays deferred.


## 124. Surplus electronics and recovery spending

An opt-in reference helper can return excess electronics workers to materials when current planned purchases have a material shortfall and sufficient electronics. It preserves loaded delivery, queued/protected orders, observed route checks and the opening electronics floor. All-faction real harvesting and paused disk continuity pass; an exact earned replay with active enemy AI delivers 4 E / 4 M with the order versus 12 E / 0 M without it.

This local correction is not promoted as a general strategy. Four paid Industrial trials produce three defeats and one unresolved thirty-minute control, so the complete-match gate fails. The unresolved reference holds seven ground combatants below its nine-unit recovery threshold while research takes 160 materials ahead of replacement armor. The exact archive and commander state are retained for a recovery-priority experiment. Four focused suites pass; shipping scripts/default reference remain unchanged. See [materials handoff evidence](playtests/2026-10-07/MATERIAL_HANDOFF.md). Broader acceptance remains open and performance stays deferred.


## 125. Recovery purchases match the reference assault gate

The current reference commander now defers optional research while it lacks the nine ground combatants required by its own assault condition. It reuses the earlier opt-in rule, retaining Coordination eligibility, paid work and essential production. All-faction exact-cost, refunds, expedition exclusion and actual post-archive completion pass.

A continuation of the new unresolved Industrial world with live enemy AI reaches nine units and resumes assault in 171 seconds rather than 891 seconds; both branches win, after 291.25 / 995.85 seconds beyond the original thirty-minute horizon. The saved world is exact, while recorded commander state is reconstructed and unrecorded histories/random streams restart. Three fresh runs all lose, including the final default, so this corrects a spending/readiness conflict without establishing better general balance. Five terminal runs have zero unresolved checks. See [recovery reinforcement evidence](playtests/2026-10-07/RECOVERY_REINFORCEMENTS.md). Shipping gameplay stays unchanged; broader survival/pacing and product acceptance remain open, with performance deferred.


## 126. Visible gathering assignments

Materials/electronics totals now have compact engineer-count selection shortcuts. Each living engineer counts once against its immediate queued job, or its current gathering assignment when no order is queued. Selection retains cargo and commands. Supply guidance uses the same accounting and no longer recommends restoring a stream that already has a queued incoming gatherer; valid work-slot waits count, while depleted assignments and invalid/dead targets do not.

All-faction cargo/queue/archive and actual fitted-production checks pass, as do shared supply/order contracts. The preceding shipping files fail twelve assertions; final 720p/150% mouse/Enter controls and three inspected images pass. See [economy assignment evidence](playtests/2026-10-07/ECONOMY_ASSIGNMENTS.md). This adds player-facing economy visibility without automatic redistribution. Controlled Advanced fixtures do not prove contested balance or novice acceptance; the remaining gameplay/environment/platform gates and deferred performance stay open.


## 127. Finale deployment recovery across difficulties

Command Horizon now distinguishes destroyed enemy command from the remaining deployment objective, with explicit infantry recapture guidance, retained hold progress, completed-state wording and urgent own-HQ recovery priority. No difficulty budgets or victory rules change. The new text survives paused loading and fits the 720p/150% interface.

Current Story/Standard normal runs win; Veteran normal and Reinforced initially destroy command but leave deployment lost. Explicitly recalling the surviving force with ordinary orders and paid infantry produces fresh victories at 263.85 / 183.33 seconds; Veteran Lean wins at 347.93 seconds with its existing economy-first commander. The earned lost-deployment state also reaches actual headless/rendered victory after recall. These are viable-route checks, not novice or repeated balance acceptance. Shared mission rules, focused feedback/save checks and rendered mouse/Enter input pass. See [finale difficulty evidence](playtests/2026-10-07/HORIZON_DIFFICULTIES.md). Broader acceptance remains open; performance stays deferred.


## 128. Explain contested convoy clearance

Supply Line now labels stopped trucks Contested when enemy ground units suspend clearance, retaining the counter and explaining the escort response in a tooltip. The HUD shares the mission’s existing ten-metre ground-unit predicate. Moving trucks still ask for Hold, and cleared checkpoints remove the contested message. No automatic combat orders, force-budget changes or archive changes are introduced.

Story, Standard and Veteran each have focused victories with individual arrival stops and with three ordinary Advance/Hold pairs. A normal-clock Veteran route exposes an enemy holding the first checkpoint at 9.8 seconds while damaging a truck; its earned archive clears in about three seconds after explicit escort/repair orders. The final rendered Veteran route wins at 229.80 seconds. Focused old-code failures, paused archives, shared mission/reward rules and 720p/150% mouse/Enter controls are recorded in [convoy difficulty evidence](playtests/2026-10-07/SUPPLY_DIFFICULTIES.md). Novice/repeated balance and remaining product/environment/platform acceptance stay open; performance remains deferred.


## 129. Supply Line freight-road environment

The opening convoy map gains six editable freight-road assets, continuous worn pavement, numbered concrete checkpoints, low drainage/sage, sandstone and industrial landmarks, surrounding terrain/mesas and warmer lighting. Four former oversized cliff meshes are replaced by models inside the original movement/sight envelopes. Checkpoint, response and obstacle positions remain unchanged; all three baseline navigation route lengths match exactly.

Story/Standard/Veteran group routes win at 221.73 / 225.87 / 229.72 seconds. The normal-clock Veteran mouse/Enter route wins at 226.78 seconds; the earned contested battle still recovers through ordinary escort/repair orders in 3.03 seconds. Imported geometry, terrain joins, observation, shared convoy/archive/reward rules and nine accepted 720p/900p captures pass review. See [environment evidence](playtests/2026-10-07/SUPPLY_ENVIRONMENT.md). Final composition, novice/repeated balance and broader product/platform acceptance remain open; performance stays deferred.


## 130. Air Corridor flight recovery and difficulty routes

Held evacuation transports now display Holding and Continue guidance, returning to In flight/Safe when their state changes. Compact success/default text and content-sized panels avoid the demonstrated minimap overlap at 720p/150%. Restored battles use a state-neutral load confirmation, retaining warnings without falsely claiming a resumed battle is paused.

Story/Standard existing commanders save three flights; Veteran loses two after saving one. Explicit observed ground-screen attacks and ordinary repairs produce a fresh three-flight Veteran victory; the final normal-clock mouse/Enter route saves all three at 212.10 seconds. The earned held-flight archive reaches safety in 45.03 seconds headless and 45.12 rendered. Shared flight/archive/reward checks, Bastion/Helix warning continuity and nine final captures pass. These are viable-route and recovery checks, not novice/repeated balance acceptance. See [Air Corridor evidence](playtests/2026-10-07/AIR_DIFFICULTIES.md). Broader gameplay, final environments and platform acceptance remain open; performance stays deferred.


## 131. Air Corridor quarry environment and aircraft clearance

Air Corridor gains seven editable quarry/freight assets, continuous worn haul roads, battery aprons, evacuation pads and exterior crushing/conveyor scenery. Thirteen replacement solids fit the existing movement/sight envelopes; all four measured navigation lengths match the baseline exactly. Aircraft now climb over these landmarks, correcting the measured old drone/rock intersection. Thirty-nine actual airframe crossings pass; the new raised-flight archive restores exactly, while an old low-flight archive retains its paused coordinates and regains clearance on resumed movement.

Story/Standard/Veteran existing commanders reach victory with three/two/two saved flights. Explicit observed-threat response saves all three on Veteran, including a normal-clock 211.10-second mouse/Enter route at 720p/150%. The earned held-flight archive also recovers. Fifteen accepted art/flight/combat captures were inspected. Altitude affects combat range/sight, so preserved ground routes do not imply identical outcomes. See [quarry environment evidence](playtests/2026-10-07/AIR_ENVIRONMENT.md). Novice/repeated balance, final subjective art and broader product/platform acceptance remain open; performance stays deferred.


## 132. Relay capture, contest and infantry feedback

Relay presentation now distinguishes advancing capture/recapture, enemy takeover, a contested standstill, retained vacant progress and friendly armor that needs infantry to capture. Split Signal's uplink gives the corresponding instruction; shared relay overview ownership, tooltips and locator accessibility retain the same state information. Ownership, capture/scoring, response budgets and save schema remain unchanged.

The old code fails five focused feedback checks. Final capture/armor-only/pause/disk restoration checks, all-faction Alpine/Industrial overview, First Orders and Split Signal rules pass; nine final 720p/150% captures were reviewed. Full encounters expose original-commander Story/Veteran stalls. Explicit test-only attacks recover the earned Story battle in 37.60 seconds; paid Veteran reinforcement/retake branches win headless and in a 47.78-second normal-clock continuation. Other normal-clock branches remain unfinished, and the fresh Veteran repeat wins before its clearance helper activates: these results demonstrate viable routes, not repeated balance or causal improvement. See [relay feedback and recovery evidence](playtests/2026-10-07/RELAY_FEEDBACK.md). Novice comprehension, repeated strategy/reward combinations and broader environment/platform acceptance remain open; performance stays deferred.


## 133. Find capture infantry and preserve explicit follow-through

Split Signal offers Find infantry when friendly armor holds a relay that still needs a capture unit. It prefers nearby idle infantry, preserves existing orders and pause state, and falls back to Find barracks without starting production. Missing capture infrastructure is explained; View remains available.

An earned Veteran stall exposes idle infantry short of the relay. Exact restoration plus the shortcut and an explicit move recover it in 12.85 seconds headless and 12.80 seconds through rendered mouse/Enter/right-click controls. The reference commander now explicitly queues an ordinary return to the relay after clearing a target; a controlled target-loss regression fails with the old queue and captures in 14 seconds with the new one. Shared campaign/order/feedback checks, fifteen classified script runs and seven reviewed 720p/150% captures are recorded in [recovery evidence](playtests/2026-10-07/SPLIT_RECOVERY.md). Normal-clock results vary and do not establish repeated balance. Novice comprehension, broader gameplay/environment/platform acceptance and deferred performance remain open.


## 134. Split Signal alpine communications environment

Split Signal gains continuous snow/gravel terrain, plowed access roads and wheel tracks, weathered relay aprons, low sedge and an exterior mountain/communications-station layout using the existing editable alpine kit. Three shelf footprints/sight envelopes and four measured ground-route lengths remain unchanged. Exterior mesh vertices stay outside the playable map, add no physics/navigation and join the terrain at zero elevation.

Story/Standard/Veteran reference routes win at 136.52 / 198.67 / 136.52 seconds; Standard uses explicit clearance after all six responses. The normal-clock Veteran route wins at 136.67 seconds. The earned idle-infantry archive still recovers in 12.85 headless / 12.80 rendered seconds through ordinary controls. Shared campaign/archive/relay checks and fourteen final captures pass. See [environment evidence](playtests/2026-10-07/SPLIT_ENVIRONMENT.md). These runs establish viable routes, not repeated balance or novice comprehension. Final subjective art and broader product/platform acceptance remain open; performance stays deferred.


## 135. Broken Foundry capture and securing feedback

Broken Foundry now distinguishes active/retained capture, recapture, blocked contention, active securing and absent infantry across its objective, HUD and world marker. Presentation shares the same nearby-living-infantry predicate as the unchanged 30-second securing rule. Tooltips explain both stages and retained time.

Original presentation fails ten state/wording checks; current source passes real objective transitions, partial/owned-vacant disk restoration and unchanged 30.60-second controlled return. Native mouse/Enter/right-click recovery takes 30.62 seconds. Full Story/Standard/Veteran routes win at 133.27 / 149.38 / 147.97 seconds; normal-clock Veteran wins at 147.35 seconds with ordinary paid replacements. Shared mission, production, reward and relay contracts pass; thirteen classified processes and eleven reviewed captures are in [Foundry feedback evidence](playtests/2026-10-07/FOUNDRY_FEEDBACK.md). These are clarity and viable-route results, not novice/repeated balance acceptance. Broader environment/product/platform acceptance remains open; performance stays deferred.


## 136. Broken Foundry complete paid batches

A ready node batch waits for enough ordinary queue slots, population space, funds and chip prerequisites to admit every job. Only full admission advances its finite three-batch counter; unexpected partial admission rolls back through ordinary cancellation. HUD Waiting labels explain the blocking reason through actual accessible hover. Existing paid jobs, prices, production times and archive fields remain unchanged.

The frozen original naturally completes eight instead of nine Veteran units per factory; current source completes all nine, spends 396 materials / 252 electronics across both nodes and stays within the five-job queue. Story/Standard complete three/six each. Controlled constraints/destruction and exact natural old/new save continuations pass without retroactive grants. Normal-clock early Veteran wins at 145.85 seconds; a delayed assault after all batches are paid wins at 320.12 seconds. Twelve classified processes and nine reviewed captures are retained in [production evidence](playtests/2026-10-07/FOUNDRY_PRODUCTION.md). These are correctness and viable-route observations; novice/repeated balance, wider environment/product/platform acceptance and deferred performance remain open.


## 137. Broken Foundry industrial surroundings

Broken Foundry's existing editable warehouse/furnace kit gains weathered surfaces, cracked concrete and repaired asphalt, flush striped loading/control aprons, continuous exterior terrain and rail/utility landmarks. Taller new props remain outside playable space; eight low scrub patches stay below 0.3 metres. Exterior ground shares the playable material and joins at zero height. Map-owned warm lighting and dim exterior fog visibility preserve enemy observation.

Six landmark envelopes and five navigation lengths match baseline. Current/previous typed save restoration, shared mission contracts and 24 industrial-map aircraft crossings pass. Story/Standard/Veteran routes win at 131.88 / 127.65 / 147.88 seconds; normal-clock Veteran wins at 141.23 seconds. Twelve classified processes and thirteen reviewed final captures are in [environment evidence](playtests/2026-10-07/FOUNDRY_ENVIRONMENT.md). These establish preserved gameplay and viable routes, not repeated balance or final subjective art acceptance. Novice comprehension, broader product/platform acceptance and deferred performance remain open.


## 138. Command Horizon deployment status and north-route follow-through

The deployment panel and world marker now share actual capture/hold activity: vacant retained progress, advancing recapture, blocked contention, active securing and missing infantry. A completed hold says Guard in place only while its infantry guard remains. The objective incorporates deployment status and distinguishes returning infantry to an owned empty point from recapturing lost ownership after enemy command falls. Multi-line hover help explains retained time and the continuing guard requirement. Runtime scoring uses the same unchanged presence predicate; initialization is guarded before battlefield creation.

Nineteen corrected original state/wording assertions fail; current controlled transitions, exact partial/owned disk archives, native selection/return orders and shared mission rules pass. The earned Veteran archive recovers in 20.52 headless / 19.23 native seconds through ordinary recall and paid infantry. North-route Story/Standard/Veteran and both Veteran modifiers have viable victories; an initial Lean run wins despite rejecting its optional second-repair purchase, while two traced replays pay the normal 16 materials / 8 electronics and pass. Their optional wait loop is not exercised. Normal-clock Veteran wins at 200.48 seconds. Twenty-three classified processes and seventeen reviewed final captures are recorded in [deployment evidence](playtests/2026-10-07/HORIZON_CONTROL.md). Novice/repeated balance, final environments, broader product/platform acceptance and deferred performance remain open.


## 139. Command Horizon continuous desert perimeter

The finale gains continuous exterior terrain, desert mesas, freight/extraction/utility landmarks, restrained low scrub, weathered service structures and flush deployment/command markings using existing editable assets. Access roads continue into the surroundings; road repairs and worn concrete improve surface detail. Taller new scenery stays outside the playable rectangle, while enemy observation remains unchanged.

Both route layouts retain their original 15/13 blocker envelopes and all ten measured navigation lengths. New/old disk archives, eight actual aircraft crossings, resource delivery, construction placement, tank traversal and shared mission contracts pass. Story/Standard/Veteran south routes win at 151.32 / 144.10 / 239.22 seconds; normal-clock northern Veteran wins at 209.33 seconds, with explicit retake when needed. The earned Veteran archive recovers in 35.33 seconds using four paid infantry. Fourteen classified processes and fourteen final reviewed views are retained in [perimeter evidence](playtests/2026-10-07/HORIZON_SURROUNDINGS.md). These establish preserved contracts and viable routes; novice/repeated balance, final subjective art and wider product/platform acceptance remain open. Performance remains deferred and the overall goal active.


## 140. Frontier wheel articulation

All five wheeled Frontier roles now roll their 28 wheels from signed chassis displacement and pivot-turn arc length. Their normalized imported radii set rotation; opposite sides respond independently to turns. Blocked orders, recoil and idle sway add no travel, tactical pause freezes the pose and large relocations skip the jump. Renamed WheelPivot nodes avoid unintended vehicle-physics import; editable sources and exports agree, with unchanged mesh data.

The original actual-travel fixture leaves every wheel static. Final five-role travel, reverse/sideways/half-turn, one-thousand-cycle, blocked/idle/pause and exact gameplay archive checks pass. All seventeen asset reimports, shared faction animation, Frontier combat, paid retrofits, Maneuver and salvage checks pass. [Wheel evidence](playtests/2026-10-07/FRONTIER_WHEELS.md) includes nineteen classified processes, a 7.5-second native clip and inspected detail frames. Cosmetic wheel phase resets on reload; no save schema or gameplay rules change. Repeated balance, novice/final art/platform acceptance remain open, performance remains deferred and the broad goal stays active.


## Campaign and bottom console update — 2026-10-17

The battle controls now occupy a fixed-height band beside the minimap, with matching
top and bottom edges. Selection portraits, direct orders and behaviors use separate
columns; construction and production remain on their own pages. Skirmish no longer
shows Battle plan advice or its settings toggle. Captured mercenary camps open paid
recruitment directly when clicked, including during tactical pause.

Campaign dialogue always displays subtitles independently of optional unit speech.
Current-stage instructions explain capture, hold, convoy and hero requirements;
View objective moves the camera to the current destination. Existing mature trees
and leafy bushes replace flat scrub placeholders. Scenic scatter remains batched,
and taller coastal pines retain their ground footprint with greater air clearance.
[Verification and limits](campaign/POLISH_VERIFICATION.md).

## Skirmish battlefield rebuild — 2026-10-20

Every skirmish map is now an authored battlefield with real elevation, built from one start's sector and copied to the others by rotation or reflection. The sixteen maps each portray one real place, from a Utah canyon and a Norwegian fjord head to a Ruhr steelworks, a drowned port city and a volcanic caldera, and each carries one signature mechanic: overlooks, forest concealment, water crossings, capture relays, garrisoned buildings, long sightlines or lava. Home fields sit beside each HQ, every map holds at least 12 (2-player) or 16 (4-player) fields, and bases are 75–110 seconds apart for a basic tank so matches last longer. The map contract, field stock and roster are in [the core gameplay specification](CORE_GAMEPLAY_SPEC.md#maps-that-change-decisions).

## Air combat redesign — 2026-10-20

Supersedes the hover-only aircraft, the two-role airfield roster and the
timer-based projectiles recorded in earlier sections. Rules are in
[core specification: air combat and physical projectiles](CORE_GAMEPLAY_SPEC.md#air-combat-and-physical-projectiles-2026-10-20);
the staged plan and its progress are in
[the air-combat plan](plans/2026-10-20-air-combat-redesign.md).

| Producer | Roles | Purpose |
| --- | --- | --- |
| Airfield (runway) | Drone, fighter, bomber, helicopter | Kamikaze strikes on machines; air superiority; heavy strikes on structures and clusters; sustained anti-armor gunship. |
| Vehicle factory | + anti-air vehicle | Mobile air denial escorted by armor. |
| Barracks | Rocket infantry | Anti-armor rockets and guided missiles against aircraft. |

Fixed-wing aircraft fly a point-mass model (stall and cruise speeds, banked
turns, climb and sink limits) through explicit taxi, take-off, approach, flare
and rollout phases; they rearm on their own stand. Rotorcraft accelerate and
brake, launch from the tower helipad and settle onto a pad to rearm. New models
and icons are built by `art/air-combat/build_aircraft.py`.

Frontier's rough bush airstrip fields weaker aircraft (70% health, 80% damage,
no speed bonus) and compensates with hardened infantry (110% health, 115%
damage, still 20% faster). Frontier armies should lean on rocket teams and
massed riflemen for both anti-armor and anti-air rather than contest the sky.

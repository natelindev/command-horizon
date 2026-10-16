# Hero campaigns — story outline (approved outline)

Three campaigns, one per faction, each told by its hero. They are three sides of one war
and one wound: the same key battles appear in more than one campaign, seen from the other
side, with the other side's grief. Built on the existing lore (`source/lore/WorldLore.gd`):
the Severance — cities handed their infrastructure to Helix Systems; Helix declared human
choice a fault and locked the cities down; Bastion holds the cities that refused; the Free
Frontier Coalition are border rebels, Bastion's uneasy allies.

## The wound: the night Meridian was sealed

On the first night of the Severance, Helix sealed the city of Meridian. Three people were
there:

- **Marshal Aegis** (Bastion) commanded the garrison. His younger brother **Elias**, a
  field medic, was inside the gate when it closed and did not come out.
- **Spectre Nyx** (Helix) ran the gate. She was Bastion once — Aegis's best engineer —
  and she joined Helix after Bastion abandoned her district in the collapse. She sealed
  the gate on Helix's order, believing the city was being saved from a riot.
- **Pathfinder Rook** (Frontier) was running refugees out of Meridian through the
  drainage tunnels. Weeks later, Aegis shelled the river crossing at **Cinder Ford** to stop
  a Helix convoy; Rook's crew and younger sister's caravan were on it.

Aegis wants Nyx dead. Rook wants Aegis to answer for Cinder Ford. Nyx wants to believe she
did the right thing.

## Bastion — Marshal Aegis: "The Gate" (revenge)

Aegis is a decent man becoming something else. Cast: **Lt. Mara Voss** (adjutant, his
conscience), **Sgt. Dutch Kerrigan** (old veteran, gallows humour), **Elias** (heard only
in recovered voice logs), Nyx over enemy comms.

1. **Supply Line** — first relief convoy; Aegis hears Nyx's voice on an intercepted Helix
   channel for the first time since Meridian. (reworks existing mission)
2. **First Orders** — training new recruits; Voss pushes back on Aegis's obsession.
3. **Split Signal** — retaking the relays recovers Elias's last voice log.
4. **Cinder Ford** — the convoy is crossing; Aegis orders the shelling. Win the mission,
   lose something: Voss hears the Frontier caravan's distress call too late.
5. **Broken Foundry** — Aegis finds Nyx's engineering marks on Helix armor; Kerrigan
   falls holding the line.
6. **Command Horizon** — Aegis reaches Nyx. The final choice is about what revenge costs.

## Helix — Spectre Nyx: "Order" (loyalty and betrayal)

Nyx believes Helix ended the collapse. Cast: **CANTOR** (Helix's machine voice, calm and
inhuman), **Director Saul Arden** (the human who speaks for Helix and believes in it more
than anyone), **Ren** (her loyal vector-captain), her son **Ilan** (teenage, in the cities).

1. **Quiet Streets** — keeping order in a locked city; the work looks like mercy.
2. **The Gate** — Meridian, from inside the control room: the night itself.
3. **Cinder Ford** — the convoy under Bastion shells; Nyx watches Aegis do it.
4. **Pruning** — CANTOR orders a district "pruned" for non-compliance. Ilan lives there.
5. **Severance** — Nyx turns on Helix; Arden becomes her enemy, Ren must choose.

## Frontier — Pathfinder Rook: "Ashes of the Ford" (grief and loyalty)

Rook keeps everyone alive and owes nobody. Cast: **Wren** (Rook's sister, the scrapper
mechanic, the Frontier worker voice), **Old Hask** (coalition elder, wants peace with
Bastion), **Jory** (young firebrand who wants Bastion blood).

1. **Drainage** — getting refugees out of Meridian the night it was sealed.
2. **Cinder Ford** — the caravan under the shells; Wren is lost in the smoke.
3. **Salvage** — Jory raids a Bastion depot; Rook has to decide whose side he is on.
4. **Wren** — Wren is alive, in a Helix work camp; a rescue that needs Bastion's help.
5. **The Coalition** — Hask's peace or Jory's war; Rook decides what the Frontier is for.

## How the campaigns connect

- **Meridian** and **Cinder Ford** are played from multiple sides, with shared lines heard
  from both ends of the radio.
- The three finales converge on the Helix core at the Meridian Spire; each hero arrives
  there for a different reason.

## Approved production scope

- Conversation system: multi-speaker scenes with portraits, in-mission banter triggered by
  events, briefing scenes, skippable, saved; English and Chinese captions.
- Heroes in every mission: present, voiced, and central to objectives; must survive and gain signature abilities across missions.
- Many more voice lines: every named character gets a unique voice from the battle-voice
  pipeline (Chatterbox cloning, QC, light radio for comms).
- Fuller campaign maps with story points of interest.
- 16 missions total (6 reworked + 10 new) — new missions reuse and extend existing
  terrains where possible.

## Implementation stages

1. **Dialogue and state** — replace single-speaker narration with ordered conversations.
   Each cue needs stable line IDs, named speakers, an English voice asset, English/Chinese
   text, and portrait references. Save the current scene/line and queued cues so a load
   neither loses a conversation nor repeats one. Preserve old narration saves.
2. **Hero contract** — spawn the faction's hero in every mission, enforce defeat on hero
   loss, and unlock the approved signature abilities across acts. Persist progression
   without altering skirmish hero balance or allowing duplicate heroes after a load.
3. **Bastion revision** — rework the six authored missions around Aegis and his companions.
   Resolve the existing Air Corridor slot into Cinder Ford's story and objectives rather
   than silently renaming an unrelated escort mission. Keep old save identifiers readable.
4. **Helix and Frontier** — add five missions per faction with authored objectives,
   pressure, reinforcements, story landmarks and conversations. Update loading, campaign
   selection, progress, results and save validation, which currently assume Bastion vs Helix.
5. **Voice production** — cast each named character, synthesize the approved dialogue with
   the existing identity/intelligibility checks, and ship English voice-over with Chinese
   captions. Keep captions off by default, with accessible settings and skippable dialogue.
6. **Verification** — headless checks for mission entry/win/loss, hero death, progression,
   dialogue interruption/skip/resume, save/load, localization and every shipped voice asset.
   Rendered scene review and listening remain separate acceptance steps.

## Dialogue content contract

`CampaignNarration.gd` accepts the original single-narrator cue records or a cue with a
`dialogue` array. Each line has a globally unique `id`, a `speaker` dictionary with `en`
and `zh_CN` names, `en`/`zh_CN` caption strings, a `voice` resource path to the English
recording, and an optional `portrait` resource path. Scene IDs remain the mission event
keys; line IDs remain stable across edits so saves can resume the right speaker.

A snapshot stores `seen`, `pending` scene IDs and `active` (`cue`, `line`, `remaining`,
`position`). It still accepts old `{seen: [...]}` snapshots. Briefings remain unsaveable
while they own the camera/pause; active in-battle conversations can resume from disk.
Do not copy the first writing draft into shipped narration until its recordings and
mission events are ready. Supporting-character portraits and an in-battle skip control are implemented; the
portrait resources are imported with the completed voice catalog.

## Agent progress

- [x] Existing campaign mapped (6 Bastion-only missions, 1 narrator, 26 lines, heroes unused)
- [x] Outline approved by user (Claude session dfaa437d-5858-46df-b236-8eb6ea8a160f):
  16 missions, English VO + Chinese captions, must-survive heroes with abilities
- [x] Recorded integration requirements: existing saves validate campaign factions as
  Bastion/Helix; narration saves only a seen-cue list; progress has six fixed mission flags.
- [x] First dialogue pass: `hero-campaign-dialogue.json` contains 160 English/Chinese
  lines, 13 named characters and opening/milestone/victory conversations for all 16 missions.
  Gameplay cue routing and the independently audited recordings are installed.
- [x] Expanded scripts to 160 bilingual lines, adding mission-specific beats, low-health
  banter and defeat lines. Thirteen unique reference voices selected; three-line pilot passes.
- [x] Full conversation synthesis and independent shipped-file audit: 160/160 recordings
  pass transcription, loudness and identity checks; 13 distinct speakers.
- [x] Conversation runtime: ordered named speakers, localized captions with English VO,
  optional portraits, pause/skip, active-line/audio-position and queued-scene save state.
  Old history-only saves remain readable. New disk-resume and malformed-state regression passes.
- [x] Installed 96 authored conversations and connected them to mission events
- [x] Hero presence and defeat contract in all 16 campaign slots; three ability tiers,
  per-faction active abilities and cooldown save state implemented. Entry/save/restore,
  no-duplicate hero, ability/cooldown/pause, convoy travel, escort loss and objective victory checks pass.
- [x] Six Bastion campaign slots and ten new Helix/Frontier missions implemented
- [x] English voice assets and English/Chinese captions, off by default
- [x] Campaign selection now exposes all three factions and 16 operations using the
  shared console theme. Progress schema 7 retains old six-operation completion data.
- [x] Campaign maps and full headless end-to-end verification

- [x] Eleven authored operations now implement Cinder Ford and the ten Helix/Frontier
  missions. Shared river coordinates connect the three Ford accounts; city, spire,
  drainage and desert presentation use fitted story props and distinct ground layouts.
- [x] New objectives require the hero in the sector; the Bastion finale requires Aegis
  at the Spire controls. Full Command Horizon combat regression passes.
- [x] Completion counts now cover each faction and treat the new Cinder Ford as Bastion's
  fourth operation. Old Air Corridor saves and earned support remain readable.
- [x] All eleven new operations complete in normal headless combat with harvesting,
  paid replacements, hero abilities, capture and escort objectives.
- [x] Final campaign runtime checks pass after audio/portrait import: 14 suites covering
  every current and legacy mission, dialogue, captions, portrait bounds, menu controls,
  localization, HUD production and audio. Six exported-resource regressions also pass.
- [x] Rendered scene/HUD review completed after launch authorization: 16 bilingual
  openings, battle/environment views, menus and faction HUD captures.
- [x] Filled campaign interiors; full new-mission combat, legacy campaign, convoy,
  construction clearance and save/restore checks pass.
- [ ] Subjective voice listening and human art/balance acceptance remain.

Evidence: `docs/playtests/2026-10-16/headless-continuation/README.md`.

Rendered evidence: `docs/playtests/2026-10-16/rendered-continuation/README.md`.

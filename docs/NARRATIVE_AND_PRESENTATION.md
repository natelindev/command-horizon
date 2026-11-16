# Narrative, Audiovisual Polish & Presentation Specification

Status: **Active Design Direction**  
Date: **2026-11-01**  
Foundation: Synthesized from RTS genre benchmarks (**StarCraft II**, **Command & Conquer: Red Alert 2**, and **Age of Empires II**) for **Command Horizon**.  
Supersedes: Generic synthetic voice lines, text-only campaign briefings, non-interactive mission menus, and flat building destruction animations.

---

## 1. Executive Summary & Vision

A legendary real-time strategy game is remembered as much for its **soul, voice, and atmosphere** as its mechanical balance:
* Players still quote *StarCraft II's* `"Nuclear launch detected"` and *Red Alert 2's* `"Kirov reporting!"` decades after release.
* The between-mission storytelling aboard the *Hyperion* or through Red Alert's bombastic live-action briefings created deep emotional attachment to the factions.
* The visceral sound of a heavy siege tank shell detonating or Frank Klepacki’s pounding industrial soundtrack (*Hell March*) converted mundane clicking into thrilling spectacle.

This document establishes the plan to elevate **Command Horizon** from a functional technical engine demo into an immersive, charismatic RTS experience.

---

## 2. Benchmark Inspiration Matrix

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              BENCHMARK LESSONS MATRIX                                  │
├─────────────────┬────────────────────────────────────┬─────────────────────────────────┤
│ BENCHMARK GAME  │ CORE PRESENTATION MECHANICS        │ APPLICATION TO COMMAND HORIZON  │
├─────────────────┼────────────────────────────────────┼─────────────────────────────────┤
│ StarCraft II    │ • Interactive 3D Campaign Hubs     │ • Add Between-Mission Faction   │
│                 │   (Hyperion Bridge/Armory/Lab).    │   Command Hubs for campaign.    │
│                 │ • Unique mission setpiece gimmicks │ • Thematic mission setpieces    │
│                 │   (lava surges, train robberies).  │   with dynamic map events.      │
│                 │ • Kinetic destruction & ragdolls.  │ • Structural debris, persistent │
│                 │ • Dynamic orchestral soundtracks.  │   ruins, and cannon shockwaves. │
├─────────────────┼────────────────────────────────────┼─────────────────────────────────┤
│ Red Alert 2     │ • Charismatic FMV Storytelling.    │ • Stylized 2.5D Motion Comic    │
│                 │ • Legendary Unit Voice Barks       │   illustrated briefings.        │
│                 │   ("Kirov reporting!").            │ • Personality-filled voice      │
│                 │ • Frank Klepacki Industrial Metal  │   lines with humor & grit.      │
│                 │   soundtrack (adrenaline beats).   │ • Heavy driving guitar & synth  │
│                 │ • Distinct faction battle music.   │   combat soundtrack stems.      │
├─────────────────┼────────────────────────────────────┼─────────────────────────────────┤
│ Age of Empires  │ • Illustrated Storybook Briefings  │ • Illustrated narrative intros  │
│ II              │   with painted parchment art.      │   for every campaign operation. │
│                 │ • Period-authentic native voice    │ • Faction-authentic dialects    │
│                 │   responses and acoustic music.    │   and customized sound effects. │
│                 │ • Crumbling timber & stone decay.  │ • Multi-stage building collapse.│
└─────────────────┴────────────────────────────────────┴─────────────────────────────────┘
```

---

## 3. Narrative Architecture & Campaign Command Hubs

Currently, the campaign in [`source/match/campaign/`](../source/match/campaign/) transitions between operations via bare text menus, while story dialogue is delivered through fleeting in-game text prompts. We will introduce two major narrative layers:

```
                  ┌──────────────────────────────────────────────┐
                  │          CAMPAIGN NARRATIVE LOOP             │
                  └──────────────────────────────────────────────┘
                                         │
                                         ▼
                     [ 1. INTERACTIVE FACTION COMMAND HUB ]
                     • Inspect equipment & unlock doctrines
                     • Talk to sub-commanders & heroes
                     • Review intercepted intelligence & lore
                                         │
                                         ▼
                     [ 2. ILLUSTRATED BRIEFING CUTSCENE ]
                     • 2.5D Motion Comic parchment animation
                     • Dramatic voiceover & strategic map plan
                     • Secondary bonus objectives revealed
                                         │
                                         ▼
                     [ 3. IN-ENGINE GAMEPLAY OPERATION ]
                     • Distinct scripted narrative mechanics
                     • Dynamic tactical voice announcements
                                         │
                                         ▼
                     [ 4. DEBRIEFING & NARRATIVE ARCHIVE ]
```

### 3.1 The Between-Mission Faction Hubs
Between operations, the player is placed inside an interactive 3D command environment tailored to their chosen faction:

1. **Bastion Directorate — The Mobile War Train ("The Iron Bastion"):**
   * *Environment:* Heavy armored train car overlooking moving desert tracks.
   * *Interactive Stations:*
     * **Command Table:** Review deployment maps with Field Marshal Aegis.
     * **Motor Pool:** Inspect customized tank modifications and choose permanent doctrine unlocks (*Fortress vs. Blitz*).
     * **Radio Console:** Listen to intercepted enemy chatter and propaganda broadcasts.
2. **Helix Systems — The Orbital Nexus Core:**
   * *Environment:* Clean, levitating cybernetic sanctum bathed in cyan light with transparent holographic floorplates.
   * *Interactive Stations:*
     * **Harmonic Spire:** Calibrate cybernetic subroutines with Spectre Nyx.
     * **Nanite Foundry:** Inspect directed-energy weapon prototypes and shield resonance upgrades.
     * **Data Archive:** Decode fragmented corporate communications and Meridian historical records.
3. **Free Frontier Coalition — The Dustfall Outpost:**
   * *Environment:* A rugged canyon encampment around a crackling campfire, surrounded by modified technicals and rusted corrugated iron shelters.
   * *Interactive Stations:*
     * **The Workbench:** Review improvised weapon blueprints with Pathfinder Rook.
     * **Scrap Yard:** Inspect recovered war trophies and convert wrecks into cosmetic insignia.
     * **The Barricade:** Talk to recruited mercenary leaders (Dust Rangers, Iron Wardens).

### 3.2 Illustrated Briefing Cutscenes (Motion Comics)
Before deploying onto the map, missions present a 45–60 second illustrated motion comic cutscene:
* Stylized 2.5D layered artwork with parallax depth, ambient dust/smoke particles, and dramatic camera pans.
* Professional vocal narration delivering strategic context, accompanied by hand-drawn tactical arrows drawing troop movements across an illustrated theater map.

---

## 4. Voice Acting & Charismatic Unit Personality

Generic responses (`"Sir?"`, `"Yes, sir"`, `"Acknowledged"`) will be overhauled into memorable, faction-defining character barks. Every combat unit will possess a voice bank with five distinct interaction triggers:
1. **Selection:** Clicking on the unit.
2. **Move Order:** Issuing navigation coordinates.
3. **Attack Order:** Issuing a hostile engagement command.
4. **Low Health / Under Heavy Fire:** Triggered when hull drops below 25%.
5. **Kill Confirmation:** Triggered upon destroying an enemy target.

### 4.1 Faction Voice Profiles & Signature Lines

#### Bastion Directorate: Disciplined, Heavy, Industrial Diesel
* *Tone:* Deep, gruff, military radio discipline, rhythmic clanking engines in background.
* *Examples:*
  * **Siege Colossus:**
    * Select: *"Colossus primed. Give us a target."* / *"The ground shakes where we tread."*
    * Deploy: *"Hydraulics locked. Anchors set. Clear the breach!"*
    * Attack: *"Firing main kinetic battery!"* / *"High-explosive payload away!"*
    * Low HP: *"Armor breach on bulkhead four! Hold this position!"*
  * **Rifle Infantry:**
    * Select: *"First Battalion, standing by."* / *"Point the way, Commander."*
    * Attack: *"Engaging hostile infantry!"* / *"Pour it on 'em!"*
    * Grenade: *"Frag out! Clear the bunker!"*

#### Helix Systems: Cybernetic, Ethereal, Chillingly Efficient
* *Tone:* Layered synthesized vocal harmonics, vocoded resonance, analytical precision.
* *Examples:*
  * **Prism Skimmer:**
    * Select: *"Optics aligned. Energy nominal."* / *"Awaiting refraction coordinates."*
    * Attack: *"Focusing coherent beam."* / *"Resonance cascade initiated."*
    * Kill: *"Target atomized. Recalibrating."*
  * **Vector Operator:**
    * Select: *"Vector online. Synchronized."* / *"Neural link active."*
    * Move: *"Executing vector shift."* / *"Path calculated."*
    * Low HP: *"Shields collapsed! Hull integrity compromised!"*

#### Free Frontier Coalition: Scrappy, Defiant, Wasteland Swagger
* *Tone:* Raw, acoustic, overdriven comms, roaring V8 engine noise, cheeky humor.
* *Examples:*
  * **Outrider Technical:**
    * Select: *"Got gas in the tank and iron in the back!"* / *"What are we shooting at today?"*
    * Move: *"Floor it!"* / *"Dust in their eyes!"*
    * Attack: *"Light 'em up, boys!"* / *"Rattle their teeth!"*
  * **Battle Rig:**
    * Select: *"The iron flatbed's ready to roll!"* / *"Pile in, we're making noise!"*
    * Attack: *"Open fire from all mounts! Let 'em have it!"*
    * Kill: *"That one's going straight to the scrap yard!"*

---

## 5. Dynamic Soundtrack & Layered Combat Stems

Currently, [`source/audio/MusicDirector.gd`](../source/audio/MusicDirector.gd) uses a single stereo track with volume ducking. We will upgrade the music engine to **dynamic vertical layering (stems)**:

```
                                [ MUSIC DIRECTOR INTENSITY ENGINE ]
                                                │
                  ┌─────────────────────────────┼─────────────────────────────┐
                  │                             │                             │
          [ BASE AMBIENT STEM ]         [ PERCUSSION STEM ]           [ CLIMAX / COMBAT STEM ]
          • Plays during scouting       • Fades in when units move     • Full volume during active
            and base building.            near hostile territory.        firefights & artillery.
          • Atmospheric synths,         • Driving acoustic & synth     • Screaming lead guitars,
            subtle percussion.            rhythms.                       epic brass, heavy drop.
```

### 5.1 Faction Musical Identities
* **Bastion Directorate:** Industrial metal and pounding war anthems inspired by Frank Klepacki’s *Hell March*. Heavy distorted rhythm guitars, mechanical stamping beats, and dark orchestral brass.
* **Helix Systems:** Glitch-synth, cinematic electronic basslines, and hypnotic arpeggios inspired by *Blade Runner* and Daft Punk's *Tron: Legacy*. Pure synthesis, deep sub-bass drops, and cybernetic resonance.
* **Free Frontier Coalition:** High-octane desert rock inspired by *Mad Max: Fury Road*. Distorted slide guitar, blues harp, energetic garage drum kits, and rebellious acoustic swagger.

---

## 6. Visual Effects, Kinetic Impact & Environmental Destruction

### 6.1 Multi-Stage Structural Collapse
Buildings will no longer vanish into an instantaneous puff of smoke. Instead, destruction follows an authored three-stage sequence:
1. **Critical Failure (0% HP):** Structural supports buckle, glass and metal blast outwards, and fires ignite across the foundation.
2. **Collapse Physics (1.5s):** The roof and primary frame collapse downward under gravity, emitting dense rolling dust clouds and sparks.
3. **Persistent Ruins:** The structure leaves a smoking, scorched concrete ruin that provides light obstacle cover and can be salvaged for scrap or cleared by bulldozing vehicles.

### 6.2 Kinetic Ballistics & Battlefield Polish
* **Muzzle Shockwaves & Heat Distortion:** Heavy cannon fire emits a visible refraction shockwave ring and dust displacement on the ground around the tank.
* **Cannon Recoil & Chassis Rocking:** Firing artillery visibly pushes the tank chassis backwards on its suspension springs, recovering over $0.4\text{s}$.
* **Scorched Ground & Blast Marks:** Explosive shells and burning wreckage leave persistent scorched ground decals that slowly fade over 3 minutes.
* **Infantry Death Variety:** Infantry hit by small arms collapse with varied ragdoll poses; infantry hit by direct high-explosive artillery shells are thrown outward with physics impulse.

---

## 7. Multi-Stage Implementation Plan

### Stage 1 — Unit Voice Banks & Scripted Personality
* Create `source/match/audio/UnitVoiceBank.gd`: loads audio streams per unit role for Select, Move, Attack, Low HP, and Kill.
* Implement priority cooldown management to prevent auditory clutter during mass selections.
* Author and import high-quality voice packs for Bastion, Helix, and Frontier starter units.

### Stage 2 — Dynamic Music Stems & Intensity Director
* Upgrade `MusicDirector.gd` to manage 3 synchronized audio streams per faction (Ambient, Tension, Combat).
* Bind combat event signals (`weapon_fired`, `unit_damaged`, `artillery_impact`) to the intensity parameter with exponential decay.

### Stage 3 — Motion Comic Briefing System
* Create `source/match/campaign/CampaignBriefing.tscn`: 2.5D layered sprite viewer with camera panning and voiceover audio playback.
* Create narrative briefing scripts for all 16 campaign operations in `art/localization/briefings.tsv`.

### Stage 4 — Interactive Between-Mission Command Hubs
* Implement 3D hub scenes (`BastionWarTrain.tscn`, `HelixNexusCore.tscn`, `FrontierOutpost.tscn`).
* Connect interactive stations to campaign progress, doctrine selection, and unit inspection viewers.

### Stage 5 — Kinetic Combat Effects & Structural Collapse
* Implement multi-stage building collapse in `source/match/effects/CombatEffects.gd`.
* Add persistent scorched crater decals and cannon muzzle refraction shaders in `source/shaders/3d/`.
* Connect physics suspension recoil to `ChassisMotion.gd` on heavy weapon discharge.

### Stage 6 — Audio Accessibility, Subtitles & Quality Settings
* Update audio options in `source/main-menu/Settings.gd` with independent sliders for Master, Music, Sound FX, Voice Lines, and Ambient.
* Add full subtitle support for all voice lines and briefings, with customizable text scaling.
* Verify performance across 200-unit battles with profiling checks.

---

## Agent Progress

- **Benchmark Synthesis Completed**: Evaluated narrative presentation and audiovisual polish across StarCraft II (interactive 3D hubs, cinematic setpieces), Red Alert 2 (charismatic FMV storytelling, Frank Klepacki industrial metal, iconic unit quotes), and Age of Empires II (illustrated storybook briefings, authentic historical voice barks).
- **Core Diagnosis Established**: Identified existing limitations in Command Horizon (generic synthetic voices, text-only briefings, non-interactive mission menus, flat building destruction).
- **Comprehensive Specification Authored**: Created `docs/NARRATIVE_AND_PRESENTATION.md` detailing the interactive Between-Mission Command Hubs, 2.5D motion comic briefings, charismatic faction voice lines, multi-stem dynamic soundtrack, kinetic muzzle shockwaves, and multi-stage building collapse.

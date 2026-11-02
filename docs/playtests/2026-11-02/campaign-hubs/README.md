# Interactive campaign hubs and illustrated briefings

The three faction hubs contain real 3D stations, direct station controls, operation selection, permanent mutually exclusive doctrines, archives, and faction-specific interactions. The original sixteen campaign routes and completion data remain intact. Frontier insignia consume trophies recovered from actual campaign wrecks; returning a living hero with at least half hull records a commendation.

## Evidence

- [Hub contracts](hub-regression.log): all sixteen launch routes; three factions in English and Chinese; three direct stations; doctrines, trophies, archival and mercenary audio; station geometry and ambience.
- [Actual operation → debrief → hub loop](operation-loop.log): doctrine application, pause/skip restoration, exact-half-hull commendation, retained operation completion, archive preview and keyboard focus.
- [Actual wreck → trophy → cosmetic loop](wreck-trophy.log): atomic salvage, unique operation recovery and one-time insignia spending.
- [Rendered operation, skip and debrief checks](rendered-story.log): English/Chinese briefing and mouse skip, First Orders and Command Horizon debriefs.
- [Original campaign routes and saves](hero-campaign.log): all sixteen operation routes and existing campaign snapshot restoration.
- [Rendered review](rendered-preview.log): real renderer, three-dimensional station picking and twenty-four English/Chinese captures below, with actual 1280×720 station images and native text widths (including Chinese mercenary controls).
- [Voiced briefing pilot](briefing-pilot.log): Supply Line, four independently audited paragraphs, actual encoded 45.1386-second playback, subtitles, serialized line identity and fourth-paragraph disk restoration.

All sixteen new briefings are installed:64 independently audited recorded paragraphs, with actual encoded mission durations45.1200–45.1627seconds. [Native full-catalog runtime checks](briefing-complete-native.log) and [scripted checks](../briefing-audio/CampaignBriefingRegression-fallback.log) validate actual Ogg lengths, English/Chinese caption identity, every persisted paragraph and each operation's real last-paragraph disk restore/resume. The [complete encoded/cast audit and audition](../briefing-audio/README.md) retain recording identity, intelligibility and unchanged older conversation files. Original `.intro` cues remain available for existing saved identities.

The maximum-caption layout check covers all 16 missions × English/Chinese × four recorded paragraphs: 128 cases in a configured 1280×720 viewport, at 150% interface scale and subtitle size 26. The [retained failing run](briefing-layout-headless-before-fix.log) records 16 English objective/dialogue overlaps. Captions now retain their actual container width when refreshed, while compact objectives use the Label's real wrapped height and relayout when its minimum changes. The [clean headless rerun](briefing-layout-headless.log) passes all 128 paragraphs without errors; [measured geometry](briefing-layout-headless.json) records caption lines, panel bounds and objective heights. The [new actual-renderer review](../graphical-resume/README.md) also passes128paragraphs and retains all32actual1280×720English/Chinese captures at150% with subtitle size26. All mission titles, objectives, captions and Continue controls were visually reviewed without clipping or overlap. The source-tree run uses a retained docs-only fixture to correct physical canvas capture and an integer-truncated logical-width guard; both earlier fixture failures and the frozen canonical source are preserved.

Reproduce the headless scenario with Godot 4.7.2:

```sh
Godot --headless --path . --fixed-fps 60 --script tests/rendered/CampaignBriefingCatalogPreview.gd -- --layout-only
```

## Captures

| Faction | Command | Workshop | Archive | Illustrated briefing |
|---|---|---|---|---|
| Bastion EN | [command](bastion-en-station0.png) | [motor pool](bastion-en-station1.png) | [radio](bastion-en-station2.png) | [briefing](bastion-en-briefing.png) |
| Bastion 中文 | [指挥](bastion-zh_CN-station0.png) | [工坊](bastion-zh_CN-station1.png) | [档案](bastion-zh_CN-station2.png) | [简报](bastion-zh_CN-briefing.png) |
| Helix EN | [spire](helix-en-station0.png) | [foundry](helix-en-station1.png) | [archive](helix-en-station2.png) | [briefing](helix-en-briefing.png) |
| Helix 中文 | [指挥](helix-zh_CN-station0.png) | [工坊](helix-zh_CN-station1.png) | [档案](helix-zh_CN-station2.png) | [简报](helix-zh_CN-briefing.png) |
| Frontier EN | [workbench](frontier-en-station0.png) | [scrap yard](frontier-en-station1.png) | [barricade](frontier-en-station2.png) | [briefing](frontier-en-briefing.png) |
| Frontier 中文 | [指挥](frontier-zh_CN-station0.png) | [工坊](frontier-zh_CN-station1.png) | [档案](frontier-zh_CN-station2.png) | [简报](frontier-zh_CN-briefing.png) |

Six original painted raster layers are recorded in [the art manifest](../../../../art/campaign-hubs/ARTWORK.md). Each briefing combines a faction environment, a transparent commander, separate tactical overlays and animated particles. The original procedural hub sound sources are reproducible with `python3 art/audio/build_command_hub_audio.py`.

Commands use Godot 4.7.2. Runtime checks use `--fixed-fps 60`; rendered review runs `--script tests/rendered/CampaignHubPreview.gd` without `--headless`. Logs retained before the shared audio shutdown drain may contain teardown resource notices; current checks use `Globals.quit_game` to drain stopped audio before process exit.

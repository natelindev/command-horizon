# Music credits and licenses

The following recordings replace the former procedural placeholders. Filenames
remain stable for saved resource references; embedded titles identify the works.

| Game use / file | Recording and attribution | Source | License |
| --- | --- | --- | --- |
| Menu / after-the-silence.ogg | **Nebulous** — music by Joe Baxter-Webb (BossLevel VGM) | https://opengameart.org/content/nebulous | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| Bastion / hold-the-line.ogg | **Rock of War** — p0ss (polished remaster) | https://opengameart.org/content/rock-war-music-marching-industrial | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) |
| Helix / perfect-compliance.ogg | **Perpetual Tension** — Zander Noriega | https://opengameart.org/content/perpetual-tension | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| Frontier / no-shutdown-code.ogg | **The Recon Mission** — Zander Noriega | https://opengameart.org/content/the-recon-mission | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |

Changes: constant volume adjustment, 80 ms entrance and 500 ms exit fades,
and stereo 44.1 kHz Ogg Vorbis encoding. The complete arrangements are retained.
The Rock of War adaptation is distributed under CC BY-SA 3.0; the other
adaptations are distributed under CC BY 3.0. The same respective licenses apply
to our 30-second audition excerpts (excerpting, volume and fades, MP3 encoding).
No artist endorsement is implied. These are copyrighted, freely licensed works,
not public-domain recordings. Attribution and applicable license conditions must
be preserved when redistributing these recordings or adaptations.

License legal texts:
- https://creativecommons.org/licenses/by/3.0/legalcode
- https://creativecommons.org/licenses/by-sa/3.0/legalcode

Source download URLs and verified hashes: `art/audio/licensed-score.json`.

## Adaptive faction stems

`tools/audio/build_music_stems.py` derives each faction's `*-calm.ogg` and
`*-combat.ogg` from the corresponding recording listed above. Median-filter
harmonic/percussive separation retains 45% of transient percussion in the calm
bed; the combat layer restores the remaining 55%. Both preserve stereo timing,
sample count, tempo and original arrangement, and sum to the source before
Ogg encoding. They are adaptations under the same respective licenses and
attributions as their source recordings (CC BY-SA 3.0 for both Rock of War
stems; CC BY 3.0 for the other four stems). No additional recordings are used.

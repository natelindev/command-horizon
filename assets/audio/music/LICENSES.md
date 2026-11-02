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

`tools/audio/build_music_stems.py` derives each faction's `*-calm.ogg`,
`*-tension.ogg` and `*-combat.ogg` from the corresponding recording listed above.
Median-filter harmonic/percussive separation and complementary smooth frequency
masks produce an atmospheric bed, a rhythm/transient layer and an upper harmonic
lead layer. The complementary base stems reconstruct the complete source arrangement.
Original faction-specific instrument parts are then added on the measured beat
grid before Ogg encoding. All three retain stereo timing and exact sample counts. They are adaptations under
the same respective licenses and attributions as their source recordings
(CC BY-SA 3.0 for all three Rock of War stems; CC BY 3.0 for the other six stems).
The added Bastion low orchestral brass uses recorded F horn and tenor trombone
from [VSCO 2 Community Edition](https://github.com/sgossner/VSCO-2-CE), recorded
by Sam Gossner and Simon Dalzell, with sample cutting by Elan Hickler/Soundemote.
Frontier uses recorded Hohner Special 20 diatonic harmonica from the
[Versilian Community Sample Library](https://github.com/sgossner/VCSL) by
Versilian Studios LLC, plus recorded Gretsch hollowbody electric guitar from
[Black And Green Guitars](https://github.com/sfzinstruments/karoryfer.black-and-green-guitars)
by Karoryfer Lecolds, recorded by Brian Wood. The guitar notes have continuous
pitch-slide articulation and saturation; harmonica phrases use note bends.
All these instrument samples carry CC0 1.0. The Helix arpeggio and sine-sub parts
are original deterministic synthesis, with no instrument recordings.

Pinned source commits, download URLs, per-file hashes and pitch mapping are in
`art/audio/faction-instruments.json`; unmodified CC0 texts are retained under
`art/audio/licenses/`. Beat/local-chord analysis is in
`art/audio/faction-arrangements.json`, and generated per-note timing/instrument
manifests accompany the audition artifacts. Only the three existing faction
stems are used at runtime; no extra streams or sample downloads are required.
The combined stem adaptations keep the respective source-work licenses above.

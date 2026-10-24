# Neutral-symbol review

The 2026-10-24 review replaced the audited cross/religious-looking emblems with
wrenches, bars, chevrons, open target brackets, service gears and a rectangular
communications panel. The UI repair marker is S in English and 修 in Chinese;
both map legends match. Ordinary structural braces, arithmetic and names were
outside this change.

| Review | Coverage | Result |
| --- | --- | --- |
| UI vectors and runtime cursors | All 45 UI SVGs; native 16 px command glyphs and 40 px cursors | Visually reviewed; glyphs remain legible |
| Native UI | 14 captures at exact 1280×720/150%: all three factions' orders/research in English and Chinese, plus both map legends | Zero failures or diagnostics |
| Weathering and materials | 12 native Bastion weathering captures and RichTexturesRegression | Zero failures or diagnostics |
| Model emblems | Nine detail/front/rear views of the active HQ, repair depot and repair robot | Zero failures or diagnostics; no cross-shaped decorative symbols in the inspected views |
| Import and localization | Godot 4.7.2 import; S/修 and legend regression; 2,248-entry catalog | Clean import and zero regression failures |

The [UI summary](ui-review.json) records the replacement motifs and capture
matrix. The [model review](../model-symbol-review.json) records inspected model
hashes and findings. Retained logs are [native UI](native-ui.log),
[localization](localization.log), [import](import.log),
[weathering](weathering.log), [material regression](rich-textures.log) and
[model views](model-views.log).

PNG evidence remains local under `art/symbol-review/` and `art/weathering/`.
[Capture hashes](capture-hashes.sha256) retain the repository-relative paths and
SHA-256 values for 14 UI views, four runtime glyph/cursor exports, two contact
sheets, 12 weathering views and nine focused model views. [SHA256SUMS](SHA256SUMS)
covers the files retained in this folder. These focused checks do not replace
the pending final export and its acceptance checks.

# Canonical briefing capture fixture correction

After the complete frozen package run passed, only `tests/rendered/CampaignBriefingCatalogPreview.gd` changed. The fixture now uses production canvas scaling, compares logical viewport size without integer truncation, and settles the native window at1280×720 for500ms before each rendered mission, bounded by a5s deadline. Headless cases skip native-window settling. Runtime UI, campaign content, native code and simulation behavior were not edited.

The [canonical headless matrix](headless-matrix.log) exits0 with **1,152 paragraphs and zero failures**:16missions×2languages×4paragraphs×3interface scales×3subtitle sizes. [Recorded geometry](headless-matrix/layouts-headless.json) contains128cases for each of the nine scale/font combinations, with the correct floating logical viewport and separate objective/dialogue bounds.

The [canonical renderer run](rendered.log) exits0 with **128 paragraphs and zero failures**, saving all **32 actual1280×720 images** in [the rendered directory](rendered/). It preserves every physical-raster, caption/title/objective and Continue-bound check. This is the canonical fixture itself, without the earlier derived guard. It uses150% interface scale, subtitle size26 and logical853.333×480. The earlier [derived full-catalog visual review](../README.md) and both failed renderer runs remain unchanged.

The graphical run temporarily stopped producing captures after23images; its [raw one-second process sample](render-hang-sample.txt) retains substantial Metal drawable waits plus engine text/render work. The run subsequently completed all checks. A bounded [focus activation attempt](focus-recovery.log) raced completion and opened a separate plain Godot process; that unintended process was explicitly terminated. No script/layout error was logged, and the pause's cause was not established. All owned engines and the sampler exited before root's isolated performance run. No additional engine runs or heavy scans followed that handoff.

The [original fixture bytes](fixture-before.gd.txt), [final fixture bytes](fixture-after.gd.txt), [exact patch](fixture.patch), [runtime source hashes before the change](runtime-before.json), [before provenance](provenance-before.json) and [final provenance](provenance-final.json) are retained. This was an officialGodot4.7.2editor/source-tree check; no PCK was used. The frozen139-suite package results remain tied to their original inputs; this test-only correction received its own complete matrix/render checks.

Reproduce:

```sh
Godot --headless --path . --fixed-fps 60 \
  --script res://tests/rendered/CampaignBriefingCatalogPreview.gd -- \
  --layout-only --layout-matrix --output-dir=/absolute/writable/headless-directory
Godot --path . --fixed-fps 60 \
  --script res://tests/rendered/CampaignBriefingCatalogPreview.gd -- \
  --output-dir=/absolute/writable/render-directory
```

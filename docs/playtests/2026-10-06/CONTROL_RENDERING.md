# Restored control rendering audit — 2026-10-06

The clipping diagnosis in the previous [regional report](REGIONAL_RECOVERY.md) was incorrect. No shipping layout change is warranted by those images.

The original `regional-recovery/width-{0,2}-withdrawal.png` panel regions are **pixel-identical** to both an untouched replay and a diagnostic replay. Comparison uses decoded RGB pixels in `(781, 84)–(1251, 703)`, covering the scroll content. [pixel-comparison.json](control-rendering/pixel-comparison.json) records exact inputs, regions and empty difference bounds. The original Industrial Attack move text occupies X=1125–1220 inside its X=1097–1251 button, matching the correct render. This directly supersedes the earlier screenshot interpretation; logical bounds alone were not the deciding evidence.

The diagnostic additionally activates Attack move at its reported center through GUI mouse events and checks that the command is armed, then cancels without issuing an order. Four withdrawal/recovered states pass. It records control sizes/transforms, then separately forces redraw; the first baseline image is taken before either input or forced redraw. The untouched replay adds neither operation. Both complete with zero failures and no script/parse errors; physical native input remains outside this audit.

Sources and evidence: [diagnostic log](control-rendering/probe.log), [untouched replay](control-rendering/baseline.log), [original Industrial panel](regional-recovery/width-2-withdrawal.png), [untouched replay panel](control-rendering/baseline-2-withdrawal.png), [diagnostic panel before input/redraw](control-rendering/probe-2-withdrawal.png). Existing renderer/resource shutdown diagnostics remain.

This resolves the reported clipping example. It does not establish every viewport, UI state or platform. The guard investigation continues separately in [guard endpoint arrival](GUARD_ENDPOINT.md).

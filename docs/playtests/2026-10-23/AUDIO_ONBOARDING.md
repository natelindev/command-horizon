# Audio and onboarding evidence — 2026-10-24

Native Godot 4.7.2 checks passed on macOS / Apple M1 Pro. These are an expert UI workflow review, signal measurements, and automated speech recognition. Human listening quality and five real novice playtests remain unverified. The available external resource is a Windows host for platform testing; no novice participants or physical input-to-photon measurement were available.

This report records focused 2026-10-24 checks. A macOS export subsequently passed all 73 registered suites; its [package record](../2026-10-24/final-macos-packaged.json) tracks the later selective refresh for two locale-dependent test fixtures. Windows verification is separate and remains in progress.

## Audio

[`IntegratedAudioPreview.gd`](../../../tests/rendered/IntegratedAudioPreview.gd) recorded **15 WAVs**: Master, Music, Voice, Effects, and Ambience for each faction, through CoreAudio. Each 26-second scenario includes calm score, routine fire, heavy fire, a base warning at 12 s, vehicle destruction at 12.5 s, and quiet recovery. Volumes were Master 0.8, Music 0.5, Voice 0.8, Effects 0.75, and Ambience 0.55. This was moderate observed combat, not maximum-population audio stress.

All 15 recordings contain **zero clipped PCM samples**. Master peaks, before its 0.8 gain:

| Faction | Peak dBFS |
| --- | ---: |
| Bastion | -8.81 |
| Helix | -9.42 |
| Frontier | -8.03 |

Unprompted local Whisper `medium.en` (package 20250625, CPU FP32, temperature 0, English, no prior-text conditioning) transcribed all **three mixed warning excerpts and three isolated Voice controls** as “Your base is under attack.” Each had **0/5 word errors**. Expected words were used only for comparison after inference. Automatic recognition does not establish human comprehension or subjective sound quality.

- [Native capture timeline and bus files](../2026-10-24/audio-review/runtime-mixes.json), [clean capture log](../2026-10-24/audio-review/native-capture.log).
- [Per-file and segment signal measurements](../2026-10-24/audio-review/signal-analysis.json).
- [Six exact transcripts, excerpt filenames, and SHA-256 hashes](../2026-10-24/audio-review/speech-intelligibility.json); [SHA-256 manifest for all 21 WAVs](../2026-10-24/audio-review/SHA256SUMS).
- [Concise results and limitations](../2026-10-24/audio-review/review-summary.json). Recorders capture after bus effects and before bus volume; sequential recorder stopping adds up to 0.43 s of trailing quiet to later buses. Excerpts use the common 11.5–16 s interval.

## Onboarding

The actual menu/control flow reproduced two issues: optional advice pushed the required build instruction below the scroll fold, and losing every tank left “Find tank” guidance with a barracks replacement notice. The fixes put required instructions first, reset scrolling on lesson changes, and direct tank recovery through a completed vehicle factory. Missing factories, unfinished foundations, and missing engineers now lead to rebuilding, resuming construction, or HQ training. Shortcuts skip dead/deleting units and unfinished factories.

The revised [`OnboardingFlowPreview.gd`](../../../tests/rendered/OnboardingFlowPreview.gd) passed with **0 failures and 11 captures**. Normal pointer input covered Campaign → First Orders, briefing, engineer selection, invalid lab placement, cancellation without resource loss, valid placement/construction, Guard destination, tactical pause, infantry selection, and factory selection after induced armor loss. Only idle construction waiting used 4× time; UI gestures used 1×. English and Chinese 150% controls were visually reviewed.

- [Before captures](../2026-10-24/onboarding-review/before/), [required instruction visible](../2026-10-24/onboarding-review/04-engineer-build-controls.png), [factory recovery shortcut](../2026-10-24/onboarding-review/10-missing-armor-shortcut.png), [Chinese 150% capture](../2026-10-24/onboarding-review/11-chinese-large-ui-recovery.png).
- [Native flow log](../2026-10-24/onboarding-review/native-flow.log), [OpeningGuidance regression](../2026-10-24/onboarding-review/opening-guidance-regression.log), [Localization regression](../2026-10-24/onboarding-review/localization-regression.log): all 0 failures with clean exits.
- [Capture dimensions and detailed scope](../2026-10-24/onboarding-review/review-summary.json): menu 1280×720, mission 1920×1080, Chinese 150% 3456×2168. This run does not establish a combined 720p/150% layout result. The new Chinese factory wording was subsequently normalized to the existing “车辆工厂” terminology with identical character count and the catalog regenerated.

A separate [`StrategicPolishPreview.gd`](../../../tests/rendered/StrategicPolishPreview.gd) run then passed with **0 failures and 8 captures**, including six lesson views at **1280×720 and 150% interface scale**, with exact pixel size asserted. All required economy, Guard, and relay-capture instructions are visible above the fold in English and Chinese; lesson controls do not overlap the minimap or unit controls. [Clean log](../2026-10-24/onboarding-review/minimum-viewport-preview.log), [six minimum-viewport captures](../2026-10-24/onboarding-review/minimum-viewport/).

The same review found tiny world-space placement feedback. It now uses a compact localized screen-space panel that follows the blueprint and respects interface scale. [`PlacementFeedbackRegression.gd`](../../../tests/headless/PlacementFeedbackRegression.gd) passed with **0 failures**, covering viewport clamping, readable type, Chinese translation, invalid-placement resource preservation, and cancellation. The native preview passed with **0 failures and 3 visually reviewed captures** at **1920×1080 / 100% English** and **1280×720 / 150% English and Chinese**. The panel stays readable and compact beside the blueprint. [Captures and clean logs](../2026-10-24/onboarding-review/placement/).

The 11-image flow review predates this placement fix; its invalid-placement image is historical. The later three placement captures show the final panel. The catalog was regenerated from TSV sources and now contains **2,248 entries**. The earlier general localization log predates the final placement strings; the final placement regression verifies the imported Chinese feedback. PlacementFeedbackRegression is included in the 73-suite exported-package gate.

The induced casualty state tests recovery controls, not a novice's ability to discover them. Human novice comprehension, subjective audio review, and physical latency acceptance remain open.

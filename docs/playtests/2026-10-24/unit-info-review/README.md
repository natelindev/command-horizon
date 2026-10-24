# Unit information text review

The user-reported repeated **Precision** captions over Helix units are hidden during ordinary play. The existing **F1** diagnostic overlay enables unit-attached status text, including weapon mode, preparation, signature, action, garrison and commander captions. It starts off for every match and works while paused. Enabling it refreshes the current state; hidden captions skip text formatting.

Health bars, rank chevrons, selection indicators, weapon effects, command controls and fixed map-site/objective labels remain. The scene reproduces a selected four-Lancer group at **Water Stop Camp**, with additional caption families included for the diagnostic comparison.

- English: [ordinary play](ordinary-en.png), [F1 diagnostics](diagnostics-en.png), [ordinary play restored](ordinary-restored-en.png).
- Chinese: [ordinary play](ordinary-zh_CN.png), [F1 diagnostics](diagnostics-zh_CN.png), [ordinary play restored](ordinary-restored-zh_CN.png).

All six native Metal captures were visually inspected at exactly 1280×720 with 150% interface scale. `UnitInfoTextRegression` and `UnitInfoTextPreview` report zero failures and exit cleanly. The regression covers hidden-state changes, F1 while paused, current-state refresh, new units, repeated toggling, inherited visibility, default-off in a new match and preservation of essential gameplay indicators. It is included in the 73-suite macOS release gate; that final exported-package gate is tracked separately.

`WeaponModeRegression` and `PreparationRegression` also report zero failures. Their existing direct-quit paths retain ObjectDB/resource teardown diagnostics, recorded in the logs rather than treated as clean shutdowns. The native launch log contains a macOS sandbox-extension diagnostic before successful Metal initialization; no Godot script or rendering errors follow.

The preparation test previously expected restored text in ordinary mode and sampled an Interception shot while 300 ms of the shared reload remained. The corrected test enables diagnostics for the exact restored-caption assertion, preserves the real reload deadline, rejects any early shot or Precision charge, requires a shot within two frames of readiness, and verifies later aircraft damage. No weapon behavior changed. The [diagnostic log](preparation-cooldown-diagnosis.log) preserves the observed state behind that fixture correction.

The [machine-readable record](review-summary.json), regression/native/gameplay logs and `SHA256SUMS` are retained here. `gdformat --check`, `gdlint` and `git diff --check` pass. This is a focused source-tree verification, not a substitute for the final exported-package gate.

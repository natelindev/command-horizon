# Current frozen headless qualification

The refreshed candidate5 passes **all162workflow rows** with `headless_checks_passed`. Every engine launch uses headless mode. This includes the later command-local geometry/action lookup changes and the six earlier CPU fact-reuse changes; no Movement-component cache remains.

| Gate | Result |
| --- | --- |
| Packaged standalone scripts |140/140, including Ownership, PassengerHud, MobileGarrison and OrderActivation |
| Source texture contract |RichTexturesRegression passes before export, preserving strict authoring-import assertions |
| Archived saves/checksums |811/389, zero failures |
| Briefing layout matrix |1,152 cases, zero failures |
| Actual ENet/network/replay workflow |14/14, with five recordings retained |
| Ordinary/numerical-solver release-template startup |Both pass with normal cleanup |
| CPU-clock and dummy-resource lifetime |Pass; six scene instances freed |

The [original report](report.json) is byte-identical to the live completed report, SHA256 `bf57694b5fdea46610620047300a5b5e517a38a1619ee843294adee61fe9b47c`. The [artifact verification](artifact-verification.json) confirms all recorded/installed/ZIP executable, PCK, signed native helper and descriptor hashes match. The6621-file input digest is `bba072d8117dc096851e412e25fd10d479c3102730fccf6f587c9b280ad8bd19`; completion has zero source/test/tool/native/asset differences. Candidate4's report and ZIP remain unchanged.

The review ZIP is `build/headless-review/macos/20261102T071352Z-45037/headless-review-artifacts/Open_RTS_macOS.zip`, SHA256 `d569e86e90dd471099324be30116ef406b2a2121ad7e84f3f908ce717dc3ce58`. All numbered logs, layout geometry, peer results/logs and replay files are retained here. Independent root checks confirm packaged-manifest membership, source-vs-pack texture separation, all five replay hashes and archive-entry identities.

Scope is **macOS ARM64 headless execution**. The universal x86_64 slice was built and structurally checked, without x86 execution; Windows/Linux execution is not claimed. Normal/graphical launches remain prohibited. Current graphical appearance and strict16.6ms frame qualification are deferred; the latest earlier authorized timing still fails its32.736ms maximum. Original3Dstyle/defaults are preserved according to the [static style audit](../../original-style-audit.md). No engine/compiler/runner remains active.

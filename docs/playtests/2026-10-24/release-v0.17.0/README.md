# v0.17.0 release verification

The initial native workflow, [40086867951](https://github.com/natelindev/copperfin/actions/runs/40086867951), exported all three desktop packages. Linux startup and all 78 packaged suites passed, then artifact upload failed because GitHub Actions storage quota was exhausted. Windows exited with access violation 0xC0000005 after InfantryDeathGroundRegression printed 72 passing scenarios. macOS later exposed the existing intermittent mixed-army retreat stall (19/20 arrivals). The native exit crash remains unresolved; neither failure is treated as a passing job.

The fresh diagnostic workflow, [40088121317](https://github.com/natelindev/copperfin/actions/runs/40088121317), did not start any build: GitHub reports an Actions budget is preventing further use. See [actions-budget-block.json](actions-budget-block.json). The user was asked to enable the allowance or choose a source-only release. No budget settings or existing build artifacts were changed.

Six local source runs passed, while exported-pack trial 6 reproduced a worker stalled on a path corner covered by a settled tank. [mixed-retreat-stall.json](mixed-retreat-stall.json) preserves the complete format-19 failure archive and its original IDs. Failure-only instrumentation prints the path, recovery state and nearby bodies after the workload has already failed.

The minimized recorded layout in GroundCrowdRecoveryRegression fails before the correction and passes after it. Ground recovery now rebuilds the path at the end of its detour, instead of returning to an unreachable old corner. Speed, collision and arrival bounds are unchanged. Compare [before](corner-before.log.txt) and [after](corner-after.log.txt).

All nine follow-up source checks pass (including two further crowd-recovery runs, ordinary navigation, mixed armies, vehicle motion, contact approach, save navigation timing, save restoration and all authored passages). See [recovery-results.json](recovery-results.json). The focused layout has passed three times after the fix. The exported pack also passes the focused crowd test and six consecutive mixed-army runs; see [recovery-pack-results.json](recovery-pack-results.json). Tests use isolated player data, and retained shutdown resource warnings are not described as clean shutdowns.

Native verification of the final correction and publication remain blocked by GitHub Actions allowance/storage. This evidence does not establish rendered Windows or overall four-player performance acceptance.

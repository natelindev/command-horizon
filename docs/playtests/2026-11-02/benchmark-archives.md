# Benchmark archive conversion — 2026-11-02

All **811** repository battle archives now use `MatchSnapshot.VERSION = 22`. The runtime accepts only the current version; conversion exists solely in the repository maintenance tool, [convert_benchmark_archives.gd](../../../tools/saves/convert_benchmark_archives.gd).

## Conversion rules

- Preserve the exact ordered unit and resource IDs. Keep existing unit positions, rotations, resource records, ownership and mission references.
- Preserve hull health percentages while applying the authored faction roster. The old calculation uses the historical unit HP values, rounded Helix `0.8` hull and Frontier infantry `1.1` / aircraft `0.7` / other mobile `0.85` factors, and completed armor ranks. The old worker base was **35 HP**, verified from the prior constants. The new calculation uses `FactionCatalog.base_health()` and the current technology HP factor.
- Add innate Helix shields. Existing shield charge percentages and damage ages survive; units without former shields receive their new full envelope. Retained `plasma_shields` research becomes Harmonic Shield Resonators, with its specified capacity increase.
- Retire unavailable mirrored/faction-incompatible research. Refund completed upgrades at their full authored price and active/queued projects at their saved paid price. Remove retained projects whose new prerequisites are absent and refund them. The corpus receives an aggregate **4,769 materials and 3,018 electronics**; no replacement upgrades are invented.
- Add default logistics, macro-effect, formation, ion-stall, refinery, Nexus energy, AI shield-withdrawal, optical-cloak and Prism-focus state. Helix headquarters begin with 50 energy; other headquarters have no Nexus energy. Mobile formations default to Line with cohesion disabled. Aircraft-contract cooldown defaults to zero and mercenary-sortie state to an empty dictionary.
- Remove obsolete Helix Advanced Tank deployment state; Bastion Siege Colossi receive their two-second deployment state. Reconcile tactical abilities from the current authoritative definitions while preserving surviving ability state.
- Keep already-paid production jobs as singleton batches. Cancel/refund excluded Frontier aircraft jobs while retaining existing aircraft, structures and valid paid Drone jobs.
- Add harvesting phase timers and the new optional moving-fire child recursively. Clamp active economic-site capture progress below the new 12-second capture threshold.
- Preserve existing POI indices, add radar fields, and append authored economic facilities with neutral default state. Maps whose old mission state omitted POIs receive the current authored records.

The converter validates each complete result before an atomic `SaveFile` write and refreshes recorded `SHA256SUMS` entries. Its default mode is read-only. Current v22 archives also receive the two required aircraft-contract defaults when absent; already reconciled v22 files are validated without rewriting their snapshots. A write pass can repair an interrupted checksum update.

## Verification

Godot 4.7.2, macOS:

```sh
Godot --headless --no-header --path . --script tools/saves/convert_benchmark_archives.gd
Godot --headless --no-header --path . --script tools/saves/convert_benchmark_archives.gd -- --write
Godot --headless --no-header --path . --script tests/headless/ArchivedSnapshotRegression.gd
```

- Read-only preflight: **811 converted candidates, zero validation failures**.
- Write pass: **811 converted, zero errors**.
- Archive regression: **811 checked, 389 recorded checksums, zero failures**.
- Independent comparison with the original v21 backup: all **29,764 unit IDs**, **13,040 resource IDs**, unit transforms and complete resource records remain unchanged. All 29,764 hull percentages are preserved; maximum floating-point ratio difference is `2.220446049250313e-16`.
- Second write pass: **811 current, zero converted, zero additional refunds**. SHA-256 comparison confirms **zero archive files changed**.
- Final aircraft-contract schema reconciliation: **811 current archives updated with zero cooldown/empty-sortie defaults, zero errors, zero refunds**. The archive regression again passed **811 archives and 389 checksums**; the next write pass reported **zero rewritten files**.

The command output and independent comparison summaries are retained in [benchmark-archives/](benchmark-archives/). The temporary original-file backup is outside the repository at `/tmp/benchmark-archives-v21-backup.tar.gz`.

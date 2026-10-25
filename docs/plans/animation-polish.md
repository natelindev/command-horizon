# Animation polish

## Stage 1 — Mechanical motion
Audit existing animation contracts; add distance-driven track articulation, deliberate recoil recovery, stronger braking response and inertial secondary motion. Keep authoritative movement, attack cadence and save data unchanged. Preserve GPU batching and cosmetic culling.

## Stage 2 — Commands and combat feedback
Animate accepted terrain-projected orders and selection entrances; preserve existing damage catch-up bars. Add restrained weapon thermal feedback and ground blast interaction through bounded cosmetic systems, with reduced-flash support.

## Stage 3 — Production and destruction
Enhance factory preparation, venting and departure acceleration. Separate collapse from delayed ammunition cook-off. Retain existing faction construction rigs, infantry collapse variants and water interactions, extending only genuine gaps.

## Stage 4 — Verification
Add focused motion regressions, exercise native and GPU-batched presentation, and review rendered captures. Run relevant existing gameplay, construction, production and effects checks. Record evidence and limitations.

## Agent progress

- Audit: the suggested baseline predates several existing features. Damage catch-up, faction construction machinery, weapon charge, terrain-projected command rings, water interaction, infantry collapse and secondary wreck explosions already exist. Extend these implementations rather than duplicate them.
- Track geometry is consolidated into hull meshes by the asset generators; articulation must be authored before export and tested with the batch renderer.
- Stage 1 complete: rebuilt Bastion track rigs and Bastion/Frontier antenna pivots from their generators. Added distance-driven tread shoes, differential turning, brake response, inertial antennas and kick/hold/hydraulic barrel return. Rigid hulls remain batched; two deforming belt meshes per vehicle use the ordinary renderer.
- Stage 2 complete: selection entrances, accepted-order ripples/heading arrows/attack corners, route pulses, bounded barrel heat and casing ejection, surface-dependent dust/clods, and muzzle/downwash foliage response. Existing damage catch-up bars remain in use. Pause and reduced-flash behavior are covered.
- Stage 3 complete: factory preparation beacons/venting, eased departure with exhaust and continuous track phase, welding light, uneven wreck collapse, delayed cook-off, moving wreck scars and explosive infantry weapon separation. Existing faction construction and water effects remain in use.
- Stage 4 complete: focused regressions, ordinary and GPU-batched rendered animation checks, all-faction HUD review, Bastion/Frontier model review and snow/forest/desert terrain captures passed. Visual testing found and fixed detached tracks under decoupled poses; the rendered regression now checks this alignment.
- Scope notes: thermal feedback is a bounded emissive muzzle sleeve; screen-space heat shimmer and new rocket-launcher hatch rigs are not included. No new gameplay attack delay was introduced. Performance budgets are bounded, but this pass does not establish Windows performance or maximum-army frame rates.
- Verification and reproduction: [animation polish report](../playtests/2026-10-25/animation-polish/verification.md). Existing shutdown audio-resource warnings and seven baseline lint findings remain; no new lint findings were introduced.

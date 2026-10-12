# Electronics economy balance

Make mixed armies affordable while keeping electronics finite, expansion worthwhile, and faction cost differences meaningful.

1. Inspect supply, collection, faction prices, AI allocation, and archive contracts.
2. Increase the four main skirmish maps' electronics stock from 240/400 to 360/600 per home/expansion deposit. Reduce collection time from 2 to 1.5 seconds and use actual collection times in AI demand allocation. Reduce skirmish repair/walker/heavy-armor/gunship electronics costs by roughly one quarter without changing materials, combat stats, or technology requirements.
3. Rebalance power supply from HQ 20 / plant 25 to HQ 8 / plant 12 so growing bases require repeated investment. Keep descriptions/translations accurate and test low-power recovery and AI construction.
4. Verify actual gathering, affordable mixed production, payment/refunds, map parity, and save/load; run relevant existing economy regressions.

## Agent progress

- Inspection complete: four main maps share 1,280 E against 3,000 M; collection takes twice as long; Helix specialist costs reach 30 E. Existing queues store their paid costs, allowing previous prices to survive load/refund.
- Implementation complete. Unrelated working-tree changes preserved.

- User added power scarcity: confirmed HQ plus one plant provided 45 against a full base demand of 29. Electronics supply/queue checks pass; older AI budget fixtures omitted recently added infantry demand and are being corrected to isolate their intended scenario.

- Final electronics costs (repair / walker / heavy armor / gunship): Bastion 6/12/18/14, Helix 8/14/22/18, Frontier 4/8/14/12. Mixed groups now cost 50/62/38 E instead of 68/86/52 E.
- Verified all four main maps at 3,000 M / 1,920 E, repeated deliveries from both starts, finite-stock conservation, all three factions' paid mixed queues and actual completed units, save/load refunds including pre-rebalance paid prices.
- Power checks cover opening investment, two-plant full bases, third-plant production expansion, unfinished/lost plants, and AI power planning before expansion. The fully equipped Bastion showcase gets a second starting generator.
- SkirmishBudgetRegression and SkirmishLaborRegression pass after updating fixtures for the expanded infantry roster and the new power budget. All three factions funded and completed Coordination through actual gathering in ResearchEconomyRegression; its budget-only rerun passes after supplying its full-base fixture and satisfying infantry demand.
- LocalizationRegression passes; existing CSV-only translations were preserved when updating generated power descriptions. Editor import, formatting, lint on changed AI/new regressions, and whitespace checks pass.
- Broader BastionDemo regression still reports the same ten roster/queue/population failures with both original and revised power values (verified using an isolated source overlay). Godot also emits teardown resource-leak warnings in the headless fixtures. These are outside this balance change. Longer competitive match tuning remains playtest work; increased deposit reserves apply to new maps, while saves preserve existing stock.

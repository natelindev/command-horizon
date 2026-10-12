# Skirmish facility AI regression

`SkirmishSitesRegression.gd` passes with zero failures for Bastion, Helix, and Frontier on the actual expanded Desert Frontier map. It exercises real infantry orders, battlefield observation, ten-second camp capture, paid recruitment, production requests, and paid producer queues. Exact source/test SHA256 values and the reproduction command are in `summary.json`; raw output is retained in `regression.log.txt`.

The opening two soldiers remain at home. Four healthy soldiers assign one capturer and retain three; repeated ticks and army coordination preserve that assignment. A wounded screen, visibly unsafe facility, or visible home raid prevents diversion. Hidden enemies do not influence the decision. Camp recruitment charges the faction's 25% premium once, admits one contract per tick, and leaves both construction and urgent production budgets available; those reserves then fund actual producer jobs.

The first run exposed missing `site_capture` metadata diagnostics. The root agent fixed the implementation with a `has_meta` guard. The final log has no unexpected gameplay/script diagnostics. Existing Godot shutdown ObjectDB/resource-in-use warnings remain.

Final root follow-up: recruitment skips a contested camp and uses the other operational owned camp; all three faction cases pass. The final log and hashes above include this additional regression.

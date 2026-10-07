"""Validate the reverse-handoff trials; no balance claim is inferred."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
rows = []
for branch in ["control", "reverse"]:
    status = json.loads((HERE / f"{branch}-exit.json").read_text())
    assert status["exit_code"] == (1 if branch == "control" else 0), status
    log = (HERE / f"{branch}.log").read_text()
    unresolved = 1 if branch == "control" else 0
    assert f"Skirmish matrix: 2 records, {unresolved} unresolved checks" in log
    if branch == "control":
        assert "ERROR: Case 6 repeat 11 did not reach a result" in log
    assert "SCRIPT ERROR" not in log and "Parse Error" not in log
    records = json.loads((HERE / f"{branch}.json").read_text())
    assert len(records) == 2 and {r["seed"] for r in records} == {4110, 4111}
    for r in records:
        assert r["result"] == ("Unresolved at 30:00" if branch == "control" and r["seed"] == 4111 else "Defeat")
        assert r["map"] == "IndustrialCrossroads" and r["faction"] == "helix"
        assert r["opponent"] == "frontier" and not r["advanced"]
        assert r["difficulty"] == "Normal" and r["army_policy"] == "screened-air"
        assert r["research_policy"] == "combined"
        assert r["final"]["home_response_enabled"] and r["final"]["electronics_handoff_enabled"]
        assert r["final"]["material_handoff_enabled"] == (branch == "reverse")
        assert not r["ai_coordination"]["violations"]
        handoffs = r.get("material_handoffs", [])
        assert branch == "reverse" or not handoffs
        for h in handoffs:
            assert h["cargo"][1] > 0 and h["funds"][0] < h["demand"][0]
            assert h["funds"][1] >= h["demand"][1]
            assert h["electronics_after"] >= h["electronics_floor"]
        rows.append({
            "branch": branch, "seed": r["seed"], "outcome": r["result"],
            "seconds": r["seconds"], "first_program": r["first_program"],
            "first_assault": r["first_assault"], "harvested": r["harvested"],
            "worker_losses": r["losses"][0].get("Worker", 0),
            "material_handoffs": len(handoffs),
            "electronics_handoffs": len(r.get("electronics_handoffs", [])),
            "coordination_samples": r["ai_coordination"]["samples"],
            "max_stationary_travel": r["longest_stationary_travel"],
        })
before = json.loads((HERE / "shipping-before.json").read_text())
current = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
           for p in (ROOT / "source").rglob("*.gd")}
assert before == current, "Shipping scripts changed"
for file in ["final-regression.log", "earned-continuation.log", "ElectronicsHandoffRegression.log", "LaborHandoffRegression.log"]:
    log = (HERE / file).read_text()
    assert "0 failures" in log and "SCRIPT ERROR" not in log and "Parse Error" not in log, file
control = (HERE / "original-policy.log").read_text()
assert "Material handoff: 6 failures" in control and "SCRIPT ERROR" not in control
report = {"rows": rows, "shipping_scripts_unchanged": len(current),
          "complete_match_gate_passed": False,
          "resolved_matches": 3, "unresolved_matches": 1,
          "scope": "Two seeds per branch; all retain response/electronics helpers; descriptive only",
          "earned_continuation": json.loads((HERE / "earned-continuation.json").read_text())}
(HERE / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))

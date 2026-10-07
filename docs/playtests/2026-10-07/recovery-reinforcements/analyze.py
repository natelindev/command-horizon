"""Validate terminal observations; distinguish saved-state recovery from fresh pacing."""
from pathlib import Path
import json
import hashlib

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
rows = []
for name in ["earned-control", "earned-priority", "fresh-control", "fresh-priority", "final-default"]:
    status = json.loads((HERE / f"{name}-exit.json").read_text())
    records = json.loads((HERE / f"{name}.json").read_text())
    assert len(records) == 1, name
    r = records[0]
    unresolved = int(r["result"] == "Unresolved at 30:00")
    assert r["result"] in ["Victory", "Defeat", "Draw", "Unresolved at 30:00"]
    assert status["exit_code"] == unresolved, status
    log = (HERE / f"{name}.log").read_text()
    assert f"Skirmish matrix: 1 records, {unresolved} unresolved checks" in log
    assert "SCRIPT ERROR" not in log and "Parse Error" not in log
    assert not r["ai_coordination"]["violations"]
    assert r["map"] == "IndustrialCrossroads" and r["faction"] == "helix"
    assert r["opponent"] == "frontier" and not r["advanced"]
    assert r["difficulty"] == "Normal" and r["army_policy"] == "screened-air"
    assert r["research_policy"] == "combined"
    assert r["final"]["home_response_enabled"] and r["final"]["electronics_handoff_enabled"]
    if name != "final-default":
        assert r["final"]["reinforcement_first"] == name.endswith("priority")
    row = {"branch": name, "outcome": r["result"], "absolute_seconds": r["seconds"],
           "first_program": r["first_program"], "first_assault": r["first_assault"],
           "harvested": r["harvested"], "net_spent": r["spent"],
           "research_orders": r.get("reference_research_orders", []),
           "worker_losses": r["losses"][0].get("Worker", 0),
           "coordination_samples": r["ai_coordination"]["samples"],
           "max_stationary_travel": r["longest_stationary_travel"]}
    if name.startswith("earned"):
        c = r["continuation"]
        assert c["initial_funds"] == [18, 224] and c["initial_readiness"]["army"] == 7
        assert c["initial_readiness"]["phase"] == "recover"
        row["continuation"] = c
        row["elapsed_since_restore"] = r["final"]["continuation_elapsed"]
        assert abs(r["seconds"] - c["restored_at"] - row["elapsed_since_restore"]) < .1
    rows.append(row)
assert rows[0]["outcome"] == rows[1]["outcome"] == "Victory"
assert rows[1]["continuation"]["first_new_ground"] < rows[0]["continuation"]["first_new_ground"]
assert rows[1]["continuation"]["first_nine_ground"] < rows[0]["continuation"]["first_nine_ground"]
for name in ["ReinforcementResearchRegression.log", "final-ReinforcementResearchRegression.log", "ResearchEconomyRegression.log"]:
    log = (HERE / name).read_text()
    assert "0 failures" in log and "SCRIPT ERROR" not in log and "Parse Error" not in log
before = json.loads((HERE / "shipping-before.json").read_text())
current = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
           for p in (ROOT / "source").rglob("*.gd")}
assert before == current
for scope in ["trial", "final"]:
    fp = json.loads((HERE / f"{scope}-source-fingerprint.json").read_text())
    for path, digest in fp.items():
        assert hashlib.sha256((HERE / f"{scope}-sources" / path).read_bytes()).hexdigest() == digest
        if scope == "final":
            assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest
report = {"rows": rows, "shipping_scripts_unchanged": len(current),
          "fresh_complete_match_gate": all(r["outcome"] in ["Victory", "Defeat", "Draw"] for r in rows if not r["branch"].startswith("earned")),
          "bounds": ["One exact saved world and one fresh seed; no general balance conclusion.",
                     "The saved world and recorded commander state are restored; unrecorded test history restarts.",
                     "Both earned outcomes occur beyond thirty minutes of total match time."]}
(HERE / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))

"""Validate allocation evidence without treating rejected previews as passing."""
from pathlib import Path
import hashlib
import json
import struct

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
before = json.loads((HERE / "shipping-before.json").read_text())
current = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
           for p in (ROOT / "source").rglob("*.gd")}
changed = sorted(p for p in before if current.get(p) != before[p])
added = sorted(set(current) - set(before))
assert changed == ["source/match/EconomySupply.gd", "source/match/hud/ResourcesBar.gd"]
assert added == ["source/match/EconomyAssignments.gd"]
fp = json.loads((HERE / "source-fingerprint.json").read_text())
assert fp["current"] == current
for name, digest in fp["final_test_sources"].items():
    assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest
    assert hashlib.sha256((HERE / "final-sources" / name).read_bytes()).hexdigest() == digest
rows = json.loads((HERE / "run-index.json").read_text())
assert len(rows) == 9
for row in rows:
    log = (HERE / row["log"]).read_text()
    if row["log"] == "preview.log":
        assert log.count("SCRIPT ERROR:") == 3 and row["exit_code"] == 0
    elif row["log"] == "final-preview.log":
        assert "Economy assignments: 3 failures" in log and row["exit_code"] == 1
        assert log.count("ERROR: Allocation preview resolution changed") == 3
        assert "SCRIPT ERROR" not in log
    elif row["log"] == "original-shipping.log":
        assert "Economy assignments: 12 failures" in log and row["exit_code"] == 1
        assert "SCRIPT ERROR" not in log
    else:
        assert row["exit_code"] == 0 and "SCRIPT ERROR" not in log and "Parse Error" not in log
        assert "0 failures" in log or "PASS: both factions queued routes" in log
images = []
for p in sorted(HERE.glob("verified-preview-*.png")):
    width, height = struct.unpack(">II", p.read_bytes()[16:24])
    assert (width, height) == (1280, 720)
    images.append(p.name)
assert len(images) == 3
preview = (HERE / "verified-preview.log").read_text()
assert preview.count("ALLOCATION INPUT ") == 3
assert preview.count("keyboard=true") == 1
assert "Success: no problems found" in (HERE / "final-lint.log").read_text()
assert "left unchanged" in (HERE / "final-format.log").read_text()
summary = {"shipping_scripts": len(current), "changed": changed, "added": added,
           "godot_processes": len(rows), "preceding_code_expected_failures": 12,
           "accepted_images": images, "input_checks": {"mouse": 2, "enter": 1},
           "final_delivery_records": [line for line in (HERE / "reciprocal-regression.log").read_text().splitlines() if line.startswith("ASSIGNMENT DELIVERY ")],
           "limits": "Controlled all-faction Advanced fixtures with disabled opponent strategy; no contested/novice/balance claim."}
assert len(summary["final_delivery_records"]) == 3
(HERE / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps(summary, indent=2))

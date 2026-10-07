"""Validate convoy playthrough evidence and the exact shipping-change scope."""

import hashlib
import json
import re
import struct
from pathlib import Path

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[3]


def read(name):
    return json.loads((EVIDENCE / name).read_text())


before = read("shipping-before.json")
after = read("shipping-final.json")
assert before.keys() == after.keys()
changed = [path for path in before if before[path] != after[path]]
assert changed == ["source/match/campaign/SupplyLine.gd", "source/match/campaign/SupplyLineHUD.gd"]
for path, digest in after.items():
    assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest, path
for path, digest in read("test-sources.json").items():
    for location in [ROOT / path, EVIDENCE / "final-sources" / path]:
        assert hashlib.sha256(location.read_bytes()).hexdigest() == digest, location

runs = read("run-index.json")
assert len(runs) == 15
for run in runs:
    log = (EVIDENCE / (run["name"] + ".log")).read_text()
    assert isinstance(run["exit"], int), run["name"]
    if run["mode"] == "rejected fixture syntax":
        assert "SCRIPT ERROR: Parse Error" in log
        assert "SUPPLY DIFFICULTY" not in log
        continue
    assert "SCRIPT ERROR" not in log, run["name"]
    failures = re.findall(r"Supply.*: (\d+) failures", log)
    assert len(failures) == 1, (run["name"], failures)
    expected = run.get("failures", 3 if run["name"] == "preview" else 0)
    assert int(failures[0]) == expected, run["name"]

outcomes = []
for name in [f"initial-{d}" for d in range(3)] + [f"verified-group-{d}" for d in range(3)] + ["final-preview"]:
    result = read(name + ".json")
    assert result["result"] == "Victory" and not result["errors"], name
    assert all(result["responses"]), name
    assert sum(truck["delivered"] for truck in result["trucks"]) >= 2
    assert all(truck["delivered"] or truck["alive"] for truck in result["trucks"])
    outcomes.append({"name": name, "difficulty": result["difficulty"], "time": result["time"], "escorts": result["escorts"]})

failure = read("preview.json")
assert failure["result"] == "" and failure["responses"] == [True, False, False]
assert all(truck["alive"] and truck["leg"] == 0 for truck in failure["trucks"])
assert all(abs(truck["clearance"] - 9.8) < 0.001 for truck in failure["trucks"])
assert (EVIDENCE / "preview-archive.json").stat().st_size > 1000
images = ["contest-contested.png", "contest-cleared.png"] + [f"final-preview-stage-{d}.png" for d in range(3)]
for name in images:
    raw = (EVIDENCE / name).read_bytes()
    assert raw[:8] == b"\x89PNG\r\n\x1a\n"
    assert struct.unpack(">II", raw[16:24]) == (1280, 720), name
rendered = (EVIDENCE / "final-preview.log").read_text()
assert rendered.count("CONVOY INPUT mouse-advance") == 3
assert rendered.count("CONVOY INPUT enter-hold") == 3
assert "CONVOY RESPONSE" in rendered
assert "CONTEST INPUT mouse=1 enter=1" in (EVIDENCE / "contest-preview.log").read_text()
assert "8 files would be left unchanged" in (EVIDENCE / "final-format.log").read_text()
assert "Success: no problems found" in (EVIDENCE / "final-lint.log").read_text()
summary = {"shipping_scripts": len(after), "changed": changed, "test_processes": len(runs),
           "successful_fresh_routes": outcomes, "accepted_images": images,
           "original_feedback_failures": 3,
           "limits": "Practiced commanders; not novice/repeated difficulty or performance acceptance."}
(EVIDENCE / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps(summary, indent=2))

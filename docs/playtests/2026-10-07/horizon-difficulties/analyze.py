"""Validate the retained finale outcomes and narrowly scoped source changes."""

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
assert changed == ["source/match/campaign/CommandHorizon.gd"], changed
for path, digest in after.items():
    assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest, path
for path, digest in read("final-test-sources.json").items():
    for location in [ROOT / path, EVIDENCE / "final-sources" / path]:
        assert hashlib.sha256(location.read_bytes()).hexdigest() == digest, location

runs = read("run-index.json")
assert len(runs) == 16
for run in runs:
    log = (EVIDENCE / (run["name"] + ".log")).read_text()
    assert "SCRIPT ERROR" not in log, run["name"]
    failures = re.findall(r"(?:Horizon.*|Command Horizon.*): (\d+) failures", log)
    assert len(failures) == 1, (run["name"], failures)
    expected = run.get("expected_failures", 0 if run["exit"] == 0 else 1)
    assert int(failures[0]) == expected, run["name"]

outcomes = []
for run in runs:
    if run["kind"] != "fresh match":
        continue
    result = read(run["name"] + ".json")
    assert result["difficulty"] == run["difficulty"]
    assert result["challenge"] == run["challenge"]
    assert not result["alternate_route"]
    assert result["deployed"] and result["command_destroyed"] and result["waves"] == 4
    if run["exit"] == 0:
        assert result["result"] == "Victory" and result["zone_held"] and not result["errors"]
    else:
        assert result["result"] == "" and not result["zone_held"]
        assert result["errors"] == ["Final HQ assault did not reach victory"]
        assert (EVIDENCE / (run["name"] + "-archive.json")).stat().st_size > 1000
    outcomes.append({"name": run["name"], "time": result["time"], "result": result["result"]})

for name in ["earned-retake", "verified-preview"]:
    result = read(name + ".json")
    assert result["result"] == "Victory" and result["zone_held"] and not result["errors"]
for label in ["paused", "result"]:
    raw = (EVIDENCE / ("verified-preview-" + label + ".png")).read_bytes()
    assert raw[:8] == b"\x89PNG\r\n\x1a\n"
    assert struct.unpack(">II", raw[16:24]) == (1280, 720)
assert "HORIZON RECOVERY INPUT mouse=1 enter=1" in (EVIDENCE / "verified-preview.log").read_text()
assert "6 files would be left unchanged" in (EVIDENCE / "final-format.log").read_text()
assert "Success: no problems found" in (EVIDENCE / "final-lint.log").read_text()

summary = {
    "shipping_scripts": len(after),
    "changed": changed,
    "godot_processes": len(runs),
    "fresh_matches": outcomes,
    "preceding_code_feedback_failures": 4,
    "accepted_rendered_images": 2,
    "limits": "Viable routes, not novice/repeatability/all-combination acceptance; performance deferred.",
}
(EVIDENCE / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps(summary, indent=2))

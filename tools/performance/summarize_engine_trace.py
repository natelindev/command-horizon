"""Summarize Tracy zone exports without treating traced timings as gameplay FPS."""

import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path


def read_zones(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return [dict(name=row["name"], source=row["src_file"], line=int(row["src_line"]),
                     calls=int(row["counts"]), elapsed_ms=int(row["total_ns"]) / 1e6)
                for row in csv.DictReader(stream)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    metadata = json.loads((args.capture / "metadata.json").read_text(encoding="utf-8"))
    self_zones = read_zones(args.capture / "zones-self.csv")
    total_zones = read_zones(args.capture / "zones-total.csv")
    sources = defaultdict(lambda: dict(elapsed_ms=0.0, calls=0))
    for zone in self_zones:
        sources[zone["source"]]["elapsed_ms"] += zone["elapsed_ms"]
        sources[zone["source"]]["calls"] += zone["calls"]
    rank = lambda rows: sorted(rows, key=lambda row: row["elapsed_ms"], reverse=True)
    report = {
        "diagnostic": True, "production_fps_evidence": False,
        "status": metadata["status"], "phase": metadata["phase"],
        "seconds_requested": metadata["seconds_requested"],
        "engine_sha256": metadata["engine_sha256"],
        "note": "Instrumented elapsed zones, including waits. Inclusive zones overlap. "
                "Self times may run on different threads and are not an additive frame budget. "
                "Script file labels also contain native calls made from that source.",
        "self_by_source": rank([dict(source=source, **values) for source, values in sources.items()]),
        "top_self_zones": rank(self_zones)[:60],
        "top_inclusive_zones": rank(total_zones)[:60],
        "engine_main_zones": rank([zone for zone in total_zones
                                   if zone["source"].replace("\\", "/") == "main/main.cpp"]),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    for zone in report["top_self_zones"][:15]:
        print(f'{zone["elapsed_ms"]:8.2f} ms / {zone["calls"]:8d} calls: '
              f'{zone["source"]}:{zone["line"]} {zone["name"]}')


if __name__ == "__main__":
    main()

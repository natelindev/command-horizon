"""Rank sampled game-function self time from the live debug script diagnostic."""

import argparse
from collections import defaultdict
import json
from pathlib import Path
import re


FUNCTION = re.compile(
    r"^\d+:(res://source/.+)\n\s*total: ([0-9.eE+-]+)/[^\n]*?"
    r"self: ([0-9.eE+-]+)/[^\n]*?tcalls: (\d+)", re.MULTILINE
)


def summarize(text):
    # Tests use async frame waits. Their profiler self time can include the wait;
    # exclude them and accumulated/coroutine totals from the game hot-function rank.
    begin = text.index("HEAVY_BEGIN day_combat")
    end = text.index("HEAVY_PHASE", begin)
    frames = text[begin:end].split("FRAME:")[1:]
    if not frames:
        raise ValueError("No measured combat profiler frames")
    functions = defaultdict(lambda: {"sampled_self_seconds": 0.0, "sampled_calls": 0})
    for frame in frames:
        for found in FUNCTION.finditer(frame):
            entry = functions[found[1]]
            entry["sampled_self_seconds"] += float(found[3])
            entry["sampled_calls"] += int(found[4])
    if not functions:
        raise ValueError("No game source functions in the measured profile")
    ranked = []
    for signature, record in functions.items():
        ranked.append({"signature": signature, **record,
                       "self_ms_per_sampled_frame": record["sampled_self_seconds"] * 1000 / len(frames)})
    ranked.sort(key=lambda row: row["sampled_self_seconds"], reverse=True)
    return {
        "diagnostic": True,
        "production_fps_evidence": False,
        "sampled_profiler_frames": len(frames),
        "note": "Editor/debug instrumentation samples only selected frames. Source-function self times rank candidates; they do not account for all engine/native work. Test coroutines and accumulated coroutine timings are excluded. Confirm optimization gains in the rendered production workload.",
        "source_functions": ranked,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        result = summarize(args.log.read_text(encoding="utf-8"))
    except ValueError as error:
        parser.error(str(error))
    if args.output:
        args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f'{result["sampled_profiler_frames"]} sampled debug profiler frames; not production FPS')
    for row in result["source_functions"][:20]:
        print(f'{row["self_ms_per_sampled_frame"]:8.3f} ms self/sample  '
              f'{row["sampled_calls"]:9d} calls  {row["signature"]}')


if __name__ == "__main__":
    main()

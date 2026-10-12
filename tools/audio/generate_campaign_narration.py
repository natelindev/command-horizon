import argparse
import array
import contextlib
import hashlib
import importlib.metadata
import json
import pathlib
import re
import shutil
import subprocess
import sys
import wave

ROOT = pathlib.Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets/audio/campaign"
DEFAULT_STAGE = ROOT / "tmp/tooling/campaign-narration-hf"
MODELS = {
    "en": {
        "repo": "hexgrad/Kokoro-82M",
        "revision": "f3ff3571791e39611d31c381e3a41a3af07b4987",
        "weights": "kokoro-v1_0.pth",
        "sha256": "496dba118d1a58f5f3db2efc88dbdc216e0483fc89fe6e47ee1f2c53f18ad1e4",
        "voice": "af_heart",
        "code": "a",
        "speed": 0.98,
    },
    "zh_CN": {
        "repo": "hexgrad/Kokoro-82M-v1.1-zh",
        "revision": "01e7505bd6a7a2ac4975463114c3a7650a9f7218",
        "weights": "kokoro-v1_1-zh.pth",
        "sha256": "b1d8410fa44dfb5c15471fd6c4225ea6b4e9ac7fa03c98e8bea47a9928476e2b",
        "voice": "zf_001",
        "code": "z",
        "speed": "token_length_curve",
    },
}


def filehash(path):
    with open(path, "rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def speed_zh(n):
    return (1 if n <= 83 else max(0.8, 1 - (n - 83) / 500)) * 1.05


def dependencies():
    try:
        import numpy as np
        import soundfile as sf
        import torch
        from huggingface_hub import hf_hub_download
        from kokoro import KModel, KPipeline
    except ImportError as exc:
        raise RuntimeError(
            "Narration build environment is missing; follow assets/audio/campaign/README.md setup."
        ) from exc
    return np, sf, torch, hf_hub_download, KModel, KPipeline


def generate(out, sample):
    results = []
    provenance = {}
    np, sf, torch, hf_hub_download, KModel, KPipeline = dependencies()
    torch.set_num_threads(1)
    torch.set_num_interop_threads(1)
    lines = json.loads((ASSETS / "narration.json").read_text())
    out.mkdir(parents=True, exist_ok=True)
    for lang, spec in MODELS.items():
        print("Preparing", lang, spec["repo"], flush=True)
        paths = {
            name: hf_hub_download(
                repo_id=spec["repo"],
                revision=spec["revision"],
                filename=name,
                token=False,
            )
            for name in [
                "config.json",
                spec["weights"],
                "voices/" + spec["voice"] + ".pt",
            ]
        }
        if filehash(paths[spec["weights"]]) != spec["sha256"]:
            raise ValueError("Model hash differs from official model card")
        provenance[lang] = {name: filehash(path) for name, path in paths.items()}
        model = (
            KModel(
                repo_id=spec["repo"],
                config=paths["config.json"],
                model=paths[spec["weights"]],
            )
            .to("cpu")
            .eval()
        )
        pipeline = KPipeline(lang_code=spec["code"], repo_id=spec["repo"], model=model)
        for key, texts in lines.items():
            if sample and key != "first_orders.intro":
                continue
            # Seed each cue independently so sample and full builds share the
            # same waveform, regardless of generation order.
            seed = int(hashlib.sha256((key + lang).encode()).hexdigest()[:8], 16)
            torch.manual_seed(seed)
            np.random.seed(seed)
            stem = key.replace(".", "_") + "_" + ("en" if lang == "en" else "zh")
            chunks = (
                [texts[lang]]
                if lang == "en"
                else re.findall(r"[^。！？]+[。！？]?", texts[lang])
            )
            segments = []
            for chunk in chunks:
                with torch.inference_mode():
                    generated = list(
                        pipeline(
                            chunk,
                            voice=paths["voices/" + spec["voice"] + ".pt"],
                            speed=0.98 if lang == "en" else speed_zh,
                        )
                    )
                for part in generated:
                    if part.audio is None or len(part.audio) <= 2400:
                        raise ValueError("Empty speech segment")
                    segments.append(part.audio.numpy())
                segments.append(np.zeros(3840, dtype=np.float32))
            raw = out / (stem + "_raw.wav")
            target = out / (stem + ".wav")
            sf.write(raw, np.concatenate(segments), 24000, subtype="PCM_16")
            subprocess.run(
                [
                    shutil.which("ffmpeg") or "ffmpeg",
                    "-loglevel",
                    "error",
                    "-y",
                    "-i",
                    str(raw),
                    "-af",
                    "loudnorm=I=-18:TP=-3:LRA=7",
                    "-ar",
                    "24000",
                    "-ac",
                    "1",
                    "-c:a",
                    "pcm_s16le",
                    str(target),
                ],
                check=True,
            )
            raw.unlink()
            audio, sr = sf.read(target)
            duration = len(audio) / sr
            if not 2 < duration < 50 or np.max(np.abs(audio)) <= 0.03:
                raise ValueError("Invalid speech asset")
            result = {
                "id": key,
                "language": lang,
                "file": target.name,
                "duration_seconds": round(duration, 3),
                "sha256": filehash(target),
                "text_sha256": hashlib.sha256(texts[lang].encode()).hexdigest(),
                "peak": round(float(np.max(np.abs(audio))), 4),
                "rms": round(float(np.sqrt(np.mean(audio**2))), 6),
                "seed": seed,
            }
            results.append(result)
            print("Rendered", target.name, round(duration, 2), "seconds", flush=True)
    (out / "generation-manifest.json").write_text(
        json.dumps(
            {
                "schema": 1,
                "sample_only": sample,
                "license": "Apache-2.0",
                "models": MODELS,
                "model_file_sha256": provenance,
                "packages": {
                    p: importlib.metadata.version(p)
                    for p in [
                        "kokoro",
                        "misaki",
                        "torch",
                        "soundfile",
                        "transformers",
                        "huggingface-hub",
                        "en-core-web-sm",
                    ]
                },
                "sample_rate": 24000,
                "channels": 1,
                "sample_bits": 16,
                "normalization": "loudnorm=I=-18:TP=-3:LRA=7",
                "clips": results,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n"
    )
    return results


def validate(directory, allow_sample=False):
    manifest_path = directory / "generation-manifest.json"
    if not manifest_path.is_file():
        raise ValueError(
            "Generation manifest is missing; run generate with this output directory."
        )
    manifest = json.loads(manifest_path.read_text())
    lines = json.loads((ASSETS / "narration.json").read_text())
    expected = {(key, lang) for key in lines for lang in MODELS}
    if allow_sample and manifest.get("sample_only"):
        expected = {("first_orders.intro", lang) for lang in MODELS}
    actual = {(clip["id"], clip["language"]) for clip in manifest["clips"]}
    if actual != expected or len(manifest["clips"]) != len(expected):
        raise ValueError(
            "Voice set is incomplete; generate without --sample before installing."
        )
    if manifest.get("models") != MODELS or manifest.get("license") != "Apache-2.0":
        raise ValueError("Voice manifest does not match the pinned narration models.")
    for clip in manifest["clips"]:
        key, lang = clip["id"], clip["language"]
        expected_name = key.replace(".", "_") + (
            "_en.wav" if lang == "en" else "_zh.wav"
        )
        if clip["file"] != expected_name:
            raise ValueError("Voice manifest contains an unexpected file path.")
        path = directory / expected_name
        if filehash(path) != clip["sha256"]:
            raise ValueError(
                "Voice file differs from its generation manifest: " + expected_name
            )
        if hashlib.sha256(lines[key][lang].encode()).hexdigest() != clip["text_sha256"]:
            raise ValueError(
                "Narration text has changed; regenerate voice: " + expected_name
            )
        with wave.open(str(path)) as wav:
            duration = wav.getnframes() / wav.getframerate()
            if (
                wav.getframerate() != 24000
                or wav.getnchannels() != 1
                or wav.getsampwidth() != 2
                or not 2 < duration < 50
            ):
                raise ValueError("Invalid narration format/duration: " + expected_name)
            if abs(duration - clip["duration_seconds"]) > 0.002:
                raise ValueError(
                    "Narration duration does not match manifest: " + expected_name
                )
            samples = array.array("h", wav.readframes(wav.getnframes()))
            if sys.byteorder != "little":
                samples.byteswap()
            peak = max(abs(value) for value in samples) / 32768
            rms = (
                sum(value * value for value in samples) / len(samples)
            ) ** 0.5 / 32768
            if not 0.03 < peak < 0.98 or rms < 0.005:
                raise ValueError("Narration is silent or clipped: " + expected_name)
            if abs(peak - clip["peak"]) > 0.0002 or abs(rms - clip["rms"]) > 0.00001:
                raise ValueError(
                    "Narration levels differ from manifest: " + expected_name
                )
    return manifest


def install(directory):
    manifest = validate(directory)
    changed = 0
    for clip in manifest["clips"]:
        target = ASSETS / clip["file"]
        if target.is_file() and filehash(target) == clip["sha256"]:
            continue
        temporary = target.with_suffix(".wav.pending")
        shutil.copyfile(directory / clip["file"], temporary)
        temporary.replace(target)
        changed += 1
    temporary = ASSETS / "generation-manifest.json.pending"
    shutil.copyfile(directory / "generation-manifest.json", temporary)
    temporary.replace(ASSETS / "generation-manifest.json")
    return changed


def emit(key, value):
    print(key + ": " + json.dumps(value, ensure_ascii=False))


def home():
    emit(
        "bin",
        str(pathlib.Path(__file__).resolve()).replace(str(pathlib.Path.home()), "~", 1),
    )
    emit(
        "description",
        "Build and verify baked campaign narration with pinned Hugging Face models.",
    )
    emit(
        "narration",
        str(len(json.loads((ASSETS / "narration.json").read_text())))
        + " English/Chinese pairs",
    )
    emit("recordings", len(list(ASSETS.glob("*.wav"))))
    print("help[2]:")
    print("  python tools/audio/generate_campaign_narration.py generate --sample")
    print(
        "  python tools/audio/generate_campaign_narration.py verify --output tmp/tooling/campaign-narration-hf"
    )


class Parser(argparse.ArgumentParser):
    def error(self, message):
        emit("error", message)
        emit("help", "Run python tools/audio/generate_campaign_narration.py --help")
        raise SystemExit(2)


def main():
    parser = Parser(add_help=False)
    parser.add_argument("command", nargs="?", choices=["generate", "verify", "install"])
    parser.add_argument("--output", type=pathlib.Path, default=DEFAULT_STAGE)
    parser.add_argument("--sample", action="store_true")
    parser.add_argument("--help", action="store_true")
    args = parser.parse_args()
    if args.help:
        emit(
            "description",
            "Generate stages audio; verify checks its exact model/text/file hashes; install replaces baked assets after a complete validation.",
        )
        emit(
            "flags",
            "--output <directory> (default tmp/tooling/campaign-narration-hf); --sample (generate two First Orders introduction recordings only)",
        )
        print("examples[3]:")
        print("  python tools/audio/generate_campaign_narration.py generate --sample")
        print("  python tools/audio/generate_campaign_narration.py generate")
        print("  python tools/audio/generate_campaign_narration.py install")
        return 0
    if not args.command:
        home()
        return 0
    if args.sample and args.command != "generate":
        parser.error("--sample is only valid with generate")
    try:
        if args.command == "generate":
            destination = args.output.resolve()
            if destination == ASSETS or ASSETS in destination.parents:
                raise ValueError(
                    "Generate into staging, then install the complete verified batch."
                )
            if not shutil.which("ffmpeg"):
                raise RuntimeError(
                    "Audio normalizer is unavailable; install FFmpeg and rerun generate."
                )
            # Dependencies write logs to stdout; keep stdout reserved for structured results.
            with contextlib.redirect_stdout(sys.stderr):
                clips = generate(destination, args.sample)
            emit("status", "generated")
            emit("clips", len(clips))
            emit("output", str(args.output.resolve()))
        elif args.command == "verify":
            manifest = validate(args.output.resolve(), allow_sample=True)
            emit("status", "verified")
            emit("clips", len(manifest["clips"]))
        else:
            changed = install(args.output.resolve())
            emit("status", "installed" if changed else "already installed")
            emit("changed", changed)
        return 0
    except (
        OSError,
        ValueError,
        KeyError,
        RuntimeError,
        subprocess.CalledProcessError,
    ) as exc:
        emit("error", str(exc))
        emit(
            "help",
            "Run python tools/audio/generate_campaign_narration.py generate --output tmp/tooling/campaign-narration-hf",
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

"""Import verified source files from tmp/music/licensed with ffmpeg.

Requires Python 3 and ffmpeg/ffprobe. Original source hashes are pinned in
licensed-score.json; downloads are intentionally separate from this importer.
"""
import array
import hashlib
import json
import math
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
CATALOG = Path(__file__).with_name('licensed-score.json')
SOURCE = ROOT / 'tmp/music/licensed'
PREVIEWS = ROOT / 'tmp/music/previews'


def run(*args):
    return subprocess.run(args, check=True, capture_output=True)


def measure(path):
    result = run('ffmpeg', '-hide_banner', '-i', str(path), '-af',
                 'loudnorm=I=-20:TP=-2:LRA=20:print_format=json', '-f', 'null', '-')
    log = result.stderr.decode()
    return json.loads(log[log.rfind('{'):log.rfind('}') + 1])


def duration(path):
    return float(run('ffprobe', '-v', 'error', '-show_entries', 'format=duration',
                     '-of', 'default=noprint_wrappers=1:nokey=1', str(path)).stdout)


def main():
    tracks = json.loads(CATALOG.read_text())
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    report = []
    for track in tracks:
        source = SOURCE / track['source_file']
        if hashlib.sha256(source.read_bytes()).hexdigest() != track['source_sha256']:
            raise ValueError('Source hash mismatch: ' + str(source))
        original = measure(source)
        seconds = duration(source)
        # Constant gain preserves the complete arrangement and source dynamics.
        gain = min(-20 - float(original['input_i']), -2.5 - float(original['input_tp']))
        target = ROOT / track['output']
        run('ffmpeg', '-y', '-hide_banner', '-i', str(source), '-map_metadata', '-1',
            '-af', f'volume={gain}dB,afade=t=in:d=0.08,afade=t=out:st={seconds - .5}:d=0.5',
            '-ar', '44100', '-ac', '2', '-c:a', 'vorbis', '-strict', '-2', '-q:a', '6',
            '-metadata', 'title=' + track['title'], '-metadata', 'artist=' + track['artist'],
            '-metadata', 'copyright=' + track['license'], '-metadata', 'comment=' + track['page'],
            str(target))
        decoded = measure(target)
        pcm = array.array('f', run('ffmpeg', '-v', 'error', '-i', str(target),
                                   '-f', 'f32le', '-acodec', 'pcm_f32le', '-').stdout)
        seam = max(abs(pcm[c] - pcm[-2 + c]) for c in (0, 1))
        peak = max(abs(sample) for sample in pcm)
        if peak >= 1 or float(decoded['input_tp']) > -1:
            raise ValueError('Output peak too high: ' + str(target))
        preview = PREVIEWS / (track['cue'] + '.mp3')
        run('ffmpeg', '-y', '-v', 'error', '-ss', '35', '-i', str(target), '-t', '30',
            '-af', 'afade=t=in:d=0.5,afade=t=out:st=28:d=2', '-c:a', 'libmp3lame',
            '-q:a', '3', str(preview))
        entry = dict(cue=track['cue'], title=track['title'], duration_seconds=duration(target),
                     gain_db=round(gain, 2), integrated_lufs=float(decoded['input_i']),
                     true_peak_dbtp=float(decoded['input_tp']),
                     sample_peak_dbfs=round(20 * math.log10(peak), 2),
                     loop_boundary_step=round(seam, 7),
                     output_sha256=hashlib.sha256(target.read_bytes()).hexdigest())
        report.append(entry)
        print(json.dumps(entry), flush=True)
    Path(__file__).with_name('licensed-audio-verification.json').write_text(
        json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()

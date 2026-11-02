"""Download only the pinned CC0 instrument sources needed to rebuild faction arrangements."""
import argparse
import hashlib
import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['status','fetch'], nargs='?', default='status')
    args = parser.parse_args()
    rows = json.loads((ROOT / 'art/audio/faction-instruments.json').read_text())
    if args.command == 'status':
        cached = sum((ROOT/row['cache']).is_file() and hashlib.sha256((ROOT/row['cache']).read_bytes()).hexdigest()==row['sha256'] for row in rows)
        print(f'bin: {Path(__file__).resolve()}\ndescription: Fetch pinned CC0 faction instruments\ninstruments: {len(rows)}\ncached: {cached}\nhelp: Run fetch_faction_instruments.py fetch to retrieve missing samples')
        return
    for row in rows:
        path = ROOT / row['cache']
        if path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == row['sha256']:
            continue
        data = urllib.request.urlopen(row['url'], timeout=60).read()
        if hashlib.sha256(data).hexdigest() != row['sha256']:
            raise ValueError('Source hash mismatch: ' + row['id'])
        path.parent.mkdir(parents=True, exist_ok=True)
        pending = path.with_suffix('.tmp')
        pending.write_bytes(data)
        pending.replace(path)
        print('Fetched ' + row['id'], file=sys.stderr)
    print('instruments: ' + str(len(rows)))


if __name__ == '__main__':
    main()

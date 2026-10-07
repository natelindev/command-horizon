"""Download checksum-pinned native build sources; requires Python 3.12 or newer."""
import hashlib
import io
import json
from pathlib import Path
import shutil
import tarfile
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parent
VENDOR = ROOT / 'vendor'
LOCK = json.loads((ROOT / 'dependencies.json').read_text())


def patch_lua(folder):
    # Exact production-source changes from upstream 0b29f408. Test-only changes omitted.
    changes = {
        'lgc.c': (
            'l_mem limit = applygcparam(g, MAJORMINOR, addedbytes);',
            'l_mem limit = (addedbytes < 0) ? 0\n                    : applygcparam(g, MAJORMINOR, addedbytes);'),
        'lobject.c': (
            'int e = (p >> 4);  /* exponent */',
            'int e = (p >> 4);  /* exponent */\n  lua_assert(x >= 0);'),
    }
    for name, (old, new) in changes.items():
        path = folder / 'src' / name
        source = path.read_text()
        if source.count(old) != 1:
            raise RuntimeError(f'Pinned Lua patch no longer matches {name}')
        path.write_text(source.replace(old, new))


def main():
    VENDOR.mkdir(exist_ok=True)
    for name, entry in LOCK.items():
        target = VENDOR / name
        stamp = json.dumps(entry, sort_keys=True)
        marker = target / '.rts-dependency.json'
        if target.exists():
            if marker.exists() and marker.read_text() == stamp:
                print(f'{name}: pinned sources already present')
                continue
            raise RuntimeError(f'{target} already exists without the current pin; inspect it before replacing')
        print(f'Downloading {name} {entry["version"]}')
        with urllib.request.urlopen(entry['url'], timeout=60) as response:
            data = response.read(32 * 1024 * 1024 + 1)
        if len(data) > 32 * 1024 * 1024 or hashlib.sha256(data).hexdigest() != entry['sha256']:
            raise RuntimeError(f'Checksum mismatch for {name}')
        with tempfile.TemporaryDirectory(dir=VENDOR) as temporary:
            with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
                archive.extractall(temporary, filter='data')
            folders = list(Path(temporary).iterdir())
            if len(folders) != 1 or not folders[0].is_dir():
                raise RuntimeError(f'Unexpected archive layout for {name}')
            if name == 'lua':
                patch_lua(folders[0])
            (folders[0] / '.rts-dependency.json').write_text(stamp)
            shutil.move(str(folders[0]), str(target))
        print(f'{name}: verified and ready')


if __name__ == '__main__':
    main()

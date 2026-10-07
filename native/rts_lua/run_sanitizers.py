"""Build and run the C sandbox boundary under Clang ASan/UBSan (macOS/Linux)."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
EXCLUDED = {'lua.c', 'luac.c', 'linit.c', 'liolib.c', 'loslib.c', 'loadlib.c',
            'ldblib.c', 'lstrlib.c', 'ltablib.c', 'lutf8lib.c', 'lcorolib.c'}
sources = [str(path) for path in (ROOT / 'vendor/lua/src').glob('*.c')
           if path.name not in EXCLUDED]
if not sources:
    raise RuntimeError('Run fetch_dependencies.py first')
with tempfile.TemporaryDirectory(prefix='rts-lua-test-') as temporary:
    binary = str(Path(temporary) / 'sandbox-test')
    subprocess.run(['clang', '-std=c11', '-g', '-O1', '-fsanitize=address,undefined',
                    '-fno-omit-frame-pointer', '-DLUA_USE_APICHECK', '-I' + str(ROOT / 'src'),
                    '-I' + str(ROOT / 'vendor/lua/src'), str(ROOT / 'src/sandbox.c'),
                    str(ROOT / 'tests/sandbox_test.c'), *sources, '-lm', '-o', binary], check=True)
    subprocess.run([binary], check=True, timeout=30)

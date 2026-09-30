"""Keep Android's offline Health Connect privacy page identical to Hosting."""
import argparse
from pathlib import Path
root = Path(__file__).resolve().parents[1]
target = root / 'frontend/android/app/src/main/assets/legal'
parser = argparse.ArgumentParser()
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
for source in (root / 'legal').iterdir():
    if source.suffix not in {'.html', '.css'}: continue
    dest = target / source.name
    if args.check:
        if not dest.exists() or dest.read_bytes() != source.read_bytes():
            raise SystemExit(f'Offline policy differs: {source.name}. Run python tools/sync_legal_assets.py')
    else:
        target.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(source.read_bytes())

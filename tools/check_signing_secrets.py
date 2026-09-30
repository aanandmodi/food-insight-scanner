"""Reject tracked signing identities without reading or printing their contents."""
from pathlib import PurePosixPath
import subprocess

paths = subprocess.check_output(['git', 'ls-files', '-z']).decode().split('\0')
forbidden = [p for p in paths if p and (
    PurePosixPath(p).name.lower() == 'key.properties'
    or PurePosixPath(p).suffix.lower() in {'.jks', '.keystore', '.p12', '.pfx'}
)]
if forbidden:
    raise SystemExit('Signing material is tracked. Remove these paths from the index:\n' + '\n'.join(forbidden))
print('No signing credentials tracked.')

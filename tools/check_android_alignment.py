"""Reject 64-bit Android native libraries incompatible with 16 KB pages.

Usage: python tools/check_android_alignment.py path/to/app.aab (or app.apk)
See https://developer.android.com/guide/practices/page-sizes.
Packaging alignment is checked separately with bundletool/zipalign.
"""
import argparse
from pathlib import Path
import struct
import zipfile


def check_archive(path: Path) -> None:
    checked = 0
    failures = []
    with zipfile.ZipFile(path) as archive:
        for name in archive.namelist():
            if not name.endswith('.so') or not any(
                    f'/{abi}/' in name for abi in ('arm64-v8a', 'x86_64')):
                continue
            data = archive.read(name)
            if data[:4] != b'\x7fELF' or data[4] != 2:
                failures.append(f'{name}: invalid 64-bit ELF')
                continue
            endian = '<' if data[5] == 1 else '>'
            offset = struct.unpack_from(endian + 'Q', data, 32)[0]
            size, count = struct.unpack_from(endian + 'HH', data, 54)
            loads = []
            writable_loads = []
            relro = []
            for index in range(count):
                position = offset + index * size
                kind = struct.unpack_from(endian + 'I', data, position)[0]
                if kind == 1:  # PT_LOAD
                    loads.append(struct.unpack_from(endian + 'Q', data, position + 48)[0])
                    flags = struct.unpack_from(endian + 'I', data, position + 4)[0]
                    if flags & 2:
                        address = struct.unpack_from(endian + 'Q', data, position + 16)[0]
                        memory_size = struct.unpack_from(endian + 'Q', data, position + 40)[0]
                        writable_loads.append((address, address + memory_size))
                elif kind == 0x6474E552:  # PT_GNU_RELRO
                    address = struct.unpack_from(endian + 'Q', data, position + 16)[0]
                    memory_size = struct.unpack_from(endian + 'Q', data, position + 40)[0]
                    relro.append((address, address + memory_size))
            # RELRO may end at a segment's suffix rather than a page boundary.
            # Rounding its protection outward must not cover writable data in
            # another LOAD or the writable remainder of its own LOAD.
            relro_safe = True
            for start, end in relro:
                rounded_start = start // 16384 * 16384
                rounded_end = (end + 16383) // 16384 * 16384
                for low, high in writable_loads:
                    if (low < start and high > rounded_start) or (
                            high > end and low < rounded_end):
                        relro_safe = False
            checked += 1
            if not loads or min(loads) < 16384 or not relro_safe:
                failures.append(f'{name}: LOAD={loads}, RELRO safe={relro_safe}')
    if not checked:
        raise SystemExit('No 64-bit native libraries found; verify the artifact path')
    if failures:
        raise SystemExit('16 KB alignment failed:\n' + '\n'.join(failures))
    print(f'16 KB ELF/RELRO alignment passed: {checked} native libraries')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    check_archive(parser.parse_args().archive)

"""Verify 64-bit native ELF LOAD alignment in an APK or AAB.

For APKs, also checks the ZIP offset of uncompressed native libraries.
Usage: python tool/check_native_alignment.py path/to/app.aab
"""

import argparse
from pathlib import Path
import struct
import sys
import zipfile


def load_alignments(data):
    if data[:4] != b'\x7fELF' or data[4] != 2 or data[5] != 1:
        raise ValueError('Expected a little-endian ELF64 library')
    offset = struct.unpack_from('<Q', data, 32)[0]
    size, count = struct.unpack_from('<HH', data, 54)
    segments = []
    for index in range(count):
        entry = offset + index * size
        if struct.unpack_from('<I', data, entry)[0] == 1:
            file_offset, virtual = struct.unpack_from('<QQ', data, entry + 8)
            alignment = struct.unpack_from('<Q', data, entry + 48)[0]
            if file_offset % 16384 != virtual % 16384:
                raise ValueError('LOAD offset and virtual address are not congruent at 16KB')
            segments.append(alignment)
    if not segments:
        raise ValueError('No LOAD segments')
    return segments


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('artifact', type=Path)
    args = parser.parse_args()
    failed = 0
    checked = 0
    with zipfile.ZipFile(args.artifact) as archive:
        for entry in archive.infolist():
            if not entry.filename.endswith('.so') or not any(
                f'/lib/{abi}/' in '/' + entry.filename for abi in ('arm64-v8a', 'x86_64')
            ):
                continue
            checked += 1
            try:
                alignments = load_alignments(archive.read(entry))
                if min(alignments) < 16384:
                    raise ValueError(f'LOAD alignments {alignments}')
                if args.artifact.suffix == '.apk' and entry.compress_type == zipfile.ZIP_STORED:
                    with args.artifact.open('rb') as raw:
                        raw.seek(entry.header_offset + 26)
                        name_size, extra_size = struct.unpack('<HH', raw.read(4))
                    data_offset = entry.header_offset + 30 + name_size + extra_size
                    if data_offset % 16384:
                        raise ValueError(f'ZIP data offset {data_offset} is not 16KB aligned')
                print(f'PASS {entry.filename}: min LOAD alignment={min(alignments)}')
            except (ValueError, struct.error) as error:
                failed += 1
                print(f'FAIL {entry.filename}: {error}')
    if not checked:
        print('FAIL: no arm64-v8a/x86_64 libraries found')
        return 1
    print(f'{checked} libraries checked, {failed} failed')
    return int(failed > 0)


if __name__ == '__main__':
    sys.exit(main())

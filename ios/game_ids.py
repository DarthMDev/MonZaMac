"""Record local NSO IDs, so the app won't use tables with mismatched files."""
import sys
from pathlib import Path

exefs, output = map(Path, sys.argv[1:])
ids = {}
for name in ('main', 'sdk'):
    with (exefs / name).open('rb') as source:
        header = source.read(0x60)
    if len(header) != 0x60 or header[:4] != b'NSO0':
        raise SystemExit(f'{name} is not an NSO')
    ids[name] = header[0x40:0x60]
if ids['main'][:8].hex() != 'b1f12fd919eae86a':
    raise SystemExit('The private iOS build requires game version 2.0.2.')
output.write_text(''.join(
    f'static const uint8_t ios_{name}_id[32] = {{' +
    ', '.join(f'0x{byte:02x}' for byte in value) + '};\n'
    for name, value in ids.items()))

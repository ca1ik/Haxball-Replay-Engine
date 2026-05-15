import struct, zlib

with open(r'c:\Users\user\Desktop\Codemations\HBR\12-05-26-20h28-Emman64vsVerone (1).hbr2', 'rb') as f:
    data = f.read()

print('=== HBR2 File Analysis ===')
print(f'Total size: {len(data)} bytes')
print(f'Magic: {data[:4]}')
print(f'Version: {struct.unpack(">I", data[4:8])[0]}')
print(f'Bytes 8-12 as uint32 BE: {struct.unpack(">I", data[8:12])[0]}')
print(f'Bytes 8-12 as uint32 LE: {struct.unpack("<I", data[8:12])[0]}')

print()
print('First 64 bytes hex:')
for i in range(0, 64, 16):
    hex_part = ' '.join(f'{b:02X}' for b in data[i:i+16])
    print(f'  {i:04X}: {hex_part}')

print()
print('Trying various decompression...')
for wbits, offset in [(15, 8), (15, 12), (-15, 8), (-15, 12), (47, 8), (47, 12)]:
    try:
        dec = zlib.decompress(data[offset:], wbits)
        if len(dec) > 0:
            print(f'  wbits={wbits} offset={offset}: SUCCESS! size={len(dec)}')
            print(f'  First 32 bytes: {" ".join(f"{b:02X}" for b in dec[:32])}')
            print(f'  As text: {dec[:32]}')
    except Exception as e:
        pass

# Also check if there's a pattern - maybe no compression, just raw binary frames
# Let's look at what values repeat
print()
print('Byte frequency (top 10):')
from collections import Counter
ctr = Counter(data[8:])
for byte, count in ctr.most_common(10):
    print(f'  0x{byte:02X} ({byte}): {count} times')

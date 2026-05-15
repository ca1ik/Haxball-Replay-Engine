import zlib, struct

# Decompress both files
def read_hbr2(path):
    with open(path, 'rb') as f:
        data = f.read()
    magic = data[:4]
    assert magic == b'HBR2', f"Bad magic: {magic}"
    version = struct.unpack('>I', data[4:8])[0]
    mf = struct.unpack('>I', data[8:12])[0]  # total frames
    compressed = data[12:]
    decompressed = zlib.decompress(compressed, -15)
    return version, mf, decompressed

file1 = r'c:\Users\user\Desktop\Codemations\HBR\12-05-26-20h28-Emman64vsVerone (1).hbr2'
file2 = r'c:\Users\user\Desktop\Codemations\HBR\12-05-26-20h41-VeronevsEmman64 (1).hbr2'

v1, mf1, dec1 = read_hbr2(file1)
v2, mf2, dec2 = read_hbr2(file2)

print(f"File1: version={v1}, frames={mf1}, decompressed={len(dec1)} bytes")
print(f"File2: version={v2}, frames={mf2}, decompressed={len(dec2)} bytes")
print()

# Search for player names in decompressed data
names = [b'Emman64', b'Verone', b'emman', b'verone', b'EMMAN', b'VERONE']
for name in names:
    pos1 = dec1.find(name)
    pos2 = dec2.find(name)
    print(f"  '{name.decode()}' in file1: offset {pos1}, in file2: offset {pos2}")

print()
print("First 100 bytes of dec1 (hex):")
for i in range(0, 100, 16):
    h = ' '.join(f'{b:02X}' for b in dec1[i:i+16])
    print(f"  {i:04X}: {h}")

"""
Check last events of file1 to determine event format (absolute or delta frame).
If last event has frame ~44763, events use absolute frames.
If last event has delta ~1 (small), events use delta.
"""
import zlib, struct

def read_hbr2(path):
    with open(path, 'rb') as f: d=f.read()
    fc = struct.unpack('>I', d[8:12])[0]
    dec = zlib.decompress(d[12:], -15)
    return fc, dec

fc1, dec1 = read_hbr2('12-05-26-20h28-Emman64vsVerone (1).hbr2')
fc2, dec2 = read_hbr2('12-05-26-20h41-VeronevsEmman64 (1).hbr2')

print(f"File1: fc={fc1}, dec_size={len(dec1)}")
print(f"File2: fc={fc2}, dec_size={len(dec2)}")

# Show last 200 bytes of each file
print("\nFile1 last 200 bytes:")
data = dec1[-200:]
for i in range(0, 200, 16):
    h = ' '.join(f'{data[i+j]:02x}' for j in range(16) if i+j < 200)
    a = ''.join(chr(data[i+j]) if 32<=data[i+j]<127 else '.' for j in range(16) if i+j < 200)
    print(f"  {len(dec1)-200+i:6d}: {h:<48} {a}")

print("\nFile2 last 200 bytes:")
data = dec2[-200:]
for i in range(0, 200, 16):
    h = ' '.join(f'{data[i+j]:02x}' for j in range(16) if i+j < 200)
    a = ''.join(chr(data[i+j]) if 32<=data[i+j]<127 else '.' for j in range(16) if i+j < 200)
    print(f"  {len(dec2)-200+i:6d}: {h:<48} {a}")

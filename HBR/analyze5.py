"""
Find where room state ends and frame events begin in both files.

The room state includes:
- Shared stadium (~11056 bytes starting at offset 25)
- Player states (differ between files, include player names)
- Score/game state

After room state, frame events are: varint(delta) + uint16(type) + event_data

Strategy: Player names appear at offsets ~12000-13000.
After all player data, there should be score fields, then frame events start.

Let me look at what comes after the last player name.
"""
import zlib, struct, re

def read_hbr2(path):
    with open(path, 'rb') as f:
        data = f.read()
    version = struct.unpack('>I', data[4:8])[0]
    frame_count = struct.unpack('>I', data[8:12])[0]
    decompressed = zlib.decompress(data[12:], -15)
    return version, frame_count, decompressed

file1 = r'c:\Users\user\Desktop\Codemations\HBR\12-05-26-20h28-Emman64vsVerone (1).hbr2'
file2 = r'c:\Users\user\Desktop\Codemations\HBR\12-05-26-20h41-VeronevsEmman64 (1).hbr2'

v1, fc1, dec1 = read_hbr2(file1)
v2, fc2, dec2 = read_hbr2(file2)

# Find last player name in each file
names_b1 = [b'Emman64', b'Verone', b'Neymar', b'player']
names_b2 = [b'Emman64', b'Verone', b'Neymar', b'player']

def find_all(data, pattern):
    results = []
    pos = 0
    while True:
        idx = data.find(pattern, pos)
        if idx == -1:
            break
        results.append(idx)
        pos = idx + 1
    return results

# Find all occurrences of player names
all_names = {}
for name in [b'Emman64', b'Verone']:
    f1_locs = find_all(dec1, name)
    f2_locs = find_all(dec2, name)
    all_names[name] = (f1_locs, f2_locs)
    print(f"'{name.decode()}' in file1: {f1_locs[:5]}")
    print(f"'{name.decode()}' in file2: {f2_locs[:5]}")
    print()

# The last occurrence of any player name should be near the end of room state
all_f1_name_positions = []
all_f2_name_positions = []
for name, (f1_locs, f2_locs) in all_names.items():
    all_f1_name_positions.extend(f1_locs)
    all_f2_name_positions.extend(f2_locs)

if all_f1_name_positions:
    last_name_f1 = max(all_f1_name_positions)
    print(f"Last player name in file1 at: {last_name_f1}")
    print(f"Bytes around it: {dec1[last_name_f1-10:last_name_f1+30].hex()}")

if all_f2_name_positions:
    last_name_f2 = max(all_f2_name_positions)
    print(f"\nLast player name in file2 at: {last_name_f2}")
    print(f"Bytes around it: {dec2[last_name_f2-10:last_name_f2+30].hex()}")

# Now find where file1 and file2 converge again after the player section
# Looking for another long common region after offset 13500
print("\n\nLooking for post-player-data common regions (offsets 13000-20000):")
i = 13000
streak_start = None
streak_len = 0
for i in range(13000, min(len(dec1), len(dec2), 20000)):
    if dec1[i] == dec2[i]:
        if streak_start is None:
            streak_start = i
        streak_len += 1
    else:
        if streak_len > 50:
            print(f"  Common region at {streak_start}: {streak_len} bytes")
            print(f"    preview: {dec1[streak_start:streak_start+30].hex()}")
        streak_start = None
        streak_len = 0

# Look at region just after last player name in file1 to understand end of room state
print("\n\nFile1 bytes 13200-13500 (should be near end of room state):")
for i in range(13200, 13500, 16):
    h = dec1[i:i+16].hex()
    print(f"  {i:6d}: {h}")

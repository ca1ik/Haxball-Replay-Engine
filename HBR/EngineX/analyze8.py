"""
Approach: Find room state boundary by scanning for valid frame event sequences.

A frame event is: varint(delta) + uint16(event_type_id) + event_data

After room state ends, the next bytes should be parseable as valid events.
Valid event types are small integers (typically 0-50).

Strategy:
1. We know room state ends SOMEWHERE between offset 12000-15000 (player data region)
2. Try parsing as events from various offsets, checking if the pattern is consistent
3. The offset where we get a long valid event chain = start of events

Also: looking at the Dl() function, it reads UNTIL the buffer is exhausted.
The Gm() function reads one event. If we know what Gm reads, we can validate.

From source: Gm(a) likely reads:
  delta = Ab() [varint]  
  event_type = Ob() [uint16]
  event_data = ... (variable, depends on event_type)

Event types and their data sizes would help. But we don't know them all.

ALTERNATIVE SIMPLER APPROACH:
=================================
Since we don't need to PARSE the room state perfectly, 
we can find the room state boundary by COMPARING the two files differently.

Key insight:
- dec1 = [header][room_state_1][events_1]
- dec2 = [header][room_state_2][events_2]

The room states are DIFFERENT (different player positions, different match metadata)
BUT have COMMON STRUCTURE (same stadium, same player list).

If room_state_1 and room_state_2 have the same SIZE (which they might since same players/stadium),
then: events_1 starts at offset X in dec1, events_2 starts at offset X in dec2.

Let's check if room states have same size by estimating from file sizes:
"""
import zlib, struct

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

print(f"File1: fc={fc1}, dec_size={len(dec1)}")
print(f"File2: fc={fc2}, dec_size={len(dec2)}")

# Events-only size = dec_size - header_and_room_state_size
# If header+room_state = R bytes, then:
# events1 = dec1 - R
# events2 = dec2 - R
# events1/fc1 = events2/fc2 (if bytes per frame is constant)
# (dec1-R)/fc1 = (dec2-R)/fc2
# This is the same equation as before... but gave wrong result.
# The issue is events_per_frame is NOT constant between the two matches.

# So we need another approach.

# BEST APPROACH: Use the SAME STADIUM ASSUMPTION
# Both files have identical bytes from offset 25 to 11080.
# This 11056-byte common block is entirely within the room state (stadium data).
# The room state ENDS at some offset E > 11080 (player data follows stadium).

# Player names in file1: Verone at 12416, Emman64 at 12985
# Player names in file2: Verone at 12731, Emman64 at 13101

# The player section lengths DIFFER between the files because of recording 
# different player states! File2 has players at slightly higher offsets.
# This means room_state_sizes DIFFER between the two files.

# BUT: the NAME/SIZE difference is small (12416 vs 12731 for first name = ~315 bytes diff)
# 
# Let me check: what bytes SURROUND the player names?

print("\nFile1 context around Verone (12416):")
for i in range(12400, 12450, 16):
    h = ' '.join(f'{dec1[i+j]:02x}' for j in range(16) if i+j < len(dec1))
    a = ''.join(chr(dec1[i+j]) if 32<=dec1[i+j]<127 else '.' for j in range(16) if i+j < len(dec1))
    print(f"  {i:6d}: {h:<48} {a}")

print("\nFile1 context around Emman64 (12985):")
for i in range(12969, 13020, 16):
    h = ' '.join(f'{dec1[i+j]:02x}' for j in range(16) if i+j < len(dec1))
    a = ''.join(chr(dec1[i+j]) if 32<=dec1[i+j]<127 else '.' for j in range(16) if i+j < len(dec1))
    print(f"  {i:6d}: {h:<48} {a}")

print("\nFile2 context around Verone (12731):")
for i in range(12715, 12765, 16):
    h = ' '.join(f'{dec2[i+j]:02x}' for j in range(16) if i+j < len(dec2))
    a = ''.join(chr(dec2[i+j]) if 32<=dec2[i+j]<127 else '.' for j in range(16) if i+j < len(dec2))
    print(f"  {i:6d}: {h:<48} {a}")

print("\nFile2 context around Emman64 (13101):")
for i in range(13085, 13140, 16):
    h = ' '.join(f'{dec2[i+j]:02x}' for j in range(16) if i+j < len(dec2))
    a = ''.join(chr(dec2[i+j]) if 32<=dec2[i+j]<127 else '.' for j in range(16) if i+j < len(dec2))
    print(f"  {i:6d}: {h:<48} {a}")

# Look for any text AFTER the player names that could be fixed room-state markers
# then look what comes after (should be frame events)
print("\nFile1 bytes 13200-13500:")
for i in range(13200, 13500, 16):
    h = ' '.join(f'{dec1[i+j]:02x}' for j in range(16) if i+j < len(dec1))
    a = ''.join(chr(dec1[i+j]) if 32<=dec1[i+j]<127 else '.' for j in range(16) if i+j < len(dec1))
    print(f"  {i:6d}: {h:<48} {a}")

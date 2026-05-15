"""
Deeper analysis: Find room state size by examining the binary structure more carefully.

Player names at 12000-13000 in both files (room state).
The "last player name" at 449966 in file1 is in a CHAT MESSAGE (in-game event), not room state!
"n goal by Emman64 !" is a chat message event in the frame stream.

So room state ends BEFORE offset 13000 (roughly).

Let me examine what comes just after the player data section.
From the strings found: after player names come some binary data.

The room state should end with player kick/ban list (kb[1].ja, kb[2].ja) entries
which are color data (just small arrays).

Let me compare file1 and file2 at various offsets to find where they re-converge
in a sustained way after the player section.
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

# The room state includes player data ending around offset 13000-14000
# Let's look at what a MINIMAL "event-free" region looks like
# Check byte-by-byte differences around 13000-14500

print("Difference map from offset 11000 to 16000:")
print("'=' = same, '.' = different")

for block_start in range(11000, 16000, 64):
    chunk_same = sum(1 for i in range(block_start, min(block_start+64, len(dec1), len(dec2))) 
                     if dec1[i] == dec2[i])
    pct = chunk_same / 64 * 100
    marker = '=' * (chunk_same // 4) + '.' * ((64-chunk_same) // 4)
    print(f"  {block_start:6d}: {pct:5.1f}%  {marker}")

# Now look for where both files have the exact same bytes for a long stretch
# after the player section - that would be the START of frame events
# (because frame events are DIFFERENT per game)
# 
# Wait... the FRAME EVENTS will be completely different per game!
# So we should look for where file1 and file2 STOP being similar -> that's end of room state
# 
# The room state is ALMOST identical (same stadium, similar player layouts)
# but differs in player names, positions, scores, etc.
# The frame events are completely different.
# 
# So: find the LAST common region before the divergence into frame events.
print("\n\nLooking for transition from room-state to frame-events...")
print("Checking byte similarity in sliding 32-byte windows:")

transition_guess = None
for i in range(11050, 16000):
    w1 = dec1[i:i+32]
    w2 = dec2[i:i+32]
    same = sum(a == b for a, b in zip(w1, w2))
    pct = same / 32 * 100
    if i % 100 == 0:
        print(f"  {i}: {pct:.0f}% same")

# Let me check specific boundaries:
# After the stadium section (ends ~11080), player section begins
# Player section likely ends around 13000-14000 based on name locations
# Let's check offset 13300-13500 more carefully

# The room state ends when we've read:
# - room header (uc + Y + te + cc)
# - fa.ja() [room state]:
#   - jc (room name string)
#   - Pc (bool)
#   - ib (uint32)
#   - Da (uint32)
#   - ce (int16)
#   - Zc (uint8)
#   - yd (uint8)
#   - S: h.ja() [stadium]
#   - bool K
#   - K.ja() [optional game state O.ja()]
#   - players: I[].va()
#   - kb[1].ja() and kb[2].ja() [team colors]

# Based on player names at 12416 (Verone) and 12985 (Emman64) in file1
# Player entry (ea.va()):
#   Md = M() uint32
#   Xg = B() uint8
# That's only 5 bytes per player!

# Actually ea.va() is the SPECTATOR/TEAM player entry in the room state
# But ea itself has more data. Let me re-check...
# ea.ua() writes: l(cb?1:0) + O(Jb) + ... many fields
# ea.va() reads: Md=M(), Xg=B() -> just 5 bytes (uint32 + uint8)
# Wait that seems too small.

# Actually looking more carefully:
# this.I[d++] = ea (player list)
# ea.va(a, b) reads players
# And separately: the game state K has the physics positions

# Let me try a different approach: find the boundary empirically
# by looking at what offset difference fc1 vs fc2 corresponds to in the files

# If decompressed = header + room_state + events
# And events are approximately (fc * avg_bytes_per_event)
# Then room_state_size ≈ dec_size - fc * avg_bytes_per_event - header_size

# Estimate average bytes per event from ratio of events to (dec - initial estimate)
# Initial estimate of header: ~12 bytes (2+4+4+varint)
# room_state_size ≈ 13500 (rough guess)

header_estimate = 14  # bytes consumed by Cq (uc + Y + te + cc approximately)

# Use ratio: (dec1_size - header - room) / fc1 = (dec2_size - header - room) / fc2
# Solve for room:
# (dec1 - h - r) * fc2 = (dec2 - h - r) * fc1
# dec1*fc2 - h*fc2 - r*fc2 = dec2*fc1 - h*fc1 - r*fc1
# r*(fc1-fc2) = dec1*fc2 - dec2*fc1 - h*(fc2-fc1)
# r = (dec1*fc2 - dec2*fc1) / (fc1-fc2) - h

d1, d2 = len(dec1), len(dec2)
room_plus_header = (d1*fc2 - d2*fc1) / (fc1-fc2)
room_size = room_plus_header - header_estimate

print(f"\n\nEstimated room state + header size: {room_plus_header:.0f} bytes")
print(f"Estimated room state size: {room_size:.0f} bytes")
print(f"\nThis means frame events start at approximately offset: {room_plus_header:.0f}")
print(f"\nFile1 frame events bytes: {d1 - room_plus_header:.0f} = {d1 - room_plus_header:.0f}/44763 = {(d1-room_plus_header)/fc1:.2f} bytes/event")
print(f"File2 frame events bytes: {d2 - room_plus_header:.0f} = {d2 - room_plus_header:.0f}/41645 = {(d2-room_plus_header)/fc2:.2f} bytes/event")

"""
HBR2 Merger - Birleştirici

HBR2 format (source-code reversing'den):
  - magic: 'HBR2' (4 bytes)
  - version: uint32 BE (4 bytes)
  - frameCount: uint32 BE (4 bytes)
  - compressed_payload: pako.deflateRaw(...) -> inflate with zlib wbits=-15

Decompressed payload:
  - initial state bytes (room/map initial snapshot)
  - followed by stream of (frameNum varint, action data...)

Replay player'ı (Jb sınıfı): her kare şöyle okunuyor:
  this.hg += a  (a = varint)
  this.Lc.Ob() -> uint16 (action id)
  this.gg = m.fh(this.Lc) -> action parse
  this.gg.P = a (uint16)

Birleştirme stratejisi:
- File1 tüm bytes'ı aynen koruyoruz
- File2'nin decompressed payload'unu alıyoruz:
  - Ön kısım (initial state) atılacak
  - Frame stream kısmı aynen ekleniyor AMA frame offset'leri düzeltilecek
  
PROBLEM: Frame stream'deki "hg increment" değerleri göreceli (delta) olduğu için
mevcut frame sayısından bağımsız. Dolayısıyla file2'nin frame stream'ini
doğrudan file1'in frame stream'inin sonuna ekleyebiliriz ve frame numaraları
zaten doğru devam edecektir - çünkü haxball player'ı her seferinde delta okur.

ANCAK: Yeni bir decompressed payload için initial state file1'den, 
frame stream ise file1 + file2'den oluşmalı.

Aslında en basit yaklaşım:
- File1 decompressed: [initial_state] + [frames1]
- File2 decompressed: [initial_state2] + [frames2]

Bunu player (Jb class) okuma sırasına göre anlayabilmek için:
initial state = özellikle biten noktayı belirlemek gerekiyor.

Initial state'in sonu: decompressed data içinde frame stream başlangıcını bulmak.

Frame stream okuma: Jb.Dl():
  a.o.byteLength - a.a > 0  varsa:
    a = this.Lc.Ab() -> varint (frame delta)
    this.hg += a
    a = this.Lc.Ob() -> uint16 (event type)  
    this.gg = m.fh(this.Lc)

Yani frame stream şu şekilde devam ediyor:
  [varint: frameDelta] [uint16: eventType] [event_data...]
  ...

Initial state uzunluğunu bulmak için en iyi yöntem:
- İlk player/map adı nerede geçiyor? -> player adlarının bulunduğu offset'e bakmak
- Veya: ilk uint16'yı okuduktan sonra event parse etmeye çalışmak

Daha güvenli yaklaşım: 
Player constructor'ında: 
  this.Lc = new F(new DataView(c.buffer...))
  this.Cq(this.Lc) -> initial state parse
  c = this.Lc.sb() -> geri kalan
  this.Lc = new F(new DataView(...))
  this.ui() -> reset

Yani initial state tamamen bir chunk ve sonrası frame stream.

Initial state chunk'ının uzunluğunu bulmak:
- File1 ve File2'nin decompressed data'sını karşılaştırıp 
  diverge ettiği noktayı bul (bu tam da farklı maç başlangıçlarını gösterir)
  
Alternatif basit yaklaşım:
- İki dosyanın decompressed payload'larını byte-by-byte karşılaştır
- İlk farklı byte = initial state'in sonu (ya da yakını)

Bu yaklaşım ile initial state boundary'yi belirleyip 
file2'nin frame bytes'ını file1'in sonuna ekleyebiliriz.
"""

import zlib, struct

def read_hbr2(path):
    with open(path, 'rb') as f:
        data = f.read()
    assert data[:4] == b'HBR2'
    version = struct.unpack('>I', data[4:8])[0]
    frame_count = struct.unpack('>I', data[8:12])[0]
    decompressed = zlib.decompress(data[12:], -15)
    return version, frame_count, decompressed

def write_hbr2(path, version, frame_count, decompressed):
    compressed = zlib.compress(decompressed, 9)[2:-4]  # raw deflate
    header = b'HBR2'
    header += struct.pack('>I', version)
    header += struct.pack('>I', frame_count)
    with open(path, 'wb') as f:
        f.write(header + compressed)
    print(f"Written: {path} ({len(header + compressed)} bytes)")

file1 = r'c:\Users\user\Desktop\Codemations\HBR\12-05-26-20h28-Emman64vsVerone (1).hbr2'
file2 = r'c:\Users\user\Desktop\Codemations\HBR\12-05-26-20h41-VeronevsEmman64 (1).hbr2'
out   = r'c:\Users\user\Desktop\Codemations\HBR\merged.hbr2'

v1, fc1, dec1 = read_hbr2(file1)
v2, fc2, dec2 = read_hbr2(file2)

print(f"File1: version={v1}, frames={fc1}, dec_size={len(dec1)}")
print(f"File2: version={v2}, frames={fc2}, dec_size={len(dec2)}")

# Find where decompressed data diverges (= end of shared initial state)
min_len = min(len(dec1), len(dec2))
diverge = None
for i in range(min_len):
    if dec1[i] != dec2[i]:
        diverge = i
        break

if diverge is None:
    diverge = min_len

print(f"\nDecompressed data diverges at byte offset: {diverge}")
print(f"This is the initial state header boundary (common prefix)")

# The initial state of file1 ends at 'diverge' (roughly)
# But actually initial state can differ between two separate matches.
# We keep file1's full initial state and append file2's frame stream.
# 
# Better: find the actual initial state boundary by looking for 
# the first varint+uint16 pair that makes sense as a frame event.
# 
# However, since both replays are separate full games, the initial states
# will be different (different player positions/lineup).
# We need to KEEP file1 fully, then append file2's events with adjusted timing.
#
# The player reads: initial_state first via Cq(), then frame stream via Dl().
# The frame stream in HBR2 is: varint(delta) + uint16(event_type_id) + event_data
# 
# Since event types are registered with incrementing IDs and the stream is 
# self-contained, we can simply concatenate the frame streams.
# 
# The trick: we need to find where the initial state ends in each file.
# Initial state = room state snapshot (fa.ja())
# After that comes the frame stream.
# 
# The simplest heuristic: scan from the beginning reading as varint+uint16 pairs
# If we can parse N consecutive valid events, that's where frame stream starts.

# Actually looking at the source more carefully:
# Jb constructor (replay player):
#   c = pako.inflateRaw(a.sb()) -> decompressed
#   this.Lc = new F(new DataView(c.buffer...))
#   this.Cq(this.Lc)  <- reads initial state from Lc
#   c = this.Lc.sb()  <- gets remaining bytes after initial state
#   this.Lc = new F(new DataView(c.buffer...)) <- reset to remaining
#   this.ui()  <- starts playing
#
# So initial state is read by Cq() which calls fa.ja(this.Lc) [room state parse]
# After that, all remaining bytes are the frame stream.
#
# Strategy: parse the initial state from dec1 (we need to know its length),
# then know where frame stream starts.
# 
# Since we can't easily parse the binary room state without replicating the 
# entire haxball state machine, we use the DIVERGENCE POINT as a proxy.
# 
# But actually for two completely different matches, initial states will differ
# from the very start (different player lists, scores, etc.)
# So diverge ≈ 0 is possible.
#
# Better approach: look at where common "FUTSAL" or stadium name text ends,
# which is likely in the initial state.

# Let's search for where the frame stream starts by looking for a known pattern.
# Frame events: first byte of frame stream is a varint for frame delta.
# After initial state, frames start at delta 0 typically.
# 
# Actually: initial state ends, then Lc is reset and ui() calls:
# this.Lc.a = 0; this.T.ja(this.Lc) [loads room from position 0]
# So the "remaining" bytes BECOME the full Lc buffer.
# Dl() reads from Lc:  varint(hg_delta) + Ob() (uint16) + action.
#
# Key insight from Dl():
#   a = this.Lc.Ab()  <- reads VARINT
#   this.hg += a
#   a = this.Lc.Ob()  <- reads uint16 (little-endian since Sa=false)
#
# So each frame event is: [varint][uint16][...event bytes...]
# 
# The initial state in `Lc` (after the reset) includes the initial room state
# followed by frame events. Lc is loaded from `c = this.Lc.sb()` which is 
# ALL remaining bytes after Cq() parsed the initial state.
# 
# Then T.ja(this.Lc) reads the room state from the START of those remaining bytes.
# After T.ja(), Lc.a points past the room state, and then Dl() reads frames from there.
#
# This means we need to know: 
# 1. length of room state in remaining bytes (= T.ja() parse length)
# 2. Then frame events follow
#
# Without implementing the full parser, the safest working approach is:
# Find the initial state boundary empirically by looking at where player names appear
# and working backward/forward to find a consistent frame boundary.
#
# SIMPLEST WORKING APPROACH for haxball merger:
# Since both files are complete standalone replays, we can treat the ENTIRE
# decompressed payload of file2 as "events" that should be played after file1.
# But the player needs a valid initial state + frame stream.
#
# THE CORRECT APPROACH based on source analysis:
# - Read file1 decompressed as-is (valid complete replay)
# - Read file2 decompressed as-is (valid complete replay)  
# - Create merged: file1 decompressed + file2 decompressed
# This won't work because file2 starts with its own initial state.
#
# REAL SOLUTION: We need to append only the FRAME STREAM bytes of file2 to file1.
# The initial state boundary = right before where Dl() starts reading frames.
# 
# From the binary analysis:
# File1 decompressed first 32 bytes:
# 00 08 FD 47 01 C4 26 01 EA 25 02 86 20 02 DB 3D
# 01 E9 30 01 DF 12 02 DF 26 02 17
# Then: 46 55 54 53 41 4C ... = "FUTSAL FUSION LEAGUE 4"
# This is the STADIUM NAME in the initial state!
# 
# Player names appear at offset ~12000-13000
# Stadium data is parsed by h.Kr() and h.Kh() -> initial state is complex binary
# 
# For a PRACTICAL merger, I'll use the following approach:
# - Keep file1 fully intact (initial state + frame stream)
# - Find where frame stream starts in file2 (the stream events begin after initial state)
# - Append file2's frame stream to file1's frame stream
# - The result will play file1 match, then continue into file2 match events
#
# To find frame stream start in dec2:
# Looking at the decompressed sizes vs frame counts:
# File1: 619946 bytes, 44763 frames -> ~13.8 bytes/frame
# File2: 539644 bytes, 41645 frames -> ~12.9 bytes/frame
# So initial state ≈ dec_size - frames*avg_bytes_per_frame
# But this is imprecise.
#
# PRACTICAL APPROACH: Use the divergence point to estimate initial state size.
# Both files have the same stadium/map (FUTSAL FUSION LEAGUE 4 based on bytes).
# So common prefix = shared initial state up to where player-specific data starts.

print(f"\nCommon prefix (shared initial state): {diverge} bytes")

# Check if initial state is roughly the same size in both
# by searching for a sentinel pattern
# After initial state, frame stream begins with small varints (frame deltas)
# Let's look at bytes around diverge point
print("\nFile1 around diverge point:")
start = max(0, diverge - 8)
end = min(len(dec1), diverge + 24)
for i in range(start, end, 16):
    chunk = dec1[i:i+16]
    h = ' '.join(f'{b:02X}' for b in chunk)
    marker = ' <-- DIVERGE' if i <= diverge < i+16 else ''
    print(f"  {i:06X}: {h}{marker}")

print("\nFile2 around diverge point:")
for i in range(start, end, 16):
    chunk = dec2[i:i+16]
    h = ' '.join(f'{b:02X}' for b in chunk)
    marker = ' <-- DIVERGE' if i <= diverge < i+16 else ''
    print(f"  {i:06X}: {h}{marker}")

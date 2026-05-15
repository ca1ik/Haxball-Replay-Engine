"""
HBR2 Merger - Detailed Analysis

Looking at the decompressed bytes:
File1 first bytes: 00 08 FD 47 01 C4 26 01 EA 25 02 86 20 02 DB 3D ...
File2 first bytes: 00 08 EA 51 02 E3 51 02 F8 1D 02 C9 07 01 9C 1B ...

Pattern at offset 0: 00 = seems like first byte
At offset 1: 08 = same in both!
At offset 2: FD vs EA -- diverge

Looking at source: ac.stop() (recorder stop):
  this.Nd.o.setUint16(0, this.Xm, this.Nd.Sa)  <- writes uint16 at position 0
  this.Nd.Vb(this.Df.Sb())  <- appends frame stream data

Jb (reader) constructor:
  c = pako.inflateRaw(a.sb())  <- full decompressed
  this.Lc = new F(new DataView(c.buffer...))
  this.Cq(this.Lc)  <- parse initial
  c = this.Lc.sb()  <- remaining
  this.Lc = new F(new DataView(c.buffer...), false)
  this.ui()

this.Cq calls:
  this.uc = a.Ob()  <- uint16 (2 bytes) = Xm (some counter)
  this.Y = a.hb()   <- uint32 (4 bytes) = mf (frame rate?)
  this.te = a.hb()  <- uint32 (4 bytes)
  this.cc = a.Ab()  <- varint
  this.Xc = 10
  for loop: this.T.ja(a) [room state]
  for loop: Cg(Gm(a)) [events]

Wait, looking at qq() (replay load from network):
  a = pako.inflateRaw(a.sb())
  a = new F(new DataView(a.buffer...))
  this.uc = a.Ob()  <- uint16
  this.Y = a.hb()   <- uint32  
  this.te = a.hb()  <- uint32
  this.cc = a.Ab()  <- varint
  this.Xc = 10
  this.T.ja(a)     <- room state
  for (this.T.ja(a); 0 < a.o.byteLength - a.a;) this.Cg(this.Gm(a))

So the structure after decompression is:
  [uint16: uc]  (2 bytes)
  [uint32: Y]   (4 bytes, current frame)
  [uint32: te]  (4 bytes)
  [varint: cc]  
  [room state: T.ja()]
  [frame events: ...]

The room state T.ja() is fa.ja() which is the complete room snapshot.
After that come the replay events (Gm reads: uint32 frame, uint16 da, uint16 P, int16 ue, action).

Let's verify:
File1: 00 08 FD 47 01 C4 26 ...
  uint16 at 0: 0x0008 = 8 (uc)  -- but wait uint16 is LE or BE?
  
Looking at F constructor: this.Sa = b (default false = little-endian)
But Jb constructor: this.Lc = new F(new DataView(...), !1) -> Sa=false = LE
  
So:
  offset 0: uint16 LE = 0x0800 = 2048? or 0x0008 = 8?
  bytes: 00 08 -> LE uint16 = 0x0800 = 2048
  
Hmm, offset 0-1: 00 08 -> LE: low=00, high=08 -> 0x0800 = 2048
  offset 2-5: uint32 LE: FD 47 01 C4 -> 0xC401_47FD = 3288401917? Too large.
  
Wait, let me reread. In qq():
  this.uc = a.Ob()  <- uint16
  this.Y = a.hb()   <- uint32

Ob() = getUint16(this.a, this.Sa) where Sa=false=LE
hb() = getUint32(this.a, this.Sa)

File1 bytes:
  0-1: 00 08 -> LE uint16 = 0x0800 = 2048 (uc)
  2-5: FD 47 01 C4 -> LE uint32 = 0xC401_47FD

Hmm, that's weird. But actually for a replay file, these are stored by the recorder:
ac.stop():
  this.Nd.o.setUint16(0, this.Xm, this.Nd.Sa)  <- Sa = this.Nd.Sa
  
The recorder's Nd buffer has Sa=? Let's check ac constructor... it's not shown directly.
But looking at how files are saved: b.Og('HBR2') which calls writeString - uses BE.
Then b.tb(this.version) -> tb() = O() = setUint32 BE.

So the header is BE. But the decompressed content might be LE since Jb reads with Sa=false.

Actually: 0x0008 in LE = bytes 08 00. But bytes are 00 08.
As BE: 00 08 = 8. As LE: bytes 00 08 = 0x0800 = 2048.

Let me check: in the Nd buffer (recorder), what's Sa?
Looking at write: b.tb() -> setUint32 at offset with this.Sa
In Jb: this.Lc = new F(new DataView(...), !1) -> Sa=false=LE

So reader uses LE. But bytes 00 08:
- Interpret as LE uint16: value = 8 (bytes: 08 00 = 8 in LE, 00 08 = 0x800 in LE)
Wait: LE uint16 from bytes [00, 08]:
  DataView.getUint16(offset, true) where true=LE
  = byte[0] + byte[1]*256 = 0 + 8*256 = 2048

So uc = 2048 for file1.

For file2: bytes 00 08 -> uc = 2048 also! (same first two bytes)

Then Y (uint32 LE):
File1: bytes 2-5: FD 47 01 C4 -> LE = 0xFD + 0x47<<8 + 0x01<<16 + 0xC4<<24
     = 253 + 18176 + 65536 + 3288334336 = hmm, very large
     
That can't be right for frame count. Let me re-examine.

Actually wait - looking at the ac.stop() code more carefully:
  this.Nd.o.setUint16(0, this.Xm, this.Nd.Sa)
This writes at offset 0 of Nd buffer after all data is written.
The initial write position when recording starts would be:
  ... first some header data is written, then setUint16 at 0 overwrites the first 2 bytes.

Looking at constructor of ac: it creates Nd buffer and writes initial state to it.
The initial state is: T.ga(c) [room state], then events are appended.
Then on stop(), position 0 is overwritten with Xm (current frame count at end).

So structure of Nd before deflate:
  [placeholder uint16 at start]
  [room state: T.ga()]  
  [events: ...]
  -> stop() overwrites bytes 0-1 with current frame count

This matches what qq() reads:
  uc = uint16
  Y = uint32 ... wait that doesn't match "setUint16 at 0 then room state"
  
Unless Y is the first field of T.ga() (room state)!

Let me reconsider: maybe ac writes:
  Nd = empty buffer
  Nd.o.setUint16(0, Xm, Sa) -> 2 bytes at position 0 (placeholder)
  Nd starts at a=0, setUint16 just writes at 0 without advancing a
  Then Nd.Vb(this.Df.Sb()) -> appends the frame stream
  
And Df is a separate buffer that recorded the initial state + events.
Actually Df = this.Df.Sb() which is the recorder's event buffer.

qq() reads differently from ac:
  uc = Ob() = uint16 [2 bytes]
  Y = hb() = uint32 [4 bytes]  
  te = hb() = uint32 [4 bytes]
  cc = Ab() = varint
  T.ja()
  events...

So the saved format IS:
  uint16: uc (2 bytes)
  uint32: Y  (4 bytes) 
  uint32: te (4 bytes)
  varint: cc
  room_state
  events

File1 decompressed:
  bytes 0-1: 00 08 (LE uint16 = 2048) <- uc
  bytes 2-5: FD 47 01 C4 (LE uint32 = ?) <- Y
  
  FD=253, 47=71, 01=1, C4=196
  LE = 253 + 71*256 + 1*65536 + 196*16777216 = 253 + 18176 + 65536 + 3288334336
  = 3288418301 -- too large

Hmm. Maybe Sa=true for the recorder? Let me look at w.ha() default:
  null == b && (b = !1) -> Sa=false by default

But wait, the RECORDER (ac) might use Sa=true (big-endian).
Jb reads with Sa=false (LE).

This mismatch would be a bug... unless the recorder uses Sa=false too.

Actually looking at Nd: it's passed as parameter. In ac constructor it's:
  this.Nd = ...  (not shown, but inferred)

Let me just try parsing as if uc=2 bytes (BE), Y=4 bytes (BE):
File1 bytes 0-5: 00 08 FD 47 01 C4
  uc BE = 0x0008 = 8
  Y BE = 0xFD4701C4 = 4249387460 -- still too large

Hmm. Maybe uc is the recorder's Xm which is... not the frame count from the file header?

Wait - the FILE HEADER already has frameCount! bytes 8-11 of the HBR2 file.
File1 header frameCount = 44763 (verified earlier).
So Y in the decompressed might be something else, or the format is different.

Looking at ac.stop() again:
  this.Nd.o.setUint16(0, this.Xm, this.Nd.Sa)  
  this.Nd.Vb(this.Df.Sb())
  var a = pako.deflateRaw(this.Nd.Sb())
  b = w.ha(a.byteLength + 32)
  b.Og('HBR2')
  b.tb(this.version)
  b.tb(this.hj.Y - this.ah)   <- frameCount in file header
  b.Vb(a)
  return b.Sb()

So decompressed = Nd.Sb() = [uint16:Xm][Df.Sb()...]
And Df is the recorder buffer that contains:
  - When recording starts (at room creation): T.ga(c) [initial state] written to Df  
  - Then each event is appended to Df
  
And the Jb (reader) reads from qq() which reads decompressed network packets, 
NOT from the file replay loader!

The FILE replay loader is Jb constructor:
  c = pako.inflateRaw(a.sb())
  this.Lc = new F(new DataView(c.buffer...), !1)  <- Sa=false, LE
  this.Cq(this.Lc)
  c = this.Lc.sb()
  this.Lc = new F(new DataView(c.buffer...), !1)
  this.ui()

this.Cq(this.Lc):
  this.uc = a.Ob()  <- uint16 LE
  this.Y = a.hb()   <- uint32 LE (but wait hb uses Sa)

Actually F.hb() uses this.Sa which is false=LE! But:
  getUint32(this.a, this.Sa) = getUint32(offset, false) = BIG-ENDIAN!

DataView: when littleEndian=false (or undefined), it's Big-Endian.
So this.Sa=false means BIG-ENDIAN in DataView terms!

Let me re-verify:
  w.ha(a, b): b=!1 (false) -> Sa=false
  w.l(x): setUint8 (no endian)
  w.Ub(x): setUint16(offset, x, this.Sa) = setUint16(offset, x, false) = BE
  w.O(x): setUint32(offset, x, this.Sa) = setUint32(offset, x, false) = BE

And F (reader):
  F.Ob(): getUint16(this.a, this.Sa) = getUint16(offset, false) = BE
  F.hb(): getUint32(this.a, this.Sa) = getUint32(offset, false) = BE

So EVERYTHING is BIG-ENDIAN when Sa=false (default)!

Now re-parse File1 decompressed:
  bytes 0-1: 00 08 -> BE uint16 = 8 (uc)
  bytes 2-5: FD 47 01 C4 -> BE uint32 = 0xFD4701C4

Hmm, 0xFD4701C4 = 4249387460 still very large for Y (current frame at start of recording = 0 usually)

Unless this ISN'T what Cq reads. Let me trace again...

Actually Cq in the source code... I saw it referenced but not directly shown.
It calls this.Cq(this.Lc) in Jb constructor.

From server-side (Lb.prototype):
  qq: function(a):  <- network packet handler
    a = pako.inflateRaw(a.sb())
    a = new F(new DataView(a.buffer..))
    this.uc = a.Ob()
    this.Y = a.hb()
    this.te = a.hb()
    this.cc = a.Ab()
    this.Xc = 10
    this.T.ja(a)
    for (this.T.ja(a); 0 < a.o.byteLength - a.a;) this.Cg(this.Gm(a))

This qq is for NETWORK join, not file replay. Cq for file replay may differ.

Actually for the file replay player (Jb), Cq might be:
  this.uc (uint16)
  this.Y (uint32)
  this.te (uint32)
  this.cc (varint)
  this.T.ja(this.Lc)

But mf is from file header (44763), and Y here would be the START frame.

So maybe Y = 0 (beginning of recording) and bytes 2-5 being FD 47 01 C4 is wrong.

Let me try: maybe the first uint16 (uc) is stored differently.
Bytes 0-1: 00 08
If we think of it as two separate bytes where only 1 byte was written...
Or maybe the format starts differently.

WAIT - ac.stop():
  this.Nd.o.setUint16(0, this.Xm, this.Nd.Sa)
  this.Nd.Vb(this.Df.Sb())

This means: at position 0 of Nd (which was initially empty/allocated), 
write Xm as uint16, THEN append Df contents starting at position 2.

But what did Df contain? When recording starts:
Looking at ac.zr(): this.Ed = new ac(this.ya, 3)
ac constructor likely initializes Df.

Looking at Dl() (file replay player's frame reader):
  0 < a.o.byteLength - a.a ?
    a = this.Lc.Ab()  <- varint (frame delta)
    this.hg += a
    a = this.Lc.Ob()  <- uint16 (event_type_id)
    this.gg = m.fh(this.Lc)  <- parse event
    this.gg.P = a

So Lc contains: room_state first (T.ja reads it), then frame events.
And the first 2 bytes (uc uint16) + 4 bytes (Y uint32) + 4 bytes (te uint32) + 
varint (cc) are consumed by Cq BEFORE Lc is reset.

Actually Jb constructor:
  this.Lc = new F(dataview, false)
  this.Cq(this.Lc)  <- reads header bytes, advances Lc.a
  c = this.Lc.sb()  <- gets REMAINING bytes (after header consumed)
  this.Lc = new F(new DataView(c.buffer...), false)  <- new reader for remaining
  this.ui()  <- resets Y=0 and calls T.ja(this.Lc) then Dl() loop

So structure is:
  [header consumed by Cq]
  [remaining = room_state + frame_events, consumed by T.ja then Dl]

The header consumed by Cq:
  uc = Ob() = 2 bytes
  Y = hb() = 4 bytes
  te = hb() = 4 bytes
  cc = Ab() = varint (1-5 bytes typically)
  Xc = 10

After that: T.ja(Lc) reads room state, then Dl() reads frame events.

File1 bytes:
  0-1: 00 08 -> uc = 8 (BE)
  2-5: FD 47 01 C4 -> Y = 0xFD4701C4 ? 

Let me check if this could be frame 44763:
0xAEDB = 44763! Let me check: bytes 8-11 of the compressed file were 00 00 AE DB.
Bytes 8-11 as BE uint32: 0x0000AEDB = 44763. ✓

But in decompressed, bytes 2-5 are FD 47 01 C4, not 0 or 44763.
Maybe Y in the decompressed payload is the frame count at RECORDING START
(which would be 0 if the room just started).

Actually, Xm = hj.Y - ah (frame at stop - frame at start of recording).
And Y in Cq could be the frame at START of recording (ah).

If the room was running before recording started, Y could be non-zero.
0xFD4701C4 as uint32 = 4249387460... way too large.

Let me try: maybe my reading is wrong and the initial bytes represent something else.

Looking at file1 more carefully:
00 08 | FD 47 01 C4 | 26 01 EA 25 02 86 20 02 DB 3D ...
 uc=8     Y=?

Actually 0xFD47 looks interesting... could Y be uint16 instead of uint32?
No, hb() reads uint32.

Let me just look at this differently. We don't need to parse the initial state.
We just need to APPEND the frame events from file2 to file1's frame events.

APPROACH: Since we know frames in file1=44763 and frames in file2=41645,
and the frame event structure uses varint DELTA (not absolute frame numbers),
we CAN simply concatenate:
  merged_dec = file1_dec + file2_dec_frame_stream_only

We just need to find the frame stream start offset in file2.

Given: file2 decompressed = [header(Cq bytes)][room_state][frame_events]
We need to find the start of [frame_events].

Alternatively: if we just use both complete decompressed blobs
(header1+room_state1+events1 + header2+room_state2+events2),
the Jb player will try to parse it as:
  - Read header (ok, from file1)
  - Read room_state (ok, from file1)  
  - Then Dl() reads events until EOF
  - It would hit file2's header bytes and misparse them as events

This won't work cleanly.

THE CLEANEST APPROACH that requires no internal parsing:
1. Keep file1's decompressed bytes EXACTLY as-is
2. Find the boundary in file2 between header+room_state vs events
3. Append only events from file2

For finding the boundary in file2:
- Use the fact that cc (counter in Cq) tracks event sequence numbers
- After Cq and T.ja, the first event in Dl would be:
  varint(delta) + uint16(type) + ...
- Since both files use the same stadium (FUTSAL FUSION LEAGUE), the room_state
  size should be similar/identical

Strategy: Compare both decompressed blobs to find where they differ.
We know they diverge at byte 2 (player positions differ at recording time).
The stadium definition should appear at the same offsets.
The "FUTSAL FUSION LEAGUE 4" text appears at similar offsets (~0x1B for both).

Let's measure the room state size by finding a known marker (FFL stadium name)
and then looking for where the events start after the stadium data.
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

file1 = r'c:\Users\user\Desktop\Codemations\HBR\12-05-26-20h28-Emman64vsVerone (1).hbr2'
file2 = r'c:\Users\user\Desktop\Codemations\HBR\12-05-26-20h41-VeronevsEmman64 (1).hbr2'

v1, fc1, dec1 = read_hbr2(file1)
v2, fc2, dec2 = read_hbr2(file2)

# Search for all text strings in decompressed data
import re

def find_strings(data, min_len=4):
    results = []
    pattern = re.compile(b'[\x20-\x7e]{%d,}' % min_len)
    for m in pattern.finditer(data):
        results.append((m.start(), m.group().decode('ascii', errors='replace')))
    return results

strings1 = find_strings(dec1, 5)
strings2 = find_strings(dec2, 5)

print("File1 strings (first 30):")
for off, s in strings1[:30]:
    print(f"  {off:6d}: {s[:60]}")

print("\nFile2 strings (first 30):")
for off, s in strings2[:30]:
    print(f"  {off:6d}: {s[:60]}")

# Now try to find player name sections (likely in room state)
# and frame data start
# Look for the last repeated string/pattern in both files (stadium name should be same offset)
print("\n\nChecking where files have same content (beyond offset 2):")
common_regions = []
i = 2
streak_start = None
streak_len = 0
for i in range(2, min(len(dec1), len(dec2), 20000)):
    if dec1[i] == dec2[i]:
        if streak_start is None:
            streak_start = i
        streak_len += 1
    else:
        if streak_len > 20:
            common_regions.append((streak_start, streak_len))
        streak_start = None
        streak_len = 0

print(f"\nCommon regions in first 20000 bytes (length > 20):")
for start, length in common_regions[:20]:
    print(f"  offset {start}: {length} bytes common")
    print(f"    content: {dec1[start:start+min(40,length)]}")

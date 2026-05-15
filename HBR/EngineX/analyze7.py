"""
Parse the HBR2 decompressed data to find where room state ends and frame events begin.

The decompressed payload structure (after Cq consumes header):
  [room_state: T.ja()] <- immediately follows, now in 'remaining' after Cq
  [frame_events: repeated varint+uint16+data]

The room state is written by fa.ga()/fa.ja() functions.
Looking at the game source, after header fields (uc+Y+te+cc), 
the entire remaining data is split:
  - T.ja(this.Lc) reads room state  
  - Then events follow

BUT we already know:
  - Both files have SAME bytes from offset 25 to 11080 (stadium data)
  - Frame events are COMPLETELY different per game  
  - We need to find room_state_end offset in EACH file

Approach: Parse the structure manually.
The header consumed by Cq is:
  uint16 uc (2 bytes)
  uint32 Y (4 bytes)
  uint32 te (4 bytes)
  varint cc (1-5 bytes)

Then room state begins immediately. The room state fa.ja() reads:
  string room_name (length-prefixed)
  bool flag
  uint32 ib
  uint32 Da
  int16 ce
  uint8 Zc
  uint8 yd
  [THEN: stadium fa.S (h.ja())]
  [THEN: bool K, optional game state]
  [THEN: player list]
  [THEN: team colors kb[1].ja(), kb[2].ja()]

The varint format: if byte < 128, it's the value; else (byte & 0x7F) is 7-bit chunk, 
next byte continues. More precisely: each byte has continuation bit 0x80.
Groups of 7 bits, little-endian order.

Let me try to parse from offset 0:
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

class BinReader:
    def __init__(self, data, pos=0):
        self.data = data
        self.pos = pos
    
    def remaining(self):
        return len(self.data) - self.pos

    def read_uint8(self):
        v = self.data[self.pos]
        self.pos += 1
        return v
    
    def read_uint16_be(self):
        v = struct.unpack_from('>H', self.data, self.pos)[0]
        self.pos += 2
        return v
    
    def read_int16_be(self):
        v = struct.unpack_from('>h', self.data, self.pos)[0]
        self.pos += 2
        return v
    
    def read_uint32_be(self):
        v = struct.unpack_from('>I', self.data, self.pos)[0]
        self.pos += 4
        return v
    
    def read_int32_be(self):
        v = struct.unpack_from('>i', self.data, self.pos)[0]
        self.pos += 4
        return v
    
    def read_float64_be(self):
        v = struct.unpack_from('>d', self.data, self.pos)[0]
        self.pos += 8
        return v
    
    def read_varint(self):
        """Read variable-length integer (Ab() from F class)"""
        # Looking at source: a.Ab() = Fh(a) with shift
        # Fh(a): result=0, shift=0; while True: byte=B(); result |= (byte&0x7F)<<shift; if !(byte&0x80) break; shift+=7
        result = 0
        shift = 0
        while True:
            byte = self.read_uint8()
            result |= (byte & 0x7F) << shift
            if not (byte & 0x80):
                break
            shift += 7
        return result
    
    def read_string(self):
        """Read length-prefixed UTF-8 string (Og/rc in source)"""
        # Looking at source: rc() reads uint16 length then UTF-16 chars
        # Actually Og/rc in haxball might be UTF-16 BE with uint16 length
        # Let's check: 'FUTSAL FUSION LEAGUE 4' is at offset 27
        # At offset 25: 02 17 FUTSAL...
        # 0x0217 = 535... that's not length 22 for 'FUTSAL FUSION LEAGUE 4'
        # Unless it's some other encoding
        # 
        # Looking at the bytes: 02 17 46 55 54 53 41 4C 20 46 55 53 49 4F 4E 20 4C 45 41 47 55 45 20 34
        # 0x17 = 23... but 'FUTSAL FUSION LEAGUE 4' has 22 chars + null? Or 23 chars including space?
        # Actually: 'FUTSAL FUSION LEAGUE 4' = 22 chars... 0x17 = 23
        # Hmm, 0x17 = 23... Close but off by 1
        # 
        # Wait: 02 = some other field? And 17 = 0x17 = 23 char length?
        # But 22 chars != 23
        # 
        # Let me count: F-U-T-S-A-L- -F-U-S-I-O-N- -L-E-A-G-U-E- -4 = 22 chars
        # 0x17 = 23... Could include null terminator?
        # 
        # Actually looking at Og: writes each char as uint16 (UTF-16), prefixed by uint16 count
        # If UTF-16: 'FUTSAL FUSION LEAGUE 4' = 22 chars * 2 bytes = 44 bytes
        # But that doesn't match the raw ASCII bytes we see
        # 
        # The string appears as raw ASCII in the binary: 46 55 54 53 41 = FUTSAL
        # This suggests it's NOT UTF-16. It's stored as raw bytes.
        # 
        # Alternative: Og writes each char as uint8 (ASCII/Latin1), prefixed by uint16 count
        # If uint16 count = 22 chars: 0x0016 = 22
        # But bytes at offset 25 are 02 17 = 0x0217 = 535! Not 22.
        # 
        # Wait - let me re-read analyze4 output: "offset 25: 11056 bytes common"
        # and the content starts with: b'\x02\x17FUTSAL FUSION LEAGUE 4\x01\x00...'
        # So offset 25 = 0x02, offset 26 = 0x17 = 23, then 'FUTSAL FUSION LEAGUE 4'
        # 
        # 0x17 = 23 but string is 22 chars... Unless it's 23 chars with something extra?
        # 'FUTSAL FUSION LEAGUE 4\x00' = 23 with null? Seems wrong.
        # 
        # OR: maybe the string encoding uses uint8 length (not uint16)
        # byte 0x02 = some other preceding field
        # byte 0x17 = length=23? But string is 22 chars... 
        # 
        # WAIT: maybe 0x02 is a field type marker and 0x17 = 23 is length of something else?
        # 
        # Let me try: bytes 25-27: 02 17 46
        # If varint at offset 25: 0x02 has no continuation bit -> value = 2 (1 byte consumed)
        # Then bytes 26+: 17 46 55 54 53 41 4c 20 46 55 53 49 4f 4e 20 4c 45 41 47 55 45 20 34
        # 0x17 = 23 still... 
        # Hmm: 0x17 as varint -> value=23 (no continuation)
        # Then 23 bytes of string data: 46 55 54 53 41 4c 20 46 55 53 49 4f 4e 20 4c 45 41 47 55 45 20 34 ??
        # That's 'FUTSAL FUSION LEAGUE 4' = 22 bytes... still 22 not 23
        # 
        # Oh wait: 'FUTSAL FUSION LEAGUE 4' - let me count more carefully:
        # F(1) U(2) T(3) S(4) A(5) L(6) ' '(7) F(8) U(9) S(10) I(11) O(12) N(13) ' '(14) L(15) E(16) A(17) G(18) U(19) E(20) ' '(21) 4(22)
        # Yes, 22 chars. But length byte says 23 (0x17 = 23).
        # 
        # Looking at bytes more carefully in the actual data:
        # Common region at 25: b'\x02\x17FUTSAL FUSION LEAGUE 4\x01\x00...'
        # After the string 'FUTSAL FUSION LEAGUE 4', next byte = 0x01
        # Let me check: maybe the length is 0x16=22, not 0x17=23?
        # 
        # From analyze4 output: b'\x02\x17FUTSAL FUSION LEAGUE 4\x01\x00\x00\x00...'
        # Python repr shows \x17 which IS 23...
        # 
        # Unless the room name has a trailing space or is slightly different?
        # Let me check the actual hex
        length = self.read_uint16_be()
        if length > 10000:
            raise ValueError(f"Implausibly large string length {length} at pos {self.pos-2}")
        chars = []
        for _ in range(length):
            chars.append(chr(self.read_uint16_be()))
        return ''.join(chars)

# Let's just hex dump the first 50 bytes
print("File1 first 50 bytes:")
for i in range(0, 50, 16):
    hex_str = ' '.join(f'{b:02x}' for b in dec1[i:i+16])
    asc_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in dec1[i:i+16])
    print(f"  {i:4d}: {hex_str:<48} {asc_str}")

print("\nFile2 first 50 bytes:")
for i in range(0, 50, 16):
    hex_str = ' '.join(f'{b:02x}' for b in dec2[i:i+16])
    asc_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in dec2[i:i+16])
    print(f"  {i:4d}: {hex_str:<48} {asc_str}")

# Now let's look at bytes 20-60 more carefully (just before and after FUTSAL)
print("\nFile1 bytes 15-70 detail:")
for i in range(15, 70, 16):
    hex_str = ' '.join(f'{b:02x}' for b in dec1[i:i+16])
    asc_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in dec1[i:i+16])
    print(f"  {i:4d}: {hex_str:<48} {asc_str}")

# Now let's try to parse the header (Cq):
# uc = uint16 BE, Y = uint32 BE, te = uint32 BE, cc = varint
r1 = BinReader(dec1)
uc = r1.read_uint16_be()
Y = r1.read_uint32_be()
te = r1.read_uint32_be()
cc = r1.read_varint()
print(f"\nFile1 Cq fields (assuming BE):")
print(f"  uc = {uc} (offset 0-1)")
print(f"  Y = {Y} (offset 2-5)")
print(f"  te = {te} (offset 6-9)")
print(f"  cc = {cc} (offset 10+)")
print(f"  After Cq: pos = {r1.pos}")
print(f"  Bytes at pos {r1.pos}: {dec1[r1.pos:r1.pos+16].hex()}")

# Try reading room_state (fa.ja()) at this position
# fa.ja() starts with reading the room name string
# Let's try to read a uint16-length string (BE)
# From current pos, check if next bytes look like a string
pos = r1.pos
b = dec1[pos]
print(f"\n  Byte at start of room_state: {b} (0x{b:02x})")
# Try various string formats
# Option A: uint8 length then ASCII chars
length_u8 = dec1[pos]
print(f"  Option A (uint8 len): len={length_u8}, str='{dec1[pos+1:pos+1+length_u8].decode('ascii','replace')}'")
# Option B: uint16 BE length then ASCII chars
length_u16 = struct.unpack_from('>H', dec1, pos)[0]
print(f"  Option B (uint16 BE len): len={length_u16}, str='{dec1[pos+2:pos+2+length_u16].decode('ascii','replace')}'")
# Option C: uint16 BE length then UTF-16 chars
print(f"  Option C (uint16 BE, UTF16): would need {length_u16*2} bytes")

# Check if the 'FFL 7x7' and 'FUTSAL' appear in the room state after the Cq header
# We know FUTSAL is at offset 27 and FFL is at offset 64
# If Cq consumed some bytes and then room_state starts with room name, 
# the room name (FFL or something) should be right at pos

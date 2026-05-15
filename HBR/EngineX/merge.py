"""
HBR2 Replay Merger
==================
Merges two HaxBall replay files into a single replay.

File format (HBR2):
  [4 bytes] Magic: 'HBR2'
  [4 bytes] Version: uint32 BE
  [4 bytes] FrameCount: uint32 BE
  [rest]    Raw DEFLATE (zlib wbits=-15) compressed payload

Decompressed payload:
  [header bytes consumed by Cq()]
  [room state - stadium + players + team colors]
  [frame events - repeated: varint(delta) + varint(type) + event_data]

Merge strategy:
  - Keep file1's complete decompressed data (header + room_state + events_1)
  - Append file2's event stream only (strip header + room_state from file2)
  - New frame count = fc1 + fc2
  - Re-compress with raw deflate

Room state boundaries (empirically determined):
  - Stadium data starts at decompressed offset 25 (same in both files)
  - Team colors end at file1 offset 13300, file2 offset 13377
  - Additional room state after team colors: 10 bytes (01 00 00 00 00 00 01 64 07 XX)
  - File1 events start: 13310
  - File2 events start: 13387
"""
import zlib
import struct

FILE1 = r'c:\Users\user\Desktop\Codemations\HBR\12-05-26-20h28-Emman64vsVerone (1).hbr2'
FILE2 = r'c:\Users\user\Desktop\Codemations\HBR\12-05-26-20h41-VeronevsEmman64 (1).hbr2'
OUTPUT = r'c:\Users\user\Desktop\Codemations\HBR\merged.hbr2'

# Event stream start offsets in the decompressed payloads
FILE1_EVENTS_START = 13310
FILE2_EVENTS_START = 13387


def read_hbr2(path):
    with open(path, 'rb') as f:
        data = f.read()
    assert data[:4] == b'HBR2', f"Not a valid HBR2 file: {path}"
    version = struct.unpack('>I', data[4:8])[0]
    frame_count = struct.unpack('>I', data[8:12])[0]
    decompressed = zlib.decompress(data[12:], -15)
    return version, frame_count, decompressed


def write_hbr2(path, version, frame_count, decompressed):
    # Re-compress as raw deflate (strip 2-byte zlib header and 4-byte Adler32 checksum)
    compressed_zlib = zlib.compress(decompressed, 9)
    compressed_raw = compressed_zlib[2:-4]  # strip zlib header (2 bytes) and checksum (4 bytes)
    
    with open(path, 'wb') as f:
        f.write(b'HBR2')
        f.write(struct.pack('>I', version))
        f.write(struct.pack('>I', frame_count))
        f.write(compressed_raw)
    
    return len(compressed_raw) + 12  # total file size


def main():
    print("Reading file 1...")
    v1, fc1, dec1 = read_hbr2(FILE1)
    print(f"  Version: {v1}, FrameCount: {fc1}, Decompressed: {len(dec1)} bytes")
    
    print("Reading file 2...")
    v2, fc2, dec2 = read_hbr2(FILE2)
    print(f"  Version: {v2}, FrameCount: {fc2}, Decompressed: {len(dec2)} bytes")
    
    assert v1 == v2, f"Version mismatch: file1={v1}, file2={v2}"
    
    # Validate event start offsets look correct
    print(f"\nFile1 events at {FILE1_EVENTS_START}: {dec1[FILE1_EVENTS_START:FILE1_EVENTS_START+12].hex()}")
    print(f"File2 events at {FILE2_EVENTS_START}: {dec2[FILE2_EVENTS_START:FILE2_EVENTS_START+12].hex()}")
    
    # Merge: file1 complete + file2 events only
    file1_complete = dec1  # header + room_state + events_1
    file2_events = dec2[FILE2_EVENTS_START:]  # events_2 only
    
    merged = file1_complete + file2_events
    merged_fc = fc1 + fc2
    
    print(f"\nMerging:")
    print(f"  File1 complete: {len(file1_complete)} bytes")
    print(f"  File2 events: {len(file2_events)} bytes ({FILE2_EVENTS_START} bytes stripped)")
    print(f"  Merged decompressed: {len(merged)} bytes")
    print(f"  Merged frame count: {merged_fc} ({fc1} + {fc2})")
    
    print(f"\nWriting {OUTPUT}...")
    out_size = write_hbr2(OUTPUT, v1, merged_fc, merged)
    print(f"  Output file size: {out_size} bytes")
    print(f"\nDone! Merged replay saved to: {OUTPUT}")
    print(f"\nNote: The merged replay contains:")
    print(f"  - Match 1 (Emman64 vs Verone): frames 1-{fc1}")
    print(f"  - Match 2 (Verone vs Emman64): frames {fc1+1}-{merged_fc}")


if __name__ == '__main__':
    main()

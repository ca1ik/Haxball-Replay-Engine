"""
merge_binary.py
Binary-level HBR2 merger — no physics manipulation, no event injection.

HBR2 format:
  4 bytes  magic "HBR2"
  4 bytes  version (uint32 BE) = 3
  4 bytes  frameCount (uint32 BE)
  rest     raw-deflate compressed payload

Decompressed payload layout:
  uint16 LE  goalCount
  for each goal:
    uint32 LE  frameDelta (cumulative, relative to previous goal)
    uint8      teamId
  events section:
    uint16 LE  eventCount
    for each event:
      varint(frameDelta)  relative to previous event frame
      varint(byteLen)
      <byteLen bytes>

Merge strategy:
  - Decode both files
  - Adjust file2 goal frame numbers by +file1_lastFrame+1
  - Adjust file2 event frame numbers by +file1_lastFrame+1
  - Re-encode combined payload and write new HBR2
"""

import struct
import zlib
import os

DIR = os.path.dirname(os.path.abspath(__file__))
FILE1 = os.path.join(DIR, "12-05-26-20h28-Emman64vsVerone (1).hbr2")
FILE2 = os.path.join(DIR, "12-05-26-20h41-VeronevsEmman64 (1).hbr2")
OUT   = os.path.join(DIR, "merged_final.hbr2")


def read_varint(data, pos):
    val = 0; shift = 0
    while True:
        b = data[pos]; pos += 1
        val |= (b & 0x7F) << shift
        if not (b & 0x80): break
        shift += 7
    return val, pos


def write_varint(val):
    out = []
    while True:
        b = val & 0x7F; val >>= 7
        if val: out.append(b | 0x80)
        else:   out.append(b); break
    return bytes(out)


def parse_hbr2(path):
    with open(path, "rb") as f:
        raw = f.read()
    magic   = raw[:4]
    version = struct.unpack_from(">I", raw, 4)[0]
    frames  = struct.unpack_from(">I", raw, 8)[0]
    payload = zlib.decompress(raw[12:], -15)
    assert magic == b"HBR2"
    assert version == 3
    return frames, payload


def decode_payload(payload):
    pos = 0

    # --- goalMarkers ---
    goal_count = struct.unpack_from("<H", payload, pos)[0]; pos += 2
    goals = []
    abs_frame = 0
    for _ in range(goal_count):
        delta  = struct.unpack_from("<I", payload, pos)[0]; pos += 4
        team   = payload[pos]; pos += 1
        abs_frame += delta
        goals.append((abs_frame, team))

    # --- events ---
    evt_count = struct.unpack_from("<H", payload, pos)[0]; pos += 2
    events = []
    frame = 0
    for _ in range(evt_count):
        delta, pos = read_varint(payload, pos)
        length, pos = read_varint(payload, pos)
        ev_bytes = payload[pos: pos + length]; pos += length
        frame += delta
        events.append((frame, bytes(ev_bytes)))

    return goals, events


def encode_payload(goals, events):
    out = bytearray()

    # goalMarkers
    out += struct.pack("<H", len(goals))
    prev = 0
    for (frame, team) in goals:
        out += struct.pack("<I", frame - prev)
        out += struct.pack("B", team)
        prev = frame

    # events
    out += struct.pack("<H", len(events))
    prev = 0
    for (frame, ev_bytes) in events:
        out += write_varint(frame - prev)
        out += write_varint(len(ev_bytes))
        out += ev_bytes
        prev = frame

    return bytes(out)


# ── Main ──────────────────────────────────────────────────────────────────────

print("Reading files...")
frames1, payload1 = parse_hbr2(FILE1)
frames2, payload2 = parse_hbr2(FILE2)
print(f"File1: {frames1} frames, payload {len(payload1)} bytes")
print(f"File2: {frames2} frames, payload {len(payload2)} bytes")

print("Decoding payloads...")
goals1, events1 = decode_payload(payload1)
goals2, events2 = decode_payload(payload2)
print(f"File1: {len(goals1)} goals, {len(events1)} events")
print(f"File2: {len(goals2)} goals, {len(events2)} events")

# Offset: file2 starts right after file1's last frame
OFFSET = frames1 + 1
print(f"Offset for file2: +{OFFSET} frames")

goals2_off  = [(f + OFFSET, t) for (f, t) in goals2]
events2_off = [(f + OFFSET, b) for (f, b) in events2]

merged_goals  = goals1  + goals2_off
merged_events = events1 + events2_off
total_frames  = frames1 + 1 + frames2

print(f"\nMerged: {total_frames} frames | {len(merged_goals)} goals | {len(merged_events)} events")

print("Encoding merged payload...")
merged_stream = encode_payload(merged_goals, merged_events)
print(f"Uncompressed size: {len(merged_stream):,} bytes")

# Raw deflate compress (strip 2-byte zlib header + 4-byte adler32 = [2:-4])
compressed = zlib.compress(merged_stream, 6)[2:-4]
print(f"Compressed size: {len(compressed):,} bytes")

# Build output
header  = b"HBR2"
header += struct.pack(">I", 3)
header += struct.pack(">I", total_frames)
output  = header + compressed

with open(OUT, "wb") as f:
    f.write(output)

print(f"\nDone! -> {OUT}")
print(f"File size: {len(output):,} bytes")


/**
 * merge_binary.js
 * Pure binary HBR2 merger — no physics manipulation, no synthetic event injection.
 *
 * HBR2 decompressed payload layout:
 *   uint16 LE  goalCount
 *   for each goal: uint32 LE frameDelta (cumulative), uint8 teamId
 *   uint16 LE  eventCount
 *   for each event: varint(frameDelta) + varint(byteLen) + <byteLen bytes>
 */

const fs   = require("fs");
const path = require("path");
const zlib = require("zlib");

const DIR   = __dirname;
const FILE1 = path.join(DIR, "12-05-26-20h28-Emman64vsVerone (1).hbr2");
const FILE2 = path.join(DIR, "12-05-26-20h41-VeronevsEmman64 (1).hbr2");
const OUT   = path.join(DIR, "merged_final.hbr2");

// ── Varint helpers ────────────────────────────────────────────────────────────

function readVarint(buf, pos) {
  let val = 0, shift = 0;
  while (true) {
    const b = buf[pos++];
    val |= (b & 0x7F) << shift;
    if (!(b & 0x80)) break;
    shift += 7;
  }
  return [val, pos];
}

function writeVarint(val) {
  const bytes = [];
  while (true) {
    const b = val & 0x7F;
    val >>>= 7;
    if (val) bytes.push(b | 0x80);
    else { bytes.push(b); break; }
  }
  return Buffer.from(bytes);
}

// ── Parse ─────────────────────────────────────────────────────────────────────

function parseHbr2(filePath) {
  const raw    = fs.readFileSync(filePath);
  const magic  = raw.slice(0, 4).toString("ascii");
  const ver    = raw.readUInt32BE(4);
  const frames = raw.readUInt32BE(8);
  const payload = zlib.inflateRawSync(raw.slice(12));

  if (magic !== "HBR2") throw new Error("Bad magic: " + magic);
  if (ver   !== 3)      throw new Error("Unexpected version: " + ver);

  return { frames, payload };
}

function decodePayload(payload) {
  let pos = 0;

  // goalMarkers
  const goalCount = payload.readUInt16BE(pos); pos += 2;
  const goals = [];
  let absFrame = 0;
  for (let i = 0; i < goalCount; i++) {
    const delta = payload.readUInt32LE(pos); pos += 4;
    const team  = payload[pos++];
    absFrame += delta;
    goals.push({ frame: absFrame, team });
  }

  // events
  const evtCount = payload.readUInt16BE(pos); pos += 2;
  const events = [];
  let frame = 0;
  for (let i = 0; i < evtCount; i++) {
    let [delta, p1] = readVarint(payload, pos);
    let [len,   p2] = readVarint(payload, p1);
    const evBytes = payload.slice(p2, p2 + len);
    pos = p2 + len;
    frame += delta;
    events.push({ frame, bytes: evBytes });
  }

  return { goals, events };
}

function encodePayload(goals, events) {
  const parts = [];

  // goalMarkers
  const gcBuf = Buffer.alloc(2); gcBuf.writeUInt16BE(goals.length); parts.push(gcBuf);
  let prev = 0;
  for (const g of goals) {
    const b = Buffer.alloc(5);
    b.writeUInt32LE(g.frame - prev, 0);
    b[4] = g.team;
    parts.push(b);
    prev = g.frame;
  }

  // events
  const ecBuf = Buffer.alloc(2); ecBuf.writeUInt16BE(events.length); parts.push(ecBuf);
  prev = 0;
  for (const e of events) {
    parts.push(writeVarint(e.frame - prev));
    parts.push(writeVarint(e.bytes.length));
    parts.push(e.bytes);
    prev = e.frame;
  }

  return Buffer.concat(parts);
}

// ── Main ──────────────────────────────────────────────────────────────────────

console.log("Reading files...");
const f1 = parseHbr2(FILE1);
const f2 = parseHbr2(FILE2);
console.log(`File1: ${f1.frames} frames, payload ${f1.payload.length} bytes`);
console.log(`File2: ${f2.frames} frames, payload ${f2.payload.length} bytes`);

console.log("Decoding payloads...");
const d1 = decodePayload(f1.payload);
const d2 = decodePayload(f2.payload);
console.log(`File1: ${d1.goals.length} goals, ${d1.events.length} events`);
console.log(`File2: ${d2.goals.length} goals, ${d2.events.length} events`);

// Sanity check: verify our decode → encode is lossless on file1
const reenc1 = encodePayload(d1.goals, d1.events);
const match = reenc1.equals(f1.payload);
console.log(`\nLossless roundtrip check (file1): ${match ? "PASS ✓" : "FAIL ✗"}`);
if (!match) {
  console.log("  original length:", f1.payload.length, "re-encoded length:", reenc1.length);
  // find first diff
  for (let i = 0; i < Math.min(f1.payload.length, reenc1.length); i++) {
    if (f1.payload[i] !== reenc1[i]) {
      console.log("  first diff at byte:", i, "orig:", f1.payload[i].toString(16), "reenc:", reenc1[i].toString(16));
      break;
    }
  }
}

const OFFSET = f1.frames + 1;
console.log(`\nOffset for file2: +${OFFSET} frames`);

const goals2off  = d2.goals.map(g  => ({ frame: g.frame  + OFFSET, team: g.team  }));
const events2off = d2.events.map(e => ({ frame: e.frame  + OFFSET, bytes: e.bytes }));

const mergedGoals  = [...d1.goals,  ...goals2off];
const mergedEvents = [...d1.events, ...events2off];
const totalFrames  = f1.frames + 1 + f2.frames;

console.log(`\nMerged: ${totalFrames} frames | ${mergedGoals.length} goals | ${mergedEvents.length} events`);

console.log("Encoding...");
const mergedPayload = encodePayload(mergedGoals, mergedEvents);
console.log(`Uncompressed: ${mergedPayload.length.toLocaleString()} bytes`);

const compressed = zlib.deflateRawSync(mergedPayload, { level: 6 });
console.log(`Compressed:   ${compressed.length.toLocaleString()} bytes`);

// Build HBR2 file
const header = Buffer.alloc(12);
header.write("HBR2", 0, "ascii");
header.writeUInt32BE(3,           4);
header.writeUInt32BE(totalFrames, 8);

const output = Buffer.concat([header, compressed]);
fs.writeFileSync(OUT, output);

console.log(`\nDone! -> ${OUT}`);
console.log(`File size: ${output.length.toLocaleString()} bytes`);

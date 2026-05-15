/**
 * hbr_merge_cli.js  —  HBR Studio Merge CLI  (Pure Binary Approach)
 *
 * Usage:
 *   node hbr_merge_cli.js <output.hbr2> <file1.hbr2> <file2.hbr2>
 *
 * Merges exactly 2 replay files using pure binary HBR2 manipulation.
 * Lossless: no node-haxball Replay.writeAll required.
 * Emits JSON progress lines to stdout.
 */

const fs   = require('fs');
const path = require('path');
const zlib = require('zlib');

// ── Emit ──────────────────────────────────────────────────────────────────────

function emit(obj) { process.stdout.write(JSON.stringify(obj) + '\n'); }

// ── Arg parsing ───────────────────────────────────────────────────────────────

const args = process.argv.slice(2);
if (args.length < 3) {
  emit({ type: 'error', message: 'Usage: node hbr_merge_cli.js <output> <file1> <file2>' });
  process.exit(1);
}

const OUT_PATH = args[0];
const FILE1    = args[1];
const FILE2    = args[2];

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

// ── Parse & decode ────────────────────────────────────────────────────────────

function parseHbr2(filePath) {
  const raw     = fs.readFileSync(filePath);
  const magic   = raw.slice(0, 4).toString('ascii');
  const ver     = raw.readUInt32BE(4);
  const frames  = raw.readUInt32BE(8);
  const payload = zlib.inflateRawSync(raw.slice(12));
  if (magic !== 'HBR2') throw new Error('Bad magic: ' + magic);
  if (ver   !== 3)      throw new Error('Unexpected version: ' + ver);
  return { frames, payload };
}

function decodePayload(payload) {
  let pos = 0;

  const goalCount = payload.readUInt16BE(pos); pos += 2;
  const goals = [];
  let absFrame = 0;
  for (let i = 0; i < goalCount; i++) {
    const delta = payload.readUInt32LE(pos); pos += 4;
    const team  = payload[pos++];
    absFrame += delta;
    goals.push({ frame: absFrame, team });
  }

  const evtCount = payload.readUInt16BE(pos); pos += 2;
  const events = [];
  let frame = 0;
  for (let i = 0; i < evtCount; i++) {
    const [delta, p1] = readVarint(payload, pos);
    const [len,   p2] = readVarint(payload, p1);
    const evBytes     = payload.slice(p2, p2 + len);
    pos   = p2 + len;
    frame += delta;
    events.push({ frame, bytes: evBytes });
  }

  return { goals, events };
}

function encodePayload(goals, events) {
  const parts = [];

  const gcBuf = Buffer.alloc(2); gcBuf.writeUInt16BE(goals.length); parts.push(gcBuf);
  let prev = 0;
  for (const g of goals) {
    const b = Buffer.alloc(5);
    b.writeUInt32LE(g.frame - prev, 0);
    b[4] = g.team;
    parts.push(b);
    prev = g.frame;
  }

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

function buildHbr2(totalFrames, encodedPayload) {
  const compressed = zlib.deflateRawSync(encodedPayload, { level: 6 });
  const header = Buffer.alloc(12);
  header.write('HBR2', 0, 'ascii');
  header.writeUInt32BE(3,           4);
  header.writeUInt32BE(totalFrames, 8);
  return Buffer.concat([header, compressed]);
}

// ── Main ──────────────────────────────────────────────────────────────────────

try {
  emit({ type: 'progress', step: 'reading', file: 1, total: 2, name: path.basename(FILE1) });
  const f1 = parseHbr2(FILE1);
  emit({ type: 'info', file: 1, frames: f1.frames });

  emit({ type: 'progress', step: 'reading', file: 2, total: 2, name: path.basename(FILE2) });
  const f2 = parseHbr2(FILE2);
  emit({ type: 'info', file: 2, frames: f2.frames });

  emit({ type: 'progress', step: 'decoding' });
  const d1 = decodePayload(f1.payload);
  const d2 = decodePayload(f2.payload);
  emit({ type: 'info', file: 1, goals: d1.goals.length, events: d1.events.length });
  emit({ type: 'info', file: 2, goals: d2.goals.length, events: d2.events.length });

  emit({ type: 'progress', step: 'merging', pair: 1, total: 1 });
  const OFFSET = f1.frames + 1;

  const mergedGoals  = [
    ...d1.goals,
    ...d2.goals.map(g => ({ frame: g.frame + OFFSET, team: g.team }))
  ];
  const mergedEvents = [
    ...d1.events,
    ...d2.events.map(e => ({ frame: e.frame + OFFSET, bytes: e.bytes }))
  ];
  const totalFrames = f1.frames + 1 + f2.frames;

  emit({ type: 'progress', step: 'writing', output: OUT_PATH });
  const payload = encodePayload(mergedGoals, mergedEvents);
  const output  = buildHbr2(totalFrames, payload);
  fs.writeFileSync(OUT_PATH, output);

  const stat = fs.statSync(OUT_PATH);
  emit({
    type   : 'done',
    frames : totalFrames,
    events : mergedEvents.length,
    goals  : mergedGoals.length,
    output : OUT_PATH,
    bytes  : stat.size
  });

} catch (e) {
  emit({ type: 'error', message: e.message });
  process.exit(1);
}

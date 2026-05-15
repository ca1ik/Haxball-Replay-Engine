/**
 * hbr_split_cli.js  —  HBR Studio Split / Trim CLI  (Pure Binary Approach)
 *
 * SPLIT mode (default):
 *   node hbr_split_cli.js <input> <output1> <output2> <splitFrame>
 *   → Part 1: frames [0 .. splitFrame]     → output1
 *   → Part 2: frames (splitFrame .. end]   → output2 (re-offset to 0)
 *
 * TRIM mode (--trim flag):
 *   node hbr_split_cli.js <input> <output> <startFrame> <endFrame> --trim
 *   → Segment: frames [startFrame .. endFrame] → output (re-offset to 0)
 *
 * HaxBall runs at 60 steps/sec:  frame = minutes*60*60 + seconds*60
 * Emits JSON progress lines to stdout.
 */

const fs   = require('fs');
const path = require('path');
const zlib = require('zlib');

// ── Emit ──────────────────────────────────────────────────────────────────────

function emit(obj) { process.stdout.write(JSON.stringify(obj) + '\n'); }

// ── Arg parsing ───────────────────────────────────────────────────────────────

const args    = process.argv.slice(2);
const isTrim  = args.includes('--trim');
const cleanArgs = args.filter(a => a !== '--trim');

if (!isTrim && cleanArgs.length < 4) {
  emit({ type: 'error', message: 'Usage: node hbr_split_cli.js <input> <output1> <output2> <splitFrame>' });
  process.exit(1);
}
if (isTrim && cleanArgs.length < 4) {
  emit({ type: 'error', message: 'Usage: node hbr_split_cli.js <input> <output> <startFrame> <endFrame> --trim' });
  process.exit(1);
}

const IN_PATH = cleanArgs[0];

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

/**
 * Extracts events and goals in [fromFrame, toFrame], re-offset to start at 0.
 * Events at frame 0 of original (startGame / room-init) are always prepended
 * so the output file is valid and openable in HaxBall.
 */
function encodeSegment(allEvents, allGoals, fromFrame, toFrame, totalOrigFrames) {
  // Always include the very first event (startGame / room-init) at frame 0
  const initEvents = allEvents
    .filter(e => e.frame <= Math.min(2, fromFrame))   // setup events near start
    .map(e => ({ frame: 0, bytes: e.bytes }));        // pin to frame 0

  const segEvents = allEvents
    .filter(e => e.frame > fromFrame && e.frame <= toFrame)
    .map(e => ({ frame: e.frame - fromFrame, bytes: e.bytes }));

  const combinedEvents = fromFrame > 0
    ? [...initEvents, ...segEvents]
    : segEvents;   // Part 1 already starts at 0, no duplicate needed

  const segGoals = allGoals
    .filter(g => g.frame > fromFrame && g.frame <= toFrame)
    .map(g => ({ frame: g.frame - fromFrame, team: g.team }));

  const frames = toFrame - fromFrame;
  return { events: combinedEvents, goals: segGoals, frames };
}

// ── Main ──────────────────────────────────────────────────────────────────────

try {
  emit({ type: 'progress', step: 'reading', name: path.basename(IN_PATH) });
  const f = parseHbr2(IN_PATH);
  emit({ type: 'info', totalFrames: f.frames });

  emit({ type: 'progress', step: 'decoding' });
  const d = decodePayload(f.payload);
  emit({ type: 'info', goals: d.goals.length, events: d.events.length });

  if (isTrim) {
    // ── TRIM MODE ─────────────────────────────────────────────────────────────
    const OUT_PATH   = cleanArgs[1];
    const START_FRAME = parseInt(cleanArgs[2], 10);
    const END_FRAME   = parseInt(cleanArgs[3], 10);

    if (isNaN(START_FRAME) || isNaN(END_FRAME) || START_FRAME < 0 || END_FRAME <= START_FRAME) {
      emit({ type: 'error', message: 'startFrame must be >= 0 and < endFrame' });
      process.exit(1);
    }
    if (END_FRAME > f.frames) {
      emit({ type: 'error', message: `endFrame (${END_FRAME}) exceeds totalFrames (${f.frames})` });
      process.exit(1);
    }

    emit({ type: 'progress', step: 'trimming', start: START_FRAME, end: END_FRAME });
    const seg = encodeSegment(d.events, d.goals, START_FRAME, END_FRAME, f.frames);

    emit({ type: 'progress', step: 'writing', output: OUT_PATH });
    const payload = encodePayload(seg.goals, seg.events);
    const output  = buildHbr2(seg.frames, payload);
    fs.writeFileSync(OUT_PATH, output);

    const stat = fs.statSync(OUT_PATH);
    emit({
      type   : 'done',
      frames : seg.frames,
      events : seg.events.length,
      goals  : seg.goals.length,
      output : OUT_PATH,
      bytes  : stat.size
    });

  } else {
    // ── SPLIT MODE ────────────────────────────────────────────────────────────
    const OUT1_PATH = cleanArgs[1];
    const OUT2_PATH = cleanArgs[2];
    const SPLIT_AT  = parseInt(cleanArgs[3], 10);

    if (isNaN(SPLIT_AT) || SPLIT_AT <= 0) {
      emit({ type: 'error', message: 'splitFrame must be a positive integer' });
      process.exit(1);
    }
    if (SPLIT_AT >= f.frames) {
      emit({ type: 'error', message: `splitFrame (${SPLIT_AT}) must be less than totalFrames (${f.frames})` });
      process.exit(1);
    }

    // Part 1: frames [0 .. SPLIT_AT]
    emit({ type: 'progress', step: 'building_part1' });
    const p1 = encodeSegment(d.events, d.goals, 0, SPLIT_AT, f.frames);

    emit({ type: 'progress', step: 'writing', output: OUT1_PATH });
    const payload1 = encodePayload(p1.goals, p1.events);
    const output1  = buildHbr2(p1.frames, payload1);
    fs.writeFileSync(OUT1_PATH, output1);
    const s1 = fs.statSync(OUT1_PATH);
    emit({ type: 'part1_done', frames: p1.frames, events: p1.events.length, goals: p1.goals.length, bytes: s1.size, output: OUT1_PATH });

    // Part 2: frames (SPLIT_AT .. end]
    emit({ type: 'progress', step: 'building_part2' });
    const p2 = encodeSegment(d.events, d.goals, SPLIT_AT, f.frames, f.frames);

    emit({ type: 'progress', step: 'writing', output: OUT2_PATH });
    const payload2 = encodePayload(p2.goals, p2.events);
    const output2  = buildHbr2(p2.frames, payload2);
    fs.writeFileSync(OUT2_PATH, output2);
    const s2 = fs.statSync(OUT2_PATH);
    emit({ type: 'part2_done', frames: p2.frames, events: p2.events.length, goals: p2.goals.length, bytes: s2.size, output: OUT2_PATH });

    emit({ type: 'done', splitAt: SPLIT_AT });
  }

} catch (e) {
  emit({ type: 'error', message: e.message });
  process.exit(1);
}

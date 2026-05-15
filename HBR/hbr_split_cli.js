/**
 * hbr_split_cli.js  —  HBR Studio Split/Trim CLI
 *
 * Usage:
 *   node hbr_split_cli.js <input.hbr2> <output1.hbr2> <output2.hbr2> <splitFrame>
 *
 * Splits a replay at <splitFrame>:
 *   Part 1 → events [0 .. splitFrame]   → output1
 *   Part 2 → events (splitFrame .. end] → output2 (re-offset to start at 0)
 *
 * Emits JSON progress lines to stdout.
 * HaxBall runs at 60 steps/sec:  frame = minutes*60*60 + seconds*60
 */

// ── Silence node-haxball verbose output ───────────────────────────────────────
const origWrite = process.stdout.write.bind(process.stdout);
const origErr   = process.stderr.write.bind(process.stderr);
process.stdout.write = () => true;
process.stderr.write = () => true;

const { performance } = require('perf_hooks');
const pako            = require('pako');
const { Replay, EventFactory } = require('node-haxball')({ performance, pako });

process.stdout.write = origWrite;
process.stderr.write = origErr;

const fs   = require('fs');
const path = require('path');

// ── Parse args ────────────────────────────────────────────────────────────────
const args = process.argv.slice(2);
if (args.length < 4) {
  origWrite(JSON.stringify({
    type: 'error',
    message: 'Usage: node hbr_split_cli.js <input> <output1> <output2> <splitFrame>'
  }) + '\n');
  process.exit(1);
}

const IN_PATH   = args[0];
const OUT1_PATH = args[1];
const OUT2_PATH = args[2];
const SPLIT_AT  = parseInt(args[3], 10);

if (isNaN(SPLIT_AT) || SPLIT_AT <= 0) {
  origWrite(JSON.stringify({ type: 'error', message: 'splitFrame must be a positive integer' }) + '\n');
  process.exit(1);
}

function emit(obj) { origWrite(JSON.stringify(obj) + '\n'); }

// ── Read input ────────────────────────────────────────────────────────────────
emit({ type: 'progress', step: 'reading', name: path.basename(IN_PATH) });

let r;
try {
  const buf = new Uint8Array(fs.readFileSync(IN_PATH));
  r = Replay.readAll(buf);
} catch (e) {
  emit({ type: 'error', message: `Failed to read ${IN_PATH}: ${e.message}` });
  process.exit(1);
}

emit({
  type: 'info',
  totalFrames : r.totalFrames,
  events      : r.events.length,
  goals       : r.goalMarkers.length,
  splitAt     : SPLIT_AT
});

if (SPLIT_AT >= r.totalFrames) {
  emit({ type: 'error', message: `splitFrame (${SPLIT_AT}) must be less than totalFrames (${r.totalFrames})` });
  process.exit(1);
}

// ── Build Part 1 ──────────────────────────────────────────────────────────────
emit({ type: 'progress', step: 'building_part1' });

const part1 = {
  roomData    : r.roomData,
  totalFrames : SPLIT_AT,
  events      : r.events.filter(e => e.frameNo <= SPLIT_AT),
  goalMarkers : r.goalMarkers.filter(g => g.frameNo <= SPLIT_AT)
};

// ── Build Part 2 ──────────────────────────────────────────────────────────────
emit({ type: 'progress', step: 'building_part2' });

// Re-offset so part2 starts at frame 0
const part2Events = r.events.filter(e => e.frameNo > SPLIT_AT);
part2Events.forEach(e => { e.frameNo -= SPLIT_AT; });

const part2GoalMarkers = r.goalMarkers
  .filter(g => g.frameNo > SPLIT_AT)
  .map(g => ({ frameNo: g.frameNo - SPLIT_AT, teamId: g.teamId }));

// Preserve the original room state for part2 (same starting positions)
// Note: physical game state may differ from room state at splitFrame, but
// the player input sequence from splitFrame onwards will replay correctly.
const part2 = {
  roomData    : r.roomData,
  totalFrames : r.totalFrames - SPLIT_AT,
  events      : part2Events,
  goalMarkers : part2GoalMarkers
};

// ── Write outputs ─────────────────────────────────────────────────────────────
emit({ type: 'progress', step: 'writing', output: OUT1_PATH });
try {
  const out1 = Replay.writeAll(part1);
  fs.writeFileSync(OUT1_PATH, Buffer.from(out1));
  const s1 = fs.statSync(OUT1_PATH);
  emit({ type: 'part1_done', frames: part1.totalFrames, events: part1.events.length, goals: part1.goalMarkers.length, bytes: s1.size, output: OUT1_PATH });
} catch (e) {
  emit({ type: 'error', message: `Failed to write part1: ${e.message}` });
  process.exit(1);
}

emit({ type: 'progress', step: 'writing', output: OUT2_PATH });
try {
  const out2 = Replay.writeAll(part2);
  fs.writeFileSync(OUT2_PATH, Buffer.from(out2));
  const s2 = fs.statSync(OUT2_PATH);
  emit({ type: 'part2_done', frames: part2.totalFrames, events: part2.events.length, goals: part2.goalMarkers.length, bytes: s2.size, output: OUT2_PATH });
} catch (e) {
  emit({ type: 'error', message: `Failed to write part2: ${e.message}` });
  process.exit(1);
}

emit({ type: 'done', splitAt: SPLIT_AT });

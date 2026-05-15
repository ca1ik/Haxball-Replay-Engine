/**
 * hbr_merge_cli.js  —  HBR Studio Merge CLI
 *
 * Usage:
 *   node hbr_merge_cli.js <output.hbr2> <file1.hbr2> <file2.hbr2>
 *
 * Merges exactly 2 replay files using node-haxball Replay API.
 * Emits JSON progress lines to stdout.
 */

// Silence node-haxball startup noise
const origWrite = process.stdout.write.bind(process.stdout);
const origErr   = process.stderr.write.bind(process.stderr);
process.stdout.write = () => true;
process.stderr.write = () => true;

const { performance } = require('perf_hooks');
const pako = require('pako');
const { Replay } = require('node-haxball')({ performance, pako });

process.stdout.write = origWrite;
process.stderr.write = origErr;

const fs   = require('fs');
const path = require('path');

// ── Emit ──────────────────────────────────────────────────────────────────────

function emit(obj) { origWrite(JSON.stringify(obj) + '\n'); }

// ── Arg parsing ───────────────────────────────────────────────────────────────

const args = process.argv.slice(2);
if (args.length < 3) {
  emit({ type: 'error', message: 'Usage: node hbr_merge_cli.js <output> <file1> <file2>' });
  process.exit(1);
}

const OUT_PATH = args[0];
const FILE1    = args[1];
const FILE2    = args[2];

// ── Main ──────────────────────────────────────────────────────────────────────

try {
  emit({ type: 'progress', step: 'reading', file: 1, total: 2, name: path.basename(FILE1) });
  const r1 = Replay.readAll(new Uint8Array(fs.readFileSync(FILE1)));
  emit({ type: 'info', file: 1, frames: r1.totalFrames, goals: r1.goalMarkers.length, events: r1.events.length });

  emit({ type: 'progress', step: 'reading', file: 2, total: 2, name: path.basename(FILE2) });
  const r2 = Replay.readAll(new Uint8Array(fs.readFileSync(FILE2)));
  emit({ type: 'info', file: 2, frames: r2.totalFrames, goals: r2.goalMarkers.length, events: r2.events.length });

  emit({ type: 'progress', step: 'merging', pair: 1, total: 1 });
  const OFFSET = r1.totalFrames + 1;

  // Offset all file2 events and goalMarkers in place
  r2.events.forEach(e => { e.frameNo += OFFSET; });
  const goals2 = r2.goalMarkers.map(g => ({ frameNo: g.frameNo + OFFSET, teamId: g.teamId }));

  // Merge into r1
  r1.events       = r1.events.concat(r2.events);
  r1.goalMarkers  = r1.goalMarkers.concat(goals2);
  r1.totalFrames  = r1.totalFrames + 1 + r2.totalFrames;

  // Ensure output directory exists
  fs.mkdirSync(path.dirname(path.resolve(OUT_PATH)), { recursive: true });

  emit({ type: 'progress', step: 'writing', output: OUT_PATH });
  const output = Replay.writeAll(r1);
  fs.writeFileSync(OUT_PATH, Buffer.from(output));

  const stat = fs.statSync(OUT_PATH);
  emit({
    type   : 'done',
    frames : r1.totalFrames,
    events : r1.events.length,
    goals  : r1.goalMarkers.length,
    output : OUT_PATH,
    bytes  : stat.size
  });

} catch (e) {
  emit({ type: 'error', message: e.message });
  process.exit(1);
}

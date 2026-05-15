/**
 * hbr_split_cli.js  —  HBR Studio Split / Trim CLI
 *
 * SPLIT mode (default):
 *   node hbr_split_cli.js <input> <output1> <output2> <splitFrame>
 *   -> Part 1: frames [0 .. splitFrame]     -> output1
 *   -> Part 2: frames (splitFrame .. end]   -> output2 (re-offset to 0)
 *
 * TRIM mode (--trim flag):
 *   node hbr_split_cli.js <input> <output> <startFrame> <endFrame> --trim
 *   -> Segment: frames [startFrame .. endFrame] -> output (re-offset to 0)
 *
 * HaxBall runs at 60 steps/sec:  frame = minutes*60*60 + seconds*60
 * Emits JSON progress lines to stdout.
 *
 * Uses Replay.readAll / Replay.trim(r, {beginFrameNo, endFrameNo}) / Replay.writeAll
 * from node-haxball. Replay.trim modifies the replay in-place, filtering events
 * and goalMarkers to [begin, end] and rebasing frameNos.
 */

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

function emit(obj) { origWrite(JSON.stringify(obj) + '\n'); }

// ── Arg parsing ───────────────────────────────────────────────────────────────

const args      = process.argv.slice(2);
const isTrim    = args.includes('--trim');
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

// ── Helpers ───────────────────────────────────────────────────────────────────

function readReplay(filePath) {
  return Replay.readAll(new Uint8Array(fs.readFileSync(filePath)));
}

function writeSegment(r, outPath) {
  fs.mkdirSync(path.dirname(path.resolve(outPath)), { recursive: true });
  const output = Replay.writeAll(r);
  fs.writeFileSync(outPath, Buffer.from(output));
  return fs.statSync(outPath).size;
}

// ── Main ──────────────────────────────────────────────────────────────────────

try {
  emit({ type: 'progress', step: 'reading', name: path.basename(IN_PATH) });
  const totalFrames = readReplay(IN_PATH).TX;
  emit({ type: 'info', totalFrames });

  if (isTrim) {
    // ── TRIM MODE ─────────────────────────────────────────────────────────────
    const OUT_PATH    = cleanArgs[1];
    const START_FRAME = parseInt(cleanArgs[2], 10);
    const END_FRAME   = parseInt(cleanArgs[3], 10);

    if (isNaN(START_FRAME) || isNaN(END_FRAME) || START_FRAME < 0 || END_FRAME <= START_FRAME) {
      emit({ type: 'error', message: 'startFrame must be >= 0 and < endFrame' });
      process.exit(1);
    }
    if (END_FRAME > totalFrames) {
      emit({ type: 'error', message: `endFrame (${END_FRAME}) exceeds totalFrames (${totalFrames})` });
      process.exit(1);
    }

    emit({ type: 'progress', step: 'trimming', start: START_FRAME, end: END_FRAME });
    const r = readReplay(IN_PATH);
    Replay.trim(r, { beginFrameNo: START_FRAME, endFrameNo: END_FRAME });

    emit({ type: 'progress', step: 'writing', output: OUT_PATH });
    const bytes = writeSegment(r, OUT_PATH);
    emit({
      type   : 'done',
      frames : r.TX,
      events : r.gD.length,
      goals  : r.Ac.length,
      output : OUT_PATH,
      bytes,
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
    if (SPLIT_AT >= totalFrames) {
      emit({ type: 'error', message: `splitFrame (${SPLIT_AT}) must be less than totalFrames (${totalFrames})` });
      process.exit(1);
    }

    // Part 1: [0 .. SPLIT_AT]
    emit({ type: 'progress', step: 'building_part1' });
    const r1 = readReplay(IN_PATH);
    Replay.trim(r1, { beginFrameNo: 0, endFrameNo: SPLIT_AT });
    emit({ type: 'progress', step: 'writing', output: OUT1_PATH });
    const s1 = writeSegment(r1, OUT1_PATH);
    emit({ type: 'part1_done', frames: r1.TX, events: r1.gD.length, goals: r1.Ac.length, bytes: s1, output: OUT1_PATH });

    // Part 2: [SPLIT_AT .. end]
    emit({ type: 'progress', step: 'building_part2' });
    const r2 = readReplay(IN_PATH);
    Replay.trim(r2, { beginFrameNo: SPLIT_AT, endFrameNo: totalFrames });
    emit({ type: 'progress', step: 'writing', output: OUT2_PATH });
    const s2 = writeSegment(r2, OUT2_PATH);
    emit({ type: 'part2_done', frames: r2.TX, events: r2.gD.length, goals: r2.Ac.length, bytes: s2, output: OUT2_PATH });

    emit({ type: 'done', splitAt: SPLIT_AT });
  }

} catch (e) {
  emit({ type: 'error', message: e.message });
  process.exit(1);
}

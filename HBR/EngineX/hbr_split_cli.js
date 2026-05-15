/**
 * hbr_split_cli.js  â€”  HBR Studio Split / Trim CLI
 *
 * Uses node-haxball Replay API for reliable binary serialization.
 *
 * SPLIT mode (default):
 *   node hbr_split_cli.js <input> <output1> <output2> <splitFrame>
 *   â†’ Part 1: frames [0 .. splitFrame]     â†’ output1
 *   â†’ Part 2: frames (splitFrame .. end]   â†’ output2 (re-offset to 0)
 *
 * TRIM mode (--trim flag):
 *   node hbr_split_cli.js <input> <output> <startFrame> <endFrame> --trim
 *   â†’ Segment: frames [startFrame .. endFrame] â†’ output (re-offset to 0)
 *
 * HaxBall runs at 60 steps/sec:  frame = minutes*60*60 + seconds*60
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

// â”€â”€ Emit â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function emit(obj) { origWrite(JSON.stringify(obj) + '\n'); }

// â”€â”€ Arg parsing â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€ Segment extractor â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/**
 * Returns a modified replay object containing only events/goals in [fromFrame, toFrame].
 * Events at frameNo === 0 (room init / startGame) are always prepended to ensure
 * the output replay is independently playable.
 * All frameNo values are re-offset so the segment starts at frame 0.
 * The original replay `r` is NOT mutated.
 */
function extractSegment(r, fromFrame, toFrame) {
  // Init events (frame 0): room-setup, startGame â€” always keep so room state is valid
  const initEvents = fromFrame > 0
    ? r.events.filter(e => e.frameNo === 0).map(e => Object.assign({}, e, { frameNo: 0 }))
    : [];

  // Segment events: strictly inside the range, re-offset
  const segEvents = r.events
    .filter(e => e.frameNo > fromFrame && e.frameNo <= toFrame)
    .map(e => Object.assign({}, e, { frameNo: e.frameNo - fromFrame }));

  // Goals in range, re-offset
  const segGoals = r.goalMarkers
    .filter(g => g.frameNo > fromFrame && g.frameNo <= toFrame)
    .map(g => ({ frameNo: g.frameNo - fromFrame, teamId: g.teamId }));

  // Build segment by shallow-copying r (preserves roomData and internal fields)
  const seg          = Object.assign({}, r);
  seg.events         = fromFrame > 0 ? [...initEvents, ...segEvents] : segEvents;
  seg.goalMarkers    = segGoals;
  seg.totalFrames    = toFrame - fromFrame;
  return seg;
}

// â”€â”€ Main â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

try {
  emit({ type: 'progress', step: 'reading', name: path.basename(IN_PATH) });
  const rawBuf = fs.readFileSync(IN_PATH);
  const r = Replay.readAll(new Uint8Array(rawBuf));
  emit({ type: 'info', totalFrames: r.totalFrames, goals: r.goalMarkers.length, events: r.events.length });

  if (isTrim) {
    // â”€â”€ TRIM MODE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    const OUT_PATH    = cleanArgs[1];
    const START_FRAME = parseInt(cleanArgs[2], 10);
    const END_FRAME   = parseInt(cleanArgs[3], 10);

    if (isNaN(START_FRAME) || isNaN(END_FRAME) || START_FRAME < 0 || END_FRAME <= START_FRAME) {
      emit({ type: 'error', message: 'startFrame must be >= 0 and < endFrame' });
      process.exit(1);
    }
    if (END_FRAME > r.totalFrames) {
      emit({ type: 'error', message: `endFrame (${END_FRAME}) exceeds totalFrames (${r.totalFrames})` });
      process.exit(1);
    }

    emit({ type: 'progress', step: 'trimming', start: START_FRAME, end: END_FRAME });
    const seg = extractSegment(r, START_FRAME, END_FRAME);

    emit({ type: 'progress', step: 'writing', output: OUT_PATH });
    fs.mkdirSync(path.dirname(path.resolve(OUT_PATH)), { recursive: true });
    fs.writeFileSync(OUT_PATH, Buffer.from(Replay.writeAll(seg)));

    const stat = fs.statSync(OUT_PATH);
    emit({
      type   : 'done',
      frames : seg.totalFrames,
      events : seg.events.length,
      goals  : seg.goalMarkers.length,
      output : OUT_PATH,
      bytes  : stat.size
    });

  } else {
    // â”€â”€ SPLIT MODE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    const OUT1_PATH = cleanArgs[1];
    const OUT2_PATH = cleanArgs[2];
    const SPLIT_AT  = parseInt(cleanArgs[3], 10);

    if (isNaN(SPLIT_AT) || SPLIT_AT <= 0) {
      emit({ type: 'error', message: 'splitFrame must be a positive integer' });
      process.exit(1);
    }
    if (SPLIT_AT >= r.totalFrames) {
      emit({ type: 'error', message: `splitFrame (${SPLIT_AT}) must be less than totalFrames (${r.totalFrames})` });
      process.exit(1);
    }

    // Part 1: frames [0 .. SPLIT_AT]
    emit({ type: 'progress', step: 'building_part1' });
    const p1 = extractSegment(r, 0, SPLIT_AT);

    emit({ type: 'progress', step: 'writing', output: OUT1_PATH });
    fs.mkdirSync(path.dirname(path.resolve(OUT1_PATH)), { recursive: true });
    fs.writeFileSync(OUT1_PATH, Buffer.from(Replay.writeAll(p1)));
    const s1 = fs.statSync(OUT1_PATH);
    emit({ type: 'part1_done', frames: p1.totalFrames, events: p1.events.length, goals: p1.goalMarkers.length, bytes: s1.size, output: OUT1_PATH });

    // Part 2: frames (SPLIT_AT .. end] â€” need a fresh parse so r is unmodified
    emit({ type: 'progress', step: 'building_part2' });
    const r2 = Replay.readAll(new Uint8Array(rawBuf));
    const p2 = extractSegment(r2, SPLIT_AT, r2.totalFrames);

    emit({ type: 'progress', step: 'writing', output: OUT2_PATH });
    fs.mkdirSync(path.dirname(path.resolve(OUT2_PATH)), { recursive: true });
    fs.writeFileSync(OUT2_PATH, Buffer.from(Replay.writeAll(p2)));
    const s2 = fs.statSync(OUT2_PATH);
    emit({ type: 'part2_done', frames: p2.totalFrames, events: p2.events.length, goals: p2.goalMarkers.length, bytes: s2.size, output: OUT2_PATH });

    emit({ type: 'done', splitAt: SPLIT_AT });
  }

} catch (e) {
  emit({ type: 'error', message: e.message });
  process.exit(1);
}


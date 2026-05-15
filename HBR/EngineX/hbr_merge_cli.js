/**
 * hbr_merge_cli.js  —  HBR Studio Merge CLI
 *
 * Usage:
 *   node hbr_merge_cli.js <output.hbr2> <file1.hbr2> <file2.hbr2> [file3.hbr2 ...]
 *
 * Merges N replay files in order. Emits JSON progress lines to stdout:
 *   {"type":"progress","step":"reading","file":1,"total":N}
 *   {"type":"progress","step":"merging","pair":1,"total":N-1}
 *   {"type":"done","frames":86411,"events":140378,"goals":16,"output":"..."}
 *   {"type":"error","message":"..."}
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
if (args.length < 3) {
  origWrite(JSON.stringify({ type: 'error', message: 'Usage: node hbr_merge_cli.js <output> <file1> <file2> [...]' }) + '\n');
  process.exit(1);
}

const OUT_PATH   = args[0];
const FILE_PATHS = args.slice(1);
const N          = FILE_PATHS.length;

// ── Emit helpers ──────────────────────────────────────────────────────────────
function emit(obj) { origWrite(JSON.stringify(obj) + '\n'); }

// ── Read all files ────────────────────────────────────────────────────────────
const replays = [];

for (let i = 0; i < N; i++) {
  emit({ type: 'progress', step: 'reading', file: i + 1, total: N, name: path.basename(FILE_PATHS[i]) });
  try {
    const buf  = new Uint8Array(fs.readFileSync(FILE_PATHS[i]));
    const rep  = Replay.readAll(buf);
    replays.push(rep);
    emit({ type: 'info', file: i + 1, frames: rep.totalFrames, events: rep.events.length, goals: rep.goalMarkers.length });
  } catch (e) {
    emit({ type: 'error', message: `Failed to read ${FILE_PATHS[i]}: ${e.message}` });
    process.exit(1);
  }
}

// ── Merge pairs: result = replays[0] ⊕ replays[1] ⊕ ... ─────────────────────
function mergeTwo(r1, r2, pairIndex, totalPairs) {
  emit({ type: 'progress', step: 'merging', pair: pairIndex, total: totalPairs });

  const STOP_FRAME = r1.totalFrames + 1;
  const TEAM_FRAME = r1.totalFrames + 2;
  const OFFSET     = r1.totalFrames + 3;

  // Host = issuer of FILE2's first startGame
  const hostId = r2.events.find(e => e.type === 7)?.X ?? r2.events[0].X;

  // stopGame
  const stopEvt = EventFactory.stopGame();
  stopEvt.frameNo = STOP_FRAME;
  stopEvt.X = hostId;

  // Spec-clear FILE1 team players
  const specEvts = [];
  r1.roomData.players.forEach(p => {
    const tid = p.team && typeof p.team === 'object' ? p.team.$ : (p.team || 0);
    if (tid === 1 || tid === 2) {
      const evt = EventFactory.setPlayerTeam(p.id, 0);
      if (evt) { evt.frameNo = TEAM_FRAME; evt.X = hostId; specEvts.push(evt); }
    }
  });

  // Re-assign in FILE2's exact room state order
  const assignEvts = [];
  r2.roomData.players.forEach(p => {
    const tid = p.team && typeof p.team === 'object' ? p.team.$ : (p.team || 0);
    if (tid === 1 || tid === 2) {
      const evt = EventFactory.setPlayerTeam(p.id, tid);
      if (evt) { evt.frameNo = TEAM_FRAME; evt.X = hostId; assignEvts.push(evt); }
    }
  });

  const teamEvts = [...specEvts, ...assignEvts];

  // Offset FILE2 events
  r2.events.forEach(e => { e.frameNo += OFFSET; });

  // Concatenate
  r1.events = r1.events.concat([stopEvt], teamEvts, r2.events);

  // Goal markers
  r2.goalMarkers.forEach(g =>
    r1.goalMarkers.push({ frameNo: g.frameNo + OFFSET, teamId: g.teamId })
  );

  r1.totalFrames = r1.totalFrames + 3 + r2.totalFrames;
  return r1;
}

let result = replays[0];
for (let i = 1; i < replays.length; i++) {
  result = mergeTwo(result, replays[i], i, replays.length - 1);
}

// ── Write output ──────────────────────────────────────────────────────────────
emit({ type: 'progress', step: 'writing', output: OUT_PATH });
try {
  const output = Replay.writeAll(result);
  fs.writeFileSync(OUT_PATH, Buffer.from(output));

  const stat = fs.statSync(OUT_PATH);
  emit({
    type   : 'done',
    frames : result.totalFrames,
    events : result.events.length,
    goals  : result.goalMarkers.length,
    output : OUT_PATH,
    bytes  : stat.size
  });
} catch (e) {
  emit({ type: 'error', message: `Failed to write output: ${e.message}` });
  process.exit(1);
}

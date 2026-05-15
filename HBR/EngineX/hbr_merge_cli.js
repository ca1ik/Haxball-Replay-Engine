/**
 * hbr_merge_cli.js  —  HBR Studio Merge CLI  (v5)
 *
 * Usage:
 *   node hbr_merge_cli.js <output.hbr2> <file1.hbr2> <file2.hbr2>
 *
 * Merges exactly 2 replay files using node-haxball Replay API.
 *
 * KEY FIX (v5): Injects StopGame + SetPlayerTeam at the half-time
 * transition so the physics engine correctly resets for file2.
 * Without StopGame, the engine cannot start file2's game (game already
 * running) and all second-half physics/goals are lost.
 *
 * ALGORITHM:
 *   1. Offset all file2 events by fc1 (frame count of file1)
 *   2. Shift file2's StartGame by +2 extra (making room for injected events)
 *   3. Inject at transition:
 *      a. StopGame at fc1           — stops file1's game, resets physics
 *      [b. KickBanPlayer+JoinRoom at fc1 — only for different-room files]
 *      c. SetPlayerTeam at fc1+1    — ensures correct team assignments for file2
 *   4. File2's StartGame fires naturally at fc1+2
 *
 * StopGame is created via EventFactory (always available).
 * SetPlayerTeam template is sourced from: merged_final.hbr2 → input files.
 * If no SetPlayerTeam template is found, team injection is skipped
 * (degraded mode — goals still play, teams may be mismatched).
 *
 * Emits JSON progress lines to stdout.
 */

const origWrite = process.stdout.write.bind(process.stdout);
const origErr   = process.stderr.write.bind(process.stderr);
process.stdout.write = () => true;
process.stderr.write = () => true;

const { performance } = require('perf_hooks');
const pako = require('pako');
const api = require('node-haxball')({ performance, pako });
const { Replay, OperationType, EventFactory } = api;

process.stdout.write = origWrite;
process.stderr.write = origErr;

const fs   = require('fs');
const path = require('path');

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

// ── Helper: clone event preserving prototype, override specific fields ────────
function cloneEv(template, fields) {
  const ev = Object.create(Object.getPrototypeOf(template));
  for (const k of Object.getOwnPropertyNames(template)) ev[k] = template[k];
  for (const [k, v] of Object.entries(fields)) ev[k] = v;
  return ev;
}

// ── Main ──────────────────────────────────────────────────────────────────────

try {
  emit({ type: 'progress', step: 'reading', file: 1, total: 2, name: path.basename(FILE1) });
  const r1 = Replay.readAll(new Uint8Array(fs.readFileSync(FILE1)));
  emit({ type: 'info', file: 1, frames: r1.TX, goals: r1.Ac.length, events: r1.gD.length });

  emit({ type: 'progress', step: 'reading', file: 2, total: 2, name: path.basename(FILE2) });
  const r2 = Replay.readAll(new Uint8Array(fs.readFileSync(FILE2)));
  emit({ type: 'info', file: 2, frames: r2.TX, goals: r2.Ac.length, events: r2.gD.length });

  emit({ type: 'progress', step: 'merging', pair: 1, total: 1 });

  const fc1 = r1.TX;
  const fc2 = r2.TX;

  // ── Detect same-room vs different-room ──────────────────────────────────────
  const r1Ids = new Set(r1.r.players.map(p => p['$']).filter(id => id !== 0));
  const r2Ids = new Set(r2.r.players.map(p => p['$']).filter(id => id !== 0));
  const overlap = [...r1Ids].filter(id => r2Ids.has(id)).length;
  const sameRoom = overlap > Math.min(r1Ids.size, r2Ids.size) * 0.5;
  emit({ type: 'debug', same_room: sameRoom, overlap });

  // ── Load event templates ────────────────────────────────────────────────────
  // StopGame: always available via EventFactory (eventType=8 on prototype).
  const stopEvTemplate = EventFactory.stopGame(0);

  // SetPlayerTeam: search seed file → input files (fallback chain).
  // merged_final.hbr2 serves as a permanent template seed in EngineX/.
  let setTeamTemplate = null;
  const seedPath = path.join(__dirname, 'merged_final.hbr2');
  if (fs.existsSync(seedPath)) {
    try {
      const seed = Replay.readAll(new Uint8Array(fs.readFileSync(seedPath)));
      setTeamTemplate = seed.gD.find(e => e.eventType === OperationType.SetPlayerTeam) || null;
    } catch (_) { /* seed unreadable — fall through */ }
  }
  if (!setTeamTemplate) {
    setTeamTemplate = r1.gD.find(e => e.eventType === OperationType.SetPlayerTeam)
                   || r2.gD.find(e => e.eventType === OperationType.SetPlayerTeam)
                   || null;
  }
  emit({ type: 'debug', stopTemplate: !!stopEvTemplate, setTeamTemplate: !!setTeamTemplate });

  // ── Offset r2 frames, apply X=0 fix, shift file2's StartGame by +2 ─────────
  // The +2 shift on StartGame reserves frames fc1 and fc1+1 for injected
  // StopGame and SetPlayerTeam events so they fire before the new game begins.
  let fixedCount = 0;
  for (let i = 0; i < r2.gD.length; i++) {
    r2.gD[i].frameNo += fc1;
    if (r2.gD[i].eventType === OperationType.StartGame) r2.gD[i].frameNo += 2;
    if (r2.gD[i].eventType !== OperationType.SendInput && r2.gD[i]['X'] !== 0) {
      r2.gD[i]['X'] = 0;
      fixedCount++;
    }
  }
  for (const g of r2.Ac) g.frameNo += fc1;
  emit({ type: 'debug', x_fixed: fixedCount });

  // ── Build transition events ─────────────────────────────────────────────────
  const transition = [];

  // 1. StopGame at fc1 — stops file1's running game, physics reset
  const stopEv = cloneEv(stopEvTemplate, { 'D_': 0, 'N$': 0, 'X': 0, 'frameNo': fc1 });
  transition.push(stopEv);

  // 2. (Different-room only) Kick file1 players, join file2 players at fc1
  if (!sameRoom) {
    const kickTemplate = r1.gD.find(e => e.eventType === OperationType.KickBanPlayer);
    const joinTemplate = r2.gD.find(e => e.eventType === OperationType.JoinRoom);

    if (kickTemplate) {
      for (const p of r1.r.players) {
        if (p['$'] === 0) continue;
        transition.push(cloneEv(kickTemplate, {
          'N$': 0, '$': p['$'], 'JD': null, 'Ec': false, 'X': 0, 'frameNo': fc1
        }));
      }
    }

    if (joinTemplate) {
      for (const p of r2.r.players) {
        if (p['$'] === 0) continue;
        transition.push(cloneEv(joinTemplate, {
          'N$': 0, '$': p['$'], 'L': p['L'], 'h$': p['h$'], 'F$': p['F$'], 'X': 0, 'frameNo': fc1
        }));
      }
    }
  }

  // 3. SetPlayerTeam at fc1+1 — assign correct teams for file2's game
  //    First pass: move all file2 players to spec (team 0)
  //    Second pass: assign actual file2 teams
  if (setTeamTemplate) {
    const specTeam = { '$': 0, 'u': 16777215, 'yg': 0, 'f': -1, 'g': 0 };
    for (const p of r2.r.players) {
      if (p['$'] === 0) continue;
      transition.push(cloneEv(setTeamTemplate, {
        'N$': 0, 'K': p['$'], 'p': specTeam, 'X': 0, 'frameNo': fc1 + 1
      }));
    }
    for (const p of r2.r.players) {
      if (p['$'] === 0) continue;
      const teamId = p.p ? p.p['$'] : 0;
      if (teamId === 0) continue;
      transition.push(cloneEv(setTeamTemplate, {
        'N$': 0, 'K': p['$'], 'p': p.p, 'X': 0, 'frameNo': fc1 + 1
      }));
    }
  }

  // 4. File2's StartGame (shifted to fc1+2) fires naturally from r2.gD
  emit({ type: 'debug', transition_events: transition.length });

  // ── Merge: r1 + transition + r2 ─────────────────────────────────────────────
  for (const e of transition) r1.gD.push(e);
  for (const e of r2.gD)      r1.gD.push(e);
  for (const g of r2.Ac)      r1.Ac.push(g);
  r1.TX = fc1 + fc2;

  // Ensure output directory exists
  fs.mkdirSync(path.dirname(path.resolve(OUT_PATH)), { recursive: true });

  emit({ type: 'progress', step: 'writing', output: OUT_PATH });
  const output = Replay.writeAll(r1);
  fs.writeFileSync(OUT_PATH, Buffer.from(output));

  const stat = fs.statSync(OUT_PATH);
  emit({
    type   : 'done',
    frames : r1.TX,
    events : r1.gD.length,
    goals  : r1.Ac.length,
    output : OUT_PATH,
    bytes  : stat.size
  });

} catch (e) {
  emit({ type: 'error', message: e.message });
  process.exit(1);
}

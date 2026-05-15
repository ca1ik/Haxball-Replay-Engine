/**
 * hbr_merge_cli.js  —  HBR Studio Merge CLI  (v3)
 *
 * Usage:
 *   node hbr_merge_cli.js <output.hbr2> <file1.hbr2> <file2.hbr2>
 *
 * Merges exactly 2 replay files using node-haxball Replay API.
 *
 * v3 fix — works for ANY 2 files, including different rooms/player sets:
 *   At the transition frame (fc1), injects:
 *     1. KickBanPlayer  — removes all file1 players to clear the room
 *     2. JoinRoom       — re-adds all file2 initial players
 *     3. SetPlayerTeam  — assigns file2 initial players to their correct teams
 *   Also sets X=0 on all non-SendInput events from file2 so that admin-action
 *   events (SetPlayerTeam, PauseResumeGame, …) are treated as host-executed.
 *   Without this fix, those events fail an authorization check because the
 *   original sender player has no admin rights in the merged room.
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
const { Replay, OperationType } = api;

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

  // ── Event templates (prototype must be preserved for writeAll) ──────────────
  const kickTemplate    = r1.gD.find(e => e.eventType === OperationType.KickBanPlayer);
  const joinTemplate    = r2.gD.find(e => e.eventType === OperationType.JoinRoom);
  const setTeamTemplate = r2.gD.find(e => e.eventType === OperationType.SetPlayerTeam);

  // ── Build transition events at frame fc1 ────────────────────────────────────
  const transition = [];

  // 1. KickBanPlayer — clear all file1 players from the room
  if (kickTemplate) {
    for (const p of r1.r.players) {
      if (p['$'] === 0) continue;
      transition.push(cloneEv(kickTemplate, {
        'N$': 0, '$': p['$'], 'JD': null, 'Ec': false, 'X': 0, 'frameNo': fc1
      }));
    }
  }

  // 2. JoinRoom — add all file2 initial players
  if (joinTemplate) {
    for (const p of r2.r.players) {
      if (p['$'] === 0) continue;
      transition.push(cloneEv(joinTemplate, {
        'N$': 0, '$': p['$'], 'L': p['L'], 'h$': p['h$'], 'F$': p['F$'], 'X': 0, 'frameNo': fc1
      }));
    }
  }

  // 3. SetPlayerTeam — assign file2 initial players to their teams
  if (setTeamTemplate) {
    for (const p of r2.r.players) {
      if (p['$'] === 0) continue;
      if (!p.p || p.p['$'] === 0) continue;
      transition.push(cloneEv(setTeamTemplate, {
        'N$': 0, 'K': p['$'], 'p': p.p, 'X': 0, 'frameNo': fc1
      }));
    }
  }

  emit({ type: 'debug', transition_events: transition.length });

  // ── Offset file2 events AND fix X field ─────────────────────────────────────
  // X=0 forces admin-action events to be treated as host-executed.
  // Without this, events like SetPlayerTeam / PauseResumeGame with X=somePlayerId
  // fail the authorization check (that player has no admin rights in merged room)
  // and are silently rejected — causing physics divergence after mid-game changes.
  // EXCEPTION: SendInput (type=3) — X identifies which player's input it is.
  let fixedCount = 0;
  for (let i = 0; i < r2.gD.length; i++) {
    r2.gD[i].frameNo += fc1;
    if (r2.gD[i].eventType !== OperationType.SendInput && r2.gD[i]['X'] !== 0) {
      r2.gD[i]['X'] = 0;
      fixedCount++;
    }
  }
  for (const g of r2.Ac) g.frameNo += fc1;

  emit({ type: 'debug', x_fixed: fixedCount });

  // ── Merge: r1 + transition + r2 ─────────────────────────────────────────────
  r1.gD.push(...transition, ...r2.gD);
  for (const g of r2.Ac) r1.Ac.push(g);
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

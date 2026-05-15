/**
 * hbr_analyze_cli.js  —  HBR Studio Full Match Analyzer
 *
 * Usage:
 *   node hbr_analyze_cli.js <file.hbr2>
 *
 * Emits a single JSON line with full match stats:
 *   { type: 'stats', fileName, totalFrames, durationSec, players, teams, goals, possession }
 *   { type: 'error', message }
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

const filePath = process.argv[2];
if (!filePath) {
  emit({ type: 'error', message: 'Usage: node hbr_analyze_cli.js <file.hbr2>' });
  process.exit(1);
}

// ── Helpers ────────────────────────────────────────────────────────────────────
function framesToSec(f) { return Math.round(f / 60); }
function frameToMMSS(f) {
  const s = Math.floor(f / 60);
  const m = Math.floor(s / 60);
  const ss = s % 60;
  return `${m}:${String(ss).padStart(2, '0')}`;
}

// ── Input flags (HaxBall JS keycodes) ─────────────────────────────────────────
// Bit 4 (16) = kick in standard HaxBall layout
const KICK_BIT = 16;
function isKick(c) { return (c & KICK_BIT) !== 0; }

try {
  const buf = new Uint8Array(fs.readFileSync(filePath));
  const r   = Replay.readAll(buf);

  // ── Build player map ─────────────────────────────────────────────────────────
  const playerMap = {}; // id -> { name, team, teamName }
  const redPlayers  = [];
  const bluePlayers = [];

  for (const p of (r.roomData.G || [])) {
    const team = p.p ? p.p['$'] : 0;
    if (team === 0) continue; // spectator
    const info = { name: (p.L || '').trim(), team };
    playerMap[p['$']] = info;
    if (team === 1) redPlayers.push({ id: p['$'], name: info.name });
    else             bluePlayers.push({ id: p['$'], name: info.name });
  }

  // ── Kick tracker per player ────────────────────────────────────────────────
  // lastKickFrame[playerId] = { frame, prevKickFrame }
  const lastInputFrame = {}; // playerId -> last frame they had ANY non-zero input
  const kickCount      = {}; // playerId -> kick count

  for (const e of r.events) {
    const pid = e.X;
    const c   = e.C$ ?? 0;
    if (c !== 0) lastInputFrame[pid] = e.frameNo;
    if (isKick(c)) kickCount[pid] = (kickCount[pid] || 0) + 1;
  }

  // ── Possession estimation (frames each team had last input) ──────────────────
  let posRed  = 0;
  let posBlue = 0;
  for (const [pid, frames] of Object.entries(lastInputFrame)) {
    const info = playerMap[pid];
    if (!info) continue;
    if (info.team === 1) posRed  += frames;
    else                  posBlue += frames;
  }
  const posTotal = posRed + posBlue || 1;

  // ── Goal analysis ────────────────────────────────────────────────────────────
  const LOOK_BACK = 300; // frames = 5 seconds look-back window for scorer/assist
  let redScore  = 0;
  let blueScore = 0;
  const goalDetails = [];

  for (const gm of r.goalMarkers) {
    const { frameNo, teamId } = gm;
    const scoringTeam = teamId; // 1=red, 2=blue

    // Build ordered list of scoring-team players that had input in look-back window
    const candidates = [];
    for (const e of r.events) {
      if (e.frameNo < frameNo - LOOK_BACK) continue;
      if (e.frameNo >= frameNo) break;
      const pid = e.X;
      const info = playerMap[pid];
      if (!info || info.team !== scoringTeam) continue;
      const c = e.C$ ?? 0;
      if (c === 0) continue;
      // Update most-recent occurrence
      const existing = candidates.find(c => c.id === pid);
      if (existing) existing.frame = e.frameNo;
      else candidates.push({ id: pid, name: info.name, frame: e.frameNo });
    }

    // Sort by most-recent first
    candidates.sort((a, b) => b.frame - a.frame);

    const scorer = candidates[0]?.name ?? '?';
    const assist = candidates[1]?.name ?? null;

    if (scoringTeam === 1) redScore++;
    else                    blueScore++;

    goalDetails.push({
      frameNo,
      time: frameToMMSS(frameNo),
      timeSec: framesToSec(frameNo),
      scoringTeam,
      redScore,
      blueScore,
      scorer,
      assist,
    });
  }

  // ── Per-player stats ─────────────────────────────────────────────────────────
  const goalCounts   = {}; // playerId -> goals
  const assistCounts = {}; // playerId -> assists

  for (const g of goalDetails) {
    // find player id by name from scoring team
    const scorerEntry = Object.entries(playerMap)
      .find(([, v]) => v.name === g.scorer && v.team === g.scoringTeam);
    if (scorerEntry) goalCounts[scorerEntry[0]] = (goalCounts[scorerEntry[0]] || 0) + 1;

    if (g.assist) {
      const assistEntry = Object.entries(playerMap)
        .find(([, v]) => v.name === g.assist && v.team === g.scoringTeam);
      if (assistEntry) assistCounts[assistEntry[0]] = (assistCounts[assistEntry[0]] || 0) + 1;
    }
  }

  const playerStats = Object.entries(playerMap).map(([id, info]) => ({
    id: parseInt(id),
    name: info.name,
    team: info.team,
    goals:   goalCounts[id]   || 0,
    assists: assistCounts[id] || 0,
    kicks:   kickCount[id]    || 0,
  }));

  // ── Output ────────────────────────────────────────────────────────────────────
  emit({
    type: 'stats',
    fileName:    path.basename(filePath),
    totalFrames: r.totalFrames,
    durationSec: framesToSec(r.totalFrames),
    duration:    frameToMMSS(r.totalFrames),
    teams: {
      red:  { score: redScore,  players: redPlayers.map(p => p.name) },
      blue: { score: blueScore, players: bluePlayers.map(p => p.name) },
    },
    goals: goalDetails,
    playerStats,
    possession: {
      red:  parseFloat(((posRed  / posTotal) * 100).toFixed(1)),
      blue: parseFloat(((posBlue / posTotal) * 100).toFixed(1)),
    },
    events:    r.events.length,
    goalCount: r.goalMarkers.length,
  });

} catch (e) {
  emit({ type: 'error', message: e.message });
  process.exit(1);
}

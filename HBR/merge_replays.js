/**
 * merge_replays.js
 * Merges two .hbr2 HaxBall replay files into one using node-haxball's Replay API.
 *
 * CORRECT ORDER:
 *   FILE1 = 1st half (Emman64vsVerone, 20:28, 44763 frames)  — plays first
 *   FILE2 = 2nd half (VeronevsEmman64, 20:41, 41645 frames)  — plays second
 *
 * Transition frame layout:
 *   [0 .. r1.totalFrames]       = FILE1 events (untouched)
 *   [r1.totalFrames + 1]        = synthetic stopGame
 *   [r1.totalFrames + 2]        = setPlayerTeam events for ALL players
 *                                  (teams from FILE2 room state; spec=0 for anyone
 *                                   who was in FILE1 but is absent/spec in FILE2)
 *   [r1.totalFrames + 3 ..]     = FILE2 events, offset by (r1.totalFrames + 3)
 *                                  FILE2's own startGame (frame 0) fires here
 *
 * Root-cause fix: players like modric.(345) who are in teams in FILE1 but spec
 * in FILE2 MUST be moved to spec before the new startGame — otherwise they stay
 * on the field as ghost players (8v7), causing NaN physics and a complete freeze.
 */

// Silence node-haxball's verbose stdout during require
const origWrite = process.stdout.write.bind(process.stdout);
const origErr   = process.stderr.write.bind(process.stderr);
process.stdout.write = () => true;
process.stderr.write = () => true;

const { performance } = require("perf_hooks");
const pako = require("pako");
const { Replay, EventFactory } = require("node-haxball")({ performance, pako });

process.stdout.write = origWrite;
process.stderr.write = origErr;

const fs   = require("fs");
const path = require("path");

const DIR  = __dirname;
// CORRECT ORDER: 1st half first, 2nd half second
const FILE1 = path.join(DIR, "12-05-26-20h28-Emman64vsVerone (1).hbr2");   // 1st half
const FILE2 = path.join(DIR, "12-05-26-20h41-VeronevsEmman64 (1).hbr2");   // 2nd half
const OUT   = path.join(DIR, "merged_final.hbr2");

// ── Read ────────────────────────────────────────────────────────────────────
origWrite("Reading replay files...\n");
const data1 = new Uint8Array(fs.readFileSync(FILE1));
const data2 = new Uint8Array(fs.readFileSync(FILE2));

origWrite("Parsing replays with node-haxball...\n");
const r1 = Replay.readAll(data1);
const r2 = Replay.readAll(data2);

origWrite(`\nFILE1 (1st half): ${r1.totalFrames} frames | ${r1.events.length} events | ${r1.goalMarkers.length} goals\n`);
origWrite(`FILE2 (2nd half): ${r2.totalFrames} frames | ${r2.events.length} events | ${r2.goalMarkers.length} goals\n`);

// ── Transition frame positions ───────────────────────────────────────────────
// FILE1 last frame = r1.totalFrames
// Give clean separation: each synthetic step on its own frame
const STOP_FRAME = r1.totalFrames + 1;   // stopGame
const TEAM_FRAME = r1.totalFrames + 2;   // setPlayerTeam events
const OFFSET     = r1.totalFrames + 3;   // FILE2 events start here (startGame at frame 0 → OFFSET)

// Host player ID — same in both recordings (player who issued startGame)
const hostId = r2.events[0].X;

// ── 1. Synthetic stopGame ────────────────────────────────────────────────────
const stopEvt = EventFactory.stopGame();
stopEvt.frameNo = STOP_FRAME;
stopEvt.X = hostId;

// ── 2. Transition: rebuild teams to match FILE2's EXACT room state ───────────
//
// CRITICAL: HaxBall assigns kickoff spawn positions (index 0-6 per team) in the
// ORDER players appear in the team's internal list.  If the order differs from
// FILE2's original recording the physics diverges immediately (wrong spawns).
//
// Strategy:
//   a) Move every FILE1 team player to spec  → clears both team lists
//   b) Add FILE2 team players in FILE2 room state order → recreates exact list
//
// This guarantees team1[0..6] and team2[0..6] are identical to FILE2 standalone,
// so startGame places every disc at exactly the right kickoff position.

// a) Spec-clear: all players currently in a team at end of FILE1
//    (FILE1 has 0 type=12 events, so end-state == initial room state)
const specEvts = [];
r1.roomData.players.forEach(p => {
  const tid = p.team && typeof p.team === 'object' ? p.team.$ : (p.team || 0);
  if (tid === 1 || tid === 2) {
    const evt = EventFactory.setPlayerTeam(p.id, 0);   // → spec
    if (evt) { evt.frameNo = TEAM_FRAME; evt.X = hostId; specEvts.push(evt); }
  }
});

// b) Team assignment: FILE2 players in FILE2's room state list order
const assignEvts = [];
r2.roomData.players.forEach(p => {
  const tid = p.team && typeof p.team === 'object' ? p.team.$ : (p.team || 0);
  if (tid === 1 || tid === 2) {
    const evt = EventFactory.setPlayerTeam(p.id, tid);
    if (evt) { evt.frameNo = TEAM_FRAME; evt.X = hostId; assignEvts.push(evt); }
  }
});

const teamEvts = [...specEvts, ...assignEvts];

origWrite(`\nTransition at frames ${STOP_FRAME}/${TEAM_FRAME}/${OFFSET}:\n`);
origWrite(`  ${specEvts.length} spec-clear events (clearing FILE1 teams)\n`);
origWrite(`  ${assignEvts.length} team-assign events (FILE2 order)\n`);
assignEvts.forEach(e => {
  const tid = e.p && typeof e.p === 'object' ? e.p.$ : e.p;
  origWrite(`    player ${e.K} → team ${tid}\n`);
});

// ── 5. Offset FILE2 events ────────────────────────────────────────────────────
r2.events.forEach(e => { e.frameNo += OFFSET; });

// ── 6. Concatenate ────────────────────────────────────────────────────────────
r1.events = r1.events.concat([stopEvt], teamEvts, r2.events);

// Offset & append FILE2 goal markers
r2.goalMarkers.forEach(g =>
  r1.goalMarkers.push({ frameNo: g.frameNo + OFFSET, teamId: g.teamId })
);

// Total frames = FILE1 (0..r1.totalFrames) + stopGame frame + team frame + FILE2 (0..r2.totalFrames)
// = r1.totalFrames + 2 + r2.totalFrames  (since FILE2's last frame is r2.totalFrames, shifted by OFFSET=r1.totalFrames+3)
r1.totalFrames = r1.totalFrames + 3 + r2.totalFrames;

origWrite(`\nMerged: ${r1.totalFrames} frames | ${r1.events.length} events | ${r1.goalMarkers.length} goals\n`);

// ── Write ─────────────────────────────────────────────────────────────────────
origWrite("Writing merged replay...\n");
const output = Replay.writeAll(r1);
fs.writeFileSync(OUT, Buffer.from(output));
origWrite(`\nDone!  →  ${OUT}\n`);
origWrite(`File size: ${output.byteLength.toLocaleString()} bytes\n`);


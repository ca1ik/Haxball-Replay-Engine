// Test: use merged_final.hbr2's StopGame+SetPlayerTeam as templates
// Then inject: StopGame(fc1) + SetPlayerTeam for each r2 player(fc1+1) + StartGame from file2 shifted to fc1+2
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

const fs = require('fs');
const FILE1 = process.argv[2];
const FILE2 = process.argv[3];
const OUT   = process.argv[4] || 'full_inject_out.hbr2';

const r1 = Replay.readAll(new Uint8Array(fs.readFileSync(FILE1)));
const r2 = Replay.readAll(new Uint8Array(fs.readFileSync(FILE2)));
const mf = Replay.readAll(new Uint8Array(fs.readFileSync('merged_final.hbr2')));

const fc1 = r1.TX;
const fc2 = r2.TX;

function cloneEv(template, fields) {
  const ev = Object.create(Object.getPrototypeOf(template));
  for (const k of Object.getOwnPropertyNames(template)) ev[k] = template[k];
  for (const [k, v] of Object.entries(fields)) ev[k] = v;
  return ev;
}

// Get REAL event templates from merged_final.hbr2
const stopTemplate    = mf.gD.find(e => e.eventType === OperationType.StopGame);
const setTeamTemplate = mf.gD.find(e => e.eventType === OperationType.SetPlayerTeam);

console.log('stopTemplate:', stopTemplate ? 'FOUND (frame=' + stopTemplate.frameNo + ')' : 'NOT FOUND');
console.log('setTeamTemplate:', setTeamTemplate ? 'FOUND (frame=' + setTeamTemplate.frameNo + ')' : 'NOT FOUND');

// Offset r2 events and fix X
// File2's StartGame is at frame 0; we'll push it to fc1+2 (after our StopGame at fc1, SetPlayerTeam at fc1+1)
for (let i = 0; i < r2.gD.length; i++) {
  r2.gD[i].frameNo += fc1;
  // Shift file2's StartGame by +2 to come AFTER our StopGame(fc1) and SetPlayerTeam(fc1+1)
  if (r2.gD[i].eventType === OperationType.StartGame) {
    r2.gD[i].frameNo += 2; // fc1+2
  }
  if (r2.gD[i].eventType !== OperationType.SendInput && r2.gD[i]['X'] !== 0) {
    r2.gD[i]['X'] = 0;
  }
}
for (const g of r2.Ac) g.frameNo += fc1;

const transition = [];

// 1. StopGame at fc1
if (stopTemplate) {
  transition.push(cloneEv(stopTemplate, { X: 0, frameNo: fc1 }));
  console.log('StopGame injected at frame', fc1);
}

// 2. SetPlayerTeam: first all to spec, then to their file2 teams
if (setTeamTemplate) {
  // Spec team object from merged_final.hbr2
  const specTeam = { '$': 0, 'u': 16777215, 'yg': 0, 'f': -1, 'g': 0 };

  // First: move all file2 players to spec
  for (const p of r2.r.players) {
    if (p['$'] === 0) continue;
    transition.push(cloneEv(setTeamTemplate, {
      'N$': 0, 'K': p['$'], 'p': specTeam, 'X': 0, 'frameNo': fc1 + 1
    }));
  }

  // Then: assign file2 players to their actual teams
  for (const p of r2.r.players) {
    if (p['$'] === 0) continue;
    const teamId = p.p ? p.p['$'] : 0;
    if (teamId === 0) continue; // leave spec players in spec
    transition.push(cloneEv(setTeamTemplate, {
      'N$': 0, 'K': p['$'], 'p': p.p, 'X': 0, 'frameNo': fc1 + 1
    }));
  }
  console.log('SetPlayerTeam injected for', r2.r.players.length, 'players at frame', fc1 + 1);
}

console.log('Total transition events:', transition.length);

// Merge
for (const e of transition) r1.gD.push(e);
for (const e of r2.gD)      r1.gD.push(e);
for (const g of r2.Ac)      r1.Ac.push(g);
r1.TX = fc1 + fc2;

const output = Replay.writeAll(r1);
fs.writeFileSync(OUT, Buffer.from(output));
console.log('Written:', OUT, Buffer.byteLength(Buffer.from(output)), 'bytes');
console.log('goals in Ac:', r1.Ac.length);

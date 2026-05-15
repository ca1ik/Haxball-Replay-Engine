// Test: inject StopGame at fc1, then let file2's StartGame run
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
const OUT   = process.argv[4] || 'stopgame_test.hbr2';

const r1 = Replay.readAll(new Uint8Array(fs.readFileSync(FILE1)));
const r2 = Replay.readAll(new Uint8Array(fs.readFileSync(FILE2)));

const fc1 = r1.TX;
const fc2 = r2.TX;

function cloneEv(template, fields) {
  const ev = Object.create(Object.getPrototypeOf(template));
  for (const k of Object.getOwnPropertyNames(template)) ev[k] = template[k];
  for (const [k, v] of Object.entries(fields)) ev[k] = v;
  return ev;
}

// Offset r2 events and fix X
for (let i = 0; i < r2.gD.length; i++) {
  r2.gD[i].frameNo += fc1;
  if (r2.gD[i].eventType !== OperationType.SendInput && r2.gD[i]['X'] !== 0) {
    r2.gD[i]['X'] = 0;
  }
}
for (const g of r2.Ac) g.frameNo += fc1;

// Find any event to use as prototype for synthetic events
const anyEvent = r1.gD[0];
const proto = Object.getPrototypeOf(anyEvent);

// Build a synthetic StopGame event at frame fc1
function makeSyntheticEv(eventType, extraFields) {
  const ev = Object.create(proto);
  // Copy all fields from a template event to get required structure
  for (const k of Object.getOwnPropertyNames(anyEvent)) ev[k] = anyEvent[k];
  ev.eventType = eventType;
  ev.X = 0;
  ev.frameNo = fc1;
  for (const [k, v] of Object.entries(extraFields || {})) ev[k] = v;
  return ev;
}

// Find SetPlayerTeam template - try file1 and file2
const setTeamTemplate = r1.gD.find(e => e.eventType === OperationType.SetPlayerTeam) ||
                        r2.gD.find(e => e.eventType === OperationType.SetPlayerTeam);
console.log('setTeamTemplate:', setTeamTemplate ? 'FOUND' : 'NOT FOUND (will use synthetic)');

// Find StartGame template from file1
const startTemplate = r1.gD.find(e => e.eventType === OperationType.StartGame);
const stopTemplate  = r1.gD.find(e => e.eventType === OperationType.StopGame);
console.log('startTemplate:', startTemplate ? 'FOUND' : 'NOT FOUND');
console.log('stopTemplate:', stopTemplate ? 'FOUND' : 'NOT FOUND');

// Build transitions for same-room: StopGame + SetPlayerTeam + file2's StartGame will handle the rest
const transition = [];

// 1. Inject StopGame at fc1 (before file2's events)
if (startTemplate) {
  // Use StartGame event as template but override eventType to StopGame
  const stopEv = cloneEv(startTemplate, { eventType: OperationType.StopGame, X: 0, frameNo: fc1 });
  transition.push(stopEv);
  console.log('StopGame injected using StartGame template');
} else {
  // Synthetic
  const stopEv = makeSyntheticEv(OperationType.StopGame);
  transition.push(stopEv);
  console.log('StopGame injected synthetically');
}

// 2. SetPlayerTeam for file2 players from r2.r.players (handles halftime team change)
let teamInjectCount = 0;
if (setTeamTemplate) {
  for (const p of r2.r.players) {
    if (p['$'] === 0) continue;
    const teamId = p.p ? p.p['$'] : 0;
    if (teamId === 0) continue; // skip spec players
    transition.push(cloneEv(setTeamTemplate, {
      'N$': 0, 'K': p['$'], 'p': p.p, 'X': 0, 'frameNo': fc1
    }));
    teamInjectCount++;
  }
  console.log('SetPlayerTeam injected for', teamInjectCount, 'players');
} else {
  console.log('No SetPlayerTeam template — teams from file1 end state will be used');
}

console.log('Total transition events:', transition.length);

// Merge: file1 events + transitions (before file2's StartGame) + file2 events
for (const e of transition) r1.gD.push(e);
for (const e of r2.gD)      r1.gD.push(e);
for (const g of r2.Ac)      r1.Ac.push(g);
r1.TX = fc1 + fc2;

const output = Replay.writeAll(r1);
fs.writeFileSync(OUT, Buffer.from(output));
console.log('Written:', OUT, Buffer.byteLength(Buffer.from(output)), 'bytes');
console.log('goals in Ac:', r1.Ac.length);

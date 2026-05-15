// Test: v3 style (always inject transitions) vs checking what team players get
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
const OUT   = process.argv[4] || 'v3_test_out.hbr2';

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
let fixedCount = 0;
for (let i = 0; i < r2.gD.length; i++) {
  r2.gD[i].frameNo += fc1;
  if (r2.gD[i].eventType !== OperationType.SendInput && r2.gD[i]['X'] !== 0) {
    r2.gD[i]['X'] = 0;
    fixedCount++;
  }
}
for (const g of r2.Ac) g.frameNo += fc1;

// ALWAYS inject transitions (v3 style)
const transition = [];

const kickTemplate    = r1.gD.find(e => e.eventType === OperationType.KickBanPlayer);
const joinTemplate    = r2.gD.find(e => e.eventType === OperationType.JoinRoom);
const setTeamTemplate = r2.gD.find(e => e.eventType === OperationType.SetPlayerTeam) ||
                        r1.gD.find(e => e.eventType === OperationType.SetPlayerTeam);

console.log('kickTemplate:', kickTemplate ? 'FOUND' : 'NOT FOUND');
console.log('joinTemplate:', joinTemplate ? 'FOUND' : 'NOT FOUND');
console.log('setTeamTemplate:', setTeamTemplate ? 'FOUND' : 'NOT FOUND');

// 1. KickBanPlayer all file1 players
if (kickTemplate) {
  for (const p of r1.r.players) {
    if (p['$'] === 0) continue;
    transition.push(cloneEv(kickTemplate, {
      'N$': 0, '$': p['$'], 'JD': null, 'Ec': false, 'X': 0, 'frameNo': fc1
    }));
  }
}

// 2. JoinRoom all file2 players (with team assignment via N$)
if (joinTemplate) {
  for (const p of r2.r.players) {
    if (p['$'] === 0) continue;
    const teamId = p.p ? p.p['$'] : 0;
    transition.push(cloneEv(joinTemplate, {
      'N$': teamId, '$': p['$'], 'L': p['L'], 'h$': p['h$'], 'F$': p['F$'], 'X': 0, 'frameNo': fc1
    }));
  }
}

console.log('transition events:', transition.length);
console.log('x_fixed:', fixedCount);

// Merge
for (const e of transition) r1.gD.push(e);
for (const e of r2.gD)      r1.gD.push(e);
for (const g of r2.Ac)      r1.Ac.push(g);
r1.TX = fc1 + fc2;

const output = Replay.writeAll(r1);
fs.writeFileSync(OUT, Buffer.from(output));
console.log('Written:', OUT, Buffer.byteLength(Buffer.from(output)), 'bytes');
console.log('goals in Ac:', r1.Ac.length);

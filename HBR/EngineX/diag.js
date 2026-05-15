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

const r1 = Replay.readAll(new Uint8Array(fs.readFileSync(FILE1)));
const r2 = Replay.readAll(new Uint8Array(fs.readFileSync(FILE2)));

// Unique types
const t1 = new Set(r1.gD.map(e => e.eventType));
const t2 = new Set(r2.gD.map(e => e.eventType));
console.log('FILE1 types:', JSON.stringify([...t1].sort((a,b)=>a-b)));
console.log('FILE2 types:', JSON.stringify([...t2].sort((a,b)=>a-b)));

// JoinRoom event from file2
const joinEv = r2.gD.find(e => e.eventType === OperationType.JoinRoom);
if (joinEv) {
  console.log('\nFILE2 JoinRoom keys:', Object.getOwnPropertyNames(joinEv).join(', '));
  const plain = {};
  for (const k of Object.getOwnPropertyNames(joinEv)) plain[k] = joinEv[k];
  console.log('FILE2 JoinRoom:', JSON.stringify(plain));
}

// KickBanPlayer from file1
const kickEv = r1.gD.find(e => e.eventType === OperationType.KickBanPlayer);
if (kickEv) {
  console.log('\nFILE1 KickBanPlayer keys:', Object.getOwnPropertyNames(kickEv).join(', '));
  const plain = {};
  for (const k of Object.getOwnPropertyNames(kickEv)) plain[k] = kickEv[k];
  console.log('FILE1 KickBanPlayer:', JSON.stringify(plain));
}

// SetPlayerTeam
const setTeamEv = r2.gD.find(e => e.eventType === OperationType.SetPlayerTeam);
console.log('\nSetPlayerTeam (type='+OperationType.SetPlayerTeam+') in FILE2:', setTeamEv ? 'FOUND' : 'NOT FOUND');
const setTeamEv1 = r1.gD.find(e => e.eventType === OperationType.SetPlayerTeam);
console.log('SetPlayerTeam (type='+OperationType.SetPlayerTeam+') in FILE1:', setTeamEv1 ? 'FOUND' : 'NOT FOUND');

// FILE2 players with teams
console.log('\nFILE2 initial players:');
r2.r.players.forEach(p => {
  const teamId = p.p ? p.p['$'] : 0;
  console.log(`  id=${p['$']} name=${p['L']} team=${teamId}`);
});

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

const fs = require('fs');
const r2 = Replay.readAll(new Uint8Array(fs.readFileSync('C:/Users/user/Desktop/Codemations/HBR2/HBR/12-05-26-20h41-VeronevsEmman64 (1).hbr2')));

const verone = r2.r.players.find(pl => pl['$'] === 336);
console.log('verone full object:');
for (const k of Object.getOwnPropertyNames(verone)) {
  const v = verone[k];
  if (v && typeof v === 'object') {
    console.log('  ' + k + ': ' + JSON.stringify(v) + ' (keys: ' + Object.getOwnPropertyNames(v).join(',') + ')');
  } else {
    console.log('  ' + k + ': ' + v);
  }
}

console.log('\n--- Testing setPlayerTeam signatures ---');
const sigs = [
  ['(0, verone, 0)', () => EventFactory.setPlayerTeam(0, verone, 0)],
  ['(0, 336, team_obj)', () => EventFactory.setPlayerTeam(0, verone['$'], verone.p)],
  ['(336, team_obj, 0)', () => EventFactory.setPlayerTeam(verone['$'], verone.p, 0)],
  ['(0, 336, 1)', () => EventFactory.setPlayerTeam(0, verone['$'], 1)],
  ['(0, verone, verone.p)', () => EventFactory.setPlayerTeam(0, verone, verone.p)],
  ['(verone, team_obj)', () => EventFactory.setPlayerTeam(verone, verone.p)],
  ['(0, 336, r2.r.teams[1])', () => EventFactory.setPlayerTeam(0, verone['$'], r2.r.teams ? r2.r.teams[1] : null)],
];
sigs.forEach(([name, fn]) => {
  try {
    const ev = fn();
    if (ev == null) { console.log(name + ': null/undefined'); return; }
    const proto = Object.getPrototypeOf(ev);
    console.log(name + ': type=' + proto.eventType + ' fields=' + JSON.stringify(ev));
  } catch (e) { console.log(name + ': ERROR ' + e.message); }
});

// Also check r2.r structure
console.log('\nr2.r keys:', Object.getOwnPropertyNames(r2.r).join(', '));
if (r2.r.teams) console.log('r2.r.teams:', JSON.stringify(r2.r.teams));

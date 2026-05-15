const f = require('fs');
const buf = new Uint8Array(f.readFileSync('c:/Users/user/Downloads/4 pas.hbr2'));
const { performance } = require('perf_hooks');
const pako = require('pako');
const { Replay } = require('node-haxball')({ performance, pako });
const r = Replay.readAll(buf);

console.log('frame0 events:', r.gD.filter(e => e.frameNo === 0).length);
console.log('first 5 frames:', r.gD.slice(0, 5).map(e => e.frameNo));
console.log('first event D_:', r.gD[0].D_, 'eventType:', r.gD[0].eventType);

// Test: trim from frame 1000 keeping init events
const START = 1000, END = 6000;
const buf2 = new Uint8Array(f.readFileSync('c:/Users/user/Downloads/4 pas.hbr2'));
const r2 = Replay.readAll(buf2);
// Include events at frame 0 (room init) + events in range
const initEvts = r2.gD.filter(e => e.frameNo < START);
const rangeEvts = r2.gD.filter(e => e.frameNo >= START && e.frameNo <= END);
// Rebase range events
for (const e of rangeEvts) e.frameNo -= START;
// Combine: init events at frame 0, range events starting at 0
r2.gD.length = 0;
for (const e of initEvts) { e.frameNo = 0; r2.gD.push(e); }
for (const e of rangeEvts) r2.gD.push(e);
const goals = r2.Ac.filter(g => g.frameNo >= START && g.frameNo <= END);
for (const g of goals) g.frameNo -= START;
r2.Ac.length = 0;
for (const g of goals) r2.Ac.push(g);
r2.TX = END - START;

try {
  const out = Replay.writeAll(r2);
  f.writeFileSync('C:/Users/user/Downloads/test_split_with_init.hbr2', Buffer.from(out));
  const v = Replay.readAll(out);
  console.log('with-init split: totalFrames:', v.TX, 'events:', v.gD.length, 'goals:', v.Ac.length);
} catch(e) { console.log('ERROR:', e.message); }

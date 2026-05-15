// Deep diagnostic: inspect event structures and understand the transition problem
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

// Inspect StartGame event (file1, frame 0)
const startEv1 = r1.gD.find(e => e.eventType === OperationType.StartGame);
console.log('\n=== File1 StartGame event ===');
if (startEv1) {
  const keys = Object.getOwnPropertyNames(startEv1);
  console.log('Keys:', keys);
  const plain = {};
  for (const k of keys) plain[k] = startEv1[k];
  console.log('Values:', JSON.stringify(plain));
}

// Inspect StartGame event (file2, frame 0)
const startEv2 = r2.gD.find(e => e.eventType === OperationType.StartGame);
console.log('\n=== File2 StartGame event ===');
if (startEv2) {
  const keys = Object.getOwnPropertyNames(startEv2);
  console.log('Keys:', keys);
  const plain = {};
  for (const k of keys) plain[k] = startEv2[k];
  console.log('Values:', JSON.stringify(plain));
}

// merged_final.hbr2: find StopGame event  
const mf = Replay.readAll(new Uint8Array(fs.readFileSync('merged_final.hbr2')));
const stopEvMF = mf.gD.find(e => e.eventType === OperationType.StopGame);
console.log('\n=== merged_final.hbr2 StopGame event ===');
if (stopEvMF) {
  const keys = Object.getOwnPropertyNames(stopEvMF);
  console.log('Keys:', keys);
  const plain = {};
  for (const k of keys) plain[k] = stopEvMF[k];
  console.log('Values:', JSON.stringify(plain));
  console.log('prototype keys:', Object.getOwnPropertyNames(Object.getPrototypeOf(stopEvMF)));
} else {
  console.log('NOT FOUND in merged_final.hbr2');
}

// merged_final.hbr2: find StartGame at frame 44764-ish (second one)
const startEvMF = mf.gD.filter(e => e.eventType === OperationType.StartGame);
console.log('\n=== merged_final.hbr2 StartGame events (' + startEvMF.length + ') ===');
startEvMF.forEach(e => {
  const keys = Object.getOwnPropertyNames(e);
  const plain = {};
  for (const k of keys) plain[k] = e[k];
  console.log(JSON.stringify(plain));
});

// Events in merged_final.hbr2 at the transition (frame ~44763-44765)
const fc1 = r1.TX;
console.log('\n=== merged_final.hbr2 events at transition (fc1=' + fc1 + ', ±5 frames) ===');
mf.gD.filter(e => e.frameNo >= fc1 - 2 && e.frameNo <= fc1 + 5)
  .slice(0, 30)
  .forEach(e => {
    const plain = {};
    for (const k of Object.getOwnPropertyNames(e)) plain[k] = e[k];
    console.log(JSON.stringify(plain));
  });

/**
 * hbr_probe_cli.js  —  Fast HBR2 file info probe (no full parse)
 * Usage: node hbr_probe_cli.js <file.hbr2>
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
  emit({ type: 'error', message: 'Usage: node hbr_probe_cli.js <file.hbr2>' });
  process.exit(1);
}

try {
  const buf = new Uint8Array(fs.readFileSync(filePath));
  const r   = Replay.readAll(buf);
  const stat = fs.statSync(filePath);
  emit({
    type        : 'info',
    totalFrames : r.totalFrames,
    events      : r.events.length,
    goals       : r.goalMarkers.length,
    bytes       : stat.size,
    name        : path.basename(filePath)
  });
} catch (e) {
  emit({ type: 'error', message: e.message });
  process.exit(1);
}

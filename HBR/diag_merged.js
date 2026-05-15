// Silence node-haxball verbose stdout at require time
const origWrite = process.stdout.write.bind(process.stdout);
const origErr   = process.stderr.write.bind(process.stderr);
process.stdout.write = () => true;
process.stderr.write = () => true;

const { Replay } = require('node-haxball')({
  performance: require('perf_hooks').performance,
  pako: require('pako')
});

process.stdout.write = origWrite;
process.stderr.write = origErr;

const fs = require('fs');

const merged = Replay.readAll(new Uint8Array(fs.readFileSync('merged_final.hbr2')));
const results = [];
results.push('=== MERGED FILE STATS ===');
results.push('totalFrames: ' + merged.totalFrames);
results.push('events: ' + merged.events.length);
results.push('goals: ' + merged.goalMarkers.length);
results.push('goalMarkers: ' + JSON.stringify(merged.goalMarkers));

// Transition area: around frame 44763 (FILE1 end) + a few frames
const TRANS = 44763;
const near = merged.events.filter(e => e.frameNo >= TRANS-2 && e.frameNo <= TRANS+10);
results.push('\n=== EVENTS NEAR TRANSITION (frames ' + (TRANS-2) + '-' + (TRANS+10) + ') ===');
near.forEach(e => {
  const keys = Object.keys(e).filter(k => !['frameNo','eventType'].includes(k));
  const extra = keys.map(k => k+'='+JSON.stringify(e[k])).join(', ');
  results.push('  frame=' + e.frameNo + ' type=' + e.eventType + (extra ? ' | ' + extra : ''));
});

// All startGame/stopGame events
results.push('\n=== ALL startGame(7)/stopGame(8)/pauseGame(9) EVENTS ===');
merged.events.filter(e => [7,8,9].includes(e.eventType)).forEach(e => {
  results.push('  frame=' + e.frameNo + ' type=' + e.eventType + ' X=' + e.X);
});

// 2nd segment: events after the transition
const seg2 = merged.events.filter(e => e.frameNo > TRANS+10);
results.push('\n=== 2ND SEGMENT - FIRST 15 EVENTS ===');
seg2.slice(0, 15).forEach(e => {
  const keys = Object.keys(e).filter(k => !['frameNo','eventType'].includes(k));
  const extra = keys.map(k => k+'='+JSON.stringify(e[k])).join(', ');
  results.push('  frame=' + e.frameNo + ' type=' + e.eventType + (extra ? ' | ' + extra : ''));
});

// Event type counts in 2nd segment
const typeCounts = {};
seg2.forEach(e => { typeCounts[e.eventType] = (typeCounts[e.eventType]||0)+1; });
results.push('\n=== 2ND SEGMENT EVENT TYPE COUNTS ===');
Object.keys(typeCounts).sort((a,b)=>+a-+b).forEach(k => {
  results.push('  type ' + k + ': ' + typeCounts[k]);
});

fs.writeFileSync('diag_result.txt', results.join('\n'));
origWrite('Done! See diag_result.txt\n');

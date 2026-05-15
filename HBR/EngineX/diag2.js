// Silence node-haxball verbose stdout at require time
const origWrite = process.stdout.write.bind(process.stdout);
const origErr   = process.stderr.write.bind(process.stderr);
process.stdout.write = () => true;
process.stderr.write = () => true;

const { Replay, EventFactory } = require('node-haxball')({
  performance: require('perf_hooks').performance,
  pako: require('pako')
});

process.stdout.write = origWrite;
process.stderr.write = origErr;

const fs   = require('fs');
const path = require('path');
const DIR  = __dirname;

// CORRECT ORDER: 1st half first, 2nd half second
const FILE1 = path.join(DIR, "12-05-26-20h28-Emman64vsVerone (1).hbr2");   // 1st half, 44763 frames
const FILE2 = path.join(DIR, "12-05-26-20h41-VeronevsEmman64 (1).hbr2");   // 2nd half, 41645 frames

const r1 = Replay.readAll(new Uint8Array(fs.readFileSync(FILE1)));
const r2 = Replay.readAll(new Uint8Array(fs.readFileSync(FILE2)));

const results = [];
results.push('FILE1 totalFrames=' + r1.totalFrames + ' events=' + r1.events.length);
results.push('FILE2 totalFrames=' + r2.totalFrames + ' events=' + r2.events.length);

// Find r2 room state players and their teams
const f2Players = r2.roomData.players;
results.push('\nFILE2 initial room state players:');
f2Players.forEach(p => {
  const tid = p.team && typeof p.team === 'object' ? p.team.$ : p.team;
  results.push('  id=' + p.id + ' name=' + p.name + ' team=' + tid);
});

// Find FILE1's last event frame
const lastF1Frame = r1.events[r1.events.length - 1].frameNo;
results.push('\nFILE1 last event at frame: ' + lastF1Frame);
results.push('FILE1 totalFrames: ' + r1.totalFrames);

// Check FILE2 first events
results.push('\nFILE2 first 5 events:');
r2.events.slice(0, 5).forEach(e => {
  const keys = Object.keys(e).filter(k => !['frameNo','eventType'].includes(k));
  const extra = keys.map(k => k+'='+JSON.stringify(e[k])).join(', ');
  results.push('  frame=' + e.frameNo + ' type=' + e.eventType + (extra ? ' | ' + extra : ''));
});

// Check FILE1 room state players
results.push('\nFILE1 initial room state players:');
r1.roomData.players.forEach(p => {
  const tid = p.team && typeof p.team === 'object' ? p.team.$ : p.team;
  results.push('  id=' + p.id + ' name=' + p.name + ' team=' + tid);
});

fs.writeFileSync('diag2_result.txt', results.join('\n'));
origWrite('Done! See diag2_result.txt\n');

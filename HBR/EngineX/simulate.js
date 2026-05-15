const origWrite = process.stdout.write.bind(process.stdout);
const origErr   = process.stderr.write.bind(process.stderr);
process.stdout.write = () => true;
process.stderr.write = () => true;
const { performance } = require('perf_hooks');
const pako = require('pako');
const api = require('node-haxball')({ performance, pako });
const { Replay } = api;
process.stdout.write = origWrite;
process.stderr.write = origErr;

const fs = require('fs');
const file = process.argv[2] || 'test_out.hbr2';

let tick = 0;
const events = [];

const reader = Replay.read(new Uint8Array(fs.readFileSync(file)), {
  onGameTick:        ()        => { tick++; },
  onGameStart:       (by)      => events.push({ tick, type: 'START', by }),
  onGameStop:        (by)      => events.push({ tick, type: 'STOP',  by }),
  onTeamGoal:        (t)       => events.push({ tick, type: 'GOAL',  team: t }),
  onPlayerJoin:      (p)       => events.push({ tick, type: 'JOIN',  id: p.id, name: p.name }),
  onPlayerLeave:     (p)       => events.push({ tick, type: 'LEAVE', id: p.id, name: p.name }),
  onPlayerTeamChange:(id, tid) => events.push({ tick, type: 'TEAM',  id, tid }),
});

reader.onEnd = () => {
  reader.destroy();
  origWrite('=== SIMULATION RESULT ===\n');
  origWrite('File: ' + file + '\n');
  origWrite('Total ticks: ' + tick + '\n');
  origWrite('Total events: ' + events.length + '\n\n');

  const goals = events.filter(e => e.type === 'GOAL');
  const starts = events.filter(e => e.type === 'START');
  const stops  = events.filter(e => e.type === 'STOP');

  origWrite('Goals (' + goals.length + '):\n');
  goals.forEach((g, i) => origWrite('  [' + i + '] tick=' + g.tick + ' team=' + g.team + '\n'));

  origWrite('\nGame starts (' + starts.length + '):\n');
  starts.forEach(s => origWrite('  tick=' + s.tick + '\n'));

  origWrite('\nGame stops (' + stops.length + '):\n');
  stops.forEach(s => origWrite('  tick=' + s.tick + '\n'));

  origWrite('\nAll events:\n');
  events.forEach(e => origWrite(JSON.stringify(e) + '\n'));

  process.exit(0);
};

reader.setSpeed(Infinity);

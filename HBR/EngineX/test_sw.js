const origWrite = process.stdout.write.bind(process.stdout);
const origErr = process.stderr.write.bind(process.stderr);
process.stdout.write = () => true;
process.stderr.write = () => true;

const { performance } = require('perf_hooks');
const pako = require('pako');
const h = require('node-haxball')({ performance, pako });

process.stdout.write = origWrite;
process.stderr.write = origErr;

const fs = require('fs');
const buf = new Uint8Array(fs.readFileSync('merged_final.hbr2'));
const sw = h.Room.streamWatcher(buf, {});

origWrite('Created streamWatcher\n');
origWrite('currentFrame: ' + sw.currentFrameNo + '\n');
origWrite('maxFrame: ' + sw.maxFrameNo + '\n');

// Step 600 frames
sw.runSteps(600);
origWrite('After 600 steps, frame: ' + sw.currentFrameNo + '\n');

const gs = sw.gameState;
origWrite('gameState type: ' + typeof gs + '\n');
if (gs) {
  origWrite('gameState keys: ' + JSON.stringify(Object.keys(gs)) + '\n');
  // Try to get players
  const players = gs.players || gs.P || gs.O;
  if (players) {
    origWrite('players count: ' + (players.length || Object.keys(players).length) + '\n');
    if (players[0]) {
      origWrite('player[0] keys: ' + JSON.stringify(Object.keys(players[0])) + '\n');
    }
  }
  // Try to get ball
  const ball = gs.ball || gs.b || gs.disc;
  if (ball) {
    origWrite('ball keys: ' + JSON.stringify(Object.keys(ball)) + '\n');
  }
}

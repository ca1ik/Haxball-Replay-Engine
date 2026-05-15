const ow = process.stdout.write.bind(process.stdout);
process.stdout.write = () => true;
process.stderr.write = () => true;

const { performance } = require('perf_hooks');
const pako = require('pako');
const h = require('node-haxball')({ performance, pako });

process.stdout.write = ow;

const fs = require('fs');
const buf = new Uint8Array(fs.readFileSync('merged_final.hbr2'));

try {
  const rr = h.Replay.read(buf, {}, null);
  ow('maxFrameNo: ' + rr.maxFrameNo + '\n');

  // Seek to frame 5000 (some mid-game action)
  rr.setCurrentFrameNo(5000);
  ow('currentFrameNo after seek: ' + rr.getCurrentFrameNo() + '\n');

  const gs = rr.gameState;
  ow('gameState keys: ' + JSON.stringify(Object.keys(gs)) + '\n');

  // 'c' might be players
  const c = gs.c;
  ow('gs.c type: ' + typeof c + ' len: ' + (c ? c.length : 'na') + '\n');
  if (c && c[0]) {
    ow('c[0] keys: ' + JSON.stringify(Object.keys(c[0])) + '\n');
  }

  // 'G$' might be discs  
  const G2 = gs['G$'];
  ow('gs.G$ type: ' + typeof G2 + ' len: ' + (G2 ? G2.length : 'na') + '\n');

  // 'a$' might be discs (ball+players)
  const a2 = gs['a$'];
  ow('gs.a$ type: ' + typeof a2 + ' len: ' + (a2 ? a2.length : 'na') + '\n');
  ow('gs.a$ keys: ' + JSON.stringify(Object.keys(a2 || {})) + '\n');

  // Check 'K_' 
  const K_ = gs.K_;
  ow('gs.K_ type: ' + typeof K_ + ' len: ' + (K_ ? (K_.length || Object.keys(K_).length) : 'na') + '\n');

  // Check all gameState props
  for (const key of Object.keys(gs)) {
    const v = gs[key];
    const t = typeof v;
    if (t === 'object' && v !== null) {
      ow(key + ': object, keys=' + JSON.stringify(Object.keys(v).slice(0,5)) + '\n');
    } else {
      ow(key + ': ' + t + '=' + v + '\n');
    }
  }

  // Check s (physics state)
  const s = gs.s;
  // F = ball?
  ow('gs.s.F type: ' + typeof s.F + '\n');
  if (s.F) ow('gs.s.F: ' + JSON.stringify(Object.keys(s.F)) + '\n');
  // L$ = ?
  ow('gs.s.L$ type: ' + typeof s.L$ + ' len: ' + (s.L$ ? s.L$.length : 'na') + '\n');

  // Check player in mid-game - try setTime
  rr.setTime(60 * 1000); // 1 min into game
  ow('after setTime(60s): currentFrameNo=' + rr.getCurrentFrameNo() + '\n');
  const gs2 = rr.gameState;
  const s2 = gs2.s;
  const O2 = s2.O;
  const activePlayers2 = O2.filter(p => p.B && Math.abs(p.B.x) < 700 && Math.abs(p.B.y) < 350);
  ow('Field players at 1min: ' + activePlayers2.length + '\n');
  activePlayers2.slice(0, 5).forEach((p, i) => {
    ow('  id=' + p['$'] + ' pos=(' + p.B.x.toFixed(1) + ',' + p.B.y.toFixed(1) + ')\n');
  });

  // Ball - check F
  if (s2.F) {
    for (const key of Object.keys(s2.F)) {
      const v = s2.F[key];
      if (typeof v === 'object' && v) ow('F.' + key + ': ' + JSON.stringify(v) + '\n');
      else ow('F.' + key + ': ' + v + '\n');
    }
  }

  rr.destroy();
} catch(e) {
  ow('ERR: ' + e.message + '\n');
}

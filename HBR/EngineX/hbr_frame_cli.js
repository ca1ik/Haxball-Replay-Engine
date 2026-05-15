/**
 * hbr_frame_cli.js — Extracts sampled frame data from a HBR2 replay
 * Usage: node hbr_frame_cli.js <file.hbr2> [sampleRate=10]
 *
 * Output (JSON lines to stdout):
 *   { type: 'meta',  totalFrames, durationMs, halfFrame, playerMap, goals }
 *   { type: 'frame', f, players:[{id,x,y}], ball:{x,y} }  ← every sampleRate frames
 *   { type: 'done',  frames }
 *   { type: 'error', message }
 *
 * Strategy: sequential setCurrentFrameNo seeks (incremental from current position,
 * ~0.04ms per frame of advance). Each seek is polled until getCurrentFrameNo() >= target.
 *
 * Positions:
 *   Ball   → gameState.s.F[0].B   (K=null, radius≈6.4)
 *   Players→ gameState.s.F[i].B   where F[i].K = room player ID (non-null)
 *
 * Wall time (sampleRate=10, 24-min match): ~15 seconds.
 * Wall time (sampleRate=30, 24-min match): ~5  seconds.
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

const fs = require('fs');

function emit(obj) { origWrite(JSON.stringify(obj) + '\n'); }

const filePath   = process.argv[2];
const sampleRate = parseInt(process.argv[3] || '10', 10);

if (!filePath) {
  emit({ type: 'error', message: 'Usage: node hbr_frame_cli.js <file.hbr2> [sampleRate]' });
  process.exit(1);
}

// Poll until rr.getCurrentFrameNo() >= target or timeout (ms)
async function waitForFrame(rr, target, timeoutMs = 5000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (rr.getCurrentFrameNo() >= target) return true;
    await new Promise(res => setTimeout(res, 1));
  }
  return false; // timeout
}

function captureState(rr) {
  const gs = rr.gameState;
  const s  = gs && gs.s;
  if (!s || !Array.isArray(s.F)) return null;

  // Ball: F[0], K=null
  let ball = null;
  if (s.F[0] && s.F[0].B) {
    ball = { x: +(s.F[0].B.x.toFixed(1)), y: +(s.F[0].B.y.toFixed(1)) };
  }

  // Players: discs where K (room player id) is not null
  const players = [];
  for (const d of s.F) {
    if (!d || d.K == null || !d.B) continue;
    const { x, y } = d.B;
    // Skip obviously out-of-bounds phantom discs (walls, goals, etc.)
    if (Math.abs(x) > 2000 || Math.abs(y) > 1000) continue;
    players.push({ id: d.K, x: +(x.toFixed(1)), y: +(y.toFixed(1)) });
  }

  return { ball, players };
}

(async () => {
  try {
    const buf = new Uint8Array(fs.readFileSync(filePath));

    // ── Metadata via readAll ──────────────────────────────────────────────────
    const rAll        = Replay.readAll(buf);
    const totalFrames = rAll.totalFrames;
    const durationMs  = Math.round(totalFrames * 1000 / 60);
    const halfFrame   = Math.floor(totalFrames / 2);

    const playerMap = {};
    for (const p of (rAll.roomData.G || [])) {
      const id = p['$'];
      if (id != null) {
        playerMap[id] = { name: p.L || '?', team: p.p ? p.p['$'] : 0 };
      }
    }

    const goals = (rAll.goalMarkers || []).map(gm => ({
      frameNo: gm.frameNo,
      teamId : gm.teamId,
    }));

    emit({ type: 'meta', totalFrames, durationMs, halfFrame, playerMap, goals });

    // ── Sequential seeks ──────────────────────────────────────────────────────
    const rr = Replay.read(buf, {}, null);
    let emittedFrames = 0;

    for (let frame = 0; frame <= totalFrames; frame += sampleRate) {
      rr.setCurrentFrameNo(frame);
      const ok = await waitForFrame(rr, frame);
      if (!ok) continue; // skip on timeout

      const state = captureState(rr);
      if (!state) continue;

      emit({ type: 'frame', f: frame, players: state.players, ball: state.ball });
      emittedFrames++;
    }

    rr.destroy();
    emit({ type: 'done', frames: emittedFrames });

  } catch (e) {
    emit({ type: 'error', message: e.message });
    process.exit(1);
  }
})();



/**
 * hbr_viewer_server.js — Local HTTP+WS server for HBR replay viewer
 *
 * Usage:
 *   node hbr_viewer_server.js <file.hbr2>
 *
 * Writes "PORT:<n>\n" to stdout when ready.
 * HTTP  → serves viewer.html
 * WS    → streams replay frame data at real-time 60fps
 *          accepts JSON commands: { cmd:"seek", frame:N }  { cmd:"pause" }
 *                                 { cmd:"play" }  { cmd:"speed", v:N }
 */

const origWrite = process.stdout.write.bind(process.stdout);
process.stdout.write = () => true;
process.stderr.write = () => true;

const { performance } = require('perf_hooks');
const pako = require('pako');
const { Replay } = require('node-haxball')({ performance, pako });

process.stdout.write = origWrite;

const http    = require('http');
const ws_mod  = require('ws');
const fs      = require('fs');
const path    = require('path');

const filePath = process.argv[2];
if (!filePath) { origWrite('ERR:no file\n'); process.exit(1); }

// ── Load replay ───────────────────────────────────────────────────────────────
const buf = new Uint8Array(fs.readFileSync(filePath));

// readAll for metadata
const rAll = Replay.readAll(buf);
const totalFrames = rAll.totalFrames;

const playerMap = {};
for (const p of (rAll.roomData.G || [])) {
  const id = p['$'];
  if (id != null) {
    playerMap[id] = {
      name: (p.L || '?').trim(),
      team: p.p ? p.p['$'] : 0,
      avatar: p.av || null,
    };
  }
}

const goals = (rAll.goalMarkers || []).map(gm => ({
  frameNo: gm.frameNo,
  teamId: gm.teamId,
}));

// Replay.read for seeking
const rr = Replay.read(buf, {}, null);

// ── HTTP server ───────────────────────────────────────────────────────────────
const htmlPath = path.join(__dirname, 'viewer.html');
const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(fs.readFileSync(htmlPath));
});

// ── WebSocket server ──────────────────────────────────────────────────────────
const wss = new ws_mod.Server({ server });

// Poll until getCurrentFrameNo() >= target
async function waitForFrame(target, ms = 4000) {
  const deadline = Date.now() + ms;
  while (Date.now() < deadline) {
    if (rr.getCurrentFrameNo() >= target) return true;
    await new Promise(r => setTimeout(r, 0));
  }
  return false;
}

function captureState() {
  const gs = rr.gameState;
  const s = gs && gs.s;
  if (!s || !Array.isArray(s.F)) return null;

  let ball = null;
  if (s.F[0] && s.F[0].B) {
    const b = s.F[0].B;
    ball = { x: +b.x.toFixed(1), y: +b.y.toFixed(1) };
  }

  const players = [];
  for (const d of s.F) {
    if (!d || d.K == null || !d.B) continue;
    const { x, y } = d.B;
    if (Math.abs(x) > 2000 || Math.abs(y) > 1000) continue;
    players.push({ id: d.K, x: +x.toFixed(1), y: +y.toFixed(1) });
  }

  return { ball, players };
}

wss.on('connection', (socket) => {
  let playing = false;
  let speed = 1.0;
  let currentFrame = 0;
  let playInterval = null;

  const FRAME_INTERVAL = 1000 / 60;

  // Send init metadata
  socket.send(JSON.stringify({
    type: 'init',
    totalFrames,
    durationMs: Math.round(totalFrames * 1000 / 60),
    playerMap,
    goals,
  }));

  function sendFrame() {
    const state = captureState();
    if (!state) return;
    const f = rr.getCurrentFrameNo();
    currentFrame = f;
    try {
      socket.send(JSON.stringify({ type: 'frame', f, ...state }));
    } catch (_) { /* client may have closed */ }
  }

  function startPlay() {
    if (playInterval) clearInterval(playInterval);
    const advancePerTick = Math.max(1, Math.round(speed));
    playInterval = setInterval(async () => {
      if (!playing) { clearInterval(playInterval); playInterval = null; return; }
      const next = Math.min(currentFrame + advancePerTick, totalFrames);
      if (currentFrame >= totalFrames) {
        playing = false;
        clearInterval(playInterval);
        playInterval = null;
        return;
      }
      rr.setCurrentFrameNo(next);
      await waitForFrame(next, 500);
      sendFrame();
    }, FRAME_INTERVAL / speed);
  }

  socket.on('message', async (raw) => {
    let msg;
    try { msg = JSON.parse(raw); } catch { return; }
    const { cmd } = msg;

    if (cmd === 'seek') {
      const target = Math.max(0, Math.min(totalFrames, msg.frame || 0));
      rr.setCurrentFrameNo(target);
      await waitForFrame(target);
      currentFrame = target;
      sendFrame();
    } else if (cmd === 'play') {
      playing = true;
      startPlay();
    } else if (cmd === 'pause') {
      playing = false;
      if (playInterval) { clearInterval(playInterval); playInterval = null; }
    } else if (cmd === 'speed') {
      speed = Math.max(0.25, Math.min(10, msg.v || 1));
      if (playing) startPlay(); // restart with new speed
    }
  });

  socket.on('close', () => {
    playing = false;
    if (playInterval) { clearInterval(playInterval); playInterval = null; }
  });
});

server.listen(0, '127.0.0.1', () => {
  const port = server.address().port;
  origWrite(`PORT:${port}\n`);
});

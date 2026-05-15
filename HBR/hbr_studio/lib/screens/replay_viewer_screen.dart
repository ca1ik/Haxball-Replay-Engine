// lib/screens/replay_viewer_screen.dart
// Filmora-style match viewer: 2D field + timeline scrubber + playback controls
//
// Layout:
//   ┌─────────────────────────────────────┐
//   │  Top bar: file name + close         │
//   ├─────────────────────────────────────┤
//   │  Field (CustomPainter, 2/3 height)  │
//   ├─────────────────────────────────────┤
//   │  Score badge + half indicator       │
//   ├─────────────────────────────────────┤
//   │  Timeline + goal markers            │
//   ├─────────────────────────────────────┤
//   │  Controls: play/pause / speed / cut │
//   └─────────────────────────────────────┘
//
// HaxBall coordinate system: x ∈ [-1200, 1200], y ∈ [-550, 550] (Big map approx.)
// Ball color: cyan 0xFF2EC6F6   Red: 0xFFE56E56   Blue: 0xFF5689E5

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;

import '../models/frame_data.dart';
import '../services/frame_service.dart';
import '../theme/app_theme.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const double _fieldW = 1250.0; // half-width of HaxBall Big stadium (sim units)
const double _fieldH = 550.0; // half-height
const double _goalH = 170.0; // half-height of goal opening
const double _goalD = 50.0; // goal depth
const double _ballR = 6.4; // ball physics radius (sim units)
const double _playerR = 15.0; // player disc radius (sim units)

// ── Entry point ───────────────────────────────────────────────────────────────
class ReplayViewerScreen extends StatefulWidget {
  final String filePath;

  const ReplayViewerScreen({super.key, required this.filePath});

  @override
  State<ReplayViewerScreen> createState() => _ReplayViewerState();
}

class _ReplayViewerState extends State<ReplayViewerScreen>
    with SingleTickerProviderStateMixin {
  // Loading state
  _LoadState _loadState = _LoadState.loading;
  String _loadError = '';
  int _loadedFrames = 0;
  int _totalEstimate = 1;

  // Replay data
  ReplaySession? _session;

  // Playback state
  double _currentFrame = 0;
  bool _isPlaying = false;
  double _speed = 1.0; // 0.25, 0.5, 1, 2, 4

  // Ticker for animation
  Ticker? _ticker;
  Duration _prevTickTime = Duration.zero;

  // HaxBall is 60fps
  static const double _fps = 60.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _loadSession();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    try {
      final session = await FrameService.load(
        widget.filePath,
        sampleRate: 30, // ~0.5s granularity; viewer interpolates
        onProgress: (loaded, total) {
          if (mounted) {
            setState(() {
              _loadedFrames = loaded;
              _totalEstimate = total;
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _session = session;
          _loadState = _LoadState.ready;
          _currentFrame = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadState = _LoadState.error;
          _loadError = e.toString();
        });
      }
    }
  }

  void _onTick(Duration elapsed) {
    if (!_isPlaying || _session == null || _loadState != _LoadState.ready) {
      _prevTickTime = elapsed;
      return;
    }
    final dt = elapsed - _prevTickTime;
    _prevTickTime = elapsed;

    final delta = dt.inMicroseconds / 1000000.0 * _fps * _speed;
    final next = (_currentFrame + delta).clamp(
      0.0,
      _session!.meta.totalFrames.toDouble(),
    );

    setState(() {
      _currentFrame = next;
      if (_currentFrame >= _session!.meta.totalFrames) {
        _isPlaying = false;
        _currentFrame = _session!.meta.totalFrames.toDouble();
      }
    });
  }

  // ── Split action ─────────────────────────────────────────────────────────────
  Future<void> _splitHere() async {
    if (_session == null) return;
    final frame = _currentFrame.round();
    final ms = (frame * 1000 / _fps).round();

    // Show confirmation + frame info
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141929),
        title: Text(
          'Split at this frame?',
          style: GoogleFonts.inter(color: AppTheme.textPrim),
        ),
        content: Text(
          'Frame $frame  (${_fmtMs(ms)})\n\nThis will split the replay into two files.',
          style: GoogleFonts.inter(color: AppTheme.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppTheme.textHint),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.black87,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Split',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (ok != true) return;

    // Return split frame to caller (could also call node directly)
    if (mounted) Navigator.pop(context, frame);
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      body: switch (_loadState) {
        _LoadState.loading => _buildLoading(),
        _LoadState.error => _buildError(),
        _LoadState.ready => _buildViewer(),
      },
    );
  }

  // ── Loading screen ────────────────────────────────────────────────────────────
  Widget _buildLoading() {
    final pct = _totalEstimate > 0
        ? (_loadedFrames / _totalEstimate).clamp(0.0, 1.0)
        : 0.0;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sports_soccer, color: AppTheme.accent, size: 48),
          const SizedBox(height: 20),
          Text(
            'Loading replay…',
            style: GoogleFonts.inter(
              color: AppTheme.textPrim,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 320,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct > 0 ? pct : null,
                backgroundColor: AppTheme.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.accent,
                ),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _loadedFrames > 0
                ? '$_loadedFrames / ~$_totalEstimate keyframes'
                : 'Simulating physics…',
            style: GoogleFonts.inter(color: AppTheme.textSec, fontSize: 12),
          ),
          const SizedBox(height: 24),
          Text(
            p.basename(widget.filePath),
            style: GoogleFonts.inter(color: AppTheme.textHint, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
        const SizedBox(height: 16),
        Text(
          'Failed to load replay',
          style: GoogleFonts.inter(
            color: AppTheme.textPrim,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            _loadError,
            style: GoogleFonts.inter(color: AppTheme.textSec, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.surface,
            foregroundColor: AppTheme.textPrim,
          ),
        ),
      ],
    ),
  );

  // ── Main viewer ───────────────────────────────────────────────────────────────
  Widget _buildViewer() {
    final session = _session!;
    final frameData = session.interpolateAt(_currentFrame.round());
    final halfFrame = session.meta.halfFrame;
    final isFirstHalf = _currentFrame <= halfFrame;

    return Column(
      children: [
        _buildTopBar(session),
        _buildScoreBadge(session, _currentFrame.round()),
        Expanded(
          child: _FieldView(session: session, frameData: frameData),
        ),
        const SizedBox(height: 8),
        _buildTimeline(session),
        const SizedBox(height: 6),
        _buildControls(session, isFirstHalf),
        const SizedBox(height: 10),
      ],
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────────
  Widget _buildTopBar(ReplaySession session) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1524),
        border: Border(bottom: BorderSide(color: Color(0xFF1E2740))),
      ),
      child: Row(
        children: [
          const Icon(Icons.sports_soccer, color: AppTheme.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              p.basename(session.filePath),
              style: GoogleFonts.inter(
                color: AppTheme.textPrim,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${session.frames.length} keyframes  •  ${session.meta.totalFrames} frames',
            style: GoogleFonts.inter(color: AppTheme.textHint, fontSize: 11),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppTheme.textSec,
            onPressed: () => Navigator.pop(context),
            tooltip: 'Close viewer',
          ),
        ],
      ),
    );
  }

  // ── Score badge ───────────────────────────────────────────────────────────────
  Widget _buildScoreBadge(ReplaySession session, int atFrame) {
    final goals = session.meta.goals;
    int red = 0, blue = 0;
    for (final g in goals) {
      if (g.frameNo <= atFrame) {
        if (g.teamId == 1)
          red++;
        else
          blue++;
      }
    }
    final half = atFrame <= session.meta.halfFrame ? '1st Half' : '2nd Half';
    final timeMs = (atFrame * 1000 / _fps).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      color: const Color(0xFF0A0E1A),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Red team score
          _ScoreChip(score: red, color: const Color(0xFFE56E56), label: 'Red'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$red – $blue',
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrim,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  '$half  •  ${_fmtMs(timeMs)}',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSec,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Blue team score
          _ScoreChip(
            score: blue,
            color: const Color(0xFF5689E5),
            label: 'Blue',
          ),
        ],
      ),
    );
  }

  // ── Timeline ──────────────────────────────────────────────────────────────────
  Widget _buildTimeline(ReplaySession session) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Goal markers row
          SizedBox(
            height: 16,
            child: LayoutBuilder(
              builder: (_, constraints) {
                final w = constraints.maxWidth;
                return Stack(
                  children: [
                    // Half marker
                    Positioned(
                      left:
                          w *
                              session.meta.halfFrame /
                              session.meta.totalFrames -
                          1,
                      child: Container(
                        width: 2,
                        height: 16,
                        color: AppTheme.textHint,
                      ),
                    ),
                    // Goal markers
                    ...session.meta.goals.map((g) {
                      final x = w * g.frameNo / session.meta.totalFrames;
                      return Positioned(
                        left: x - 3,
                        top: 2,
                        child: Container(
                          width: 6,
                          height: 12,
                          decoration: BoxDecoration(
                            color: g.teamId == 1
                                ? const Color(0xFFE56E56)
                                : const Color(0xFF5689E5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 2),
          // Scrubber
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: AppTheme.border,
              thumbColor: AppTheme.accent,
              overlayColor: AppTheme.accent.withOpacity(0.15),
            ),
            child: Slider(
              value: _currentFrame,
              min: 0,
              max: session.meta.totalFrames.toDouble(),
              onChanged: (v) => setState(() {
                _currentFrame = v;
                _isPlaying = false;
              }),
            ),
          ),
          // Time labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _fmtMs((_currentFrame * 1000 / _fps).round()),
                  style: GoogleFonts.inter(
                    color: AppTheme.textSec,
                    fontSize: 11,
                  ),
                ),
                Text(
                  _fmtMs(session.meta.durationMs),
                  style: GoogleFonts.inter(
                    color: AppTheme.textHint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Playback controls ─────────────────────────────────────────────────────────
  Widget _buildControls(ReplaySession session, bool isFirstHalf) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Jump to prev goal
        _CtrlBtn(
          icon: Icons.skip_previous_rounded,
          tooltip: 'Previous goal',
          onTap: () {
            final cur = _currentFrame.round();
            final prev = session.meta.goals
                .where((g) => g.frameNo < cur - 60)
                .fold<int?>(
                  null,
                  (best, g) =>
                      best == null || g.frameNo > best ? g.frameNo : best,
                );
            if (prev != null) {
              setState(() {
                _currentFrame = prev.toDouble();
                _isPlaying = false;
              });
            }
          },
        ),
        const SizedBox(width: 6),
        // Play / Pause
        _CtrlBtn(
          icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          tooltip: _isPlaying ? 'Pause' : 'Play',
          large: true,
          onTap: () {
            setState(() {
              _isPlaying = !_isPlaying;
              if (_isPlaying && _currentFrame >= session.meta.totalFrames) {
                _currentFrame = 0;
              }
              _prevTickTime = Duration.zero; // reset dt
            });
          },
        ),
        const SizedBox(width: 6),
        // Jump to next goal
        _CtrlBtn(
          icon: Icons.skip_next_rounded,
          tooltip: 'Next goal',
          onTap: () {
            final cur = _currentFrame.round();
            final next = session.meta.goals
                .where((g) => g.frameNo > cur + 60)
                .fold<int?>(
                  null,
                  (best, g) =>
                      best == null || g.frameNo < best ? g.frameNo : best,
                );
            if (next != null) {
              setState(() {
                _currentFrame = next.toDouble();
                _isPlaying = false;
              });
            }
          },
        ),
        const SizedBox(width: 20),
        // Speed selector
        ...[0.25, 0.5, 1.0, 2.0, 4.0].map(
          (s) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _SpeedChip(
              label: s == 0.25
                  ? '¼×'
                  : s == 0.5
                  ? '½×'
                  : '${s.toInt()}×',
              active: _speed == s,
              onTap: () => setState(() => _speed = s),
            ),
          ),
        ),
        const SizedBox(width: 20),
        // Split here
        _CtrlBtn(
          icon: Icons.content_cut_rounded,
          tooltip: 'Split at current frame',
          color: AppTheme.warning,
          onTap: _splitHere,
        ),
        const SizedBox(width: 6),
        // Half indicator chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Text(
            isFirstHalf ? '1st Half' : '2nd Half',
            style: GoogleFonts.inter(
              color: AppTheme.textSec,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Field painter ─────────────────────────────────────────────────────────────
class _FieldView extends StatelessWidget {
  final ReplaySession session;
  final FrameData frameData;

  const _FieldView({required this.session, required this.frameData});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF050810),
      child: CustomPaint(
        painter: _FieldPainter(
          frameData: frameData,
          playerMap: session.meta.playerMap,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _FieldPainter extends CustomPainter {
  final FrameData frameData;
  final Map<int, PlayerInfo> playerMap;

  const _FieldPainter({required this.frameData, required this.playerMap});

  // Map sim coords → canvas coords
  Offset _toCanvas(double sx, double sy, double cw, double ch) {
    // Sim: x ∈ [-_fieldW, _fieldW], y ∈ [-_fieldH, _fieldH]  (y up)
    // Canvas: top-left origin, y down
    final scaleX = cw / (_fieldW * 2);
    final scaleY = ch / (_fieldH * 2);
    final scale = math.min(scaleX, scaleY) * 0.85; // slight margin
    final ox = cw / 2;
    final oy = ch / 2;
    return Offset(ox + sx * scale, oy - sy * scale);
  }

  double _scale(double cw, double ch) {
    final scaleX = cw / (_fieldW * 2);
    final scaleY = ch / (_fieldH * 2);
    return math.min(scaleX, scaleY) * 0.85;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width;
    final ch = size.height;
    final sc = _scale(cw, ch);

    // ── Field background ──────────────────────────────────────────────────────
    final tl = _toCanvas(-_fieldW, _fieldH, cw, ch);
    final br = _toCanvas(_fieldW, -_fieldH, cw, ch);
    final fieldRect = Rect.fromLTRB(tl.dx, tl.dy, br.dx, br.dy);

    canvas.drawRRect(
      RRect.fromRectAndRadius(fieldRect, const Radius.circular(4)),
      Paint()..color = const Color(0xFF1A4A2E),
    );

    // Grass stripes (alternating light/dark)
    final stripeW = fieldRect.width / 10;
    for (int i = 0; i < 10; i++) {
      if (i % 2 == 0) continue;
      canvas.drawRect(
        Rect.fromLTWH(
          fieldRect.left + i * stripeW,
          fieldRect.top,
          stripeW,
          fieldRect.height,
        ),
        Paint()..color = const Color(0xFF1F5534),
      );
    }

    // ── Field lines ───────────────────────────────────────────────────────────
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.45)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Outer boundary
    canvas.drawRect(fieldRect, linePaint);

    // Center line
    final centerL = _toCanvas(0, _fieldH, cw, ch);
    final centerR = _toCanvas(0, -_fieldH, cw, ch);
    canvas.drawLine(centerL, centerR, linePaint);

    // Center circle (radius ~150 sim units)
    final centerO = _toCanvas(0, 0, cw, ch);
    canvas.drawCircle(centerO, 150 * sc, linePaint);
    canvas.drawCircle(
      centerO,
      3,
      Paint()..color = Colors.white.withOpacity(0.6),
    );

    // Goals (left = red, right = blue)
    _drawGoal(canvas, cw, ch, sc, isLeft: true, linePaint: linePaint);
    _drawGoal(canvas, cw, ch, sc, isLeft: false, linePaint: linePaint);

    // Penalty areas (simplified)
    _drawPenaltyArea(canvas, cw, ch, sc, isLeft: true, linePaint: linePaint);
    _drawPenaltyArea(canvas, cw, ch, sc, isLeft: false, linePaint: linePaint);

    // ── Players ───────────────────────────────────────────────────────────────
    for (final player in frameData.players) {
      final info = playerMap[player.id];
      final isRed = info?.team == 1;
      final isBlue = info?.team == 2;
      if (!isRed && !isBlue) continue; // skip spec

      final pos = _toCanvas(player.x, player.y, cw, ch);
      final r = _playerR * sc;
      final col = isRed ? const Color(0xFFE56E56) : const Color(0xFF5689E5);

      // Disc shadow
      canvas.drawCircle(
        pos + const Offset(1.5, 2),
        r,
        Paint()..color = Colors.black.withOpacity(0.35),
      );

      // Disc fill
      canvas.drawCircle(pos, r, Paint()..color = col);

      // Disc border
      canvas.drawCircle(
        pos,
        r,
        Paint()
          ..color = Colors.white.withOpacity(0.6)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );

      // Player name label
      if (info?.name != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: info!.name.trim().length > 8
                ? '${info.name.trim().substring(0, 7)}…'
                : info.name.trim(),
            style: TextStyle(
              color: Colors.white,
              fontSize: math.max(8, r * 0.7),
              fontWeight: FontWeight.w700,
              shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        tp.paint(
          canvas,
          Offset(pos.dx - tp.width / 2, pos.dy - r - tp.height - 2),
        );
      }
    }

    // ── Ball ──────────────────────────────────────────────────────────────────
    if (frameData.ball != null) {
      final bp = _toCanvas(frameData.ball!.dx, frameData.ball!.dy, cw, ch);
      final br = _ballR * sc * 1.8; // slightly larger for visibility

      // Shadow
      canvas.drawCircle(
        bp + const Offset(1.5, 2),
        br,
        Paint()..color = Colors.black.withOpacity(0.4),
      );

      // Ball
      canvas.drawCircle(bp, br, Paint()..color = const Color(0xFFFFFFFF));
      canvas.drawCircle(
        bp,
        br,
        Paint()
          ..color = const Color(0xFF2EC6F6)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawGoal(
    Canvas canvas,
    double cw,
    double ch,
    double sc, {
    required bool isLeft,
    required Paint linePaint,
  }) {
    final sx = isLeft ? -_fieldW : _fieldW;
    final depth = isLeft ? -_goalD : _goalD;

    final topInner = _toCanvas(sx, _goalH, cw, ch);
    final botInner = _toCanvas(sx, -_goalH, cw, ch);
    final topOuter = _toCanvas(sx + depth, _goalH, cw, ch);
    final botOuter = _toCanvas(sx + depth, -_goalH, cw, ch);

    // Goal net fill
    final goalPath = Path()
      ..moveTo(topInner.dx, topInner.dy)
      ..lineTo(topOuter.dx, topOuter.dy)
      ..lineTo(botOuter.dx, botOuter.dy)
      ..lineTo(botInner.dx, botInner.dy)
      ..close();

    canvas.drawPath(
      goalPath,
      Paint()
        ..color = (isLeft ? const Color(0xFFE56E56) : const Color(0xFF5689E5))
            .withOpacity(0.12),
    );

    // Goal frame
    canvas.drawLine(topInner, topOuter, linePaint);
    canvas.drawLine(topOuter, botOuter, linePaint);
    canvas.drawLine(botOuter, botInner, linePaint);

    // Goal line (thicker, colored)
    canvas.drawLine(
      topInner,
      botInner,
      Paint()
        ..color = isLeft
            ? const Color(0xFFE56E56).withOpacity(0.8)
            : const Color(0xFF5689E5).withOpacity(0.8)
        ..strokeWidth = 2,
    );
  }

  void _drawPenaltyArea(
    Canvas canvas,
    double cw,
    double ch,
    double sc, {
    required bool isLeft,
    required Paint linePaint,
  }) {
    const paW = 200.0; // penalty area width (sim units from goal line)
    const paH = 350.0; // half-height
    final sx = isLeft ? -_fieldW : _fieldW;
    final endX = isLeft ? sx + paW : sx - paW;

    final tl = _toCanvas(sx, paH, cw, ch);
    final tr = _toCanvas(endX, paH, cw, ch);
    final br = _toCanvas(endX, -paH, cw, ch);
    final bl = _toCanvas(sx, -paH, cw, ch);

    final path = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy);

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_FieldPainter old) => old.frameData != frameData;
}

// ── Helper widgets ─────────────────────────────────────────────────────────────
class _ScoreChip extends StatelessWidget {
  final int score;
  final Color color;
  final String label;

  const _ScoreChip({
    required this.score,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '$score',
            style: GoogleFonts.inter(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool large;
  final Color? color;

  const _CtrlBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.large = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final size = large ? 44.0 : 36.0;
    final iconSize = large ? 26.0 : 18.0;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: large ? AppTheme.accent.withOpacity(0.15) : AppTheme.surface,
            border: Border.all(
              color: large ? AppTheme.accent : AppTheme.border,
            ),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: color ?? (large ? AppTheme.accent : AppTheme.textSec),
          ),
        ),
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SpeedChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent.withOpacity(0.2) : AppTheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? AppTheme.accent : AppTheme.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: active ? AppTheme.accent : AppTheme.textHint,
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── State enum ────────────────────────────────────────────────────────────────
enum _LoadState { loading, error, ready }

// ── Helpers ───────────────────────────────────────────────────────────────────
String _fmtMs(int ms) {
  final s = ms ~/ 1000;
  final m = s ~/ 60;
  final rem = s % 60;
  return '${m.toString().padLeft(2, '0')}:${rem.toString().padLeft(2, '0')}';
}

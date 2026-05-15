import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class HowItWorksScreen extends StatefulWidget {
  const HowItWorksScreen({super.key});

  @override
  State<HowItWorksScreen> createState() => _HowItWorksScreenState();
}

class _HowItWorksScreenState extends State<HowItWorksScreen>
    with TickerProviderStateMixin {
  int _tab = 0;
  late final AnimationController _flowCtrl;
  bool _animating = false;
  // Interactive split point (0.0–1.0), draggable after animation ends
  double _splitRatio = 0.45;

  @override
  void initState() {
    super.initState();
    _flowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void dispose() {
    _flowCtrl.dispose();
    super.dispose();
  }

  void _playAnimation() async {
    setState(() => _animating = true);
    await _flowCtrl.forward(from: 0);
    setState(() => _animating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 20),
        _buildTabs(),
        const SizedBox(height: 24),
        Expanded(
          child: _tab == 0 ? _buildMergeContent() : _buildSplitContent(),
        ),
      ],
    );
  }

  Widget _buildHeader() => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF8C42), Color(0xFFFF4D6A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.play_circle_outline_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
      const SizedBox(width: 14),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How It Works',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrim,
            ),
          ),
          Text(
            'Visual guide to merge & split operations',
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSec),
          ),
        ],
      ),
      const Spacer(),
      GestureDetector(
        onTap: _animating ? null : _playAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8C42), Color(0xFFFF4D6A)],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF8C42).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _animating
                    ? Icons.hourglass_top_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                _animating ? 'Playing...' : 'Play Animation',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);

  Widget _buildTabs() => Row(
    children: [
      _TabBtn(
        label: 'Merge Replays',
        icon: Icons.merge_type_rounded,
        color: AppTheme.accent,
        active: _tab == 0,
        onTap: () => setState(() {
          _tab = 0;
          _flowCtrl.reset();
        }),
      ),
      const SizedBox(width: 8),
      _TabBtn(
        label: 'Split Replay',
        icon: Icons.content_cut_rounded,
        color: AppTheme.purple,
        active: _tab == 1,
        onTap: () => setState(() {
          _tab = 1;
          _flowCtrl.reset();
        }),
      ),
    ],
  );

  // ── Merge content ──────────────────────────────────────────────────────────
  Widget _buildMergeContent() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(flex: 5, child: _buildMergeAnimation()),
      const SizedBox(width: 24),
      Expanded(flex: 3, child: _buildMergeSteps()),
    ],
  ).animate().fadeIn(duration: 400.ms);

  Widget _buildMergeAnimation() => GlassCard(
    padding: const EdgeInsets.all(28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel('Merge Flow Diagram'),
        const SizedBox(height: 24),
        _MergeDiagram(controller: _flowCtrl),
        const SizedBox(height: 24),
        _buildMergeTimeline(),
      ],
    ),
  );

  Widget _buildMergeTimeline() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionLabel('Merged Timeline'),
      const SizedBox(height: 10),
      Container(
        height: 36,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Expanded(
                flex: 53,
                child: Container(
                  color: AppTheme.accent.withOpacity(0.25),
                  child: Center(
                    child: Text(
                      '1st Half  ·  44,763 frames',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                ),
              ),
              Container(width: 3, color: AppTheme.bg),
              Expanded(
                flex: 3,
                child: Container(
                  color: AppTheme.border,
                  child: Center(
                    child: Icon(
                      Icons.sync_alt_rounded,
                      size: 10,
                      color: AppTheme.textHint,
                    ),
                  ),
                ),
              ),
              Container(width: 3, color: AppTheme.bg),
              Expanded(
                flex: 47,
                child: Container(
                  color: AppTheme.purple.withOpacity(0.25),
                  child: Center(
                    child: Text(
                      '2nd Half  ·  41,645 frames',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.purple,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Text(
            '00:00',
            style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textHint),
          ),
          const Spacer(),
          Text(
            '~44:47',
            style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textHint),
          ),
          const Spacer(),
          Text(
            '~86:11',
            style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textHint),
          ),
        ],
      ),
    ],
  );

  Widget _buildMergeSteps() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionLabel('Process Steps'),
      const SizedBox(height: 12),
      ..._mergeSteps.asMap().entries.map(
        (e) => _StepCard(
          index: e.key + 1,
          title: e.value.$1,
          description: e.value.$2,
          color: AppTheme.accent,
          delay: e.key * 80,
        ),
      ),
    ],
  );

  static const _mergeSteps = [
    (
      'Read both files',
      'Each .hbr2 file is parsed using the node-haxball Replay API, extracting events, room state and goal markers.',
    ),
    (
      'Normalize team order',
      'FILE1 team players are moved to spectator. FILE2 players are re-added in FILE2\'s exact room state order to preserve spawn positions.',
    ),
    (
      'Insert transition',
      'A synthetic stopGame event is injected, followed by setPlayerTeam events at the boundary frame.',
    ),
    (
      'Offset & concat',
      'FILE2 events are offset by FILE1.totalFrames+3 so they continue seamlessly after the halftime.',
    ),
    (
      'Write output',
      'The merged replay object is serialized back to the HBR2 binary format (magic + version + deflate payload).',
    ),
  ];

  // ── Split content ──────────────────────────────────────────────────────────
  Widget _buildSplitContent() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(flex: 5, child: _buildSplitAnimation()),
      const SizedBox(width: 24),
      Expanded(flex: 3, child: _buildSplitSteps()),
    ],
  ).animate().fadeIn(duration: 400.ms);

  Widget _buildSplitAnimation() => GlassCard(
    padding: const EdgeInsets.all(28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Split Flow Diagram'),
        const SizedBox(height: 24),
        _SplitDiagram(controller: _flowCtrl),
        const SizedBox(height: 24),
        _buildSplitTimeline(),
      ],
    ),
  );

  /// Convert a ratio (0.0–1.0) to "MM:SS" assuming a 90-minute typical match
  String _ratioToTime(double ratio) {
    final totalSec = (ratio * 90 * 60).round();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildSplitTimeline() {
    final canDrag = !_animating;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SectionLabel('Split at chosen point'),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.purple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.purple.withOpacity(0.4)),
                boxShadow: canDrag
                    ? [
                        BoxShadow(
                          color: AppTheme.purple.withOpacity(0.25),
                          blurRadius: 8,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    canDrag
                        ? Icons.drag_indicator_rounded
                        : Icons.lock_clock_rounded,
                    size: 12,
                    color: AppTheme.purple,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    canDrag ? '← drag to reposition →' : 'play animation first',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.purple,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final totalW = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: canDrag
                  ? (d) => setState(() {
                      _splitRatio =
                          ((_splitRatio * totalW + d.delta.dx) / totalW).clamp(
                            0.05,
                            0.95,
                          );
                    })
                  : null,
              onTapDown: canDrag
                  ? (d) => setState(() {
                      _splitRatio = (d.localPosition.dx / totalW).clamp(
                        0.05,
                        0.95,
                      );
                    })
                  : null,
              child: MouseRegion(
                cursor: canDrag
                    ? SystemMouseCursors.resizeColumn
                    : SystemMouseCursors.basic,
                child: Stack(
                  children: [
                    // Timeline bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 40,
                        child: Row(
                          children: [
                            Expanded(
                              flex: (_splitRatio * 1000).round(),
                              child: Container(
                                color: AppTheme.accent.withOpacity(0.2),
                                child: Center(
                                  child: Text(
                                    'Part 1  →  output1.hbr2',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.accent,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: ((1 - _splitRatio) * 1000).round(),
                              child: Container(
                                color: AppTheme.purple.withOpacity(0.2),
                                child: Center(
                                  child: Text(
                                    'Part 2  →  output2.hbr2',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.purple,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Draggable divider line
                    Positioned(
                      left: totalW * _splitRatio - 1,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.7),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Drag handle knob
                    Positioned(
                      left: totalW * _splitRatio - 8,
                      top: 10,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 16,
                        height: 20,
                        decoration: BoxDecoration(
                          color: canDrag ? Colors.white : Colors.white54,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.purple.withOpacity(0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            size: 10,
                            color: canDrag
                                ? AppTheme.purple
                                : AppTheme.textHint,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '00:00',
              style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textHint),
            ),
            const Spacer(),
            // Time badge at split point
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.purple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.purple.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.content_cut_rounded,
                    size: 9,
                    color: AppTheme.purple,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _ratioToTime(_splitRatio),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.purple,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              '90:00',
              style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textHint),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSplitSteps() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionLabel('Process Steps'),
      const SizedBox(height: 12),
      ..._splitSteps.asMap().entries.map(
        (e) => _StepCard(
          index: e.key + 1,
          title: e.value.$1,
          description: e.value.$2,
          color: AppTheme.purple,
          delay: e.key * 80,
        ),
      ),
    ],
  );

  static const _splitSteps = [
    (
      'Read input file',
      'The .hbr2 file is fully parsed to obtain all events with absolute frame numbers.',
    ),
    (
      'Partition events',
      'Events with frameNo ≤ splitFrame go to Part 1. Events with frameNo > splitFrame go to Part 2.',
    ),
    (
      'Re-offset Part 2',
      'Part 2 event frame numbers are shifted left by splitFrame so Part 2 starts at frame 0.',
    ),
    (
      'Preserve room state',
      'Both parts share the original room state (initial player/stadium config).',
    ),
    (
      'Write two files',
      'Part 1 and Part 2 are each serialized to independent .hbr2 binary files.',
    ),
  ];
}

// ── Tab button ────────────────────────────────────────────────────────────────
class _TabBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _TabBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: active ? color.withOpacity(0.12) : Colors.transparent,
        border: Border.all(
          color: active ? color.withOpacity(0.4) : AppTheme.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: active ? color : AppTheme.textHint),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? color : AppTheme.textHint,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Step card ─────────────────────────────────────────────────────────────────
class _StepCard extends StatelessWidget {
  final int index;
  final String title;
  final String description;
  final Color color;
  final int delay;

  const _StepCard({
    required this.index,
    required this.title,
    required this.description,
    required this.color,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) =>
      Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.surface,
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '$index',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrim,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.textSec,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .animate(delay: Duration(milliseconds: delay))
          .fadeIn(duration: 300.ms)
          .slideX(begin: 0.1);
}

// ── Merge Diagram (CustomPainter) ─────────────────────────────────────────────
class _MergeDiagram extends StatelessWidget {
  final AnimationController controller;
  const _MergeDiagram({required this.controller});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (_, __) => CustomPaint(
      painter: _MergePainter(progress: controller.value),
      size: const Size(double.infinity, 140),
    ),
  );
}

class _MergePainter extends CustomPainter {
  final double progress;
  _MergePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final fileW = 80.0;
    final fileH = 54.0;
    final midY = h * 0.35;

    // ── File 1 (teal) — slides in from left
    final f1x = progress < 0.3 ? w * 0.05 * (progress / 0.3) : w * 0.05;
    _drawFileBox(
      canvas,
      f1x,
      midY - fileH / 2,
      fileW,
      fileH,
      AppTheme.accent,
      '1st Half',
      '44,763 fr',
    );

    // ── File 2 (purple) — slides in from right
    final f2xFinal = w - fileW - w * 0.05;
    final f2x = progress < 0.3
        ? w + (f2xFinal - w) * (progress / 0.3)
        : f2xFinal;
    _drawFileBox(
      canvas,
      f2x,
      midY - fileH / 2,
      fileW,
      fileH,
      AppTheme.purple,
      '2nd Half',
      '41,645 fr',
    );

    // ── Connecting arrows (appear after files arrive)
    if (progress > 0.3) {
      final arrowProgress = ((progress - 0.3) / 0.35).clamp(0.0, 1.0);
      final cx = w / 2;

      // Arrow from file1 to center
      final f1End = f1x + fileW;
      final p1 = Offset(f1End, midY);
      final p2 = Offset(cx - 24, midY);
      _drawArrow(
        canvas,
        p1,
        Offset(f1End + (p2.dx - f1End) * arrowProgress, midY),
        AppTheme.accent,
        arrowProgress,
      );

      // Arrow from file2 to center
      final f2Start = f2x;
      final p3 = Offset(f2Start, midY);
      final p4 = Offset(cx + 24, midY);
      _drawArrow(
        canvas,
        p3,
        Offset(f2Start + (p4.dx - f2Start) * arrowProgress, midY),
        AppTheme.purple,
        arrowProgress,
      );
    }

    // ── Merge box
    if (progress > 0.65) {
      final mergeProgress = ((progress - 0.65) / 0.15).clamp(0.0, 1.0);
      final bx = w / 2 - 30;
      final by = midY - 16;
      final bw = 60.0;
      final bh = 32.0;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, by, bw * mergeProgress, bh),
        const Radius.circular(6),
      );
      canvas.drawRRect(rrect, Paint()..color = const Color(0xFF1E2740));
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = AppTheme.accent.withOpacity(0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // ── Output file (bottom center)
    if (progress > 0.80) {
      final outProgress = ((progress - 0.80) / 0.20).clamp(0.0, 1.0);
      final outX = w / 2 - fileW / 2;
      final outY = h * 0.60;

      // Down arrow
      final arrowStart = Offset(w / 2, midY + 16);
      final arrowEnd = Offset(w / 2, outY - 8);
      _drawArrow(
        canvas,
        arrowStart,
        Offset(
          arrowStart.dx,
          arrowStart.dy + (arrowEnd.dy - arrowStart.dy) * outProgress,
        ),
        Colors.white54,
        outProgress,
      );

      if (outProgress > 0.6) {
        final scale = ((outProgress - 0.6) / 0.4).clamp(0.0, 1.0);
        canvas.save();
        canvas.translate(outX + fileW / 2, outY + fileH / 2);
        canvas.scale(scale, scale);
        canvas.translate(-(outX + fileW / 2), -(outY + fileH / 2));
        _drawFileBox(
          canvas,
          outX,
          outY,
          fileW,
          fileH,
          const Color(0xFF00D4AA),
          'merged.hbr2',
          '86,411 fr',
        );
        canvas.restore();
      }
    }
  }

  void _drawFileBox(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    Color color,
    String title,
    String sub,
  ) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect, Paint()..color = AppTheme.card);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Color strip on top
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, 4),
        const Radius.circular(8),
      ),
      Paint()..color = color.withOpacity(0.7),
    );

    // Icon placeholder (film icon via box)
    final iconPaint = Paint()..color = color.withOpacity(0.4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 8, y + 10, 16, 14),
        const Radius.circular(2),
      ),
      iconPaint,
    );

    final tp1 = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          color: AppTheme.textPrim,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 28);
    tp1.paint(canvas, Offset(x + 28, y + 10));

    final tp2 = TextPainter(
      text: TextSpan(
        text: sub,
        style: TextStyle(color: AppTheme.textHint, fontSize: 8),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 28);
    tp2.paint(canvas, Offset(x + 28, y + 24));
  }

  void _drawArrow(
    Canvas canvas,
    Offset from,
    Offset to,
    Color color,
    double progress,
  ) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);
    if (progress > 0.9) {
      final arrowPaint = Paint()..color = color.withOpacity(0.7);
      final path = Path();
      final dx = to.dx - from.dx;
      final dy = to.dy - from.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len > 0) {
        final nx = dx / len;
        final ny = dy / len;
        path.moveTo(to.dx, to.dy);
        path.lineTo(to.dx - 6 * nx + 4 * ny, to.dy - 6 * ny - 4 * nx);
        path.lineTo(to.dx - 6 * nx - 4 * ny, to.dy - 6 * ny + 4 * nx);
        path.close();
        canvas.drawPath(path, arrowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_MergePainter old) => old.progress != progress;
}

// ── Split Diagram ─────────────────────────────────────────────────────────────
class _SplitDiagram extends StatelessWidget {
  final AnimationController controller;
  const _SplitDiagram({required this.controller});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (_, __) => CustomPaint(
      painter: _SplitPainter(progress: controller.value),
      size: const Size(double.infinity, 140),
    ),
  );
}

class _SplitPainter extends CustomPainter {
  final double progress;
  _SplitPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fileW = 90.0;
    final fileH = 52.0;

    // ── Source file (top center) — drops in
    final srcY = progress < 0.25
        ? -fileH + (h * 0.08 + fileH) * (progress / 0.25)
        : h * 0.08;
    _drawFileBox(
      canvas,
      w / 2 - fileW / 2,
      srcY,
      fileW,
      fileH,
      Colors.white54,
      'input.hbr2',
      '86,411 frames',
    );

    // ── Timeline bar
    if (progress > 0.25) {
      final tProgress = ((progress - 0.25) / 0.25).clamp(0.0, 1.0);
      final barY = h * 0.47;
      final barLeft = w * 0.06;
      final barRight = w * 0.94;
      final barH = 12.0;

      // Gray base bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barLeft, barY, (barRight - barLeft) * tProgress, barH),
          const Radius.circular(6),
        ),
        Paint()..color = AppTheme.border,
      );

      // Cut scissors icon area
      if (tProgress > 0.7) {
        final cutX = barLeft + (barRight - barLeft) * 0.45;
        final p = Paint()
          ..color = Colors.white.withOpacity(0.9)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(cutX, barY - 6),
          Offset(cutX, barY + barH + 6),
          p,
        );
        // Glow
        canvas.drawLine(
          Offset(cutX, barY - 6),
          Offset(cutX, barY + barH + 6),
          Paint()
            ..color = Colors.white.withOpacity(0.15)
            ..strokeWidth = 8
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }

      // Arrow from source to bar
      final arrowPaint = Paint()
        ..color = Colors.white38
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(w / 2, srcY + fileH),
        Offset(w / 2, barY),
        arrowPaint,
      );
    }

    // ── Two output files
    if (progress > 0.65) {
      final outProgress = ((progress - 0.65) / 0.35).clamp(0.0, 1.0);
      final barY = h * 0.47;
      final outY = h * 0.70;
      final part1X = w * 0.10;
      final part2X = w * 0.55;

      // Arrows
      if (outProgress > 0.2) {
        final ap = ((outProgress - 0.2) / 0.4).clamp(0.0, 1.0);
        final cutX = w * 0.06 + (w * 0.94 - w * 0.06) * 0.45;
        final ap2 = Paint()
          ..color = Colors.white24
          ..strokeWidth = 1.2;
        canvas.drawLine(
          Offset(cutX, barY + 12),
          Offset(part1X + fileW / 2, outY - (outY - barY - 12) * (1 - ap)),
          ap2,
        );
        canvas.drawLine(
          Offset(cutX, barY + 12),
          Offset(part2X + fileW / 2, outY - (outY - barY - 12) * (1 - ap)),
          ap2,
        );
      }

      if (outProgress > 0.5) {
        final scale = ((outProgress - 0.5) / 0.5).clamp(0.0, 1.0);
        // Part 1
        canvas.save();
        canvas.translate(part1X + fileW / 2, outY + fileH / 2);
        canvas.scale(scale, scale);
        canvas.translate(-(part1X + fileW / 2), -(outY + fileH / 2));
        _drawFileBox(
          canvas,
          part1X,
          outY,
          fileW,
          fileH,
          AppTheme.accent,
          'part1.hbr2',
          '~45 min',
        );
        canvas.restore();

        // Part 2
        canvas.save();
        canvas.translate(part2X + fileW / 2, outY + fileH / 2);
        canvas.scale(scale, scale);
        canvas.translate(-(part2X + fileW / 2), -(outY + fileH / 2));
        _drawFileBox(
          canvas,
          part2X,
          outY,
          fileW,
          fileH,
          AppTheme.purple,
          'part2.hbr2',
          '~41 min',
        );
        canvas.restore();
      }
    }
  }

  void _drawFileBox(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    Color color,
    String title,
    String sub,
  ) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect, Paint()..color = AppTheme.card);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, 4),
        const Radius.circular(8),
      ),
      Paint()..color = color.withOpacity(0.7),
    );
    final tp1 = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          color: AppTheme.textPrim,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 12);
    tp1.paint(canvas, Offset(x + 8, y + 11));

    final tp2 = TextPainter(
      text: TextSpan(
        text: sub,
        style: const TextStyle(color: AppTheme.textHint, fontSize: 8),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 12);
    tp2.paint(canvas, Offset(x + 8, y + 24));
  }

  @override
  bool shouldRepaint(_SplitPainter old) => old.progress != progress;
}

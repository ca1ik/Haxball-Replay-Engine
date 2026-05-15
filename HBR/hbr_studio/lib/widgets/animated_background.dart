// lib/widgets/animated_background.dart
// Aurora-style animated background with optional custom photo overlay.
// Supports both dark and light themes. Designed for 360Hz smoothness:
// all animations use vsync + RepaintBoundary so the orb layer repaints
// independently from the rest of the widget tree.

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with TickerProviderStateMixin {
  late final AnimationController _c1 = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat(reverse: true);
  late final AnimationController _c2 = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat(reverse: true);
  late final AnimationController _c3 = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  )..repeat(reverse: true);
  // Slow color-shift controller for background gradient
  late final AnimationController _cBg = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat(reverse: true);
  // Slow pulsing balls layer
  late final AnimationController _cBalls = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    _cBg.dispose();
    _cBalls.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Layer 1: Base gradient (repaints on theme change only) ────────────
        _BaseGradient(isDark: isDark, animation: _cBg),
        // ── Layer 2: Custom photo overlay (if backgroundx.png exists) ─────────
        const _PhotoOverlay(), // ── Layer 3: Animated aurora orbs (RepaintBoundary isolated) ──────────
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_c1, _c2, _c3]),
            builder: (_, __) => CustomPaint(
              painter: _OrbPainter(
                t1: _c1.value,
                t2: _c2.value,
                t3: _c3.value,
                isDark: isDark,
              ),
            ),
          ),
        ),
        // ── Layer 4: Pulsing small balls ─────────────────────────────────────
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _cBalls,
            builder: (_, __) => CustomPaint(
              painter: _BallsPainter(t: _cBalls.value),
            ),
          ),
        ),
        // ── Layer 5: Content ──────────────────────────────────────────
        widget.child,
      ],
    );
  }
}

// ── Base gradient ──────────────────────────────────────────────────────────────
class _BaseGradient extends StatelessWidget {
  final bool isDark;
  final Animation<double> animation;
  const _BaseGradient({required this.isDark, required this.animation});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (_, __) {
      final t = animation.value;
      if (isDark) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  const Color(0xFF080B14),
                  const Color(0xFF060A18),
                  t,
                )!,
                Color.lerp(
                  const Color(0xFF0A0D1A),
                  const Color(0xFF080C16),
                  t,
                )!,
                Color.lerp(
                  const Color(0xFF070A12),
                  const Color(0xFF050810),
                  t,
                )!,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      } else {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  const Color(0xFFF0F2F8),
                  const Color(0xFFECEFF9),
                  t,
                )!,
                Color.lerp(
                  const Color(0xFFF5F7FF),
                  const Color(0xFFF0F2FC),
                  t,
                )!,
                Color.lerp(
                  const Color(0xFFEBEEF8),
                  const Color(0xFFE8ECF6),
                  t,
                )!,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      }
    },
  );
}

// ── Photo overlay ──────────────────────────────────────────────────────────────
// Loads backgroundx.png from the filesystem (placed by user at
// HBR/Assets/photo/backgroundx.png) using a path relative to the running
// executable. The file is NOT bundled in Flutter assets — it lives outside
// the build output alongside the EngineX scripts.
class _PhotoOverlay extends StatefulWidget {
  const _PhotoOverlay();
  @override
  State<_PhotoOverlay> createState() => _PhotoOverlayState();
}

class _PhotoOverlayState extends State<_PhotoOverlay>
    with SingleTickerProviderStateMixin {
  File? _imageFile;
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  /// Resolves the background image path: 6 levels up from the executable,
  /// then Assets/photo/backgroundx.png — same root as EngineX scripts.
  static String _resolvePath() {
    final exe = Platform.resolvedExecutable;
    return p.normalize(
      p.join(
        p.dirname(exe),
        '..',
        '..',
        '..',
        '..',
        '..',
        '..',
        'Assets',
        'photo',
        'backgroundx.png',
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _checkImage();
  }

  Future<void> _checkImage() async {
    final path = _resolvePath();
    final file = File(path);
    if (await file.exists()) {
      if (mounted) setState(() => _imageFile = file);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final show = context.watch<SettingsProvider>().showBackground;
    if (!show || _imageFile == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _fade,
      builder: (_, __) => Opacity(
        opacity: isDark ? 0.12 + _fade.value * 0.04 : 0.14 + _fade.value * 0.04,
        child: Image.file(
          _imageFile!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: 1920,
        ),
      ),
    );
  }
}

// ── Aurora orb painter ─────────────────────────────────────────────────────────
class _OrbPainter extends CustomPainter {
  final double t1, t2, t3;
  final bool isDark;
  const _OrbPainter({
    required this.t1,
    required this.t2,
    required this.t3,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isDark) {
      // Lighter, subtler orbs for light theme
      _drawOrb(
        canvas,
        size,
        x: size.width * (0.75 + t1 * 0.12),
        y: size.height * (0.15 + t1 * 0.08),
        radius: size.width * 0.38,
        color: const Color(0xFF00D4AA),
        opacity: 0.025 + t1 * 0.01,
      );
      _drawOrb(
        canvas,
        size,
        x: size.width * (0.15 - t2 * 0.08),
        y: size.height * (0.70 + t2 * 0.10),
        radius: size.width * 0.32,
        color: const Color(0xFF7B5EA7),
        opacity: 0.02 + t2 * 0.008,
      );
      return;
    }
    // Dark theme orbs
    _drawOrb(
      canvas,
      size,
      x: size.width * (0.78 + t1 * 0.14),
      y: size.height * (0.12 + t1 * 0.10),
      radius: size.width * 0.42,
      color: const Color(0xFF00D4AA),
      opacity: 0.055 + t1 * 0.015,
    );
    _drawOrb(
      canvas,
      size,
      x: size.width * (0.10 - t2 * 0.08),
      y: size.height * (0.72 + t2 * 0.12),
      radius: size.width * 0.36,
      color: const Color(0xFF7B5EA7),
      opacity: 0.05 + t2 * 0.012,
    );
    _drawOrb(
      canvas,
      size,
      x: size.width * (0.48 + t3 * 0.06 - 0.03),
      y: size.height * (0.45 + t3 * 0.08 - 0.04),
      radius: size.width * 0.28,
      color: const Color(0xFF4A6CF7),
      opacity: 0.035 + t3 * 0.010,
    );
  }

  void _drawOrb(
    Canvas canvas,
    Size size, {
    required double x,
    required double y,
    required double radius,
    required Color color,
    required double opacity,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withOpacity(opacity), color.withOpacity(0)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(x, y), radius: radius));
    canvas.drawCircle(Offset(x, y), radius, paint);
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.t1 != t1 || old.t2 != t2 || old.t3 != t3 || old.isDark != isDark;
}

// ── Pulsing small balls ──────────────────────────────────────────────────
class _BallsPainter extends CustomPainter {
  final double t;
  const _BallsPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    const balls = [
      (0.12, 0.22, 4.0, 9.0, 0.00, Color(0xFF7B5EA7)),
      (0.82, 0.18, 3.0, 8.0, 0.33, Color(0xFF4A6CF7)),
      (0.25, 0.72, 5.0, 11.0, 0.60, Color(0xFF7B5EA7)),
      (0.68, 0.60, 4.0, 9.0, 0.15, Color(0xFF4A6CF7)),
      (0.50, 0.38, 3.0, 7.0, 0.75, Color(0xFF00C9FF)),
      (0.88, 0.52, 4.0, 8.0, 0.45, Color(0xFF7B5EA7)),
      (0.40, 0.10, 3.0, 7.0, 0.80, Color(0xFF4A6CF7)),
    ];
    for (final (rx, ry, minR, maxR, phase, color) in balls) {
      final pulse = math.sin((t + phase) * math.pi * 2) * 0.5 + 0.5;
      final radius = minR + (maxR - minR) * pulse;
      final cx = size.width * rx;
      final cy = size.height * ry;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(0.45), color.withOpacity(0)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_BallsPainter old) => old.t != t;
}

// lib/widgets/animated_background.dart
// Aurora-style animated background with optional custom photo overlay.
// Supports both dark and light themes. Designed for 360Hz smoothness:
// all animations use vsync + RepaintBoundary so the orb layer repaints
// independently from the rest of the widget tree.

import 'package:flutter/material.dart';

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

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    _cBg.dispose();
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
        const _PhotoOverlay(),
        // ── Layer 3: Animated aurora orbs (RepaintBoundary isolated) ──────────
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
        // ── Layer 4: Content ──────────────────────────────────────────────────
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
class _PhotoOverlay extends StatefulWidget {
  const _PhotoOverlay();
  @override
  State<_PhotoOverlay> createState() => _PhotoOverlayState();
}

class _PhotoOverlayState extends State<_PhotoOverlay>
    with SingleTickerProviderStateMixin {
  bool _hasImage = false;
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  static const String _assetPath = 'assets/photo/backgroundx.png';

  @override
  void initState() {
    super.initState();
    _checkImage();
  }

  Future<void> _checkImage() async {
    // Check if asset exists (it's bundled) — try/catch for graceful fallback
    try {
      await DefaultAssetBundle.of(context).load(_assetPath);
      if (mounted) setState(() => _hasImage = true);
    } catch (_) {
      // Asset not found — background image not added yet
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasImage) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _fade,
      builder: (_, __) => Opacity(
        opacity: isDark ? 0.06 + _fade.value * 0.02 : 0.08 + _fade.value * 0.02,
        child: Image.asset(
          _assetPath,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
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

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Aurora-style animated background with slowly drifting gradient orbs.
class AnimatedBackground extends StatefulWidget {
  final Widget child;
  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with TickerProviderStateMixin {
  late final AnimationController _c1;
  late final AnimationController _c2;
  late final AnimationController _c3;

  @override
  void initState() {
    super.initState();
    _c1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
    _c2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat(reverse: true);
    _c3 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF080B14), Color(0xFF0A0D1A), Color(0xFF070A12)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        // Orb 1 — teal, top-right
        AnimatedBuilder(
          animation: _c1,
          builder: (_, __) => _Orb(
            color: AppTheme.accent,
            cx: 0.7 + 0.15 * math.sin(_c1.value * math.pi),
            cy: 0.1 + 0.12 * math.cos(_c1.value * math.pi),
            radius: 0.35,
            opacity: 0.055,
          ),
        ),
        // Orb 2 — purple, bottom-left
        AnimatedBuilder(
          animation: _c2,
          builder: (_, __) => _Orb(
            color: AppTheme.purple,
            cx: 0.1 + 0.10 * math.cos(_c2.value * math.pi),
            cy: 0.7 + 0.15 * math.sin(_c2.value * math.pi),
            radius: 0.40,
            opacity: 0.05,
          ),
        ),
        // Orb 3 — blue, center
        AnimatedBuilder(
          animation: _c3,
          builder: (_, __) => _Orb(
            color: const Color(0xFF4A6CF7),
            cx: 0.45 + 0.08 * math.sin(_c3.value * math.pi * 1.3),
            cy: 0.45 + 0.08 * math.cos(_c3.value * math.pi * 0.7),
            radius: 0.28,
            opacity: 0.035,
          ),
        ),
        // Content
        widget.child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double cx, cy, radius, opacity;

  const _Orb({
    required this.color,
    required this.cx,
    required this.cy,
    required this.radius,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final r = radius * math.max(size.width, size.height);
    return Positioned(
      left: cx * size.width - r,
      top: cy * size.height - r,
      child: IgnorePointer(
        child: Container(
          width: r * 2,
          height: r * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withOpacity(opacity), color.withOpacity(0)],
            ),
          ),
        ),
      ),
    );
  }
}

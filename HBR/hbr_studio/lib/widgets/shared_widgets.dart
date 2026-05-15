import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final bool highlighted;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.highlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(16);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: AppTheme.cardGradOf(context),
        border: Border.all(
          color: highlighted
              ? AppTheme.accent.withOpacity(0.5)
              : AppTheme.borderOf(context),
          width: highlighted ? 1.5 : 1,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: AppTheme.accent.withOpacity(0.08),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: br,
        child: InkWell(
          borderRadius: br,
          onTap: onTap,
          splashColor: AppTheme.accent.withOpacity(0.05),
          highlightColor: AppTheme.accent.withOpacity(0.03),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GradientButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool secondary;
  final double? width;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.secondary = false,
    this.width,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final gradient = widget.secondary
        ? AppTheme.purpleGrad
        : AppTheme.accentGrad;
    final disabled = widget.onPressed == null && !widget.loading;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.width,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: disabled ? null : gradient,
          color: disabled ? AppTheme.border : null,
          boxShadow: _hovered && !disabled
              ? [
                  BoxShadow(
                    color:
                        (widget.secondary ? AppTheme.purple : AppTheme.accent)
                            .withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: (disabled || widget.loading) ? null : widget.onPressed,
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, size: 16, color: Colors.white),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Color? color;
  const SectionLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: color ?? AppTheme.textHintOf(context),
      letterSpacing: 1.2,
      decoration: TextDecoration.none,
    ),
  );
}

/// Section label with a purple → indigo gradient shimmer effect.
class GradientSectionLabel extends StatelessWidget {
  final String text;
  final LinearGradient? gradient;
  const GradientSectionLabel(this.text, {super.key, this.gradient});

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => (gradient ?? AppTheme.purpleGrad)
            .createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
        child: Text(
          text.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 1.4,
            decoration: TextDecoration.none,
          ),
        ),
      );
}

/// Numbered step card — same design as Guide screen Process Steps.
class StepCard extends StatelessWidget {
  final int index;
  final String title;
  final String description;
  final Color color;

  const StepCard({
    super.key,
    required this.index,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
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
                width: 22,
                height: 22,
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
                        fontSize: context.rfs(12),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimOf(context),
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: context.rfs(11),
                        color: AppTheme.textSecOf(context),
                        height: 1.4,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// Modern color-coded log entry with icon + Fira Code font.
class LogLine extends StatelessWidget {
  final String text;
  const LogLine(this.text, {super.key});

  Color _color() {
    final l = text.toLowerCase();
    if (l.contains('error') || l.contains('fail') || l.contains('✗'))
      return const Color(0xFFFF4D6A);
    if (l.contains('success') ||
        l.contains('saved') ||
        l.contains('done') ||
        l.contains('complete') ||
        l.contains('✓'))
      return const Color(0xFF00D4AA);
    if (l.contains('warning') || l.contains('warn'))
      return const Color(0xFFFFB347);
    if (l.contains('%') ||
        l.contains('frame') ||
        l.contains('progress') ||
        l.contains('reading') ||
        l.contains('writing'))
      return const Color(0xFF4A6CF7);
    return const Color(0xFF8B9DC3);
  }

  IconData _icon() {
    final l = text.toLowerCase();
    if (l.contains('error') || l.contains('fail') || l.contains('✗'))
      return Icons.error_outline_rounded;
    if (l.contains('success') ||
        l.contains('saved') ||
        l.contains('done') ||
        l.contains('complete') ||
        l.contains('✓'))
      return Icons.check_circle_outline_rounded;
    if (l.contains('%') || l.contains('frame') || l.contains('progress'))
      return Icons.data_usage_rounded;
    return Icons.chevron_right_rounded;
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1.5),
              child: Icon(_icon(), size: 12, color: _color()),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.firaCode(
                  fontSize: context.rfs(11.5),
                  color: _color(),
                  height: 1.4,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      );
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.35), width: 1),
    ),
    child: Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}

class GlowDot extends StatelessWidget {
  final Color color;
  const GlowDot({super.key, this.color = AppTheme.accent});

  @override
  Widget build(BuildContext context) =>
      Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fadeIn(duration: 800.ms, curve: Curves.easeInOut);
}

class InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const InfoChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppTheme.surfaceOf(context),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.borderOf(context)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textHintOf(context)),
        const SizedBox(width: 6),
        Text(
          '$label  ',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppTheme.textHintOf(context),
            decoration: TextDecoration.none,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimOf(context),
            decoration: TextDecoration.none,
          ),
        ),
      ],
    ),
  );
}

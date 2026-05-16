// lib/main.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:window_manager/window_manager.dart';

import 'core/app_l10n.dart';
import 'providers/replay_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/about_screen.dart';
import 'screens/analyzer_screen.dart';
import 'screens/how_it_works_screen.dart';
import 'screens/merge_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/split_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/ai_chat_widget.dart';
import 'widgets/animated_background.dart';
import 'widgets/shared_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Enable pointer-event resampling for ultra-smooth 144/240/360Hz displays
  GestureBinding.instance.resamplingEnabled = true;
  await windowManager.ensureInitialized();
  // Allow haxball.com (HTTPS) to fetch the replay file from our local HTTP server
  await WebviewController.initializeEnvironment(
    additionalArguments: '--allow-running-insecure-content',
  );

  const options = WindowOptions(
    size: Size(1340, 820),
    minimumSize: Size(1060, 680),
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'HBR Studio',
    windowButtonVisibility: false,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ReplayProvider()),
      ],
      child: const HbrStudioApp(),
    ),
  );
}

// ── App Root ──────────────────────────────────────────────────────────────────
class HbrStudioApp extends StatelessWidget {
  const HbrStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'HBR Studio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      // Globally suppress text underlines inherited from Material defaults
      builder: (context, child) => DefaultTextStyle.merge(
        style: const TextStyle(
          decoration: TextDecoration.none,
          decorationColor: Colors.transparent,
        ),
        child: child!,
      ),
      home: const AppShell(),
    );
  }
}

// ── Navigation Items ──────────────────────────────────────────────────────────
enum NavItem { analyze, merge, split, howItWorks, about, settings }

extension NavItemX on NavItem {
  String label(AppL10n l10n) => switch (this) {
    NavItem.merge => l10n.t('nav.merge'),
    NavItem.split => l10n.t('nav.split'),
    NavItem.analyze => l10n.t('nav.analyze'),
    NavItem.howItWorks => l10n.t('nav.guide'),
    NavItem.about => l10n.t('nav.about'),
    NavItem.settings => l10n.t('nav.settings'),
  };
  IconData get icon => switch (this) {
    NavItem.merge => Icons.merge_type_rounded,
    NavItem.split => Icons.content_cut_rounded,
    NavItem.analyze => Icons.bar_chart_rounded,
    NavItem.howItWorks => Icons.play_circle_outline_rounded,
    NavItem.about => Icons.info_outline_rounded,
    NavItem.settings => Icons.settings_rounded,
  };
  Color get color => switch (this) {
    NavItem.merge => AppTheme.accent,
    NavItem.split => AppTheme.purple,
    NavItem.analyze => const Color(0xFF4A6CF7),
    NavItem.howItWorks => const Color(0xFFFF8C42),
    NavItem.about => const Color(0xFF4A9EFF),
    NavItem.settings => const Color(0xFF7B5EA7),
  };
}

// ── Shell ─────────────────────────────────────────────────────────────────────
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  NavItem _current = NavItem.analyze;

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Stack(
        children: [
          Column(
            children: [
              _TitleBar(
                current: _current,
                onSettings: () => setState(() => _current = NavItem.settings),
              ),
              Expanded(
                child: Row(
                  children: [
                    _Sidebar(
                      current: _current,
                      onSelect: (n) => setState(() => _current = n),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween(
                                begin: const Offset(0.02, 0),
                                end: Offset.zero,
                              ).animate(anim),
                              child: child,
                            ),
                          ),
                          child: KeyedSubtree(
                            key: ValueKey(_current),
                            child: switch (_current) {
                              NavItem.merge => const MergeScreen(),
                              NavItem.split => const SplitScreen(),
                              NavItem.analyze => const AnalyzerScreen(),
                              NavItem.howItWorks => const HowItWorksScreen(),
                              NavItem.about => const AboutScreen(),
                              NavItem.settings => const SettingsScreen(),
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _BottomBar(
                current: _current,
                onSelect: (n) => setState(() => _current = n),
              ),
            ],
          ),
          // ── Floating AI Chat ─────────────────────────────────────────────────
          const Positioned.fill(child: AiChatWidget()),
        ],
      ),
    );
  }
}

// ── Custom Title Bar ──────────────────────────────────────────────────────────
class _TitleBar extends StatelessWidget {
  final NavItem current;
  final VoidCallback onSettings;
  const _TitleBar({required this.current, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context.watch<SettingsProvider>().lang);
    return DragToMoveArea(
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.surfaceOf(context).withOpacity(0.85),
          border: Border(
            bottom: BorderSide(
              color: AppTheme.borderOf(context).withOpacity(0.6),
            ),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: AppTheme.accentGrad,
                borderRadius: BorderRadius.circular(7),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.videocam_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'HBR Studio',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimOf(context),
                letterSpacing: -0.2,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 1, height: 14, color: AppTheme.borderOf(context)),
            const SizedBox(width: 8),
            Text(
              current.label(l10n),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.textHintOf(context),
                decoration: TextDecoration.none,
              ),
            ),
            const Spacer(),
            const GlowDot(),
            const SizedBox(width: 6),
            Text(
              'Ready',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppTheme.textHintOf(context),
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(width: 12),
            _SettingsBtn(onTap: onSettings),
            const SizedBox(width: 8),
            _ThemeToggleBtn(),
            const SizedBox(width: 16),
            _WinBtn(
              color: const Color(0xFFFFBD44),
              icon: Icons.remove_rounded,
              onTap: () => windowManager.minimize(),
            ),
            const SizedBox(width: 6),
            _WinBtn(
              color: const Color(0xFF00CA4E),
              icon: Icons.crop_square_rounded,
              onTap: () async {
                if (await windowManager.isMaximized())
                  windowManager.unmaximize();
                else
                  windowManager.maximize();
              },
            ),
            const SizedBox(width: 6),
            _WinBtn(
              color: const Color(0xFFFF605C),
              icon: Icons.close_rounded,
              onTap: () => windowManager.close(),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

class _SettingsBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _SettingsBtn({required this.onTap});
  @override
  State<_SettingsBtn> createState() => _SettingsBtnState();
}

class _SettingsBtnState extends State<_SettingsBtn> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hov = true),
    onExit: (_) => setState(() => _hov = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: _hov
              ? AppTheme.borderOf(context).withOpacity(0.5)
              : Colors.transparent,
        ),
        child: Icon(
          Icons.settings_rounded,
          size: 16,
          color: _hov
              ? AppTheme.textPrimOf(context)
              : AppTheme.textHintOf(context),
        ),
      ),
    ),
  );
}

class _ThemeToggleBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return GestureDetector(
      onTap: () =>
          settings.setTheme(settings.isDark ? ThemeMode.light : ThemeMode.dark),
      child: Container(
        padding: const EdgeInsets.all(5),
        child: Icon(
          settings.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          size: 16,
          color: AppTheme.textHintOf(context),
        ),
      ),
    );
  }
}

class _WinBtn extends StatefulWidget {
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _WinBtn({required this.color, required this.icon, required this.onTap});
  @override
  State<_WinBtn> createState() => _WinBtnState();
}

class _WinBtnState extends State<_WinBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _hovered ? widget.color : widget.color.withOpacity(0.5),
          boxShadow: _hovered
              ? [BoxShadow(color: widget.color.withOpacity(0.4), blurRadius: 6)]
              : [],
        ),
        child: _hovered
            ? Icon(widget.icon, size: 9, color: Colors.black.withOpacity(0.6))
            : null,
      ),
    ),
  );
}

// ── Sidebar ───────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final NavItem current;
  final ValueChanged<NavItem> onSelect;
  const _Sidebar({required this.current, required this.onSelect});

  static const _main = [
    NavItem.analyze,
    NavItem.merge,
    NavItem.split,
    NavItem.howItWorks,
  ];
  static const _bottom = [NavItem.about];

  @override
  Widget build(BuildContext context) => Container(
    width: 80,
    decoration: BoxDecoration(
      color: AppTheme.bgOf(context),
      border: Border(
        right: BorderSide(color: AppTheme.borderOf(context).withOpacity(0.6)),
      ),
    ),
    child: Column(
      children: [
        const SizedBox(height: 16),
        ..._main.map(
          (item) => _NavBtn(
            item: item,
            isActive: current == item,
            onTap: () => onSelect(item),
          ),
        ),
        const Spacer(),
        ..._bottom.map(
          (item) => _NavBtn(
            item: item,
            isActive: current == item,
            onTap: () => onSelect(item),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            children: [
              Container(
                width: 28,
                height: 1,
                color: AppTheme.borderOf(context),
              ),
              const SizedBox(height: 8),
              Text(
                'v1.0',
                style: GoogleFonts.inter(
                  fontSize: 8,
                  color: AppTheme.textHintOf(context),
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _NavBtn extends StatefulWidget {
  final NavItem item;
  final bool isActive;
  final VoidCallback onTap;
  const _NavBtn({
    required this.item,
    required this.isActive,
    required this.onTap,
  });
  @override
  State<_NavBtn> createState() => _NavBtnState();
}

// ── Particle for analyze button hover effect ───────────────────────────────────
class _NavParticle {
  double x; // relative 0..1 within button width
  double y; // relative 0..1 within button height, starting near center
  double dy; // slow upward drift
  double dx;
  double opacity;
  double radius;
  Color color;

  _NavParticle({
    required this.x,
    required this.y,
    required this.dy,
    required this.dx,
    required this.opacity,
    required this.radius,
    required this.color,
  });
}

class _NavBtnState extends State<_NavBtn> with TickerProviderStateMixin {
  bool _hovered = false;
  final List<_NavParticle> _particles = [];
  late final AnimationController _particleCtrl;
  Timer? _spawnTimer;
  final _rng = math.Random();

  bool get _isAnalyze => widget.item == NavItem.analyze;
  bool get _isAbout => widget.item == NavItem.about;

  static const _purpleBlue = [
    Color(0xFF7B5EA7),
    Color(0xFF4A6CF7),
    Color(0xFF00C9FF),
  ];

  @override
  void initState() {
    super.initState();
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    );
    if (_isAnalyze) {
      _particleCtrl.addListener(_updateParticles);
      _particleCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _particleCtrl.removeListener(_updateParticles);
    _particleCtrl.dispose();
    _spawnTimer?.cancel();
    super.dispose();
  }

  void _updateParticles() {
    if (!mounted) return;
    setState(() {
      // Move + fade
      for (final p in _particles) {
        p.y -= p.dy;
        p.x += p.dx;
        p.opacity -= 0.012;
      }
      _particles.removeWhere((p) => p.opacity <= 0);
    });
  }

  void _onHoverEnter() {
    setState(() => _hovered = true);
    if (!_isAnalyze) return;
    _spawnTimer?.cancel();
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      if (_particles.length >= 8) return;
      setState(() {
        _particles.add(
          _NavParticle(
            x: 0.2 + _rng.nextDouble() * 0.6,
            y: 0.3 + _rng.nextDouble() * 0.4,
            dy: 0.008 + _rng.nextDouble() * 0.006,
            dx: (_rng.nextDouble() - 0.5) * 0.004,
            opacity: 0.9,
            radius: 2.5 + _rng.nextDouble() * 3.0,
            color: _purpleBlue[_rng.nextInt(_purpleBlue.length)],
          ),
        );
      });
    });
  }

  void _onHoverExit() {
    setState(() => _hovered = false);
    _spawnTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    final c = widget.item.color;
    final l10n = AppL10n.of(context.read<SettingsProvider>().lang);
    final iconColor = active
        ? c
        : (_hovered
              ? AppTheme.textSecOf(context)
              : AppTheme.textHintOf(context));

    Widget iconWidget = Icon(
      widget.item.icon,
      size: active ? 22 : 20,
      color: _isAbout ? null : iconColor,
    );

    // About: gradient icon
    if (_isAbout) {
      iconWidget = ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Color(0xFF7B5EA7), Color(0xFF4A6CF7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        blendMode: BlendMode.srcIn,
        child: Icon(
          widget.item.icon,
          size: active ? 22 : 20,
          color: Colors.white,
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => _onHoverEnter(),
      onExit: (_) => _onHoverExit(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.item.label(l10n),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            width: 64,
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: active
                  ? LinearGradient(
                      colors: [c.withOpacity(0.28), c.withOpacity(0.06)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: active
                  ? null
                  : (_hovered
                        ? AppTheme.borderOf(context).withOpacity(0.4)
                        : Colors.transparent),
              border: active ? Border.all(color: c.withOpacity(0.35)) : null,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: c.withOpacity(0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Particle layer (analyze only)
                  if (_isAnalyze && _particles.isNotEmpty)
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (_, constraints) => CustomPaint(
                          painter: _ParticlePainter(
                            particles: _particles,
                            w: constraints.maxWidth,
                            h: constraints.maxHeight,
                          ),
                        ),
                      ),
                    ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      iconWidget,
                      const SizedBox(height: 4),
                      Text(
                        widget.item.label(l10n),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: _isAbout ? const Color(0xFF7B5EA7) : iconColor,
                          decoration: TextDecoration.none,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

// ── Particle painter ─────────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final List<_NavParticle> particles;
  final double w;
  final double h;
  const _ParticlePainter({
    required this.particles,
    required this.w,
    required this.h,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withOpacity(p.opacity.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawCircle(Offset(p.x * w, p.y * h), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}

// ── Bottom Bar ────────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final NavItem current;
  final ValueChanged<NavItem> onSelect;
  const _BottomBar({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<ReplayProvider>();
    final isDark = AppTheme.isDark(context);
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.bgOf(context) : const Color(0xFFF0F2F8),
        border: Border(
          top: BorderSide(color: AppTheme.borderOf(context).withOpacity(0.6)),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const GlowDot(),
          const SizedBox(width: 7),
          Text(
            'HBR Studio',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecOf(context),
              decoration: TextDecoration.none,
            ),
          ),
          if (rp.hasStats) ...[
            Container(
              width: 1,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: AppTheme.borderOf(context),
            ),
            const Icon(
              Icons.videocam_rounded,
              size: 12,
              color: AppTheme.accent,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                rp.stats!.fileName,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.textSecOf(context),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
          const Spacer(),
          for (final item in [NavItem.analyze, NavItem.merge, NavItem.split])
            _BottomBtn(
              item: item,
              active: current == item,
              onTap: () => onSelect(item),
            ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _BottomBtn extends StatefulWidget {
  final NavItem item;
  final bool active;
  final VoidCallback onTap;
  const _BottomBtn({
    required this.item,
    required this.active,
    required this.onTap,
  });
  @override
  State<_BottomBtn> createState() => _BottomBtnState();
}

class _BottomBtnState extends State<_BottomBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context.read<SettingsProvider>().lang);
    final c = widget.item.color;
    final active = widget.active;
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: active
                ? c.withOpacity(0.15)
                : (_h ? Colors.white.withOpacity(0.04) : Colors.transparent),
            border: active ? Border.all(color: c.withOpacity(0.3)) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.item.icon,
                size: 13,
                color: active ? c : AppTheme.textHintOf(context),
              ),
              const SizedBox(width: 5),
              Text(
                widget.item.label(l10n),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: active ? c : AppTheme.textHintOf(context),
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

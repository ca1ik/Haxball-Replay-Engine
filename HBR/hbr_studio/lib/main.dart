// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
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
  await windowManager.ensureInitialized();

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
      home: const AppShell(),
    );
  }
}

// ── Navigation Items ──────────────────────────────────────────────────────────
enum NavItem { merge, split, analyze, howItWorks, about, settings }

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
  NavItem _current = NavItem.merge;

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
    NavItem.merge,
    NavItem.split,
    NavItem.analyze,
    NavItem.howItWorks,
  ];
  static const _bottom = [NavItem.about];

  @override
  Widget build(BuildContext context) => Container(
    width: 76,
    decoration: BoxDecoration(
      color: AppTheme.surfaceOf(context).withOpacity(0.7),
      border: Border(
        right: BorderSide(color: AppTheme.borderOf(context).withOpacity(0.5)),
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

class _NavBtnState extends State<_NavBtn> {
  bool _hovered = false;

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

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.item.label(l10n),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            width: 56,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: active
                  ? c.withOpacity(0.12)
                  : (_hovered
                        ? AppTheme.borderOf(context).withOpacity(0.4)
                        : Colors.transparent),
              border: active ? Border.all(color: c.withOpacity(0.25)) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.item.icon,
                  size: active ? 20 : 18,
                  color: iconColor,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.item.label(l10n),
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: iconColor,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

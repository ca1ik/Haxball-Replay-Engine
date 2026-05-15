import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';

import 'screens/about_screen.dart';
import 'screens/how_it_works_screen.dart';
import 'screens/merge_screen.dart';
import 'screens/split_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/animated_background.dart';
import 'widgets/shared_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: Size(1280, 780),
    minimumSize: Size(1000, 640),
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

  runApp(const HbrStudioApp());
}

class HbrStudioApp extends StatelessWidget {
  const HbrStudioApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'HBR Studio',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.theme,
    home: const AppShell(),
  );
}

// ── Navigation ────────────────────────────────────────────────────────────────
enum NavItem { merge, split, howItWorks, about }

extension NavItemX on NavItem {
  String get label => switch (this) {
    NavItem.merge => 'Merge',
    NavItem.split => 'Split',
    NavItem.howItWorks => 'Guide',
    NavItem.about => 'About',
  };
  IconData get icon => switch (this) {
    NavItem.merge => Icons.merge_type_rounded,
    NavItem.split => Icons.content_cut_rounded,
    NavItem.howItWorks => Icons.play_circle_outline_rounded,
    NavItem.about => Icons.info_outline_rounded,
  };
  Color get color => switch (this) {
    NavItem.merge => AppTheme.accent,
    NavItem.split => AppTheme.purple,
    NavItem.howItWorks => const Color(0xFFFF8C42),
    NavItem.about => const Color(0xFF4A6CF7),
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
      child: Column(
        children: [
          // ── Custom Title Bar ───────────────────────────────────────────────
          _TitleBar(current: _current),
          // ── Body ───────────────────────────────────────────────────────────
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
                          NavItem.howItWorks => const HowItWorksScreen(),
                          NavItem.about => const AboutScreen(),
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
    );
  }
}

// ── Custom Title Bar ──────────────────────────────────────────────────────────
class _TitleBar extends StatelessWidget {
  final NavItem current;
  const _TitleBar({required this.current});

  @override
  Widget build(BuildContext context) {
    return DragToMoveArea(
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          // Seamlessly blends with the app — no chrome border, same color
          color: AppTheme.surface.withOpacity(0.85),
          border: Border(
            bottom: BorderSide(
              color: AppTheme.border.withOpacity(0.6),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            // Logo + name
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
                color: AppTheme.textPrim,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 1, height: 14, color: AppTheme.border),
            const SizedBox(width: 8),
            Text(
              current.label,
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textHint),
            ),
            const Spacer(),
            // Live indicator
            const GlowDot(),
            const SizedBox(width: 6),
            Text(
              'Ready',
              style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textHint),
            ),
            const SizedBox(width: 20),
            // Window controls (macOS-style, positioned on right for Windows)
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
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
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

  @override
  Widget build(BuildContext context) => Container(
    width: 76,
    decoration: BoxDecoration(
      color: AppTheme.surface.withOpacity(0.7),
      border: Border(
        right: BorderSide(color: AppTheme.border.withOpacity(0.5)),
      ),
    ),
    child: Column(
      children: [
        const SizedBox(height: 16),
        ...NavItem.values.map(
          (item) => _NavBtn(
            item: item,
            isActive: current == item,
            onTap: () => onSelect(item),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            children: [
              Container(width: 28, height: 1, color: AppTheme.border),
              const SizedBox(height: 8),
              Text(
                'v1.0',
                style: GoogleFonts.inter(fontSize: 8, color: AppTheme.textHint),
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
    final iconColor = active
        ? c
        : (_hovered ? AppTheme.textSec : AppTheme.textHint);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.item.label,
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
                        ? AppTheme.border.withOpacity(0.4)
                        : Colors.transparent),
              border: active
                  ? Border.all(color: c.withOpacity(0.25), width: 1)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: active ? 36 : 28,
                  height: active ? 36 : 28,
                  child: Icon(
                    widget.item.icon,
                    size: active ? 20 : 18,
                    color: iconColor,
                  ),
                ),
                Text(
                  widget.item.label,
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

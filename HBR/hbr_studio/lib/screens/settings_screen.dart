// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/app_l10n.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppL10n.of(settings.lang);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A6CF7), Color(0xFF7B5EA7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.settings_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('settings.title'),
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimOf(context),
                    decoration: TextDecoration.none,
                  ),
                ),
                Text(
                  'Preferences & customization',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecOf(context),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ],
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
        const SizedBox(height: 28),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _AppearanceCard(
                      settings: settings,
                      l10n: l10n,
                    ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
                    const SizedBox(height: 16),
                    _LanguageCard(
                      settings: settings,
                      l10n: l10n,
                    ).animate().fadeIn(duration: 500.ms, delay: 150.ms),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _PerformanceCard(
                      settings: settings,
                      l10n: l10n,
                    ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                    const SizedBox(height: 16),
                    _AboutMiniCard().animate().fadeIn(
                      duration: 500.ms,
                      delay: 250.ms,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Appearance ─────────────────────────────────────────────────────────────────
class _AppearanceCard extends StatelessWidget {
  final SettingsProvider settings;
  final AppL10n l10n;
  const _AppearanceCard({required this.settings, required this.l10n});

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.palette_rounded,
              size: 15,
              color: AppTheme.textHintOf(context),
            ),
            const SizedBox(width: 8),
            SectionLabel(l10n.t('settings.theme')),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ThemeBtn(
                label: l10n.t('settings.dark'),
                icon: Icons.dark_mode_rounded,
                active: settings.isDark,
                onTap: () => settings.setTheme(ThemeMode.dark),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ThemeBtn(
                label: l10n.t('settings.light'),
                icon: Icons.light_mode_rounded,
                active: !settings.isDark,
                onTap: () => settings.setTheme(ThemeMode.light),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ThemeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ThemeBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: active
            ? AppTheme.accent.withOpacity(0.12)
            : AppTheme.borderOf(context).withOpacity(0.3),
        border: Border.all(
          color: active ? AppTheme.accent.withOpacity(0.4) : Colors.transparent,
          width: active ? 1.5 : 0,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 24,
            color: active ? AppTheme.accent : AppTheme.textHintOf(context),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? AppTheme.accent : AppTheme.textSecOf(context),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Language ───────────────────────────────────────────────────────────────────
class _LanguageCard extends StatelessWidget {
  final SettingsProvider settings;
  final AppL10n l10n;
  const _LanguageCard({required this.settings, required this.l10n});

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.language_rounded,
              size: 15,
              color: AppTheme.textHintOf(context),
            ),
            const SizedBox(width: 8),
            SectionLabel(l10n.t('settings.lang')),
          ],
        ),
        const SizedBox(height: 16),
        _LangOption(
          flag: '🇬🇧',
          lang: 'English',
          active: settings.lang == 'en',
          onTap: () => settings.setLang('en'),
        ),
        const SizedBox(height: 8),
        _LangOption(
          flag: '🇹🇷',
          lang: 'Türkçe',
          active: settings.lang == 'tr',
          onTap: () => settings.setLang('tr'),
        ),
      ],
    ),
  );
}

class _LangOption extends StatelessWidget {
  final String flag, lang;
  final bool active;
  final VoidCallback onTap;
  const _LangOption({
    required this.flag,
    required this.lang,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: active
            ? AppTheme.accent.withOpacity(0.1)
            : AppTheme.borderOf(context).withOpacity(0.25),
        border: Border.all(
          color: active
              ? AppTheme.accent.withOpacity(0.35)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Text(
            lang,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: active ? AppTheme.accent : AppTheme.textPrimOf(context),
              decoration: TextDecoration.none,
            ),
          ),
          const Spacer(),
          if (active)
            Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.accent),
        ],
      ),
    ),
  );
}

// ── Performance ────────────────────────────────────────────────────────────────
class _PerformanceCard extends StatelessWidget {
  final SettingsProvider settings;
  final AppL10n l10n;
  const _PerformanceCard({required this.settings, required this.l10n});

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.speed_rounded,
              size: 15,
              color: AppTheme.textHintOf(context),
            ),
            const SizedBox(width: 8),
            SectionLabel(l10n.t('settings.perf')),
          ],
        ),
        const SizedBox(height: 16),
        _ToggleRow(
          label: l10n.t('settings.fps'),
          sublabel: 'Targets system refresh rate up to 360Hz',
          value: settings.highRefreshRate,
          onChanged: settings.setHighRefreshRate,
          color: AppTheme.accent,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.accent.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: AppTheme.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Flutter renders at vsync rate. For 360Hz monitors, ensure Windows game mode is enabled for maximum smoothness.',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppTheme.textSecOf(context),
                    height: 1.5,
                    decoration: TextDecoration.none,
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

class _ToggleRow extends StatelessWidget {
  final String label, sublabel;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color color;
  const _ToggleRow({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimOf(context),
                decoration: TextDecoration.none,
              ),
            ),
            Text(
              sublabel,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppTheme.textHintOf(context),
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
      Switch(
        value: value,
        onChanged: onChanged,
        activeColor: color,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ],
  );
}

// ── About mini ─────────────────────────────────────────────────────────────────
class _AboutMiniCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 15,
              color: AppTheme.textHintOf(context),
            ),
            const SizedBox(width: 8),
            const SectionLabel('Application'),
          ],
        ),
        const SizedBox(height: 16),
        _AboutRow(label: 'Version', value: '1.0.0 stable'),
        _AboutRow(label: 'Engine', value: 'node-haxball v2.3.0'),
        _AboutRow(label: 'Runtime', value: 'Flutter 3.x (Windows)'),
        _AboutRow(label: 'License', value: 'MIT – Free & Open Source'),
      ],
    ),
  );
}

class _AboutRow extends StatelessWidget {
  final String label, value;
  const _AboutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textSecOf(context),
              decoration: TextDecoration.none,
            ),
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

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: _buildAboutCard(context)),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          _buildTechStack(context),
                          const SizedBox(height: 20),
                          _buildContact(context),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildFeatureGrid(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) => Row(
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
          Icons.info_outline_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
      const SizedBox(width: 14),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About HBR Studio',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimOf(context),
              decoration: TextDecoration.none,
            ),
          ),
          Text(
            'HaxBall replay editor for the community',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecOf(context),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
      const Spacer(),
      StatusBadge(label: 'v1.0.0 stable', color: AppTheme.accent),
    ],
  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);

  Widget _buildAboutCard(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // App Logo
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppTheme.accentGrad,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.videocam_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HBR Studio',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimOf(context),
                    letterSpacing: -0.5,
                    decoration: TextDecoration.none,
                  ),
                ),
                Text(
                  'HaxBall Replay Editor',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textSecOf(context),
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    StatusBadge(label: 'Free', color: AppTheme.accent),
                    const SizedBox(width: 6),
                    StatusBadge(label: 'Open Source', color: AppTheme.purple),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(height: 1, color: AppTheme.borderOf(context)),
        const SizedBox(height: 24),
        Text(
          'What is HBR Studio?',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimOf(context),
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'HBR Studio is a professional desktop application for editing HaxBall replay files (.hbr2). '
          'It allows you to merge multiple recordings into a single seamless replay, and split a long '
          'recording into separate parts — perfect for archiving full matches, creating highlights, '
          'or sharing specific moments with your community.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppTheme.textSecOf(context),
            height: 1.65,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Key Capabilities',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimOf(context),
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 12),
        ..._capabilities.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    c,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecOf(context),
                      height: 1.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.accent.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: AppTheme.accent,
                size: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Powered by node-haxball v2.3.0 — the official HaxBall JavaScript API — ensuring '
                  '100% accurate physics and byte-identical replay serialization.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
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
  ).animate().fadeIn(duration: 500.ms, delay: 100.ms);

  Widget _buildTechStack(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.developer_mode_rounded,
              size: 15,
              color: AppTheme.textHintOf(context),
            ),
            const SizedBox(width: 8),
            const SectionLabel('Tech Stack'),
          ],
        ),
        const SizedBox(height: 16),
        ..._techItems.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: t.$3.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      t.$1,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: t.$3,
                        decoration: TextDecoration.none,
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
                        t.$2,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimOf(context),
                          decoration: TextDecoration.none,
                        ),
                      ),
                      Text(
                        t.$4,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppTheme.textHintOf(context),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ).animate().fadeIn(duration: 500.ms, delay: 150.ms);

  static const _techItems = [
    ('FL', 'Flutter 3.x', AppTheme.accent, 'Cross-platform desktop UI'),
    (
      'JS',
      'Node.js + node-haxball',
      AppTheme.warning,
      'Replay parsing & writing',
    ),
    ('Dart', 'Dart 3', Color(0xFF4A6CF7), 'App logic & state'),
  ];

  Widget _buildContact(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.alternate_email_rounded,
              size: 15,
              color: AppTheme.textHintOf(context),
            ),
            const SizedBox(width: 8),
            const SectionLabel('Contact & Links'),
          ],
        ),
        const SizedBox(height: 16),
        ..._contactItems.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => launchUrl(Uri.parse(c.$3)),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceOf(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderOf(context)),
                ),
                child: Row(
                  children: [
                    Icon(c.$1, size: 16, color: c.$4),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.$2,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimOf(context),
                              decoration: TextDecoration.none,
                            ),
                          ),
                          Text(
                            c.$3,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppTheme.textHintOf(context),
                              decoration: TextDecoration.none,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 12,
                      color: AppTheme.textHintOf(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.purple.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.purple.withOpacity(0.2)),
          ),
          child: Text(
            'Found a bug or have a feature request? Open an issue on GitHub or reach out on Discord.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textSecOf(context),
              height: 1.5,
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  ).animate().fadeIn(duration: 500.ms, delay: 200.ms);

  static const _contactItems = [
    (
      Icons.code_rounded,
      'GitHub',
      'https://github.com/codemations/hbr-studio',
      Color(0xFFE8EAF2),
    ),
    (
      Icons.discord_rounded,
      'Discord Community',
      'https://discord.gg/haxball',
      Color(0xFF7289DA),
    ),
    (
      Icons.mail_outline_rounded,
      'Email',
      'hello@codemations.dev',
      AppTheme.accent,
    ),
    (
      Icons.sports_soccer_rounded,
      'HaxBall Forum',
      'https://www.haxball.com',
      Color(0xFFFF8C42),
    ),
  ];

  Widget _buildFeatureGrid() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionLabel('Features'),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.8,
        children: _features
            .asMap()
            .entries
            .map(
              (e) => _FeatureCard(
                icon: e.value.$1,
                title: e.value.$2,
                description: e.value.$3,
                color: e.value.$4,
                delay: e.key * 60,
              ),
            )
            .toList(),
      ),
    ],
  ).animate().fadeIn(duration: 500.ms, delay: 300.ms);

  static const _features = [
    (
      Icons.merge_type_rounded,
      'N-File Merge',
      'Combine 2+ replays in any order',
      AppTheme.accent,
    ),
    (
      Icons.content_cut_rounded,
      'Precision Split',
      'Cut at any MM:SS with a slider',
      AppTheme.purple,
    ),
    (
      Icons.drag_handle_rounded,
      'Drag & Drop',
      'Drop .hbr2 files directly into the app',
      Color(0xFF4A6CF7),
    ),
    (
      Icons.sync_alt_rounded,
      'Physics Accurate',
      'Exact spawn order preserved — no divergence',
      Color(0xFF00C9FF),
    ),
    (
      Icons.bar_chart_rounded,
      'File Preview',
      'Instant probe: duration, frames, goals',
      Color(0xFFFF8C42),
    ),
    (
      Icons.animation_rounded,
      'Visual Animations',
      'Animated merge/split flow diagrams',
      Color(0xFFFF4D6A),
    ),
    (
      Icons.folder_open_rounded,
      'Smart Output',
      'Auto-save to Downloads or custom path',
      AppTheme.success,
    ),
    (
      Icons.terminal_rounded,
      'Live Log',
      'Real-time progress output per operation',
      AppTheme.textSec,
    ),
    (
      Icons.dark_mode_rounded,
      'Dark Native UI',
      'Custom title bar, aurora background',
      Color(0xFF7B5EA7),
    ),
  ];
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final int delay;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) =>
      Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.surfaceOf(context),
              border: Border.all(color: AppTheme.borderOf(context)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
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
                          color: AppTheme.textPrimOf(context),
                          decoration: TextDecoration.none,
                        ),
                      ),
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppTheme.textHintOf(context),
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
          .animate(delay: Duration(milliseconds: delay))
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.1);
}

const _capabilities = [
  'Merge 2 or more .hbr2 replay files into one continuous match replay, maintaining correct physics through precise spawn-order normalization.',
  'Split any replay at an arbitrary time point using an interactive slider or MM:SS input field, creating two independent output files.',
  'Drag & drop support: load files by dragging them directly from Windows Explorer into the app.',
  'Per-file info probe: instantly see total duration, frame count and goal count for any .hbr2 file.',
  'Reorder files in merge queue with drag handles before processing.',
  'Animated "How It Works" diagrams with a custom-painted flow visualization.',
];

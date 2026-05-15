// lib/screens/analyzer_screen.dart
// Full match statistics viewer for HBR2 replay files

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/app_l10n.dart';
import '../models/match_stats.dart';
import '../providers/replay_provider.dart';
import '../providers/settings_provider.dart';
import '../services/analyzer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class AnalyzerScreen extends StatefulWidget {
  const AnalyzerScreen({super.key});
  @override
  State<AnalyzerScreen> createState() => _AnalyzerScreenState();
}

class _AnalyzerScreenState extends State<AnalyzerScreen> {
  bool _dragging = false;
  String? _error;

  AppL10n get _l10n => AppL10n.of(context.read<SettingsProvider>().lang);

  Future<void> _load(String path) async {
    if (!path.toLowerCase().endsWith('.hbr2')) return;
    final rp = context.read<ReplayProvider>();
    rp.setAnalyzing(true);
    setState(() => _error = null);
    try {
      final stats = await AnalyzerService.analyze(path);
      rp.setStats(path, stats);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
      rp.setAnalyzing(false);
    }
  }

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['hbr2'],
    );
    if (r?.files.first.path != null) _load(r!.files.first.path!);
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<ReplayProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(rp),
        const SizedBox(height: 20),
        Expanded(
          child: rp.hasStats && !rp.analyzing
              ? _StatsView(stats: rp.stats!)
              : _buildDropZone(rp),
        ),
      ],
    );
  }

  Widget _buildHeader(ReplayProvider rp) => Row(
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
          Icons.bar_chart_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
      const SizedBox(width: 14),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _l10n.t('analyze.title'),
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimOf(context),
              decoration: TextDecoration.none,
            ),
          ),
          Text(
            _l10n.t('analyze.subtitle'),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecOf(context),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
      const Spacer(),
      if (rp.hasStats) ...[
        TextButton.icon(
          onPressed: () {
            context.read<ReplayProvider>().clear();
          },
          icon: const Icon(Icons.close_rounded, size: 14),
          label: Text(
            'Clear',
            style: GoogleFonts.inter(
              fontSize: 12,
              decoration: TextDecoration.none,
            ),
          ),
          style: TextButton.styleFrom(foregroundColor: AppTheme.textHint),
        ),
        const SizedBox(width: 8),
        GradientButton(
          label: 'Load Another',
          icon: Icons.folder_open_rounded,
          onPressed: _pick,
        ),
      ],
    ],
  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);

  Widget _buildDropZone(ReplayProvider rp) => Center(
    child: DropTarget(
      onDragDone: (d) {
        if (d.files.isNotEmpty) _load(d.files.first.path);
      },
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      child: GestureDetector(
        onTap: _pick,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 480,
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _dragging
                ? const Color(0xFF4A6CF7).withOpacity(0.06)
                : AppTheme.surfaceOf(context),
            border: Border.all(
              color: _dragging
                  ? const Color(0xFF4A6CF7)
                  : AppTheme.borderOf(context),
              width: _dragging ? 2 : 1,
            ),
          ),
          child: rp.analyzing
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        color: Color(0xFF4A6CF7),
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Analyzing replay...',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textSecOf(context),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A6CF7), Color(0xFF7B5EA7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _l10n.t('analyze.drop'),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimOf(context),
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scores · Goals · Assists · Possession · Player stats',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textHintOf(context),
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.danger,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
  );
}

// ── Stats View ─────────────────────────────────────────────────────────────────
class _StatsView extends StatelessWidget {
  final MatchStats stats;
  const _StatsView({required this.stats});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _ScoreCard(stats: stats)),
              const SizedBox(width: 16),
              Expanded(child: _PossessionCard(stats: stats)),
              const SizedBox(width: 16),
              Expanded(child: _InfoCard(stats: stats)),
            ],
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 20),
          _GoalTimeline(
            stats: stats,
          ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
          const SizedBox(height: 20),
          _PlayerTable(
            stats: stats,
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
        ],
      ),
    );
  }
}

// ── Score Card ─────────────────────────────────────────────────────────────────
class _ScoreCard extends StatelessWidget {
  final MatchStats stats;
  const _ScoreCard({required this.stats});

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      children: [
        const SectionLabel('Score'),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _TeamScoreBlock(
              name: context.read<SettingsProvider>().lang == 'tr'
                  ? 'Kırmızı'
                  : 'Red',
              score: stats.redTeam.score,
              color: const Color(0xFFFF4D6A),
              players: stats.redTeam.players,
            ),
            Text(
              '–',
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                color: AppTheme.textHintOf(context),
                decoration: TextDecoration.none,
              ),
            ),
            _TeamScoreBlock(
              name: context.read<SettingsProvider>().lang == 'tr'
                  ? 'Mavi'
                  : 'Blue',
              score: stats.blueTeam.score,
              color: const Color(0xFF4A9EFF),
              players: stats.blueTeam.players,
            ),
          ],
        ),
      ],
    ),
  );
}

class _TeamScoreBlock extends StatelessWidget {
  final String name;
  final int score;
  final Color color;
  final List<String> players;
  const _TeamScoreBlock({
    required this.name,
    required this.score,
    required this.color,
    required this.players,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        name,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 1,
          decoration: TextDecoration.none,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        '$score',
        style: GoogleFonts.inter(
          fontSize: 52,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
      const SizedBox(height: 8),
      ...players.map(
        (p) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            p.trim(),
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppTheme.textSecOf(context),
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    ],
  );
}

// ── Possession Card ────────────────────────────────────────────────────────────
class _PossessionCard extends StatelessWidget {
  final MatchStats stats;
  const _PossessionCard({required this.stats});

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      children: [
        const SectionLabel('Possession'),
        const SizedBox(height: 16),
        SizedBox(
          width: 80,
          height: 80,
          child: _PossessionDonut(
            red: stats.possession.red,
            blue: stats.possession.blue,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PossLegend(
              color: const Color(0xFFFF4D6A),
              label: '${stats.possession.red.toStringAsFixed(0)}% Red',
            ),
            const SizedBox(width: 12),
            _PossLegend(
              color: const Color(0xFF4A9EFF),
              label: '${stats.possession.blue.toStringAsFixed(0)}% Blue',
            ),
          ],
        ),
      ],
    ),
  );
}

class _PossLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _PossLegend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          color: AppTheme.textSecOf(context),
          decoration: TextDecoration.none,
        ),
      ),
    ],
  );
}

class _PossessionDonut extends StatelessWidget {
  final double red, blue;
  const _PossessionDonut({required this.red, required this.blue});
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DonutPainter(red: red, blue: blue),
  );
}

class _DonutPainter extends CustomPainter {
  final double red, blue;
  const _DonutPainter({required this.red, required this.blue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const sw = 12.0;
    final total = red + blue;
    final redAngle = (red / total) * 2 * 3.14159;

    final bgPaint = Paint()
      ..color = const Color(0xFF4A9EFF).withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw;
    canvas.drawCircle(center, radius, bgPaint);

    final redPaint = Paint()
      ..color = const Color(0xFFFF4D6A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      redAngle,
      false,
      redPaint,
    );

    final bluePaint = Paint()
      ..color = const Color(0xFF4A9EFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2 + redAngle,
      2 * 3.14159 - redAngle,
      false,
      bluePaint,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.red != red || old.blue != blue;
}

// ── Info Card ──────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final MatchStats stats;
  const _InfoCard({required this.stats});

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Match Info'),
        const SizedBox(height: 14),
        _InfoRow(
          icon: Icons.timer_outlined,
          label: 'Duration',
          value: stats.duration,
        ),
        _InfoRow(
          icon: Icons.sports_soccer_rounded,
          label: 'Total Goals',
          value: '${stats.goalCount}',
        ),
        _InfoRow(
          icon: Icons.people_outline_rounded,
          label: 'Players',
          value: '${stats.playerStats.length}',
        ),
        _InfoRow(
          icon: Icons.event_note_rounded,
          label: 'Events',
          value: _fmt(stats.events),
        ),
        _InfoRow(
          icon: Icons.file_present_rounded,
          label: 'File',
          value: stats.fileName,
          small: true,
        ),
      ],
    ),
  );

  String _fmt(int n) => n > 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool small;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textHintOf(context)),
        const SizedBox(width: 8),
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
            fontSize: small ? 10 : 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimOf(context),
            decoration: TextDecoration.none,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

// ── Goal Timeline ──────────────────────────────────────────────────────────────
class _GoalTimeline extends StatelessWidget {
  final MatchStats stats;
  const _GoalTimeline({required this.stats});

  @override
  Widget build(BuildContext context) {
    final lang = context.read<SettingsProvider>().lang;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SectionLabel('Match Timeline'),
              const SizedBox(width: 12),
              StatusBadge(
                label: '${stats.goals.length} goals',
                color: AppTheme.accent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Visual bar
          _buildBar(context),
          const SizedBox(height: 20),
          // Goal list
          ...stats.goals.asMap().entries.map(
            (e) => _GoalRow(goal: e.value, index: e.key, lang: lang)
                .animate(delay: Duration(milliseconds: e.key * 60))
                .fadeIn(duration: 250.ms)
                .slideX(begin: -0.05),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(BuildContext context) {
    final total = stats.totalFrames.toDouble();
    return Container(
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: AppTheme.borderOf(context),
      ),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final w = constraints.maxWidth;
          return Stack(
            children: [
              // Gradient fill
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.danger.withOpacity(0.15),
                        const Color(0xFF4A9EFF).withOpacity(0.15),
                      ],
                    ),
                  ),
                ),
              ),
              // Goal markers
              ...stats.goals.map((g) {
                final x = (g.frameNo / total * w).clamp(0.0, w - 2);
                return Positioned(
                  left: x - 1,
                  top: 0,
                  bottom: 0,
                  child: Tooltip(
                    message: '${g.scorer} (${g.time})',
                    child: Container(
                      width: 2.5,
                      decoration: BoxDecoration(
                        color: g.scoringTeam == 1
                            ? AppTheme.danger
                            : const Color(0xFF4A9EFF),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                );
              }),
              // Time labels
              Positioned(
                left: 6,
                bottom: 4,
                child: Text(
                  '0:00',
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    color: AppTheme.textHintOf(context),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              Positioned(
                right: 6,
                bottom: 4,
                child: Text(
                  stats.duration,
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    color: AppTheme.textHintOf(context),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  final GoalEvent goal;
  final int index;
  final String lang;
  const _GoalRow({required this.goal, required this.index, required this.lang});

  @override
  Widget build(BuildContext context) {
    final isRed = goal.scoringTeam == 1;
    final teamColor = isRed ? const Color(0xFFFF4D6A) : const Color(0xFF4A9EFF);
    final scoreStr = isRed
        ? '${goal.redScore}–${goal.blueScore}'
        : '${goal.redScore}–${goal.blueScore}';

    final rowText =
        '${goal.scorer}'
        '${goal.assist != null ? "  ·  Assist: ${goal.assist}" : ""}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          Clipboard.setData(
            ClipboardData(
              text:
                  '⚽ ${goal.scorer}${goal.assist != null ? " (${lang == 'tr' ? 'Asist' : 'Assist'}: ${goal.assist})" : ""} ${goal.time}',
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Copied!',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
              ),
              duration: const Duration(seconds: 1),
              backgroundColor: AppTheme.accent.withOpacity(0.8),
            ),
          );
        },
        child: Row(
          children: [
            // Team dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: teamColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: teamColor.withOpacity(0.4), blurRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Score badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: teamColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: teamColor.withOpacity(0.3)),
              ),
              child: Text(
                scoreStr,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: teamColor,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Soccer ball icon
            const Text('⚽', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                rowText,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textPrimOf(context),
                  decoration: TextDecoration.none,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Time
            Text(
              goal.time,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.textHintOf(context),
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.copy_rounded,
              size: 11,
              color: AppTheme.textHintOf(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Player Table ───────────────────────────────────────────────────────────────
class _PlayerTable extends StatefulWidget {
  final MatchStats stats;
  const _PlayerTable({required this.stats});
  @override
  State<_PlayerTable> createState() => _PlayerTableState();
}

class _PlayerTableState extends State<_PlayerTable> {
  String _sortBy = 'goals';
  bool _ascending = false;

  List<PlayerStat> get _sorted {
    final list = List<PlayerStat>.from(widget.stats.playerStats);
    list.sort((a, b) {
      int r;
      switch (_sortBy) {
        case 'goals':
          r = a.goals.compareTo(b.goals);
          break;
        case 'assists':
          r = a.assists.compareTo(b.assists);
          break;
        case 'kicks':
          r = a.kicks.compareTo(b.kicks);
          break;
        default:
          r = a.name.compareTo(b.name);
      }
      return _ascending ? r : -r;
    });
    return list;
  }

  void _sort(String col) {
    setState(() {
      if (_sortBy == col)
        _ascending = !_ascending;
      else {
        _sortBy = col;
        _ascending = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Player Statistics'),
        const SizedBox(height: 14),
        // Header
        _TableHeader(sortBy: _sortBy, ascending: _ascending, onSort: _sort),
        const SizedBox(height: 8),
        // Rows
        ..._sorted.asMap().entries.map(
          (e) => _PlayerRow(player: e.value, index: e.key)
              .animate(delay: Duration(milliseconds: e.key * 50))
              .fadeIn(duration: 200.ms),
        ),
      ],
    ),
  );
}

class _TableHeader extends StatelessWidget {
  final String sortBy;
  final bool ascending;
  final ValueChanged<String> onSort;
  const _TableHeader({
    required this.sortBy,
    required this.ascending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(flex: 4, child: Text('Player', style: _hStyle(context))),
      _SortCol(
        label: 'G',
        col: 'goals',
        sortBy: sortBy,
        ascending: ascending,
        onSort: onSort,
      ),
      _SortCol(
        label: 'A',
        col: 'assists',
        sortBy: sortBy,
        ascending: ascending,
        onSort: onSort,
      ),
      _SortCol(
        label: 'K',
        col: 'kicks',
        sortBy: sortBy,
        ascending: ascending,
        onSort: onSort,
      ),
      Expanded(
        flex: 2,
        child: Text(
          'Team',
          style: _hStyle(context),
          textAlign: TextAlign.right,
        ),
      ),
    ],
  );

  TextStyle _hStyle(BuildContext context) => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppTheme.textHintOf(context),
    decoration: TextDecoration.none,
  );
}

class _SortCol extends StatelessWidget {
  final String label, col, sortBy;
  final bool ascending;
  final ValueChanged<String> onSort;
  const _SortCol({
    required this.label,
    required this.col,
    required this.sortBy,
    required this.ascending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    flex: 2,
    child: GestureDetector(
      onTap: () => onSort(col),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: sortBy == col
                  ? AppTheme.accent
                  : AppTheme.textHintOf(context),
              decoration: TextDecoration.none,
            ),
          ),
          if (sortBy == col)
            Icon(
              ascending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 9,
              color: AppTheme.accent,
            ),
        ],
      ),
    ),
  );
}

class _PlayerRow extends StatelessWidget {
  final PlayerStat player;
  final int index;
  const _PlayerRow({required this.player, required this.index});

  @override
  Widget build(BuildContext context) {
    final isRed = player.team == 1;
    final tc = isRed ? const Color(0xFFFF4D6A) : const Color(0xFF4A9EFF);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppTheme.borderOf(context).withOpacity(0.3),
        border: player.goals > 0
            ? Border.all(color: tc.withOpacity(0.2))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: tc, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(
              player.name.trim(),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimOf(context),
                decoration: TextDecoration.none,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Goals
          Expanded(
            flex: 2,
            child: _Stat(
              val: player.goals,
              highlight: player.goals > 0,
              color: const Color(0xFF00D4AA),
            ),
          ),
          // Assists
          Expanded(
            flex: 2,
            child: _Stat(
              val: player.assists,
              highlight: player.assists > 0,
              color: const Color(0xFFFFB347),
            ),
          ),
          // Kicks
          Expanded(
            flex: 2,
            child: _Stat(val: player.kicks, color: AppTheme.textSecOf(context)),
          ),
          // Team
          Expanded(
            flex: 2,
            child: Text(
              isRed ? 'Red' : 'Blue',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: tc,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final int val;
  final bool highlight;
  final Color color;
  const _Stat({required this.val, required this.color, this.highlight = false});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      '$val',
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
        color: highlight ? color : AppTheme.textSecOf(context),
        decoration: TextDecoration.none,
      ),
    ),
  );
}

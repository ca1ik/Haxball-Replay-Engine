import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/node_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  String? _inputPath;
  Map<String, dynamic>? _fileInfo;
  bool _probing = false;
  bool _dragging = false;
  bool _running = false;

  // Split time controllers
  final _minCtrl = TextEditingController(text: '45');
  final _secCtrl = TextEditingController(text: '00');

  String? _out1Path;
  String? _out2Path;
  final List<String> _logLines = [];
  double _progress = 0;
  String? _resultMessage;
  bool _success = false;

  @override
  void dispose() {
    _minCtrl.dispose();
    _secCtrl.dispose();
    super.dispose();
  }

  int get _splitFrame {
    final m = int.tryParse(_minCtrl.text) ?? 0;
    final s = int.tryParse(_secCtrl.text) ?? 0;
    return durationToFrame(m, s);
  }

  int get _totalFrames => _fileInfo?['totalFrames'] as int? ?? 0;

  double get _sliderRatio =>
      _totalFrames > 0 ? (_splitFrame / _totalFrames).clamp(0.0, 1.0) : 0.0;

  // ── File loading ──────────────────────────────────────────────────────────
  void _loadFile(String path) async {
    if (!path.toLowerCase().endsWith('.hbr2')) return;
    setState(() {
      _inputPath = path;
      _fileInfo = null;
      _probing = true;
      _logLines.clear();
      _resultMessage = null;
    });
    final info = await NodeService.probeFile(path);
    if (mounted)
      setState(() {
        _fileInfo = info;
        _probing = false;
      });
  }

  Future<void> _pickInput() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['hbr2'],
    );
    if (result?.files.first.path != null) _loadFile(result!.files.first.path!);
  }

  Future<void> _pickOutput1() async => _pickOutputFile(1);
  Future<void> _pickOutput2() async => _pickOutputFile(2);

  Future<void> _pickOutputFile(int part) async {
    final dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
    final base = _inputPath != null
        ? p.basenameWithoutExtension(_inputPath!)
        : 'replay';
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Part $part as...',
      fileName: '${base}_part$part.hbr2',
      initialDirectory: dir.path,
      type: FileType.custom,
      allowedExtensions: ['hbr2'],
    );
    if (result != null) {
      setState(() => part == 1 ? _out1Path = result : _out2Path = result);
    }
  }

  Future<void> _runSplit() async {
    if (_inputPath == null || _totalFrames == 0 || _running) return;
    final sf = _splitFrame;
    if (sf <= 0 || sf >= _totalFrames) return;

    final dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
    final base = p.basenameWithoutExtension(_inputPath!);
    final out1 = _out1Path ?? p.join(dir.path, '${base}_part1.hbr2');
    final out2 = _out2Path ?? p.join(dir.path, '${base}_part2.hbr2');

    setState(() {
      _running = true;
      _logLines.clear();
      _progress = 0;
      _resultMessage = null;
      _success = false;
    });

    int step = 0;
    const totalSteps = 4; // read, build1, build2, write

    await for (final evt in NodeService.split(
      inputPath: _inputPath!,
      output1Path: out1,
      output2Path: out2,
      splitFrame: sf,
    )) {
      if (!mounted) break;
      setState(() {
        final type = evt['type'] as String? ?? '';
        switch (type) {
          case 'progress':
            step++;
            _progress = step / totalSteps;
            _logLines.add(_progressLabel(evt));
            break;
          case 'info':
            _logLines.add(
              '  Total: ${evt['totalFrames']} frames · ${evt['goals']} goals · split at frame $sf',
            );
            break;
          case 'part1_done':
            _out1Path = evt['output'] as String?;
            final size = ((evt['bytes'] as int? ?? 0) / 1024).toStringAsFixed(
              1,
            );
            _logLines.add(
              '  Part 1: ${evt['frames']} frames · ${evt['goals']} goals · ${size} KB',
            );
            break;
          case 'part2_done':
            _out2Path = evt['output'] as String?;
            final size = ((evt['bytes'] as int? ?? 0) / 1024).toStringAsFixed(
              1,
            );
            _logLines.add(
              '  Part 2: ${evt['frames']} frames · ${evt['goals']} goals · ${size} KB',
            );
            break;
          case 'done':
            _progress = 1.0;
            _success = true;
            _resultMessage =
                'Split at ${_minCtrl.text}:${_secCtrl.text.padLeft(2, '0')} → 2 files';
            _logLines.add('Done!');
            break;
          case 'error':
            _success = false;
            _resultMessage = evt['message'] as String? ?? 'Unknown error';
            _logLines.add('Error: $_resultMessage');
            break;
        }
      });
    }

    if (mounted) setState(() => _running = false);
  }

  String _progressLabel(Map<String, dynamic> evt) {
    final step = evt['step'] as String? ?? '';
    switch (step) {
      case 'reading':
        return 'Reading ${evt['name']}...';
      case 'building_part1':
        return 'Building Part 1...';
      case 'building_part2':
        return 'Building Part 2...';
      case 'writing':
        return 'Writing ${p.basename(evt['output'] as String? ?? '')}...';
      default:
        return step;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildLeftPanel()),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: _buildRightPanel()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: AppTheme.purpleGrad,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.content_cut_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
      const SizedBox(width: 14),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Split Replay',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimOf(context),
              decoration: TextDecoration.none,
            ),
          ),
          Text(
            'Cut a replay at any point in time into two separate files',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecOf(context),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
      const Spacer(),
      if (_fileInfo != null)
        StatusBadge(
          label: framesToDuration(_totalFrames),
          color: AppTheme.purple,
        ).animate().fadeIn(duration: 300.ms),
    ],
  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);

  Widget _buildLeftPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildDropZone(),
      if (_fileInfo != null) ...[
        const SizedBox(height: 20),
        _buildFileInfo(),
        const SizedBox(height: 20),
        _buildSplitControls(),
        const SizedBox(height: 20),
        _buildOutputSelectors(),
        const SizedBox(height: 16),
        _buildSplitButton(),
      ],
    ],
  );

  Widget _buildDropZone() => DropTarget(
    onDragDone: (detail) {
      if (detail.files.isNotEmpty) _loadFile(detail.files.first.path);
    },
    onDragEntered: (_) => setState(() => _dragging = true),
    onDragExited: (_) => setState(() => _dragging = false),
    child: GestureDetector(
      onTap: _running ? null : _pickInput,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _dragging
              ? AppTheme.purple.withOpacity(0.06)
              : (_inputPath != null
                    ? AppTheme.surfaceOf(context)
                    : AppTheme.surfaceOf(context)),
          border: Border.all(
            color: _dragging
                ? AppTheme.purple
                : (_inputPath != null
                      ? AppTheme.purple.withOpacity(0.4)
                      : AppTheme.borderOf(context)),
            width: _dragging ? 2 : (_inputPath != null ? 1.5 : 1),
          ),
        ),
        child: Center(
          child: _inputPath != null
              ? _probing
                    ? const CircularProgressIndicator(
                        color: AppTheme.purple,
                        strokeWidth: 2,
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.purple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.movie_rounded,
                              color: AppTheme.purple,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.basename(_inputPath!),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimOf(context),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              Text(
                                'Click to change file',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppTheme.textHintOf(context),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _dragging
                          ? Icons.file_download_rounded
                          : Icons.add_circle_outline_rounded,
                      size: 32,
                      color: _dragging ? AppTheme.purple : AppTheme.textHint,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _dragging ? 'Drop file here' : 'Drag & drop a .hbr2 file',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _dragging
                            ? AppTheme.purple
                            : AppTheme.textSecOf(context),
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'or click to browse',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textHintOf(context),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ),
  ).animate().fadeIn(duration: 500.ms, delay: 100.ms);

  Widget _buildFileInfo() {
    final info = _fileInfo!;
    return Row(
      children: [
        InfoChip(
          icon: Icons.timer_outlined,
          label: 'Duration',
          value: framesToDuration(info['totalFrames'] as int),
        ),
        const SizedBox(width: 8),
        InfoChip(
          icon: Icons.sports_soccer_rounded,
          label: 'Goals',
          value: '${info['goals']}',
        ),
        const SizedBox(width: 8),
        InfoChip(
          icon: Icons.event_note_rounded,
          label: 'Frames',
          value: '${info['totalFrames']}',
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildSplitControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionLabel('Split at time'),
      const SizedBox(height: 12),
      Row(
        children: [
          _timeField(_minCtrl, 'min', 0, 999),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              ':',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSec,
              ),
            ),
          ),
          _timeField(_secCtrl, 'sec', 0, 59),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.purple.withOpacity(0.3)),
            ),
            child: Text(
              'Frame ${_splitFrame}',
              style: GoogleFonts.robotoMono(
                fontSize: 12,
                color: AppTheme.purple,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (_totalFrames > 0) _buildTimeline(),
    ],
  ).animate().fadeIn(duration: 300.ms, delay: 100.ms);

  Widget _timeField(
    TextEditingController ctrl,
    String label,
    int min,
    int max,
  ) => SizedBox(
    width: 72,
    child: TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimOf(context),
        decoration: TextDecoration.none,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          fontSize: 10,
          color: AppTheme.textHintOf(context),
          decoration: TextDecoration.none,
        ),
        filled: true,
        fillColor: AppTheme.surfaceOf(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.borderOf(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.borderOf(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.purple, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      ),
      onChanged: (_) => setState(() {}),
    ),
  );

  Widget _buildTimeline() {
    final ratio = _sliderRatio;
    final splitMin = _minCtrl.text.padLeft(2, '0');
    final splitSec = _secCtrl.text.padLeft(2, '0');
    final totalDur = framesToDuration(_totalFrames);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 6,
                  thumbColor: AppTheme.purple,
                  activeTrackColor: AppTheme.purple,
                  inactiveTrackColor: AppTheme.border,
                  overlayColor: AppTheme.purple.withOpacity(0.15),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                ),
                child: Slider(
                  value: ratio,
                  onChanged: (v) {
                    final frame = (v * _totalFrames).round();
                    final totalSec = (frame / 60).round();
                    setState(() {
                      _minCtrl.text = (totalSec ~/ 60).toString();
                      _secCtrl.text = (totalSec % 60).toString().padLeft(
                        2,
                        '0',
                      );
                    });
                  },
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Text(
              '00:00',
              style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textHint),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.purple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$splitMin:$splitSec',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.purple,
                ),
              ),
            ),
            const Spacer(),
            Text(
              totalDur,
              style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textHint),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                  ),
                  border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                ),
                child: Center(
                  child: Text(
                    'Part 1  ·  00:00 → $splitMin:$splitSec',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.purple.withOpacity(0.08),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(6),
                    bottomRight: Radius.circular(6),
                  ),
                  border: Border.all(color: AppTheme.purple.withOpacity(0.2)),
                ),
                child: Center(
                  child: Text(
                    'Part 2  ·  $splitMin:$splitSec → $totalDur',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppTheme.purple,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOutputSelectors() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionLabel('Output Files'),
      const SizedBox(height: 8),
      _outputRow('Part 1', _out1Path, AppTheme.accent, _pickOutput1),
      const SizedBox(height: 8),
      _outputRow('Part 2', _out2Path, AppTheme.purple, _pickOutput2),
    ],
  ).animate().fadeIn(duration: 300.ms, delay: 150.ms);

  Widget _outputRow(
    String label,
    String? path,
    Color color,
    VoidCallback onTap,
  ) => GestureDetector(
    onTap: _running ? null : onTap,
    child: Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: path != null ? color.withOpacity(0.3) : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            '$label  ',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Expanded(
            child: Text(
              path != null ? p.basename(path) : 'Auto-generated',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: path != null ? AppTheme.textPrim : AppTheme.textHint,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'Browse',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppTheme.accent,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildSplitButton() => Row(
    children: [
      Expanded(
        child: GradientButton(
          label: _running ? 'Splitting...' : 'Split Replay',
          icon: Icons.content_cut_rounded,
          onPressed:
              (_inputPath != null &&
                  _totalFrames > 0 &&
                  _splitFrame > 0 &&
                  _splitFrame < _totalFrames &&
                  !_running)
              ? _runSplit
              : null,
          loading: _running,
          secondary: true,
        ),
      ),
    ],
  );

  Widget _buildRightPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionLabel('Output Log'),
      const SizedBox(height: 8),
      GlassCard(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 260,
          child: _logLines.isEmpty
              ? _buildIdleInfo()
              : ListView.builder(
                  itemCount: _logLines.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      _logLines[i],
                      style: GoogleFonts.robotoMono(
                        fontSize: 11,
                        color: AppTheme.textSec,
                      ),
                    ),
                  ),
                ),
        ),
      ),
      const SizedBox(height: 16),
      if (_running || _progress > 0) _buildProgressBar(),
      if (_resultMessage != null) ...[
        const SizedBox(height: 12),
        _buildResultBanner(),
      ],
    ],
  ).animate().fadeIn(duration: 500.ms, delay: 200.ms);

  Widget _buildIdleInfo() {
    final items = [
      (
        Icons.content_cut_rounded,
        AppTheme.purple,
        'How Split Works',
        'Events with frameNo ≤ splitFrame go to Part 1; the rest to Part 2. Part 2 frame numbers are re-offset to start at 0.',
      ),
      (
        Icons.sports_soccer_rounded,
        AppTheme.accent,
        'Preserve Room State',
        'Both parts share the original room state — stadium, teams, player names — so each is a valid standalone .hbr2 file.',
      ),
      (
        Icons.timer_rounded,
        const Color(0xFF4A6CF7),
        'Frame-Accurate Timing',
        'haxball.com records at ~60 fps. Enter MM:SS and the app converts to exact frame number (time × 60), then writes the boundary.',
      ),
      (
        Icons.merge_type_rounded,
        const Color(0xFFFF8C42),
        'Re-Merge Anytime',
        'Split parts are fully compatible with the Merge tool. Reorder or re-combine them to create highlight reels or match reviews.',
      ),
    ];
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final item = items[i];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: item.$2.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.$1, size: 14, color: item.$2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.$3,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimOf(context),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.$4,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppTheme.textSecOf(context),
                      height: 1.45,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressBar() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const SectionLabel('Progress'),
          const Spacer(),
          Text(
            '${(_progress * 100).toInt()}%',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.purple,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: _progress,
          backgroundColor: AppTheme.border,
          valueColor: const AlwaysStoppedAnimation(AppTheme.purple),
          minHeight: 6,
        ),
      ),
    ],
  );

  Widget _buildResultBanner() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: (_success ? AppTheme.success : AppTheme.danger).withOpacity(0.08),
      border: Border.all(
        color: (_success ? AppTheme.success : AppTheme.danger).withOpacity(0.3),
      ),
    ),
    child: Row(
      children: [
        Icon(
          _success
              ? Icons.check_circle_outline_rounded
              : Icons.error_outline_rounded,
          size: 16,
          color: _success ? AppTheme.success : AppTheme.danger,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _resultMessage!,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _success ? AppTheme.success : AppTheme.danger,
            ),
          ),
        ),
        if (_success)
          GestureDetector(
            onTap: () {
              final dir = _out1Path != null ? p.dirname(_out1Path!) : null;
              if (dir != null) Process.run('explorer', [dir]);
            },
            child: Text(
              'Open folder',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.accent,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
      ],
    ),
  ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1);
}
